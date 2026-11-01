# Gate 04 — High-Poly detailing clay review

These renders review physical **bake-source** geometry in `source/aetherfall_high_poly.blend`. The Gate 03 collections remain for silhouette context; all Gate 04 detail is kept separately in `HP_ARCHIVE`, `HP_TRAVERSAL`, and `HP_TERRAIN`. Nothing here is exported to the game.

| Review | Geometry verified in the source |
|---|---|
| `01_archive_high_poly_clay.png` | nested gate leaves and lintel, threshold sill, armor plates, panel seams, load ribs, service conduits, louver blades, fasteners, crown collar/sockets, core cage |
| `02_traversal_high_poly_clay.png` | deck grate bars, channels, expansion joints, rail brackets, physical bolts, under-deck cable bundles, service-tray lids/latches |
| `03_recovery_high_poly_clay.png` | crevasses with fracture lips, stratified ledge lips and undercuts, anchor collars/bolts, compression-crack geometry |

The high-poly source is deliberately not marked runtime-safe. Gate 05 must create dedicated `LP_` topology before UVs or export; Gate 07 must bake from these `HP_` collections to that matching low-poly target.

Regenerate with:

```sh
LD_LIBRARY_PATH=/tmp/xlibs .venv/bin/python tools/blender/build_aetherfall_high_poly.py
LD_LIBRARY_PATH=/tmp/xlibs .venv/bin/python tools/blender/render_aetherfall_high_poly.py
```
