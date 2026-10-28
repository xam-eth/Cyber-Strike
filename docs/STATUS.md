# Status produksi Aetherfall

## Yang diubah

- Proyek Godot dipisah dari game induk; scene tidak lagi memerlukan registry, selection service, mission wrapper, atau pagar tak terlihat milik game lama.
- JSON dibaca sebagai array dan dikonversi ke Vector3 secara eksplisit; offset collider ditempatkan pada `CollisionShape3D`, bukan pada `BoxShape3D`.
- `palette_materials()` sebelumnya tidak pernah dipanggil sehingga GLB yang lama menggunakan material abu-abu default. Kit telah dibangun ulang dengan palet, tekstur warna sRGB yang tertanam, dan material emisi. File `.blend` sumber kit dikemas bersama gambar sumbernya.
- Blender `bpy` digunakan untuk membuat dan mengekspor orbit energi beranimasi, dengan sumber `.blend` terpisah.
- Ditambahkan kamera terbang untuk memeriksa world saat menjalankan scene di Godot dan uji kontrak aset.

## Hasil yang terverifikasi

- Python `tests/check_assets.py`: 251 placement, seluruh 27 referensi GLB ditemukan dan header valid, satu GLB orbit memiliki animation, kedua `.blend` ada.
- Godot **4.7.2.stable.custom_build**, build headless dari source: import editor selesai (exit 0; dua peringatan tema editor headless); main scene berjalan 60 frame (exit 0); `tests/world_smoke.gd` lulus: 251 placement, 191 collider proxy, routes/spawn dan AnimationPlayer orbit. Ini bukan uji visual.
- Blender `bpy` 5.0.1: skrip build kit dan orbit dijalankan pada sandbox; diekspor ulang menjadi GLB dan disimpan sebagai file sumber Blender. Penggunaan `bpy` di sandbox ini memerlukan library sistem atau konfigurasi headless yang setara.

## Yang masih perlu diperiksa / belum selesai

- Tidak ada klaim kualitas photorealistik atau gambar dari Godot sampai scene dirender dan diperiksa pada renderer grafis. Material sudah tidak default abu-abu, tetapi model masih procedural dan sebagian bentuk low-poly.
- Proxy collider dihitung dari AABB; beberapa aset memiliki railing atau kabel yang membuat AABB bukan permukaan lantai. Jalur vertikal, sambungan bridge/catwalk, lower approach, collision dan interaksi karakter belum lulus playtest. Tidak ada navmesh.
- Performa mobile, FPS, draw call, memori dan perangkat nyata belum diukur. Jumlah triangle di manifest lama bersifat perkiraan, bukan profil runtime.
- Orbit Blender diekspor dengan animasi dan AnimationPlayer berjalan dalam tes headless. Penampilan dan kualitas geraknya masih harus dinilai secara visual.
