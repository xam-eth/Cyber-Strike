# World Designer — Full Course Skill Install

> **Branch**: `arena/3a7253a1-cyber-strike` · **Tanggal**: 25 Oct 2026 · **Scope**: World only  
> **Tujuan**: Install skill **Godot + Blender + Level Design full course** dari GitHub di branch ini, tapi pakai HANYA untuk World.

---

## Ringkas

| | Jumlah | Upstream | Commit | Status di branch |
|---|---|---|---|---|
| **awesome-gamedev-agent-skills** | 77 + router | `gamedev-skills/awesome-gamedev-agent-skills` | `184b72b` (2026-10-24 latest) | ✅ Updated dari 7eb1b53 → 184b72b |
| **blender-skills FULL COURSE** | 22 | `EL4CTEO/blender-skills` | `71d031d` (2026-10-16, Blender 5.2 LTS) | ✅ Baru install full 22 |
| **setcodes supplements** | 3 | `setcodes/gamedev-skills` | `096c224` | ✅ Baru install |
| **img2threejs** | 1 set | `img2threejs/img2threejs` | `954cd58` | ✅ Tetap |
| **TOTAL di `.claude/skills/`** | **103 SKILL.md** | — | — | 78 → 103 (+25 World pipeline) |

Semua skill adalah **vendored copy** (bukan link), di-commit supaya fresh clone punya instruksi sama. Tidak ada yang dieksekusi saat game runtime. Provenance lengkap: `.claude/skills/PROVENANCE.md`.

---

## 1. Cara install (yang sudah dijalankan di branch ini)

```bash
# Clone full-course sources (allowed hosts: github.com, api.github.com)
mkdir -p /tmp/skill-fetch && cd /tmp/skill-fetch
git clone --depth 1 https://github.com/gamedev-skills/awesome-gamedev-agent-skills.git awesome
git clone --depth 1 https://github.com/EL4CTEO/blender-skills.git blender-skills
git clone --depth 1 https://github.com/setcodes/gamedev-skills.git setcodes

# Install ke branch — HANYA WORLD PATHS
DEST="/home/user/Cyber-Strike/.claude/skills"

# 1) awesome full refresh (77 + router) — update semua, World subset dipakai
for d in $(find awesome/skills -name SKILL.md -exec dirname {} \;); do
  cp -R "$d" "$DEST/"
done
cp -R awesome/router "$DEST/router"

# 2) blender FULL COURSE (22 skills) — pipeline Blender 5.2 LTS lengkap
for d in blender-skills/skills/*; do cp -R "$d" "$DEST/"; done

# 3) setcodes supplements (game-designer etc)
for s in game-designer godot-gamedev blender-game-assets; do
  cp -R "setcodes/skills/$s" "$DEST/"
done
```

Verifikasi:
```bash
ls .claude/skills/*/SKILL.md | wc -l          # 103
ls .claude/skills/blender-*/SKILL.md | wc -l  # 22
ls .claude/skills/godot-*/SKILL.md | wc -l    # 16
cat .claude/skills/PROVENANCE.md | grep "Commit pinned"
```

---

## 2. World Full Course — 48 skill yang RELEVAN untuk World

Dari 103 total, **48 skill ini yang dipakai untuk World**. Sisanya ada tapi DIABAikan (scope guard).

### A. Level Design & World Building (inti World Designer)
| Skill | Upstream | Untuk apa di World |
|---|---|---|
| `level-design` | awesome/disciplines | **INTI**: blockout → test → iterate → dress, player metrics, pacing/beats, gating, critical path. Dipakai untuk district layout di `compose.js` & beats di `CONCEPT.md` |
| `procedural-gen` | awesome/disciplines | scatter, terrain dressing, placement rules di `terrainKit.js` + `roles.js` |
| `game-designer` | setcodes | GDD, vision, beats per world (Frostline defense, Verdant recovery, Emberfall extraction) — HANYA bagian World di `docs/world/CONCEPT.md` |
| `create-game-assets` | awesome/disciplines | asset manifest, family generation, deterministic normalisation, quality gate — kenapa `tools/asset-forge/` punya `catalog.json` + `quality-report.json` |
| `performance-optimization` | awesome/disciplines | budget tris/draw calls/mobile — Frostline 113k, Verdant 128k, Emberfall 247k tris |
| `shader-programming` | awesome/disciplines | spatial shader untuk emissive/crystal/pulse (bukan gameplay VFX) |
| `game-feel` | awesome/disciplines | readability World (silhouette, palette amber/cyan/violet) |
| `camera-systems` | awesome/disciplines | framing World untuk capture `world_shot.mjs` |

### B. Godot 4.7 — World di Engine
| Skill | Upstream | Untuk apa di World |
|---|---|---|
| `godot-3d-essentials` | awesome/godot | **INTI**: Node3D, Camera3D, DirectionalLight3D, WorldEnvironment, GridMap, StandardMaterial3D. Dipakai di `mission_world.gd` & `world_mood.gd` |
| `godot-shaders` | awesome/godot | ShaderMaterial untuk emissive/energy di World |
| `godot-physics` | awesome/godot | StaticBody3D/CollisionShape3D untuk floor & prop colliders (bukan character controller) |
| `godot-resources` | awesome/godot | .tres/.res untuk Environment, Material World |
| `godot-gdscript` | awesome/godot | GDScript untuk `mission_world.gd` (World placement only, no gameplay logic) |
| `godot-nodes-scenes` | awesome/godot | scene composition World (RealFrontierWorld) |
| `godot-gdscript-headless-testing` | awesome/godot | smoke test World headless |
| `godot-gdscript` + `godot-export` | awesome/godot | export World GLB pipeline |
| `godot-gamedev` | setcodes | Godot implementation review (hanya World) |

### C. Blender 5.2 LTS — Full Course 22 skills (World Pipeline)
| Skill | Apa yang dilakukan | Untuk World apa |
|---|---|---|
| `blender-core` | Foundation — bpy MCP/headless, 5.x API, routing | entry point semua Blender World task |
| `blender-scene-setup` | Units (meter), naming, collections, asset libraries | setup `.blend` World kit |
| `blender-hardsurface-modeling` | Bevels, booleans, weighted normals | modular World pieces (platform, corridor, hangar) |
| `blender-sculpting` | Organic sculpting, multires | rock, terrain, organic World props |
| `blender-retopology-uv` | Retopo, UV unwrap, texel density | UV untuk World kit |
| `blender-pbr-materials` | PBR, color spaces, texture sets | material World (metal/rock/crystal) |
| `blender-texture-baking` | Normal/AO/curvature/ORM bake | bake World kit |
| `blender-geometry-nodes` | Procedural modeling dari JSON | procedural World dressing |
| `blender-character-rigging` | Rigify, skinning | **SKIP untuk World** (untuk karakter, bukan World) |
| `blender-facial-shapekeys` | ARKit blendshapes | **SKIP untuk World** |
| `blender-animation` | Actions, NLA, root motion | anim clip World (dish spin, turret sweep, crystal pulse) |
| `blender-game-optimization` | Budget, LODs, draw calls | optimize World GLB untuk mobile |
| `blender-export-pipelines` | glTF/FBX/USD → Godot | **INTI**: export World GLB ke `game/assets/forge/worlds/` |
| `blender-rendering` | Cycles/EEVEE, batch | render World preview |
| `blender-lighting-lookdev` | HDRI, studio lighting | lookdev World palette |
| `blender-time-of-day` | Golden hour, night, fog | mood per World (Frostline polar dusk, Emberfall furnace) |
| `blender-weather-fx` | Rain, snow, wet, lightning | weather World (opsional) |
| `blender-simulation` | Rigid/cloth/fluid | sim World (crater, debris) |
| `blender-addon-development` | Extensions | pipeline tooling |
| `blender-pipeline-automation` | Batch/headless conversion | `tools/blender/author_hero.py` pattern untuk World kit |
| `blender-asset-qa` | Z-fighting, floating, normals, weights | **WAJIB** sebelum commit World GLB |
| `blender-workflow-recipes` | Playbooks prop→character→product | end-to-end World prop workflow |
| `blender-game-assets` | Concept→game-ready low-poly | suplemen (setcodes) untuk World props |

### D. Three.js Forge — Build World GLB (code-only, real assets)
| Skill | Upstream | Untuk apa |
|---|---|---|
| `threejs-scene-setup` | awesome/web-engines | scene, camera, lights untuk `tools/asset-forge/` |
| `threejs-materials-lighting` | awesome/web-engines | PBR grading per library (hardware/organics/floor) |
| `threejs-gltf-loading` | awesome/web-engines | GLTFLoader + `userData.realSource` tagging + export |
| `create-game-assets` (three-d-pipeline) | awesome/disciplines | `realModels.js` → `roles.js` → `compose.js` → GLB |

---

## 3. Cara pakai per task World (router)

Jangan baca semua 103 sekaligus — pakai router:

| Task World | Skill yang dibaca | File yang disentuh |
|---|---|---|
| Design district baru / pacing | `level-design` + `game-designer` | `docs/world/CONCEPT.md`, `tools/asset-forge/src/worlds/<world>.js` |
| Atur lighting/mood/fog per world | `godot-3d-essentials` + `blender-lighting-lookdev` + `blender-time-of-day` | `tools/asset-forge/src/worlds/themes.js`, `game/scripts/worlds/world_mood.gd` |
| Tambah prop/role baru | `create-game-assets` + `blender-hardsurface-modeling` + `blender-asset-qa` | `tools/asset-forge/src/worlds/roles.js`, `game/assets/world/real/` |
| Dress terrain / scatter | `procedural-gen` + `blender-geometry-nodes` | `tools/asset-forge/src/worlds/terrainKit.js` |
| Optimize untuk Android low-end | `performance-optimization` + `blender-game-optimization` | `forge_manifest.json` tris/draw, `blender-asset-qa` |
| Export World GLB ke Godot | `blender-export-pipelines` + `threejs-gltf-loading` | `tools/asset-forge/gate/stage_worlds_into_game.mjs` → `game/assets/forge/worlds/*.glb` |
| Verifikasi World (gate) | `blender-asset-qa` + `godot-gdscript-headless-testing` | `real/fetch_real_assets.mjs --verify`, `world_shot.mjs` asset-policy gate |

Contoh prompt ke agent (di repo ini):
```
Pakai skill level-design untuk review pacing Frostline Relay di docs/world/CONCEPT.md
Pakai blender-asset-qa untuk cek world GLB sebelum commit
Pakai godot-3d-essentials untuk tuning WorldEnvironment di world_mood.gd (World only)
```

---

## 4. Yang TIDAK dipakai (di luar World scope)

Skill ini tetap ada di `.claude/skills/` karena bagian dari full install, tapi **DILARANG dipakai untuk ubah code non-World** (scope guard di `WORLD_DESIGNER_SCOPE.md`):

`fps-shooter`, `godot-2d-movement`, `godot-multiplayer`, `audio-design` (gameplay audio), `rpg`, `roguelike`, `tower-defense`, `platformer`, `puzzle`, `bevy-ecs`, `unity-*`, `unreal-*`, `roblox-*`, `phaser-*` dll. Jika task butuh mereka → lempar ke role lain.

---

## 5. Verifikasi install

```bash
# Total
ls .claude/skills/*/SKILL.md | wc -l
# 103

# World subset harus ada
for s in level-design godot-3d-essentials godot-shaders godot-physics procedural-gen \
         blender-core blender-scene-setup blender-pbr-materials blender-export-pipelines \
         blender-asset-qa blender-game-optimization threejs-scene-setup create-game-assets \
         game-designer; do
  test -f .claude/skills/$s/SKILL.md && echo "✓ $s" || echo "✗ $s MISSING"
done

# Versi
grep "Commit pinned" .claude/skills/PROVENANCE.md
# awesome: 184b72b (2026-10-24)
# blender-skills: 71d031d (2026-10-16)
# setcodes: 096c224

# World docs
ls docs/world/WORLD_DESIGNER_SCOPE.md docs/world/SKILLS_WORLD_FULLCOURSE.md

# Smoke World (jika Godot ada)
godot --headless --path game --script res://tests/mission_world_smoke.gd
node tools/asset-forge/real/fetch_real_assets.mjs --verify # 130 files hash-checked
```

---

## 6. Update ke depan

Jika ada full-course baru (mis: Godot 4.8, Blender 5.3 LTS):

```bash
cd /tmp/skill-fetch/awesome && git pull --ff-only
cd /tmp/skill-fetch/blender-skills && git pull --ff-only
# re-run install block di section 1, lalu update PROVENANCE.md commit hash
```

Jangan `git pull` di `.claude/skills/` langsung — itu vendored copy, bukan git repo. Selalu pull di `/tmp/skill-fetch/*` lalu `cp -R`.
