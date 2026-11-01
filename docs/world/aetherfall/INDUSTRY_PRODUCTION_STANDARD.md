# Aetherfall — Industry Production Standard and Asset Remediation Plan

**Status: RESET TO EVIDENCE-LED PRODUCTION PLANNING — no Aetherfall runtime GLB is accepted as production-polished.**

This document replaces any interpretation that a rapid script pass, mesh count, static test, or three clay images can establish production quality. A real environment-art delivery is an **asset-by-asset** process: authored source, silhouette review, high-to-low relationship, UV quality, bake inspection, PBR look development, target-engine review, and target-hardware profiling.

## 1. What was actually found

The repository currently contains **51 runtime GLBs** totaling **146,068,764 bytes** under `assets/world/aetherfall/`, backed by ten grouped Blender source files. This is materially larger than the earlier “20-plus assets” estimate:

| Source family | Runtime asset count | Source of record |
|---|---:|---|
| Reusable core kit | 27 | `source/aetherfall_kit.blend` |
| Connector ramp | 1 | `source/connector_ramp.blend` |
| Energy orbit | 1 | `source/energy_orbit.blend` |
| Ice-planet exterior | 4 | `source/aetherfall_ice_planet.blend` |
| Interactive props | 2 | `source/aetherfall_interactives.blend` |
| Landmark set | 4 | `source/aetherfall_landmarks.blend` |
| Phase-2 cover/traversal | 4 | `source/aetherfall_phase2_cover.blend` |
| Archive interior | 2 | `source/aetherfall_archive_interior.blend` |
| Connected expanse | 3 | `source/aetherfall_connected_expanse.blend` |
| Vertical infrastructure | 3 | `source/aetherfall_vertical_infrastructure.blend` |

The full asset-level ledger, source linkage, SHA-256 identity, static issue count, mesh statistics, and current art status is generated at `validation/gltf_validation.json`. It lists every one of the 51 files rather than treating a family mesh count as proof of quality.

## 2. Technical preflight result — not art approval

The official Khronos `gltf-validator` npm package (version `2.0.0-dev.3.10`) was run against all 51 GLBs. The reproducible runner is `tools/gltf-validation/validate_aetherfall.mjs`, with its dependency locked in `tools/gltf-validation/package-lock.json`.

| Result | Count | Interpretation |
|---|---:|---|
| Format errors | 0 | The GLBs are structurally parseable by this validator at the audited revision. This is necessary, not sufficient. |
| Warnings | 1,093 | **Release blocker:** normal-mapped primitives rely on generated tangent space (`MESH_PRIMITIVE_GENERATED_TANGENT_SPACE`). Tangents must be explicitly exported after the final UV/topology pass, or a documented Godot target-import exception must be visually tested per asset. |
| Informational messages | 30 | `UNUSED_OBJECT` findings exist in the VFX/animation-oriented files and require intentionality review. |
| NPOT image warnings | 21 | Present in the connected-expanse asset family. These need a device-specific texture/performance decision, not an automatic resize. |

Khronos specifies normal maps as tangent-space textures and notes that absent tangents cause a runtime to generate MikkTSpace tangents from geometry, normals, and UVs. The validator explicitly warns that this result may not be portable. Therefore, **zero format errors does not make the current assets shipped-quality**. See the Khronos glTF specification and Validator links in [References](#references).

## 3. Status of the recent Base-Mesh and High-Poly studies

`source/aetherfall_base_mesh.blend` and `source/aetherfall_high_poly.blend` are **three-family exploratory studies only** (Archive / traversal / recovery terrain). They are not a rework of all 51 runtime GLBs, have not been retopologized, UV-unwrapped, baked, textured, imported, or approved in Godot, and must not be described as completed Gate 03/04 production for Aetherfall.

They remain useful as a design hypothesis to be reviewed before an individual hero-asset brief is approved. They do **not** authorize Gate 05 for the library.

## 4. Definition of done — per individual asset

An asset may advance only when every applicable check below has a recorded result. “Not applicable” needs a reason (for example, a non-normal-mapped VFX card has a different material gate); it must not be silently skipped.

### A. Brief and reference lock

- Asset ID, gameplay/environment role, world location, expected camera distances, reuse count, collision need, and target material families are recorded.
- A scale reference is present in the review scene.
- Reference analysis names the observable construction or geological logic. A generic “sci-fi” label is not a brief.
- The owning source `.blend`, intended `HP_`, `LP_`, collision, and final export path are declared before modelling begins.

### B. Base Mesh review

- Silhouette, primary/secondary/tertiary forms, negative spaces, load paths, access/maintenance logic, and terrain contact are reviewed in clay from the actual planned camera distance.
- No material, fog, or bloom is allowed to hide a weak silhouette.
- Reusable modules must demonstrate their join conditions, pivots/origins, and non-obvious repetition handling.

### C. High-poly review

- High-poly detail is real geometry or sculpted surface information with an identified bake purpose: bevel hierarchy, panel recesses, seams, fasteners, vents, brackets, weld/edge damage, fracture/strata/undercut, and attachment stress as appropriate.
- `HP_` geometry remains separate from low-poly/runtime geometry and is named to establish its corresponding target. Repeated noise, a generic displacement, or arbitrary bolt scatter does not pass this gate.

### D. Retopology and UV review

- `LP_` topology retains the reviewed silhouette at the intended camera distance, has controlled hard edges, no accidental non-manifold/degenerate geometry, and a separately authored collision proxy where needed.
- UV0 is intentionally seam-marked at physical/material breaks, checked for stretch and overlap policy, packed to the assigned texel density, and reviewed with a checker map. Hero unique areas, tileable modular sections, trims, and decals have declared rationale.
- The target platform and shot list determine actual triangle, material, texture, and draw-call budgets. There is **no universal “industry” number** that can honestly be assumed before those targets are set.

### E. Baking and PBR review

- Each `HP_`/`LP_` correspondence has an explicit selected-to-active bake or controlled exploded bake, cage/ray-distance record, and a visual artifact check for projection errors, gradients, seams, and padding.
- Required outputs are determined by the asset brief, normally tangent normal, AO, curvature, ID/masks, and material-response data. Normal map orientation and colour space are checked in the target engine.
- PBR sets are authored from physical reference and baked masks: base color, metallic, roughness, normal, AO, emissive/masks as needed. Roughness must tell the material/wear story; a colour/noise overlay is not material completion.

### F. Export, engine, and performance acceptance

- Final export is only from the reviewed `LP_` source, with transforms/origin/axis, material slots, named animation/collision data, and explicit tangents checked.
- Run the Khronos validator with **zero errors and no untriaged warnings**. The current tangent-space warnings are not waived globally.
- Import the exact GLB into the Godot review scene; inspect normal direction, UV scale, textures, transparency, LOD/collision behavior, camera views, and lighting response. Save an in-engine capture.
- Profile the assembled scene on the declared target hardware/build. Record device, renderer, resolution, frame timing, draw calls, texture memory, and the accepted visual/performance trade-off.

## 5. Realistic work breakdown

The library will be processed in **small accepted batches**, never mass “polished” by a single procedural pass. A batch can share trim/material standards, but each asset still receives its own ledger entry and QA evidence.

| Order | Asset batch | Runtime assets requiring individual review | Gate starting point |
|---:|---|---|---|
| 0 | Pipeline preflight | all 51 | Freeze legacy GLBs; define target hardware, camera distances, material/trim strategy, naming, source ownership, and budget policy. Resolve/triage validator warnings. |
| 1 | Hero destination | `sentinel_archive`, `archive_vestibule`, `archive_computer`, `energy_core`, `tower_foundation`, `tower_tier`, `tower_spire` | New asset briefs and reference sheets; the current Archive study may be used only as a rejected/accepted concept comparison. |
| 2 | Primary traversal | `transit_spine`, `bridge_deck`, `bridge_support`, `walkway_deck`, `deck_6x6`, `deck_edge`, `connector_ramp`, `railing`, `beam`, `pillar`, `cable_bundle`, `conduit` | Build one production modular construction language, then verify every junction and repeat condition. |
| 3 | Macro ice and recovery | `glacier_shelf`, `frozen_spire`, `cliff_face`, `terrain_chunk`, `rock_boulder`, `glacier_berm`, `ice_terrace`, `expanse_shelf`, `lowland_field` | Reference-led geological massing, then sculpt/retopo/bake at route and overview distances. |
| 4 | Operational/cover systems | `access_gate`, `cooling_vent`, `machinery`, `wall_section`, `cover_barrier`, `cover_machine`, `damaged_slab`, `debris_cluster`, `cryo_bulkhead`, `salvage_pod`, `cryo_pylon`, `objective_device`, `tech_cache` | Function-first hard-surface briefs, including interaction/collision where relevant. |
| 5 | Settlement and vertical set dressing | `field_outpost`, `relay_annex`, `service_hangar`, `cargo_service_cluster`, `refinery_stack`, `overhead_gantry`, `raised_ops_deck`, `background_silhouette` | Distinct silhouettes and readable function before trim/prop dressing. |
| 6 | Atmosphere/VFX exceptions | `cloud_puff`, `energy_orbit` | Separate VFX material, animation, overdraw, and target-device review; they do not share the hard-surface definition of done unchanged. |

Asset batches 1–6 may overlap only after their preceding review evidence is accepted. Gate 05 therefore starts **per accepted asset**, not globally after a scripted scene file exists.

## 6. Mandatory ledger fields for each asset

The JSON ledger is the technical baseline. Before production rework begins, it must be expanded with the following human-reviewed fields per asset:

`asset_id`, `source_owner`, `brief_status`, `reference_status`, `base_mesh_status`, `high_poly_status`, `retopo_status`, `uv_status`, `bake_status`, `pbr_status`, `godot_review_status`, `target_device_profile_status`, `validator_exception`, `review_images`, `approved_by`, and `revision`.

Until those fields are filled with evidence, the only truthful art status is **legacy runtime asset — unaccepted for production polish**.

## 7. Reproducible validation

```sh
npm ci --prefix tools/gltf-validation
npm run --prefix tools/gltf-validation validate:aetherfall
```

This updates `docs/world/aetherfall/validation/gltf_validation.json`. The command intentionally returns non-zero only for validator **errors** so that the complete warning ledger can be generated. A release/approval gate must separately fail while warnings remain untriaged.

## References

- Khronos glTF 2.0 specification: geometry, material and tangent-space normal-map requirements: <https://github.com/KhronosGroup/glTF/blob/main/specification/2.0/Specification.adoc>
- Khronos glTF Validator: scope and command-line/validation behavior: <https://github.com/KhronosGroup/glTF-Validator>
- Khronos `CarConcept` sample-asset notes: consistent, low-distortion UVs and texture compression as an example of asset-specific production decisions: <https://github.com/KhronosGroup/glTF-Sample-Assets/tree/main/Models/CarConcept>
- Khronos `CommercialRefrigerator` notes: UV/material restructuring, baking, and explicitly exported tangents to remove warnings: <https://github.com/KhronosGroup/glTF-Sample-Assets/blob/main/Models/CommercialRefrigerator/README.md>
- High-to-low baking reference used for the selected-to-active/cage requirement: <https://github.com/PoBruno/mcp-blender-agent/blob/main/.claude/docs/research/pipelines/B4-uv-and-baking.md>
