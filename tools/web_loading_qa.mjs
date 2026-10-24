#!/usr/bin/env node
/*
 * Interrupt each large Web download, require a visible error (not an endless
 * loading screen), then allow the asset through and activate the real retry.
 * PASS requires a fresh engine boot into WORLD, no unhandled rejection, and
 * monotonic combined WASM + PCK progress after recovery.
 *
 *   node tools/web_loading_qa.mjs --json
 *   node tools/web_loading_qa.mjs --asset wasm --out exports/web-loading-qa
 *   node tools/web_loading_qa.mjs --url http://127.0.0.1:8000
 */
import fs from 'node:fs';
import path from 'node:path';
import zlib from 'node:zlib';
import { execFileSync, spawn } from 'node:child_process';
import { fileURLToPath } from 'node:url';

const ROOT = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '..');
const CACHE = path.join(ROOT, 'tools', '.cache');
const LIB_DIR = path.join(CACHE, 'al2023-lib', 'lib');
const argv = process.argv.slice(2);
const flag = (name, fallback) => {
  const index = argv.indexOf(name);
  return index === -1 ? fallback : argv[index + 1];
};
const has = (name) => argv.includes(name);
const asJson = has('--json');
const progress = (message) => (asJson ? console.error(message) : console.log(message));
const outDir = path.resolve(ROOT, flag('--out', path.join('exports', 'web-loading-qa')));
const timeoutMs = Math.max(20, Number(flag('--timeout', '120')) || 120) * 1000;
const throughputMbps = Math.max(0, Number(flag('--throughput-mbps', '0')) || 0);
const selected = flag('--asset', 'both');
if (!['both', 'wasm', 'pck'].includes(selected)) {
  console.error('ERROR: --asset must be both, wasm, or pck');
  process.exit(2);
}

let chromium;
let puppeteer;
for (const [name, assign] of [
  ['@sparticuz/chromium', (value) => { chromium = value; }],
  ['puppeteer-core', (value) => { puppeteer = value; }],
]) {
  try {
    assign((await import(name)).default);
  } catch (error) {
    console.error(`ERROR: ${name} is not installed. Run: npm ci --prefix tools`);
    console.error(String(error.message || error));
    process.exit(2);
  }
}

if (!fs.existsSync(path.join(LIB_DIR, 'libnss3.so'))) {
  const archive = path.join(path.dirname(fileURLToPath(import.meta.resolve('@sparticuz/chromium'))), '..', 'bin', 'al2023.tar.br');
  fs.mkdirSync(path.dirname(LIB_DIR), { recursive: true });
  const tar = path.join(CACHE, 'al2023.tar');
  fs.writeFileSync(tar, zlib.brotliDecompressSync(fs.readFileSync(archive)));
  execFileSync('tar', ['-xf', tar, '-C', path.dirname(LIB_DIR)]);
  fs.rmSync(tar);
}

let server = null;
let baseUrl = String(flag('--url', '')).replace(/\/$/, '');
if (!baseUrl) {
  const port = Number(flag('--port', '8132'));
  server = spawn('python3', ['-m', 'http.server', String(port), '--bind', '127.0.0.1'], { cwd: ROOT, stdio: 'ignore' });
  baseUrl = `http://127.0.0.1:${port}`;
  await new Promise((resolve) => setTimeout(resolve, 800));
}
fs.mkdirSync(outDir, { recursive: true });

const browser = await puppeteer.launch({
  executablePath: await chromium.executablePath(),
  args: [...chromium.args, '--no-sandbox', '--disable-dev-shm-usage'],
  headless: true,
  protocolTimeout: 300000,
  env: { ...process.env, LD_LIBRARY_PATH: [LIB_DIR, process.env.LD_LIBRARY_PATH].filter(Boolean).join(':') },
}).catch((error) => {
  if (server) server.kill();
  throw error;
});

const report = { base: baseUrl, throughputMbps: throughputMbps || null, cases: [] };
const assets = selected === 'both' ? ['wasm', 'pck'] : [selected];

function summarizeEvents(events) {
  return {
    count: events.length,
    totals: [...new Set(events.map((event) => event[1]))],
    first: events.slice(0, 3),
    last: events.slice(-3),
  };
}

function compactConsecutive(values) {
  return values.filter((value, index) => index === 0 || value !== values[index - 1]);
}

async function runCase(asset) {
  const filename = `index.${asset}`;
  const result = { asset: filename, failures: [] };
  const consoleLines = [];
  const pageErrors = [];
  const failedRequests = [];
  let failAssets = true;
  const page = await browser.newPage();
  await page.setViewport({ width: 844, height: 390, deviceScaleFactor: 1 });
  await page.setCacheEnabled(false);
  if (throughputMbps > 0) {
    const session = await page.createCDPSession();
    await session.send('Network.enable');
    await session.send('Network.emulateNetworkConditions', {
      offline: false,
      latency: 80,
      downloadThroughput: throughputMbps * 1000000 / 8,
      uploadThroughput: Math.min(throughputMbps, 20) * 1000000 / 8,
    });
  }
  page.on('console', (message) => consoleLines.push(`${message.type()}: ${message.text().slice(0, 500)}`));
  page.on('pageerror', (error) => pageErrors.push(String(error).slice(0, 500)));
  page.on('requestfailed', (request) => failedRequests.push(`${request.url().replace(baseUrl, '')} ${request.failure()?.errorText}`));
  await page.setRequestInterception(true);
  page.on('request', (request) => {
    if (failAssets && request.url().endsWith(`/web/${filename}`)) request.abort('failed');
    else request.continue();
  });
  await page.evaluateOnNewDocument(() => {
    window.__loadingTrace = { percent: [], status: [] };
    window.__progressEvents = [];
    // Observe the real loader callback without replacing its behavior. This
    // distinguishes missing engine progress from a DOM observer that ran late.
    let engineClass;
    Object.defineProperty(window, 'Engine', {
      configurable: true,
      get: () => engineClass,
      set: (value) => {
        engineClass = new Proxy(value, {
          construct(target, args) {
            const instance = Reflect.construct(target, args);
            const startGame = instance.startGame;
            instance.startGame = function (options) {
              const onProgress = options?.onProgress;
              return startGame.call(this, {
                ...options,
                onProgress: (loaded, total) => {
                  window.__progressEvents.push([loaded, total]);
                  if (onProgress) onProgress(loaded, total);
                },
              });
            };
            return instance;
          },
        });
      },
    });
    // Install before DOMContentLoaded: qa_stage boots from the module at the end
    // of the body, so a fast localhost download can finish before a DCL listener.
    const install = () => {
      const percent = document.getElementById('launch-percent');
      const status = document.getElementById('launch-status');
      if (!percent || !status) return false;
      const record = () => {
        const value = percent.textContent.trim();
        if (/^\d+%$/.test(value)) window.__loadingTrace.percent.push(Number.parseInt(value, 10));
        const phase = status.textContent.trim();
        if (window.__loadingTrace.status.at(-1) !== phase) window.__loadingTrace.status.push(phase);
      };
      new MutationObserver(record).observe(percent, { childList: true, subtree: true, characterData: true });
      new MutationObserver(record).observe(status, { childList: true, subtree: true, characterData: true });
      record();
      return true;
    };
    const observer = new MutationObserver(() => {
      if (install()) observer.disconnect();
    });
    observer.observe(document, { childList: true, subtree: true });
    if (install()) observer.disconnect();
  });

  const expect = (condition, message) => {
    if (!condition) result.failures.push(message);
  };
  const state = () => page.evaluate(() => ({
    title: document.getElementById('launch-title')?.textContent || '',
    status: document.getElementById('launch-status')?.textContent || '',
    hint: document.getElementById('launch-hint')?.textContent || '',
    retryVisible: !!document.getElementById('launch-retry') && !document.getElementById('launch-retry').hidden,
    canvasHidden: document.getElementById('canvas')?.dataset.hidden,
    appDisplay: getComputedStyle(document.getElementById('app')).display,
    mode: document.body.dataset.mode || '',
    trace: window.__loadingTrace || { percent: [], status: [] },
    progressEvents: window.__progressEvents || [],
  }));

  try {
    await page.goto(`${baseUrl}/`, { waitUntil: 'domcontentloaded', timeout: 60000 });
    await page.waitForFunction(() => {
      const button = document.getElementById('opening-enter');
      return button && !button.disabled;
    }, { timeout: 30000 });
    await page.evaluate(() => document.getElementById('opening-enter').click());
    await page.evaluate(() => document.getElementById('hub-deploy').click());
    await page.waitForFunction(() => {
      const button = document.getElementById('launch-retry');
      return button && !button.hidden;
    }, { timeout: 30000 });

    result.interrupted = await state();
    result.interruptedProgress = summarizeEvents(result.interrupted.progressEvents);
    delete result.interrupted.progressEvents;
    result.expectedRequestFailures = [...failedRequests];
    result.interruptedPageErrors = [...pageErrors];
    expect(result.interrupted.retryVisible, 'interrupted download did not expose retry');
    expect(result.interrupted.title === 'Koneksi dunia terputus', `unexpected failure title: ${result.interrupted.title}`);
    expect(result.interrupted.canvasHidden === 'true', 'canvas was revealed after a failed boot');
    expect(result.interruptedPageErrors.length === 0, `unhandled initialization rejection: ${result.interruptedPageErrors.join(' | ')}`);
    expect(result.expectedRequestFailures.some((line) => line.includes(filename)), 'the requested asset was not actually interrupted');
    await page.screenshot({ path: path.join(outDir, `${asset}-interrupted.png`) });

    failAssets = false;
    consoleLines.length = 0;
    pageErrors.length = 0;
    failedRequests.length = 0;
    await Promise.all([
      page.waitForNavigation({ waitUntil: 'domcontentloaded', timeout: 60000 }),
      page.click('#launch-retry'),
    ]);
    await page.waitForFunction(() => (
      document.body.dataset.mode === 'playing'
      && document.getElementById('canvas')?.dataset.hidden === 'false'
      && getComputedStyle(document.getElementById('app')).display === 'none'
    ), { timeout: timeoutMs });
    await page.waitForFunction(() => document.getElementById('launch-status')?.textContent === 'dunia siap', { timeout: 15000 });
    result.recovered = await state();
    result.recoveredConsole = [...consoleLines];
    result.recoveredPageErrors = [...pageErrors];
    result.recoveredRequestFailures = [...failedRequests];
    const percentages = result.recovered.trace.percent;
    const statuses = result.recovered.trace.status;
    const events = result.recovered.progressEvents;
    expect(result.recovered.mode === 'playing' && result.recovered.canvasHidden === 'false', 'retry did not reveal the game canvas');
    expect(consoleLines.some((line) => /Godot Engine v/i.test(line)), 'retry produced no Godot engine banner');
    expect(consoleLines.some((line) => line.includes('FrontEnd: stage WORLD')), 'retry did not reach WORLD');
    expect(result.recoveredPageErrors.length === 0, `retry page errors: ${result.recoveredPageErrors.join(' | ')}`);
    expect(events.length > 0, 'the loader emitted no byte-progress events');
    expect(events.every((event) => event[1] > 0), 'loader regressed to total=0; remap the rewritten fileSizes paths');
    expect(events.at(-1)?.[0] === events.at(-1)?.[1], 'the final loader event was incomplete');
    // Reload intentionally aborts any still-active request from the failed
    // document. Keep those diagnostics, but prove recovery by the fresh engine
    // banner/WORLD/canvas instead of misattributing that old ERR_ABORTED.
    expect(percentages.at(-1) === 100, `combined progress did not finish at 100: ${percentages.join(',')}`);
    expect(percentages.every((value, index) => index === 0 || value >= percentages[index - 1]), `combined progress moved backwards: ${percentages.join(',')}`);
    if (throughputMbps > 0) {
      expect(percentages.some((value) => value < 100), `throttled download exposed no intermediate byte progress: ${percentages.join(',')}`);
      expect(
        statuses.some((line) => line.includes('mengunduh mesin + dunia')),
        'combined byte/phase status was not rendered',
      );
    }
    const downloadStatuses = statuses.filter((line) => line.includes('mengunduh mesin + dunia'));
    result.progressEvidence = {
      ...summarizeEvents(events),
      firstDownloadStatus: downloadStatuses[0] || null,
      lastDownloadStatus: downloadStatuses.at(-1) || null,
    };
    result.recovered.trace = {
      percent: compactConsecutive(percentages),
      status: compactConsecutive(statuses.map((line) => (
        line.includes('mengunduh mesin + dunia') ? 'mengunduh mesin + dunia (byte counts above)' : line
      ))),
    };
    delete result.recovered.progressEvents;
    await page.screenshot({ path: path.join(outDir, `${asset}-recovered.png`) });
  } catch (error) {
    result.failures.push(String(error.stack || error));
    try {
      result.lastState = await state();
      await page.screenshot({ path: path.join(outDir, `${asset}-failed.png`) });
    } catch { /* browser may already have closed */ }
  } finally {
    result.ok = result.failures.length === 0;
    await page.close();
  }
  return result;
}

try {
  for (const asset of assets) {
    progress(`Loading recovery: interrupt index.${asset}, then retry`);
    const result = await runCase(asset);
    report.cases.push(result);
    progress(`  ${result.ok ? 'PASS' : 'FAIL'} index.${asset}${result.failures.length ? ` — ${result.failures.join(' | ')}` : ''}`);
  }
} finally {
  await browser.close();
  if (server) server.kill();
}

report.ok = report.cases.length === assets.length && report.cases.every((result) => result.ok);
const serialized = `${JSON.stringify(report, null, 2)}\n`;
fs.writeFileSync(path.join(outDir, 'report.json'), serialized);
if (asJson) console.log(serialized.trimEnd());
else console.log(`Loading recovery: ${report.ok ? 'PASS' : 'FAIL'} (${report.cases.filter((result) => result.ok).length}/${assets.length})`);
process.exitCode = report.ok ? 0 : 1;
