# Character Visual QA — rendered pre-integration gate

This is a **standalone Godot 4.7.2 project**, separate from the game project. Its job is to inspect each character GLB in a real Godot 3D viewport, play the animations that will ship, record a human visual decision, and block promotion until the review is complete.

It is not a headless test and it does not change the game project, its settings, autoloads, scenes, or combat systems.

## First open

From the repository root, run:

```sh
python character_visual_qa/tools/sync_assets.py
```

This copies the manifest GLBs into `character_visual_qa/assets/` and writes `staged_assets.json`. The copies are generated and ignored by Git; the original GLBs remain in `game/assets/` or `source-assets/`.

Then in **Godot Project Manager** choose **Import**, select `character_visual_qa/project.godot` (or choose the `character_visual_qa/` folder), open the project, and run the main scene. Godot will import the GLBs before the review desk loads them.

After changing a source GLB or adding a candidate, run the sync command again. Check that the local QA copies still match their sources with:

```sh
python character_visual_qa/tools/sync_assets.py --check
```

## Review desk controls

- Choose a labeled character from the left list. The exact GLB filename, source path, mesh count, skin bindings, skeleton joint count, imported animation clips, and automated contract result are shown on screen.
- Drag in the 3D view to orbit, use the mouse wheel to zoom, or use **RESET VIEW**. **Auto rotate** can be paused.
- For animated models, select a clip, play it at a chosen speed, inspect it in the rendered viewport, then press **MARK CLIP REVIEWED**. Every required clip in the manifest must be played and marked individually before approval is enabled.
- **TEST SKIN POSE** applies a temporary arm/leg pose to the imported skeleton, including static enemies with no authored clips. **RESET POSE** restores the imported rest pose.
- Tick the manual visual checklist, record notes, then choose **APPROVE** or **NEEDS FIX**. The checklist asks a human to inspect silhouette, materials, scale/facing/rest pose, skinning, animation quality, and import problems.
- Use **Left/Right** to change character, **R** to reset the view, and **Space** to play/restart the selected clip.

`review_results.json` is the saved review record. Every asset starts as `PENDING`. A PASS is only accepted if the imported mesh/skeleton/required clips meet the manifest contract, all required manual checks are ticked, all required animation clips have been reviewed, and the reviewed GLB hash still matches the staged file.

## Pre-integration workflow for a new character

1. Preserve the incoming `.glb` under `source-assets/` (not in the game runtime folder).
2. Add an entry to `asset_manifest.json` with a unique `id`, the exact source path and GLB filename, a unique `qa_file`, expected skeleton-joint count, expected animation clip names, required checklist items, preview size/facing, and `promotion_destination` such as `game/assets/characters/new_hero.glb`. When copying an existing baseline entry, remove `baseline_already_in_game` or set it to `false`.

   ```json
   {
     "id": "hero_new",
     "label": "New Hero",
     "category": "PLAYER HERO",
     "glb_label": "new_hero.glb",
     "source": "source-assets/characters/new_hero.glb",
     "qa_file": "assets/hero_new.glb",
     "expected_joint_count": 79,
     "requires_skin": true,
     "expected_animation_names": ["idle", "walk", "run"],
     "required_checks": ["visual", "materials", "scale_pose", "skin", "animations", "import"],
     "preview_height_m": 1.78,
     "preview_yaw_degrees": 180.0,
     "promotion_destination": "game/assets/characters/new_hero.glb"
   }
   ```

3. Run `python character_visual_qa/tools/sync_assets.py`, then open/run this project in the Godot GUI and complete the review.
4. Check the gate for the reviewed model:

   ```sh
   python character_visual_qa/tools/check_gate.py --asset-id new_hero
   ```

   With no `--asset-id`, `check_gate.py` checks **every** character in the manifest.
5. Only after a PASS, promote the exact reviewed GLB:

   ```sh
   python character_visual_qa/tools/promote_character.py --asset-id new_hero
   ```

   The promotion command rechecks the review status, checklist, clip reviews, source/staged hashes, and automated report. It refuses to overwrite an existing file unless `--overwrite` is explicitly supplied. Wire the promoted model into gameplay only after this step and the normal game-specific integration checks.

The desk lists the three current player heroes, both **runtime/rigged enemy GLBs**, and both **original enemy GLBs downloaded from Google Drive** as separate labeled entries. The two Drive-source entries let you compare the untouched source mesh/materials with the runtime result; they are unrigged, static reference assets and are marked review-only so they can never be promoted directly. All review records start as `PENDING`. The three player heroes have ten required clips each. The two runtime enemies currently have no authored clips, so their clip playback check is `N/A`; use **TEST SKIN POSE** to inspect their imported weights in the rendered viewport. The runtime baseline assets are not removed from the existing game. Future characters should be staged from `source-assets/` and promoted only through the gate above.

The manifest currently assumes each character is a self-contained `.glb` with embedded textures. If a new asset depends on external texture files, add support for those dependencies to the sync process before reviewing it.
