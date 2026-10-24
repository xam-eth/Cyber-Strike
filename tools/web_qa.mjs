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
 *   node tools/web_qa.mjs --menus         # screenshot pause, then resume
 *   node tools/web_qa.mjs --menus --settings  # also open/settings screenshot, Esc/back
 *   node tools/web_qa.mjs --menus --settings-tabs # capture Controls, HUD, Access tabs
 *   node tools/web_qa.mjs --menus --settings --editor # HUD tab/editor screenshot
 *   node tools/web_qa.mjs --menus --swipe --viewport 390x844 # portrait sheet gesture
 *   node tools/web_qa.mjs --tour          # world review camera: P (F10 is browser-reserved) + keys 1-8
 *   node tools/web_qa.mjs --encounter-prep --explore-wait 8000
 *       # safe Explore + deliberate B + preparation; Defense is NOT claimed
 *   node tools/web_qa.mjs --encounter --explore-wait 8000 --encounter-timeout 600
 *       # strict: await a real Defense transition (software WebGL can be slow)
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
import crypto from 'node:crypto';
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
const requireDefense = has('--encounter');
const encounterMode = requireDefense || has('--encounter-prep');
const encounterTimeoutMs = Math.max(0, Number(flag('--encounter-timeout', '600')) || 0) * 1000;
const exploreWaitMs = Number(flag('--explore-wait', '8000'));
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

// Await an actual Godot transition, not a guessed wall-clock duration. A
// background SwiftShader renderer may advance only a fraction of a simulation
// second for each real second; don't falsify Defense by naming a countdown
// screenshot "started". The timeout belongs to strict --encounter only.
function awaitConsoleText(page, existingLines, text, timeoutMs) {
  if (existingLines.some((line) => line.includes(text))) return Promise.resolve(true);
  return new Promise((resolve) => {
    const onMessage = (message) => {
      if (!message.text().includes(text)) return;
      clearTimeout(timer);
      page.off('console', onMessage);
      resolve(true);
    };
    const timer = setTimeout(() => {
      page.off('console', onMessage);
      resolve(false);
    }, timeoutMs);
    page.on('console', onMessage);
  });
}

async function checkPage(target, viewport) {
  const url = `${baseUrl}${target}`;
  const page = await browser.newPage();
  // A narrow viewport alone is not a phone: without touch emulation Godot
  // correctly hides the thumb controls, so mobile screenshots used to QA the
  // wrong HUD. --touch also forces touch on a wide viewport when requested.
  const touchDevice = has('--touch') || Math.min(viewport.width, viewport.height) < 600;
  await page.setViewport({
    width: viewport.width,
    height: viewport.height,
    hasTouch: touchDevice,
    isMobile: touchDevice,
    deviceScaleFactor: 1,
  });
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
    const bounds = canvas?.getBoundingClientRect();
    const hitTarget = bounds
      ? document.elementFromPoint(bounds.x + bounds.width / 2, bounds.y + bounds.height / 2)
      : null;
    return {
      title: document.title,
      hasCanvas: !!canvas,
      canvasSize: canvas ? `${canvas.width}x${canvas.height}` : null,
      canvasHittable: hitTarget === canvas,
      hitTarget: hitTarget?.id || hitTarget?.tagName || null,
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

  /* ---------- optional pause/resume frame ---------- */
  const menuFrames = [];
  const settingsTabFrames = [];
  let accessBottomFrame = null;
  if (booted && has('--menus')) {
    const canvasCentre = await page.evaluate(() => {
      const rect = document.querySelector('canvas')?.getBoundingClientRect();
      return rect ? { x: rect.x + rect.width / 2, y: rect.y + rect.height / 2 } : null;
    });
    if (canvasCentre) {
      await page.mouse.click(canvasCentre.x, canvasCentre.y);
      await page.keyboard.press('Escape');
      await new Promise((r) => setTimeout(r, 500));
      const pauseFrame = path.join(outDir, `${slug}-${viewport.spec}-pause.png`);
      await page.screenshot({ path: pauseFrame });
      menuFrames.push(path.relative(ROOT, pauseFrame));
      if (has('--settings') || has('--editor') || has('--settings-tabs')) {
        // Pause focuses RESUME; two Tab presses select SETTINGS. Keyboard
        // navigation works even when the entire Godot UI lives in a canvas.
        await page.keyboard.press('Tab');
        await page.keyboard.press('Tab');
        await page.keyboard.press('Enter');
        await new Promise((r) => setTimeout(r, 500));
        const settingsFrame = path.join(outDir, `${slug}-${viewport.spec}-settings.png`);
        await page.screenshot({ path: settingsFrame });
        menuFrames.push(path.relative(ROOT, settingsFrame));
        if (has('--settings-tabs')) {
          // Each selected tab retains focus when its page contents change.
          // Visit all pages, then return to HUD if the editor is requested.
          for (const tab of ['controls', 'hud', 'access']) {
            await page.keyboard.press('Tab');
            await page.keyboard.press('Enter');
            await new Promise((r) => setTimeout(r, 350));
            const frame = path.join(outDir, `${slug}-${viewport.spec}-settings-${tab}.png`);
            await page.screenshot({ path: frame });
            settingsTabFrames.push(path.relative(ROOT, frame));
          }
          if (viewport.height < 500) {
            // The fixed footer must not obscure the last accessibility toggle
            // on a short landscape phone; wheel over the scrollable page.
            await page.mouse.move(viewport.width / 2, viewport.height * 0.6);
            await page.mouse.wheel({ deltaY: 480 });
            await new Promise((r) => setTimeout(r, 350));
            const frame = path.join(outDir, `${slug}-${viewport.spec}-settings-access-bottom.png`);
            await page.screenshot({ path: frame });
            accessBottomFrame = path.relative(ROOT, frame);
          }
        }
        if (has('--editor')) {
          if (has('--settings-tabs')) {
            // ACCESS has focus; Shift-Tab returns to HUD.
            await page.keyboard.down('Shift');
            await page.keyboard.press('Tab');
            await page.keyboard.up('Shift');
          } else {
            // AUDIO has focus; two tabs reach HUD.
            await page.keyboard.press('Tab');
            await page.keyboard.press('Tab');
          }
          await page.keyboard.press('Enter');
          // From HUD, the next four stops are ACCESS, HUD SCALE, OPACITY,
          // EDIT HUD LAYOUT. The last Enter opens the live inspector.
          for (let stop = 0; stop < 4; stop += 1) await page.keyboard.press('Tab');
          await page.keyboard.press('Enter');
          await new Promise((r) => setTimeout(r, 500));
          const editorFrame = path.join(outDir, `${slug}-${viewport.spec}-editor.png`);
          await page.screenshot({ path: editorFrame });
          menuFrames.push(path.relative(ROOT, editorFrame));
          await page.keyboard.press('Escape');
          await new Promise((r) => setTimeout(r, 250));
        }
        await page.keyboard.press('Escape');
        await new Promise((r) => setTimeout(r, 250));
      }
      if (has('--swipe') && viewport.height > viewport.width) {
        // The portrait bottom sheet sits 34 physical px above the gesture
        // area and is 340 px tall. Start at its 48x4 grip, not on RESUME.
        const gripX = viewport.width / 2;
        const gripY = viewport.height - 34 - 340 + 18;
        await page.touchscreen.touchStart(gripX, gripY);
        await page.touchscreen.touchMove(gripX, gripY + 100);
        await page.touchscreen.touchEnd();
      } else {
        await page.keyboard.press('Escape');
      }
      await new Promise((r) => setTimeout(r, 350));
    }
  }

  /* ---------- reach the gameplay scene ---------- */
  // A Godot canvas is one DOM element with no children, so a button cannot be
  // queried, and every menu stage sets mouse_filter = MOUSE_FILTER_STOP: the
  // GUI absorbs the click and the stage's `_unhandled_input()` fallback never
  // fires, so "tap anywhere to continue" does not work from a click at an
  // arbitrary point. Each stage therefore prints its primary button's rect
  // (`MenuCTA: x,y,w,h in <viewport w>,<viewport h>`) and this pass clicks it,
  // stage by stage, until the gameplay scene reports in. Without it the tour
  // pressed F10 in the front-end menu, where the review camera does not exist,
  // and reported eight menu frames as a success (docs/DECISIONS.md
  // §12.3).
  // Each stage opens with its primary action focused, so ui_accept (Enter)
  // activates it: one Enter per stage, no coordinates and no guessing. A Godot
  // canvas has no DOM to query, a stage's mouse_filter = MOUSE_FILTER_STOP
  // means the GUI absorbs a click before the stage's _unhandled_input() sees
  // it, and the button's global rect reads 0,0 while the stage sits in the
  // front-end viewport — all three measured, see
  // docs/DECISIONS.md §12.3.
  const advanceToGameplay = async () => {
    const reached = () => consoleLines.some((line) => line.includes('Encounter: Explore safe'));
    const stageLine = () => consoleLines.filter((l) => l.includes('FrontEnd: stage')).pop() || '';
    // A Control only owns GUI focus while the Godot window has keyboard focus,
    // and headless Chromium does not hand it over on its own: without this
    // click the grab_focus() in the stage is a no-op and every Enter below is
    // swallowed by the document.
    const canvas = await page.$('canvas');
    if (canvas) await canvas.click();
    // The opening cinematic is 9.58 s of video and ignores Enter entirely.
    // Software WebGL decodes it at roughly a fifth of real time, so the wait
    // is measured in minutes, not seconds.
    for (let i = 0; i < 240 && !/stage (CHAPTER|DASHBOARD|HERO|WEAPON|WORLD|PRELOAD)/.test(stageLine()); i += 1) {
      await new Promise((r) => setTimeout(r, 1000));
    }
    if (!reached()) console.log(`  journey: front-end at ${stageLine().trim() || '(no stage yet)'}`);
    for (let press = 0; press < 16 && !reached(); press += 1) {
      const before = stageLine();
      // Enter first: a stage built while the window already had focus owns it.
      await page.keyboard.press('Enter');
      await new Promise((r) => setTimeout(r, 1000));
      if (stageLine() === before) {
        // Fall back to the focus ring. grab_focus() cannot take effect while
        // the Godot window has no keyboard focus, and headless Chromium only
        // hands it over on a click — so a stage created before that click
        // (the first one, CHAPTER) has no focused control at all.
        await page.keyboard.press('Tab');
        await page.keyboard.press('Enter');
        await new Promise((r) => setTimeout(r, 1000));
      }
      if (stageLine() === before) {
        // Still nothing: a panel may be open on top of the stage.
        await page.keyboard.press('Escape');
        await new Promise((r) => setTimeout(r, 400));
      }
    }
    if (!reached()) console.log(`  journey stalled at: ${stageLine().trim() || '(unknown)'}`);
    return reached();
  };

  /* ---------- explicit Explore → Preparing → Defense check ---------- */
  const encounterFrames = [];
  let safeBeforeActivation = false;
  if (booted && encounterMode) {
    await new Promise((r) => setTimeout(r, exploreWaitMs));
    const transitions = consoleLines.filter((line) => line.includes('Encounter:'));
    safeBeforeActivation = transitions.some((line) => line.includes('Explore safe'))
      && !transitions.some((line) => line.includes('Defense started'));
    const exploreFrame = path.join(outDir, `${slug}-${viewport.spec}-explore-idle.png`);
    await page.screenshot({ path: exploreFrame });
    encounterFrames.push(path.relative(ROOT, exploreFrame));
    const centre = await page.evaluate(() => {
      const rect = document.querySelector('canvas')?.getBoundingClientRect();
      return rect ? { x: rect.x + rect.width / 2, y: rect.y + rect.height / 2 } : null;
    });
    if (centre) {
      await page.mouse.click(centre.x, centre.y);
      await page.keyboard.press('KeyB');
      await new Promise((r) => setTimeout(r, 450));
      const preparingFrame = path.join(outDir, `${slug}-${viewport.spec}-defense-preparing.png`);
      await page.screenshot({ path: preparingFrame });
      encounterFrames.push(path.relative(ROOT, preparingFrame));
      // Godot's countdown advances in simulation time. SwiftShader may render
      // a fraction of a second of Godot time per several wall-clock seconds;
      // never label a frame 'Defense started' merely because a timer elapsed.
      await new Promise((r) => setTimeout(r, 7000));
      if (requireDefense) {
        await awaitConsoleText(page, consoleLines, 'Encounter: Defense started', encounterTimeoutMs);
        // Allow the HUD state changed in Godot to reach the visible canvas.
        await new Promise((r) => setTimeout(r, 700));
      }
      const defenseStarted = consoleLines.some((line) => line.includes('Encounter: Defense started'));
      const phase = defenseStarted ? 'defense-started' : 'preparing-progress';
      const phaseFrame = path.join(outDir, `${slug}-${viewport.spec}-${phase}.png`);
      await page.screenshot({ path: phaseFrame });
      encounterFrames.push(path.relative(ROOT, phaseFrame));
    }
  }

  /* ---------- walk the front end to the gameplay scene ---------- */
  // A play pass acts on the *gameplay* scene, so it needs the journey walked
  // even when no tour or encounter was asked for. Before this, `--play` on its
  // own clicked the centre of whichever menu stage was on screen: the shot
  // check could never pass, which is worse than no check
  // (docs/DECISIONS.md §12.3, the same defect as the tour
  // photographing the menu).
  let inGameplay = false;
  if (booted && (tourMode || encounterMode || playSeconds > 0)) {
    inGameplay = await advanceToGameplay();
  }

  /* ---------- optional play pass ---------- */
  const frames = [];
  if (booted && playSeconds > 0 && state.canvasHittable) {
    const centre = await page.evaluate(() => {
      const canvas = document.querySelector('canvas');
      if (!canvas) return null;
      const rect = canvas.getBoundingClientRect();
      return { x: rect.x + rect.width / 2, y: rect.y + rect.height / 2 };
    });
    if (centre) {
      // The click doubles as the gesture browsers require before audio runs.
      await page.mouse.click(centre.x, centre.y);
      // Verify a real shot before entering the time-boxed motion loop. In
      // SwiftShader, screenshots and CDP key events can each take tens of
      // seconds: fire-and-forget mute toggles raced one another and left the
      // entire play pass muted. Do this before --hold so a mouse-held UI
      // button is not released by the firing probe.
      if (consoleLines.some((line) => /Audio: .*muted=yes/.test(line))) {
        await page.keyboard.press('KeyM');
        await awaitConsoleText(page, consoleLines, 'Audio: unmuted', 30000);
      }
      await page.mouse.move(centre.x, centre.y);
      await page.mouse.down();
      await awaitConsoleText(page, consoleLines, 'Audio: first voice played', 45000);
      await page.mouse.up();
      // Capture the spent magazine before the motion loop switches weapons.
      // A later frame can say 6/6 for Nova even though Pulse already fired.
      const firedFrame = path.join(outDir, `${slug}-${viewport.spec}-fired.png`);
      await page.screenshot({ path: firedFrame });
      frames.push(path.relative(ROOT, firedFrame));
      // Test the sound control separately, in sequence, after audible firing.
      await page.keyboard.press('KeyM');
      await awaitConsoleText(page, consoleLines, 'Audio: muted', 30000);
      await page.keyboard.press('KeyM');
      await awaitConsoleText(page, consoleLines, 'Audio: unmuted', 30000);
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

  /* ---------- optional world tour (last: it pauses the simulation) ---------- */
  const tourFrames = [];
  if (booted && tourMode && inGameplay) {
    // Click the canvas first: a Godot window only owns keyboard focus after a
    // user gesture, and keys sent to an unfocused page go nowhere.
    const viewportCentre = await page.evaluate(() => {
      const canvas = document.querySelector('canvas');
      if (!canvas) return null;
      const rect = canvas.getBoundingClientRect();
      return { x: rect.x + rect.width / 2, y: rect.y + rect.height / 2 };
    });
    if (viewportCentre) await page.mouse.click(viewportCentre.x, viewportCentre.y);
    // P, not F10: F10 is reserved by browsers and never reaches the page, so
    // the review camera was never engaged while this pass reported that it had
    // captured a "world tour" (docs/DECISIONS.md §12.3).
    await page.keyboard.press('KeyP');
    await new Promise((r) => setTimeout(r, 600));
    const engaged = consoleLines.some((line) => line.includes('World tour: review camera engaged'));
    if (!engaged) console.log('  tour: the review camera did not engage (no World tour: log line)');
    for (const digit of ['Digit1', 'Digit2', 'Digit3', 'Digit4', 'Digit5', 'Digit6', 'Digit7', 'Digit8']) {
      await page.keyboard.press(digit);
      await new Promise((r) => setTimeout(r, tourWaitMs));
      const frame = path.join(outDir, `${slug}-${viewport.spec}-tour-${digit.replace('Digit', '')}.png`);
      await page.screenshot({ path: frame });
      tourFrames.push(path.relative(ROOT, frame));
    }
    // The review rig freezes the simulation on purpose. It is the last thing
    // this run does for exactly that reason: earlier it ran before the play
    // pass, the release key never reached the game (the same window-focus
    // problem as §12.3), and the play pass then fired into a paused game while
    // the report blamed the audio pipeline. Ordering beats a key press here;
    // the assertion below still proves the rig was engaged.
    await page.keyboard.press('KeyP');
    await new Promise((r) => setTimeout(r, 600));
  }
  await page.close();

  const audioLines = consoleLines.filter((line) => line.includes('Audio:'));
  const menuLines = consoleLines.filter((line) => line.includes('HUD: '));
  const scriptErrors = consoleLines.filter((line) => /SCRIPT ERROR:|Parse Error:/.test(line));

  const checks = [
    ['engine booted (console banner)', booted],
    ['no Godot script/parse errors', scriptErrors.length === 0],
    ['no page errors', pageErrors.length === 0],
    ['no failed requests', failedRequests.length === 0],
    ['no HTTP 4xx/5xx for page assets', badResponses.length === 0],
    ['a canvas exists', state.hasCanvas],
    ['canvas is not the 300x150 default', state.canvasSize !== '300x150'],
    ['canvas accepts pointer input (no transparent loading overlay)', state.canvasHittable === true],
    ['WebGL context alive', state.glContext === true && state.glLost === false],
    ['no failure card shown', state.failureVisible === false],
  ];
  if (tourMode) {
    checks.push(['front-end journey reached the gameplay scene', inGameplay]);
    checks.push(['world tour captured frames', tourFrames.length === 8]);
    // Eight identical files mean the camera never moved, which is what this
    // pass reported as a success for as long as nobody compared the frames.
    const hashes = new Set(
      tourFrames.map((f) => crypto.createHash('md5').update(fs.readFileSync(path.join(ROOT, f))).digest('hex')),
    );
    checks.push([
      `world tour frames differ (${hashes.size} distinct of ${tourFrames.length})`,
      tourFrames.length > 0 && hashes.size >= 2,
    ]);
    // The tour is the last thing a run does, because the rig pauses the
    // simulation while it tours. What is worth asserting is that the rig ran in
    // gameplay at all — the eight frames above only mean something if the
    // review camera moved, and the release key is not asserted: it depends on
    // the Godot window owning keyboard focus, which a freshly loaded page does
    // not have (docs/DECISIONS.md §12.3). Ordering removes the need.
    checks.push([
      'world tour engaged the review camera in gameplay',
      consoleLines.some((line) => line.includes('World tour: review camera engaged')),
    ]);
  }
  if (encounterMode) {
    const encounterLines = consoleLines.filter((line) => line.includes('Encounter:'));
    const preparationAt = encounterLines.findIndex((line) => line.includes('Preparing Defense'));
    const defenseAt = encounterLines.findIndex((line) => line.includes('Defense started'));
    checks.push(['Explore remained safe before explicit activation', safeBeforeActivation]);
    checks.push(['B requested a visible Defense preparation', preparationAt >= 0]);
    checks.push(['Explore and preparation frames captured', encounterFrames.length === 3]);
    if (requireDefense) {
      checks.push(['Defense began only after the preparation countdown', defenseAt > preparationAt]);
      checks.push([
        'browser screenshot shows actual Defense',
        encounterFrames.some((frame) => frame.includes('defense-started.png')),
      ]);
    }
  }
  if (has('--menus')) {
    checks.push(['pause menu captured a frame', menuFrames.length >= 1]);
    checks.push(['ESC opened the pause state', menuLines.some((line) => line.includes('HUD: paused'))]);
    checks.push([
      has('--swipe') && viewport.height > viewport.width ? 'portrait swipe resumed the game' : 'ESC resumed the game',
      menuLines.some((line) => line.includes('HUD: resumed')),
    ]);
    if (has('--settings') || has('--editor') || has('--settings-tabs')) {
      checks.push(['settings screen captured a frame', menuFrames.length >= 2]);
      checks.push(['SETTINGS opened via keyboard', menuLines.some((line) => line.includes('HUD: settings opened'))]);
      checks.push(['ESC returned to pause from settings', menuLines.some((line) => line.includes('HUD: settings closed'))]);
    }
    if (has('--settings-tabs')) {
      checks.push(['Controls, HUD, and Access tabs captured', settingsTabFrames.length === 3]);
      if (viewport.height < 500) {
        checks.push(['landscape Access bottom captured after scrolling', accessBottomFrame !== null]);
      }
    }
    if (has('--editor')) {
      checks.push(['HUD editor captured a frame', menuFrames.length === 3]);
      checks.push(['HUD editor opened via keyboard', menuLines.some((line) => line.includes('HUD: editor opened'))]);
      checks.push(['ESC returned to settings from editor', menuLines.some((line) => line.includes('HUD: editor closed'))]);
    }
  }
  if (playSeconds > 0) {
    checks.push(['scripted play captured frames', frames.length > 0]);
    checks.push(['audio pipeline reported itself', audioLines.length > 0]);
    checks.push(
      encounterMode
        ? ['audio played a voice in the browser', audioLines.some((line) => line.includes('first voice played'))]
        : [
            'weapon shot played in the browser',
            // The first voice of a session is usually a menu/session sound, so
            // matching the *first-voice* line reported a failure while the
            // magazine was one round down. The engine now logs the first
            // weapon voice separately (audio_director._note_played).
            audioLines.some((line) => line.includes('first weapon voice played')),
          ],
    );
    checks.push([
      'the mute control reaches the audio pipeline',
      // Exact transition only. Browser user:// persists between viewport runs:
      // the first M can unmute a previous run instead of muting a fresh one.
      // The boot line ends in "muted=yes/no" and must not count as a toggle.
      audioLines.some((line) => /Audio: (muted|unmuted)$/.test(line.trim())),
    ]);
  }

  const result = {
    target,
    viewport: viewport.spec,
    touchDevice,
    url,
    ms: Date.now() - started,
    booted,
    engine: version ? version.replace(/^\w+: /, '') : null,
    state,
    checks: checks.map(([name, ok]) => ({ name, ok })),
    failed: checks.filter(([, ok]) => !ok).map(([name]) => name),
    screenshot: path.relative(ROOT, shot),
    menuFrames,
    settingsTabFrames,
    accessBottomFrame,
    frames,
    tourFrames,
    encounterFrames,
    safeBeforeActivation,
    defenseObserved: consoleLines.some((line) => line.includes('Encounter: Defense started')),
    encounterTransitions: consoleLines.filter((line) => line.includes('Encounter:')),
    audio: audioLines,
    menuTransitions: menuLines,
    scriptErrors,
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
      console.log(`  canvas: ${result.state.canvasSize} | WebGL: ${result.state.glContext ? 'yes' : 'no'} | touch: ${result.touchDevice ? 'yes' : 'no'} | chip: ${result.state.chip ?? '-'}`);
      if (!result.state.canvasHittable) console.log(`  canvas blocked by DOM element: ${result.state.hitTarget ?? 'none'}`);
      for (const c of result.checks) console.log(`  ${c.ok ? 'ok  ' : 'FAIL'} ${c.name}`);
      if (result.pageErrors.length) console.log(`  page errors: ${result.pageErrors.join(' | ')}`);
      if (result.badResponses.length) console.log(`  bad responses: ${result.badResponses.join(' | ')}`);
      if (result.failedRequests.length) console.log(`  failed requests: ${result.failedRequests.join(' | ')}`);
      if (result.state.failureText) console.log(`  failure card: ${result.state.failureText}`);
      if (result.scriptErrors.length) console.log(`  script errors: ${result.scriptErrors.join(' | ')}`);
      console.log(`  screenshot: ${result.screenshot}`);
      if (result.menuFrames?.length) console.log(`  menu frames: ${result.menuFrames.join(', ')}`);
      if (result.settingsTabFrames?.length) console.log(`  tab frames: ${result.settingsTabFrames.join(', ')}`);
      if (result.accessBottomFrame) console.log(`  Access scroll: ${result.accessBottomFrame}`);
      if (result.menuTransitions?.length) console.log(`  menu state: ${result.menuTransitions.join(' | ')}`);
      if (result.frames?.length) console.log(`  play frames: ${result.frames.join(', ')}`);
      if (result.tourFrames?.length) console.log(`  tour frames: ${result.tourFrames.length} in ${path.relative(ROOT, outDir)}`);
      if (result.encounterFrames?.length) console.log(`  encounter frames: ${result.encounterFrames.join(', ')}`);
      if (result.encounterTransitions?.length) console.log(`  encounter: ${result.encounterTransitions.join(' | ')}`);
      if (encounterMode && !result.defenseObserved) {
        console.log('  browser Defense: NOT OBSERVED (SwiftShader simulation may lag; Godot smoke is a separate test)');
      }
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
    `\nSummary: ${report.pages.length - failed.length}/${report.pages.length} page/viewport combination(s) passed all requested checks.`,
  );
  if (failed.length) {
    console.log(`FAILED: ${failed.map((p) => `${p.target}@${p.viewport}`).join(', ')}`);
  }
}
process.exit(report.ok ? 0 : 1);
