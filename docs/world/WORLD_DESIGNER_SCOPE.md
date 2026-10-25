# WORLD DESIGNER — Scope Isolation

> **Role**: World Designer · **Branch**: `arena/3a7253a1-cyber-strike` · **Tanggal**: 25 Oct 2026  
> **Prinsip**: *Ambil job cuma bagian World. Jangan clone semua, jangan sentuh scope lain.*

Dokumen ini adalah **kontrak scope** untuk sesi ini. Semua kerja di branch ini
HANYA menyentuh World — jika sebuah file bukan World, perubahan ditolak.

---

## 1. Apa itu "World" (dan apa yang BUKAN)

| IN SCOPE — World | OUT OF SCOPE — Dilarang sentuh |
|---|---|
| `game/scenes/worlds/` — mission_world.tscn, vanguard_station.tscn, components | `game/scripts/player/`, `game/scripts/enemies/`, `game/scripts/weapons/`, `game/scripts/combat/` |
| `game/scripts/worlds/` — mission_world.gd, world_mood.gd, neon_frontier_asset.gd | `game/scripts/ui/`, `game/scripts/audio/`, `game/scripts/systems/` |
| `tools/asset-forge/src/worlds/` — themes.js, roles.js, frostline/verdant/emberfall.js, terrainKit.js, compose.js, realModels.js, assemblyReal.js | `tools/asset-forge/src/runtime/` di luar world themes |
| `game/assets/world/` — real/, kenney_space_kit/, scifi_starter_kit/, forge/ | `game/assets/characters/`, `game/assets/weapons/`, `game/assets/enemies/` |
| `game/assets/forge/worlds/` — frostline/verdant/emberfall.glb + forge_manifest.json | `game/assets/audio/`, `game/assets/vfx/` |
| `docs/world/` — CONCEPT.md, README.md, PBR_AND_VERIFICATION.md, ASSET_LIST.md + dokumen World di `docs/` | `docs/ARCHITECTURE.md` (hanya baca), `AUDIO_SYSTEM.md`, `HERO_RIG_PIPELINE.md` |
| `tools/asset-forge/gate/world_shot.mjs`, `stage_worlds_into_game.mjs`, `real/` (fetch/slice) | `tools/qa_*`, `tools/web_qa.mjs` di luar world_shot |
| `tools/blender/` — hanya untuk world props & world kit (bukan hero/weapon) | `source-assets/characters/` (hero), `source-assets/weapons/` |
| `WORLD_BLOCKOUT.md`, `WORLD_KIT_BUILD.md` | `GAME_CONCEPT.md`, `IAP_CONCEPT.md`, `ANIMATION_*` |

**Rule of thumb**: Jika path tidak mengandung `world`, `asset-forge/src/worlds`, `forge/worlds`, atau `docs/world`, tanya dulu — kemungkinan besar OUT OF SCOPE.

---

## 2. Cara kerja "jangan clone semua, ambil bagian World"

Repo ini besar (≈ tezett). World Designer tidak perlu clone semua history/assets untuk kerja World. Tiga opsi:

### Opsi A — Sparse checkout (disarankan untuk World only)
```bash
# Clone hanya folder World + docs World + tooling World
git clone --filter=blob:none --sparse https://github.com/xam-eth/Cyber-Strike.git
cd Cyber-Strike
git sparse-checkout set game/scenes/worlds game/scripts/worlds \
  game/assets/world game/assets/forge docs/world \
  tools/asset-forge/src/worlds tools/asset-forge/gate \
  tools/asset-forge/real WORLD_BLOCKOUT.md WORLD_KIT_BUILD.md

# Hasil: working tree hanya berisi World, tapi branch tetap utuh di remote
git log --oneline -5
```

### Opsi B — Shallow + single branch
```bash
git clone --depth 1 --branch arena/3a7253a1-cyber-strike https://github.com/xam-eth/Cyber-Strike.git
# Hemat bandwidth, tetap dapat file World terbaru
```

### Opsi C — Di branch ini (yang dipakai sekarang)
Branch `arena/3a7253a1-cyber-strike` sudah ada. Semua commit World DIJAGA terisolasi:
```bash
git status --short
# Hanya file World yang boleh muncul di diff:
git diff --stat HEAD | grep -E "world|forge|asset-forge|docs/world|WORLD_"
# Jika muncul file di luar itu (mis: game/scripts/player/*), REVERT
```

**Yang dilakukan di sesi ini**: Opsi C — kerja langsung di `arena/3a7253a1-cyber-strike`, tapi `git diff` dijaga hanya menyentuh World paths (lihat commit log di bawah).

---

## 3. Skill yang ter-install — HANYA untuk World

Full-course World pipeline ter-install di branch ini di `.claude/skills/` (103 skills total, +25 baru). **Yang dipakai HANYA subset World**:

| Domain | Skill | Untuk file World apa |
|---|---|---|
| **Level Design** | `level-design` | `docs/world/CONCEPT.md`, `compose.js` districts, pacing beats, critical path |
| **Godot 3D** | `godot-3d-essentials` | `mission_world.gd`, `world_mood.gd`, lighting rig (Directional + WorldEnvironment) |
| **Godot Shaders** | `godot-shaders`, `shader-programming` | emissive crystal/pulse di `roles.js` (bukan gameplay VFX) |
| **Godot Physics** | `godot-physics` | StaticBody3D/CollisionShape3D floor & prop colliders di `mission_world.gd` |
| **Procedural** | `procedural-gen` | scatter, terrain dressing di `terrainKit.js` |
| **Performance** | `performance-optimization` | budget tris/draw calls (Frostline 113k tris, dll) |
| **Asset Forge** | `create-game-assets` | manifest, quality gate di `tools/asset-forge/` |
| **Three.js Forge** | `threejs-scene-setup`, `threejs-materials-lighting`, `threejs-gltf-loading` | build & export GLB di `tools/asset-forge/src/worlds/` |
| **Blender Full Course (22)** | `blender-core` → `blender-asset-qa` | `tools/blender/` untuk world props, UV, PBR, export glTF ke Godot |
| **Game Design** | `game-designer` (setcodes) | beats World di `docs/world/CONCEPT.md` |

Skill di luar World (`fps-shooter`, `godot-multiplayer`, `audio-design` untuk gameplay audio, `rpg`, `tower-defense` dll) **tetap ada di folder tapi TIDAK DIPAKAI** untuk mengubah code non-World. Lihat `docs/world/SKILLS_WORLD_FULLCOURSE.md` untuk daftar lengkap.

---

## 4. Checklist sebelum commit (World scope guard)

Jalankan ini sebelum `git push`:

```bash
# 1. Pastikan hanya file World yang berubah
git diff --name-only HEAD | grep -vE "(world|forge|asset-forge|docs/world|WORLD_|\.claude/skills)"
# Harus kosong — jika ada output, itu file non-World yang harus di-revert

# 2. Static check World (no engine needed)
./scripts/dev_check.sh
# Harus pass

# 3. World smoke di headless (jika Godot tersedia)
godot --headless --path game --script res://tests/mission_world_smoke.gd
godot --headless --path game --script res://tests/arena_blockout_smoke.gd

# 4. World forge gate (three.js)
node tools/asset-forge/gate/world_shot.mjs --help
node tools/asset-forge/real/fetch_real_assets.mjs --verify
```

Jika checklist 1 gagal → `git restore <file>` untuk file non-World.

---

## 5. Yang dikerjakan di branch ini (25 Oct 2026)

- [x] **Skill install**: update `awesome-gamedev-agent-skills` 7eb1b53 → 184b72b (latest 2026-10-24) + install `EL4CTEO/blender-skills` FULL COURSE 22 skills (Blender 5.2 LTS) + `setcodes` supplements → total 103 skills. Provenance: `.claude/skills/PROVENANCE.md`.
- [x] **Scope docs**: `docs/world/WORLD_DESIGNER_SCOPE.md` (file ini) + `docs/world/SKILLS_WORLD_FULLCOURSE.md` (full course manifest World-only).
- [ ] **World design iteration** (next): hanya jika diminta — terbatas ke `tools/asset-forge/src/worlds/` themes/roles/layout dan `game/scripts/worlds/` mood/lighting. Tidak menyentuh player/weapons/enemies/UI/audio.

---

## 6. Kontak scope

Jika task membutuhkan file di luar tabel IN SCOPE, **STOP** dan tanya:
> "Ini di luar World — mau saya lempar ke role Gameplay/Audio/UI, atau mau saya bantu definisikan interface World-nya saja (mis: socket `spawn_*`, collision bounds, theme token) tanpa mengubah code mereka?"

World Designer tidak pernah "pinjam" scope lain, bahkan untuk fix kecil.
