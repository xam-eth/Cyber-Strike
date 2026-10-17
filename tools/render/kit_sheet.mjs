#!/usr/bin/env node
/*
 * tools/render/kit_sheet.mjs — thumbnail every model in a local asset pack.
 *
 * Why: choosing a model for a spot in the level by reading its file name is how
 * you end up with a wind turbine where a wall should be. This renders each GLTF
 * at a fixed framing through headless Chromium (SwiftShader), so the layout can
 * be decided by looking at the actual geometry.
 *
 *   node tools/render/kit_sheet.mjs --dir game/assets/world/kaykit_space_base_bits/gltf
 *   node tools/render/kit_sheet.mjs --out exports/kit-sheet --size 360
 *
 * Writes <out>/<model>.png plus <out>/sheet.json (bounds per model).
 */
import fs from 'node:fs';
import path from 'node:path';
import zlib from 'node:zlib';
import { execFileSync, spawn } from 'node:child_process';
import { fileURLToPath } from 'node:url';

const ROOT = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '..', '..');
const CACHE = path.join(ROOT, 'tools', '.cache');
const LIB_DIR = path.join(CACHE, 'al2023-lib', 'lib');

const argv = process.argv.slice(2);
const flag = (name, def) => {
  const i = argv.indexOf(name);
  return i === -1 ? def : argv[i + 1];
};

const assetDir = flag('--dir', 'game/assets/world/kaykit_space_base_bits/gltf');
const outDir = path.resolve(ROOT, flag('--out', 'exports/kit-sheet'));
const size = Number(flag('--size', '320'));
const only = flag('--only', '');

// .gltf and .glb behave the same through GLTFLoader; the uploaded SciFi pack
// arrives as GLB, so both extensions are accepted.
const models = fs
  .readdirSync(path.join(ROOT, assetDir))
  .filter((f) => f.endsWith('.gltf') || f.endsWith('.glb'))
  .filter((f) => !only || only.split(',').includes(path.basename(f).replace(/\.gl[b]?tf?$/, '')))
  .map((f) => ({ name: path.basename(f).replace(/\.gl[b]?tf?$/, ''), file: f }))
  .sort();
if (!models.length) {
  console.error('no .gltf files found in ' + assetDir);
  process.exit(2);
}

const chromium = (await import('@sparticuz/chromium')).default;
const puppeteer = (await import('puppeteer-core')).default;

if (!fs.existsSync(path.join(LIB_DIR, 'libnss3.so'))) {
  const br = path.join(
    path.dirname(fileURLToPath(import.meta.resolve('@sparticuz/chromium'))),
    '..',
    'bin',
    'al2023.tar.br',
  );
  fs.mkdirSync(path.dirname(LIB_DIR), { recursive: true });
  const tar = path.join(CACHE, 'al2023.tar');
  fs.writeFileSync(tar, zlib.brotliDecompressSync(fs.readFileSync(br)));
  execFileSync('tar', ['-xf', tar, '-C', path.dirname(LIB_DIR)]);
  fs.rmSync(tar);
}

const port = Number(flag('--port', '8138'));
const server = spawn('python3', ['-m', 'http.server', String(port), '--bind', '127.0.0.1'], {
  cwd: ROOT,
  stdio: 'ignore',
});
await new Promise((r) => setTimeout(r, 800));
fs.mkdirSync(outDir, { recursive: true });

const browser = await puppeteer.launch({
  executablePath: await chromium.executablePath(),
  args: [...chromium.args, '--no-sandbox', '--disable-dev-shm-usage', '--enable-unsafe-swiftshader'],
  headless: true,
  protocolTimeout: 300000,
  env: { ...process.env, LD_LIBRARY_PATH: [LIB_DIR, process.env.LIBRARY_PATH_EXTRA, process.env.LD_LIBRARY_PATH].filter(Boolean).join(':') },
});
const page = await browser.newPage();
await page.setViewport({ width: size, height: size });
await page.goto(`http://127.0.0.1:${port}/tools/render/kit_viewer.html`, { waitUntil: 'domcontentloaded' });

const report = {};
for (const entry of models) {
  const model = entry.name;
  const url = `/${assetDir}/${entry.file}`;
  await page.evaluate((u) => { window.__ready = false; return window.showModel(u); }, url);
  await page.waitForFunction(() => window.__ready || window.__error, { timeout: 60000 });
  const error = await page.evaluate(() => window.__error);
  if (error) {
    console.error(`${model}: ${error}`);
    continue;
  }
  const info = await page.evaluate(() => window.__info);
  await page.screenshot({ path: path.join(outDir, `${model}.png`) });
  report[model] = info;
  console.log(`${model.padEnd(30)} size ${info.size.map((v) => v.toFixed(2)).join(' x ')}`);
}

fs.writeFileSync(path.join(outDir, 'sheet.json'), JSON.stringify(report, null, 2) + '\n');
await browser.close();
server.kill();
console.log(`wrote ${Object.keys(report).length}/${models.length} thumbnails to ${path.relative(ROOT, outDir)}`);
