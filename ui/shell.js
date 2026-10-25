/*
 * Player shell: opening -> hero -> hub -> deploy -> gameplay.
 *
 * Why this exists as its own layer: the web build used to open on an engine
 * splash and a debug chip bar. A player's first seconds are the opening of the
 * game, not the start of a download, so the front end of the *player journey*
 * lives here, in HTML. The opening preloads the engine and the complete world
 * pack without starting gameplay; DEPLOY starts that prepared engine. HOME is
 * this shell, once: the engine's own board is not shown after it, which is why
 * the hand-off goes straight into the selected world.
 *
 * Three rules it keeps:
 *   1. Nothing on screen is invented. Opening and launch share Godot's combined
 *      WASM + PCK byte count, the theatres are the four the registry can
 *      actually launch, and weapon numbers come from their definitions.
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

import { ShellAudio } from './audio.js';

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
    world: 'frostline_relay',
    muted: false,
  },
  readPrefs(),
);

const BOOT_STALL_TIMEOUT_MS = 180000;

let current = 'opening';
/* Where the settings sheet returns to. It can be opened from the dock on any
   screen, and "close" must mean "back to where I was", not "to the hub". */
let fromSettings = 'hub';
/* Which screen the hero page was opened from. The journey enters it from the
   opening (first run) and from the hub (the Operatif tile), and "kembali" has to
   mean "back to where I was" in both cases. */
let fromHero = 'opening';
let engineReady = false;
// idle -> preparing -> prepared -> loading -> ready. Preparation belongs to
// the opening; only the last two states belong to DEPLOY/gameplay.
let bootState = 'idle';
let bootWatchdog = 0;
let assetsComplete = false;
let engine = null;
let enginePreparation = null;
let mainPackPath = '';
let expectedBytes = 0;
let downloadedBytes = 0;
let hold = params.has('ui_hold');

const audio = new ShellAudio({
  muted: prefs.muted === true,
  onMutedChange: (value) => {
    prefs.muted = value;
    savePrefs();
    paintAudioControl();
  },
});
audio.onStateChange = () => paintAudioControl();
// Read-only diagnostics let browser QA verify real Web Audio state without
// exposing transport controls or a second gameplay audio owner.
Object.defineProperty(window, 'AegisAudio', {
  value: Object.freeze({ snapshot: () => audio.snapshot() }),
  writable: false,
});

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
  audio.setScene(name);
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

function paintAudioControl() {
  const node = el('dock-audio');
  if (!node) return;
  const label = !audio.supported
    ? 'Audio tidak didukung peramban'
    : audio.muted
      ? 'Nyalakan audio'
      : audio.unlocked
        ? 'Bisukan audio'
        : 'Aktifkan audio';
  node.dataset.state = !audio.supported ? 'unavailable' : audio.muted ? 'muted' : audio.unlocked ? 'ready' : 'locked';
  node.setAttribute('aria-label', label);
  node.setAttribute('aria-pressed', String(audio.muted));
  node.title = label;
  node.disabled = !audio.supported;
  el('dock-audio-icon')?.setAttribute('href', audio.muted ? '#i-sound-off' : '#i-sound-on');
}

/* -------------------------------------------------------------- opening */

/*
 * Opening is the real download gate, not a three-check animation. The engine
 * WASM and the PCK (which contains every theatre) are fetched before MASUK is
 * enabled. The percentage is Godot Preloader's aggregate byte count; there is
 * no timer-based or per-file progress accumulation.
 */
const checks = { engine: false, payload: false, display: false, assets: false };

function paintOpening() {
  const done = Object.values(checks).every(Boolean);
  const failed = el('opening-note')?.hidden === false;
  const hasByteTotal = expectedBytes > 0;
  const ratio = done ? 1 : hasByteTotal ? Math.min(1, downloadedBytes / expectedBytes) : 0;

  const rail = el('opening-progress');
  rail.dataset.indeterminate = hasByteTotal || done || failed ? 'false' : 'true';
  rail.setAttribute('aria-valuenow', String(Math.round(ratio * 100)));
  el('opening-fill').style.width = `${(ratio * 100).toFixed(1)}%`;

  el('opening-status').textContent = failed
    ? 'Unduhan dunia terhenti'
    : done
      ? 'Mesin + dunia siap'
      : assetsComplete
        ? 'Aset lengkap · menyiapkan konsol'
        : hasByteTotal
          ? `Mengunduh mesin + dunia · ${formatMegabytes(downloadedBytes)}/${formatMegabytes(expectedBytes)} MB`
          : 'Menyiapkan konsol';

  const button = el('opening-enter');
  button.disabled = !(done || failed);
  button.querySelector('.btn__label').textContent = failed ? 'Coba lagi' : done ? 'Masuk' : 'Menyiapkan';
}

function markCheck(key, ok) {
  checks[key] = Boolean(ok);
  paintOpening();
}

async function runOpeningChecks() {
  el('opening-note').hidden = true;
  markCheck('engine', typeof (window.Engine || window.Godot) === 'function');
  markCheck('display', window.innerWidth > 0 && window.innerHeight > 0);
  if (!checks.engine) {
    showNote('Konsol tidak termuat. Jalankan halaman dari root repo: python -m http.server 800');
    return;
  }

  try {
    // This initializes the runtime and downloads the main pack, but deliberately
    // does not call start(): no gameplay or theatre runs behind the opening.
    await prepareEngine();
  } catch (error) {
    failLaunchFrom(error);
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
 * The four theatres the registry can launch, in WorldDefinition order. Card
 * plates are captures of those worlds; the short roles only condense their
 * registry descriptions. Nothing here is a mission choice: DEPLOY launches the
 * theatre the player selected.
 */
const WORLDS = [
  { id: 'frostline_relay', name: 'Frostline Relay', line: 'Frostline Relay · uplink' },
  { id: 'verdant_bloom', name: 'Verdant Bloom', line: 'Verdant Bloom · grove riset' },
  { id: 'emberfall_foundry', name: 'Emberfall Foundry', line: 'Emberfall Foundry · ekstraksi' },
  { id: 'vanguard_station', name: 'Vanguard Station', line: 'Vanguard Station · hanggar 02' },
];

// A saved Neon selection predates the new registry. Migrate it explicitly so
// the card, URL handoff, and ProgressionService all agree on the same default.
if (!WORLDS.some((world) => world.id === prefs.world)) prefs.world = WORLDS[0].id;

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
  savePrefs();
  paintWorld();
  void audio.play('deploy');
  el('launch-title').textContent = 'Menyiapkan dunia';
  el('launch-status').textContent = 'menghubungkan paket dunia';
  el('launch-hint').textContent = 'Paket dunia diunduh sekali saat opening. DEPLOY menyiapkan teater yang dipilih.';
  el('launch-retry').hidden = true;
  show('launch', { focus: false });
  el('canvas').dataset.hidden = 'true';

  // Hand the GPU over before the engine asks for its own context: two live
  // WebGL contexts on a phone is a memory bill, and the lobby's stage is over.
  if (typeof window.AegisHeroStage !== 'undefined') window.AegisHeroStage.dispose();

  // The URL carries the hand-off, so retry/reload resumes it instead of dropping
  // the player back at the opening.
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

function armBootWatchdog() {
  window.clearTimeout(bootWatchdog);
  bootWatchdog = window.setTimeout(() => {
    if (!['preparing', 'loading'].includes(bootState)) return;
    const title = assetsComplete ? 'Dunia terlalu lama disiapkan' : 'Unduhan dunia berhenti';
    const detail = assetsComplete
      ? 'Mesin dan paket dunia sudah diterima, tetapi dunia belum siap setelah 3 menit. Muat ulang lalu coba lagi.'
      : 'Tidak ada data baru selama 3 menit. Periksa koneksi, biarkan tab tetap aktif, lalu coba lagi.';
    launchFailed(title, detail);
  }, BOOT_STALL_TIMEOUT_MS);
}

function formatMegabytes(bytes) {
  return (bytes / 1000000).toFixed(1).replace('.', ',');
}

function failLaunchFrom(error) {
  const detail = String(error?.message || error || 'Kesalahan yang tidak dikenal.');
  if (/failed to fetch|network\s*error|load failed|failed loading file|err_(?:failed|content_length_mismatch)/i.test(detail)) {
    launchFailed(
      'Koneksi dunia terputus',
      `Unduhan mesin atau paket dunia tidak selesai. Periksa koneksi lalu coba lagi. Detail: ${detail}`,
    );
  } else {
    launchFailed('Dunia gagal dimuat', detail);
  }
}

/* The launch rail mirrors the same opening byte snapshot. It is not a second
 * accumulator: both DOMs read loadedBytes/expectedBytes from Godot's callback. */
function paintAssetProgress() {
  if (expectedBytes <= 0) return;
  const progress = el('launch-progress');
  const ratio = Math.min(1, downloadedBytes / expectedBytes);
  progress.dataset.indeterminate = 'false';
  progress.setAttribute('aria-valuenow', String(Math.round(ratio * 100)));
  el('launch-fill').style.width = `${(ratio * 100).toFixed(1)}%`;
  progress.querySelector('.rail__head').style.left = `calc(${(ratio * 100).toFixed(1)}% - 2px)`;
  el('launch-percent').textContent = `${Math.floor(ratio * 100)}%`;
  el('launch-status').textContent = assetsComplete
    ? 'aset lengkap, menyusun dunia'
    : `mengunduh mesin + dunia · ${formatMegabytes(downloadedBytes)}/${formatMegabytes(expectedBytes)} MB`;
  if (assetsComplete) el('launch-hint').textContent = 'Unduhan selesai. Menyiapkan WebGL dan dunia…';
}

function handleAssetProgress(loaded, total) {
  if (bootState === 'failed' || bootState === 'ready' || loaded <= 0 || total <= 0) return;
  armBootWatchdog();

  // Godot's Preloader already sums every active file: loaded/total are the
  // combined WASM + PCK byte counts, not independent per-file percentages.
  // exported fileSizes supplies the same aggregate total from the first frame.
  const totalBytes = expectedBytes || total;
  downloadedBytes = Math.min(loaded, totalBytes);
  assetsComplete = totalBytes > 0 && loaded >= totalBytes;
  paintOpening();
  paintAssetProgress();
}

function prepareEngine() {
  if (enginePreparation) return enginePreparation;
  bootState = 'preparing';
  engineReady = false;
  assetsComplete = false;
  downloadedBytes = 0;
  el('launch-retry').hidden = true;
  armBootWatchdog();

  enginePreparation = (async () => {
    const response = await fetch('./web/index.html', { cache: 'no-store' });
    if (!response.ok) throw new Error(`./web/index.html returned HTTP ${response.status}`);
    const html = await response.text();
    const match = html.match(/const GODOT_CONFIG = (\{[^\n]*\});/);
    if (!match) throw new Error('./web/index.html has no GODOT_CONFIG line.');
    const config = JSON.parse(match[1]);
    if (!config.fileSizes?.['index.pck'] || !config.fileSizes?.['index.wasm']) {
      throw new Error('./web/index.html does not declare both payload sizes.');
    }
    markCheck('payload', true);

    // The page is the root landing page and the payload is /web/. Keep the
    // exported keys and add the rewritten keys used by Engine.load/preloadFile;
    // otherwise the bytes download but Godot reports total=0.
    const exportedFileSizes = config.fileSizes || {};
    config.fileSizes = { ...exportedFileSizes };
    config.fileSizes['./web/index.wasm'] = exportedFileSizes['index.wasm'];
    config.fileSizes['./web/index.pck'] = exportedFileSizes['index.pck'];
    config.executable = './web/index';
    mainPackPath = config.mainPack || `${config.executable}.pck`;
    expectedBytes = Number(exportedFileSizes['index.wasm']) + Number(exportedFileSizes['index.pck']);

    const EngineClass = window.Engine || window.Godot;
    if (typeof EngineClass !== 'function') throw new Error('window.Engine/window.Godot is unavailable.');
    engine = new EngineClass({ ...config, onProgress: handleAssetProgress });

    el('launch-hint').textContent = `Unduhan awal ${formatMegabytes(expectedBytes)} MB (mesin + dunia). Jangan tutup atau muat ulang saat progres bergerak.`;
    paintAssetProgress();
    paintOpening();

    // Official Godot Web API: initialize WASM and preload the PCK without
    // starting gameplay. start() later consumes these exact buffers, so DEPLOY
    // does not issue a second PCK request and no world runs behind the shell.
    await Promise.all([
      engine.init(config.executable),
      engine.preloadFile(mainPackPath, mainPackPath),
    ]);
    if (bootState === 'failed') throw new Error('Engine preparation was interrupted.');

    assetsComplete = true;
    downloadedBytes = expectedBytes;
    bootState = 'prepared';
    window.clearTimeout(bootWatchdog);
    markCheck('assets', true);
    paintAssetProgress();
    paintDock('ok', 'Paket dunia siap');
    return engine;
  })();

  return enginePreparation;
}

async function bootEngine() {
  if (bootState === 'loading' || bootState === 'ready' || bootState === 'failed') return;
  el('launch-retry').hidden = true;

  try {
    await prepareEngine();
    // Another DEPLOY event may have started the prepared engine while this
    // caller awaited the same preparation Promise.
    if (bootState !== 'prepared') return;
    bootState = 'loading';
    engineReady = false;
    armBootWatchdog();
    // Retire the HTML theme before Godot's autoload can start the same asset.
    // The DEPLOY stinger may finish as a one-shot; music beds never overlap.
    await audio.handoff();
    if (bootState !== 'loading') return;
    if (audio.snapshot().musicVoices !== 0) {
      throw new Error('Audio opening belum selesai; DEPLOY dihentikan untuk mencegah musik ganda.');
    }
    el('launch-status').textContent = 'aset lengkap, menyusun dunia';
    el('launch-hint').textContent = 'Paket sudah lengkap. Menyiapkan WebGL dan teater pilihan…';

    // startGame() would call preloadFile() a second time. The opening already
    // owns that buffer, so supply startGame's main-pack argument directly to
    // the official start() API instead.
    await engine.start({ args: ['--main-pack', mainPackPath] });
    if (bootState !== 'loading') return;
    bootState = 'ready';
    window.clearTimeout(bootWatchdog);
    engineReady = true;
    paintDock('ok', 'Konsol siap');
    const progress = el('launch-progress');
    progress.dataset.indeterminate = 'false';
    progress.setAttribute('aria-valuenow', '100');
    el('launch-fill').style.width = '100%';
    progress.querySelector('.rail__head').style.left = 'calc(100% - 2px)';
    el('launch-percent').textContent = '100%';
    el('launch-status').textContent = 'dunia siap';
    el('launch-hint').textContent = 'Masuk ke dunia…';
    revealCanvas();
  } catch (error) {
    failLaunchFrom(error);
  }
}

function launchFailed(title, detail) {
  if (bootState === 'failed' || bootState === 'ready') return;
  bootState = 'failed';
  engineReady = false;
  window.clearTimeout(bootWatchdog);
  audio.setScene('launch');
  el('launch-title').textContent = title;
  el('launch-status').textContent = 'berhenti — muat ulang untuk mencoba lagi';
  el('launch-percent').textContent = '';
  el('launch-hint').textContent = String(detail);
  el('launch-progress').dataset.indeterminate = 'false';
  el('launch-retry').hidden = false;
  paintDock('bad', 'Konsol gagal dimuat');
  // The same failure is visible where the opening download actually happened.
  showNote(String(detail));
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

// Only trusted input may unlock Web Audio. Programmatic QA clicks can still
// navigate, but they never pretend to satisfy a browser's autoplay policy.
document.addEventListener('pointerdown', () => {
  if (!audio.handedOff) void audio.unlock();
}, { capture: true, passive: true });
document.addEventListener('keydown', () => {
  if (!audio.handedOff) void audio.unlock();
}, { capture: true });

document.addEventListener('click', (event) => {
  const button = event.target.closest('button');
  if (!button || button.disabled || button.getAttribute('aria-disabled') === 'true') return;
  if (button.matches('#hub-deploy, #dock-audio, #launch-retry')) return;
  void audio.play(button.id === 'opening-enter' ? 'confirm' : 'navigate');
});

// Defensive fallback for failures inside Godot's response-stream callbacks.
// The export patch handles normal init/preload rejections; a truncated body can
// also reject outside those chains. Surface it only while preparing/starting,
// never during active gameplay.
window.addEventListener('unhandledrejection', (event) => {
  if (!['preparing', 'loading'].includes(bootState)) return;
  event.preventDefault();
  failLaunchFrom(event.reason);
});

el('opening-enter').addEventListener('click', () => {
  if (!el('opening-note').hidden) {
    window.location.reload();
    return;
  }
  if (checks.assets) show('hero', { from: 'opening' });
});
el('hero-next').addEventListener('click', () => show('hub'));
el('hero-back').addEventListener('click', () => show(fromHero, { focus: false }));
el('hub-deploy').addEventListener('click', () => deploy());
el('launch-retry').addEventListener('click', () => window.location.reload());
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
el('dock-audio').addEventListener('click', () => {
  if (!audio.unlocked && !audio.muted) {
    void audio.unlock();
    return;
  }
  const muted = !audio.muted;
  audio.setMuted(muted);
  if (!muted) void audio.unlock();
});
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

/* ------------------------------------------------------------------ boot */

applyMotionPref();
applyPrefsToUrl();
paintAudioControl();
paintDock(engineReady ? 'ok' : 'warn', engineReady ? 'Konsol siap' : 'Konsol belum siap');
paintLoadout();
paintWorld();
paintOpening();
paintTab('info');
runOpeningChecks();

// QA and deep links: a page that asks for an engine stage still performs the
// same opening preparation, then hands the canvas over without showing the hub.
// It never bypasses the download or fabricates readiness.
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
