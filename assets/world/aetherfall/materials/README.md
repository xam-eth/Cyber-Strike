# PBR material output

`tools/blender/build_aetherfall.py` rebuilds these maps and embeds the maps needed by each module in its GLB.

| Suffix | Encoding | Godot/glTF use |
| --- | --- | --- |
| none | sRGB RGBA | base colour / albedo |
| `_normal` | non-colour tangent-space RGB | `normalTexture` |
| `_orm` | non-colour RGBA; **R=metallic, G=roughness, B=AO** | glTF metallic-roughness texture (R/G) |

Surface families cover deck paint, concrete, canyon rock, two metal finishes, composite, rubber/cable, hazard paint, and warning paint. The PBR output is authored by the Blender production script and checked by `tests/check_assets.py`.

The albedos are a controlled blend of procedural maps and three AI-generated source textures in `../source_textures/`; they are not scans and are not represented as scans. Normal and ORM maps are generated from the final blended albedo by the Blender script.
