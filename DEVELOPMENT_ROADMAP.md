# Project Overdrive — Development Roadmap

> **Status:** Prototype NEON FRONTIER 3D kini mencakup world modular, KayKit GLTF, Runner/Shooter waves, Pulse/Nova/Arc, EMP, dan UI touch/HUD. Sepuluh GLB Kenney Space Kit CC0 telah dicari, diunduh, dan dikurasi sebagai kandidat; belum ditempatkan ke scene. Android import/export workflow sudah disiapkan, tetapi Godot/JDK/Android SDK tidak tersedia di sesi ini; smoke test terbaru, import, APK, render, dan perangkat belum diverifikasi. Permanent progression dan balancing interaktif juga belum selesai.
>
> **Pembaruan 16 Oktober 2026 (tooling & gap analysis):** pemeriksaan statis kini benar-benar dijalankan dan dapat direproduksi — `./scripts/dev_check.sh` lulus untuk 28 skrip (gdparse + gdlint + gdformat, gdtoolkit 4.5.0) dan `tools/project_doctor.py` melaporkan 0 FAIL / 8 WARN atas referensi scene, jalur node, tipe script/node, aksi input, signal, group, kontrak senjata, integritas glTF, dan konsistensi dokumen; satu temuan nyata (`load_steps` salah di `scenes/enemies/shooter.tscn`) sudah diperbaiki. Ditambahkan `scripts/install_godot.sh` (unduh + verifikasi SHA-512 + template, di luar repo), `scripts/run_smoke_tests.sh` (import + 9 smoke test + log), dan CI `.github/workflows/godot-ci.yml`. **Verifikasi runtime pertama sudah diperoleh lewat CI:** `Godot CI` run #1 (PR #1, run `38905670471`) hijau untuk job statis **dan** job engine — Godot 4.7.2-stable resmi dipasang dengan verifikasi checksum (`4.7.2.stable.official.ed1daf0bf`), project diimpor headless, dan **9/9 smoke test keluar dengan exit code 0** (dua run berturut-turut hijau). Sandbox coding ini sendiri tetap tidak dapat mengunduh engine (host aset rilis diblokir), jadi CI adalah environment runtime sampai engine dipasang di mesin dev. Yang belum tercakup: render, frame time, dan perilaku perangkat Android. Lihat [`GAP_ANALYSIS.md`](GAP_ANALYSIS.md) untuk daftar gap berprioritas (progresi persisten, audio/VFX, navigasi musuh, Android baseline).
>
> **Tanggal pembaruan:** 16 Oktober 2026
>
> **Sumber keputusan:** `GAME_CONCEPT.md`, `GAME_OVERVIEW.md`, dan `IAP_CONCEPT.md` di `main` (commit awal repository: `03ffb078`).
>
> **Platform MVP:** Android · **Engine baseline:** Godot 4.7.2-stable + GDScript (provisional) · **Mode:** single-player

Roadmap ini menerjemahkan dokumen konsep menjadi urutan kerja yang dapat diuji. Angka durasi, biaya unlock, statistik senjata, target FPS, dan harga **belum dianggap final**; tetapkan setelah perangkat uji dan hasil playtest diketahui.

## Status implementasi saat ini

Project Godot di `game/` menyusun dunia NEON FRONTIER sebagai satu level 3D kontinu sekitar 192 × 180 unit. Arena reactor, command center, lab, depot, generator, landing pad, gate/turret perimeter, sektor rusak, batu/kristal/tanaman alien, dan boss platform dibuat dari PackedScene komponen 3D dengan mesh, material, serta collider; beberapa prop memakai GLTF KayKit CC0. Kode saat ini juga mencakup third-person player/camera, input desktop/touch, target latihan, health/damage/retry, Wave Director Runner/Shooter, Pulse/Nova/Arc, EMP, HUD/Results, dan 360° joystick. **Verifikasi terkini:** tidak ada Godot/JDK/Android SDK di sesi ini; import engine dan smoke test setelah integrasi GLTF/EMP/joystick belum dijalankan. Sebuah environment/headless build pada checkout lebih lama pernah mengukur 2.545 `MeshInstance3D` dan 138 `StaticBody3D`, memeriksa traversal, dan menjalankan regression smoke; angka/hasil historis tersebut bukan verifikasi terhadap kode terbaru. Android export scaffold kini mencakup preload statis KayKit GLTF dan `scripts/export_android_debug.sh`. Sepuluh kandidat GLB Kenney Space Kit yang sudah diunduh tercatat di `game/assets/world/kenney_space_kit/ASSET_PROVENANCE.md` dan belum dimasukkan ke scene/export dependency graph. Belum ada export preset lokal, APK, deployment, atau hasil perangkat. Blockout bukan art final; visual renderer, navigasi menyeluruh, performa mobile, dan balance belum final. BP wallet permanen, unlock/equip, dan save juga belum diimplementasikan.

## 1. Ringkasan produk yang dibangun

**Project Overdrive** adalah third-person sci-fi arena survival shooter untuk sesi singkat. Pemain bergerak dengan kontrol sentuh, membidik dari kamera over-the-shoulder, melawan wave musuh, mendapat Battle Points (BP), membuka senjata, lalu masuk arena lagi.

Urutan prioritas produknya:

1. Gerak, kamera, aiming, dan tembakan terasa nyaman di ponsel.
2. Hit, damage, eliminasi, serta feedback audio/visual jelas dan konsisten.
3. Senjata memiliki pola dan fungsi yang benar-benar berbeda.
4. Wave loop, hasil pertandingan, BP, unlock, dan save bekerja tanpa duplikasi atau kehilangan progres.
5. Art/audio dan optimasi dilakukan setelah gameplay dasar terbukti menyenangkan.
6. Monetisasi opsional baru dikembangkan setelah loop gratis dan progresi stabil.

**Bukan sasaran MVP:** multiplayer, open world, campaign panjang, crafting, skill tree, leaderboard online, loot box, Battle Pass, premium subscription, atau ekonomi IAP lengkap.

## 2. Baseline dan interpretasi dokumen

- Kamera third-person over-the-shoulder; gerak relatif ke kamera. Arah bidik ditentukan kamera, lalu tembakan bergerak dari muzzle ke titik sasaran. Obstacle harus tetap menghentikan tembakan.
- Kontrol mobile: joystick kiri, look/aim kanan, fire, pergantian senjata, dan pause. Auto-fire hanya opsi untuk diuji, bukan asumsi default.
- Combat menggunakan satu pipeline bersama; konfigurasi senjata disimpan sebagai Godot `Resource` (`.tres`). Projectile dapat berupa hitscan, proyektil fisik, atau efek area/chain sesuai kebutuhan senjata.
- Runner dan Shooter adalah dua archetype musuh pertama. AI awal memakai state machine sederhana; jangan mulai dari behavior tree kompleks.
- Pisahkan **Run Score** dari **Battle Points**. Reward eliminasi dikeluarkan dari event kematian yang tervalidasi tepat satu kali, bukan dari setiap projectile.
- Progres MVP disimpan lokal. Data save harus divalidasi; jangan menganggap save lokal sebagai sumber yang aman untuk permainan kompetitif.
- Art direction adalah stylized-realistic sci-fi yang terbaca di layar kecil. Gunakan Blender sebagai file sumber dan GLB sebagai aset runtime yang diuji di Godot.
- Mobile renderer dan Compatibility renderer harus dibandingkan di perangkat sasaran. Pilihan renderer, batas jumlah musuh, dan sasaran performa ditetapkan dari build nyata, bukan hanya editor.
- Multiplayer tetap *deferred*. Batas tanggung jawab komponen dijaga rapi, tetapi tidak dibuat abstraksi networking atau server sebelum kebutuhan produk terbukti.

### Resolusi scope senjata MVP

`GAME_CONCEPT.md` mendefinisikan MVP dengan **tiga** senjata, sementara daftar Phase 3 mencantumkan Scatter Blaster, Arc Shooter, dan Nova Launcher selain Pulse Rifle. Agar cakupan MVP tetap tiga dan selaras dengan contoh visual di `GAME_OVERVIEW.md`, pilihan kerja yang digunakan saat ini adalah:

1. **Pulse Rifle** — starter, tembakan energi cepat.
2. **Nova Launcher** — proyektil lambat dan damage area.
3. **Arc Shooter** — serangan listrik/chain terbatas.

Dengan pilihan ini, **Scatter Blaster** menjadi senjata tambahan pertama setelah MVP; Rail Cannon dan Gravity Gun menyusul lebih jauh. Prototype Arc sudah diimplementasikan sebagai chain terbatas dan smoke test headless memeriksa target selection, cover, jumlah hop, radius, serta falloff. Roster tetap provisional sampai rasa tembak dan biaya implementasi divalidasi lewat playtest; jika chain terlalu mahal untuk MVP, Arc dapat ditukar dengan Scatter Blaster tanpa mengubah arsitektur `WeaponDefinition`.

### Resolusi scope monetisasi

MVP hanya membutuhkan ekonomi gratis: BP, unlock senjata, inventaris, equip, dan local save. **Jangan** tambahkan Core Shards, pembelian uang sungguhan, rewarded ads, BP booster, atau katalog toko produksi dalam MVP. Setelah gameplay/progresi stabil, kosmetik dan toko simulasi dapat diuji; rewarded ads dan real IAP memerlukan gate kebijakan, privasi, usia audiens, dan validasi transaksi tersendiri. Tidak boleh ada senjata gameplay yang hanya dapat dibeli.

## 3. Keputusan yang harus dikunci pada Phase 0

Keputusan berikut belum ditentukan secara eksplisit dalam dokumen. Catat jawabannya di changelog keputusan proyek sebelum konten produksi membesar.

| Keputusan | Rekomendasi awal | Mengapa perlu dikunci |
|---|---|---|
| Orientasi layar | Landscape, lalu validasi dengan pemain | Kontrol dua ibu jari dan kamera third-person membutuhkan ruang horizontal. |
| Perangkat minimum | Pilih satu perangkat Android kelas rendah/menengah sebagai baseline dan satu perangkat pembanding | Menentukan renderer, batas efek, jumlah musuh, serta anggaran performa. |
| Renderer Godot | Uji Mobile terlebih dahulu; uji Compatibility bila perangkat sasaran memerlukannya | Dokumen konsep meminta keputusan berdasarkan perangkat nyata. |
| Versi Godot | Pilih satu rilis stabil Godot 4.x dan pin selama milestone | Export templates, plugin, dan build harus cocok versinya. |
| Roster MVP | Pulse + Nova + Arc; keputusan bersyarat seperti di atas | Menyelaraskan jumlah MVP dengan contoh pada Overview. |
| Audiens/usia | Putuskan apakah game secara khusus ditujukan kepada anak-anak atau audiens umum | Berpengaruh ke rating, iklan, privasi, dan kebijakan platform. Jangan pasang SDK iklan sebelum keputusan ini ditinjau. |
| Target performa | Ukur baseline dahulu; tetapkan sasaran frame time/FPS setelah device dipilih | Jangan mengklaim target yang belum pernah diuji. |
| Bahasa & aksesibilitas | Tentukan bahasa rilis pertama, kebutuhan subtitle, ukuran teks, dan opsi sensitivitas | Mencegah UI dan kontrol dibangun ulang belakangan. |

## 4. Roadmap fase demi fase

Durasi menggunakan **sprint relatif** (satu sprint kira-kira 1–2 minggu). Ini estimasi perencanaan untuk tim kecil, bukan janji kalender; solo development, aset eksternal, dan kapasitas playtest dapat memperpanjangnya. Art source dan UI boleh berjalan paralel setelah pipeline dan greybox disetujui.

### Phase 0 — Scope, toolchain, dan validasi teknis

**Estimasi:** 1 sprint. **Tujuan:** memastikan fondasi produksi bisa menghasilkan build Android yang dapat diuji.

**Pekerjaan**
- Putuskan item pada tabel keputusan Phase 0; buat catatan versi tool.
- Siapkan Godot 4.x, export templates yang cocok, Android SDK/JDK sesuai dokumentasi versi Godot, Git, Blender, serta perangkat Android/ADB. Lihat [`TOOLCHAIN_SETUP.md`](TOOLCHAIN_SETUP.md).
- Buat project Godot dan struktur folder minimal; pilih renderer setelah uji singkat.
- Buat arena greybox, capsule/mesh placeholder, spawn point, collision, dan camera rig sederhana.
- Uji kontrol sentuh dan pipeline Blender → GLB → Godot dengan satu aset dummy.
- Hasilkan, pasang, dan jalankan debug build Android di perangkat baseline.

**Deliverable:** keputusan teknis tercatat, project kosong dapat dibuka, greybox dapat diekspor dan dimainkan di Android, serta GLB dummy masuk dengan skala/orientasi benar.

**Exit gate:** build Android berhasil dipasang; joystick/look tidak saling mengambil input; renderer dan perangkat baseline dipilih; tidak ada plugin IAP/iklan yang ikut ditambahkan.

### Phase 1 — Vertical slice: movement, camera, dan Pulse Rifle

**Estimasi:** 1–2 sprint. **Tujuan:** membuktikan kontrol dan sensasi menembak sebelum membuat konten besar.

**Pekerjaan**
- `PlayerController` berbasis `CharacterBody3D`: gerak relatif kamera, akselerasi/deselerasi, gravitasi, collision, dan orientasi karakter.
- `CameraRig` dengan yaw/pitch pivot, SpringArm3D, batas pitch, follow smoothing, dan collision avoidance.
- Input map untuk joystick kiri, area look/aim kanan, fire, weapon switch, serta pause. Uji skema sentuh pada beberapa rasio layar.
- Hybrid aiming: ray dari kamera menentukan titik sasaran, lalu ray/projectile dari muzzle menuju titik itu; dinding harus memblokir tembakan.
- Pulse Rifle versi pertama, satu target dummy/Runner, health, hit reaction sederhana, muzzle flash, impact, dan audio sementara.
- Buat test scene yang bisa mengulang tembak-hit-mati dengan cepat; jangan membuat model karakter final dahulu.

**Exit gate (Gate A/B):** karakter tidak menembus lantai/obstacle; kamera stabil; sentuhan kanan tidak menggerakkan karakter; aim dapat diprediksi; hit/damage hanya diterapkan sesuai collision; pemain dapat menembak dan mengulang skenario tanpa blocker. Catat temuan kontrol sebelum memperluas fitur.

### Phase 2 — Fondasi combat modular dan musuh MVP

**Estimasi:** 1–2 sprint. **Tujuan:** menambah kedalaman tanpa menggandakan kode senjata.

**Status implementasi:** in progress — `WeaponDefinition`/`WeaponController` data-driven menggerakkan Pulse Rifle, Nova Launcher, dan Arc Shooter. Smoke test mencakup switching desktop/touch, cooldown, Pulse hit/blocking, Nova area damage, Arc chain/line-of-sight/cap/radius/falloff, Shooter telegraph/cover/dodge, reward idempotent, dan mixed waves. Eksekusi smoke terakhir bersifat historis pada checkout lebih lama; perubahan terbaru belum dapat diuji karena Godot tidak tersedia di sesi ini. Validasi death/reward-once dari combat senjata dan playtest balancing masih tertunda.

**Pekerjaan**
- Implementasikan `WeaponDefinition` berbasis `.tres`, `WeaponController`, dan pipeline umum: validasi input/fire rate → resolusi aim → hitscan/projectile → hit → damage → impact/audio/feedback.
- Pisahkan `HealthComponent`, `CombatResolver`, efek visual, reward, dan UI. Event death hanya boleh diproses satu kali.
- Implementasikan perilaku senjata sesuai roster yang diputuskan. Prototype Nova (projectile + explosion radius) dan Arc (hitscan + chain target terbatas dengan line-of-sight) kini tersedia; Arc tidak memakai simulasi fisika listrik.
- Tambahkan Runner dan Shooter. Gunakan finite state machine sederhana; gunakan Navigation mesh/path update terjadwal bila arena membutuhkannya.
- Smoke test senjata memeriksa indeks pilihan invalid, switching desktop/touch, cooldown, Pulse yang terhalang dan kena target, Nova direct/splash/radius, serta Arc yang menghormati cover, memilih target chain dengan line-of-sight, berhenti pada batas chain/radius, dan menerapkan falloff tanpa hit duplikat. Lengkapi validasi kematian/reward-once dari combat senjata; regression test reward yang ada sudah memeriksa idempotensi Runner/Shooter.

**Exit gate (Gate B):** senjata MVP terasa berbeda dari pola, jarak, atau hasil serangannya; target mati sekali; tidak ada reward sebelum eliminasi; musuh kedua dapat menyerang dengan telegraph terbaca; combat tetap jelas ketika efek dasar aktif.

### Phase 3 — Survival loop, wave, dan Results

**Estimasi:** 1 sprint. **Tujuan:** membentuk satu sesi yang lengkap dan bisa diulang.

**Status implementasi:** in progress — Wave Director Runner/Shooter, run-scoped Score/BP reward, survival timer, serta Results/retry overlay tersedia. Smoke test untuk loop tersebut ada, tetapi eksekusi pada versi project terbaru belum diverifikasi di sesi ini karena Godot tidak tersedia. Results masih menyimpan data hanya selama run; progression permanen dan session flow lengkap belum ada.

**Pekerjaan**
- `WaveDirector`: mulai/selesai wave, komposisi musuh, spawn point valid, jeda, batas musuh aktif, progres, dan kondisi game over.
- Tingkatkan kesulitan dengan satu atau dua variabel dahulu; angka formula di konsep adalah titik eksperimen, bukan balancing final.
- Pisahkan `RunScore` dan BP. Hasilkan reward dari event musuh mati dan penyelesaian wave yang sah; cegah reward ganda.
- HUD: health, crosshair, wave, enemy counter, score, BP run, fire, weapon switch, pause.
- Pause/resume, game over, results (wave, eliminasi, score, BP, senjata), retry, dan kembali ke weapon menu.
- Ukur sasaran sesi eksplorasi 3–8 menit dari konsep; jangan memaksa durasi ini sebelum playtest.

**Exit gate (Gate C):** satu alur penuh dari arena → combat/wave → mati/hasil → retry berjalan berulang; tidak ada wave yang macet tanpa alasan; spawn tidak muncul terlalu dekat/di dalam obstacle; hasil yang ditampilkan cocok dengan data sesi.

### Phase 4 — BP, weapon unlock, dan local save

**Estimasi:** 1 sprint. **Tujuan:** membuat progression MVP transparan dan aman dari bug transaksi lokal.

**Pekerjaan**
- Kembangkan `RewardService` run-only yang sudah ada bersama `ProgressionService`/`UnlockService`, katalog senjata, dan inventaris terpisah dari UI.
- Buka senjata dengan BP; Pulse tersedia sejak awal; transaksi menolak saldo kurang dan tidak pernah membuat saldo negatif; unlock berulang tidak memotong saldo.
- Weapon menu: nama, deskripsi peran, harga, status unlock/equip, dan tombol yang sesuai status. Hanya item yang dimiliki dapat dipilih.
- Simpan BP, unlock/equip, best score, statistik dasar, dan pengaturan yang disepakati. Validasi nilai saat load dan sediakan nilai default bila save rusak/tidak tersedia.
- Tulis test untuk award, unlock atomik, equip, restart, save rusak, dan reward sesudah game over.

**Exit gate (Gate D):** pemain dapat memperoleh BP, membuka dan memakai senjata pada run berikutnya; saldo/status tetap benar setelah restart; UI bukan pemilik state ekonomi; run score tidak tercampur dengan mata uang.

### Phase 5 — Art, audio, VFX, dan UX pass

**Estimasi:** 2–3 sprint, sebagian dapat paralel setelah Phase 0/1. **Tujuan:** mencapai tampilan yang koheren tanpa mengorbankan keterbacaan dan performa.

**Pekerjaan**
- Buat character, senjata MVP, Runner/Shooter, arena kecil, cover, dan elemen UI dengan siluet kuat dan material terbedakan.
- Terapkan pipeline Blender `.blend` (source) → GLB (runtime). Catat lisensi/sumber untuk setiap aset pihak ketiga.
- Animasi minimum: idle/move/fire/hit/death yang diperlukan untuk keterbacaan; jangan membuat rig/animasi kompleks yang tidak dipakai.
- VFX: muzzle, trail, impact, explosion/chain, death/reward. Batasi transparansi, lifetime, cahaya berbayang, dan jumlah partikel berdasarkan uji device.
- Audio: tembakan, impact, enemy attack/hit, eliminasi, reward, UI, dan ambience sederhana. Pastikan aset berlisensi.
- Finalisasi menu, Results, font/kontras, safe area, dan ukuran kontrol di layar kecil.

**Exit gate:** placeholder inti sudah diganti atau diberi alasan; pemain masih dapat membaca ancaman, crosshair, dan projectile ketika layar ramai; aset impor benar; tidak ada regresi gameplay akibat model/animasi.

### Phase 6 — Profiling Android, closed playtest, dan balancing

**Estimasi:** 1–2 sprint, lalu diulang setelah perubahan besar. **Tujuan:** menemukan masalah nyata di perangkat dan perilaku pemain.

**Pekerjaan**
- Jalankan build release/debug di perangkat baseline dan pembanding; gunakan profiler Godot serta Android logcat.
- Profil jumlah musuh/projectile, draw calls, shader/material, shadow, particle overdraw, memory, waktu load, panas, dan crash. Pool objek **hanya** bila profiling menunjukkan bottleneck.
- Playtest tertutup dengan pemain target; amati pemahaman kontrol, senjata yang dicoba/dipakai, kapan pemain berhenti, alasan retry, bug, dan performa. Minta izin/privasi yang sesuai; untuk MVP cukup catatan playtest terkontrol—belum perlu analytics SDK.
- Tuning reward/unlock dari rata-rata run dan waktu membuka senjata; pastikan pemain gratis tetap memperoleh progres berarti.
- Tetapkan ambang performa dan indikator keberhasilan setelah data baseline, bukan berdasarkan tebakan.

**Exit gate:** tidak ada blocker yang diketahui pada core loop; save dapat bertahan di skenario uji; target performa yang disepakati tercapai di device sasaran; masalah terbesar hasil playtest ditangani atau diterima secara sadar.

### Phase 7 — Single-player Release Candidate

**Estimasi:** 1–2 sprint. **Tujuan:** menyiapkan build Android yang stabil; fitur baru ditahan.

**Pekerjaan**
- Regression test untuk Gate A–F, rasio/aspect layar, pause/resume, kehilangan fokus, restart app, save load, dan koneksi offline.
- Siapkan package ID, ikon/splash, versi, signing key/release process, internal testing track, crash triage, dan catatan build.
- Simpan signing keys, kata sandi, dan credential di luar repository/secret manager; jangan commit ke Git atau `export_presets.cfg` lokal.
- Tetapkan rating usia, deklarasi data, privasi, izin aplikasi, dan store listing sebelum publikasi. Bila produk diarahkan ke anak, review kebijakan keluarga/iklan secara khusus.
- Tidak memasukkan pembelian/iklan sungguhan ke release candidate tanpa approval produk, teknis, kebijakan, serta QA tersendiri.

**Exit gate (Gate F):** core loop dapat dijalankan dan diulang; tidak ada blocker/error kritis berulang; tidak ada kehilangan progres yang diketahui; build ditandatangani dan dapat dipasang lewat jalur uji internal.

### Phase 8 — Monetisasi pasca-core-game (opsional, gate terpisah)

**Tujuan:** menambahkan monetisasi yang tidak merusak pengalaman gratis. Urutannya mengikuti `IAP_CONCEPT.md`.

1. **Cosmetic foundation:** data skin, preview, equip/inventory, kosmetik tidak mengubah statistik. Selesaikan hanya jika konten kosmetik dan art pipeline tersedia.
2. **Store simulation:** katalog produk data-driven dan alur simulasi khusus development/test. Pastikan flag/dev build tidak bisa memberi produk gratis pada build produksi.
3. **Rewarded Ads:** integrasi hanya setelah penentuan usia audiens, consent, privacy/data disclosure, SDK/policy review, dan frequency cap. Iklan hanya opt-in di hasil pertandingan; reward normal selalu diberikan; bonus hanya setelah callback valid; gagal/batal tidak menghapus reward normal.
4. **Real IAP:** buat SKU yang jelas, integrasikan Google Play Billing melalui plugin yang kompatibel dengan versi Godot yang dipin, lalu tangani sukses, pending, cancel, gagal, restore, koneksi putus, dan duplikasi callback. `PurchaseHandler`/`EntitlementService` tidak boleh terikat ke combat. Verifikasi ownership sesuai model keamanan produk; jangan menyamakan respons UI lokal dengan bukti transaksi.
5. **Tuning ekonomi:** pertimbangkan Core Shards, Starter Bundle, atau booster hanya setelah data BP/run, biaya unlock, durasi, minat kosmetik, dan kebijakan audiens tersedia. BP Booster ditunda; loot box dan Battle Pass tetap di luar baseline.

**Gate:** semua jalur pembelian dan iklan harus bisa gagal dengan aman; pemain yang menolak/tidak bisa membayar tetap dapat memainkan konten inti dan membuka senjata gameplay lewat BP.

### Phase 9 — Evaluasi kelayakan multiplayer

Mulai hanya jika single-player stabil dan hasil playtest menunjukkan kebutuhan. Sebelum prototype networking, buat dokumen pilihan co-op vs competitive, authority server, state replication, latency, matchmaking, biaya operasi, anti-cheat, dan maintenance. Lakukan feasibility prototype terpisah; jangan menganggap arsitektur single-player saat ini otomatis siap multiplayer.

## 5. Urutan dependensi sistem

```text
Toolchain + device baseline
  → player movement + camera + touch aim
  → hit/damage + one weapon + one enemy
  → data-driven weapons + enemy roster
  → wave/session/results/retry
  → BP + unlock + inventory + save
  → art/audio/performance + closed playtest
  → Android release candidate
  → (opsional) cosmetics → store simulation → ads/IAP
  → (opsional, paling akhir) multiplayer feasibility
```

Jangan mendahulukan final art, monetisasi, atau networking atas loop gerak-tembak yang dapat dimainkan.

## 6. Quality gates ringkas

- **A — Movement/camera:** gerak dan collision benar, aim nyaman, tidak ada tembus lantai/dinding.
- **B — Combat:** firing/hit/damage konsisten; death dan reward hanya sekali; efek/audio memberi feedback tanpa menutup gameplay.
- **C — Wave:** spawn valid; jumlah musuh dibatasi; transisi dan game over tidak macet.
- **D — Progression:** BP, unlock/equip, best score, save/load tervalidasi dan tidak membuat saldo negatif.
- **E — Android:** kontrol sentuh, safe area/rasio, pause, save, dan performa diuji pada perangkat nyata.
- **F — Release candidate:** core loop dapat diulang; tidak ada blocker; progres tidak hilang pada skenario uji; signing dan internal distribution tersedia.

## 7. Risiko utama dan mitigasi

| Risiko | Mitigasi praktis |
|---|---|
| Aim kamera terasa buruk di layar sentuh | Validasi di Phase 1 dengan greybox dan perangkat nyata sebelum art. Uji sensitivitas, dead zone, dan skema fire. |
| Terlalu banyak senjata/fitur sebelum core loop | Batasi MVP ke tiga senjata dan dua musuh; simpan sisanya sebagai post-MVP. Gunakan exit gate. |
| Performa Android rendah | Baseline sejak Phase 0; profiling build perangkat; batasi efek/pathfinding; optimasi berdasar data. |
| Asset pipeline memperlambat gameplay | GLB test sejak Phase 0, placeholder lebih dulu, versi low-cost, simpan file Blender sumber dan katalog lisensi. |
| BP/save/reward tidak konsisten | Service terpisah, event death idempotent, test transaksi dan save sebelum UI polish. |
| Monetisasi berisiko untuk audiens muda | Tidak ada SDK iklan/IAP di MVP; tetapkan audiens dan review kebijakan/privacy sebelum Phase 8. |
| Scope multiplayer menghambat MVP | Multiplayer hanya feasibility gate setelah release candidate single-player. |

## 8. Langkah kerja berikutnya

0. **Alur review cepat (tanpa instalasi):** pakai build WebAssembly — `python -m http.server 800 --bind 0.0.0.0` dari root repo, lihat [`WEB_PREVIEW.md`](WEB_PREVIEW.md). Ini memungkinkan iterasi UI/UX serta uji kontrol sebelum toolchain Android siap; renderer web adalah Compatibility, jadi bukan pengganti verifikasi performa perangkat.
1. **Stage 0 — Android baseline (current, gate E):** ikuti [`ANDROID_BASELINE.md`](ANDROID_BASELINE.md). Ringkasnya: `./scripts/install_godot.sh --with-templates` → `./scripts/setup_android_sdk.sh --guide` lalu `--install-packages` → `python3 tools/android_preset.py scaffold --package-id <id> && python3 tools/android_preset.py check` → `./scripts/export_android_debug.sh` → `adb install` di perangkat baseline → checklist uji sentuh/pause/retry → tabel profiling §7. Verifikasi runtime headless sudah berjalan di CI (9/9 smoke test lulus); yang belum ada adalah APK dan hasil perangkat.
2. **Stage 1 — Blockout:** the initial world layout is approved as a prototype direction. Keep that layout in component-based 3D; use interactive/device playtests to tune traversal, collision, controls and feel. Initial layout approval does not mean final visuals, playability, performance, or release acceptance; headless historical checks do not establish those.
3. **Stage 2 — Asset production:** after Stage 1 approval, replace only high-impact primitives with modular 3D assets made in Blender or Tripo AI. Preserve source files, actual 3D geometry, scale/origin/collision integration, and asset provenance/licensing.
4. **Stage 3 and 4 — Materials/textures, then lighting/VFX:** apply the approved PBR palette and surface detail first; then tune lighting, energy effects, particles, and environmental VFX without harming mobile readability.
5. **Stage 5 — Optimization:** after selecting an Android baseline, profile real device builds (frame time, draw calls, memory, overdraw, physics, load, heat/stability), optimize measured bottlenecks, and rerun gameplay tests. Export success alone is not a device-performance pass.
6. Continue permanent BP wallet, unlock/equip, and local save only after combat/traversal are stable; monetization remains deferred. Commit and push every job’s verified deliverable before beginning the next stage.

Catatan: toolchain Godot, JDK, Android SDK, export templates, dan perangkat uji tidak tersedia pada sandbox saat pembaruan ini. Workflow dapat berjalan tanpa GUI, tetapi import/export harus dijalankan ulang pada mesin dengan SDK/JDK/templates yang cocok; APK sukses sekalipun belum membuktikan performa atau kontrol perangkat.

**Prinsip penutup:** ukur dan validasi dulu. Game ini menang lewat respons kontrol, variasi senjata, feedback combat, dan keinginan bermain ulang—bukan banyaknya sistem atau cepatnya memasukkan IAP.