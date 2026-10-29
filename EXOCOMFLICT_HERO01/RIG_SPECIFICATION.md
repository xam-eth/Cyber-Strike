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
- Bone names in Blender, in the exported GLB skin, and (expected) in Godot `Skeleton3D` are **identical** — no renaming layer. **VERIFIED for Blender+GLB; Godot side UNVERIFIED (no Godot binary in authoring environment).**
- `Root` and `Weapon_R` are non-deforming (zero painted weight, by construction); all other 22 bones deform. **VERIFIED**
- No IK/control bones are exported; animation is baked bone keys (see ANIMATION_SPECIFICATION).
- Joint coordinates (Blender Z-up, as-modeled space): `tools/out/joints_final_v1.json`. Key points: Hips at pelvis z≈0.52; right wrist (Hand_R head) (−0.185, −0.025, 0.465); `Weapon_R` head (−0.192, −0.033, 0.452), tail (−0.207, −0.040, 0.380) — placed on the rifle grip axis in the right palm. **VERIFIED**

## 2. Rest pose, axes, scale, root motion
- Bind/rest pose = the as-modeled contrapposto stance (weight shifted, head offset x≈+0.043). It is **not** a symmetric T/A-pose — retargeted external animations should be authored/adjusted with this in mind. **VERIFIED**
- Blender: Z-up, character faces −Y. Exported GLB (Y-up): character faces +Z, height 1.0 unit, origin at ground centre between the feet. **VERIFIED**
- Godot validation project: `ScaleRoot` applies uniform ×1.8 → 1.8 m tall (**ASSUMPTION**, change in `scenes/characters/HERO_01.tscn`). Character faces +Z as imported; rotate the HERO_01 root 180° about Y if the main project requires the −Z forward convention. **LIKELY (axis math VERIFIED; Godot runtime UNVERIFIED)**
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
- In Godot, `scripts/characters/hero_01.gd` creates a `BoneAttachment3D` on `Weapon_R`, instances the weapon scene, and solves the local offset as `inverse(Weapon_R global rest)` so the Blender-authored grip is reproduced regardless of importer bone bases. The solved offset is printed at startup and can be frozen via the `use_manual_weapon_offset` export var — grip adjustment never requires editing hero geometry. **Logic VERIFIED by equivalent Blender math; Godot execution UNVERIFIED.**
- Grip reference points (Blender rest space): grip (−0.192, −0.033, 0.452); foregrip (−0.215, −0.062, 0.315); muzzle (−0.238, −0.080, 0.205); barrel rest direction ≈ (−0.14, −0.12, −0.98) (pointing down).

## 5. Export settings (reproduce exactly)
Blender 4.5 glTF exporter, per script `tools/blender/scripts/18_export_polish.py`:
format GLB; `use_selection`; Y-up; **no modifier apply**; skins on; *deformation-bones-only OFF* (all 24 bones exported, incl. `Weapon_R`); animations = ACTIONS mode, force-sampling ON, optimize-animation-size OFF; materials EXPORT (rig + weapon) / NONE→superseded by skeleton-only animations file (script 20). Scene frame rate 30 fps.
Deliverable GLBs: `assets/characters/HERO_01_RIGGED.glb` (body+skin+clip), `assets/weapons/HERO_01_WEAPON.glb`, `animations/HERO_01_ANIMATIONS.glb` (skeleton + clip only, 67 KB — retarget/reference; the playable clip also lives inside RIGGED).

## 6. Retargeting preparation (Phase E)
Suggested Godot `SkeletonProfileHumanoid` BoneMap (our bone → profile name):
Root→Root, Hips→Hips, Spine→Spine, Chest→Chest, UpperChest→UpperChest, Neck→Neck, Head→Head, Clavicle_R→RightShoulder, UpperArm_R→RightUpperArm, Forearm_R→RightLowerArm, Hand_R→RightHand, Clavicle_L→LeftShoulder, UpperArm_L→LeftUpperArm, Forearm_L→LeftLowerArm, Hand_L→LeftHand, UpperLeg_R→RightUpperLeg, LowerLeg_R→RightLowerLeg, Foot_R→RightFoot, Toe_R→RightToes, UpperLeg_L→LeftUpperLeg, LowerLeg_L→LeftLowerLeg, Foot_L→LeftFoot, Toe_L→LeftToes. `Weapon_R` has no humanoid equivalent — exclude from the map.
Warnings: rest pose is an asymmetric contrapposto (not T-pose), unit height is normalized (apply project scale), and bone roll axes follow Blender's glTF conversion. External clips must be validated per-clip; perfect retargeting is **not** claimed. **UNVERIFIED until tested in Godot.**
