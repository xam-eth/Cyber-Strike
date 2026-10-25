# Cyber-Strike Character Assets

This branch contains **character meshes, rigs, animation clips, glTF build tooling, and a standalone Godot QA project only**. It does not include the wider gameplay framework or a playable game.

## Character plan and current state

- **One human hero with five visual upgrade tiers:** T1 through T5 are appearances for the same hero identity, not five separate heroes.
- The five original Drive GLBs are preserved unchanged at `source-assets/characters/human_hero_tiers/Hero_Human_T1.glb` through `Hero_Human_T5.glb`.
- Optimized review candidates live at `game/assets/characters/human_hero_tiers/`. Each uses its own per-mesh skin weights on a copied 79-joint Robot Common rig and currently contains twelve clips: idle, walk, run, raise weapon, aim, aim-walk, aim-run, fire, reload, hit, death, and lower weapon.
- The former Common, Rare, and Epic robot hero models have been reclassified as enemies under `game/assets/enemies/` and `source-assets/enemies/`. Robot Common remains the shared rig/animation template; Sentinel and Warden remain enemies too.
- The human models and their animation/skin candidates are **not visually approved or wired into gameplay**. Inspect all tiers, skin deformation, and clips in the local Godot QA project before any integration.

## Character-only files

- `character_visual_qa/` — standalone Godot project with a T1–T5 hero selector, rendered rig/skin/animation review controls, plus robot-enemy review entries.
- `source-assets/characters/human_hero_tiers/` — five original high-poly source meshes.
- `game/assets/characters/human_hero_tiers/` — optimized, rigged, animated review candidates and generated rig profiles.
- `source-assets/enemies/` — robot source GLBs and the existing Sentinel/Warden source GLBs.
- `game/assets/enemies/` — runtime-form robot enemy GLBs and rig metadata. This folder contains assets only, not game code.
- `source-assets/tripo_references/` — individual robot/enemy character reference PNGs.
- `tools/gltf/` — character-only asset optimization, rigging, and animation tools.

## Build the human hero tier candidates

The pipeline keeps source meshes unchanged, optimizes their real geometry, generates mesh-specific skin weights from the copied Robot Common rig, and writes animation clips plus weapon raise/lower transitions:

```sh
python3 -m venv .venv
.venv/bin/pip install -r requirements-dev.txt
./tools/gltf/build_human_hero_tiers.sh
```

Runtime candidates target a 50,000-triangle maximum. The build verifies mesh budgets, 79-joint order/hierarchy, skin-weight sums, bind-pose identity, deformation probes, weapon grip/socket IK, clip presence, and raise/lower transition continuity.

## Standalone Godot review

Stage the 15 QA assets and verify they match their manifest sources:

```sh
python3 character_visual_qa/tools/sync_assets.py
python3 character_visual_qa/tools/sync_assets.py --check
```

Import `character_visual_qa/project.godot` in Godot 4.7.2. Choose T1–T5 from the dedicated hero-tier dropdown, then use the animation selector and playback controls to review the rig and clips. All review records start as `PENDING`; automated checks are not a substitute for visual GUI review. See `character_visual_qa/README.md` for the full controls and gate commands.

## Rebuild the robot enemy assets

```sh
./tools/gltf/build_robot_enemy_variants.sh
./tools/gltf/build_enemy_models.sh
```

## Clone only the QA project and required character assets

GitHub does not offer a direct single-folder `clone`. This sparse, shallow clone gets the Godot review project and only the character assets it reads, without the rest of the branch tree or its older history:

```sh
git clone --depth 1 --filter=blob:none --sparse --single-branch \
  --branch arena/0b00d4dd-cyber-strike \
  https://github.com/xam-eth/Cyber-Strike.git Cyber-Strike-Character-QA
cd Cyber-Strike-Character-QA
git sparse-checkout set \
  character_visual_qa \
  game/assets/characters/human_hero_tiers \
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
