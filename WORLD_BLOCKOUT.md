# NEON FRONTIER — Playable 3D World

> **18 Oct 2026 — historical implementation notes below.** The current playable
> scene has retired KayKit scripts/assets and instead dresses the bay and five
> exterior districts/perimeter with the user's converted SciFi Starter Kit FBX
> models (`scifi_bay_builder.gd`, `scifi_frontier_dresser.gd`). Procedural ground,
> ramps, structures, and collision still exist, so this is **not** a claim of
> all-FBX final art. Lighting/HUD/Explore are being reworked under
> [`docs/DECISIONS.md`](docs/DECISIONS.md).
>
> The KayKit discussion below describes the earlier build and is **not** a
> current asset manifest or runtime guarantee.

**Purpose:** a continuous, explorable third-person shooter level assembled from real 3D scene components. This is a playable production blockout, not a static concept image, final art lock, or release-ready world. All measurements are provisional Godot units.

## Godot entry points

- Main game: `game/project.godot` → `res://scenes/main.tscn`.
- Standalone environment: `game/scenes/worlds/neon_frontier.tscn`.
- World assembly: `game/scripts/worlds/neon_frontier_world.gd`.
- Reusable component builder: `game/scripts/worlds/neon_frontier_asset.gd`.
- Packed 3D component scenes: `game/scenes/worlds/components/*.tscn`.
- Automated environment checks: `tests/neon_frontier_world_smoke.gd` and `tests/arena_blockout_smoke.gd`.

Each packed component scene has a `Node3D` root and creates named `MeshInstance3D` parts, material instances, and gameplay-relevant `StaticBody3D`/`CollisionShape3D` components. The world script instances those packed scenes into one connected level. Most of the current level is still procedural blockout geometry, but selected high-visibility props now use actual licensed KayKit GLTF models instantiated at runtime: depot, cargo stacks, truck, drill, landing pad, and boundary rocks. No static image or plane stands in for the explorable world; the player, enemies, world, lights, meshes, and collision remain in the same Godot scene.

## Scale and spatial plan

The base terrain is approximately **192 × 180 units** and is centered slightly north of the combat arena. The central combat platform is about 42 units across; the perimeter, side districts, and boss platform extend several dozen units beyond it. A full-width terrain collision plane keeps exploration continuous while layered rock formations and reinforced boundary structures frame the frontier.

```text
                               NORTH / BOSS FRONT
                        perimeter gate and sensor tower
                                      │
                          ┌───────────┴───────────┐
                          │ circular boss platform│
                          │     colossal gate     │
                          └───────────┬───────────┘
                              broad energy causeway
                                      │
 WEST MILITARY OUTPOST ─── CENTRAL REACTOR ARENA ─── EAST LANDING PAD
 command / lab / depot       wave gates + cover       vehicle apron
        │                             │                      │
        └──── wrecked sector ─── south access ───── extraction plant
                                 alien terrain / resources
```

This diagram is a location guide only; the delivered level itself is a fully spatial 3D scene. Outpost, central arena, landing apron, generator yard, ruined sector, perimeter gates, causeway, and boss zone are joined by walkable ground plates and open routes. No zone is a separate image or disconnected floating island.

## 3D component inventory

| Packed scene | Constructed 3D pieces and gameplay role |
|---|---|
| `reactor_core.tscn` | Separated structural footings, four load-bearing pylons, transparent containment cylinder, emerald/turquoise core, segmented energy halos, overhead service arms, orange conduits; the lower center stays open to preserve the combat lane. |
| `command_center.tscn` | Armored foundation and hull, raised command bridge, visor windows, door, roof vents, antenna mast and dish, corner armor, and fasteners. |
| `research_lab.tscn` | Ceramic laboratory shell, glass sampling vessel, colored sample core, service wings, roof vents, equipment pods, and a maintenance arm. |
| `equipment_depot.tscn` | Licensed KayKit `cargodepot_A` module with a generated bounds collider, plus stacked cargo models; procedural depot details remain as a load-failure fallback. |
| `generator_bank.tscn` | Three contained generator towers, glass sleeves, luminous energy columns, repeated pressure bands, feed/return pipes, and service walk. |
| `boss_gate.tscn` | Tall reinforced docking frame, supports, shutter leaves and slats, cyan seam lights, power conduits, bolts, and warning hardware. |
| `defense_turret.tscn` | Mount plate, yaw bearing, armored housing, twin barrels, optical sensor, and base collision. |
| `sensor_tower.tscn` | Structural shaft, observation deck/cabin, radar plates, masts, dishes, and collision shaft. |
| `landing_pad.tscn` | Raised collidable foundation, procedural safety edges and beacon lights, with the licensed KayKit landing-pad model integrated as the central deck surface. |
| `wrecked_transport.tscn` | Damaged hull, glazed cockpit, separated/broken wings, engines, hot impact damage, and scattered wreck plates. |
| `alien_drone_wreck.tscn` | Chassis, luminous sensor core, articulated broken arms, joints, claw plates, and a damaged cable. |
| `crystal_cluster.tscn` | Individually tapered, differently colored cyan/emerald/turquoise mineral shards on geological roots. |
| `alien_flora.tscn` | Stems, luminous buds, varied leaves, and arching fronds. |
| `rock_cluster.tscn` | Procedural warm sandstone/rose boundary rocks remain the fallback; four perimeter positions use KayKit `rocks_B` models with bounds colliders. |
| `enemy_spawn_gate.tscn` | Open arch frame, visible warning panels, cyan guide strips, beacons, and clear passage through the middle. |
| `cover_module.tscn` | Segmented waist-high armored cover with yellow top marking, edge guards, signal panels, bolts, and collision. |

### Licensed modular world assets

A selective subset of **KayKit Space Base Bits** is stored at `game/assets/world/kaykit_space_base_bits/`. The copied files retain their GLTF geometry, companion BIN data, shared texture atlas, and upstream `LICENSE.txt` (CC0 1.0). Runtime placements use `cargodepot_A` in the equipment-depot component, `cargo_A_stacked`/`cargo_B_stacked` in depot and outpost supply areas, `spacetruck_large` on the western vehicle apron, `drill_structure` at the extraction plant, `landingpad_large` on the east pad, and four `rocks_B` models around the outer terrain. `gltf_asset_library.gd` loads/caches templates, makes per-placement instances, and can add bounds-based colliders where needed. The art source is a GitHub `main` archive (not pinned to an immutable upstream commit); the pack is a selective visual upgrade, not a final art/palette approval. Other blockout geometry remains editable procedural 3D.

## Districts and traversal

### Central combat arena

The central 42-unit platform has layered metal trim, alternating panel plates, seams/fasteners, cyan and turquoise energy channels, copper conduits, yellow/orange warning edges, four open entry arches, and asymmetric cover. The tall reactor is the central visual anchor, supported above the open lower combat lane. The existing southeast service deck and shallow ramp remain as an explicit no-jump traversal test. Spawn beacons correspond to the actual Wave Director markers.

### Military outpost

The western district contains the command center, laboratory, equipment depot, observation/signal towers, supply stacks, and damaged perimeter sections. The depot and supplies now include actual KayKit GLTF models; a scaled service truck sits on the collidable-free vehicle apron. The access apron connects to the central arena; buildings have volume and selected collision, while service details remain visual-only. A damaged security checkpoint marks the ruined edge.

### Extraction plant and landing zone

The east/northeast route reaches a full vehicle landing pad, the generator bank, and a KayKit extraction drill structure. The raised pad keeps its procedural safety frame and beacons around an integrated KayKit deck model. Five large pipe runs, supports, maintenance walkways, and colored cores visually lead back toward the reactor. Energy conduits are placed above the terrain with supports rather than floating without attachment.

### Destroyed frontier sector

The south/west side route contains a crashed human transport, broken alien drone, disabled turret/checkpoint, fractured floor plates, scrap, scarred walls, controlled orange damage accents, and a sealed deeper-facility gate. Debris is kept off the main approach lane.

### Perimeter and alien terrain

Segmented blue-and-silver defense walls leave actual openings at the north, south, east, and west gates. Six turret emplacements, sensor towers, radar arrays, and a communication mast establish the outpost defense ring. Beyond the traversable industrial plateau, warm layered rock shelves, larger cliff clusters, mineral shards, and varied alien flora frame the boundary. Small resource canisters occupy side alcoves away from the main firing lanes.

### Boss encounter

A broad northbound causeway and open perimeter gate lead from the central arena to a large circular, reinforced platform. The monumental docking gate and energy supports form a high-contrast landmark behind the boss floor. The arena center is intentionally open; its warning ring and radial energy markings keep its edge readable.

## Materials, lighting, and readability

The environment uses `StandardMaterial3D` materials with explicit albedo, metallic, roughness, transparency, and restrained emissive settings. Pearl ceramic and silver carry most human structures; royal blue identifies military armor; cyan/turquoise mark energy and routes; emerald highlights selected cores/crystals; yellow indicates safety; orange/red signal damage and hazards; warm sandstone, rose rock, teal foliage, and lime bioluminescence provide a contrasting planetary palette. The main combat area is lit by a warm directional daylight source and bright ambient sky. Small local cyan/green lights mark only major energy landmarks, while fog/glow are deliberately subtle.

Combat readability takes priority over prop density: cover is waist-high and asymmetric, principal routes are wide, the arena center is open, and defensive structures sit on the edge of the play space. Decoration and repeated props do not replace collision or the enemy/player combat systems.

## Validation and known limits

**Previously verified, before the current KayKit/HUD changes (Godot 4.7.2 headless):** an earlier checkout reported clean main-scene startup and a world smoke run with 2,545 procedural `MeshInstance3D`s and 138 `StaticBody3D`s. The earlier traversal checks reached the boss platform and raised landing pad, and the earlier combat/world regression suite passed. Those counts and results are historical baselines, not a validation of the new GLTF loader, asset colliders, EMP skill, or expanded joystick checks.

**Current change validation:** GDScript parsing/lint passes with `gdtoolkit` on the modified scripts. A Godot executable is not present in this checkout, so the new runtime asset integration and expanded smoke tests have **not** been run here. Run the headless import and smoke-test commands below with Godot 4.7.2 before treating scene integration or collider behavior as verified.

The scene remains a blockout with selected licensed 3D models, not a final art lock. Visual material response, mobile draw-call cost, movement feel, enemy navigation through every route, Android rendering/performance, and physical-device behavior still need playtesting. No release-art, Android-export, or device-performance claim is made.

## Environment production stages and approval gates

Follow these five stages in order; approval of one gate does not approve the next gate or final visuals/performance.

1. **Blockout — initial layout approved; interaction/visual feel still pending.** The user approved the initial connected layout. Preserve the arena footprint, combat lanes, route widths, collision, spawn/object placement, and continuous traversal. Historical headless checks cover central-to-boss, boss-platform, and landing-pad traversal, but do not verify sightlines, feel, or touch navigation on a device.
2. **Asset production — selective integration in progress by request.** Integrate actual modular 3D assets only where appropriate; the initial KayKit subset listed above is now placed in the depot, supply areas, apron, extraction plant, landing pad, and outer rocks. Preserve real geometry, scale/origin, relevant colliders, component-scene integration, provenance, and license. Keep fallbacks editable and do not turn this selective import into final-art approval. A flat photo or image plane is not a world asset.
3. **Materials and textures — after asset silhouettes and scale are accepted.** Apply PBR material properties, texture maps, surface detail, and the bright NEON FRONTIER palette. Check UVs, transparency, texture memory, and readability on the intended mobile renderer; existing procedural colors/emission are placeholders, not a completed texture pass.
4. **Lighting and VFX — after material readability.** Tune key/fill/environment lighting and add restrained energy, particle, impact, and environmental effects. Protect combat visibility and establish per-effect limits for lights, particles, transparency, and overdraw.
5. **Optimization — on a selected Android baseline.** Profile a real Android build for frame time, draw calls, shader/material cost, texture and mesh memory, physics load, particles/overdraw, load time, heat, and stability. Optimize measured bottlenecks, then repeat gameplay/traversal checks. A headless scene test or successful export alone is not a device-performance pass.
