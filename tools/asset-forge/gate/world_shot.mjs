#!/usr/bin/env node
/**
 * world_shot.mjs — render the assembled world and (optionally) export it.
 *
 * The per-asset gate proves every prop on its own. This proves the *world*: it
 * loads `world.html` in the same pinned Chromium, waits for the real build, then
 * captures a review photograph from each authored camera and writes a single
 * GLB the whole thing can be inspected in.
 *
 *   node tools/asset-forge/gate/world_shot.mjs                 # 2048², all shots
 *   node tools/asset-forge/gate/world_shot.mjs --tex 4096
 *   node tools/asset-forge/gate/world_shot.mjs --shot arena,boss
 *   node tools/asset-forge/gate/world_shot.mjs --no-glb
 *
 * Outputs
 *   tools/asset-forge/build/world/<shot>.png          review photographs
 *   tools/asset-forge/build/world/world.glb           full world, embedded maps
 *   tools/asset-forge/build/world/world-report.json   what was measured
 */
import fs from 'node:fs';
import path from 'node:path';
import zlib from 'node:zlib';
import { execFileSync, spawn } from 'node:child_process';
import { fileURLToPath } from 'node:url';

const HERE = path.dirname(fileURLToPath(import.meta.url));
const ROOT = path.resolve(HERE, '..', '..', '..');
const FORGE = path.join(ROOT, 'tools', 'asset-forge');
const OUT = path.join(FORGE, 'build', 'world');
const CACHE = path.join(ROOT, 'tools', '.cache');
const LIB_DIR = path.join(CACHE, 'al2023-lib', 'lib');

const argv = process.argv.slice(2);
const flag = (name, fallback) => {
  const i = argv.indexOf(`--${name}`);
  return i === -1 ? fallback : (argv[i + 1] ?? true);
};
const has = (name) => argv.includes(`--${name}`);

const tex = String(flag('tex', '2048'));
const width = Number(flag('width', '2048'));
const height = Number(flag('height', '1152'));
const time = String(flag('t', '6'));
const wantGlb = !has('no-glb');
const shotsArg = flag('shot', null);
const SHOTS = shotsArg
  ? String(shotsArg).split(',').map((s) => s.trim()).filter(Boolean)
  : ['overview', 'arena', 'outpost', 'extraction', 'boss', 'perimeter', 'wilds', 'skyline'];

fs.mkdirSync(OUT, { recursive: true });

/* ------------------------------------------------------- chromium + server -- */

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

const port = Number(flag('port', '8163'));
const server = spawn('python3', ['-m', 'http.server', String(port), '--bind', '127.0.0.1'], { cwd: ROOT, stdio: 'ignore' });
await new Promise((r) => setTimeout(r, 900));

const browser = await puppeteer.launch({
  executablePath: await chromium.executablePath(),
  args: [...chromium.args, '--no-sandbox', '--disable-dev-shm-usage', '--enable-unsafe-swiftshader'],
  headless: true,
  protocolTimeout: 900000,
  env: { ...process.env, LD_LIBRARY_PATH: [LIB_DIR, process.env.LIBRARY_PATH, process.env.LD_LIBRARY_PATH].filter(Boolean).join(':') },
});

const page = await browser.newPage();
await page.setViewport({ width, height, deviceScaleFactor: 1 });
page.on('pageerror', (e) => console.error('  pageerror:', e.message));
page.on('console', (m) => { if (m.type() === 'error') console.error('  console:', m.text()); });

const t0 = Date.now();
await page.goto(`http://127.0.0.1:${port}/tools/asset-forge/world.html?capture=1&tex=${tex}&t=${time}&shot=overview`, {
  waitUntil: 'domcontentloaded',
  timeout: 180000,
});
await page.waitForFunction(() => window.__ready === true, { timeout: 240000 });
const loadMs = Date.now() - t0;

const report = await page.evaluate(() => window.__world.worldInfo());
console.log(`world: ${report.stats.instances} instances · ${report.stats.triangles.toLocaleString('en-US')} tris · ${report.stats.clips} clips · ${tex}² textures · built in ${loadMs} ms`);

/* -------------------------------------------------------------- photographs -- */

const rendered = [];
for (const shot of SHOTS) {
  await page.evaluate((s, t) => { window.__world.setShot(s); window.__world.seek(t); }, shot, Number(time));
  // Two frames: the first uploads the new 2K texture pages, the second is clean.
  await page.evaluate(() => new Promise((r) => requestAnimationFrame(() => requestAnimationFrame(r))));
  const file = path.join(OUT, `${shot}.png`);
  await page.screenshot({ path: file, type: 'png' });
  const bytes = fs.statSync(file).size;
  rendered.push({ shot, file: path.relative(ROOT, file), bytes });
  console.log(`  ${shot.padEnd(11)} ${(bytes / 1024).toFixed(0)} KB`);
}

/* -------------------------------------------------------------------- GLB -- */

let glb = null;
if (wantGlb) {
  const base64 = await page.evaluate(async () => {
    const bytes = await window.__world.exportGLB();
    let binary = '';
    const chunk = 0x8000;
    for (let i = 0; i < bytes.length; i += chunk) {
      binary += String.fromCharCode.apply(null, bytes.subarray(i, i + chunk));
    }
    return btoa(binary);
  });
  const buffer = Buffer.from(base64, 'base64');
  const file = path.join(OUT, 'world.glb');
  fs.writeFileSync(file, buffer);
  glb = { file: path.relative(ROOT, file), bytes: buffer.length, megabytes: +(buffer.length / 1048576).toFixed(2) };
  console.log(`  world.glb   ${glb.megabytes} MB`);
}

const out = {
  generated: new Date().toISOString(),
  textureSize: Number(tex),
  viewport: [width, height],
  seekSeconds: Number(time),
  buildMs: loadMs,
  world: report,
  renders: rendered,
  glb,
};
fs.writeFileSync(path.join(OUT, 'world-report.json'), `${JSON.stringify(out, null, 2)}\n`);
console.log(`report → ${path.relative(ROOT, path.join(OUT, 'world-report.json'))}`);

await browser.close();
server.kill();
