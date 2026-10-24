#!/usr/bin/env node
/**
 * real_lib_sheet.mjs — look at the real asset libraries before composing with them.
 *
 * The world is built from real, licensed, pre-modelled GLB meshes. Choosing which
 * mesh goes where is an art decision, so this renders every candidate into one
 * contact sheet that can actually be inspected.
 *
 *   node tools/asset-forge/gate/real_lib_sheet.mjs --lib kenney
 *   node tools/asset-forge/gate/real_lib_sheet.mjs --lib kit
 *
 * Output: tools/asset-forge/build/real-lib-<lib>.png
 */
import fs from 'node:fs';
import path from 'node:path';
import zlib from 'node:zlib';
import { execFileSync, spawn } from 'node:child_process';
import { fileURLToPath } from 'node:url';

const HERE = path.dirname(fileURLToPath(import.meta.url));
const ROOT = path.resolve(HERE, '..', '..', '..');
const FORGE = path.join(ROOT, 'tools', 'asset-forge');
const BUILD = path.join(FORGE, 'build');
const CACHE = path.join(ROOT, 'tools', '.cache');
const LIB_DIR = path.join(CACHE, 'al2023-lib', 'lib');

const argv = process.argv.slice(2);
const flag = (name, fallback) => {
  const i = argv.indexOf(`--${name}`);
  return i === -1 ? fallback : (argv[i + 1] ?? true);
};

const lib = String(flag('lib', 'kenney'));
const cell = String(flag('cell', '200'));
const cols = String(flag('cols', '10'));

const LIBS = {
  kenney: {
    dir: 'game/assets/world/kenney_space_kit/models',
    column: 'Kenney Space Kit (CC0)',
  },
  kit: {
    dir: 'game/assets/world/scifi_starter_kit/models',
    column: '3D SciFi Starter Kit (free licence)',
  },
};

const spec = LIBS[lib];
if (!spec) throw new Error(`unknown library "${lib}" — use one of ${Object.keys(LIBS).join(', ')}`);

const dir = path.join(ROOT, spec.dir);
const items = fs.readdirSync(dir).filter((f) => f.endsWith('.glb')).sort().map((f) => ({
  id: f.replace(/\.glb$/, ''),
  url: `/${spec.dir}/${f}`,
}));

fs.mkdirSync(BUILD, { recursive: true });
fs.writeFileSync(path.join(BUILD, 'real-lib.json'), `${JSON.stringify({ library: lib, column: spec.column, items }, null, 1)}\n`);

if (!fs.existsSync(path.join(LIB_DIR, 'libnss3.so'))) {
  const br = path.join(path.dirname(fileURLToPath(import.meta.resolve('@sparticuz/chromium'))), '..', 'bin', 'al2023.tar.br');
  fs.mkdirSync(path.dirname(LIB_DIR), { recursive: true });
  const tar = path.join(CACHE, 'al2023.tar');
  fs.writeFileSync(tar, zlib.brotliDecompressSync(fs.readFileSync(br)));
  execFileSync('tar', ['-xf', tar, '-C', path.dirname(LIB_DIR)]);
  fs.rmSync(tar);
}
const chromium = (await import('@sparticuz/chromium')).default;
const puppeteer = (await import('puppeteer-core')).default;

const port = Number(flag('port', '8171'));
const server = spawn('python3', ['-m', 'http.server', String(port), '--bind', '127.0.0.1'], { cwd: ROOT, stdio: 'ignore' });
await new Promise((r) => setTimeout(r, 800));

const browser = await puppeteer.launch({
  executablePath: await chromium.executablePath(),
  args: [...chromium.args, '--no-sandbox', '--disable-dev-shm-usage', '--enable-unsafe-swiftshader'],
  headless: true,
  protocolTimeout: 600000,
  env: { ...process.env, LD_LIBRARY_PATH: [LIB_DIR, process.env.LD_LIBRARY_PATH].filter(Boolean).join(':') },
});
const page = await browser.newPage();
await page.setViewport({ width: 1400, height: 900 });
page.on('pageerror', (e) => console.error('  pageerror:', e.message));
await page.goto(`http://127.0.0.1:${port}/tools/asset-forge/real_lib.html?cell=${cell}&cols=${cols}`, { waitUntil: 'domcontentloaded' });
await page.waitForFunction(() => window.__sheetReady === true || window.__sheetError, { timeout: 300000 });
const error = await page.evaluate(() => window.__sheetError ?? null);
if (error) throw new Error(error);
const dataUrl = await page.evaluate(() => document.getElementById('sheet').toDataURL('image/png'));
const out = path.join(BUILD, `real-lib-${lib}.png`);
fs.writeFileSync(out, Buffer.from(dataUrl.split(',')[1], 'base64'));
console.log(`${items.length} models · ${spec.column}`);
console.log(`→ ${path.relative(ROOT, out)}`);
await browser.close();
server.kill();
