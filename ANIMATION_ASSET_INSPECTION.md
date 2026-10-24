# Character and weapon asset inspection

> **2026-10-17 update — resolved.** The rigged hero (`source-assets/characters/hero/hero_rigged_source.glb`) and the
> rifle (`source-assets/weapons/rifle_source.glb`) were integrated into the player scene.
> The hero ships 79 joints and five clips (`idle`, `run`, `walk` plus baked
> `aim`/`fire`), the rifle carries a baked `MuzzlePoint`, and the muzzle flash,
> projectile spawn and `Muzzle` marker all use it. The sections below describe
> the **previous** state (`Hero_02.glb` static mesh, placeholder box weapon) and
> are kept as history. Current pipeline, numbers and evidence:
> [`HERO_RIG_PIPELINE.md`](HERO_RIG_PIPELINE.md) and
> `qa-evidence/hero-rig/`.

**Date:** 2026-10-16

**Project:** Godot 4.7.2, project root `game/`

**Scope:** factual inventory before any character/weapon scene changes. This report does not claim Blender, Godot import, animation, or Android validation.

## Actual asset inventory

| Path | Source/runtime status | Structure verified | Rig / clips | Findings and limitations |
|---|---|---|---|---|
| `Hero_02.glb` (repository root, local untracked file; 18,831,072 bytes) | Local Tripo 2.0 GLB source candidate; not currently referenced by a Godot scene and not included in the branch | **VERIFIED structurally** by reading the GLB JSON/buffer and producing an auxiliary software orthographic preview. **Not opened in Blender.** | 0 skins, 0 joints, 0 animation clips | One node, one mesh primitive, one material. POSITION bounds: X `[-0.236542, 0.236542]`, Y `[0, 1.000002]`, Z `[-0.128952, 0.128952]`; 253,387 vertices and 482,282 triangles. Three embedded 2048px textures (normal PNG, base-colour JPEG, metallic/roughness JPEG). The auxiliary preview shows a full-body armored humanoid in an upright pose. It is a static mesh, not a rigged or animated character. Model forward direction/attachment points have not been validated in Blender or Godot. The triangle count also needs a mobile-performance review before runtime use. |
| `HERO_01.glb` (repository root, tracked; 2 bytes) | Tracked file | **VERIFIED invalid/incomplete:** shorter than a GLB header; not opened as a valid GLB | Unknown; no valid asset structure to inspect | Do not load, rename over, or treat this as a character asset. |
| Weapon GLB/glTF/BLEND files | None found in the project or repository asset scan | No weapon model file to inspect | Unknown / not applicable | `game/resources/weapons/{pulse_rifle,nova_launcher,arc_shooter}.tres` are gameplay data resources, not visual weapon assets. |
| Player visual and weapon socket | `game/scenes/player/player.tscn` | Scene text inspected | Capsule visual; no Skeleton3D, AnimationPlayer, AnimationTree, or imported character | `WeaponBody` is a BoxMesh prototype and `Muzzle` is a placeholder Marker3D. Its transform is not verified against a real weapon. The capsule collision shape is a gameplay collider and should remain independent of future character geometry. |
| Runner and Shooter visuals | `game/scenes/enemies/runner.tscn`, `game/scenes/enemies/shooter.tscn` | Scene text inspected | Capsule visuals; no skeleton or animation clips | Enemy movement/combat scripts already exist. No enemy character model source was found. |
| Training drone | `game/scenes/enemies/training_drone.tscn` | Scene text inspected | No character rig/animation | Separate combat target used for practice feedback. |
| Blender runtime | Not available as a native CLI in this sandbox | `bpy==4.5.14` wheel installed under ignored `.cache/` and import attempted | No Blender session was run | Import stops because native libraries (`libXrender`, `libXfixes`, `libXi`, `libxkbcommon`, `libSM`, `libICE`, and `libGL`) are absent. The auxiliary preview is not a Blender viewport and is not evidence of a Blender export or rig check. |

## Implementation decision

The current gameplay controller, projectiles, target damage, and wave system are already present; they should be repaired and extended rather than replaced. A new skeleton, hand grip, muzzle transform, or character animation must **not** be guessed from these assets. The supplied `Hero_02.glb` has no skeleton or clips, and no weapon GLB exists. Until a rigged source is supplied or a Blender rigging workflow is explicitly available and validated, animation and weapon attachment remain blocked. No runtime character/weapon model change is claimed by this inventory.

## Verification boundary

- **VERIFIED:** Git/project inventory, file sizes, GLB JSON and buffer structure, mesh bounds/counts, embedded texture references, and scene/script structure.
- **VERIFIED only as an auxiliary preview:** an upright, full-body armored humanoid silhouette in four orthographic software renders. This is not Blender viewport inspection.
- **UNKNOWN:** Blender visual inspection, skeleton or animation behavior, final forward-axis decision, weapon grip/muzzle transforms, Godot GLB import and runtime appearance, and Android performance.
