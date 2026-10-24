#!/usr/bin/env node
/*
 * tools/render/pose_shot.mjs — offline pose screenshots of the hero rig.
 *
 * The shipped hero is now authored in Blender on CI; this sandbox has no
 * Blender viewport or GPU. These software-rendered browser frames allow human
 * inspection of the exported motion poses. This starts pinned Chromium
 * (SwiftShader), serves the repo, loads
 * hero.glb + rifle.glb in three.js, repeats the same weapon attachment the game
 * does (hand bone + hero_rig.json), and writes PNGs.
 *
 * Usage:
 *   node tools/render/pose_shot.mjs                 # default contact sheet
 *   node tools/render/pose_shot.mjs --clip aim --time 0.4 --az 35 --el 8 --dist 3
 *   node tools/render/pose_shot.mjs --out exports/render
 *
 * Exit code 0 = every requested frame rendered; 1 = the page reported an error.
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
const has = (name) => argv.includes(name);

const HERO = '/game/assets/characters/hero/hero.glb';
const RIFLE = '/game/assets/weapons/futuristic_rifle/rifle.glb';
const RIG = '/game/assets/characters/hero/hero_rig.json';
const outDir = path.resolve(ROOT, flag('--out', 'exports/render'));
const viewport = { width: Number(flag('--width', '900')), height: Number(flag('--height', '900')) };
const height = Number(flag('--height-scale', '1.78'));

const shots = has('--clip')
  ? [
      {
        name: flag('--name', `pose-${flag('--clip')}`),
        clip: flag('--clip'),
        time: Number(flag('--time', '0')),
        az: Number(flag('--az', '35')),
        el: Number(flag('--el', '8')),
        dist: Number(flag('--dist', '3')),
        targetY: Number(flag('--target-y', '0.95')),
        weapon: !has('--no-weapon'),
      },
    ]
  : [
      { name: 'aim-front', clip: 'aim', time: 0.0, az: 0, el: 6, dist: 3.0, targetY: 0.95 },
      { name: 'aim-side', clip: 'aim', time: 0.0, az: 90, el: 6, dist: 3.0, targetY: 0.95 },
      { name: 'aim-three-quarter', clip: 'aim', time: 0.5, az: 35, el: 10, dist: 3.0, targetY: 0.95 },
      { name: 'idle-front', clip: 'idle', time: 0.0, az: 0, el: 6, dist: 3.0, targetY: 0.95 },
      { name: 'run-side', clip: 'run', time: 0.3, az: 90, el: 6, dist: 3.0, targetY: 0.95 },
      { name: 'walk-side', clip: 'walk', time: 0.4, az: 90, el: 6, dist: 3.0, targetY: 0.95 },
      { name: 'fire-peak', clip: 'fire', time: 0.07, az: 35, el: 10, dist: 3.0, targetY: 0.95 },
      { name: 'aim-walk-side', clip: 'aim_walk', time: 0.4, az: 90, el: 6, dist: 3.0, targetY: 0.95 },
      { name: 'aim-run-quarter', clip: 'aim_run', time: 0.3, az: 35, el: 8, dist: 3.0, targetY: 0.95 },
      { name: 'reload-handling', clip: 'reload', time: 0.55, az: 35, el: 6, dist: 2.6, targetY: 0.95 },
      { name: 'hit-peak', clip: 'hit', time: 0.13, az: 35, el: 6, dist: 3.0, targetY: 0.95 },
      { name: 'death-settle', clip: 'death', time: 1.2, az: 35, el: 6, dist: 3.0, targetY: 0.95 },
      { name: 'aim-close', clip: 'aim', time: 0.0, az: 28, el: 4, dist: 1.5, targetY: 1.05 },
    ];

/* ---------- chromium + libs (same recipe as tools/web_qa.mjs) ---------- */
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

const port = Number(flag('--port', '8137'));
const server = spawn('python3', ['-m', 'http.server', String(port), '--bind', '127.0.0.1'], {
  cwd: ROOT,
  stdio: 'ignore',
});
const baseUrl = `http://127.0.0.1:${port}`;
await new Promise((r) => setTimeout(r, 800));

fs.mkdirSync(outDir, { recursive: true });

const browser = await puppeteer.launch({
  executablePath: await chromium.executablePath(),
  args: [...chromium.args, '--no-sandbox', '--disable-dev-shm-usage', '--enable-unsafe-swiftshader'],
  headless: true,
  protocolTimeout: 300000,
  env: { ...process.env, LD_LIBRARY_PATH: [LIB_DIR, process.env.LD_LIBRARY_PATH].filter(Boolean).join(':') },
});

const page = await browser.newPage();
await page.setViewport(viewport);
const errors = [];
page.on('pageerror', (e) => errors.push(String(e)));
page.on('console', (m) => {
  if (m.type() === 'error') errors.push(m.text());
});

await page.goto(`${baseUrl}/tools/render/pose_viewer.html`, { waitUntil: 'domcontentloaded' });
await page.evaluate(
  (opts) => window.setup(opts),
  { heroUrl: HERO, weaponUrl: RIFLE, rigUrl: RIG, height },
);
await page.waitForFunction(() => window.__ready || window.__error, { timeout: 180000 });
const setupError = await page.evaluate(() => window.__error);
if (setupError) {
  console.error('SETUP FAILED: ' + setupError);
  await browser.close();
  server.kill();
  process.exit(1);
}
const clips = await page.evaluate(() => window.__clips);
console.log(`clips in hero.glb: ${clips.join(', ')}`);

const report = [];
for (const shot of shots) {
  await page.evaluate(
    (s) => {
      window.setPose(s.clip, s.time, s.weapon);
      window.setCamera(s.az, s.el, s.dist, s.targetY);
    },
    shot,
  );
  // two animation frames plus a short settle: SwiftShader is slow but stable
  await new Promise((r) => setTimeout(r, 900));
  const file = path.join(outDir, `${shot.name}.png`);
  await page.screenshot({ path: file });
  const measured = await page.evaluate(() => window.measure());
  report.push({ shot: shot.name, clip: shot.clip, time: shot.time, file: path.relative(ROOT, file), measured });
  console.log(
    `${shot.name.padEnd(18)} clip=${shot.clip}@${shot.time}s ` +
      `hand=${measured?.hand?.map((v) => v.toFixed(3)).join(',')} ` +
      `muzzle=${measured?.muzzle?.map((v) => v.toFixed(3)).join(',')}`,
  );
}

fs.writeFileSync(
  path.join(outDir, 'render-report.json'),
  JSON.stringify({ hero: HERO, rifle: RIFLE, height, clips, shots: report, errors }, null, 2) + '\n',
);

await browser.close();
server.kill();
if (errors.length) {
  console.error('page errors:');
  for (const e of errors) console.error('  ' + e);
  process.exit(1);
}
console.log(`wrote ${shots.length} frames to ${path.relative(ROOT, outDir)}`);
