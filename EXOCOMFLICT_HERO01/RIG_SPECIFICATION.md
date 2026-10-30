# HERO_01 — Rig Specification (Phases B, C, E)

## 1. Skeleton (24 bones)
```
Root (non-deform)
└─ Hips
   ├─ Spine
   │  └─ Chest
   │     └─ UpperChest
   │        ├─ Neck
   │        │  └─ Head
   │        ├─ Clavicle_R → UpperArm_R → Forearm_R → Hand_R → Weapon_R (non-deform)
   │        └─ Clavicle_L → UpperArm_L → Forearm_L → Hand_L
   ├─ UpperLeg_R → LowerLeg_R → Foot_R → Toe_R
   └─ UpperLeg_L → LowerLeg_L → Foot_L → Toe_L
```
- Bone names in Blender, in the exported GLB skin, and (expected) in Godot `Skeleton3D` are **identical** — no renaming layer. **VERIFIED in all three** (Godot 4.7.2 headless import: Skeleton3D reports the same 24 names - VALIDATION_REPORT 5.3).
- `Root` and `Weapon_R` are non-deforming (zero painted weight, by construction); all other 22 bones deform. **VERIFIED**
- No IK/control bones are exported; animation is baked bone keys (see ANIMATION_SPECIFICATION).
- Joint coordinates (Blender Z-up, as-modeled space): `tools/out/joints_final_v1.json`. Key points: Hips at pelvis z≈0.52; right wrist (Hand_R head) (−0.185, −0.025, 0.465); `Weapon_R` head (−0.192, −0.033, 0.452), tail (−0.207, −0.040, 0.380) — placed on the rifle grip axis in the right palm. **VERIFIED**

## 2. Rest pose, axes, scale, root motion
- Bind/rest pose = the as-modeled contrapposto stance (weight shifted, head offset x≈+0.043). It is **not** a symmetric T/A-pose — retargeted external animations should be authored/adjusted with this in mind. **VERIFIED**
- Blender: Z-up, character faces −Y. Exported GLB (Y-up): character faces +Z, height 1.0 unit, origin at ground centre between the feet. **VERIFIED**
- Godot validation project: `ScaleRoot` applies uniform ×1.8 → 1.8 m tall (**ASSUMPTION**, change in `scenes/characters/HERO_01.tscn`). Character faces +Z as imported; rotate the HERO_01 root 180° about Y if the main project requires the −Z forward convention. **VERIFIED in-engine** (bore line measures +Z at aim in Godot 4.7.2 - VALIDATION_REPORT 5.3).
- Root motion: none. `Root`/`Hips` translation channels are constant zero in Milestone 1; all clips are in-place. **VERIFIED**

## 3. Skinning strategy (as shipped)
Automatic weights failed on this asset (Blender `ARMATURE_AUTO` produced 100% zero-weight vertices — thin non-watertight shells). Weights were instead computed procedurally per shell and then verified/corrected through pose-test renders (pipeline scripts 08–10, 14):
1. Each body shell is assigned to one kinematic chain (SPINE / ARM_R / ARM_L / LEG_R / LEG_L) by centre-to-bone-segment distance.
2. Blending is allowed **only between skeletally adjacent bones** (e.g. arm↔Chest/UpperChest near the shoulder, leg↔Hips near the hip). An earlier "any bone within 45 mm" rule leaked arm weights into thigh shells and caused a severe artifact — it was removed; see VALIDATION_REPORT for the rendered before/after.
3. Small/rigid shells (armor plates, pouches, buckles) are rigidified to their shell-average weights → armor follows its bone without rubber deformation; large clothing shells keep per-vertex proximity falloff `(1/(d+0.004))³` within the allowed set, then intra-shell smoothing; max 4 influences; all weights normalized (sum = 1.0 on every exported vertex, 0 zero-weight verts — **VERIFIED numerically in the shipped GLB**).
4. Belt band (z 0.495–0.555) locked to {Hips, Spine}; head/hair locked to Head/Neck region rules; a hand-zone override guarantees grip shells follow the arm chain.
5. One misclassified wrist shell (body island 13) was detected by a neighbour-detachment audit in posed renders and reassigned to Forearm_R/Hand_R (script 14). **VERIFIED by re-render.**
- Known skinning limitation: `Hand_L` has **0 dominant vertices** — the left wrist is driven mostly by `Forearm_L` (with secondary Hand_L blend). For the foregrip-support role in `Weapon_Raise_To_Aim` this measured ≤3 mm grip error at hold, but future left-wrist-articulation clips should re-check this region first. **VERIFIED measurement; documented limitation**

## 4. Weapon attachment (documented convention)
- The rifle is a **separate object/scene**: `assets/weapons/HERO_01_WEAPON.glb`, wrapped by `scenes/weapons/HERO_01_WEAPON.tscn` with `GripPoint`, `ForegripPoint`, `MuzzlePoint` Marker3Ds (Godot-space positions in the .tscn).
- Attachment bone: **`Weapon_R`** (child of `Hand_R`). In Blender the weapon object is bone-parented to `Weapon_R` with world-identity transform at rest (max error 1.2e-07, **VERIFIED**); consequently the weapon GLB origin = character origin.
- In Godot, `scripts/characters/hero_01.gd` creates a `BoneAttachment3D` on `Weapon_R`, instances the weapon scene, and solves the attachment-local offset as `skeleton.get_bone_global_rest(Weapon_R).affine_inverse()` - pure skeleton space, so the Blender-authored grip is reproduced at any character scale/placement (an earlier hero-root-anchored version failed exactly here under ScaleRoot x1.8; caught by the headless CI, VALIDATION_REPORT 5.3). The solved offset is printed at startup and can be frozen via the `use_manual_weapon_offset` export var — grip adjustment never requires editing hero geometry. **VERIFIED by execution in Godot 4.7.2** (grip 0.0302 m constant = Blender 0.017 x 1.8; VALIDATION_REPORT 5.3).
- Grip reference points (Blender rest space): grip (−0.192, −0.033, 0.452); foregrip (−0.215, −0.062, 0.315); muzzle (−0.238, −0.080, 0.205); barrel rest direction ≈ (−0.14, −0.12, −0.98) (pointing down).

## 5. Export settings (reproduce exactly)
Blender 4.5 glTF exporter, per script `tools/blender/scripts/18_export_polish.py`:
format GLB; `use_selection`; Y-up; **no modifier apply**; skins on; *deformation-bones-only OFF* (all 24 bones exported, incl. `Weapon_R`); animations = ACTIONS mode, force-sampling ON, optimize-animation-size OFF; materials EXPORT (rig + weapon) / NONE→superseded by skeleton-only animations file (script 20). Scene frame rate 30 fps.
**Double-sided material REQUIRED:** the mesh is open shells, so the glTF material must be `doubleSided: true` (Blender material Backface Culling OFF), otherwise Godot culls back-facing shell detail during motion. Shipped GLBs carry the flag via `tools/patch_glb_double_sided.py`; re-apply after any re-export with culling on. See VALIDATION_REPORT 5.6.

**Presentation requirement (host scenes):** the material is heavily metallic PBR. In Godot it needs sky/environment ambient + reflections (or reflection probes) and MSAA; a flat color-ambient scene without anti-aliasing crushes neighbouring dark shells into a near-black, detail-less mass that reads as missing geometry — the shipped geometry itself is complete (VALIDATION_REPORT 5.7). Thin seam lines between the source's 247 loose shells are inherent to the source asset.

**Spine-chain shared weight field (do not regress, VALIDATION_REPORT 5.8):** every spine-chain shell at rest height z∈[0.435,0.825] shares one height-based `Hips`→`Neck` weight field (script 31, fitted + smoothed), so inter-shell seams cannot open under spine motion. Never weight waist/abdomen shells to leg bones — the original 100%-`UpperLeg_L` waist shell caused the abdomen hole fixed in 5.8. Any re-skinning must preserve seam coherence (equal weights at equal height across shell boundaries) or re-apply script 31; the working .blend is the source of truth for weights.
**Hidden undersuit patch (do not delete/regress, VALIDATION_REPORT 5.9):** `HERO_01_UNDERSUIT` is a separate additive mesh (325 verts) placed 14 mm (normalized units) behind the measured first non-arm surface over the source-inherent front-left hip occlusion void (z∈[0.500,0.586], sector −52°..+18° around the skeleton centerline; script 43 BVH ray fit), weighted with the script-31 spine field and dark double-sided `HERO_01_UNDERSUIT_MAT`. It is **not** source geometry: never merge it into `HERO_01_BODY`, and keep it behind source surfaces when re-skinning (rebuild/re-gate with script 43 if the hip weights change). Rigged re-exports must select armature+body+undersuit (script 44; same exporter settings as script 18/32), then re-run `tools/patch_glb_double_sided.py` (now patches every material) and verify the body primitive stayed identical with `tools/diff_rigged_glb.py`.
**Phase-1 animation exports (VALIDATION_REPORT 5.10):** current animation-bearing GLBs are exported by `tools/blender/scripts/49_export_phase1_animations.py` (same script-18 settings and armature+body+undersuit selection rule as script 44; ACTIONS mode carries every fake-user Action). After any re-export: run `tools/patch_glb_double_sided.py`, `tools/validate_exports.py`, and `tools/diff_rigged_glb.py` against the previous shipped GLB — body/skin/material must stay byte-identical (state `--anim-tol` explicitly only for float-epsilon re-sampling of pre-existing clips). Never re-run the older single-clip exporters (18/20/32/44) over the shipped files or the Phase-1 clips will be lost.
Deliverable GLBs: `assets/characters/HERO_01_RIGGED.glb` (body+undersuit+skin+6 clips, 23,177,636 B), `assets/weapons/HERO_01_WEAPON.glb`, `animations/HERO_01_ANIMATIONS.glb` (skeleton + same 6 clips, 346,860 B — retarget/reference; playable clips also live inside RIGGED).

## 6. Retargeting preparation (Phase E)
Suggested Godot `SkeletonProfileHumanoid` BoneMap (our bone → profile name):
Root→Root, Hips→Hips, Spine→Spine, Chest→Chest, UpperChest→UpperChest, Neck→Neck, Head→Head, Clavicle_R→RightShoulder, UpperArm_R→RightUpperArm, Forearm_R→RightLowerArm, Hand_R→RightHand, Clavicle_L→LeftShoulder, UpperArm_L→LeftUpperArm, Forearm_L→LeftLowerArm, Hand_L→LeftHand, UpperLeg_R→RightUpperLeg, LowerLeg_R→RightLowerLeg, Foot_R→RightFoot, Toe_R→RightToes, UpperLeg_L→LeftUpperLeg, LowerLeg_L→LeftLowerLeg, Foot_L→LeftFoot, Toe_L→LeftToes. `Weapon_R` has no humanoid equivalent — exclude from the map.
Warnings: rest pose is an asymmetric contrapposto (not T-pose), unit height is normalized (apply project scale), and bone roll axes follow Blender's glTF conversion. External clips must be validated per-clip; perfect retargeting is **not** claimed. The skeleton itself is verified in Godot 4.7.2, but BoneMap retargeting has not been exercised - **UNVERIFIED**.
