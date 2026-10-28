# Status produksi Aetherfall

## Ringkasan

Aetherfall sekarang adalah proyek Godot mandiri yang hanya berisi satu world review. Kit memiliki 27 modul GLB dan 251 placement dalam meter, dengan tiga ramp sambungan reusable. Semua sumber aset prosedural dibuat ulang melalui Blender `bpy`; source `.blend` disimpan di `source/`.

## VERIFIED

- **Blender:** `bpy` 5.0.1 benar-benar menjalankan `build_aetherfall.py`, `build_orbit.py`, `build_connector.py`, dan `render_preview.py`. Build terbaru mengekspor ulang 27 GLB, orbit animasi, ramp, material batu yang diperhalus, serta `.blend` editable.
- **Godot:** Godot **4.7.2.stable.custom_build** berhasil dikompilasi dari source dan menjalankan clean editor import headless. Dua peringatan tema editor `<null>_color` muncul di headless; tidak ada error project.
- **Kontrak aset:** `tests/check_assets.py` lulus — 251 placement, 27 modul, GLB orbit beranimasi, tiga connector, dan tiga source Blender.
- **Perakitan:** `tests/world_smoke.gd` lulus — 251 placement, 188 collider, marker routes/spawn dan `AnimationPlayer` orbit aktif.
- **Sumbu serta permukaan:** `tests/surface_collision.gd` lulus untuk mesh lantai deck, bridge, catwalk dan masing-masing tiga titik pada ramp timur, barat, dan canyon. Kit mempertahankan authored Y-up saat ekspor; collider lantai tidak lagi memakai AABB railing/kabel.
- **Traversal geometris:** `tests/traversal_clearance.gd` lulus pada 19 sampel per ramp dengan **seluruh collider aktif**. `tests/traversal_motion.gd` lulus untuk kapsul `CharacterBody3D` tinggi 1.8 m di ketiga ramp, pada kedua arah. Tes ini menemukan dan memperbaiki orientasi deck edge di depan descent canyon yang sebelumnya menutup jalur.
- **Gate/rail:** collider gate dibentuk per bagian agar opening tidak berupa kotak padat; railing bridge/catwalk memakai collider komponen. Props canyon digeser dari sumbu ramp.

## LIKELY

- `docs/previews/blender_design_preview.png` adalah preview Cycles yang sudah diperiksa: tower tetap menjadi landmark pusat; deck, canyon, bridge, dan catwalk terbaca sebagai ruang berlapis. Material batu tidak lagi memiliki pola RGB banding ekstrem. Ini mendukung penilaian komposisi, bukan validasi renderer Godot.
- Tombol kamera review 1–5 menyediakan sudut tower, platform, bridge, canyon, dan overview untuk inspeksi manual ketika project dibuka dalam editor Godot dengan renderer grafis.

## UNKNOWN / UNVERIFIED

- **UNKNOWN:** tampilan material PBR, sky, fog, glow orbit dan framing pada renderer Godot nyata. Binary yang dijalankan untuk validasi adalah build headless tanpa backend Vulkan/OpenGL, sehingga tidak dapat menghasilkan screenshot in-engine yang jujur.
- **UNVERIFIED:** FPS/frame time, draw call, memori, device mobile/desktop, kualitas kontrol pemain, AI/navigation, combat/cover gameplay, audio, dan accessibility.
- **UNVERIFIED:** penilaian artistik final. Kit masih procedural dan sebagian siluet sengaja low-poly; tidak ada klaim photorealistik atau production-ready.

## Batas yang disengaja

- Tidak ada `NavigationRegion3D` atau NavMesh karena proyek ini bukan implementasi AI.
- Sebagian prop non-lantai tetap memakai proxy AABB. Rute kritis memiliki collision yang diuji; world belum memakai collision mesh yang dipanggang untuk semua aset.
- `docs/previews/blender_design_preview.png` **bukan screenshot Godot**. Untuk screenshot in-engine, buka scene pada Godot ber-renderer grafis dan dokumentasikan GPU/driver serta setting renderer.

Baca `docs/DESIGN.md` untuk maksud ruang dan metrik rute.
