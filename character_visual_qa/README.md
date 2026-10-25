# Character Visual QA

This character-only branch has **one standalone Godot project for character review** (Godot 4.7.2): `character_visual_qa/project.godot`. Open that file in Godot Project Manager; the repository root is not a Godot project. The reviewer is separate from gameplay.

## Complete setup and open

From the repository root, stage the manifest assets:

```sh
python3 character_visual_qa/tools/sync_assets.py
```

In Godot Project Manager, import `character_visual_qa/project.godot` and run the project. Godot will import the staged GLBs before the review scene loads them.

## Review controls

- **T1–T5** switch between five upgrades of the same human hero.
- **Other models** selects robot runtime models and source comparisons. Original Drive enemy GLBs remain separate, review-only entries.
- The information panel reports mesh count, skinned mesh count, skeleton joints, and expected animation clips found. **STRUCTURE CHECK** is an automated import check, not a visual approval.
- Choose an animation clip, then use **PLAY**, **PAUSE**, **STOP**, and the speed selector. Use **TEST SKIN POSE** and **RESET POSE** to inspect deformation.
- Drag in the viewport to orbit; use the mouse wheel to zoom. **RESET VIEW** and **Rotate** are in the left panel. Keyboard: **Left/Right** changes model, **R** resets the view, **Space** plays the selected clip.

After changing or adding a source GLB, run the staging command again. To verify the staged copies match their sources:

```sh
python3 character_visual_qa/tools/sync_assets.py --check
```

All visual review is still performed by the user in local Godot; automated structure checks do not replace it.
