# Aetherfall Layout Rebalance Review

**Status:** coordinate cleanup applied to the runtime assembly JSON. This is a conservative placement review, **not** a Godot visual, navigation, collision, or performance approval.

## Scope and method

The reproducible command is:

```sh
python3 tools/qa/audit_aetherfall_layout.py
```

It resolves **305** assembled visual objects directly from the runtime placement sources:

| Source family | Objects |
| --- | ---: |
| `layout.json` core kit | 251 |
| vertical infrastructure | 4 |
| landmarks | 6 |
| ice planet / Archive exterior | 9 |
| Phase 2 cover | 8 |
| Archive interior and computer | 2 |
| Stellar Horizon interactives | 2 |
| connected expanse lowlands and shelves | 23 |
| **Total** | **305** |

The tool reads GLB scene transforms and `POSITION` accessor extrema, rotates each local box by its authored yaw, and calculates a conservative world-space axis-aligned box. It protects the high-risk pairs that were previously interpenetrating: Archive vs. nearby landmark/vertical pieces, perimeter wall vs. outer glacier, east refinery vs. hangar, and raised deck vs. west terrace.

## Rebalanced sectors

The previous composition placed several full-size landmarks, cover pieces, and glacier masses through the Archive approach and main deck. The adjustment gives each sector one readable role.

| Sector | Placement result |
| --- | --- |
| Archive approach / north-center | Sentinel Archive remains at the existing central-route endpoint. Its two cryo pylons frame the approach; the adjacent berm now sits fully west of its exterior envelope. |
| West industrial flank | West refinery moves to `(-27, -11)`, archive berm to `(-16, -14)`, raised operations deck to `(-16, -4)`, and ice terrace to `(-27, -1)`. These read as a stepped flank rather than a single stack through the Archive. |
| East industrial flank | East refinery moves to `(30, -10)`, with a clear horizontal gap from the Archive and a separate south-east hangar. |
| South-east relay / arrival sector | The relay annex is at `(19, 13)`, relay cargo at `(14, 14)`, hangar at `(30, 12)`, and hangar cargo at `(23, 7)`. This separates the relay objective area from the Archive door and refinery silhouette. |
| Central basin | Salvage pod moves to `(2, 9)`, bulkhead to `(18, 4)`, and east terrace to `(10, 10)`, leaving the central/Archive sightline legible. |
| Perimeter ice | Glacier walls move outside the deck basin at `x=-52` and `x=52`; outer glaciers move farther out at `x=-86` and `x=86`; tall spires are behind the north frame at `x=±65, z=-55`. The wall and outer-glacier AABBs now have a gap rather than a deep overlap. |

Coordinates above are `(x, z)` in the runtime’s Y-up metre space. The authoritative full transforms remain in `assets/world/aetherfall/*.json`.

## Intentional integrations retained

These remaining conservative-box overlaps are deliberate assembly relationships, not silent exceptions to the cleanup:

1. **Sentinel Archive exterior / vestibule / Archive Computer:** the vestibule and computer are contained by the exterior destination; the exterior’s collision-box design leaves its threshold accessible.
2. **Primary tech cache / landing-ridge berm:** cache is positioned beside the arrival cover as a visible early pickup.
3. **Horizon relay / east ice terrace:** the objective device is intentionally set on the raised central-east shelf.
4. **Core deck/terrain with structures:** the core kit provides the ground and attachment surface for buildings, gantry supports, and cover. AABB penetration into a broad ground box is not a visual-intersection verdict.
5. **Connected-expanse terrain sheets:** shelves and lowland fields are continuous terrain layers at different heights; their broad bounds are expected to meet or cover supporting terrain.

No formerly clashing *major independent* perimeter, landmark, cover, or vertical setpiece is listed as an allowed clearance-pair overlap.

## Regression gate

The audit currently verifies the following pairs have less than 1 m² plan overlap or less than 0.3 m vertical overlap:

- Archive exterior vs. both refineries, relay annex, hangar, raised deck, and Archive-west berm
- west/east glacier walls vs. their matching outer glacier and nearest refinery
- east refinery vs. east hangar
- west raised deck vs. west ice terrace
- relay annex vs. hangar

A failure is a regression signal, not a substitute for visual review.

## Required next QA

- Load the checked-in revision in Godot and complete a player-height and overhead visual pass. The local environment did not provide a Godot executable, so this repository-side work cannot claim an engine parse/run or visual sign-off.
- Verify the amended collision boxes, Archive doorway, central spine, east bridge, west catwalk, lower canyon, and both spawn spaces in-engine.
- Review composition from playable cameras before deciding that the current locations are final. The AABB method is intentionally conservative and cannot judge silhouette, occlusion, or terrain contour.
- Keep Gate 01 art work paused until that engine review accepts this cleanup, per the ordered production workflow.
