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
 *      WASM + PCK byte count, the theatres are the five the registry can
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
import {
  apply as applyLocale,
  init as initLocale,
  locale,
  nativeName,
  nextLocale,
  setLocale,
  t,
} from './i18n.js';

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
    hero: 'sable',
    tier: 1,
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
    // Every arrival on the page is the same beat: the operative comes in from
    // the right, once. Re-entering is a new arrival, not a resume.
    stageShow('right');
    celebrate('right');
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
    ? t('opening.status.failed')
    : done
      ? t('opening.status.ready')
      : assetsComplete
        ? t('opening.status.assets_ready')
        : hasByteTotal
          ? `${t('opening.status.downloading')} · ${formatMegabytes(downloadedBytes)}/${formatMegabytes(expectedBytes)} MB`
          : t('opening.status.checking');

  const button = el('opening-enter');
  button.disabled = !(done || failed);
  button.querySelector('.btn__label').textContent = failed
    ? t('opening.retry')
    : done
      ? t('opening.enter')
      : t('opening.enter_wait');
}

function markCheck(key, ok) {
  checks[key] = Boolean(ok);
  paintOpening();
}

/*
 * Godot's audio initialization dereferences AudioContext.audioWorklet. On an
 * insecure HTTP origin that property can be absent, which otherwise surfaces
 * only after the opening has downloaded the payload and DEPLOY has started the
 * engine. Use the exported engine's own feature probe before any payload fetch,
 * and keep the audio requirement explicit because getMissingFeatures treats
 * audio as optional even though this build initializes its position worklet.
 */
function browserSupportIssue() {
  if (window.isSecureContext !== true) {
    return {
      title: t('launch.failed.secure_context'),
      detail: t('opening.note.insecure_context', location.port || '80'),
    };
  }

  const AudioContextClass = window.AudioContext || window.webkitAudioContext;
  if (!AudioContextClass || !('audioWorklet' in AudioContextClass.prototype)) {
    return {
      title: t('launch.failed.browser'),
      detail: t('opening.note.no_audio_worklet'),
    };
  }

  const EngineClass = window.Engine || window.Godot;
  if (typeof EngineClass?.getMissingFeatures === 'function') {
    const missing = EngineClass.getMissingFeatures({ threads: false });
    if (missing.length) {
      return {
        title: t('launch.failed.browser'),
        detail: t('opening.note.missing_features', missing.join('; ')),
      };
    }
  }
  return null;
}

async function runOpeningChecks() {
  el('opening-note').hidden = true;
  markCheck('engine', typeof (window.Engine || window.Godot) === 'function');
  markCheck('display', window.innerWidth > 0 && window.innerHeight > 0);
  if (!checks.engine) {
showNote(t('opening.note.no_engine'));
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
 * The five theatres the registry can launch, in WorldDefinition order. Card
 * plates are captures of those worlds; the short roles only condense their
 * registry descriptions. Nothing here is a mission choice: DEPLOY launches the
 * theatre the player selected.
 */
const WORLDS = [
{ id: 'frostline_relay', name: 'Frostline Relay', lineKey: 'world.frostline_relay.line' },
  { id: 'verdant_bloom', name: 'Verdant Bloom', lineKey: 'world.verdant_bloom.line' },
  { id: 'emberfall_foundry', name: 'Emberfall Foundry', lineKey: 'world.emberfall_foundry.line' },
  { id: 'vanguard_station', name: 'Vanguard Station', lineKey: 'world.vanguard_station.line' },
  { id: 'titans', name: 'THE TITANS', lineKey: 'world.titans.line' },
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
  const snap = profileSnapshot();
  const strip = el('hub-profile-strip');
  if (strip) {
    const bp = Number.isFinite(Number(snap.balance)) ? Math.max(0, Math.floor(Number(snap.balance))) : 0;
    const runs = completedRuns();
    const best = Number.isFinite(Number(snap.best_score)) ? Math.max(0, Math.floor(Number(snap.best_score))) : 0;
    strip.textContent = t('hub.profile_strip', bp, runs, best);
  }
  const line = el('hub-world-line');
  if (line) {
    const selected = WORLDS[worldIndex()];
    if (selected.id === 'verdant_bloom') {
      const caches = snap.secured_caches && typeof snap.secured_caches === 'object'
        ? Object.values(snap.secured_caches).filter(Boolean).length
        : 0;
      line.textContent = t(selected.lineKey, Math.min(caches, 2));
    } else {
      line.textContent = t(selected.lineKey);
    }
  }
  const eyebrow = el('launch-eyebrow');
  if (eyebrow) eyebrow.textContent = t('launch.eyebrow', WORLDS[worldIndex()].name);
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

/* ------------------------------------------------------------- operative */

/*
 * The operative page: who the player deploys as, and what that operative
 * becomes. Two card groups, one card.
 *
 * The composition follows the character page of a shipped mobile shooter (CoD
 * Mobile's Operator page, Free Fire's Character page) — the operative at the
 * largest scale, the roster on a strip, one lit action — and adds the half
 * those pages do not show: the upgrade ladder as five pictures of the same
 * body. A costume ladder expressed as a text row ("Lv. 12 → Lv. 13") is a
 * costume ladder the player cannot see, which is the whole reason the tier
 * strip is card art rendered from each tier's own GLB.
 *
 * The data is game/resources/heroes/roster.json, not markup: a card exists
 * because a model, a rig and a render exist. `tools/check_hero_roster.py` fails
 * the build if a path in that file is missing, so a card cannot promise a
 * costume nobody made.
 *
 * Motion is meaning here, and both beats are in the scene (ui/hero_stage.js),
 * not a CSS transform on a picture:
 *
 *   selecting a HERO  -> the operative enters from the RIGHT
 *   selecting a TIER  -> the operative enters from the TOP, under a beam, with
 *                        the ring, sparks and a banner naming the rank
 *
 * Every one of them honours "kurangi gerak".
 */

/* The tiers the player owns come from the arena, which mirrors its saved
   profile into localStorage (ProgressionService -> `aegis.runs`). Runs, not
   currency: BP is spent inside the arena (DECISIONS 32) and the shell never
   touches the wallet, while completed runs are a number the shell can read
   without becoming a second save file. */
const RUNS_KEY = 'aegis.runs';

function completedRuns() {
  const raw = window.localStorage ? window.localStorage.getItem(RUNS_KEY) : null;
  const value = Number.parseInt(raw ?? '0', 10);
  return Number.isFinite(value) && value > 0 ? value : 0;
}

let roster = null;
let heroState = { heroId: '', tier: 1, ownedTier: 1 };

function rosterUrl() {
  // Cache-busted: a stale roster next to a fresh render is the one way these
  // two can disagree.
  return './game/resources/heroes/roster.json?v=3';
}

async function loadRoster() {
  if (roster) return roster;
  const response = await fetch(rosterUrl(), { cache: 'no-cache' });
  if (!response.ok) throw new Error(`roster ${response.status}`);
  roster = await response.json();
  return roster;
}

function heroOf(id) {
  if (!roster) return null;
  return roster.heroes.find((hero) => hero.id === id) || roster.heroes[0];
}

function tierTable() {
  return roster ? roster.tiers : [];
}

function tierRow(tier) {
  return tierTable().find((row) => row.tier === tier) || tierTable()[0];
}

/** The highest tier the player's completed runs unlock. */
function ownedTier() {
  const runs = completedRuns();
  let owned = 1;
  for (const row of tierTable()) {
    if (runs >= row.runs_required) owned = Math.max(owned, row.tier);
  }
  return owned;
}

function tierArt(hero, tier) {
  const entry = hero && hero.tiers ? hero.tiers.find((item) => item.tier === tier) : null;
  return entry && entry.art ? entry.art : null;
}

function tierModel(hero, tier) {
  const entry = hero && hero.tiers ? hero.tiers.find((item) => item.tier === tier) : null;
  return entry && entry.model ? entry.model : null;
}

/* The rig sidecar is where the rifle socket lives, so the stage hangs the
   weapon exactly the way the engine does -- per tier, not per guess. */
function tierRig(hero, tier) {
  const entry = hero && hero.tiers ? hero.tiers.find((item) => item.tier === tier) : null;
  return entry && entry.rig ? entry.rig : null;
}

/* One card component, two groups. The difference between them is what the name
   line says (a callsign or a rank) and whether the art window is a portrait or
   a costume — not how the card is built. */
function buildCard({ art, badge, name, role, state, meta, locked, empty, lock }) {
  const button = document.createElement('button');
  button.type = 'button';
  button.className = 'card';
  if (art) {
    const image = document.createElement('img');
    image.className = 'card__art';
    image.src = art;
    image.alt = '';
    button.appendChild(image);
  }
  if (badge) {
    const chip = document.createElement('span');
    chip.className = 'card__badge';
    chip.textContent = badge;
    button.appendChild(chip);
  }
  if (lock) {
    const icon = document.createElementNS('http://www.w3.org/2000/svg', 'svg');
    icon.setAttribute('class', 'ico card__lock');
    icon.setAttribute('aria-hidden', 'true');
    const use = document.createElementNS('http://www.w3.org/2000/svg', 'use');
    use.setAttribute('href', '#i-lock');
    icon.appendChild(use);
    button.appendChild(icon);
  }
  const body = document.createElement('span');
  body.className = 'card__body';
  const nameNode = document.createElement('span');
  nameNode.className = 'card__name';
  nameNode.textContent = name;
  body.appendChild(nameNode);
  if (role) {
    const roleNode = document.createElement('span');
    roleNode.className = 'card__role';
    roleNode.textContent = role;
    body.appendChild(roleNode);
  }
  const stateNode = document.createElement('span');
  stateNode.className = 'card__state';
  stateNode.textContent = state;
  body.appendChild(stateNode);
  if (meta) {
    const metaNode = document.createElement('span');
    metaNode.className = 'card__meta';
    metaNode.textContent = meta;
    body.appendChild(metaNode);
  }
  button.appendChild(body);
  if (locked) button.dataset.locked = 'true';
  if (empty) button.dataset.empty = 'true';
  return button;
}

function paintHeroCards() {
  const host = el('hero-roster');
  if (!host || !roster) return;
  host.replaceChildren();
  for (const hero of roster.heroes) {
    const playable = hero.status === 'field_ready';
    const tier = playable ? Math.min(heroState.tier, ownedTier()) || 1 : 1;
    const card = buildCard({
      art: playable ? tierArt(hero, Math.max(1, tier)) : null,
      name: hero.callsign,
      role: t(hero.role_key),
      state: hero.name,
      meta: playable ? t('hero.status') : t('common.in_development'),
      locked: !playable,
      empty: !playable,
      lock: !playable,
    });
    card.classList.add('herocard');
    card.dataset.hero = hero.id;
    card.setAttribute('aria-pressed', String(hero.id === heroState.heroId));
    // A hero without a rig is a slot with a name, not a button that pretends:
    // `aria-disabled` keeps it reachable by a screen reader (so the player
    // learns it exists) and the click handler refuses it.
    if (!playable) card.setAttribute('aria-disabled', 'true');
    host.appendChild(card);
  }
}

function paintTierCards() {
  const host = el('hero-tiers');
  if (!host || !roster) return;
  const hero = heroOf(heroState.heroId);
  const owned = ownedTier();
  host.replaceChildren();
  for (const row of tierTable()) {
    const isOwned = row.tier <= owned;
    const selected = row.tier === heroState.tier;
    const card = buildCard({
      art: null,
      badge: `T${row.tier}`,
      name: t(row.name_key),
      state: isOwned
        ? selected
          ? t('hero.tier.equipped')
          : t('hero.tier.owned')
        : row.runs_required === 1
          ? t('hero.tier.runs_one', row.runs_required)
          : t('hero.tier.runs', row.runs_required),
      locked: !isOwned,
      empty: false,
      lock: !isOwned,
    });
    card.classList.add('tierstep');
    card.dataset.tier = String(row.tier);
    card.setAttribute('role', 'radio');
    card.setAttribute('aria-checked', String(selected));
    if (!isOwned) {
      // Reachable and previewable: looking at the armour is the reason to play
      // the next run. It is not deployable, and the state line says why.
      card.dataset.preview = String(selected);
    }
    host.appendChild(card);
  }
  const count = el('hero-tier-count');
  if (count) count.textContent = `${heroState.tier} / ${roster.tier_count}`;
}

function paintOperative() {
  if (!roster) return;
  const hero = heroOf(heroState.heroId || roster.heroes[0].id);
  const row = tierRow(heroState.tier);
  const owned = ownedTier();
  const nameNode = el('hero-name');
  if (nameNode) nameNode.textContent = hero.name;
  const callsign = el('hero-callsign');
  if (callsign) callsign.textContent = hero.callsign;
  const tierNumber = el('hero-tier-number');
  if (tierNumber) tierNumber.textContent = String(row.tier);
  const tierName = el('hero-tier-name');
  if (tierName) tierName.textContent = t(row.name_key);
  const roleTitle = el('hero-role-title');
  if (roleTitle) roleTitle.textContent = t(hero.role_key);
  const status = el('hero-status');
  if (status) {
    status.textContent = hero.status === 'field_ready' ? t('hero.status') : t('common.in_development');
  }
  const role = el('hero-role');
  if (role) {
    role.dataset.i18n = hero.brief_key;
    role.textContent = t(hero.brief_key);
  }
  const vitals = el('hero-stat-vitals');
  if (vitals) vitals.textContent = String(row.vitals);
  const armour = el('hero-stat-armour');
  if (armour) armour.textContent = `${row.reduction}%`;
  const vitalsDelta = el('hero-stat-vitals-delta');
  if (vitalsDelta) vitalsDelta.textContent = row.tier > 1 ? t('hero.stat.from_base', row.vitals - 100) : '';
  const armourDelta = el('hero-stat-armour-delta');
  // The plate figure is already the big number, so its note says what the
  // figure *means* rather than repeating it.
  if (armourDelta) armourDelta.textContent = row.reduction > 0 ? t('hero.stat.armour_note') : '';
  const next = el('hero-stat-next');
  const upcoming = tierTable().find((item) => item.tier === row.tier + 1);
  if (next) {
    next.textContent = upcoming
      ? upcoming.runs_required === 1
        ? t('hero.tier.runs_one', upcoming.runs_required)
        : t('hero.tier.runs', upcoming.runs_required)
      : t('hero.tier.max');
  }
  const banner = el('hero-banner-title');
  if (banner) banner.textContent = `${t('hero.tier.word')} ${row.tier}`;
  const bannerNote = el('hero-banner-note');
  if (bannerNote) bannerNote.textContent = t(row.name_key);
  const canvas = el('hero-canvas');
  if (canvas) {
    canvas.dataset.tier = String(row.tier);
    canvas.dataset.hero = hero.id;
    canvas.setAttribute(
      'aria-label',
      t('hero.stage_label', hero.callsign, row.tier, t(row.name_key)),
    );
  }
  // The tier badge on the header says whether what is selected is what the
  // player owns, because a preview that looks identical to an equipped tier is
  // a screen lying about the run.
  const chip = el('hero-tier-chip');
  if (chip) {
    chip.dataset.owned = String(row.tier <= owned);
    chip.dataset.preview = String(row.tier > owned);
  }
  paintHeroCards();
  paintTierCards();
  paintLadder();
}

/* The rail under the numbers. `aegis.runs` is the arena's own mirror of how
   many runs are finished, so the fill is the player's real progress and the
   sentence is the real distance to the next rank. */
function paintLadder() {
  const host = el('hero-ladder');
  if (!host) return;
  const rows = tierTable();
  const owned = ownedTier();
  const runs = completedRuns();
  if (host.childElementCount !== rows.length) {
    host.replaceChildren();
    for (const row of rows) {
      const item = document.createElement('li');
      item.dataset.tier = String(row.tier);
      host.appendChild(item);
    }
  }
  for (const item of host.children) {
    const row = tierRow(Number(item.dataset.tier));
    const isOwned = row.tier <= owned;
    const previous = tierRow(row.tier - 1);
    const floor = previous ? previous.runs_required : 0;
    const span = Math.max(1, row.runs_required - floor);
    item.dataset.state = isOwned ? 'owned' : 'locked';
    // The bar is the fraction of this tier's price already paid, so the ladder
    // grows with every run instead of jumping at the unlock.
    item.style.setProperty(
      '--fill',
      String(isOwned ? 1 : Math.max(0, Math.min(1, (runs - floor) / span))),
    );
    item.dataset.current = String(row.tier === heroState.tier);
  }
  const note = el('hero-ladder-note');
  if (note) {
    const next = rows.find((row) => row.tier === heroState.tier + 1);
    note.textContent = next
      ? t(
          next.runs_required === 1 ? 'hero.ladder.to_next_one' : 'hero.ladder.to_next',
          runs,
          next.runs_required,
          next.tier,
        )
      : t('hero.ladder.max');
  }
}

/* The stage. `ui/hero_stage.js` owns the rig, the deck, the light and the
   entrance; this owns the decision of what to show and from where. */
/* The beat the page is currently playing. It is remembered because the stage
   announces itself twice -- when it mounts and when a model finishes loading --
   and a tier press must still arrive from the TOP after its GLB has landed,
   not restart as a hero selection. */
let lastEntry = 'right';

function stageShow(entry) {
  const stage = window.AegisHeroStage;
  if (entry) lastEntry = entry;
  // Loadout paints also run during OPENING/direct DEPLOY. Never initialize the
  // Three.js stage or fetch hero/weapon models behind the engine preloader.
  // Before the roster answers there is no operative to set, and after a failed
  // fetch there never will be: either way the stage keeps its own default.
  if (current !== 'hero' || typeof stage === 'undefined' || !roster) return;
  const hero = heroOf(heroState.heroId);
  if (!hero) return;
  const weapon = WEAPONS[prefs.weapon] || WEAPONS.pulse_rifle;
  stage.setLoadout({
    heroId: hero.id,
    tier: heroState.tier,
    model: tierModel(hero, heroState.tier),
    rig: tierRig(hero, heroState.tier),
    weaponId: prefs.weapon,
    weaponTier: weaponTierFor(prefs.weapon),
    weaponModel: weapon.model,
    entry: lastEntry,
  });
}

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

/*
 * The celebration: chrome for the one beat the page owns. `direction` is what
 * the player did — a hero selection enters from the right, an upgrade from the
 * top — and the scene is told separately (stageShow). Reduced motion keeps the
 * end state (banner up, ring lit) and drops every traveller.
 */
function celebrate(direction) {
  const screen = screens.hero;
  if (!screen) return;
  buildSparks();
  const reduced = document.documentElement.dataset.motion === 'reduced';
  screen.dataset.celebrate = 'false';
  screen.dataset.enter = direction;
  void screen.offsetWidth; // restart the animations rather than resuming them
  screen.dataset.celebrate = 'true';
  if (typeof window.AegisHeroStage !== 'undefined') window.AegisHeroStage.pulse(direction);
  window.clearTimeout(celebrateTimer);
  celebrateTimer = window.setTimeout(
    () => {
      screen.dataset.celebrate = 'false';
      screen.dataset.enter = '';
    },
    reduced ? 100000 : 2800,
  );
}

/* Sparks are generated rather than typed into the markup: the pattern wants
   variety (angle, distance, colour, duration) and eighteen spans of
   hand-authored custom properties is a transcription, not a design. Whites
   only: the stage is shared by every hero, so a burst in this hero's palette
   would be the one thing in the room that does not belong to the next one. */
const SPARK_COLORS = ['#ffffff', '#e2eaf2', '#b6c2cf', '#f6fafd'];

function selectHero(id) {
  const hero = heroOf(id);
  if (!hero || hero.status !== 'field_ready') return;
  heroState.heroId = hero.id;
  heroState.tier = Math.min(heroState.tier, ownedTier()) || 1;
  prefs.hero = hero.id;
  prefs.tier = heroState.tier;
  savePrefs();
  paintOperative();
  stageShow('right');
  // A card that is already selected still answers: pressing the thing you
  // already have is how a player says "show me again". The beat never includes
  // the upgrade ceremony -- that belongs to the tier strip alone.
  celebrate('right');
}

function selectTier(tier) {
  const row = tierRow(tier);
  if (!row) return;
  heroState.tier = row.tier;
  prefs.tier = row.tier;
  savePrefs();
  paintOperative();
  // Owned or not, the picture is the point; what changes is whether the run
  // can deploy at that tier (see deploy()).
  stageShow('top');
  celebrate('top');
}

document.addEventListener('click', (event) => {
  const heroCard = event.target.closest('#hero-roster .card[data-hero]');
  if (heroCard) {
    selectHero(heroCard.dataset.hero);
    return;
  }
  const tierCard = event.target.closest('#hero-tiers .card[data-tier]');
  if (tierCard) {
    selectTier(Number(tierCard.dataset.tier));
  }
});

/* The stage announces itself instead of assuming the shell got there first: a
   module script and a classic deferred script have no guaranteed order. */
window.addEventListener('aegis:hero-stage-ready', () => {
  if (current !== 'hero') return;
  stageShow();
  if (typeof window.AegisHeroStage !== 'undefined') window.AegisHeroStage.play();
});

window.addEventListener('aegis:hero-stage-mounted', () => {
  if (current === 'hero') stageShow();
});

/* --------------------------------------------------------- weapon modal */

/*
 * The rack, as a sheet with the weapons' own renders. Round 10 asked for the
 * weapon choice to stop being a label; this is one modal over the operative
 * page with a picture, a name, three numbers and a price per weapon, opening
 * from the loadout chip and closing back to it.
 *
 * It does not unlock anything. BP is earned and spent inside the arena, so a
 * priced weapon is listed, priced and refused here — the same rule the in-game
 * armory follows, and the reason the shell cannot become a shop.
 */
function buildRack() {
  const host = el('hero-rack');
  if (!host) return;
  host.replaceChildren();
  for (const [id, weapon] of Object.entries(WEAPONS)) {
    const item = document.createElement('li');
    const button = document.createElement('button');
    button.type = 'button';
    button.className = 'rackcard';
    button.dataset.weapon = id;
    button.dataset.cost = String(weapon.cost);
    const owned = weaponOwned(id);
    const hasBp = weaponHasBlueprint(id);
    const equipped = owned && id === prefs.weapon;
    const tier = weaponTierFor(id);
    const numbers = weaponNumbers(id, tier);
    button.setAttribute('aria-pressed', String(equipped));
    if (!owned) button.setAttribute('aria-disabled', 'true');
    button.innerHTML = `
      <span class="rackcard__art"><img src="${weapon.art}" alt="" /></span>
      <span class="rackcard__row">
        <span class="rackcard__name">${t(weapon.nameKey)}</span>
        <span class="rackcard__tier">T${tier}</span>
      </span>
      <span class="rackcard__state">${
        !owned
          ? !hasBp
            ? t('hero.weapon.blueprint_cost', weapon.cost)
            : t('hero.weapon.cost', weapon.cost)
          : equipped
            ? t('hero.weapon.equipped')
            : t('hero.weapon.owned')
      }</span>
      <span class="rackcard__spec">${numbers.damage} dmg · ${numbers.rate}/s · ${numbers.magazine} · ${numbers.reload}s</span>`;
    item.appendChild(button);
    host.appendChild(item);
  }
}

function openWeaponModal() {
  const modal = el('weapon-modal');
  if (!modal) return;
  buildRack();
  modal.hidden = false;
  const first = modal.querySelector('.rackcard:not([aria-disabled="true"])');
  if (first) first.focus();
  document.addEventListener('keydown', trapWeaponModal);
}

function closeWeaponModal() {
  const modal = el('weapon-modal');
  if (!modal || modal.hidden) return;
  modal.hidden = true;
  document.removeEventListener('keydown', trapWeaponModal);
  el('hero-loadout')?.focus();
}

/* A modal that lets Tab walk into the page behind it is not a modal
   (docs/skills/disciplines/game-ui-ux: trap focus, hand it back on close). */
function trapWeaponModal(event) {
  if (event.key === 'Escape') {
    event.preventDefault();
    closeWeaponModal();
    return;
  }
  if (event.key !== 'Tab') return;
  const modal = el('weapon-modal');
  const focusable = [...modal.querySelectorAll('button')].filter((node) => !node.hidden);
  if (!focusable.length) return;
  const first = focusable[0];
  const last = focusable[focusable.length - 1];
  if (event.shiftKey && document.activeElement === first) {
    event.preventDefault();
    last.focus();
  } else if (!event.shiftKey && document.activeElement === last) {
    event.preventDefault();
    first.focus();
  }
}

el('hero-loadout')?.addEventListener('click', openWeaponModal);
el('weapon-modal-close')?.addEventListener('click', closeWeaponModal);
el('weapon-modal')?.addEventListener('click', (event) => {
  if (event.target === el('weapon-modal')) closeWeaponModal();
});
el('hero-rack')?.addEventListener('click', (event) => {
  const card = event.target.closest('.rackcard');
  if (!card || card.getAttribute('aria-disabled') === 'true') return;
  prefs.weapon = card.dataset.weapon;
  savePrefs();
  paintLoadout();
  buildRack();
  closeWeaponModal();
});

/* Boot: the roster is one fetch, and the screen waits for it rather than
   painting cards that might name a costume the file does not have. */
loadRoster()
  .then(() => {
    heroState.heroId = heroOf(prefs.hero)?.id || roster.heroes[0].id;
    heroState.tier = Math.min(Math.max(1, Number(prefs.tier) || 1), roster.tier_count);
    heroState.tier = Math.min(heroState.tier, ownedTier()) || 1;
    paintOperative();
    const screen = screens.hero;
    if (screen) screen.dataset.ready = 'true';
    if (current === 'hero') {
      stageShow('right');
      celebrate('right');
    }
  })
  .catch((error) => {
    // A roster that will not load is a shell problem, not a player problem:
    // say it where the cards would be rather than showing an empty strip.
    const host = el('hero-roster');
    if (host) host.textContent = `roster unavailable · ${error.message}`;
    console.warn('[operative]', error);
  });

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
  pulse_rifle: {
    nameKey: 'wpn.pulse.name',
    cost: 0,
    art: './game/assets/ui/weapon_pulse_rifle.png',
    model: './game/assets/weapons/futuristic_rifle/rifle.glb',
    definition: { damage: 18, fire_rate: 5, magazine_size: 24, reload_seconds: 1.35 },
  },
  nova_launcher: {
    nameKey: 'wpn.nova.name',
    cost: 120,
    art: './game/assets/ui/weapon_nova_launcher.png',
    model: './game/assets/weapons/futuristic_rifle/rifle.glb',
    definition: { damage: 34, fire_rate: 0.8, magazine_size: 6, reload_seconds: 2.2 },
  },
  arc_shooter: {
    nameKey: 'wpn.arc.name',
    cost: 250,
    art: './game/assets/ui/weapon_arc_shooter.png',
    model: './game/assets/weapons/futuristic_rifle/rifle.glb',
    definition: { damage: 20, fire_rate: 2, magazine_size: 12, reload_seconds: 1.7 },
  },
};

/* This is a read-only mirror of ProgressionService, never a shell save. The
   shared JSON supplies ranks/costs; the .tres files refresh base stats below. */
let weaponTierData = {
  tier_count: 1,
  tiers: [{ tier: 1, damage_multiplier: 1, reload_multiplier: 1, costs: {} }],
};

function profileSnapshot() {
  try {
    return JSON.parse(window.localStorage?.getItem('aegis.progress') || 'null') || {};
  } catch {
    return {};
  }
}

function weaponOwned(id) {
  if (id === 'pulse_rifle') return true;
  const unlocked = profileSnapshot().unlocked;
  return Array.isArray(unlocked) && unlocked.includes(id);
}

function weaponHasBlueprint(id) {
  if (id !== 'arc_shooter') return true;
  const blueprints = profileSnapshot().blueprints;
  return Array.isArray(blueprints) && blueprints.includes(id);
}

function weaponTierFor(id) {
  const saved = profileSnapshot().weapon_tiers;
  const raw = saved && typeof saved === 'object' ? Number(saved[id]) : 1;
  return Math.min(weaponTierData.tier_count, Math.max(1, Number.isFinite(raw) ? Math.floor(raw) : 1));
}

function weaponTierRow(tier) {
  return weaponTierData.tiers.find((row) => row.tier === tier) || weaponTierData.tiers[0];
}

function weaponNumbers(id, tier = weaponTierFor(id)) {
  const weapon = WEAPONS[id] || WEAPONS.pulse_rifle;
  const row = weaponTierRow(tier);
  const damageScale = Number(row?.damage_multiplier) || 1;
  const reloadScale = Number(row?.reload_multiplier) || 1;
  const base = weapon.definition;
  return {
    damage: Math.round(base.damage * damageScale),
    rate: base.fire_rate.toFixed(1),
    magazine: base.magazine_size,
    reload: Number((base.reload_seconds * reloadScale).toFixed(2)).toString(),
  };
}

function weaponName(id) {
  const weapon = WEAPONS[id] || WEAPONS.pulse_rifle;
  return t(weapon.nameKey);
}

async function loadWeaponData() {
  const response = await fetch('./game/resources/weapons/tiers.json', { cache: 'no-cache' });
  if (!response.ok) throw new Error(`weapon tiers ${response.status}`);
  const table = await response.json();
  if (!Array.isArray(table.tiers) || !table.tiers.length) throw new Error('weapon tiers empty');
  weaponTierData = table;
  await Promise.all(
    Object.entries(WEAPONS).map(async ([id, weapon]) => {
      const reply = await fetch(`./game/resources/weapons/${id}.tres`, { cache: 'no-cache' });
      if (!reply.ok) throw new Error(`${id} ${reply.status}`);
      const source = await reply.text();
      for (const key of ['damage', 'fire_rate', 'magazine_size', 'reload_seconds']) {
        const match = source.match(new RegExp(`^${key}\\s*=\\s*([0-9.]+)`, 'm'));
        if (match) weapon.definition[key] = Number(match[1]);
      }
    }),
  );
  paintLoadout();
  if (!el('weapon-modal')?.hidden) buildRack();
}

function paintLoadout() {
  if (!weaponOwned(prefs.weapon)) prefs.weapon = 'pulse_rifle';
  for (const button of document.querySelectorAll('.rackcard')) {
    const owned = weaponOwned(button.dataset.weapon);
    button.setAttribute('aria-pressed', String(owned && button.dataset.weapon === prefs.weapon));
    button.setAttribute('aria-disabled', String(!owned));
  }
  const id = prefs.weapon;
  const weapon = WEAPONS[id];
  const tier = weaponTierFor(id);
  const numbers = weaponNumbers(id, tier);
  const name = weaponName(id);
  const chip = el('hero-loadout-weapon');
  if (chip) chip.textContent = name;
  const tierNode = el('hero-weapon-tier');
  if (tierNode) tierNode.textContent = `T${tier}`;
  const art = el('hero-weapon-art');
  if (art) art.src = weapon.art;
  const stats = el('hero-weapon-stats');
  if (stats) stats.textContent = `${numbers.damage} DMG · ${numbers.reload}s`;
  const next = el('hero-weapon-next');
  if (next) {
    const cost = Number(weaponTierRow(tier + 1)?.costs?.[id]);
    next.textContent = tier >= weaponTierData.tier_count
      ? t('hero.weapon.tier_max')
      : t('hero.weapon.next_tier', tier + 1, cost, t('hero.weapon.armory'));
  }
  const track = el('hero-weapon-tiers');
  if (track) {
    if (track.childElementCount !== weaponTierData.tier_count) {
      track.replaceChildren();
      for (let rank = 1; rank <= weaponTierData.tier_count; rank += 1) {
        const item = document.createElement('li');
        item.dataset.tier = String(rank);
        track.appendChild(item);
      }
    }
    for (const item of track.children) {
      const rank = Number(item.dataset.tier);
      item.dataset.owned = String(rank <= tier);
      item.dataset.current = String(rank === tier);
    }
  }
  const hub = el('hub-operative-meta');
  if (hub) hub.textContent = `${name} · T${tier}`;
  const deployMeta = el('hub-deploy-meta');
  if (deployMeta) deployMeta.textContent = `${name} · T${tier}`;
  stageShow();
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
  // A direct ?ui=launch navigation must not erase an opening preflight failure
  // and then strand the player on a connecting screen with no active boot.
  if (bootState === 'failed') {
    show('launch', { focus: false });
    return;
  }
  lockLandscape();
  savePrefs();
  paintWorld();
void audio.play('deploy');
  el('launch-title').textContent = t('launch.title');
  el('launch-status').textContent = t('launch.status.connecting');
  el('launch-hint').textContent = t('launch.hint.preloaded');
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
  // The operative and the tier the player is looking at, clamped to what they
  // own: ProgressionService re-checks both and refuses anything else, so a
  // hand-edited URL cannot field a tier nobody unlocked.
  url.searchParams.set('hero', prefs.hero || 'sable');
  url.searchParams.set('tier', String(Math.min(Number(prefs.tier) || 1, ownedTier())));
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
  if (error?.launchTitle) {
    launchFailed(error.launchTitle, detail);
  } else if (/failed to fetch|network\s*error|load failed|failed loading file|err_(?:failed|content_length_mismatch)/i.test(detail)) {
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
  const supportIssue = browserSupportIssue();
  if (supportIssue) {
    const error = new Error(supportIssue.detail);
    error.launchTitle = supportIssue.title;
    throw error;
  }
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
el('launch-status').textContent = t('launch.status.stopped');
  el('launch-percent').textContent = '';
  el('launch-hint').textContent = String(detail);
  el('launch-progress').dataset.indeterminate = 'false';
el('launch-retry').hidden = false;
  paintDock('bad', t('dock.failed'));
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
el('hero-back')?.addEventListener('click', () => show(fromHero, { focus: false }));
el('hub-deploy').addEventListener('click', () => deploy());
el('launch-retry').addEventListener('click', () => window.location.reload());
el('hub-card-operative').addEventListener('click', () => show('hero', { from: 'hub' }));
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

/*
 * The language row: one press, the whole document re-reads, and the engine is
 * told through `window.aegisSetLocale` if it is already running. The value is
 * shown in the language's own name -- a player looking for Indonesian should not
 * have to find the word "Indonesian" in English first.
 */
function paintLanguage() {
  const value = el('opt-language-value');
  if (value) value.textContent = nativeName(locale());
}

el('opt-language')?.addEventListener('click', () => {
  // `setLocale` re-reads the static tree, writes `?lang=` into the URL so a
  // reload agrees, and calls the running engine's callback if it registered one.
  setLocale(nextLocale());
  paintLanguage();
  // The dynamic lines (opening status, dock state, launch title, the theatre
  // line) are painted by their owners, so the switch repaints them by hand.
  paintOpening();
  paintWorld();
  paintDock(engineReady ? 'ok' : 'warn', engineReady ? t('dock.ready') : t('dock.not_ready'));
  if (current === 'launch') el('launch-title').textContent = t('launch.title');
});

document.addEventListener('aegis:locale', () => {
  paintLanguage();
  // The cards are built in JavaScript, so their words are not in the tree the
  // catalogue walks: they are repainted here, by the function that knows how.
  paintOperative();
  paintLoadout();
  if (!el('weapon-modal')?.hidden) buildRack();
});

document.addEventListener('keydown', (event) => {
  if (event.defaultPrevented) return;
  if (event.key === 'Escape') {
    event.preventDefault();
    back();
    return;
  }
  // Arrows walk the tier ladder: up is the next rank, down is the previous one,
  // and the same beat plays, because a keyboard player gets the same screen.
  if (
    current === 'hero' &&
    (event.key === 'ArrowUp' || event.key === 'ArrowDown' || event.key === 'ArrowRight' || event.key === 'ArrowLeft') &&
    document.body.dataset.mode !== 'playing'
  ) {
    event.preventDefault();
    const max = roster ? roster.tier_count : 5;
    const step = event.key === 'ArrowUp' || event.key === 'ArrowRight' ? 1 : -1;
    selectTier(Math.min(max, Math.max(1, heroState.tier + step)));
    document.querySelector(`#hero-tiers .card[data-tier="${heroState.tier}"]`)?.focus();
    return;
  }
  if (current === 'hub' && (event.key === 'ArrowRight' || event.key === 'ArrowLeft')) {
    event.preventDefault();
    stepWorld(event.key === 'ArrowRight' ? 1 : -1);
    return;
  }
  if (event.key === 'Enter') {
    const active = screens[current].querySelector(
      '.btn--primary, .wcard[aria-selected="true"], .wcard, .card[aria-pressed="true"], .card',
    );
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

// Language first: every painter below reads its words from the catalog, so the
// active language has to be resolved before the first frame is painted.
initLocale();
applyLocale();
applyMotionPref();
applyPrefsToUrl();
paintAudioControl();
paintLanguage();
paintDock(engineReady ? 'ok' : 'warn', engineReady ? t('dock.ready') : t('dock.not_ready'));
paintLoadout();
loadWeaponData().catch((error) => console.warn('[operative] weapon data', error));
paintWorld();
paintOpening();
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
