# NEON FRONTIER — "Frontier Outpost"

The single world this branch builds. One place, 192 × 180 m, wholly walkable, every
asset in it made from code in this repository.

---

## 1. The place

A frontier outpost of the Exocomplict corporation, built around the reactor that
keeps it alive, on a shelf of black basalt at the edge of an alien night. The
outpost is not ruined and it is not finished: it is **holding**, and the reason it
is holding is the reactor in the middle of the arena.

Everything radiates from that reactor. Roads leave it in four directions, the
settlement sits on its west side like a lean-to against a furnace, the energy bank
taps it from the east, the docking gate north of it is the way off this rock, and
south of it the planet is taking the place back — a crashed transport, a dead
alien drone, and crystals growing through the cracks in the pavement.

The player never leaves the map. There is no loading screen between districts,
because there are no districts in the technical sense: it is one continuous
surface with a navmesh-friendly 0.2 m deck at the centre and a 2.6 m perimeter
wall that exists to frame the playfield, not to stop the player.

## 2. The five beats

| Beat | Where | What it is for |
| --- | --- | --- |
| **Arena** | centre, 38 × 38 m deck | Wave combat around the reactor; four wave-entry gates on the deck's cardinals and four cover modules for line-of-fire breaks. |
| **Outpost** | west | Friendly ground: command centre, research lab, equipment depot, two sensor towers, the landing platform on the east deck. Vendors, upgrades, respawn. |
| **Extraction** | east | The generator bank and its pipe run — an industrial, exposed-brass counterweight to the outpost's clean panels. |
| **Docking gate** | north | An 11 m colossal gate on the far end of a raised causeway. The horizon landmark you can navigate by. |
| **Crashed sector** | south | Wreckage, crystals, luminous flora. Low cover, harvestable colour, and the only place in the world where the palette goes green. |

## 3. Why it looks like this

The palette is nine tokens — near-black voids, graphite panels with a cool
hairline, and exactly three luminous colours: **amber** (warning and heat),
**cyan** (power and information) and **violet** (alien). Nothing is bright by
accident. A surface is either structure (low saturation, matte) or energy (fully
saturated, emissive); there is no third category, which is what keeps a night
scene readable at mobile brightness.

Three lighting rules, applied by `src/worlds/neon_frontier.js → worldLighting()`:

1. One warm key from the south-west, low enough to throw 20–30 m shadows.
2. One cyan fill from the east, at half the key's intensity, marking the edges
   that face away from the key.
3. One violet rim from the north — the alien colour arrives from the direction of
   the docked wreck, so the light itself tells you where the danger is.

The sky is a procedural gradient with a single bright haze band just above the
horizon. That band is deliberate: a night scene needs one soft edge to separate
silhouettes from the backdrop, or the skyline disappears into the fog.

## 4. The world moves

A static outpost reads as a diorama. Every district therefore has at least two
moving parts, authored as animation clips inside the assets themselves:

- **Reactor**: the two containment halos counter-rotate, the seed pulses on a 2.6 s
  breath, and the beacon on the crown flashes on the same clock as the arena's
  hazard ring.
- **Settlement**: command-centre dish scans a full turn every 14 s, roof beacon
  pulses every 1.7 s, the lab's sample column breathes every 3.4 s and the
  maintenance arm sweeps.
- **Perimeter**: six turrets sweep their yaw housings out of phase with each other
  (the phase comes from the instance's position, so no two are in step); five
  sensor towers spin their radar drums at 1.3 rad/s and their beacons pulse.
- **Extraction**: generator energy columns breathe at 2.4 s, manifold glow at
  3.8 s, crowns counter-rotate.
- **Crashed sector**: embers flicker at 0.9 s, the dead drone's lens and its
  sparking cable pulse at different rates, crystals shimmer and nineteen flora
  sway on their own phase.

In the browser build this is 70 clips driven by one `AnimationMixer`. In Godot it
is `game/scripts/worlds/neon_frontier_motion.gd` — a data-driven node that rides
inside each component and animates the meshes that should move (see
[`ASSET_LIST.md`](ASSET_LIST.md#3-runtime-motion-in-godot)).

## 5. How you verify it

Not by trusting the code. Three independent gates, described in
[`PBR_AND_VERIFICATION.md`](PBR_AND_VERIFICATION.md):

1. **Per-asset gate** — 20 automated checks per asset, including the Khronos glTF
   validator and a "rendered images actually differ" check.
2. **World renders** — eight authored cameras, rendered from the real scene graph
   in pinned headless Chromium at 2048 × 1152, looked at with human eyes.
3. **Engine import** — the GLBs are imported into Godot in CI and measured against
   their catalogued heights and clip names.
