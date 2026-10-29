# HERO_01 — Validation Report (Phases F, G, H) — Milestone 1

Toolchain actually used: Blender **4.5.15 LTS** (headless bpy, Cycles CPU renders) and Python (pygltflib) for GLB inspection.
**No Godot binary could be obtained in the authoring sandbox** (the Drive Godot zip is 0 bytes; egress to Godot release hosts is blocked; no system package access). Everything in §5 is therefore **UNVERIFIED at runtime** and is packaged with exact owner steps. No test below is claimed beyond what was executed.

## 1. Source preservation — VERIFIED
- `assets/source/HERO_01.glb` untouched (18,888,488 B, MD5 `9d0ad8cd…`, SHA-256 `f067d3f5…45d50`); all editing on `blender/HERO_01_working.blend`.
- Vertex conservation through separation **and** export: 262,714 = 244,770 body + 17,944 weapon (counted in source, in Blender, and in shipped GLBs).
- Neutral-pose render from shipped GLBs matches the untouched-source baseline (same camera/lighting): `screenshots/baseline/` vs `screenshots/01_neutral_pose.png`.

## 2. Rig & skinning pose tests (Blender renders, viewed individually) — VERIFIED
World-axis rotations about joint heads; images in `screenshots/rig/` (final weights = v4 + island-13 fix):
| Test | Pose | Result |
|---|---|---|
| T0 | Neutral | Matches baseline. |
| T1 | Elbows flex −65° | Clean; forearm armor rigid, no collapse (`v6_T1_elbows_front.jpg`). |
| T2 | Knees +55° / hips −18° | Knee armor tracks shin/thigh; mild back-of-knee stretch, acceptable (`v3_T2_knees_sideR.jpg`). |
| T3 | Arm raise −75° + elbow −20° | Clean after fix; weapon follows right hand with barrel forward (`v6_T3_armraise_front.jpg`, `v3_T3_armraise_sideR.jpg`). |
| T4 | Spine −10°X, Chest/UpperChest yaw, Head counter | No candy-wrapper twist; belt stable (`v3_T4_spine_3q.jpg`). |
| T5 | Neck +16° / Head +30° yaw | Head/hair/collar coherent (`v3_T5_head_front.jpg`). |
Defect history (transparent): weight iterations v1/v2 produced a hand-to-thigh "blade" sheet in T3 (proximity leakage across chains). Root cause found and fixed by restricting blends to skeletally adjacent bones (v3+). A separate early experiment (script 11) mis-reassigned 25 forearm shells and was **reverted** by restoring v4 before proceeding; it is kept in the repo only as a record — do not rerun. One wrist shell (island 13) was then found by neighbour-detachment audit and fixed (script 14).
Residual minors (documented, not blockers): a gold jacket flap lifts slightly under the right arm at extreme raise (reads as loose clothing); `Hand_L` has 0 dominant verts (see RIG_SPECIFICATION §3).

## 3. Animation — VERIFIED in Blender (renders + numeric sampling)
- Existence/timing: `Weapon_Raise_To_Aim`, 1.5 s @30 fps, keys + stage map in ANIMATION_SPECIFICATION.
- Renders reviewed: F00/F12/F24/F36 × front/side/three-quarter + F36 close-up (`screenshots/animation/`). No snapping, teleporting, extreme bends, or severe intersections observed at reviewed frames; feet static by construction (leg channels constant).
- Barrel direction sampled: F0 (−0.159,−0.130,−0.979) → F12 (0.113,−0.947,−0.301) → F24 (0.068,−0.996,0.053) → F36/F45 **(0,−1,0)**.
- Grip: right hand→grip 0.017 m every sample; left hand→foregrip ≤0.011 m from F22, ≤0.003 m F28–45 (every-2-frames sweep).

## 4. Export validation — VERIFIED (pygltflib; raw data `tools/out/export_validation.json`)
| Check | HERO_01_RIGGED.glb | HERO_01_WEAPON.glb | HERO_01_ANIMATIONS.glb |
|---|---|---|---|
| Size | 22,878,116 B | 5,326,624 B | 67,196 B |
| Vertices | 244,770 | 17,944 | (skeleton-only) |
| Skin | 24 joints, exact bone names | — | 24 joints |
| Weights | sum 1.000000 ±1.2e-7, **0 zero-weight verts** | — | — |
| Animation | `Weapon_Raise_To_Aim`, 72 ch, **1.5 s** | — | same clip |
| Images/materials | 3 / 1 (source set) | 3 / 1 | 0 / 0 |
Roundtrip: fresh Blender scene, import RIGGED+WEAPON, re-attach weapon to `Weapon_R` (identity at F0, error 2.5e-07; grip distance 0.017 m at F0 **and** F36), renders `screenshots/01…04*.png` produced **from the shipped GLBs only**. One quirk: Blender's own glTF importer reports the re-imported action range as 0–36 (it drops identical trailing samples); the GLB itself contains the full 1.5 s (sampler max = 1.500 s, VERIFIED above).

## 5. Godot project — STATICALLY AUTHORED, RUNTIME **UNVERIFIED**
`project.godot` (4.7 feature tag, main scene set), `scenes/main/RigValidation.tscn`, `scenes/characters/HERO_01.tscn`, `scenes/weapons/HERO_01_WEAPON.tscn`, GDScript-only logic in `scripts/`. Scripts locate `Skeleton3D`/`AnimationPlayer` by recursive search (no hard-coded importer paths), create the `Weapon_R` BoneAttachment3D at runtime, and solve the weapon offset from the bone rest transform. The validation scene provides Play/Pause/Restart, timeline scrub, 0.25–2× speed, 6 camera presets, weapon toggle, skeleton dump, and an automated check list (`scripts/validation/auto_rig_check.gd`: skeleton presence, 24-bone count, all bone names, animation presence/length≈1.5 s, attachment + weapon instance).
### Owner validation steps (≈5 minutes)
1. Open Godot **4.7.2**, Import → select `EXOCOMFLICT_HERO01/project.godot`; wait for GLB import to finish (no errors expected; `.import` files are generated on first open).
2. Run the project (F5). Expect: character at origin facing camera, aim clip plays once, `AUTO RIG CHECK` panel all PASS, console prints the solved weapon offset + bone dump on demand.
3. Scrub the timeline slowly; use CloseHands/CloseWeapon presets; confirm grip contact and chest clearance visually; toggle the weapon off/on.
4. If the weapon appears offset, copy the printed solved offset into `HERO_01.use_manual_weapon_offset/manual_weapon_offset` and nudge there — by design this never touches hero geometry.
5. Report any console errors verbatim for a fix pass.
Known static-authoring risks (UNVERIFIED): exact imported node names under the GLB root, `Skeleton3D.get_bone_global_rest()` availability (present in Godot 4.x API), AnimationPlayer default-library naming (`ends_with` matching is used defensively), environment/light setup in the text-authored scene.

## 6. Acceptance mapping (Milestone 1)
- Visually intact rigged humanoid in Blender: **VERIFIED** (§1–2, renders).
- `Weapon_Raise_To_Aim` in Blender: **VERIFIED** (§3).
- Same character + clip in Godot: **UNVERIFIED** — package complete, runtime confirmation pending owner run (§5). This is the single open acceptance item and it is environmental (no Godot binary), not an asset defect.
- Humanoid skeleton / inspected weights / armor stability / documented weapon attachment: **VERIFIED** as detailed above.
- Specs distinguishing verified vs unverified: this report + ART_ASSET_REPORT / RIG_SPECIFICATION / ANIMATION_SPECIFICATION.

## 7. Recommended next work (not in Milestone 1)
1. Owner Godot run (§5) → close the UNVERIFIED items.
2. Cheek-weld ADS variant of the aim pose if first-person-style ADS is required.
3. Locomotion set (idle/walk/run) — validate `Hand_L` wrist weights and hip/knee ranges at run extremes first.
4. Optional owner-approved LOD/decimation pass for perf budgets; split the 19 grip-fusion shells only if a bare-hand weapon-hidden state is required.
