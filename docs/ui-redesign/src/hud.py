"""HUD compositions: desktop 1280x720, phone 390x844, landscape 844x390.

These are the same layouts the Godot implementation will have to reproduce, so
every number here is a spec value, not decoration.
"""

from __future__ import annotations

from kit import (
    ABILITY,
    ACCENT,
    ACCENT_INK,
    DANGER,
    INFO,
    INK,
    INK_2,
    INK_3,
    LINE,
    LINE_HI,
    MONO,
    OK,
    PANEL,
    PANEL_2,
    PANEL_3,
    DISPLAY,
    UI,
    UI_M,
    UI_SB,
    WHITE,
    bar,
    brackets,
    chip,
    circle,
    icon,
    keycap,
    label,
    line,
    panel,
    rect,
    ring,
    t,
    tc,
)

DEFAULT = dict(
    health=0.82,
    armor=0.40,
    ammo=24,
    reserve=96,
    weapon="ARC-07",
    weapon_type="PLASMA RIFLE",
    slot=1,
    wave=3,
    left=7,
    total=18,
    score="1,240",
    time="02:14",
    emp=1.0,
    ads=False,
    hint=True,
)


def _plate(name: str, w: int, h: int, ox: float = 0, oy: float = 0) -> str:
    return (
        f'<image x="{ox}" y="{oy}" width="{w}" height="{h}" '
        f'preserveAspectRatio="xMidYMid slice" href="{name}"/>'
    )


def reticle(cx: float, cy: float, gap: float = 12, tick: float = 6, color: str = INK) -> str:
    out = []
    for dx, dy in ((0, -1), (0, 1), (-1, 0), (1, 0)):
        x1, y1 = cx + dx * gap, cy + dy * gap
        x2, y2 = cx + dx * (gap + tick), cy + dy * (gap + tick)
        out.append(line(x1, y1, x2, y2, "#05080C", 4.0, 0.45))
        out.append(line(x1, y1, x2, y2, color, 1.5, 0.98))
    out.append(circle(cx, cy, 2.2, "#05080C", op=0.5))
    out.append(circle(cx, cy, 1.2, color))
    return "".join(out)


# ---------------------------------------------------------------------------
# Desktop 1280 x 720
# ---------------------------------------------------------------------------
def hud_desktop(s: dict | None = None) -> str:
    s = {**DEFAULT, **(s or {})}
    health = s["health"]
    hcolor = DANGER if health <= 0.35 else OK
    out = []

    # 1 ── vitals ────────────────────────────────────────────────────────────
    out.append(panel(20, 20, 268, 64, accent_edge=hcolor))
    out.append(label(34, 37, "VITALS", INK_3, 10, 1.9))
    out.append(t(244, 40, f"{round(health * 100)}", 18, INK, MONO, "end"))
    out.append(t(274, 40, "/100", 9.5, INK_3, MONO, "end"))
    out.append(icon("heart", 33, 42, 11, hcolor, opacity=0.95))
    out.append(icon("shield", 34, 51, 9, INFO if s["armor"] > 0 else INK_3, opacity=0.95))
    out.append(bar(54, 44, 220, 6, health, hcolor, ticks=4))
    out.append(bar(54, 54, 220, 3, s["armor"], INFO))

    # 2 ── objective ─────────────────────────────────────────────────────────
    ox, oy, ow, oh = 490, 20, 300, 44
    out.append(panel(ox, oy, ow, oh))
    out.append(icon("target", ox + 12, oy + 14, 16, ACCENT))
    out.append(label(ox + 38, oy + 15, "WAVE", INK_3, 8.6, 2.4))
    out.append(t(ox + 38, oy + 37, f"{s['wave']:02d}", 20, INK, DISPLAY, ls=1.2))
    out.append(label(ox + ow - 12, oy + 15, "HOSTILES", INK_3, 8.2, 2.0))
    out.append(t(ox + ow - 12, oy + 36, f"{s['left']} LEFT", 12, INK_2, MONO, "end"))
    killed = max(0.0, 1.0 - s["left"] / max(1, s["total"]))
    out.append(bar(ox, oy + oh, ow, 2, killed, ACCENT, track="#0A1219", ticks=10))

    # 3 ── system / score ────────────────────────────────────────────────────
    for bx, name in ((1216, "pause"), (1164, "speaker-high")):
        out.append(rect(bx, 20, 44, 44, PANEL, LINE, 1.0, 0.92))
        out.append(brackets(bx, 20, 44, 44, 7, LINE_HI, 1.0, 0.8))
        out.append(icon(name, bx + 12, 32, 20, INK_2))
    out.append(rect(1116, 72, 144, 30, PANEL, LINE, 1.0, 0.88))
    out.append(icon("skull", 1126, 80, 12, INK_3))
    out.append(t(1144, 91, s["score"], 12, INK, MONO))
    out.append(icon("timer", 1194, 80, 12, INK_3))
    out.append(t(1212, 91, s["time"], 12, INK_2, MONO))

    # 5 ── ability + ADS + weapon ────────────────────────────────────────────
    out.append(rect(1004, 580, 76, 36, PANEL, LINE, 1.0, 0.92))
    ads_color = ACCENT if s["ads"] else INK_2
    out.append(icon("crosshair", 1012, 590, 16, ads_color))
    out.append(t(1032, 601, "ADS", 10, INK_2, UI_SB, ls=1.4))
    if s["ads"]:
        out.append(rect(1004, 580, 2, 36, ACCENT))

    out.append(rect(1088, 580, 172, 36, PANEL, LINE, 1.0, 0.92))
    out.append(icon("lightning", 1100, 589, 17, ABILITY))
    out.append(t(1124, 601, "EMP", 11, INK, UI_SB, ls=1.6))
    ready = s["emp"] >= 0.999
    out.append(
        t(
            1248,
            600,
            "READY" if ready else f"{s['emp'] * 100:.0f}%",
            9,
            OK if ready else INK_2,
            UI_M,
            "end",
            1.4,
        )
    )
    out.append(bar(1100, 608, 148, 2, s["emp"], ABILITY, track="#0A1219"))
    out.append(ring(1240, 598, 0, 0))  # keeps imports honest; no-op

    out.append(panel(992, 624, 268, 76, accent_edge=ACCENT))
    out.append(t(1006, 650, s["weapon"], 17, INK, DISPLAY, ls=1.0))
    out.append(label(1006, 664, s["weapon_type"], INK_3, 8.2, 1.8))
    out.append(t(1212, 656, f"{s['ammo']}", 30, INK, MONO, "end"))
    out.append(t(1246, 656, f"/{s['reserve']}", 11, INK_3, MONO, "end"))
    out.append(label(1246, 670, "RESERVE", INK_3, 6.8, 1.5, ))
    for i in range(3):
        x = 1006 + i * 26
        active = (i + 1) == s["slot"]
        out.append(rect(x, 676, 20, 14, ACCENT if active else "none", None if active else LINE, 1.0, 1.0, rx=1))
        out.append(tc(x + 10, 683, str(i + 1), 9, ACCENT_INK if active else INK_3, MONO, "middle"))

    # 6 ── keyboard legend (desktop only) ────────────────────────────────────
    legend = [
        ("WASD", 34, "MOVE"),
        ("SHIFT", 40, "SPRINT"),
        ("SPACE", 46, "JUMP"),
        ("RMB", 32, "AIM"),
    ]
    x = 20
    for key, kw, name in legend:
        out.append(keycap(x, 672, kw, 22, key, 8.6))
        out.append(label(x, 706, name, INK_3, 7.4, 1.4))
        x += kw + 10

    # reticle
    out.append(reticle(640, 360))
    return "".join(out)


def frame_desktop(plate: str = "plates/plate-desktop.png", state: dict | None = None) -> str:
    return (
        _plate(plate, 1280, 720)
        + rect(0, 0, 1280, 210, "url(#scrimTop)")
        + rect(0, 590, 1280, 130, "url(#scrimBottom)")
        + hud_desktop(state)
        + rect(0, 0, 1280, 720, "url(#vignette)", op=0.35)
    )


# ---------------------------------------------------------------------------
# Phone portrait 390 x 844
# ---------------------------------------------------------------------------
def hud_phone(s: dict | None = None) -> str:
    s = {**DEFAULT, **(s or {})}
    health = s["health"]
    hcolor = DANGER if health <= 0.35 else OK
    out = []

    # status rail
    out.append(panel(12, 44, 168, 48, accent_edge=hcolor))
    out.append(icon("heart", 22, 51, 12, hcolor))
    out.append(t(41, 68, f"{round(health * 100)}", 17, INK, MONO))
    out.append(t(78, 68, "/100", 8, INK_3, MONO))
    out.append(bar(22, 74, 146, 4, health, hcolor, ticks=4))
    out.append(bar(22, 81, 146, 2, s["armor"], INFO))

    out.append(panel(190, 44, 88, 48))
    out.append(t(200, 62, f"WAVE {s['wave']:02d}", 10.5, INK, UI_SB, ls=1.0))
    out.append(t(200, 79, f"{s['left']} LEFT", 10, ACCENT, MONO))

    out.append(rect(334, 46, 44, 44, PANEL, LINE, 1.0, 0.92))
    out.append(brackets(334, 46, 44, 44, 7, LINE_HI, 1.0, 0.8))
    out.append(icon("pause", 346, 58, 20, INK_2))

    if s["hint"]:
        out.append(rect(24, 118, 342, 30, PANEL, LINE, 1.0, 0.9, rx=2))
        out.append(icon("info", 36, 127, 12, ACCENT))
        out.append(t(54, 137, "Drag left to move  ·  hold FIRE to shoot", 10.2, INK_2, UI_M))

    # left thumb: joystick
    jx, jy = 84, 738
    out.append(circle(jx, jy, 64, "#05080C", LINE_HI, 1.4, 0.36))
    out.append(circle(jx, jy, 63, "none", WHITE, 1.0, 0.10))
    out.append(circle(jx, jy, 38, "none", LINE_HI, 1.0, 0.25))
    out.append(circle(jx, jy, 26, PANEL_2, LINE_HI, 1.2, 0.92))
    for name, dx, dy in (
        ("caret-left", -1, 0),
        ("caret-right", 1, 0),
    ):
        out.append(icon(name, jx + dx * 52 - 5, jy + dy * 52 - 5, 10, INK_3, opacity=0.7))

    # right thumb: fire / aim / emp / weapon
    fx, fy = 326, 748
    out.append(circle(fx, fy, 51, "none", WHITE, 1.0, 0.16))
    out.append(circle(fx, fy, 46, ACCENT))
    out.append(circle(fx, fy, 46, "none", WHITE, 1.0, 0.10))
    out.append(icon("crosshair", fx - 14, fy - 14, 28, ACCENT_INK))

    ax, ay = 326, 640
    out.append(circle(ax, ay, 28, PANEL, LINE, 1.0, 0.94))
    if s["ads"]:
        out.append(circle(ax, ay, 31, "none", ACCENT, 1.4, 0.9))
    out.append(icon("crosshair-simple", ax - 9, ay - 9, 18, ACCENT if s["ads"] else INK_2))
    out.append(tc(ax, ay + 18, "AIM", 6.4, INK_3, UI_M, "middle", 1.0))

    ex, ey = 232, 700
    out.append(ring(ex, ey, 33, s["emp"], ABILITY, LINE, 2.0))
    out.append(circle(ex, ey, 28, PANEL, LINE, 1.0, 0.94))
    out.append(icon("lightning", ex - 9, ey - 9, 18, ABILITY))
    out.append(tc(ex, ey + 19, "EMP", 6.4, INK_3, UI_M, "middle", 1.0))

    wx, wy = 232, 616
    out.append(circle(wx, wy, 24, PANEL, LINE, 1.0, 0.94))
    out.append(icon("swap", wx - 8, wy - 8, 16, INK_2))
    out.append(tc(wx, wy + 17, "SWAP", 6.2, INK_3, UI_M, "middle", 1.0))

    out.append(reticle(195, 392, gap=10.5, tick=5.5))
    return "".join(out)


def frame_phone(plate: str = "plates/plate-mobile.png", state: dict | None = None, safe_area: bool = True) -> str:
    out = (
        _plate(plate, 390, 844)
        + rect(0, 0, 390, 150, "url(#scrimTop)")
        + rect(0, 640, 390, 204, "url(#scrimBottom)")
        + hud_phone(state)
    )
    if safe_area:
        out += rect(135, 826, 120, 4, WHITE, op=0.28, rx=2)
    return out


# ---------------------------------------------------------------------------
# Phone landscape 844 x 390
# ---------------------------------------------------------------------------
def hud_landscape(s: dict | None = None) -> str:
    s = {**DEFAULT, **(s or {})}
    health = s["health"]
    hcolor = DANGER if health <= 0.35 else OK
    out = []

    out.append(panel(44, 16, 196, 44, accent_edge=hcolor))
    out.append(icon("heart", 54, 22, 11, hcolor))
    out.append(t(72, 38, f"{round(health * 100)}", 15, INK, MONO))
    out.append(t(104, 38, "/100", 8, INK_3, MONO))
    out.append(bar(54, 44, 172, 4, health, hcolor, ticks=4))

    out.append(panel(372, 16, 100, 44))
    out.append(t(382, 34, f"WAVE {s['wave']:02d}", 9.5, INK, UI_SB, ls=0.9))
    out.append(t(382, 50, f"{s['left']} LEFT", 9, ACCENT, MONO))

    out.append(rect(756, 14, 44, 44, PANEL, LINE, 1.0, 0.92))
    out.append(brackets(756, 14, 44, 44, 7, LINE_HI, 1.0, 0.8))
    out.append(icon("pause", 768, 26, 20, INK_2))

    jx, jy = 120, 300
    out.append(circle(jx, jy, 56, "#05080C", LINE_HI, 1.2, 0.34))
    out.append(circle(jx, jy, 34, "none", LINE_HI, 1.0, 0.25))
    out.append(circle(jx, jy, 23, PANEL_2, LINE_HI, 1.2, 0.92))

    fx, fy = 760, 300
    out.append(circle(fx, fy, 44, "none", WHITE, 1.0, 0.16))
    out.append(circle(fx, fy, 40, ACCENT))
    out.append(icon("crosshair", fx - 12, fy - 12, 24, ACCENT_INK))

    ax, ay = 760, 212
    out.append(circle(ax, ay, 24, PANEL, LINE, 1.0, 0.94))
    out.append(icon("crosshair-simple", ax - 8, ay - 8, 16, ACCENT if s["ads"] else INK_2))

    ex, ey = 672, 262
    out.append(ring(ex, ey, 28, s["emp"], ABILITY, LINE, 2.0))
    out.append(circle(ex, ey, 24, PANEL, LINE, 1.0, 0.94))
    out.append(icon("lightning", ex - 8, ey - 8, 16, ABILITY))

    wx, wy = 672, 190
    out.append(circle(wx, wy, 20, PANEL, LINE, 1.0, 0.94))
    out.append(icon("swap", wx - 7, wy - 7, 14, INK_2))

    out.append(reticle(422, 195, gap=10, tick=5))
    return "".join(out)


def frame_landscape(plate: str = "plates/plate-landscape.png", state: dict | None = None) -> str:
    return (
        _plate(plate, 844, 390)
        + rect(0, 0, 844, 110, "url(#scrimTop)")
        + rect(0, 250, 844, 140, "url(#scrimBottom)")
        + hud_landscape(state)
    )
