# Exocomplict — Analisis Gap & Status Verifikasi

> **Tanggal:** 16 Oktober 2026 · **Branch:** `arena/5257bce8-cyber-strike` · **Pin engine:** Godot 4.7.2-stable (`.godot-version`)
>
> **Sumber kebenaran:** kode di `game/`, dokumen `GAME_CONCEPT.md`, `GAME_OVERVIEW.md`, `DEVELOPMENT_ROADMAP.md`, `PROJECT_DECISIONS.md`, `WORLD_BLOCKOUT.md`, `TOOLCHAIN_SETUP.md`, `IAP_CONCEPT.md`, `ANIMATION_ASSET_INSPECTION.md`, `ASSET_CANDIDATE_REVIEW.md`.
>
> Dokumen ini memisahkan **apa yang benar-benar sudah diverifikasi** dari **apa yang baru direncanakan atau baru diklaim**. Kalau sebuah item tidak punya bukti eksekusi, item itu ditulis sebagai belum terverifikasi.

---

## 1. Ringkasan eksekutif

Slice saat ini adalah **prototype arena survival third-person** yang sudah dapat dimainkan secara kode: world 3D kontinu NEON FRONTIER, player third-person + kamera over-the-shoulder, tiga senjata data-driven (Pulse Rifle, Nova Launcher, Arc Shooter), skill EMP Pulse, dua archetype musuh (Runner, Shooter) plus training drone, Wave Director deterministik, reward run-scoped, HUD/touch controls, serta 9 smoke test headless.

**Perubahan status terbesar pada sesi ini: 9 smoke test sekarang PASS di Godot 4.7.2-stable asli.** Karena binary engine tidak dapat diunduh di sandbox, verifikasi runtime dipindahkan ke CI: `install_godot.sh` memasang engine resmi (SHA-512 dari `SHA512-SUMS.txt`), lalu `run_smoke_tests.sh` melakukan import headless dan menjalankan kesembilan test. Run pertama (`Godot CI` #1, run `38905670471`, PR #1) selesai **hijau untuk kedua job** — static checks dan headless smoke tests. Artinya klaim "smoke test belum diverifikasi" sudah tidak berlaku untuk checkout ini; yang masih belum diverifikasi adalah render, frame time, dan input perangkat.

Sesi ini memindahkan proyek dari "hanya klaim dokumen" ke **verifikasi statis yang nyata + tooling yang siap dipakai**:

| Sebelum sesi ini | Setelah pekerjaan ini |
|---|---|
| Klaim "lint + format lulus" tanpa bukti yang dapat dijalankan ulang | `./scripts/dev_check.sh` benar-benar dijalankan: 28 file GDScript lolos parse, `gdlint`, `gdformat --check` |
| Tidak ada pemeriksaan referensi/struktur tanpa engine | `tools/project_doctor.py` memeriksa 30 file scene/resource + 28 script, 11 kelompok pemeriksaan, hasil sekarang **0 FAIL / 8 WARN** |
| Tidak ada cara memasang Godot yang dipin | `scripts/install_godot.sh` (unduh → verifikasi SHA-512 → ekstrak → symlink → template opsional); **sudah diuji end-to-end dengan release lokal tiruan** |
| Perintah smoke test tersebar di dokumen, tanpa ringkasan hasil | `scripts/run_smoke_tests.sh` (import headless + 9 test + log per test + exit code) |
| Tidak ada CI | `.github/workflows/godot-ci.yml`: job statis + job mesin Godot headless (import + 9 smoke test + artefak log) |
| GitHub Actions tidak pernah menjalankan proyek | Workflow di-push dan **run pertama hijau**: job statis + job engine (import + 9 smoke test). Bukti: run `38905670471` di PR #1 |

**Dua hal yang masih menjadi blocker dan harus dikerjakan di luar sandbox ini:**

1. **Android Phase 0 (gate E)** — belum ada JDK, Android SDK/ADB, export preset lokal, APK, maupun device uji. CI headless tidak dapat menggantikan ini karena membutuhkan perangkat nyata.
2. **Art character/weapon (Phase 5)** — player & musuh masih capsule, senjata masih box; `HERO_01.glb` (2 byte) bukan aset valid dan tidak ada rig/animasi.

Catatan: verifikasi runtime headless kini berjalan otomatis di CI, tetapi **tidak** menggantikan pengujian di mesin developer (F5/inspect scene) maupun perangkat Android.

---

## 2. Yang benar-benar diverifikasi pada sesi ini

| Item | Cara verifikasi | Hasil |
|---|---|---|
| Isi repo & git state | `find`, `git log/status` | 107 file, HEAD `fe809e9`, branch bersih, tanpa PR terbuka |
| GDScript dapat diparse | `gdparse` (gdtoolkit 4.5.0) pada 28 file | **lulus**, tidak ada syntax error |
| Gaya & format GDScript | `gdlint` + `gdformat --check` (aturan `gdlintrc`, max 1600 baris) | **lulus**, "Success: no problems found" / "28 files would be left unchanged" |
| Referensi scene/resource | `tools/project_doctor.py` | 30 file `.tscn/.tres`: ext_resource, sub_resource, parent node, `load_steps` |
| Jalur node literal | project doctor (`$Path`, `get_node`, `NodePath` export) | Semua jalur milik scene sendiri resolve; 6 lookup lintas-scene dilaporkan sebagai WARN (memang bergantung pada parent scene saat runtime) |
| Tipe script vs tipe node | project doctor | Setiap script (`extends`) cocok dengan tipe node yang memasangnya |
| Aksi input | project doctor | 7 aksi dipakai kode, 7 terdefinisi di `project.godot` |
| Signal & group | project doctor | 26 signal; semua target `connect("...")` terdeklarasi; 3 group (`enemies`, `runner_enemies`, `shooter_enemies`) konsisten |
| Kontrak senjata | project doctor (mirror `WeaponDefinition.is_valid_definition()`) | 3 `.tres` valid, projectile scene ada dan punya `launch()` |
| Aset glTF/GLB | project doctor (header + dependensi) | 17 aset valid; `HERO_01.glb` 2 byte ditandai |
| Installer Godot | dijalankan dengan release tiruan lokal (`GODOT_RELEASE_BASE=file://…`), termasuk template `.tpz` | unduh, **verifikasi SHA-512**, ekstrak, symlink, direktori template: **lulus** |
| Runner smoke test | dijalankan dengan stub `godot` (bukan engine) | Alur import → 9 test → log → ringkasan → exit code bekerja |
| `check_toolchain.sh` | dijalankan dengan editor tiruan + tanpa JDK/SDK | Melaporkan 2 FAIL (Java, Android SDK) dan 2 WARN (Blender, LFS) dengan benar |
| **Import Godot + 9 smoke test** | CI `Godot CI` run `38905670471` (commit `d3fec14`) dan `38905987866` (commit `425e159`), job "Headless smoke tests (Godot 4.7.2)" | **Lulus dua kali.** Bukti yang dapat dibaca ulang dari annotation check-run: `Godot engine = 4.7.2.stable.official.ed1daf0bf` dan `Smoke tests = 9 passed, 0 failed (of 9, import ok)`. Log per test tersedia sebagai artefak CI `smoke-test-logs` |
| Static check di CI | CI `Godot CI` #1, job "Static checks (gdtoolkit + project doctor)" | **Lulus** (gdtoolkit + project doctor berjalan di runner bersih) |

**Belum diverifikasi (jangan diklaim):** tampilan render, performa/frame time, perilaku sentuh di perangkat, export/APK Android, rig/animasi, serta semua angka performa historis (`2.545 MeshInstance3D`, `138 StaticBody3D`) yang berasal dari checkout lama. Log lengkap tiap test tersedia sebagai artefak CI `smoke-test-logs` (unduhan artefak diblokir dari sandbox, jadi di sini buktinya adalah status langkah CI + ringkasan `exports/test-logs/summary.txt` yang juga dicetak ke job summary).

---

## 3. Perbaikan nyata yang sudah masuk

| # | Temuan | Bukti | Tindakan |
|---|---|---|---|
| 1 | `scenes/enemies/shooter.tscn` menulis `load_steps=8`, padahal file mendeklarasikan 9 resource (1 ext + 7 sub + 1) | project doctor | Diperbaiki menjadi `load_steps=9` |
| 2 | Tidak ada jalur pemeriksaan tanpa engine | kebutuhan fase berikutnya | `tools/project_doctor.py` + `scripts/dev_check.sh` ditambahkan |
| 3 | Tidak ada installer build yang dipin, padahal dokumen mewajibkan Godot 4.7.2 Standard | kebutuhan Phase 0 | `scripts/install_godot.sh` (keluar dari repo, verifikasi checksum) |
| 4 | Smoke test harus dijalankan satu per satu dengan perintah manual | `README.md`, `TOOLCHAIN_SETUP.md` | `scripts/run_smoke_tests.sh` + CI headless |

---

## 4. Peta implementasi per sistem

| Sistem | Status implementasi | Berkas kunci | Gap yang tersisa |
|---|---|---|---|
| Gerak & kamera | `CharacterBody3D`, gerak relatif kamera, akselerasi, gravitasi; kamera yaw/pitch + SpringArm, pitch clamp −52°…+35° | `scripts/player/player_controller.gd`, `scripts/camera/camera_rig.gd`, `scenes/player/player.tscn` | Belum ada sensitivitas configurable, auto-aim opsional, atau feel-test di perangkat |
| Aiming & tembakan | Raycast kamera → titik bidik; tembakan dari muzzle ke titik bidik; obstacle menghentikan proyektil | `weapon_controller.gd`, `pulse/nova/arc_projectile.gd` | Tidak ada spread/recoil, tidak ada hitscan untuk senjata cepat, tanpa audio/VFX tembakan |
| Hit & damage | `apply_damage()` konsisten; proyektil & rantai menghindari double-damage lewat dictionary instance id | `arc_projectile.gd`, `nova_projectile.gd` | Tidak ada hit reaction, knockback, headshot, atau damage number |
| Senjata | Roster MVP 3 senjata data-driven (Pulse 5/s 18 dmg; Nova 0,8/s 34 dmg + splash 24@4; Arc 2/s 20 dmg, chain 2@5 ×0,7) | `resources/weapons/*.tres`, `weapon_definition.gd` | Belum ada Scatter Blaster/Rail/Gravity; belum ada unlock/equip; cooldown disimpan di array (tidak persisten lintas sesi) |
| Skill | EMP Pulse: 18 dmg, radius 9, cooldown 12 s, efek torus, feedback HUD | `player_controller.gd` | Hanya satu skill; tidak ada skill musuh/boss |
| Musuh | Runner (36 HP, 3,8 u/s, melee 8/1,25 s) dan Shooter (30 HP, windup 0,7 s, hit-scan 8 dmg, 2,2 s) + training drone respawn | `scripts/enemies/*.gd`, `scenes/enemies/*.tscn` | **Tanpa navigasi/obstacle avoidance** (musuh bergerak garis lurus dan bisa tersangkut cover/ramp); visual capsule; tidak ada telegraph visual serangan Runner |
| Wave & sesi | Wave deterministik: 3 musuh wave 1 (+1/wave, cap 8), active cap 3, Shooter dari wave 2, spawn validasi bounds/obstacle/kamera-front, intermission 3 s, state `BLOCKED`/`GAME_OVER` | `scripts/waves/wave_director.gd` | Tanpa boss, elite, atau variasi pola wave; spawn retry hanya 6 kali lalu memblokir sesi |
| Reward & progresi | Run-scoped: Runner/Shooter 100 score + 10 BP, wave +100 BP, idempotent per instance id | `scripts/progression/*.gd` | **Belum ada BP wallet persisten, unlock/equip, save/load lokal** (gate D) |
| HUD & kontrol | Health/wave/run card, crosshair, hit/damage feedback, tombol FIRE/WEAPON/EMP/PAUSE, hasil + RETRY, joystick 360° + look, `PROCESS_MODE_ALWAYS` saat pause | `scripts/ui/touch_controls.gd`, `scenes/ui/hud.tscn` | Tanpa menu pengaturan (sensitivitas/volume), tanpa safe-area untuk layar berponi, tanpa indikator FPS/frame time |
| World | 1 level kontinu ~192×180 unit dari komponen procedural + 7 GLTF KayKit; arena, outpost, ekstraksi, landing pad, perimeter, sektor rusak, alien, boss gate | `scripts/worlds/neon_frontier_world.gd`, `neon_frontier_asset.gd`, `scenes/worlds/**` | Blockout bukan art final; 10 GLB Kenney sudah diunduh tetapi **belum dipakai di scene**; `scenes/arena/arena_graybox.tscn` tidak direferensikan siapa pun (orphan) |
| Audio | — | — | **0% implementasi**: tidak ada `AudioStreamPlayer`, tidak ada aset suara |
| VFX | Efek minimal: torus EMP (tween), beam `ImmediateMesh` untuk Arc, material emissive | `player_controller.gd`, `arc_projectile.gd` | Tidak ada partikel, trail, decal, muzzle flash, impact/explosion |
| Animasi | — | — | Tidak ada `AnimationPlayer`/`Skeleton3D`; player & musuh statis |
| Save/load | — | — | Tidak ada `FileAccess`/`ConfigFile`/`user://` |
| Navigasi | — | — | Tidak ada `NavigationRegion3D`/`NavigationAgent3D` |
| Android | Renderer `mobile`, landscape, `emulate_mouse_from_touch=false`, preload GLTF untuk dependency export, skrip export debug | `project.godot`, `scripts/export_android_debug.sh` | Belum ada `export_presets.cfg`, JDK, SDK, APK, atau device test |
| Jaringan/monetisasi | Sengaja tidak ada | — | Sesuai keputusan: di luar MVP |

---

## 5. Gap berprioritas

Prioritas di bawah memakai urutan dependensi di `DEVELOPMENT_ROADMAP.md` §5: verifikasi → core loop → progresi → art/audio → performa → release.

### P0 — blocker yang menghambat kepercayaan pada kode

| ID | Gap | Dampak | Cara menutup | Definisi selesai |
|---|---|---|---|---|
| G1 | ~~Belum ada verifikasi runtime~~ **Tertutup di CI** | — | Selesai: `install_godot.sh` + `run_smoke_tests.sh` dijalankan di CI | ✅ CI #1: 9/9 smoke test exit code 0. Sisa kecil: belum dijalankan di mesin dev (F5/inspeksi scene) |
| G2 | ~~Tidak ada CI~~ **Tertutup** | — | Selesai: `.github/workflows/godot-ci.yml` | ✅ Job statis + job engine hijau pada run pertama |
| G3 | Phase 0 Android belum lulus (gate E): JDK, SDK/ADB, preset lokal, APK, device | Renderer, kontrol sentuh, dan performa belum dapat divalidasi | **Tooling siap:** `scripts/setup_android_sdk.sh` (deteksi JDK/SDK, `--install-packages`, env file di luar repo), `tools/android_preset.py` (scaffold/patch/check preset tanpa GUI), dan runbook [`ANDROID_BASELINE.md`](ANDROID_BASELINE.md) dengan checklist perangkat + prosedur profiling. Sisanya butuh perangkat nyata | APK debug terpasang dan dijalankan di perangkat baseline, checklist §6 lulus, tabel §7 terisi |
| G4 | Aset karakter/senjata tidak valid atau tidak ada; tidak ada rig/animasi | Phase 5 terblokir; presentasi tidak dapat naik kelas | Sediakan GLB berig (atau jalankan Blender) + validasi impor; `HERO_01.glb` (2 byte) dihapus/ditandai | Satu karakter berig + satu senjata terimpor dan tampil benar di Godot |

### P1 — melengkapi core loop (gate D & pengalaman inti)

| ID | Gap | Dampak | Cara menutup |
|---|---|---|---|
| G5 | Progresi persisten belum ada: BP wallet, unlock/equip, save/load lokal, best score | Pemain tidak punya alasan bermain ulang (design pillar 4); gate D gagal | Tambahkan service tersimpan (`FileAccess` + `user://progression.cfg` atau JSON), idempotent, dengan smoke test baru (write → read → saldo tidak negatif → unlock/equip) |
| G6 | Audio 0% | "Sensasi menembak" (pillar 3) tidak bisa dinilai; feedback kombat tidak lengkap | Tambahkan bus + `AudioStreamPlayer` untuk muzzle, impact, hit, eliminasi, reward, UI, ambience; aset CC0 berlisensi; batasi jumlah suara bersamaan untuk mobile |
| G7 | VFX minimal (tanpa partikel/trail/impact) | Readability ancaman & kepuasan menembak lemah | Muzzle flash, impact, explosion Nova, chain Arc, death burst; batasi overdraw berdasarkan pengukuran device |
| G8 | Musuh tanpa navigasi/obstacle avoidance | Musuh dapat tersangkut di cover/ramp → wave tidak selesai → sesi `BLOCKED` | Minimal steering menghindari tembok (raycast kiri/kanan) atau `NavigationRegion3D` + `NavigationAgent3D` bila profiling mengizinkan; tambahkan test navigasi di smoke |
| G9b | Review visual/gameplay membutuhkan instalasi Godot + Android SDK (mahal untuk iterasi cepat) | Iterasi UI/UX tertahan toolchain | **Jalur preview WebAssembly ditambahkan:** `scripts/export_web_preview.sh` + `game/web_shell/index.html` + landing `index.html` + job CI `web-preview`; cukup `python -m http.server 800 --bind 0.0.0.0` di root repo | Artefak `web-preview` tersedia di CI dan game terbuka di browser; temuan UI dicatat lalu diverifikasi ulang di Android |
| G9 | Tidak ada telemetry internal (FPS/frame time, jumlah musuh aktif, draw call) | Profiling Phase 6 akan menebak-nebak; sementara ini hanya bisa lewat remote debug Editor (`Debugger > Monitors`) | Tambahkan overlay debug opsional (`Performance.get_monitor`) yang dapat dimatikan di build rilis |
| G10 | Tidak ada menu pengaturan & safe-area awareness | Tidak siap untuk perangkat nyata (layar berponi, sensitivitas berbeda) | `DisplayServer.get_display_safe_area()` untuk HUD; slider sensitivitas/volume; simpan ke file save yang sama |

### P2 — presentasi & efisiensi

| ID | Gap | Catatan |
|---|---|---|
| G11 | Material dibuat per komponen pada saat runtime | Banyak instance material serupa → risiko draw call tinggi di mobile; ukur dulu sebelum pooling/batching |
| G12 | 10 GLB Kenney (`game/assets/world/kenney_space_kit/`) belum dipakai scene mana pun | Kandidat pengganti prop blockout; butuh keputusan artistik + validasi impor |
| G13 | `scenes/arena/arena_graybox.tscn` + `scripts/arena/arena_graybox.gd` orphan | Dead content: simpan sebagai referensi atau hapus agar tidak menyesatkan |
| G14 | `pulse_projectile.gd` mengekspor `collision_mask` yang tidak dipakai (Nova memakai `_collision_mask`) | Sumber kebingungan saat menambah senjata baru |
| G15 | ESC tidak dapat me-resume di desktop (`main.gd` berhenti diproses saat pause; `TouchControls` hanya menangani R) | Perbaikan kecil tapi jelas terasa pada fallback PC |

### P3 — sengaja ditunda (bukan cacat)

Monetisasi (Core Shards, IAP, rewarded ads), multiplayer, Battle Pass/loot box, campaign/open world, leaderboard online. Semua tetap di luar MVP sesuai `DEVELOPMENT_ROADMAP.md` §2 dan `IAP_CONCEPT.md`.

---

## 6. Status per gate roadmap

| Phase | Fokus | Status | Bukti / penghambat |
|---|---|---|---|
| 0 | Scope + toolchain + build Android | **Sebagian** | Tooling lokal siap (installer, doctor, dev check, runner, CI). Godot belum dijalankan; JDK/SDK/preset/device belum ada → gate E belum lulus |
| 1 | Movement, kamera, Pulse Rifle | **Implementasi ada, verifikasi belum** | Kode lengkap + 9 smoke test; hasil engine belum diperoleh |
| 2 | Hit/damage + musuh | **Implementasi ada, verifikasi belum** | Runner/Shooter/drone + smoke `combat_feedback`, `shooter_enemy` |
| 3 | Wave/session/results + 3 senjata | **Implementasi ada, verifikasi belum** | `wave_director_smoke`, `weapon_system_smoke`, `arc_weapon_smoke` |
| 4 | BP + unlock + inventory + save | **Belum mulai** | Gate D belum; lihat G5 |
| 5 | Art/audio/VFX | **Belum mulai** | Placeholder capsule/box; audio 0%; lihat G4, G6, G7 |
| 6 | Profiling Android + playtest + balancing | **Belum mulai** | Butuh G1–G3 selesai lebih dulu; tambahkan G9 agar data terukur |
| 7 | Release candidate single-player | **Belum mulai** | Butuh gate A–E lulus |
| 8 | Monetisasi pasca-core-game | **Ditunda (gate terpisah)** | Sesuai kebijakan audiens/usia belum diputuskan |
| 9 | Evaluasi multiplayer | **Ditunda** | Hanya setelah single-player stabil |

---

## 7. Rekomendasi urutan kerja berikutnya

1. ~~Jalankan verifikasi engine (G1, G2).~~ **Selesai di CI** (run #1 hijau). Sisa opsional: jalankan `./scripts/install_godot.sh --with-templates && ./scripts/run_smoke_tests.sh` di mesin dev agar hasilnya dapat dilihat langsung bersama scene (F5).
2. **Bangun progresi persisten (G5).** Satu service + data save + smoke test: BP bertambah, unlock hanya sekali, equip memengaruhi roster di arena, saldo tidak pernah negatif, save bertahan setelah restart. Ini melengkapi core loop dan membuka gate D.
3. **Feedback pass minimum (G6, G7).** Mulai audio + VFX untuk tembakan/impact/eliminasi/reward dengan aset berlisensi jelas dan batas overdraw; jangan polish art sebelum Android baseline diukur.
4. **Android baseline (G3).** Setelah langkah 1 hijau: pasang JDK/SDK, buat preset `Android`, ekspor APK debug, ukur frame time/draw call di device baseline, lalu tuning (G9, G11) berdasarkan data.
5. **Art produksi (G4).** Setelah rig/animasi tersedia dan pipeline Blender → GLB tervalidasi, ganti placeholder secara bertahap tanpa mengubah kontrak gameplay (`apply_damage`, `launch`, `eliminated`).

---

## 8. Cara memakai tooling baru

```bash
# 1. Pemeriksaan statis (tanpa Godot, bisa dijalankan di CI/sandbox)
./scripts/dev_check.sh

# Validasi struktur saja, dengan daftar temuan per kelompok
python3 tools/project_doctor.py            # atau: .venv/bin/python tools/project_doctor.py

# 2. Memasang engine yang dipin (di luar repo, dengan verifikasi checksum)
./scripts/install_godot.sh                 # engine saja
./scripts/install_godot.sh --with-templates

# 3. Verifikasi runtime di engine
./scripts/run_smoke_tests.sh               # import headless + 9 smoke test + log
./scripts/run_smoke_tests.sh --list
./scripts/run_smoke_tests.sh wave_director_smoke

# 4. Toolchain Android: deteksi/pasang JDK+SDK, tulis env file, lalu preflight
./scripts/setup_android_sdk.sh --guide
./scripts/setup_android_sdk.sh --install-packages
./scripts/check_toolchain.sh

# 5. Preset Android lokal (git-ignored) tanpa GUI Editor
python3 tools/android_preset.py scaffold --package-id com.studioanda.exocomplict
python3 tools/android_preset.py check

# 6. Build APK debug, lalu ikuti runbook perangkat + profiling
./scripts/export_android_debug.sh        # lihat ANDROID_BASELINE.md untuk langkah adb

# 7. Preview WebAssembly tanpa instalasi (review UI/UX cepat)
./scripts/export_web_preview.sh          # butuh Godot; atau unduh artefak CI "web-preview"
python -m http.server 800 --bind 0.0.0.0 # buka http://localhost:800/
```

Lint GDScript memakai `.venv`:

```bash
python3 -m venv .venv
.venv/bin/pip install -r requirements-dev.txt
./scripts/dev_check.sh
```

`exports/` (termasuk `exports/test-logs/`) sudah diabaikan Git, jadi log test tidak masuk commit.

---

## 9. Batas kejujuran dokumen ini

- Semua status "lulus" pada §2 berasal dari eksekusi di sesi ini (sandbox) atau dari run CI yang dapat diperiksa ulang, dan dapat direproduksi dengan perintah di §8.
- Installer dan runner smoke test **diuji dua kali**: dengan release lokal tiruan dan stub binary (membuktikan alur skrip), lalu dengan Godot 4.7.2-stable asli di CI (membuktikan perilaku engine headless).
- Hasil smoke test di CI membuktikan logika gameplay headless: gerak/traversal, tembakan & damage, wave, reward, HUD/touch routing, dan struktur world. Hasil itu **tidak** membuktikan tampilan render, frame time, maupun input di perangkat.
- Engine yang dipakai CI adalah build resmi `4.7.2.stable.official.ed1daf0bf`, diverifikasi terhadap `SHA512-SUMS.txt` resmi pada saat pemasangan, sehingga kegagalan unduh/checksum akan menggagalkan job — bukan lolos diam-diam.
- Tidak ada klaim tentang tampilan render, performa mobile, kontrol sentuh, atau APK pada dokumen ini.
- Angka gameplay (damage, HP, fire rate, reward) adalah nilai prototype sesuai `PROJECT_DECISIONS.md`, bukan hasil balancing terukur.
