#!/usr/bin/env node
/*
 * tools/ui_flow_shots.mjs — walk the player journey and prove it in pixels.
 *
 *   node tools/ui_flow_shots.mjs --tag r3
 *   node tools/ui_flow_shots.mjs --tag r3 --viewport 390x844
 *   node tools/ui_flow_shots.mjs --tag r3 --viewport 844x390
 *
 * What it does, in order, with real clicks on the real buttons:
 *
 *   opening  -> click Masuk
 *   hub      -> click Kontrol (the settings sheet), close it
 *   launch   -> click Deploy, wait for the engine's own progress, photograph it
 *   world    -> wait for the canvas to be handed over, photograph the world
 *   gameplay -> move and fire, photograph again
 *
 * Two things make this evidence rather than decoration: every step asserts the
 * screen it expected is the active one (so a broken transition fails the run),
 * and every frame is read back for statistics (so a black canvas is a failure,
 * not a file). The console is captured too: an engine error during boot fails
 * the run even if something was painted.
 *
 * Exit 0 = the whole journey completed, every frame non-blank, no console error.
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
const flag = (name, def) => {
  const index = argv.indexOf(name);
  return index === -1 ? def : argv[index + 1];
};
const arg = (name) => argv.includes(name);
const list = (name) => argv.reduce((acc, arg, i) => (arg === name ? [...acc, argv[i + 1]] : acc), []);

const tag = flag('--tag', 'flow');
const outDir = path.resolve(ROOT, flag('--out', path.join('qa-evidence', 'ui', tag)));
const port = Number(flag('--port', '8174'));
const viewports = list('--viewport').length ? list('--viewport') : ['1280x720', '390x844'];
const worldTimeout = Number(flag('--world-timeout', '180000'));

if (!fs.existsSync(path.join(LIB_DIR, 'libnss3.so'))) {
  const archive = path.join(
    path.dirname(fileURLToPath(import.meta.resolve('@sparticuz/chromium'))),
    '..',
    'bin',
    'al2023.tar.br',
  );
  fs.mkdirSync(path.dirname(LIB_DIR), { recursive: true });
  const tar = path.join(CACHE, 'al2023.tar');
  fs.writeFileSync(tar, zlib.brotliDecompressSync(fs.readFileSync(archive)));
  execFileSync('tar', ['-xf', tar, '-C', path.dirname(LIB_DIR)]);
  fs.rmSync(tar);
}

const chromium = (await import('@sparticuz/chromium')).default;
const puppeteer = (await import('puppeteer-core')).default;

const server = spawn('python3', ['-m', 'http.server', String(port), '--bind', '127.0.0.1'], {
  cwd: ROOT,
  stdio: 'ignore',
});
await new Promise((resolve) => setTimeout(resolve, 900));

const browser = await puppeteer.launch({
  executablePath: await chromium.executablePath(),
  args: [...chromium.args, '--no-sandbox', '--disable-dev-shm-usage', '--enable-unsafe-swiftshader'],
  headless: true,
  protocolTimeout: 600000,
  env: {
    ...process.env,
    LD_LIBRARY_PATH: [LIB_DIR, process.env.LIBRARY_PATH_EXTRA, process.env.LD_LIBRARY_PATH].filter(Boolean).join(':'),
  },
});

fs.mkdirSync(outDir, { recursive: true });
const steps = [];
let failures = 0;

for (const viewport of viewports) {
  const [width, height] = viewport.split('x').map(Number);
  const page = await browser.newPage();
  const consoleErrors = [];
  const consoleLines = [];
  page.on('pageerror', (error) => consoleErrors.push(String(error).split('\n')[0]));
  page.on('console', (message) => {
    const text = message.text();
    consoleLines.push(`${message.type()}: ${text.slice(0, 240)}`);
    if (message.type() === 'error') consoleErrors.push(text.slice(0, 240));
  });
  // A narrow viewport alone is not a phone: without touch emulation the engine
  // correctly shows its desktop HUD, and a "portrait" frame would then be
  // evidence for a layout no phone ever gets. Same rule as tools/web_qa.mjs.
  const touchDevice = arg('--touch') || Math.min(width, height) < 600;
  await page.setViewport({ width, height, deviceScaleFactor: 1, hasTouch: touchDevice, isMobile: touchDevice });

  const shoot = async (name, expectScreen) => {
    const file = path.join(outDir, `${name}-${viewport}.png`);
    await page.screenshot({ path: file });
    const stats = readPng(file);
    const active = await page.evaluate(() => document.body.dataset.screen);
    const okScreen = !expectScreen || active === expectScreen;
    const blank = stats.lumaStdDev < 3;
    if (!okScreen || blank) failures += 1;
    steps.push({
      step: name,
      viewport,
      file: path.relative(ROOT, file),
      expectedScreen: expectScreen ?? null,
      activeScreen: active ?? null,
      blank,
      ok: okScreen && !blank,
      ...stats,
    });
    console.log(
      `${name.padEnd(16)} ${viewport.padEnd(9)} ${String(active || 'world').padEnd(9)} mean ${stats.lumaMean
        .toFixed(1)
        .padStart(5)} sd ${stats.lumaStdDev.toFixed(1).padStart(5)} colors ${String(stats.uniqueColors).padStart(
        5,
      )} ${okScreen && !blank ? 'ok' : 'FAIL'}`,
    );
  };

  await page.goto(`http://127.0.0.1:${port}/index.html`, { waitUntil: 'domcontentloaded' });
  await page.waitForFunction(
    () => !document.getElementById('opening-enter').disabled,
    { timeout: 30000 },
  );
  await settled(page);
  await shoot('01-opening', 'opening');

  await page.click('#opening-enter');
  await page.waitForFunction(() => document.body.dataset.screen === 'hub', { timeout: 10000 });
  await settled(page);
  await shoot('02-hub', 'hub');

  await page.click('#hub-controls');
  await page.waitForFunction(() => document.body.dataset.screen === 'settings', { timeout: 10000 });
  await settled(page);
  await shoot('03-settings', 'settings');
  await page.click('#settings-close');
  await page.waitForFunction(() => document.body.dataset.screen === 'hub', { timeout: 10000 });

  await page.click('#hub-deploy');
  await page.waitForFunction(() => document.body.dataset.screen === 'launch', { timeout: 10000 });
  // Mid-load, with real byte progress if the engine has reported any.
  await page
    .waitForFunction(() => document.getElementById('launch-percent').textContent !== '—', { timeout: 90000 })
    .catch(() => {});
  await settled(page);
  await shoot('04-launch', 'launch');

  // The engine takes over: the shell hides itself and the canvas becomes visible.
  await page.waitForFunction(() => document.body.dataset.mode === 'playing', { timeout: worldTimeout });
  await new Promise((resolve) => setTimeout(resolve, 2500));
  await shoot('05-world', null);

  const centre = { x: Math.round(width / 2), y: Math.round(height / 2) };
  await page.mouse.click(centre.x, centre.y);
  await page.keyboard.down('KeyW');
  await new Promise((resolve) => setTimeout(resolve, 1200));
  await page.keyboard.up('KeyW');
  await new Promise((resolve) => setTimeout(resolve, 800));
  await shoot('06-gameplay', null);

  steps[steps.length - 1].consoleErrors = consoleErrors.slice(0, 12);
  steps[steps.length - 1].console = consoleLines.slice(-25);
  if (consoleErrors.length) failures += 1;
  await page.close();
}

fs.writeFileSync(
  path.join(outDir, 'manifest.json'),
  JSON.stringify(
    {
      tag,
      viewports,
      entry: 'index.html',
      steps,
      failures,
      generatedAt: new Date().toISOString(),
    },
    null,
    2,
  ) + '\n',
);

await browser.close();
server.kill();
console.log(`wrote ${steps.length} frames to ${path.relative(ROOT, outDir)} (${failures} failed)`);
process.exit(failures === 0 ? 0 : 1);

async function settled(page) {
  await page.evaluate(
    () => new Promise((resolve) => requestAnimationFrame(() => requestAnimationFrame(() => setTimeout(resolve, 220)))),
  );
}

function readPng(file) {
  const buffer = fs.readFileSync(file);
  const idat = [];
  let width = 0;
  let height = 0;
  let colorType = 6;
  let offset = 8;
  while (offset < buffer.length) {
    const length = buffer.readUInt32BE(offset);
    const type = buffer.toString('ascii', offset + 4, offset + 8);
    const data = buffer.subarray(offset + 8, offset + 8 + length);
    if (type === 'IHDR') {
      width = data.readUInt32BE(0);
      height = data.readUInt32BE(4);
      colorType = data[9];
    } else if (type === 'IDAT') {
      idat.push(data);
    }
    offset += 12 + length;
    if (type === 'IEND') break;
  }
  const channels = { 0: 1, 2: 3, 4: 2, 6: 4 }[colorType] ?? 4;
  const stride = width * channels;
  const raw = zlib.inflateSync(Buffer.concat(idat));
  const pixels = Buffer.alloc(stride * height);
  let position = 0;
  for (let y = 0; y < height; y += 1) {
    const filter = raw[position++];
    const row = raw.subarray(position, position + stride);
    position += stride;
    const previous = y > 0 ? pixels.subarray((y - 1) * stride, y * stride) : Buffer.alloc(stride);
    const target = pixels.subarray(y * stride, (y + 1) * stride);
    for (let x = 0; x < stride; x += 1) {
      const left = x >= channels ? target[x - channels] : 0;
      const up = previous[x];
      const upLeft = x >= channels ? previous[x - channels] : 0;
      let value = row[x];
      if (filter === 1) value += left;
      else if (filter === 2) value += up;
      else if (filter === 3) value += (left + up) >> 1;
      else if (filter === 4) {
        const p = left + up - upLeft;
        const pa = Math.abs(p - left);
        const pb = Math.abs(p - up);
        const pc = Math.abs(p - upLeft);
        value += pa <= pb && pa <= pc ? left : pb <= pc ? up : upLeft;
      }
      target[x] = value & 0xff;
    }
  }
  let sum = 0;
  let sumSquares = 0;
  const colors = new Set();
  const total = width * height;
  for (let index = 0; index < total; index += 1) {
    const base = index * channels;
    const r = pixels[base];
    const g = channels >= 3 ? pixels[base + 1] : r;
    const b = channels >= 3 ? pixels[base + 2] : r;
    const luma = 0.2126 * r + 0.7152 * g + 0.0722 * b;
    sum += luma;
    sumSquares += luma * luma;
    if (colors.size < 20000) colors.add((r >> 2) * 4096 + (g >> 2) * 64 + (b >> 2));
  }
  const mean = sum / total;
  return {
    width,
    height,
    bytes: buffer.length,
    lumaMean: mean,
    lumaStdDev: Math.sqrt(Math.max(0, sumSquares / total - mean * mean)),
    uniqueColors: colors.size,
  };
}
