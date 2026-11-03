#!/usr/bin/env node
/*
 * tools/web_qa.mjs — browser QA for the WebAssembly preview.
 *
 *   node tools/web_qa.mjs                      # serve the repo root, check both pages
 *   node tools/web_qa.mjs --json               # machine-readable report
 *   node tools/web_qa.mjs --url http://host/   # check an already-running server
 *   node tools/web_qa.mjs --page /web/index.html --page /
 *   node tools/web_qa.mjs --viewport 844x390 --viewport 667x375
 *   node tools/web_qa.mjs --play 30         # also play: click, move, shoot, film
 *   node tools/web_qa.mjs --play 30 --hold 955,636 --touch --still
 *       # hold the AIM button with a real touch event, standing still
 *   node tools/web_qa.mjs --menus         # screenshot pause, then resume
 *   node tools/web_qa.mjs --menus --settings  # also open/settings screenshot, Esc/back
 *   node tools/web_qa.mjs --menus --settings-tabs # capture Controls, HUD, Access tabs
 *   node tools/web_qa.mjs --menus --settings --editor # HUD tab/editor screenshot
 *   node tools/web_qa.mjs --menus --viewport 844x390   # lobby pages and overlays
 *   node tools/web_qa.mjs --tour          # world review camera: P (F10 is browser-reserved) + keys 1-8
 *   node tools/web_qa.mjs --encounter-prep --explore-wait 8000
 *       # safe Explore + deliberate B + preparation; Defense is NOT claimed
 *   node tools/web_qa.mjs --encounter --explore-wait 8000 --encounter-timeout 600
 *       # strict: await a real Defense transition (software WebGL can be slow)
 *   node tools/web_qa.mjs --page / --recovery
 *       # Aetherfall Explore -> Engage -> two rigged 3D robot guards + Secure-locked HUD
 *   node tools/web_qa.mjs --page / --journey --select-world aetherfall --audio-shell
 *       # choose SH-01 Aetherfall in the shell and verify selection, runtime and audio
 *   node tools/web_qa.mjs --page / --journey --audio-shell
 *       # real-gesture shell music, mute persistence and DEPLOY audio handoff
 *   node tools/web_qa.mjs --page / --encounter --select-world aetherfall
 *       # additionally request Defense in SH-01 Aetherfall
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
const viewports = (viewportArgs.length ? viewportArgs : ['844x390', '667x375']).map((spec) => {
  const [w, h] = spec.split('x').map(Number);
  return { spec, width: w || 1280, height: h || 720 };
});
const outDir = path.resolve(ROOT, flag('--out', path.join('exports', 'web-qa')));
const bootTimeoutMs = Number(flag('--timeout', '45')) * 1000;
const asJson = has('--json');
// Keep stdout machine-readable in --json mode. Progress remains visible on
// stderr instead of being silently discarded or corrupting the JSON report.
const progress = (message) => (asJson ? console.error(message) : console.log(message));
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
// --recovery proves the real Aetherfall landing → Engage → guarded robot state.
// --recovery-e2e drives the full Aetherfall Arrival Tech Cache clear via movable
// [+] cursor aiming → Phase Thrusters schematic secure → Hub tier-free Operative
// switch (Sable 110 HP → Kestrel 96 HP) → 96-vital redeploy loop via real inputs.
const recoveryE2eMode = has('--recovery-e2e');
const recoveryMode = has('--recovery') || recoveryE2eMode;
const upgradesMode = has('--upgrades');
const selectVanguard = has('--select-vanguard');
const selectedWorld = String(
  flag('--select-world', selectVanguard || recoveryMode ? 'aetherfall' : ''),
);
const selectWorld = selectedWorld.length > 0;
const selectedWorldCard = `world-card-${selectedWorld.replaceAll('_', '-')}`;
const selectedWorldPin = `${selectedWorld.split('_').map((part) => part.charAt(0).toUpperCase() + part.slice(1)).join('')}Pin`;
const selectedWorldBuildLog = `MISSION WORLD: ${selectedWorld} (`;
// Journey mode proves the root shell's direct theatre hand-off, and retains
// the measured WORLD-stage route for raw engine journeys. --select-vanguard
// remains the original compatibility spelling of --select-world vanguard_station.
const journeyMode = has('--journey') || selectWorld;
// Optional real-gesture Web Audio checks on the root shell. This is separate
// from Godot's first-voice/mute checks and never claims human mix acceptance.
const audioShellMode = has('--audio-shell');
// Measured ADS on the equipped Web weapon. All three ids are covered by the
// engine input smoke; this pass proves real browser mouse/touch delivery.
const adsMode = has('--ads');
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

const launchBrowser = async (protocolTimeout) => {
  try {
    return await puppeteer.launch({
      executablePath: await chromium.executablePath(),
      args: [...chromium.args, '--no-sandbox', '--disable-dev-shm-usage'],
      headless: true,
      protocolTimeout,
      env: { ...process.env, LD_LIBRARY_PATH: [LIB_DIR, process.env.LD_LIBRARY_PATH].filter(Boolean).join(':') },
    });
  } catch (primaryErr) {
    for (const candidate of ['/usr/bin/google-chrome', '/usr/bin/google-chrome-stable', '/usr/bin/chromium', '/usr/bin/chromium-browser']) {
      if (!fs.existsSync(candidate)) continue;
      try {
        return await puppeteer.launch({
          executablePath: candidate,
          args: [
            '--no-sandbox',
            '--disable-setuid-sandbox',
            '--disable-dev-shm-usage',
            '--use-gl=angle',
            '--use-angle=swiftshader-webgl',
            '--enable-unsafe-swiftshader',
          ],
          headless: true,
          protocolTimeout,
        });
      } catch (_fallbackErr) {
        // try next binary
      }
    }
    if (server) server.kill();
    console.error(`ERROR: Failed to launch headless Chromium: ${primaryErr?.message || primaryErr}`);
    throw primaryErr;
  }
};

const safeClosePage = async (pageInstance) => {
  if (!pageInstance) return;
  await Promise.race([
    pageInstance.goto('about:blank', { waitUntil: 'commit', timeout: 2500 }).catch(() => {}),
    new Promise((resolve) => setTimeout(resolve, 2600)),
  ]);
  await Promise.race([
    pageInstance.close().catch(() => {}),
    new Promise((resolve) => setTimeout(resolve, 4000)),
  ]);
};

const safeCloseBrowser = async (browserInstance) => {
  if (!browserInstance) return;
  const proc = browserInstance.process();
  await Promise.race([
    browserInstance.close().catch(() => {}),
    new Promise((resolve) => setTimeout(resolve, 5000)),
  ]);
  if (proc && proc.exitCode === null) {
    try {
      proc.kill('SIGKILL');
    } catch {
      // ignore already-exited child process
    }
  }
};

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
  const browser = await launchBrowser(180000);
  try {
    return await checkPageWithBrowser(browser, target, viewport);
  } finally {
    await safeCloseBrowser(browser);
  }
}

async function checkPageWithBrowser(browser, target, viewport) {
  const url = new URL(`${baseUrl}${target}`);
  // WORLD selection uses the engine's measured Control rectangles, never a
  // second set of guessed layout coordinates in the browser harness.
  if (selectWorld) url.searchParams.set('qa_menu', '1');
  if (recoveryMode) {
    url.searchParams.set('qa_recovery', '1');
    url.searchParams.set('qa_camera', '1');
  }
  if (upgradesMode) url.searchParams.set('qa_upgrade', '1');
  if (adsMode) {
    url.searchParams.set('qa_touch', '1');
    url.searchParams.set('qa_camera', '1');
  }
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
  page.on('console', (m) => {
    const text = m.text();
    // Menu QA is a single line carrying every rendered Control rect. Keep it
    // intact; truncating it at the normal 220 characters hides the pin/launch.
    const detailed = text.startsWith('Menu QA:') || text.startsWith('Touch QA:') || text.startsWith('Camera QA:');
    const limit = detailed ? 12000 : 220;
    consoleLines.push(`${m.type()}: ${text.slice(0, limit)}`);
  });
  page.on('pageerror', (e) => pageErrors.push(String(e).slice(0, 300)));
  page.on('response', (r) => {
    if (r.status() >= 400) badResponses.push(`${r.status()} ${r.url().replace(baseUrl, '')}`);
  });
  page.on('requestfailed', (r) => {
    const errText = r.failure()?.errorText || '';
    if (recoveryE2eMode && errText === 'net::ERR_ABORTED') return;
    failedRequests.push(`${r.url().replace(baseUrl, '')} ${errText}`);
  });

  if (recoveryE2eMode) {
    await page.evaluateOnNewDocument(() => {
      // CDP mouse moves deliver zero movementX/Y under pointer lock, and native
      // context menus swallow right-button mouseup events when pointer lock is off.
      // Exercise PlayerController's supported no-pointer-lock ADS fallback cleanly.
      HTMLElement.prototype.requestPointerLock = function requestPointerLockNoop() {};
      window.addEventListener('contextmenu', (e) => e.preventDefault(), { capture: true });
    });
  }

  const started = Date.now();
  await page.goto(url.toString(), { waitUntil: 'domcontentloaded', timeout: 60000 });

  // The player opening initializes the engine and preloads the complete world
  // pack before MASUK, but does not start gameplay until DEPLOY. Walk that real
  // path instead of using an auto-boot that only exists for tests. Pages without
  // the shell (the raw /web/ build) skip this.
  const isFrontEnd = await page.evaluate(() => !!document.getElementById('hub-deploy'));
  let shellWorldSelected = null;
  let shellHeroStage = null;
  let shellAudioHero = null;
  let shellAudioBefore = null;
  let shellAudioMuted = null;
  let shellAudioUnmuted = null;
  let shellAudioHandoff = null;
  let shellAudioAfter = null;
  let shellMuteStored = null;
  let shellUnmuteStored = null;
  let gameplayMuteStored = null;
  let gameplayUnmuteStored = null;
  if (isFrontEnd) {
    await page
      .waitForFunction(() => {
        const enter = document.getElementById('opening-enter');
        return enter && !enter.disabled;
      }, { polling: 100, timeout: Math.max(90000, bootTimeoutMs) })
      .catch(() => {});
    if (audioShellMode) await page.click('#opening-enter');
    else await page.evaluate(() => document.getElementById('opening-enter')?.click());
    await page.waitForFunction(() => document.body.dataset.screen === 'hero', { polling: 100, timeout: 30000 }).catch(() => {});
    await page.waitForFunction(() => {
      const stage = window.AegisHeroStage?.describe();
      return stage?.ready && stage.celebration === 'celebration';
    }, { polling: 100, timeout: 60000 }).catch(() => {});
    shellHeroStage = await page.evaluate(() => window.AegisHeroStage?.describe() || null);
    if (audioShellMode) {
      await page.waitForFunction(() => {
        const state = window.AegisAudio?.snapshot();
        return state?.scene === 'hero' && state.unlocked && state.musicPlaying && state.loaded.length === 4;
      }, { polling: 100, timeout: 30000 }).catch(() => {});
      shellAudioHero = await page.evaluate(() => window.AegisAudio?.snapshot() || null);
      await page.click('#hero-next');
    } else {
      await page.evaluate(() => document.getElementById('hero-next')?.click());
    }
    await page.waitForFunction(() => document.body.dataset.screen === 'hub', { polling: 100, timeout: 30000 }).catch(() => {});
    if (audioShellMode) {
      await page.waitForFunction(() => {
        const state = window.AegisAudio?.snapshot();
        return state?.unlocked && state.musicPlaying && state.loaded.length === 4;
      }, { timeout: 20000 }).catch(() => {});
      shellAudioBefore = await page.evaluate(() => window.AegisAudio?.snapshot() || null);
      if (shellAudioBefore?.musicPlaying) {
        await page.click('#dock-audio');
        await page.waitForFunction(() => {
          const state = window.AegisAudio?.snapshot();
          return state?.muted && !state.musicPlaying && state.musicVoices === 0;
        }, { timeout: 10000 }).catch(() => {});
        shellAudioMuted = await page.evaluate(() => window.AegisAudio?.snapshot() || null);
        shellMuteStored = await page.evaluate(() => JSON.parse(localStorage.getItem('aegis.prefs') || '{}').muted);
        await page.click('#dock-audio');
        await page.waitForFunction(() => {
          const state = window.AegisAudio?.snapshot();
          return !state?.muted && state.musicPlaying;
        }, { timeout: 10000 }).catch(() => {});
        shellAudioUnmuted = await page.evaluate(() => window.AegisAudio?.snapshot() || null);
        shellUnmuteStored = await page.evaluate(() => JSON.parse(localStorage.getItem('aegis.prefs') || '{}').muted);
      }
    }
    if (selectWorld) {
      // Select the actual shell card before DEPLOY. The runtime assertions below
      // still require the engine to accept that ID and build its world, so a DOM
      // aria-state change alone can never masquerade as a successful handoff.
      shellWorldSelected = await page.evaluate((cardId) => {
        const card = document.getElementById(cardId);
        if (!card) return false;
        card.click();
        return card.getAttribute('aria-selected') === 'true';
      }, selectedWorldCard);
    }
    if (audioShellMode) await page.click('#hub-deploy');
    else await page.evaluate(() => document.getElementById('hub-deploy')?.click());
    if (audioShellMode) {
      await page.waitForFunction(() => {
        const state = window.AegisAudio?.snapshot();
        return state?.handedOff && state.musicVoices === 0;
      }, { timeout: 15000 }).catch(() => {});
      shellAudioHandoff = await page.evaluate(() => window.AegisAudio?.snapshot() || null);
    }
  }

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
  // When launched through the integrated shell (`/`), ENGINE_BANNER is already
  // logged during Opening preparation before `#hub-deploy` starts the world.
  // Wait for `revealCanvas()` (`mode === 'playing'` and `#app` hidden) before
  // sampling `elementFromPoint` on large 1280x720 SwiftShader viewports.
  if (booted && isFrontEnd) {
    await page
      .waitForFunction(
        () =>
          document.body?.dataset?.mode === 'playing' &&
          getComputedStyle(document.getElementById('app')).display === 'none',
        { polling: 100, timeout: bootTimeoutMs },
      )
      .catch(() => {});
  }
  // give the first frames a moment to render before inspecting the canvas
  if (booted) await new Promise((r) => setTimeout(r, 5000));
  if (audioShellMode && isFrontEnd) {
    shellAudioAfter = await page.evaluate(() => window.AegisAudio?.snapshot() || null);
  }

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

  const shellProgressMirror = isFrontEnd
    ? await page.evaluate(() => {
        try {
          return JSON.parse(localStorage.getItem('aegis.progress') || 'null');
        } catch {
          return null;
        }
      })
    : null;

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
      await page.keyboard.press('Escape');
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
  const worldControlCenter = (label) => {
    const line = [...consoleLines]
      .reverse()
      .find((entry) => entry.includes('Menu QA:') && entry.includes('STAGE=WORLD'));
    if (!line) return null;
    const physical = line.match(/PHYSICAL=(\d+)x(\d+)/);
    const rect = line.match(new RegExp(`(?:^|[|\\s])${label}=(\\d+),(\\d+),(\\d+)x(\\d+)`));
    if (!physical || !rect) return null;
    return {
      x: Number(rect[1]) + Number(rect[3]) / 2,
      y: Number(rect[2]) + Number(rect[4]) / 2,
      physicalWidth: Number(physical[1]),
      physicalHeight: Number(physical[2]),
    };
  };

  const clickWorldControl = async (label) => {
    let center = null;
    // FrontEnd prints Menu QA two frames after entering WORLD. Wait for that
    // measurement rather than clicking wherever the previous layout happened
    // to put the same button.
    for (let attempt = 0; attempt < 40 && !center; attempt += 1) {
      center = worldControlCenter(label);
      if (!center) await new Promise((resolve) => setTimeout(resolve, 250));
    }
    if (!center) {
      progress(`  WORLD selection: no measured rect for ${label}`);
      return false;
    }
    const point = await page.evaluate((measured) => {
      const bounds = document.querySelector('canvas')?.getBoundingClientRect();
      if (!bounds || !measured.physicalWidth || !measured.physicalHeight) return null;
      return {
        x: bounds.x + (measured.x / measured.physicalWidth) * bounds.width,
        y: bounds.y + (measured.y / measured.physicalHeight) * bounds.height,
      };
    }, center);
    if (!point) return false;
    await page.mouse.click(point.x, point.y);
    return true;
  };

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
    for (
      let i = 0;
      i < 240 && !reached() && !/stage (CHAPTER|DASHBOARD|HERO|WEAPON|WORLD|PRELOAD)/.test(stageLine());
      i += 1
    ) {
      // The root shell now hands straight to gameplay, so there is no engine
      // stage line to wait for. Raw engine/deep-link journeys still use stages.
      await new Promise((r) => setTimeout(r, 1000));
    }
    if (!reached()) progress(`  journey: front-end at ${stageLine().trim() || '(no stage yet)'}`);
    let worldSelectionHandled = false;
    for (let press = 0; press < 16 && !reached(); press += 1) {
      const before = stageLine();
      if (selectWorld && /stage WORLD/.test(before) && !worldSelectionHandled) {
        // Keyboard focus is not a reliable selector in headless Chromium, and
        // fixed fractions silently selected Neon after the UI layout changed.
        // Click the real measured pin, require its selection log, then click
        // the real measured LAUNCH rect. A miss fails before a default world
        // can be presented as the selected theatre.
        const worldFrame = path.join(outDir, `${slug}-${viewport.spec}-world-select.png`);
        await page.screenshot({ path: worldFrame });
        if (!(await clickWorldControl(selectedWorldPin))) return false;
        const selectionText = `FrontEnd: world selected ${selectedWorld}`;
        const selected = await awaitConsoleText(page, consoleLines, selectionText, 10000);
        if (!selected) {
          progress(`  WORLD selection: ${selectedWorldPin} did not select ${selectedWorld}`);
          return false;
        }
        const selectedFrame = path.join(outDir, `${slug}-${viewport.spec}-world-selected.png`);
        await page.screenshot({ path: selectedFrame });
        if (!(await clickWorldControl('LAUNCH'))) return false;
        worldSelectionHandled = true;
        await awaitConsoleText(page, consoleLines, 'FrontEnd: stage PRELOAD', 10000);
        continue;
      }
      // Enter first: a stage built while the window already had focus owns it.
      await page.keyboard.press('Enter');
      await new Promise((r) => setTimeout(r, 1000));
      // A stage transition and its console line are asynchronous. Check before
      // every fallback so a late Escape cannot pause newly reached gameplay
      // and poison subsequent Explore/Defense screenshots.
      if (reached()) break;
      if (stageLine() === before) {
        // Fall back to the focus ring. grab_focus() cannot take effect while
        // the Godot window has no keyboard focus, and headless Chromium only
        // hands it over on a click — so a stage created before that click
        // (the first one, CHAPTER) has no focused control at all.
        await page.keyboard.press('Tab');
        await page.keyboard.press('Enter');
        await new Promise((r) => setTimeout(r, 1000));
        if (reached()) break;
      }
      if (stageLine() === before) {
        // Still nothing: a panel may be open on top of the stage.
        await page.keyboard.press('Escape');
        await new Promise((r) => setTimeout(r, 400));
      }
    }
    if (!reached()) progress(`  journey stalled at: ${stageLine().trim() || '(unknown)'}`);
    return reached();
  };

  // Reach gameplay before any encounter input or screenshots. Running this
  // after the encounter block photographed menus and sent B to the front end.
  let inGameplay = false;
  if (booted && (journeyMode || tourMode || encounterMode || playSeconds > 0 || adsMode || upgradesMode)) {
    inGameplay = await advanceToGameplay();
  }

  /* ---------- measured mouse / multi-touch ADS on the equipped weapon ---------- */
  const adsFrames = [];
  let adsEvidence = null;
  if (booted && adsMode && inGameplay && state.canvasHittable) {
    const canvasBox = await page.evaluate(() => {
      const canvas = document.querySelector('canvas');
      const rect = canvas?.getBoundingClientRect();
      return rect
        ? {
            x: rect.x,
            y: rect.y,
            width: rect.width,
            height: rect.height,
            bufferWidth: canvas.width,
            bufferHeight: canvas.height,
          }
        : null;
    });
    const parseCamera = (line) => {
      const match = line.match(
        /Camera QA: aim=(true|false) blend=([\d.]+) fov=([\d.]+).*weapon=([a-z_]+) yaw=(-?[\d.]+) pitch=(-?[\d.]+)/,
      );
      return match
        ? {
            aim: match[1] === 'true',
            blend: Number(match[2]),
            fov: Number(match[3]),
            weapon: match[4],
            yaw: Number(match[5]),
            pitch: Number(match[6]),
          }
        : null;
    };
    const waitCamera = async (mark, predicate, timeout = 60000) => {
      const deadline = Date.now() + timeout;
      while (Date.now() < deadline) {
        const states = consoleLines.slice(mark).map(parseCamera).filter(Boolean);
        if (states.length && predicate(states.at(-1))) return states.at(-1);
        await new Promise((resolve) => setTimeout(resolve, 250));
      }
      return null;
    };
    const captureAds = async (name) => {
      const file = path.join(outDir, `${slug}-${viewport.spec}-ads-${name}.png`);
      await page.screenshot({ path: file });
      adsFrames.push(path.relative(ROOT, file));
    };
    if (canvasBox) {
      // Focus/audio gesture on the real canvas before either input family.
      await page.mouse.click(canvasBox.x + canvasBox.width * 0.5, canvasBox.y + canvasBox.height * 0.5);
      if (has('--touch')) {
        const deadline = Date.now() + 45000;
        let aimRect = null;
        while (Date.now() < deadline && !aimRect) {
          const line = consoleLines.filter((item) => item.includes('Touch QA:') && item.includes(' ADS=')).at(-1);
          const match = line?.match(/\bADS=(-?\d+),(-?\d+),(-?\d+)x(-?\d+)\b/);
          if (match) {
            aimRect = { x: Number(match[1]), y: Number(match[2]), width: Number(match[3]), height: Number(match[4]) };
          } else {
            await new Promise((resolve) => setTimeout(resolve, 250));
          }
        }
        if (!aimRect) {
          adsEvidence = {
            input: 'touch',
            weapon: null,
            aimRect: null,
            aimed: false,
            settledBlend: 0,
            lookChanged: false,
            released: false,
            error: 'No measured ADS rect in Touch QA',
          };
        }
        if (aimRect) {
          const scaleX = canvasBox.width / canvasBox.bufferWidth;
          const scaleY = canvasBox.height / canvasBox.bufferHeight;
          const aimPoint = {
            x: canvasBox.x + (aimRect.x + aimRect.width / 2) * scaleX,
            y: canvasBox.y + (aimRect.y + aimRect.height / 2) * scaleY,
            id: 11,
          };
          const lookPoint = {
            x: canvasBox.x + canvasBox.width * 0.5,
            y: canvasBox.y + canvasBox.height * 0.6,
            id: 12,
          };
          const cdp = await page.target().createCDPSession();
          let mark = consoleLines.length;
          await cdp.send('Input.dispatchTouchEvent', { type: 'touchStart', touchPoints: [aimPoint] });
          const aimed = await waitCamera(mark, (camera) => camera.aim && camera.blend >= 0.95);
          await captureAds('touch-hold');
          let moved = null;
          if (aimed) {
            await cdp.send('Input.dispatchTouchEvent', { type: 'touchStart', touchPoints: [aimPoint, lookPoint] });
            mark = consoleLines.length;
            await cdp.send('Input.dispatchTouchEvent', {
              type: 'touchMove',
              touchPoints: [aimPoint, { ...lookPoint, x: lookPoint.x + 36, y: lookPoint.y - 18 }],
            });
            moved = await waitCamera(
              mark,
              (camera) => Math.abs(camera.yaw - aimed.yaw) > 0.001 || Math.abs(camera.pitch - aimed.pitch) > 0.001,
            );
            await captureAds('touch-look');
          }
          mark = consoleLines.length;
          await cdp.send('Input.dispatchTouchEvent', { type: 'touchEnd', touchPoints: [] });
          const released = await waitCamera(mark, (camera) => !camera.aim);
          await captureAds('touch-release');
          await cdp.detach();
          adsEvidence = {
            input: 'touch',
            weapon: aimed?.weapon || null,
            aimRect,
            aimed: Boolean(aimed),
            settledBlend: aimed?.blend || 0,
            lookChanged: Boolean(moved),
            released: Boolean(released),
            before: aimed,
            after: moved,
          };
        }
      } else {
        const centre = { x: canvasBox.x + canvasBox.width / 2, y: canvasBox.y + canvasBox.height / 2 };
        let mark = consoleLines.length;
        await page.mouse.move(centre.x, centre.y);
        await page.mouse.down({ button: 'right' });
        const aimed = await waitCamera(mark, (camera) => camera.aim && camera.blend >= 0.95);
        const pointerLock = await page.evaluate(() => document.pointerLockElement?.tagName || 'none');
        await captureAds('mouse-hold');
        let moved = null;
        let lookOrigin = null;
        let lookPointerLock = null;
        let aimAfterUnlock = false;
        if (aimed) {
          // CDP mouse events do not carry Web movementX/Y while pointer lock is
          // active. Verify hold under the browser's chosen lock state, then
          // explicitly exercise the supported no-lock fallback without letting
          // go of right mouse. ADS must remain active across that transition.
          await page.evaluate(() => document.exitPointerLock?.());
          await page
            .waitForFunction(() => document.pointerLockElement === null, { timeout: 5000 })
            .catch(() => {});
          lookPointerLock = await page.evaluate(() => document.pointerLockElement?.tagName || 'none');
          const fallbackMark = consoleLines.length;
          lookOrigin = await waitCamera(fallbackMark, (camera) => camera.aim && camera.blend >= 0.95, 45000);
          aimAfterUnlock = Boolean(lookOrigin) && lookPointerLock === 'none';
          mark = consoleLines.length;
          if (aimAfterUnlock) {
            for (let step = 1; step <= 6; step += 1) {
              await page.mouse.move(centre.x + step * 8, centre.y - step * 4);
              await new Promise((resolve) => setTimeout(resolve, 60));
            }
          }
          moved = await waitCamera(
            mark,
            (camera) =>
              lookOrigin &&
              (Math.abs(camera.yaw - lookOrigin.yaw) > 0.001 ||
                Math.abs(camera.pitch - lookOrigin.pitch) > 0.001),
          );
          await captureAds('mouse-look');
        }
        mark = consoleLines.length;
        await page.mouse.up({ button: 'right' });
        const released = await waitCamera(mark, (camera) => !camera.aim);
        await captureAds('mouse-release');
        adsEvidence = {
          input: 'mouse',
          weapon: aimed?.weapon || null,
          pointerLock,
          lookPointerLock,
          lookMode: 'relative-mouse-without-pointer-lock',
          aimAfterUnlock,
          aimed: Boolean(aimed),
          settledBlend: aimed?.blend || 0,
          lookChanged: Boolean(moved),
          released: Boolean(released),
          before: lookOrigin || aimed,
          after: moved,
        };
      }
    }
  }

  /* ---------- explicit Explore → Preparing → Defense check ---------- */
  const encounterFrames = [];
  let safeBeforeActivation = false;
  if (booted && encounterMode && inGameplay) {
    await new Promise((r) => setTimeout(r, exploreWaitMs));
    const transitions = consoleLines.filter((line) => line.includes('Encounter:'));
    const pausedBeforeActivation = consoleLines.some((line) => line.includes('HUD: paused'));
    safeBeforeActivation = transitions.some((line) => line.includes('Explore safe'))
      && !transitions.some((line) => line.includes('Defense started'))
      && !pausedBeforeActivation;
    const exploreFrame = path.join(outDir, `${slug}-${viewport.spec}-explore-idle.png`);
    await page.screenshot({ path: exploreFrame });
    encounterFrames.push(path.relative(ROOT, exploreFrame));
    const centre = await page.evaluate(() => {
      const rect = document.querySelector('canvas')?.getBoundingClientRect();
      return rect ? { x: rect.x + rect.width / 2, y: rect.y + rect.height / 2 } : null;
    });
    if (centre && safeBeforeActivation) {
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
    } else if (!safeBeforeActivation) {
      progress('  encounter: Defense input skipped because Explore was paused or no longer safe');
    }
  }

  /* ---------- real Verdant Recovery approach and guard activation ---------- */
  const recoveryFrames = [];
  let recoveryEvidence = null;
  if (booted && upgradesMode && inGameplay) {
    const canvasCentre = await page.evaluate(() => {
      const rect = document.querySelector('canvas')?.getBoundingClientRect();
      return rect ? { x: rect.x + rect.width / 2, y: rect.y + rect.height / 2 } : null;
    });
    if (canvasCentre) {
      await page.mouse.click(canvasCentre.x, canvasCentre.y);
      await new Promise((r) => setTimeout(r, 500));
      const readyFrame = path.join(outDir, `${slug}-${viewport.spec}-upgrade-ready.png`);
      await page.screenshot({ path: readyFrame });
      menuFrames.push(path.relative(ROOT, readyFrame));

      await page.keyboard.press('KeyV');
      await awaitConsoleText(page, consoleLines, 'HUD: run upgrades opened', 10000);
      await new Promise((r) => setTimeout(r, 600));
      const modalFrame = path.join(outDir, `${slug}-${viewport.spec}-upgrade-modal.png`);
      await page.screenshot({ path: modalFrame });
      menuFrames.push(path.relative(ROOT, modalFrame));

      await page.keyboard.press('Digit1');
      await new Promise((r) => setTimeout(r, 600));
      const appliedFrame = path.join(outDir, `${slug}-${viewport.spec}-upgrade-applied.png`);
      await page.screenshot({ path: appliedFrame });
      menuFrames.push(path.relative(ROOT, appliedFrame));

      await page.keyboard.press('KeyU');
      await new Promise((r) => setTimeout(r, 600));
      const armoryFrame = path.join(outDir, `${slug}-${viewport.spec}-armory.png`);
      await page.screenshot({ path: armoryFrame });
      menuFrames.push(path.relative(ROOT, armoryFrame));
      await page.keyboard.press('Escape');
      await new Promise((r) => setTimeout(r, 350));
    }
  }
  if (booted && recoveryMode && inGameplay) {
    const RECOVERY_CACHE_ID = 'aetherfall_primary_tech_cache';
    const canvas = await page.$('canvas');
    if (canvas) await canvas.click();
    const capture = async (name) => {
      const file = path.join(outDir, `${slug}-${viewport.spec}-recovery-${name}.png`);
      await page.screenshot({ path: file });
      recoveryFrames.push(path.relative(ROOT, file));
    };
    await capture('landing');
    const latestRecovery = () => {
      const line = [...consoleLines].reverse().find((entry) => entry.includes('Recovery QA:'));
      if (!line) return null;
      return {
        action: line.match(/\baction=([a-z]+)/)?.[1] || 'none',
        guards: Number(line.match(/\bguards=(\d+)/)?.[1] || 0),
        line,
      };
    };
    const latestPlayerPos = () => {
      const line = [...consoleLines].reverse().find((entry) => entry.includes('Camera QA:'));
      if (!line) return null;
      const m = line.match(/\bplayer=\(\s*(-?[0-9.]+),\s*(-?[0-9.]+),\s*(-?[0-9.]+)\s*\)/);
      if (!m) return null;
      const yaw = Number(line.match(/\byaw=(-?[0-9.]+)/)?.[1]);
      return {
        x: Number(m[1]),
        y: Number(m[2]),
        z: Number(m[3]),
        yaw: Number.isFinite(yaw) ? yaw : null,
      };
    };
    const waitNextPlayerPos = async (maxMs = 25000) => {
      const startLen = consoleLines.length;
      const deadline = Date.now() + maxMs;
      while (Date.now() < deadline) {
        if (consoleLines.slice(startLen).some((l) => l.includes('Camera QA:'))) {
          return latestPlayerPos();
        }
        await new Promise((r) => setTimeout(r, 40));
      }
      return latestPlayerPos();
    };
    const engageOffered = () => latestRecovery()?.action === 'engage';
    // Arrival Outpost spawn (-30, 1.2, 14) sits between Primary Arrival Outpost
    // (-34, 0.25, 12.7; x_max=-30.4) and Landing Ridge Berm (-26, 0.25, 13;
    // yaw=-28 deg, corners z=[10.56, 15.44]), with West Catwalk Ramp along z=8.0.
    // Self-calibrate msPerMeter from real Camera QA world coordinates and route
    // along the wide-open Southern Boulevard:
    //   (-30,14) -> (-28.5,14) -> (-28.5,16.5) -> (-21.5,16.5) -> (-21.5,10.2)
    // landing in the unobstructed East Plaza 3.0m from Outpost Cache (-24.5,10.5)
    // and 2.0-3.1m from both robot guards with >=0.71m clearance on every leg.
    let msPerMeter = 520;
    let calibratedRate = false;
    let pos = latestPlayerPos() || (await waitNextPlayerPos(25000));
    const driveAxis = async (axis, target, tol, maxMs, stopOnEngage = false) => {
      const deadline = Date.now() + maxMs;
      while (Date.now() < deadline && pos) {
        if (stopOnEngage && engageOffered()) break;
        const val = axis === 'x' ? pos.x : pos.z;
        const diff = target - val;
        if (Math.abs(diff) <= tol) break;
        const dir = diff > 0 ? 1 : -1;
        const key = axis === 'x'
          ? (dir > 0 ? 'KeyD' : 'KeyA')
          : (dir > 0 ? 'KeyS' : 'KeyW');
        if (Math.abs(diff) >= 1.35) {
          await page.keyboard.down(key);
          try {
            while (Date.now() < deadline) {
              if (stopOnEngage && engageOffered()) break;
              const cur = latestPlayerPos();
              if (cur) {
                pos = cur;
                const curVal = axis === 'x' ? cur.x : cur.z;
                if ((target - curVal) * dir <= 0.45) break;
              }
              await new Promise((r) => setTimeout(r, 30));
            }
          } finally {
            await page.keyboard.up(key).catch(() => {});
          }
          pos = await waitNextPlayerPos(25000);
        } else {
          const holdMs = !calibratedRate
            ? 240
            : Math.min(3000, Math.max(100, Math.round(Math.abs(diff) * msPerMeter * 0.7)));
          await page.keyboard.down(key);
          await new Promise((r) => setTimeout(r, holdMs));
          await page.keyboard.up(key).catch(() => {});
          pos = await waitNextPlayerPos(25000);
          if (pos) {
            const moved = Math.abs((axis === 'x' ? pos.x : pos.z) - val);
            if (moved >= 0.1) {
              msPerMeter = Math.min(4500, Math.max(140, Math.round(holdMs / moved)));
              calibratedRate = true;
            } else if (!calibratedRate) {
              msPerMeter = 1200;
              calibratedRate = true;
            }
          }
        }
      }
    };
    if (recoveryE2eMode) {
      await driveAxis('x', -28.5, 0.55, 60000);
      await driveAxis('z', 16.5, 0.65, 60000);
      await driveAxis('x', -21.5, 0.80, 75000);
      await driveAxis('z', 10.2, 0.75, 75000);
    } else {
      await driveAxis('x', -28.5, 0.55, 45000, true);
      await driveAxis('z', 11.2, 0.65, 45000, true);
    }
    if (!engageOffered()) {
      for (const [k1, ms] of [['KeyA', 650], ['KeyW', 550], ['KeyD', 650]]) {
        if (engageOffered()) break;
        await page.keyboard.down(k1);
        await new Promise((r) => setTimeout(r, ms));
        await page.keyboard.up(k1).catch(() => {});
        pos = await waitNextPlayerPos(4500);
      }
    }
    const engagePlayerPos = latestPlayerPos();
    recoveryEvidence = { engageOffered: engageOffered(), guardsActive: false, guardModels: [] };
    await capture('engage-offer');
    const beforeEngage = consoleLines.length;
    if (recoveryEvidence.engageOffered) {
      await page.keyboard.press('KeyB');
      recoveryEvidence.guardsActive = await awaitConsoleText(
        page, consoleLines.slice(beforeEngage), 'guards=2', 15000,
      );
      if (recoveryE2eMode && recoveryEvidence.guardsActive) {
        // Trigger EMP Pulse (9.0m AoE: 18 dmg + disrupt stun on both guards at
        // 2-3m range) immediately so Sable takes minimal hits during screenshot
        // capture, and turn east (+X) toward both robot guards (-18.5,9.2)/(-19.5,10.2).
        await page.keyboard.press('KeyF');
        await page.keyboard.down('ArrowRight');
        try {
          const turnDeadline = Date.now() + 9000;
          while (Date.now() < turnDeadline) {
            const latestTargetLine = [...consoleLines.slice(beforeEngage)]
              .reverse()
              .find((l) => l.includes('Recovery Target QA:'));
            if (latestTargetLine && latestTargetLine.includes('behind=no')) {
              const gx = Number(latestTargetLine.match(/\bx=(-?[0-9.]+)/)?.[1]);
              if (Number.isFinite(gx) && gx >= 220 && gx <= 1020) break;
            }
            await new Promise((r) => setTimeout(r, 45));
          }
        } finally {
          await page.keyboard.up('ArrowRight').catch(() => {});
        }
      }
      await new Promise((resolve) => setTimeout(resolve, 350));
    }
    await capture('guarded');
    if (recoveryEvidence.guardsActive) {
      await page.mouse.move(viewport.width * 0.52, viewport.height * 0.48);
      await page.mouse.down();
      await new Promise((resolve) => setTimeout(resolve, 450));
      await page.mouse.up();
      await new Promise((resolve) => setTimeout(resolve, 250));
      await capture('contact');
    }
    const models = new Set();
    const guardRegex = new RegExp(`EnemyVisual\\[(Guard_${RECOVERY_CACHE_ID}_[^\\]]+)\\].*fallback=no`);
    for (const line of consoleLines) {
      const match = line.match(guardRegex);
      if (match) models.add(match[1]);
    }
    recoveryEvidence.guardModels = [...models];
    recoveryEvidence.finalState = latestRecovery();
    const guardActivation = consoleLines.slice(beforeEngage).find(
      (line) => line.includes('Recovery QA:') && line.includes('action=none') && line.includes('guards=2'),
    );
    recoveryEvidence.secureLocked = recoveryEvidence.guardsActive
      && Boolean(guardActivation)
      && !consoleLines.some((line) => line.includes('Encounter: Preparing Defense'));

    if (recoveryE2eMode && recoveryEvidence.guardsActive) {
      const e2e = {
        initialVitals110: consoleLines.some((line) =>
          line.includes('Operative: hero=sable vitals=110 reduction=6%')),
        guidanceObserved: consoleLines.some((line) =>
          line.includes('Recovery QA:') && /\bguidance=(area|local|interact|combat)\b/.test(line)),
        cursorAimFired: false,
        guardsCleared: false,
        secureOffered: false,
        blueprintSecured: false,
        returnedToHub: false,
        mirrorSynced: false,
        heroTiersRemovedInDom: false,
        kestrelSelected: false,
        kestrelReadout: null,
        redeployedKestrelVitals96: false,
        redeployCachePersisted: false,
      };
      recoveryEvidence.e2e = e2e;
      let cdp = null;
      try {
      const parseVector = (raw) => {
        if (!raw || raw === 'none') return null;
        const parts = raw.split(',').map(Number);
        return parts.length === 2 && parts.every(Number.isFinite)
          ? { x: parts[0], y: parts[1] }
          : null;
      };
      const parseProjection = (prefix, afterIdx = 0) => {
        for (let i = consoleLines.length - 1; i >= afterIdx; i -= 1) {
          const entry = consoleLines[i];
          if (!entry.includes(prefix)) continue;
          const x = Number(entry.match(/\bx=(-?[0-9.]+)/)?.[1]);
          const y = Number(entry.match(/\by=(-?[0-9.]+)/)?.[1]);
          const behind = entry.match(/\bbehind=(yes|no)/)?.[1] || 'no';
          const dist = Number(entry.match(/\bdist=([0-9.]+)/)?.[1] ?? 'NaN');
          const vpMatch = entry.match(/\bvp=([0-9]+)x([0-9]+)/);
          if (!Number.isFinite(x) || !Number.isFinite(y)) continue;
          return {
            id: entry.match(/\bid=([^\s]+)/)?.[1] || '',
            x,
            y,
            behind: behind === 'yes',
            dist: Number.isFinite(dist) ? dist : null,
            vpW: vpMatch ? Number(vpMatch[1]) : viewport.width,
            vpH: vpMatch ? Number(vpMatch[2]) : viewport.height,
          };
        }
        return null;
      };
      const pickGuardSnapshot = (afterIdx = 0) => {
        const recNow = latestRecovery();
        const liveCount = recNow ? recNow.guards : 2;
        if (liveCount <= 0) return { target: null, anyClose: false };
        // If only 1 guard remains, ignore target telemetry printed before the
        // first `guards=1` line so a defeated guard's last frame is never chased.
        let floorIdx = afterIdx;
        if (liveCount === 1) {
          for (let i = consoleLines.length - 1; i >= afterIdx; i -= 1) {
            if (consoleLines[i].includes('Recovery QA:') && consoleLines[i].includes('guards=1')) {
              floorIdx = i;
              break;
            }
          }
        }
        const recent = new Map();
        for (let i = consoleLines.length - 1; i >= floorIdx && recent.size < liveCount; i -= 1) {
          const entry = consoleLines[i];
          if (!entry.includes('Recovery Target QA:')) continue;
          const id = entry.match(/\bid=([^\s]+)/)?.[1] || '';
          if (!id || recent.has(id)) continue;
          const x = Number(entry.match(/\bx=(-?[0-9.]+)/)?.[1]);
          const y = Number(entry.match(/\by=(-?[0-9.]+)/)?.[1]);
          const behind = entry.match(/\bbehind=(yes|no)/)?.[1] || 'no';
          const dist = Number(entry.match(/\bdist=([0-9.]+)/)?.[1] ?? 'NaN');
          const vpMatch = entry.match(/\bvp=([0-9]+)x([0-9]+)/);
          if (!Number.isFinite(x) || !Number.isFinite(y)) continue;
          recent.set(id, {
            id,
            x,
            y,
            behind: behind === 'yes',
            dist: Number.isFinite(dist) ? dist : null,
            vpW: vpMatch ? Number(vpMatch[1]) : viewport.width,
            vpH: vpMatch ? Number(vpMatch[2]) : viewport.height,
          });
        }
        if (!recent.size) return { target: null, anyClose: false };
        const all = [...recent.values()];
        const anyClose = all.some((g) =>
          (g.dist !== null ? g.dist < 4.5 : (!g.behind && g.y > 545)));
        all.sort((a, b) => {
          if (a.behind !== b.behind) return a.behind ? 1 : -1;
          const da = a.dist ?? 99;
          const db = b.dist ?? 99;
          return da - db;
        });
        return { target: all[0], anyClose };
      };
      cdp = await page.createCDPSession();
      const cdpMove = (x, y, buttons = 0) =>
        cdp.send('Input.dispatchMouseEvent', {
          type: 'mouseMoved',
          x: Math.round(x),
          y: Math.round(y),
          button: 'none',
          buttons,
        });
      const cdpButton = (type, x, y, button, buttons) =>
        cdp.send('Input.dispatchMouseEvent', {
          type,
          x: Math.round(x),
          y: Math.round(y),
          button,
          buttons,
          clickCount: 1,
        });

      const fpsScale = Math.min(4.2, Math.max(1.0, msPerMeter / 170));
      const waitEngineTick = async (maxMs = 8000) => {
        const startLen = consoleLines.length;
        const deadline = Date.now() + maxMs;
        while (Date.now() < deadline) {
          if (consoleLines.slice(startLen).some((l) => l.includes('Recovery Target QA:') || l.includes('Recovery QA:') || l.includes('Camera QA:'))) {
            return;
          }
          await new Promise((r) => setTimeout(r, 35));
        }
      };
      const turnCameraToward = async (proj) => {
        if (!proj) return;
        const cx = canvasBounds.left + canvasBounds.width * 0.5;
        const cy = canvasBounds.top + canvasBounds.height * 0.45;
        let dragX = 0;
        let dragY = 0;
        if (proj.behind) {
          dragX = 340;
        } else {
          const errX = proj.x - proj.vpW * 0.5;
          const errY = proj.y - proj.vpH * 0.44;
          dragX = Math.max(-360, Math.min(360, Math.round(errX * 0.38)));
          dragY = Math.max(-180, Math.min(180, Math.round(errY * 0.35)));
        }
        if (Math.abs(dragX) < 6 && Math.abs(dragY) < 6) return;
        await page.mouse.move(cx, cy);
        await page.mouse.down({ button: 'right' });
        await page.mouse.move(cx + dragX, cy + dragY, { steps: 4 });
        await page.mouse.up({ button: 'right' }).catch(() => {});
        await waitEngineTick(8000);
      };

      const canvasBounds = await page.evaluate(() => {
        const r = document.querySelector('canvas')?.getBoundingClientRect();
        return r
          ? { left: r.left, top: r.top, width: r.width || 1280, height: r.height || 720 }
          : { left: 0, top: 0, width: 1280, height: 720 };
      });
      const toCanvasCoords = (proj) => ({
        x: canvasBounds.left + proj.x * (canvasBounds.width / Math.max(1, proj.vpW)),
        y: canvasBounds.top + proj.y * (canvasBounds.height / Math.max(1, proj.vpH)),
      });
      const isInSafeReticleWindow = (g) => {
        if (!g || g.behind) return false;
        const overRightThumbRail = g.x > g.vpW - 195 && g.y > g.vpH - 235;
        const overTopSystemButtons = g.x > g.vpW - 220 && g.y < 90;
        return g.x >= 85
          && g.x <= g.vpW - 110
          && g.y >= 115
          && g.y <= g.vpH - 145
          && !overRightThumbRail
          && !overTopSystemButtons;
      };

      // 1. Defeat both live Arrival Tech Cache robot guards by placing the
      // movable [+] reticle directly over each guard's screen projection and
      // firing left-mouse bursts + EMP Pulse (only rotating camera when off-screen).
      const combatDeadline = Date.now() + 110000;
      e2e.engagePos = engagePlayerPos;
      let lastEmpAt = 0;
      let burstsSinceReload = 0;
      while (Date.now() < combatDeadline) {
        const rec = latestRecovery();
        const readySeen = consoleLines
          .slice(beforeEngage)
          .some((l) => l.includes('Recovery QA:') && l.includes('guards=0'));
        if ((rec && rec.guards === 0) || readySeen) {
          e2e.guardsCleared = true;
          break;
        }
        await waitEngineTick(8000);
        const snap = pickGuardSnapshot(beforeEngage);
        const guard = snap.target;
        if (Date.now() - lastEmpAt > 4000 && (snap.anyClose || (guard?.dist !== null && guard?.dist !== undefined && guard.dist <= 8.9))) {
          await page.keyboard.press('KeyF', { delay: 450 });
          lastEmpAt = Date.now();
        }
        if (!guard) continue;
        if (!isInSafeReticleWindow(guard)) {
          await turnCameraToward(guard);
          continue;
        }
        if (guard.dist !== null && guard.dist > 11.5 && Math.abs(guard.x - guard.vpW * 0.5) < 220) {
          await page.keyboard.down('KeyW');
          await new Promise((r) => setTimeout(r, Math.min(900, Math.round(msPerMeter * 1.4))));
          await page.keyboard.up('KeyW').catch(() => {});
          await waitEngineTick(8000);
          continue;
        }
        // Place the movable [+] crosshair directly onto the guard's 3D screen
        // coordinates and fire a left-mouse burst straight at [+], tracking the
        // live guard projection mid-burst via Puppeteer's unified mouse state!
        let pt = toCanvasCoords(guard);
        await page.mouse.move(pt.x, pt.y);
        await new Promise((r) => setTimeout(r, 110));
        await page.mouse.down({ button: 'left' });
        e2e.cursorAimFired = true;
        try {
          for (let sub = 0; sub < 3; sub += 1) {
            await new Promise((r) => setTimeout(r, 620));
            if ((latestRecovery()?.guards ?? 2) === 0) break;
            const liveSnap = pickGuardSnapshot(beforeEngage);
            if (liveSnap.target && isInSafeReticleWindow(liveSnap.target)) {
              pt = toCanvasCoords(liveSnap.target);
              await page.mouse.move(pt.x, pt.y);
            }
          }
        } finally {
          await page.mouse.up({ button: 'left' }).catch(() => {});
        }
        await new Promise((r) => setTimeout(r, 90));
        burstsSinceReload += 1;
        if (burstsSinceReload >= 6) {
          await page.keyboard.press('KeyG', { delay: 450 });
          burstsSinceReload = 0;
        }
      }
      e2e.postCombatPos = latestPlayerPos();
      e2e.lastGuard = pickGuardSnapshot(beforeEngage).target;
      e2e.playerDown = consoleLines
        .slice(beforeEngage)
        .some((l) => l.includes('Encounter: Defeated') || l.includes('HUD: player down'));

      // 2. Approach the now-READY Arrival Tech Cache and press B to Secure.
      if (e2e.guardsCleared) {
        const waitReadyCacheTick = async (maxMs = 1800) => {
          const startIdx = consoleLines.length;
          const deadline = Date.now() + maxMs;
          while (Date.now() < deadline) {
            if (latestRecovery()?.action === 'secure') return null;
            const fresh = parseProjection(`Recovery Cache QA: id=${RECOVERY_CACHE_ID}`, startIdx);
            if (fresh) return fresh;
            await new Promise((r) => setTimeout(r, 45));
          }
          return parseProjection(`Recovery Cache QA: id=${RECOVERY_CACHE_ID}`, Math.max(0, startIdx - 6));
        };
        const approachDeadline = Date.now() + 45000;
        while (Date.now() < approachDeadline) {
          if (latestRecovery()?.action === 'secure') {
            e2e.secureOffered = true;
            break;
          }
          const proj = await waitReadyCacheTick(1400);
          if (latestRecovery()?.action === 'secure') {
            e2e.secureOffered = true;
            break;
          }
          if (proj && (proj.behind || Math.abs(proj.x - proj.vpW * 0.5) > 95)) {
            await turnCameraToward(proj);
            continue;
          }
          await page.keyboard.down('KeyW');
          try {
            const strideEnd = Date.now() + 550;
            while (Date.now() < strideEnd) {
              if (latestRecovery()?.action === 'secure') {
                e2e.secureOffered = true;
                break;
              }
              await new Promise((r) => setTimeout(r, 45));
            }
          } finally {
            await page.keyboard.up('KeyW').catch(() => {});
          }
        }
      }
      await capture('ready-to-secure');

      // 3. Explicit Secure -> persists Phase Thrusters schematic + 45 permanent BP.
      const beforeSecure = consoleLines.length;
      if (e2e.secureOffered) {
        await page.keyboard.press('KeyB', { delay: 450 });
        e2e.blueprintSecured = await awaitConsoleText(
          page,
          consoleLines.slice(beforeSecure),
          `Recovery: secured ${RECOVERY_CACHE_ID} · reward phase_thrusters_blueprint`,
          25000,
        );
        // Allow Emscripten IDBFS + ProgressionService localStorage sync to flush.
        await new Promise((r) => setTimeout(r, 1800));
      }
      await capture('cache-secured');

      // 4. Open Pause menu -> Return HOME -> Shell Hub -> Verify Hero Tiers removed ->
      // Select Scout Kestrel (96 HP / 4% DR) -> Redeploy into SH-01 Aetherfall.
      const clickCanvasPoint = async (pt) => {
        const px = canvasBounds.left + pt.x;
        const py = canvasBounds.top + pt.y;
        await page.mouse.move(px, py);
        await new Promise((r) => setTimeout(r, 120));
        await page.mouse.down({ button: 'left' });
        await new Promise((r) => setTimeout(r, 150));
        await page.mouse.up({ button: 'left' });
      };
      if (e2e.blueprintSecured && isFrontEnd) {
        const beforePause = consoleLines.length;
        await page.keyboard.press('Escape', { delay: 300 });
        await awaitConsoleText(page, consoleLines.slice(beforePause), 'Pause QA:', 25000);
        await capture('pause-menu');
        const pauseLine = [...consoleLines.slice(beforePause)]
          .reverse()
          .find((l) => l.includes('Pause QA:'));
        const pauseHomePt = parseVector(pauseLine?.match(/\bhome=([^\s]+)/)?.[1]);
        // Pause focuses ResumeButton; three Tabs deterministically select
        // PauseHomeButton (Resume -> Restart -> Settings -> PauseHome).
        await page.keyboard.press('Tab', { delay: 200 }).catch(() => {});
        await new Promise((r) => setTimeout(r, 500));
        await page.keyboard.press('Tab', { delay: 200 }).catch(() => {});
        await new Promise((r) => setTimeout(r, 500));
        await page.keyboard.press('Tab', { delay: 200 }).catch(() => {});
        await new Promise((r) => setTimeout(r, 500));
        await page.keyboard.press('Enter', { delay: 250 }).catch(() => {});

        const hubDeadline = Date.now() + 45000;
        const fallbackAt = Date.now() + 4500;
        let triedClickFallback = false;
        while (Date.now() < hubDeadline) {
          const onHub = await page.evaluate(
            () =>
              document.body?.dataset?.screen === 'hub'
              && document.body?.dataset?.mode !== 'playing'
              && typeof window.AegisShell === 'object',
          ).catch(() => false);
          if (onHub) {
            e2e.returnedToHub = true;
            break;
          }
          if (!triedClickFallback && Date.now() >= fallbackAt) {
            triedClickFallback = true;
            if (pauseHomePt && pauseHomePt.x > 5 && pauseHomePt.y > 5) {
              await clickCanvasPoint(pauseHomePt).catch(() => {});
            }
          }
          await new Promise((r) => setTimeout(r, 300));
        }
        if (cdp) {
          await cdp.detach().catch(() => {});
          cdp = null;
        }

        if (e2e.returnedToHub) {
          const mirrorCheck = await page.evaluate((cacheId) => {
            let progress = null;
            try {
              progress = JSON.parse(localStorage.getItem('aegis.progress') || 'null');
            } catch {
              progress = null;
            }
            const modBps = progress?.module_blueprints;
            const hasPhase = Array.isArray(modBps)
              ? modBps.includes('phase_thrusters')
              : Boolean(modBps?.phase_thrusters);
            return {
              balance: Number(progress?.balance ?? 0),
              hasPhase,
              cacheSecured: Boolean(progress?.secured_caches?.[cacheId]),
            };
          }, RECOVERY_CACHE_ID);
          e2e.mirrorCheck = mirrorCheck;
          e2e.mirrorSynced = mirrorCheck.balance >= 45
            && mirrorCheck.hasPhase
            && mirrorCheck.cacheSecured;

          await page.evaluate(() => document.getElementById('hub-card-operative')?.click());
          await page.waitForFunction(
            () => document.body?.dataset?.screen === 'hero'
              && document.getElementById('screen-hero')?.dataset?.ready === 'true',
            { polling: 100, timeout: 60000 },
          ).catch(() => {});
          await new Promise((r) => setTimeout(r, 450));
          const sableReadout = await page.evaluate(() => ({
            tierSteps: document.querySelectorAll('#hero-tiers .tierstep').length,
            vitals: document.getElementById('hero-stat-vitals')?.textContent?.trim() || '',
            armour: document.getElementById('hero-stat-armour')?.textContent?.trim() || '',
          }));
          e2e.heroTiersRemovedInDom = sableReadout.tierSteps === 0
            && sableReadout.vitals === '110'
            && sableReadout.armour === '6%';
          await capture('operative-sable-tierfree');

          await page.evaluate(() =>
            document.querySelector('#hero-roster [data-hero="kestrel"]')?.click());
          await new Promise((r) => setTimeout(r, 500));
          const kestrelReadout = await page.evaluate(() => ({
            vitals: document.getElementById('hero-stat-vitals')?.textContent?.trim() || '',
            armour: document.getElementById('hero-stat-armour')?.textContent?.trim() || '',
          }));
          e2e.kestrelReadout = kestrelReadout;
          e2e.kestrelSelected = kestrelReadout.vitals === '96' && kestrelReadout.armour === '4%';
          await capture('operative-kestrel-96hp');

          await page.evaluate(() => document.getElementById('hero-next')?.click());
          await page.waitForFunction(() => document.body?.dataset?.screen === 'hub', { timeout: 15000 }).catch(() => {});
          await capture('hub-kestrel-ready');
          await page.evaluate(() => {
            document.getElementById('world-card-aetherfall')?.click();
          });
          const beforeRedeploy = consoleLines.length;
          await page.evaluate(() => document.getElementById('hub-deploy')?.click());
          e2e.redeployedKestrelVitals96 = await awaitConsoleText(
            page,
            consoleLines.slice(beforeRedeploy),
            'Operative: hero=kestrel vitals=96 reduction=4%',
            Math.max(150000, bootTimeoutMs),
          );
          await awaitConsoleText(page, consoleLines.slice(beforeRedeploy), 'Recovery QA:', 45000);
          await page
            .waitForFunction(() => document.body?.dataset?.mode === 'playing', { polling: 100, timeout: 45000 })
            .catch(() => {});
          await new Promise((r) => setTimeout(r, 2000));
          e2e.redeployCachePersisted = consoleLines
            .slice(beforeRedeploy)
            .some((l) => l.includes('Recovery QA:') && l.includes('HORIZON RELAY'));
          await capture('redeploy-kestrel-96hp');
        }
      }
      } catch (e2eErr) {
        e2e.error = String(e2eErr?.stack || e2eErr).slice(0, 400);
      } finally {
        if (cdp) await cdp.detach().catch(() => {});
      }
      recoveryEvidence.e2e = e2e;
    }
  }

  /* ---------- walk the front end to the gameplay scene ---------- */
  // A play pass acts on the *gameplay* scene, so it needs the journey walked
  // even when no tour or encounter was asked for. Before this, `--play` on its
  // own clicked the centre of whichever menu stage was on screen: the shot
  // check could never pass, which is worse than no check
  // (docs/DECISIONS.md §12.3, the same defect as the tour
  // photographing the menu).
  /* ---------- optional play pass ---------- */
  const frames = [];
  if (booted && playSeconds > 0 && inGameplay && state.canvasHittable) {
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
      if (audioShellMode && isFrontEnd) {
        gameplayMuteStored = await page.evaluate(() => JSON.parse(localStorage.getItem('aegis.prefs') || '{}').muted);
      }
      await page.keyboard.press('KeyM');
      await awaitConsoleText(page, consoleLines, 'Audio: unmuted', 30000);
      if (audioShellMode && isFrontEnd) {
        gameplayUnmuteStored = await page.evaluate(() => JSON.parse(localStorage.getItem('aegis.prefs') || '{}').muted);
      }
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
    if (!engaged) progress('  tour: the review camera did not engage (no World tour: log line)');
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
  await safeClosePage(page);

  const audioLines = consoleLines.filter((line) => line.includes('Audio:'));
  const menuLines = consoleLines.filter((line) => line.includes('HUD: '));
  const scriptErrors = consoleLines.filter((line) => /SCRIPT ERROR:|Parse Error:|ERROR: String formatting error/.test(line));

  const checks = [
    ['engine booted (console banner)', booted],
    ['no Godot script/parse/format errors', scriptErrors.length === 0],
    ['no page errors', pageErrors.length === 0],
    ['no failed requests', failedRequests.length === 0],
    ['no HTTP 4xx/5xx for page assets', badResponses.length === 0],
    ['a canvas exists', state.hasCanvas],
    ['canvas is not the 300x150 default', state.canvasSize !== '300x150'],
    ['canvas accepts pointer input (no transparent loading overlay)', state.canvasHittable === true],
    ['WebGL context alive', state.glContext === true && state.glLost === false],
    ['no failure card shown', state.failureVisible === false],
  ];
  if (isFrontEnd) {
    checks.push([
      'HERO shows the real rig and its authored celebration before the theatre map',
      shellHeroStage?.ready === true
        && shellHeroStage?.model === './game/assets/characters/human_hero_tiers/hero_human_tier_1.glb'
        && shellHeroStage?.heroId === 'sable'
        && shellHeroStage?.clips?.includes('idle')
        && shellHeroStage?.celebration === 'celebration',
    ]);
    checks.push([
      'engine profile mirror is a readable object with weapon ownership and tiers',
      shellProgressMirror
        && Array.isArray(shellProgressMirror.unlocked)
        && shellProgressMirror.weapon_tiers
        && typeof shellProgressMirror.weapon_tiers === 'object'
        && !Array.isArray(shellProgressMirror.weapon_tiers),
    ]);
  }
  if (audioShellMode && isFrontEnd) {
    checks.push([
      'the HERO scene keeps one shared shell theme after a real gesture',
      shellAudioHero?.scene === 'hero'
        && shellAudioHero?.unlocked === true
        && shellAudioHero?.musicPlaying === true
        && shellAudioHero?.musicVoices === 1,
    ]);
    checks.push([
      'a real gesture unlocked the shared shell theme and all four buffers',
      shellAudioBefore?.unlocked === true
        && shellAudioBefore?.musicPlaying === true
        && shellAudioBefore?.loaded?.length === 4,
    ]);
    checks.push([
      'shell mute stops music and persists aegis.prefs.muted=true',
      shellAudioMuted?.muted === true
        && shellAudioMuted?.musicVoices === 0
        && shellMuteStored === true,
    ]);
    checks.push([
      'shell unmute restarts one theme and persists muted=false',
      shellAudioUnmuted?.muted === false
        && shellAudioUnmuted?.musicPlaying === true
        && shellAudioUnmuted?.musicVoices === 1
        && shellUnmuteStored === false,
    ]);
    checks.push([
      'DEPLOY retires every shell music voice before Godot starts',
      shellAudioHandoff?.handedOff === true && shellAudioHandoff?.musicVoices === 0,
    ]);
    checks.push([
      'Godot music owns gameplay without a shell music voice',
      shellAudioAfter?.handedOff === true
        && shellAudioAfter?.musicVoices === 0
        && audioLines.some((line) => /Audio: .*music=on/.test(line)),
    ]);
    if (playSeconds > 0) {
      checks.push([
        'Godot HUD mute/unmute mirrors the shared shell preference',
        gameplayMuteStored === true && gameplayUnmuteStored === false,
      ]);
    }
  }
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
  if (journeyMode) {
    checks.push(['front-end handoff reached the gameplay scene', inGameplay]);
  }
  if (adsMode) {
    checks.push(['ADS pass reached live gameplay', inGameplay]);
    checks.push(['ADS entered and settled on the equipped weapon', adsEvidence?.aimed === true]);
    checks.push(['ADS mouse/touch look changed camera yaw or pitch', adsEvidence?.lookChanged === true]);
    if (adsEvidence?.input === 'mouse') {
      checks.push(['ADS right-mouse hold survives pointer-lock exit', adsEvidence?.aimAfterUnlock === true]);
    }
    checks.push(['ADS release restored the unaimed state', adsEvidence?.released === true]);
    checks.push(['ADS hold/look/release frames were captured', adsFrames.length === 3]);
  }
  if (recoveryMode) {
    checks.push(['Recovery pass reached SH-01 Aetherfall gameplay', inGameplay && selectedWorld === 'aetherfall']);
    checks.push(['Arrival Tech Cache offered explicit Engage in interaction range', recoveryEvidence?.engageOffered === true]);
    checks.push(['Engage produced two live Recovery robot guards', recoveryEvidence?.guardsActive === true]);
    checks.push(['both Recovery guards loaded rigged 3D robot GLBs without fallback', recoveryEvidence?.guardModels?.length === 2]);
    checks.push(['active guards kept Secure locked and blocked generic Defense', recoveryEvidence?.secureLocked === true]);
    checks.push([
      recoveryE2eMode
        ? 'Recovery E2E frames captured across combat, secure, pause, tier-free Kestrel switch, and redeploy'
        : 'Recovery landing, offer, guarded and contact frames were captured',
      recoveryE2eMode ? recoveryFrames.length >= 8 : recoveryFrames.length === 4,
    ]);
    if (recoveryE2eMode) {
      const e2e = recoveryEvidence?.e2e;
      checks.push(['Run 1 spawned Sable with canonical tier-free 110 vitals and 6% armor', e2e?.initialVitals110 === true]);
      checks.push(['Escalating directional guidance reported active stage in HUD', e2e?.guidanceObserved === true]);
      checks.push(['Movable [+] cursor crosshair aimed and defeated both 3D robot guards', e2e?.cursorAimFired === true && e2e?.guardsCleared === true]);
      checks.push(['Arrival Tech Cache transitioned to explicit Secure offer after guard clear', e2e?.secureOffered === true]);
      checks.push(['Explicit Secure persisted Phase Thrusters schematic and 45 permanent BP', e2e?.blueprintSecured === true]);
      checks.push(['Pause HOME returned to shell Hub with synced localStorage progress', e2e?.returnedToHub === true && e2e?.mirrorSynced === true]);
      checks.push(['Web Hub Operative stage has zero Hero Tier controls and shows Sable 110 HP / 6% DR', e2e?.heroTiersRemovedInDom === true]);
      checks.push(['Selecting Scout Kestrel updates Web Hub vitals to 96 HP and 4% armor', e2e?.kestrelSelected === true]);
      checks.push(['Redeploy spawned Kestrel at 96 vitals and preserved Aetherfall cache state', e2e?.redeployedKestrelVitals96 === true && e2e?.redeployCachePersisted === true]);
    }
  }
  if (selectWorld) {
    if (isFrontEnd) {
      checks.push([`shell ${selectedWorld} card was selected before DEPLOY`, shellWorldSelected === true]);
    }
    const selectionLog = isFrontEnd
      ? `FrontEnd: qa_world selected ${selectedWorld}`
      : `FrontEnd: world selected ${selectedWorld}`;
    checks.push([
      isFrontEnd ? `engine accepted the shell ${selectedWorld} selection` : `WORLD pin selected ${selectedWorld} before launch`,
      consoleLines.some((line) => line.includes(selectionLog)),
    ]);
    checks.push([
      `front-end selection built ${selectedWorld} gameplay`,
      inGameplay && consoleLines.some((line) => line.includes(selectedWorldBuildLog)),
    ]);
    checks.push([
      isFrontEnd ? 'shell DEPLOY bypassed the engine WORLD stage' : 'engine journey offered the WORLD stage',
      isFrontEnd
        ? !consoleLines.some((line) => line.includes('FrontEnd: stage WORLD'))
        : consoleLines.some((line) => line.includes('FrontEnd: stage WORLD')),
    ]);
  }
  if (encounterMode) {
    checks.push(['front-end journey reached gameplay before encounter input', inGameplay]);
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
      'ESC resumed the game',
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
    url: url.toString(),
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
    recovery: recoveryEvidence,
    recoveryFrames,
    recoveryTransitions: consoleLines.filter((line) => line.includes('Recovery QA:') || line.includes('Recovery:')),
    audio: audioLines,
    heroStage: shellHeroStage,
    profileMirror: shellProgressMirror,
    ads: adsEvidence,
    adsFrames,
    shellAudio: {
      hero: shellAudioHero,
      before: shellAudioBefore,
      muted: shellAudioMuted,
      unmuted: shellAudioUnmuted,
      handoff: shellAudioHandoff,
      after: shellAudioAfter,
      muteStored: shellMuteStored,
      unmuteStored: shellUnmuteStored,
      gameplayMuteStored,
      gameplayUnmuteStored,
    },
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
  if (server) {
    try {
      server.kill('SIGKILL');
    } catch {
      // ignore already-exited server
    }
  }
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
