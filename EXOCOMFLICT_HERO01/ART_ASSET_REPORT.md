# HERO_01 — Art Asset Report (Phase A)

Project: EXOCONFLICT: STELLAR HORIZON — HERO_01 production preparation (external contribution, Milestone 1).
Status labels used throughout: VERIFIED / LIKELY / ASSUMPTION / UNKNOWN / UNVERIFIED.

## 1. Authoritative source
- File: `assets/source/HERO_01.glb` (untouched copy of the owner's Google Drive asset). **VERIFIED**
- Size 18,888,488 bytes; MD5 `9d0ad8cd9e2bea0627a2275dafa19c30`; SHA-256 `f067d3f574e5fa0404b543fd9a86974e9a73f529a1a778fbd029debd20945d50`. **VERIFIED**
- No substitute, recreation or generated replacement was used at any point. All work derives from this file. **VERIFIED**
- The repository character `source-assets/characters/hero/hero_rigged_source.glb` is a *different* (helmeted) character and was used for comparison only; no weights or skeleton were transferred from it. **VERIFIED**

## 2. Source structure (measured)
- glTF 2.0 (Tripo-generated), 1 mesh / 1 primitive, 262,714 vertices, 494,060 triangles, attributes POSITION/NORMAL/TEXCOORD_0 only; no skins, no animations, no morphs. **VERIFIED**
- 247 disconnected mesh shells (islands); non-watertight shells; 0 degenerate triangles found. **VERIFIED**
- One PBR material: baseColor + metallicRoughness + normal maps, all 2048×2048 embedded PNG; metallic/roughness *factors* are 1.0/1.0 (maps carry the variation — a source quirk to be aware of in-engine); OPAQUE. **VERIFIED**
- Character: unhelmeted male, dark hair, black/gold hooded jacket with chest armor, belts/pouches/straps, cargo pants, knee armor, armored boots; relaxed contrapposto stance; futuristic rifle held vertically, barrel down, in the right hand, clear of the torso. **VERIFIED (baseline renders `screenshots/baseline/`)**
- Bounds (Blender Z-up metres-as-authored): x −0.266…0.266, y −0.102…0.102, z 0…1.0 → the character is authored at **normalized height 1.0 unit**, feet at z=0. Faces −Y in Blender (= +Z in glTF/Godot space). **VERIFIED**
- Real-world height is therefore a project decision: the Godot validation project scales him to 1.8 m (see RIG_SPECIFICATION). **ASSUMPTION — owner to confirm target height.**

## 3. Weapon separability
The source is a *single fused mesh*: body, clothing, armor and rifle are one primitive. Separation was performed at whole-shell (island) granularity only — no faces were cut, so geometry, UVs and materials are bit-preserved and vertex counts conserve exactly (262,714 = 244,770 body + 17,944 weapon). **VERIFIED**
- Weapon object: 24 shells / 17,944 verts (island IDs listed in `tools/blender/scripts/05_build_rig.py` and VALIDATION_REPORT). Selection = spatial rule around the modelled rifle + per-island visual adjudication from contact renders (`screenshots/audit/contact_*.jpg`). **VERIFIED**
- 19 grip-zone shells remain in the body object: they are fragments of glove/grip interface that are fused with the hand at shell granularity. They are skinned to the hand/forearm, sit inside the grip, and are occluded by the separate weapon model in both rest and aim poses. **VERIFIED visually; documented trade-off** — splitting them per-face would risk visible seams in the hero's hand, which the brief forbids. If the owner wants a perfectly clean bare hand with the weapon hidden, these shells are the exact list to revisit (`tools/out/contact_islands.json`).

## 4. Visual preservation baseline
Baseline renders of the untouched source were captured before any modification (`screenshots/baseline/`, 5 views, Cycles CPU, fixed camera/lighting). The rigged neutral render from the *exported* GLBs (`screenshots/01_neutral_pose.png`) matches the baseline in identity, silhouette, palette and material response. **VERIFIED by direct visual comparison.**
No decimation, remeshing, repainting, UV or material changes were performed at any stage. **VERIFIED**

## 5. Working files & regeneration
- `blender/HERO_01_working.blend` (Blender 4.5 LTS) — source-preserving working file containing separated body/weapon, armature, final weights and the `Weapon_Raise_To_Aim` action.
- Every transformation is scripted and reproducible: `tools/blender/scripts/01…20` (numbered pipeline; run via `tools/blender/run_bpy.sh`). Audit data in `tools/out/`.
- Known environment note: authoring used Blender 4.5.15 (bpy module) headless, Cycles CPU renders only; no Eevee/viewport checks were possible. **VERIFIED limitation**

## 6. Risks / notes for production
- 494k triangles with a single 2048² texture set and no LODs — acceptable for a PC hero character; mobile/console budgets may later want an owner-approved LOD pass (explicitly *not* done here, per brief). **LIKELY**
- Tripo shells are non-watertight and thin in places; extreme poses beyond the tested ranges may reveal inter-shell gaps. Tested ranges are listed in VALIDATION_REPORT. **VERIFIED within tested ranges**
- Fingers are modelled as closed glove forms; there are no finger bones in the brief's skeleton, so grip poses rely on the modelled hand shape. **VERIFIED**
