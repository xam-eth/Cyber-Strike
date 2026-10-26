# Cyber-Strike Character Assets

This branch contains **character meshes, rigs, animation clips, glTF build tooling, and a standalone Godot QA project only**. It does not include the wider gameplay framework or a playable game.

## Character plan and current state

- **One human hero with five visual upgrade tiers:** T1 through T5 are appearances for the same hero identity, not five separate heroes.
- The five original Drive GLBs are preserved unchanged at `source-assets/characters/human_hero_tiers/hero_human_tier_1_source.glb` through `hero_human_tier_5_source.glb`.
- Optimized review candidates live at `game/assets/characters/human_hero_tiers/`. Each uses its own per-mesh skin weights on a copied 79-joint Robot Common rig and currently contains twelve clips: idle, walk, run, raise weapon, aim, aim-walk, aim-run, fire, reload, hit, death, and lower weapon.
- Robot Common, Robot T2 Rare, and Robot T3 Epic are enemies—not player heroes—and live under `game/assets/enemies/` and `source-assets/enemies/`. Robot T2 Rare and T3 Epic are additionally marked as animation references for the Human Operative hero; Robot Common remains the shared rig/animation template. Iron Sentinel and Iron Warden are enemies too.
- Runtime GLB names are role-first: `hero_human_tier_1.glb` through `hero_human_tier_5.glb`; `enemy_robot_common.glb`, `enemy_robot_tier_2_rare.glb`, and `enemy_robot_tier_3_epic.glb`.
- Runtime rig profiles distinguish `character_role: player_hero` from `character_role: enemy` and carry canonical identity metadata. Robot Common is Common with no inferred numeric tier; the Rare and Epic robot references remain T2 and T3.
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

Runtime candidates target a 50,000-triangle maximum. Human skin weights are constrained per connected mesh island and anatomical bone family, preventing hands resting against the thighs from pulling nearby leg or torso geometry into the aim pose. The retargeter also deforms the actual skinned mesh through seven `aim_run` loop phases and enforces edge-stretch and bounds limits; it does not rely on animation-track checks alone. Other build checks cover mesh budgets, 79-joint order/hierarchy, skin-weight sums, bind-pose identity, weapon grip/socket IK, clip presence, and raise/lower transition continuity. The retarget checks require `aim_walk`/`aim_run` to use the exact walk/run key times, keep the upper body on the aim pose, and match the lower-body gait. Root/Hip translation is transferred only when that joint actually moves in the source clip, so a static Hip cannot counteract a moving BoneRoot during death.

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
