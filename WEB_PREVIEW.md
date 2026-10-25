# Exocomplict — WebAssembly Preview

> **Tujuan:** melihat dan menguji game di browser **tanpa memasang Godot, Android SDK, JDK, atau Blender** — cukup satu server statis: `python3 tools/serve_preview.py --port 800` dari root repo. Server preview ini menyimpan asset yang tidak berubah dan memvalidasinya dengan ETag.
>
> **Ini bukan perubahan target platform.** Android tetap target rilis; pipeline produksi tetap Godot + Blender di mesin dev. Web hanya dipakai sebagai jendela review UI/UX + gameplay supaya iterasi tidak menunggu instalasi toolchain.
>

>
>
> **Status preview saat ini:** payload `c7be6bfc` berasal dari source gabungan `35844894`; PCK berukuran 79,615,004 bytes (887 files) dan total `web/` sekitar 114 MiB. CI `40179327354` lulus static, 28/28 Godot test, export/payload audit, empat browser boot, initial-opening preload, interrupted-download recovery, serta strict Vanguard + audio-shell. Run lokal pada payload final juga lulus HERO + authored celebration, direct-DEPLOY ke theatre default, gesture/mute/handoff audio, `shot_pulse_rifle`, dan HUD mute/unmute. Palette serta batas listening/device evidence ada di [`AUDIO_SYSTEM.md`](AUDIO_SYSTEM.md); integrasi dunia ada di [`docs/WORLD_OPENING_INTEGRATION.md`](docs/WORLD_OPENING_INTEGRATION.md).
>
> **Status verifikasi (baseline lama di bawah ini; ukuran berikut bukan payload current):** seluruh wiring statis sudah diperiksa (`tools/web_preset.py check`, `tools/project_doctor.py` → 0 FAIL, 22 unit test). Ekspor Web nyata sudah berhasil di CI (run `38919299364`, job `web-preview` hijau). Hasil terukur:

| Bagian | Ukuran | Content-Type dari `python -m http.server` |
|---|---|---|
| `index.html` | 12,9 KB | `text/html` |
| `index.js` | 273 KB | `text/javascript` |
| `index.wasm` | 37,7 MB | `application/wasm` |
| `index.pck` | 588 KB | `application/octet-stream` |
| total `web/` | 39 MB | — |

Artefak CI `web-preview` (zip, isi `web/` + `README.txt`) ≈ **10 MB** karena wasm terkompresi baik. `web/` sudah berada di repo; halaman root memuat game langsung dari situ. Kalau `web/` tidak ada, halaman menampilkan kartu diagnostik (bukan layar kosong).

**Bukti browser (dijalankan di sandbox ini, Chromium headless + WebGL 2):** `node tools/web_qa.mjs` → **2/2 halaman PASS**, keduanya mem-boot Godot `4.7.2.stable.official.ed1daf0bf`, kanvas 1280×720, WebGL hidup, tanpa error halaman maupun permintaan gagal. Tangkapan layar: `exports/web-qa/root.png` dan `exports/web-qa/web-index-html.png`.

> **Catatan bandwidth:** opening mengunduh WASM 39,514,754 bytes + PCK 79,615,004 bytes = **119.1 MB** (tepatnya 119,129,758 bytes, sekitar **113.6 MiB**), belum termasuk loader/HTML. Setelah gesture pertama, shell juga mengambil empat WAV yang dipakai bersama (2,288,084 bytes); pulse gameplay sudah berada di PCK. `python -m http.server` tidak mengompresi payload besar; forwarded port atau Wi-Fi dapat membuat unduhan lama. DEPLOY memakai buffer PCK yang sama tanpa mengunduhnya lagi. Error dapat diulang dan watchdog tetap aktif bila tidak ada kemajuan. Jangan tutup/muat ulang saat byte masih bergerak. Diagnosis dan bukti: [`docs/WEB_LOADING_RECOVERY.md`](docs/WEB_LOADING_RECOVERY.md).

**Cache warm preview:** gunakan `python3 tools/serve_preview.py --port 800`, bukan server dengan `no-store`. Cold load pertama tetap mengambil seluruh payload. Pada reload berikutnya di origin dan profil browser yang sama, file yang tidak berubah dikirim sebagai **304 Not Modified** setelah revalidasi ETag; body WASM/PCK tidak diunduh ulang. Bila isi file berubah, ETag berubah dan browser mengambil versi baru. Opsi **Disable cache** di DevTools, profil/private window baru, atau clear cache memang memaksa cold load lagi.

---

## 0. Struktur: semuanya ada di dalam repo

Repo ini disusun seperti `xam-eth/Scary-Night` (game lain yang juga dipakai lewat browser): apa pun yang dibutuhkan untuk **membuka game di browser ada di repo**, bukan di balik langkah unduh manual.

| Peran | Scary-Night | Cyber-Strike (repo ini) |
|---|---|---|
| Halaman yang dibuka pemain | `index.html` di root, meng-import game (`<script type="module" src="./src/main.js">`) | `index.html` di root, **meng-import build Godot langsung** (bukan iframe): konfigurasi dibaca dari `./web/index.html`; opening memakai `Engine.init()` + `preloadFile()`, lalu DEPLOY memakai `Engine.start()` dengan pack yang sama |
| Payload game | `src/` (JS/Three.js, di-commit) | `web/` (`index.js`, `index.wasm`, `index.pck`, di-commit oleh job CI `web-preview`) |
| Engine | `Godot_v4.6.2-stable_linux.x86_64.zip` di root | `scripts/install_godot.sh` mengunduh 4.7.2 sesuai OS |
| Template ekspor web | `web_nothreads_release.zip`, `web_nothreads_debug.zip` di root | `engine/web_templates/*.zip` (di-commit; lihat `engine/README.md`) |
| Aset mentah (model) | GLB di root + `assets/` | `game/` (project Godot) + GLB di root |
| QA browser | `tools/*.mjs` + puppeteer-core + `@sparticuz/chromium` | `tools/web_qa.mjs` + puppeteer-core + `@sparticuz/chromium`, dijalankan di CI (dan bisa lokal) |
| Jalur Android | PWA + TWA/Bubblewrap (`android/twa-manifest.json`, `.well-known/assetlinks.json`) | ekspor Android Godot (`ANDROID_BASELINE.md`, gate E) |

Konsekuensinya: `git pull` lalu `python3 tools/serve_preview.py --port 800` **langsung memainkan game** — tidak perlu membuka Actions untuk mengunduh artefak.

## 1. Alur singkat (pemakaian harian)

```bash
git pull                                        # web/ sudah ikut di dalam repo
python3 tools/serve_preview.py --port 800      # dari root repo

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
# putuskan WASM/PCK, wajibkan error + retry → gameplay theatre terpilih, dan ukur progres pada 100 Mbps
node tools/web_loading_qa.mjs --throughput-mbps 100 --json
node tools/web_qa.mjs --play 80 --play-shot-every 25   # main sungguhan + foto berseri
node tools/web_qa.mjs --encounter-prep --explore-wait 8000 --viewport 390x844
# verifikasi Explore aman + B menuju countdown; TIDAK mengklaim Defense
node tools/web_qa.mjs --encounter --explore-wait 8000 --encounter-timeout 600 --viewport 844x390
node tools/web_qa.mjs --page / --viewport 1280x720 --encounter --select-vanguard
# gate lebih ketat: tunggu log Defense nyata, lalu ambil frame Defense

# Dengan server root port 800 masih berjalan, uji sentuhan KO sampai Results,
# Return→Armory→replay di satu profil browser (membutuhkan BP positif sungguhan):
node tools/qa_combat_loop.mjs --url=http://127.0.0.1:800/
# ukur rect FISIK di WebGL dan sentuh pita tombol baru di luar hitbox lama;
# F8 hanya membekukan tembakan sungguhan, bukan menyuntikkan peluru:
node tools/qa_touch_targets.mjs --url=http://127.0.0.1:800/
# gate lebih sulit: dua KO + bonus clear → unlock/equip Nova → tembak saat replay
node tools/qa_wave_clear.mjs --url=http://127.0.0.1:800/
# gate opsional: Nova benar-benar memberi splash damage + capture frame compositor
node tools/qa_wave_clear.mjs --effects --url=http://127.0.0.1:800/
# dokumentasikan gerak rig Blender, ADS, FIRE dan run+FIRE di Explore (bukan sign-off visual)
node tools/qa_motion_touch.mjs --url=http://127.0.0.1:800/
# gate terpisah: Runner sungguhan mengalahkan player; death tetap terbuka sebelum Results
node tools/qa_death_touch.mjs --url=http://127.0.0.1:800/
```

`tools/web_qa.mjs` membuka halaman sungguhan di Chromium headless dan gagal (exit 1) bila engine tidak boot, tidak ada WebGL 2, kanvas tetap 300×150, ada permintaan 4xx/5xx, atau kartu error tampil. Tangkapan layarnya ditulis ke `exports/web-qa/`. Gate boot ini sama dengan boot dasar pada job CI `web-preview`; opsi `--encounter-prep` dan `--encounter` tidak berjalan otomatis di sana, sedangkan CI menjalankan `--select-vanguard` sebagai gate kontrak terpisah. Pada root landscape, `--select-vanguard` mengklik kartu Vanguard di shell dan baru PASS bila adapter menerima `qa_world`, gameplay tercapai, dan log runtime `VanguardStation:` benar-benar muncul; klik DOM atau boot dunia default saja tidak dianggap bukti. Raw engine journey tetap memakai pin WORLD terukur. Dalam SwiftShader tanpa GPU, countdown lima detik Godot bisa membutuhkan >100 detik waktu nyata. `--encounter` baru PASS bila log `Defense started` dan screenshot Defense sungguh ada; setelah timeout ia FAIL, bukan melabeli frame Preparing sebagai Defense. Tes Results terpisah `tools/qa_combat_loop.mjs` memerlukan server root yang sudah hidup dan **tidak berjalan otomatis** pada gate boot CI; skrip sengaja FAIL bila KO/+BP nyata tidak tercapai. Ia menulis frame sementara ke `exports/qa-combat-loop/`. `tools/qa_touch_targets.mjs` membuka empat viewport asli secara terpisah, membaca `get_global_rect()` fisik dengan opt-in `?qa_touch`, lalu menguji FIRE/ADS/EMP/Pause/Armory lewat input sentuh **di luar rect sebelum revisi**; screenshot sementara tersimpan di `exports/qa-touch-targets/`, sedangkan perbandingan yang diinspeksi berada di `exports/qa-evidence/qa-frames/touch-hitboxes-*`. Tes lanjutan `tools/qa_wave_clear.mjs` sengaja FAIL jika <120 BP pada Results, atau unlock Nova tidak sungguh dipicu di Armory; frame sementara ada di `exports/qa-wave-clear/`. `tools/qa_motion_touch.mjs` memakai opt-in `?qa_camera`, memotret Explore/ADS/FIRE/run+FIRE di `exports/qa-motion-touch/` dan memerlukan trace `aim=true`, `fire=true`, `clip=aim_run`; ia **tidak** mengklaim mutu animasi final. Opsi `--record` membuat `exports/qa-motion-touch/hero-motion.webm` sebagai diagnostik lokal yang di-ignore. Dalam probe SwiftShader ini hanya **23 frame selama 63,7 detik (~0,36 fps)** meski stream meminta 16 fps: video itu berguna untuk pose-per-pose, **bukan** penilaian timing animasi, performa mobile, atau penerimaan visual. `tools/qa_wave_clear.mjs --effects` menambah gate opsional: setelah unlock, tembakan Nova harus benar-benar memberi damage, bukan hanya mengurangi amunisi. Pada payload `61571d9` gate ini **PASS**: `ArenaFloor damaged=2 radius=4.0`, yakni splash mengenai dua target, **bukan** direct hit; capture awal tidak menangkap cincin. Pada payload `9e82cb5`, run berikutnya mencapai +120 BP → equip Nova → replay dan `ArenaFloor damaged=1 radius=4.0`, dengan **62 frame compositor**; `exports/qa-evidence/qa-frames/nova-shockfront-stage14.png` memperlihatkan cincin amber. Koreksi geometrinya pada payload stage 18 `41113be` juga lulus alur/damage Nova dengan 64 frame compositor; `exports/qa-evidence/qa-frames/nova-shockfront-stage18.png` menunjukkan glint kecil dan etch yang lebih tertahan, **bukan** persetujuan efek AAA atau representasi FPS fisik. `tools/qa_death_touch.mjs` membiarkan Runner menyerang tanpa menyuntik damage, memeriksa clip dan Head bone sebelum Results, dan merekam frame compositor selama reveal; pada payload `d45345c` gate alur/trace PASS tetapi hero terlihat tegak. Payload stage 15 `7ea6cc6` menahan pose akhir enam frame render: **19 frame compositor** memperlihatkan berdiri → rebah → terbaring sebelum Results (`exports/qa-evidence/qa-frames/death-*-stage15.png`). Ini bukti visual death di WebGL, bukan pengesahan kelancaran timing pada ponsel fisik. Semua folder `exports/` di-ignore, pindahkan bukti yang sah ke `qa-evidence/` bila perlu. Urutan frame Chromium software-rendered perlu dibaca bersama log peristiwa, bukan dari nama file saja.

**Mode `--play <detik>`** menguji input gerak/tembak di mode saat ini (**Explore aman**, kecuali `--encounter` juga diberikan). Klik kanvas sekaligus menjadi gesture yang dibutuhkan browser sebelum audio boleh berbunyi; kemudian skrip berjalan, berbelok, berganti senjata, dan menembak dengan event input sungguhan sambil menulis rangkaian foto `<halaman>-<viewport>-play-<t>s.png`. Ia juga memeriksa baris log `Audio:` — termasuk `Audio: first voice played (...)`, bukti audio benar-benar terpakai di browser, bukan sekadar ter-import. Di tengah sesi play, gate menekan tombol `M` dan memastikan baris `Audio: muted` muncul, jadi jalur HUD → audio ikut terbukti. Pemeriksaan itu sengaja eksak: baris boot berakhir `muted=no`, sehingga pencocokan longgar akan lulus tanpa tombolnya benar-benar sampai.

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
python3 tools/serve_preview.py --port 800
```

`scripts/export_web_preview.sh` melakukan lima langkah dan berhenti kalau ada yang gagal:

1. `tools/web_preset.py ensure` — menulis preset **Web** ke `game/export_presets.cfg` (git-ignored). Preset Android/desktop yang sudah ada di file itu tidak diubah.
2. `tools/web_preset.py check` — memvalidasi preset + custom HTML shell (placeholder lengkap, `<canvas>`, `<canvas>` bootstrap).
3. Import headless (`godot --headless --editor --path game --quit`).
4. `godot --headless --path game --export-release Web web/index.html`.
5. `tools/web_loader_patch.py web/index.js` meneruskan kegagalan WASM/module/filesystem ke rejection `startGame()`; lalu `tools/verify_web_build.py web` memastikan `index.html`, `index.js`, `index.wasm`, `index.pck` ada, magic bytes benar (`\0asm`, `GDPC`), placeholder sudah diganti, dan custom shell benar-benar terpakai.

Opsi: `--debug` (build debug, error lebih jelas, ukuran lebih besar), `--output <dir>`, `--no-import`. Override `WEB_EXPORT_PRESET` atau `GODOT_BIN` bila perlu.

## 3. Yang dibangun di dalam

| Berkas | Peran |
|---|---|
| `index.html` + `ui/` (root repo) | **Player shell**: opening → HERO/operative → hub/theatre → launch → gameplay theatre terpilih. Pilihan `qa_world`/`weapon` divalidasi adapter engine; root tidak berhenti di stage WORLD. Memuat `web/` tanpa CDN/build step, memakai font/art lokal, dan menampilkan kegagalan payload/WebGL yang dapat dibaca beserta retry. Portrait mendapat layar instruksi rotasi; produk saat ini landscape-only. |
| `tools/web_qa.mjs` | QA browser headless: menyajikan repo, membuka `/` dan `/web/index.html`, memeriksa banner engine, WebGL 2, ukuran kanvas, 4xx/5xx, kartu error; menulis tangkapan layar dan laporan `--json`. Mode root `--journey --select-vanguard` mengklik kartu Vanguard dan mewajibkan hand-off serta log build dunia yang dipilih; raw engine mempertahankan jalur WORLD terukur. `--play <detik>` menambah input/SFX/mute; `--audio-shell` menambah real-gesture theme, shared mute, dan DEPLOY handoff. Keduanya bukan bukti satu run penuh atau listening test. |
| `tools/web_loading_qa.mjs` | Opening + negative/recovery gate: membuktikan satu request WASM dan satu PCK sebelum **Masuk**, tidak ada gameplay di belakang opening, dan DEPLOY tanpa PCK kedua. Kemudian memutus tiap aset pada direct DEPLOY, mewajibkan error/retry, dan kembali ke gameplay theatre terpilih. Dengan `--throughput-mbps 100` juga mewajibkan `fileSizes` nonzero, progres byte antara, dan persen yang tidak mundur. |
| `tools/web_loader_patch.py` | Patch ekspor Godot 4.7.2 yang idempoten agar kegagalan response WASM, module initialization, dan filesystem menolak Promise `init()`/`startGame()`; dipanggil otomatis oleh pipeline ekspor. |
| `game/web_shell/index.html` | **Custom Godot HTML shell** (dipakai lewat `html/custom_html_shell`). Menyediakan boot overlay bertema (progress bar + persentase) dan error yang dapat dibaca, lalu menghilang tanpa browser chrome di atas HUD gameplay. Placeholder `$GODOT_*` resmi dipertahankan. |
| `tools/web_preset.py` | `ensure` / `check` / `show` untuk preset Web (thread support, custom shell, resize policy, PWA off). |
| `scripts/export_web_preview.sh` | Pipeline ekspor web 5 langkah + verifikasi. |
| `tools/verify_web_build.py` | Verifikasi hasil ekspor tanpa browser (magic bytes, placeholder, ukuran). |
| `tools/tests/test_web_preview.py` | 13 unit test untuk preset + verifier (ikut `dev_check.sh` dan CI). |
| Job CI `web-preview` | Memasang Godot + template, mengekspor, menyajikan dengan `python -m http.server` dan memeriksa pengiriman `index.wasm`/`index.pck` lewat HTTP, lalu mengunggah artefak `web-preview` (berisi `web/` + `README.txt`). |

### Cara halaman root memuat game (dan dua jebakan yang sudah diuji)

1. `fetch('./web/index.html')` → ambil satu baris `const GODOT_CONFIG = {...};` dari build. Halaman ini tidak perlu tahu isi preset ekspor.
2. Tag **statis** `<script src="./web/index.js">` di `<head>`. Engine menurunkan direktori asetnya dari `document.currentScript.src`; skrip yang disuntik dinamis membuat `currentScript` bernilai `null` sehingga engine mengejar `index.wasm` di root dan mendapat 404.
3. `config.executable = './web/index'` sebelum `new Engine(config)`. Tanpa ini engine tetap mencari `index.pck`/`index.wasm` relatif halaman (`/index.wasm`), bukan relatif `web/`. Keduanya dibuktikan dengan uji headless (`node tools/web_qa.mjs` lulus untuk `/` dan `/web/index.html`).
4. Saat opening, `Engine.init(executable)` dan `Engine.preloadFile(pack, pack)` menyiapkan runtime + seluruh world pack tanpa memulai scene gameplay. **Masuk** menunggu keduanya.
5. Saat DEPLOY, `Engine.start({args: ['--main-pack', pack]})` memakai buffer tersebut. `startGame()` sengaja tidak dipanggil lagi karena akan mengulangi `preloadFile(pack)`.

`web/` adalah **output yang sengaja di-commit** (lihat §0): jangan mengeditnya dengan tangan, dan jangan menganggap diff-nya sebagai perubahan sumber. Isinya disegarkan oleh job CI `web-preview`; satu-satunya transformasi pasca-ekspor adalah `tools/web_loader_patch.py`, yang juga dijalankan otomatis oleh pipeline. `exports/` tetap di-`.gitignore`.

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
| Menembak | tahan klik kiri atau tahan ikon FIRE | tahan ikon FIRE (kanan bawah, 180×180 px pada layout acuan landscape) |
| Ganti senjata / Armory | E atau U | ikon senjata/rotasi di samping readout amunisi |
| Skill EMP | tombol F | ikon petir/pulse ungu di kanan bawah |
| Mulai Defense | B setelah menjelajah | tombol START DEFENSE (countdown sebelum wave) |
| Pause / Resume | Esc | tombol PAUSE / RESUME |
| Retry / kembali ke Explore | R untuk retry, setelah hasil pilih kembali | tombol RETRY DEFENSE atau EXPLORE pada hasil |
| Mute / unmute | M atau kontrol SOUND | kontrol SOUND pada HUD |

### Audio pada shell dan gameplay

- Browser tidak mengizinkan autoplay sebelum interaksi. Klik/tap atau keyboard yang sah membuka audio; ikon speaker di dock dapat mengaktifkan/mute shell secara eksplisit.
- Opening/HERO/dashboard memakai tema **Frontier Signal**. DEPLOY memainkan stinger, menghentikan loop HTML, lalu menyerahkan musik ke `AudioDirector`; tidak ada dua background loop yang bersaing.
- Preferensi `aegis.prefs.muted` dibawa ke Godot. Perubahan dari HUD/M juga ditulis kembali ke preferensi tersebut untuk sesi shell berikutnya.
- Detail aset, generator, state Explore/Preparing/Defense/Results, dan perintah QA ada di [`AUDIO_SYSTEM.md`](AUDIO_SYSTEM.md). Pemeriksaan otomatis bukan penilaian listening atau kualitas speaker/headphone.

**Tidak ada wave otomatis saat boot**. Menembak training target di Explore tidak memulai Defense. DEPLOY pada root shell langsung memasuki Explore aman di theatre yang dipilih; raw engine journey dapat tetap melewati WORLD/LAUNCH. Layout produk saat ini **landscape-only** (844×390 dan 667×375 dalam QA); portrait menampilkan instruksi rotasi, bukan susunan HUD alternatif. Raw shell tidak lagi menambahkan lapisan HTML di atas HUD gameplay.

## 6. Batas yang harus diingat (jujur)

- **Renderer berbeda.** Web = Compatibility/WebGL 2; Android = Mobile renderer. Efek yang terlihat di web belum tentu identik (post-processing, bayangan, presisi emissive).
- **Performa tidak representatif.** FPS/frame time di browser adalah ukuran mesin Anda, bukan perangkat Android kelas menengah. Tabel profiling di `ANDROID_BASELINE.md` tetap wajib untuk gate E.
- **Single-thread.** Build ini tidak memakai `Thread` Godot; jangan menilai audio latency atau paralelisme dari preview.
- **Ukuran unduhan.** WebAssembly engine + pack biasanya beberapa puluh MB; muat pertama lambat, berikutnya ter-cache.
- **Bukan jalur distribusi.** Ini alat review. Publikasi tetap: Godot → GLB/PCK → Android (APK/AAB).
- **Payload integrasi `cec0fdd`:** laporan lokal `exports/integration-audit/` membuktikan seleksi/build Vanguard, Neon Explore → Preparing → Defense dengan tembakan/audio/mute, pause/settings, dan enam frame shell pada dua ukuran landscape. Pass Neon tidak membuktikan KO, reward, Results, atau satu run penuh; Android/perangkat nyata tetap UNKNOWN.
- **Bukti browser lama, terbatas per payload.** Payload `abec6e5` membuktikan KO +10 BP dan satu clear +120 BP; payload `318ef35` **dan** `b499bb5` masing-masing membuktikan clear +120 yang dilanjutkan unlock/equip Nova serta satu shot saat replay. `pre-tracer-fix-held.png` vs `08-portrait-fire-held.png` memperlihatkan garis tembakan di dekat hero lebih ramping, **bukan** sign-off VFX. Variasi spawn sebelum koreksi menghasilkan +0/+10; 2/2 pass pada flank baru bukan statistik reliabilitas global. Bukti kualitas motion/VFX dan kenyamanan fisik masih terbatas; reaktor dan area floor terlalu biru di banyak frame. Android nyata tetap terpisah.

## 7. Troubleshooting

| Gejala | Sebab | Tindakan |
|---|---|---|
| Landing page: "build belum ada" | `web/` belum ada | Unduh artefak `web-preview` dari Actions, ekstrak ke root repo (harus jadi `web/index.html`), muat ulang |
| Loading lama tetapi byte/persen bergerak | Opening saat ini 119.1 MB dan `http.server` tidak mengompresi | Biarkan tab aktif sampai 100%; jangan reload. Lewat forwarded port/Wi-Fi waktunya bergantung pada koneksi nyata |
| Opening/dashboard belum berbunyi | Browser menahan autoplay sebelum gesture | Klik/tap atau gunakan keyboard, lalu cek ikon speaker; jangan menilai audio sebelum interaksi yang sah |
| `Koneksi dunia terputus` atau server mencatat BrokenPipe | Browser/proxy menutup response sebelum aset selesai | Tekan **Coba lagi**, periksa koneksi, dan catat aset yang gagal di Network. Favicon 404 bukan penyebab boot |
| `Unduhan dunia berhenti` / `Dunia terlalu lama disiapkan` | Tidak ada kemajuan selama 3 menit, atau aset lengkap tetapi engine belum mulai | Tekan **Coba lagi**; bila berulang simpan judul/detail layar serta Console/Network untuk membedakan delivery dari engine start |
| Loading tanpa persen pada checkout lama | Path `./web/index` tidak memiliki entri `fileSizes`, sehingga callback ber-`total=0` | Pull perbaikan dan buka halaman `/` baru; regression gate membuktikan total 135,101,522 bytes |
| Layar hitam, progres macet | WebGL 2 tidak tersedia/terblokir | Gunakan Chrome/Firefox/Edge terbaru; cek `chrome://gpu`; hindari mode hemat data |
| Pesan "The following features ... are missing" | Browser tidak mendukung WebGL 2 atau canvas diblokir | Perbarui browser; pastikan bukan di iframe yang membatasi; jangan aktifkan thread support |
| `404` pada `index.wasm` / `index.pck` | Server dijalankan dari folder yang salah | Jalankan `python3 tools/serve_preview.py --port 800` **dari root repo** |
| Payload besar terunduh lagi pada setiap reload | Server mengirim `no-store`, DevTools **Disable cache** aktif, atau origin/profil browser berubah | Pakai `tools/serve_preview.py`, matikan **Disable cache**, dan buka URL preview yang sama; origin menjawab `304` dan transfer body besar harus hilang (Chromium dapat menampilkan cached `200` setelah revalidasi) |
| Export gagal: template tidak ditemukan | Export templates belum dipasang | `./scripts/install_godot.sh --with-templates` |
| `tools/web_preset.py check` gagal: threads | Preset memakai `variant/thread_support=true` | Jalankan `ensure` lagi (default single-thread), atau sajikan dengan header COOP/COEP dan pakai `--allow-threads` saat check |
| Ingin lihat error engine | Build rilis menyembunyikan detail | `./scripts/export_web_preview.sh --debug`, lalu cek konsol browser |

## 8. Jalur lanjutan ke Android

Setelah UI/UX dan kontrol dinilai sudah tepat di web:

1. Ikuti `ANDROID_BASELINE.md` (JDK/SDK, preset, APK, checklist perangkat, profiling).
2. Bandingkan renderer `mobile` vs `compatibility` di perangkat baseline sebelum mengunci pilihan di `PROJECT_DECISIONS.md` — preview web sudah memberi gambaran kasar bagaimana Compatibility terlihat.
3. Catat perbedaan perilaku yang ditemukan di web (mis. layout HUD di rasio layar tertentu) sebagai temuan yang harus diverifikasi ulang di perangkat.
