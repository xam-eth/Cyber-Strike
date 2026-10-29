# HERO_01 — Laporan Validasi (Fase F, G, H) — Milestone 1

> Versi Bahasa Indonesia dari `VALIDATION_REPORT.md`. Jika terdapat perbedaan tafsir, versi Bahasa Inggris adalah acuan utama. Label status (VERIFIED / LIKELY / ASSUMPTION / UNKNOWN / UNVERIFIED) dipertahankan dalam Bahasa Inggris sebagai kode standar proyek.

Toolchain yang benar-benar digunakan: Blender **4.5.15 LTS** (bpy headless, render Cycles CPU), Python (pygltflib) untuk inspeksi GLB, dan — sejak sesi validasi 2026-10-29 — binary editor **Godot 4.7.2** asli yang dikompilasi dari source resmi `4.7.2-stable` di dalam sandbox (bagian 5.1 menjelaskan alasannya: unduhan release-asset GitHub serta semua jalur engine via npm/PyPI terbukti tidak dapat digunakan dari environment ini). Semua pengujian Godot dijalankan secara headless dengan driver rendering dummy: pemeriksaan import, scene, skeleton, script, animasi, dan transform adalah eksekusi engine yang sesungguhnya, tetapi **Godot tidak me-render pixel apa pun** — bukti visual tetap berasal dari render Cycles Blender terhadap GLB yang disertakan (bagian 2–4), dan pemeriksaan visual di desktop oleh pemilik tetap direkomendasikan (5.5). Tidak ada pengujian yang diklaim melebihi apa yang benar-benar dijalankan.

## 1. Pelestarian file sumber — VERIFIED
- `assets/source/HERO_01.glb` tidak diubah (18,888,488 B, MD5 `9d0ad8cd…`, SHA-256 `f067d3f5…45d50`); semua pengeditan dilakukan pada `blender/HERO_01_working.blend`.
- Konservasi vertex melalui pemisahan **dan** ekspor: 262,714 = 244,770 body + 17,944 weapon (dihitung pada file sumber, di Blender, dan pada GLB hasil ekspor).
- Render pose netral dari GLB hasil ekspor cocok dengan baseline file sumber yang tidak diubah (kamera/lighting sama): `screenshots/baseline/` vs `screenshots/01_neutral_pose.png`.

## 2. Uji pose rig & skinning (render Blender, dilihat satu per satu) — VERIFIED
Rotasi sumbu dunia (world-axis) mengelilingi kepala joint; gambar di `screenshots/rig/` (weight final = v4 + perbaikan island-13):
| Tes | Pose | Hasil |
|---|---|---|
| T0 | Netral | Cocok dengan baseline. |
| T1 | Siku fleksi −65° | Bersih; armor forearm tetap rigid, tidak kolaps (`v6_T1_elbows_front.jpg`). |
| T2 | Lutut +55° / pinggul −18° | Armor lutut mengikuti shin/thigh; sedikit stretch di belakang lutut, masih dapat diterima (`v3_T2_knees_sideR.jpg`). |
| T3 | Angkat lengan −75° + siku −20° | Bersih setelah perbaikan; weapon mengikuti tangan kanan dengan barrel menghadap ke depan (`v6_T3_armraise_front.jpg`, `v3_T3_armraise_sideR.jpg`). |
| T4 | Spine −10°X, yaw Chest/UpperChest, Head counter | Tidak ada twist "candy-wrapper"; sabuk (belt) stabil (`v3_T4_spine_3q.jpg`). |
| T5 | Neck +16° / Head yaw +30° | Head/hair/collar koheren (`v3_T5_head_front.jpg`). |

Riwayat cacat (transparan): iterasi weight v1/v2 menghasilkan lembaran "blade" dari tangan ke paha pada T3 (kebocoran proximity antar-chain). Penyebab akar ditemukan dan diperbaiki dengan membatasi blend hanya pada bone yang bersebelahan secara skeletal (v3+). Eksperimen awal terpisah (script 11) salah menetapkan 25 shell forearm dan telah **di-revert** dengan memulihkan v4 sebelum melanjutkan; script tersebut disimpan di repo hanya sebagai catatan — jangan dijalankan ulang. Satu shell pergelangan (island 13) kemudian ditemukan lewat audit neighbour-detachment dan diperbaiki (script 14).
Minor residual (terdokumentasi, bukan blocker): flap jaket emas sedikit terangkat di bawah lengan kanan saat pengangkatan ekstrem (terbaca sebagai pakaian longgar); `Hand_L` memiliki 0 vertex dominan (lihat RIG_SPECIFICATION §3).

## 3. Animasi — VERIFIED di Blender (render + sampling numerik)
- Keberadaan/timing: `Weapon_Raise_To_Aim`, 1.5 detik @30 fps, key + peta stage ada di ANIMATION_SPECIFICATION.
- Render yang ditinjau: F00/F12/F24/F36 × front/side/three-quarter + close-up F36 (`screenshots/animation/`). Tidak ada snapping, teleporting, tekukan ekstrem, atau interseksi parah yang teramati pada frame yang ditinjau; kaki statis sesuai konstruksi (channel kaki konstan).
- Sampel arah barrel: F0 (−0.159,−0.130,−0.979) → F12 (0.113,−0.947,−0.301) → F24 (0.068,−0.996,0.053) → F36/F45 **(0,−1,0)**.
- Grip: tangan kanan→grip 0.017 m di setiap sampel; tangan kiri→foregrip ≤0.011 m sejak F22, ≤0.003 m pada F28–45 (sweep setiap 2 frame).

## 4. Validasi ekspor — VERIFIED (pygltflib; data mentah `tools/out/export_validation.json`)
| Pemeriksaan | HERO_01_RIGGED.glb | HERO_01_WEAPON.glb | HERO_01_ANIMATIONS.glb |
|---|---|---|---|
| Ukuran | 22,878,116 B | 5,326,624 B | 67,196 B |
| Vertex | 244,770 | 17,944 | (khusus skeleton) |
| Skin | 24 joint, nama bone persis | — | 24 joint |
| Weight | jumlah 1.000000 ±1.2e-7, **0 vertex berbobot nol** | — | — |
| Animasi | `Weapon_Raise_To_Aim`, 72 channel, **1.5 detik** | — | clip yang sama |
| Image/material | 3 / 1 (set sumber) | 3 / 1 | 0 / 0 |
Roundtrip: scene Blender baru, import RIGGED+WEAPON, pasang kembali weapon ke `Weapon_R` (identitas pada F0, error 2.5e-07; jarak grip 0.017 m pada F0 **dan** F36), render `screenshots/01…04*.png` dihasilkan **hanya dari GLB yang disertakan**. Satu keanehan: importer glTF milik Blender sendiri melaporkan rentang action hasil re-import sebagai 0–36 (ia membuang sampel trailing yang identik); GLB-nya sendiri berisi 1.5 detik penuh (sampler max = 1.500 detik, VERIFIED di atas).

## 5. Validasi runtime Godot — DIJALANKAN pada Godot 4.7.2 (headless)

### 5.1 Bagaimana engine diperoleh (asal-usul/provenance)
- Zip release resmi: **tidak dapat dijangkau** dari sandbox — github.com berfungsi, tetapi release asset mengarah (redirect) ke `release-assets.githubusercontent.com`, yang diblokir oleh proxy sandbox (kegagalan SSL curl tercatat).
- Jalur registry dievaluasi dan ditolak dengan bukti: npm `godot-cli` (launcher 0.9 MB yang mengunduh dari GitHub, jadi terblokir); npm `@ringozz/godot` 4.7.2 (Godot-di-JS: addon native hanya ada untuk macOS/Windows — **tidak ada addon Linux** — dan fallback wasm-nya boot terhadap canvas/WebGL browser, sehingga tidak dapat berjalan CLI-headless di sini); PyPI tidak memiliki paket engine. File zip Godot di Drive milik user berukuran 0 byte.
- **Jalur yang berhasil:** source resmi `godot-4.7.2-stable` diambil via codeload.github.com (host yang diizinkan); `pkgconf` 2.5.1 dibangun dari source GitHub-nya dengan cara yang sama (detect linux pada Godot mewajibkan pkg-config); editor dibangun dengan SCons, exit 0, string versi `4.7.2.stable.custom_build`:
  `scons platform=linuxbsd target=editor arch=x86_64 debug_symbols=no production=no vulkan=no opengl3=no module_text_server_adv_enabled=no module_openxr_enabled=no module_webrtc_enabled=no module_websocket_enabled=no module_webxr_enabled=no module_mono_enabled=no module_raycast_enabled=no module_lightmapper_rd_enabled=no module_betsy_enabled=no module_camera_enabled=no -j2`
  Driver rendering dimatikan karena validasi di sini adalah data/logika (RenderingServer dummy); import, Skeleton3D, AnimationPlayer, dan GDScript tidak terpengaruh.

### 5.2 Import — LULUS (setelah satu perbaikan proyek yang nyata)
Percobaan import pertama menghasilkan **nol** produk `.import` untuk setiap file (proyek kontrol minimal berisi satu PNG berhasil di-import dengan baik, membuktikan binary sehat). Penyebab akar, ditelusuri di source engine: proyek kami menyertakan `blender/HERO_01_working.blend` *di dalam* proyek Godot. Memindai (scan) file `.blend` memicu query dukungan format Blender; dalam mode headless query itu menghasilkan error "Cannot configure blender path in headless mode" dan mengembalikan *true* (= konfigurasi user diperlukan), lalu `EditorFileSystem::_update_scan_actions` return **sebelum** `reimport_files(...)` — membatalkan seluruh batch import secara diam-diam. Pada desktop, layout yang sama akan menyambut pemilik dengan dialog "Configure Blender Importer" saat pertama dibuka.
**Perbaikan yang disertakan:** `.gdignore` ditambahkan ke folder non-runtime: `blender/`, `screenshots/`, `assets/source/`, `tools/blender/`, `tools/out/`. Setelah perbaikan, `godot --headless --path . --import` meng-import ketiga GLB (`.scn` + `.ctex` basecolor/metallic-roughness/normal) dengan **nol error**. File .blend authoring, GLB sumber yang dilestarikan, dan screenshot tetap berada di dalam paket — mereka hanya tidak terlihat oleh importer Godot, sebagaimana mestinya.

### 5.3 CI di dalam engine — SEMUA LULUS (`tools/godot/CICheck.tscn`, exit code 0)
Scene pengujian headless yang meng-instantiate `HERO_01.tscn` yang disertakan tanpa perubahan, melakukan seek pada clip, dan mengukur di dalam engine (Godot 4.7.2, skala scene x1.8, sehingga 0.017 m di Blender = 0.0306 m di sini):
| Sampel | jarak Hand_R→grip | jarak Hand_L→foregrip | Barrel (receiver→muzzle) |
|---|---|---|---|
| t=0.0s | 0.0302 m | 0.7536 m (di samping badan) | (-0.133,-0.984,0.117) — ke bawah |
| t=0.4s | 0.0302 m | 0.5920 m | berayun ke depan/bawah |
| t=0.8s | 0.0302 m | 0.0125 m | kira-kira ke depan |
| t=1.2s | 0.0302 m | **0.0000 m** | **0.1° dari +Z** |
| t=1.5s | 0.0302 m | **0.0000 m** | **0.4° dari +Z** |
Juga LULUS: Skeleton3D ditemukan dengan tepat 24 bone dan semua nama yang disyaratkan; panjang clip `AnimationPlayer` 1.500 detik; `BoneAttachment3D` terikat ke `Weapon_R`; marker weapon ditemukan; sebaran (spread) grip kanan di sepanjang clip 0.0000 m; Hips bergerak 0.0000 m; kaki tetap menapak (planted). Jalankan ulang kapan saja: `godot --headless --path . res://tools/godot/CICheck.tscn` (lakukan import sekali terlebih dahulu).
**Bug nyata yang ditemukan oleh CI ini dan telah diperbaiki:** run CI pertama mengukur error grip kanan konstan sebesar 0.4102 m. `hero_01.gd` menjangkarkan (anchor) offset weapon hasil perhitungan ke transform global hero-root, sehingga di bawah `ScaleRoot` (x1.8) weapon mendarat pada skala ternormalisasi di samping tangan, bukan di dalamnya. Offset sekarang adalah `skeleton.get_bone_global_rest(Weapon_R).affine_inverse()` — ruang skeleton murni, invarian terhadap skala/penempatan karakter. Marker `ReceiverPoint` juga ditambahkan ke scene weapon agar garis laras (bore line) diukur melalui receiver→muzzle (estimasi awal berbasis foregrip secara menyesatkan menunjukkan 4.6°; error laras sebenarnya 0.1–0.4°).

### 5.4 Scene validasi yang disertakan — LULUS
`godot --headless --path . --quit-after 150` menjalankan main scene proyek `RigValidation`: exit 0, **nol SCRIPT ERROR**, semua auto-check `[RigCheck]` LULUS, offset weapon hasil perhitungan tercetak (`HERO_01: weapon local offset under Weapon_R = ... O: (0.288757, 0.398398, 0.012436)`, basis ortonormal). Perilaku UI interaktif (button/slider/kamera) terkonstruksi tanpa error secara headless tetapi tidak dapat diklik di sana — interaksi desktop berstatus **LIKELY** (kode Control standar).

### 5.5 Pemeriksaan oleh pemilik yang direkomendasikan (editor resmi desktop, ~5 menit)
1. Buka di Godot **4.7.2** desktop, Import -> `EXOCOMFLICT_HERO01/project.godot`; import pertama sekarang seharusnya selesai tanpa dialog apa pun.
2. Jalankan (F5): clip diputar, panel AUTO RIG CHECK semua LULUS. Pemeriksaan visual dengan rendering asli: texture/lighting, scrub perlahan dengan preset CloseHands/CloseWeapon, konfirmasi kontak grip dan clearance dada secara visual (semuanya sudah terverifikasi numerik, 5.3).
3. Konfirmasi konvensi arah-hadap (facing) untuk proyek utama: karakter menghadap +Z sebagaimana dikirim; putar root HERO_01 sebesar 180° terhadap sumbu Y jika proyek utama mengharapkan forward −Z.
Belum pernah dijalankan di mana pun: retargeting BoneMap untuk clip pihak ketiga (RIG_SPECIFICATION bagian 6) — tetap **UNVERIFIED**.

### 5.6 Perbaikan lanjutan dari preview pemilik: detail hilang saat bergerak (2026-10-30)
Masukan dari preview desktop pemilik: detail halus pada weapon, badan, dan tangan terlihat hilang saat bergerak. Diagnosis (VERIFIED secara statis): material pada GLB yang disertakan **tidak memiliki flag `doubleSided`** (default glTF = false, sama seperti file sumber), sehingga Godot membuat material dengan backface culling. HERO_01 terdiri dari 247 shell terbuka yang tidak watertight; Blender/Cycles me-render kedua sisi face (itulah sebabnya screenshot Blender terlihat utuh), sedangkan Godot membuang (cull) permukaan shell yang membelakangi kamera, sehingga detail tipis (panel/arch weapon, strap/flap kerah, jari) hilang pada sudut-sudut tertentu selama animasi. Risiko pendukung: LOD mesh otomatis Godot menyederhanakan shell kecil seiring jarak, dan instance ber-skin dapat terkena frustum-culling terhadap bounds pose istirahatnya pada kamera dekat.
Perbaikan yang disertakan:
- `HERO_01_RIGGED.glb` dan `HERO_01_WEAPON.glb`: material di-patch menjadi **`doubleSided: true`** dengan `tools/patch_glb_double_sided.py` (hanya penyisipan byte pada chunk JSON; chunk BIN terverifikasi identik byte-per-byte lewat hash; ukuran 22,878,116 -> 22,878,136 B dan 5,326,624 -> 5,326,644 B, sehingga angka pada bagian 4 adalah kondisi sebelum perubahan flag ini; file sumber yang dilestarikan tidak diubah, MD5 `9d0ad8cd...`). Godot meng-import material glTF doubleSided dengan face culling nonaktif.
- `hero_01.gd`: export baru `force_full_detail` (default aktif) mengatur `lod_bias = 64` dan `extra_cull_margin = 1.0` pada setiap `GeometryInstance3D` karakter/weapon setelah weapon terpasang, mencegah LOD pop-out dan cull pop akibat deformasi. Diterapkan setelah semua setup kritis; murni aditif.
Status: patch GLB serta invariansi geometri/weight/animasi **VERIFIED** (pemeriksaan parse + hash di atas). Pemetaan import Godot doubleSided -> culling nonaktif adalah perilaku standar yang terdokumentasi (**LIKELY**; build Godot sandbox tidak dipertahankan, jadi tidak ada run in-engine baru pada putaran ini). Hasil visual **UNVERIFIED** sampai pemilik melakukan re-import (editor otomatis me-reimport GLB yang berubah; jika tidak, hapus folder `.godot/` pada proyek lalu buka kembali) dan menjalankan ulang preview. Jika setelah perbaikan ini masih ada bagian spesifik yang hilang, penyebabnya adalah skin weight shell individual (mis. shell zona grip), bukan pengaturan rendering - screenshot/video momen persisnya akan didiagnosis per shell.

## 6. Pemetaan kriteria penerimaan (Milestone 1)
- Humanoid berig yang utuh secara visual di Blender: **VERIFIED** (§1–2, render).
- `Weapon_Raise_To_Aim` di Blender: **VERIFIED** (§3).
- Karakter + clip yang sama di Godot 4.7.2: **VERIFIED** pada runtime (headless) — import bersih, Skeleton3D 24 bone, playback clip disampel di dalam engine, grip/barrel/root semuanya terukur (5.2–5.4). Item yang tersisa bagi pemilik hanyalah pemeriksaan *visual* desktop (5.5), karena Godot headless tidak menggambar pixel.
- Skeleton humanoid / weight yang diinspeksi / stabilitas armor / attachment weapon yang terdokumentasi: **VERIFIED** sebagaimana dirinci di atas.
- Spesifikasi yang membedakan verified vs unverified: laporan ini + ART_ASSET_REPORT / RIG_SPECIFICATION / ANIMATION_SPECIFICATION.

## 7. Pekerjaan lanjutan yang direkomendasikan (bukan bagian Milestone 1)
1. Pemeriksaan visual desktop oleh pemilik (5.5); lalu kunci keputusan tinggi/skala karakter final (saat ini asumsi x1.8, RIG_SPECIFICATION bagian 2).
2. Varian pose aim ADS dengan cheek-weld jika ADS bergaya first-person diperlukan.
3. Set locomotion (idle/walk/run) — validasi weight pergelangan `Hand_L` serta rentang hip/knee pada ekstrem gerakan lari terlebih dahulu.
4. Pass LOD/decimation opsional yang disetujui pemilik untuk budget performa; pisahkan 19 shell grip-fusion hanya jika keadaan tangan-kosong saat weapon disembunyikan diperlukan.
