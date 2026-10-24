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

`node tools/asset-forge/gate/run_gate.mjs` — 17 checks per asset, all measured:

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
| `unique-node-names` | no duplicate node names (three.js and glTF resolve nodes by name — a duplicate animates the wrong object) |
| `geometry-finite` | non-degenerate bounding box |
| `materials-on-palette` | every authored colour is within 6/255 of a palette token |
| `deterministic-rebuild` | rebuilding the module produces an identical geometry hash |
| `glb-valid` | glTF 2.0 binary: magic, version, declared length, JSON chunk, ≥1 mesh, declared animations and sockets present as nodes |
| `render-coverage` | the asset covers 1.5–90% of the frame in each of three views (per-entry floors for thin props) |
| `render-luma` | luma spread ≥ 0.30 and std ≥ 0.045 — the render is not a flat silhouette |
| `views-differ` | the three views are not the same projection (best pair differs ≥ 0.12) |

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

# 3. review sheets
node tools/asset-forge/gate/contact_sheet.mjs

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
| `tools/asset-forge/build/` | **no** (git-ignored) | renders, per-clip stills, `.glb` exports, full `quality-report.json` |

## 6. Status — what is real, what is not

Honest status at the time of writing:

* **36/36 model modules exist and build.** All render without errors.
* **Reference images: 10 of 36.** The image generator is capped at 10 images per
  turn, and the remaining 26 (6 world props, 6 heroes, 7 weapons, 3 enemies,
  4 VFX) are scheduled for the next turns. `meta-matches-catalog` therefore
  fails on those 26 today — deliberately. The gate does not skip a missing
  reference.
* **Visual review has been done on:** the 10 assets that have references
  (reactor, command centre, lab, depot, generator bank, landing pad, boss gate,
  turret, sensor tower, damaged transport) plus the hero and weapon families
  reviewed through contact sheets. Several of those reviews changed the model
  (see §4.1 and §7).
* **GLB exports verified structurally** (chunks, meshes, node names, animations)
  — **not yet imported into Godot.** Importing is a separate, unverified step;
  nothing in this document claims the models are in `game/assets/` or referenced
  by a `.tscn`. That integration is the next deliberate action, and it will be
  reported with its own evidence.
* **Performance figures are from software rendering** (SwiftShader). Triangle
  and mesh counts are real and are what a mobile GPU budget should be read
  against; frame timings are not.

## 7. Review notes (what changed because a human looked)

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
  hip→knee→hock→ankle chain of joint struts.

## 8. Limits and next steps

1. **26 reference images remain** (10 per turn), then a full gate run.
2. **Godot import** — the exported GLBs need importing into
   `game/assets/forge/`, with scale/pivot verification in-engine and a
   replacement of the three `WeaponDefinition.model_scene` entries that today
   all point at `rifle.glb`.
3. **No skinning** — if a hero needs close-up deformation, the honest options
   are (a) export the hierarchy to Blender and rig it, or (b) keep it as a
   stylised low-poly character. This pipeline will not fake a skinned mesh.
4. **Single reference per asset** — one view cannot reveal hidden sides. The
   models are consistent and on-palette, not photogrammetrically faithful.
