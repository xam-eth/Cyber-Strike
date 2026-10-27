# Aetherfall — Modular Asset Manifest

SH-01 "Aetherfall, the Broken Frontier" for EXOCONFLICT: STELLAR HORIZON.

Every module below is one `.glb` in `models/`, centred on its own AABB so that
one placement = one transform. Sizes are metres, `tris` is the exported triangle
count after the non-destructive retopo, `objects` counts meshes inside the module.

- Modules: **27**
- Total triangles: **5,604**
- Total meshes: **234**

| Module | Size (m) | Objects | Tris | Roles |
|---|---|---|---|---|
| `access_gate` | 7.20 × 5.40 × 6.00 | 7 | 84 | boundary gate |
| `background_silhouette` | 44.00 × 38.10 × 24.00 | 6 | 84 | distant skyline |
| `beam` | 1.00 × 0.90 × 8.00 | 6 | 72 | overhead structure, girder |
| `bridge_deck` | 6.20 × 1.95 × 8.00 | 17 | 204 | east elevated bridge |
| `bridge_support` | 6.60 × 15.00 × 7.00 | 11 | 132 | bridge pylon |
| `cable_bundle` | 0.80 × 6.00 × 6.00 | 9 | 128 | service duct |
| `cliff_face` | 26.00 × 16.81 × 26.00 | 11 | 544 | canyon walls, silhouette |
| `cloud_puff` | 11.17 × 7.42 × 16.01 | 7 | 840 | canyon fog volume |
| `conduit` | 0.83 × 6.25 × 0.93 | 8 | 128 | cable tray, verticality |
| `cooling_vent` | 4.40 × 3.90 × 4.40 | 10 | 208 | industrial detail, cover |
| `cover_barrier` | 2.60 × 1.30 × 0.70 | 5 | 60 | low cover |
| `cover_machine` | 4.60 × 3.70 × 3.20 | 5 | 72 | stationary cover |
| `damaged_slab` | 9.05 × 3.14 × 6.50 | 7 | 100 | broken bridge end |
| `debris_cluster` | 6.35 × 2.40 × 6.08 | 6 | 84 | scatter, floor detail |
| `deck_6x6` | 6.20 × 0.70 × 6.20 | 10 | 152 | combat platform, switchback road |
| `deck_edge` | 6.00 × 0.70 × 0.74 | 7 | 116 | platform perimeter |
| `energy_core` | 14.40 × 8.30 × 13.44 | 9 | 268 | Energy Tower heart (emissive) |
| `machinery` | 4.60 × 5.50 × 4.26 | 9 | 176 | industrial scatter, cover |
| `pillar` | 1.80 × 5.90 × 1.80 | 5 | 60 | structure, catwalk support |
| `railing` | 5.54 × 1.35 × 6.00 | 7 | 84 | bridge handrail |
| `rock_boulder` | 6.60 × 5.94 × 7.53 | 3 | 304 | scatter cover, descent |
| `terrain_chunk` | 46.00 × 7.06 × 53.62 | 5 | 696 | canyon floor, lower approach ground |
| `tower_foundation` | 18.00 × 8.10 × 18.10 | 15 | 292 | Energy Tower base |
| `tower_spire` | 7.60 × 16.00 × 7.60 | 8 | 136 | Energy Tower apex |
| `tower_tier` | 13.00 × 11.00 × 17.48 | 15 | 228 | Energy Tower shaft |
| `walkway_deck` | 1.70 × 6.00 × 6.00 | 17 | 220 | west catwalk |
| `wall_section` | 4.20 × 3.60 × 0.52 | 9 | 132 | cover, boundary |

## Textures (13 materials, 7 PNG maps, 3.16 MB)

| Map | Resolution | Role |
|---|---|---|
| `aether_cloud.png` | 256×256 | volumetric cloud puff |
| `aether_concrete.png` | 512×512 | concrete, foundations, road |
| `aether_deck.png` | 512×512 | steel deck, platform floor |
| `aether_energy.png` | 256×256 | emissive cyan energy |
| `aether_metal.png` | 512×512 | steel structure |
| `aether_metal2.png` | 512×512 | secondary metal |
| `aether_rock.png` | 512×512 | canyon rock |

## Materials (13)

Steel, PaintedSteel, Titanium, Concrete, Composite, Rock, Stratum, Glass, Rubber,
Cable, Energy (emissive cyan, strength 2.4), Hazard, WarningRed.

> **Provenance.** The PNG maps are procedurally generated with numpy/Pillow inside
> `tools/blender/build_aetherfall.py`. They are not scanned or licensed assets. The
> geometry is likewise generated: no third-party kit was imported, so the kit is
> self-contained and redistributable. This is stated here rather than implied.