# Status produksi Aetherfall

## Ringkasan

Aetherfall sekarang adalah proyek Godot mandiri yang hanya berisi satu world review. Kit memiliki 27 modul GLB dan 251 placement dalam meter, dengan tiga ramp sambungan reusable. Geometri dan ekspor dibuat ulang melalui Blender `bpy`; source `.blend` disimpan di `source/`. Material kini memadukan detail prosedural dengan tiga albedo sumber AI-generated yang provenance-nya didokumentasikan. Phase 1 menambahkan exterior ice planet; Phase 2 menambahkan delapan setpiece cover/traversal yang sengaja sedikit dan purpose-defined, bukan filler.

## VERIFIED

- **Blender:** `bpy` 5.0.1 benar-benar menjalankan `build_aetherfall.py`, `build_orbit.py`, `build_connector.py`, dan `render_preview.py`. Build terbaru mengekspor ulang 27 GLB, orbit animasi, ramp, `.blend` editable, serta material PBR albedo + normal + packed metallic/roughness/AO.
- **Godot:** Godot **4.7.2.stable.custom_build** berhasil dikompilasi dari source dan menjalankan clean editor import headless **setelah ekspor PBR dan peningkatan bentuk terbaru**. Dua peringatan tema editor `<null>_color` muncul di headless; tidak ada error project.
- **Kontrak aset:** `tests/check_assets.py` lulus — 251 placement, 27 modul, GLB orbit beranimasi, tiga connector, empat family Phase 2, delapan source Blender, serta normal dan ORM untuk semua material opaque PBR yang relevan. Parser GLB mengonfirmasi `normalTexture` dan `metallicRoughnessTexture` pada deck, terrain, cover, connector ramp, dan semua GLB Phase 2.
- **Perakitan:** `tests/world_smoke.gd` lulus — 251 placement, 188 collider, marker routes/spawn dan `AnimationPlayer` orbit aktif.
- **Sumbu serta permukaan:** `tests/surface_collision.gd` lulus untuk mesh lantai deck, bridge, catwalk dan masing-masing tiga titik pada ramp timur, barat, dan canyon. Kit mempertahankan authored Y-up saat ekspor; collider lantai tidak lagi memakai AABB railing/kabel.
- **Traversal geometris:** `tests/traversal_clearance.gd` lulus pada 19 sampel per ramp dengan **seluruh collider aktif**. `tests/traversal_motion.gd` lulus untuk kapsul `CharacterBody3D` tinggi 1.8 m di ketiga ramp, pada kedua arah. Tes ini menemukan dan memperbaiki orientasi deck edge di depan descent canyon yang sebelumnya menutup jalur.
- **Gate/rail:** collider gate dibentuk per bagian agar opening tidak berupa kotak padat; railing bridge/catwalk memakai collider komponen. Props canyon digeser dari sumbu ramp.
- **Bentuk asset:** build Blender memperkaya seluruh 27 modul dengan detail geometri sesuai peran: fastener dan service channel deck, stiffener beam/pillar, panel/louver machinery, bracket/clamp cable, grating/brace traversal, anchor/ring tower, control gate, serta outcrop/strata/boulder geology. `tests/check_assets.py` menerapkan floor jumlah mesh per modul agar detail ini tidak hilang saat rebuild. Clean import Godot kemudian lulus bersama smoke, surface, clearance, dan motion traversal tests.
- **Phase 2 static assembly (2026-10-31):** Blender `bpy` 5.0.1 benar-benar mengekspor empat GLB PBR baru plus source editable `aetherfall_phase2_cover.blend`: glacier berm (10 mesh), salvage pod (13), cryo bulkhead (15), dan ice terrace (11). `python3 tests/check_assets.py`, `python3 -m py_compile`, `gdparse scripts/*.gd tests/*.gd`, serta `git diff --check` lulus setelah integrasi. Kontrak aset juga menghitung margin clearance statis minimal 0.5 m terhadap central route dan tiga connector route. Ini **bukan** bukti eksekusi fisika Godot.

## LIKELY

- `docs/previews/blender_design_preview.png` dan crop `docs/previews/blender_pbr_detail.png` adalah preview Cycles yang sudah diperiksa: tower tetap menjadi landmark pusat; deck, canyon, bridge, dan catwalk terbaca sebagai ruang berlapis. Baja, beton dan batu kini membawa albedo ber-detail, normal serta metallic-roughness yang terlihat pada preview Cycles; material batu tidak lagi memiliki pola RGB banding ekstrem. Ini mendukung penilaian komposisi, bukan validasi renderer Godot.
- Tombol kamera review 1–0 menyediakan framing overview, landmark, Archive, skyline, Scrapper Basin, serta lower canyon untuk inspeksi manual ketika project dibuka dalam editor Godot dengan renderer grafis.

## UNKNOWN / UNVERIFIED

- **UNKNOWN:** tampilan material PBR, sky, fog, glow orbit dan framing pada renderer Godot nyata. Binary yang dijalankan untuk validasi adalah build headless tanpa backend Vulkan/OpenGL, sehingga tidak dapat menghasilkan screenshot in-engine yang jujur.
- **UNVERIFIED:** instantiation Godot pasca-Phase 2, capsule clearance terhadap dua belas collider baru, FPS/frame time, draw call, memori, device mobile/desktop, kualitas kontrol pemain, AI/navigation, combat/cover gameplay, audio, dan accessibility.
- **UNVERIFIED:** penilaian artistik final. Sebagian siluet tetap procedural/low-poly; penambahan PBR dan detail bentuk meningkatkan keterbacaan, tetapi tidak menjadi klaim photorealistik atau production-ready.

## Batas yang disengaja

- Tidak ada `NavigationRegion3D` atau NavMesh karena proyek ini bukan implementasi AI.
- Sebagian prop non-lantai tetap memakai proxy AABB. Rute kritis memiliki collision yang diuji; world belum memakai collision mesh yang dipanggang untuk semua aset.
- `docs/previews/blender_design_preview.png` dan `blender_pbr_detail.png` **bukan screenshot Godot**. Untuk screenshot in-engine, buka scene pada Godot ber-renderer grafis dan dokumentasikan GPU/driver serta setting renderer.

Baca `docs/DESIGN.md` untuk maksud ruang dan metrik rute.
