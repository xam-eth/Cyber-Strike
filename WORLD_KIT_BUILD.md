# World build: original KayKit pass (historical) → uploaded SciFi Starter Kit

**Date:** 2026-10-17 (historical build) · **Branch:** `arena/5257bce8-cyber-strike`

> **18 Oct 2026 — rebaseline in progress:** this document records an **older**
> KayKit build and the original interior FBX integration, not the current runtime
> layout. The playable `NeonFrontierWorld` now instantiates the user's converted
> FBX SciFi kit across the bay, landing deck, depot, districts, and visible
> perimeter; KayKit runtime scripts and files were removed. Existing procedural
> foundations/ramps/supports remain for gameplay and need visual review before
> the world can be called fully art-finished. See
> [`docs/REBASE_VISUAL_GAMEPLAY_2026-10-18.md`](docs/REBASE_VISUAL_GAMEPLAY_2026-10-18.md)
> for the approved direction and still-open gates.

The level used to be a blockout: a flat plane, four box cliffs and a few GLTF
props in a sea of grey. This round rebuilds it from the CC0 **KayKit Space Base
Bits** pack that was pushed to the branch, and proves the result in the browser.

## What the pack actually contains (and why only 7 models were in the repo)

`3DScifiStarterKitFree.zip` (259 MB) is stored through **Git LFS**. The LFS object
could not be downloaded from this sandbox (`github-cloud.githubusercontent.com`
is not reachable), and the pointer file in the tree is 134 bytes, not a zip.

What *is* in the branch is the imported subset under
`game/assets/world/kaykit_space_base_bits/gltf/`: 7 models plus the shared
`spacebits_texture.png`. The rest of the pack — **57 models in total** — was
taken from the upstream repository and is byte-identical:

* upstream: `KayKit-Game-Assets/KayKit-Space-Base-Bits-1.0`
* commit: **`6dfbcac9927d06283752c4defd4882cfe0d29666`**
* verified by md5 on `cargo_A_stacked.gltf`, `cargo_A_stacked.bin` and
  `spacebits_texture.png` (all three match the files already in the branch)

So the zip was not "used" directly, but its contents are in the level, pinned to
a commit. `game/assets/world/kaykit_space_base_bits/README.md` records this.

## What was built

`game/scripts/worlds/kaykit_base_builder.gd` (new, 887 lines) composes the pack
into the districts the blockout already defined. Every placement uses the same
coordinates as the boxes it replaces, and the two paths the traversal test walks
(arena → boss causeway, arena → landing ramp) stay clear by construction.

| District | Kit-built content |
|---|---|
| Arena rim | 8 checkpoint modules on the diagonal (the four axis lanes carry the spawn gates and routes), cargo cover, roof modules, lamps |
| Outpost | 3-module barracks row with solar roofs, hangar (garage + two tunnels + lamp), cargo yard, command annex, parked truck and shuttle |
| Landing zone | 5×5 landing-pad apron (18 m), two landers, service truck, cargo, perimeter lamps |
| Extraction | two mine faces (mining + curved terrain), tunnel mouth and run, truck trailer, ore containers, pylons |
| Boss zone | pylon gate, buttresses, a ring of barriers that skips the ramp lane the test walks |
| Ruins | broken tunnels, a toppled lander, rock debris, collapsed service tunnel |
| Power grid | six wind turbines + solar panels around the perimeter |
| Routes | lamp posts down every road, roadside cargo on the south approach |
| Boundary | the four 10 m collision boxes are now **invisible**; the horizon is 68 staggered rock tiles (`terrain`, `rocks_B`) in four runs |
| Terrain shoulders | 137 terrain tiles in the four off-route quadrants, tops flush with the floor at y = 0 |

Numbers from the engine (headless run, printed by the world itself):

| | Blockout | Now |
|---|---|---|
| MeshInstance3D in the world | 2,539 | **2,897** |
| StaticBody3D | 130 | **354** |
| Kit models available | 7 | **57** |

## How the builder handles the pack's rough edges

* **Grounding** — trucks have their origin 8–14 cm above the mesh and tunnels
  20 cm below it. `BASE_MIN_Y` shifts each model by its measured minimum Y, so
  nothing floats or sinks.
* **Collision** — imported GLTFs carry no physics. Buildings get a box bounds
  collider (fill ratio 0.75–0.9); a 0.3 m rock deliberately does not, because it
  should not stop a sprint.
* **Shadows** — only buildings cast. The ~200 cliff/terrain/prop meshes do not:
  Compatibility renders shadows per light, and that is the cheapest frame-time
  win available on a phone.
* **Determinism** — every scattered district uses a seeded `RandomNumberGenerator`,
  so two builds are identical and screenshots stay comparable.
* **Pad seams** — the landing pads are octagons, so a tight grid still leaves
  triangular gaps. A continuous 26 m slab sits 5 cm under the tile tops, which
  turns the gaps into joints instead of holes.

## Reviewing it

`game/scripts/qa/world_tour.gd` adds a review camera to `main.tscn`:

* **F10** toggles it (and pauses the simulation, so enemies stop shooting the
  idle player and the run-results panel never covers a district),
* **1–8** jump to arena / outpost / landing / extraction / boss / ruins /
  skyline / cliffs,
* **Esc** hands the view back to the player.

`tools/web_qa.mjs --tour` drives it with real key events in the exported
WebAssembly build and writes eight screenshots. That is the evidence in
`qa-evidence/world-kit/`; the shots are of the shipped build, not of a separate
review scene.

`tools/render/kit_sheet.mjs` renders every model in a pack to a labelled contact
sheet (`qa-evidence/world-kit/kit-catalog-{1,2,3}.png`). That sheet is how the
placements above were chosen — by looking at the geometry, not at file names.

## Tests

`neon_frontier_world_smoke.gd` grew from component checks to district checks:

* every required blockout component still exists (the gameplay contract),
* each of the nine kit groups has at least N meshes (arena 16, outpost 20,
  landing 10, extraction 15, boss 10, ruins 12, power 8, routes 10, shoulders 120),
* the four boundary colliders still exist and are invisible,
* the horizon has at least 16 rock tiles,
* the original walk tests still pass: central arena → boss causeway → elevated
  boss platform, and the landing-pad ramp.

Full suite: **13/13 pass**, `dev_check` 0 failed / 8 warnings.


## The uploaded pack is the one inside the arena

The first version of this document described only the KayKit pass. That was the
wrong reading of the request: the zip you pushed (`3DScifiStarterKitFree.zip`,
125 FBX) is what the playable arena is now built from, and the KayKit pack does
the outside — outpost, landing zone, cliffs, terrain.

Getting the archive here needed a detour. The 259 MB zip is a **Git LFS pointer**
whose download host is unreachable from this sandbox, and GitHub artifact
downloads are blocked too, so no data can be pulled in either direction except
through git. The CI job `lfs-pack` resolves the archive on a runner, converts
every FBX with Blender (`tools/convert_fbx_pack.py`) and commits 2.4 MB of GLB:
**125 converted, 0 failed**. `docs/LFS_ASSET_MANIFEST.md` is the full manifest.

| | Before | Now |
|---|---|---|
| Arena floor | painted plates + decals | 49 SciFi floor plates |
| Arena walls | none (open platform) | 4 wall runs, 28 pieces, 6 m lane opening per side |
| Lanes | open edge | `DoorWay_01_Large` frame, no collider |
| Cover | none | 8 octagonal pillars, crates, low plates |
| Detail | decals | consoles, pipe stacks, 16 emissive strips |

Two things in that pack are traps, both documented in the code:

* **Orientation.** `Wall_Simple_01_Long` is 6 m along its own Z. Placed with no
  yaw it stands as a fin; the east-west runs need a 90° turn. The first build
  looked like a walled arena that was missing two of its walls.
* **Material names.** Every model — floors included — carries a material
  literally named `Orange`. Mapping that name to orange painted the whole arena
  orange. Colour is resolved per model (`ScifiKitLibrary.surface_color_key`).

The pack's 4K texture set is not used: the FBX carry named materials with no
image links, and importing ~700 MB of TIF/PNG to colour a floor is the wrong
trade for a repository. The palette is applied in code.

### Controls and HUD this round

* `Shift` sprint, `Space` jump, `Q` previous weapon, `1`/`2`/`3` direct weapon
  selection. All are real actions in `project.godot`, not hard-coded key reads.
* The thumb controls (FIRE / AIM / EMP / weapon) are **hidden on a desktop
  session** — they covered a third of the play area and swallowed clicks — and a
  compact keyboard legend takes their place. A real touch event switches back;
  the HUD smoke test asserts both modes.
* The help text sits on a dark plate over three lines instead of floating cyan
  pixels on a white floor, and the reticle is thicker mint rather than pale cyan.

## Known gaps

* The 259 MB LFS zip itself is not in the tree and cannot be fetched here. If you
  want the original archive committed, push it through LFS again (the pointer is
  already tracked) and it will resolve on a machine with LFS installed.
* Debris and rock props are not collidable by design; if a playtest shows the
  player clipping through something that looks solid, add it to the `place(...)`
  call for that prop.
* The flat playable floor is unchanged on purpose — combat readability beats
  terrain relief. The relief is all outside the route lanes.
* Nothing here was measured on an Android device: mesh count is not a frame-rate
  claim.
* The SciFi pack's own textures are unused (see above); if the interior should
  use them, the conversion step can pack them, at roughly 50x the committed size.
* Enemies, shooting and the HUD were reported as needing work in the same
  message as the world. This round fixed the two concrete input problems found
  by inspection (invisible weapon switching beyond `E`, and desktop showing thumb
  controls); AI behaviour, weapon feel and the results screen were not redesigned.
