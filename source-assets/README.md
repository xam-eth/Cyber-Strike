# Editable DCC sources (outside the Godot project)

Blender authoring output for the uploaded hero belongs at
`source-assets/characters/hero/hero_source.blend`. The playable exported rig
remains `game/assets/characters/hero/hero.glb`, with the measured rifle at
`game/assets/weapons/futuristic_rifle/rifle.glb`.

The `.blend` stays **outside** `game/` intentionally. Godot automatically
attempts to import `.blend` files as scenes during its headless editor scan;
when a source and its exported GLB live together inside that scan, the second
import can interfere with completion of unrelated model imports and enlarge
the Web export. This is a DCC source, not a second runtime character.

Use the opt-in Blender CI authoring job documented in
`tools/blender/author_hero.py`. Its JSON inspection report records the actual
bones, markers, measured bounds, clip inventory, and remaining visual QA work.
The `.blend` and exported GLB are only published after a Godot smoke run.
