# Ready-to-submit correction for GitHub issue #4

> GitHub issue creation succeeded, but this integration token was denied permission to edit or comment on issue #4. This is the corrected body for a maintainer to apply. It supersedes the original broader scope; it does not request reintroducing the older high-poly hero.

**Owning domain:** Character Content
**Severity:** Medium
**Integration status:** The older candidate branch was not merged because the current branch already contains its optimized, more complete derivative. Runtime integration is present; release/provenance and physical-device budget checks remain open.

## Reconciled evidence

- Older source branch: `arena/9f883711-cyber-strike`, tip `9e0ddadcb73aec9bdc935bbc905ecdce23e33568`.
- Its candidate was `HERO-3d-tier_1-common.glb`: 24,436,604 bytes, 79 joints, 253,387 vertices / 482,282 triangles, and only `idle`, `walk`, `run`.
- The current `game/assets/characters/hero/hero.glb` is a later optimized derivative of the same Tripo asset, supported by `HERO_RIG_PIPELINE.md`, matching source bounds/image names/joint structure, and the repository's GLTF/Blender authoring pipeline.
- Current runtime asset: approximately 36k triangles, 3.06 MB, the same 79-joint rig, and ten clips: `aim`, `aim_run`, `aim_walk`, `death`, `fire`, `hit`, `idle`, `reload`, `run`, `walk`.
- The older direct `player_controller` idle/walk/run adapter is superseded by the newer `CharacterVisual` combat/attachment implementation.
- Final reconciliation CI run `40088522484` passed all 29 Godot tests, including hero rig, hero visibility, showcase, and the gameplay vertical slice.

## Current behavior

The optimized hero is already connected to gameplay and the 3D showcase. Merging the older branch would downgrade that implementation and add an unused 24 MB source copy. No such downgrade was made.

## Expected correction / remaining work

Confirm usage and redistribution terms for the uploaded Tripo source and derived runtime asset, and assess the optimized hero on the intended mobile hardware. The older candidate's provenance noted that license terms were not included; later optimization does not by itself resolve rights or device-performance evidence.

## Reproduction steps

1. Compare `HERO_RIG_PIPELINE.md` and `tools/gltf/prepare_assets.mjs` with the older branch's `ASSET_PROVENANCE.md`.
2. Inspect both GLBs' JSON: image names, joint/node structure, POSITION bounds, mesh counts, and animation names.
3. Run the hero/showcase/gameplay smoke tests on the integrated branch.

## Impact

This does not block current gameplay integration. It blocks public/commercial redistribution claims and Android/mobile performance claims until the remaining evidence is supplied.

## Acceptance criteria

- Source and derived-asset usage/redistribution terms are documented.
- The intended runtime hero is explicitly identified so the older high-poly candidate is not reintroduced accidentally.
- Physical-device or representative mobile GPU profiling records frame time and memory for the integrated hero and weapon.
- Any newly supplied replacement preserves the existing combat clips, measured hand attachment/muzzle alignment, and all hero/showcase/gameplay tests.

## Integration dependencies

`HeroDefinition.model_scene`, `player.tscn` `VisualRoot.model_scene`, `hero_rig.json`, `CharacterVisual`, and the UI showcase already reference the same optimized model.

## Ownership boundary

Character Content owns asset rights, visual identity, rigs, animation assets, and content-level optimization. Gameplay Core owns the adapter and contract validation, not replacement of the approved character.

## Validation requirements

Retain the passing Godot hero/showcase/gameplay checks and add physical-device profiling before making mobile performance claims.
