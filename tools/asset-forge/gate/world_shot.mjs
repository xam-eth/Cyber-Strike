#!/usr/bin/env node
/**
 * world_shot.mjs — render every mission world and export it.
 *
 * For each world in `src/worlds/index.js` this loads `world.html`, waits for the
 * real build, enforces the asset policy, photographs each authored camera and
 * writes one self-contained GLB. The worlds are rendered in the same pinned
 * Chromium, one page per world, so nothing leaks between them.
 *
 *   node tools/asset-forge/gate/world_shot.mjs                    # all three worlds
 *   node tools/asset-forge/gate/world_shot.mjs --world frostline
 *   node tools/asset-forge/gate/world_shot.mjs --world verdant --shot overview,shrine
 *   node tools/asset-forge/gate/world_shot.mjs --no-glb
 *
 * Outputs
 *   tools/asset-forge/build/worlds/<id>/<shot>.png   review photographs
 *   tools/asset-forge/build/worlds/<id>/world.glb    the whole world, embedded maps
 *   tools/asset-forge/build/worlds/worlds-report.json
 */
import fs from 'node:fs';
import path from 'node:path';
import zlib from 'node:zlib';
import { execFileSync, spawn } from 'node:child_process';
import { fileURLToPath } from 'node:url';

const HERE = path.dirname(fileURLToPath(import.meta.url));
const ROOT = path.resolve(HERE, '..', '..', '..');
const FORGE = path.join(ROOT, 'tools', 'asset-forge');
const OUT_ROOT = path.join(FORGE, 'build', 'worlds');
const CACHE = path.join(ROOT, 'tools', '.cache');
const LIB_DIR = path.join(CACHE, 'al2023-lib', 'lib');

const argv = process.argv.slice(2);
const flag = (name, fallback) => {
  const i = argv.indexOf(`--${name}`);
  return i === -1 ? fallback : (argv[i + 1] ?? true);
};
const has = (name) => argv.includes(`--${name}`);

const width = Number(flag('width', '2048'));
const height = Number(flag('height', '1152'));
const time = String(flag('t', '6'));
const wantGlb = !has('no-glb');
const ALL_WORLDS = ['frostline', 'verdant', 'emberfall', 'titans'];
const worldIds = flag('world', null) ? String(flag('world')).split(',').map((s) => s.trim()) : ALL_WORLDS;
const shotFilter = flag('shot', null);
const SHOTS = shotFilter ? String(shotFilter).split(',').map((s) => s.trim()) : null;

fs.mkdirSync(OUT_ROOT, { recursive: true });

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

const report = {
  generated: new Date().toISOString(),
  viewport: [width, height],
  seekSeconds: Number(time),
  worlds: {},
};

let failed = false;

for (const worldId of worldIds) {
  const outDir = path.join(OUT_ROOT, worldId);
  fs.mkdirSync(outDir, { recursive: true });
  console.log(`\n== ${worldId}`);

  const page = await browser.newPage();
  await page.setViewport({ width, height, deviceScaleFactor: 1 });
  page.on('pageerror', (e) => console.error('  pageerror:', e.message));
  page.on('console', (m) => { if (m.type() === 'error') console.error('  console:', m.text()); else if (has('debug')) console.log('  log:', m.text().slice(0, 900)); });

  const t0 = Date.now();
  await page.goto(
    `http://127.0.0.1:${port}/tools/asset-forge/world.html?capture=1&world=${worldId}&t=${time}&shot=overview${has('debug') ? '&debug=1' : ''}${has('no-shadows') ? '&shadows=0' : ''}`,
    { waitUntil: 'domcontentloaded', timeout: 180000 },
  );
  await page.waitForFunction(() => window.__ready === true, { timeout: 300000 });
  const loadMs = Date.now() - t0;

  const info = await page.evaluate(() => window.__world.worldInfo());
  const availableShots = await page.evaluate(() => window.__world.shotNames);

  // Asset policy: one mesh without a real GLB behind it fails the whole run,
  // before a single picture is taken.
  const procedural = await page.evaluate(() => window.__world.proceduralMeshes());
  if (procedural.length) {
    console.error(`  FAIL asset policy — ${procedural.length} mesh(es) are not from a real GLB: ${procedural.slice(0, 5).join(', ')}`);
    failed = true;
  }

  const shots = (SHOTS ?? availableShots).filter((s) => availableShots.includes(s));
  if (!shots.length) {
    console.error(`  FAIL no valid shots for ${worldId} (have: ${availableShots.join(', ')})`);
    failed = true;
  }

  console.log(
    `  ${info.stats.roles} roles · ${info.stats.instances} instances · `
    + `${info.stats.triangles.toLocaleString('en-US')} tris · ${info.stats.clips} clips · `
    + `${info.stats.realFiles} real GLBs · built in ${loadMs} ms`,
  );

  const renders = [];
  for (const shot of shots) {
    await page.evaluate((s, t) => { window.__world.setShot(s); window.__world.seek(t); }, shot, Number(time));
    await page.evaluate(() => new Promise((r) => requestAnimationFrame(() => requestAnimationFrame(r))));
    const file = path.join(outDir, `${shot}.png`);
    await page.screenshot({ path: file, type: 'png' });
    const bytes = fs.statSync(file).size;
    renders.push({ shot, file: path.relative(ROOT, file), bytes });
    console.log(`  ${shot.padEnd(10)} ${(bytes / 1024).toFixed(0)} KB`);
  }

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
    const file = path.join(outDir, 'world.glb');
    fs.writeFileSync(file, buffer);
    glb = {
      file: path.relative(ROOT, file),
      bytes: buffer.length,
      megabytes: +(buffer.length / 1048576).toFixed(2),
    };
    console.log(`  world.glb  ${glb.megabytes} MB`);
  }

  report.worlds[worldId] = {
    id: info.id,
    meta: info.meta,
    stats: info.stats,
    bounds: info.bounds,
    buildMs: loadMs,
    renders,
    glb,
    assetPolicy: { ok: procedural.length === 0, offenders: procedural.slice(0, 10) },
  };

  await page.close();
}

fs.writeFileSync(path.join(OUT_ROOT, 'worlds-report.json'), `${JSON.stringify(report, null, 1)}\n`);
console.log(`\nreport → ${path.relative(ROOT, path.join(OUT_ROOT, 'worlds-report.json'))}`);

await browser.close();
server.kill();
if (failed) process.exit(1);
