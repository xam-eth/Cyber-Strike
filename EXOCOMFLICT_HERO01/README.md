# EXOCONFLICT: STELLAR HORIZON — HERO_01 (independent contribution package)

Standalone Godot **4.7.2** validation project for the rigged HERO_01 hero character + `Weapon_Raise_To_Aim` animation. This project is intentionally independent of the main game repository: validate here, then import the GLBs/scenes you approve.

## Start here
1. `VALIDATION_REPORT.md` — what was tested and what passed, including the executed Godot 4.7.2 headless validation (clean import; in-engine grip/barrel CI) and the short desktop visual pass still recommended on the official editor.
2. `ART_ASSET_REPORT.md`, `RIG_SPECIFICATION.md`, `ANIMATION_SPECIFICATION.md` — asset audit, skeleton/weights/weapon-attachment contract, animation timing & grip metrics.
3. Open in Godot: Import → `project.godot` → run (F5) → `RigValidation` scene plays the clip and prints automated PASS/FAIL checks.

## Deliverables map
| Item | Path |
|---|---|
| Untouched source | `assets/source/HERO_01.glb` |
| Rigged character (skin + clip) | `assets/characters/HERO_01_RIGGED.glb` |
| Separate weapon | `assets/weapons/HERO_01_WEAPON.glb` (+ `scenes/weapons/HERO_01_WEAPON.tscn`) |
| Animation (skeleton+clip) | `animations/HERO_01_ANIMATIONS.glb` (clip also inside RIGGED) |
| Blender working file | `blender/HERO_01_working.blend` (Blender 4.5 LTS) |
| Character scene | `scenes/characters/HERO_01.tscn` (auto-attaches weapon to `Weapon_R`) |
| Validation scene | `scenes/main/RigValidation.tscn` |
| Screenshots | `screenshots/01_neutral_pose.png`, `02_weapon_raised.png`, `03_final_aim_front.png`, `03b_final_aim_3q.png`, `04_final_aim_sideR.png` (+ process evidence in subfolders) |
| Repro pipeline | `tools/blender/scripts/01…20` via `tools/blender/run_bpy.sh`, `tools/validate_exports.py` |

## Key facts
- 24-bone humanoid (`Root…Toe_L` + `Weapon_R`), identical names in Blender/GLB/Godot; no geometry, UV, material or polycount changes from source (262,714 verts conserved exactly).
- Weapon attaches via `BoneAttachment3D` on `Weapon_R`; offset auto-solved at startup and manually overridable (`scripts/characters/hero_01.gd`) without touching hero geometry.
- Character authored at normalized height 1.0; `HERO_01.tscn` scales ×1.8 (assumption — adjust `ScaleRoot`).
- GDScript only, GLB/glTF 2.0, no addons or external dependencies.
- Runtime-validated on Godot 4.7.2 (headless editor compiled from official source in the authoring sandbox): re-run the CI anytime with `godot --headless --path . res://tools/godot/CICheck.tscn` after a one-time `--import`.
- Non-runtime folders (`blender/`, `screenshots/`, `assets/source/`, `tools/blender/`, `tools/out/`) contain `.gdignore` files so Godot never tries to import the authoring .blend / preserved source / screenshots. (A .blend inside a Godot project without a configured Blender path silently aborts *all* headless imports - this bit us once, see VALIDATION_REPORT 5.2; keep the .gdignore files.)
