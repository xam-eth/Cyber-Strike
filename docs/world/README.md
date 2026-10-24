# NEON FRONTIER — three mission worlds, built from real assets

This branch ships **three complete playable worlds**, one per mission. Every
visible surface in all three is a **real, licensed, pre-modelled GLB**: triangle
meshes with vertices and faces, produced by their authors' DCC pipelines, loaded
and placed by code that creates no geometry of its own.

| World | Mission | Mood | Signature components |
| --- | --- | --- | --- |
| **Frostline Relay** | defence | polar dusk — white ice, cyan light, visible air | comms array, relay masts, cryo condensers, ice spires, frozen hauler |
| **Verdant Bloom** | recovery | humid overgrowth — moss, spore light, green sun | bio domes, giant flora, spore vents, overgrown arches, crashed lab, real pine groves |
| **Emberfall Foundry** | extraction | volcanic industry — basalt, molten seams, ash | smelter towers, ore silos, magma drill rig, gantry cranes, slag pools, the Cinder Yard plant |

```
game/assets/world/real/        130 files · 52.8 MB · provenance: real-manifest.json
  kenney/*.glb                 87 × CC0 Space Kit hardware
  nature/*.glb                 33 × CC0 Nature Kit (trees, bushes, moss, grass, rocks)
  powerplant.glb                1 × CC-BY-4.0 Cinder Yard plant (Kammertonus)
  setpieces/*.glb               8 × real structures cut out of that plant
  ground/tile_floor.glb         1 × CC-BY-4.0 photographed ground plate

tools/asset-forge/src/worlds/
  themes.js        art direction per world (sky, fog, four lights, grades)
  roles.js         30 roles, each an assembly of real parts + motion rules
  frostline.js     world 1 — data: theme, layout, terrain, landmark
  verdant.js       world 2 — data
  emberfall.js     world 3 — data
  terrainKit.js    ground/configurable terrain layers, all real files
  compose.js       the single builder all three worlds share
  index.js         the register: id → world, buildWorld(id)

game/assets/forge/worlds/       staged GLBs Godot imports
  frostline.glb   171.6 × 19.5 × 175.0 m · 113,086 tris · 61 clips · 5.8 MB
  verdant.glb     180.3 × 16.5 × 168.4 m · 128,182 tris · 156 clips · 3.0 MB
  emberfall.glb   320.0 × 24.6 × 196.4 m · 227,811 tris · 31 clips · 20.5 MB
```

## The rule, and how it is enforced

`realModels.js` is the only module that constructs a `GLTFLoader`. It tags every
mesh it returns with `userData.realSource = <file>`. The capture gate asks the
live scene for any mesh without that tag and **fails the run** before it writes a
single photograph; the Godot smoke test asserts the same thing in-engine.

| Stage | File | What it does |
| --- | --- | --- |
| provenance | `real/fetch_real_assets.mjs` | downloads and hash-verifies every file, writes the ledger |
| slicing | `real/slice_setpieces.mjs` | cuts real structures out of `powerplant.glb` (copies nodes, materials, maps) |
| loading | `src/worlds/realModels.js` | loads + caches models, grades surfaces per library, tags meshes |
| roles | `src/worlds/roles.js` | what each role is made of, and what moves |
| assembly | `src/worlds/assemblyReal.js` | instancing, name prefixing, animation clips |
| terrain | `src/worlds/terrainKit.js` | floor, routes, decks, fences, dressing — every layer a real file |
| composition | `src/worlds/compose.js` | districts, landmarks, scatter, stats, atmosphere |

## Why three worlds share one builder

The three worlds differ in **art direction and content, not in machinery**: each
is a data module (theme + layout + terrain config + landmarks) handed to the same
`composeWorld()`. That is what keeps a 30-role library maintainable: adding a prop
to Emberfall cannot change how Frostline is assembled, and a fix to placement
lands in all three at once.

Surfaces are graded per library, because they are not the same kind of asset:

* **hardware** (Space Kit) — untextured painted metal, re-mapped onto the world's
  steel-and-accent ramp in sRGB;
* **organics** (Nature Kit) — authored foliage colours, only lerped toward the
  world's plant tone, never hue-replaced;
* **floor** (scanned plate, grass tiles) — exposed per theme, because a polar
  plate and a volcanic one need different values;
* **scanned set pieces and the plant** — left exactly as the author authored them.

## Build, look, export

```bash
node tools/asset-forge/real/fetch_real_assets.mjs --verify   # 130 files, hash-checked
node tools/asset-forge/gate/world_shot.mjs                   # 15 shots + 3 GLBs + policy gate
node tools/asset-forge/gate/world_shot.mjs --world verdant --shot overview
node tools/asset-forge/gate/stage_worlds_into_game.mjs        # stage into Godot + manifest
```

Or browse them interactively (each world is one page load):

```bash
python3 -m http.server 8080
# /tools/asset-forge/world.html?world=frostline
# /tools/asset-forge/world.html?world=verdant
# /tools/asset-forge/world.html?world=emberfall
```

## Credits

| Library | Licence | Author |
| --- | --- | --- |
| Kenney Space Kit (87 models) | CC0-1.0 | Kenney — <https://kenney.nl/assets/space-kit> |
| Kenney Nature Kit (33 models) | CC0-1.0 | Kenney — <https://kenney.nl/assets/nature-kit> |
| Cinder Yard Power Plant, set pieces, ground plate | CC-BY-4.0 | Kammertonus — <https://twitter.com/Kammertonus> |

Redistribution of the CC-BY material requires that attribution; it is also carried
inside `tools/asset-forge/real/real-manifest.json` and
`game/assets/forge/forge_manifest.json`.
