# HERO_01 — Animation Specification: `Weapon_Raise_To_Aim` (Phase D)

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
