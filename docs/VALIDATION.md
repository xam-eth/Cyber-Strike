# Validation report — Stellar Horizon vertical slice

**Recorded:** 2026-10-29 (Asia/Kuching)

**Scope:** static asset/source validation performed after adding the local Aetherfall slice. This report deliberately separates completed checks from checks that require a graphical Godot runtime.

## Completed evidence

| Check | Result | Evidence |
| --- | --- | --- |
| Editable production source | **PASS** | `source/aetherfall_interactives.blend` was written by Blender bpy 5.0.1. |
| GLB export integrity | **PASS** | `tech_cache.glb` is GLB 2.0 with 24 nodes/22 meshes and `TechCache_Open`; `objective_device.glb` is GLB 2.0 with 20 nodes/19 meshes and `ObjectiveDevice_Activate`. |
| PBR dependency contract | **PASS (static)** | Both hero GLBs contain embedded textures and PBR materials with normal + metallic-roughness texture references. This does not claim final rendered appearance. |
| Vertical-slice asset contract | **PASS** | `python tests/check_assets.py` checks the original world contract plus exactly two interaction props, their sources, mesh floors, animation names, scene scripts and PBR dependencies. |
| GDScript syntax parse | **PASS (static)** | `gdparse scripts/*.gd tests/*.gd` parses the new and existing scripts. A parse pass is not equivalent to a Godot runtime test. |
| Existing world regression history | **VERIFIED BEFORE THIS CHANGE** | Earlier clean Godot validation recorded 251 placements, 188 proxy colliders, three ramp-clearance routes and two-direction capsule traversal. Those runs predate this interactive change. |

## Required Godot runtime validation

The following test is included as `tests/interactive_slice.gd` and must be run with a Godot 4.7 editor/headless binary from the project root:

```bash
godot --headless --path . --editor --quit
godot --headless --path . --script res://tests/interactive_slice.gd
```

It asserts:

1. both props instantiate into the unchanged Aetherfall world;
2. each has a distinct functional collider and `Area3D` range volume;
3. Blender-authored clips imported as `AnimationPlayer` resources;
4. cache reward is committed exactly once and persisted in `user://aetherfall_stellar_horizon.cfg`;
5. duplicate cache and relay interactions are rejected;
6. relay activation requires the committed tech-data reward and persists after reloading its local state.

**Status at report time: NOT YET RUN in the post-change Godot runtime.** A sandbox rebuild of Godot 4.7.2 was attempted because no engine binary persisted in the environment; it could not finish within the available sandbox build window and the parallel attempt hit the compiler memory limit. No runtime PASS is claimed here.

## Visual and performance status

- **Godot graphical screenshot:** **NOT PROVIDED / UNVERIFIED.** The sandbox validation build has X11, Wayland, Vulkan and OpenGL disabled, so it cannot make an honest graphical Godot screenshot. Blender images are not substituted for a Godot screenshot.
- **Third-person visual readability/camera clipping:** **PENDING runtime inspection.** A basic third-person validation actor is now supplied; its exact visual camera result must be checked in an editor/game window.
- **Mobile FPS, frame time, draw calls, memory:** **NOT MEASURED.** The project remains configured for Godot Mobile rendering, but no performance claims are made.

## Manual smoke path for a local Godot GUI

1. Import the repository root with Godot 4.7 or newer and run `scenes/aetherfall.tscn`.
2. Use **WASD** to move, hold right mouse to look, **E** to interact, and **F1** to toggle the preserved free-fly review camera.
3. From the primary spawn, collect the cache on the adjacent central approach. The HUD must increase `Data teknologi tersimpan` to 1.
4. Continue to the compact relay in the central machinery/cover zone. Activate it with **E**.
5. Restart the scene. The opened cache and active relay should retain their state from `user://aetherfall_stellar_horizon.cfg`; deleting that file resets the vertical slice.

## Known scope boundary

This is a local, authoritative vertical slice, not a claim that a missing EXOCOMFLICT inventory, combat, enemy, save-game or mission framework exists. Enemy spawn/approach, weapon/combat, NavMesh, objective chains beyond this relay, LOD, and device profiling remain outside the implemented slice.
