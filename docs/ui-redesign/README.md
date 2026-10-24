# AEGIS — papan desain UI/UX

Folder ini berisi **papan desain yang disetujui**, bukan kode game. Implementasi
Godot dan bukti QA berada di `game/`, `web/`, serta milestone §13 spesifikasi.

Spesifikasi lengkap: [`../UI_UX_REDESIGN_SPEC.md`](../UI_UX_REDESIGN_SPEC.md)

## Isi

| Board | File | Isi |
|---|---|---|
| 01 | `board/01-foundation.png` | palet 13 token, 7 tingkat tipografi, anatomi panel, uji kontras di 3 crop dunia nyata |
| 02 | `board/02-hud-desktop.png` | HUD 1280×720 + ukuran tiap zona + perbandingan sebelum/sesudah |
| 03 | `board/03-hud-mobile.png` | 390×844, 844×390, peta jangkauan ibu jari, ukuran target |
| 04 | `board/04-components.png` | 30 specimen tombol (5 jenis × 6 state), target sentuh, bar, ring, kartu, kontrol, feedback |
| 05 | `board/05-menus-desktop.png` | pause + results + struktur menu + aturan |
| 06 | `board/06-menus-mobile.png` | settings + HUD editor desktop, serta pause/hasil/settings 390×844 |
| 07 | `board/07-icons.png` | 41 ikon Phosphor + 16 varian fill + aturan ukuran |

Setiap board tersedia sebagai **PNG** (untuk dilihat) dan **SVG** (untuk diedit).
Latar HUD memakai tangkapan layar asli `qa-evidence/scifi-bay/09-cliffs.png`
yang diburamkan agar fokus ke UI; uji kontras di board 01 memakai piksel asli
tanpa blur.

## Membangun ulang

Butuh Python 3.11+ dan `resvg-py` (renderer SVG Rust, tanpa browser):

```bash
python3 -m venv .venv
.venv/bin/pip install resvg-py pillow fonttools
cd docs/ui-redesign
.venv/bin/python src/boards.py            # semua board
.venv/bin/python src/boards.py 02-hud-desktop
```

`src/kit.py` berisi token + helper SVG, `src/hud.py` komposisi HUD (dipakai juga
oleh board komponen/menu), `src/boards.py` menyusun tiap papan.

## Aset

* `assets/fonts/` — Chakra Petch (SemiBold, Medium), Barlow (Regular, Medium,
  SemiBold), JetBrains Mono (Medium, Bold). Semua **SIL Open Font License 1.1**;
  teks lisensi ada di folder yang sama. JetBrains Mono di-instance dari variable
  font ke weight 500/700.
* `assets/icons/` — Phosphor Icons, **MIT**, 41 glyph regular + 41 fill (yang
  dipakai di board: 16). Lisensi: `assets/icons/LICENSE-Phosphor.txt`.
* `assets/plates/` — plate dari evidence repo (diburamkan) + 3 crop kontras.

Semua aset komersial-aman tanpa atribusi wajib; lisensi tetap disertakan.

## Status

Arah AEGIS Industrial disetujui 17 Oktober 2026. Implementasi M0–M6 berlangsung;
lihat tabel status dan batasan verifikasi di §13 spesifikasi. Board adalah target
visual, bukan bukti bahwa tiap fitur sudah tersedia dalam build.
