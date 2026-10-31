# Validation report — Stellar Horizon vertical slice

**Recorded / last updated:** 2026-10-31 (Asia/Kuching)

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

## Ice Planet Phase 1 — exterior macro composition

Phase 1 implements the approved cold, open-sky robot-planet direction without claiming AI or combat. The world now assembles nine dedicated placements from four Blender-authored PBR asset families: four glacier shelves, two frozen skyline spires, two cryo pylons, and the Sentinel Archive exterior. The archive is the visible route destination and has segmented collision volumes rather than an indiscriminate solid box, preserving its future doorway/vestibule work.

`aether_ice` is a new original procedural material dependency with its own albedo, normal and ORM maps. Sky, sun, fog and tone parameters now use a cold ice-blue exterior palette with slightly leaner fog for landmark visibility. The runtime visual result remains unverified until opened in graphical Godot.

## Phase 2 — cover and traversal blockout

Phase 2 assembles eight sparse, purpose-defined outdoor placements from four Blender-authored PBR GLB families: `glacier_berm`, `salvage_pod`, `cryo_bulkhead`, and `ice_terrace`. The configuration provides one documented role for each placement: Landing Ridge cover, west/east Scrapper Basin cover lanes, an east bulkhead sightline break, Archive approach cover, two raised side terraces, and a Lower Canyon maintenance-shell cover. It is explicitly not a robot/combat/hazard or Archive-interior implementation.

**Completed static evidence:** `tests/check_assets.py` verifies the four GLB 2.0 containers, minimum authored mesh counts (10/13/15/11), embedded PBR normal+ORM map references, eight nonempty purposes, twelve intentional collision boxes, route-clearance records and a conservative 2D clearance calculation. The central route and three connector approaches retain at least **0.5m static margin** after subtracting the setpiece collision footprint and configured route half-width. This is a static geometric check, **not** a Godot physics/capsule execution result.

`tests/phase2_cover.gd` is supplied to check runtime assembly (eight placements, twelve collision volumes, two 3-level terraces and three lights), but it has **NOT YET RUN** in a post-change Godot runtime. No graphical Godot screenshot, final material composition, changed-route capsule traversal, player feel, performance or combat/AI claim follows from this record.

## Phase 3 — compact Archive interior and named Data Core

Phase 3 changes the Sentinel Archive exterior from a solid visual core to a shell with a deliberately open south/front threshold: six exterior collision volumes now model the side shells, rear shell, front wings and lintel while leaving the doorway physically clear. `archive_vestibule.glb` (55 meshes) fits into that footprint as one short vestibule and one objective room. It has floor channels, partition opening, server pylons and console banks; it is not a multi-room dungeon. `archive_computer.glb` (23 meshes) is the single final-tech prop and contains the Blender-authored `ArchiveComputer_Download` animation.

**Completed static evidence:** Blender `bpy` 5.0.1 generated both GLBs and `source/aetherfall_archive_interior.blend`. `tests/check_assets.py` verifies both GLB 2.0 containers, PBR normal+ORM references, detail floors, terminal animation, one interior configuration, four interior collision boxes, two lights, a collision-free exterior door point, the named `aetherfall_sentinel_data_core`, and the state/persistence methods. The cache config now documents `tech_data` as an access credential rather than the final Data Core; relay feedback does not claim mission completion.

The supplied `tests/archive_phase3.gd` owns a private test actor and covers the real local sequence: no credential → locked rejection; persisted credential → authorization; one timer-driven download; persisted named Data Core; duplicate/concurrent rejection; fresh state reader reload. It has **NOT YET RUN** in a post-change Godot runtime because this sandbox does not retain a Godot executable. Static parsing is not substituted for that execution.

No claim is made for a playable Archive door animation, visual Godot lighting, exterior-to-interior capsule traversal, combat/AI, hazards, extraction, generic mission completion, performance, or device behavior.

## Connected Expanse — world topology and higher-density surface detail

The connected-expanse pass turns the prior finite-looking outer connector ends into a closed physical perimeter loop. Seventeen route spans link the original west-catwalk endpoint, east-bridge endpoint, and lower-canyon endpoint through fourteen broad ice shelves; one additional recovery span reaches the lowlands. Nine 80m × 72m lowland fields create a contiguous 240m × 216m ice surface beneath the exposed paths. The authored outer loop spans 208m × 170m. These are actual visual and `StaticBody3D` surface placements in the Aetherfall scene, not merely map markers.

The transit kit intentionally has low visual curbs and beacons but no collision rails or invisible boundary wall. A fall has a lower ice surface beneath it and an authored lower-canyon recovery slope; this does **not** imply damage, respawn, a falling state, or any gameplay consequence without a controller/runtime decision.

**Completed static evidence:** Blender `bpy` 5.0.1 generated three PBR GLBs (`expanse_shelf`: 25 meshes, `transit_spine`: 23, `lowland_field`: 23), source `aetherfall_connected_expanse.blend`, and original 768px ice/metal/hazard albedo, normal, and ORM maps. `tests/check_assets.py` verifies GLB/PBR integrity, source, 768px PNG headers, exact placement/route counts, explicit legacy-endpoint links, loop degree-two topology, nine lowlands, fourteen shelves, 18 total spans, and coverage extents. The higher texture density comes from the new 768px maps plus repeated UVs on the large surfaces; legacy embedded GLBs were not mass-rebuilt in this pass.

Setelah laporan screenshot QA yang menunjukkan edge far-lowland terbaca seperti dinding es di tengah framing awal, field diturunkan dari Y = -14,0 menjadi **Y = -18,5**. Recovery lower-canyon juga diperpanjang dari 6 m menjadi 44 m menuju field selatan: selisih 12,25 m menghasilkan grade statis 27,8%, di bawah batas config 0,30. Kamera awal kini secara eksplisit menerapkan overview key 1 yang mengarah ke skyline/basin, bukan transform scene yang hampir horizontal. `tests/check_assets.py` memverifikasi elevasi seragam, endpoint recovery berada pada lowland, panjang horizontal 44 m, dan grade maksimum. Ini adalah koreksi konfigurasi/geometri terverifikasi statis; screenshot setelah koreksi belum tersedia.

`tests/world_expansion.gd` supplies a Godot runtime contract for 9 lowlands, 14 shelves, 18 spans, and 41 collision surfaces, plus the lowered field elevation and the recovery-spine midpoint. It has **NOT YET RUN** in a post-change Godot executable. Thus actual world assembly, slope traversal, lowland landing behavior, texture perception, graphical camera framing, memory, draw calls, FPS, and mobile behavior remain unverified.

## Camera-only QA and dense verticality pass

`scenes/aetherfall.tscn` is now character-free for visual QA. The default `ReviewCamera` provides ten numeric presets (overview through lower-canyon high/low read), **I** for the Sentinel Archive vestibule/Data Core view, and **O** for the full Connected Expanse loop. The interaction actor remains only in dedicated tests so visual review is not obstructed by an avatar or HUD.

A reference-analysis brief is recorded in `docs/ART_DIRECTION_REFERENCE.md`. Based on its layered hangar/industrial principles, the world now adds two 13m refinery stacks, a 24m overhead service gantry at 7m, and a raised operations deck at 5m. This produces foreground/mid/high structural rhythm rather than merely spacing additional floor props.

## Structural-density and atmosphere enhancement

The world now adds six purpose-authored placements outside the preserved 251-placement kit contract:

- **Field Outpost** at the west primary-spawn edge: entry landmark, shelter silhouette and local cyan guide light.
- **Relay Annex** east of the central line: vertical receiver/mast architecture that gives the relay objective a credible physical support building.
- **Service Hangar** at the east deck: open-front industrial shelter with non-blocking segmented collision, load bays, roof vents and a local light.
- **Three Cargo Service Clusters:** named logistics/maintenance cover setpieces placed beside their respective building, not on the central direct lane.

Atmosphere parameters now use less than half the prior fog density (`0.00095` from `0.0018`), lower sky fog influence, restrained glow/bloom, modest contrast/saturation correction and a more separated blue horizon palette. This is an authored configuration change; final perceived sharpness remains a graphical-runtime check.

## Visual and performance status

- **Godot graphical screenshot:** **NOT PROVIDED / UNVERIFIED.** The sandbox validation build has X11, Wayland, Vulkan and OpenGL disabled, so it cannot make an honest graphical Godot screenshot. Blender images are not substituted for a Godot screenshot.
- **Third-person visual readability/camera clipping:** **PENDING runtime inspection.** A basic third-person validation actor is now supplied; its exact visual camera result must be checked in an editor/game window.
- **Mobile FPS, frame time, draw calls, memory:** **NOT MEASURED.** The project remains configured for Godot Mobile rendering, but no performance claims are made.

## Manual review and runtime path for a local Godot GUI

1. Import the repository root with Godot 4.7 or newer and run `scenes/aetherfall.tscn`.
2. The default scene is intentionally **camera-only**: hold right mouse to look; use **WASD/Q/E**, **1–0**, **I**, and **O** to inspect the exterior, cover/traversal, Archive threshold, vestibule, Archive Computer, and full Connected Expanse loop without a player mesh or HUD.
3. To validate state rather than merely view it, run the private-actor contracts from the project root:
   ```bash
   godot --headless --path . --script res://tests/interactive_slice.gd
   godot --headless --path . --script res://tests/archive_phase3.gd
   godot --headless --path . --script res://tests/world_expansion.gd
   ```
4. The Archive contract first commits one access credential, then verifies `locked → authorized → downloading → collected`; it must find the named Data Core after constructing a new `AetherfallProgressionState`. Its cleanup deletes `user://aetherfall_stellar_horizon.cfg` after the test.
5. The expansion contract confirms the configured loop/collision assembly; it is required before treating the former remote connector ends as runtime-verified. It does not prove falling physics, traversal feel, or a return path under controller input.
6. A GUI review may inspect the physical open exterior threshold, compact interior, and connected loop, but it does not alone prove persistence, combat, mission completion, performance, or device behavior.

## Known scope boundary

This is a local, authoritative vertical slice, not a claim that a missing EXOCOMFLICT inventory, combat, enemy, save-game or mission framework exists. Enemy spawn/approach, weapon/combat, NavMesh, objective chains beyond this relay, LOD, and device profiling remain outside the implemented slice.
