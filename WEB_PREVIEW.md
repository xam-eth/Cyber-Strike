# Project Overdrive — WebAssembly Preview

> **Tujuan:** melihat dan menguji game di browser **tanpa memasang Godot, Android SDK, JDK, atau Blender** — cukup satu server statis: `python -m http.server 800 --bind 0.0.0.0` dari root repo.
>
> **Ini bukan perubahan target platform.** Android tetap target rilis; pipeline produksi tetap Godot + Blender di mesin dev. Web hanya dipakai sebagai jendela review UI/UX + gameplay supaya iterasi tidak menunggu instalasi toolchain.
>
> **Status verifikasi:** seluruh wiring statis sudah diperiksa (`tools/web_preset.py check`, `tools/project_doctor.py` → 0 FAIL, 22 unit test). Ekspor Web nyata sudah berhasil di CI (run `38919299364`, job `web-preview` hijau). Hasil terukur:

| Bagian | Ukuran | Content-Type dari `python -m http.server` |
|---|---|---|
| `index.html` | 12,9 KB | `text/html` |
| `index.js` | 273 KB | `text/javascript` |
| `index.wasm` | 37,7 MB | `application/wasm` |
| `index.pck` | 588 KB | `application/octet-stream` |
| total `web/` | 39 MB | — |

Artefak CI `web-preview` (zip, isi `web/` + `README.txt`) ≈ **10 MB** karena wasm terkompresi baik. `web/` sudah berada di repo; halaman root memuat game langsung dari situ. Kalau `web/` tidak ada, halaman menampilkan kartu diagnostik (bukan layar kosong).

**Bukti browser (dijalankan di sandbox ini, Chromium headless + WebGL 2):** `node tools/web_qa.mjs` → **2/2 halaman PASS**, keduanya mem-boot Godot `4.7.2.stable.official.ed1daf0bf`, kanvas 1280×720, WebGL hidup, tanpa error halaman maupun permintaan gagal. Tangkapan layar: `exports/web-qa/root.png` dan `exports/web-qa/web-index-html.png`.

> **Catatan bandwith:** kalau menyajikan dari `python -m http.server` di mesin sendiri, 38 MB wasm dimuat dari disk (instan). Kalau lewat GitHub Pages, Pages mengirim terkompresi (~10 MB saat muat pertama, lalu masuk cache browser). Hindari server statis lokal yang dipakai lewat jaringan Wi-Fi/HP — wasm besar tidak dikompresi oleh `http.server`.

---

## 0. Struktur: semuanya ada di dalam repo

Repo ini disusun seperti `xam-eth/Scary-Night` (game lain yang juga dipakai lewat browser): apa pun yang dibutuhkan untuk **membuka game di browser ada di repo**, bukan di balik langkah unduh manual.

| Peran | Scary-Night | Cyber-Strike (repo ini) |
|---|---|---|
| Halaman yang dibuka pemain | `index.html` di root, meng-import game (`<script type="module" src="./src/main.js">`) | `index.html` di root, **meng-import build Godot langsung** (bukan iframe): konfigurasi ekspor dibaca dari `./web/index.html`, engine dari tag statis `./web/index.js`, lalu `Engine.startGame()` |
| Payload game | `src/` (JS/Three.js, di-commit) | `web/` (`index.js`, `index.wasm`, `index.pck`, di-commit oleh job CI `web-preview`) |
| Engine | `Godot_v4.6.2-stable_linux.x86_64.zip` di root | `scripts/install_godot.sh` mengunduh 4.7.2 sesuai OS |
| Template ekspor web | `web_nothreads_release.zip`, `web_nothreads_debug.zip` di root | `engine/web_templates/*.zip` (di-commit; lihat `engine/README.md`) |
| Aset mentah (model) | GLB di root + `assets/` | `game/` (project Godot) + GLB di root |
| QA browser | `tools/*.mjs` + puppeteer-core + `@sparticuz/chromium` | `tools/web_qa.mjs` + puppeteer-core + `@sparticuz/chromium`, dijalankan di CI (dan bisa lokal) |
| Jalur Android | PWA + TWA/Bubblewrap (`android/twa-manifest.json`, `.well-known/assetlinks.json`) | ekspor Android Godot (`ANDROID_BASELINE.md`, gate E) |

Konsekuensinya: `git pull` lalu `python -m http.server 800 --bind 0.0.0.0` **langsung memainkan game** — tidak perlu membuka Actions untuk mengunduh artefak.

## 1. Alur singkat (pemakaian harian)

```bash
git pull                                        # web/ sudah ikut di dalam repo
python -m http.server 800 --bind 0.0.0.0        # dari root repo

# Buka di browser
#   http://localhost:800/        <- landing page + game
#   http://localhost:800/web/    <- halaman game langsung (fullscreen-friendly)
#   http://<ip-perangkat>:800/   <- dari HP di jaringan yang sama
```

`web/` diperbarui otomatis: setiap push ke branch ini, job CI `web-preview`
mengekspor ulang dan **meng-commit** hasilnya (`Refresh the committed web
payload and templates [skip ci]`) bila isinya berubah. Jadi tidak ada langkah
unduh artefak manual; artefak `web-preview` tetap ada sebagai jalur cadangan.

### Uji otomatis di browser (tanpa membuka browser)

```bash
npm ci --prefix tools          # sekali; mengunduh Chromium headless (paket @sparticuz/chromium)
node tools/web_qa.mjs          # menyajikan repo sendiri, membuka / dan /web/index.html
node tools/web_qa.mjs --json   # laporan terstruktur untuk skrip/CI
node tools/web_qa.mjs --play 80 --play-shot-every 25   # main sungguhan + foto berseri
```

`tools/web_qa.mjs` membuka halaman sungguhan di Chromium headless dan gagal (exit 1) bila engine tidak boot, tidak ada WebGL 2, kanvas tetap 300×150, ada permintaan 4xx/5xx, atau kartu error tampil. Tangkapan layarnya ditulis ke `exports/web-qa/`. Ini gate yang sama yang dijalankan job CI `web-preview`.

**Mode `--play <detik>`** menambahkan uji main: klik kanvas (sekaligus gesture yang dibutuhkan browser sebelum audio boleh berbunyi), lalu berjalan, berbelok, berganti senjata, dan menembak dengan event input sungguhan sambil menulis rangkaian foto `<halaman>-<viewport>-play-<t>s.png`. Ia juga memeriksa baris log `Audio:` — termasuk `Audio: first voice played (...)`, bukti audio benar-benar terpakai di browser, bukan sekadar ter-import. Di tengah sesi play, gate menekan tombol `M` dan memastikan baris `Audio: muted` muncul, jadi jalur HUD → audio ikut terbukti. Pemeriksaan itu sengaja eksak: baris boot berakhir `muted=no`, sehingga pencocokan longgar akan lulus tanpa tombolnya benar-benar sampai.

Bukti terakhir (Chromium headless, software rendering): ada dua set, keduanya di-commit karena `exports/` di-git-ignore — `qa-evidence/enemies-and-audio/` (Runner menempel di jarak melee, VITALS turun 100 → 84 → 60, senjata berganti mengikuti tombol `E`, baris `Audio: first voice played`) dan `qa-evidence/hud-mobile/` (layout 390×844 vs 844×390, dan tombol berubah `SOUND` → `MUTED` setelah gate menekan `M`). Karena renderer-nya SwiftShader (tanpa GPU), laju frame di run ini **tidak** mewakili browser sungguhan; satu tangkapan layar pun butuh belasan detik di sana, jadi pakai `--play-shot-every` yang longgar.

Tidak perlu header COOP/COEP, tidak perlu `--directory`, tidak perlu konfigurasi MIME: build yang dihasilkan memakai **single-thread** (`variant/thread_support=false`), dan Python 3.9+ sudah mengirim `.wasm` sebagai `application/wasm` (diverifikasi di sesi ini pada Python 3.11.2).

### Cadangan: artefak CI (kalau `web/` belum ada di checkout)

`Actions → Godot CI → run terbaru → Artifacts → web-preview`, ekstrak ke root repo.

### Alternatif tanpa unduh: GitHub Pages

Artefak `web-preview` ~10 MB. Kalau kuota internet sedang mahal, pakai Pages (CDN GitHub, terkompresi, tanpa unduh manual):

1. Buka **Settings → Pages** di repo, pilih **Source: GitHub Actions** (sekali saja).
2. Jalankan workflow **Godot CI** lewat **Actions → Godot CI → Run workflow** (atau biarkan terpicu setelah perubahan masuk `main`).
3. Job `deploy-pages` akan mempublikasikan landing page + build ke URL Pages; URL-nya muncul di ringkasan run dan di environment `github-pages`.

Job `deploy-pages` sudah ada di workflow dan tidak berjalan pada push biasa ke branch sesi — hanya pada dispatch manual atau push ke `main`.

## 2. Kalau ingin membangun sendiri (butuh Godot 4.7.2 + export templates)

```bash
./scripts/install_godot.sh --with-templates   # pasang engine yang dipin
./scripts/export_web_preview.sh               # preset + import + export + verifikasi
python -m http.server 800 --bind 0.0.0.0
```

`scripts/export_web_preview.sh` melakukan lima langkah dan berhenti kalau ada yang gagal:

1. `tools/web_preset.py ensure` — menulis preset **Web** ke `game/export_presets.cfg` (git-ignored). Preset Android/desktop yang sudah ada di file itu tidak diubah.
2. `tools/web_preset.py check` — memvalidasi preset + custom HTML shell (placeholder lengkap, `<canvas>`, `<canvas>` bootstrap).
3. Import headless (`godot --headless --editor --path game --quit`).
4. `godot --headless --path game --export-release Web web/index.html`.
5. `tools/verify_web_build.py web` — memastikan `index.html`, `index.js`, `index.wasm`, `index.pck` ada, magic bytes benar (`\0asm`, `GDPC`), placeholder sudah diganti, dan custom shell benar-benar terpakai.

Opsi: `--debug` (build debug, error lebih jelas, ukuran lebih besar), `--output <dir>`, `--no-import`. Override `WEB_EXPORT_PRESET` atau `GODOT_BIN` bila perlu.

## 3. Yang dibangun di dalam

| Berkas | Peran |
|---|---|
| `index.html` (root repo) | **Halaman game**: meng-import `web/` di halaman yang sama (kanvas penuh layar + chip status/kontrol/fullscreen). Menampilkan kartu diagnostik bila `web/` belum ada, konfigurasi ekspor tidak terbaca, atau WebGL 2 tidak tersedia. Tanpa CDN, tanpa build step. |
| `tools/web_qa.mjs` | QA browser headless: menyajikan repo, membuka `/` dan `/web/index.html`, memeriksa banner engine, WebGL 2, ukuran kanvas, 4xx/5xx, kartu error; menulis tangkapan layar dan laporan `--json`. Mode `--play <detik>` memainkan game dengan input sungguhan, menulis foto berseri, dan memverifikasi pipeline audio. |
| `game/web_shell/index.html` | **Custom Godot HTML shell** (dipakai lewat `html/custom_html_shell`). Menambah boot overlay bertema (progress bar + persentase), HUD atas (chip build, Fullscreen, Hide UI), panel kontrol yang bisa dilipat, dan penanganan error yang menampilkan pesan gagal yang dapat dibaca. Placeholder `$GODOT_*` resmi dipertahankan. |
| `tools/web_preset.py` | `ensure` / `check` / `show` untuk preset Web (thread support, custom shell, resize policy, PWA off). |
| `scripts/export_web_preview.sh` | Pipeline ekspor web 5 langkah + verifikasi. |
| `tools/verify_web_build.py` | Verifikasi hasil ekspor tanpa browser (magic bytes, placeholder, ukuran). |
| `tools/tests/test_web_preview.py` | 13 unit test untuk preset + verifier (ikut `dev_check.sh` dan CI). |
| Job CI `web-preview` | Memasang Godot + template, mengekspor, menyajikan dengan `python -m http.server` dan memeriksa pengiriman `index.wasm`/`index.pck` lewat HTTP, lalu mengunggah artefak `web-preview` (berisi `web/` + `README.txt`). |

### Cara halaman root memuat game (dan dua jebakan yang sudah diuji)

1. `fetch('./web/index.html')` → ambil satu baris `const GODOT_CONFIG = {...};` dari build. Halaman ini tidak perlu tahu isi preset ekspor.
2. Tag **statis** `<script src="./web/index.js">` di `<head>`. Engine menurunkan direktori asetnya dari `document.currentScript.src`; skrip yang disuntik dinamis membuat `currentScript` bernilai `null` sehingga engine mengejar `index.wasm` di root dan mendapat 404.
3. `config.executable = './web/index'` sebelum `new Engine(config)`. Tanpa ini engine tetap mencari `index.pck`/`index.wasm` relatif halaman (`/index.wasm`), bukan relatif `web/`. Keduanya dibuktikan dengan uji headless (`node tools/web_qa.mjs` lulus untuk `/` dan `/web/index.html`).

`web/` adalah **output yang sengaja di-commit** (lihat §0): jangan mengeditnya dengan tangan, dan jangan menganggap diff-nya sebagai perubahan sumber. Isinya disegarkan oleh job CI `web-preview`; `exports/` tetap di-`.gitignore`.

## 4. Pengaturan renderer

Godot hanya mendukung renderer **Compatibility (WebGL 2)** di platform web. `game/project.godot` sekarang menyatakan hal itu secara eksplisit:

```ini
renderer/rendering_method="mobile"
renderer/rendering_method.mobile="mobile"
renderer/rendering_method.web="gl_compatibility"
```

Artinya build Android tetap memakai renderer `mobile` (sesuai `PROJECT_DECISIONS.md`), sedangkan build web otomatis memakai Compatibility. `tools/project_doctor.py` memeriksa baris ini supaya tidak hilang tanpa sengaja.

## 5. Kontrol

| Aksi | Keyboard (desktop) | Sentuh (HP/tablet) |
|---|---|---|
| Bergerak | WASD | joystick ibu jari di sisi kiri |
| Membidik | tahan klik kanan + gerakkan mouse | geser di sisi kanan |
| Menembak | tahan klik kiri | tahan tombol FIRE |
| Ganti senjata | E atau tombol WEAPON | tombol WEAPON |
| Skill EMP | klik tombol EMP | tombol EMP |
| Pause / Resume | Esc | tombol PAUSE / RESUME |
| Reset run | R | tombol RETRY setelah defeat |

Tombol **HIDE UI** di shell hanya menyembunyikan lapisan HTML (chip/panel kontrol), bukan HUD di dalam game.

## 6. Batas yang harus diingat (jujur)

- **Renderer berbeda.** Web = Compatibility/WebGL 2; Android = Mobile renderer. Efek yang terlihat di web belum tentu identik (post-processing, bayangan, presisi emissive).
- **Performa tidak representatif.** FPS/frame time di browser adalah ukuran mesin Anda, bukan perangkat Android kelas menengah. Tabel profiling di `ANDROID_BASELINE.md` tetap wajib untuk gate E.
- **Single-thread.** Build ini tidak memakai `Thread` Godot; jangan menilai audio latency atau paralelisme dari preview.
- **Ukuran unduhan.** WebAssembly engine + pack biasanya beberapa puluh MB; muat pertama lambat, berikutnya ter-cache.
- **Bukan jalur distribusi.** Ini alat review. Publikasi tetap: Godot → GLB/PCK → Android (APK/AAB).
- **Belum diuji di browser sungguhan dari sandbox ini.** Yang sudah diuji: pembuatan preset, pengecekan shell, verifier build (dengan build tiruan), unit test, dan penyajian statis halaman landing. Job CI `web-preview` yang akan membuktikan ekspor + delivery nyata.

## 7. Troubleshooting

| Gejala | Sebab | Tindakan |
|---|---|---|
| Landing page: "build belum ada" | `web/` belum ada | Unduh artefak `web-preview` dari Actions, ekstrak ke root repo (harus jadi `web/index.html`), muat ulang |
| Layar hitam, progres macet | WebGL 2 tidak tersedia/terblokir | Gunakan Chrome/Firefox/Edge terbaru; cek `chrome://gpu`; hindari mode hemat data |
| Pesan "The following features ... are missing" | Browser tidak mendukung WebGL 2 atau canvas diblokir | Perbarui browser; pastikan bukan di iframe yang membatasi; jangan aktifkan thread support |
| `404` pada `index.wasm` / `index.pck` | Server dijalankan dari folder yang salah | Jalankan `python -m http.server 800` **dari root repo** (atau `--directory <web>`) |
| Export gagal: template tidak ditemukan | Export templates belum dipasang | `./scripts/install_godot.sh --with-templates` |
| `tools/web_preset.py check` gagal: threads | Preset memakai `variant/thread_support=true` | Jalankan `ensure` lagi (default single-thread), atau sajikan dengan header COOP/COEP dan pakai `--allow-threads` saat check |
| Ingin lihat error engine | Build rilis menyembunyikan detail | `./scripts/export_web_preview.sh --debug`, lalu cek konsol browser |

## 8. Jalur lanjutan ke Android

Setelah UI/UX dan kontrol dinilai sudah tepat di web:

1. Ikuti `ANDROID_BASELINE.md` (JDK/SDK, preset, APK, checklist perangkat, profiling).
2. Bandingkan renderer `mobile` vs `compatibility` di perangkat baseline sebelum mengunci pilihan di `PROJECT_DECISIONS.md` — preview web sudah memberi gambaran kasar bagaimana Compatibility terlihat.
3. Catat perbedaan perilaku yang ditemukan di web (mis. layout HUD di rasio layar tertentu) sebagai temuan yang harus diverifikasi ulang di perangkat.
