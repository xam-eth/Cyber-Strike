# Gate 03 — Base Mesh clay review

These are **source-review renders only**, generated from `source/aetherfall_base_mesh.blend`. They show a deliberately low-resolution, functional-massing **study for three concept families only** before High-Poly detailing, retopology, UVs, baking, or PBR work. They do not cover the 51 runtime GLBs and are not Gate 03 acceptance, runtime art, final lighting, or evidence of Gate 09 visual approval. See `../INDUSTRY_PRODUCTION_STANDARD.md` for the asset-level production requirement.

| Review | Source family | What is being checked |
|---|---|---|
| `01_archive_base_clay.png` | `BM_ARCHIVE` | arrival plinth, nested access threshold, buttresses, service wings, central shell, crown, and reserved objective-core volume |
| `02_traversal_base_clay.png` | `BM_TRAVERSAL` | deck thickness, under-deck load path, rail posts/handrail, and central service tray |
| `03_recovery_base_clay.png` | `BM_TERRAIN` | watertight glacier mass, broad slope/ledge arrangement, and cliff-anchor volumes |

Regenerate the source with:

```sh
LD_LIBRARY_PATH=/tmp/xlibs .venv/bin/python tools/blender/build_aetherfall_base_mesh.py
LD_LIBRARY_PATH=/tmp/xlibs .venv/bin/python tools/blender/render_aetherfall_base_mesh.py
```

The temporary library path is an Arena headless-Blender dependency, not a project runtime dependency.
