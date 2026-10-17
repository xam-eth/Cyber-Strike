"""Small SVG drawing kit used to build the AEGIS HUD design boards.

The boards are rendered with resvg (no browser required) so the same font files
that ship in the repo drive the mock-ups. Everything is plain SVG: no external
CSS, no JS, no layout engine.
"""

from __future__ import annotations

import os
import re
from pathlib import Path

import resvg_py

ROOT = Path(__file__).resolve().parent.parent
ASSETS = ROOT / "assets"
BOARDS = ROOT / "board"

FONT_FILES = [
    str(ASSETS / "fonts" / "ChakraPetch-SemiBold.ttf"),
    str(ASSETS / "fonts" / "ChakraPetch-Medium.ttf"),
    str(ASSETS / "fonts" / "Barlow-Regular.ttf"),
    str(ASSETS / "fonts" / "Barlow-Medium.ttf"),
    str(ASSETS / "fonts" / "Barlow-SemiBold.ttf"),
    str(ASSETS / "fonts" / "JetBrainsMono-Medium.ttf"),
    str(ASSETS / "fonts" / "JetBrainsMono-Bold.ttf"),
]

# resvg/fontdb resolve a family plus a weight, so each role carries both. The
# names are the real families in the shipped TTFs.
DISPLAY = ("Chakra Petch", 600)
DISPLAY_M = ("Chakra Petch", 500)
UI = ("Barlow", 400)
UI_M = ("Barlow", 500)
UI_SB = ("Barlow", 600)
MONO = ("JetBrains Mono", 400)
MONO_B = ("JetBrains Mono", 700)

# ---------------------------------------------------------------------------
# Tokens
# ---------------------------------------------------------------------------
VOID = "#05080C"
CANVAS = "#070B10"
PANEL = "#0B131B"
PANEL_2 = "#111C26"
PANEL_3 = "#16232E"
LINE = "#27384A"
LINE_HI = "#4E6A7E"
INK = "#EDF5FB"
INK_2 = "#A9BCCB"
INK_3 = "#7C94A6"
ACCENT = "#FFB020"
ACCENT_INK = "#171005"
OK = "#37E08C"
INFO = "#54C8FF"
DANGER = "#FF5A5A"
ABILITY = "#B79CFF"
WHITE = "#FFFFFF"

TOKEN_COLORS = [
    ("void", VOID, "kanvas / letterbox"),
    ("panel", PANEL, "kartu HUD 92%"),
    ("panel-2", PANEL_2, "permukaan naik"),
    ("line", LINE, "hairline 1px"),
    ("line-hi", LINE_HI, "border fokus"),
    ("ink", INK, "teks utama"),
    ("ink-2", INK_2, "teks sekunder"),
    ("ink-3", INK_3, "caption"),
    ("accent", ACCENT, "aksi / fokus"),
    ("ok", OK, "health"),
    ("info", INFO, "armor"),
    ("danger", DANGER, "damage"),
    ("ability", ABILITY, "EMP"),
]

_ICONS: dict[tuple[str, str], str] = {}


def esc(value: object) -> str:
    return (
        str(value)
        .replace("&", "&amp;")
        .replace("<", "&lt;")
        .replace(">", "&gt;")
        .replace('"', "&quot;")
    )


def _icon_paths(name: str, style: str) -> str:
    key = (name, style)
    if key in _ICONS:
        return _ICONS[key]
    path = ASSETS / "icons" / style / f"{name}.svg"
    if not path.exists():
        path = ASSETS / "icons" / "regular" / f"{name}.svg"
    text = path.read_text(encoding="utf-8")
    ds = re.findall(r'<path[^>]*\sd="([^"]+)"', text)
    _ICONS[key] = "".join(ds)
    return _ICONS[key]


def icon(
    name: str,
    x: float,
    y: float,
    size: float = 24,
    color: str = INK,
    style: str = "regular",
    opacity: float = 1.0,
) -> str:
    d = _icon_paths(name, style)
    scale = size / 256.0
    return (
        f'<g transform="translate({x:.2f} {y:.2f}) scale({scale:.5f})" '
        f'fill="{color}" opacity="{opacity}"><path d="{d}"/></g>'
    )


def t(
    x: float,
    y: float,
    s: object,
    size: float = 14,
    fill: str = INK,
    family: str | tuple[str, int] = UI,
    anchor: str = "start",
    ls: float = 0.0,
    opacity: float = 1.0,
    weight: str | None = None,
) -> str:
    if isinstance(family, tuple):
        family, family_weight = family
        if weight is None:
            weight = str(family_weight)
    extra = ""
    if anchor != "start":
        extra += f' text-anchor="{anchor}"'
    if ls:
        extra += f' letter-spacing="{ls:.2f}"'
    if opacity != 1.0:
        extra += f' opacity="{opacity:.2f}"'
    if weight:
        extra += f' font-weight="{weight}"'
    return (
        f'<text x="{x:.2f}" y="{y:.2f}" font-family="{family}" font-size="{size:.1f}" '
        f'fill="{fill}"{extra}>{esc(s)}</text>'
    )


def tc(
    x: float,
    cy: float,
    s: object,
    size: float = 14,
    fill: str = INK,
    family: str | tuple[str, int] = UI,
    anchor: str = "start",
    ls: float = 0.0,
    opacity: float = 1.0,
) -> str:
    """Text vertically centred on `cy` by shifting the baseline."""
    return t(x, cy + size * 0.355, s, size, fill, family, anchor, ls, opacity)


def label(x: float, y: float, s: object, fill: str = INK_3, size: float = 11, ls: float = 1.4) -> str:
    return t(x, y, s, size, fill, UI_M, ls=ls)


def rect(
    x: float,
    y: float,
    w: float,
    h: float,
    fill: str = "none",
    stroke: str | None = None,
    sw: float = 1.0,
    op: float = 1.0,
    rx: float = 0.0,
    dash: str | None = None,
) -> str:
    a = f'<rect x="{x:.2f}" y="{y:.2f}" width="{w:.2f}" height="{h:.2f}" fill="{fill}"'
    if rx:
        a += f' rx="{rx:.2f}"'
    if stroke:
        a += f' stroke="{stroke}" stroke-width="{sw}"'
    if dash:
        a += f' stroke-dasharray="{dash}"'
    if op != 1.0:
        a += f' opacity="{op:.3f}"'
    return a + "/>"


def line(
    x1: float,
    y1: float,
    x2: float,
    y2: float,
    stroke: str = LINE,
    sw: float = 1.0,
    op: float = 1.0,
    dash: str | None = None,
) -> str:
    a = (
        f'<line x1="{x1:.2f}" y1="{y1:.2f}" x2="{x2:.2f}" y2="{y2:.2f}" '
        f'stroke="{stroke}" stroke-width="{sw}"'
    )
    if dash:
        a += f' stroke-dasharray="{dash}"'
    if op != 1.0:
        a += f' opacity="{op:.3f}"'
    return a + "/>"


def circle(
    cx: float,
    cy: float,
    r: float,
    fill: str = "none",
    stroke: str | None = None,
    sw: float = 1.0,
    op: float = 1.0,
) -> str:
    a = f'<circle cx="{cx:.2f}" cy="{cy:.2f}" r="{r:.2f}" fill="{fill}"'
    if stroke:
        a += f' stroke="{stroke}" stroke-width="{sw}"'
    if op != 1.0:
        a += f' opacity="{op:.3f}"'
    return a + "/>"


def ring(
    cx: float,
    cy: float,
    r: float,
    value: float,
    color: str = ACCENT,
    track: str = LINE,
    sw: float = 3.0,
    start: float = -90.0,
) -> str:
    import math

    value = max(0.0, min(1.0, value))
    circ = 2 * math.pi * r
    a = (
        f'<circle cx="{cx:.2f}" cy="{cy:.2f}" r="{r:.2f}" fill="none" '
        f'stroke="{track}" stroke-width="{sw}" opacity="0.75"/>'
    )
    a += (
        f'<circle cx="{cx:.2f}" cy="{cy:.2f}" r="{r:.2f}" fill="none" stroke="{color}" '
        f'stroke-width="{sw}" stroke-dasharray="{circ * value:.2f} {circ:.2f}" '
        f'transform="rotate({start:.1f} {cx:.2f} {cy:.2f})" stroke-linecap="butt"/>'
    )
    return a


def brackets(
    x: float,
    y: float,
    w: float,
    h: float,
    size: float = 10,
    color: str = LINE_HI,
    sw: float = 1.2,
    op: float = 1.0,
) -> str:
    out = []
    corners = [
        (x, y, 1, 1),
        (x + w, y, -1, 1),
        (x, y + h, 1, -1),
        (x + w, y + h, -1, -1),
    ]
    for cx, cy, dx, dy in corners:
        out.append(line(cx, cy, cx + dx * size, cy, color, sw, op))
        out.append(line(cx, cy, cx, cy + dy * size, color, sw, op))
    return "".join(out)


def panel(
    x: float,
    y: float,
    w: float,
    h: float,
    fill: str = PANEL,
    op: float = 0.92,
    stroke: str | None = LINE,
    br: bool = True,
    bsize: float = 10,
    bcolor: str = LINE_HI,
    accent_edge: str | None = None,
) -> str:
    out = [rect(x, y, w, h, fill, stroke, 1.0, op)]
    if br:
        out.append(brackets(x, y, w, h, bsize, bcolor, 1.2, 0.95))
    if accent_edge:
        out.append(rect(x, y + 0.0, 2, h, accent_edge, op=1.0))
    return "".join(out)


def bar(
    x: float,
    y: float,
    w: float,
    h: float,
    value: float,
    color: str = OK,
    track: str = "#071017",
    ticks: int = 0,
    tick_color: str = PANEL,
) -> str:
    value = max(0.0, min(1.0, value))
    out = [rect(x, y, w, h, track)]
    if value > 0:
        out.append(rect(x, y, max(w * value, 1.0), h, color))
    if ticks:
        for i in range(1, ticks):
            tx = x + w * i / ticks
            out.append(rect(tx, y, 1.0, h, tick_color, op=0.9))
    return "".join(out)


def keycap(x: float, y: float, w: float, h: float, text: str, size: float = 11) -> str:
    out = [
        rect(x, y, w, h, PANEL_2, LINE_HI, 1.0, 0.98, rx=2),
        rect(x + 1, y + h - 2, w - 2, 1, LINE, op=0.8),
        tc(x + w / 2, y + h / 2, text, size, INK_2, MONO, "middle"),
    ]
    return "".join(out)


def chip(
    x: float,
    y: float,
    w: float,
    h: float,
    text: str,
    color: str = INK_2,
    fill: str = PANEL_2,
    border: str = LINE,
    size: float = 10,
    icon_name: str | None = None,
    icon_color: str | None = None,
) -> str:
    out = [rect(x, y, w, h, fill, border, 1.0, 0.96, rx=2)]
    tx = x + 10
    if icon_name:
        out.append(icon(icon_name, x + 8, y + (h - 14) / 2, 14, icon_color or color))
        tx = x + 28
    out.append(tc(tx, y + h / 2, text, size, color, UI_M, ls=0.9))
    return "".join(out)


def button(
    x: float,
    y: float,
    w: float,
    h: float,
    text: str,
    kind: str = "primary",
    state: str = "default",
    icon_name: str | None = None,
    size: float = 13,
) -> str:
    """Button specimen for the component board."""
    enabled = state != "disabled"
    if state == "focus":
        focus = True
    else:
        focus = False
    if state == "active":
        active = True
    else:
        active = False

    if kind == "primary":
        bg = ACCENT
        fg = ACCENT_INK
        border = None
        if state == "hover":
            bg = "#FFC24B"
        elif state == "pressed":
            bg = "#E89A12"
        elif state == "disabled":
            bg = "#3A2E18"
            fg = "#8A7A5C"
        elif active:
            bg = "#F0A31C"
        if focus:
            bg = ACCENT
    elif kind == "secondary":
        bg = PANEL_2
        fg = INK
        border = LINE_HI if state in ("hover", "focus") else LINE
        if state == "hover":
            bg = PANEL_3
        elif state == "pressed":
            bg = "#0A1219"
        elif state == "disabled":
            bg = "#0C141B"
            fg = "#5B7284"
            border = "#1B2A36"
        elif active:
            bg = "#1B2A36"
            border = ACCENT
            fg = ACCENT
    elif kind == "ghost":
        bg = "none"
        fg = INK_2 if enabled else "#4E6476"
        border = None
        if state == "hover":
            bg = PANEL_2
            fg = INK
        elif state == "pressed":
            bg = "#0A1219"
        elif active:
            fg = ACCENT
        if focus:
            border = ACCENT
    else:  # danger
        bg = "none"
        fg = DANGER
        border = DANGER if state in ("hover", "focus", "pressed") else "#5A2A2C"
        if state == "hover":
            bg = "#23100F"
        elif state == "pressed":
            bg = "#2E1211"
        elif state == "disabled":
            fg = "#6B4144"
            border = "#332023"

    out = []
    if bg != "none":
        out.append(rect(x, y, w, h, bg, border, 1.0, 1.0, rx=2))
    elif border:
        out.append(rect(x, y, w, h, "none", border, 1.0, 1.0, rx=2))
    if kind == "secondary" and active:
        out.append(rect(x, y, 2, h, ACCENT))
    if focus:
        out.append(rect(x - 3, y - 3, w + 6, h + 6, "none", ACCENT, 1.5, 0.9, rx=3))
    tx = x + w / 2
    if icon_name:
        icon_size = 18
        label_w = len(str(text)) * size * 0.52
        total = icon_size + (8 if text else 0) + label_w
        start = x + (w - total) / 2
        out.append(icon(icon_name, start, y + (h - icon_size) / 2, icon_size, fg))
        out.append(tc(start + icon_size + 8, y + h / 2, text, size, fg, UI_SB, ls=0.9))
    else:
        out.append(tc(tx, y + h / 2, text, size, fg, UI_SB, "middle", 0.9))
    return "".join(out)


def arrow(x: float, y: float, w: float = 34, color: str = LINE_HI) -> str:
    return (
        line(x, y, x + w, y, color, 1.0, 0.9)
        + f'<path d="M{x + w - 6:.1f} {y - 4:.1f} L{x + w:.1f} {y:.1f} L{x + w - 6:.1f} {y + 4:.1f}" '
        f'fill="none" stroke="{color}" stroke-width="1.2"/>'
    )


# ---------------------------------------------------------------------------
# Document helpers
# ---------------------------------------------------------------------------
def defs(extra: str = "") -> str:
    return (
        "<defs>"
        '<linearGradient id="bg" x1="0" y1="0" x2="0" y2="1">'
        f'<stop offset="0" stop-color="#0A1218"/>'
        f'<stop offset="1" stop-color="{CANVAS}"/>'
        "</linearGradient>"
        '<linearGradient id="scrimTop" x1="0" y1="0" x2="0" y2="1">'
        '<stop offset="0" stop-color="#05080C" stop-opacity="0.82"/>'
        '<stop offset="1" stop-color="#05080C" stop-opacity="0"/>'
        "</linearGradient>"
        '<linearGradient id="scrimBottom" x1="0" y1="0" x2="0" y2="1">'
        '<stop offset="0" stop-color="#05080C" stop-opacity="0"/>'
        '<stop offset="1" stop-color="#05080C" stop-opacity="0.92"/>'
        "</linearGradient>"
        '<linearGradient id="fadeRight" x1="0" y1="0" x2="1" y2="0">'
        f'<stop offset="0" stop-color="{PANEL}" stop-opacity="0.0"/>'
        f'<stop offset="0.55" stop-color="{PANEL}" stop-opacity="0.86"/>'
        f'<stop offset="1" stop-color="{PANEL}" stop-opacity="0.96"/>'
        "</linearGradient>"
        '<radialGradient id="vignette" cx="0.5" cy="0.5" r="0.75">'
        '<stop offset="0.55" stop-color="#000000" stop-opacity="0"/>'
        '<stop offset="1" stop-color="#000000" stop-opacity="0.45"/>'
        "</radialGradient>"
        '<pattern id="grid" width="48" height="48" patternUnits="userSpaceOnUse">'
        f'<path d="M48 0H0V48" fill="none" stroke="{LINE}" stroke-width="1" opacity="0.20"/>'
        "</pattern>"
        f"{extra}"
        "</defs>"
    )


def board(w: int, h: int, index: str, title: str, subtitle: str, body: str, extra_defs: str = "") -> str:
    head = (
        f'<svg xmlns="http://www.w3.org/2000/svg" xmlns:xlink="http://www.w3.org/1999/xlink" '
        f'width="{w}" height="{h}" viewBox="0 0 {w} {h}">'
        + defs(extra_defs)
        + rect(0, 0, w, h, "url(#bg)")
        + rect(0, 0, w, h, "url(#grid)", op=0.35)
        + rect(0, 0, w, 3, ACCENT, op=0.85)
        + label(80, 62, "AEGIS // SISTEM ANTARMUKA TEMPUR", INK_3, 11, 2.2)
        + t(80, 112, title, 40, INK, DISPLAY, ls=1.0)
        + t(80, 142, subtitle, 14, INK_2, UI)
        + t(w - 80, 62, index, 12, INK_3, MONO, "end", 1.6)
        + t(w - 80, 84, "CYBER-STRIKE · BAY 07 · 2026-10", 11, INK_3, UI_M, "end", 0.8)
    )
    foot = (
        line(80, h - 56, w - 80, h - 56, LINE, 1.0, 0.7)
        + t(80, h - 32, "Proposal desain — belum ada perubahan pada kode game.", 11, INK_3, UI)
        + t(w - 80, h - 32, "docs/ui-redesign/", 11, INK_3, MONO, "end")
        + "</svg>"
    )
    return head + body + foot


def render(svg: str, out_stem: str) -> Path:
    BOARDS.mkdir(parents=True, exist_ok=True)
    svg_path = BOARDS / f"{out_stem}.svg"
    svg_path.write_text(svg, encoding="utf-8")
    png = resvg_py.svg_to_bytes(
        svg_string=svg,
        font_files=FONT_FILES,
        resources_dir=str(ASSETS),
        shape_rendering="geometric_precision",
        text_rendering="optimize_legibility",
    )
    png_path = BOARDS / f"{out_stem}.png"
    png_path.write_bytes(bytes(png))
    print(f"  {out_stem}: {os.path.getsize(png_path) // 1024} KB")
    return png_path
