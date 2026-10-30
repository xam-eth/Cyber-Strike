# HERO_01 — Animation Specification & Production Plan

Sections 1–5 document the original verified `Weapon_Raise_To_Aim` clip (Milestone 1 / Phase D). Sections 6 onward define the approved 20-clip production target and the completed Phase-1 weapon chain built from that verified clip.

## 1. Clip summary
- Name: `Weapon_Raise_To_Aim` (Blender action + exported glTF animation). **VERIFIED**
- 30 fps, frames 0–45, duration **1.5 s**, in-place (no root/Hips translation), no loop, no recoil/firing. **VERIFIED in exported GLB (72 channels = 24 bones × T/R/S).**
- Action starts in the exact bind pose (frame 0 keys re-authored to exact rest — neutral pose is untouched) and ends in a stable two-handed aim, held frames 36–45 with a subtle settle. **VERIFIED**

## 2. Timing / stage map
| Frames | Time | Stage (brief §D) | Content |
|---|---|---|---|
| 0 | 0.00s | 1 Neutral ready | As-modelled stance, rifle vertical at right side, clear of torso |
| 0–8 | 0–0.27s | 2 Initial movement | Right wrist lifts (−0.185,−0.025,0.465)→(−0.175,−0.05,0.50); chest begins to blade |
| 8–18 | 0.27–0.60s | 3 Weapon alignment | Wrist →(−0.12,−0.12,0.62); barrel rotates from down to forward-down; support hand leaves side |
| 18–28 | 0.60–0.93s | 3→4 | Wrist →(−0.06,−0.13,0.70); barrel ≈ forward (0.07,−1.00,0.05); left hand contacts foregrip ≈F22–24 |
| 28–36 | 0.93–1.20s | 4 Stable aim | Wrist →(−0.035,−0.132,0.712); barrel exactly (0,−1,0); muzzle (−0.054,−0.401,0.734) |
| 36–45 | 1.20–1.50s | 5 Hold | Aim held; micro chest settle (−0.4°) keeps the hold inside the exported range |

Keys at 0/8/18/28/36/45 (all bones), support-arm tracking keys additionally at 21/24/27/30/33/40. Interpolation: Bézier with AUTO_CLAMPED handles (no overshoot past the grip), baked by the exporter's force-sampling. Legs/feet are keyed constant at rest → feet planted, zero foot slide. **VERIFIED numerically (channels) and visually (renders `screenshots/animation/`).**

## 3. Authoring method (no runtime dependencies)
Poses were computed in Python and baked to ordinary bone keys — the exported clip needs **no IK, constraints or control rig**:
- Two-bone analytic IK (law of cosines) per arm, applied as world-space rotations about the shoulder/elbow. Elbow poles: down/back/outward. Reach was verified against measured bone lengths (R: 0.190+0.119; L: 0.166+0.177 in normalized units); the aim wrist target was pulled 2 cm closer to the body so the support arm reaches the foregrip without full extension.
- Barrel alignment: after placing the right arm, `Hand_R` receives a corrective world rotation rotating the measured barrel vector onto character forward (0,−1,0), ramped 0→1 across the raise. Two iterations converge to machine precision (final barrel = (0.000,−1.000,0.000)). The glove rotates inside the modeled cuff; the grip itself cannot break because the weapon is parented to the same hand chain.
- Support hand: the foregrip world position is *sampled from the posed weapon* at each key, then the left arm is IK-placed onto it; a second pass (script 16) re-keys the left arm densely against the final interpolated weapon motion.
- Torso: Spine pitch −4°, Chest yaw −10° (support side leads), UpperChest −6°, counter-yaw Neck +9°/Head +7° and slight pitch so the gaze returns to the aim line.

## 4. Grip validation (measured on the final clip in Blender)
- Right hand → grip point: **0.017 m constant at every sampled frame** (bone-anchored by construction; 17 mm is the fixed wrist-bone-to-grip-centre offset inside the modelled glove). **VERIFIED**
- Left hand → foregrip point: F20 0.040 → F22 0.011 → F24 0.007 → F26 0.004 → F28–45 ≤0.003 m (sampled every 2 frames; script 16 output). **VERIFIED**
- Same 0.017 m right-grip distance measured again **after export/re-import** at F0 and F36. **VERIFIED**
- Torso clearance: rifle receiver passes in front of the chest armor without intersection in reviewed frames (close-up `screenshots/animation/aim_F36_closeup.jpg`); the weapon is never forced across the chest — it rises at the right side and comes forward. **VERIFIED visually in Blender renders, and numerically in Godot 4.7.2** (in-engine grips 0.0000-0.0302 m, bore 0.1-0.4 deg off forward - VALIDATION_REPORT 5.3; a rendered desktop visual pass remains an owner step).

## 5. Honest limitations
- The final pose is a **shouldered ready/aim at chest height** (barrel line z≈0.73 vs eyes z≈0.90 in normalized units — the character looks *over* the rifle). It reads correctly for a third-person over-shoulder aim; a cheek-weld ADS variant would need the wrist target ≈8 cm higher and a re-check of support-arm reach. **Documented polish item, not a defect.**
- Fingers do not articulate (no finger bones in the skeleton contract); both modelled gloves are used as-is.
- In-engine playback was additionally seek-sampled in Godot 4.7.2 (all measurements match Blender), but judged visual smoothness rests on the Blender frame renders, because headless Godot renders no pixels.

## 6. Approved 20-clip production target

The production set is intentionally **20 reusable clips**, not one clip for every combined gameplay state. Gameplay code controls character facing and movement speed (joystick/`CharacterBody3D` velocity); the animation system composes locomotion, weapon actions, full-body actions and interactions at runtime.

| # | Clip | Primary layer / use | Status at Phase 1 |
|---|---|---|---|
| 1 | `Idle` | Locomotion base, loop | **Done — Phase 1** |
| 2 | `Walk` | Locomotion, loop | Not started |
| 3 | `Run` | Locomotion, loop | Not started |
| 4 | `Sprint` | Locomotion, loop | Not started |
| 5 | `Weapon_Raise` | Weapon transition | **Done — Phase 1** |
| 6 | `Aim_Idle` | Weapon aim hold, loop | **Done — Phase 1** |
| 7 | `Fire` | Weapon one-shot | **Done — Phase 1** |
| 8 | `Reload` | Upper-body weapon action | Not started |
| 9 | `Weapon_Lower` | Weapon transition | **Done — Phase 1** |
| 10 | `Recoil` | Future heavy/weapon-class impulse layer; exact gameplay role to confirm because `Fire` already contains normal recoil/recovery | Not started |
| 11 | `Jump` | Full-body action (takeoff) | Not started |
| 12 | `Fall` | Full-body air state, loop/hold | Not started |
| 13 | `Land` | Full-body recovery | Not started |
| 14 | `Dodge` | Full-body action; gameplay supplies direction initially | Not started |
| 15 | `Crouch` | Posture state/loop, blended by state machine | Not started |
| 16 | `Melee_Attack` | Full-body action | Not started |
| 17 | `Hit_React` | Full-body/upper-body reaction | Not started |
| 18 | `Heavy_Hit` | Full-body reaction/stagger-scale event | Not started |
| 19 | `Death` | Full-body terminal action | Not started |
| 20 | `Interact` | Generic interaction base | Not started |

Deferred until after the first 20-evaluation: `Pickup_Item`, `Open_Cache`, `Activate_Terminal`, `Victory`. Directional locomotion (`Walk_Left`, `Walk_Right`, `Walk_Backward`, `Walk_Forward`) is **not** in the initial set because the character rotates toward joystick movement. Dedicated strafe/backpedal clips become a separate requirement only if gameplay later requires the character to keep facing/aiming at an enemy while moving sideways or backwards.

`Weapon_Raise_To_Aim` (sections 1–5) remains exported as an additional legacy/reference clip. It is **not counted** in the 20; the production chain splits its raise and hold into `Weapon_Raise` + `Aim_Idle` so the state machine can hold, fire and lower independently.

## 7. Runtime composition architecture (Godot)

Target composition, to be completed phase by phase:

1. **Locomotion layer:** `Idle → Walk → Run → Sprint` in a BlendSpace1D driven by horizontal speed. Clips are in-place unless a later phase explicitly approves root motion; gameplay velocity and facing remain code-driven.
2. **Weapon upper-body layer:** aim/fire/reload composed over locomotion with an `AnimationNodeBlendTree` (filtered upper-body tracks: Spine/Chest/UpperChest/Neck/Head/clavicles/arms/hands/`Weapon_R`) and one-shot nodes where appropriate. This is what will permit move-while-aiming or run-then-fire without combination clips.
3. **Full-body action states:** Jump/Fall/Land, Dodge, Melee, Heavy_Hit and Death override or strongly blend over the base through the root state machine.
4. **Interaction states:** generic `Interact` first; object-specific variants only after the base set is evaluated in game context.

**Important implementation boundary:** Blender currently exports every clip with all 24 bone channels. The Phase-1 tree (below) therefore plays the weapon chain as full-body states while stationary. Before Phase-2 locomotion is accepted, the upper-body track filtering/blending must be implemented and tested (Move + Aim / Run + Fire) — that combination is **not yet claimed**.

## 8. Phase-1 weapon chain — completed clips (Blender/GLB VERIFIED)

Production gate executed first, per owner direction, because this asset previously showed deformation defects when the arms raised:

`Idle → Weapon_Raise → Aim_Idle → Fire → Aim_Idle → Weapon_Lower → Idle`

| Clip | Frames @30 fps | Seconds | Loop in Godot wrapper | Construction / measured result |
|---|---:|---:|---|---|
| `Idle` | 0–90 | 3.0 | Linear | Exact bind-pose basis + one smooth breathing cycle through Spine/Chest/UpperChest (±0.35° max). Right-hand excursion 0.0028; loop closure 0.00e+00; feet drift 0.0000. |
| `Weapon_Raise` | 0–36 | 1.2 | None | Legacy verified raise resampled every 3 source frames, ending at source stable-aim F36. Final barrel error 0.000°; contact-phase left grip ≤0.0069 at F33 and ~0 at F36. |
| `Aim_Idle` | 0–90 | 3.0 | Linear | Stable F36 aim + breathing; max barrel sway 0.443°; left grip ≤0.0002; loop closure 5.96e-08. |
| `Fire` | 0–12 | 0.4 | None | Stable aim → F2 recoil peak → F7 near-aim → F12 exact aim. Peak muzzle climb 1.867°; left grip ≤0.0003; starts/recovers at stable aim. |
| `Weapon_Lower` | 0–24 | 0.8 | None | Reverse of the verified stable-aim→rest path (source F36→F0 sampled every 2 frames). Ends at rest barrel direction, error 0.000°. |

All five clips: 168 Blender fcurves (24 bones × loc/quat/scale channels), 72 exported glTF channels, finite sampled bone transforms, right-grip deviation 0.0000 at the printed precision, feet planted (leg/foot channels stay at bind), no `Root`/`Hips` translation. Recoil and breathing are driven through the spine chain so both arms and the bone-parented weapon move coherently and the authored grips do not separate. `Weapon_Raise` deliberately ends at source F36 — the first exact stable-aim frame — excluding the legacy clip's extra 0.3 s settle/hold.

Evidence: gated generator `tools/blender/scripts/47_build_phase1_weapon_chain.py` (saves only if every numeric gate passes); 13 Cycles verification renders in `screenshots/animation/phase1/` (script 48). The underside/hip-critical left and front-left views at Fire F02, Raise F36, Lower F12 and Idle F45 were individually inspected: **no re-opened front-left hip void, shell tearing, grip loss or gross intersection observed** in Blender renders.

Export (script 49 + `tools/patch_glb_double_sided.py`): `assets/characters/HERO_01_RIGGED.glb` (23,177,636 B, md5 `95360c299bc7d3d25c11913b83e425b5`) and `animations/HERO_01_ANIMATIONS.glb` (346,860 B, md5 `54cf3004be0359fb681b8d6b91cb6d0d`) each contain all six clips. `tools/diff_rigged_glb.py --anim-tol 1e-6` proves the body geometry/weights/material, skin joints and inverse-bind matrices stayed **byte-identical** to the pre-Phase-1 GLB; the legacy clip's sampler outputs moved by at most 4.77e-07 (float32 epsilon scale) in the multi-action re-export, so it is documented as equivalent within 1e-6, not byte-identical.

## 9. Godot Phase-1 integration shipped in this package

`scripts/characters/hero_01.gd` now resolves all clip names by exact basename (so `Idle` can never resolve to `Aim_Idle`), sets `Idle`/`Aim_Idle` to linear loop and the transition/one-shot clips to no loop, and builds an `AnimationTree` state machine in code:

- `Start → Idle` (auto), `Idle → Weapon_Raise`, `Weapon_Raise → Aim_Idle` (auto at end), `Aim_Idle → Fire`, `Fire → Aim_Idle` (auto at end), `Aim_Idle → Weapon_Lower`, `Weapon_Raise → Weapon_Lower` (interrupt), `Weapon_Lower → Idle` (auto at end).
- Public API: `play_idle()`, `raise_weapon()`, `play_aim_idle()`, `fire_weapon()`, `lower_weapon()`, `travel_animation_state(name)`, `set_animation_tree_enabled(bool)`, plus current state/position/length getters. The export `use_animation_tree` defaults to true; disable it if a host game supplies its own AnimationTree. Legacy `play_aim()` remains for the original clip/CI.
- `RigValidation` gained Phase-1 chain buttons; its scrub slider becomes a read-only position indicator in tree mode and still scrubs the legacy clip in direct mode. `auto_rig_check.gd` verifies all six clips (presence, duration, loop mode) and that the tree built; `tools/godot/ci_check.gd` disables the tree before its direct seek measurements.

Godot status for this new layer is **UNVERIFIED at runtime** until the owner re-imports the changed GLBs in desktop Godot 4.7.2 (or the headless CI is re-run on a Godot binary): see VALIDATION_REPORT 5.10 for exactly what was and was not executed. GDScript syntax was parser-checked only.

## 10. Production order and acceptance gates

1. **Phase 1 (done in Blender/GLB):** `Idle → Weapon_Raise → Aim_Idle → Fire → Weapon_Lower`. *Exit gates still open:* owner Godot re-import + visual confirmation of the chain and hip locus, and resolution of the owner's stale-import clip failure (VALIDATION_REPORT 5.11).
2. **Rig-anatomy gate (closed in Blender/GLB, VALIDATION_REPORT 5.11–5.12):** torso-island arm-weight leakage, the over-wide left-elbow blend and the misplaced `Hand_L` pivot are repaired/re-rigged and re-exported; all six existing Actions were converted to the new Forearm_L/Hand_L rest skeleton with exported world deformation equivalent within 0.0005 mm. No locomotion sign-off until the owner re-imports the 5.12 GLBs in Godot and visually confirms the Phase-1 chain and wrist, per the production order.
3. **Phase 2 locomotion:** stress-validate hip/knee/ankle ranges first, then `Walk`, `Run`, `Sprint`; foot-plant/speed sync, BlendSpace1D, and the filtered upper-body layer (Move + Aim test) before acceptance.
4. **Phase 3 weapon completion:** `Reload`; define/confirm whether `Recoil` is a distinct heavy-weapon clip or should be removed as redundant with `Fire`.
5. **Phase 4 full-body:** `Jump → Fall → Land`, `Dodge`, `Crouch`, `Melee_Attack`, `Hit_React`, `Heavy_Hit`, `Death` — each with deformation stress renders around hips/shoulders before export.
6. **Phase 5 interaction:** generic `Interact`, evaluate in context, then decide the deferred object-specific clips.

Every clip must pass the same evidence chain before it is called production-ready: Blender numeric gates (finite transforms, grips where relevant, planted/support feet, loop closure) → individually viewed renders at deformation-critical angles → GLB structural validation + byte-diff of body data → Godot import/auto-check/CI → owner desktop visual pass. Export success or keyframes alone are never sufficient evidence.
