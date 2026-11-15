#!/usr/bin/env node
/**
 * qa_armory_shot.mjs -- photograph the in-dashboard ARMORY overlay.
 *
 * `tools/qa_flow_shots.mjs` covers the seven FrontEnd stages, but the armory
 * is an overlay on DASHBOARD (`stage_dashboard.gd` `_on_armory_pressed`), not
 * a stage, so it has no `?qa_stage=` deep link. This script deep-links to
 * DASHBOARD exactly like qa_flow_shots and clicks the ARMORY button at its
 * anchored dashboard position per viewport, then screenshots the overlay.
 *
 * Usage:
 *   node tools/qa_armory_shot.mjs [--tag armory] [--port 8061]
 *     [--base http://127.0.0.1:8061] [--viewport 1280x720,844x390]
 *
 * Requires tools/node_modules (npm install in tools/) and .venv (Pillow) if
 * you want image stats on the output; the frames are written to
 * exports/flow/<tag>/. Serves `web/` itself unless --base points at a running
 * server.
 */
import { spawn } from 'node:child_process';
import { execFileSync } from 'node:child_process';
import fs from 'node:fs';
import os from 'node:os';
import path from 'node:path';
import zlib from 'node:zlib';
import { fileURLToPath } from 'node:url';

const ROOT = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '..');

function arg(name, fallback) {
  const i = process.argv.indexOf(name);
  return i >= 0 && process.argv[i + 1] ? process.argv[i + 1] : fallback;
}

const tag = arg('--tag', 'armory');
const port = Number(arg('--port', '8061'));
const base = arg('--base', `http://127.0.0.1:${port}`);
const specs = arg('--viewport', '1280x720,844x390').split(',');

/* ARMORY button centre in canvas pixels, measured from the DASHBOARD frames
 * (exports/flow/gf6/dashboard-*.png): the right-hand action column under the
 * RUNS panel. Anchors keep it fixed per aspect; each entry = (x, y). */
const ARMORY_BUTTON = {
  '1280x720': [1073, 512],
  '844x390': [688, 226],
};

/* --- browser bootstrap (same recipe as qa_flow_shots.mjs) --- */
const LIB_DIR = path.join(ROOT, 'tools', '.cache', 'al2023-lib', 'lib');
if (!fs.existsSync(path.join(LIB_DIR, 'libnss3.so'))) {
  const br = path.join(
    path.dirname(fileURLToPath(import.meta.resolve('@sparticuz/chromium'))),
    '..', 'bin', 'al2023.tar.br',
  );
  fs.mkdirSync(path.dirname(LIB_DIR), { recursive: true });
  const tar = path.join(ROOT, 'tools', '.cache', 'al2023.tar');
  fs.writeFileSync(tar, zlib.brotliDecompressSync(fs.readFileSync(br)));
  execFileSync('tar', ['-xf', tar, '-C', path.dirname(LIB_DIR)]);
  fs.rmSync(tar);
}

const chromium = (await import('@sparticuz/chromium')).default;
const puppeteer = (await import('puppeteer-core')).default;

let server = null;
if (!process.argv.includes('--base')) {
  server = spawn('python3', ['-m', 'http.server', String(port), '--bind', '127.0.0.1'], {
    cwd: path.join(ROOT, 'web'),
    stdio: 'ignore',
  });
  await new Promise((r) => setTimeout(r, 900));
}

const outDir = path.join(ROOT, 'exports', 'flow', tag);
fs.mkdirSync(outDir, { recursive: true });

const userDataDir = fs.mkdtempSync(path.join(os.tmpdir(), 'qaarmory-profile-'));
const stripProfile = (args) => args.filter((a) => !String(a).startsWith('--user-data-dir'));
const browser = await puppeteer.launch({
  executablePath: await chromium.executablePath(),
  args: [
    ...stripProfile(chromium.args),
    '--no-sandbox',
    '--disable-dev-shm-usage',
    `--user-data-dir=${userDataDir}`,
  ],
  headless: true,
  protocolTimeout: 300000,
  env: {
    ...process.env,
    LD_LIBRARY_PATH: [LIB_DIR, process.env.LD_LIBRARY_PATH].filter(Boolean).join(':'),
  },
});

const results = [];
for (const spec of specs) {
  const [w, h] = spec.split('x').map(Number);
  const page = await browser.newPage();
  await page.setViewport({ width: w, height: h, hasTouch: w < 600, isMobile: w < 600, deviceScaleFactor: 1 });
  const lines = [];
  page.on('console', (m) => lines.push(String(m.text())));
  await page.goto(`${base}/?qa_stage=DASHBOARD&qa_hold=1`, { waitUntil: 'domcontentloaded', timeout: 120000 });
  await page.waitForFunction(() => document.querySelector('canvas') !== null, { timeout: 180000 });
  const deadline = Date.now() + 120000;
  while (Date.now() < deadline && !lines.some((l) => l.includes('FrontEnd: stage DASHBOARD'))) {
    await new Promise((r) => setTimeout(r, 250));
  }
  await new Promise((r) => setTimeout(r, 1500));
  const [cx, cy] = ARMORY_BUTTON[spec] || ARMORY_BUTTON['1280x720'];
  await page.mouse.click(cx, cy);
  /* ArmoryUi covers the dashboard; give it a beat to lay out. */
  await new Promise((r) => setTimeout(r, 1800));
  const file = path.join(outDir, `armory-${spec}.png`);
  await page.screenshot({ path: file });
  const armed = lines.slice(-12).join('\n');
  results.push({ spec, file: path.relative(ROOT, file), sawArmoryLog: /armory/i.test(armed) });
  console.log(`shot ${path.relative(ROOT, file)}`);
  await page.close();
}

await browser.close();
if (server) server.kill();
console.log(JSON.stringify({ tag, results }, null, 2));
