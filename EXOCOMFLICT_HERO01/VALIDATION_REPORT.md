# HERO_01 — Validation Report (Phases F, G, H) — Milestone 1

Toolchain actually used: Blender **4.5.15 LTS** (headless bpy, Cycles CPU renders), Python (pygltflib) for GLB inspection, and - as of the 2026-10-29 validation pass - a real **Godot 4.7.2** editor binary compiled from the official `4.7.2-stable` source inside the sandbox (section 5.1 explains why: GitHub release-asset downloads and every npm/PyPI engine route proved unusable from this environment). All Godot tests were executed headless with the dummy rendering driver: import, scene, skeleton, script, animation and transform checks are real engine execution, but **Godot rendered no pixels** - visual evidence remains the Blender Cycles renders from the shipped GLBs (sections 2-4), and a desktop visual pass by the owner is still recommended (5.5). No test is claimed beyond what was executed.
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

## 5. Godot runtime validation - EXECUTED on Godot 4.7.2 (headless)

### 5.1 How the engine was obtained (provenance)
- Official release zip: **unreachable** from the sandbox - github.com works, but release assets redirect to `release-assets.githubusercontent.com`, which the sandbox proxy blocks (recorded curl SSL failure).
- Registry routes evaluated and rejected with evidence: npm `godot-cli` (0.9 MB launcher that downloads from GitHub, so blocked); npm `@ringozz/godot` 4.7.2 (Godot-in-JS: native addons exist only for macOS/Windows - **no Linux addon** - and its wasm fallback boots against a browser canvas/WebGL, so it cannot run CLI-headless here); PyPI has no engine package. The user's Drive Godot zip is 0 bytes.
- **Working route:** official source `godot-4.7.2-stable` fetched via codeload.github.com (allowed host); `pkgconf` 2.5.1 built from its GitHub source the same way (Godot's linux detect hard-requires pkg-config); editor built with SCons, exit 0, version string `4.7.2.stable.custom_build`:
  `scons platform=linuxbsd target=editor arch=x86_64 debug_symbols=no production=no vulkan=no opengl3=no module_text_server_adv_enabled=no module_openxr_enabled=no module_webrtc_enabled=no module_websocket_enabled=no module_webxr_enabled=no module_mono_enabled=no module_raycast_enabled=no module_lightmapper_rd_enabled=no module_betsy_enabled=no module_camera_enabled=no -j2`
  Rendering drivers are off because validation here is data/logic (dummy RenderingServer); import, Skeleton3D, AnimationPlayer and GDScript are unaffected.

### 5.2 Import - PASS (after one real project fix)
First import runs produced **zero** `.import` products for every file (a minimal one-PNG control project imported fine, proving the binary healthy). Root cause, traced in engine source: our project shipped `blender/HERO_01_working.blend` *inside* the Godot project. Scanning a `.blend` file triggers the Blender format-support query; in headless mode that query errors "Cannot configure blender path in headless mode" and returns *true* (= user configuration required), and `EditorFileSystem::_update_scan_actions` then returns **before** `reimport_files(...)` - silently aborting the whole import batch. On desktop the same layout would have greeted the owner with a "Configure Blender Importer" dialog on first open.
**Fix shipped:** `.gdignore` added to non-runtime folders: `blender/`, `screenshots/`, `assets/source/`, `tools/blender/`, `tools/out/`. After the fix, `godot --headless --path . --import` imports all three GLBs (`.scn` + basecolor/metallic-roughness/normal `.ctex`) with **zero errors**. The authoring .blend, preserved source GLB and screenshots remain in the package - they are simply invisible to Godot's importer, as they should be.

### 5.3 In-engine CI - ALL PASS (`tools/godot/CICheck.tscn`, exit code 0)
Headless test scene instantiating the shipped `HERO_01.tscn` unchanged, seeking the clip and measuring in-engine (Godot 4.7.2, scene scale x1.8, so Blender 0.017 m = 0.0306 m here):
| Sample | dHandR->grip | dHandL->foregrip | Barrel (receiver->muzzle) |
|---|---|---|---|
| t=0.0s | 0.0302 m | 0.7536 m (at side) | (-0.133,-0.984,0.117) - down |
| t=0.4s | 0.0302 m | 0.5920 m | swinging forward/down |
| t=0.8s | 0.0302 m | 0.0125 m | approx. forward |
| t=1.2s | 0.0302 m | **0.0000 m** | **0.1 deg off +Z** |
| t=1.5s | 0.0302 m | **0.0000 m** | **0.4 deg off +Z** |
Also PASS: Skeleton3D found with exactly 24 bones and all required names; `AnimationPlayer` clip length 1.500 s; `BoneAttachment3D` bound to `Weapon_R`; weapon markers found; right-grip spread across the clip 0.0000 m; Hips moved 0.0000 m; feet planted. Re-run any time: `godot --headless --path . res://tools/godot/CICheck.tscn` (import once first).
**Real bug found by this CI and fixed:** the first CI run measured a constant 0.4102 m right-grip error. `hero_01.gd` anchored the solved weapon offset to the hero-root global transform, so under `ScaleRoot` (x1.8) the weapon landed at normalized scale beside the hand instead of in it. The offset is now `skeleton.get_bone_global_rest(Weapon_R).affine_inverse()` - pure skeleton space, invariant to character scale/placement. A `ReceiverPoint` marker was also added to the weapon scene so the bore line is measured through receiver->muzzle (an initial foregrip-based estimate misleadingly suggested 4.6 deg; true bore error is 0.1-0.4 deg).

### 5.4 Shipped validation scene - PASS
`godot --headless --path . --quit-after 150` runs the project's main scene `RigValidation`: exit 0, **zero SCRIPT ERRORs**, all `[RigCheck]` auto-checks PASS, solved weapon offset printed (`HERO_01: weapon local offset under Weapon_R = ... O: (0.288757, 0.398398, 0.012436)`, orthonormal basis). Interactive UI behaviour (buttons/slider/cameras) is constructed without errors headless but cannot be clicked there - desktop interaction is **LIKELY** (standard Control code).

### 5.5 Recommended owner pass (desktop official editor, ~5 minutes)
1. Open in Godot **4.7.2** desktop, Import -> `EXOCOMFLICT_HERO01/project.godot`; the first import should now complete with no dialogs.
2. Run (F5): clip plays, AUTO RIG CHECK panel all PASS. Visual pass with real rendering: textures/lighting, scrub slowly with CloseHands/CloseWeapon presets, confirm grip contact and chest clearance visually (all numerically verified already, 5.3).
3. Confirm the facing convention for the main project: character faces +Z as delivered; rotate the HERO_01 root 180 deg about Y if the main project expects -Z forward.
Not exercised anywhere yet: BoneMap retargeting of third-party clips (RIG_SPECIFICATION section 6) - remains **UNVERIFIED**.
### 5.6 Owner-preview follow-up fix: detail disappearing while moving (2026-10-30)
Owner desktop-preview feedback: fine detail on the weapon, body and hands visually disappeared while moving. Diagnosis (VERIFIED statically): the shipped GLB materials had **no `doubleSided` flag** (glTF default = false, identical to the source), so Godot created backface-culled materials. HERO_01 consists of 247 open, non-watertight shells; Blender/Cycles renders both faces (why the Blender screenshots look intact), while Godot culls back-facing shell surfaces, so thin detail (weapon panels/arch, straps/collar flaps, fingers) vanishes at certain angles during animation. Contributing risk: Godot's automatic mesh LODs simplify small shells with distance, and skinned instances can frustum-cull against their rest-pose bounds in close cameras.
Fixes shipped:
- `HERO_01_RIGGED.glb` and `HERO_01_WEAPON.glb`: material patched to **`doubleSided: true`** with `tools/patch_glb_double_sided.py` (JSON-chunk byte splice only; BIN chunk verified byte-identical by hash; sizes 22,878,116 -> 22,878,136 B and 5,326,624 -> 5,326,644 B, so section 4 numbers predate this flag-only change; preserved source untouched, MD5 `9d0ad8cd...`). Godot imports doubleSided glTF materials with face culling disabled.
- `hero_01.gd`: new `force_full_detail` export (default on) sets `lod_bias = 64` and `extra_cull_margin = 1.0` on every character/weapon `GeometryInstance3D` after weapon attachment, preventing LOD pop-out and deform-related cull pops. Applied after all critical setup; purely additive.
Status: GLB patch and geometry/weight/animation invariance **VERIFIED** (parse + hash checks above). Godot's doubleSided -> cull-disabled import mapping is standard documented behaviour (**LIKELY**; the sandbox Godot build was not retained, so no new in-engine run this round). Visual result **UNVERIFIED** until the owner re-imports (the editor auto-reimports changed GLBs; if it does not, delete the project's `.godot/` folder and reopen) and re-runs the preview. If specific parts still disappear after this fix, the cause is individual shell skin weights (e.g. grip-zone shells), not rendering settings - a screenshot/video of the exact moment will be diagnosed per shell.

### 5.7 Second owner preview: "weapon visible, detail still lacking / body looks missing" (2026-10-30)
Diagnosis first, geometry cleared. The shipped patched GLBs — the exact files Godot imports — were re-rendered in Blender Cycles at the owner's camera angles (the scene's `CloseWeapon`/`CloseHands` presets converted to Blender coordinates), neutral F0 and aim F36, plus a right-shoulder/armpit macro and a back view (`tools/blender/scripts/21_diag_closeups.py`; evidence `screenshots/diag/diag_F00_closeweapon.png`, `diag_F36_{closeweapon,closehands,shoulderR,back}.png`). **VERIFIED (Blender render of the shipped files): the geometry is complete and detailed in both poses** — no missing shells, no see-through gaps at shoulder/armpit/collar; face, armor, straps, pouches and weapon all present. The thin dark seam lines between the source's 247 loose shells are equally visible at rest — inherent to the source asset, not pose damage.
The Godot appearance came from the validation scene's presentation, not the asset: (1) MSAA was off (`rendering/anti_aliasing/quality/msaa_3d` defaults to 0), so sub-pixel-thin shells/straps shimmer and break up, reading as missing detail; (2) the Environment used flat color ambient only (0.55x white, no reflections, linear tonemap), while this asset's material is heavily metallic PBR — with no environment to reflect, metals render near-black and neighbouring dark shells merge into a detail-less black mass.
Fix (presentation only; hero geometry/materials/weights/animation byte-untouched): the `scenes/main/RigValidation.tscn` Environment now uses a `ProceduralSkyMaterial` sky (`background_mode=2`), sky-sourced ambient (`ambient_light_source=3`, energy 1.0) and reflections (`reflected_light_source=2`), and AgX tonemapping (`tonemap_mode=4`, exposure 1.1); `project.godot` sets `anti_aliasing/quality/msaa_3d=2` (MSAA 4x; read at project start — judge in a fresh F5 game window, the editor 3D viewport has its own MSAA setting). Property names and enum values were verified against the Godot 4.7 class-reference XML (`Environment`, `ProceduralSkyMaterial`, `ProjectSettings`) fetched from the engine repository.
Status: asset geometry integrity **VERIFIED**; the in-Godot visual improvement is **LIKELY** (standard rendering behaviour) but **UNVERIFIED** on desktop Godot until the owner re-runs F5 and confirms with a screenshot. Host-game note: any scene lighting this character needs an environment/sky (or reflection probes) plus MSAA, or the same crushed-black look will recur.

### 5.8 Third owner report: hole at the left abdomen during aim — real skinning defect, fixed (2026-10-30)
Correction to 5.7: its "geometry is complete in both poses" conclusion was overbroad. The renders sampled angles where the defect was occluded or edge-on, and neither they nor the background-colour pixel test can reveal a seam that opens onto dark interior. The 5.7 presentation findings (MSAA/sky) remain valid, but they were not the whole story — the owner was right to persist.
Diagnosis (scripts 22–23b renders/pair-tracking on the shipped GLB; script 31 PRE metrics in the working blend): one front-left waist shell (842 verts; rest centroid (+0.089, −0.087, 0.581); +X = character's left) carried 100% `UpperLeg_L` weights from the original distance-based assignment. The legs do not move in the clip, so the shell stayed static while its Spine/Chest-blended neighbours rotated with the aim twist. Cross-island touch pairs at that seam opened by up to +9.6 mm (normalized units ×1000, ≈17 mm at the ×1.8 Godot scale) at F36 and were closed at F0 — exactly the reported "hole during aim, gone at rest". Adjacent waist seams between differently-blended shells added true gaps (nearest-other-island distance growth) up to +6.5 mm; the waist-zone (rest z∈[0.53,0.65]) true gap on the old shipped GLB measured 8.34 mm (script 34, same method as the post-fix re-measure).
Fix (script 31, skin weights only): a single shared spine-chain height field — `Hips`→`Spine`→`Chest`→`UpperChest`→`Neck` weights as a smoothed function of rest height, fit from the asset's own spine-chain vertices (4 mm bins) to preserve the original flexibility profile — applied to all 39,100 spine-chain vertices at z∈[0.435,0.825] (faded at both ends) plus the offender shell. Shell boundaries in the band now share identical weights at equal height, so seams move coherently under any spine pose. Scripts 24–30 were gated iterations that failed their numeric save criteria and did not modify the shipped blend (kept, marked SUPERSEDED; script 27 is a read-only diagnostic). Script 32 re-exported with script 18's exact settings; `tools/patch_glb_double_sided.py` re-applied.
Preservation proof: in-Blender F0 evaluated displacement 0.0001 mm (≈0); in the exported GLB, `POSITION`/`NORMAL`/`TEXCOORD_0`/indices, the animation samplers and the inverse-bind matrices are byte-identical to the previous GLB (per-accessor hash comparison); only `JOINTS_0`/`WEIGHTS_0` changed, on exactly 39,100 of 244,770 vertices.
Verification on the shipped file (scripts 33–34, `tools/validate_exports.py`, `tools/detect_holes.py`): abdomen true gap at F36/F45 = 0.28 mm (was 8.34 mm); under stress poses far beyond the clip (Spine+Chest yaw ±40°, forward bend 35°, side bend 30°) the abdomen gap stays ≤0.53 mm (was 11.4–13.6 mm); no island pair in the clip worsened by >0.5 mm; weight sums ∈ [0.99999988, 1.00000012], zero-weight verts 0, 24 joints, 1.5 s clip intact; neutral-pose pixel components match the source renders; the magenta before/after renders (`screenshots/diag/fix_{PREFIX,NEW}_F36_waist.png`, `crop_fix_*`) show the pre-fix background glints through the seam gone after the fix. Known remaining limitation (pre-existing, not a regression): at the hip line (z<0.53) under extreme 30–40° bends the conservative vertex-distance metric reads up to ~15.7 mm (pre-fix 16.6 mm) — pants/thigh shell shear inherent to the loose-shell source; the stress renders show no see-through openings (surfaces still overlap). A dedicated pelvis weighting pass is recommended before locomotion or extreme retargeted animation.
New `HERO_01_RIGGED.glb`: 22,878,136 B, md5 `725c29296f979d0e0c9e24fe5546cba6`, sha256 `2a835722a4a1f99a9088e681aa6db76d7d9acb58d8bf858345b6f6fd61db86d4`; `HERO_01_WEAPON.glb` / `HERO_01_ANIMATIONS.glb` unchanged. Status: fix **VERIFIED** in Blender on the shipped GLB (metrics + renders); Godot desktop visual **UNVERIFIED** until the owner re-imports (the GLB changed) and confirms with an F5 screenshot. Housekeeping: the sandbox workspace rolled back mid-task (same-day diagnostic files were lost); state was recovered from origin plus a local backup, and scripts 22/23/23b + `tools/detect_holes.py` were recreated from the session record — the committed tree is complete and self-consistent.

## 6. Acceptance mapping (Milestone 1)
- Visually intact rigged humanoid in Blender: **VERIFIED** (§1–2, renders).
- `Weapon_Raise_To_Aim` in Blender: **VERIFIED** (§3).
- Same character + clip in Godot 4.7.2: **VERIFIED** at runtime (headless) - clean import, 24-bone Skeleton3D, clip playback sampled in-engine, grips/barrel/root all measured (5.2-5.4). Remaining owner item is a desktop *visual* pass only (5.5), because headless Godot draws no pixels.
- Humanoid skeleton / inspected weights / armor stability / documented weapon attachment: **VERIFIED** as detailed above.
- Specs distinguishing verified vs unverified: this report + ART_ASSET_REPORT / RIG_SPECIFICATION / ANIMATION_SPECIFICATION.

## 7. Recommended next work (not in Milestone 1)
1. Owner desktop visual pass (5.5); then lock the final character height/scale decision (currently x1.8 assumption, RIG_SPECIFICATION section 2).
2. Cheek-weld ADS variant of the aim pose if first-person-style ADS is required.
3. Locomotion set (idle/walk/run) — validate `Hand_L` wrist weights and hip/knee ranges at run extremes first.
4. Optional owner-approved LOD/decimation pass for perf budgets; split the 19 grip-fusion shells only if a bare-hand weapon-hidden state is required.
