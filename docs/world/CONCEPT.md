# World Concept — STELLAR HORIZON

This document defines current environment identity and spatial intent. It does not assign Gameplay missions or rewards. TECH HUNT mission selection and guardian/cache behavior remain in [`../GAMEPLAY_DESIGN.md`](../GAMEPLAY_DESIGN.md).

## 1. Theatre identities

| Theatre | Stable id | Current environmental identity | Runtime family |
|---|---|---|---|
| **Frostline Relay** | `frostline_relay` | **Daytime.** Bright archipelago/canyon approaches, central relay tower, upper platforms and interior bases, ice formations and relay equipment | Shared Forge / `MissionWorld` |
| **Verdant Bloom** | `verdant_bloom` | **Sunset.** Shared canyon/tower/sky-bridge/interior route at golden hour, living canopy, giant flora and research-bloom structures | Shared Forge / `MissionWorld` |
| **Emberfall Foundry** | `emberfall_foundry` | **Night.** Common tower-and-islands route under a deep navy sky, foundry silhouettes, city light and cyan interior bases | Shared Forge / `MissionWorld` |
| **The Titans** | `titans` | **Storm.** Shared canyon, central tower, sky bridges and interior bases under low storm cloud, Titans wreckage, torn structures and lightning-rim dressing | Shared Forge / `MissionWorld` |
| **Vanguard Station** | `vanguard_station` | Dock 07 of a dead orbital station: gantry hall, reactor hall, cargo bay and a corridor fading into darkness | Separate imported-kit station |

`WorldDefinition` resources are the source for player-facing names, descriptions, card art, readiness, spawn/configuration, and scene selection. Do not duplicate a different identity into UI copy or documentation.

## 2. Shared route language

The four Forge theatres intentionally reuse a navigable spatial family:

- canyon/approach routes that establish direction;
- a central tower/relay landmark;
- upper platforms and sky bridges;
- interior bases with readable cyan accents;
- safe initial spawn and configured field boundaries;
- markers/collision supplied through the shared runtime contract.

Sharing this language keeps traversal and production coherent. Their identities come from time, atmosphere, dressing, silhouettes, and environmental motion—not from pretending each has a separate Gameplay mode.

Any future mission must use the actual route and markers. A word such as `recovery`, `hunt`, or `extraction` in metadata is not sufficient to create an objective, guard encounter, or reward.

## 3. World-type design role

World types are one of the three content pillars. A meaningful world type can change:

- route choice and sight lines;
- landmark/navigation decisions;
- appropriate guard composition through an explicit Gameplay contract;
- environmental hazards or interactions when separately approved;
- which technology opportunities fit the environment.

It should not merely reskin the same combat while claiming new gameplay. Conversely, do not add a unique mechanic to every world before TECH HUNT 0 proves one shared mission path.

The first TECH HUNT 0 theatre remains an open selection in `GAMEPLAY_DESIGN.md`; no world is implicitly assigned by this concept document.

## 4. Atmosphere and readability

All theatres share the STELLAR HORIZON / Frontier Signal presentation direction:

- near-black/graphite structure with controlled cyan, amber, and world-specific accents;
- a readable central route and threat silhouettes before small surface detail;
- atmosphere that supports time/weather identity without hiding aim, cover, or objective landmarks;
- painted theatre cards consistent with the shell, while actual gameplay validation uses the real 3D scene;
- motion attached to real environmental assets rather than distracting diagnostic overlays.

Detailed palette/type/composition rules live in [`../ART_DIRECTION.md`](../ART_DIRECTION.md). World mood configuration and generated measurements remain in code/manifests, not duplicate prose tables.

## 5. Environmental motion and life

Motion should make a place feel active while preserving navigation and combat readability:

- relay/hardware movement supports Frostline's function;
- canopy/flora/research structures support Verdant's living overgrowth;
- foundry silhouettes and industrial lights support Emberfall's night identity;
- wreckage, torn structures, storm and lightning-rim accents support The Titans;
- station rooms and lighting support Vanguard's dead-orbital identity.

Animation existence is verified through import/runtime checks where covered. Human assessment of motion quality, timing, and performance remains a separate gate.

## 6. Adding or changing a theatre

1. Update the World source data and `WorldDefinition` through the existing registry.
2. Preserve stable ids or provide an explicit profile/shell migration.
3. Keep card art, mood, spawn, route markers, collision, and runtime scene selection consistent.
4. Rebuild/review the affected Forge world or use Vanguard's own pipeline; do not conflate the two.
5. Verify initial pack inclusion, direct selected-theatre DEPLOY, safe entry, traversal fixtures, and payload/cache behavior.
6. Coordinate any new gameplay objective, enemy, guardian, cache, or reward with Gameplay/Core rather than encoding it only in World data.
7. Update this concept only for durable identity/route changes; record measured results in [`../VALIDATION.md`](../VALIDATION.md).

Build/provenance commands and verification policy are centralized in [`README.md`](README.md).
