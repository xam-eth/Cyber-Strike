# Exocomplict — Android Baseline Runbook (Gate E)

> **Tujuan:** membuat build Android debug yang benar-benar terpasang dan berjalan di perangkat, lalu mengukur performa serta kontrol sentuh sesuai quality gates di [`../DEVELOPMENT.md`](../DEVELOPMENT.md).
>
> **Status tooling:** scaffold, export APK debug arm64, sparse payload audit, dan keberadaan profiler sudah lulus CI; native visual capture dan remote-loop guidance mempunyai static/fake-ADB gate pada checkpoint di [`../VALIDATION.md`](../VALIDATION.md). **Belum ada instalasi, screenshot/video, FPS, thermal, atau hasil perangkat fisik**; dokumen ini tetap merupakan prosedur pengujian perangkat.
>
> **Pin versi:** Godot 4.7.2-stable (`.godot-version`), GDScript. Versi SDK/JDK harus cocok dengan dokumentasi Godot versi tersebut.

---

## 0. Definisi selesai (gate E)

Gate E dianggap lulus jika **semua** poin ini ada buktinya:

1. `./scripts/check_toolchain.sh` melaporkan **0 FAIL** (Godot Editor, Java/JDK, Android SDK).
2. `python3 tools/android_preset.py check` melaporkan **0 FAIL** pada preset `Android`.
3. `./scripts/export_android_debug.sh` menghasilkan `exports/exocomplict-debug.apk` dan seluruh smoke test dalam inventaris saat ini lulus pada langkah itu.
4. APK terpasang dan dapat dijalankan di minimal satu perangkat Android nyata (`adb install` sukses, aplikasi masuk ke arena).
5. Kontrol sentuh terverifikasi manual: joystick kiri menggerakkan, drag kanan mengubah kamera, FIRE/WEAPON/EMP/PAUSE merespons, orientasi landscape, tidak ada tombol yang tertutup area sistem.
6. Pause/resume, kehilangan fokus (home), dan kembali ke aplikasi tidak merusak sesi; RETRY setelah defeat bekerja.
7. Ada angka pertama untuk FPS/frame time, jumlah musuh aktif, memori, dan suhu perangkat pada build yang sama.
8. Screenshot/video native untuk state visual yang berubah telah ditangkap melalui §5.2 dan direview manusia; capture saja bukan approval.

Poin 1–3 bisa dilakukan tanpa perangkat. Poin 4–8 memerlukan perangkat. Visual capture dan profiling dilakukan sebagai run terpisah pada build/skenario yang sama.

---

## 1. Prasyarat

| Kebutuhan | Catatan |
|---|---|
| Godot 4.7.2-stable editor + export templates versi sama | `./scripts/install_godot.sh --with-templates` |
| JDK 17 atau lebih baru | `JAVA_HOME` harus menunjuk ke JDK yang sama dengan yang dipakai Godot |
| Android SDK: `cmdline-tools`, `platform-tools`, satu SDK platform, satu build-tools | Tanpa Android Studio pun cukup; paket versinya mengikuti dokumentasi Godot 4.7 |
| Perangkat Android kelas rendah/menengah sebagai baseline + satu pembanding | Aktifkan USB debugging hanya selama pengujian |
| Kabel USB yang stabil | Alternatif: `adb connect` via Wi-Fi untuk perangkat yang mendukung |

---

## 2. Langkah A — Engine + export templates

```bash
./scripts/install_godot.sh --with-templates
export PATH="$HOME/.local/bin:$PATH"      # bin dir default; sesuaikan bila diubah
godot --version                            # harus 4.7.2.stable.*
./scripts/check_toolchain.sh               # Godot harus OK di langkah ini
```

## 3. Langkah B — JDK dan Android SDK

```bash
./scripts/setup_android_sdk.sh --guide              # instruksi manual per OS
./scripts/setup_android_sdk.sh                      # deteksi + tulis android-env.sh
./scripts/setup_android_sdk.sh --install-packages    # pasang paket SDK via sdkmanager
source "$HOME/.local/share/exocomplict/android-env.sh"
./scripts/check_toolchain.sh                        # target: 0 FAIL
```

`ANDROID_SDK_PLATFORM` (default `android-36`) dan `ANDROID_BUILD_TOOLS` (default `36.0.0`) dapat di-override. Jika Godot menolak export karena paket hilang, dialog Export di Editor menyebutkan paket persisnya — pasang paket itu dengan `sdkmanager`.

Setelah SDK siap, arahkan Godot ke toolchain **satu kali** melalui GUI:
`Editor > Editor Settings > Export > Android` → isi **Android SDK Path** dan **Java SDK Path**. Debug keystore dibuat otomatis oleh Godot pada export pertama; jangan commit keystore ke repo.

## 4. Langkah C — Preset export Android (sekarang bisa tanpa GUI)

`game/export_presets.cfg` sengaja di-ignore Git karena memuat path lokal dan setelan signing. Tool baru menangani pembuatan/validasinya:

```bash
# 1) Preset dari nol (CLI-only). Ganti package id — Google Play menolak com.example.*
python3 tools/android_preset.py scaffold \
  --package-id com.studioanda.exocomplict \
  --app-name "Exocomplict" \
  --version-code 1 --version-name 0.1.0 \
  --arch arm64-v8a

# 2) Atau, jika preset sudah dibuat lewat Editor: sinkronkan nilainya (aman, ada backup)
python3 tools/android_preset.py patch --package-id com.studioanda.exocomplict

# 3) Validasi
python3 tools/android_preset.py check
python3 tools/android_preset.py show
```

Catatan penting tentang `scaffold`: berkas yang dihasilkan memakai set option yang Godot 4.x tulis untuk preset Android; Godot mengisi option yang tidak ada dengan nilai default platform dan menormalkan berkas saat preset disimpan dari Editor. Scaffold **sudah divalidasi oleh export Android CI** pada checkpoint di [`../VALIDATION.md`](../VALIDATION.md). Jika preset lokal lama berbeda dan `--export-debug` mengeluh, sinkronkan dengan mode `patch` atau buka/simpan dialog Export sekali lalu ulangi validasi.

## 5. Pilih loop development dan bukti perangkat

Jangan memakai satu perintah untuk semua tujuan. Tiga jalur berikut mempunyai kontrak berbeda:

| Tujuan | Jalur | Batas |
|---|---|---|
| Iterasi scene/script/visual yang cepat | Godot One-click Deploy + Remote Debug + Network Filesystem | Memerlukan Editor yang dapat dihubungi perangkat; bukan APK offline final |
| Screenshot/video native dari state yang sedang dilihat | `scripts/android_visual.sh` | Human visual review tetap PENDING; bukan pengukuran FPS/audio |
| Install offline, relaunch, log, dan performa terukur | `scripts/android_usb.sh` | Reinstall/relaunch, bukan hot reload; profiling harus menjadi run terpisah |

### 5.1 Inner loop — Godot Remote Debug dan Small Deploy

Scaffold `tools/android_preset.py` menulis `runnable=true`. Untuk preset buatan sendiri, pastikan preset Android juga ditandai **Runnable** di dialog Export. Setelah langkah A–C selesai:

1. Sambungkan perangkat, izinkan USB debugging, lalu pastikan `adb devices` menampilkan state `device`.
2. Buka `game/project.godot` dengan Godot 4.7.2. Pada menu **Debug**, aktifkan **Deploy with Remote Debug** dan **Small Deploy with Network Filesystem**.
3. Untuk perubahan yang sedang dikerjakan, aktifkan **Synchronize Scene Changes** dan/atau **Synchronize Script Changes** pada menu yang sama.
4. Klik tombol Android/Remote Deploy di kanan atas Editor. Godot mengekspor, memasang, dan menjalankan debug build pada perangkat yang dipilih. Network Filesystem membuat Editor menyediakan file proyek tanpa mengirim full game pada setiap iterasi.
5. Gunakan Output/Debugger dan Remote scene inspector untuk memeriksa state yang benar. Jika koneksi remote gagal, periksa otorisasi ADB serta Editor Settings > Network > Debug dan jaringan yang dipakai sesuai dokumentasi Godot; jangan menggantinya dengan klaim bahwa reinstall adalah hot reload.

Referensi resmi: [One-click Deploy](https://docs.godotengine.org/en/stable/tutorials/export/one-click_deploy.html) dan [Remote Debug/scene-script synchronization](https://docs.godotengine.org/en/stable/tutorials/scripting/debug/overview_of_debugging_tools.html).

Sinkronisasi bukan clean process restart. Setelah mengubah initialization, lifecycle, save/reset, exported properties, atau alur yang bergantung pada state lama, relaunch dan ulangi skenario dari kondisi yang diketahui. Small Deploy bergantung pada Editor/network selama development; sebelum final, kembali uji APK self-contained dari §5.3 dan §8.

### 5.2 Native screenshot dan video — IMPLEMENTED tooling

Tool ini menangkap aplikasi **yang sudah terpasang** tanpa build, install, uninstall, `pm clear`, atau perubahan save. Jalankan dari repository root:

```bash
# Satu screenshot dari state yang sedang tampil.
./scripts/android_visual.sh shot --label hud-safe-area

# Video 30 detik + screenshot sebelum/sesudah untuk gerakan/transisi.
./scripts/android_visual.sh record --seconds 30 --label reload-animation

# Pilih perangkat dan buka package yang sudah terpasang sebelum capture.
./scripts/android_visual.sh shot --serial SERIAL_HP --launch --label explore-opening

# Evidence directory eksplisit; direktori nonempty tidak akan ditimpa.
./scripts/android_visual.sh record --seconds 45 --label cache-secure \
  --output artifacts/android/visual/DEVICE-cache-secure-after
```

Tanpa `--launch`, tool sengaja mempertahankan state yang sedang tampil. `--settle-seconds` hanya memberi waktu setelah launch, bukan bukti bahwa scene sudah siap. Package id dibaca dari preset lokal atau `--package-id`; `--adb`/`ADB_BIN` dan `--serial`/`ANDROID_SERIAL` mengikuti konvensi helper USB.

Default output adalah `artifacts/android/visual/<UTC>-<label>/`:

| File | Isi dan batas |
|---|---|
| `screen.png` | Mode `shot`; PNG divalidasi termasuk chunk/CRC dan ukuran piksel |
| `before.png` / `after.png` | Mode `record`; keadaan layar sebelum dan sesudah recording |
| `motion.mp4` + `screenrecord.log` | Video native dan log `screenrecord`; container diperiksa, tetapi playback/isi tetap harus dilihat |
| `run.json` | Mode, waktu, model/Android/package/version, display/focus, checkout context, artifact hash, dan metadata warnings |
| `report.md` | Ringkasan review; selalu menandai human visual review **PENDING** dan performance evidence **NO** |

Checkout commit dalam report hanya konteks repository, **bukan bukti source yang membentuk APK terpasang**. Ukuran screenshot adalah output layar native, bukan bukti resolusi render 3D internal. Video tidak membuktikan kualitas animasi, audio, touch ergonomics, atau FPS; tinjau state dan transisi yang sebenarnya.

Untuk perbandingan perubahan, gunakan state/kamera/perangkat yang sama dan label `before`/`after` yang jelas. Untuk animasi, review sequence/video idle/run/aim/fire/reload/hit dan transisinya, bukan satu frame saja. **Jangan menjalankan `screenrecord` bersamaan dengan profiling FPS.** Ulangi skenario pada build yang sama dengan §8 setelah visual run selesai.

### 5.3 Offline USB — build/install/relaunch

Setelah langkah A–C selesai dan USB debugging sudah diizinkan di HP:

```bash
# Build source terbaru, jalankan smoke tests, install -r, lalu buka aplikasi.
./scripts/android_usb.sh

# Jika ada lebih dari satu perangkat.
./scripts/android_usb.sh --serial SERIAL_HP

# Install ulang APK yang memang belum berubah, tanpa export baru.
./scripts/android_usb.sh --skip-build

# Install APK hasil CI/unduhan tanpa memakai JDK/Godot pada langkah ini.
./scripts/android_usb.sh --skip-build --apk /path/ke/exocomplict-debug.apk

# Setelah launch, ikuti log engine dan AndroidRuntime.
./scripts/android_usb.sh --skip-build --logcat
```

Helper mencari `adb` dari `PATH`, `ADB_BIN`, atau `ANDROID_SDK_ROOT`/`ANDROID_HOME`, membaca package id dari preset lokal, menolak perangkat `unauthorized`, dan meminta `--serial` bila ada beberapa perangkat. Override yang tersedia dapat dilihat dengan `./scripts/android_usb.sh --help`.

Untuk membangun artifact APK di GitHub tanpa mengubah repository settings, sertakan tag literal `[android-build]` pada commit message perubahan Android yang memang perlu diuji. Workflow juga dapat dijalankan manual oleh akun yang memiliki akses `workflow_dispatch`. Artifact hanya membuktikan packaging; install tetap dilakukan pada HP dengan helper di atas.

`adb install -r` mempertahankan data/save selama package id dan signing key sama. Jangan uninstall atau membersihkan data saat update. Ini adalah **reinstall + relaunch**, bukan hot reload GDScript dalam proses yang tetap berjalan. Setelah APK terpasang, game dan asset-nya berjalan tanpa server Web atau unduhan data runtime.

## 6. Langkah D — Build APK debug saja

```bash
./scripts/export_android_debug.sh
```

Skrip ini: menjalankan `check_toolchain.sh` → import Editor headless → menjalankan seluruh `tests/*_smoke.gd` → `--export-debug "Android" exports/exocomplict-debug.apk` → memeriksa arsip APK. Override dengan `ANDROID_EXPORT_PRESET`, `ANDROID_APK_PATH`, `GODOT_BIN`.

## 7. Langkah E — Pasang manual dan uji di perangkat

```bash
adb devices                       # pastikan perangkat terdeteksi sebagai "device", bukan "unauthorized"
adb install -r exports/exocomplict-debug.apk
PACKAGE_ID="$(python3 tools/android_preset.py show | sed -n 's/.*package\/unique_name: //p' | head -n1)"
adb shell monkey -p "$PACKAGE_ID" -c android.intent.category.LAUNCHER 1
adb logcat -s godot:V            # jalankan di terminal kedua
```

Checklist uji manual yang harus dicatat hasilnya:

| # | Uji | Cara | Hasil yang diharapkan |
|---|---|---|---|
| E1 | Layar & orientasi | Buka aplikasi | Landscape penuh, HUD tidak terpotong, tidak ada tombol di bawah area sistem |
| E2 | Gerak | Tahan dan geser di sisi kiri | Player bergerak 360°, kecepatan proporsional jarak geser, lepas = berhenti |
| E3 | Kamera/aim | Geser di sisi kanan | Kamera berputar, pitch terbatas, crosshair tetap di tengah |
| E4 | Tembak | Tahan FIRE | Pulse Rifle menembak terus; proyektil mengenai target; hit feedback muncul |
| E5 | Ganti senjata | Tombol senjata | Nama senjata berubah; Nova meledak area, Arc merantai ke musuh terdekat |
| E6 | EMP | Tombol EMP saat READY | Musuh di radius kena damage, cincin muncul, tombol cooldown 12 s |
| E7 | Wave | Dari Explore aman, tekan START DEFENSE / `B` | Countdown terlihat sebelum wave; musuh spawn dari marker yang valid, wave naik, dan hasil tampil setelah defeat |
| E8 | Pause | Tombol PAUSE | Sesi berhenti, RESUME mengembalikan; input sentuh yang tertahan dibersihkan |
| E9 | Fokus | Tekan Home lalu kembali | Tidak ada input macet; joystick tidak "menempel" |
| E10 | Retry | Defeat lalu RETRY | Run baru bersih: HP penuh, wave 1, score/run-BP nol; wallet dan unlock permanen tetap |
| E11 | Stabilitas | Main 10–15 menit | Tidak ada crash/ANR; `adb logcat` tanpa error berulang |
| E12 | Suhu/baterai | Setelah 15 menit | Catat suhu dan tingkat baterai; perhatikan throttle |

## 8. Langkah F — Profiling terukur pada perangkat nyata

### 8.1 Capture yang dapat direproduksi — IMPLEMENTED

Profiler internal hanya aktif di Android debug, preset dengan custom feature `device_profile`, atau bila argumen `--device-profile` memang dapat diberikan oleh launcher. Ia tidak mengubah quality, resolusi, timing, gameplay, atau save. Build release normal tidak membuat node profiler.

```bash
# Build smoke-tested debug APK, install, launch, lalu rekam 120 detik.
./scripts/android_usb.sh --serial SERIAL_HP --profile-seconds 120

# Ulangi APK yang sama dengan nama evidence directory yang eksplisit.
./scripts/android_usb.sh --skip-build --serial SERIAL_HP \
  --profile-seconds 120 --profile-dir artifacts/android/DEVICE-defense-run1
```

Selama capture, mainkan skenario yang disepakati dan jangan mengirim aplikasi ke background kecuali untuk skenario lifecycle. Jangan menjalankan `android_visual.sh record` atau screen recorder lain pada saat yang sama karena overhead recording dapat mengubah frame time. Fokus keluar/masuk mengosongkan window timing agar waktu suspend tidak dihitung sebagai satu frame raksasa. Durasi minimum praktis adalah 10 detik; gunakan 120 detik untuk skenario dan 15 menit untuk soak. Logcat mentah tetap disimpan bila report gagal.

Setiap `artifacts/android/<capture>/` berisi:

| File | Isi dan batasnya |
|---|---|
| `logcat.txt` + `logcat-errors.txt` | Bukti mentah, crash/ANR, dan marker `EXOCOMPLICT_METRICS` |
| `device.json` | Model, Android, ABI, resolusi, kandidat refresh rate, package, SHA-256 APK, waktu capture |
| `raw_windows.json` / `windows.csv` | Semua window lima detik; fase, wave, jumlah musuh, FPS, p50/p95/p99/max, hitch, render/load/memory counters |
| `summary.json` / `report.md` | Ringkasan per fase dan seluruh run, siap direview |
| `gfxinfo.txt` | `dumpsys gfxinfo ... framestats`; pelengkap yang cakupannya bergantung Android/renderer |
| `meminfo-before/after.txt` | PSS dan rincian memori proses dari Android |
| `thermal-before/after.txt`, `battery-before/after.txt`, `display.txt` | Bukti sistem mentah; format/suhu yang tersedia berbeda menurut OEM |

`FPS = jumlah frame / waktu window`. p50/p95/p99 adalah nearest-rank dari frame time **di dalam window itu**. Report menghitung weighted FPS dan **worst-window p95/p99**, bukan “overall p95” palsu dari rata-rata percentile. Exact whole-run percentile membutuhkan sample setiap frame yang tidak disimpan oleh transport ringan ini. Process/physics/render counters adalah snapshot pada akhir window, bukan rata-rata window.

Folder `artifacts/android/` sengaja di-ignore Git karena log perangkat dapat memuat informasi sensitif. Review sebelum membagikannya.

### 8.2 Protokol dan matriks perangkat

1. Catat commit dan SHA-256 APK; jangan membandingkan build berbeda seolah-olah sama.
2. Gunakan skenario, resolusi/refresh, renderer, 3D scale, vsync, koneksi USB/charging, dan kondisi awal suhu yang sama. Untuk pengukuran thermal, USB charging dapat mengubah hasil; catat atau gunakan ADB Wi-Fi secara konsisten.
3. Jalankan tiga kali per skenario; simpan semua run, bukan hanya yang terbaik. Skenario minimum: cold open/shell, Explore idle, Defense awal, Defense dengan beban musuh tinggi, pause/Home/resume, lalu soak 15 menit. Jumlah musuh aktual harus berasal dari window, bukan dari nama skenario.
4. Ukur minimal satu perangkat baseline kelas rendah/menengah dan satu pembanding. Tambahkan perangkat 60/90/120 Hz bila masuk target. Budget frame adalah `1000 / refresh Hz`; 60 Hz = 16,67 ms dan 120 Hz = 8,33 ms. Counter >33/>50 ms adalah hitch umum, bukan satu-satunya ukuran jank pada refresh tinggi.
5. Tetapkan target lulus per tier hanya setelah baseline disetujui. Tanpa hasil perangkat, status FPS/full resolution/thermal tetap **UNKNOWN**; jangan menjanjikan “60 FPS penuh”.

| Perangkat / SoC / GPU | Android | Resolusi @ Hz | Build + APK SHA | Skenario / run | Weighted FPS | Worst-window p95 / p99 | >33 / >50 ms | PSS / memori | Suhu + throttle | Evidence path |
|---|---|---|---|---|---:|---|---|---|---|---|
| | | | | | | | | | | |

### 8.3 Debug, profiling release, dan release akhir

- **Debug:** alat diagnosis default. Debug template, checking, dan logging dapat mengubah FPS; hasilnya bukan sertifikasi release.
- **Profiling release candidate:** duplikat preset release, tambahkan custom feature `device_profile`, gunakan signing yang sesuai, lalu export variant khusus pengukuran. Install APK itu dengan `--skip-build --apk /path/profiling-release.apk --profile-seconds 120`. Simpan preset/signing lokal di luar Git dan **jangan mengaktifkan feature ini pada production release**.
- **Release akhir tanpa instrumentasi:** ulangi skenario pada APK final. Gunakan Perfetto/Android Studio dan `gfxinfo` untuk CPU, frequency, thermal, memori, serta frame timeline pada Android/renderer yang mendukungnya. Bila frame timeline tidak tersedia, tandai batas pengukuran; jangan menggantinya dengan angka debug.

Contoh trace sistem tambahan (Android/Perfetto yang mendukung; tambahkan `-s SERIAL` bila perlu):

```bash
adb shell perfetto -o /data/misc/perfetto-traces/cyber-strike.pftrace \
  -t 30s sched freq idle am wm gfx view binder_driver hal dalvik input memory
adb pull /data/misc/perfetto-traces/cyber-strike.pftrace \
  artifacts/android/DEVICE-defense-run1/system.pftrace
```

Remote Godot Editor (`Debugger > Monitors`) tetap berguna saat development, tetapi bukan pengganti pengujian APK yang sama dengan yang akan dikirim. Browser/software rendering juga bukan bukti FPS Android.

## 9. Kalibrasi keputusan setelah data pertama

- **Renderer:** bandingkan `mobile` vs `compatibility` pada perangkat baseline sebelum mengunci pilihan dan mencatat keputusan teknis di [`../DECISIONS.md`](../DECISIONS.md).
- **Batas musuh & efek:** nilai `max_active_enemies`, partikel, dan shadow ditetapkan dari frame time terukur, bukan tebakan.
- **Resolusi/FPS:** untuk native 3D, pertahankan `rendering/scaling_3d/scale=1.0`; jangan menurunkannya sebelum ada data. Resolusi native tidak menjamin FPS. Pertimbangkan perubahan hanya setelah mengukur perangkat baseline, dan catat nilai yang dipakai.
- **Perangkat minimum:** setelah angka pertama ada, tuliskan spesifikasi perangkat baseline sebagai keputusan resmi (saat ini masih “Not chosen yet”).

## 10. Troubleshooting umum

| Gejala | Penyebab umum | Tindakan |
|---|---|---|
| `No local Android export preset at game/export_presets.cfg` | Preset belum dibuat/dinamai lain | `python3 tools/android_preset.py scaffold …` atau set `ANDROID_EXPORT_PRESET` |
| Godot mengeluh keystore | Debug keystore belum dibuat | Buka preset di Editor sekali; Godot membuat debug keystore otomatis |
| `Missing 'platform-tools'` / build-tools | Paket SDK kurang | `sdkmanager "platform-tools" "platforms;android-XX" "build-tools;XX.0.0"` |
| `adb devices` menampilkan `unauthorized` | Belum menerima prompt USB debugging di perangkat | Terima prompt, cabut-pasang kabel |
| `android_usb.sh` menolak beberapa perangkat | Serial tujuan ambigu | Ulangi dengan `--serial SERIAL_HP`; jangan menebak perangkat |
| Aplikasi tidak muncul setelah `monkey` | Preset lama menyembunyikan launcher | Pastikan `package/show_as_launcher_app=true`; scaffold repo sekarang mengaktifkannya |
| `ETC2/ASTC texture compression is required` | Format tekstur mobile belum diaktifkan | Pertahankan `rendering/textures/vram_compression/import_etc2_astc=true` di `game/project.godot`, import ulang, lalu export |
| APK terpasang tetapi langsung tertutup | Package id/versi bentrok atau crash awal | `adb logcat -s godot:V`, cek `version/code` unik |
| Sentuh tidak berfungsi | Konfigurasi emulasi mouse | `input_devices/pointing/emulate_mouse_from_touch=false` sudah diset; pastikan event sentuh tidak ditelan UI |
| `android_visual.sh` menolak perangkat/direktori | Device unauthorized/ambiguous atau evidence sudah ada | Pilih `--serial`; gunakan `--output` baru agar evidence tidak tertimpa |
| `screenrecord` gagal / MP4 tidak valid | Recorder lain aktif, batas Android/OEM, atau transfer terputus | Baca `screenrecord.log`, hentikan recorder lain, ulangi; jangan tandai run sebagai captured/approved |
| CI hijau tetapi perangkat gagal | CI hanya menjalankan headless test | Perbedaan renderer/GPU/perangkat tidak terlihat di CI — inilah alasan gate E butuh perangkat |

## 11. Batas kejujuran dokumen ini

- APK debug dan isi payload-nya sudah diverifikasi di CI pada checkpoint [`../VALIDATION.md`](../VALIDATION.md); instalasi, kompatibilitas renderer/GPU, touch, dan performa pada perangkat Anda tetap harus diuji secara terpisah.
- Fake ADB, PNG/MP4 sintetis, dan APK sparse sintetis pada tooling tests hanya membuktikan kontrol alur/parser; hasil tiruan itu bukan bukti export, instalasi, tampilan, animasi, atau FPS perangkat nyata.
- Setelah pengujian lokal, catat keluaran `check_toolchain.sh`, keluaran `android_preset.py check`, log export, dan tabel §8 bersama commit/perangkat yang diuji. Ringkas hasilnya di [`../VALIDATION.md`](../VALIDATION.md) tanpa mengubah prosedur ini menjadi laporan checkpoint lama.
