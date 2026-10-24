# Asset list — the real files the world is made of

Every visible asset here is a licensed, pre-modelled GLB. None of them is produced
by code in this repository. The complete inventory, with a SHA-256 per file, is
`tools/asset-forge/real/real-manifest.json` (verified by
`node tools/asset-forge/real/fetch_real_assets.mjs --verify`).

## 1. Libraries

| Library | Files | Size | Licence | Author | Role in the world |
| --- | --- | --- | --- | --- | --- |
| Kenney **Space Kit** | 87 | 5.4 MB | CC0-1.0 | Kenney — <https://kenney.nl/assets/space-kit> | the modular hardware: hulls, gates, dishes, turrets, pipes, rocks, wrecks |
| **Cinder Yard Power Plant** | 1 | 40.5 MB | CC-BY-4.0 | Kammertonus — <https://twitter.com/Kammertonus> | the landmark, and the source of the set pieces |
| **Power Plant set pieces** | 8 | 8.5 MB | CC-BY-4.0 | Kammertonus | cooling tower, tank ring, tank pad, arch ribs, column, drone, crane carriage |
| Photographed **ground plate** | 1 | 0.7 MB | CC-BY-4.0 | Kammertonus | the 1920 px stone-tile floor |
| **Total** | **97** | **52.5 MB** | | | 47 distinct files are referenced by the current world build |

The Power Plant is a 285-mesh industrial scene with 79 PBR materials and 65 baked
1024 px maps. It is used twice over: whole, as the off-field landmark, and sliced
into the structures the playfield needs. `real/slice_setpieces.mjs` copies the
author's nodes, materials and maps into smaller GLBs — it models nothing.

## 2. The 16 roles

Each role is a small assembly of real files, placed by `src/worlds/layout.js` and
described in `src/worlds/roleSpecs.js`. "Real parts" counts distinct source GLBs;
motion counts authored clips on those meshes.

| Role | Real parts it is built from | Motion | Instances |
| --- | --- | --- | --- |
| Reactor Core | `cooling_tower`, `tank_ring` ×2, `tank_pad`, `rock-crystalslargea`, `satellitedish-large` | 4 clips (two counter-rotating rings, core pulse, crown spin) | 1 |
| Command Centre | `hangar-largea`, `column`, `satellitedish-large`, `corridor-detailed` | dish spin | 1 |
| Research Laboratory | `hangar-roundb`, `machine-wirelesscable`, `pipe-ringhigh`, `tank_ring`, `satellitedish-detailed` | vessel spin, dome turn, dish spin | 1 |
| Equipment Depot | `hangar-smallb`, `barrels`, `barrels-rail`, `platform-low` | crate bob | 2 |
| Generator Bank | `tank_pad`, `cooling_tower` ×2, `tank_ring`, `pipe-ringhigh` ×2, `pipe-straight` | 4 clips (generator pulse, stack spin) | 1 |
| Landing Pad | `tank_pad`, `platform-corner` ×4, `chimney` ×4, `satellitedish`, `crane` | gantry bob, beacon spin, four post pulses | 1 |
| Boss Gate | `tank_pad`, `tall_arch`, `column` ×2, `satellitedish-large`, `gate-simple` | gate pulse, lock frame pulse, sentry spin | 1 |
| Defence Turret | `platform-low`, `pipe-supportlow`, `turret-double`, `satellitedish` | turret sweep, sensor spin | 7 |
| Sensor Tower | `platform-low`, `column`, `pipe-ring` ×2, `satellitedish-detailed`, `satellitedish-large` | dish spin, dish sweep, ring spins | 5 |
| Wave / Enemy Gate | `platform-low`, `gate-simple`, `structure` ×2, `satellitedish` | beacon spin, gate pulse | 8 |
| Wrecked Transport | `drone`, `craft-cargob`, `meteor-half`, `rocks-smalla`, `column` | hull sway | 1 |
| Alien Drone Wreck | `crater`, `drone`, `bones`, `meteor-detailed` | chassis sway | 1 |
| Crystal Cluster | `rock-crystalslargea`, `rock-crystalslargeb`, `rock-crystals`, `rocks-smallb` | two pulses | 4 |
| Alien Flora | `bones`, `rocks-smallb`, `rock-crystals` | sway, bloom pulse | 18 |
| Rock Cluster | `rock-largea`, `rock-largeb`, `rocks-smalla` | — | 8 |
| Cover Module | `tank_ring`, `barrels-rail`, `barrel` ×2 | — | 4 |

## 3. Landmark and ground

| Asset | File | Placement | Measured |
| --- | --- | --- | --- |
| Cinder Yard Power Station | `powerplant.glb` | `[152, 0, -14]`, yaw 96° | 24.0 m tall, standing outside the east wall |
| Ground plate | `ground/tile_floor.glb` | 12 m grid, 16 × 15 = 240 tiles | 1920 px albedo + normal + roughness |
| Arena deck | `platform-center` | 6.4 m plates, 38 × 38 m | — |
| Routes | `terrain-roadstraight` | 5 legs from the reactor | — |
| Perimeter | `structure` + `supports-high` | 3.4 m fence, three gate gaps | 3.4 m |
| Wilds dressing | `craterlarge`, `rocks-smallb` | 22 pieces around the crash site | — |

## 4. What is *not* in here, on purpose

* No procedurally generated geometry — the gate rejects any mesh without
  `userData.realSource`.
* No generated textures — no `CanvasTexture`, no code-drawn noise, no faked
  normal maps. The kit's flat colours are graded, not re-painted.
* No hero, weapon, enemy or VFX assets: this branch is world-only.
