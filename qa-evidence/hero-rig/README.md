# QA evidence — rigged hero, rifle and baked aiming animation

**Date:** 2026-10-17 · **Build:** `arena/5257bce8-cyber-strike`, Godot
4.6.2-stable headless + WebAssembly export.

The source hero had no aiming or firing animation and the weapon was a floating
box with a hand-placed muzzle marker. These frames and numbers are what replaced
that. Full pipeline: [`../../HERO_RIG_PIPELINE.md`](../../HERO_RIG_PIPELINE.md).

## What was checked automatically

`tests/hero_rig_smoke.gd` ran headlessly on the real engine and passed with
these measurements printed by the engine itself:

| Check | Result |
|---|---|
| avatar is a `Skeleton3D` + `AnimationPlayer` (not the capsule fallback) | yes |
| clips in `hero.glb` | `idle`, `run`, `walk`, `aim`, `fire` |
| `R_Hand` bone exists | yes |
| weapon socket distance from the hand bone | **0.088 m** |
| `Muzzle` marker ↔ rifle's `MuzzlePoint` | **0.0000 m** |
| muzzle flash node ↔ muzzle | **0.0000 m** |
| muzzle position inside the rifle (`-Z` is the barrel) | local **z = −0.67** |
| barrel direction while carried | 0.72 dot with facing (angled down) |
| barrel direction while aiming | **1.00** dot with facing (level) |
| socket rotation change carry → aim | 0.73 dot (the rifle really moves) |
| projectile spawn position ↔ muzzle | **0.000 m** |
| `fire` clip → back to `aim` | yes |

Suite: **13/13 smoke tests**, `project_doctor` 0 FAIL / 8 WARN, `dev_check`
0 failed.

Baked-clip numbers from `tools/gltf/build_clips.py` (measured on the written
file, not on the source):

* right-hand IK error **0.00 mm**, support-hand error **0.00 mm**
* muzzle `(−0.035, 0.724, 0.388)`, barrel pitch **0.00°**
* recoil: muzzle **−37.6 mm back, +28.4 mm up**
* `run` hip offset removed: **0.55 units** (it used to park the body in front of
  the collider for the whole clip)

## Frames

Rendered with `node tools/render/pose_shot.mjs` — three.js in headless Chromium
(SwiftShader), using the same socket transform the game uses.

| File | What it shows |
|---|---|
| `aim-side.png` | both hands on the rifle, stock at the shoulder, barrel level |
| `aim-three-quarter.png` | the aim pose from the gameplay-ish angle; orange dot = `MuzzlePoint` |
| `aim-close.png` | trigger hand on the grip, support hand on the handguard |
| `idle-front.png` | carry pose: rifle angled forward/down at the side |
| `run-side.png` | sprint clip, in place (the hip offset is gone) |
| `fire-peak.png` | 0.07 s into `fire`: muzzle kicked back and up |

In-engine frames from the WebAssembly build via `tools/web_qa.mjs`:

| File | What it shows |
|---|---|
| `in-game-aim-1280x720.png` | touch AIM held: camera zoomed, arms up in the aim pose |
| `in-game-carry-1280x720.png` | boot frame: hero standing with the rifle at his side |
| `in-game-portrait-390x844.png` | portrait HUD with the rigged hero rendering |

## How to reproduce

```bash
# 1. engine + templates (outside the repo)
./scripts/install_godot.sh --with-templates

# 2. rebuild the assets if needed, in this order
node tools/gltf/prepare_assets.mjs
.venv/bin/python tools/gltf/build_clips.py

# 3. the assertions
./scripts/run_smoke_tests.sh hero_rig_smoke
./scripts/run_smoke_tests.sh            # all 13

# 4. the still frames
node tools/render/pose_shot.mjs

# 5. browser build + QA (touch AIM button at 955,636 on a 1280x720 canvas)
./scripts/export_web_preview.sh --output /tmp/preview/web
cp index.html /tmp/preview/ && (cd /tmp/preview && python3 -m http.server 8130)
node tools/web_qa.mjs --url http://127.0.0.1:8130 --page / --viewport 1280x720 \
  --play 3 --hold 955,636 --touch --still --out exports/web-qa/hero-aim
```

## Limits of this evidence

* Headless Chromium uses **software rendering**; the frame rate in these frames
  says nothing about a phone GPU.
* The clips were reviewed as **stills at chosen times**, not watched as motion
  by a person. Foot sliding while aiming and moving is a known trade-off until
  an `AnimationTree` upper/lower-body split exists.
* Nothing here was captured on an Android device.
