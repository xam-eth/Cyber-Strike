# Surfaces and verification

How the three worlds' materials are made, and the exact checks that prove what is
claimed here. Every number below was produced by the commands shown.

## 1. Where the surfaces come from

There is no texture synthesis anywhere in this pipeline. Four real surface
sources are used as authored:

| Source | Resolution | Maps | Used by |
| --- | --- | --- | --- |
| Power Plant baked set | 1024² (65 maps) | albedo + normal + roughness, MR-roughness packed | the foundry's plant, set pieces, landmark |
| Photographed ground plate | 1920² | albedo + normal + roughness | Frostline and Emberfall floors |
| Kenney Space Kit | — | none (flat painted colour per material) | modular hardware, all three worlds |
| Kenney Nature Kit | — | none (flat painted colour per material) | Verdant's trees, moss, grass tiles, floor |

Both Kenney libraries ship **untextured painted surfaces**, and they are *graded*,
not scanned. `realModels.gradeKit()` re-maps the kit's existing material colours
onto the world's steel-and-accent ramp **in sRGB** (the loader delivers linear
values; grading in linear made every kit part read white), clones the material,
keeps the geometry, and sets `roughness 0.64 / metalness 0.34`. Organics are
graded by a *separate* function, `gradeNature()`, which **lerps** the authored
foliage hue 10% toward the world's moss tone instead of replacing it — running
foliage through the metal ramp turned Verdant's canopy near-black, and the
difference is the whole reason the two functions exist.

The ground plate is photographed at noon, so its albedo multiplier is lifted or
pushed down per theme and metalness dropped to 0. That is a grade on the *tint*,
not a new texture — the map is still the scanned one. Tints are authored in sRGB
(`THREE.SRGBColorSpace`) for the same reason the kit grades are.

The plant and the set pieces are left exactly as their author baked them.

## 2. The review renders

```bash
node tools/asset-forge/gate/world_shot.mjs                       # all three worlds
node tools/asset-forge/gate/world_shot.mjs --world verdant --shot overview
```

produces **15 photographs** at **2048 × 1152** (`build/worlds/<id>/<shot>.png`)
plus three GLBs and `build/worlds/worlds-report.json`:

| World | Shots |
| --- | --- |
| Frostline Relay | `overview`, `core`, `station`, `defence`, `icefield` |
| Verdant Bloom | `overview`, `shrine`, `station`, `grove`, `wreck` |
| Emberfall Foundry | `overview`, `smelters`, `yard`, `drill`, `plant` |

Each run prints what it built:

```
frostline  10 roles · 36 instances · 113,086 tris · 61 clips · 35 real GLBs · 1427 ms
verdant    12 roles · 92 instances · 128,182 tris · 156 clips · 44 real GLBs ·  937 ms
emberfall  10 roles · 31 instances · 227,811 tris · 31 clips · 29 real GLBs · 2023 ms
```

* **Asset-policy gate** — `window.__world.proceduralMeshes()` walks the live scene
  and returns every mesh without `userData.realSource`. A non-empty result fails
  the run (`FAIL asset policy — N mesh(es) are not from a real GLB`) *before* any
  screenshot is written. This is the mechanical version of "no code-built assets",
  and it runs per world.
* **Clip binding** — clips are named `<Instance>__<Part>`; the gate fails if a
  motion rule targets a node that does not exist, and the browser console stays
  clean of `PropertyBinding: No target node found` warnings (those warnings were
  a real bug: tracks were being double-prefixed and silently orphaned).
* **Determinism** — placement comes from each world's data module; scatter tilt
  is a hash of position and name, so two builds of the same commit are
  byte-comparable.

## 3. The exported files

```bash
node tools/asset-forge/gate/stage_worlds_into_game.mjs
```

reads each re-exported `build/worlds/<id>/world.glb`, re-encodes its photographic
maps as quality-92 JPEG at 2048² (the exporter writes PNG, which made a 61 MB
file), and stages it at `game/assets/forge/worlds/<id>.glb` with a manifest of
measured facts:

| World | Size | Triangles | Meshes | Maps | Clips | Staged |
| --- | --- | --- | --- | --- | --- | --- |
| Frostline Relay | 171.6 × 19.5 × 175.0 m | 113,086 | 182 | 16 | 61 | 5.8 MB |
| Verdant Bloom | 180.3 × 16.5 × 168.4 m | 128,182 | 221 | 10 | 156 | 3.0 MB |
| Emberfall Foundry | 320.0 × 24.6 × 196.4 m | 227,811 | 400 | 84 | 31 | 20.5 MB |

The stage step also runs the **Khronos glTF validator** on the exact bytes Godot
imports and fails on any error, because a file only three.js accepts is not a
shipping asset:

```
frostline  … 5.8 MB · glTF 0E/0W
verdant    … 3.0 MB · glTF 0E/0W
emberfall  … 20.5 MB · glTF 0E/0W
```

The in-file triangle count is lower than the drawn count because the exporter
shares geometry between identical clones; nothing is dropped (an earlier attempt
with `prune()` did drop 103 meshes and was removed for that reason). Textures are
embedded, so each GLB opens in any glTF viewer without side-car files.

## 4. Engine verification

Three checks run inside Godot:

* **`tests/mission_world_smoke.gd`** — for **each** world: the staged GLB imports
  and instances, carries its mesh and map floors, adds **no mesh outside the
  GLB**, runs its authored clips, is lit by its own mood (key/fill/rim/accent
  colours, sky, ambient, fog and density compared against `WorldMood`, plus an
  intent check per world — frostline's key is cooler than it is warm, verdant's
  is a hot green-white, emberfall's is orange), keeps a collision floor the size
  of that world's own field, and — across the three — no two key colours are the
  same. Then the gameplay scene is walked end to end on the default world.
* **`tests/world_palette_smoke.gd`** — every staged world keeps its material
  library (12 / 8 / 40 distinct materials) and its photographic maps (8 / 4 / 40
  textured surfaces) after import; the three moods declare different skies, key
  lights and fog densities; and the design-token palette still matches.
* **`tools/asset-forge/godot/verify_import.gd`** — runs inside Godot 4.7.2,
  imports the project headlessly, then for every manifest entry: `load()`s it,
  measures the real AABB, compares against the manifest, reads the imported
  `AnimationPlayer` for the declared clips, finds every declared spawn socket,
  and writes `qa-evidence/forge/import-report.json`. CI job **forge-verify**
  (`.github/workflows/godot-ci.yml`) runs it on any commit whose message contains
  `[forge-verify]`.

## 5. What is deliberately not claimed

* The Kenney libraries are untextured by design; their surfaces are *graded*, not
  scanned, and the docs say so instead of implying otherwise.
* The Power Plant's maps are 1024², the ground plate 1920². Nothing here is
  upscaled and presented as native 4K.
* Nothing in this build came out of an image-to-3D model — see §6.

## 6. Why there is no generative asset in this build

The intended pipeline was *generate an image → convert it to a real mesh*
(TRELLIS.2 / Hunyuan3D 2.0) and then place the result. It cannot run on the
machine this branch was produced on, and that was **measured, not assumed**:

| Requirement | Measured here |
| --- | --- |
| CUDA device | none (`nvidia-smi` absent, no `/dev/nvidia*`) |
| RAM | 3 GB total |
| `huggingface.co`, `cdn-lfs.huggingface.co` | connection fails (HTTP `000`) |
| `download.pytorch.org`, `www.modelscope.cn` | connection fails (HTTP `000`) |
| `pypi.org`, `github.com` | reachable (HTTP `200`) |

So the weights are unreachable and there is no hardware to run them on. Rather
than fake the step — which is exactly what `img2threejs` does, emitting
procedural geometry that only *looks* like the reference — every mesh in this
build is a **pre-authored, licensed, hand-modelled GLB** from the libraries in
§1. The image budget for this session (10 images) is untouched.

The pipeline is ready for that step, though, and adding it does not change any
downstream code:

`generate image (≤10/session)` → `img2mesh (TRELLIS.2 on a CUDA host)` →
`export binary .glb with PBR maps` → drop it in `game/assets/world/real/hero/` →
add a `hm_` prefix to `realModels.js` → reference it from a role in `roles.js`.

Everything after the export is the machinery this repository already runs: the
asset-policy gate tags and verifies it, the moods grade it, the capture gate
photographs it, and `verify_import.gd` proves Godot imports it.
