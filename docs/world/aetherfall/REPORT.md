# SH-01 "Aetherfall, the Broken Frontier" — Technical Report

World production build for **EXOCONFLICT: STELLAR HORIZON** (Godot 4.7, mobile-first
third-person shooter, Mobile renderer). Branch `arena/707b30d9-cyber-strike`.

---

## 1. What was delivered

| Artifact | Path |
|---|---|
| World scene | `game/scenes/worlds/aetherfall.tscn` |
| World script | `game/scripts/worlds/aetherfall_world.gd` |
| Registry entry | `game/resources/worlds/aetherfall.tres` |
| Mood | `game/scripts/worlds/world_mood.gd` (`"aetherfall"` entry) |
| UI plate | `game/assets/ui/world_aetherfall.jpg` (1280×720, 22 KB) |
| Modular kit — 27 GLBs | `game/assets/world/aetherfall/models/*.glb` (2.32 MB total) |
| Modular kit — 7 texture maps | `game/assets/world/aetherfall/materials/*.png` |
| Measurements | `game/assets/world/aetherfall/measurements.json` |
| Placement layout | `game/assets/world/aetherfall/layout.json` (251 placements) |
| Asset manifest | `game/assets/world/aetherfall/MANIFEST.md` |
| Blender forge (asset build) | `tools/blender/build_aetherfall.py` |
| Blender forge (assembly + shots) | `tools/blender/assemble_aetherfall.py` |
| Screenshots | `docs/world/aetherfall/shots/*.png` |

---

## 2. The world

One vertical theatre built entirely from 27 self-contained modules placed by
`layout.json`. Nothing is authored in Godot: no coordinate is written twice.

- **Central Energy Tower** at `(0, 0, -26)`, base `tower_foundation` through three
  tapering `tower_tier` rings to `tower_spire` at Y 29, with an emissive cyan
  `energy_core`. Approx. **48.7 m** tall — the world's landmark, and the light
  that reads across the canyon.
- **Main combat deck**, 76 × 36 m at Y 0 on the south canyon rim, tiled by 87
  `deck_6x6` slabs with 36 `deck_edge` perimeter pieces.
- **East–west canyon** centred on Z ≈ −18, floor at Y ≈ −46, filled with 11
  `cloud_puff` volumes so it reads as haze rather than a hole.
- **Elevated bridges**: east bridge at Y 5 (3 `bridge_deck` spans on pylons at
  X 44 and X 60, 3 `railing`) reaching a `damaged_slab` broken end at X 64.
- **West catwalk** at Y 6.5 (4 `walkway_deck`) on 17 `pillar` supports out to X −59.
- **Lower canyon approach**: a switchback `deck_6x6` industrial road descending
  south from Z 19 to Z 35, Y 0 → −6.4, running past 10 `cliff_face` and 13
  `terrain_chunk`.
- **Distant skyline**: 7 `background_silhouette` silhouettes at X ±150, Z −190.
- **Verticality**: five levels, Y −6.4 (canyon floor) → Y 29 (spire) → Y 48.7
  (tower top).
- **Routes** (in `layout.json`, mirrored as `Route_*` waypoint nodes): `central`,
  `east_bridge`, `west_catwalk`, `lower_approach`.
- **Spawns**: `[-30, 1.2, 14]` and `[30, 1.2, 14]`, on the south deck.
- **Cover**: 7 authored cover spots plus 4 `cover_barrier`, 3 `cover_machine`,
  2 `access_gate`, 5 `machinery`, 2 `cooling_vent`.

### 2.1 Scale note

The kit is **5,604 triangles across 27 modules** — deliberately low, on the order
of a mobile target. "Photorealistic" here comes from the lighting rig, the fog
and the energy materials, **not** from mesh density. The texture maps are
procedurally generated with numpy/Pillow (see §7); they are not scanned assets.

---

## 3. Pipeline

Blender 4.5 headless (`bpy`) drives two scripts:

1. **`build_aetherfall.py`** — generates the texture maps, builds the 27 modules
   with real boolean/modifier geometry (`grid_mesh`, `mcyl`, `bmesh` grids),
   applies 13 materials and 7 PNG maps, centres each module on its own AABB,
   and exports one GLB per module with `export_yup=True` / `export_apply=True`.
   Writes `measurements.json`.
2. **`assemble_aetherfall.py`** — imports every GLB into a dedicated `M_<key>`
   collection, then **duplicates** real objects (not `COLLECTION` instances) into
   the scene per placement, setting `location` / `rotation` / `scale` and copying
   modifiers by `bl_rna` property name. Adds sky, Sun, area fill light, renders the
   five shots, and writes `layout.json`.

### 3.1 Bugs found and fixed (the ones that matter)

- **`hide_render` on a module master also hides its `COLLECTION` instances.**
  Every shot rendered as a uniform single-colour frame. Fixed by duplicating real
  objects instead of instantiating collections.
- **`o.matrix_world` on a stale depsgraph segfaults** (EXIT 139). Fixed by never
  reading `matrix_world`: `asset_bounds()` transforms `o.bound_box` corners with
  `_rot_mat(o.rotation_euler)` × scale + location.
- **`Euler @ Euler` is unsupported** in this `bpy` build. Fixed with
  `(a.to_matrix() @ b.to_matrix()).to_euler('XYZ')`.
- **No `HEMI` light type** exists in this build. The fill light is an `AREA`,
  energy 260.0, size 60.0.
- **`img.save()` writes blank PNGs**; Pillow's `fromarray().save()` works.
- **`bpy.ops` slice-replacement data loss** — verified with `grep -n "^def |^ASSETS"`
  after every programmatic edit.

---

## 4. Godot integration

`aetherfall_world.gd` reads `layout.json` + `measurements.json` and:

- instantiates each module GLB at the authored transform (251 nodes under
  `AetherfallWorld`),
- adds **box colliders derived from the same measurements** the mesh was centred
  on — so a collider and its mesh agree by construction. Decorative geology
  (`terrain_chunk`, `cliff_face`, `rock_boulder`, `background_silhouette`,
  `cloud_puff`, `debris_cluster`) carries **no** collider: a rock that blocks a
  route is a design bug,
- walkable roles (`deck_6x6`, `deck_edge`, `walkway_deck`, `bridge_deck`,
  `railing`) get a **slab** whose top face is the walking surface,
- adds spawn markers, route waypoints and cover markers,
- lights itself from the `aetherfall` mood unless it is wrapped by
  `mission_world.tscn`, in which case the wrapper's rig is used (no double lights).

Registry wiring:

- `WorldDefinition.DEFINITION_PATHS` / `DEFINITION_IDS` — `&"aetherfall"` added,
  so `load_all_definitions()` and the launcher see it.
- `mission_world.gd` — `WORLD_SCENES["aetherfall"] = "res://scenes/worlds/aetherfall.tscn"`,
  added to `WORLD_ORDER`, and `WORLD_FIELDS["aetherfall"] = Vector2(76, 36)` centred
  on `(0, 0)` — the deck, not the canyon.
- `WorldMood.MOODS` — an `aetherfall` entry. **Deliberately not added to
  `MOOD_ORDER`**: `tests/mission_world_smoke.gd` asserts exactly three distinct
  mission-world key colours, and `tests/world_palette_smoke.gd` walks
  `MOOD_ORDER` with hardcoded expectations. Adding a fifth theatre would break
  both.

**Player-controller contract** (read from `player_controller.gd` and
`camera_rig.gd`): world colliders publish on **layer 1**; enemy colliders are
expected on layer 3 (the aim ray mask is 3). `CameraRig/YawPivot/PitchPivot/
SpringArm3D/Camera3D` and `VisualRoot/WeaponSocket/Muzzle` are unchanged — the
world provides only collision, mesh and lighting.

---

## 5. Screenshots

Five 1280×720 frames in `docs/world/aetherfall/shots/`:

| File | Camera | Content |
|---|---|---|
| `01_hero_tower.png` | `(0,8,36)` → `(0,26,-26)`, 42 mm | The Energy Tower against the canyon |
| `02_combat_platform.png` | `(-26,10,18)` → `(0,3,-8)` | Main deck, cover, tower beyond |
| `03_lower_approach.png` | switchback descent | Canyon road and cliffs |
| `04_canyon_vista.png` | `(0,-18,54)` → `(0,-2,-30)` | Looking up the canyon at the tower |
| `05_layout_overview.png` | top-down `(0,96,104)`, 30 mm | Whole theatre |

**Verification performed:** pixel means `0.683 / 0.681 / 0.641 / 0.229 / 0.674`,
stds `0.069 / 0.070 / 0.137 / 0.125 / 0.078`, min 0.00, max 0.69–0.86, and all five
MD5s distinct. That confirms the frames are not blank, not uniform, and not
duplicates.

**This is a hard limit and it must be read as such:** these were rendered by
**Blender Cycles on CPU (12 samples)**, *not* by Godot. The images show the
*assembled scene* — the same 251 placements, the same transforms — but they are
**not** screenshots of the running Godot project and they do not prove the Godot
scene loads, imports, or renders.

---

## 6. Performance measurements

| Measurement | Value | Tool |
|---|---|---|
| Modules | 27 GLBs, 2.32 MB | `du` |
| Total triangles | 5,604 | `measurements.json` |
| Placements | 251 | `layout.json` |
| Rendered shots | 5 × 1280×720 | Blender Cycles |
| Per-frame render time | ~43 s, 12 samples, CPU | Blender |
| Texture maps | 7 PNGs, 3.16 MB (5 × 512², 2 × 256²) | `materials/` |
| Godot scene build | **not measured** | — |

The Blender timings above are a *forge* cost, not a runtime cost. **No runtime
measurement exists**: Godot could not be executed in this sandbox (§7).

---

## 7. Completed / Incomplete / Unverified

### Completed

- 27 distinct modular meshes, all exported to GLB with real per-module geometry.
- 13 materials, 7 procedurally generated PNG maps.
- `measurements.json` + `layout.json` as the single source of truth for size and
  placement.
- A 251-placement, five-level, non-flat theatre: central landmark tower,
  connected elevated bridges, foreground/middle/background, authored cover,
  spawns and routes.
- Godot scene, script, registry entry, mood, UI plate.
- Collision: box colliders from measurements; walkable slabs; set dressing
  excluded.
- Integration with `mission_world.tscn`, `WorldDefinition`, `WorldMood`,
  `WorldSelection`.
- Asset manifest, technical report, five reference renders.
- `gdlint` clean on `aetherfall_world.gd`, `mission_world.gd`, `world_mood.gd`.

### Incomplete

- **No screenshot from the running Godot scene.** The directive asks for them;
  they do not exist. Blender renders are a substitute and are labelled as such.
- **No runtime performance numbers** (frame rate, draw calls, triangle budget,
  memory). Nothing was ever executed.
- **No navmesh.** `layout.json` carries routes and cover, but no navigation
  mesh was generated or validated — `validated collision/navigation` is
  therefore only half met (collision is authored; navigation is not).
- **No in-engine playthrough** of the bridges, catwalk or descent. The fenced
  field is the 76 × 36 deck (`WORLD_FIELDS["aetherfall"]`); the elevated routes
  and the canyon sit **beyond the fence**. They are built, lit and collided, but
  the player cannot reach them under the current arena bounds.
- **No enemy placement / scripted combat.** The world has spawns and cover; it
  has no `runner_enemies` / `shooter_enemies` colliders on layer 3, so the
  player-controller's aim and EMP paths have nothing to target.
- **Texture maps are procedural**, not scanned or licensed assets.

### Unverified (could not be tested here)

- **Whether the 27 GLBs import in Godot.** `.import` files are not committed (the
  repo convention); Godot generates them on first open. The GLBs were produced by
  Blender's own glTF exporter and load back through `bpy` in the assembly step,
  which is evidence but not proof.
- **Whether `aetherfall_world.gd` runs without error.** It passes `gdlint` but
  has never been parsed by the Godot compiler. GDScript 4.7 semantics
  (`Dictionary.get` defaults, `look_at_from_position`, `Marker3D`,
  `WorldEnvironment`) are written to spec, not executed.
- **Whether `_has_mission_wrapper()` correctly detects the wrapper.** It compares
  the parent node name to `"MissionWorld"`. If `main.tscn` is restructured, the
  scene would build its own lights in addition to the wrapper's.
- **Whether the fenced field matches the deck visually.** The fence is a 76 × 36
  box from `WORLD_FIELDS`; the deck tiles were placed in Blender. Both come from
  the same layout but were not cross-checked in-engine.
- **Whether the colliders line up with the meshes.** They are derived from the
  same `measurements.json` numbers, but no overlap test was run.

### Why Godot could not be run

`scripts/install_godot.sh` fails with `SSL_ERROR_SYSCALL`. The release binaries
live on `release-assets.githubusercontent.com` / `objects.githubusercontent.com`,
both blocked by this sandbox's egress policy. There is no apt package and no
binary on disk. This was retried once and abandoned — **do not retry**.

---

## 8. Honest summary

The **geometry and the layout are real and complete**: 27 modules, 251
placements, five vertical levels, one landmark tower, two elevated routes, a
canyon, a descent road, seven texture maps and thirteen materials, all driven
from two JSON files.

The **Godot side is written and consistent** with the existing conventions —
registry entry, mood, scene, script, plate, launcher wiring — and lints clean.
It has **never been executed**. Everything above that requires the engine
(screenshots, frame rate, navmesh, in-engine playthrough, collider overlap) is
either missing or unverified, and the report says so rather than implying it.

The single highest-value next step is a machine with Godot 4.7 installed:
open the project, let it import the 27 GLBs, run `res://scenes/worlds/aetherfall.tscn`,
and confirm the scene builds and the deck is walkable.
