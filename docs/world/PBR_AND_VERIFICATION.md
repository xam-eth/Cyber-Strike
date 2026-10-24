# Surfaces and verification

How the world's materials are made, and the exact checks that prove what is
claimed here. Every number below was produced by the commands shown.

## 1. Where the surfaces come from

There is no texture synthesis anywhere in this pipeline. Three real surface
sources are used as authored:

| Source | Resolution | Maps | Used by |
| --- | --- | --- | --- |
| Power Plant baked set | 1024² (65 maps) | albedo + normal + roughness, MR-roughness packed | every set piece and the landmark |
| Photographed ground plate | 1920² | albedo + normal + roughness | the 240-tile floor |
| Kenney Space Kit | — | none (flat colour per material) | the modular hardware |

The kit ships untextured painted metal, so `realModels.gradeKit()` grades its
existing material colours onto the installation's steel-and-amber ramp **in
sRGB** (the loader delivers linear values; grading in linear made every kit part
read white). It clones the material, keeps the geometry, and sets
`roughness 0.64 / metalness 0.34` so both libraries answer the key light the same
way. No map is created, and no map is replaced.

The ground plate is photographed at noon, so its albedo multiplier is lifted
above 1.0 (`3.1, 2.9, 2.5`) and metalness dropped to 0 to read as worn concrete
under a dusk rig. That is a grade on the *tint*, not a new texture — the map is
still the scanned one.

## 2. The review renders

```bash
node tools/asset-forge/gate/world_shot.mjs
```

produces nine photographs at **2048 × 1152** plus the re-exported world:

| Shot | What it proves |
| --- | --- |
| `overview` | the whole field, the fence, the Power Plant outside the east wall |
| `arena` | reactor assembly, deck plates, cover modules, wave gates |
| `outpost` | command centre, lab, depot, sensor towers |
| `extraction` | generator bank on its real concrete pad |
| `powerplant` | the landmark's scanned surfaces at close range |
| `boss` | the 20 m ribbed docking gate |
| `perimeter` | fence, pylons, turret line |
| `wilds` | drone wreck, crystals, flora, craters |
| `skyline` | the world read from outside the fence |

Each run prints and enforces:

```
world: 64 instances · 254,719 tris · 119 clips · 47 real GLB files · built in ~2.5 s
```

* **Asset-policy gate** — `window.__world.proceduralMeshes()` walks the live scene
  and returns every mesh without `userData.realSource`. A non-empty result fails
  the run (`FAIL asset policy — N mesh(es) are not from a real GLB`) *before* any
  screenshot is written. This is the mechanical version of "no code-built assets".
* **Clip binding** — clips are named `<Instance>__<Part>`; the gate fails if a
  motion rule targets a node that does not exist, and the browser console is
  clean of `PropertyBinding: No target node found` warnings (those warnings were
  a real bug: tracks were being double-prefixed and silently orphaned).
* **Determinism** — placement comes from `layout.js`; scatter tilt is a hash of
  position and name, so two builds of the same commit are byte-comparable.

## 3. The exported file

```bash
node tools/asset-forge/gate/stage_world_into_game.mjs
```

reads the re-exported `build/world/world.glb`, re-encodes its 84 photographic maps
as quality-92 JPEG (the exporter writes PNG, which made a 61 MB file), and stages
it at `game/assets/forge/world/world.glb` with a manifest of measured facts:

```
world      285.032 × 24.584 × 188.986 m · 153,885 tris · 119 clips · 530 meshes · 21.6 MB
sockets    4/4 kept as named nodes
```

The in-file triangle count is lower than the drawn count because the exporter
shares geometry between identical clones; nothing is dropped (530 meshes in, 530
meshes out — an earlier attempt with `prune()` did drop 103 of them and was
removed for that reason).

## 4. Engine verification

`tools/asset-forge/godot/verify_import.gd` runs inside Godot 4.7.2, imports the
project headlessly, then for the manifest entry:

1. `load()`s `res://assets/forge/world/world.glb` and instantiates it,
2. measures the real AABB in metres and compares it with the manifest target,
3. reads the imported `AnimationPlayer` and checks the declared clips exist,
4. finds every declared spawn socket by name,
5. writes `qa-evidence/forge/import-report.json` and exits non-zero on any failure.

CI job **forge-verify** (`.github/workflows/godot-ci.yml`) runs it on any commit
whose message contains `[forge-verify]`. It is the check that the world is not
merely renderable in a browser but importable by the game.

## 5. What is deliberately not claimed

* The kit is untextured by design; its surfaces are *graded*, not scanned, and the
  docs say so instead of implying otherwise.
* The Power Plant's maps are 1024², the ground plate 1920². Nothing here is
  upscaled and presented as native 4K.
* Textures are embedded in `world.glb`, so the file is self-contained and opens in
  any glTF viewer without side-car files.
