# The world — documentation

One complete world: **NEON FRONTIER — Frontier Outpost**, 192 × 180 m, built
entirely from procedural code in this repository.

| Document | Read it for |
| --- | --- |
| [`CONCEPT.md`](CONCEPT.md) | the place, its five districts, the art-direction rules, what moves and why |
| [`ASSET_LIST.md`](ASSET_LIST.md) | all 16 component models, their heights, clips, sockets and 64 placed instances; terrain layers; the runtime motion table |
| [`PBR_AND_VERIFICATION.md`](PBR_AND_VERIFICATION.md) | the 2K/4K texture pipeline, the three verification gates, and what looking at the renders actually changed |
| [`REFERENCE_COMPARISON.md`](REFERENCE_COMPARISON.md) | reference photo vs forge render, asset by asset, with an honest verdict on every difference |

## Where the code lives

| Path | Role |
| --- | --- |
| `tools/asset-forge/src/world/*.js` | the 16 component models (pure three.js, one module each) |
| `tools/asset-forge/src/runtime/` | shared kit: `kit.js`, `materials.js`, `textures.js`, `rig.js`, `palette.js` |
| `tools/asset-forge/src/worlds/layout.js` | where every instance stands — mirrors the Godot zones |
| `tools/asset-forge/src/worlds/terrain.js` | ground, roads, deck, perimeter, dressing |
| `tools/asset-forge/src/worlds/assembly.js` | instancing, name/clip prefixing, district grouping |
| `tools/asset-forge/src/worlds/neon_frontier.js` | the composition root: `buildWorld()` + the lighting rig |
| `tools/asset-forge/world.html` | interactive viewer (orbit, district toggles, playback, 1K/2K/4K switch) |
| `tools/asset-forge/gate/` | the gate, render, sheet and staging scripts |
| `game/scenes/worlds/neon_frontier.tscn` · `game/scripts/worlds/` | the same world as a playable Godot scene |
| `game/scripts/worlds/neon_frontier_motion.gd` | data-driven runtime motion for placed components |

## Quick start

```bash
cd tools && npm ci
node tools/asset-forge/gate/run_gate.mjs                 # 20 checks × 16 assets
node tools/asset-forge/gate/world_shot.mjs --tex 2048    # 8 world renders + world.glb
```

```bash
python3 -m http.server 8080
# open http://localhost:8080/tools/asset-forge/world.html
```
