#!/usr/bin/env node
/*
 * Verify the real opening download contract and interrupted-download recovery.
 *
 * Opening contract: WASM + PCK finish before MASUK, no gameplay runs behind the
 * opening, and DEPLOY consumes the same buffers instead of fetching the PCK
 * again. Recovery: interrupt a large download on a direct selected-world DEPLOY,
 * require a visible retry, then reload into that same world's real gameplay.
 *
 *   node tools/web_loading_qa.mjs --json
 *   node tools/web_loading_qa.mjs --asset opening --world vanguard_station
 *   node tools/web_loading_qa.mjs --asset pck --out exports/web-loading-qa
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
const world = flag('--world', 'frostline_relay');
if (!['both', 'opening', 'wasm', 'pck'].includes(selected)) {
  console.error('ERROR: --asset must be both, opening, wasm, or pck');
  process.exit(2);
}
if (!/^[a-z][a-z0-9_]*$/.test(world)) {
  console.error('ERROR: --world must be a snake_case world id');
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

const report = { base: baseUrl, throughputMbps: throughputMbps || null, world, opening: null, cases: [] };
const assets = selected === 'both' ? ['wasm', 'pck'] : selected === 'opening' ? [] : [selected];
const cardId = `world-card-${world.replaceAll('_', '-')}`;
const selectionLog = `FrontEnd: qa_world selected ${world}`;
const worldBuildLog = world === 'vanguard_station' ? 'VanguardStation:' : `MISSION WORLD: ${world} (`;

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

function requestCount(requests, filename) {
  return requests.filter((url) => url.endsWith(`/web/${filename}`)).length;
}

async function makePage() {
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

  const consoleLines = [];
  const pageErrors = [];
  const failedRequests = [];
  const assetRequests = [];
  const stageAssetRequests = [];
  page.on('console', (message) => consoleLines.push(`${message.type()}: ${message.text().slice(0, 500)}`));
  page.on('pageerror', (error) => pageErrors.push(String(error).slice(0, 500)));
  page.on('requestfailed', (request) => failedRequests.push(`${request.url().replace(baseUrl, '')} ${request.failure()?.errorText}`));
  page.on('request', (request) => {
    if (/\/web\/index\.(?:wasm|pck)$/.test(request.url())) assetRequests.push(request.url());
  });
  page.on('request', (request) => {
    if (/human_hero_tiers|futuristic_rifle|hero_rig\.json/.test(request.url())) {
      stageAssetRequests.push(request.url());
    }
  });

  await page.evaluateOnNewDocument(() => {
    window.__loadingTrace = { percent: [], status: [] };
    window.__progressEvents = [];
    window.__engineCalls = [];
    // Observe the actual Engine instance without replacing loading behavior.
    // The opening uses init/preloadFile/start; a startGame call is a regression
    // because it would fetch the already-preloaded PCK a second time.
    let engineClass;
    Object.defineProperty(window, 'Engine', {
      configurable: true,
      get: () => engineClass,
      set: (value) => {
        engineClass = new Proxy(value, {
          construct(target, args) {
            const config = { ...(args[0] || {}) };
            const onProgress = config.onProgress;
            config.onProgress = (loaded, total) => {
              window.__progressEvents.push([loaded, total, performance.now()]);
              if (onProgress) onProgress(loaded, total);
            };
            const instance = Reflect.construct(target, [config]);
            for (const method of ['init', 'preloadFile', 'start', 'startGame']) {
              const original = instance[method];
              if (typeof original !== 'function') continue;
              instance[method] = function (...callArgs) {
                window.__engineCalls.push({ method, at: performance.now(), args: callArgs.map((arg) => {
                  if (method === 'start' || method === 'startGame') return arg?.args || [];
                  return typeof arg === 'string' ? arg : '<buffer>';
                }) });
                return original.apply(this, callArgs);
              };
            }
            return instance;
          },
        });
      },
    });

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

  return { page, consoleLines, pageErrors, failedRequests, assetRequests, stageAssetRequests };
}

async function readState(page) {
  return page.evaluate(() => ({
    screen: document.body.dataset.screen || '',
    mode: document.body.dataset.mode || '',
    openingStatus: document.getElementById('opening-status')?.textContent || '',
    openingLabel: document.getElementById('opening-enter')?.querySelector('.btn__label')?.textContent || '',
    openingNote: document.getElementById('opening-note')?.hidden === false
      ? document.getElementById('opening-note').textContent
      : '',
    title: document.getElementById('launch-title')?.textContent || '',
    status: document.getElementById('launch-status')?.textContent || '',
    hint: document.getElementById('launch-hint')?.textContent || '',
    retryVisible: !!document.getElementById('launch-retry') && !document.getElementById('launch-retry').hidden,
    canvasHidden: document.getElementById('canvas')?.dataset.hidden,
    appDisplay: getComputedStyle(document.getElementById('app')).display,
    trace: window.__loadingTrace || { percent: [], status: [] },
    progressEvents: window.__progressEvents || [],
    engineCalls: window.__engineCalls || [],
  }));
}

function expectByteProgress(result, state, requireIntermediate) {
  const events = state.progressEvents;
  const percentages = state.trace.percent;
  const loaded = events.map((event) => event[0]);
  result.expect(events.length > 0, 'the loader emitted no aggregate byte-progress events');
  result.expect(events.every((event) => event[1] > 0), 'loader regressed to total=0; check rewritten fileSizes keys');
  result.expect(loaded.every((value, index) => index === 0 || value >= loaded[index - 1]), 'aggregate byte count moved backwards');
  result.expect(events.at(-1)?.[0] === events.at(-1)?.[1], 'the final loader event was incomplete');
  result.expect(percentages.at(-1) === 100, `combined progress did not finish at 100: ${percentages.join(',')}`);
  result.expect(percentages.every((value, index) => index === 0 || value >= percentages[index - 1]), 'displayed progress moved backwards');
  if (requireIntermediate) {
    result.expect(percentages.some((value) => value < 100), 'throttled download exposed no intermediate byte progress');
    result.expect(
      state.trace.status.some((line) => /mengunduh mesin \+ dunia|downloading engine \+ world/i.test(line)),
      'combined byte/phase status was not rendered',
    );
  }
}

function expectSingleDownloadStart(result, state, requests, requireNotStarted) {
  const calls = state.engineCalls;
  const preloads = calls.filter((call) => call.method === 'preloadFile');
  const starts = calls.filter((call) => call.method === 'start');
  result.expect(requestCount(requests, 'index.wasm') === 1, `WASM request count was ${requestCount(requests, 'index.wasm')}, expected 1`);
  result.expect(requestCount(requests, 'index.pck') === 1, `PCK request count was ${requestCount(requests, 'index.pck')}, expected 1`);
  result.expect(preloads.length === 1 && String(preloads[0].args[0]).endsWith('/web/index.pck'), 'opening did not preload the main PCK exactly once');
  result.expect(!calls.some((call) => call.method === 'startGame'), 'startGame caused a second main-pack preload path');
  if (requireNotStarted) {
    result.expect(starts.length === 0, 'gameplay engine.start ran behind the opening');
  } else {
    result.expect(starts.length === 1, `engine.start count was ${starts.length}, expected 1`);
    result.expect(
      starts[0]?.args[0]?.includes('--main-pack') && starts[0]?.args[0]?.some((arg) => String(arg).endsWith('/web/index.pck')),
      'engine.start did not receive the already-preloaded main pack',
    );
    const finalDownloadAt = state.progressEvents.at(-1)?.[2] || 0;
    result.expect(finalDownloadAt <= (starts[0]?.at || 0), 'engine.start ran before the opening download completed');
  }
}

async function runOpeningContract() {
  const result = { failures: [] };
  const { page, consoleLines, pageErrors, failedRequests, assetRequests, stageAssetRequests } = await makePage();
  result.expect = (condition, message) => { if (!condition) result.failures.push(message); };

  try {
    await page.goto(`${baseUrl}/`, { waitUntil: 'domcontentloaded', timeout: 60000 });
    await page.waitForFunction(() => {
      const button = document.getElementById('opening-enter');
      const label = button?.querySelector('.btn__label')?.textContent.trim().toUpperCase();
      // The integrated shell is localized; readiness is the enabled ENTER /
      // MASUK action, not one hard-coded language string.
      return ['ENTER', 'MASUK'].includes(label) && !button?.disabled;
    }, { timeout: timeoutMs });

    result.opening = await readState(page);
    result.openingRequests = [...assetRequests];
    result.openingStageRequests = [...stageAssetRequests];
    result.expect(stageAssetRequests.length === 0, 'hero/rifle stage assets loaded behind OPENING');
    expectSingleDownloadStart(result, result.opening, assetRequests, true);
    expectByteProgress(result, result.opening, throughputMbps > 0);
    result.expect(result.opening.screen === 'opening', `opening advanced too early to ${result.opening.screen}`);
    result.expect(result.opening.canvasHidden === 'true' && result.opening.mode !== 'playing', 'canvas/gameplay was revealed during opening preload');
    result.expect(!consoleLines.some((line) => line.includes('Encounter:')), 'gameplay ran behind the opening');
    await page.screenshot({ path: path.join(outDir, 'opening-preloaded.png') });

    await page.evaluate(() => document.getElementById('opening-enter').click());
    result.expect(
      await page.evaluate(() => document.body.dataset.screen === 'hero'),
      'MASUK did not open the HERO screen',
    );
    await page.evaluate(() => document.getElementById('hero-next').click());
    result.expect(
      await page.evaluate(() => document.body.dataset.screen === 'hub'),
      'HERO did not continue to the theatre map',
    );
    const selectedCard = await page.evaluate((id) => {
      const card = document.getElementById(id);
      if (!card) return false;
      card.click();
      return card.getAttribute('aria-selected') === 'true';
    }, cardId);
    result.expect(selectedCard, `shell card ${cardId} did not select ${world}`);
    await page.evaluate(() => document.getElementById('hub-deploy').click());
    await page.waitForFunction(() => (
      document.body.dataset.mode === 'playing'
      && document.getElementById('canvas')?.dataset.hidden === 'false'
      && getComputedStyle(document.getElementById('app')).display === 'none'
    ), { timeout: timeoutMs });
    for (let attempt = 0; attempt < 240 && !consoleLines.some((line) => line.includes('Encounter: Explore safe')); attempt += 1) {
      await new Promise((resolve) => setTimeout(resolve, 250));
    }

    result.deployed = await readState(page);
    result.deployedRequests = [...assetRequests];
    result.console = [...consoleLines];
    result.pageErrors = [...pageErrors];
    result.failedRequests = [...failedRequests];
    expectSingleDownloadStart(result, result.deployed, assetRequests, false);
    result.expect(consoleLines.some((line) => line.includes(selectionLog)), 'DEPLOY lost the selected-world handoff');
    result.expect(consoleLines.some((line) => line.includes(worldBuildLog)), `selected world did not build: ${worldBuildLog}`);
    result.expect(consoleLines.some((line) => line.includes('Encounter: Explore safe')), 'DEPLOY did not reach safe Explore gameplay');
    result.expect(!consoleLines.some((line) => line.includes('FrontEnd: stage WORLD')), 'shell DEPLOY stopped at engine WORLD');
    result.expect(pageErrors.length === 0, `page errors: ${pageErrors.join(' | ')}`);
    result.expect(failedRequests.length === 0, `failed requests: ${failedRequests.join(' | ')}`);
    result.expect(!consoleLines.some((line) => /SCRIPT ERROR:|Parse Error:/.test(line)), 'Godot reported a script/parse error');
    result.progressEvidence = summarizeEvents(result.deployed.progressEvents);
    result.deployed.trace = {
      percent: compactConsecutive(result.deployed.trace.percent),
      status: compactConsecutive(result.deployed.trace.status),
    };
    delete result.deployed.progressEvents;
    delete result.opening.progressEvents;
    await page.screenshot({ path: path.join(outDir, 'opening-deployed.png') });
  } catch (error) {
    result.failures.push(String(error.stack || error));
    try {
      result.lastState = await readState(page);
      await page.screenshot({ path: path.join(outDir, 'opening-failed.png') });
    } catch { /* browser may already have closed */ }
  } finally {
    result.ok = result.failures.length === 0;
    await page.close();
  }
  return result;
}

async function runRecoveryCase(asset) {
  const filename = `index.${asset}`;
  const result = { asset: filename, failures: [] };
  const { page, consoleLines, pageErrors, failedRequests, assetRequests, stageAssetRequests } = await makePage();
  let failAssets = true;
  await page.setRequestInterception(true);
  page.on('request', (request) => {
    if (failAssets && request.url().endsWith(`/web/${filename}`)) request.abort('failed');
    else request.continue();
  });
  result.expect = (condition, message) => { if (!condition) result.failures.push(message); };

  try {
    // A direct DEPLOY deep link preserves the previous recovery contract: retry
    // returns to selected gameplay, while the download still happens up front.
    await page.goto(`${baseUrl}/?qa_stage=GAMEPLAY&qa_world=${world}&weapon=pulse_rifle`, { waitUntil: 'domcontentloaded', timeout: 60000 });
    await page.waitForFunction(() => {
      const button = document.getElementById('launch-retry');
      return button && !button.hidden;
    }, { timeout: timeoutMs });

    result.interrupted = await readState(page);
    result.interruptedProgress = summarizeEvents(result.interrupted.progressEvents);
    delete result.interrupted.progressEvents;
    result.expectedRequestFailures = [...failedRequests];
    result.interruptedPageErrors = [...pageErrors];
    result.expect(result.interrupted.retryVisible, 'interrupted download did not expose retry');
    result.expect(
      ['Koneksi dunia terputus', 'World connection lost'].includes(result.interrupted.title),
      `unexpected failure title: ${result.interrupted.title}`,
    );
    result.expect(result.interrupted.canvasHidden === 'true', 'canvas was revealed after a failed boot');
    result.expect(result.interruptedPageErrors.length === 0, `unhandled initialization rejection: ${result.interruptedPageErrors.join(' | ')}`);
    result.expect(result.expectedRequestFailures.some((line) => line.includes(filename)), 'the requested asset was not actually interrupted');
    await page.screenshot({ path: path.join(outDir, `${asset}-interrupted.png`) });

    failAssets = false;
    consoleLines.length = 0;
    pageErrors.length = 0;
    failedRequests.length = 0;
    assetRequests.length = 0;
    await Promise.all([
      page.waitForNavigation({ waitUntil: 'domcontentloaded', timeout: 60000 }),
      page.click('#launch-retry'),
    ]);
    await page.waitForFunction(() => (
      document.body.dataset.mode === 'playing'
      && document.getElementById('canvas')?.dataset.hidden === 'false'
      && getComputedStyle(document.getElementById('app')).display === 'none'
    ), { timeout: timeoutMs });
    await page.waitForFunction(
      () => ['dunia siap', 'world ready'].includes((document.getElementById('launch-status')?.textContent || '').trim().toLowerCase()),
      { timeout: 15000 },
    );
    for (let attempt = 0; attempt < 240 && !consoleLines.some((line) => line.includes('Encounter: Explore safe')); attempt += 1) {
      await new Promise((resolve) => setTimeout(resolve, 250));
    }

    result.recovered = await readState(page);
    result.recoveredConsole = [...consoleLines];
    result.recoveredPageErrors = [...pageErrors];
    result.recoveredRequestFailures = [...failedRequests];
    result.recoveredRequests = [...assetRequests];
    result.recoveredStageRequests = [...stageAssetRequests];
    result.expect(stageAssetRequests.length === 0, 'hero/rifle stage assets loaded behind direct DEPLOY/retry');
    result.expect(result.recovered.mode === 'playing' && result.recovered.canvasHidden === 'false', 'retry did not reveal the game canvas');
    result.expect(consoleLines.some((line) => /Godot Engine v/i.test(line)), 'retry produced no Godot engine banner');
    result.expect(consoleLines.some((line) => line.includes(selectionLog)), 'retry lost the selected-world handoff');
    result.expect(consoleLines.some((line) => line.includes(worldBuildLog)), `retry did not build ${world}`);
    result.expect(consoleLines.some((line) => line.includes('Encounter: Explore safe')), 'retry did not reach real gameplay');
    result.expect(!consoleLines.some((line) => line.includes('FrontEnd: stage WORLD')), 'retry stopped at engine WORLD');
    result.expect(result.recoveredPageErrors.length === 0, `retry page errors: ${result.recoveredPageErrors.join(' | ')}`);
    expectSingleDownloadStart(result, result.recovered, assetRequests, false);
    expectByteProgress(result, result.recovered, throughputMbps > 0);
    result.progressEvidence = summarizeEvents(result.recovered.progressEvents);
    result.recovered.trace = {
      percent: compactConsecutive(result.recovered.trace.percent),
      status: compactConsecutive(result.recovered.trace.status.map((line) => (
        /mengunduh mesin \+ dunia|downloading engine \+ world/i.test(line)
          ? 'engine + world (aggregate bytes)'
          : line
      ))),
    };
    delete result.recovered.progressEvents;
    await page.screenshot({ path: path.join(outDir, `${asset}-recovered.png`) });
  } catch (error) {
    result.failures.push(String(error.stack || error));
    try {
      result.lastState = await readState(page);
      await page.screenshot({ path: path.join(outDir, `${asset}-failed.png`) });
    } catch { /* browser may already have closed */ }
  } finally {
    result.ok = result.failures.length === 0;
    await page.close();
  }
  return result;
}

try {
  if (selected === 'both' || selected === 'opening') {
    progress(`Opening contract: preload once, then DEPLOY ${world} without another PCK request`);
    report.opening = await runOpeningContract();
    progress(`  ${report.opening.ok ? 'PASS' : 'FAIL'} opening${report.opening.ok ? '' : ` — ${report.opening.failures.join(' | ')}`}`);
  }
  for (const asset of assets) {
    progress(`Loading recovery: interrupt index.${asset}, then retry directly into ${world}`);
    const result = await runRecoveryCase(asset);
    report.cases.push(result);
    progress(`  ${result.ok ? 'PASS' : 'FAIL'} index.${asset}${result.ok ? '' : ` — ${result.failures.join(' | ')}`}`);
  }
} finally {
  await browser.close();
  if (server) server.kill();
}

report.ok = (report.opening === null || report.opening.ok)
  && report.cases.length === assets.length
  && report.cases.every((result) => result.ok);
const serialized = `${JSON.stringify(report, null, 2)}\n`;
fs.writeFileSync(path.join(outDir, 'report.json'), serialized);
if (asJson) console.log(serialized.trimEnd());
else console.log(`Opening/loading QA: ${report.ok ? 'PASS' : 'FAIL'}`);
process.exitCode = report.ok ? 0 : 1;
