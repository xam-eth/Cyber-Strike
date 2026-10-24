# Asset list

Everything the world is made of, where it comes from, and where it stands.

Two kinds of asset live here:

- **Component models** — 16 catalogued assets in `tools/asset-forge/catalog.json`,
  each built by one module in `tools/asset-forge/src/world/`, each with a Godot
  scene in `game/scenes/worlds/components/`, each with a staged GLB in
  `game/assets/forge/world/`.
- **Terrain and dressing** — built directly by
  `tools/asset-forge/src/worlds/terrain.js` (decks, roads, aprons, perimeter,
  outer shelf). It has no catalog entry because it is not placed as a prop: it is
  the ground the props stand on.

## 1. Components

| Asset | id | Target height | Animations | Sockets | Instances |
| --- | --- | --- | --- | --- | --- |
| Reactor Core | `reactor_core` | 6 m | `core_pulse` | `charge_fx` | 1 |
| Command Centre | `command_center` | 7.5 m | `beacon_pulse` | `dish_yaw`, `door` | 1 |
| Research Laboratory | `research_lab` | 5.5 m | `sample` | `vessel` | 1 |
| Equipment Depot | `equipment_depot` | 4.6 m | `lamp_pulse` | `cargo_slot`, `door` | 2 |
| Generator Bank | `generator_bank` | 6.5 m | `energy_columns` | `feed_pipe` | 1 |
| Landing Pad | `landing_pad` | 1.2 m | `beacon` | `pad_centre` | 1 |
| Boss Gate | `boss_gate` | 11 m | `gate_open` | `shutter_l`, `shutter_r` | 1 |
| Defence Turret | `defense_turret` | 2.8 m | `yaw_sweep`, `fire_recoil` | `muzzle_l`, `muzzle_r`, `sensor` | 7 |
| Sensor Tower | `sensor_tower` | 11 m | `dish_scan` | `dish`, `beacon` | 5 |
| Wrecked Transport | `wrecked_transport` | 3.4 m | `ember_flicker` | `hull_cut`, `wing_l` | 1 |
| Alien Drone Wreck | `alien_drone_wreck` | 2.4 m | `sensor_fade` | `sensor_core`, `arm_l`, `arm_r` | 1 |
| Crystal Cluster | `crystal_cluster` | 3.2 m | `shimmer` | `harvest_point` | 4 |
| Alien Flora | `alien_flora` | 1.8 m | `sway` | `root` | 18 |
| Rock Cluster | `rock_cluster` | 3.6 m | — | `base` | 8 |
| Enemy Spawn Gate | `enemy_spawn_gate` | 5.2 m | `strip_pulse` | `spawn_point` | 8 |
| Cover Module | `cover_module` | 1.15 m | — | `top_mark` | 4 |

**64 instances, 16 unique models.** The count per id is not decoration — it is the
reason the world reads as infrastructure rather than a showroom: five sensor
towers, seven turrets and eight gates are what a *perimeter* means.

`rock_cluster` and `cover_module` carry no clips on purpose. Rocks do not move,
and a cover module that flinches when you shoot past it is a bug, not drama. The
cover module's warning lamp pulses at runtime instead (section 3).

### Where each one stands

The authoritative placement is `tools/asset-forge/src/worlds/layout.js`, which is
a transcription of the shipped Godot zones in
`game/scripts/worlds/neon_frontier/zones/`. The mapping is one-to-one:

| District | Zone script | Components placed |
| --- | --- | --- |
| Arena | `zones/arena.gd` | reactor ×1, cover ×4, wave-entry gate ×4 |
| Outpost | `zones/settlement.gd` | command ×1, lab ×1, depot ×1, sensor ×2, landing pad ×1 |
| Extraction | `zones/settlement.gd` | generator ×1, sensor ×1 |
| Docking gate | `zones/perimeter.gd` | boss gate ×1 |
| Perimeter | `zones/perimeter.gd` | turret ×6, spawn gate ×4, sensor ×2 |
| Crashed sector | `zones/wilds.gd` | transport ×1, drone ×1, dead turret ×1, depot ×1, crystal ×4, flora ×18, rock ×8 |

## 2. Terrain and dressing

| Layer | Node group | What it is |
| --- | --- | --- |
| Ground | `Terrain/Ground` | 320 × 300 m basalt plane, 2K tiled ×64 |
| Outer shelf | `Terrain/OuterShelf` | ring beyond the wall so the horizon is not a cut edge |
| Roads | `Terrain/Routes` | six road legs from `routes.gd`, cyan signal strip, amber lane edge |
| Arena deck | `Terrain/ArenaDeck` | 38 × 38 m deck, hazard ring, four corner lamps |
| Perimeter | `Terrain/Perimeter` | 2.6 m wall with emissive cap rail, split around the four gate openings, four corner pylons |
| Dressing | `Terrain/Dressing` | three district aprons, 14 cargo crates, 22 route bollards, four cable ducts |
| Extraction pipes | `Terrain/ExtractionPipes` | five 25 m pipe runs with emissive glow strips, from `settlement.gd` |
| Outer rocks | `Terrain/OuterRocks` | eight silhouette boulders outside the wall |

## 3. Runtime motion in Godot

`game/scripts/worlds/neon_frontier_motion.gd` is attached by
`neon_frontier_world.gd::_place_component()` to every animated component. It
holds one rule table keyed by `asset_kind`:

```gdscript
"defense_turret": [
    {"match": "TurretHousing", "mode": "sweep", "axis": "y", "amount": 0.85, "speed": 0.55},
    {"match": "TurretBarrel",  "mode": "bob",   "axis": "z", "amount": 0.05, "speed": 2.2},
    {"match": "TurretSensor",  "mode": "pulse", "amount": 0.14, "speed": 2.8},
],
```

Rules match node-name *prefixes*, never indices: Godot renames duplicate siblings
(`LandingPadBeaconLens`, `LandingPadBeaconLens2`, …), and an index-based rule
would silently animate the wrong beacon. Four modes — `spin`, `sweep`, `bob`,
`pulse` — are enough for every component in the world.

Adding a component needs **no** change to the motion code: give it an
`asset_kind`, add a row to `RULES`, done. The editor toggle
`@export var animate_components` on the world turns the whole system off, and the
node is inert in-editor (`Engine.is_editor_hint()`), so opening the scene stays
cheap.

## 4. Materials

Every surface is one of five constructors in
`tools/asset-forge/src/runtime/materials.js`, all of which attach the shared PBR
texture set:

| Constructor | Use | Roughness / metalness |
| --- | --- | --- |
| `metal(token)` | structural plate, frames, pipes | 0.55 / 0.55 |
| `paint(token)` | painted panels, ceramic, polymer | 0.72 / 0.16 |
| `glow(token)` | energy strips, lenses, membranes (+ emissive map) | 0.4 / 0.1 |
| `glass(token)` | visors, containment sleeves | 0.08 / 0.1, transparent |
| `hazard()` | chevron warning bands | 0.6 / 0.3 |

*Full palette tokens and their hex values:* `void #05080c`, `panel #0b131b`,
`panel2 #111c26`, `panel3 #16232e`, `line #27384a`, `lineHi #4e6a7e`,
`ink #edf5fb`, `accent #ffb020`, `ok #37e08c`, `info #54c8ff`, `danger #ff5a5a`,
`ability #b79cff`.
