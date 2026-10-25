# Installed agent skills — provenance

These skills are **vendored copies**, not links. They are committed so that a
fresh clone has the same instructions the session that produced
`tools/asset-forge/` used. Nothing here is executed at game runtime.

> **WORLD DESIGNER SCOPE — 25 Oct 2026**
> Branch `arena/3a7253a1-cyber-strike` dikunci ke **World Design only**.
> Instalasi full-course di bawah ini HANYA untuk domain World (Godot 3D, Blender pipeline, Level Design, procedural, Three.js forge). Skill di luar World (gameplay, audio, networking dsb) tetap ter-install sebagai dependensi router tapi TIDAK DIKERJAKAN — lihat `docs/world/WORLD_DESIGNER_SCOPE.md`.

| Skill set | Upstream | Commit pinned (25 Oct 2026) | License | Files | Scope |
| --- | --- | --- | --- | --- | --- |
| `awesome-gamedev-agent-skills` (77 skills + `router`) | <https://github.com/gamedev-skills/awesome-gamedev-agent-skills> | `184b72be02884f782a0058f2eeae2ce4277453e4` (latest 2026-10-24) | Apache-2.0 (`LICENSE-awesome-gamedev-agent-skills.txt`) | `skills/<category>/<name>/SKILL.md` copied flat into `.claude/skills/<name>/` | **FULL — di-update dari 7eb1b53 → 184b72b**. World-relevant: `level-design`, `godot-3d-essentials`, `godot-shaders`, `godot-physics`, `procedural-gen`, `performance-optimization`, `create-game-assets`, `threejs-*`, `shader-programming`, `game-feel` |
| `blender-skills` FULL COURSE (22 skills) | <https://github.com/EL4CTEO/blender-skills> | `71d031dab8bc6729504d11a78cbe91945401045f` (2026-10-16) | MIT | `skills/blender-*/SKILL.md` → `.claude/skills/blender-*/` | **WORLD PIPELINE UTAMA — Blender 5.2 LTS full pipeline**: `blender-core`, `blender-scene-setup`, `blender-hardsurface-modeling`, `blender-sculpting`, `blender-retopology-uv`, `blender-pbr-materials`, `blender-texture-baking`, `blender-geometry-nodes`, `blender-character-rigging`, `blender-facial-shapekeys`, `blender-animation`, `blender-game-optimization`, `blender-export-pipelines`, `blender-rendering`, `blender-lighting-lookdev`, `blender-simulation`, `blender-time-of-day`, `blender-weather-fx`, `blender-addon-development`, `blender-pipeline-automation`, `blender-asset-qa`, `blender-workflow-recipes` |
| `game-designer` + `godot-gamedev` + `blender-game-assets` | <https://github.com/setcodes/gamedev-skills> | `096c224` (latest 2026-10) | MIT | `skills/<name>/SKILL.md` → `.claude/skills/<name>/` | **SUPLEMEN WORLD**: `game-designer` (GDD/mechanics/level), `godot-gamedev` (Godot implementation), `blender-game-assets` (concept→game-ready low-poly) |
| `img2threejs` | <https://github.com/img2threejs/img2threejs> | `954cd5845e90efd045694bab725d68a9863c20e0` | Apache-2.0 (`LICENSE-img2threejs.txt`) | full checkout, `forge/` + `grimoire/` included | shared pipeline shape (reference → spec → code build → gate) |

**Total ter-install di `.claude/skills/`: 103 SKILL.md (78 → 103, +25 World pipeline)**

## Install layout

The upstream installation rule for the skills collection is: *the directory that
directly contains `SKILL.md` is the skill, and its folder name equals the skill's
`name`.* Names are unique across the collection, so flattening into one directory
is the documented bulk install (`.claude/skills/` is the project-local directory
Claude Code reads). The `router` skill is installed too — the upstream docs are
explicit that the dispatcher must be present.

```bash
# === WORLD DESIGNER INSTALL — 25 Oct 2026 (hanya bagian World) ===
# awesome-gamedev-agent-skills — FULL UPDATE (77 + router)
for d in $(cd awesome-gamedev-agent-skills && find skills -name SKILL.md -exec dirname {} \;); do
  cp -R "awesome-gamedev-agent-skills/$d" .claude/skills/
done
cp -R awesome-gamedev-agent-skills/router .claude/skills/router

# blender-skills FULL COURSE — Blender 5.2 LTS pipeline lengkap (22 skills)
for d in blender-skills/skills/*; do cp -R "$d" .claude/skills/; done

# setcodes supplements — world design only
for s in game-designer godot-gamedev blender-game-assets; do
  cp -R "setcodes/skills/$s" .claude/skills/
done
cp -R img2threejs .claude/skills/img2threejs        # .git removed
```

Lihat `docs/world/SKILLS_WORLD_FULLCOURSE.md` untuk daftar lengkap 48 skill World + cara pakai per-task.

## Verification (re-run, do not trust this table)

```bash
# 1. upstream validator: parses every SKILL.md, checks names/wiring
python3 <upstream>/scripts/validate-skills.py     # "Validated 77 skill file(s) … All checks passed."

# 2. hitung install World di branch ini
ls .claude/skills/*/SKILL.md | wc -l                # 103
ls .claude/skills/blender-*/SKILL.md | wc -l        # 22 (EL4CTEO full course)
ls .claude/skills/godot-*/SKILL.md | wc -l          # 16 (Godot 4.7)

# 3. world-relevant check
for s in level-design godot-3d-essentials godot-shaders godot-physics procedural-gen \
         blender-core blender-scene-setup blender-pbr-materials blender-export-pipelines \
         game-designer; do test -f .claude/skills/$s/SKILL.md && echo "✓ $s"; done

# 4. the img2threejs state machine actually starts
cd .claude/skills/img2threejs && python3 forge/state.py init --help
```

Validator awesome `184b72b` tetap lulus. Blender skills diverifikasi via `blender-core/scripts/run_in_blender.py --help`.

## What was actually used (World scope only)

* `level-design` — **WORLD UTAMA**: blockout → test → iterate → dress, player metrics, pacing/tension curve, gating/critical path, encounter placement. Dipakai untuk `docs/world/CONCEPT.md` & `tools/asset-forge/src/worlds/compose.js` districts.
* `godot-3d-essentials` — Node3D/Camera3D/DirectionalLight3D/WorldEnvironment/GridMap, material & fog. Dipakai untuk `game/scripts/worlds/mission_world.gd` & `world_mood.gd`.
* `godot-shaders` / `shader-programming` — spatial shaders untuk emissive/crystal/pulse, bukan untuk gameplay VFX.
* `godot-physics` — StaticBody3D/CollisionShape3D untuk world collision (floor + prop colliders), bukan untuk karakter.
* `procedural-gen` — scatter & terrain dressing rules di `terrainKit.js` + `roles.js`.
* `performance-optimization` — draw call / mesh / texture budget untuk mobile (Frostline 113k tris etc), bukan untuk code profiling.
* `create-game-assets` — asset manifest, family generation, deterministic normalisation, "do not call an asset production-ready from a prompt result alone" gate. Ini kenapa `tools/asset-forge/` punya `catalog.json`, `references/` dan `quality-report.json`.
* `threejs-scene-setup`, `threejs-materials-lighting`, `threejs-gltf-loading` — gallery/render harness dan GLB export path untuk `tools/asset-forge/`.
* `blender-core` → `blender-asset-qa` (22 skills) — **FULL COURSE Blender 5.2 LTS**: scene setup → hardsurface → retopo/UV → PBR → baking → geometry nodes → optimization → export (Godot glTF) → QA. Dipakai untuk `tools/blender/author_hero.py` dan `source-assets/` pipeline.
* `game-designer` (setcodes) — GDD, vision, progression, level beats — hanya untuk World beats di `docs/world/CONCEPT.md`.
* `img2threejs` — shape pipeline: reference image → spec → pass-by-pass code build → deterministic gate + vision review. Rules diimplement sebagai `tools/asset-forge/gate/`.

> **Scope guard**: skill di luar World (mis: `fps-shooter`, `godot-multiplayer`, `audio-design` untuk gameplay audio, `rpg`, `tower-defense`) TIDAK dipakai untuk mengubah code di luar `game/scripts/worlds/`, `game/scenes/worlds/`, `tools/asset-forge/src/worlds/`, `game/assets/world/`, `docs/world/`. Jika butuh sentuh file lain, tolak — itu scope orang lain.

The `img2threejs` **scripts** were not used as the build driver for the whole
batch: `forge/state.py` models one reconstruction at a time and its profiles
(`generic` / `character`) do not know about a 36-asset, palette-locked game kit.
Its rules were implemented as `tools/asset-forge/gate/` (state file + evidence +
deterministic gate + visual review), which is the same contract in this repo's
own tooling. Per-asset reconstructions can still be driven through
`forge/state.py` one at a time; `tools/asset-forge/README.md` documents how.
