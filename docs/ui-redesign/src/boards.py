"""Builds every AEGIS design board as SVG + PNG.

Usage:  python src/boards.py [board ...]
        python src/boards.py            # all boards
"""

from __future__ import annotations

import sys

from hud import frame_desktop, frame_landscape, frame_phone, hud_desktop  # noqa: E402

from kit import (
    ABILITY,
    ACCENT,
    ACCENT_INK,
    ASSETS,
    CANVAS,
    DANGER,
    DISPLAY,
    DISPLAY_M,
    INFO,
    INK,
    INK_2,
    INK_3,
    LINE,
    LINE_HI,
    MONO,
    MONO_B,
    OK,
    PANEL,
    PANEL_2,
    PANEL_3,
    UI,
    UI_M,
    UI_SB,
    VOID,
    WHITE,
    bar,
    board,
    brackets,
    button,
    chip,
    circle,
    icon,
    label,
    line,
    panel,
    rect,
    render,
    ring,
    t,
    tc,
)

# ---------------------------------------------------------------------------
# 01 — Foundation
# ---------------------------------------------------------------------------
TOKENS = [
    ("void", VOID, "kanvas / letterbox"),
    ("panel", PANEL, "kartu HUD 92%"),
    ("panel-2", PANEL_2, "permukaan naik"),
    ("line", LINE, "hairline 1px"),
    ("line-hi", LINE_HI, "border / fokus"),
    ("ink", INK, "teks utama"),
    ("ink-2", INK_2, "teks sekunder"),
    ("ink-3", INK_3, "caption 5.1:1 di panel"),
    ("accent", ACCENT, "aksi / fokus"),
    ("ok", OK, "health"),
    ("info", INFO, "armor"),
    ("danger", DANGER, "damage"),
    ("ability", ABILITY, "EMP"),
]


def board_foundation() -> str:
    b = []

    # ── 01 palette ─────────────────────────────────────────────────────────
    b.append(t(80, 196, "01 / PALET & PERAN", 18, INK, DISPLAY, ls=1.2))
    b.append(line(80, 208, 940, 208, LINE, 1.0, 0.8))
    for i, (name, value, role) in enumerate(TOKENS):
        col, row = i % 4, i // 4
        x, y = 80 + col * 220, 226 + row * 96
        b.append(rect(x, y, 200, 54, value, LINE, 1.0, 1.0))
        b.append(t(x, y + 70, name, 11.5, INK, MONO_B, ls=0.2))
        b.append(t(x + 200, y + 70, value.upper(), 9.5, INK_3, MONO, "end"))
        b.append(t(x, y + 84, role, 9.5, INK_3, UI))

    # ── 02 type ────────────────────────────────────────────────────────────
    tx = 1020
    b.append(t(tx, 196, "02 / TIPOGRAFI", 18, INK, DISPLAY, ls=1.2))
    b.append(line(tx, 208, 1840, 208, LINE, 1.0, 0.8))
    rows = [
        ("WAVE 03", 40, DISPLAY, INK, 0.8, "DISPLAY XL", "40 / 44  ·  +2%"),
        ("SECTOR BAY 07", 28, DISPLAY, INK, 1.0, "DISPLAY L", "28 / 32"),
        ("OBJECTIVE // HOSTILES", 18, DISPLAY, INK_2, 0.8, "HEADING", "18 / 22"),
        ("Readable under fire: one idea per line.", 14, UI, INK_2, 0, "BODY", "14 / 20"),
        ("INCOMING WAVE", 11, UI_M, INK_3, 2.4, "LABEL", "11 / 14  ·  +12%"),
        ("24 / 96", 34, MONO, INK, 0, "MONO XL", "34 / 34  ·  tabular"),
        ("SCORE 1,240  ·  02:14", 13, MONO, INK_2, 0, "MONO M", "13 / 16"),
    ]
    for i, (text, size, family, color, ls, name, spec) in enumerate(rows):
        top = 214 + i * 58
        b.append(t(tx, top + 42, text, size, color, family, ls=ls))
        b.append(t(1840, top + 30, name, 9.5, INK_3, UI_M, "end", 1.8))
        b.append(t(1840, top + 44, spec, 9.5, INK_3, MONO, "end"))
        b.append(line(tx, top + 56, 1840, top + 56, LINE, 1.0, 0.45))

    # ── 03 geometry ────────────────────────────────────────────────────────
    b.append(t(80, 662, "03 / GEOMETRI & GRID", 18, INK, DISPLAY, ls=1.2))
    b.append(line(80, 674, 940, 674, LINE, 1.0, 0.8))
    px, py, pw, ph = 110, 706, 380, 150
    b.append(panel(px, py, pw, ph, accent_edge=ACCENT))
    b.append(rect(px + 12, py + 12, pw - 24, ph - 24, "none", LINE_HI, 1.0, 0.45, dash="3 3"))
    b.append(label(px + 26, py + 34, "VITALS", INK_3, 10, 1.9))
    b.append(t(px + pw - 54, py + 37, "82", 18, INK, MONO, "end"))
    b.append(t(px + pw - 26, py + 37, "/100", 9.5, INK_3, MONO, "end"))
    b.append(bar(px + 40, py + 50, 240, 6, 0.82, OK, ticks=4))

    def marker(x, y, n):
        return circle(x, y, 9, ACCENT, "#05080C", 1.0) + tc(x, y, str(n), 9, ACCENT_INK, MONO, "middle")

    b.append(marker(px - 10, py - 10, 1))
    b.append(marker(px + 12, py + ph - 12, 2))
    b.append(marker(px - 10, py + 120, 3))
    b.append(marker(px + 292, py + 47, 4))
    legend = [
        ("1", "Corner bracket", "10px · stroke 1px, hanya di 4 sudut"),
        ("2", "Padding", "12px dalam panel, 8px antar elemen"),
        ("3", "Accent edge", "2px, warna status (health / senjata)"),
        ("4", "Bar data", "6px health, 3px armor, 2px progres"),
    ]
    for i, (num, head, body) in enumerate(legend):
        ly = 716 + i * 42
        b.append(t(560, ly, num, 10, ACCENT, MONO))
        b.append(t(584, ly, head, 11, INK, UI_SB, ls=1.2))
        b.append(t(584, ly + 15, body, 9.8, INK_3, UI))

    # spacing scale
    b.append(label(80, 936, "SPACING — KELIPATAN 4", INK_3, 9.5, 2.0))
    sx = 80
    for val in (2, 4, 8, 12, 16, 24, 32, 48):
        w = val * 2
        b.append(rect(sx, 952 + (48 - w), w, w, ACCENT, op=0.85))
        b.append(t(sx, 1012, str(val), 9, INK_3, MONO))
        sx += w + 30

    # ── 04 contrast on the real world ──────────────────────────────────────
    b.append(t(1020, 662, "04 / KONTRAS DI DUNIA NYATA", 18, INK, DISPLAY, ls=1.2))
    b.append(line(1020, 674, 1840, 674, LINE, 1.0, 0.8))
    crops = [
        ("contrast-sky.png", "LANGIT TERANG", "panel 92% · teks 14.9:1"),
        ("contrast-bright.png", "TANAH TERANG", "panel 92% · teks 14.6:1"),
        ("contrast-ground.png", "MID-TONE", "panel 92% · teks 15.0:1"),
    ]
    for i, (file, name, note) in enumerate(crops):
        x = 1020 + i * 274
        b.append(f'<image x="{x}" y="698" width="254" height="146" href="plates/{file}"/>')
        b.append(rect(x, 698, 254, 146, PANEL, LINE, 1.0, 0.0))
        b.append(brackets(x, 698, 254, 146, 8, LINE_HI, 1.0, 0.7))
        # mini vitals card over the crop
        b.append(rect(x + 16, 720, 196, 46, PANEL, LINE, 1.0, 0.92))
        b.append(rect(x + 16, 720, 2, 46, OK))
        b.append(label(x + 28, 736, "VITALS", INK_3, 8, 1.6))
        b.append(t(x + 172, 739, "82", 14, INK, MONO, "end"))
        b.append(t(x + 200, 739, "/100", 7.5, INK_3, MONO, "end"))
        b.append(bar(x + 28, 748, 172, 5, 0.82, OK, ticks=4))
        b.append(label(x, 868, name, INK_2, 9.5, 1.6))
        b.append(t(x, 884, note, 9, INK_3, UI))

    # ── 05 principles ──────────────────────────────────────────────────────
    b.append(t(1020, 936, "05 / PRINSIP", 18, INK, DISPLAY, ls=1.2))
    principles = [
        ("SATU AKSEN", "Amber hanya untuk aksi, fokus, dan angka kunci."),
        ("DATA DI ATAS DEKORASI", "Tanpa glow di belakang angka; kontras dulu."),
        ("MAKS 6 KONTROL", "Sisanya kontekstual atau di dalam pause."),
        ("44PX ADALAH LANTAI", "Target sentuh, jarak 12px, tepi layar 16px."),
    ]
    for i, (head, body) in enumerate(principles):
        col, row = i % 2, i // 2
        x, y = 1020 + col * 420, 960 + row * 82
        b.append(t(x, y + 18, f"0{i + 1}", 12, ACCENT, MONO))
        b.append(t(x + 30, y + 17, head, 10.5, INK, UI_SB, ls=1.6))
        b.append(t(x + 30, y + 38, body, 10.5, INK_3, UI))

    return board(
        1920,
        1200,
        "BOARD 01 / 07",
        "Fondasi visual",
        "Palet, tipografi, geometri, dan uji kontras di atas tangkapan layar game yang sebenarnya.",
        "".join(b),
    )




# ---------------------------------------------------------------------------
# 02 — Desktop HUD
# ---------------------------------------------------------------------------
def marker(x: float, y: float, n: str) -> str:
    return circle(x, y, 11, ACCENT, "#05080C", 2.0) + tc(x, y, n, 11, ACCENT_INK, MONO, "middle")


def board_desktop() -> str:
    fx, fy = 64, 170
    b = []
    b.append(f'<g transform="translate({fx} {fy})">' + frame_desktop() + "</g>")
    b.append(rect(fx, fy, 1280, 720, "none", LINE_HI, 1.2, 0.9))
    b.append(brackets(fx - 8, fy - 8, 1296, 736, 18, ACCENT, 1.6, 0.9))
    b.append(t(fx, fy + 748, "1280 × 720  ·  inset 20  ·  panel 92%  ·  target minimum 44", 10, INK_3, MONO))

    markers = [
        (fx + 8, fy + 8, "1"),
        (fx + 806, fy + 70, "2"),
        (fx + 1268, fy + 8, "3"),
        (fx + 666, fy + 386, "4"),
        (fx + 980, fy + 612, "5"),
        (fx + 10, fy + 662, "6"),
    ]
    for x, y, n in markers:
        b.append(marker(x, y, n))

    # right column
    rx = 1400
    b.append(t(rx, 196, "ZONA & UKURAN", 18, INK, DISPLAY, ls=1.2))
    b.append(line(rx, 208, 1856, 208, LINE, 1.0, 0.8))
    items = [
        ("1", "VITALS", "268×64 · health 220×6, armor 220×3", "Accent edge 2px = status nyawa."),
        ("2", "OBJECTIVE", "300×44 di tengah atas", "Wave + hostiles + progres 2px."),
        ("3", "SYSTEM", "2 target 44×44 · chip 144×30", "Skor & waktu pakai mono tabular."),
        ("4", "RETICLE", "tick 6px · gap 12px · stroke 1.5", "Titik pusat 2px, kontras di dunia terang."),
        ("5", "WEAPON + EMP", "268×76 · 172×36 · 76×36", "Ammo mono 30px, tiga slot senjata."),
        ("6", "KEY LEGEND", "keycap 22px · hanya desktop", "Hilang total saat mode sentuh."),
    ]
    for i, (num, head, spec, note) in enumerate(items):
        y = 240 + i * 74
        b.append(marker(rx + 9, y - 4, num))
        b.append(t(rx + 26, y, head, 10.5, INK, UI_SB, ls=1.8))
        b.append(t(rx + 26, y + 16, spec, 9.8, INK_2, MONO))
        b.append(t(rx + 26, y + 31, note, 9.8, INK_3, UI))

    b.append(t(rx, 712, "APA YANG BERUBAH", 18, INK, DISPLAY, ls=1.2))
    b.append(line(rx, 724, 1856, 724, LINE, 1.0, 0.8))
    changes = [
        "Ammo dan slot senjata akhirnya terlihat di HUD.",
        "Satu aksen amber; cyan hanya untuk armor.",
        "Pause dan sound jadi ikon 44px, bukan teks.",
        "Skor, waktu, KO jadi chip mono — bukan 4 baris.",
        "Hint pindah ke toast; tengah layar tetap bersih.",
        "Kerangka kartu 1px + bracket, bukan kotak penuh.",
    ]
    for i, text in enumerate(changes):
        y = 750 + i * 27
        b.append(rect(rx, y - 5, 4, 4, ACCENT))
        b.append(t(rx + 14, y, text, 10.2, INK_3, UI))

    # before / after strip
    b.append(line(80, 940, 1856, 940, LINE, 1.0, 0.6))
    b.append(label(80, 966, "SEBELUM", INK_3, 9.5, 2.0))
    b.append(label(700, 966, "SESUDAH", INK_3, 9.5, 2.0))
    b.append(f'<image x="80" y="978" width="563" height="58" href="plates/before-topbar.png" opacity="0.9"/>')
    b.append(rect(80, 978, 563, 58, "none", LINE, 1.0, 0.9))
    b.append(t(80, 1054, "3 kartu 104px · teks 12px · tanpa ammo · dua bahasa warna", 9.5, INK_3, UI))

    b.append('<g clip-path="url(#clipAfter)"><g transform="translate(700 978) scale(0.44)">')
    b.append(rect(0, 0, 1280, 132, PANEL, op=1.0))
    b.append(hud_desktop())
    b.append("</g></g>")
    b.append(rect(700, 978, 563, 58, "none", LINE, 1.0, 0.9))
    b.append(t(700, 1054, "3 modul 64px · target 44px · ammo + slot · satu aksen", 9.5, INK_3, UI))

    body = "".join(b)
    extra = '<clipPath id="clipAfter"><rect x="700" y="978" width="563" height="58"/></clipPath>'
    return board(
        1920,
        1200,
        "BOARD 02 / 07",
        "HUD desktop",
        "Zona layar, ukuran target, dan kepadatan informasi pada 1280×720.",
        body,
        extra_defs=extra,
    )




# ---------------------------------------------------------------------------
# 03 — Mobile HUD
# ---------------------------------------------------------------------------
def board_mobile() -> str:
    px, py = 90, 150
    lx, ly = 540, 150
    b = []
    b.append(f'<g transform="translate({px} {py})">' + frame_phone() + "</g>")
    b.append(rect(px, py, 390, 844, "none", LINE_HI, 1.2, 0.9))
    b.append(brackets(px - 8, py - 8, 406, 860, 16, ACCENT, 1.5, 0.85))
    b.append(rect(px + 12, py + 44, 366, 766, "none", LINE_HI, 1.0, 0.30, dash="4 6"))
    b.append(label(px + 12, py + 40, "SAFE 44", INK_3, 7.5, 1.2))
    b.append(label(px + 378, py + 40, "12", INK_3, 7.5, 1.0))

    ann = [
        (px + 326, py + 806, "FIRE 92", "middle"),
        (px + 362, py + 644, "56", "start"),
        (px + 198, py + 704, "56", "end"),
        (px + 202, py + 620, "48", "end"),
        (px + 84, py + 818, "JOYSTICK 128", "middle"),
        (px + 24, py + 164, "TOAST 30", "start"),
    ]
    for x, y, text, anchor in ann:
        b.append(t(x, y, text, 7.6, INK_3, MONO, anchor))

    b.append(f'<g transform="translate({lx} {ly})">' + frame_landscape() + "</g>")
    b.append(rect(lx, ly, 844, 390, "none", LINE_HI, 1.2, 0.9))
    b.append(brackets(lx - 8, ly - 8, 860, 406, 16, ACCENT, 1.5, 0.85))
    b.append(t(lx, ly + 414, "844 × 390  ·  inset aman 44 kiri/kanan (notch)  ·  kontrol bawah", 9.5, INK_3, MONO))

    # thumb reach map (second portrait, 0.55x)
    tx, ty, sc = 540, 640, 0.55
    b.append(label(tx, ty - 14, "PETA JANGKAUAN IBU JARI", INK_3, 9.5, 2.0))
    b.append(f'<g clip-path="url(#clipPhone)"><g transform="translate({tx} {ty}) scale({sc})">')
    b.append(rect(0, 0, 390, 844, VOID))
    b.append(frame_phone())
    b.append(rect(0, 0, 390, 844, "#05080C", op=0.55))
    b.append(circle(84, 738, 185, OK, OK, 1.5, 0.10))
    b.append(circle(326, 748, 185, OK, OK, 1.5, 0.10))
    b.append(circle(84, 738, 250, ACCENT, ACCENT, 1.5, 0.06))
    b.append(circle(326, 748, 250, ACCENT, ACCENT, 1.5, 0.06))
    b.append(rect(0, 0, 120, 120, DANGER, op=0.10))
    b.append(rect(270, 0, 120, 120, DANGER, op=0.10))
    b.append(circle(84, 738, 185, "none", OK, 1.5, 0.55, ))
    b.append(circle(326, 748, 185, "none", OK, 1.5, 0.55))
    b.append(circle(84, 738, 250, "none", ACCENT, 1.5, 0.45))
    b.append(circle(326, 748, 250, "none", ACCENT, 1.5, 0.45))
    b.append("</g></g>")
    b.append(rect(tx, ty, 390 * sc, 844 * sc, "none", LINE, 1.0, 0.8))

    # legend
    ex = 800
    b.append(t(ex, 668, "ZONA JEMPOL", 15, INK, DISPLAY, ls=1.0))
    legend = [
        (OK, "NYAMAN", "Aksi primer: FIRE, AIM, joystick. Radius ±185px."),
        (ACCENT, "TERJANGKAU", "Aksi sekunder: EMP, SWAP. Butuh gerak ibu jari."),
        (DANGER, "SULIT", "Sudut atas: pause / status saja. Jangan aksi cepat."),
    ]
    for i, (color, head, note) in enumerate(legend):
        y = 700 + i * 58
        b.append(circle(ex + 6, y - 4, 6, color))
        b.append(t(ex + 24, y, head, 10, INK, UI_SB, ls=1.6))
        b.append(t(ex + 24, y + 17, note, 9.8, INK_3, UI))

    b.append(t(ex, 900, "ATURAN KIDAL", 15, INK, DISPLAY, ls=1.0))
    b.append(t(ex, 926, "Semua kontrol kanan dicerminkan ke x = 390 − x;", 9.8, INK_3, UI))
    b.append(t(ex, 942, "joystick pindah ke kanan, bukan hanya diputar.", 9.8, INK_3, UI))

    # right column
    rx = 1430
    b.append(t(rx, 196, "ATURAN MOBILE", 18, INK, DISPLAY, ls=1.2))
    b.append(line(rx, 208, 1856, 208, LINE, 1.0, 0.8))
    rules = [
        ("1", "Ibu jari kiri gerak, kanan aksi.", "Tidak ada aksi cepat di atas layar."),
        ("2", "Maksimal 6 kontrol aktif.", "FIRE, AIM, EMP, SWAP, pause + joystick."),
        ("3", "Target 44–92px, jarak ≥12px.", "Sudut butuh 12mm; beri jarak lebih."),
        ("4", "Info penting di rail atas.", "Jangan taruh status di bawah jempol."),
        ("5", "Safe area 44 / 34 / 12.", "Chip web, gesture bar, tepi layar."),
        ("6", "Hint = toast 10 detik.", "Setelah itu hilang; tidak menutupi bidik."),
    ]
    for i, (num, head, note) in enumerate(rules):
        y = 244 + i * 58
        b.append(circle(rx + 8, y - 4, 10, "none", LINE_HI, 1.2, 0.9))
        b.append(tc(rx + 8, y - 4, num, 9.5, INK_2, MONO, "middle"))
        b.append(t(rx + 28, y, head, 10.5, INK, UI_SB))
        b.append(t(rx + 28, y + 16, note, 9.5, INK_3, UI))

    b.append(t(rx, 632, "UKURAN", 18, INK, DISPLAY, ls=1.2))
    b.append(line(rx, 644, 1856, 644, LINE, 1.0, 0.8))
    sizes = [
        ("FIRE", "92"), ("AIM", "56"), ("EMP", "56"), ("SWAP", "48"),
        ("PAUSE", "44"), ("JOYSTICK", "128"), ("TOAST", "30"),
    ]
    for i, (name, value) in enumerate(sizes):
        col, row = i % 2, i // 2
        x, y = rx + col * 214, 674 + row * 26
        b.append(t(x, y, name, 9.5, INK_2, UI_M, ls=1.0))
        b.append(t(x + 190, y, value, 10, ACCENT, MONO, "end"))
        b.append(line(x, y + 6, x + 190, y + 6, LINE, 1.0, 0.5))

    b.append(t(rx, 830, "CATATAN", 18, INK, DISPLAY, ls=1.2))
    b.append(line(rx, 842, 1856, 842, LINE, 1.0, 0.8))
    notes = [
        "Portrait tetap didukung, landscape adalah mode utama.",
        "Tidak ada kontrol di 120px atas: area chip & status.",
        "Semua tombol punya state pressed (skala 0.96 + fill).",
        "Haptic 10ms saat FIRE ditambahkan di tahap implementasi.",
    ]
    for i, text in enumerate(notes):
        y = 874 + i * 30
        b.append(rect(rx, y - 5, 4, 4, ACCENT))
        b.append(t(rx + 14, y, text, 10, INK_3, UI))

    return board(
        1920,
        1200,
        "BOARD 03 / 07",
        "HUD mobile",
        "390×844 dan 844×390: apa yang bisa dijangkau ibu jari, dan seberapa besar targetnya.",
        "".join(b),
        extra_defs='<clipPath id="clipPhone"><rect x="540" y="640" width="215" height="464"/></clipPath>',
    )




# ---------------------------------------------------------------------------
# 04 — Components
# ---------------------------------------------------------------------------
def icon_button(x: float, y: float, size: float, kind: str = "secondary", state: str = "default", glyph: str = "pause") -> str:
    enabled = state != "disabled"
    bg = PANEL_2 if enabled else "#0C141B"
    border = LINE_HI if state in ("hover", "focus") else LINE
    fg = INK_2 if enabled else "#4E6476"
    out = [rect(x, y, size, size, bg, border, 1.0, 1.0, rx=2)]
    if state == "focus":
        out.append(rect(x - 3, y - 3, size + 6, size + 6, "none", ACCENT, 1.5, 0.9, rx=3))
    if state == "pressed":
        out.append(rect(x, y, size, size, "#0A1219", None, 0, 0.7, rx=2))
    if state == "active":
        out.append(rect(x, y, 2, size, ACCENT))
        fg = ACCENT
    out.append(icon(glyph, x + (size - size * 0.42) / 2, y + (size - size * 0.42) / 2, size * 0.42, fg,
                    "fill" if state == "active" else "regular"))
    return "".join(out)


def toggle(x: float, y: float, on: bool) -> str:
    out = [rect(x, y, 46, 24, ACCENT if on else PANEL_3, ACCENT if on else LINE_HI, 1.0, 1.0, rx=12)]
    out.append(circle(x + (34 if on else 12), y + 12, 8.5, ACCENT_INK if on else INK_2))
    return "".join(out)


def segmented(x: float, y: float, w: float, h: float, items: list[str], active: int) -> str:
    out = [rect(x, y, w, h, PANEL, LINE, 1.0, 0.95, rx=2)]
    cw = w / len(items)
    for i, item in enumerate(items):
        cx = x + i * cw
        if i == active:
            out.append(rect(cx + 2, y + 2, cw - 4, h - 4, PANEL_3, None, 1.0, 1.0, rx=1))
            out.append(rect(cx + 2, y + h - 4, cw - 4, 2, ACCENT))
        out.append(tc(cx + cw / 2, y + h / 2, item, 9.5, INK if i == active else INK_3, UI_SB, "middle", 1.2))
    return "".join(out)


def slider(x: float, y: float, w: float, value: float) -> str:
    value = max(0.0, min(1.0, value))
    out = [rect(x, y - 2, w, 4, "#071017", None, 1.0, 1.0)]
    out.append(rect(x, y - 2, w * value, 4, ACCENT))
    out.append(rect(x + w * value - 7, y - 8, 14, 14, PANEL_2, ACCENT, 1.4, 1.0, rx=2))
    return "".join(out)


def board_components() -> str:
    b = []
    # ── button matrix ──────────────────────────────────────────────────────
    b.append(t(80, 196, "01 / TOMBOL — LIMA STATE", 18, INK, DISPLAY, ls=1.2))
    b.append(line(80, 208, 1280, 208, LINE, 1.0, 0.8))
    cols = ["DEFAULT", "HOVER", "PRESSED", "FOCUS", "DISABLED", "ACTIVE"]
    x0, y0 = 200, 262
    for c, name in enumerate(cols):
        b.append(t(x0 + c * 180 + 80, 246, name, 8.6, INK_3, UI_M, "middle", 1.8))
    rows = [
        ("primary", "RESUME", "aksi utama", "satu per layar"),
        ("secondary", "SETTINGS", "aksi pendamping", "border 1px"),
        ("ghost", "CANCEL", "navigasi ringan", "tanpa isi"),
        ("danger", "QUIT RUN", "keluar / restart", "konfirmasi dulu"),
        ("icon", "", "ikon 44×44", "tanpa label"),
    ]
    states = ["default", "hover", "pressed", "focus", "disabled", "active"]
    for r, (kind, text, note, note2) in enumerate(rows):
        y = y0 + r * 76
        b.append(t(80, y + 24, kind.upper(), 10, INK, UI_SB, ls=1.6))
        b.append(t(80, y + 39, note, 9, INK_3, UI))
        b.append(t(80, y + 51, note2, 9, INK_3, UI))
        for c, state in enumerate(states):
            x = x0 + c * 180
            if kind == "icon":
                b.append(icon_button(x + 58, y, 44, "secondary", state, "pause"))
            else:
                b.append(button(x, y, 160, 44, text, kind, state, size=11.5))

    # ── anatomy ────────────────────────────────────────────────────────────
    ax = 1340
    b.append(t(ax, 196, "02 / ANATOMI", 18, INK, DISPLAY, ls=1.2))
    b.append(line(ax, 208, 1856, 208, LINE, 1.0, 0.8))
    bx, by, bw, bh = 1400, 250, 320, 56
    b.append(rect(bx, by, bw, bh, PANEL_2, LINE_HI, 1.0, 1.0, rx=2))
    b.append(icon("gear-six", bx + 20, by + 18, 20, INK))
    b.append(t(bx + 50, by + 36, "SETTINGS", 13, INK, UI_SB, ls=1.0))
    # dimension marks
    b.append(line(bx, by - 14, bx + bw, by - 14, LINE_HI, 1.0, 0.7))
    b.append(line(bx, by - 18, bx, by - 10, LINE_HI, 1.0, 0.7))
    b.append(line(bx + bw, by - 18, bx + bw, by - 10, LINE_HI, 1.0, 0.7))
    b.append(t(bx + bw / 2, by - 20, "320", 9, INK_3, MONO, "middle"))
    b.append(line(bx + bw + 14, by, bx + bw + 14, by + bh, LINE_HI, 1.0, 0.7))
    b.append(t(bx + bw + 22, by + bh / 2 + 3, "56", 9, INK_3, MONO))
    b.append(t(bx + 24, by - 22, "icon 20 · gap 10", 9, INK_3, MONO))

    specs = [
        ("TINGGI", "48 menu · 56 aksi utama · 44 ikon"),
        ("PADDING", "20 kiri/kanan · ikon 20 · gap 10"),
        ("RADIUS", "2px — bahasa bentuk tetap tajam"),
        ("FOCUS", "ring 2px offset 2 — selalu terlihat"),
        ("TEKAN", "skala 0.96 + fill 12% selama 90ms"),
        ("NONAKTIF", "opacity 40%, border hilang, tanpa hover"),
    ]
    for i, (head, value) in enumerate(specs):
        y = 356 + i * 44
        b.append(t(ax, y, head, 9, INK_3, UI_M, ls=1.6))
        b.append(t(ax, y + 16, value, 9.8, INK_2, UI))

    # ── targets ────────────────────────────────────────────────────────────
    b.append(t(80, 700, "03 / TARGET & JARAK", 18, INK, DISPLAY, ls=1.2))
    b.append(line(80, 712, 940, 712, LINE, 1.0, 0.8))
    # 44 gap demo
    b.append(rect(100, 750, 44, 44, PANEL_2, LINE_HI, 1.0, 1.0))
    b.append(rect(152, 750, 44, 44, PANEL_2, LINE_HI, 1.0, 1.0))
    b.append(line(144, 806, 152, 806, ACCENT, 1.2))
    b.append(line(144, 802, 144, 810, ACCENT, 1.2))
    b.append(line(152, 802, 152, 810, ACCENT, 1.2))
    b.append(t(124, 824, "8 min", 9, ACCENT, MONO, "middle"))
    b.append(t(100, 742, "44 × 44", 9, INK_3, MONO))

    # fire circle + hit ring
    b.append(circle(330, 790, 46, ACCENT))
    b.append(circle(330, 790, 54, "none", ACCENT, 1.0, 0.5))
    b.append(icon("crosshair", 316, 776, 28, ACCENT_INK))
    b.append(t(330, 862, "FIRE 92 · hit ring +8", 9, INK_3, MONO, "middle"))

    # edge spacing: 44 target, 12 to the screen edge
    b.append(rect(470, 750, 44, 44, PANEL_2, LINE_HI, 1.0, 1.0))
    b.append(rect(526, 730, 2, 84, ACCENT, op=0.9))
    b.append(line(514, 806, 526, 806, ACCENT, 1.2))
    b.append(line(514, 802, 514, 810, ACCENT, 1.2))
    b.append(line(526, 802, 526, 810, ACCENT, 1.2))
    b.append(t(550, 828, "12 ke tepi", 9, ACCENT, MONO, "middle"))
    b.append(t(560, 752, "LAYAR", 8, INK_3, MONO))

    # ── bars & rings ───────────────────────────────────────────────────────
    b.append(t(80, 930, "04 / BAR & RING", 18, INK, DISPLAY, ls=1.2))
    b.append(line(80, 942, 940, 942, LINE, 1.0, 0.8))
    states = [(1.0, OK, "100", "sehat"), (0.55, OK, "55", "normal"), (0.22, DANGER, "22", "kritis")]
    for i, (v, color, text, note) in enumerate(states):
        y = 968 + i * 52
        b.append(label(80, y, f"HEALTH {text}", INK_3, 8.6, 1.6))
        b.append(bar(80, y + 8, 300, 8, v, color, ticks=4))
        b.append(t(392, y + 15, note, 9, INK_3, UI))

    b.append(label(80, 1140, "ARMOR", INK_3, 8.6, 1.6))
    b.append(bar(80, 1148, 300, 3, 0.4, INFO))
    b.append(label(80, 1176, "WAVE PROGRESS", INK_3, 8.6, 1.6))
    b.append(bar(80, 1184, 300, 2, 0.64, ACCENT, ticks=10))

    for i, (v, color, note) in enumerate([(1.0, OK, "READY"), (0.45, ABILITY, "45%"), (0.0, INK_3, "OFF")]):
        cx = 470 + i * 92
        b.append(ring(cx, 1010, 24, v, color))
        b.append(circle(cx, 1010, 18, PANEL_2, LINE, 1.0, 0.9))
        b.append(icon("lightning", cx - 8, 1002, 16, color))
        b.append(t(cx, 1050, note, 8.4, INK_3, MONO, "middle"))

    # ── cards ──────────────────────────────────────────────────────────────
    b.append(t(80, 1250, "05 / KARTU SENJATA", 18, INK, DISPLAY, ls=1.2))
    b.append(line(80, 1262, 940, 1262, LINE, 1.0, 0.8))
    variants = [("24", "/96", INK, ACCENT, "NORMAL"), ("05", "/96", DANGER, DANGER, "LOW AMMO"), ("00", "/00", INK_3, LINE_HI, "EMPTY")]
    for i, (ammo, reserve, color, edge, note) in enumerate(variants):
        x = 80 + i * 292
        b.append(panel(x, 1280, 268, 76, accent_edge=edge))
        b.append(t(x + 14, 1306, "ARC-07", 17, INK if i < 2 else INK_3, DISPLAY, ls=1.0))
        b.append(label(x + 14, 1320, "PLASMA RIFLE", INK_3, 8.2, 1.8))
        b.append(t(x + 220, 1312, ammo, 30, color, MONO, "end"))
        b.append(t(x + 254, 1312, reserve, 11, INK_3, MONO, "end"))
        b.append(label(x + 14, 1344, note, INK_3, 7.4, 1.6))

    # ── controls ───────────────────────────────────────────────────────────
    cx = 1000
    b.append(t(cx, 700, "06 / KONTROL", 18, INK, DISPLAY, ls=1.2))
    b.append(line(cx, 712, 1840, 712, LINE, 1.0, 0.8))

    b.append(t(cx, 748, "TOGGLE", 9, INK_3, UI_M, ls=1.6))
    b.append(toggle(cx, 760, True))
    b.append(t(cx + 58, 776, "ON", 9, INK_2, MONO))
    b.append(toggle(cx + 120, 760, False))
    b.append(t(cx + 178, 776, "OFF", 9, INK_2, MONO))

    b.append(t(cx, 816, "SEGMENTED", 9, INK_3, UI_M, ls=1.6))
    b.append(segmented(cx, 828, 330, 36, ["AUDIO", "CONTROLS", "HUD"], 1))

    b.append(t(cx, 900, "SLIDER", 9, INK_3, UI_M, ls=1.6))
    b.append(slider(cx + 10, 918, 300, 0.42))
    b.append(t(cx + 330, 922, "42%", 10, ACCENT, MONO))

    b.append(t(cx, 974, "TABS", 9, INK_3, UI_M, ls=1.6))
    for i, name in enumerate(["RUN", "LOADOUT", "STATS"]):
        tx = cx + i * 96
        b.append(t(tx, 1002, name, 10, INK if i == 0 else INK_3, UI_SB, ls=1.6))
        if i == 0:
            b.append(rect(tx - 2, 1010, 44, 2, ACCENT))
    b.append(line(cx, 1012, 1840, 1012, LINE, 1.0, 0.6))

    b.append(t(cx, 1050, "STEPPER", 9, INK_3, UI_M, ls=1.6))
    b.append(icon_button(cx, 1062, 36, "secondary", "default", "minus"))
    b.append(t(cx + 66, 1086, "80%", 12, INK, MONO, "middle"))
    b.append(icon_button(cx + 100, 1062, 36, "secondary", "default", "plus"))

    # ── feedback ───────────────────────────────────────────────────────────
    b.append(t(cx, 1140, "07 / FEEDBACK", 18, INK, DISPLAY, ls=1.2))
    b.append(line(cx, 1152, 1840, 1152, LINE, 1.0, 0.8))
    b.append(rect(cx, 1170, 330, 34, PANEL, LINE, 1.0, 0.94, rx=2))
    b.append(icon("info", cx + 12, 1181, 12, ACCENT))
    b.append(t(cx + 30, 1192, "Sensitivity updated", 10, INK_2, UI_M))
    b.append(t(cx + 330, 1218, "TOAST", 8, INK_3, MONO, "end"))

    # hitmarkers
    for i, (color, note) in enumerate([(WHITE, "HIT"), (DANGER, "KILL")]):
        hx, hy = cx + 30 + i * 96, 1260
        for dx, dy in ((1, 1), (1, -1), (-1, 1), (-1, -1)):
            b.append(line(hx + dx * 5, hy + dy * 5, hx + dx * 13, hy + dy * 13, color, 2.0))
        if i == 1:
            for dx, dy in ((0, 1), (0, -1), (1, 0), (-1, 0)):
                b.append(line(hx + dx * 4, hy + dy * 4, hx + dx * 14, hy + dy * 14, color, 1.4))
        b.append(t(hx, 1290, note, 8, INK_3, MONO, "middle"))

    # damage vignette sample
    b.append(rect(cx + 200, 1232, 150, 84, "#2A0808", DANGER, 1.0, 0.55, rx=2))
    b.append(rect(cx + 200, 1232, 150, 84, "none", DANGER, 1.0, 0.5, rx=2))
    b.append(t(cx + 275, 1310, "DAMAGE EDGE", 8, DANGER, MONO, "middle"))

    # modal shell
    b.append(rect(cx + 380, 1180, 330, 180, "#05080C", LINE_HI, 1.0, 0.85, rx=2))
    b.append(rect(cx + 380, 1180, 330, 34, PANEL_2, LINE, 1.0, 1.0))
    b.append(t(cx + 396, 1202, "PAUSED", 11, INK, UI_SB, ls=2.0))
    b.append(icon("x", cx + 690, 1190, 14, INK_3))
    for i, name in enumerate(["RESUME", "SETTINGS", "QUIT RUN"]):
        b.append(t(cx + 396, 1240 + i * 30, name, 9.5, INK if i == 0 else INK_3, UI_SB, ls=1.2))
        if i == 0:
            b.append(rect(cx + 380, 1228 + i * 30, 2, 20, ACCENT))
    b.append(t(cx + 545, 1382, "MODAL SHELL · 330×180", 8, INK_3, MONO, "end"))

    return board(
        1920,
        1500,
        "BOARD 04 / 07",
        "Komponen & state",
        "Tombol, target sentuh, bar, kartu, kontrol, dan feedback — semua state yang harus dibangun.",
        "".join(b),
    )



# ---------------------------------------------------------------------------
# 05 — Desktop menus
# ---------------------------------------------------------------------------
def backdrop(w: int = 1280, h: int = 720, dim: float = 0.62) -> str:
    return (
        f'<image x="0" y="0" width="{w}" height="{h}" preserveAspectRatio="xMidYMid slice" href="plates/plate-menu.png"/>'
        + rect(0, 0, w, h, "#05080C", op=dim)
        + rect(0, 0, w, h, "url(#vignette)", op=0.5)
    )


def menu_row(
    x: float,
    y: float,
    w: float,
    h: float,
    title: str,
    sub: str,
    selected: bool = False,
    danger: bool = False,
    toggle_on: bool | None = None,
) -> str:
    out = []
    if selected:
        out.append(rect(x, y, w, h, PANEL_2, None, 0, 0.96))
        out.append(rect(x, y, 2, h, ACCENT))
    out.append(line(x, y + h, x + w, y + h, LINE, 1.0, 0.5))
    color = DANGER if danger else INK
    out.append(t(x + 20, y + 30, title, 13, color, UI_SB, ls=1.4))
    out.append(t(x + 20, y + 47, sub, 9.5, INK_3, UI))
    if toggle_on is not None:
        out.append(toggle(x + w - 78, y + 20, toggle_on))
    else:
        out.append(icon("caret-right", x + w - 26, y + h / 2 - 6, 12, ACCENT if selected else INK_3))
    return "".join(out)


def stat_block(
    x: float, y: float, w: float, label_text: str, value: str, unit: str = "", size: float = 26
) -> str:
    out = [label(x, y, label_text, INK_3, 8.6, 1.8)]
    out.append(t(x, y + 34, value, size, INK, MONO))
    if unit:
        out.append(t(x + len(value) * size * 0.62 + 6, y + 34, unit, 10, INK_3, MONO))
    return "".join(out)


def screen_pause() -> str:
    b = [backdrop()]
    b.append(label(80, 92, "SESSION PAUSED", ACCENT, 9, 2.4))
    b.append(t(80, 136, "PAUSED", 44, INK, DISPLAY, ls=3.0))
    b.append(t(1160, 92, "BUILD 0.9.4  ·  BAY 07", 9, INK_3, MONO, "end"))
    b.append(line(80, 156, 1200, 156, LINE, 1.0, 0.6))

    rows = [
        ("RESUME", "Continue the run", False, False, None),
        ("RESTART RUN", "From wave 01", False, False, None),
        ("SETTINGS", "Audio, controls, HUD", False, False, None),
        ("SOUND", "Master output", False, False, True),
        ("QUIT RUN", "Back to main menu", False, True, None),
    ]
    for i, (title, sub, _sel, danger, tog) in enumerate(rows):
        b.append(menu_row(80, 184 + i * 64, 400, 64, title, sub, i == 0, danger, tog))

    b.append(panel(540, 184, 660, 392))
    b.append(label(564, 214, "RUN SUMMARY", INK_3, 9, 2.2))
    b.append(t(1176, 214, "SECTOR BAY 07", 9, INK_3, MONO, "end"))
    b.append(t(564, 262, "WAVE 03", 34, INK, DISPLAY, ls=1.6))
    b.append(t(1176, 260, "02:14", 22, INK_2, MONO, "end"))
    b.append(line(564, 286, 1176, 286, LINE, 1.0, 0.7))
    for i, (lab, val, unit) in enumerate(
        [("KOs", "12", ""), ("ACCURACY", "38", "%"), ("HOSTILES", "54", ""), ("BEST", "07", "")]
    ):
        b.append(stat_block(564 + i * 156, 316, 140, lab, val, unit, 24))
    b.append(line(564, 388, 1176, 388, LINE, 1.0, 0.7))
    b.append(label(564, 416, "WAVE PROGRESS", INK_3, 8.4, 1.8))
    b.append(bar(564, 426, 612, 4, 0.64, ACCENT, ticks=10))
    b.append(t(1176, 452, "3 / 5 WAVES", 9, INK_3, MONO, "end"))

    b.append(panel(564, 488, 300, 88))
    b.append(label(580, 512, "NEXT", INK_3, 8.4, 1.8))
    b.append(t(580, 536, "RESUME", 16, INK, DISPLAY, ls=1.4))
    b.append(t(580, 556, "ESC  ·  continue", 9, INK_3, UI))
    b.append(icon("play", 820, 518, 22, ACCENT, "fill"))

    b.append(t(80, 668, "ESC  resume  ·  UP/DOWN  navigate  ·  ENTER  select", 9.5, INK_3, MONO))
    b.append(t(1200, 668, "Progress saved automatically", 9.5, INK_3, UI_M, "end"))
    return "".join(b)


def screen_results() -> str:
    b = [backdrop()]
    b.append(rect(340, 96, 600, 528, PANEL, LINE, 1.0, 0.96))
    b.append(brackets(340, 96, 600, 528, 18, LINE_HI, 1.4, 0.9))
    b.append(rect(340, 96, 600, 3, ACCENT))
    b.append(label(376, 138, "RUN COMPLETE", ACCENT, 9, 2.6))
    b.append(t(376, 200, "WAVE 04", 54, INK, DISPLAY, ls=2.0))
    b.append(t(376, 226, "SECTOR CLEARED", 11, INK_2, UI_M, ls=2.0))
    b.append(t(904, 138, "02:14", 12, INK_3, MONO, "end"))
    b.append(line(376, 252, 904, 252, LINE, 1.0, 0.8))

    stats = [("KOs", "12", ""), ("ACCURACY", "38", "%"), ("SHOTS", "54", ""), ("BEST", "07", "")]
    for i, (lab, val, unit) in enumerate(stats):
        b.append(stat_block(376 + i * 134, 288, 120, lab, val, unit, 28))

    b.append(rect(376, 360, 528, 1, LINE, op=0.7))
    b.append(label(376, 392, "EARNED", INK_3, 8.6, 1.8))
    b.append(t(376, 420, "+ 240 BP", 18, ACCENT, MONO))
    b.append(t(904, 420, "TOTAL 1,240 BP", 9, INK_3, MONO, "end"))

    b.append(button(376, 462, 240, 52, "RETRY", "primary", icon_name="arrow-counter-clockwise", size=13))
    b.append(button(632, 462, 200, 52, "MAIN MENU", "secondary", icon_name="house", size=11))
    b.append(label(376, 552, "PRESS  R  TO  RETRY  ·  ESC  FOR  MENU", INK_3, 8.4, 2.2))
    return "".join(b)


def board_menus_desktop() -> str:
    b = []
    b.append('<g transform="translate(80 150) scale(0.68)">' + screen_pause() + "</g>")
    b.append(rect(80, 150, 870, 490, "none", LINE_HI, 1.2, 0.85))
    b.append(brackets(72, 142, 886, 506, 14, ACCENT, 1.4, 0.8))
    b.append(label(80, 666, "01 / PAUSE — 1280×720", INK_3, 9.5, 2.0))

    b.append('<g transform="translate(80 700) scale(0.68)">' + screen_results() + "</g>")
    b.append(rect(80, 700, 870, 490, "none", LINE_HI, 1.2, 0.85))
    b.append(brackets(72, 692, 886, 506, 14, ACCENT, 1.4, 0.8))
    b.append(label(80, 1216, "02 / RESULTS", INK_3, 9.5, 2.0))

    rx = 1050
    b.append(t(rx, 196, "STRUKTUR MENU", 18, INK, DISPLAY, ls=1.2))
    b.append(line(rx, 208, 1856, 208, LINE, 1.0, 0.8))
    tree = [
        ("MAIN", INK, 0),
        ("CONTINUE", INK_2, 1),
        ("NEW RUN", INK_2, 1),
        ("SETTINGS", INK_2, 1),
        ("AUDIO · CONTROLS · HUD · A11Y", INK_3, 2),
        ("QUIT", INK_2, 1),
        ("", INK_3, 0),
        ("PAUSE (IN-RUN)", INK, 0),
        ("RESUME  *", ACCENT, 1),
        ("RESTART RUN", INK_2, 1),
        ("SETTINGS  (same screen)", INK_2, 1),
        ("SOUND  [toggle]", INK_2, 1),
        ("QUIT RUN  !", DANGER, 1),
    ]
    for i, (text, color, indent) in enumerate(tree):
        if not text:
            continue
        b.append(t(rx + indent * 18, 240 + i * 22, text, 9.8, color, MONO))
    b.append(t(rx + 18, 240 + 13 * 22 + 6, "* default focus    ! needs confirmation", 8.6, INK_3, UI))

    b.append(t(rx, 600, "ATURAN", 18, INK, DISPLAY, ls=1.2))
    b.append(line(rx, 612, 1856, 612, LINE, 1.0, 0.8))
    rules = [
        "Maksimal 3 level; tidak ada menu di dalam menu di dalam menu.",
        "Resume selalu item pertama dan sudah terpilih saat pause.",
        "Quit di paling bawah, butuh konfirmasi kedua.",
        "Pause 120ms; results 240ms; tidak ada transisi > 300ms.",
        "ESC menutup submenu lalu menu — tidak pernah keluar game.",
        "Settings dari main dan pause adalah layar yang sama.",
    ]
    for i, text in enumerate(rules):
        y = 642 + i * 32
        b.append(rect(rx, y - 5, 4, 4, ACCENT))
        b.append(t(rx + 14, y, text, 9.6, INK_3, UI))

    b.append(t(rx, 884, "KOMPONEN", 18, INK, DISPLAY, ls=1.2))
    b.append(line(rx, 896, 1856, 896, LINE, 1.0, 0.8))
    comps = [
        ("Menu rail", "400px · baris 64 · selected 2px accent"),
        ("Stat block", "label 8.6 / nilai mono 26"),
        ("Footer hint", "9.5 mono, selalu di bawah"),
        ("Scrim", "0.74 + vignette; dunia tetap terlihat"),
    ]
    for i, (name, note) in enumerate(comps):
        y = 926 + i * 42
        b.append(t(rx, y, name, 10, INK, UI_SB, ls=1.2))
        b.append(t(rx, y + 15, note, 9.4, INK_3, UI))

    return board(
        1920,
        1300,
        "BOARD 05 / 07",
        "Menu desktop",
        "Pause dan hasil: hierarki, fokus default, dan bahasa visual yang sama dengan HUD.",
        "".join(b),
    )



# ---------------------------------------------------------------------------
# 06 — Settings, HUD editor, phone menus
# ---------------------------------------------------------------------------
def screen_settings() -> str:
    b = [backdrop()]
    b.append(icon("caret-left", 80, 82, 18, INK_2))
    b.append(t(108, 96, "SETTINGS", 28, INK, DISPLAY, ls=2.0))
    b.append(t(1200, 92, "CHANGES APPLY IMMEDIATELY", 8.6, INK_3, MONO, "end"))
    b.append(line(80, 120, 1200, 120, LINE, 1.0, 0.7))

    tabs = [
        ("speaker-high", "AUDIO", False),
        ("sliders", "CONTROLS", True),
        ("crosshair", "HUD", False),
        ("eye", "ACCESSIBILITY", False),
    ]
    for i, (ic, name, active) in enumerate(tabs):
        y = 160 + i * 52
        if active:
            b.append(rect(80, y, 220, 52, PANEL_2, None, 0, 0.9))
            b.append(rect(80, y, 2, 52, ACCENT))
        b.append(icon(ic, 96, y + 16, 18, ACCENT if active else INK_3))
        b.append(t(126, y + 32, name, 10.5, INK if active else INK_2, UI_SB, ls=1.4))
        b.append(line(80, y + 52, 300, y + 52, LINE, 1.0, 0.45))

    b.append(label(336, 160, "CONTROLS", ACCENT, 9, 2.4))
    rows = [
        ("SENSITIVITY", "Look speed for mouse and touch", "slider", 0.42, "42%"),
        ("AIM ASSIST", "Slowdown near the target", "toggle", 1.0, "ON"),
        ("FIRE MODE", "Tap to shoot or hold to fire", "segment", 0.0, "TAP / HOLD"),
        ("LEFT-HANDED", "Mirror the touch controls", "toggle", 0.0, "OFF"),
        ("INVERT LOOK Y", "Invert vertical look", "toggle", 0.0, "OFF"),
        ("VIBRATION", "Haptics on fire and damage", "toggle", 1.0, "ON"),
    ]
    for i, (name, desc, kind, value, text) in enumerate(rows):
        y = 190 + i * 68
        b.append(t(336, y, name, 12.5, INK, UI_SB, ls=1.2))
        b.append(t(336, y + 16, desc, 9.4, INK_3, UI))
        b.append(line(336, y + 46, 1200, y + 46, LINE, 1.0, 0.4))
        if kind == "slider":
            b.append(slider(980, y + 6, 150, value))
            b.append(t(1196, y + 12, text, 10, ACCENT, MONO, "end"))
        elif kind == "toggle":
            b.append(toggle(1146, y, value >= 1.0))
        else:
            b.append(segmented(996, y - 4, 190, 32, ["TAP", "HOLD"], 1))

    b.append(button(336, 620, 170, 48, "RESET DEFAULTS", "ghost", size=10))
    b.append(button(1010, 620, 190, 48, "DONE", "primary", icon_name="check", size=12))
    b.append(t(336, 692, "Pengaturan disimpan per akun, bukan per sesi.", 9, INK_3, UI))
    return "".join(b)


def screen_hud_editor() -> str:
    b = [frame_desktop(), rect(0, 0, 1280, 720, "#05080C", op=0.42)]
    for gx in range(0, 1280, 40):
        b.append(line(gx, 0, gx, 720, LINE_HI, 1.0, 0.05))
    for gy in range(0, 720, 40):
        b.append(line(0, gy, 1280, gy, LINE_HI, 1.0, 0.05))

    # selected group
    b.append(rect(20, 20, 268, 64, "none", ACCENT, 1.4, 0.95, dash="5 4"))
    for hx, hy in ((20, 20), (288, 20), (20, 84), (288, 84)):
        b.append(rect(hx - 4, hy - 4, 8, 8, ACCENT))
    b.append(rect(20, 4, 116, 18, ACCENT, op=1.0))
    b.append(t(28, 17, "VITALS · 100%", 8.4, ACCENT_INK, UI_SB, ls=1.2))

    # inspector
    px, py, pw, ph = 850, 96, 360, 528
    b.append(rect(px, py, pw, ph, PANEL, LINE_HI, 1.0, 0.97))
    b.append(rect(px, py, pw, 3, ACCENT))
    b.append(label(px + 20, py + 30, "HUD EDITOR", ACCENT, 8.6, 2.2))
    b.append(t(px + 20, py + 64, "VITALS", 24, INK, DISPLAY, ls=1.4))
    b.append(t(px + pw - 20, py + 30, "GROUP 1 / 4", 8.4, INK_3, MONO, "end"))
    b.append(line(px + 20, py + 82, px + pw - 20, py + 82, LINE, 1.0, 0.6))

    b.append(label(px + 20, py + 110, "OPACITY", INK_3, 8.4, 1.8))
    b.append(t(px + pw - 20, py + 110, "80%", 10, ACCENT, MONO, "end"))
    b.append(slider(px + 20, py + 126, pw - 40, 0.80))
    b.append(label(px + 20, py + 162, "SCALE", INK_3, 8.4, 1.8))
    b.append(t(px + pw - 20, py + 162, "100%", 10, INK_2, MONO, "end"))
    b.append(slider(px + 20, py + 178, pw - 40, 1.0))

    b.append(label(px + 20, py + 214, "PRESET", INK_3, 8.4, 1.8))
    b.append(segmented(px + 20, py + 226, pw - 40, 34, ["MINIMAL", "STANDARD", "ADVANCED"], 1))

    b.append(label(px + 20, py + 292, "POSITION", INK_3, 8.4, 1.8))
    b.append(icon_button(px + 20, py + 304, 36, "secondary", "default", "minus"))
    b.append(t(px + 66, py + 328, "X  20", 10, INK_2, MONO))
    b.append(icon_button(px + 130, py + 304, 36, "secondary", "default", "plus"))
    b.append(icon_button(px + 190, py + 304, 36, "secondary", "default", "minus"))
    b.append(t(px + 236, py + 328, "Y  20", 10, INK_2, MONO))
    b.append(icon_button(px + 296, py + 304, 36, "secondary", "default", "plus"))

    b.append(line(px + 20, py + 360, px + pw - 20, py + 360, LINE, 1.0, 0.6))
    b.append(button(px + 20, py + 380, 140, 44, "RESET", "ghost", size=10))
    b.append(button(px + 176, py + 380, 164, 44, "DONE", "primary", icon_name="check", size=11))

    b.append(label(px + 20, py + 456, "SNAP 8px", INK_3, 8.2, 1.6))
    b.append(label(px + 120, py + 456, "DRAG UNTUK PINDAH", INK_3, 8.2, 1.6))
    b.append(label(px + 20, py + 474, "OPACITY MIN 30% UNTUK INFO KRITIS", INK_3, 8.2, 1.6))

    b.append(t(30, 700, "ESC  cancel  ·  ENTER  apply", 9, INK_2, MONO))
    return "".join(b)


def screen_pause_phone() -> str:
    b = [backdrop(390, 844)]
    b.append(label(24, 68, "SESSION PAUSED", ACCENT, 7.6, 1.8))
    b.append(t(24, 104, "PAUSED", 30, INK, DISPLAY, ls=2.0))
    b.append(t(24, 128, "WAVE 03  ·  02:14  ·  1,240 BP", 8.4, INK_2, MONO))

    b.append(rect(0, 404, 390, 440, PANEL, LINE, 1.0, 0.97))
    b.append(rect(0, 404, 390, 2, LINE_HI))
    b.append(rect(171, 416, 48, 4, LINE_HI, op=0.9, rx=2))
    rows = [
        ("RESUME", "Continue the run", False, None),
        ("RESTART RUN", "From wave 01", False, None),
        ("SETTINGS", "Audio, controls, HUD", False, None),
        ("SOUND", "Master output", False, True),
        ("QUIT RUN", "Back to main menu", True, None),
    ]
    for i, (title, sub, danger, tog) in enumerate(rows):
        y = 432 + i * 74
        if i == 0:
            b.append(rect(0, y, 390, 74, PANEL_2, None, 0, 0.9))
            b.append(rect(0, y, 3, 74, ACCENT))
        b.append(t(24, y + 32, title, 12.5, DANGER if danger else INK, UI_SB, ls=1.2))
        b.append(t(24, y + 48, sub, 8.6, INK_3, UI))
        if tog:
            b.append(toggle(316, y + 26, True))
        else:
            b.append(icon("caret-right", 348, y + 34, 12, ACCENT if i == 0 else INK_3))
        b.append(line(24, y + 74, 390, y + 74, LINE, 1.0, 0.45))

    b.append(t(24, 812, "SWIPE DOWN TO RESUME", 8, INK_3, MONO))
    return "".join(b)


def screen_results_phone() -> str:
    b = [backdrop(390, 844)]
    b.append(rect(24, 92, 342, 660, PANEL, LINE, 1.0, 0.96))
    b.append(brackets(24, 92, 342, 660, 14, LINE_HI, 1.2, 0.9))
    b.append(rect(24, 92, 342, 3, ACCENT))
    b.append(label(44, 126, "RUN COMPLETE", ACCENT, 7.6, 1.8))
    b.append(t(44, 176, "WAVE 04", 40, INK, DISPLAY, ls=1.4))
    b.append(t(44, 198, "SECTOR CLEARED", 8.6, INK_2, UI_M, ls=1.6))
    b.append(t(346, 126, "02:14", 9, INK_3, MONO, "end"))
    b.append(line(44, 218, 346, 218, LINE, 1.0, 0.6))

    stats = [("KOs", "12", ""), ("ACCURACY", "38", "%"), ("SHOTS", "54", ""), ("BEST", "07", "")]
    for i, (lab, val, unit) in enumerate(stats):
        col, row = i % 2, i // 2
        x = 44 + col * 158
        y = 254 + row * 78
        b.append(label(x, y, lab, INK_3, 7.6, 1.4))
        b.append(t(x, y + 32, val, 26, INK, MONO))
        if unit:
            b.append(t(x + 34, y + 32, unit, 9, INK_3, MONO))

    b.append(line(44, 410, 346, 410, LINE, 1.0, 0.6))
    b.append(label(44, 438, "EARNED", INK_3, 7.6, 1.6))
    b.append(t(44, 466, "+ 240 BP", 17, ACCENT, MONO))
    b.append(t(346, 466, "TOTAL 1,240", 8.4, INK_3, MONO, "end"))

    b.append(button(44, 512, 302, 56, "RETRY", "primary", icon_name="arrow-counter-clockwise", size=12))
    b.append(button(44, 580, 302, 50, "MAIN MENU", "secondary", icon_name="house", size=10))

    b.append(label(44, 682, "R  RETRY  ·  ESC  MENU", INK_3, 7.4, 1.6))
    return "".join(b)


def screen_settings_phone() -> str:
    b = [backdrop(390, 844)]
    b.append(icon("caret-left", 20, 58, 18, INK_2))
    b.append(t(46, 74, "SETTINGS", 24, INK, DISPLAY, ls=1.6))
    b.append(t(366, 72, "AUTO-SAVE", 7.4, INK_3, MONO, "end"))
    b.append(line(20, 94, 370, 94, LINE, 1.0, 0.6))

    b.append(segmented(20, 116, 350, 36, ["AUDIO", "CTRL", "HUD", "A11Y"], 1))

    rows = [
        ("SENSITIVITY", "slider", "42%"),
        ("AIM ASSIST", "toggle", "ON"),
        ("FIRE MODE", "segment", "HOLD"),
        ("LEFT-HANDED", "toggle", "OFF"),
        ("INVERT LOOK Y", "toggle", "OFF"),
        ("VIBRATION", "toggle", "ON"),
    ]
    for i, (name, kind, text) in enumerate(rows):
        y = 180 + i * 74
        b.append(t(20, y + 20, name, 11, INK, UI_SB, ls=1.2))
        b.append(t(20, y + 36, text, 8.4, INK_3, MONO))
        b.append(line(20, y + 60, 370, y + 60, LINE, 1.0, 0.4))
        if kind == "slider":
            b.append(slider(170, y + 24, 180, 0.42))
        elif kind == "toggle":
            b.append(toggle(324, y + 12, text == "ON"))
        else:
            b.append(segmented(226, y + 4, 140, 30, ["TAP", "HOLD"], 1))

    b.append(button(20, 760, 150, 48, "RESET", "ghost", size=10))
    b.append(button(200, 760, 170, 48, "DONE", "primary", icon_name="check", size=11))
    return "".join(b)


def board_menus_mobile() -> str:
    b = []
    sc = 0.68
    b.append('<g transform="translate(80 150) scale(0.68)">' + screen_settings() + "</g>")
    b.append(rect(80, 150, 870, 490, "none", LINE_HI, 1.2, 0.85))
    b.append(brackets(72, 142, 886, 506, 14, ACCENT, 1.4, 0.8))
    b.append(label(80, 666, "01 / SETTINGS — 1280×720", INK_3, 9.5, 2.0))

    b.append('<g transform="translate(80 700) scale(0.68)">' + screen_hud_editor() + "</g>")
    b.append(rect(80, 700, 870, 490, "none", LINE_HI, 1.2, 0.85))
    b.append(brackets(72, 692, 886, 506, 14, ACCENT, 1.4, 0.8))
    b.append(label(80, 1216, "02 / HUD EDITOR", INK_3, 9.5, 2.0))

    phones = [
        (1020, 150, screen_pause_phone(), "03 / PAUSE — 390×844"),
        (1300, 150, screen_results_phone(), "04 / RESULTS"),
        (1580, 150, screen_settings_phone(), "05 / SETTINGS"),
    ]
    for px_, py_, screen, caption in phones:
        b.append(f'<g transform="translate({px_} {py_}) scale(0.62)">' + screen + "</g>")
        b.append(rect(px_, py_, 242, 523, "none", LINE_HI, 1.2, 0.85))
        b.append(brackets(px_ - 6, py_ - 6, 254, 535, 12, ACCENT, 1.3, 0.8))
        b.append(label(px_, py_ + 545, caption, INK_3, 8.6, 1.6))

    rx, ry = 1020, 740
    b.append(t(rx, ry, "MENU DI HP", 18, INK, DISPLAY, ls=1.2))
    b.append(line(rx, ry + 12, 1856, ry + 12, LINE, 1.0, 0.8))
    items = [
        ("Bottom sheet", "Pause memakai sheet 440px; dunia tetap terlihat."),
        ("Baris 74px", "Lebih tinggi dari 56px karena target ibu jari."),
        ("Swipe down", "Gestur tutup sama dengan tombol resume."),
        ("Tombol penuh", "Aksi utama 302×56; tidak ada tombol kecil."),
        ("Safe area", "Footer 34px di atas gesture bar."),
    ]
    for i, (head, note) in enumerate(items):
        y = ry + 52 + i * 52
        b.append(t(rx, y, head, 10, INK, UI_SB, ls=1.2))
        b.append(t(rx + 130, y, note, 9.4, INK_3, UI))

    b.append(t(rx, ry + 350, "YANG TIDAK DIPAKAI", 18, INK, DISPLAY, ls=1.2))
    b.append(line(rx, ry + 362, 1856, ry + 362, LINE, 1.0, 0.8))
    nope = [
        "Menu bertingkat dengan animasi > 300ms.",
        "Tombol < 44px atau hanya ikon tanpa label di menu.",
        "Slider tanpa angka; pengguna harus tahu nilainya.",
        "Panel penuh yang menutup seluruh dunia 3D.",
    ]
    for i, text in enumerate(nope):
        y = ry + 396 + i * 28
        b.append(icon("x", rx, y - 10, 10, DANGER))
        b.append(t(rx + 18, y, text, 9.4, INK_3, UI))

    return board(
        1920,
        1300,
        "BOARD 06 / 07",
        "Menu lanjutan",
        "Settings dan HUD editor di desktop; pause, hasil, dan settings di 390×844.",
        "".join(b),
    )


# ---------------------------------------------------------------------------
# 07 — Icons
# ---------------------------------------------------------------------------
def board_icons() -> str:
    b = []
    names = sorted(p.stem for p in (ASSETS / "icons" / "regular").glob("*.svg"))
    b.append(t(80, 196, "01 / SET IKON — PHOSPHOR", 18, INK, DISPLAY, ls=1.2))
    b.append(line(80, 208, 1856, 208, LINE, 1.0, 0.8))
    b.append(t(80, 230, "24px grid · stroke 1.5–2 · regular untuk default, fill untuk state aktif", 9.6, INK_3, UI))

    cols = 9
    for i, name in enumerate(names):
        col, row = i % cols, i // cols
        x, y = 80 + col * 118, 258 + row * 86
        b.append(rect(x, y, 104, 70, PANEL, LINE, 1.0, 0.55, rx=2))
        b.append(icon(name, x + 40, y + 9, 24, INK))
        b.append(t(x + 52, y + 56, name, 7.4, INK_3, MONO, "middle"))

    # fill variants
    fy = 258 + ((len(names) + cols - 1) // cols) * 86 + 26
    b.append(t(80, fy, "STATE AKTIF — FILL", 18, INK, DISPLAY, ls=1.2))
    b.append(line(80, fy + 12, 1856, fy + 12, LINE, 1.0, 0.8))
    fills = ["pause", "play", "speaker-high", "speaker-slash", "crosshair", "lightning", "shield",
             "heart", "target", "timer", "skull", "chart-bar", "gear-six", "house", "sliders", "eye"]
    for i, name in enumerate(fills):
        x, y = 80 + i * 108, fy + 36
        b.append(rect(x, y, 96, 66, PANEL, LINE, 1.0, 0.55, rx=2))
        b.append(icon(name, x + 36, y + 9, 24, ACCENT, "fill"))
        b.append(t(x + 48, y + 54, name, 7.0, INK_3, MONO, "middle"))

    # sizes and usage
    sy = fy + 140
    b.append(t(80, sy, "UKURAN & PEMAKAIAN", 18, INK, DISPLAY, ls=1.2))
    b.append(line(80, sy + 12, 1856, sy + 12, LINE, 1.0, 0.8))
    for i, size in enumerate([16, 20, 24, 32]):
        x = 80 + i * 130
        b.append(rect(x, sy + 34, 100, 86, PANEL, LINE, 1.0, 0.7, rx=2))
        b.append(icon("crosshair", x + 50 - size / 2, sy + 40, size, INK))
        b.append(t(x + 50, sy + 106, f"{size}px", 8.6, INK_3, MONO, "middle"))

    uses = [
        ("TOMBOL IKON", "44×44 · ikon 20, tanpa label"),
        ("TOMBOL + TEKS", "ikon 18 · gap 8 · label 13"),
        ("CHIP STATUS", "ikon 12 · label 10"),
        ("HUD", "ikon 16–20 · warna per peran"),
    ]
    for i, (head, note) in enumerate(uses):
        x = 660 + i * 204
        b.append(t(x, sy + 38, head, 8.6, INK, UI_SB, ls=1.4))
        b.append(t(x, sy + 120, note, 8.2, INK_3, UI))

    b.append(rect(660, sy + 54, 44, 44, PANEL_2, LINE_HI, 1.0, 1.0, rx=2))
    b.append(icon("pause", 672, sy + 66, 20, INK_2))
    b.append(rect(864, sy + 54, 160, 44, ACCENT, None, 1.0, 1.0, rx=2))
    b.append(icon("play", 880, sy + 66, 18, ACCENT_INK, "fill"))
    b.append(t(906, sy + 81, "RESUME", 12, ACCENT_INK, UI_SB, ls=1.0))
    b.append(rect(1068, sy + 60, 96, 26, PANEL_2, LINE, 1.0, 0.9, rx=2))
    b.append(icon("skull", 1078, sy + 67, 12, INK_3))
    b.append(t(1094, sy + 78, "12 KOs", 9, INK_2, MONO))
    b.append(icon("crosshair", 1280, sy + 56, 24, INK))
    b.append(t(1316, sy + 76, "24px", 9, INK_3, MONO))

    return board(
        1920,
        1200,
        "BOARD 07 / 07",
        "Set ikon",
        "Phosphor Icons (MIT): 41 glyph yang dipakai, plus aturan ukuran dan pemakaian.",
        "".join(b),
    )


BOARDS = {
    "01-foundation": board_foundation,
    "02-hud-desktop": board_desktop,
    "03-hud-mobile": board_mobile,
    "04-components": board_components,
    "05-menus-desktop": board_menus_desktop,
    "06-menus-mobile": board_menus_mobile,
    "07-icons": board_icons,
}


def main(argv: list[str]) -> None:
    wanted = argv[1:] or list(BOARDS)
    for key in wanted:
        if key not in BOARDS:
            raise SystemExit(f"unknown board: {key}")
        print(f"building {key}")
        render(BOARDS[key](), key)


if __name__ == "__main__":
    main(sys.argv)
