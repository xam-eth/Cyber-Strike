# Source texture provenance

The three PNG files in this directory were generated during this Arena session as flat material-albedo inputs:

- `ai_weathered_steel.png`
- `ai_poured_concrete.png`
- `ai_sedimentary_rock.png`

They are source inputs, not direct screenshots or third-party scans. `tools/blender/build_aetherfall.py` resizes and blends them with deterministic procedural patterns; it then generates normal and packed ORM maps, packs all referenced image inputs into `source/aetherfall_kit.blend`, and embeds the exported textures in every affected GLB. Do not call them seamless scans or externally licensed texture photographs.
