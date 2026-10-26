/*
 * Player shell: opening -> hero -> hub -> deploy -> gameplay.
 *
 * Why this exists as its own layer: the web build used to open on an engine
 * splash and a debug chip bar. A player's first seconds are the opening of the
 * game, not the start of a download, so the front end of the *player journey*
 * lives here, in HTML, with the engine booting behind it only once the player
 * has pressed Deploy. HOME is this shell, once: the engine's own board is not
 * shown after it, which is why the hand-off goes straight into the world.
 *
 * Three rules it keeps:
 *   1. Nothing on screen is invented. The opening's rail is the three real
 *      readiness checks, the launch rail is the engine's byte count, the
 *      theatres are the two the registry can actually launch, and the weapon
 *      numbers are the ones in `game/resources/weapons/*.tres`.
 *   2. It never shows engine chrome: no module names, no version banner, no
 *      "WebAssembly" wording anywhere in the opening.
 *   3. Every screen is reachable by keyboard, works in landscape on a phone,
 *      and honours reduced motion.
 *
 * This round fixed the order of the journey, which was wrong: pressing Masuk
 * after the load screen dropped the player on a map, asking where they wanted to
 * go before it had told them who they were going as. The first lobby screen is
 * now HERO -- roster, celebration, and the four tabs a character page carries
 * (info, upgrade, skin, weapon) -- and the theatre map is the second screen, once
 * the operative is chosen. The old OPERATIF page was folded into it; two pages
 * showing the same character in two compositions was the duplication, not the
 * styling.
 *
 * Everything before that is unchanged: the top strip carries no text, the
 * opening is a poster, and nothing on any screen is invented -- the roster is
 * the one hero the registry ships, the skin slots say "belum dibuat" instead of
 * selling something that does not exist, and the upgrade ladder is the weapon
 * tiers priced in the currency the arena pays.
 */
'use strict';

const SCREENS = ['opening', 'hero', 'hub', 'settings', 'launch'];
const params = new URLSearchParams(location.search);

const el = (id) => document.getElementById(id);
const screens = Object.fromEntries(SCREENS.map((name) => [name, el(`screen-${name}`)]));

const prefsKey = 'aegis.prefs';
const prefs = Object.assign(
  {
    touch: params.has('touch_preview'),
    motion: false,
    fullscreen: false,
    weapon: 'pulse_rifle',
    world: 'neon_frontier',
  },
  readPrefs(),
);

let current = 'opening';
/* Where the settings sheet returns to. It can be opened from the dock on any
   screen, and "close" must mean "back to where I was", not "to the hub". */
let fromSettings = 'hub';
/* Which screen the hero page was opened from. The journey enters it from the
   opening (first run) and from the hub (the Operatif tile), and "kembali" has to
   mean "back to where I was" in both cases. */
let fromHero = 'opening';
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
  if (name === 'hub') paintWorld();
  // The stage renders the rig in WebGL; the loop only runs while the screen that
  // owns it is up, and the context is released before the engine boots.
  if (typeof window.AegisHeroStage !== 'undefined') {
    if (name === 'hero') window.AegisHeroStage.play();
    else window.AegisHeroStage.pause();
  }
  if (name === 'hero') {
    if (options.from) fromHero = options.from;
    celebrate();
  }
  if (name === 'settings') fromSettings = options.from === 'hero' ? 'hero' : 'hub';
  if (options.focus !== false) {
    const target = screens[name].querySelector('.btn--primary, .wcard[aria-selected="true"], button, [tabindex]');
    if (target) target.focus({ preventScroll: true });
  }
}

function back() {
  if (current === 'settings') show(fromSettings);
  else if (current === 'hub') show('hero');
  else if (current === 'hero') show(fromHero, { focus: false });
}

/* -------------------------------------------------------------------- dock */

/*
 * The dock says one thing: whether the console is ready. It used to also print
 * the measured viewport and the pointer type, which are facts about the browser
 * and not about the game; the settings sheet is where build facts belong and the
 * player does not need them at all.
 */
function paintDock(state, title) {
  const node = el('dock-state');
  if (!node) return;
  node.dataset.state = state;
  node.title = title;
  node.setAttribute('aria-label', title);
}

/* -------------------------------------------------------------- opening */

/*
 * The opening's rail is the same three checks as before — engine loader present,
 * payload answers, viewport measurable — but it reports them as a load bar with
 * a percentage instead of as a checklist. The enter plate unlights until all
 * three pass, which is why it can be pressed with confidence.
 */
const checks = { engine: false, payload: false, display: false };
const CHECK_TOTAL = Object.keys(checks).length;

function paintOpening() {
  const passed = Object.values(checks).filter(Boolean).length;
  const done = passed === CHECK_TOTAL;
  const failed = document.getElementById('opening-note')?.hidden === false;
  const ratio = passed / CHECK_TOTAL;

  const rail = el('opening-progress');
  rail.dataset.indeterminate = done || failed ? 'false' : 'true';
  rail.setAttribute('aria-valuenow', String(Math.round(ratio * 100)));
  el('opening-fill').style.width = `${(ratio * 100).toFixed(0)}%`;

  el('opening-status').textContent = done
    ? 'Konsol siap · sambungkan'
    : failed
      ? 'Konsol tidak siap'
      : `Menyiapkan konsol · ${Math.round(ratio * 100)}%`;

  const button = el('opening-enter');
  button.disabled = !done;
  button.querySelector('.btn__label').textContent = done ? 'Masuk' : 'Menyiapkan';
}

function markCheck(key, ok) {
  checks[key] = Boolean(ok);
  paintOpening();
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

  paintOpening();

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
  paintOpening();
}

/* --------------------------------------------------------------- theatres */

/*
 * The two theatres the registry can launch. The card art is painted; the names
 * and the one-line roles are the WorldDefinition's own words, shortened to what
 * fits on a 150 px card. Nothing here is a mission choice: there is one Deploy,
 * and it launches the theatre the player selected.
 */
const WORLDS = [
  { id: 'neon_frontier', name: 'Neon Frontier', line: 'Neon Frontier · sektor 07' },
  { id: 'vanguard_station', name: 'Vanguard Station', line: 'Vanguard Station · hanggar 02' },
];

function worldIndex() {
  const index = WORLDS.findIndex((world) => world.id === prefs.world);
  return index < 0 ? 0 : index;
}

function paintWorld() {
  for (const card of document.querySelectorAll('.wcard[data-world]')) {
    card.setAttribute('aria-selected', String(card.dataset.world === prefs.world));
  }
  const dots = el('world-dots');
  if (dots) {
    [...dots.children].forEach((dot, index) => {
      dot.dataset.active = String(index === worldIndex());
    });
  }
  const line = el('hub-world-line');
  if (line) line.textContent = WORLDS[worldIndex()].line;
  const kitWorld = el('hero-kit-world');
  if (kitWorld) kitWorld.textContent = WORLDS[worldIndex()].name;
  const eyebrow = el('launch-eyebrow');
  if (eyebrow) eyebrow.textContent = `Deploy · ${WORLDS[worldIndex()].name}`;
}

function selectWorld(id) {
  if (!WORLDS.some((world) => world.id === id)) return;
  prefs.world = id;
  savePrefs();
  paintWorld();
}

function stepWorld(delta) {
  const next = (worldIndex() + delta + WORLDS.length) % WORLDS.length;
  selectWorld(WORLDS[next].id);
}

for (const card of document.querySelectorAll('.wcard[data-world]')) {
  card.addEventListener('click', () => selectWorld(card.dataset.world));
}
el('world-prev').addEventListener('click', () => stepWorld(-1));
el('world-next').addEventListener('click', () => stepWorld(1));

/* ------------------------------------------------------------------ hero */

/*
 * The first lobby screen: who the player deploys as.
 *
 * The composition is the one a modern mobile shooter's character page uses
 * (CoD Mobile's Operator page, Free Fire's Character page): the hero as the
 * largest object, a roster strip under him, a rail of tabs that each answer one
 * question, and exactly one lit action. The research that shaped it:
 *
 *   - a character page is a stage, not a form: identity first, detail on demand;
 *   - the roster belongs on the page, because choosing a hero is the same act as
 *     reviewing one;
 *   - every tab must have something true in it, or it should not exist. So this
 *     hero has three tabs that describe the game as it is today -- his rig, the
 *     kit ladder the arena pays for, and the one livery the rig actually wears --
 *     plus the rack, which is the only choice here that changes the run.
 */
const HERO_TABS = ['info', 'upgrade', 'skin', 'weapon'];

function paintTab(name) {
  if (!HERO_TABS.includes(name)) return;
  for (const tab of document.querySelectorAll('.htab')) {
    const on = tab.dataset.tab === name;
    tab.setAttribute('aria-selected', String(on));
    tab.tabIndex = on ? 0 : -1;
  }
  for (const panel of document.querySelectorAll('.hpanel')) {
    panel.hidden = panel.id !== `hero-panel-${name}`;
  }
}

for (const tab of document.querySelectorAll('.htab')) {
  tab.addEventListener('click', () => paintTab(tab.dataset.tab));
}

/*
 * The celebration. Sparks are generated rather than typed into the markup: the
 * pattern wants variety (angle, distance, colour, duration) and fifteen spans of
 * hand-authored CSS custom properties is not a design, it is a transcription.
 *
 * It runs on entry, once per entry, and it is a no-op under "kurangi gerak" --
 * the banner simply sits there. Nothing in it is data: it is the one flourish in
 * the lobby, and it exists because the moment a player first sees their operative
 * is the moment a lobby is supposed to feel like an event.
 */
/* Whites only. The stage is shared by every hero, so a burst tinted with this
   hero's palette would be the one thing in the room that does not belong to the
   next hero. */
const SPARK_COLORS = ['#ffffff', '#e2eaf2', '#b6c2cf', '#f6fafd'];

function buildSparks() {
  const host = el('hero-sparks');
  if (!host || host.childElementCount) return;
  for (let index = 0; index < 18; index += 1) {
    const spark = document.createElement('i');
    const spread = (index % 2 === 0 ? 1 : -1) * (10 + ((index * 37) % 46));
    spark.style.setProperty('--x', `${44 + ((index * 13) % 18)}%`);
    spark.style.setProperty('--y', `${8 + ((index * 7) % 16)}%`);
    spark.style.setProperty('--dx', `${spread}px`);
    spark.style.setProperty('--dy', `${-70 - ((index * 29) % 120)}px`);
    spark.style.setProperty('--w', `${2 + (index % 3)}px`);
    spark.style.setProperty('--d', `${1.1 + ((index * 11) % 9) / 10}s`);
    spark.style.setProperty('--delay', `${(index % 6) * 0.06}s`);
    spark.style.setProperty('--c', SPARK_COLORS[index % SPARK_COLORS.length]);
    host.appendChild(spark);
  }
}

let celebrateTimer = 0;

function celebrate() {
  const screen = screens.hero;
  if (!screen) return;
  buildSparks();
  const reduced = document.documentElement.dataset.motion === 'reduced';
  screen.dataset.celebrate = 'false';
  void screen.offsetWidth; // restart the animations rather than resuming them
  screen.dataset.celebrate = 'true';
  // The rig answers too: the beat is not only DOM effects over a still frame.
  if (typeof window.AegisHeroStage !== 'undefined') window.AegisHeroStage.pulse();
  window.clearTimeout(celebrateTimer);
  celebrateTimer = window.setTimeout(() => {
    screen.dataset.celebrate = reduced ? 'true' : 'false';
  }, reduced ? 100000 : 2800);
}

/* A module script and a classic deferred script have no guaranteed order, so the
   stage announces itself instead of assuming the shell got there first. */
window.addEventListener('aegis:hero-stage-ready', () => {
  if (current === 'hero' && typeof window.AegisHeroStage !== 'undefined') {
    window.AegisHeroStage.play();
  }
});

/* The roster: one hero card and two slots. Selecting a card re-plays the short
   beat, because a tap on a character card is a confirmation and a confirmation
   with no response reads as a missed input. A card that is already active still
   answers -- pressing the thing you already have is how a player says "show me
   again". */
for (const card of document.querySelectorAll('#hero-roster .hcard[data-hero]')) {
  card.addEventListener('click', () => {
    for (const other of document.querySelectorAll('#hero-roster .hcard[data-hero]')) {
      other.dataset.active = String(other === card);
      other.setAttribute('aria-pressed', String(other === card));
    }
    celebrate();
  });
}

for (const skin of document.querySelectorAll('.skin')) {
  skin.addEventListener('click', () => {
    if (skin.getAttribute('aria-disabled') === 'true') return;
    for (const other of document.querySelectorAll('.skin')) {
      other.setAttribute('aria-checked', String(other === skin));
    }
  });
}

/* --------------------------------------------------------------- loadout */

/*
 * The weapons are the ones the game ships, with the numbers out of their own
 * definitions (`game/resources/weapons/*.tres`): damage per shot, rounds per
 * second, magazine. Costs are ProgressionService.COSTS. The shell does not
 * unlock anything -- BP is spent in the arena -- so a weapon with a price is
 * listed, priced and not selectable here, which is the same rule the in-game
 * armory follows.
 */
const WEAPONS = {
  pulse_rifle: { name: 'Pulse Rifle', cost: 0 },
  nova_launcher: { name: 'Nova Launcher', cost: 120 },
  arc_shooter: { name: 'Arc Shooter', cost: 250 },
};

function paintLoadout() {
  for (const button of document.querySelectorAll('.weapon')) {
    const locked = Number(button.dataset.cost) > 0;
    // A priced weapon is not "selected", it is "available later": pressing it
    // moves the focus ring and nothing else, so the screen never claims a
    // loadout the game would refuse. `aria-disabled` is how that is said, and
    // it is the same attribute the CSS colours the price from.
    button.setAttribute('aria-pressed', String(!locked && button.dataset.weapon === prefs.weapon));
    button.setAttribute('aria-disabled', String(locked));
  }
  const weapon = WEAPONS[prefs.weapon] || WEAPONS.pulse_rifle;
  const chip = el('hero-weapon-chip');
  if (chip) chip.textContent = weapon.name;
  const hub = el('hub-operative-meta');
  if (hub) hub.textContent = weapon.name;
  const deployMeta = el('hub-deploy-meta');
  if (deployMeta) deployMeta.textContent = weapon.name;
  const kitWeapon = el('hero-kit-weapon');
  if (kitWeapon) kitWeapon.textContent = weapon.name;
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
  paintWorld();
  el('launch-title').textContent = 'Menyiapkan dunia';
  show('launch', { focus: false });
  el('canvas').dataset.hidden = 'true';

  // Hand the GPU over before the engine asks for its own context: two live
  // WebGL contexts on a phone is a memory bill, and the lobby's stage is over.
  if (typeof window.AegisHeroStage !== 'undefined') window.AegisHeroStage.dispose();

  // The URL carries the hand-off, so a reload resumes it instead of dropping the
  // player back at the opening.
  const url = new URL(location.href);
  url.searchParams.set('qa_stage', 'GAMEPLAY');
  // The engine reads these in ProgressionService.load_profile() and
  // FrontEnd._enter_qa_world(): the shell's choices are the run's loadout and
  // theatre, not a picture of them.
  url.searchParams.set('weapon', prefs.weapon);
  url.searchParams.set('qa_world', prefs.world);
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
  status.textContent = 'Memuat aset dunia';

  engine.startGame({
    onProgress: (loaded, total) => {
      if (loaded > 0 && total > 0) {
        const ratio = Math.min(1, loaded / total);
        progress.dataset.indeterminate = 'false';
        progress.setAttribute('aria-valuenow', String(Math.round(ratio * 100)));
        fill.style.width = `${(ratio * 100).toFixed(1)}%`;
        // The head is a 2 px mark, so it is inset by its own width: at 100 %
        // it sits on the far end of the channel instead of just past it.
        progress.querySelector('.rail__head').style.left = `calc(${(ratio * 100).toFixed(1)}% - 2px)`;
        percent.textContent = `${Math.floor(ratio * 100)}%`;
        status.textContent = ratio >= 1 ? 'Aset lengkap · menyusun dunia' : 'Memuat aset dunia';
      }
    },
  }).then(
    () => {
      engineReady = true;
      paintDock('ok', 'Konsol siap');
      progress.dataset.indeterminate = 'false';
      fill.style.width = '100%';
      percent.textContent = '100%';
      status.textContent = 'Dunia siap';
      hint.textContent = 'Masuk ke dunia…';
      revealCanvas();
    },
    (error) => launchFailed('Dunia gagal dimuat', String(error)),
  );
}

function launchFailed(title, detail) {
  el('launch-title').textContent = title;
  el('launch-status').textContent = 'Berhenti';
  el('launch-percent').textContent = '';
  el('launch-hint').textContent = detail;
  el('launch-progress').dataset.indeterminate = 'false';
  paintDock('bad', 'Konsol gagal dimuat');
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

el('opening-enter').addEventListener('click', () => show('hero', { from: 'opening' }));
el('hero-next').addEventListener('click', () => show('hub'));
el('hero-back').addEventListener('click', () => show(fromHero, { focus: false }));
el('hub-deploy').addEventListener('click', () => deploy());
el('hub-card-operative').addEventListener('click', () => show('hero', { from: 'hub' }));
for (const button of document.querySelectorAll('.weapon')) {
  button.addEventListener('click', () => {
    if (Number(button.dataset.cost) > 0) return;
    prefs.weapon = button.dataset.weapon;
    savePrefs();
    paintLoadout();
  });
}
el('hub-card-controls').addEventListener('click', () => show('settings'));
el('hub-card-display').addEventListener('click', () => show('settings'));
el('settings-close').addEventListener('click', () => show(fromSettings));
el('dock-settings').addEventListener('click', () => show('settings', { from: current }));
el('dock-fullscreen').addEventListener('click', () => toggleFullscreen());

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
setSwitch('opt-fullscreen', false, (value) => toggleFullscreen(value));

document.addEventListener('keydown', (event) => {
  if (event.defaultPrevented) return;
  if (event.key === 'Escape') {
    event.preventDefault();
    back();
    return;
  }
  if (current === 'hero' && (event.key === 'ArrowDown' || event.key === 'ArrowUp')) {
    event.preventDefault();
    const step = event.key === 'ArrowDown' ? 1 : -1;
    const index = HERO_TABS.indexOf(document.querySelector('.htab[aria-selected="true"]')?.dataset.tab || 'info');
    const next = HERO_TABS[(index + step + HERO_TABS.length) % HERO_TABS.length];
    paintTab(next);
    document.querySelector(`.htab[data-tab="${next}"]`)?.focus();
    return;
  }
  if (current === 'hub' && (event.key === 'ArrowRight' || event.key === 'ArrowLeft')) {
    event.preventDefault();
    stepWorld(event.key === 'ArrowRight' ? 1 : -1);
    return;
  }
  if (event.key === 'Enter') {
    const active = screens[current].querySelector('.btn--primary, .wcard[aria-selected="true"], .wcard');
    if (active && document.body.dataset.mode !== 'playing') {
      event.preventDefault();
      active.click();
    }
  }
});

document.addEventListener('fullscreenchange', () => {
  const full = Boolean(document.fullscreenElement);
  el('opt-fullscreen').setAttribute('aria-checked', String(full));
  if (full) lockLandscape();
});

/*
 * Landscape is the product's only orientation. Fullscreen is the one context a
 * browser lets a page ask for it (and iOS refuses even there), so the lock is a
 * best effort: the CSS guard already keeps a portrait window on the rotate
 * notice, and nothing here blocks the game if the API says no.
 */
function toggleFullscreen(force) {
  const want = typeof force === 'boolean' ? force : !document.fullscreenElement;
  prefs.fullscreen = want;
  savePrefs();
  if (want && !document.fullscreenElement) document.documentElement.requestFullscreen().catch(() => {});
  if (!want && document.fullscreenElement) document.exitFullscreen().catch(() => {});
}

function lockLandscape() {
  try {
    if (typeof screen.orientation?.lock === 'function') {
      screen.orientation.lock('landscape').catch(() => {});
    }
  } catch {
    /* not supported: the rotate notice is the fallback */
  }
}

/* ------------------------------------------------------------------- home */

/*
 * HOME is the lobby, and the engine asks for it by name: an in-game HOME button
 * calls `window.AegisShell.home()` through
 * game/scripts/ui/dashboard_return.gd. The world is a WebGL context the page
 * cannot unload in place, so the honest way back is a fresh document: the
 * hand-off parameters are dropped and `ui=hub` puts the lobby up -- loadout,
 * world and progress all survive because they live in storage, not in the tab.
 */
function home() {
  const url = new URL(location.href);
  url.searchParams.delete('qa_stage');
  url.searchParams.delete('weapon');
  url.searchParams.delete('qa_world');
  url.searchParams.set('ui', 'hub');
  location.replace(url.toString());
}

/* Read by the engine's HOME affordances and by the shell's own QA harness. */
window.AegisShell = { home, screen: () => current };

/* ------------------------------------------------------------------ boot */

applyMotionPref();
applyPrefsToUrl();
paintDock(engineReady ? 'ok' : 'warn', engineReady ? 'Konsol siap' : 'Konsol belum siap');
paintLoadout();
paintWorld();
paintOpening();
paintTab('info');
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
