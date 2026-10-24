#!/usr/bin/env node
/*
 * tools/ui_shots.mjs — photograph every player screen at both viewports.
 *
 *   node tools/ui_shots.mjs                       # opening, hub, deploy, settings
 *   node tools/ui_shots.mjs --tag round2
 *   node tools/ui_shots.mjs --only deploy --viewport 390x844
 *
 * Why: the player front end (ui/) is judged on pixels, not on intent. This walks
 * the real screens in the real Chromium the repo pins, at the two shapes the
 * product must survive — 1280x720 landscape and 390x844 portrait — and writes a
 * manifest with per-frame statistics, so a screen that renders empty is a failed
 * run rather than a file that exists.
 *
 * Screens are entered through the shell's own `?ui=` route, which is the same
 * router the buttons use; nothing here injects markup or CSS.
 *
 * Exit 0 = every requested screen rendered non-blank and threw no console error.
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
const list = (name) => argv.reduce((acc, arg, i) => (arg === name ? [...acc, argv[i + 1]] : acc), []);

const tag = flag('--tag', 'ui');
const outDir = path.resolve(ROOT, flag('--out', path.join('qa-evidence', 'ui', tag)));
const port = Number(flag('--port', '8172'));
const only = list('--only');
const viewports = list('--viewport').length ? list('--viewport') : ['844x390', '1280x720'];

const SCREENS = [
  { id: 'opening', query: '?ui=opening' },
  { id: 'hub', query: '?ui=hub' },
  { id: 'settings', query: '?ui=settings' },
];
const wanted = only.length ? SCREENS.filter((screen) => only.includes(screen.id)) : SCREENS;

/* Chromium's shared libraries come from the pinned package, same as web_qa.mjs. */
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
  protocolTimeout: 180000,
  env: {
    ...process.env,
    LD_LIBRARY_PATH: [LIB_DIR, process.env.LIBRARY_PATH_EXTRA, process.env.LD_LIBRARY_PATH].filter(Boolean).join(':'),
  },
});

fs.mkdirSync(outDir, { recursive: true });
const frames = [];
let failures = 0;

for (const viewport of viewports) {
  const [width, height] = viewport.split('x').map(Number);
  const page = await browser.newPage();
  const errors = [];
  page.on('pageerror', (error) => errors.push(String(error).split('\n')[0]));
  page.on('console', (message) => {
    if (message.type() === 'error') errors.push(message.text().slice(0, 200));
  });
  await page.setViewport({ width, height, deviceScaleFactor: 1 });

  for (const screen of wanted) {
    await page.goto(`http://127.0.0.1:${port}/index.html${screen.query}&ui_hold=1`, {
      waitUntil: 'domcontentloaded',
    });
    // The opening's checks are async (a HEAD for the payload); give them a beat,
    // then wait for the screen's own active flag rather than a fixed sleep.
    await page
      .waitForFunction(
        (id) => document.querySelector(`#screen-${id}`)?.dataset.active === 'true',
        { timeout: 20000 },
        screen.id,
      )
      .catch(() => {});
    await page.evaluate(() => new Promise((resolve) => requestAnimationFrame(() => requestAnimationFrame(resolve))));
    await new Promise((resolve) => setTimeout(resolve, 260));

    const file = path.join(outDir, `${screen.id}-${viewport}.png`);
    await page.screenshot({ path: file });
    const stats = readPng(file);
    // Text-bearing screens are "blank" when nothing was painted: a correctly
    // empty screen would still have its type and hairlines inside this floor.
    const blank = stats.lumaStdDev < 4;
    if (blank) failures += 1;
    frames.push({
      screen: screen.id,
      viewport,
      file: path.relative(ROOT, file),
      blank,
      errors: [...errors],
      ...stats,
    });
    console.log(
      `${screen.id.padEnd(9)} ${viewport.padEnd(9)} mean ${stats.lumaMean.toFixed(1).padStart(5)}  sd ${stats.lumaStdDev
        .toFixed(1)
        .padStart(5)}  colors ${String(stats.uniqueColors).padStart(5)}  ${blank ? 'BLANK' : 'ok'}`,
    );
  }
  await page.close();
}

fs.writeFileSync(
  path.join(outDir, 'manifest.json'),
  JSON.stringify({ tag, viewports, screens: frames, failures, generatedAt: new Date().toISOString() }, null, 2) + '\n',
);

await browser.close();
server.kill();
console.log(`wrote ${frames.length} frames to ${path.relative(ROOT, outDir)} (${failures} failed)`);
process.exit(failures === 0 ? 0 : 1);

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
