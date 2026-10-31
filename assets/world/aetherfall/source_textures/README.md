# Source texture provenance

The four PNG files in this directory were generated during Arena sessions as flat material-albedo inputs:

- `ai_weathered_steel.png`
- `ai_poured_concrete.png`
- `ai_sedimentary_rock.png`
- `citadel_weathered_metal_base.png`

They are source inputs, not direct screenshots or third-party scans. The first three are resized/blended by `tools/blender/build_aetherfall.py`; the Citadel panel albedo is processed by `tools/blender/build_ice_planet.py` into `aether_citadel_metal` albedo + tangent-space normal + packed metallic/roughness/AO maps. The builders pack referenced image inputs into their editable `.blend` source and embed them in affected GLBs. Do not call them seamless scans or externally licensed texture photographs.
