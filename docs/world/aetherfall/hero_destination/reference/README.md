# Hero Destination — Gate 01 visual working references

These seven original concept studies are the visual portion of the Hero Destination **Reference** gate. They are organised one-per-asset so a future modelling review can discuss a specific silhouette, construction story, functional equipment, material allocation, and high-poly target rather than calling the entire destination “detailed.”

| Asset | Study | Review focus |
| --- | --- | --- |
| Sentinel Archive exterior | [`sentinel_archive_exterior_concept.png`](sentinel_archive_exterior_concept.png) | Open threshold, buttress/load path, separate crown and service wings |
| Archive Vestibule | [`archive_vestibule_concept.png`](archive_vestibule_concept.png) | Weather transition, pressure-frame depth, drains, service voids |
| Archive Computer | [`archive_computer_concept.png`](archive_computer_concept.png) | Operator plane, data path, service/cooling, stable grounded mass |
| Energy Core | [`energy_core_concept.png`](energy_core_concept.png) | Containment rather than an emissive orb; coolant, bus, guard and maintenance access |
| Tower Foundation | [`tower_foundation_concept.png`](tower_foundation_concept.png) | Load transfer into the terrain, service bays, approach and drainage |
| Tower Tier | [`tower_tier_concept.png`](tower_tier_concept.png) | Repeat-safe collars, a readable service sector, protected shell and stack logic |
| Tower Spire | [`tower_spire_concept.png`](tower_spire_concept.png) | Skyline read, supported receiver/crown, fins and service route |

## Reference-use boundary

These are **not** game assets, source textures, decals, bakes, normal maps, ORM maps, alpha masks, or a permission to trace/generated-convert geometry. They cannot establish visual approval, retopology quality, UV quality, bake projection, material performance, or engine correctness.

Use the studies only to make the current briefs more reviewable. The modelling team must build the Base Mesh from the approved functional-volume and orthographic requirements in the corresponding packet, with a scale proxy in the actual world. A unique content hash for every file is recorded in [`REFERENCE_MANIFEST.json`](REFERENCE_MANIFEST.json).

## Deliberate constraints for the next review

- Retain the **open** Archive threshold and clearance defined by the runtime collision design; the exterior study is not permission to seal it with facade detail.
- The generated studies contain illustrative small parts. Only parts that support a specified load, access, cooling, data, power, drainage, or service function may become geometry.
- The Tower Tier and Spire studies must not turn the reusable tower modules into dense one-off hero meshes. Their stack collars and service sectors need controlled module interfaces.
- No Base Mesh is accepted from these images alone. The outstanding player/camera scale decision and in-engine layout/collision review remain explicit blockers.
