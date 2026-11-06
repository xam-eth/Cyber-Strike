# Gate 01 draft — Archive Vestibule

**Asset ID:** `archive__archive_vestibule`
**Legacy source/export:** `source/aetherfall_archive_interior.blend` → `assets/world/aetherfall/archive/archive_vestibule.glb`
**Legacy measured envelope:** 10.50 m X × 5.43 m Y × 6.50 m Z.
**Status:** draft brief; Base Mesh is **not authorized**.
**Visual working reference:** [`reference/archive_vestibule_concept.png`](reference/archive_vestibule_concept.png) — original design study for silhouette/construction discussion only; it is not a texture, bake, geometry source, or Gate 01 approval.

## Role

The vestibule is the short pressure and security transition between open ice basin and the single Archive Computer room. It must have a clear arrival axis, a readable partition/door system, equipment/service recesses, and contrast in temperature/material response. It cannot be a generic glowing corridor or a solid room shell around the exterior opening.

## Orthographic modelling guide

| Projection | Required construction logic |
|---|---|
| **Entry/front** | A wide centered threshold lines up with the Archive exterior. Frame depth is visible: exterior ice/weather lip, structural pressure frame, then a protected inner reveal. |
| **Longitudinal side** | The floor rises or channels moisture into a threshold drain; wall skins sit off a service void; the objective-room partition is a real assembly with an opening, header, and side services. |
| **Plan/top** | Entry, decompression/inspection bay, and objective-room door form a short serial sequence. Service cabinet, cable routing, and emergency/manual access have deliberate side placement rather than symmetric wall decoration. |

## Functional Base-Mesh volumes

- **Exterior weather lip and floor drain** — stops the interior looking like an ice-surface continuation.
- **Primary pressure frame** — carries wall/ceiling panels and has a reason for its thickness.
- **Wall service voids** — route cooling, power, data, and inspection access without surface-only detail.
- **Objective partition and header** — controls the view/reveal of the computer room while preserving access clearance.
- **Ceiling utility spine** — lighting, cable/air routing, and maintenance panels are structurally located.
- **Emergency/manual access niche** — establishes a believable alternate operating mode without adding new gameplay claims.

## Scale/camera and continuity checks

- Validate the exterior opening, floor, partition, and computer location against `archive_phase3.json`; visual reconstruction must not invalidate the declared collision/interaction space.
- Use approved player/camera proxy to test headroom, doorway width, computer reach, and camera clipping. The proxy is a blocker until one is approved.
- Review with exterior light spilling through the entry and low-level interior lighting; do not use darkness to hide blank forms.

## High-poly plan

Physical panel breaks, gasket channels, latch pockets, hinge/slider hardware, ventilation baffles, recessed ceiling trays, cable clamps, drain grate, service labels/fasteners, and ice/rust/wear only at plausible air/water contact zones. The interior needs less exterior damage and more controlled maintenance logic.

## Material-breakdown plan

- Dark painted structural shell; exposed alloy only on service edges/threshold hardware.
- Cold floor metal with drain/grating material distinction.
- Insulation/rubber in pressure-frame and cable interfaces.
- Restrained cyan status/emissive integrated into indicators, not into entire walls.
- Frost/condensation masks physically limited to entry-facing, drain, and cold-bridge surfaces.

## Evidence required to accept Gate 01

Annotated entry/side/plan sheet; approved scale-proxy review; exterior-to-interior alignment check; signed interior material map and high-poly feature list.