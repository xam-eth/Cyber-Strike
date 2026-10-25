# NEON FRONTIER — Cinematic Sci-Fi: Hidup & Dramatis

> **World Designer**: `arena/3a7253a1-cyber-strike` · **Tanggal**: 26 Oct 2026  
> **Prinsip**: Semua komponen adalah **asset 3D asli (real GLB)** — tidak ada procedural geometric. Setiap mesh punya `userData.realSource`. Dunia harus **hidup** (bergerak, bernafas) dan **dramatis cinematic** seperti film.

---

## 1. Reference — genre yang sama, se keren mungkin

### Blade Runner (1982, 2049) — Syd Mead: "Reality Ahead of Schedule"
- **Kunci visual**: Nocturnal, rain-slick streets yang refleksi neon, *volumetric haze* dengan shaft of light (backlit rain), dense vertical sprawl, *greeble* di setiap permukaan, megastructure siluet (Tyrell Pyramid). Warna: **teal/cyan + amber/orange** dengan *chiaroscuro* (high contrast, deep shadows).
- **Yang kita curi**: Monorail transit spine yang membelah horizon (seperti Syd Mead's transit), rocket gantry sebagai landmark vertikal, *practical lights* (emissive strips di setiap corridor) yang memotivasi *dramatic lights*, wet floor illusion via emissive lift pada scanned plate.

### Destiny (Bungie) — "10% Bright, 10% Dark"
- **Kunci visual**: *Terraformed* landscape dengan *greebled* architecture, *overgrown* nature reclaiming tech (Old Russia, EDZ), *Vex* cubes, *Dreaming City* yang pristine tapi cursed. Interconnected destinations, *lived-in* clutter, *scale storytelling* (player kecil vs megastructure).
- **Yang kita curi**: Verdant Bloom sebagai *overgrown research station* (Annihilation + Destiny EDZ): modular corridors yang collapsed dan ditumbuhi moss, bio-dome yang cracked, giant flora sebagai canopy character. Emberfall sebagai *Nessus* terraformed foundry dengan slag pools seperti radiolaria.

### Syd Mead's Megastructures — "Supersonic Baroque on Slick Geometry"
- **Kunci visual**: Slick geometric shapes dengan *swirly baroque embroidery*, industrial megastructure dengan plumbing yang terlihat (pipes, supports, cables), *atmospheric perspective* planetary scale.
- **Yang kita curi**: Pipe racks, rail lines, crane gantries, tank farms sebagai *visual plumbing* yang membuat dunia terasa *engineered*, bukan di-tempel.

### No Film School — Generic Sci-Fi Cinematic Rules
- **Anamorphic lens**: flare, shallow depth — kita simulasikan dengan **fog density + bloom (emissive)**.
- **Volumetric fog**: shafts of light melalui haze — kita pakai **Fog density tuned per world** + **sky glow band** di `themeSky`.
- **Backlight + rim**: silhouettes against sci-fi sky — kita pakai **AuroraRim / AshRim dari utara** yang mengarah ke landmark.

---

## 2. Design Language: 9 Token Palette → Cinematic Grade

Palette asli (CONCEPT.md) tetap: near-black void, graphite, amber (heat), cyan (info), violet (alien). Tapi untuk **cinematic drama**, kita *push* contrast dan saturasi:

| Token | Cinematic Treatment |
|---|---|
| **Void** `#040d18` / `#070302` | Lebih hitam (exposure 1.0 → 1.3 untuk Emberfall) supaya shadow jatuh dalam, hanya rim yang selamat |
| **Steel** | Grade lebih gelap (targetLight 0.11-0.13) supaya silhouette tajam |
| **Cyan** `#59e6ff` | **Practical light** — emissive intensity 0.6-0.8 di setiap dish/ring, jadi sumber cahaya diegetic |
| **Amber** `#ff7a1e` / `#ffd166` | **Heat** — emissive di barrel/collar, tapi juga **fog color** untuk Emberfall (ash haze) |
| **Violet** `0x7b4bff` | **Alien** — crystal pulse, spore vents, jadi accent yang *pop* di atas desaturasi steel |

**Lighting 4-point cinematic (per world di `themes.js`)**:
1. **Key** (SW, low, hard, shadow caster) — warna signature world, intensity 2.5-4.0
2. **Fill** (East, soft, 1/3 intensity) — isi shadow yang menghadap away dari key
3. **Rim** (North, accent color) — dari arah landmark mission, jadi light bercerita *dimana objective*
4. **Bounce** (down, warm) — dari floor, menghindari pure black di bawah

Ditambah **Hemisphere (SkyBounce)** — ambient yang tinted per world.

**Atmosphere**: Sky dome adalah gradient dengan **haze band** di horizon (0.03 height) — `glow * 0.07`. Fog adalah exponential, density tuned: Frostline 0.0028→0.0032 (visible air), Verdant 0.0038 (spore haze), Emberfall 0.0016 (ash, agar yard tidak jadi void).

---

## 3. Apa artinya "Hidup" — semua yang bergerak

Dunia statis = diorama. Dunia hidup = *every district breathes*.

| World | District yang bergerak (clips) | Cara |
|---|---|---|
| **Frostline** | dishes spin/sweep, relay mast whip spin + band bob, cryo collar spin + vent bob, turret sweep, sensor spin, breach gate pulse/beacon spin, ice crystals pulse (offset phase), monorail train subtly bobbing, rover idle sweep | 61→~75 clips. Monorail train `sweep` Y 0.2, rover `sweep` Z 0.01 — cukup untuk *alive* tanpa mengganggu gameplay |
| **Verdant** | bio dome crown spin, overgrowth sway, spore vent pulse, canopy sway (Z 0.012), mushroom ring breathe, moss drape swing, fallen log not moving (grounded), modular corridor gate lasers pulse | 156 clips — canopy sway adalah *karakter* utama, modular gate `pulse` 0.015 untuk *diegetic light* |
| **Emberfall** | smelter glow band spin, flues vent bob, silo drum spin, drill crown spin + arm sweep, slag pool pulse, crane beam bob, rail line tidak bergerak (grounded), monorail ore train sweep, rocket tidak bergerak (monument) | 42→~58 clips. Rocket adalah **monument** — tidak perlu bergerak, tapi *light* di sekitarnya yang bergerak (drill, crane) membuatnya hidup via reflection |

Semua anim adalah **GLTF clips di dalam staged GLB**, satu `AnimationMixer` per world. Track naming `<Instance>__<Part>` jadi 5 sensor towers animate independent. `realModels.js` tidak generate geometry — hanya load GLB dan tag `realSource`.

---

## 4. Asset Cinematic Baru — semua real GLB, bukan procedural

**Download 26 Oct 2026 via GitHub API (allowed) — total 254 files, 61.4 MB:**

| Kit | Jumlah | File cinematic kunci yang dipakai |
|---|---|---|
| **Kenney Space Kit** (Hidencod/tge-assets 2c8950b) | 153 (87→153, +66) | `monorail-*` (track + train), `rocket-*` (base/sides/fuel/fins/top), `rover`, `rail-*`, `platform-*` variants, `pipe-*` variants, `terrain-*` variants — semua untuk *transit spine* dan *rocket landmark* |
| **Kenney Modular Space Kit** (shorepine/kenney 3d/modular-space) | 40 | `corridor*`, `room-*`, `gate-lasers`, `cables`, `template-*` — untuk *corridor run* dramatic dan *laser gate* |
| **Kenney Space Station Kit** (shorepine/kenney 3d/space-station) | 18 curated | `container*`, `computer*`, `display-wall`, `door-double`, `balcony-floor` — untuk *lived-in dressing* |
| **Kenney Nature Kit** | 33 | tetap — untuk Verdant canopy |
| **Cinder Yard Power Plant** | 1 + 8 setpieces | tetap — hero for Emberfall |

**Provenance**: `tools/asset-forge/real/real-manifest.json` (254 entries, SHA256 per file) + `realModels.js` `userData.realSource` tagging + capture gate (`gate/real_asset_checks.mjs`) yang fail jika ada mesh tanpa tag.

**Roles baru (di `roles.js`) — semua pakai `model: '<id>'` yang resolve ke `game/assets/world/real/kenney/<id>.glb`:**
- `monorail_spine` — `monorail-trackstraight` + `monorail-tracksupport` + `monorail-trackslope` (elevated transit, Syd Mead spine)
- `monorail_train` — `monorail-trainfront` + `monorail-trainbox` + `monorail-trainend` (alive, sweep)
- `rocket_stack` — `rocket-basea/b` + `rocket-sidesa/b` + `rocket-fuela/b` + `rocket-finsa/b` + `rocket-topa/b` (vertical megastructure, 18-22m)
- `rover_outrider` — `rover` (lived-in vehicle)
- `rail_line` — `rail-middle` + `rail-corner/end` (ore line)
- `modular_corridor` — `modular-corridor` + `modular-corridor-corner` + `modular-gate-lasers` (dramatic corridor dengan emissive lasers)
- `station_dressing` — `station-container` + `station-computer` (yard clutter)
- `cable_greeble` — `modular-cables` (surface detail)

---

## 5. World Beats — cinematic per mission

### Frostline Relay — "Blade Runner di Kutub"
*Tagline cinematic*: **Hold the uplink while the aurora cuts the ice like a searchlight.**

- **Core**: Comms array dengan relay masts (seperti Tyrell comms), tapi sekarang **monorail spine** memotong icefield dari station ke breach east — garis horizontal yang memecah vertikal masts, creating *leading line* ke horizon.
- **Station**: Cryo condensers + station dish + **rocket_stack** di belakang station (siluet 22m melawan aurora) — bukan sekadar dish, tapi *launch pad yang beku*.
- **Defence**: Turret line tetap, tapi gate diberi **rail_line** pendek di depannya (seperti supply rail yang beku).
- **Icefield**: Frozen haulers + ice spires + **rover_outrider** di samping hauler (story: tim keluar, rover ditinggal). Monorail train subtle di atas spine — alive.
- **Landmark**: `tall_arch` polar gate tetap, tapi diberi **cable_greeble** di base untuk scale detail.
- **Fog**: Dinaikkan 0.0028→0.0034, `ground lift` 1.35→1.45 supaya ice lebih *glow* di bawah cyan rim.

### Verdant Bloom — "Destiny EDZ + Annihilation"
*Tagline cinematic*: **Recover the seed vault before the bloom sings over it.**

- **Shrine**: Seed vault arch tetap, tapi **modular_corridor** collapsed di sampingnya (seperti lab corridor yang ditelan moss) — *storytelling via architecture*.
- **Station**: 3 bio domes + **modular_room-large** sebagai *collapsed lab* di west (cracked, dengan `station_dressing` containers di dalamnya) — lived-in, bukan clean.
- **Grove**: 40+ trees tetap, tapi **hanging-moss** ditambah density, dan **station_computer** half-buried sebagai *lost tech*.
- **Nursery**: Spore vents + giant flora + **gate_lasers** sebagai *quarantine gate* yang masih pulsing violet.
- **Wreck**: Crashed lab + drone di crater, dengan **rover_outrider** di rim — tim sebelumnya.

### Emberfall Foundry — "Syd Mead Megastructure"
*Tagline cinematic*: **Tap the seam, load the ore, get out before the floor opens — megastructure is breathing.**

- **Smelter line**: 3 smelters + 3 ore silos tetap, tapi **rail_line** menghubungkan silos seperti *plumbing*.
- **Yard**: Gantry cranes + drill rig + slag pools + **monorail_spine** di atas yard (ore monorail) + **monorail_train** di atasnya (alive) — *horizontal drama*.
- **Guard**: Turrets + gates + **rocket_stack** di approach timur (foundry's rocket for orbital lift, 18m) — *vertical megastructure* yang tell story: ini bukan sekadar foundry, ini *launch foundry*.
- **Approach**: Silo rail + **modular_corridor** sebagai *loading corridor* ke plant + **station_dressing** containers (lived-in yard, bukan empty).
- **Slagfield**: Ash statues + slag pools + **cable_greeble** di sekitar crater — *greeble* seperti Vitaly Bulgarov megastructure kitbash.

---

## 6. Verifikasi — tetap 100% real asset

- `node tools/asset-forge/real/fetch_real_assets.mjs --verify` — 254 files hash-checked
- `node tools/asset-forge/gate/world_shot.mjs` — asset-policy gate (fail jika ada mesh tanpa `realSource`) + 15 shots + 3 GLBs
- `node tools/asset-forge/gate/stage_worlds_into_game.mjs` — stage ke `game/assets/forge/worlds/` + manifest
- `godot --headless --path game --script res://tests/mission_world_smoke.gd` — engine test (meshes, clips, mood, field)

Tidak ada procedural: `realModels.js` adalah SATU-SATUNYA yang construct `GLTFLoader`. `roles.js` hanya list `model: '<id>'`, `compose.js` hanya `await makePart()` + clone.

---

## 7. Next — cara liat cinematic

```bash
python3 -m http.server 8080
# /tools/asset-forge/world.html?world=frostline  — lihat monorail spine + rocket siluet vs aurora
# /tools/asset-forge/world.html?world=verdant   — lihat modular corridor collapsed + spore haze
# /tools/asset-forge/world.html?world=emberfall — lihat ore monorail + rocket gantry + slag glow

node tools/asset-forge/gate/world_shot.mjs --world emberfall --shot overview
node tools/asset-forge/gate/stage_worlds_into_game.mjs
# lalu buka game/project.godot di Godot 4.7.2
```

*Bayangkan*: Frostline di kutub, aurora cyan memotong kabut, monorail train melintas pelan di atas icefield sementara rocket beku di belakang station berkilau — itu Blade Runner di es. Verdant di bawah canopy, green sun menembus dedaunan, spore vents pulsing violet, modular corridor yang collapsed setengah terkubur lumut — itu Destiny's EDZ yang sudah menang. Emberfall di volcanic plain, furnace orange dari bawah, monorail ore meluncur di atas yard, rocket 18m berdiri di timur seperti Syd Mead's launch gantry — itu megastructure yang bernafas.

Semua dari file GLB yang sama yang Kenney dan Kammertonus buat — kita hanya menyusunnya seperti Syd Mead menyusun *reality ahead of schedule*.
