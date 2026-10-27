#!/usr/bin/env node
/*
 * Verify browser-support failures happen before Godot downloads or constructs
 * its runtime. The insecure-context case uses a real non-loopback HTTP URL;
 * the AudioWorklet case deliberately removes that capability on a secure
 * localhost origin so it is tested independently.
 *
 *   node tools/web_support_qa.mjs --json
 *   node tools/web_support_qa.mjs \
 *     --url http://127.0.0.1:8000 \
 *     --insecure-url http://192.168.1.10:8000
 */
import fs from 'node:fs';
import os from 'node:os';
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
const asJson = argv.includes('--json');
const outDir = path.resolve(ROOT, flag('--out', path.join('exports', 'web-support-qa')));
const timeoutMs = Math.max(5, Number(flag('--timeout', '30')) || 30) * 1000;
const progress = (message) => (asJson ? console.error(message) : console.log(message));

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
let secureUrl = String(flag('--url', '')).replace(/\/$/, '');
let insecureUrl = String(flag('--insecure-url', '')).replace(/\/$/, '');
if (!secureUrl) {
  const port = Number(flag('--port', '8137'));
  server = spawn('python3', ['tools/serve_preview.py', '--host', '0.0.0.0', '--port', String(port)], {
    cwd: ROOT,
    stdio: 'ignore',
  });
  secureUrl = `http://127.0.0.1:${port}`;
  let ready = false;
  for (let attempt = 0; attempt < 50; attempt += 1) {
    try {
      const response = await fetch(`${secureUrl}/__build`);
      if (response.ok) {
        ready = true;
        break;
      }
    } catch {
      // The server may still be binding.
    }
    await new Promise((resolve) => setTimeout(resolve, 100));
  }
  if (!ready) {
    server.kill();
    throw new Error(`Preview server did not become ready at ${secureUrl}`);
  }
}
if (!insecureUrl) {
  const port = new URL(secureUrl).port || '80';
  const address = Object.values(os.networkInterfaces())
    .flat()
    .find((entry) => entry && entry.family === 'IPv4' && !entry.internal)?.address;
  if (!address) {
    if (server) server.kill();
    throw new Error('No non-loopback IPv4 address; pass --insecure-url explicitly');
  }
  insecureUrl = `http://${address}:${port}`;
}

fs.mkdirSync(outDir, { recursive: true });
const browser = await puppeteer.launch({
  executablePath: await chromium.executablePath(),
  args: [...chromium.args, '--no-sandbox', '--disable-dev-shm-usage'],
  headless: true,
  protocolTimeout: 120000,
  env: { ...process.env, LD_LIBRARY_PATH: [LIB_DIR, process.env.LD_LIBRARY_PATH].filter(Boolean).join(':') },
}).catch((error) => {
  if (server) server.kill();
  throw error;
});

const report = { secureUrl, insecureUrl, cases: [], ok: false };

async function checkCase({ name, baseUrl, locale, removeAudio, query = '', expectedScreen = 'opening', expect }) {
  const result = { name, url: `${baseUrl}/?lang=${locale}${query}`, simulated: removeAudio ? 'AudioWorklet removed' : null, failures: [] };
  const expectCheck = (condition, message) => {
    if (!condition) result.failures.push(message);
  };
  const page = await browser.newPage();
  const pageErrors = [];
  const payloadRequests = [];
  const configRequests = [];
  page.on('pageerror', (error) => pageErrors.push(String(error)));
  page.on('request', (request) => {
    const url = new URL(request.url());
    if (/^\/web\/index\.(?:wasm|pck)$/.test(url.pathname)) payloadRequests.push(url.pathname);
    if (url.pathname === '/web/index.html') configRequests.push(url.pathname);
  });
  await page.setViewport({ width: 844, height: 390, deviceScaleFactor: 1 });
  await page.evaluateOnNewDocument((disableAudio) => {
    window.__engineConstructs = 0;
    let engineClass;
    Object.defineProperty(window, 'Engine', {
      configurable: true,
      get: () => engineClass,
      set: (Value) => {
        engineClass = new Proxy(Value, {
          construct(target, args) {
            window.__engineConstructs += 1;
            return Reflect.construct(target, args);
          },
        });
      },
    });
    if (disableAudio) {
      // Web IDL exposes the getter on BaseAudioContext in Chromium. Keep the
      // AudioContext constructor and remove only the capability under test.
      for (const prototype of [
        window.AudioContext?.prototype,
        window.webkitAudioContext?.prototype,
        window.BaseAudioContext?.prototype,
      ]) {
        if (prototype) delete prototype.audioWorklet;
      }
    }
  }, removeAudio);

  try {
    await page.goto(result.url, { waitUntil: 'domcontentloaded', timeout: timeoutMs });
    await page.waitForFunction(() => {
      const note = document.getElementById('opening-note');
      return note && !note.hidden && note.textContent.trim().length > 0;
    }, { timeout: timeoutMs });
  } catch (error) {
    result.failures.push(`support error was not visible: ${error.message}`);
  }

  const state = await page.evaluate(() => ({
    secure: window.isSecureContext,
    audioWorklet: typeof window.AudioContext === 'function'
      ? window.Engine?.isAudioWorkletAvailable?.() ?? null
      : false,
    engineConstructs: window.__engineConstructs,
    screen: document.body.dataset.screen || '',
    title: document.getElementById('launch-title')?.textContent || '',
    note: document.getElementById('opening-note')?.textContent || '',
    noteVisible: document.getElementById('opening-note')?.hidden === false,
    retry: document.body.dataset.screen === 'launch'
      ? document.getElementById('launch-retry')?.hidden === false
      : !document.getElementById('opening-enter')?.disabled,
    canvasHidden: document.getElementById('canvas')?.dataset.hidden,
  }));
  Object.assign(result, { state, pageErrors, payloadRequests, configRequests });
  expectCheck(state.noteVisible, 'opening support note is hidden');
  expectCheck(state.retry, `${expectedScreen} retry is not available`);
  expectCheck(state.screen === expectedScreen, `expected ${expectedScreen}, got ${state.screen || '<none>'}`);
  expectCheck(state.canvasHidden === 'true', 'gameplay canvas was revealed');
  expectCheck(state.engineConstructs === 0, `Engine was constructed ${state.engineConstructs} time(s)`);
  expectCheck(payloadRequests.length === 0, `payload requested before support failure: ${payloadRequests.join(', ')}`);
  expectCheck(configRequests.length === 0, 'exported config was fetched before support failure');
  expectCheck(pageErrors.length === 0, `page errors: ${pageErrors.join(' | ')}`);
  expectCheck(!/addModule/i.test(state.note), 'raw addModule exception leaked into the support note');
  expect(state, expectCheck);

  const shot = path.join(outDir, `${name}.png`);
  await page.screenshot({ path: shot });
  result.screenshot = path.relative(ROOT, shot);
  result.ok = result.failures.length === 0;
  report.cases.push(result);
  progress(`${name}: ${result.ok ? 'PASS' : 'FAIL'}`);
  for (const failure of result.failures) progress(`  ${failure}`);
  await page.close();
}

try {
  await checkCase({
    name: 'insecure-context',
    baseUrl: insecureUrl,
    locale: 'id',
    removeAudio: false,
    expect: (state, check) => {
      check(state.secure === false, 'test URL was not a real insecure context');
      check(state.audioWorklet === false, 'insecure context unexpectedly exposed AudioWorklet');
      check(/HTTPS/.test(state.note) && /http:\/\/localhost:\d+\//.test(state.note), 'note lacks HTTPS/localhost recovery guidance');
      check(/IP LAN|LAN IP/.test(state.note), 'note does not explain the LAN-IP boundary');
      check(/Koneksi aman diperlukan/.test(state.title), `wrong localized title: ${state.title}`);
    },
  });
  await checkCase({
    name: 'insecure-direct-deploy',
    baseUrl: insecureUrl,
    locale: 'id',
    removeAudio: false,
    query: '&ui=launch&qa_world=frostline_relay',
    expectedScreen: 'launch',
    expect: (state, check) => {
      check(state.secure === false, 'direct-DEPLOY URL was not a real insecure context');
      check(/HTTPS/.test(state.note) && /http:\/\/localhost:\d+\//.test(state.note), 'direct DEPLOY lacks HTTPS/localhost recovery guidance');
      check(/Koneksi aman diperlukan/.test(state.title), 'direct DEPLOY erased the preflight failure title');
    },
  });
  await checkCase({
    name: 'missing-audio-worklet',
    baseUrl: secureUrl,
    locale: 'en',
    removeAudio: true,
    expect: (state, check) => {
      check(state.secure === true, 'localhost control case was not secure');
      check(state.audioWorklet === false, 'AudioWorklet removal was not observed by the exported engine probe');
      check(/AudioWorklet/.test(state.note) && /Chrome, Edge, Firefox, or Safari/.test(state.note), 'note lacks AudioWorklet/browser recovery guidance');
      check(!/HTTPS|localhost:\d+/.test(state.note), 'capability failure was misdiagnosed as an insecure URL');
      check(/Browser not supported/.test(state.title), `wrong localized title: ${state.title}`);
    },
  });
} finally {
  await browser.close();
  if (server) server.kill();
}

report.ok = report.cases.length === 3 && report.cases.every((result) => result.ok);
fs.writeFileSync(path.join(outDir, 'report.json'), `${JSON.stringify(report, null, 2)}\n`);
if (asJson) console.log(JSON.stringify(report, null, 2));
else console.log(`Summary: ${report.cases.filter((result) => result.ok).length}/${report.cases.length} support cases passed`);
if (!report.ok) process.exitCode = 1;
