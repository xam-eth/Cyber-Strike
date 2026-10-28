# Hero rig and weapon asset pipeline

> **Current-state note — 2026-10-26:** The sections below are the historical
> 2026-10-17 first-pass glTF pipeline; their initial five-clip inventory and
> “no Blender ran” note are not the current asset state. The current character
> development brief is [`docs/EXO_OPERATIVE_CHARACTER_DESIGN.md`](docs/EXO_OPERATIVE_CHARACTER_DESIGN.md).
> Common/T1 authoring now lives in `tools/blender/author_hero.py`, and T2/T3
> animation transfer plus gait-alignment checks live in
> `tools/gltf/retarget_hero_variants.py`. The latest recorded Blender
> inspection is `docs/asset-inspections/hero-blender.json`. This pass used the
> real GLBs and offline Chromium pose renders; no Godot GUI visual approval is
> claimed.

**Historical date:** 2026-10-17

**Scope:** the rigged hero (`source-assets/characters/hero/hero_rigged_source.glb`, 24.4 MB) and the rifle
(`source-assets/weapons/rifle_source.glb`, 17.3 MB) that were uploaded to the repository
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
| Hero | `source-assets/characters/hero/hero_rigged_source.glb` · 482,282 tris · 24.4 MB · 3 textures @2048 | `game/assets/characters/hero/hero.glb` · **36,170 tris** · **2.4 MB** · textures @1024 | meshoptimizer simplify + texture resize; **79/79 joints kept**, 3 clips kept |
| Rifle | `source-assets/weapons/rifle_source.glb` · 487,100 tris · 17.3 MB | `game/assets/weapons/futuristic_rifle/rifle.glb` · **12,176 tris** · **0.49 MB** · textures @512 | baked into a canonical frame, `MuzzlePoint`/`GripPoint` added |

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
| `tests/hero_rig_smoke.gd` (13th smoke test) | the avatar is rigged, all five clips exist, the socket rides the hand (0.088 m from the bone), the `Muzzle` marker is on `MuzzlePoint`, the flash node is on the muzzle, the barrel is angled down when carried and level with the player's facing when aimed (dot 1.00), a shot spawns at the barrel (0.000 m), and `fire` returns to `aim` |
| `tools/render/pose_shot.mjs` | 8 still frames of the baked clips, rendered through three.js in headless Chromium with the same socket transform the game uses |
| `tools/web_qa.mjs --play --hold … --touch` | the exported WebAssembly build boots, the hero renders in-game, and the touch AIM button puts the rig into the aim pose (camera zoom + arm silhouette) |
| `qa-evidence/hero-rig/` | committed copies of the above frames |

**Not verified:** a real Android device (touch, thermals, frame rate), the
clips played back as motion by a human eye, and skin deformation under extreme
poses after decimation. The still frames and the numeric IK checks are the
strongest evidence available without a GPU or a device.

## Current character design and animation state — 2026-10-26

The original report above is preserved as historical evidence. The current
production direction and tier-by-tier design brief are in
[`docs/EXO_OPERATIVE_CHARACTER_DESIGN.md`](docs/EXO_OPERATIVE_CHARACTER_DESIGN.md).

- **Common/T1:** `tools/blender/author_hero.py` imports the real hero and rifle
  GLBs, saves `source-assets/characters/hero/hero_source.blend`, authors the
  gameplay action set, and exports `game/assets/characters/hero/hero.glb`.
  The most recent recorded Blender report is Blender 4.0.2 with 79 bones and
  10 actions. This pass changed no mesh, skeleton, or skin weights.
- **Rare/T2 and Epic/T3 runtime exports:** the files are
  `game/assets/characters/hero_variants/hero_tier_2_rare.glb` and
  `game/assets/characters/hero_variants/hero_tier_3_epic.glb`, with matching
  `*_rig.json` profiles. The corresponding preserved source meshes are under
  `source-assets/characters/hero_variants/`. The QA manifest’s old
  `game/assets/enemies/robot_tier_*.glb` names are not these filenames.
  T2 has 78 of the 79 Common skin joints (only the documented helper
  `neutral_bone` is absent); T3 has 79. T4/T5 runtime GLBs are not present in
  this checkout.
- **Gait-alignment repair:** `tools/gltf/retarget_hero_variants.py` now bakes
  Common/T1 `aim_walk` and `aim_run` from T1’s own aim pose plus the matching
  `walk`/`run` lower-body cycle, using that gait’s exact zero-based key times.
  The previous T1 clips began at 1/30 s and extended one frame beyond the
  movement cycle; the rebuilt clips are phase-locked to `walk`/`run`. The same
  composition and timebase are used for the T2/T3 target rigs. The tool checks
  that the upper body stays on aim, the lower body matches its gait, and both
  feet move.
- **Root-translation retarget fix:** only root/hip joints with actual
  per-clip translation motion are independently retargeted. A static Hip now
  inherits a moving BoneRoot, preventing the T2/T3 death pose from being held
  above the floor by a compensating Hip track.
- **Current runtime action names:** `idle`, `walk`, `run`, `aim`, `aim_walk`,
  `aim_run`, `fire`, `reload`, `hit`, and `death`. Gameplay owns world movement;
  the locomotion clips are in-place. Clip durations and design intent are
  tabulated in the design brief.
- **Animation-track cleanup:** `tools/gltf/strip_static_scale_tracks.py`
  removes only skin-joint scale tracks proven equal to rest scale. T1/T2/T3
  runtime GLBs now have no bone-scale animation channels. The Blender and GLB
  retarget authoring paths guard against reintroducing scale animation.
- **QA boundary:** the standalone Godot QA project and project separation were
  preserved. No Godot GUI approval is claimed; local visual inspection remains
  required, while the retargeter’s data checks and offline renders are
  supporting evidence rather than a visual sign-off.

## Character appearance and playback follow-up — 2026-10-29

- The player no longer draws its near-black grown outline overlay over every
  skinned surface. The original GLB PBR materials remain in use, with per-surface
  anisotropic filtering; the native Mobile renderer requests 4× 3D MSAA. Meshes,
  textures, rig, and skin weights are unchanged.
- The in-place walk/run cycles receive a velocity-based playback rate. Walk/run
  and aim-walk/aim-run clip changes carry normalized cycle phase, and separate
  enter/exit thresholds reduce state flicker during acceleration/deceleration.
- `tests/hero_rig_smoke.gd` checks playback rate, phase continuity, and run/walk
  hysteresis. `tests/hero_visibility_smoke.gd` now CPU-skins the actual mesh at
  seven `aim_walk` and seven `aim_run` phases, bounding the silhouette and
  checking that both foot joints move. These Godot runtime assertions were not
  executed in this sandbox; formatter/linter checks passed.
- An eight-frame Three.js sweep of the actual hero/rifle GLBs showed no obvious
  gross deformation in the sampled poses. It is not a Godot screenshot, GUI
  review, or human motion approval. Forward cadence is addressed; directional
  foot locking during lateral strafes and local Godot review remain open.
