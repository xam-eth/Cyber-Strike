# Aetherfall — proyek world design mandiri

Satu proyek Godot untuk meninjau SH-01 **Aetherfall**. Tidak memerlukan proyek game, autoload, atau layanan eksternal. Fokus branch ini hanya world, asset produksi Blender, dan alat validasinya.

## Membuka dan meninjau

1. Buka **folder root ini** di Godot **4.7.2** (Project Manager → Import → pilih `project.godot`). Tunggu import seluruh GLB selesai.
2. Tekan **F6** pada `scenes/aetherfall.tscn`, atau **F5** untuk main scene. World dirakit pada runtime dari `layout.json`; node modul tidak muncul di editor sebelum scene dijalankan. Tab **Remote** dapat dipakai untuk memeriksa hierarchy yang sudah terbangun.
3. Kamera review: tahan **klik kanan** untuk melihat, **W/A/S/D** bergerak, **Q/E** turun/naik, **Shift** mempercepat, **Esc** melepas mouse.

Kamera ini adalah kamera inspeksi bebas, bukan karakter/gameplay. Material dan lighting perlu dinilai pada mesin dengan renderer grafis; headless tidak membuktikan tampilan visual.

## Struktur

- `scenes/aetherfall.tscn`, `scripts/`: scene, builder independen, dan kamera review.
- `assets/world/aetherfall/`: layout dalam meter, 27 modul kit GLB, 7 tekstur procedural, satu GLB animasi orbit tower dan connector ramp.
- `source/*.blend`: sumber Blender editable (tekstur kit dikemas dalam file). Kit ditulis dalam koordinat **Y-up** untuk mengikuti layout Godot, sehingga tampil menyamping relatif terhadap grid Z-up Blender; ekspor kit sengaja tidak mengonversi sumbu lagi.
- `tools/blender/build_aetherfall.py`, `build_orbit.py`, dan `build_connector.py`: produksi ulang kit dan animasi menggunakan Blender `bpy` + numpy/Pillow.
- `tests/`: kontrak statis dan smoke test scene Godot.

## Validasi

```sh
python3 tests/check_assets.py
godot --headless --editor --path . --quit
godot --headless --path . --script res://tests/world_smoke.gd
godot --headless --path . --script res://tests/surface_collision.gd
```

Lihat `docs/STATUS.md` untuk hasil nyata dan keterbatasan. Proyek review ini bukan klaim game-ready: collider menggunakan kotak proxy dan route belum diuji dengan karakter; belum ada navmesh, profil mobile, atau screenshot Godot. Asset procedural ini masih membutuhkan penilaian visual dan penyempurnaan artistik.
