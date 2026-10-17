# Project Overdrive — Android Baseline Runbook (Gate E)

> **Tujuan:** membuat build Android debug yang benar-benar terpasang dan berjalan di perangkat, lalu mengukur performa serta kontrol sentuh sesuai `DEVELOPMENT_ROADMAP.md` (Phase 0 dan Phase 6, gate E).
>
> **Status tooling:** siap dan sudah diuji sejauh mungkin tanpa perangkat. **Belum ada APK atau hasil perangkat** yang dihasilkan dari repo ini — dokumen ini adalah prosedur, bukan laporan hasil.
>
> **Pin versi:** Godot 4.7.2-stable (`.godot-version`), GDScript. Versi SDK/JDK harus cocok dengan dokumentasi Godot versi tersebut.

---

## 0. Definisi selesai (gate E)

Gate E dianggap lulus jika **semua** poin ini ada buktinya:

1. `./scripts/check_toolchain.sh` melaporkan **0 FAIL** (Godot Editor, Java/JDK, Android SDK).
2. `python3 tools/android_preset.py check` melaporkan **0 FAIL** pada preset `Android`.
3. `./scripts/export_android_debug.sh` menghasilkan `exports/project-overdrive-debug.apk` dan seluruh 9 smoke test lulus pada langkah itu.
4. APK terpasang dan dapat dijalankan di minimal satu perangkat Android nyata (`adb install` sukses, aplikasi masuk ke arena).
5. Kontrol sentuh terverifikasi manual: joystick kiri menggerakkan, drag kanan mengubah kamera, FIRE/WEAPON/EMP/PAUSE merespons, orientasi landscape, tidak ada tombol yang tertutup area sistem.
6. Pause/resume, kehilangan fokus (home), dan kembali ke aplikasi tidak merusak sesi; RETRY setelah defeat bekerja.
7. Ada angka pertama untuk FPS/frame time, jumlah musuh aktif, memori, dan suhu perangkat pada build yang sama.

Poin 1–3 bisa dilakukan tanpa perangkat. Poin 4–7 memerlukan perangkat.

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
source "$HOME/.local/share/project-overdrive/android-env.sh"
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
  --package-id com.studioanda.projectoverdrive \
  --app-name "Project Overdrive" \
  --version-code 1 --version-name 0.1.0 \
  --arch arm64-v8a

# 2) Atau, jika preset sudah dibuat lewat Editor: sinkronkan nilainya (aman, ada backup)
python3 tools/android_preset.py patch --package-id com.studioanda.projectoverdrive

# 3) Validasi
python3 tools/android_preset.py check
python3 tools/android_preset.py show
```

Catatan penting tentang `scaffold`: berkas yang dihasilkan memakai set option yang Godot 4.x tulis untuk preset Android; Godot mengisi option yang tidak ada dengan nilai default platform dan menormalkan berkas saat preset disimpan dari Editor. Scaffold **belum divalidasi oleh export nyata** di repo ini — kalau `--export-debug` mengeluh soal preset, buka dialog Export sekali, simpan, lalu ulangi mode `patch`.

## 5. Langkah D — Build APK debug

```bash
./scripts/export_android_debug.sh
```

Skrip ini: menjalankan `check_toolchain.sh` → import Editor headless → menjalankan seluruh `game/tests/*_smoke.gd` → `--export-debug "Android" exports/project-overdrive-debug.apk` → memeriksa arsip APK. Override dengan `ANDROID_EXPORT_PRESET`, `ANDROID_APK_PATH`, `GODOT_BIN`.

## 6. Langkah E — Pasang dan uji di perangkat

```bash
adb devices                       # pastikan perangkat terdeteksi sebagai "device", bukan "unauthorized"
adb install -r exports/project-overdrive-debug.apk
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
| E4 | Tembak | Tahan FIRE | Pulsa Rifle menembak terus; proyektil mengenai target; hit feedback muncul |
| E5 | Ganti senjata | Tombol senjata | Nama senjata berubah; Nova meledak area, Arc merantai ke musuh terdekat |
| E6 | EMP | Tombol EMP saat READY | Musuh di radius kena damage, cincin muncul, tombol cooldown 12 s |
| E7 | Wave | Diamkan permainan | Musuh spawn dari perimeter non-depan-kamera, wave naik, hasil tampil setelah defeat |
| E8 | Pause | Tombol PAUSE | Sesi berhenti, RESUME mengembalikan; input sentuh yang tertahan dibersihkan |
| E9 | Fokus | Tekan Home lalu kembali | Tidak ada input macet; joystick tidak "menempel" |
| E10 | Retry | Defeat lalu RETRY | Run baru bersih: HP penuh, wave 1, skor/BP nol |
| E11 | Stabilitas | Main 10–15 menit | Tidak ada crash/ANR; `adb logcat` tanpa error berulang |
| E12 | Suhu/baterai | Setelah 15 menit | Catat suhu dan tingkat baterai; perhatikan throttle |

## 7. Langkah F — Profiling terukur

Dua cara, pakai keduanya:

1. **Remote debug dari Editor (paling informatif).** Jalankan project ke perangkat dari Godot Editor (“Run on device” / one-click deploy), lalu buka `Debugger > Monitors`. Catat: **FPS, frame time, draw calls, objects, video memory, static/dynamic memory**.
2. **Build APK mandiri + `adb`.** Untuk angka kasar dan crash:

```bash
adb shell dumpsys thermalservice | head -20      # suhu perangkat (best effort)
adb logcat -d | grep -iE "godot|error|fatal|anr" | tail -50
adb shell dumpsys meminfo "$PACKAGE_ID" | head -20
```

Baseline yang harus dicatat pada tabel ini (satu baris per perangkat/pengaturan):

| Perangkat | Android | Renderer | FPS (idle / 3 musuh / 8 musuh) | Frame time p95 | Draw calls | Memori | Suhu setelah 15 mnt | Catatan |
|---|---|---|---|---|---|---|---|---|
| | | mobile | | | | | | |

**Gap yang diketahui sebelum profiling ini berguna:** HUD belum menampilkan FPS/frame time di dalam game (tercatat sebagai G9 di `GAP_ANALYSIS.md`). Remote debug dari Editor tetap memberi angka tersebut; menambahkan overlay internal direkomendasikan sebagai pekerjaan kecil berikutnya agar pengukuran tidak bergantung pada kabel/editor.

## 8. Kalibrasi keputusan setelah data pertama

- **Renderer:** bandingkan `mobile` vs `compatibility` pada perangkat baseline sebelum mengunci pilihan di `PROJECT_DECISIONS.md`.
- **Batas musuh & efek:** nilai `max_active_enemies`, partikel, dan shadow ditetapkan dari frame time terukur, bukan tebakan.
- **Resolusi:** pertimbangkan `rendering/scaling_3d/scale` bila perangkat baseline tertinggal; catat nilai yang dipakai.
- **Perangkat minimum:** setelah angka pertama ada, tuliskan spesifikasi perangkat baseline sebagai keputusan resmi (saat ini masih “Not chosen yet”).

## 9. Troubleshooting umum

| Gejala | Penyebab umum | Tindakan |
|---|---|---|
| `No local Android export preset at game/export_presets.cfg` | Preset belum dibuat/dinamai lain | `python3 tools/android_preset.py scaffold …` atau set `ANDROID_EXPORT_PRESET` |
| Godot mengeluh keystore | Debug keystore belum dibuat | Buka preset di Editor sekali; Godot membuat debug keystore otomatis |
| `Missing 'platform-tools'` / build-tools | Paket SDK kurang | `sdkmanager "platform-tools" "platforms;android-XX" "build-tools;XX.0.0"` |
| `adb devices` menampilkan `unauthorized` | Belum menerima prompt USB debugging di perangkat | Terima prompt, cabut-pasang kabel |
| APK terpasang tetapi langsung tertutup | Package id/versi bentrok atau crash awal | `adb logcat -s godot:V`, cek `version/code` unik |
| Sentuh tidak berfungsi | Konfigurasi emulasi mouse | `input_devices/pointing/emulate_mouse_from_touch=false` sudah diset; pastikan event sentuh tidak ditelan UI |
| CI hijau tetapi perangkat gagal | CI hanya menjalankan headless test | Perbedaan renderer/GPU/perangkat tidak terlihat di CI — inilah alasan gate E butuh perangkat |

## 10. Batas kejujuran dokumen ini

- Tidak ada APK, hasil perangkat, atau angka performa yang dihasilkan dari repo ini sampai langkah di atas benar-benar dijalankan pada mesin/perangkat Anda.
- `tools/android_preset.py` dan `scripts/setup_android_sdk.sh` diuji lokal dengan layout SDK/JPK tiruan (deteksi, patch, backup, validasi) dan `export_android_debug.sh` sudah ada sebelumnya; kombinasi dengan export nyata belum pernah dijalankan.
- Setelah selesai, kirimkan: keluaran `check_toolchain.sh`, keluaran `android_preset.py check`, log export, dan tabel §7. Dari data itu saya bisa lanjut ke optimasi terukur (G9/G11) dan melengkapi gate E di `DEVELOPMENT_ROADMAP.md`.
