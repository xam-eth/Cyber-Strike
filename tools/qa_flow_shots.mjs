#!/usr/bin/env node
/*
 * tools/qa_flow_shots.mjs — photograph the whole journey, once, repeatably.
 *
 *   node tools/qa_flow_shots.mjs --tag before
 *   node tools/qa_flow_shots.mjs --tag after --viewport 390x844
 *   node tools/qa_flow_shots.mjs --tag art --stages DASHBOARD,HERO,WEAPON,WORLD
 *   node tools/qa_flow_shots.mjs --tag play --stages GAMEPLAY,TOUR
 *
 * Why this exists: every review so far argued about a flow it had photographed
 * one screen at a time, so "is the product coherent?" was answered from memory
 * of five separate sessions. This walks the real stages the real journey uses
 * — BOOT -> LOADING -> CHAPTER -> DASHBOARD -> HERO -> WORLD -> gameplay —
 * from the committed payload in one run, at mobile and
 * desktop sizes, and writes a manifest with per-frame statistics.
 *
 * Stage entry is the existing `?qa_stage=` deep link (front_end.gd), i.e. the
 * same stages the journey builds, mounted through the same FrontEnd. It is not
 * a mock: the payload, the scenes and the scripts are the shipped ones.
 *
 * Two things this tool refuses to do, both learned the hard way
 * (docs/DECISIONS.md §12.3, docs/DECISIONS.md §3):
 *
 *  - it will not call a screenshot a "screen" without checking that the engine
 *    reached the stage it asked for (stage log line, or the gameplay marker);
 *  - it reports image statistics for every frame, so a blank capture is
 *    visible in the summary instead of being a file that exists.
 *
 * Exit code 0 = every requested stage was reached and rendered; 1 = otherwise.
 */
import fs from 'node:fs';
import path from 'node:path';
import zlib from 'node:zlib';
import crypto from 'node:crypto';
import { execFileSync, spawn } from 'node:child_process';
import { fileURLToPath } from 'node:url';

const ROOT = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '..');
const CACHE = path.join(ROOT, 'tools', '.cache');
const LIB_DIR = path.join(CACHE, 'al2023-lib', 'lib');

const argv = process.argv.slice(2);
const flag = (name, def) => {
  const i = argv.indexOf(name);
  return i === -1 ? def : argv[i + 1];
};
const has = (name) => argv.includes(name);
const list = (name) => argv.reduce((acc, arg, i) => (arg === name ? [...acc, argv[i + 1]] : acc), []);

const tag = flag('--tag', 'flow');
const outDir = path.resolve(ROOT, flag('--out', path.join('exports', 'flow', tag)));
const pageTarget = flag('--page', '/web/index.html');
// Which theatre to photograph. Passed straight through to the `?qa_world=` hook in
// front_end.gd, so a second world is captured from the shipped build like the first.
const worldId = flag('--world', '');
const worldQuery = worldId ? `&qa_world=${encodeURIComponent(worldId)}` : '';
const port = Number(flag('--port', '8133'));
const settleMs = Number(flag('--settle', '6000'));
const stageTimeoutMs = Number(flag('--stage-timeout', '240000'));
const serveDir = path.resolve(ROOT, flag('--serve', '.'));
/* Extra wait before a transient stage (BOOT, LOADING) is
 * photographed. Those three are shot the moment they announce themselves
 * because a web build leaves them in a frame or two -- which is right for a
 * splash and wrong for a film: the opening is 10 s long and the interesting
 * frame is inside it, not on its first. 0 by default, so every existing
 * capture behaves exactly as before. */
const transientDelayMs = Number(flag('--transient-delay', '0'));

const DEFAULT_STAGES = ['BOOT', 'LOADING', 'CHAPTER', 'DASHBOARD', 'HERO', 'WEAPON', 'WORLD'];
const requested = (list('--stages').join(',') || DEFAULT_STAGES.join(','))
  .split(',')
  .map((name) => name.trim().toUpperCase())
  .filter(Boolean);

const viewportArgs = list('--viewport');
const viewports = (viewportArgs.length ? viewportArgs : ['390x844', '1280x720']).map((spec) => {
  const [w, h] = spec.split('x').map(Number);
  return { spec, width: w || 390, height: h || 844 };
});

/* Chromium comes from the pinned packages in tools/package.json, extracted on
 * first use exactly as tools/web_qa.mjs does it. */
if (!fs.existsSync(path.join(LIB_DIR, 'libnss3.so'))) {
  const br = path.join(
    path.dirname(fileURLToPath(import.meta.resolve('@sparticuz/chromium'))),
    '..',
    'bin',
    'al2023.tar.br'
  );
  fs.mkdirSync(path.dirname(LIB_DIR), { recursive: true });
  const tar = path.join(CACHE, 'al2023.tar');
  fs.writeFileSync(tar, zlib.brotliDecompressSync(fs.readFileSync(br)));
  execFileSync('tar', ['-xf', tar, '-C', path.dirname(LIB_DIR)]);
  fs.rmSync(tar);
}

const chromium = (await import('@sparticuz/chromium')).default;
const puppeteer = (await import('puppeteer-core')).default;

const server = spawn('python3', ['-m', 'http.server', String(port), '--bind', '127.0.0.1'], {
  cwd: serveDir,
  stdio: 'ignore',
});
const baseUrl = `http://127.0.0.1:${port}`;
await new Promise((resolve) => setTimeout(resolve, 900));

fs.mkdirSync(outDir, { recursive: true });

const browser = await puppeteer.launch({
  executablePath: await chromium.executablePath(),
  args: [...chromium.args, '--no-sandbox', '--disable-dev-shm-usage'],
  headless: true,
  protocolTimeout: 300000,
  env: { ...process.env, LD_LIBRARY_PATH: [LIB_DIR, process.env.LD_LIBRARY_PATH].filter(Boolean).join(':') },
});

/* The engine prints one of these once it is up. Waiting for a fixed sleep
 * instead meant menu frames were captured long after the state they were
 * meant to show. */
const BOOT_MARKER = /FrontEnd:|Menu QA:|MenuLoading:|MenuCinematic:|Encounter:|Audio:/;

const rows = [];

async function openPage(viewport) {
  const page = await browser.newPage();
  await page.setViewport({
    width: viewport.width,
    height: viewport.height,
    hasTouch: Math.min(viewport.width, viewport.height) < 600,
    isMobile: Math.min(viewport.width, viewport.height) < 600,
    deviceScaleFactor: 1,
  });
  const lines = [];
  page.on('console', (message) => lines.push(String(message.text())));
  page.on('pageerror', (error) => lines.push(`PAGEERROR ${error.message}`));
  return { page, lines };
}

const TRANSIENT_STAGES = new Set(['BOOT', 'LOADING']);

/** The stage the front end moved on to after `stage`, or null. */
function laterStage(lines, stage) {
  const seen = lines.filter((line) => line.startsWith('FrontEnd: stage '));
  const index = seen.findIndex((line) => line === `FrontEnd: stage ${stage}`);
  if (index === -1 || index === seen.length - 1) return null;
  return seen[seen.length - 1].replace('FrontEnd: stage ', '');
}

async function waitFor(lines, predicate, timeoutMs, label) {
  const deadline = Date.now() + timeoutMs;
  while (Date.now() < deadline) {
    if (predicate(lines)) return true;
    await new Promise((resolve) => setTimeout(resolve, 250));
  }
  console.log(`  !! timed out waiting for ${label}`);
  return false;
}

async function shoot(page, viewport, name) {
  const file = path.join(outDir, `${name}-${viewport.spec}.png`);
  await page.screenshot({ path: file });
  return path.relative(ROOT, file);
}

/* ---------- menu / front-end stages: one page load per stage ---------- */
for (const viewport of viewports) {
  for (const stage of requested) {
    if (stage === 'GAMEPLAY' || stage === 'TOUR') continue;
    const { page, lines } = await openPage(viewport);
    // `qa_hold` keeps a stage that finishes in one frame -- the loading
    // screens -- on screen long enough to photograph. It is a QA deep-link
    // flag, inert in the real flow.
    const url = `${baseUrl}${pageTarget}?qa_stage=${stage}&qa_hold=1${worldQuery}`;
    await page.goto(url, { waitUntil: 'domcontentloaded', timeout: 120000 });
    await page.waitForFunction(() => document.querySelector('canvas') !== null, { timeout: 180000 });
    await waitFor(lines, (l) => l.some((line) => BOOT_MARKER.test(line)), stageTimeoutMs, `${stage} boot`);
    // The stage must announce itself. A deep link that silently lands on BOOT
    // would otherwise be photographed and filed as DASHBOARD.
    const reached = await waitFor(
      lines,
      (l) => l.some((line) => line.includes(`FrontEnd: stage ${stage}`)),
      stageTimeoutMs,
      `FrontEnd: stage ${stage}`
    );
    // BOOT and LOADING are *transient*: they advance themselves as
    // soon as their work finishes, which in a web build is immediately. The
    // settle delay used to be spent after they had already left, so the frame
    // filed as LOADING was a photograph of the ident -- the two looked
    // identical in the audit (docs/DECISIONS.md 4) for that reason.
    // Those three are photographed the moment they announce themselves; the
    // rest get the settle they need to finish laying out.
    const transient = TRANSIENT_STAGES.has(stage);
    let shot;
    if (transient) {
      if (transientDelayMs > 0) {
        await new Promise((resolve) => setTimeout(resolve, transientDelayMs));
      }
      // The stage has *announced* itself, which is one frame before it has
      // drawn anything: photographing immediately produced a 9 KB black frame.
      // So take the first frame that is not still blank, and stop trying the
      // moment the front end moves on -- then say so, rather than filing the
      // next stage under this name.
      for (let attempt = 0; attempt < 12; attempt += 1) {
        await new Promise((resolve) => setTimeout(resolve, 120));
        shot = await shoot(page, viewport, stage.toLowerCase());
        const size = fs.statSync(path.join(ROOT, shot)).size;
        if (size > 20000 || laterStage(lines, stage)) break;
      }
    } else {
      await new Promise((resolve) => setTimeout(resolve, settleMs));
      shot = await shoot(page, viewport, stage.toLowerCase());
    }
    const advancedTo = transient ? laterStage(lines, stage) : null;
    rows.push({
      stage,
      viewport: viewport.spec,
      shot,
      reached,
      advancedTo,
      lines: lines.slice(),
    });
    const note = advancedTo ? `  (advanced to ${advancedTo} before the shot)` : '';
    console.log(`  ${reached ? 'ok  ' : 'MISS'} ${stage.padEnd(10)} ${viewport.spec}${note}`);
    await page.close();
  }
}

/* ---------- gameplay: walk the real journey, then photograph ---------- */
for (const viewport of viewports) {
  const wantsPlay = requested.includes('GAMEPLAY') || requested.includes('TOUR');
  if (!wantsPlay) continue;
  const { page, lines } = await openPage(viewport);
  // The gameplay leg loads the page without `?qa_stage=`, so it needs the world
  // query in its own right: the earlier version dropped it here and photographed
  // the default theatre while reporting the requested one.
  const gameplayUrl = `${baseUrl}${pageTarget}${worldQuery ? `?${worldQuery.slice(1)}` : ''}`;
  await page.goto(gameplayUrl, { waitUntil: 'domcontentloaded', timeout: 120000 });
  await page.waitForFunction(() => document.querySelector('canvas') !== null, { timeout: 180000 });
  await waitFor(lines, (l) => l.some((line) => BOOT_MARKER.test(line)), stageTimeoutMs, 'boot');
  if (worldQuery) {
    await waitFor(
      lines,
      (l) => l.some((line) => line.includes('FrontEnd: qa_world selected')),
      stageTimeoutMs,
      'the requested world to be selected'
    );
  }

  const centre = await page.evaluate(() => {
    const canvas = document.querySelector('canvas');
    if (!canvas) return null;
    const rect = canvas.getBoundingClientRect();
    return { x: rect.x + rect.width / 2, y: rect.y + rect.height / 2 };
  });
  if (centre) await page.mouse.click(centre.x, centre.y);

  const inGameplay = () => lines.some((line) => line.includes('Encounter: Explore safe'));
  const deadline = Date.now() + stageTimeoutMs;
  while (Date.now() < deadline && !inGameplay()) {
    await page.keyboard.press('Enter');
    await new Promise((resolve) => setTimeout(resolve, 1200));
  }
  const reachedGameplay = inGameplay();
  await new Promise((resolve) => setTimeout(resolve, settleMs));
  const shot = await shoot(page, viewport, 'gameplay');
  rows.push({ stage: 'GAMEPLAY', viewport: viewport.spec, shot, reached: reachedGameplay, lines: lines.slice() });
  console.log(`  ${reachedGameplay ? 'ok  ' : 'MISS'} ${'GAMEPLAY'.padEnd(10)} ${viewport.spec}`);

  if (requested.includes('TOUR')) {
    // P, not F10: F10 never reaches the page (docs/DECISIONS.md §3.2).
    await page.keyboard.press('KeyP');
    await new Promise((resolve) => setTimeout(resolve, 900));
    const engaged = lines.some((line) => line.includes('World tour: review camera engaged'));
    // The station is reviewed from six vantages, the frontier from four; the
    // tour rig clamps to whichever list the selected theatre owns.
    const tourDigits = worldId === 'vanguard_station' ? 6 : 4;
    const tourKeys = Array.from({ length: tourDigits }, (_, i) => `Digit${i + 1}`);
    for (const key of tourKeys) {
      await page.keyboard.press(key);
      await new Promise((resolve) => setTimeout(resolve, 900));
      const tourShot = await shoot(page, viewport, `tour-${key.replace('Digit', '')}`);
      rows.push({
        stage: `TOUR_${key.replace('Digit', '')}`,
        viewport: viewport.spec,
        shot: tourShot,
        reached: engaged,
        lines: [],
      });
    }
    console.log(`  ${engaged ? 'ok  ' : 'MISS'} ${'TOUR'.padEnd(10)} ${viewport.spec}`);
  }
  await page.close();
}

await browser.close();
server.kill();

/* ---------- statistics: a file is not a picture ---------- */
const frames = rows.map((row) => row.shot);
let stats = [];
const python = path.join(ROOT, '.venv', 'bin', 'python');
if (fs.existsSync(python) && frames.length) {
  try {
    const raw = execFileSync(python, [path.join(ROOT, 'tools', 'image_stats.py'), '--json', ...frames], {
      encoding: 'utf8',
      maxBuffer: 32 * 1024 * 1024,
    });
    stats = JSON.parse(raw);
  } catch (error) {
    console.log(`  note: image statistics unavailable (${String(error.message).split('\n')[0]})`);
  }
} else {
  console.log(
    '  note: image statistics skipped -- no .venv/bin/python with Pillow, so no frame can be checked for being blank'
  );
}
const byFile = new Map(stats.map((row) => [row.file.replace(/\\/g, '/'), row]));
for (const row of rows) {
  const key = String(row.shot).replace(/\\/g, '/');
  const found = byFile.get(key) || byFile.get(path.join(ROOT, key)) || null;
  row.stats = found;
  row.md5 = fs.existsSync(path.join(ROOT, row.shot))
    ? crypto.createHash('md5').update(fs.readFileSync(path.join(ROOT, row.shot))).digest('hex')
    : null;
}

const manifest = {
  tag,
  generatedAt: new Date().toISOString(),
  payload: pageTarget,
  viewports: viewports.map((v) => v.spec),
  frames: rows.map(({ lines, ...rest }) => ({ ...rest, logLines: lines.slice(0, 40) })),
};
fs.writeFileSync(path.join(outDir, 'manifest.json'), JSON.stringify(manifest, null, 2));

/* ---------- summary ---------- */
console.log('\nstage      viewport   reached  mean    sd   cols  verdict');
console.log('-'.repeat(66));
let bad = 0;
let unmeasured = 0;
for (const row of rows) {
  const s = row.stats || {};
  const blank = s.blank === true;
  const measured = Object.keys(s).length > 0;
  if (!measured) unmeasured += 1;
  if (!row.reached || blank || !measured) bad += 1;
  const verdict = !row.reached
    ? 'NOT REACHED'
    : blank
      ? 'BLANK'
      : !measured
        ? 'NO STATS'
        : 'render';
  console.log(
    `${row.stage.padEnd(10)} ${row.viewport.padEnd(10)} ${String(row.reached).padEnd(8)} ` +
      `${String(s.mean ?? '-').padStart(5)} ${String(s.stddev ?? '-').padStart(5)} ` +
      `${String(s.distinct ?? '-').padStart(5)}  ${verdict}`
  );
}
console.log(`\n${rows.length} frame(s) in ${path.relative(ROOT, outDir)}/ — manifest.json has the log lines.`);
if (unmeasured) {
  console.log(
    `WARNING: ${unmeasured} frame(s) have no image statistics, so nothing checked whether they are blank. ` +
      'Install Pillow into .venv (tools/image_stats.py needs it) and re-run before using these as evidence.'
  );
}
if (bad) {
  console.log(`FAIL: ${bad} frame(s) were not reached, are blank, or could not be measured.`);
  process.exit(1);
}
console.log('PASS: every requested stage was reached and rendered.');
