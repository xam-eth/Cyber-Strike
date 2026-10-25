# Cyber-Strike Character Assets

This branch snapshot is intentionally limited to **character design assets, rigs, animation retargeting, and standalone visual QA**. It is not the full Cyber-Strike game project: gameplay systems, UI, worlds, weapons, web export, and general game tooling are outside this scope and are not included in this branch's current tree.

## Contents

- `source-assets/characters/` — preserved Common, Rare, and Epic hero source files.
- `source-assets/enemies/` — preserved Sentinel and Warden source GLBs.
- `source-assets/tripo_references/` — individual character reference PNGs only.
- `game/assets/characters/` and `game/assets/enemies/` — character GLBs and rig metadata, kept at runtime-compatible paths for the receiving game project.
- `tools/gltf/` — character-only optimization, animation-retarget, and enemy-rigging tools.
- `character_visual_qa/` — separate Godot project for importing and visually reviewing the seven character GLBs before approval.

The `game/assets/` directory here contains only character assets; there is no main game project or gameplay integration in this snapshot. The consuming game's controller, UI, scenes, and systems are deliberately not part of this branch tree.

## Character deliverables

| Character | Asset state |
| --- | --- |
| Common hero | Existing 79-joint runtime model and rig profile used as the shared rig/animation template. |
| Rare hero | Optimized GLB retargeted to its own rig profile; 10 runtime clips. |
| Epic hero | Optimized GLB retargeted to its own rig profile; 10 runtime clips. |
| Iron Sentinel enemy | Original source preserved; optimized runtime GLB weighted to the Common 79-joint skeleton. No authored enemy clips yet. |
| Iron Warden Boss enemy | Original source preserved; optimized runtime GLB weighted to the Common 79-joint skeleton. No authored enemy clips yet. |

The enemy GLBs have per-mesh skin weights; adding a skeleton alone would not make their original meshes deform. Source models remain separate from optimized runtime outputs.

## Rebuild the character assets

Requirements: Python 3, Node/npm, and Godot 4.7.2 for the optional visual QA project.

```sh
python3 -m venv .venv
.venv/bin/pip install -r requirements-dev.txt
./tools/gltf/build_hero_variants.sh
./tools/gltf/build_enemy_models.sh
```

The build scripts install the pinned glTF dependencies with `npm ci` when needed. They use the Common runtime GLB as the shared rig/animation template and leave the preserved source GLBs untouched.

## Visual QA

```sh
python3 character_visual_qa/tools/sync_assets.py
python3 character_visual_qa/tools/sync_assets.py --check
```

Open `character_visual_qa/project.godot` in Godot 4.7.2 and perform the rendered visual review there. The review records start as `PENDING`; this repository does not claim GUI verification or an approval result. See `character_visual_qa/README.md` for the review steps and gate commands.

This asset-only snapshot intentionally does not wire models into gameplay. Any receiving game project should perform its own Godot import and integration checks after the character review passes.

## Clone only the character snapshot

The branch preserves its earlier Git history, which contains the original game framework. To fetch only the current character-only snapshot and avoid downloading that old history, use a shallow clone:

```sh
git clone --depth 1 --single-branch \
  --branch arena/0b00d4dd-cyber-strike \
  https://github.com/xam-eth/Cyber-Strike.git Cyber-Strike-characters
```
