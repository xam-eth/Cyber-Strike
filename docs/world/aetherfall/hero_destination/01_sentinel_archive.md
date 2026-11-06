# Gate 01 draft — Sentinel Archive exterior

**Asset ID:** `ice_planet__sentinel_archive`
**Legacy source/export:** `source/aetherfall_ice_planet.blend` → `assets/world/aetherfall/ice_planet/sentinel_archive.glb`
**Legacy measured envelope:** 28.60 m X × 24.45 m Y × 21.30 m Z. This is a baseline measurement only, not an approved production dimension.
**Status:** draft brief; Base Mesh is **not authorized**.
**Visual working reference:** [`reference/sentinel_archive_exterior_concept.png`](reference/sentinel_archive_exterior_concept.png) — original design study for silhouette/construction discussion only; it is not a texture, bake, geometry source, or Gate 01 approval.

## Role and composition

The Archive is the destination landmark at the end of the central route. Its south-facing threshold stays physically open and readable from the approach; its rear locks into the tower/foundation hierarchy without turning the open-sky basin into a sealed box. It must read first as a robot-built archive with access, maintenance paths, load transfer, and a protected core—not as a fantasy chapel, a smooth cone, or a stack of anonymous panels.

## Orthographic modelling guide

| Projection | Required silhouette and negative space |
|---|---|
| **South/front** | A broad, low arrival plinth carries two unequal structural gate pylons. The threshold is deeply recessed and visibly open; an offset lintel, inner pressure frame, and service-jamb recesses create three depth planes. Tiered wing masses step back from the opening and never hide it. |
| **East/west side** | The plinth transitions into sloped load-bearing buttresses, with a recessed maintenance gallery between the exterior shell and inner archive mass. One side has a heavier service trunk/coolant path; the other carries a receiver or access route. The crown is a separate, tapered command/receiver volume rather than the end of a cone. |
| **Top** | A roughly bilateral arrival axis is deliberately broken by service routing and receiver placement. The crown has radial equipment sockets and a bridge/halo relationship; wing roofs show drainage/snow-trap zones and distinct maintenance zones. |

## Functional volumes that must be visible in Base Mesh

| Volume | Purpose | Non-negotiable read |
|---|---|---|
| Arrival plinth | Receives the central route and distributes approach traffic | Broad threshold apron with actual elevation/edge logic, not a flat pad |
| Outer pylons and buttresses | Carry facade/crown load into the base | Continuous load path, widening toward contact points |
| Nested threshold | Security, weather buffer, and exterior-to-interior transition | Open negative space through at least the first frame |
| Central archive shell | Protected data/archive mass | Offset layered skins, not one uninterrupted tower surface |
| Service wings | Cooling, cable routes, access, and repair | Exterior access panels/vents have a route and destination |
| Crown/receiver | Archive sensing/command and skyline identity | Separate equipment hierarchy anchored to the central shell |
| Objective-core reserve | Keeps final objective volume meaningful | A protected cavity/cage, never a painted glowing door |

## Scale and camera checks

- Place the approved player/camera proxy on the real south approach before review; the current camera-only project provides no approved character height.
- Review from the archive approach, east bridge, west catwalk, lower recovery basin, and distant skyline. The threshold, buttress spacing, and crown must remain legible at the distances where the actual scene sees them.
- Verify the open threshold against `ice_planet_phase1.json` collision intent; visual redesign cannot seal the playable entrance.

## High-poly plan after Base Mesh approval

Model—not texture—these features: two-scale bevel hierarchy; nested pressure-frame seams; articulated door/lock parts only if they have a function; louver housings with interior depth; panel overlaps; accessible cable trays and brackets; receiver sockets; structural weld/bolt patterns where loads meet; frost dams and chipped contact points only where exposure or drainage explains them. Do not scatter bolts/noise evenly or use a universal greeble pass.

## Material-breakdown plan

1. **Dark painted titanium/steel:** principal shells and structural skins; varied roughness around access zones and weather exposure.
2. **Exposed alloy:** worn edge bands, mechanical joints, lintel/receiver interfaces; not a blanket bright-metal shader.
3. **Cryogenic ice/frost:** physical accumulations in snow traps, buttress feet, drainage lips, and terrain contact; includes fractured/dirty inclusions where appropriate.
4. **Cavity/insulation/rubber:** deep threshold gaps, service-jamb sealing, cable isolation.
5. **Restricted cyan emissive/service guidance:** core cage, controlled route indicators, and safety state; never a substitute for form.

## Evidence required to accept Gate 01

- Annotated Blender front/side/top sheet matching the guide above.
- A scene capture with approved scale proxy on the south route.
- A review note showing the open threshold, maintenance route, load path, and core reserve.
- Signed material allocation and the list of specific high-poly/bake targets.
