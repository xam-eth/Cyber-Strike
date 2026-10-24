# AEGIS — Spesifikasi redesain UI/UX

**Tanggal spesifikasi:** 17 Oktober 2026
**Status (koreksi 18 Oktober 2026):** persetujuan AEGIS adalah **historis**; pengguna menolak hasil visual, animasi, pacing, dan keterbacaan UI build sekarang. Arah redesign **belum disepakati ulang**.
**Branch:** `arena/5257bce8-cyber-strike` · **PR:** #1 (open, jangan di-merge)
**Audit ulang dan rujukan game rilis:** [`DECISIONS.md`](DECISIONS.md)

Dokumen ini mencatat arah token/layout AEGIS yang **pernah** disetujui, bukan
spesifikasi kualitas visual final. Angka pada board adalah target desain waktu
itu, **bukan** bukti animasi, pencahayaan, kontrol, atau pacing telah benar.
Tabel §13 adalah riwayat implementasi UI dan harus dibaca bersama audit ulang;
CI 16/16 dan QA boot/menu Web 3/3 hanya meloloskan interaksi yang diuji, bukan
persetujuan visual atau QA perangkat nyata.

---

## 0. Ringkasan

Audit **HUD sebelum redesain** (bukan keadaan build terbaru) menemukan:

| Masalah | Bukti pada build sebelum redesain | Dampak |
|---|---|---|
| Tiga kartu besar menutupi seperempat layar | `VITALS`, `WAVE`, `RUN DATA` masing-masing 104px tinggi | Dunia dan target tertutup; tidak ada ruang untuk ammo |
| Tidak ada ammo / slot senjata | Kartu senjata hanya berupa tombol teks di kanan bawah | Pemain tidak tahu sisa peluru |
| Warna aksen campur | Cyan, teal, amber, merah dipakai untuk hal yang tidak konsisten | Tidak ada hierarki; semua terasa "penting" |
| Tipografi tanpa skala | Satu ukuran untuk label dan data; angka proporsional | Angka bergeser saat berubah; label sulit dipindai |
| Tidak ada menu settings / HUD editor | Hanya pause teks dan panel hasil | Tidak ada jalur untuk mengubah sensitivitas, HUD, atau a11y |
| Target sentuh tidak seragam | Pause/SOUND berupa teks; FIRE 96px, AIM 42px | Salah tap di layar kecil; tidak ada jarak minimum |

Arah yang diusulkan — **AEGIS Industrial** — mempertahankan bahasa sci-fi yang
sudah ada di dunia, tetapi merapikannya menjadi sistem:

* panel gelap **92%** dengan hairline 1px dan **corner bracket**, bukan kotak penuh;
* **satu aksen amber** untuk aksi/fokus, mint untuk health, cyan untuk armor,
  merah untuk damage, violet untuk EMP;
* **Chakra Petch** untuk display, **Rajdhani** untuk UI, **JetBrains Mono** untuk
  semua angka (tabular);
* **Phosphor Icons** (MIT) regular + fill;
* target sentuh **44px adalah lantai**, FIRE 92px;
* maksimal **6 kontrol aktif** di layar; sisanya masuk pause/settings;
* ini juga menambah dua layar yang belum ada: **Settings** dan **HUD Editor**.

---

## 1. Keputusan visual (historis; validasi ulang diperlukan)

1. **Arah visual A — Aegis Industrial**, aksen amber `#FFB020`.
2. **Tipografi:** Chakra Petch / Rajdhani / JetBrains Mono (OFL, ikut di repo).
   Rajdhani menggantikan Barlow: keduanya condensed dan bersudut, dan baris
   uppercase ala lobby terbaca lebih baik di Rajdhani pada ukuran yang sama.
3. **Ikon:** Phosphor (MIT), regular untuk default, fill untuk state aktif.
4. **Mobile:** landscape sebagai mode utama, portrait tetap didukung.
5. **HUD editor** dikerjakan pada milestone M4, bukan ditunda ke v2.

Kelima keputusan **pernah** disetujui untuk fase AEGIS. Masukan terbaru
menolak hasilnya; jangan perlakukan persetujuan ini sebagai mandat melanjutkan
polish atau mengunci palet redesign baru. Baca audit ulang sebelum koding visual.

---

## 2. Riset: angka yang dijadikan aturan

### 2.1 Ergonomi layar sentuh

| Temuan | Angka | Konsekuensi desain |
|---|---|---|
| Target minimum iOS | 44×44 pt | Semua tombol ≥44px; ikon 20px di dalam 44px |
| Android | 48×48 dp + jarak 8dp | FIRE 92, AIM/EMP 56, SWAP 48, PAUSE 44 |
| NN/g | ~1cm fisik | di 390px, 1cm ≈ 44px; jangan pernah di bawahnya |
| WCAG 2.5.5 / 2.5.8 | 44px / 24px | 24px hanya untuk mouse, bukan game ini |
| Akurasi tap | 7mm tengah → 9mm tepi → **12mm sudut** | Sudut atas hanya untuk pause/status, bukan aksi |
| Zona jempol | sepertiga bawah | Semua aksi tempur di bawah; info di atas |
| Jumlah kontrol | **5–6 aktif** (Epic, Fortnite mobile) | FIRE, AIM, EMP, SWAP, pause + joystick |
| Joystick | tetap (fixed) membangun muscle memory | Joystick kiri fixed; tidak muncul di mana-mana |
| Jepit/jarak | 8pt minimum, 12pt di dekat tepi | Gap 12px di semua klaster |

> Sumber: Apple HIG, Material, NN/g "Touch target size", WCAG 2.5.5/2.5.8,
> Epic Games "Designing for Mobile in Fortnite" (lihat §16).

### 2.2 HUD shooter komersial

* **COD Mobile / PUBG / Free Fire**: HUD dapat diatur (drag, resize, opacity
  30–80%), punya preset *Simplified/Advanced*, dan tombol fire di posisi jempol
  beristirahat. Ini yang membuat HUD editor masuk lingkup, bukan kemewahan.
* **Fortnite mobile**: maks 5–6 kontrol aktif; info (timer, skor, objective) di
  **atas-tengah** atau bisa dilipat; teks/ikon minimum 44pt; kontras tinggi agar
  terbaca di luar ruangan.
* **Pola konsisten**: health kiri-atas, objective atas-tengah, sistem kanan-atas;
  aksi kanan-bawah. Pemain tidak perlu mencari.

### 2.3 Tipografi

* Ambang keterbacaan ±**0.3° sudut visual** → 14–16px di handheld, 20–22px di TV.
  Game ini render di kanvas 1280×720 yang diperbesar; karena itu ukuran ditulis
  dalam **px logis 720p** dan lantai fisik 11px dipertahankan (`MIN_PHYSICAL_FONT_PX`).
* Rasio skala **1.25** untuk HUD padat, **1.333** untuk menu.
* Token peran, bukan ukuran ad-hoc: `display-xl`, `display-l`, `heading`,
  `body`, `label`, `mono-xl`, `mono-m`.
* **Angka tabular wajib** untuk ammo, skor, timer; tanpa itu digit menggeser
  layout setiap frame. JetBrains Mono dipakai justru karena ini.
* Eurostile adalah bahasa genre sci-fi HUD; Chakra Petch adalah pengganti gratis
  yang mempertahankan sudut dan proporsi lebar tanpa biaya lisensi.

### 2.4 Warna dan kontras

* Basis gelap, satu aksen, token semantik; hindari `#000000`/`#FFFFFF` murni.
* Aksen dijaga ketat: amber **hanya** untuk aksi, fokus, dan angka kunci.
* Status tidak boleh dibedakan hanya lewat warna: danger memakai ikon + border,
  health memakai panjang bar + angka.

Kontras terukur (WCAG 2.1, dihitung dari nilai token, bukan dikira-kira):

| Pasangan | Rasio | Status |
|---|---:|---|
| `ink` #EDF5FB di `panel` #0B131B | **17.2:1** | AAA |
| `ink-2` #A9BCCB di panel | **9.7:1** | AAA |
| `ink-3` #7C94A6 di panel | **6.0:1** | AA |
| `accent` #FFB020 di panel | **10.4:1** | AAA |
| `accent-ink` #171005 di atas accent | **10.3:1** | AAA |
| `ok` / `info` / `danger` / `ability` di panel | 10.9 / 9.9 / 6.1 / 8.2 | AA+ |
| Panel 92% di atas 3 crop dunia nyata (langit / tanah / mid-tone) | **14.9 / 14.6 / 15.0:1** | AAA |
| `ink-3` di panel yang sama | 5.18 / 5.10 / 5.23 | AA |

Catatan penting: **teks putih di atas fill merah hanya 2.8:1** — karena itu
tombol danger selalu *outlined*, tidak pernah filled.

### 2.5 Menu

* Kedalaman maksimum **3 level**; lebih dari itu pemain kehilangan orientasi.
* **Resume** selalu item pertama dan sudah terpilih saat pause.
* Quit di paling bawah, butuh konfirmasi kedua.
* Transisi 120ms (pause), 200–240ms (results); tidak ada >300ms.
* **ESC** menutup submenu lalu menu, tidak pernah keluar game.
* Settings dari main menu dan pause adalah **layar yang sama**.
* Slider selalu menampilkan angka; toggle selalu punya label status.

### 2.6 Ikon

| Set | Ukuran | Lisensi | Catatan |
|---|---:|---|---|
| **Phosphor** | ~1.500 × 6 bobot | **MIT** | Punya **Fill** untuk state aktif — dipilih |
| Lucide | ~1.700 | ISC | Konsisten, tapi tanpa fill |
| Material Symbols | ~3.800 | Apache 2.0 | Variabel, terasa "Google" |
| Tabler | ~5.000 | MIT | Strokenya lebih ringan |

Semua komersial-aman tanpa atribusi wajib; lisensi tetap disertakan di
`game/assets/ui/icons/LICENSE-Phosphor.txt`.

---

## 3. Arah visual

### A. Aegis Industrial — **dipilih**

Panel gelap biru-arang, hairline 1px, bracket di empat sudut, sudut tajam
(radius 0–2px), satu aksen amber, angka mono, label uppercase bertracking lebar.
Terasa seperti perangkat keras militer, bukan neon arcade. Kontras tinggi di atas
dunia pastel, dan tetap terbaca saat layar kecil.

Alasan menang: paling dekat dengan dunia SciFi Bay yang sudah ada, paling murah
diimplementasikan (StyleBoxFlat + `_draw`), dan paling tahan terhadap latar
terang (dibuktikan di board 01 §04).

### B. Neon Arcade — ditolak

Fill cerah, radius 8px, glow, gradien. Bertabrakan dengan dunia low-poly pastel;
glow di belakang angka menurunkan kontras; sulit dibuat konsisten di 30+ widget.

### C. Swiss Minimal (ala Destiny) — ditolak untuk HUD

Tipografi putih langsung di atas dunia, hampir tanpa panel. Elegan, tetapi di
dunia terang dan ramai ini angka ammo akan hilang. Hierarki tipografinya tetap
diadopsi: satu display besar per layar, sisanya tenang.

---

## 4. Design tokens

### 4.1 Warna

| Token | Nilai | Peran |
|---|---|---|
| `void` | `#05080C` | kanvas, letterbox |
| `panel` | `#0B131B` @ 92% | kartu HUD, sheet |
| `panel-2` | `#111C26` | permukaan naik (selected, hover) |
| `panel-3` | `#16232E` | pressed / inset |
| `line` | `#27384A` | hairline 1px |
| `line-hi` | `#4E6A7E` | border fokus / hover |
| `ink` | `#EDF5FB` | teks utama |
| `ink-2` | `#A9BCCB` | teks sekunder |
| `ink-3` | `#7C94A6` | caption (≥5:1 di panel) |
| `accent` | `#FFB020` | aksi, fokus, angka kunci |
| `accent-ink` | `#171005` | teks di atas accent (10.3:1) |
| `ok` | `#37E08C` | health, ready |
| `info` | `#54C8FF` | armor |
| `danger` | `#FF5A5A` | damage, quit, low ammo |
| `ability` | `#B79CFF` | EMP |

Aturan: **tidak ada warna lain**. Cyan tidak dipakai untuk tombol; amber tidak
dipakai untuk health.

### 4.2 Tipografi

| Peran | Font | Ukuran / line | Tracking | Pakai |
|---|---|---|---|---|
| Display XL | Chakra Petch 600 | 40 / 44 | +2% | judul hasil |
| Display L | Chakra Petch 600 | 28 / 32 | +2% | judul menu |
| Heading | Chakra Petch 600 | 18 / 22 | +1% | judul kartu |
| Title | Rajdhani 600 | 15 / 20 | +1% | nama senjata |
| Body | Rajdhani 400 | 14 / 20 | 0 | deskripsi |
| Label | Rajdhani 500 | 11 / 14 | **+12%** | label uppercase |
| Caption | Rajdhani 400 | 11 / 14 | +2% | catatan |
| Mono XL | JetBrains Mono 500 | 34 / 34 | 0 | ammo |
| Mono L | JetBrains Mono 500 | 20 / 22 | 0 | timer besar |
| Mono M | JetBrains Mono 500 | 13 / 16 | 0 | skor, KOs |

Lantai fisik: **11px** setelah skala kanvas (sudah ada di
`touch_controls.gd`). Tidak boleh ada font di bawah itu.

### 4.3 Spacing, bentuk, elevasi

* Spacing: kelipatan **4** — `2, 4, 8, 12, 16, 24, 32, 48`.
* Padding panel **12**; gap antar elemen **8**; jarak antar target sentuh **12**;
  inset layar **20** (desktop) / **12** (HP).
* Radius **0–2px**. Bracket sudut **10px**, stroke **1px**. Accent edge **2px**.
* Elevasi bukan shadow: `scrim` (0.62–0.74) + panel 92–96%. Tidak ada drop shadow.

### 4.4 Motion

| Kejadian | Durasi | Easing |
|---|---:|---|
| Hover / state | 120ms | ease-out |
| Tekan | 90ms | ease-out |
| Buka pause | 120ms | ease-out |
| Results | 240ms | ease-out |
| Toast | 120ms masuk / 180ms keluar | ease-out |
| Hit marker | 160ms | linear |

Tidak ada bounce, tidak ada overshoot kecuali kill-confirm (scale 1.06, 120ms).
Semua durasi berhenti kalau `reduce_motion` aktif.

---

## 5. Layout HUD

### 5.1 Desktop 1280×720

```
┌ 20 ────────────────────────────────────────────────────────────────┐
│ VITALS 268×64          WAVE 300×44                    [🔊] [⏸]      │
│ 82/100 · hp 220×6      progress 300×2                SCORE 144×30   │
│ armor 220×3                                                          │
│                                                                     │
│                              ✛ reticle                              │
│                                                                     │
│ [WASD][SHIFT][SPACE][RMB]                     [ADS][EMP]            │
│  legend 22px                                  [ ARC-07   24/96 ]    │
└─────────────────────────────────────────────────────────────────────┘
```

| Zona | Posisi | Ukuran | Isi |
|---|---|---|---|
| Vitals | 20, 20 | 268×64 | label, `82/100`, health 220×6 (4 segmen), armor 220×3, accent edge |
| Objective | 490, 20 (tengah) | 300×44 | ikon target, `WAVE 03`, `7 LEFT`, progres 2px |
| System | 1164…1260, 20 | 2× 44×44 | sound, pause (ikon, bukan teks) |
| Score | 1116, 72 | 144×30 | `1,240` + `02:14`, mono |
| ADS | 1004, 580 | 76×36 | crosshair + label; accent edge saat aktif |
| EMP | 1088, 580 | 172×36 | ikon, label, `READY`, progres 2px |
| Weapon | 992, 624 | 268×76 | nama, tipe, ammo mono 30, `3` slot |
| Legend | 20, 672 | keycaps 22px | WASD/Shift/Space/RMB, hanya desktop |
| Reticle | 640, 360 | tick 6 · gap 12 | stroke 1.5, titik 2px |

Inset layar 20px; panel tidak boleh menyentuh tepi. Total area atas yang
tertutup turun dari **104px** menjadi **64px**.

### 5.2 Portrait 390×844

Safe area: **44 atas** (chip shell web), **12 samping**, **34 bawah** (gesture).

| Kontrol | Posisi (pusat/kiri-atas) | Ukuran | Catatan |
|---|---|---|---|
| Status rail | 12, 44 | 168×48 | health 146×4 + armor 146×2 |
| Wave chip | 190, 44 | 88×48 | `WAVE 03` + `7 LEFT` |
| Pause | 334, 46 | 44×44 | ikon, bukan teks |
| Toast | 24, 118 | 342×30 | hilang setelah 10 detik |
| Reticle | 195, 392 | — | sedikit di atas tengah |
| Joystick | (84, 738) | Ø128 | knob Ø52, ring dalam Ø76 |
| FIRE | (326, 748) | Ø92 | aksen penuh, ikon crosshair |
| AIM | (326, 640) | Ø56 | toggle, ring saat aktif |
| EMP | (232, 700) | Ø56 | ring kooldown Ø66 |
| SWAP | (232, 616) | Ø48 | ikon swap |

Jarak antar target: FIRE–AIM 34px, FIRE–EMP 31px, EMP–SWAP 32px — semuanya
di atas 12px. Tidak ada aksi di 120px teratas. Score/time tidak ditampilkan di
HP (dipindah ke pause) supaya rail tetap satu baris.

### 5.3 Landscape 844×390

| Kontrol | Posisi | Ukuran |
|---|---|---|
| Vitals | 44, 16 | 196×44 |
| Wave | 372, 16 | 100×44 |
| Pause | 756, 14 | 44×44 |
| Joystick | (120, 300) | Ø112 |
| FIRE | (760, 300) | Ø80 |
| AIM | (760, 212) | Ø48 |
| EMP | (672, 262) | Ø48 |
| SWAP | (672, 190) | Ø40 |

Landscape memakai inset 44 kiri/kanan untuk notch. Semua tombol berada di
bawah 250px (zona jempol).

### 5.4 Aturan responsif

* Basis tetap 1280×720; `apply_layout_for_size()` dan `_control_unit()` dipakai
  untuk memetakan ukuran fisik.
* `MIN_PHYSICAL_FONT_PX = 11` dipertahankan.
* Ambang `NARROW_WIDTH = 760` dipertahankan; di bawah itu rail atas menjadi satu
  baris padat, bukan tiga kartu.
* Safe area dibaca dari `DisplayServer.get_display_safe_area()`; shell web punya
  inset tambahan 46px (chip) — jangan dihapus.
* Angka ammo **tidak boleh** mengubah lebar kartu: mono + lebar tetap.

---

## 6. Komponen & state

| Komponen | Varian | State | Ukuran | Catatan |
|---|---|---|---|---|
| Button primary | aksi utama | default/hover/pressed/focus/disabled/active | 160×48, 56 untuk aksi besar | fill accent, teks accent-ink |
| Button secondary | pendamping | idem | 160×48 | border 1px, fill panel-2 |
| Button ghost | navigasi | idem | 160×48 | tanpa fill; hover 6% |
| Button danger | quit/restart | idem | 160×48 | **outlined**, bukan filled |
| Icon button | pause, sound, close | idem | 44×44 | ikon 20px |
| Touch button | FIRE/AIM/EMP/SWAP | default/pressed/cooldown | 92/56/56/48 | hit area +8px, gap ≥12 |
| Toggle | sound, aim assist | on/off/disabled | 46×24 | knob 17, fill accent saat on |
| Segmented | tab, fire mode | 2–4 pilihan | 330×36 | underline accent |
| Slider | sensitivitas, opacity | normal/drag | 150–300 | wajib menampilkan % |
| Stepper | posisi HUD | normal | 36×36 + nilai | untuk editor |
| Tabs | settings | active/inactive | 220×52 | ikon + label |
| Stat card | vitals, wave | normal/low/critical | 268×64 | accent edge = status |
| Weapon card | senjata | normal/low/empty | 268×76 | ammo mono 30 |
| Bar | health/armor/progress | 0–100% | 220×6 / 220×3 / 300×2 | 4 segmen untuk health |
| Ring | EMP cooldown | ready/charging/off | Ø66 | arc 270°, warna ability |
| Chip | wave, skor | normal | 88×48 / 144×30 | mono untuk angka |
| Toast | hint, konfirmasi | enter/exit | 342×30 | ikon info + teks 10.2 |
| Hit marker | hit/kill | flash 160ms | 24px | kill = 8 tick merah |
| Menu row | pause/settings | default/selected/danger | 400×64 | bar 2px accent saat selected |
| Sheet | menu HP | open/closed | 390×440 | handle 48×4, swipe down |
| Editor handle | HUD editor | idle/drag | 8×8 | snap 8px |

Semua tombol memakai **focus ring 2px offset 2** — terlihat di keyboard dan
gamepad, bukan hanya hover.

---

## 7. Menu

### 7.1 Struktur

```
MAIN
├─ CONTINUE
├─ NEW RUN
├─ SETTINGS ── AUDIO · CONTROLS · HUD · ACCESSIBILITY
└─ QUIT

PAUSE (in-run)
├─ RESUME            ← fokus default, item pertama
├─ RESTART RUN
├─ SETTINGS          ← layar yang sama dengan main
├─ SOUND [toggle]
└─ QUIT RUN          ← butuh konfirmasi

RESULTS
├─ stats: KOs · ACCURACY · SHOTS · BEST
├─ RETRY (primary)
└─ MAIN MENU (secondary)
```

### 7.2 Pause (desktop)

Rail 400px di kiri, 5 baris 64px. Baris terpilih memakai fill `panel-2` + bar
amber 2px; baris lain hanya hairline. Ringkasan run di kanan (660×392): wave,
timer, 4 stat, progres wave. Kartu "NEXT" di bawah ringkasan menampilkan aksi
yang sedang difokuskan — ini yang membuat navigasi keyboard terasa hidup.

### 7.3 Results

Panel 600×528 di tengah. Eyebrow `RUN COMPLETE`, judul `WAVE 04` 54px, stat
2×2, `+240 BP`, lalu `RETRY` 240×52 dan `MAIN MENU` 200×52. Tidak ada tombol
tutup: hasil harus dipilih.

### 7.4 Settings

Rail 220px (4 tab), konten 864px, baris 68px: label + deskripsi + kontrol di
kanan. Slider menampilkan angka; segmented menampilkan pilihan; toggle punya
label status. Footer `RESET DEFAULTS` (ghost) dan `DONE` (primary). Semua
perubahan langsung diterapkan (live preview).

### 7.5 HUD editor

Pratinjau HUD penuh + grid 40px. Grup terpilih diberi border dashed amber,
4 handle, dan chip nama. Inspector 360×528: opacity (min 30%), scale (80–120%),
preset `MINIMAL/STANDARD/ADVANCED`, posisi X/Y, reset, done. Snap 8px.
Implementasi membatasi opacity panel ke **65–100%** (bukan minimum 30% di
board) agar teks tetap memiliki latar yang cukup gelap di atas world terang;
ini kompromi aksesibilitas yang disengaja, bukan hasil uji kontras di perangkat.

### 7.6 Menu di HP

Board menargetkan **bottom sheet** 440px dengan handle dan baris 74px.
Implementasi pause di 390×844 memakai tinggi 340px agar ruang kosong di bawah
aksi berkurang setelah QA visual; results tetap punya tombol 302×56 dan
safe area footer 34px. Handle 48×4px dan swipe-down 80px untuk resume sudah
diimplementasikan; perlu validasi touch asli di perangkat.

---

## 8. Ikon

41 glyph regular + 16 fill, semuanya Phosphor (MIT). Lihat

| Aksi | Ikon | State |
|---|---|---|
| Pause | `pause` | fill saat menu terbuka |
| Resume / play | `play` | fill |
| Retry | `arrow-counter-clockwise` | regular |
| Settings | `gear-six` | fill saat tab aktif |
| Sound | `speaker-high` / `speaker-slash` | fill saat on |
| Health | `heart` | fill di kartu |
| Armor | `shield` | regular |
| EMP | `lightning` | fill saat ready |
| Ganti senjata | `swap` | regular |
| Aim | `crosshair` / `crosshair-simple` | fill saat aktif |
| Objective | `target` | regular |
| Skor / waktu | `skull`, `timer` | regular |
| Menu | `house` | regular |
| Hasil | `chart-bar` | regular |

Aturan: grid 24, stroke 1.5–2, jangan regangkan non-uniform, jangan campur
set, ikon **selalu** punya label di menu (kecuali pause/sound di HUD).

---

## 9. Motion & feedback

* Hit confirm: 4 tick putih, 160ms; kill: 8 tick merah + skala 1.06.
* Damage: vignette tepi merah 280ms, bukan kilatan penuh layar.
* Low health: bar merah + pulse 1.2s; tidak ada strobe.
* Ammo berubah: **snap**, tanpa animasi angka — animasi terasa lag.
* Skor: boleh tick 180ms.
* Toast: 2.4s + fade; tidak menutupi reticle.
* Semua efek di atas bisa dimatikan lewat `reduce_motion`.

---

## 10. Aksesibilitas

* Kontras teks ≥4.5:1 (semua token lolos; lihat §2.4).
* Target sentuh ≥44px; jarak ≥12px; sudut atas hanya untuk aksi jarang.
* Status tidak hanya warna: danger punya ikon/border, health punya angka.
* Skala teks 100–130% di settings; layout tidak boleh pecah.
* `reduce_motion`, `reduce_flash`, dan `colorblind` (danger → oranye + ikon)
  masuk tab ACCESSIBILITY.
* Safe area dinamis (notch/gesture) dibaca dari OS.
* Semua kontrol bisa dijangkau keyboard: fokus awal jelas, ESC konsisten.

---

## 11. Pemetaan implementasi ke Godot

### 11.1 Struktur file yang diusulkan

```
game/scripts/ui/tokens.gd              # warna, ukuran, durasi (const)
game/scripts/ui/aegis_theme.gd         # Theme + StyleBoxFlat dibangun runtime
game/scripts/ui/widgets/bracket_panel.gd
game/scripts/ui/widgets/stat_card.gd
game/scripts/ui/widgets/hud_button.gd
game/scripts/ui/widgets/cooldown_ring.gd
game/scripts/ui/hud_desktop.gd
game/scripts/ui/hud_touch.gd
game/scripts/ui/menus/pause_menu.gd
game/scripts/ui/menus/results_panel.gd
game/scripts/ui/menus/settings_menu.gd
game/scripts/ui/menus/hud_editor.gd
game/scripts/ui/touch_controls.gd      # orkestrator; signal tetap
game/assets/ui/fonts/*.ttf
game/assets/ui/icons/*.svg
```

`touch_controls.gd` sekarang 1.300 baris; refactor dilakukan **bertahap** dengan
mempertahankan semua signal yang sudah dipakai `main.gd`
(`movement_changed`, `fire_changed`, `pause_requested`, dst). Jangan mengganti
nama signal di tengah refactor.

### 11.2 Theme

* `StyleBoxFlat`: `bg_color`, `border_width_* = 1`, `border_color`, `corner_radius
  = 0–2`. Tanpa tekstur.
* Bracket sudut digambar oleh `BracketPanel._draw()` (8 garis) — jauh lebih
  murah daripada nine-patch dan tetap tajam di semua skala.
* Font: impor 6 TTF; buat `FontVariation` untuk weight, atau pakai family
  terpisah (Chakra Petch 600 / Rajdhani 400·500·600 / JetBrains Mono 500).
* Ikon: impor SVG pada 1× dan 2×; `TextureRect` + `modulate` untuk warna state.
* Jangan memakai `theme_override` ad-hoc di 20 tempat; semua lewat `AegisTheme`.

### 11.3 Perilaku

* `apply_layout_for_size(viewport, stretch)` tetap menjadi satu-satunya jalur
  layout; jangan membaca ukuran window langsung di `_ready`.
* Mode sentuh tetap dideteksi `DisplayServer.is_touchscreen_available()`; QA
  memaksa lewat `set_touch_mode(true)` (tanpa memanggil ulang layout).
* Settings disimpan di `user://aegis.cfg` (`ConfigFile`): sensitivity, hud_scale,
  hud_opacity, left_handed, reduce_motion, mute.
* HUD editor menyimpan offset per grup dalam koordinat 1280×720, lalu diskalakan.
* Semua angka layout berada di `tokens.gd`, tidak ada magic number di widget.

### 11.4 Biaya

* 6 TTF + 57 SVG ≈ 900KB; bisa di-subset ke Latin + glyph yang dipakai.
* Bracket `_draw` hanya 8 garis per panel; <0.1ms per frame.
* Tidak ada shader/blur runtime; scrim memakai `ColorRect` + gradient texture.

---

## 12. QA & kriteria penerimaan

### 12.1 Checklist visual

- [ ] 1280×720, 390×844, 844×390: tidak ada panel yang bertumpuk.
- [ ] Semua target sentuh ≥44px fisik; gap ≥12px; di dalam safe area.
- [ ] Ammo dan slot senjata terlihat di ketiga ukuran.
- [ ] Hanya satu aksen (amber); cyan hanya armor; merah hanya damage/quit.
- [ ] Angka tidak menggeser layout saat berubah (mono/tabular).
- [ ] Pause terbuka ≤120ms; ESC menutup submenu lalu menu.
- [ ] Settings dari main dan pause identik.
- [ ] HUD editor menyimpan dan reset per grup.
- [ ] `reduce_motion` mematikan semua animasi >120ms.

### 12.2 Tambahan smoke test

`tests/playability_hud_smoke.gd`:

1. Di 390×844 touch: setiap `Button` yang terlihat berukuran ≥44px.
2. FIRE/AIM/EMP/SWAP tidak saling beririsan (cek rect + radius).
3. Toast tidak menimpa rail atas atau reticle.
4. Pause → Settings → ESC kembali ke pause, bukan ke game.
5. Ammo `24 → 5 → 0` tidak mengubah lebar kartu senjata (≥1px toleransi).
6. `set_touch_mode(false)` mengembalikan legend keyboard tanpa layout shift.

`tools/web_qa.mjs`: tambah frame `pause`, `results`, `settings`, `editor` untuk
1280×720 dan 390×844.

### 12.3 Perintah verifikasi (sudah dipakai di repo)

```bash
GODOT_BIN=/tmp/godot/Godot_v4.6.2-stable_linux.x86_64 SKIP_VERSION_CHECK=1 \
  ./scripts/run_smoke_tests.sh --no-import
./scripts/export_web_preview.sh --output /tmp/preview/web --no-import
node tools/web_qa.mjs --url http://127.0.0.1:8133 --page / \
  --viewport 1280x720 --tour --out /tmp/aegis
```

---

## 13. Milestone implementasi

**Catatan status:** ✅ di bawah berarti komponen/perilaku tertentu *terimplementasi*
atau lulus tes teknis, **tidak** berarti kualitas board telah disetujui pengguna.
Kriteria visual kolom “Selesai bila” harus divalidasi ulang dengan rujukan baru.

| # | Isi | File utama | Selesai bila | Status |
|---|---|---|---|---|
| M0 | Token + theme + font + ikon | `aegis_tokens.gd`, `aegis_theme.gd`, `assets/ui/` | HUD lama tampil dengan token baru | ✅ token/tema terpasang; arah palet perlu validasi ulang |
| M1 | HUD desktop baru | `touch_controls.gd`, `hud_layout.gd`, `hud_renderer.gd` | Board 02 cocok di 1280×720; smoke hijau | ✅ kode terpasang; smoke 13/13 (2026-10-17); **bukan** tanda board disetujui |
| M2 | HUD sentuh + portrait/landscape | `hud_layout.gd` (`touch_portrait`, `touch_landscape`) | Board 03 cocok di 390×844 & 844×390 | ✅ layout mobile tersedia; QA WASM 3 viewport lulus untuk interaksi yang diuji, **bukan** persetujuan keterbacaan |
| M3 | Pause + results | `_build_pause_menu`, `_build_results_panel` | Board 05; ESC/focus benar | ⏳ Pause diuji pada WASM; **hasil/results belum berhasil dijangkau** pada probe idle, sehingga visual results belum terverifikasi |
| M4 | Settings + HUD editor | `aegis_settings_menu.gd`, `hud_editor.gd` | Board 06; setting persist | ✅ Interaksi/settings/editor yang diuji lulus smoke dan QA WASM; **bukan persetujuan visual** |
| M5 | Polish + a11y | theme, motion | `reduce_motion`, kontras, 44px | ⏳ Sebagian preferensi tersedia dan diuji; kontras, animasi, keterbacaan kontrol di tangan pemain/perangkat nyata **belum** divalidasi |
| M6 | QA + evidence | smoke, `web_qa` | Semua frame + smoke 16/16 | ⏳ CI run `39088836330`: **16/16 smoke PASS**; QA payload `95f39f6`: **3/3 viewport PASS** untuk interaksi yang diuji. Frame results, perbandingan visual game rilis dan QA perangkat nyata **belum selesai** |

Catatan implementasi: HUD tinggal di satu facade (`touch_controls.gd`) dengan
geometri di `hud_layout.gd` dan gambar reticle/joystick/vignette di
`hud_renderer.gd`. Nama file lama (`hud_desktop.gd`, `pause_menu.gd`, …) tidak
dipakai supaya smoke test lama yang membaca field privat HUD tetap valid.

Estimasi kasar: M0–M2 = 2 hari, M3–M4 = 2 hari, M5–M6 = 1 hari.

---

## 14. Risiko

| Risiko | Mitigasi |
|---|---|
| Dunia terang membuat panel "menyatu" | bracket + hairline, panel 92%, diuji di 3 crop nyata |
| Refactor 1.300 baris merusak input | port widget dulu, signal tetap, smoke tiap milestone |
| Font menambah ukuran build | subset Latin + hanya 6 file; ukur di CI |
| HUD editor menambah kompleksitas | mulai preset 3 pilihan, drag grup, opacity; tanpa rotasi |
| Portrait terasa sempit | 6 kontrol, rail satu baris, score pindah ke pause |
| Angka fisik < 11px di layar kecil | `MIN_PHYSICAL_FONT_PX` + tes ukuran |

---

## 15. Pertanyaan terbuka (historis; jawaban terbaru di audit ulang)

Pertanyaan di bawah berasal dari fase AEGIS. **Jangan** menganggap keputusan
historisnya masih berlaku; keputusan yang memblokir redesign tercantum dalam
[`DECISIONS.md` §4](DECISIONS.md#4-keputusan-pengguna-yang-masih-dibutuhkan).

1. Apakah aksen amber disetujui, atau tetap mint/cyan seperti reticle sekarang?
2. Portrait: dipertahankan sebagai mode setara, atau hanya fallback?
3. Apakah skor/waktu perlu tampil di HP, atau cukup di pause?
4. Berapa jumlah wave per sesi (mockup memakai 5)? Ini memengaruhi progress.
5. Apakah reload akan ditambahkan? Desain sekarang tidak punya tombol reload;
   rekomendasi: auto-reload agar tidak menambah kontrol ke-7.
6. Nama senjata final (`ARC-07`, `NOVA`, dst) untuk label kartu.

---

## 16. Sumber

**Ergonomi & HUD mobile**

* Epic Games — *Designing for Mobile in Fortnite*:
  https://dev.epicgames.com/documentation/fortnite/designing-for-mobile-in-fortnite
* Apple Human Interface Guidelines — target 44×44 pt.
* Material Design — 48×48 dp, jarak 8 dp.
* Nielsen Norman Group — *Touch target size*.
* WCAG 2.5.5 (44px) dan 2.5.8 (24px).
* Panduan HUD COD Mobile / PUBG Mobile / Free Fire (custom layout, opacity
  30–80%, fixed joystick, preset simplified/advanced).

**Tipografi**

* Sidebearings — *Game UI Type Systems: HUD to Handheld*:
  https://www.sidebearings.com/game-ui-type-system/
* h-idris — *Typography for game UI* (tabular numerals, type scale).
* David Candland / Polygon — catatan UI Destiny (Swiss type, low footprint).

**Warna & ikon**

* Analisis palet HUD sci-fi (`#0B0C10`, `#1F2833`, `#66FCF1`) sebagai referensi
  awal; final memakai token di §4.1.
* Phosphor Icons — https://phosphoricons.com (MIT)
* Lucide — https://lucide.dev (ISC)
* Material Symbols — Apache 2.0

**Menu**

* *Game UI Design: Building Interfaces Players Actually Use* — maksimal 3 level.
* *Game UI/UX Design Principles* — transisi 100–300ms, fokus default.
* NN/g heuristics — konsistensi, recognition over recall.
