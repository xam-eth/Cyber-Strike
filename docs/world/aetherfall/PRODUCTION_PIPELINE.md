# Aetherfall — Production Art Pipeline

**Status:** Production reset — asset-level brief and evidence ledger required before any Gate 03/04 asset can be accepted

This is the production sequence for Aetherfall. It replaces the incorrect practice of treating an extruded, generated, or multi-part mesh as a finished environment asset.

## Non-negotiable quality bar

A finished asset must read as a manufactured or geographic thing before the viewer sees its material name:

- a structure has a legible load path, interior/exterior voids, access, service zones, panel hierarchy, and scale cues;
- a traversal element has a deck system, supports, anchoring, rail/wire routing, drainage or ice accumulation, and a reason to exist;
- terrain has geological mass, eroded silhouette, strata, fracture, ledges, and structure-to-ground contact;
- a vehicle, if one is introduced for a real mission purpose, has a unique silhouette and all major functional systems (hull, canopy/sensor volume, engines, intake/exhaust, hardpoints, landing/contact logic). It must never be a rounded blob or a collection of primitive boxes;
- every visible surface has a deliberately authored material response, not just a colour/noise pass.

No mesh count, node naming convention, generated texture, or static test may be presented as proof that this bar has been reached. Godot camera review is the visual acceptance gate.

## Gate 01 — Reference lock

The following original visual studies are **production reference only**. They must not be copied as decals, baked directly onto a model, or used as a substitute for a 3D asset.

| Study | File | It locks | It does not authorize |
|---|---|---|---|
| Archive hero | `reference/01_archive_hero.png` | archive massing, deep facade bays, ice/structure contact, distant industrial hierarchy | copying a building identity or reducing the archive to a rectangular tower |
| Traversal close view | `reference/02_traversal_detail.png` | deck thickness, grating, channels, rails, cable routing, support depth, weathering scale | scattering random bolts or tiling one panel over the entire route |
| Canyon recovery view | `reference/03_canyon_recovery.png` | geographic mass, shelf/ledge composition, lower recovery path, industrial integration, atmospheric depth | flat displaced planes, pebble scatter, or a sky colour in place of atmosphere |

### Visual language locked for modelling

1. **Material hierarchy:** dark painted titanium/steel is the primary mass; cold exposed metal appears at worn edges; cyan is limited to energy/service guidance; frost is a physical accumulation layer rather than a blue colour overlay.
2. **Architecture:** robot occupation is expressed through nested thresholds, load-bearing buttresses, recessed bays, exposed maintenance routing, and layered skins. Smooth box silhouettes are prohibited.
3. **Terrain:** glacier faces must be broad, fractured, and vertically stratified. Natural shelves are traversal or structure anchors, not random rocks around a flat floor.
4. **Composition:** foreground route detail, midground operational structure, and a distant silhouette must be visible in every review vista. The archive is a destination landmark, not an isolated prop.
5. **Lighting target:** a dark cold zenith, lifted cyan horizon, directional cold key, restrained emissive bloom, and distance fog. Lighting reveals form; it must not hide weak geometry.

### Reference gate exit criteria

Before Base Mesh work begins for an asset family, its Blender scene must contain:

- an original orthographic silhouette sheet or equivalent front/side/back modelling guide;
- named functional volumes and a stated real world role;
- a scale comparison against the player/camera route;
- a list of high-poly features that will be baked later;
- a material-breakdown plan (painted steel, exposed metal, ice, rubber, glass/emissive as applicable).

## Gate 02 — Blockout

**Current state:** route connectivity, lower recovery area, deck footprint, bridge/catwalk intent, and archive destination are retained as gameplay blockout. They are not visual assets.

The existing layout is locked only for gameplay: connected paths, recovery space, objective placement, natural physical boundaries, and progression order. Existing visual modules are not accepted as final Base Mesh.

**Exit:** camera-only Godot review confirms silhouette, route width, vertical clearance, landmark placement, and lower-area recovery without claiming surface quality.

## Gate 03 — Base Mesh

Each family is rebuilt as a deliberately designed low-resolution form, not decorated blockout:

1. `terrain_chunk` and `cliff_face`: sculptable watertight geological masses with primary/secondary/tertiary silhouette.
2. `tower_foundation`, `tower_tier`, `tower_spire`, `energy_core`: an Archive assembly with service voids, buttresses, threshold, crown, and readable objective core.
3. `deck_*`, `bridge_*`, `walkway_*`, `railing`, `conduit`, `cable_bundle`: a coherent traversal construction system.
4. `machinery`, `cooling_vent`, `cover_*`, `access_gate`, `wall_section`: purposeful operational equipment and combat cover.
5. `background_silhouette`: a real distant industrial settlement silhouette, not repeated shed/tower placeholders.

**Exit:** clay render review from hero, route, lowland, and skyline cameras. No material polish may be used to compensate for a weak base silhouette.

## Gate 04 — High-poly detailing

For every approved base mesh, author real Blender high-poly geometry:

- boolean-cut panel recesses and openings;
- two-scale bevel strategy (manufactured edges versus large structural breaks);
- seams, weld boundaries, fasteners, latches, vents, hinges, conduit brackets, mechanical joints, and interior shadow cavities;
- erosion, split strata, chipped ice, compression cracks, ledge undercuts, snow traps, and anchor damage on terrain;
- hand-authored damage only where it tells a functional story.

High-poly geometry is kept in separate `HP_` collections from runtime meshes. It is not exported as the game mesh.

## Gate 05 — Retopology

Create `LP_` runtime meshes from approved high-poly forms:

- retain the approved silhouette at the actual gameplay camera distance;
- preserve hard edge flow, major recesses, and readable negative spaces;
- use LODs only after the primary low-poly reads correctly;
- keep collision meshes separate and simple; collision must not dictate the visible model.

## Gate 06 — UV unwrap

UVs follow physical parts and material breaks. Texel density is set per family and checked with a checker map:

- terrain/ice: broad but non-stretched terrain density;
- deck/bridge: repeatable manufactured plate density;
- hero Archive: unique UV space for landmark faces plus tiled trim/decals only where physically justified;
- props: enough unique space for wear, labels, and local damage.

No world-space projection or generic noise texture is accepted as the final unwrap.

## Gate 07 — Bake

Bake **from the actual high-poly source to its matching low-poly target**:

- tangent normal;
- ambient occlusion;
- curvature;
- thickness/position masks where needed;
- ID masks for paint, exposed metal, ice, rubber, glass, and emissive systems.

Bakes must be inspected on the low-poly in Blender before they enter Godot.

## Gate 08 — PBR texturing and shader

Author material sets from the baked data and physical reference:

- base colour, metallic, roughness, normal, AO, emissive, and masks;
- roughness carries the strongest visual storytelling: polished contact edges, dull paint, wet/frozen deposits, oxidised recesses, and matte rubber;
- decals and trim are applied as controlled detail, never as a substitute for high-poly form;
- ice uses depth, fracture, translucent edge behaviour, snow/frost accumulation, and rock inclusions.

Generated noise can only be a non-final mask input. It cannot be the final material identity.

## Gate 09 — Polish, lighting, and Godot review

Review with the camera only—no default character obscuring the result—from:

1. archive approach;
2. deck/cover combat view;
3. east bridge;
4. west catwalk;
5. lower recovery basin;
6. distant skyline/horizon.

The review checks form separation, material response, geographic scale, route readability, fog/horizon depth, and landmark hierarchy. A static parser/test pass is not visual approval.

## Gate 10 — Optimization and export

Only after Godot visual approval:

- create LODs and simplify invisible backfaces;
- pack final texture maps at the reviewed resolution;
- validate collision, import, draw cost, lighting, mobile compatibility, and memory;
- export GLB from the approved `LP_` scene and preserve the Blender source.

## Current acceptance status

| Area | Status |
|---|---|
| Reference language | **WORLD LANGUAGE LOCKED; ASSET BRIEFS INCOMPLETE** — three studies exist, but they do not replace per-asset reference/scale/function sign-off |
| Gameplay blockout/connectivity | **RETAINED** |
| Runtime asset inventory | **51 GLBs AUDITED; NONE PRODUCTION-ACCEPTED** — consult `INDUSTRY_PRODUCTION_STANDARD.md` and `validation/gltf_validation.json` |
| Production Base Mesh | **EXPLORATORY STUDY ONLY** — `BM_*` covers three concept families and is not a full asset-library Gate 03 delivery |
| High-poly detailing | **EXPLORATORY STUDY ONLY** — `HP_*` is bake-source research for three families, not an accepted Gate 04 delivery for 51 runtime assets |
| Retopo / authored UV / bake | **NOT STARTED AS A REVIEWED ASSET PIPELINE** |
| Final PBR texture authoring | **NOT STARTED AS A REVIEWED ASSET PIPELINE** |
| Godot visual approval / target-device profile | **UNVERIFIED** |
