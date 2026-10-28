# Status produksi Aetherfall

## Yang diubah

- Proyek Godot dipisah dari game induk; scene tidak lagi memerlukan registry, selection service, mission wrapper, atau pagar tak terlihat milik game lama.
- JSON dibaca sebagai array dan dikonversi ke Vector3 secara eksplisit; offset collider ditempatkan pada `CollisionShape3D`, bukan pada `BoxShape3D`.
- `palette_materials()` sebelumnya tidak pernah dipanggil sehingga GLB yang lama menggunakan material abu-abu default. Kit telah dibangun ulang dengan palet, tekstur warna sRGB yang tertanam, dan material emisi. File `.blend` sumber kit dikemas bersama gambar sumbernya.
- Blender `bpy` digunakan untuk membuat dan mengekspor orbit energi beranimasi, dengan sumber `.blend` terpisah.
- Ditambahkan kamera terbang untuk memeriksa world saat menjalankan scene di Godot dan uji kontrak aset.

## Hasil yang terverifikasi

- Python `tests/check_assets.py`: 251 placement, seluruh 27 referensi GLB ditemukan dan header valid, satu GLB orbit memiliki animation, file sumber Blender tersedia.
- Godot **4.7.2.stable.custom_build**, build headless dari source: import editor selesai (exit 0; dua peringatan tema editor headless); main scene berjalan 60 frame (exit 0); `tests/world_smoke.gd` lulus: 251 placement, 191 collider proxy, routes/spawn dan AnimationPlayer orbit. Ini bukan uji visual.
- Blender `bpy` 5.0.1: skrip build kit dan orbit dijalankan pada sandbox; diekspor ulang menjadi GLB dan disimpan sebagai file sumber Blender. Penggunaan `bpy` di sandbox ini memerlukan library sistem atau konfigurasi headless yang setara.

## Yang masih perlu diperiksa / belum selesai

- Tidak ada klaim kualitas photorealistik atau gambar dari Godot sampai scene dirender dan diperiksa pada renderer grafis. Material sudah tidak default abu-abu, tetapi model masih procedural dan sebagian bentuk low-poly.
- Sebagian besar collider masih berupa proxy AABB; lihat bagian lanjutan untuk perbaikan lantai deck, bridge, dan catwalk. Jalur vertikal, sambungan bridge/catwalk, lower approach, collision dan interaksi karakter belum lulus playtest. Tidak ada navmesh.
- Performa mobile, FPS, draw call, memori dan perangkat nyata belum diukur. Jumlah triangle di manifest lama bersifat perkiraan, bukan profil runtime.
- Orbit Blender diekspor dengan animasi dan AnimationPlayer berjalan dalam tes headless. Penampilan dan kualitas geraknya masih harus dinilai secara visual.

## Lanjutan: sumbu, collider, dan sambungan

- Ditemukan bahwa kit ditulis dengan Y sebagai sumbu vertikal, tetapi ekspor Blender sebelumnya mengaktifkan konversi Z-up ke Y-up. Ini merotasi geometri relatif terhadap layout dan collider. Ekspor kit kini mempertahankan koordinat Y-up yang sudah ditulis, lalu semua 27 GLB dibangun ulang dengan Blender `bpy`.
- Collider deck, bridge dan catwalk sekarang mengikuti bounds mesh lantai bernama, bukan AABB seluruh modul yang mencakup railing/kabel. Railing dekoratif yang AABB-nya menghalangi jembatan tidak lagi diberi collider kotak penuh; railing fisik khusus masih harus dibuat.
- Ditambahkan ramp reusable buatan Blender, beserta source `.blend` dan `connectors.json` untuk pendekatan bridge dan catwalk. Ramp ini menyambungkan elevasi yang diukur dari tiga jenis lantai; bukan jaminan bahwa rute bebas halangan.
- Godot 4.7.2 headless: test `surface_collision.gd` memeriksa ukuran/orientasi mesh, kesesuaian posisi/ukuran collider dan raycast ke masing-masing jenis lantai, serta tiga titik pada setiap ramp secara terisolasi. Semua lulus. Test ini **bukan** playthrough; collision dari objek lain tidak aktif dalam pengujian ramp dan dapat menghalangi jalur. Lower approach belum disambungkan/dites dengan karakter.
- Perubahan sejak commit awal belum menjadi bukti screenshot Godot atau performa. Evaluasi visual dan uji traversal menyeluruh masih diperlukan.
