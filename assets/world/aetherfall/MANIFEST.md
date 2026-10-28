# Manifest Aetherfall

27 modul kit berdasarkan `measurements.json`, 251 placement pada `layout.json`, 7 PNG procedural; semua menggunakan meter dan Y-up di Godot. `models/energy_orbit.glb` adalah aset animasi tambahan dan `models/connector_ramp.glb` adalah ramp reusable. Sumber editable: `source/aetherfall_kit.blend` dan `source/energy_orbit.blend`, `source/connector_ramp.blend`; pipeline: `tools/blender/build_aetherfall.py`, `tools/blender/build_orbit.py` dan `tools/blender/build_connector.py`.

Material dan tekstur dihasilkan procedural, bukan scan atau aset pihak ketiga. GLB menyertakan material dan tekstur. Bounds dan angka mesh/triangle per modul tersedia pada `measurements.json` (angka triangle adalah perkiraan pembuat, bukan statistik render). Collider Godot adalah proxy AABB, bukan collision yang telah diuji. Belum ada LOD authored atau bukti performa runtime.
