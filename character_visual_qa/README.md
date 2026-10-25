# Character Visual QA — standalone pre-integration review

This is a standalone Godot 4.7.2 project for visually reviewing character GLBs, their imported skeletons, skin weights, materials, and animation clips. It is separate from the consuming game. This branch intentionally contains no gameplay framework or character-to-gameplay wiring; the `game/assets/` paths here hold assets only.

## Stage and open the project

From the repository root, run:

```sh
python3 character_visual_qa/tools/sync_assets.py
python3 character_visual_qa/tools/sync_assets.py --check
```

The sync tool copies the seven manifest GLBs to `character_visual_qa/assets/` and writes `staged_assets.json`. These local copies are ignored by Git; the preserved sources and runtime-form assets stay in `source-assets/` and `game/assets/`.

In Godot Project Manager, import and open `character_visual_qa/project.godot`, then run the main scene. Godot imports the GLBs before the review desk loads them. This is the intended visual review path; static checks are not a substitute for inspecting the models in the Godot viewport.

## Review desk

- Select a labeled hero or enemy. The desk displays the exact GLB, mesh count, skin bindings, skeleton joints, imported clips, and structural contract result.
- Drag to orbit, use the mouse wheel to zoom, or choose **RESET VIEW**. Auto-rotation can be paused.
- Play every required animation clip and mark it reviewed. Static enemies have no authored clips yet; use **TEST SKIN POSE** to check their imported skin weights.
- Complete the manual visual checklist, add notes, and record **APPROVE** or **NEEDS FIX**. The checklist covers silhouette, materials, scale/facing/rest pose, skinning, animation, and import issues.
- Use **Left/Right** to change character, **R** to reset the view, and **Space** to play/restart the selected clip.

`review_results.json` starts every entry as `PENDING`. A PASS requires the manifest contract, completed manual checks, reviewed required clips, and an unchanged reviewed GLB hash. No entry is approved in advance.

## Gate and promotion helpers

Check every manifest entry, or a specific one:

```sh
python3 character_visual_qa/tools/check_gate.py
python3 character_visual_qa/tools/check_gate.py --asset-id hero_tier_2_rare
```

The promotion helper only accepts an approved, hash-matched candidate with a `promotion_destination` in the manifest:

```sh
python3 character_visual_qa/tools/promote_character.py --asset-id hero_new
```

Promotion copies the reviewed GLB to its asset destination. Importing it into, and wiring it to, the consuming game remains a separate integration task; this branch contains no game systems.

## Current roster

The desk lists Common, Rare, and Epic player heroes; the rigged runtime-form Iron Sentinel and Iron Warden Boss; and each enemy's original unrigged source GLB as a separate **review-only** comparison entry. The source entries cannot be promoted. The three player heroes have ten required clips each. The two runtime enemy models currently have no authored animation clips.

Future character candidates should be preserved under `source-assets/`, added to `asset_manifest.json`, staged with the sync tool, and reviewed in Godot before approval. Keep original sources separate from runtime-form outputs.
