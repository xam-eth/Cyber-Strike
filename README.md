# Aetherfall — proyek world design mandiri

Satu proyek Godot untuk meninjau SH-01 **Aetherfall**. Tidak memerlukan proyek game, autoload, atau layanan eksternal. Fokus branch ini hanya world, asset produksi Blender, dan alat validasinya.

## Stellar Horizon — vertical slice interaktif

Main scene kini tetap memakai layout Aetherfall yang sama, dengan tambahan minimal berikut:

- `TechCache` reusable di sisi jalur dari spawn primer: collider statis, `Area3D` range, animasi buka authored Blender, serta transaksi `tech_data` satu kali yang disimpan ke `user://aetherfall_stellar_horizon.cfg`.
- `ObjectiveDevice` reusable di zona mesin/cover tengah: meminta satu `tech_data`, kemudian menyimpan aktivasi relai satu kali.
- Interaksi tetap memiliki actor test privat di `tests/interactive_slice.gd`, tetapi **scene QA utama tidak lagi memunculkan karakter**. `ReviewCamera` adalah kamera QA default: tahan klik kanan untuk melihat, **WASD/Q/E** untuk free-fly, dan **1–7** untuk framing overview, outpost, cache, relay, hangar, density, serta tower.

Tambahan density terarah juga tersedia di `assets/world/aetherfall/landmarks/`: Field Outpost, Relay Annex, Service Hangar, dan cargo/service cluster. Ketiganya ditempatkan sebagai landmark spawn/relay/cover berdasarkan `landmarks.json`, dengan collider sederhana, bukan filler acak. Atmosfer mengurangi kabut dan bloom untuk pemisahan siluet yang lebih tegas; kualitas visual final tetap perlu diperiksa pada Godot GUI.

Ini bukan pengganti atau klaim integrasi dengan inventory/mission/combat EXOCOMFLICT lama—sistem tersebut tidak ada di branch standalone ini. Jalankan `tests/interactive_slice.gd` di Godot untuk memeriksa range, collision, animasi, persistence, reward dan anti-duplikasi. Detail bukti serta keterbatasan screenshot/performa ada pada `docs/VALIDATION.md`.

## Preview Godot GUI — tanpa toolchain sandbox

**Seluruh file yang dibutuhkan untuk melihat world sudah ada di Git.** Yang berada di luar Git hanya toolchain sementara yang saya gunakan untuk membangun/mengetes (`.venv/`, `/tmp/godot-source`, dan `/tmp/xlibs`) serta cache hasil import Godot (`.godot/`). Anda **tidak** memerlukan file sementara tersebut untuk membuka world.

1. Ambil branch yang dipush:

   ```sh
   git clone https://github.com/xam-eth/Cyber-Strike.git
   cd Cyber-Strike
   git fetch origin arena/939d9492-cyber-strike
   git switch --track origin/arena/939d9492-cyber-strike
   ```

   Jika clone Anda sudah memiliki branch lokal tersebut, gunakan `git switch arena/939d9492-cyber-strike` lalu `git pull --ff-only`.

2. Jalankan **Godot desktop 4.7.2** atau versi 4.7 yang kompatibel. Pada Project Manager pilih **Import**, lalu pilih **`project.godot` di root repository** — bukan folder `assets/`, `scenes/`, atau `.godot/`.
3. Tunggu proses import GLB selesai. Godot membuat folder `.godot/` sendiri; folder itu adalah cache lokal, sehingga sengaja tidak dipush dan tidak hilang dari world.
4. Tekan **F5** untuk menjalankan `project.godot`, atau buka `scenes/aetherfall.tscn` lalu tekan **F6**. Main scene sudah dideklarasikan sebagai `res://scenes/aetherfall.tscn`.
5. World dirakit dari `assets/world/aetherfall/layout.json` saat runtime. Karena itu node `Modules`, `Collision`, dan `Connectors` terlihat di tab **Remote** ketika scene berjalan, bukan sebagai anak statis sebelum tombol Run ditekan.

File world yang tersedia langsung dari Git: `project.godot`, scene, GDScript builder, 29 GLB (27 modul + orbit + ramp), albedo/normal/ORM PBR, JSON layout/measurement/connector, dan tiga source `.blend`. Tidak ada dependency game induk, autoload, registry, atau service eksternal yang perlu Anda instal untuk preview.

## Membuka dan meninjau

1. Buka **folder root ini** di Godot **4.7.2** (Project Manager → Import → pilih `project.godot`). Tunggu import seluruh GLB selesai.
2. Tekan **F6** pada `scenes/aetherfall.tscn`, atau **F5** untuk main scene. World dirakit pada runtime dari `layout.json`; node modul tidak muncul di editor sebelum scene dijalankan. Tab **Remote** dapat dipakai untuk memeriksa hierarchy yang sudah terbangun.
3. Kamera review: tahan **klik kanan** untuk melihat, **W/A/S/D** bergerak, **Q/E** turun/naik, **Shift** mempercepat, **Esc** melepas mouse. Tombol **1–5** melompat ke sudut tower, platform, bridge, canyon, dan overview.

Kamera ini adalah kamera inspeksi bebas, bukan karakter/gameplay. Material dan lighting perlu dinilai pada mesin dengan renderer grafis; headless tidak membuktikan tampilan visual.

## Struktur

- `scenes/aetherfall.tscn`, `scripts/`: scene, builder independen, dan kamera review.
- `assets/world/aetherfall/`: layout dalam meter, 27 modul kit GLB, albedo + normal + ORM PBR untuk surface utama, 27 modul yang diperkaya dengan detail bentuk konstruktif, satu GLB animasi orbit tower dan connector ramp.
- `source/*.blend`: sumber Blender editable (tekstur kit dikemas dalam file). Kit ditulis dalam koordinat **Y-up** untuk mengikuti layout Godot, sehingga tampil menyamping relatif terhadap grid Z-up Blender; ekspor kit sengaja tidak mengonversi sumbu lagi.
- `tools/blender/build_aetherfall.py`, `build_orbit.py`, dan `build_connector.py`: produksi ulang kit dan animasi menggunakan Blender `bpy` + numpy/Pillow.
- `tests/`: kontrak statis dan smoke test scene Godot.

## Produksi ulang asset

Jalankan pipeline melalui Blender `bpy` dalam urutan ini agar ramp menerima peta PBR bersama:

```sh
python tools/blender/build_aetherfall.py
python tools/blender/build_connector.py
python tools/blender/build_orbit.py
```

Peta yang dibangun untuk permukaan opaque adalah albedo sRGB, normal tangent-space, serta ORM (metallic/roughness/AO). Build kit juga menambahkan ribs, bolts, panel, gusset, louver, cable clamp, guard, energy ring, dan detail struktur pada seluruh 27 modul serta connector ramp. Lihat `assets/world/aetherfall/materials/README.md` dan provenance sumber di `assets/world/aetherfall/source_textures/README.md`.

## Validasi

```sh
python3 tests/check_assets.py
godot --headless --editor --path . --quit
godot --headless --path . --script res://tests/world_smoke.gd
godot --headless --path . --script res://tests/surface_collision.gd
godot --headless --path . --script res://tests/traversal_clearance.gd
godot --headless --path . --script res://tests/traversal_motion.gd
```

Lihat `docs/STATUS.md` untuk hasil nyata dan keterbatasan. Proyek review ini bukan klaim game-ready: jalur ramp utama sudah diuji dengan kapsul `CharacterBody3D` otomatis, tetapi sebagian prop tetap menggunakan collider proxy. Belum ada navmesh, profil mobile, screenshot Godot, atau penilaian visual renderer Godot. Kit masih membutuhkan penilaian artistik pada renderer Godot dan bukan klaim kualitas photorealistik.

## Preview desain Blender

`docs/previews/blender_design_preview.png` adalah render desain Blender Cycles dari kit dan layout, sedangkan `docs/previews/blender_pbr_detail.png` adalah crop untuk memeriksa material PBR. Keduanya **bukan** screenshot Godot. Untuk menghasilkan ulang, jalankan `python tools/blender/render_preview.py` atau `python tools/blender/render_preview.py --detail` dengan modul `bpy` tersedia. Renderer, atmosfer dan hasilnya tidak identik dengan Godot; nilai kualitas akhir di Godot sendiri.
