# Baseline audit — EXOCOMFLICT: STELLAR HORIZON / Aetherfall

**Audit date:** 2026-10-29 (Asia/Kuching)

**Scope:** actual contents of this standalone branch before the interactive-environment vertical slice.
**Method:** repository/source audit, layout/GLB metadata inspection, static asset contract. The audit does not infer runtime graphics quality from Blender renders.

## Executive result

This branch is a **standalone Aetherfall world-review project**, not the former full game. It preserves one recognizable industrial canyon/tower world, its reusable kit, route geometry and a free-fly review camera. It contains **no player controller, enemy system, resource inventory, mission/objective service, HUD, interaction system, damage system, or navigation system**. Those systems cannot be integrated with a pre-existing game service because none exists in this branch.

The smallest safe enhancement is therefore a self-contained Aetherfall vertical slice: one local persistent progression state, one controlled player validation actor, one tech cache, and one objective device. It must not claim compatibility with a removed game-wide inventory or mission service.

## Component classification

| Component | Classification | Evidence / consequence |
| --- | --- | --- |
| Main world scene | **VERIFIED WORKING** | `project.godot` points to `scenes/aetherfall.tscn`; `scripts/aetherfall.gd` builds the world from `layout.json`. Existing headless smoke evidence covers 251 placements. |
| World geometry | **VERIFIED WORKING** | 27 kit module kinds, 251 placements, three connector ramps, 29 GLBs total including orbit/ramp. Existing world remains the starting layout. |
| Player spawn markers | **PARTIALLY WORKING** | `layout.json` declares `primary` `[-30, 1.2, 14]` and `secondary` `[30, 1.2, 14]`, but no player scene/controller consumes them. |
| Player / third-person camera | **NOT IMPLEMENTED** | Only `ReviewCamera` free-fly script exists. Third-person readability cannot yet be honestly validated. |
| Enemy spawn / enemy approach actors | **NOT IMPLEMENTED** | Routes are markers only; no enemy, spawner, AI, encounter or NavMesh is present. |
| Objectives / mission state | **NOT IMPLEMENTED** | No objective resource, mission script, HUD, or state authority exists. |
| Reward / inventory / progression | **NOT IMPLEMENTED** | Repository search finds no reward, resource, inventory, unlock, save, or HUD implementation. |
| Interactive objects | **NOT IMPLEMENTED** | Existing machinery, vents, gates and cover are visual/static modules only. |
| Traversal | **VERIFIED WORKING for tested ramps** | Existing test suite samples three ramps with all colliders and moves a capsule both directions. This is not a complete player playtest. |
| Collision | **PARTIALLY WORKING** | 188 generated proxy bodies; deck/bridge/catwalk use named floor bounds, gate/rail have special handling. Non-floor prop collision is mostly AABB proxy. |
| Cover | **PLACEHOLDER / PARTIALLY WORKING** | Seven intentional cover positions and reusable cover assets exist, but no player, attack, or camera system validates combat usefulness. |
| Lighting/environment | **PARTIALLY WORKING** | Script creates procedural sky, fog, directional light, glow and mobile renderer configuration. Visual Godot output remains **UNKNOWN** in this sandbox. |
| Materials/textures | **VERIFIED STATIC** | GLB inspection confirms normal and metallic-roughness maps on representative PBR materials. Final Godot visual response remains **UNKNOWN**. |
| Animation | **PARTIALLY WORKING** | Tower orbit GLB has an `AnimationPlayer` and is played. No gameplay prop state animation exists. |
| Navigation | **NOT IMPLEMENTED** | No `NavigationRegion3D`, NavMesh, link, or AI integration exists. |
| Rendering method | **VERIFIED CONFIGURED** | `project.godot` specifies Godot Mobile rendering. It is configuration, not a device-performance measurement. |
| Mobile performance | **UNKNOWN / UNVERIFIED** | No frame time, draw-call, GPU, memory, or device test is stored. |

## Level design baseline

- **Landmark:** energy tower at approximately `(0, 0, -26)`.
- **Primary/secondary spawn markers:** outer south deck at X `-30` / `30`, Z `14`.
- **Main routes:** central deck route, east bridge, west catwalk, and lower canyon approach. Three physical ramp connectors were previously tested.
- **Existing combat language:** four cover barriers and three cover machines are positioned intentionally on the deck; without a player/enemy/combat implementation, their combat value is not yet verified.
- **Critical limitation:** no third-person camera or player exists, so safe-spawn readability, camera clipping, pickup reachability, and combat-space validation are presently **UNKNOWN**, not failed or passed.

## Minimum approved enhancement

1. Preserve layout, routes, PBR kit, collision builder and review camera.
2. Add only two new reusable hero props initially: `TechCache` and `ObjectiveDevice`.
3. Add a local `AetherfallProgressionState` only because this branch has no pre-existing equivalent. It will persist the vertical-slice cache collection and tech-data reward in `user://`; it is not represented as a replacement for a game-wide inventory.
4. Add a basic third-person `AetherfallPlayer` solely to make the integrated slice playable and validate proximity/camera/collision.
5. Place the cache beside the primary route without blocking it; place the objective device at the central relay/cover-machine zone. Require the cache reward before activating the device, so the sequence has an authoritative gameplay dependency.
6. Defer generator, ammunition supply, weapons, enemy AI, NavMesh, and mass prop production until this vertical slice passes interaction, duplicate-prevention, collision and persistence tests.

## Audit limitations

- The sandbox compiler used for Godot validation is headless and lacks a graphical backend, so it cannot provide truthful Godot screenshots or GPU measurements.
- Blender renders are useful for asset inspection only; they do not validate Godot lighting or mobile performance.
- An existing untracked historical audit under `docs/world/` was not used or changed by this audit.
