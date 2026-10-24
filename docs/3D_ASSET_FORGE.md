# 3D Asset Forge — code-only models for EXOCOMFLICT / NEON FRONTIER

`tools/asset-forge/` rebuilds this game's world, hero, weapon, enemy and VFX
assets as **procedural three.js models generated from code**, from a reference
image per asset, behind a **deterministic quality gate**. Nothing is
photogrammetry, nothing is a downloaded art pack: every vertex is produced by a
module in `tools/asset-forge/src/`, and every module is measured before it is
accepted.

Two upstream skill sets are installed in `.claude/skills/` and their rules are
what this pipeline follows — see [`.claude/skills/PROVENANCE.md`](../.claude/skills/PROVENANCE.md):

| Skill set | What was taken from it |
| --- | --- |
| [`gamedev-skills/awesome-gamedev-agent-skills`](https://github.com/gamedev-skills/awesome-gamedev-agent-skills) @ `7eb1b53` | `create-game-assets` (manifest → family → normalise → **validate**, "do not call an asset production-ready from a prompt result alone"), `threejs-scene-setup`, `threejs-materials-lighting`, `threejs-gltf-loading`, `godot-3d-essentials`, `godot-shaders` |
| [`img2threejs/img2threejs`](https://github.com/img2threejs/img2threejs) @ `954cd58` | the staged shape of the work: reference → spec → pass-by-pass code build → deterministic gate + vision review, and "a state file, not conversation memory, is the checklist authority" |

---

## 1. What was read before anything was built

The asset list is **derived from the repository**, not invented. Each of the 36
catalog entries cites the file that proves it belongs to this game:

| Source read | What it decided |
| --- | --- |
| `GAME_CONCEPT.md`, `GAME_OVERVIEW.md` | stylized-realistic sci-fi, mobile-first, "every weapon feels different", third-person camera behind the character |
| `docs/ART_DIRECTION.md` + `game/scripts/ui/aegis_tokens.gd` | the **palette is law**: navy/graphite/cyan/amber/silver/green/red/violet, one amber key + one cyan fill, silhouette-first. The gate re-reads the `.gd` file and fails if the forge's copy drifts |
| `WORLD_BLOCKOUT.md` §3D component inventory | the 16 world props, each with its construction notes (reactor's open lower centre, boss-gate shutter leaves, cover height, etc.) |
| `game/scenes/worlds/components/*.tscn` | the prop list is the scene list — one model per shipped component |
| `game/resources/weapons/*.tres` | the three real weapons and their stats (5.0 shots/s, 24 rounds, 18 damage …) and the fact that *all three currently point at one `rifle.glb`* — which is exactly the gap this work closes |
| `IAP_CONCEPT.md` §Pillar 1–2 | the documented **working names** of three more weapons (Scatter Blaster, Rail Cannon, Gravity Gun), the Arc Shooter's **Void Edition** skin, and the five character skin themes (Combat Tech, Void Runner, Neon Phantom, Rogue Engineer, Alien Hunter) |
| `game/resources/heroes/exo_operative.tres`, `game/scripts/progression/hero_definition.gd` | the hero roster is 1 field-ready operative + skins, not five separate characters |
| `game/scenes/enemies/*.tscn` | three enemies and their fitted sizes (Runner 1.72 m, Shooter 1.62 m, Training Drone 1.15 m + hover) |
| `HERO_RIG_PIPELINE.md`, `ANIMATION_ASSET_INSPECTION.md` | shipped hero height ≈ 1.78 m, five clips, no second rig — the reason the forged hero is 1.8 m with idle/aim/fire/run |

Anything that is a *working name* upstream is marked as such in
`catalog.json` → `source: "IAP_CONCEPT.md#..."`. Nothing claims to be
canonical where the repo has not decided yet.

## 2. The asset list (36)

| Category | Count | Assets |
| --- | --- | --- |
| `world` | 16 | reactor core, command centre, research lab, equipment depot, generator bank, landing pad, boss gate, defence turret, sensor tower, wrecked transport, alien drone wreck, crystal cluster, alien flora, rock cluster, enemy spawn gate, cover module |
| `hero` | 6 | Exo Operative + 5 documented skins (Combat Tech, Void Runner, Neon Phantom, Rogue Engineer, Alien Hunter) |
| `weapon` | 7 | Pulse Rifle, Nova Launcher, Arc Shooter, Scatter Blaster, Rail Cannon, Gravity Gun, Arc Shooter — Void Edition |
| `enemy` | 3 | Runner, Shooter, Training Drone |
| `vfx` | 4 | Pulse Bolt, Nova Shockwave, Arc Chain, Impact Burst |

`tools/asset-forge/catalog.json` is the single source of truth: height or
length in metres, triangle/mesh budgets, sockets, animation clip names, view
angles for the render gate, and the reference image path.

## 3. Pipeline

```
catalog.json
   │
   ├─ 1. reference image per asset      tools/asset-forge/references/<category>/<id>.png
   │       one image, palette-locked prompt, three-quarter view, flat navy backdrop
   │
   ├─ 2. code-only model module         src/<category>/<id>.js   (+ shared src/runtime/*)
   │       primitives + procedural greebles, no imported mesh, deterministic rng
   │
   ├─ 3. gate: build in a real browser  gate/run_gate.mjs  (pinned Chromium, SwiftShader)
   │       measure → rebuild → render 3 views → export GLB → check
   │
   ├─ 4. review sheets                  gate/contact_sheet.mjs → review/<category>.png
   │
   └─ 5. results.json                   committed summary, machine-readable
```

### 3.1 Code, not meshes

Every model is assembled from a small primitive kit (`src/runtime/kit.js`):
boxes, chamfered boxes, cylinders, lathes, struts, cables, trusses, dishes,
greeble scatter with seeded jitter. Two properties matter:

* **Deterministic.** A seeded `mulberry32` decides every jitter, so building the
  same module twice yields identical vertices. The gate proves it by rebuilding
  the module from a cache-busted URL and comparing geometry hashes.
* **Named hierarchy.** Parts are `Group`s called `Housing`, `Yaw`, `BarrelL`,
  `ShutterL`, `Plasma`… so animations can address them, and so a reviewer can
  read the structure in a GLB inspector.

### 3.2 Materials are palette tokens

`src/runtime/materials.js` builds `MeshStandardMaterial`s only from
`aegis_tokens.gd` values: structure (`line`), plating (`ink2`), energy (`info`),
friendly (`ok`), warning (`accent`), hostile (`danger`), ability (`ability`).
Two intensities of the same token are allowed (a dim sleeve, a hot core);
a new hue is not. The gate rejects an authored colour more than 6/255 away from
a token.

### 3.3 Animation without a skin

The forged characters are **not** skinned meshes. They are object hierarchies —
`Hips → Torso → Head/ArmL/ArmR`, `Hips → LegL/LegR` — animated by real
`THREE.AnimationClip`s that address nodes by name. Consequences, stated
plainly:

* Good: the clips are real data, they survive GLB export, they play in three.js,
  Godot can drive the same node transforms, and there is no skinning pipeline to
  maintain.
* Limited: shoulders and knees rotate rigidly. There is no soft deformation, no
  finger animation, no blend-shape face. For a 1.8 m character seen from a
  third-person camera at 3–8 m this is acceptable; for a cut-scene close-up it
  is not.

**The track-name rule.** three.js parses a track name as
`nodeName.propertyName[propertyIndex]`. `ArmR.rotation.x` is *not* that form:
it is read as node `ArmR.rotation`, property `x`, and because no node is called
`ArmR.rotation` the mixer binds to `null`, logs a warning nobody is reading, and
plays a clip that moves nothing. Every axis track in this project was written in
the dotted form, so for a while all 34 animated assets had *working* clips that
animated *nothing* — while `clips-declared` and `clip-targets-exist` both passed,
because the node names were fine. The fix is centralised in
`src/runtime/rig.js` (`trackName()` rewrites `ArmR.rotation.x` to
`ArmR.rotation[x]`), and `clip-bindings-resolve` now fails the gate if any track
cannot bind to a real node property.

Clips per category:

| Category | Clips |
| --- | --- |
| hero | `idle`, `aim`, `fire`, `run` (three exported per hero) |
| weapon | `idle`, `fire_recoil`, `reload`, plus `charge` on the Rail Cannon and Gravity Gun |
| enemy | `idle`, `run`, `hit`, `death` / drone `hover`, `hit`, `death` |
| world | one meaningful loop each: `core_pulse`, `dish_scan`, `gate_open`, `yaw_sweep` + `fire_recoil`, `energy_columns`, `beacon_cycle`, `strip_pulse`, `shimmer`, `sway`, `sample_cycle`, `lamp_pulse`, `ember_flicker`, `sensor_fade` |
| vfx | `travel`/`impact`, `expand`/`fade`, `strike`/`fork`, `burst` |

### 3.4 Sockets

Each model exposes named empties a gameplay system attaches to: `muzzle`,
`grip_r`, `hand_r`, `shutter_l`, `spawn_point`, `pad_centre`, `sensor`… The
catalog declares which sockets a consumer needs; the gate fails if one is
missing, and the GLB check fails if the socket node did not survive export.

## 4. The quality gate

`node tools/asset-forge/gate/run_gate.mjs` — 20 checks per asset, all measured:

| Check | Rule |
| --- | --- |
| `palette-source` | the 14 tokens in the forge match `game/scripts/ui/aegis_tokens.gd` exactly |
| `catalog-source-exists` | the `.tscn`/`.tres`/doc the entry cites exists |
| `meta-matches-catalog` | id, category, name, source, reference image all agree with the catalog |
| `normalisation-recorded` | the uniform scale factor is recorded and stays inside 0.5–2.0 — a normaliser may seat a model, not rescue bad proportions |
| `height-within-tolerance` | measured height (or length) within ±12% of the catalog target |
| `origin-sane` | ground-contact assets sit on y=0; centre-origin assets are centred; hand-held props keep a grip origin inside their own bounds |
| `triangle-budget` / `mesh-budget` | mobile-first ceilings per asset |
| `sockets-declared` | every declared socket exists |
| `clips-declared` | every declared clip exists |
| `clip-targets-exist` | every animation track targets a node that exists |
| `clip-bindings-resolve` | every track parses into a node **and** a property the mixer can bind to (`ArmR.rotation[x]`, not `ArmR.rotation.x`) |
| `unique-node-names` | no duplicate node names (three.js and glTF resolve nodes by name — a duplicate animates the wrong object) |
| `geometry-finite` | non-degenerate bounding box |
| `materials-on-palette` | every authored colour is within 6/255 of a palette token |
| `deterministic-rebuild` | rebuilding the module produces an identical geometry hash |
| `glb-valid` | glTF 2.0 binary: magic, version, declared length, JSON chunk, ≥1 mesh, declared animations and sockets present as nodes |
| `gltf-conformance` | the file passes the **Khronos glTF validator** with 0 errors and 0 warnings — the rules Godot's importer reads |
| `glb-matches-measured` | the exported GLB's own bounding box matches the in-memory measurement within 1% (catches pose baked into the file) |
| `render-coverage` | the asset covers 1.5–90% of the frame in each of three views (per-entry floors for thin props) |
| `render-luma` | luma spread ≥ 0.30 and std ≥ 0.045 — the render is not a flat silhouette |
| `views-differ` | the three views are not the same projection (best pair differs ≥ 0.12; rotationally symmetric subjects may declare a lower `views_differ_min`, printed in the message) |

The gate is **deterministic-only**. It cannot see whether a model *looks like*
its reference — so the renders and `review/<category>.png` contact sheets exist
for a human (or a vision model) to check, and each asset's `results.json` entry
records the reference it should be compared against. A green gate means
"measurable and on-palette", nothing more.

### 4.1 What a green gate caught, so far

The gate is not decoration; these are real defects it refused:

* `crystal_cluster` built with an unnormalised 3.2 m base and shards that did not
  reach the ground → `origin-sane` failed until the shards were seated.
* `command_center` greebles floated 1.5 m below the hull (`minY -0.835`) because a
  scatter helper placed panels in its own local space → fixed by making
  `greebles()` take a `centre`.
* `generator_bank` bolt rings were placed twice (once via the ring helper's own
  `y`, once by the group), producing a column of floating bolts.
* `equipment_depot` and `research_lab` came in at 4.33 m and 4.65 m against 4.6 m
  and 5.5 m targets until the normaliser recorded the correction.
* Every weapon was rejected by `sockets-declared` until the fore-grip socket was
  unconditional instead of rifle-only.
* **Every animation in the project was inert.** The gate was green and the
  filmstrips were identical six-frame strips; the cause was the track-name form
  above. Caught by `gate/anim_strip.mjs` (rendering a clip is evidence; a clip
  existing is not) and now prevented by `clip-bindings-resolve`.
* **A stale contact sheet hid a real model change.** `build/renders/<id>/` kept
  views from an older catalog alongside the new ones, and the sheet composited
  the old file, so the hero sheet showed the pre-change skin. The gate now wipes
  an asset's render directory before writing it, and `contact_sheet.mjs` prints
  a warning listing any cell whose render is older than the model source —
  `freshness: every cell is newer than its model source` is part of the output
  you should read before trusting a sheet.
* `impact_burst` measured 0.36 m in one run and 0.70 m in the next, and
  `defense_turret` passed `views-differ` in isolation but failed it in a full
  run: the gallery auto-played clip 0 and the gate captured whatever frame the
  RAF loop had reached. Capture mode now holds the model at its rest pose unless
  a time is passed, which makes measurement deterministic again.

### 4.2 Why the clips had to become vector channels

Per-axis track authoring (`rotation.x`, `scale.y`) is readable in three.js and
**impossible in glTF**: a glTF channel addresses a whole property
(`translation`/`rotation`/`scale`), never one axis. The per-axis form produced
two defects that the structural GLB check did not see, and the Khronos validator
did:

| Symptom | Validator code | Cause | Fix |
| --- | --- | --- | --- |
| hero clips exported with **zero channels** | `EMPTY_ENTITY` | three's exporter cannot map `ArmR.rotation[x]` to a node property | rotation is baked to `quaternion` tracks |
| VFX scale tracks rejected | `ANIMATION_SAMPLER_OUTPUT_ACCESSOR_INVALID_FORMAT` (`SCALAR` where `VEC3` required) | one scalar accessor per axis | position/scale grouped into `VectorKeyframeTrack` |
| drone `death` clip invalid | `ANIMATION_DUPLICATE_TARGETS` | two channels on one `scale` target | same grouping |

`src/runtime/rig.js` now groups tracks by (node, channel), samples each axis
onto the union of key times and emits **one** quaternion or vector track. The
mixer motion is unchanged; the export is legal. Result: **36/36 GLBs pass the
Khronos validator with 0 errors, 0 warnings**, and that is now a gate check
(`gltf-conformance`) rather than a one-off manual run.

### 4.3 Verified inside Godot — 36/36

Valid glTF is necessary, not sufficient. The engine check runs on every
`[forge-verify]` commit and its result is committed back to
`qa-evidence/forge/import-report.json` (the artifact and log hosts are not
reachable from the development sandbox, so git is the channel back — the same
pattern the `lfs-convert` and `hero-blender` jobs already use).

| Piece | What it does |
| --- | --- |
| `.github/workflows/godot-ci.yml` → `forge-verify` | installs the pinned Godot 4.7.2-stable via `scripts/install_godot.sh`, runs the real importer, runs the verifier, commits the report |
| `gate/stage_into_game.mjs` | copies the 36 GLBs to `game/assets/forge/` and writes `forge_manifest.json` (resource path, target size, normalisation axis, clips, sockets) |
| `godot/verify_import.gd` | `load()`s every asset, instantiates it, measures the real AABB, and fails if height, any declared clip, or any declared socket is missing after import |

**Result on Godot 4.7.2-stable (official), run `40065094729`:**

```
checked 36 · passed 36 · failed 0
```

Every asset imports, every declared clip arrives in the `AnimationPlayer`, every
declared socket survives as a named node, and every measured size matches the
manifest. The check is strict enough to be worth having: the same job's first run
failed 7 of 36, and every failure was a real defect (see §4.4).

### 4.4 What the engine found that three.js could not

The first `forge-verify` run reported **29 passed, 7 failed**. The engine was
right in all seven cases, and a GLB parsed directly in Node reproduced Godot's
numbers exactly — so the fault was in the forge, not the measurement.

| Asset | Godot | Should be | Cause |
| --- | --- | --- | --- |
| `runner` | 1.444 m | 1.72 m | exported at its **death pose** |
| `impact_burst` | 0.271 m | 0.70 m | exported at a **collapsed animation frame** |
| `landing_pad` | 1.428 m | 1.20 m | same class (beacon pulse pose) |
| `command_center` | 8.004 m | 7.50 m | same class (dish/beacon pose) |
| `rail_cannon` | 1.429 m | 1.25 m | same class |
| `nova_shockwave` | 3.733 m | 4.00 m | same class |
| `research_lab` / `landing_pad` | clip `sample` / `beacon` | `sample_cycle` / `beacon_cycle` | Godot imports those names without the `_cycle` suffix |

The root cause of the first six: `run_gate.mjs` rendered a filmstrip by calling
`playClip()` for every declared clip **and then exported the GLB**. Playing a
clip leaves the posed transforms on the graph, and the exporter writes the
current transforms as the rest pose — so the file shipped posed. Every three.js
check stayed green because every one of them measured the in-memory model, not
the file. Fixes:

* export happens **before** any clip is played;
* new check **`glb-matches-measured`** (20th) parses the exported GLB itself and
  requires its bounding box to agree with the in-memory measurement within 1%;
* the two clip names are now what the importer produces.

This is the honest lesson of the exercise: a green in-browser suite said nothing
about the file that ships. Only the engine did.

## 5. Running it

```bash
# 0. one-time: the pinned Chromium and libs (shared with tools/web_qa.mjs)
npm ci --prefix tools

# 1. wire catalog → src/registry.js (fails if the file is stale)
node tools/asset-forge/gate/gen_registry.mjs

# 2. build + measure + export + check every model
node tools/asset-forge/gate/run_gate.mjs
node tools/asset-forge/gate/run_gate.mjs --only reactor_core,pulse_rifle
node tools/asset-forge/gate/run_gate.mjs --no-glb        # faster, skips export

# 3. review sheets, reference-vs-render pairs, then animation filmstrips
node tools/asset-forge/gate/contact_sheet.mjs
node tools/asset-forge/gate/compare_sheet.mjs                # REF | RENDER, one row per asset
node tools/asset-forge/gate/anim_strip.mjs                       # every declared clip, 34 models → 72 strips
node tools/asset-forge/gate/anim_strip.mjs --only exo_operative --frames 8 --cell 220 --az 90

# 5. stage for the engine, then verify inside Godot — locally if the engine is
#    installed, otherwise the same verifier runs on CI via the [forge-verify]
#    commit marker and commits qa-evidence/forge/import-report.json back
node tools/asset-forge/gate/stage_into_game.mjs
tools/asset-forge/godot/run_verify.sh

# 4. look at one asset interactively (orbit, wireframe, spin, clip)
python3 -m http.server 800 --bind 0.0.0.0
#   http://localhost:800/tools/asset-forge/gallery.html?model=pulse_rifle
```

Outputs:

| Path | Committed? | What |
| --- | --- | --- |
| `tools/asset-forge/references/` | yes | one reference image per asset |
| `tools/asset-forge/src/` | yes | the models (code) |
| `tools/asset-forge/results.json` | yes | measured summary of the last full run |
| `tools/asset-forge/review/*.png` | yes | contact sheets used for visual review |
| `tools/asset-forge/review/anim/*.png` + `anim.json` | yes | one filmstrip per declared clip (6 sampled frames each) — the evidence that a clip actually moves the model |
| `tools/asset-forge/review/compare/*.png` + `compare.json` | yes | reference image next to the built render, one row per asset — the evidence for "matches the reference" |
| `game/assets/forge/**` + `forge_manifest.json` | yes | the imports staged inside the Godot project, plus the manifest the in-engine verifier checks |
| `tools/asset-forge/build/` | **no** (git-ignored) | renders, per-clip stills, `.glb` exports, full `quality-report.json` |

## 6. Status — what is real, what is not

Honest status at the time of writing:

* **36/36 model modules exist and build.** All render without errors.
* **Animation is now real and evidenced.** `gate/anim_strip.mjs` renders every
  declared clip as a six-frame filmstrip (`review/anim/`, 34 models → 72 strips).
  The hero's `aim` clip swings both arms from the hips to a forward aim over
  0.5 s, `fire` adds the recoil kick, the runner's `run` alternates the leg
  chain, the turret's `yaw_sweep` turns the head ±0.75 rad, and the rifle's
  `fire_recoil` pushes the receiver back. Frame times come from the clip's own
  duration, so a strip is a real playback sample, not a posed still.
* **20 assets pass the full gate; 16 fail on one check only** —
  `meta-matches-catalog`, because their reference image does not exist yet.
  Nothing else fails.
* **Reference images: 20 of 36** — the whole `world` family (16) and the whole
  `enemy` family (3) plus the Pulse Rifle. The image generator is capped at 10
  images per turn, so the remaining 16 (6 heroes, 6 weapons, 4 VFX) are
  scheduled for the next turns. `meta-matches-catalog` fails on exactly those
  16 today — deliberately; the gate does not skip a missing reference.
* **Visual review has been done on:** the 10 assets that have references
  (reactor, command centre, lab, depot, generator bank, landing pad, boss gate,
  turret, sensor tower, damaged transport) plus the hero and weapon families
  reviewed through contact sheets. Several of those reviews changed the model
  (see §4.1 and §7).
* **Verified inside Godot 4.7.2-stable: 36/36** (§4.3). Every asset is staged in
  `game/assets/forge/` and imports, with its declared clips and sockets intact
  and its measured size matching the manifest. That is engine-level import
  evidence, not a claim that the game *uses* them: no `.tscn` references a forged
  model yet, and the three `WeaponDefinition.model_scene` entries still point at
  `rifle.glb`. Wiring them into scenes is the next deliberate action.
* **Performance figures are from software rendering** (SwiftShader). Triangle
  and mesh counts are real and are what a mobile GPU budget should be read
  against; frame timings are not.
* **Axis convention is not uniform.** Characters are authored **+Z forward**
  (visor, jaw and chest plate on +Z — the glTF convention, and every enemy is
  built the same way), while the weapons are authored **muzzle toward −Z**. Each
  family is internally consistent and the renders are correct, but a hero
  holding a weapon socket-to-socket would point it backwards. Unify before the
  Godot import step: either rotate the weapon root by π on import or re-author
  the weapons +Z forward. This is a known, documented mismatch, not a hidden one.

## 7. Review notes (what changed because a human looked)

The review loop is now mechanical: `gate/compare_sheet.mjs` writes
`review/compare/<category>.png` with the reference on the left and the built
render on the right, one row per asset, plus `compare.json` listing which assets
have no reference yet. That sheet is what the notes below were written against —
"it looks close enough" is not a review, a side-by-side is.

* **Alien drone wreck** — first build was a grey box on thin legs with a glowing
  disc on top; the reference is a **domed hull rolled onto one side**, buried in
  soil, with overlapping armour petals, a broken segmented ring hoop, two ringed
  emerald sensor ports and exposed ribs. Rebuilt from the dome outward (6,808 →
  7,300 tris). Its plates now sit on the ellipsoid surface via
  `quaternion.setFromUnitVectors(+Y, normal)` — the first attempt mapped +Z and
  every plate stood on edge.
* **Enemy spawn gate** — was a rectangular steel gantry with no portal at all;
  the reference is a **pointed gothic arch** full of violet energy. Rebuilt on a
  quadratic ogive with tangent-aligned ribs, scale plates, red eye-lamps, a
  chevroned plinth per leg and a dim violet membrane with a hot rim. Three
  iterations were needed: the first arch segments were not rotated to the curve
  (floating bricks), the second crossed at the crown (basket weave), the third
  is one swept polyline rib.
* **Training drone** — was a pale dome with a blown cyan ball; the reference is a
  **dark armoured pod** wearing a wide cyan visor, a segmented skirt ring with
  four amber thruster nozzles and a stub cannon. Rebuilt and re-toned (4,328 tris).
* **Cover module / defence turret / runner** — see the earlier notes below.

* **Reactor** — first build was a black silhouette: `MeshStandardMaterial` with
  metalness 0.72 and no environment returns black. The viewer now builds a
  procedural gradient environment from palette tokens, and the plating order was
  inverted (silver dominant, graphite recesses) to match the reference.
* **Command centre** — the dish read as a billboard; `dish()` now builds a real
  bowl with a rim, feed horn and struts, and the mesh was cloned so
  `DoubleSide` cannot leak into a shared cached material.
* **Generator bank** — a large emissive area at full intensity reads **white**,
  not cyan. The columns carry a dim sleeve and a hot core instead.
* **Research lab** — an all-white shell read as an untextured box; now a
  two-tone silver/graphite shell with a ceramic crown plate.
* **Hero** — first pass was a toy: box legs, tiny hands, a blown-out visor of
  white. Rebuilt with tapered cylinder limbs, a chest core in a recess, a jawed
  helmet and a narrow visor bar.
* **Weapons** — receivers were flat bricks and the Nova's blast shield was a
  billboard; both now carry inset side panels, end collars, a vented top cover
  and a deflector lip.
* **Runner** — legs were detached tubes; rebuilt as one continuous
  hip→knee→hock→ankle chain of joint struts. Once its reference arrived the
  body was rebuilt again: the spine pitches forward 0.3 rad, the skull is a
  tapered wedge with a swept four-spine crest and side-set red eyes, the
  shoulder carapace carries outward spines, the dorsal crest runs from skull to
  tail, the tail is thick with barbs, and the green chest disc (which made it
  read as a friendly machine) was replaced by a narrow slit. 3,796 tris.
* **Alien Hunter** — `line` plating on a `panel2` secondary rendered as a black
  slab from the side (render coverage 0.0 at az 90, i.e. the silhouette
  disappeared into the background). Re-toned to `ink3` chitin over `line`
  ridges and given a dorsal shell ridge that grows backwards so the profile
  reads; 5,548 tris.
* **Shooter** — same problem at a high camera angle (coverage 3.9% at az 90/42);
  the hostile palette was retoned the same way and now passes.
* **Defence turret** — plan-symmetric, so 0° and 90° rendered almost the same
  (`views-differ` 0.109 vs a 0.12 floor). Given the lopsided hardware real
  turrets have: an ammunition drum on one flank, a conduit run and ladder rungs
  on the other, an offset rear hatch. 2,884 tris.
* **Cover module** — the first pass was three grey boxes with bolts — office
  furniture, not cover. Rebuilt around the profile: plinth, back-leaning face,
  canted shoulder wedges with a firing notch between them, braced feet, a stowed
  antenna on one end only. 4,160 tris.

## 8. Limits and next steps

1. **16 reference images remain** (the platform caps generation at 10 per turn):
   6 heroes, 6 weapons, 4 VFX. They are planned in batches of ten in §9.
2. **Wire the imports into the game** — import is proven (§4.3, 36/36), but no
   `.tscn` references a forged model yet and the three
   `WeaponDefinition.model_scene` entries still point at `rifle.glb`. That is the
   next action, and it will be reported with its own evidence (a scene that
   instantiates `res://assets/forge/...` and boots in the headless smoke tests).
3. **No skinning** — if a hero needs close-up deformation, the honest options
   are (a) export the hierarchy to Blender and rig it, or (b) keep it as a
   stylised low-poly character. This pipeline will not fake a skinned mesh.
4. **Single reference per asset** — one view cannot reveal hidden sides. The
   models are consistent and on-palette, not photogrammetrically faithful.

## 9. The remaining plan — batches of ten

The generator allows **10 images per session**, so the remaining 16 references are
planned as two batches and nothing is generated past ten in one session.

| Batch | Assets | Why this order |
| --- | --- | --- |
| **B1 (10)** | `exo_operative`, `exo_combat_tech`, `exo_void_runner`, `exo_neon_phantom`, `exo_rogue_engineer`, `exo_alien_hunter`, `nova_launcher`, `arc_shooter`, `scatter_blaster`, `rail_cannon` | The six hero skins are one silhouette with five documented themes — with references, "is the skin distinct enough" becomes a picture question instead of an opinion. The four weapons complete the visible loadout. |
| **B2 (6)** | `gravity_gun`, `arc_shooter_void_edition`, `pulse_bolt`, `nova_shockwave`, `arc_chain`, `impact_burst` | Remaining two weapons plus all four VFX. VFX are last on purpose: their references matter least (they are additive sprite-like effects judged in motion), so they are not allowed to hold up the character work. |

After B2 the forge holds **36/36 references**, and `meta-matches-catalog` becomes
a meaningful check for every asset instead of a to-do list. The 4 unused image
slots in B2 stay unused rather than being filled with variants nobody asked for.
