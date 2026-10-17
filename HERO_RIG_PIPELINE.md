# Hero rig and weapon asset pipeline

**Date:** 2026-10-17

**Scope:** the rigged hero (`HERO+3d+model.glb`, 24.4 MB) and the rifle
(`futuristic gun 3d model.glb`, 17.3 MB) that were uploaded to the repository
root are now runtime assets with aiming/firing animation, wired into the player
scene. This document records what was produced, how, and what is still
unverified.

## Why the work happens in glTF space, not in Blender

`GAME_CONCEPT.md` §13.4 asks for a Blender `.blend` source next to every GLB.
That is still the right long-term home for authoring, but **no Blender ran in
this environment**: the `bpy` wheel needs native libraries this image does not
ship (`libXrender`, `libXfixes`, `libXi`, `libxkbcommon`, `libSM`, `libICE`,
`libGL`), and there is no GPU or X server to run the editor anyway. Claiming a
Blender pass would be false.

What was done instead is real, inspectable work on the same data Blender would
edit: the GLB is parsed as JSON + binary buffers (`tools/gltf/rigmath.py`), the
skeleton is solved with forward kinematics, the missing clips are authored with
analytic two-bone IK, and the result is written back into a valid GLB that the
engine imports. When a Blender install is available, the `.blend` file should be
created from these GLBs; nothing in the pipeline depends on Blender-specific
data.

## Source → runtime

| | Source | Runtime | Notes |
|---|---|---|---|
| Hero | `HERO+3d+model.glb` · 482,282 tris · 24.4 MB · 3 textures @2048 | `game/assets/characters/hero/hero.glb` · **36,170 tris** · **2.4 MB** · textures @1024 | meshoptimizer simplify + texture resize; **79/79 joints kept**, 3 clips kept |
| Rifle | `futuristic gun 3d model.glb` · 487,100 tris · 17.3 MB | `game/assets/weapons/futuristic_rifle/rifle.glb` · **12,176 tris** · **0.49 MB** · textures @512 | baked into a canonical frame, `MuzzlePoint`/`GripPoint` added |

Both outputs drop the non-standard `FB_ngon_encoding` extension and
`KHR_materials_volume`, so Godot's importer only sees core glTF. The reduction
is an 93 % / 97 % triangle cut and a 90 % / 97 % file-size cut; neither number
is a performance claim for a phone — that still needs a device run.

`game/assets/characters/hero/hero_rig.json` is generated next to the hero and is
the contract the game reads: hand bone name, weapon socket rotation for the aim
and carry poses, weapon scale in model units, clip names/durations, and the
measured aim-pose numbers.

## The rifle's frame and muzzle

The Tripo rifle is authored with the barrel along **+X**. The pipeline measures
the two end cross-sections (the muzzle end collapses to a 0.06 radius, the stock
end stays at 0.095) and rotates the mesh so that:

* the barrel runs along **−Z** (Godot's forward),
* **+Y** stays up,
* the pistol grip sits at the **origin**.

It then writes two nodes into the GLB: `MuzzlePoint` at the centre of the barrel
end cap (`0, 0.161, −0.670`; 6.8 mm from the nearest vertex after decimation)
and `GripPoint` at the origin. The game does not hard-code a muzzle offset — it
copies the `MuzzlePoint` transform onto the existing `Muzzle` marker, so the
muzzle flash and the projectile spawn are on the barrel by construction. A smoke
test asserts the distance is 0.0000 m.

## The animation clips

The source hero shipped `idle` (15.33 s), `run` (1.25 s) and `walk` (2.33 s) —
no aiming, no firing. Two clips are baked by `tools/gltf/build_clips.py`:

| Clip | Length | Loop | How |
|---|---|---|---|
| `aim` | 2.0 s | yes | idle base pose + breathing + two-bone IK for both arms |
| `fire` | 0.5 s | no | the aim pose + a recoil impulse that settles back into it |

The right hand is solved to a point 0.66 m up and 0.12 m forward of the feet
(hero-local, the model is 1 m tall); the left hand follows the rifle's
handguard. Measured on the written file:

* right-hand IK error **0.00 mm**, support-hand error **0.00 mm**,
* arm extension 58 % of reach on the trigger arm, 96 % on the support arm,
* muzzle at `(−0.035, 0.724, 0.388)`, barrel direction **exactly +Z** (0.00° pitch),
* recoil moves the muzzle **−37.6 mm back and +28.4 mm up**,
* weapon socket quaternion (xyzw) `0.1704, 0.0902, −0.6206, 0.7601`, scale **0.40**
  (0.71 m rifle on a 1.78 m soldier).

Two source-clip defects were found and fixed while baking:

* **`run` parks the body 0.55 units in front of the node origin** (constant hip
  offset, not root motion). Left alone, the avatar would slide ahead of its
  collider for the whole run. The constant offset is subtracted; the stride and
  the bob are untouched.
* **The lowered rifle points sideways** because the socket is authored for the
  aim pose. A second socket rotation (`carry`) swings the barrel forward and
  ~49° down; the game blends between `carry` and `aim` over 0.16 s. No wrist
  keyframes were damaged to achieve this.

`fire` is only played while the rifle is already shouldered. Firing from a
sprint keeps the run clip and only the flash/procedural kick fire, so the arms
never snap up for half a second.

## Engine integration

`game/scripts/player/character_visual.gd` now has two paths:

* **rigged** (`hero.glb`): `Skeleton3D` + `AnimationPlayer` drive the body; a
  `BoneAttachment3D` on `R_Hand` provides the hand transform; `WeaponSocket`
  stays a child of `VisualRoot` (so `VisualRoot/WeaponSocket/Muzzle` and
  `.../MuzzleFlash` keep their paths for combat code and six existing smoke
  tests) and copies the attachment's global transform every frame. The rifle is
  parented to the socket with the JSON rotation and scale.
* **static** (the Kenney astronaut, still the fallback): the previous procedural
  bob/lean/recoil path is unchanged.

Clip selection: `aim` wins whenever the player aims (the barrel must point where
the crosshair points); otherwise idle/walk/run by speed. Known limitation: with
no `AnimationTree` upper/lower-body split, aiming while moving slides the feet.
That is a visible trade-off, not an accident — the follow-up is a two-bone mask,
not shipping a shot that leaves a lowered gun.

## Rebuild

```bash
cd tools/gltf && npm ci          # @gltf-transform, meshoptimizer, sharp
node prepare_assets.mjs           # source GLBs -> game/assets (hero.glb, rifle.glb)
cd ../.. && .venv/bin/python tools/gltf/build_clips.py   # adds aim + fire
```

**Order matters.** `build_clips.py` refuses to run twice on the same file: it
replaces animation accessors, and a second bake would leave the replaced data in
the BIN chunk. Re-run `prepare_assets.mjs` first (it regenerates the hero from
the source GLB).

`tools/gltf/build_all.sh` runs both in order.

## Verification

| Evidence | What it proves |
|---|---|
| `game/tests/hero_rig_smoke.gd` (13th smoke test) | the avatar is rigged, all five clips exist, the socket rides the hand (0.088 m from the bone), the `Muzzle` marker is on `MuzzlePoint`, the flash node is on the muzzle, the barrel is angled down when carried and level with the player's facing when aimed (dot 1.00), a shot spawns at the barrel (0.000 m), and `fire` returns to `aim` |
| `tools/render/pose_shot.mjs` | 8 still frames of the baked clips, rendered through three.js in headless Chromium with the same socket transform the game uses |
| `tools/web_qa.mjs --play --hold … --touch` | the exported WebAssembly build boots, the hero renders in-game, and the touch AIM button puts the rig into the aim pose (camera zoom + arm silhouette) |
| `qa-evidence/hero-rig/` | committed copies of the above frames |

**Not verified:** a real Android device (touch, thermals, frame rate), the
clips played back as motion by a human eye, and skin deformation under extreme
poses after decimation. The still frames and the numeric IK checks are the
strongest evidence available without a GPU or a device.
