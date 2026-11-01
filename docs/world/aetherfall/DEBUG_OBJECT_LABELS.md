# Aetherfall Debug Object Labels

## Purpose

Aetherfall now assigns an opt-in `Label3D` to every assembled **runtime placement root**. This is a placement-review and inspection tool, not gameplay UI. It makes it possible to identify the exact JSON/kit instance under review without permanently covering the world with text.

## Use

- Start the Aetherfall scene normally or enter **F1** review-camera mode.
- Press **F2** to toggle labels **on/off**.
- Labels start **off** by default and are not intended for a player-facing build.
- The active QA camera help strip also displays the F2 control.

Each label has the form:

```text
[CATEGORY] object_id
```

The same `object_id` and `category` are also saved as metadata on the object root:

- `aetherfall_object_id`
- `aetherfall_object_category`

This preserves an inspectable identity in the Godot scene tree even when labels are hidden.

## Scope

The label generator registers **327** runtime assembly roots when every current Aetherfall source file loads:

| Category | Count | Source |
| --- | ---: | --- |
| `kit` | 251 | `layout.json` core placements |
| `expanse` | 23 | connected-expanse lowland fields and rim shelves |
| `route` | 18 | connected-expanse loop and recovery transit spines |
| `archive` | 1 | Archive Vestibule |
| `interactive` | 3 | tech cache, horizon relay, Archive Computer |
| `phase2` | 8 | `phase2_cover.json` |
| `ice` | 9 | `ice_planet_phase1.json` |
| `vertical` | 4 | `verticality.json` |
| `landmark` | 6 | `landmarks.json` |
| `connector` | 3 | legacy connector ramps |
| `fx` | 1 | energy orbit visual |
| **Total** | **327** | |

A label represents one placed/assembled object, **not every GLB child mesh, bolt, collider, light, or route marker**. Labeling those implementation details would produce thousands of labels and would not help world-layout review.

## Rendering behavior

- Labels billboard toward the active camera, have a dark outline, and are lifted above the highest imported mesh bound where one is available.
- Color encodes category: cyan (`kit`/ice/expanse), amber (landmark/vertical), lime (Phase 2), magenta (Archive/interactives), and yellow (connectors/routes).
- The feature adds no collision, navigation, material, mesh, gameplay state, or production-art claim.
- Debug labels are a runtime visual aid only. Verify them in Godot after synchronization; static source tests cannot prove final label placement or mobile performance.
