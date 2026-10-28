/*
 * The shell's half of the two-language rule.
 *
 * The Godot build keeps its words in `game/scripts/i18n/aegis_text_catalog.gd`.
 * This file is the same idea for the HTML front end, which is a separate
 * document and cannot read that catalog. Both carry English and Indonesian, both
 * are written natively rather than translated word for word, and both switch
 * from the same stored choice, so the page and the canvas can never disagree
 * about what language the player is reading.
 *
 * How the two stay in step:
 *   1. `init()` resolves the language once — `?lang=`, then localStorage, then
 *      the browser's own preference — and writes it back into the URL with
 *      `history.replaceState`, so a reload hands the same value to the engine.
 *   2. The engine reads that same `?lang=` on boot (`AegisText`).
 *   3. When the switch is flipped after boot, `setLocale` also calls
 *      `window.aegisSetLocale`, a callback the running game registers through
 *      `JavaScriptBridge`. No reload, so no lost run.
 *
 * Static text lives in the document as `data-i18n="key"`; labels that are not
 * text nodes use `data-i18n-aria` / `data-i18n-title`.
 */

export const LOCALES = ['en', 'id'];
export const NATIVE_NAMES = { en: 'ENGLISH', id: 'BAHASA INDONESIA' };

const STRINGS = {
  en: {
    'rotate.title': 'ROTATE DEVICE',
    'rotate.hint': 'This console only runs in landscape',

    'opening.tagline': 'No line at your back',
    'opening.status.checking': 'Preparing console',
    'opening.status.ready': 'Console ready · connect',
    'opening.status.failed': 'Console not ready',
    'opening.status.assets_ready': 'Assets complete · preparing console',
    'opening.status.downloading': 'Downloading engine + world',
    'opening.retry': 'TRY AGAIN',
    'opening.enter': 'ENTER',
    'opening.enter_wait': 'PREPARING',
    'opening.note.no_engine':
      'Console did not load. From the repository root run: python3 tools/serve_preview.py --port 800',
    'opening.note.no_payload':
      'World package (web/index.pck) is missing. Re-export with ./scripts/export_web_preview.sh',
    'opening.note.insecure_context':
      'Godot audio needs a secure browser context. Use HTTPS, or open http://localhost:%s/ on the same computer that runs the server. Plain HTTP through a LAN IP is not secure; localhost on another device points to that device. Reload after changing the URL.',
    'opening.note.no_audio_worklet':
      'This browser does not provide AudioWorklet, which Godot audio requires. Open the page in an up-to-date Chrome, Edge, Firefox, or Safari browser (not an embedded/in-app browser), then reload.',
    'opening.note.missing_features':
      'This browser is missing required Web features: %s. Use an up-to-date browser and enable WebGL 2/hardware acceleration, then reload.',
    'opening.rail_label': 'Preparing console',

    'dock.ready': 'Console ready',
    'dock.not_ready': 'Console not ready',
    'dock.failed': 'Console failed to load',
    'dock.settings': 'Display and controls',
    'dock.settings_title': 'Display',

    'hub.eyebrow': 'OPERATIONS MAP',
    'hub.title': 'CHOOSE THEATRE',
    'hub.carousel_label': 'Theatres',
    'hub.prev': 'Previous theatre',
    'hub.next': 'Next theatre',
    'hub.deploy': 'DEPLOY',
    'hub.hint': 'The first wave starts inside the arena',
    'hub.tile.operative': 'OPERATIVE',
    'hub.tile.display': 'DISPLAY',
    'hub.tile.display_meta': 'HUD · motion',
    'hub.tile.controls': 'CONTROLS',
    'hub.tile.controls_meta': 'Keys',
    'hub.menu': 'Menu',

    'world.frostline_relay.role': 'Relay · frozen antenna field',
    'world.frostline_relay.line': 'Frostline Relay · frozen signal field',
    'world.verdant_bloom.role': 'Recovery · overgrown research dome',
    'world.verdant_bloom.line': 'Verdant Bloom · research sanctuary',
    'world.emberfall_foundry.role': 'Foundry · furnace and cinder yard',
    'world.emberfall_foundry.line': 'Emberfall Foundry · furnace district',
    'world.titans.role': 'Storm · fallen giant',
    'world.titans.line': 'THE TITANS · storm approach',
    'world.vanguard_station.role': 'Hangar · blast door',
    'world.vanguard_station.line': 'Vanguard Station · hangar 02',
    'world.slot_03.name': 'Sector 08',
    'world.slot_03.role': 'Not open yet',
    'wpn.pulse.name': 'PULSE RIFLE',
    'wpn.nova.name': 'NOVA LAUNCHER',
    'wpn.arc.name': 'ARC SHOOTER',
    'wpn.unit_damage': 'dmg',
    'wpn.unit_bp': 'BP',
    'world.state.open': 'OPEN',
    'world.state.soon': 'SOON',
    'common.close': 'Close',
    'common.in_development': 'IN DEVELOPMENT',

    'hero.eyebrow': 'OPERATIVE',
    'hero.name': 'Mara Voss',
    'hero.callsign': 'SABLE',
    'hero.status': 'Field ready',
    'hero.stage_label': '%s, tier %s %s, rendered live from her rig',
    'hero.group.heroes': 'OPERATIVES',
    'hero.group.tiers': 'TIER',
    'hero.tier.word': 'TIER',
    'hero.tier.equipped': 'EQUIPPED',
    'hero.tier.owned': 'OWNED',
    'hero.tier.runs': '%s RUNS',
    'hero.tier.runs_one': '%s RUN',
    'hero.tier.max': 'MAX',
    'hero.tier.ladder':
      'Runs unlock the rank: one run opens tier 2, three open tier 3, six open tier 4, ten open tier 5. Every tier is plate welded over the one before it.',
    'hero.tier.1.name': 'FIELD RECRUIT',
    'hero.tier.2.name': 'PLATED',
    'hero.tier.3.name': 'FRONT LINE',
    'hero.tier.4.name': 'SPEARHEAD',
    'hero.tier.5.name': 'WARPLATE',
    'hero.stat.vitals': 'VITALS',
    'hero.stat.armour': 'ARMOUR',
    'hero.stat.next': 'NEXT TIER',
    'hero.ladder.label': 'TIER LADDER',
    'hero.ladder.to_next': '%s / %s RUNS TO TIER %s',
    'hero.ladder.to_next_one': '%s / %s RUN TO TIER %s',
    'hero.ladder.max': 'ALL FIVE TIERS OPEN',
    'hero.stat.from_base': '+%s HP',
    'hero.stat.armour_note': 'blocked',
    'hero.loadout': 'LOADOUT',
    'hero.progress': 'HERO PROGRESSION',
    'hero.combat_role': 'COMBAT ROLE',
    'hero.weapon.equipped_weapon': 'EQUIPPED WEAPON',
    'hero.weapon.choose': 'Choose equipped weapon',
    'hero.weapon.tier': 'WEAPON TIER',
    'hero.weapon.next_tier': 'T%s · %s BP · %s',
    'hero.weapon.tier_max': 'MAX TIER',
    'hero.weapon.armory': 'ARMORY',
    'hero.weapon.owned': 'Owned',
    'hero.sable.role': 'STRIKE LEAD',
    'hero.sable.brief':
      'Raised on the frontier line and fielded as a strike lead. Her kit is the rank: every tier is plate welded over the last one, and the arena fields whichever tier you own.',
    'hero.kestrel.role': 'SCOUT',
    'hero.kestrel.brief':
      'A scout with a rig still on the bench. The slot is real and its name is real; there is no body to render yet, so nothing here can be pressed.',
    'hero.ready_chip': 'READY',
    'hero.weapon.eyebrow': 'WEAPON RACK',
    'hero.weapon.title': 'CHOOSE A WEAPON',
    'hero.weapon.equipped': 'Equipped',
    'hero.weapon.cost': '%s BP',
    'hero.weapon.note':
      'The selected weapon travels with you on Deploy. Priced weapons are bought in the arena, with the BP the arena pays.',
    'hero.next': 'CONTINUE TO MAP',
    'hero.back': 'BACK',

    'settings.title': 'Display & controls',
    'settings.close': 'CLOSE',
    'settings.touch': 'Touch HUD',
    'settings.touch_hint': 'Joystick and fire button are always available.',
    'settings.motion': 'Reduce motion',
    'settings.motion_hint': 'Screen transitions are turned off.',
    'settings.fullscreen': 'Full screen',
    'settings.fullscreen_hint': 'The browser bar goes away while you play.',
    'settings.controls': 'CONTROLS',
    'settings.language': 'Language',
    'settings.language_hint': 'Applies to the lobby and the arena.',
    'key.move': 'Move',
    'key.aim': 'Aim',
    'key.fire': 'Fire',
    'key.swap': 'Swap weapon',
    'key.emp': 'EMP',
    'key.defense': 'Defence',
    'key.pause': 'Pause',
    'key.aim_value': 'Right click',
    'key.fire_value': 'Left click',

    'launch.eyebrow': 'DEPLOY · %s',
    'launch.title': 'PREPARING WORLD',
    'launch.rail_label': 'Loading world assets',
    'launch.status.loading': 'Loading world assets',
    'launch.status.connecting': 'Connecting the world package',
    'launch.status.assembling': 'Assets complete · assembling world',
    'launch.status.ready': 'World ready',
    'launch.status.stopped': 'Stopped',
    'launch.retry': 'TRY AGAIN',
    'launch.retry_meta': 'reload',
    'launch.hint.preloaded': 'The world package downloads once during opening. Deploy prepares the selected theatre.',
    'launch.hint.enter': 'Entering the world…',
    'launch.hint.stay': 'Stay on this screen until the world is ready.',
    'launch.failed.payload': 'Payload could not be read',
    'launch.failed.config': 'Export configuration could not be read',
    'launch.failed.world': 'World failed to load',
    'launch.failed.secure_context': 'Secure connection required',
    'launch.failed.browser': 'Browser not supported',
  },
  id: {
    'rotate.title': 'PUTAR PERANGKAT',
    'rotate.hint': 'Konsol ini hanya berjalan dalam mode mendatar',

    'opening.tagline': 'Tak ada garis di belakangmu',
    'opening.status.checking': 'Menyiapkan konsol',
    'opening.status.ready': 'Konsol siap · sambungkan',
    'opening.status.failed': 'Konsol tidak siap',
    'opening.status.assets_ready': 'Aset lengkap · menyiapkan konsol',
    'opening.status.downloading': 'Mengunduh mesin + dunia',
    'opening.retry': 'COBA LAGI',
    'opening.enter': 'MASUK',
    'opening.enter_wait': 'MENYIAPKAN',
    'opening.note.no_engine':
      'Konsol tidak termuat. Dari akar repo jalankan: python3 tools/serve_preview.py --port 800',
    'opening.note.no_payload':
      'Paket dunia (web/index.pck) tidak ada. Ekspor ulang lewat ./scripts/export_web_preview.sh',
    'opening.note.insecure_context':
      'Audio Godot membutuhkan konteks aman. Gunakan HTTPS, atau buka http://localhost:%s/ di komputer yang menjalankan server. HTTP biasa melalui IP LAN tidak aman; localhost di HP/perangkat lain menunjuk perangkat itu sendiri. Muat ulang setelah mengganti URL.',
    'opening.note.no_audio_worklet':
      'Browser ini tidak menyediakan AudioWorklet yang dibutuhkan audio Godot. Buka halaman di Chrome, Edge, Firefox, atau Safari versi terbaru (bukan browser sematan/di dalam aplikasi), lalu muat ulang.',
    'opening.note.missing_features':
      'Browser ini kekurangan fitur Web yang dibutuhkan: %s. Gunakan browser versi terbaru dan aktifkan WebGL 2/akselerasi perangkat keras, lalu muat ulang.',
    'opening.rail_label': 'Menyiapkan konsol',

    'dock.ready': 'Konsol siap',
    'dock.not_ready': 'Konsol belum siap',
    'dock.failed': 'Konsol gagal dimuat',
    'dock.settings': 'Tampilan dan kontrol',
    'dock.settings_title': 'Tampilan',

    'hub.eyebrow': 'PETA OPERASI',
    'hub.title': 'PILIH TEATER',
    'hub.carousel_label': 'Teater',
    'hub.prev': 'Teater sebelumnya',
    'hub.next': 'Teater berikutnya',
    'hub.deploy': 'DEPLOY',
    'hub.hint': 'Gelombang pertama dimulai di dalam arena',
    'hub.tile.operative': 'OPERATIF',
    'hub.tile.display': 'TAMPILAN',
    'hub.tile.display_meta': 'HUD · gerak',
    'hub.tile.controls': 'KONTROL',
    'hub.tile.controls_meta': 'Tombol',
    'hub.menu': 'Menu',

    'world.frostline_relay.role': 'Relai · ladang antena beku',
    'world.frostline_relay.line': 'Frostline Relay · ladang sinyal beku',
    'world.verdant_bloom.role': 'Pemulihan · kubah riset yang ditumbuhi',
    'world.verdant_bloom.line': 'Verdant Bloom · suaka riset',
    'world.emberfall_foundry.role': 'Pengecoran · tungku dan halaman bara',
    'world.emberfall_foundry.line': 'Emberfall Foundry · distrik tungku',
    'world.titans.role': 'Badai · raksasa yang gugur',
    'world.titans.line': 'THE TITANS · pendekatan badai',
    'world.vanguard_station.role': 'Hanggar · pintu ledak',
    'world.vanguard_station.line': 'Vanguard Station · hanggar 02',
    'world.slot_03.name': 'Sektor 08',
    'world.slot_03.role': 'Belum dibuka',
    'wpn.pulse.name': 'PULSE RIFLE',
    'wpn.nova.name': 'NOVA LAUNCHER',
    'wpn.arc.name': 'ARC SHOOTER',
    'wpn.unit_damage': 'dmg',
    'wpn.unit_bp': 'BP',
    'world.state.open': 'TERBUKA',
    'world.state.soon': 'SEGERA',
    'common.close': 'Tutup',
    'common.in_development': 'SEDANG DIBUAT',

    'hero.eyebrow': 'OPERATIF',
    'hero.name': 'Mara Voss',
    'hero.callsign': 'SABLE',
    'hero.status': 'Siap berangkat',
    'hero.stage_label': '%s, tingkat %s %s, dirender langsung dari rig-nya',
    'hero.group.heroes': 'OPERATIF',
    'hero.group.tiers': 'TINGKAT',
    'hero.tier.word': 'TINGKAT',
    'hero.tier.equipped': 'DIPAKAI',
    'hero.tier.owned': 'TERBUKA',
    'hero.tier.runs': '%s RUN',
    'hero.tier.runs_one': '%s RUN',
    'hero.tier.max': 'MAKS',
    'hero.tier.ladder':
      'Jumlah run membuka tingkatnya: satu run membuka tingkat 2, tiga run tingkat 3, enam run tingkat 4, sepuluh run tingkat 5. Tiap tingkat adalah pelat yang dilas menutup pelat sebelumnya.',
    'hero.tier.1.name': 'REKRUT LAPANGAN',
    'hero.tier.2.name': 'BERPELAT',
    'hero.tier.3.name': 'GARIS DEPAN',
    'hero.tier.4.name': 'UJUNG TOMBAK',
    'hero.tier.5.name': 'ZIRAH PERANG',
    'hero.stat.vitals': 'DARAH',
    'hero.stat.armour': 'PELINDING',
    'hero.stat.next': 'TINGKAT BERIKUT',
    'hero.ladder.label': 'TANGGA TINGKAT',
    'hero.ladder.to_next': '%s / %s RUN MENUJU TINGKAT %s',
    'hero.ladder.to_next_one': '%s / %s RUN MENUJU TINGKAT %s',
    'hero.ladder.max': 'KELIMA TINGKAT TERBUKA',
    'hero.stat.from_base': '+%s HP',
    'hero.stat.armour_note': 'ditahan',
    'hero.loadout': 'PERLENGKAPAN',
    'hero.progress': 'PROGRES HERO',
    'hero.combat_role': 'PERAN TEMPUR',
    'hero.weapon.equipped_weapon': 'SENJATA TERPASANG',
    'hero.weapon.choose': 'Pilih senjata terpasang',
    'hero.weapon.tier': 'TIER SENJATA',
    'hero.weapon.next_tier': 'T%s · %s BP · %s',
    'hero.weapon.tier_max': 'TIER MAKS',
    'hero.weapon.armory': 'ARSENAL',
    'hero.weapon.owned': 'Dimiliki',
    'hero.sable.role': 'PEMIMPIN SERBU',
    'hero.sable.brief':
      'Besar di garis perbatasan, diterjunkan sebagai pemimpin serbu. Perlengkapannya adalah pangkatnya: tiap tingkat adalah pelat yang dilas menutup pelat sebelumnya, dan arena memakai tingkat yang sudah kamu punya.',
    'hero.kestrel.role': 'PENINJAU',
    'hero.kestrel.brief':
      'Seorang peninjau yang rig-nya masih di meja kerja. Slotnya nyata dan namanya nyata; belum ada tubuh untuk dirender, jadi tidak ada yang bisa ditekan di sini.',
    'hero.ready_chip': 'SIAP',
    'hero.weapon.eyebrow': 'RAK SENJATA',
    'hero.weapon.title': 'PILIH SENJATA',
    'hero.weapon.equipped': 'Terpasang',
    'hero.weapon.cost': '%s BP',
    'hero.weapon.note':
      'Senjata terpilih terbawa saat berangkat. Senjata berharga dibeli di dalam arena, dengan BP yang dibayar arena.',
    'hero.next': 'LANJUT KE PETA',
    'hero.back': 'KEMBALI',

    'settings.title': 'Tampilan & kontrol',
    'settings.close': 'TUTUP',
    'settings.touch': 'HUD sentuh',
    'settings.touch_hint': 'Joystick dan tombol tembak selalu ada.',
    'settings.motion': 'Kurangi gerak',
    'settings.motion_hint': 'Transisi layar dimatikan.',
    'settings.fullscreen': 'Layar penuh',
    'settings.fullscreen_hint': 'Bilah peramban hilang saat bermain.',
    'settings.controls': 'KONTROL',
    'settings.language': 'Bahasa',
    'settings.language_hint': 'Berlaku untuk lobi dan arena.',
    'key.move': 'Bergerak',
    'key.aim': 'Bidik',
    'key.fire': 'Tembak',
    'key.swap': 'Ganti senjata',
    'key.emp': 'EMP',
    'key.defense': 'Pertahanan',
    'key.pause': 'Pause',
    'key.aim_value': 'Klik kanan',
    'key.fire_value': 'Klik kiri',

    'launch.eyebrow': 'DEPLOY · %s',
    'launch.title': 'MENYIAPKAN DUNIA',
    'launch.rail_label': 'Memuat aset dunia',
    'launch.status.loading': 'Memuat aset dunia',
    'launch.status.connecting': 'Menghubungkan paket dunia',
    'launch.status.assembling': 'Aset lengkap · menyusun dunia',
    'launch.status.ready': 'Dunia siap',
    'launch.status.stopped': 'Berhenti — coba lagi',
    'launch.retry': 'COBA LAGI',
    'launch.retry_meta': 'muat ulang',
    'launch.hint.preloaded': 'Paket dunia diunduh sekali saat opening. DEPLOY menyiapkan teater yang dipilih.',
    'launch.hint.enter': 'Masuk ke dunia…',
    'launch.hint.stay': 'Tetap di layar ini sampai dunia siap.',
    'launch.failed.payload': 'Payload tidak terbaca',
    'launch.failed.config': 'Konfigurasi ekspor tidak terbaca',
    'launch.failed.world': 'Dunia gagal dimuat',
    'launch.failed.secure_context': 'Koneksi aman diperlukan',
    'launch.failed.browser': 'Browser belum didukung',
  },
};

const STORAGE_KEY = 'aegis.locale';
let active = 'en';

/** `?lang=`, then the stored choice, then the browser's own preference. */
export function resolveLocale() {
  const fromUrl = new URLSearchParams(location.search).get('lang');
  if (fromUrl && STRINGS[fromUrl]) return fromUrl;
  try {
    const stored = localStorage.getItem(STORAGE_KEY);
    if (stored && STRINGS[stored]) return stored;
  } catch {
    /* private mode: fall through to the browser's preference */
  }
  const nav = (navigator.languages?.[0] || navigator.language || 'en').toLowerCase();
  return nav.startsWith('id') ? 'id' : 'en';
}

export function locale() {
  return active;
}

export function nativeName(code) {
  return NATIVE_NAMES[code] || code;
}

export function nextLocale() {
  return LOCALES[(LOCALES.indexOf(active) + 1) % LOCALES.length];
}

/** `t('launch.eyebrow', 'Neon Frontier')` -> "DEPLOY · Neon Frontier". */
export function t(key, ...args) {
  const table = STRINGS[active] || STRINGS.en;
  let value = table[key];
  if (value === undefined) value = STRINGS.en[key];
  if (value === undefined) {
    console.warn(`i18n: no string for "${key}"`);
    return key;
  }
  let index = 0;
  return value.replace(/%s/g, () => String(args[index++] ?? ''));
}

/**
 * Rewrites every marked node. Called on boot and on every switch; cheap because
 * the shell has a few hundred nodes and the walk is one querySelectorAll.
 */
export function apply(root = document) {
  for (const node of root.querySelectorAll('[data-i18n]')) {
    node.textContent = t(node.dataset.i18n);
  }
  for (const node of root.querySelectorAll('[data-i18n-aria]')) {
    node.setAttribute('aria-label', t(node.dataset.i18nAria));
  }
  for (const node of root.querySelectorAll('[data-i18n-title]')) {
    node.title = t(node.dataset.i18nTitle);
  }
  document.documentElement.lang = active;
}

/**
 * Switches language, remembers it, and hands it to the running game.
 *
 * `history.replaceState` is what keeps a reload honest: the URL now carries
 * `?lang=`, and the engine reads that on boot, so the canvas comes back in the
 * language the page was just showing.
 */
export function setLocale(code) {
  active = STRINGS[code] ? code : 'en';
  try {
    localStorage.setItem(STORAGE_KEY, active);
  } catch {
    /* private mode: the session still works, it just will not be remembered */
  }
  const url = new URL(location.href);
  url.searchParams.set('lang', active);
  history.replaceState(null, '', url);
  apply();
  document.dispatchEvent(new CustomEvent('aegis:locale', { detail: active }));
  // The engine, if it is already running, takes the switch live.
  if (typeof window.aegisSetLocale === 'function') {
    window.aegisSetLocale(active);
  }
  return active;
}

export function init() {
  active = resolveLocale();
  try {
    localStorage.setItem(STORAGE_KEY, active);
  } catch {
    /* private mode */
  }
  const url = new URL(location.href);
  url.searchParams.set('lang', active);
  history.replaceState(null, '', url);
  apply();
  return active;
}
