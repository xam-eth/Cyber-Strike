# Character Visual QA — standalone review project

This Godot 4.7.2 project is for inspecting character GLBs and their imported skeletons, skin weights, materials, and animation clips. It is separate from the game; this branch contains character assets and QA only, not gameplay systems.

## Stage and open the project

From the repository root:

```sh
python3 character_visual_qa/tools/sync_assets.py
python3 character_visual_qa/tools/sync_assets.py --check
```

The sync tool stages the 15 manifest GLBs under `character_visual_qa/assets/`. These copies are local and Git-ignored; original/source and runtime-form assets remain under `source-assets/` and `game/assets/`. The sync removes staged GLBs no longer listed in the manifest.

In Godot Project Manager, choose **Import** and select `character_visual_qa/project.godot`. Run the project to open the review desk. Structural checks are not a substitute for visually inspecting the models in Godot.

## Updated role and tier plan

- **Human Operative Tiers 1–5** are five visual upgrade states of one hero identity, not five different heroes. The Drive GLBs are currently unrigged static source meshes: no skeleton, skin, or animation clips. Their QA entries are source-only and review-only; they are not approved for runtime use.
- **Robot Common, Rare, and Epic** are now classified as enemy models, not player heroes. Their runtime-form GLBs and preserved source GLBs are listed separately for comparison. Robot Common remains the shared rig/animation template for the robot enemy family.
- **Iron Sentinel** and **Iron Warden Boss** remain enemies. Their original unrigged Drive GLBs appear as separate review-only entries alongside their rigged runtime-form assets.

All 15 review records start as `PENDING`. The five human tiers require visual, material, scale/pose, and import review; they are not expected to contain a skeleton or animations yet. Runtime robot entries require skin review, and the robot hero-origin tiers also list their imported clips. Sentinel/Warden currently have no authored animation clips.

## Review desk controls

- Select a labeled hero tier or enemy. The desk shows the GLB filename, source path, mesh count, skin bindings, joint count, clips, and automated contract result.
- Drag to orbit, use the mouse wheel to zoom, or choose **RESET VIEW**. Auto-rotation can be paused.
- Play and mark required clips reviewed where an asset has clips. For rigged robots, use **TEST SKIN POSE** to inspect deformation. The unrigged human sources have no skin pose or animation to test yet.
- Complete the visual checklist, add notes, then record **APPROVE** or **NEEDS FIX**. This is a review record, not a claim that assets have been integrated into gameplay.
- Use **Left/Right** to change asset, **R** to reset the view, and **Space** to play/restart the selected clip.

## Gate helpers

Check all entries, or one specific entry:

```sh
python3 character_visual_qa/tools/check_gate.py
python3 character_visual_qa/tools/check_gate.py --asset-id human_hero_t1
```

The promotion helper refuses `review_only` entries. Human tiers must not be promoted until they have completed the separate optimization, rigging, animation, and approval steps. Any later integration into the consuming game is outside this branch's scope.
