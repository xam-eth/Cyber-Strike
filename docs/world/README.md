# NEON FRONTIER — the world, built from real assets

This branch ships **one complete game world**: the Frontier Outpost at Cinder Yard.
Every visible surface in it — the ground, the reactors, the hangars, the gate, the
wrecks, the rocks — is a **real, licensed, pre-modelled GLB**. Nothing is extruded,
lathed, lofted or box-built by code, and no texture is generated.

```
game/assets/world/real/            97 files · 52.5 MB · provenance in real-manifest.json
  kenney/*.glb                     87 × CC0 Space Kit (Kenney)
  powerplant.glb                    1 × CC-BY-4.0 Cinder Yard Power Plant (Kammertonus)
  setpieces/*.glb                   8 × real structures cut out of that plant
  ground/tile_floor.glb             1 × CC-BY-4.0 photographed ground plate

tools/asset-forge/src/worlds/      the composition: placement, motion, lighting
tools/asset-forge/world.html       the review viewer (also the export path)
tools/asset-forge/build/world/     9 review photographs + world.glb
```

## The rule, and how it is enforced

`realModels.js` is the only module in the world pipeline that constructs a
`GLTFLoader`. It tags every mesh it returns with `userData.realSource = <file>`.
The capture gate (`gate/world_shot.mjs`) asks the live scene for any mesh without
that tag and **fails the run** before it takes a single picture. If someone adds a
`BoxGeometry` to the world, the world cannot be re-exported — that is the whole
enforcement story, and it is checked on every render, not by inspection.

| Stage | File | What it does |
|---|---|---|
| provenance | `real/fetch_real_assets.mjs` | downloads and hash-verifies every file, writes the ledger |
| slicing | `real/slice_setpieces.mjs` | cuts real structures out of `powerplant.glb` (copies nodes, materials, maps) |
| loading | `src/worlds/realModels.js` | loads + caches models, grades kit surfaces, tags meshes |
| roles | `src/worlds/roleSpecs.js` | what each of the 16 roles is made of, and what moves |
| assembly | `src/worlds/assemblyReal.js` | instancing, name prefixing, animation clips |
| terrain | `src/worlds/terrainReal.js` | 240-tile floor, routes, arena deck, perimeter, wilds |
| composition | `src/worlds/neon_frontier.js` | districts, landmarks, scatter, stats, lighting |
| layout | `src/worlds/layout.js` | coordinates, mirroring the shipped Godot zones |

## What the world contains

* **192 × 180 m** field at `centreZ = -10`, 16 role types across 64 placed
  instances plus wilds scatter.
* **Districts:** `arena` (reactor), `outpost` (command, lab, depot, two sensor
  towers, landing pad), `extraction` (generator bank, mast), `boss` (the ribbed
  docking gate), `perimeter` (six turrets, gates, sensors, a 3.4 m fence of real
  structure frames), `wilds` (crashed transport, drone wreck, crystals, flora,
  rocks) and the `landmark` — the Power Plant itself, 24 m tall, standing outside
  the east wall as the installation the outpost serves.
* **119 animation clips** — spinning dishes and rings, sweeping turrets, pulsing
  generators and crystals, a bobbing crane gantry. Motion is authored as clips on
  real meshes; the meshes are never deformed by code.
* **254,719 triangles** drawn across 64 instances; `world.glb` re-exports the same
  content with shared geometry as 530 meshes / 153,885 triangles, 84 embedded maps.

## Surfaces

Two honest sources share one light response:

* the Power Plant's **baked 1024 px PBR maps** (albedo, normal, roughness) — real
  photoscanned concrete, rust and paint;
* the photographed **ground plate at 1920 px**, tiled 12 m to the tile;
* the CC0 kit ships **untextured painted metal**. `realModels.gradeKit` grades its
  *existing* material colours onto the installation's steel-and-amber ramp in sRGB
  so a kit hangar and a scanned tank read as the same world. Geometry is untouched.

No `CanvasTexture`, no procedural normal map, no generated displacement anywhere in
the pipeline. `docs/world/PBR_AND_VERIFICATION.md` lists what is checked.

## Build, look, export

```bash
node tools/asset-forge/real/fetch_real_assets.mjs --write   # provenance ledger
node tools/asset-forge/real/fetch_real_assets.mjs --verify  # 97 files, hash-checked
node tools/asset-forge/real/slice_setpieces.mjs             # set pieces from the plant
node tools/asset-forge/gate/world_shot.mjs                  # 9 shots + world.glb + policy gate
node tools/asset-forge/gate/stage_world_into_game.mjs        # stage into Godot + manifest
```

Or open the viewer interactively — it is a static page, served from the repo root:

```bash
python3 -m http.server 8080     # then /tools/asset-forge/world.html
```

## Credits

| Library | Licence | Author |
|---|---|---|
| Kenney Space Kit (87 models) | CC0-1.0 | Kenney — <https://kenney.nl/assets/space-kit> |
| Cinder Yard Power Plant + set pieces | CC-BY-4.0 | Kammertonus — <https://twitter.com/Kammertonus> |
| Photographed ground plate | CC-BY-4.0 | Kammertonus — <https://twitter.com/Kammertonus> |

Redistribution of the CC-BY material requires the attribution above; it is also
carried inside `tools/asset-forge/real/real-manifest.json` and
`game/assets/forge/forge_manifest.json`.
