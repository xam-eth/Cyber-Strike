# PBR pipeline and visual verification

How the surfaces are made, and how we prove the result actually looks right
instead of assuming it does.

---

## 1. Textures: 2K, procedural, shared

`tools/asset-forge/src/runtime/textures.js` generates four maps at **2048²** by
default (`setTextureSize()` accepts 512–4096; `?tex=4096` in the viewer and
`--tex 4096` in the render script give the 4K set).

| Map | Content | Colour space | Export format |
| --- | --- | --- | --- |
| Base colour | neutral plate tones, grooves, grime, vertical weathering streaks | sRGB | JPEG |
| Tangent normal | derived from the same height field (Sobel → normalised TBN) | linear | PNG |
| ORM | R = ambient occlusion, G = roughness, B = metalness | linear | JPEG |
| Emissive grain | sparse hot speckle, ≤1024², only applied to `glow()` materials | sRGB | JPEG |

Three properties matter and are worth stating plainly:

1. **It is one set of four images for the entire forge.** Every material —
   40-odd of them across 16 models — points at the same four textures, tinted by
   its palette colour. A GLB therefore carries four images, not one set per
   material. That is what makes a 2K world export practical.
2. **Tiling is a sampler property, so `applyPbr()` clones the *view*, not the
   pixels** (`tiled()`). A 30 m road can tile 14× and a 1 m cover plate 1× while
   both still share one image buffer.
3. **The normal map is never JPEG.** JPEG ringing on a vector map is a visible
   shading artifact; colour and ORM data tolerate it at a tenth of the file size.
   The chosen MIME type is stamped on each texture (`userData.mimeType`) because
   that is what `GLTFExporter` reads.

Everything is deterministic: value noise + fBm from a fixed seed hash, no
`Math.random()`, no downloaded images, no image generator.

## 2. Verification gates

### 2.1 Per-asset gate — `node tools/asset-forge/gate/run_gate.mjs`

Twenty checks per asset, run in pinned headless Chromium (SwiftShader) so the
numbers are reproducible in CI:

- geometry: triangle and mesh budget, target height ±tolerance, non-degenerate
  bounds, socket presence, unique node names;
- **glb-matches-measured** — the exported GLB's own accessor bounds are parsed
  back out and compared with the measured scene (≤1 % drift). This check exists
  because it once failed: the exporter ran *after* a clip had been played, so the
  posed transform was baked in as the rest pose. See section 4.
- animation: every clip track targets a node that exists, and `views-differ`
  (a radial symmetry guard — three rendered views must not be identical);
- conformance: Khronos `gltf-validator`, 0 errors / 0 warnings. Two real defects
  had to be fixed to earn this: a normal map without a TANGENT attribute makes
  the file non-portable (so tangents are computed at finalize time), and
  `computeTangents()` writes zero-length tangents on uv-degenerate seams (so they
  are repaired against the vertex normal);
- framing: `render-coverage` and `render-luma` per view, with a per-entry coverage
  floor for props that are legitimately flat (the landing pad is 32 × 24 × 1.2 m,
  so it cannot fill a portrait frame the way a building does);
- determinism: the module is rebuilt from a cache-busted URL and the geometry
  hash must match;
- images: front / three-quarter / side renders exist and differ.

**Current result: 16 / 16 assets pass, 25 / 25 checks each, 0 failures.** Full
report in `tools/asset-forge/results.json`; review sheets in
`tools/asset-forge/review/`.

### 2.2 World renders — `node tools/asset-forge/gate/world_shot.mjs`

The per-asset gate proves props. This proves the *place*: it loads
`tools/asset-forge/world.html` in the same Chromium, waits for the real world
build, then renders eight authored cameras at 2048 × 1152 and optionally exports
the whole world as one GLB.

| Shot | Camera | What it is meant to prove |
| --- | --- | --- |
| `overview` | 96, 72, 118 | the whole world reads as one place; districts are distinct from the air |
| `arena` | 24, 13, 26 | reactor containment, hazard ring, cover, wave gates |
| `outpost` | −18, 15, 12 | command / lab / depot silhouettes and window bands |
| `extraction` | 24, 13, −12 | generator bank, pipe run and brass palette |
| `boss` | 0, 17, −38 | the 11 m docking gate as the north landmark |
| `perimeter` | 96, 26, 54 | wall rhythm, corner pylons, turret spacing |
| `wilds` | −16, 12, 74 | wreckage, crystals, flora, cracked pavement |
| `skyline` | 150, 26, −12 | horizon and wall silhouette against the sky |

**Current result:** 8 shots at 2048 × 1152, plus one `world.glb` of **29.44 MB**
carrying 64 instances / 173,028 triangles / 70 clips and exactly four embedded
images. Khronos validator on that file: **0 errors, 0 warnings**. Measurements in
`tools/asset-forge/build/world/world-report.json`.

The stills are then **looked at**, side by side with
`tools/asset-forge/references/world/*.png`. The rule for this branch is explicit:
a render that has not been viewed does not count as verified. Shape, texture
readability, PBR response and lighting balance are judged by eye, and the notes
below record what changed as a result.

### 2.3 Engine import — `forge-verify` CI job

`.github/workflows/godot-ci.yml` installs Godot 4.7.2, imports every staged GLB
and writes `qa-evidence/forge/import-report.json` (per-asset height, clip names,
socket names, pass/fail). The staging step (`stage_into_game.mjs`) copies the 16
world GLBs into `game/assets/forge/world/` and writes
`game/assets/forge/forge_manifest.json` — the contract the Godot verifier checks
the import against.

## 3. What viewing the renders changed

Each of these was found by looking at a PNG, not by reading code:

| Symptom in the render | Cause | Fix |
| --- | --- | --- |
| Sky went muddy brown, horizon had a hard seam | sky-dome gradient and fog used two different colours, and the amber haze band was 2× too strong | one `HORIZON` colour shared by background, fog and dome base; haze band 0.10 → 0.055 and recoloured to cyan |
| Ground was featureless at 100 m | all four maps were shared at `repeat = 1`, so a 320 m plane got one tile | `tiled()` views; ground now tiles ×64, roads ×14, plates ×1 |
| Outpost read as black boxes at night | hemisphere light 1.05 and no fill below the roofline | key 3.4 → 4.6, cyan fill 1.5 → 2.2, hemisphere 1.05 → 2.0, exposure 1.0 → 1.22 |
| Empty plate between districts | no scale cues on the ground | district aprons with emissive edges, 14 cargo crates, 22 bollards, 4 cable ducts |
| World looked like a diorama | almost nothing moved | per-component clips + `neon_frontier_motion.gd` runtime motion |

## 4. The defect worth remembering

`run_gate.mjs` used to play each clip for the animation filmstrip **and then**
export the GLB. `AnimationMixer` writes into the scene graph, so by export time
the last sampled pose had become the rest pose of the file. Godot then measured
different heights than three.js had: runner 1.444 m instead of 1.720 m, command
centre 8.004 m instead of 7.500 m.

The GLB export now happens **before** any clip is played, and the
`glb-matches-measured` check fails the gate if the two ever disagree again.

## 5. Reproducing everything

```bash
cd tools && npm ci                      # pinned Chromium + puppeteer + validator
node tools/asset-forge/gate/gen_registry.mjs
node tools/asset-forge/gate/run_gate.mjs                 # 20 checks × 16 assets
node tools/asset-forge/gate/world_shot.mjs --tex 2048    # 8 shots + world.glb
node tools/asset-forge/gate/contact_sheet.mjs            # per-asset review sheet
node tools/asset-forge/gate/stage_into_game.mjs          # copy GLBs into game/
```

Interactive viewing: serve the repo root and open
`/tools/asset-forge/world.html` — orbit camera, district toggles, clip
playback and a 1K / 2K / 4K texture switch.

```bash
python3 -m http.server 8080
# → http://localhost:8080/tools/asset-forge/world.html?tex=4096
```
