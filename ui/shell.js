/*
 * Player shell: opening -> hub -> deploy -> gameplay.
 *
 * Why this exists as its own layer: the web build used to open on an engine
 * splash and a debug chip bar. A player's first seconds are the opening of the
 * game, not the start of a download, so the front end of the *player journey*
 * lives here, in HTML, with the engine booting behind it only once the player
 * has pressed Deploy. HOME is this shell, once: the engine's own board is not
 * shown after it, which is why the hand-off goes straight into the world.
 *
 * Three rules it keeps:
 *   1. Nothing on screen is invented. Progress is the engine's byte count, the
 *      "sector available" line is a real request for the payload, and the
 *      input/viewport readouts are measured.
 *   2. It never shows engine chrome: no module names, no version banner, no
 *      "WebAssembly" wording anywhere in the opening.
 *   3. Every screen is reachable by keyboard, works in portrait and landscape,
 *      and honours reduced motion.
 */
'use strict';

const SCREENS = ['opening', 'hub', 'settings', 'launch'];
const params = new URLSearchParams(location.search);

const el = (id) => document.getElementById(id);
const screens = Object.fromEntries(SCREENS.map((name) => [name, el(`screen-${name}`)]));

const prefsKey = 'aegis.prefs';
const prefs = Object.assign(
  { touch: params.has('touch_preview'), motion: false, fullscreen: false },
  readPrefs(),
);

let current = 'opening';
let engineReady = false;
let engineStarted = false;
let hold = params.has('ui_hold');

function readPrefs() {
  try {
    return JSON.parse(localStorage.getItem(prefsKey) || '{}');
  } catch {
    return {};
  }
}

function savePrefs() {
  try {
    localStorage.setItem(prefsKey, JSON.stringify(prefs));
  } catch {
    /* private mode: the session still works, it just will not be remembered */
  }
}

/* ---------------------------------------------------------------- screens */

function show(name, options = {}) {
  if (!screens[name]) return;
  for (const key of SCREENS) {
    const screen = screens[key];
    const active = key === name;
    screen.dataset.active = String(active);
    screen.setAttribute('aria-hidden', String(!active));
    if (active) screen.scrollTop = 0;
  }
  current = name;
  document.body.dataset.screen = name;
  if (options.focus !== false) {
    const target = screens[name].querySelector('.btn--primary, .card, button, [tabindex]');
    if (target) target.focus({ preventScroll: true });
  }
}

function back() {
  if (current === 'settings') show('hub');
  else if (current === 'hub') show('opening', { focus: false });
}

/* ------------------------------------------------------------ readouts */

function describeViewport() {
  const w = Math.round(window.innerWidth);
  const h = Math.round(window.innerHeight);
  // The shell is landscape-only, so the readout states the measured shape and
  // flags the one case the product does not serve instead of pretending to.
  return `${w}×${h} · ${w >= h ? 'mendatar' : 'tegak · tidak didukung'}`;
}

function describeInput() {
  const coarse = matchMedia('(pointer: coarse)').matches;
  const fine = matchMedia('(pointer: fine)').matches;
  if (coarse && !fine) return 'sentuh';
  if (coarse && fine) return 'hibrida';
  return 'tetikus';
}

function paintReadouts() {
  el('strip-view').textContent = describeViewport();
  el('strip-input').textContent = describeInput();
  el('about-view').textContent = describeViewport();
  el('about-build').textContent = 'lokal';
  el('about-engine').textContent = engineReady ? 'siap' : 'belum dimuat';
  el('strip-engine').dataset.state = engineReady ? 'ok' : 'warn';
  el('strip-engine-label').textContent = engineReady ? 'siap' : 'siaga';
}

/* -------------------------------------------------------------- opening */

/*
 * The opening's three lines are checks, not a script: the engine loader really
 * has to be present, the payload really has to answer, and the viewport really
 * has to be measurable. Each line lights when its check resolves, which is why
 * the enter button is disabled until all three have.
 */
const checks = { engine: false, payload: false, display: false };

const CHECK_COPY = {
  engine: ['Konsol', 'siap', 'tidak ada'],
  payload: ['Paket dunia', 'terbaca', 'hilang'],
  display: ['Tampilan', 'terukur', 'gagal'],
};

function markCheck(key, ok) {
  checks[key] = ok;
  const line = document.querySelector(`#opening-log li[data-key="${key}"]`);
  if (line) {
    const [, okText, badText] = CHECK_COPY[key];
    line.dataset.shown = 'true';
    line.dataset.tone = ok ? 'ok' : 'bad';
    line.querySelector('b').textContent = ok ? okText : badText;
  }
  const done = checks.engine && checks.payload && checks.display;
  const button = el('opening-enter');
  button.disabled = !done;
  el('opening-enter-meta').textContent = done ? 'siap' : 'menyiapkan';
  const channel = el('opening-channel');
  channel.textContent = done ? 'terhubung' : 'menyiapkan';
  channel.className = done ? 'chip chip--ok' : 'chip';
}

async function runOpeningChecks() {
  // Line 1: the engine loader. Present means the browser has executed the shell
  // that this page boots through; missing means a 404 the player must be told about.
  markCheck('engine', typeof (window.Engine || window.Godot) === 'function');

  // Line 2: the payload. The export's own config is a small file that lists the
  // engine and pack it will load, so reading it is proof this checkout can run —
  // and it fails loudly on a fresh clone before the player commits to a
  // deployment. (A HEAD for the pack itself was tempting, but a HEAD against a
  // static server ends the connection without a body, which browsers report as
  // an aborted request; the gate would then flag a request that actually worked.)
  try {
    const response = await fetch('./web/index.html', { cache: 'no-cache' });
    const html = response.ok ? await response.text() : '';
    markCheck('payload', html.includes('"index.pck"') && html.includes('"index.wasm"'));
  } catch {
    markCheck('payload', false);
  }

  // Line 3: the display. Always true in a browser that got this far; it is the
  // line that tells the player what the shell measured.
  markCheck('display', window.innerWidth > 0 && window.innerHeight > 0);

  if (!checks.engine) {
    showNote('Konsol tidak termuat. Jalankan halaman dari root repo: python -m http.server 800');
  } else if (!checks.payload) {
    showNote('Paket dunia (web/index.pck) tidak ditemukan. Ekspor ulang dengan ./scripts/export_web_preview.sh');
  }
}

function showNote(text) {
  const note = el('opening-note');
  note.hidden = false;
  note.textContent = text;
}

/* --------------------------------------------------------------- deploy */

function applyPrefsToUrl() {
  const url = new URL(location.href);
  if (prefs.touch) url.searchParams.set('touch_preview', '1');
  else url.searchParams.delete('touch_preview');
  history.replaceState(null, '', url);
}

function setSwitch(id, value, onChange) {
  const node = el(id);
  node.setAttribute('aria-checked', String(value));
  node.addEventListener('click', () => {
    const next = node.getAttribute('aria-checked') !== 'true';
    node.setAttribute('aria-checked', String(next));
    onChange(next);
  });
}

function applyMotionPref() {
  document.documentElement.dataset.motion = prefs.motion ? 'reduced' : 'full';
}

/*
 * Deploy is one action, not a mode switch: the engine's own Explore is the
 * default state of the theatre and starting waves stays a decision the player
 * makes inside it (B). The shell therefore launches the world and nothing else —
 * it never starts an encounter on the player's behalf.
 */
function deploy() {
  lockLandscape();
  el('launch-title').textContent = 'Menyiapkan dunia';
  show('launch', { focus: false });
  el('canvas').dataset.hidden = 'true';

  // The URL carries the hand-off, so a reload resumes it instead of dropping the
  // player back at the opening.
  const url = new URL(location.href);
  url.searchParams.set('qa_stage', 'GAMEPLAY');
  history.replaceState(null, '', url);

  bootEngine();
}

async function bootEngine() {
  if (engineStarted) return;
  engineStarted = true;

  let html;
  try {
    const response = await fetch('./web/index.html', { cache: 'no-store' });
    html = await response.text();
  } catch (error) {
    launchFailed('Payload tidak terbaca', String(error));
    return;
  }
  const match = html.match(/const GODOT_CONFIG = (\{[^\n]*\});/);
  if (!match) {
    launchFailed('Konfigurasi ekspor tidak terbaca', './web/index.html has no GODOT_CONFIG line.');
    return;
  }

  const config = JSON.parse(match[1]);
  // The page is the root landing page and the payload is /web/: the engine derives
  // its asset paths from the executable it is told about, so this is explicit.
  config.executable = './web/index';
  const EngineClass = window.Engine || window.Godot;

  const progress = el('launch-progress');
  const fill = el('launch-fill');
  const percent = el('launch-percent');
  const status = el('launch-status');
  const hint = el('launch-hint');

  const engine = new EngineClass(config);
  status.textContent = 'memuat aset dunia';

  engine.startGame({
    onProgress: (loaded, total) => {
      if (loaded > 0 && total > 0) {
        const ratio = Math.min(1, loaded / total);
        progress.dataset.indeterminate = 'false';
        progress.setAttribute('aria-valuenow', String(Math.round(ratio * 100)));
        fill.style.width = `${(ratio * 100).toFixed(1)}%`;
        percent.textContent = `${Math.floor(ratio * 100)}%`;
        status.textContent = ratio >= 1 ? 'aset lengkap, menyusun dunia' : 'memuat aset dunia';
      }
    },
  }).then(
    () => {
      engineReady = true;
      paintReadouts();
      progress.dataset.indeterminate = 'false';
      fill.style.width = '100%';
      percent.textContent = '100%';
      status.textContent = 'dunia siap';
      hint.textContent = 'Masuk ke dunia…';
      revealCanvas();
    },
    (error) => launchFailed('Dunia gagal dimuat', String(error)),
  );
}

function launchFailed(title, detail) {
  el('launch-title').textContent = title;
  el('launch-status').textContent = 'berhenti';
  el('launch-percent').textContent = '';
  el('launch-hint').textContent = detail;
  el('launch-progress').dataset.indeterminate = 'false';
  el('strip-engine').dataset.state = 'bad';
  el('strip-engine-label').textContent = 'gagal';
}

function revealCanvas() {
  if (hold) return;
  // A short beat so the player reads "dunia siap" and the fade does not look like
  // a dropped frame. Then the canvas takes the screen and the shell goes away.
  window.setTimeout(() => {
    el('canvas').dataset.hidden = 'false';
    el('app').style.opacity = '0';
    document.body.dataset.mode = 'playing';
    window.setTimeout(() => {
      el('app').style.display = 'none';
      const canvas = el('canvas');
      canvas.tabIndex = -1;
      canvas.focus({ preventScroll: true });
    }, 320);
  }, 700);
}

/* ---------------------------------------------------------------- wiring */

el('opening-enter').addEventListener('click', () => show('hub'));
el('hub-deploy').addEventListener('click', () => deploy());
el('hub-card-controls').addEventListener('click', () => show('settings'));
el('hub-card-display').addEventListener('click', () => show('settings'));
el('settings-close').addEventListener('click', () => show('hub'));

setSwitch('opt-touch', prefs.touch, (value) => {
  prefs.touch = value;
  savePrefs();
  applyPrefsToUrl();
});
setSwitch('opt-motion', prefs.motion, (value) => {
  prefs.motion = value;
  savePrefs();
  applyMotionPref();
});
setSwitch('opt-fullscreen', false, (value) => {
  prefs.fullscreen = value;
  savePrefs();
  if (value && !document.fullscreenElement) document.documentElement.requestFullscreen().catch(() => {});
  if (!value && document.fullscreenElement) document.exitFullscreen().catch(() => {});
});

document.addEventListener('keydown', (event) => {
  if (event.defaultPrevented) return;
  if (event.key === 'Escape') {
    event.preventDefault();
    back();
    return;
  }
  if (event.key === 'Enter') {
    const active = screens[current].querySelector('.btn--primary, .card[data-active="true"], .card');
    if (active && document.body.dataset.mode !== 'playing') {
      event.preventDefault();
      active.click();
    }
  }
});

window.addEventListener('resize', paintReadouts);
document.addEventListener('fullscreenchange', () => {
  el('opt-fullscreen').setAttribute('aria-checked', String(Boolean(document.fullscreenElement)));
  if (document.fullscreenElement) lockLandscape();
});

/*
 * Landscape is the product's only orientation. Fullscreen is the one context a
 * browser lets a page ask for it (and iOS refuses even there), so the lock is a
 * best effort: the CSS guard already keeps a portrait window on the rotate
 * notice, and nothing here blocks the game if the API says no.
 */
function lockLandscape() {
  try {
    if (typeof screen.orientation?.lock === 'function') {
      screen.orientation.lock('landscape').catch(() => {});
    }
  } catch {
    /* not supported: the rotate notice is the fallback */
  }
}

/* ------------------------------------------------------------------ boot */

applyMotionPref();
applyPrefsToUrl();
paintReadouts();
runOpeningChecks();

// QA and deep links: a page that asks for an engine stage boots immediately and
// hands the canvas over, because the thing being photographed is the world, not
// the hub. The shell is not bypassed — it is skipped on purpose, and it still
// waits for the real engine before revealing anything.
const qaStage = params.get('qa_stage');
if (qaStage) {
  show('launch', { focus: false });
  bootEngine();
}

const forced = params.get('ui');
if (forced && SCREENS.includes(forced)) {
  if (forced === 'launch') deploy();
  else show(forced, { focus: false });
} else if (!qaStage) {
  show('opening', { focus: false });
}
