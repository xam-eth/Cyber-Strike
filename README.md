# Cyber-Strike Character Assets

This branch contains **character assets, rigs, animation tooling, and a standalone visual QA project only**. It does not include the gameplay framework or a playable game.

## Updated character plan

- **One human hero with five visual upgrade tiers:** Tier 1 through Tier 5 are appearances for the same hero identity, not five separate heroes.
- The five Drive files are preserved at `source-assets/characters/human_hero_tiers/` as original source GLBs.
- Structural inspection found each human GLB is a single static mesh at approximately 480k triangles, with **no skeleton, skin, or animation clips**. These are source visuals for review—not rigged/runtime-ready heroes. Visual review, optimization, skinning, and animation remain pending.
- The former Common, Rare, and Epic robot hero models have been reclassified under `game/assets/enemies/` and `source-assets/enemies/`. Robot Common remains the shared rig template for the robot enemies; Sentinel and Warden remain enemies too.

## Character-only files

- `character_visual_qa/` — standalone Godot project for the current 15-entry visual review set.
- `source-assets/characters/human_hero_tiers/` — five human hero tier source models from Drive.
- `source-assets/enemies/` — robot source GLBs and the existing Sentinel/Warden source GLBs.
- `game/assets/enemies/` — runtime-form robot enemy GLBs and rig metadata. This folder contains assets only, not game code.
- `source-assets/tripo_references/` — individual robot/enemy character reference PNGs.
- `tools/gltf/` — character-only asset optimization, rigging, and animation tools.

## Visual review in Godot

Stage the models, then check that the local copies match the manifest:

```sh
python3 character_visual_qa/tools/sync_assets.py
python3 character_visual_qa/tools/sync_assets.py --check
```

Import `character_visual_qa/project.godot` in Godot 4.7.2 and review the five human tiers plus the robot enemy models. All review records start as `PENDING`; the human tier entries are explicitly marked unrigged and review-only. See `character_visual_qa/README.md` for controls and gate commands.

## Robot enemy rebuild tools

The retained build scripts apply only to the existing robot assets; they do not rig the new human hero GLBs:

```sh
python3 -m venv .venv
.venv/bin/pip install -r requirements-dev.txt
./tools/gltf/build_robot_enemy_variants.sh
./tools/gltf/build_enemy_models.sh
```

Human tier optimization, rigging, and animation must be treated as a separate next step after visual review. No human tier is claimed complete or wired into gameplay.

## Clone only the visual QA project and its required character assets

GitHub does not offer a direct single-folder `clone`. This sparse, shallow clone gets the Godot review project and only the character assets it reads, without the rest of the branch tree or its older history:

```sh
git clone --depth 1 --filter=blob:none --sparse --single-branch \
  --branch arena/0b00d4dd-cyber-strike \
  https://github.com/xam-eth/Cyber-Strike.git Cyber-Strike-Character-QA
cd Cyber-Strike-Character-QA
git sparse-checkout set \
  character_visual_qa \
  game/assets/enemies \
  source-assets/enemies \
  source-assets/characters/human_hero_tiers
python3 character_visual_qa/tools/sync_assets.py
```

Then import `Cyber-Strike-Character-QA/character_visual_qa/project.godot` through Godot Project Manager. For later updates, from the clone root run:

```sh
git pull --ff-only origin arena/0b00d4dd-cyber-strike
python3 character_visual_qa/tools/sync_assets.py
```
