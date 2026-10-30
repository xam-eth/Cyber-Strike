# EXOCONFLICT: STELLAR HORIZON — HERO_01 (independent contribution package)

Standalone Godot **4.7.2** validation project for the rigged HERO_01 hero character, the original `Weapon_Raise_To_Aim` clip, and the Phase-1 production weapon chain (`Idle → Weapon_Raise → Aim_Idle → Fire → Weapon_Lower`; see `ANIMATION_SPECIFICATION.md` sections 6–10 for the approved 20-clip plan). This project is intentionally independent of the main game repository: validate here, then import the GLBs/scenes you approve.

## Start here
1. `VALIDATION_REPORT.md` (versi Bahasa Indonesia: `VALIDATION_REPORT-ID.md`) — what was tested and what passed, including the executed Godot 4.7.2 headless validation (clean import; in-engine grip/barrel CI) and the short desktop visual pass still recommended on the official editor.
2. `ART_ASSET_REPORT.md`, `RIG_SPECIFICATION.md`, `ANIMATION_SPECIFICATION.md` — asset audit, skeleton/weights/weapon-attachment contract, animation timing & grip metrics.
3. Open in Godot: Import → `project.godot` → run (F5) → `RigValidation` starts the Phase-1 AnimationTree at `Idle`; use the chain buttons (Idle / Weapon_Raise / Aim_Idle / Fire / Weapon_Lower) and read the automated PASS/FAIL checks. The legacy clip remains available via “Play legacy aim”.

## Deliverables map
| Item | Path |
|---|---|
| Untouched source | `assets/source/HERO_01.glb` |
| Rigged character (skin + 6 clips) | `assets/characters/HERO_01_RIGGED.glb` |
| Separate weapon | `assets/weapons/HERO_01_WEAPON.glb` (+ `scenes/weapons/HERO_01_WEAPON.tscn`) |
| Animations (skeleton + same 6 clips) | `animations/HERO_01_ANIMATIONS.glb` (clips also inside RIGGED) |
| Blender working file | `blender/HERO_01_working.blend` (Blender 4.5 LTS) |
| Character scene | `scenes/characters/HERO_01.tscn` (auto-attaches weapon to `Weapon_R`) |
| Validation scene | `scenes/main/RigValidation.tscn` |
| Screenshots | `screenshots/01_neutral_pose.png`, `02_weapon_raised.png`, `03_final_aim_front.png`, `03b_final_aim_3q.png`, `04_final_aim_sideR.png`, Phase-1 evidence in `screenshots/animation/phase1/` (+ process evidence in subfolders) |
| Repro pipeline | `tools/blender/scripts/01…49` via `tools/blender/run_bpy.sh` (read each script header — some are gated/SUPERSEDED records), `tools/validate_exports.py`, `tools/diff_rigged_glb.py` |

## Key facts
- 24-bone humanoid (`Root…Toe_L` + `Weapon_R`), identical names in Blender/GLB/Godot; no geometry, UV, material or polycount changes from source (262,714 verts conserved exactly).
- Weapon attaches via `BoneAttachment3D` on `Weapon_R`; offset auto-solved at startup and manually overridable (`scripts/characters/hero_01.gd`) without touching hero geometry.
- Character authored at normalized height 1.0; `HERO_01.tscn` scales ×1.8 (assumption — adjust `ScaleRoot`).
- GDScript only, GLB/glTF 2.0, no addons or external dependencies.
- `HERO_01.tscn` builds and starts a Phase-1 `AnimationTree` state machine in code by default (`scripts/characters/hero_01.gd`; disable `use_animation_tree` if a host game supplies its own graph). Locomotion blending is Phase 2 — not shipped yet.
- The original package was runtime-validated on Godot 4.7.2 (headless editor compiled from official source in the authoring sandbox); the Phase-1 GLBs/GDScript still need an owner desktop re-import pass (VALIDATION_REPORT 5.10). Re-run the CI anytime with `godot --headless --path . res://tools/godot/CICheck.tscn` after a one-time `--import`.
- Non-runtime folders (`blender/`, `screenshots/`, `assets/source/`, `tools/blender/`, `tools/out/`) contain `.gdignore` files so Godot never tries to import the authoring .blend / preserved source / screenshots. (A .blend inside a Godot project without a configured Blender path silently aborts *all* headless imports - this bit us once, see VALIDATION_REPORT 5.2; keep the .gdignore files.)
