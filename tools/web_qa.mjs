#!/usr/bin/env node
/*
 * tools/web_qa.mjs — browser QA for the WebAssembly preview.
 *
 *   node tools/web_qa.mjs                      # serve the repo root, check both pages
 *   node tools/web_qa.mjs --json               # machine-readable report
 *   node tools/web_qa.mjs --url http://host/   # check an already-running server
 *   node tools/web_qa.mjs --page /web/index.html --page /
 *   node tools/web_qa.mjs --viewport 390x844 --viewport 1280x720
 *   node tools/web_qa.mjs --play 30         # also play: click, move, shoot, film
 *   node tools/web_qa.mjs --play 30 --hold 955,636 --touch --still
 *       # hold the AIM button with a real touch event, standing still
 *   node tools/web_qa.mjs --tour          # world review camera: F10 + keys 1-8
 *
 * `--hold` exists because the touch HUD lives inside the WebGL canvas: the AIM
 * button cannot be found with a DOM selector, so its canvas coordinates (read
 * from a screenshot) are passed explicitly. Holding AIM is the only way to
 * capture the aimed pose in a headless browser, where pointer-lock capture
 * never engages.
 *
 * `--play <seconds>` turns the boot check into a play test: it clicks the canvas
 * (which is also the user gesture browsers require before any audio can start),
 * walks and shoots with real input events, and writes a screenshot series. Those
 * frames are the only evidence that the game renders and reacts in a browser —
 * a boot check cannot see enemies, hits or the HUD under load.
 *
 * Why: an export that passes every static check can still boot to a black
 * screen — a missing index.wasm (wrong base path), no WebGL 2, a shell whose
 * Engine call drifted, a 404 on the audio worklet. This opens the real pages in
 * a real Chromium, waits for the engine, and fails loudly.
 *
 * Chromium comes from the pinned packages in tools/package.json, the same way
 * xam-eth/Scary-Night does it: @sparticuz/chromium ships bin/al2023.tar.br with
 * the shared libraries a headless build needs, extracted into tools/.cache/ at
 * first use (git-ignored) and fed to the browser through LD_LIBRARY_PATH.
 *
 * Exit code 0 = every page booted; 1 = at least one check failed.
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
  const i = argv.indexOf(name);
  return i === -1 ? def : argv[i + 1];
};
const has = (name) => argv.includes(name);
const pages = argv.reduce((list, arg, i) => (arg === '--page' ? [...list, argv[i + 1]] : list), []);
const targets = pages.length ? pages : ['/', '/web/index.html'];
const viewportArgs = argv.reduce((list, arg, i) => (arg === '--viewport' ? [...list, argv[i + 1]] : list), []);
const viewports = (viewportArgs.length ? viewportArgs : ['1280x720', '390x844']).map((spec) => {
  const [w, h] = spec.split('x').map(Number);
  return { spec, width: w || 1280, height: h || 720 };
});
const outDir = path.resolve(ROOT, flag('--out', path.join('exports', 'web-qa')));
const bootTimeoutMs = Number(flag('--timeout', '45')) * 1000;
const asJson = has('--json');
// Play pass: seconds of scripted input after boot. 0 keeps the fast boot check.
const playSeconds = Math.max(0, Number(flag('--play', '0')) || 0);
const playShotEvery = Math.max(1, Number(flag('--play-shot-every', '5')) || 5);
const givenUrl = flag('--url', '');
// --tour drives the in-game review camera (WorldTour): F10 toggles it, keys 1-8
// pick a district. Screenshots come from the real build, not a separate scene.
const tourMode = has('--tour');
const tourWaitMs = Number(flag('--tour-wait', '900'));
const port = Number(flag('--port', '8126'));

let chromium;
let puppeteer;
for (const [name, mod] of [['@sparticuz/chromium', 'chromium'], ['puppeteer-core', 'puppeteer']]) {
  try {
    const imported = (await import(name)).default;
    if (mod === 'chromium') chromium = imported; else puppeteer = imported;
  } catch (error) {
    console.error(`ERROR: ${name} is not installed. Run: npm ci --prefix tools`);
    console.error(String(error.message || error));
    process.exit(2);
  }
}

/* ---------- shared libraries for the headless build ---------- */
if (!fs.existsSync(path.join(LIB_DIR, 'libnss3.so'))) {
  const br = path.join(path.dirname(fileURLToPath(import.meta.resolve('@sparticuz/chromium'))), '..', 'bin', 'al2023.tar.br');
  if (!fs.existsSync(br)) {
    console.error(`ERROR: ${br} not found; @sparticuz/chromium looks broken.`);
    process.exit(2);
  }
  fs.mkdirSync(path.dirname(LIB_DIR), { recursive: true });
  const tar = path.join(CACHE, 'al2023.tar');
  fs.writeFileSync(tar, zlib.brotliDecompressSync(fs.readFileSync(br)));
  execFileSync('tar', ['-xf', tar, '-C', path.dirname(LIB_DIR)]);
  fs.rmSync(tar);
}

/* ---------- serve the repository when no URL was given ---------- */
let server = null;
let baseUrl = givenUrl.replace(/\/$/, '');
if (!baseUrl) {
  server = spawn('python3', ['-m', 'http.server', String(port), '--bind', '127.0.0.1'], { cwd: ROOT, stdio: 'ignore' });
  baseUrl = `http://127.0.0.1:${port}`;
  await new Promise((resolve) => setTimeout(resolve, 800));
}

fs.mkdirSync(outDir, { recursive: true });

const browser = await puppeteer.launch({
  executablePath: await chromium.executablePath(),
  args: [...chromium.args, '--no-sandbox', '--disable-dev-shm-usage'],
  headless: true,
  protocolTimeout: 300000,
  env: { ...process.env, LD_LIBRARY_PATH: [LIB_DIR, process.env.LD_LIBRARY_PATH].filter(Boolean).join(':') },
});

const ENGINE_BANNER = /Godot Engine v/i;
const report = { base: baseUrl, pages: [] };

async function checkPage(target, viewport) {
  const url = `${baseUrl}${target}`;
  const page = await browser.newPage();
  await page.setViewport({ width: viewport.width, height: viewport.height });
  const consoleLines = [];
  const pageErrors = [];
  const badResponses = [];
  const failedRequests = [];
  page.on('console', (m) => consoleLines.push(`${m.type()}: ${m.text().slice(0, 220)}`));
  page.on('pageerror', (e) => pageErrors.push(String(e).slice(0, 300)));
  page.on('response', (r) => {
    if (r.status() >= 400) badResponses.push(`${r.status()} ${r.url().replace(baseUrl, '')}`);
  });
  page.on('requestfailed', (r) => failedRequests.push(`${r.url().replace(baseUrl, '')} ${r.failure()?.errorText}`));

  const started = Date.now();
  await page.goto(url, { waitUntil: 'domcontentloaded', timeout: 60000 });

  let booted = false;
  let version = null;
  while (Date.now() - started < bootTimeoutMs) {
    await new Promise((r) => setTimeout(r, 1000));
    version = consoleLines.find((line) => ENGINE_BANNER.test(line)) || null;
    const failureVisible = await page.evaluate(() => {
      const el = document.getElementById('failure');
      return el ? !el.hidden : false;
    });
    if (version) { booted = true; break; }
    if (failureVisible) break;
  }
  // give the first frames a moment to render before inspecting the canvas
  if (booted) await new Promise((r) => setTimeout(r, 5000));

  const state = await page.evaluate(() => {
    const canvas = document.querySelector('canvas');
    const gl = canvas ? canvas.getContext('webgl2') || canvas.getContext('webgl') : null;
    const failure = document.getElementById('failure');
    const chip = document.getElementById('build-label');
    return {
      title: document.title,
      hasCanvas: !!canvas,
      canvasSize: canvas ? `${canvas.width}x${canvas.height}` : null,
      glContext: !!gl,
      glLost: gl ? gl.isContextLost() : null,
      failureVisible: failure ? !failure.hidden : false,
      failureText: (document.getElementById('failure-lead')?.textContent || '').slice(0, 200),
      chip: chip ? chip.textContent : null,
      bodyText: (document.body.innerText || '').replace(/\s+/g, ' ').slice(0, 160),
    };
  });

  const slug = target.replace(/[^a-z0-9]+/gi, '-').replace(/^-|-$/g, '') || 'root';
  const shot = path.join(outDir, `${slug}-${viewport.spec}.png`);
  await page.screenshot({ path: shot });

  /* ---------- optional world tour ---------- */
  const tourFrames = [];
  if (booted && tourMode) {
    await page.keyboard.press('F10');
    await new Promise((r) => setTimeout(r, 600));
    for (const digit of ['Digit1', 'Digit2', 'Digit3', 'Digit4', 'Digit5', 'Digit6', 'Digit7', 'Digit8']) {
      await page.keyboard.press(digit);
      await new Promise((r) => setTimeout(r, tourWaitMs));
      const frame = path.join(outDir, `${slug}-${viewport.spec}-tour-${digit.replace('Digit', '')}.png`);
      await page.screenshot({ path: frame });
      tourFrames.push(path.relative(ROOT, frame));
    }
  }

  /* ---------- optional play pass ---------- */
  const frames = [];
  if (booted && playSeconds > 0) {
    const centre = await page.evaluate(() => {
      const canvas = document.querySelector('canvas');
      if (!canvas) return null;
      const rect = canvas.getBoundingClientRect();
      return { x: rect.x + rect.width / 2, y: rect.y + rect.height / 2 };
    });
    if (centre) {
      // The click doubles as the gesture browsers require before audio runs.
      await page.mouse.click(centre.x, centre.y);
      // Mute and unmute up front. Each screenshot can cost tens of seconds in a
      // software-rendered browser, so anything timing-based inside the loop may
      // never be reached — and the console lines these produce are the only
      // outside proof that the audio toggle is wired.
      void page.keyboard.press('KeyM');
      await new Promise((r) => setTimeout(r, 300));
      void page.keyboard.press('KeyM');
      // --hold presses and holds one canvas point for the whole play pass. The
      // play screenshots then show the held state (e.g. the AIM button -> the
      // aimed pose), which is the only outside proof of the aimed weapon.
      const holdSpec = flag('--hold', '');
      let holdPoint = null;
      if (holdSpec) {
        const [hx, hy] = holdSpec.split(',').map(Number);
        holdPoint = { x: hx, y: hy };
        if (has('--touch')) {
          await page.touchscreen.touchStart(holdPoint.x, holdPoint.y);
        } else {
          await page.mouse.move(holdPoint.x, holdPoint.y);
          await page.mouse.down();
        }
        // Let the held state settle (socket blend is 0.16 s) before the first
        // scheduled screenshot, otherwise frame 0 shows a half-blended pose.
        await new Promise((r) => setTimeout(r, Number(flag('--warmup', '1200'))));
      }
      const started = Date.now();
      let nextShot = 0;
      // A hard cap on frames: SwiftShader needs 15-30 s per screenshot, and a
      // play window is measured in wall clock.
      const maxFrames = 6;
      // Input is fire-and-forget on purpose: a headless Chromium rendering this
      // scene through SwiftShader answers CDP calls slowly, so awaiting every
      // keystroke would spend the whole play window waiting on round-trips.
      while ((Date.now() - started) / 1000 < playSeconds) {
        const elapsed = (Date.now() - started) / 1000;
        const phase = Math.floor(elapsed / 6) % 3;
        const key = ['KeyW', 'KeyA', 'KeyD'][phase];
        if (!has('--still')) void page.keyboard.down(key);
        void page.keyboard.press('KeyE');
        // Turn towards the spawn ring so the enemies that chase the player end
        // up in front of the camera instead of behind it.
        void page.mouse.move(centre.x + 120 + phase * 60, centre.y - 10);
        if (!holdPoint) {
          void page.mouse.down();
          await new Promise((r) => setTimeout(r, 400));
          void page.mouse.up();
        } else {
          await new Promise((r) => setTimeout(r, 400));
        }
        await new Promise((r) => setTimeout(r, 400));
        if (!has('--still')) void page.keyboard.up(key);
        if (elapsed >= nextShot && frames.length < maxFrames) {
          const frame = path.join(outDir, `${slug}-${viewport.spec}-play-${Math.round(elapsed)}s.png`);
          await page.screenshot({ path: frame });
          frames.push(path.relative(ROOT, frame));
          nextShot += playShotEvery;
        }
      }
      if (holdPoint) {
        if (has('--touch')) await page.touchscreen.touchEnd();
        else await page.mouse.up();
      }
    }
  }

  const audioLines = consoleLines.filter((line) => line.includes('Audio:'));
  await page.close();

  const checks = [
    ['engine booted (console banner)', booted],
    ['no page errors', pageErrors.length === 0],
    ['no failed requests', failedRequests.length === 0],
    ['no HTTP 4xx/5xx for page assets', badResponses.length === 0],
    ['a canvas exists', state.hasCanvas],
    ['canvas is not the 300x150 default', state.canvasSize !== '300x150'],
    ['WebGL context alive', state.glContext === true && state.glLost === false],
    ['no failure card shown', state.failureVisible === false],
  ];
  if (tourMode) {
    checks.push(['world tour captured frames', tourFrames.length === 8]);
  }
  if (playSeconds > 0) {
    checks.push(['scripted play captured frames', frames.length > 0]);
    checks.push(['audio pipeline reported itself', audioLines.length > 0]);
    checks.push([
      'audio played a voice in the browser',
      audioLines.some((line) => line.includes('first voice')),
    ]);
    checks.push([
      'the mute control reaches the audio pipeline',
      // Exact line only: the boot line ends in "muted=no", so a loose substring
      // match here would pass without the M key ever reaching the audio.
      audioLines.some((line) => line.trim().endsWith('Audio: muted')),
    ]);
  }

  const result = {
    target,
    viewport: viewport.spec,
    url,
    ms: Date.now() - started,
    booted,
    engine: version ? version.replace(/^\w+: /, '') : null,
    state,
    checks: checks.map(([name, ok]) => ({ name, ok })),
    failed: checks.filter(([, ok]) => !ok).map(([name]) => name),
    screenshot: path.relative(ROOT, shot),
    frames,
    tourFrames,
    audio: audioLines,
    console: consoleLines,
    pageErrors,
    badResponses,
    failedRequests,
  };
  report.pages.push(result);
  return result;
}

try {
  for (const target of targets) {
    for (const viewport of viewports) {
    const result = await checkPage(target, viewport);
    if (!asJson) {
      console.log(`\n${target} @ ${viewport.spec} → ${result.failed.length ? 'FAIL' : 'PASS'} (${(result.ms / 1000).toFixed(1)}s)`);
      if (result.engine) console.log(`  engine: ${result.engine}`);
      console.log(`  canvas: ${result.state.canvasSize} | WebGL: ${result.state.glContext ? 'yes' : 'no'} | chip: ${result.state.chip ?? '-'}`);
      for (const c of result.checks) console.log(`  ${c.ok ? 'ok  ' : 'FAIL'} ${c.name}`);
      if (result.pageErrors.length) console.log(`  page errors: ${result.pageErrors.join(' | ')}`);
      if (result.badResponses.length) console.log(`  bad responses: ${result.badResponses.join(' | ')}`);
      if (result.failedRequests.length) console.log(`  failed requests: ${result.failedRequests.join(' | ')}`);
      if (result.state.failureText) console.log(`  failure card: ${result.state.failureText}`);
      console.log(`  screenshot: ${result.screenshot}`);
      if (result.frames?.length) console.log(`  play frames: ${result.frames.join(', ')}`);
      if (result.tourFrames?.length) console.log(`  tour frames: ${result.tourFrames.length} in ${path.relative(ROOT, outDir)}`);
      if (result.audio?.length) console.log(`  audio: ${result.audio.join(' | ')}`);
    }
    }
  }
} finally {
  await browser.close();
  if (server) server.kill();
}

const failed = report.pages.filter((p) => p.failed.length > 0);
report.ok = failed.length === 0;

if (asJson) {
  console.log(JSON.stringify(report, null, 2));
} else {
  console.log(
    `\nSummary: ${report.pages.length - failed.length}/${report.pages.length} page/viewport combination(s) booted into the engine.`,
  );
  if (failed.length) {
    console.log(`FAILED: ${failed.map((p) => `${p.target}@${p.viewport}`).join(', ')}`);
  }
}
process.exit(report.ok ? 0 : 1);
