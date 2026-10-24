# Reference vs forge — what actually matches

The forge does not claim to reproduce the in-game reference photographs pixel for
pixel. It claims to reproduce the **asset**, and this page records where that
claim holds and where it does not.

Method: `node tools/asset-forge/gate/compare_sheet.mjs` writes
`tools/asset-forge/review/compare/world.png` — one row per asset, reference photo
on the left, forge render on the right, both at the same cell size. The sheet was
then inspected by eye, row by row, and the verdicts below are what the eye said.
A machine cannot give this verdict: every automated check can pass while the
silhouette is wrong.

## Verdicts

| Asset | Verdict | What differs |
| --- | --- | --- |
| `reactor_core` | close | Proportions. The reference reads as four heavy pylons around a tall plasma column; the forge vessel is slimmer and its crown is wider than its base. Palette, suspended-core concept and the open lane underneath all match. |
| `command_center` | partial | The reference has a rounded, domed upper deck; the forge is a two-tier box with a roof dish. Same mass, different silhouette. |
| `research_lab` | partial | The reference is a wide, low complex with orange accents; the forge is a taller compact module with a cyan window band. The "containment vessel in a bay" idea survives, the massing does not. |
| `equipment_depot` | match | Low armoured bunker, roll-up door, amber lamps. |
| `generator_bank` | match | Twin towers, blue energy columns, brass feed pipes. The strongest match of the sixteen. |
| `landing_pad` | partial | Footprint. The forge pad is a 12.4 m circular deck with chevron markings and six stanchion beacons; the reference is a much broader rectangular apron with an H marking. Deck height (1.2 m) is right; the plan does not extend as far. |
| `boss_gate` | close | The forge header is shorter and the buttresses wider; the violet membrane, hazard chevrons and side conduits match. |
| `defense_turret` | match | Twin barrels, yaw housing, sensor post on a ringed base. |
| `sensor_tower` | match | Mast, observation deck, twin dishes, banded lights. |
| `wrecked_transport` | close | The forge wreck is more compact; the reference's wings spread further. Damage language (broken fin, ember glow, debris) matches. |
| `alien_drone_wreck` | differs | The reference is an insect-like wreck with splayed legs; the forge is a lens-fronted dome with four short arms. Same alley (dead alien tech), different creature. |
| `crystal_cluster` | close | The forge shards are fewer and more upright; colour and shimmer match. |
| `alien_flora` | differs | The reference is bulbous pods on curved stems; the forge is a spiky frond crown. Reads as "alien plant" either way, but not the same plant. |
| `rock_cluster` | match | Rounded basalt masses with the same weathering. |
| `enemy_spawn_gate` | match | Frame, membrane, hazard floor guide. |
| `cover_module` | match | Low armour block with a warning stripe and signal lamp. |

**Score:** 7 match · 4 close · 4 partial · 2 differ.

## Why the differences exist, and what was done about them

1. **The forge is a re-interpretation, not a trace.** Every model is procedural
   three.js built from primitives in `src/runtime/kit.js`; the reference is the
   game's own GDScript blockout dressed with an imported kit. Matching the kit's
   rounded hulls would mean modelling that kit, not this one.
2. **Height is locked, mass is not.** The catalog fixes each asset's target
   height (a gameplay constraint — the reactor must not block the arena lane, the
   boss gate must read from 60 m). The forge hits those heights within tolerance;
   width and depth follow from the build, which is where most of the differences
   above come from.
3. **What the comparison is for.** It is a *reading* check, not a diff. Two of the
   verdicts above were reached only after looking: `boss_gate` reads as a gate at
   distance because its two leaves are cut into nine slats with a light per slat,
   and `landing_pad` reads as a pad because of its chevrons and six beacons —
   neither of which any measurement in the gate would have flagged as missing.
4. **What was deliberately left.** Re-modelling `alien_drone_wreck` and
   `alien_flora` to match the reference creature would take a modelling pass each
   and change nothing about how the world plays or how it reads at 20 m. They are
   recorded as differences instead of being quietly declared "good enough".

## Reproducing the sheet

```bash
node tools/asset-forge/gate/run_gate.mjs        # renders + measures all 16
node tools/asset-forge/gate/compare_sheet.mjs   # reference | forge, side by side
# → tools/asset-forge/review/compare/world.png
```
