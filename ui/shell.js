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
import {
  apply as applyLocale,
  init as initLocale,
  locale,
  nativeName,
  nextLocale,
  setLocale,
  t,
} from './i18n.js';

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
    hero: 'sable',
    tier: 1,
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
    ? t('opening.status.ready')
    : failed
      ? t('opening.status.failed')
      : `${t('opening.status.checking')} · ${Math.round(ratio * 100)}%`;

  const button = el('opening-enter');
  button.disabled = !done;
  button.querySelector('.btn__label').textContent = done
    ? t('opening.enter')
    : t('opening.enter_wait');
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
    showNote(t('opening.note.no_engine'));
  } else if (!checks.payload) {
    showNote(t('opening.note.no_payload'));
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
  { id: 'neon_frontier', name: 'Neon Frontier', lineKey: 'world.neon_frontier.line' },
  { id: 'vanguard_station', name: 'Vanguard Station', lineKey: 'world.vanguard_station.line' },
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
  if (line) line.textContent = t(WORLDS[worldIndex()].lineKey);
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
function buildCard({ art, badge, name, state, locked, empty, lock }) {
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
  const stateNode = document.createElement('span');
  stateNode.className = 'card__state';
  stateNode.textContent = state;
  body.append(nameNode, stateNode);
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
      state: playable ? hero.name : t('common.in_development'),
      locked: !playable,
      empty: !playable,
      lock: !playable,
    });
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
    const art = tierArt(hero, row.tier);
    const isOwned = row.tier <= owned;
    const selected = row.tier === heroState.tier;
    const card = buildCard({
      art,
      badge: String(row.tier),
      name: t(row.name_key),
      state: isOwned
        ? selected
          ? t('hero.tier.equipped')
          : t('hero.tier.owned')
        : row.runs_required === 1
          ? t('hero.tier.runs_one', row.runs_required)
          : t('hero.tier.runs', row.runs_required),
      locked: !isOwned,
      empty: !art,
      lock: !isOwned,
    });
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
  // Before the roster answers there is no operative to set, and after a failed
  // fetch there never will be: either way the stage keeps its own default.
  if (typeof stage === 'undefined' || !roster) return;
  const hero = heroOf(heroState.heroId);
  if (!hero) return;
  stage.setLoadout({
    heroId: hero.id,
    tier: heroState.tier,
    model: tierModel(hero, heroState.tier),
    rig: tierRig(hero, heroState.tier),
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
    const locked = weapon.cost > 0;
    button.setAttribute('aria-pressed', String(!locked && id === prefs.weapon));
    if (locked) button.setAttribute('aria-disabled', 'true');
    button.innerHTML = `
      <span class="rackcard__art"><img src="${weapon.art}" alt="" /></span>
      <span class="rackcard__row">
        <span class="rackcard__name">${t(weapon.nameKey)}</span>
        <span class="rackcard__state">${
          locked ? t('hero.weapon.cost', weapon.cost) : t('hero.weapon.equipped')
        }</span>
      </span>
      <span class="rackcard__spec">${weapon.spec}</span>`;
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
    spec: '18 dmg · 5.0/s · 24',
  },
  nova_launcher: {
    nameKey: 'wpn.nova.name',
    cost: 120,
    art: './game/assets/ui/weapon_nova_launcher.png',
    spec: '34 dmg · 0.8/s · 6',
  },
  arc_shooter: {
    nameKey: 'wpn.arc.name',
    cost: 250,
    art: './game/assets/ui/weapon_arc_shooter.png',
    spec: '20 dmg · 2.0/s · 12',
  },
};

function weaponName(id) {
  const weapon = WEAPONS[id] || WEAPONS.pulse_rifle;
  return t(weapon.nameKey);
}

function paintLoadout() {
  for (const button of document.querySelectorAll('.rackcard')) {
    const locked = Number(button.dataset.cost) > 0;
    // A priced weapon is not "selected", it is "available later": pressing it
    // moves the focus ring and nothing else, so the screen never claims a
    // loadout the game would refuse. `aria-disabled` is how that is said, and
    // it is the same attribute the CSS colours the price from.
    button.setAttribute('aria-pressed', String(!locked && button.dataset.weapon === prefs.weapon));
    button.setAttribute('aria-disabled', String(locked));
  }
  // Resolved through the catalogue, not stored: a weapon's name is the player's
  // word for it, and painting it from a literal left three English chips on an
  // Indonesian page (qa-evidence/ui/round-12/i18n).
  const weapon = weaponName(prefs.weapon);
  const chip = el('hero-loadout-weapon');
  if (chip) chip.textContent = weapon;
  const hub = el('hub-operative-meta');
  if (hub) hub.textContent = weapon;
  const deployMeta = el('hub-deploy-meta');
  if (deployMeta) deployMeta.textContent = weapon;
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
  el('launch-title').textContent = t('launch.title');
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
  // The operative and the tier the player is looking at, clamped to what they
  // own: ProgressionService re-checks both and refuses anything else, so a
  // hand-edited URL cannot field a tier nobody unlocked.
  url.searchParams.set('hero', prefs.hero || 'sable');
  url.searchParams.set('tier', String(Math.min(Number(prefs.tier) || 1, ownedTier())));
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
    launchFailed(t('launch.failed.payload'), String(error));
    return;
  }
  const match = html.match(/const GODOT_CONFIG = (\{[^\n]*\});/);
  if (!match) {
    launchFailed(t('launch.failed.config'), './web/index.html has no GODOT_CONFIG line.');
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
  status.textContent = t('launch.status.loading');

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
        status.textContent =
          ratio >= 1 ? t('launch.status.assembling') : t('launch.status.loading');
      }
    },
  }).then(
    () => {
      engineReady = true;
      paintDock('ok', t('dock.ready'));
      progress.dataset.indeterminate = 'false';
      fill.style.width = '100%';
      percent.textContent = '100%';
      status.textContent = t('launch.status.ready');
      hint.textContent = t('launch.hint.enter');
      revealCanvas();
    },
    (error) => launchFailed(t('launch.failed.world'), String(error)),
  );
}

function launchFailed(title, detail) {
  el('launch-title').textContent = title;
  el('launch-status').textContent = t('launch.status.stopped');
  el('launch-percent').textContent = '';
  el('launch-hint').textContent = detail;
  el('launch-progress').dataset.indeterminate = 'false';
  paintDock('bad', t('dock.failed'));
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
el('hero-back')?.addEventListener('click', () => show(fromHero, { focus: false }));
el('hub-deploy').addEventListener('click', () => deploy());
el('hub-card-operative').addEventListener('click', () => show('hero', { from: 'hub' }));
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
paintLanguage();
paintDock(engineReady ? 'ok' : 'warn', engineReady ? t('dock.ready') : t('dock.not_ready'));
paintLoadout();
paintWorld();
paintOpening();
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
