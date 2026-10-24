# Asset list — 130 real files, three worlds

Every visible asset in the game is a licensed, pre-modelled GLB. Nothing is
extruded, lathed, lofted or box-built by code, and no texture is generated. The
full inventory with a SHA-256 per file is
`tools/asset-forge/real/real-manifest.json`
(`node tools/asset-forge/real/fetch_real_assets.mjs --verify`).

## 1. Libraries

| Library | Files | Licence | Author | Used for |
| --- | --- | --- | --- | --- |
| Kenney **Space Kit** | 87 | CC0-1.0 | Kenney | modular hardware: hulls, gates, dishes, turrets, pipes, platforms |
| Kenney **Nature Kit** | 33 | CC0-1.0 | Kenney | real trees, bushes, grass, moss, flowers, mushrooms, logs, boulders, grass/path floor tiles |
| **Cinder Yard Power Plant** | 1 | CC-BY-4.0 | Kammertonus | the Emberfall landmark (285 meshes, 65 baked 1024² maps) |
| **Power Plant set pieces** | 8 | CC-BY-4.0 | Kammertonus | tank ring, tank pad, cooling tower, arch ribs, column, crane, drone |
| **Scanned ground plate** | 1 | CC-BY-4.0 | Kammertonus | 1920² stone-tile floor (Frostline, Emberfall) |

The set pieces are **cut**, not authored: `real/slice_setpieces.mjs` copies the
plant's own nodes, materials and maps into smaller GLBs and models nothing.

## 2. Roles (30)

A role is an assembly of real parts placed by a world's layout. `roles.js`
declares the parts, their metric size, and their motion; `WORLD_ROLES` says which
world may use which.

| Role | Parts (real files) | Motion | Worlds |
| --- | --- | --- | --- |
| `comms_array` | `tank_pad`, `column`, `satellitedish-large`, `satellitedish-detailed`, `pipe-ring` | dish spin, dish sweep, ring spin | Frostline |
| `relay_mast` | `supports-low`, `pipe-supporthigh`, `pipe-ringhigh` ×2, `satellitedish` | whip spin, band bob | Frostline |
| `cryo_condenser` | `tank_pad`, `cooling_tower`, `tank_ring`, `pipe-straight` | collar spin, vent bob | Frostline |
| `ice_crystal` | `rock-crystalslargea/b`, `rock-crystals`, `rocks-smallb` | two pulses | Frostline |
| `frozen_hauler` | `tank_pad`, `craft-cargob`, `drone`, `rock-crystals` | tender sway | Frostline |
| `sensor_tower` | `platform-low`, `column`, `pipe-ring` ×2, two dishes | dish spin/sweep, ring spins | Frostline, Verdant |
| `bio_dome` | `tank_pad`, `hangar-roundb`, `tank_ring`, `bones`, `pipe-ring` | crown spin, overgrowth sway, vent spin | Verdant |
| `giant_flora` | `bones`, `rock-crystalslargea`, `rock-crystals`, `rocks-smallb` | trunk sway, canopy pulse, shoot sway | Verdant |
| `spore_vent` | `crater`, `pipe-ringhigh`, `rock-crystals`, `bones` | spore pulse, frond sway | Verdant |
| `overgrown_arch` | `tank_pad`, `tall_arch`, `bones` ×2, `rock-crystalslargeb` | vine sway, bloom pulse | Verdant |
| `crashed_lab` | `craterlarge`, `hangar-smallb`, `drone`, `bones` | scout sweep | Verdant |
| `grove_tree` | `nk_tree-pinerounda`, 2 bushes, `nk_mushroom-tangroup` | canopy sway | Verdant |
| `undergrowth` | `nk_plant-bushdetailed`, `nk_grass-large`, `nk_flower-purplea`, `nk_hanging-moss` | bush sway, bloom pulse | Verdant |
| `moss_rock` | `nk_rock-tallb`, `nk_plant-bushsmall`, `nk_hanging-moss` | drape sway | Verdant |
| `mushroom_ring` | `nk_mushroom-redtall`, `nk_mushroom-red` ×2, `nk_mushroom-tangroup` | stalk pulse | Verdant |
| `fallen_log` | `nk_log-large`, `nk_stump-oldtall`, `nk_plant-bushsmall` | — | Verdant |
| `smelter_tower` | `tank_pad`, `cooling_tower`, `tank_ring`, `column`, `pipe-straight` | glow band spin, flue bob | Emberfall |
| `ore_silo` | `tank_pad`, `tank_ring` ×2, `column` | drum-top spin | Emberfall |
| `drill_rig` | `tank_pad`, `columns`, `pipe-straight`, `crane` | crown spin, arm sweep | Emberfall |
| `crane_gantry` | `column` ×3, `crane` | beam bob | Emberfall |
| `slag_pool` | `craterlarge`, `platform-small`, `rocks-smallb` | melt pulse | Emberfall |
| `ash_statue` | `columns`, `meteor-detailed` | — | Emberfall |
| `defense_turret` | `platform-low`, `pipe-supportlow`, `turret-double`, `satellitedish` | turret sweep, sensor spin | all three |
| `cover_module` | `tank_ring`, `barrels-rail`, `barrel` | — | all three |
| `enemy_spawn_gate` | `platform-low`, `gate-simple`, `structure` ×2, `satellitedish` | beacon spin, gate pulse | Frostline, Emberfall |
| `crystal_cluster` | `rock-crystalslargea/b`, `rock-crystals`, `rocks-smallb` | two pulses | Verdant |
| `alien_flora` | `bones`, `rocks-smallb`, `rock-crystals` | sway, bloom pulse | Verdant |
| `rock_cluster` | `rock-largea/b`, `rocks-smalla` | — | Frostline, Verdant, Emberfall |
| `wrecked_transport` | `drone`, `craft-cargob`, `meteor-half`, `rocks-smalla`, `column` | hull sway | Frostline, Emberfall |

## 3. What each world contains

| | Frostline Relay | Verdant Bloom | Emberfall Foundry |
| --- | --- | --- | --- |
| Mission | defence | recovery | extraction |
| Field | 168 × 156 m | 176 × 164 m | 200 × 176 m |
| Floor | scanned stone plate | real grass tiles + dirt paths | scanned stone plate |
| Roles / instances | 10 / 36 | 12 / 92 | 10 / 31 |
| Animation clips | 61 | 156 | 31 |
| Landmark | polar arch gate | fallen scout drone | Cinder Yard power station |
| Real GLBs referenced | 35 | 44 | 29 |

## 4. What is deliberately not here

* No image-to-3D output in this build: the sandbox this branch was produced in has
  no GPU and no access to model weights (Hugging Face / PyTorch hubs are blocked),
  so every asset is a **pre-authored** licensed model instead of a hallucinated
  one. See `docs/world/PBR_AND_VERIFICATION.md` §6 for the pipeline that is ready
  to receive generative assets.
* No procedural geometry, no generated textures, no hero/weapon/enemy assets —
  this branch is world scope.
