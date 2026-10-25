# Character Rig & Animation QA — standalone Godot project

This Godot 4.7.2 project is a rendered review desk for the character GLBs, including imported skeletons, skinning, and animation playback. It is separate from the game; this branch contains character assets and QA only, not gameplay systems.

## Build and stage the character assets

From the repository root, build the five human hero tier candidates (the preserved source meshes are never overwritten):

```sh
python3 -m venv .venv
.venv/bin/pip install -r requirements-dev.txt
./tools/gltf/build_human_hero_tiers.sh
```

Then stage the 15 manifest models and verify the copies:

```sh
python3 character_visual_qa/tools/sync_assets.py
python3 character_visual_qa/tools/sync_assets.py --check
```

The five human hero entries point to optimized, skinned runtime-form candidates. The remaining entries cover robot enemy runtime/source GLBs, including the original Sentinel/Warden Drive meshes. Staged copies under `character_visual_qa/assets/` are local and Git-ignored; source and runtime assets remain in their character folders.

In Godot Project Manager, choose **Import** and select `character_visual_qa/project.godot`. Run the project to open the review desk. Automated checks verify imported structure and clip presence, but they do not replace visual review.

## Human hero tier selector

T1–T5 are five upgrade states for **one human hero identity**, not separate hero characters. The left-side **ONE HERO · UPGRADE TIER** selector has explicit `T1` through `T5` choices; selecting one loads that tier's rigged GLB. The asset list below still includes enemy and source review entries.

Each human candidate currently contains:

- The preserved real source mesh, optimized from roughly 480–493k triangles to about 36–37k triangles. The original high-poly GLB stays unchanged under `source-assets/characters/human_hero_tiers/`.
- A copied 79-joint Robot Common skeleton, with per-vertex skin weights calculated independently for that tier's own optimized mesh.
- Twelve clips: `idle`, `walk`, `run`, `raise_weapon`, `aim`, `aim_walk`, `aim_run`, `fire`, `reload`, `hit`, `death`, and `lower_weapon`.

The robot Common skeleton/animation set is reused as a rig template; Robot Common itself remains an enemy. The human outputs are **rigged review candidates**, not visually approved or connected to gameplay.

## Review desk controls

- Use the `T1`–`T5` dropdown to switch between hero upgrade tiers. The full character list switches to robots and source models as well.
- Select an animation from the bottom **Animation Review** clip dropdown. Use **PLAY / RESTART**, **PAUSE**, **STOP**, and the speed selector to inspect it in the rendered viewport.
- Play each required clip, inspect the skin and pose, then choose **MARK CLIP REVIEWED**. Approval remains blocked until required clips and the manual checklist are complete.
- Use **TEST SKIN POSE** to bend the shared arm/leg joints independently of a clip; choose **RESET POSE** afterward.
- Drag to orbit, use the mouse wheel to zoom, or choose **RESET VIEW**. Auto-rotation can be paused.
- **APPROVE** and **NEEDS FIX** update the local review record. Do not approve a model before reviewing its mesh deformation and all required clips in Godot.
- Use **Left/Right** to change the full asset list, **R** to reset the view, and **Space** to play/restart the selected clip.

## Structural checks and gate helpers

The asset build checks verify mesh budgets, per-vertex weight sums, copied joint order/hierarchy, bind-pose identity, deformation probes, weapon-grip IK, and clip/transition continuity. These are structural/analytical checks, not a substitute for local Godot GUI review.

Check all entries, or one specific tier:

```sh
python3 character_visual_qa/tools/check_gate.py
python3 character_visual_qa/tools/check_gate.py --asset-id human_hero_t1
```

The promotion helper refuses `review_only` entries. Any later integration into the consuming game is outside this branch's scope.
