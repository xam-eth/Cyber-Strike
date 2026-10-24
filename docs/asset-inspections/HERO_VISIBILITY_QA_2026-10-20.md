# BUG 1 — "hero not rendered in gameplay while the weapon is visible"

**Verdict: NOT REPRODUCED on the current build.** The avatar is in the scene, is
skinned to the imported 79-bone skeleton, is inside the camera frustum, is not
occluded, and is **actually drawn and animated in a real WebGL frame** of the
committed browser build. Evidence below; every number was measured, none of it
was inferred from an inspector or from a green test suite.

This is deliberately *not* written as "fixed". Nothing was broken in the path
that draws the hero, so nothing there was changed. One genuine defect *was*
found in the same code and is fixed (§4).

The gate that used to block this claim: the headless Godot runner has no
rasteriser, so no smoke test could say whether the avatar is drawn. That gate is
now open — §3 uses the committed `web/` payload in the pinned headless Chromium.

---

## 1. The runtime test that would have caught it

`tests/hero_visibility_smoke.gd` (new, 21 assertions, all passing). It
measures, inside the real `main.tscn`, every mechanism that decides whether the
avatar reaches the screen:

| Check | Measured result |
|---|---|
| model instance under `VisualRoot` | `CharacterModel`, all ancestors visible (`ModelPivot / VisualRoot / Player / Main`) |
| layer vs camera cull mask | layer 1 AND 1048575 ≠ 0 |
| skeleton + skin | 79 bones, `skin=true`, `skeleton=..` |
| bones actually move while a clip plays | yes; the clip name alone is not accepted |
| **posed** silhouette | **1.79 m tall, 0.66 m wide, 0.52 m deep**, feet at the player's floor (y = −0.02), determinant +5.64 (not mirrored) |
| near/far clipping | nearest corner **6.60 m** in front of a 0.08 m near plane |
| occlusion | raycast camera → hero: **clear** |
| on-screen at 5 aspects | inside the frame and **21 % of screen height** at 1280×720, 390×844, 375×667, 844×390, 667×375 |
| surface winding vs vertex normals | **0 % disagreeing** (calibrated against a built-in `BoxMesh`, which is what makes this number mean anything) |
| material | opaque, `alpha=1.00`, albedo texture `hero_HERO_3d_model_basecolor.jpg` loaded |
| weapon relationship | socket **88 mm** from the `R_Hand` bone, muzzle **0.42 m in front of the grip**, both in frustum |
| fallback | placeholder capsule exists and is **hidden** |

The posed silhouette is computed as `Σ wᵢ · (pose_globalᵢ · inverse(rest_globalᵢ)) · v`
over all 23 310 vertices. The naive form (dropping the inverse rest transform)
reports a 2.6 m "hero" from a 1.78 m model — worth knowing before anyone
measures this again.

"Camer/aniation never hide the hero" is a claim about every state, so the test
re-measures the framing in **idle, ADS held, hip fire, reload and defeated**:
nearest corner 6.59–6.80 m, in frustum every time, height 1.79 m every time.

## 2. What the geometry says the screen should show

`?qa_camera=1` on the web build reports the live camera:

```
Camera QA: aim=false blend=0.00 fov=66.0 arm=4.20 hit=4.20
           cam=(0.55, 2.304712, 12.13937) player=(0.0, 0.0, 8.0) clip=idle
CharacterVisual: model=CharacterModel fitted_height=1.780m scale=1.780 rig=Armature clips=10 fallback=no
```

`arm=4.20 hit=4.20` → the spring arm is at full length, so nothing is between
the camera and the player. Projecting the measured 1.79 m silhouette through
that transform (vertical FOV 66°, aspect 16:9) puts the avatar at
**x 518…616, y 349…593** — 34 % of frame height, left of centre because of the
0.55 m shoulder offset.

## 3. What the real browser frame actually shows

`node tools/qa_avatar_shot.mjs --viewport 1280x720 --frames 4 --gap 2200`
opens the committed `web/` payload in the pinned headless Chromium
(SwiftShader WebGL 2), waits for `Encounter: Explore safe`, and writes frames
plus every console line. Then
`python3 tools/avatar_motion_map.py <frames> --out motion.png` scores each pixel
by how much its luma moved across the burst: static geometry scores ~0, anything
animating lights up.

| | 1280×720 | 390×844 |
|---|---|---|
| predicted avatar bbox | x 518…616, y 349…593 | x 111…178, y 422…595 |
| measured motion bbox | **x 520…689, y 308…571** | **x 111…219, y 376…580** |
| motion height | 264 px (36.7 % of frame) | 205 px (24.3 % of frame) |
| pixels above threshold | 11 180 (1.21 %) | 3 354 (1.02 %) |

The left edge matches the prediction to within 2 px at both aspects. The motion
bbox is wider and a little taller than the avatar's own bbox because the map
also catches other animated things in the frame (HUD plates, world emissives) —
that is expected, and it is why the map is read as a picture, not as a number.
Read as a picture it is a standing human figure: head at the top, torso, then
two legs that separate below the hips and end on the floor line.

Evidence committed with this report:

* [`qa-frames/hero-visibility-1280x720-frame1.png`](qa-frames/hero-visibility-1280x720-frame1.png) — the real WebGL frame
* [`qa-frames/hero-visibility-1280x720-motion.png`](qa-frames/hero-visibility-1280x720-motion.png) — its motion map
* [`qa-frames/hero-visibility-390x844-frame1.png`](qa-frames/hero-visibility-390x844-frame1.png) — portrait frame
* [`qa-frames/hero-visibility-390x844-motion.png`](qa-frames/hero-visibility-390x844-motion.png) — its motion map

## 4. One real defect found on the way, and fixed

`ModelFitter.apply_overlay_material()` was called with `VisualRoot` as its root.
`VisualRoot` already contains `WeaponSocket/MuzzleFlash/*` at that point, so the
near-black grow outline that exists to give the avatar a readable silhouette was
also being applied to the muzzle-flash VFX:

```
WeaponSocket/MuzzleFlash/FlashCone     mat transparency=1 blend=1  overlay=StandardMaterial3D (the outline)
WeaponSocket/MuzzleFlash/FlashCore     mat transparency=1 blend=1  overlay=StandardMaterial3D (the outline)
WeaponSocket/MuzzleFlash/FlashGlint    mat transparency=1 blend=1  overlay=StandardMaterial3D (the outline)
WeaponSocket/MuzzleFlash/FlashSpark_0  mat transparency=1 blend=1  overlay=StandardMaterial3D (the outline)
WeaponSocket/MuzzleFlash/FlashSpark_1  mat transparency=1 blend=1  overlay=StandardMaterial3D (the outline)
```

Those five meshes are additive VFX. An opaque `CULL_FRONT` shell grown around a
muzzle flash paints a dark blob over the shot instead of a rim around the body.
`character_visual.gd` now outlines the fitted model and the fallback capsule
only; the weapon model is spawned afterwards and never carried the outline.
Re-measured after the change: the hero mesh keeps the outline, the five flash
meshes report `overlay=null`.

### The 34 % and the 21 % are both right — reconciled

The report's §2 projects 34 % of frame height from a `?qa_camera` sample; the
runtime test measures 21 %. They are two camera states, and the two states are
now both on record:

| | headless `main.tscn` (the test) | browser `?qa_camera` sample |
| --- | --- | --- |
| camera | (0.55, 2.654, 14.011) | (0.55, 2.305, 12.139) |
| player | (0, 0, 8) | (0, 0, 8) |
| camera → player | **6.59 m** | **4.77 m** |
| vertical FOV | **73.0°** | **66.0°** |

A 1.79 m hero at 6.59 m / 73° fills 18 % of the frame by the naive projection
(the measured 21 % is larger because an axis-aligned box projects taller than
its own height when the camera looks down at it); the same hero at 4.77 m / 66°
fills 29 % naively, ~33 % with the same box effect. 21 % × 1.385 × 1.14 ≈ 33 %,
which is where the 34 % came from.

So the browser sample was taken with the spring arm pulled in and the lens
narrower — a different instant, not a contradiction. Both figures sit inside the
test's readable band (10 %–85 %), and neither changes the verdict.

## 5. NOT TESTED — do not read this as a blanket PASS

* **Android / any real GPU.** No device, and this sandbox has no GL, EGL or
  Vulkan library, so Godot runs headless against a dummy rasteriser.
* **A build that contains this session's changes.** `engine/web_templates/*.zip`
  are 133-byte LFS pointers, so the export template cannot be unpacked and the
  `web/` payload cannot be re-exported. The frames above come from the committed
  payload, which predates this session's UI edits. BUG 1's subject (the avatar)
  is unaffected by those edits, but that is an argument, not a measurement.
* **Average frame rate, shader compilation on real drivers, thermal behaviour.**
* The death clip's end pose: the state sweep only holds each state ~0.4 s.
