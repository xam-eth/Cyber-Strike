# Neon Frontier — the world module

Everything that builds the playable world. `neon_frontier_world.gd` is the
composition root: it lays out terrain, districts, lighting and routes.
`neon_frontier_asset.gd` (one folder up) is the component dispatcher: it turns
an `asset_kind` into a built prop. This folder holds what both of them build
from.

| File | What it is |
| --- | --- |
| `geometry.gd` | The eight shapes every component is made of: box, box collider, cylinder, sphere, link cylinder, ring, reactor coils, bolts. Pure construction — take a parent, add a mesh with a material, hand it back. |
| `material_kit.gd` | How a surface behaves. The *palettes* stay in each builder's `_create_materials()`; palettes are content and differ, the factories were plumbing. |
| `components/props.gd` | Crystal clusters, alien flora, rock outcrops, spawn gates, cover modules — the components that get placed rather than built. |
| `scenes.gd` | The component scenes and world dimensions the zones share. They were consts at the top of the world builder, which is why a zone could not leave that file. |
| `zones/` | One file per group of districts: `arena.gd` (combat floor, hazard markings, spawn gates), `routes.gd` (the ground routes between districts), `settlement.gd` (outpost, extraction), `perimeter.gd` (boss platform, defenses), `wilds.gd` (destroyed sector, alien landscape). |
| `components/` | The rest of the components, one group per file, as they move out of `neon_frontier_asset.gd`. |

## Rules

1. **Shapes come from `NeonFrontierGeometry`.** Do not inline a `MeshInstance3D`
   in a component builder; if a shape is missing, add it to the kit so every
   component gets it.
2. **Surfaces come from `NeonFrontierMaterialKit`.** Take colours from the
   builder's own palette (`asset._materials`), which is where the art direction
   lives.
3. **A component builder is static and takes the asset node.** It may read the
   palette and the variant seed and nothing else. That is what keeps two people
   working on two components out of each other's way.
4. **No component reaches into another component.** Shared shapes go in
   `geometry.gd`, shared behaviour does not exist yet — if it does, it belongs
   there too.

## Adding a component

1. Write `static func build_<kind>(asset) -> void:` in the group file it belongs
   to (a new `components/<group>.gd` if it fits none).
2. Build it from `NeonFrontierGeometry` calls and the builder's palette.
3. Add the `asset_kind` to the `@export_enum` in `neon_frontier_asset.gd` and
   the dispatch branch in its `_ready()`.
4. Run `./scripts/dev_check.sh` and `./scripts/run_smoke_tests.sh` —
   `neon_frontier_world_smoke` builds the whole world.

The module map in [`docs/ARCHITECTURE.md`](../../../docs/ARCHITECTURE.md) is
generated from the tree; adding a file here changes it, and `dev_check` will
say so until the map is regenerated.
