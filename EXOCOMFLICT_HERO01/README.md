# EXOCONFLICT: STELLAR HORIZON — HERO_01 (independent contribution package)

Standalone Godot **4.7.2** validation project for the rigged HERO_01 hero character. **Current character: NEW_HERO_01** (owner-directed replacement, 2026-10-31 — the previous character's hands rested against the torso, which made clean skinning unreliable; see `VALIDATION_REPORT.md` §5.15). The new rig + skinning are fully validated (Blender deformation battery, GLB roundtrip, Godot headless CI — all PASS); animation clips for the new skeleton are **not authored yet** (the ~20-clip plan in `ANIMATION_SPECIFICATION.md` starts after owner rig acceptance). This project is intentionally independent of the main game repository: validate here, then import the GLBs/scenes you approve.

## Start here
1. `VALIDATION_REPORT.md` §5.15 (versi Bahasa Indonesia: `VALIDATION_REPORT-ID.md`) — the NEW_HERO_01 replacement record: source audit, A-pose clearance measurements, skinning method, isolated-joint deformation battery (raised arm moves the waist by 0.00 mm), export verification, executed Godot 4.7.2 headless validation, and the short desktop visual pass still required. Sections 1–5.14 document the superseded asset.
2. `ART_ASSET_REPORT.md`, `RIG_SPECIFICATION.md`, `ANIMATION_SPECIFICATION.md` — asset audit, skeleton/weights/weapon-attachment contract, animation plan (each carries a NEW_HERO_01 section at the top; older sections describe the previous asset).
3. Open in Godot: Import → `project.godot` → run (F5) → `RigValidation` shows the NEW_HERO_01 rig at rest with the weapon seated on the right palm; read the automated PASS/FAIL checks and inspect with the camera presets (incl. `CloseHands`, `CloseWeapon`, `CloseShoulderR`).

## Deliverables map
| Item | Path |
|---|---|
| Untouched source (current) | `assets/source/NEW_HERO_01.glb` (previous asset kept beside it for provenance) |
| Rigged character (skin, no clips yet) | `assets/characters/HERO_01_RIGGED.glb` |
| Separate weapon | `assets/weapons/HERO_01_WEAPON.glb` (+ `scenes/weapons/HERO_01_WEAPON.tscn`) |
| Animations | not authored yet for NEW_HERO_01 (planned: `ANIMATION_SPECIFICATION.md`) |
| Blender working file | `blender/NEW_HERO_01_working.blend` (Blender 4.5 LTS; rebuildable by script 66) |
| Character scene | `scenes/characters/HERO_01.tscn` (auto-attaches weapon to `Weapon_R`, grip-aligned) |
| Validation scene | `scenes/main/RigValidation.tscn` |
| Evidence renders | `screenshots/rig/audit64_*` (source baseline), `audit66_*` (skeleton overlay), `audit67_*` (deformation battery), `audit68_rest_*` (rest preservation). Older folders document the superseded asset. |
| Repro pipeline | `tools/blender/scripts/64…68` via `tools/blender/run_bpy.sh` (scripts 01–63 are the previous asset's history), `tools/patch_glb_double_sided.py` (run automatically by script 68) |

## Key facts
- 24-bone humanoid (`Root…Toe_L` + `Weapon_R`), identical names in Blender/GLB/Godot; no geometry, UV, material or polycount changes from source (527,406 verts; rest bbox matches source within 2 mm).
- NEW_HERO_01 is an armored A-pose soldier with empty open hands: measured arm–torso clearance ≈185 mm at waist height, so arm weights inside the torso bands are exactly 0 and raising an arm moves the waist/belt by 0.00 mm (Blender battery, VALIDATION_REPORT 5.15).
- Weapon attaches via `BoneAttachment3D` on `Weapon_R`; the offset auto-seats the rifle's `GripPoint` on the palm at startup (verified 0.0000 m in-engine) and is manually overridable. Open hands + no finger bones ⇒ the grip rests on the flat palm; finger wrap is not claimed.
- Character height 0.9813 units as authored; `HERO_01.tscn` scales ×1.8 ≈ 1.766 m (assumption — adjust `ScaleRoot`).
- GDScript only, GLB/glTF 2.0, no addons or external dependencies.
- Rig stage runtime-validated on Godot 4.7.2 (headless editor compiled from official source in the authoring sandbox): clean import, CI all PASS, main scene zero script errors. Owner desktop visual pass still required (VALIDATION_REPORT 5.15). Re-run the CI anytime with `godot --headless --path . res://tools/godot/CICheck.tscn` after a one-time `--import`.
- Non-runtime folders (`blender/`, `screenshots/`, `assets/source/`, `tools/blender/`, `tools/out/`) contain `.gdignore` files so Godot never tries to import the authoring .blend / preserved source / screenshots. (A .blend inside a Godot project without a configured Blender path silently aborts *all* headless imports - this bit us once, see VALIDATION_REPORT 5.2; keep the .gdignore files.)
