"""PBR surface library for the Aetherfall world enrichment pass.

Every generator returns explicit channels — albedo, height, roughness,
metallic — instead of deriving everything from luminance, so the maps can tell
a material story: cavities hold grime, worn edges polish to bright metal,
frost raises roughness on stone and lowers it on ice. All maps are procedural
(no scans), authored for the Aetherfall dark sci-fi palette: cold steel,
glacial blue mineral, hazard orange, cyan energy.

Usage (bpy build scripts):

    from pbr_lib import surface_set, build_material

    maps = surface_set("deck")                       # dict of numpy arrays
    build_material("PaintedSteel", maps, tex_scale=0.5)
"""

import math
import os
import sys

import numpy as np
from PIL import Image as PILImage

# ---------------------------------------------------------------------------
# shared noise helpers
# ---------------------------------------------------------------------------


def _value_noise(rng, size, res):
    """Bicubic-upsampled value noise in [0,1]."""
    pixels = (rng.random((res, res)) * 255).astype(np.uint8)
    return np.asarray(
        PILImage.fromarray(pixels).resize((size, size), PILImage.Resampling.BICUBIC),
        dtype=np.float32,
    ) / 255.0


def _fbm(rng, size, octaves=5, base=4, gain=0.5, lacunarity=2.0):
    total = np.zeros((size, size), np.float32)
    amp, res = 1.0, base
    norm = 0.0
    for _ in range(octaves):
        total += _value_noise(rng, size, int(res)) * amp
        norm += amp
        amp *= gain
        res *= lacunarity
    return total / norm


def _warp(field, dx, dy, amount):
    """Domain-warp a field by two offset noise fields (tileable-ish)."""
    size = field.shape[0]
    yy, xx = np.mgrid[0:size, 0:size].astype(np.float32) / size
    sx = np.clip((xx + (dx - 0.5) * amount) * size, 0, size - 1).astype(np.int32)
    sy = np.clip((yy + (dy - 0.5) * amount) * size, 0, size - 1).astype(np.int32)
    return field[sy, sx]


def _smoothstep(edge0, edge1, x):
    t = np.clip((x - edge0) / max(edge1 - edge0, 1e-6), 0.0, 1.0)
    return t * t * (3.0 - 2.0 * t)


def _scratches(rng, size, count, length, width, strength):
    """Thin bright/dark scratch lines as a signed height contribution."""
    height = np.zeros((size, size), np.float32)
    for _ in range(count):
        t = np.linspace(0, 1, int(rng.uniform(length * 0.4, length)))
        x0, y0 = rng.uniform(0, 1), rng.uniform(0, 1)
        xs = (x0 + t * rng.uniform(-1, 1) * length * 0.9) % 1.0
        ys = (y0 + t * rng.uniform(-1, 1) * length * 0.9) % 1.0
        px = (xs * size).astype(np.int32) % size
        py = (ys * size).astype(np.int32) % size
        for step in range(len(px) - 1):
            x1, x2 = px[step], px[step + 1]
            y1, y2 = py[step], py[step + 1]
            steps = max(abs(x2 - x1), abs(y2 - y1), 1)
            for s in range(steps + 1):
                xi = (x1 + (x2 - x1) * s // steps) % size
                yi = (y1 + (y2 - y1) * s // steps) % size
                height[yi, xi] += strength * rng.uniform(0.6, 1.0)
                for w in range(1, width):
                    height[(yi + w) % size, xi] += strength * 0.35
    return height


def _streaks_down(rng, size, count, dark=True):
    """Vertical weathering streaks (rust drips, efflorescence, grime runs)."""
    layer = np.zeros((size, size), np.float32)
    for _ in range(count):
        x0 = rng.uniform(0, 1)
        w = rng.uniform(0.004, 0.02)
        y0 = rng.uniform(-0.2, 0.5)
        length = rng.uniform(0.3, 1.1)
        y = np.mgrid[0:size, 0:size][0] / size
        x = np.mgrid[0:size, 0:size][1] / size
        band = np.exp(-((x - x0) ** 2) / (2 * w * w))
        window = np.clip((y - y0) / length, 0, 1) * np.clip((y0 + length - y) / (length * 0.35), 0, 1)
        layer += band * window * rng.uniform(0.4, 1.0)
    return layer if dark else layer


def _normal_from_height(height, strength):
    dy, dx = np.gradient(height.astype(np.float32))
    nx = -dx * strength
    ny = -dy * strength
    nz = np.ones_like(height, dtype=np.float32)
    length = np.sqrt(nx * nx + ny * ny + nz * nz)
    normal = np.empty((*height.shape, 4), np.float32)
    normal[..., 0] = nx / length * 0.5 + 0.5
    normal[..., 1] = ny / length * 0.5 + 0.5
    normal[..., 2] = nz / length * 0.5 + 0.5
    normal[..., 3] = 1.0
    return normal


def _cavity_ao(height, radius=6, strength=1.0):
    """Cheap cavity map: blurred height minus local height."""
    from PIL import ImageFilter as _IF
    img = PILImage.fromarray((np.clip(height, 0, 1) * 255).astype(np.uint8))
    blur = np.asarray(img.filter(_IF.GaussianBlur(radius)), dtype=np.float32) / 255.0
    cavity = np.clip(0.5 + (height - blur) * strength * 2.0, 0.0, 1.0)
    return 0.35 + cavity * 0.65


# ---------------------------------------------------------------------------
# surface generators — each returns dict(arr, height, rough, metal, strength)
# ---------------------------------------------------------------------------


def _wrap_tex(fn):
    def wrapped(size=1024):
        return fn(size)

    return wrapped


@_wrap_tex
def tex_deck(size):
    """Painted armour deck plate: major/minor panel grid, recessed seams,
    bolt rings, traffic polish and chipped paint over steel."""
    rng = np.random.default_rng(7)
    y, x = np.mgrid[0:size, 0:size].astype(np.float32) / size
    grime = _fbm(rng, size, 5, 3)
    micro = rng.normal(0, 0.012, (size, size))

    # two-scale panel grid: 4 major panels, each with 2x2 minor plates
    major_x = np.abs((x * 2.0) % 1.0 - 0.5)
    major_y = np.abs((y * 2.0) % 1.0 - 0.5)
    minor_x = np.abs((x * 4.0) % 1.0 - 0.5)
    minor_y = np.abs((y * 4.0) % 1.0 - 0.5)
    seam_major = 1.0 - _smoothstep(0.006, 0.020, np.minimum(major_x, major_y))
    seam_minor = 1.0 - _smoothstep(0.004, 0.014, np.minimum(minor_x, minor_y))
    seam = np.clip(seam_major + seam_minor * 0.55, 0, 1)
    plate_rise = np.clip(seam_minor, 0, 1) * 0.10

    height = 0.55 + plate_rise - seam * 0.42
    height += _scratches(rng, size, 120, 90, 1, 0.045)
    height += micro * 0.25

    # bolt rings at major seams intersections and mid-edges
    bolts = np.zeros((size, size), np.float32)
    for gx in (0.0, 0.5, 1.0):
        for gy in (0.0, 0.5, 1.0):
            for ox, oy in ((0.045, 0.045), (-0.045, 0.045), (0.045, -0.045), (-0.045, -0.045)):
                cx, cy = (gx + ox) % 1.0, (gy + oy) % 1.0
                d = np.hypot((x - cx + 0.5) % 1.0 - 0.5, (y - cy + 0.5) % 1.0 - 0.5)
                bolts = np.maximum(bolts, _smoothstep(0.011, 0.006, d))
    height += bolts * 0.22

    # albedo: painted steel with wear
    paint = np.zeros((size, size, 3), np.float32)
    paint[..., 0] = 0.196
    paint[..., 1] = 0.235
    paint[..., 2] = 0.278
    paint += (grime[..., None] - 0.5) * 0.055
    paint += micro[..., None] * 0.4
    # traffic polish bands (walked paths polish brighter + smoother)
    traffic = _smoothstep(0.55, 0.85, _warp(_fbm(rng, size, 4, 2), _fbm(rng, size, 3, 2), _fbm(rng, size, 3, 3), 0.25))
    paint += traffic[..., None] * np.array([0.075, 0.082, 0.09], np.float32)
    # chips reveal bright steel
    chips = (rng.random((size, size)) > 0.9955) | (_warp(_fbm(rng, size, 4, 6), _fbm(rng, size, 3, 4), _fbm(rng, size, 3, 5), 0.2) > 0.82)
    chip_m = chips & (seam < 0.4)
    paint[chip_m] = np.array([0.42, 0.45, 0.48], np.float32) + micro[chip_m, None] * 0.5
    # seams hold dark grime
    paint *= (1.0 - seam * 0.55)[..., None]
    paint += (bolts * 0.10)[..., None] * np.array([0.28, 0.30, 0.32], np.float32)
    # hazard stripe band at v≈0.06 like the original kit language
    band = np.abs((y - 0.055) / 0.028) < 1.0
    stripe = np.mod(np.floor(x * 12.0), 2.0) < 1.0
    hazard = band & stripe
    paint[hazard] = np.array([0.82, 0.52, 0.10], np.float32) + micro[hazard, None] * 0.3
    paint = np.clip(paint, 0, 1)

    rough = 0.62 - traffic * 0.22 + seam * 0.16 + chips * (-0.10) + micro * 0.6
    rough = np.clip(rough, 0.18, 0.95)
    metal = np.clip(0.28 + chips * 0.55 - seam * 0.1, 0.0, 1.0)
    arr = np.concatenate([paint, np.ones((size, size, 1), np.float32)], axis=2)
    return dict(arr=arr, height=np.clip(height, 0, 1), rough=rough, metal=metal, strength=9.0)


@_wrap_tex
def tex_metal(size):
    """Brushed structural steel: anisotropic grain, weld beads, oxidation
    patches and long abrasion scratches."""
    rng = np.random.default_rng(31)
    y, x = np.mgrid[0:size, 0:size].astype(np.float32) / size
    brush = rng.normal(0, 0.05, (size, size))
    from PIL import ImageFilter as _IF
    brush = np.asarray(PILImage.fromarray(((brush - brush.min()) / (np.ptp(brush) + 1e-6) * 255).astype(np.uint8)).filter(
        _IF.GaussianBlur(0.6)), dtype=np.float32) / 255.0 - 0.5
    # stretch the grain along X
    brush = np.repeat(brush[::2, :], 2, axis=0)[:size, :size] if size >= 512 else brush
    broad = _fbm(rng, size, 5, 3)
    oxide = _smoothstep(0.62, 0.86, _warp(_fbm(rng, size, 5, 4), _fbm(rng, size, 4, 3), _fbm(rng, size, 4, 5), 0.3))
    weld = np.zeros((size, size), np.float32)
    for yv in (0.22, 0.74):
        band = np.exp(-((y - yv + 0.012 * np.sin(x * 24.0)) ** 2) / (2 * 0.006 ** 2))
        ripple = 0.5 + 0.5 * np.sin(x * 90.0)
        weld += band * ripple
    height = 0.5 + brush * 0.30 + weld * 0.32 + _scratches(rng, size, 160, 120, 1, 0.05) + (broad - 0.5) * 0.18

    steel = np.zeros((size, size, 3), np.float32)
    steel[..., 0] = 0.455
    steel[..., 1] = 0.482
    steel[..., 2] = 0.512
    steel += (brush * 0.10)[..., None]
    steel += ((broad - 0.5) * 0.10)[..., None]
    rust_col = np.array([0.36, 0.185, 0.085], np.float32)
    steel = steel * (1 - oxide[..., None] * 0.85) + rust_col * (oxide[..., None] * 0.85)
    steel += (weld * 0.06)[..., None]
    steel = np.clip(steel, 0, 1)
    rough = np.clip(0.42 + oxide * 0.38 + (broad - 0.5) * 0.14 - np.abs(brush) * 0.18, 0.12, 0.95)
    metal = np.clip(0.92 - oxide * 0.45, 0, 1)
    arr = np.concatenate([steel, np.ones((size, size, 1), np.float32)], axis=2)
    return dict(arr=arr, height=np.clip(height, 0, 1), rough=rough, metal=metal, strength=6.5)


@_wrap_tex
def tex_metal2(size):
    """Titanium cladding: fine polish, sharp scratches, cold blue-grey."""
    rng = np.random.default_rng(97)
    broad = _fbm(rng, size, 4, 3)
    height = 0.5 + _scratches(rng, size, 90, 140, 1, 0.06) + (broad - 0.5) * 0.10
    tint = np.zeros((size, size, 3), np.float32)
    tint[..., 0] = 0.53
    tint[..., 1] = 0.565
    tint[..., 2] = 0.615
    tint += ((broad - 0.5) * 0.08)[..., None]
    tint = np.clip(tint, 0, 1)
    rough = np.clip(0.30 + (broad - 0.5) * 0.30 + np.abs(_fbm(rng, size, 3, 6) - 0.5) * 0.25, 0.10, 0.72)
    metal = np.full((size, size), 0.96, np.float32)
    arr = np.concatenate([tint, np.ones((size, size, 1), np.float32)], axis=2)
    return dict(arr=arr, height=np.clip(height, 0, 1), rough=rough, metal=metal, strength=5.0)


@_wrap_tex
def tex_concrete(size):
    """Poured concrete: form-board lines, aggregate pits, cracks, efflorescence
    runs and frost patches."""
    rng = np.random.default_rng(11)
    y, x = np.mgrid[0:size, 0:size].astype(np.float32) / size
    broad = _fbm(rng, size, 5, 3)
    grain = rng.normal(0, 0.022, (size, size))
    form = np.abs((y * 3.0) % 1.0 - 0.5)
    form_line = 1.0 - _smoothstep(0.004, 0.012, form)
    pits = np.zeros((size, size), np.float32)
    for _ in range(260):
        cx, cy = rng.uniform(0, 1), rng.uniform(0, 1)
        r = rng.uniform(0.002, 0.011)
        d = np.hypot((x - cx + 0.5) % 1.0 - 0.5, (y - cy + 0.5) % 1.0 - 0.5)
        pits = np.maximum(pits, _smoothstep(r, r * 0.5, d) * rng.uniform(0.4, 1.0))
    crack_h = np.zeros((size, size), np.float32)
    for _ in range(10):
        t = np.linspace(0, 1, 240)
        x0, y0 = rng.uniform(0, 1), rng.uniform(0, 1)
        walk = np.cumsum(rng.normal(0, 0.012, len(t)))
        xs = (x0 + walk) % 1.0
        ys = (y0 + t * rng.uniform(-0.5, 0.5)) % 1.0
        px = (xs * size).astype(np.int32) % size
        py = (ys * size).astype(np.int32) % size
        crack_h[py, px] = 1.0
    height = 0.62 - form_line * 0.30 - pits * 0.42 - crack_h * 0.5 + (broad - 0.5) * 0.16 + grain * 0.5

    grey = np.zeros((size, size, 3), np.float32)
    tone = 0.42 + (broad - 0.5) * 0.12 + grain * 0.5
    grey[..., 0] = tone * 1.01
    grey[..., 1] = tone
    grey[..., 2] = tone * 0.985
    efflor = _streaks_down(rng, size, 26)
    grey += (efflor * 0.055)[..., None] * np.array([0.9, 0.92, 0.95], np.float32)
    drip = _streaks_down(rng, size, 14)
    rust = _smoothstep(0.25, 0.9, drip) * (_fbm(rng, size, 4, 3) > 0.55)
    grey = grey * (1 - rust[..., None] * 0.4) + np.array([0.30, 0.185, 0.11], np.float32) * (rust[..., None] * 0.4)
    frost = _smoothstep(0.68, 0.9, broad) * _smoothstep(0.3, 0.6, _fbm(rng, size, 4, 5))
    grey += frost[..., None] * np.array([0.16, 0.185, 0.21], np.float32)
    grey *= (1 - form_line * 0.35)[..., None]
    grey *= (1 - pits * 0.30)[..., None]
    grey = np.clip(grey, 0, 1)
    rough = np.clip(0.82 + pits * 0.1 - frost * 0.06 - efflor * 0.05, 0.4, 0.99)
    metal = np.zeros((size, size), np.float32)
    arr = np.concatenate([grey, np.ones((size, size, 1), np.float32)], axis=2)
    return dict(arr=arr, height=np.clip(height, 0, 1), rough=rough, metal=metal, strength=5.5)


@_wrap_tex
def tex_rock(size):
    """Sedimentary cliff rock: wavy strata, differential erosion, fracture
    planes, frost dusting in cavities."""
    rng = np.random.default_rng(23)
    y, x = np.mgrid[0:size, 0:size].astype(np.float32) / size
    broad = _fbm(rng, size, 5, 3)
    detail = _fbm(rng, size, 4, 12)
    warped = y + 0.045 * (broad - 0.5) + 0.012 * np.sin(x * 11.0)
    layers = 0.5 + 0.5 * np.sin(warped * math.pi * 9.0)
    band_soft = 0.5 + 0.5 * np.sin(warped * math.pi * 9.0 + 1.2)
    height = 0.5 + (layers - 0.5) * 0.42 + (detail - 0.5) * 0.35 + (broad - 0.5) * 0.22
    # fracture planes
    for angle, spacing in ((0.35, 0.19), (-0.62, 0.26), (1.15, 0.31)):
        axis = x * math.cos(angle) + y * math.sin(angle)
        dist = np.abs((axis % spacing) - spacing * 0.5) / (spacing * 0.5)
        height -= _smoothstep(0.12, 0.0, dist) * 0.16
    height = np.clip(height, 0, 1)

    tone = 0.335 + (layers - 0.5) * 0.16 + (broad - 0.5) * 0.12 + (detail - 0.5) * 0.08
    albedo = np.empty((size, size, 3), np.float32)
    albedo[..., 0] = tone * 1.04
    albedo[..., 1] = tone * 1.0
    albedo[..., 2] = tone * 0.955
    frost = _smoothstep(0.66, 0.92, height) * _smoothstep(0.35, 0.7, _fbm(rng, size, 4, 4))
    albedo += frost[..., None] * np.array([0.14, 0.17, 0.20], np.float32)
    albedo = np.clip(albedo + rng.normal(0, 0.012, (size, size, 1)), 0, 1)
    rough = np.clip(0.86 - frost * 0.10 + (detail - 0.5) * 0.12, 0.45, 0.99)
    metal = np.zeros((size, size), np.float32)
    arr = np.concatenate([albedo, np.ones((size, size, 1), np.float32)], axis=2)
    return dict(arr=arr, height=height, rough=rough, metal=metal, strength=8.5)


@_wrap_tex
def tex_ice_rock(size):
    """Glacial mineral mass: deep blue body, white pressure strata, dark
    cryo-fractures with bright rims, frost caps and crystal glitter."""
    rng = np.random.default_rng(61)
    y, x = np.mgrid[0:size, 0:size].astype(np.float32) / size
    broad = _fbm(rng, size, 5, 3)
    fine = _fbm(rng, size, 4, 16)
    bands = 0.5 + 0.5 * np.sin((y * 11.0 + 0.32 * np.sin(x * 7.0) + (broad - 0.5) * 0.6) * math.pi)
    height = 0.5 + (bands - 0.5) * 0.30 + (broad - 0.5) * 0.30 + (fine - 0.5) * 0.18

    albedo = np.empty((size, size, 3), np.float32)
    albedo[..., 0] = 0.115 + bands * 0.115 + (broad - 0.5) * 0.075
    albedo[..., 1] = 0.235 + bands * 0.205 + (broad - 0.5) * 0.10
    albedo[..., 2] = 0.345 + bands * 0.275 + (broad - 0.5) * 0.12

    # dark cryo-fractures with bright pressure rims
    crack_mask = np.zeros((size, size), np.float32)
    rim_mask = np.zeros((size, size), np.float32)
    for _ in range(26):
        xx = rng.uniform(0, 1)
        slope = rng.uniform(-0.30, 0.30)
        width = rng.uniform(0.0016, 0.005)
        line = np.abs(x - (xx + (y - 0.5) * slope))
        crack = _smoothstep(width, 0.0, line)
        rim = _smoothstep(width * 3.2, width * 1.2, line) - crack
        crack_mask = np.maximum(crack_mask, crack * rng.uniform(0.5, 1.0))
        rim_mask = np.maximum(rim_mask, rim * rng.uniform(0.35, 0.8))
    albedo *= (1.0 - crack_mask[..., None] * 0.52)
    albedo += (rim_mask * 0.16)[..., None] * np.array([0.55, 0.72, 0.85], np.float32)
    height -= crack_mask * 0.30

    # pale pressure seams on shelves
    seam = np.minimum.reduce([np.abs(y - v) for v in (0.14, 0.36, 0.60, 0.84)])
    pale = _smoothstep(0.010, 0.0, seam)
    albedo += pale[..., None] * np.array([0.085, 0.175, 0.225], np.float32)
    height += pale * 0.10

    # frost caps collect on high ground
    frost = _smoothstep(0.58, 0.88, height) * _smoothstep(0.35, 0.75, _fbm(rng, size, 4, 5))
    albedo += frost[..., None] * np.array([0.20, 0.235, 0.265], np.float32)
    height += frost * 0.12

    # crystal glitter specks
    glitter = (rng.random((size, size)) > 0.9965).astype(np.float32)
    albedo += glitter[..., None] * 0.28

    albedo = np.clip(albedo + rng.normal(0, 0.010, (size, size, 1)), 0, 1)
    rough = np.clip(0.62 - frost * 0.30 - glitter * 0.35 + crack_mask * 0.18, 0.08, 0.95)
    metal = np.clip(0.03 + glitter * 0.25, 0, 1)
    arr = np.concatenate([albedo, np.ones((size, size, 1), np.float32)], axis=2)
    return dict(arr=arr, height=np.clip(height, 0, 1), rough=rough, metal=metal, strength=9.5)


@_wrap_tex
def tex_composite(size):
    """Carbon-composite armour: fine weave, panel borders, scuffed edges."""
    rng = np.random.default_rng(57)
    y, x = np.mgrid[0:size, 0:size].astype(np.float32) / size
    weave_a = np.sin((x + y) * math.pi * 22.0) * 0.5 + 0.5
    weave_b = np.sin((x - y) * math.pi * 22.0) * 0.5 + 0.5
    fiber = np.maximum(weave_a, weave_b)
    panel = np.minimum(np.abs((x * 2) % 1 - 0.5), np.abs((y * 2) % 1 - 0.5))
    border = 1.0 - _smoothstep(0.012, 0.03, panel)
    broad = _fbm(rng, size, 4, 3)
    height = 0.5 + (fiber - 0.5) * 0.16 - border * 0.28 + (broad - 0.5) * 0.12
    height += _scratches(rng, size, 70, 80, 1, 0.04)

    value = 0.165 + (fiber - 0.5) * 0.022 + (broad - 0.5) * 0.030
    albedo = np.empty((size, size, 3), np.float32)
    albedo[..., 0] = value * 0.82
    albedo[..., 1] = value * 0.93
    albedo[..., 2] = value * 1.08
    albedo *= (1 - border * 0.35)[..., None]
    # scuffs on borders
    scuff = border * _smoothstep(0.55, 0.85, _fbm(rng, size, 4, 6))
    albedo += scuff[..., None] * np.array([0.10, 0.105, 0.11], np.float32)
    albedo = np.clip(albedo, 0, 1)
    rough = np.clip(0.52 + (fiber - 0.5) * 0.10 + border * 0.18 + scuff * 0.12, 0.2, 0.95)
    metal = np.clip(0.12 + scuff * 0.35, 0, 1)
    arr = np.concatenate([albedo, np.ones((size, size, 1), np.float32)], axis=2)
    return dict(arr=arr, height=np.clip(height, 0, 1), rough=rough, metal=metal, strength=5.0)


@_wrap_tex
def tex_rubber(size):
    """Moulded anti-slip rubber: stud grid, worn tops, dust in the grooves."""
    rng = np.random.default_rng(83)
    y, x = np.mgrid[0:size, 0:size].astype(np.float32) / size
    stud = np.maximum(np.cos(x * math.pi * 34.0), 0) * np.maximum(np.cos(y * math.pi * 34.0), 0)
    stud = _smoothstep(0.25, 0.75, stud)
    broad = _fbm(rng, size, 4, 3)
    height = 0.42 + stud * 0.42 + (broad - 0.5) * 0.10
    value = 0.072 + stud * 0.020 + (broad - 0.5) * 0.018
    albedo = np.empty((size, size, 3), np.float32)
    albedo[..., 0] = value * 0.90
    albedo[..., 1] = value * 0.955
    albedo[..., 2] = value
    dust = _smoothstep(0.55, 0.9, broad) * (1 - stud)
    albedo += dust[..., None] * np.array([0.035, 0.038, 0.042], np.float32)
    albedo = np.clip(albedo, 0, 1)
    rough = np.clip(0.85 - stud * 0.10 + dust * 0.06, 0.4, 0.99)
    metal = np.zeros((size, size), np.float32)
    arr = np.concatenate([albedo, np.ones((size, size, 1), np.float32)], axis=2)
    return dict(arr=arr, height=np.clip(height, 0, 1), rough=rough, metal=metal, strength=6.0)


@_wrap_tex
def tex_hazard(size):
    """Safety paint on steel: diagonal chevrons, chipped paint over substrate,
    roller texture and grime wash."""
    rng = np.random.default_rng(101)
    y, x = np.mgrid[0:size, 0:size].astype(np.float32) / size
    stripe = np.mod(np.floor((x * 6.0 - y * 6.0) % 1.0 * 2.0), 2.0) < 1.0
    paint = np.empty((size, size, 3), np.float32)
    paint[...] = (0.86, 0.475, 0.048)
    dark = np.empty((size, size, 3), np.float32)
    dark[...] = (0.115, 0.125, 0.14)
    albedo = np.where(stripe[..., None], paint, dark)
    roller = rng.normal(0, 0.022, (size, size, 1))
    albedo += roller
    chips = (rng.random((size, size)) > 0.982) | (_smoothstep(0.72, 0.92, _fbm(rng, size, 4, 7)) > 0.72)
    substrate = np.array([0.30, 0.315, 0.33], np.float32)
    albedo[chips] = substrate + roller[chips] * 1.6
    grime = _smoothstep(0.55, 0.9, _fbm(rng, size, 5, 3))
    albedo *= (1 - grime * 0.22)[..., None]
    albedo = np.clip(albedo, 0, 1)
    height = 0.55 + (stripe.astype(np.float32)) * 0.10 - chips * 0.22 + roller[..., 0] * 1.2
    rough = np.clip(0.48 + chips * 0.28 + grime * 0.12, 0.2, 0.95)
    metal = np.clip(0.10 + chips * 0.55, 0, 1)
    arr = np.concatenate([albedo, np.ones((size, size, 1), np.float32)], axis=2)
    return dict(arr=arr, height=np.clip(height, 0, 1), rough=rough, metal=metal, strength=5.5)


@_wrap_tex
def tex_hazard_red(size):
    out = tex_hazard(size)
    arr = out["arr"]
    orange = (arr[..., 0] > 0.6) & (arr[..., 1] < 0.7)
    arr[..., 0] = np.where(orange, 0.62, arr[..., 0])
    arr[..., 1] = np.where(orange, 0.075, arr[..., 1])
    arr[..., 2] = np.where(orange, 0.045, arr[..., 2])
    out["arr"] = arr
    return out


@_wrap_tex
def tex_energy(size):
    """Emissive core: radial falloff, circuit filaments, concentric rings."""
    rng = np.random.default_rng(5)
    y, x = np.mgrid[0:size, 0:size].astype(np.float32) / size
    d = np.hypot(x - 0.5, y - 0.5)
    g = np.clip(1.0 - d / 0.62, 0, 1) ** 1.6
    rings = 0.5 + 0.5 * np.sin(d * 62.0)
    base = np.zeros((size, size, 4), np.float32)
    base[..., 0] = 0.16 + 0.62 * g
    base[..., 1] = 0.60 + 0.38 * g
    base[..., 2] = 1.0
    base[..., 3] = 1.0
    for _ in range(22):
        t = np.linspace(0, 1, 60)
        x0, y0 = rng.uniform(0.15, 0.85), rng.uniform(0.15, 0.85)
        xs = x0 + t * rng.uniform(-0.5, 0.5)
        ys = y0 + t * rng.uniform(-0.5, 0.5)
        px = np.clip((xs * size).astype(np.int32), 0, size - 1)
        py = np.clip((ys * size).astype(np.int32), 0, size - 1)
        base[py, px, 0] = np.maximum(base[py, px, 0], 0.52)
        base[py, px, 1] = np.maximum(base[py, px, 1], 0.85)
    base[..., :3] += (rings * g * 0.06)[..., None]
    return dict(arr=base, height=None, rough=None, metal=None, strength=None)


@_wrap_tex
def tex_cloud(size):
    """Soft vapour puff with alpha."""
    rng = np.random.default_rng(9)
    y, x = np.mgrid[0:size, 0:size].astype(np.float32) / size
    base = np.zeros((size, size, 4), np.float32)
    d = np.hypot(x - 0.5, y - 0.5)
    a = np.clip(1.0 - d / 0.45, 0, 1) ** 1.3
    base[..., 0] = 0.93
    base[..., 1] = 0.95
    base[..., 2] = 0.98
    base[..., 3] = a
    for _ in range(28):
        cx, cy = rng.uniform(0.2, 0.8), rng.uniform(0.2, 0.8)
        r = rng.uniform(0.08, 0.2)
        dd = np.hypot(x - cx, y - cy)
        m = np.clip(1.0 - dd / r, 0, 1) ** 1.5
        base[..., 3] = np.maximum(base[..., 3], m * rng.uniform(0.25, 0.7))
    return dict(arr=base, height=None, rough=None, metal=None, strength=None)


SURFACES = {
    "deck": tex_deck,
    "metal": tex_metal,
    "metal2": tex_metal2,
    "concrete": tex_concrete,
    "rock": tex_rock,
    "ice_rock": tex_ice_rock,
    "composite": tex_composite,
    "rubber": tex_rubber,
    "hazard": tex_hazard,
    "hazard_red": tex_hazard_red,
    "energy": tex_energy,
    "cloud": tex_cloud,
}


def surface_set(kind, size=1024):
    maps = SURFACES[kind](size)
    if maps.get("height") is not None:
        h = maps["height"]
        span = float(np.ptp(h))
        if span > 1e-6:
            maps["height"] = (h - float(h.min())) / span
        maps["rough"] = np.clip(maps["rough"], 0.04, 0.99)
        maps["metal"] = np.clip(maps["metal"], 0.0, 1.0)
    return maps


def save_set(out_dir, name, maps):
    """Write albedo/normal/ORM PNGs; return dict of paths."""
    os.makedirs(out_dir, exist_ok=True)
    size = maps["arr"].shape[0]
    albedo = (np.clip(maps["arr"], 0, 1) * 255).astype(np.uint8)
    albedo_path = os.path.join(out_dir, name + ".png")
    PILImage.fromarray(albedo, "RGBA").convert("RGB").save(albedo_path, optimize=True)
    paths = {"albedo": albedo_path}
    if maps.get("height") is not None:
        normal = (np.clip(_normal_from_height(maps["height"], maps["strength"]), 0, 1) * 255).astype(np.uint8)
        normal_path = os.path.join(out_dir, name + "_normal.png")
        PILImage.fromarray(normal, "RGBA").convert("RGB").save(normal_path, optimize=True)
        ao = _cavity_ao(maps["height"])
        orm = np.stack([
            np.clip(maps["metal"], 0, 1) * 255,
            np.clip(maps["rough"], 0, 1) * 255,
            np.clip(ao, 0, 1) * 255,
        ], axis=2).astype(np.uint8)
        orm_path = os.path.join(out_dir, name + "_orm.png")
        PILImage.fromarray(orm, "RGB").save(orm_path, optimize=True)
        paths.update(normal=normal_path, orm=orm_path)
    return paths


# ---------------------------------------------------------------------------
# material builder (Blender side)
# ---------------------------------------------------------------------------


def build_material(mat_name, paths, tex_scale=0.35, emission=0.0, alpha_blend=False,
                   normal_strength=0.8):
    """Create/replace a Principled material with mapped PBR set.

    tex_scale = world metres per UV unit (planar metric UVs in the kit).
    """
    import bpy

    mat = bpy.data.materials.get(mat_name) or bpy.data.materials.new(mat_name)
    mat.use_nodes = True
    nt = mat.node_tree
    nt.nodes.clear()
    out = nt.nodes.new("ShaderNodeOutputMaterial")
    out.location = (520, 0)
    bsdf = nt.nodes.new("ShaderNodeBsdfPrincipled")
    bsdf.location = (200, 0)
    nt.links.new(bsdf.outputs["BSDF"], out.inputs["Surface"])

    texco = nt.nodes.new("ShaderNodeTexCoord")
    texco.location = (-620, 0)
    mapping = nt.nodes.new("ShaderNodeMapping")
    mapping.location = (-420, 0)
    mapping.inputs["Scale"].default_value = (tex_scale, tex_scale, tex_scale)
    nt.links.new(texco.outputs["Object"], mapping.inputs["Vector"])

    albedo = bpy.data.images.load(paths["albedo"])
    albedo.colorspace_settings.name = "sRGB"
    node_a = nt.nodes.new("ShaderNodeTexImage")
    node_a.image = albedo
    node_a.location = (-200, 120)
    nt.links.new(mapping.outputs["Vector"], node_a.inputs["Vector"])
    nt.links.new(node_a.outputs["Color"], bsdf.inputs["Base Color"])

    if "normal" in paths:
        normal = bpy.data.images.load(paths["normal"])
        normal.colorspace_settings.name = "Non-Color"
        node_n = nt.nodes.new("ShaderNodeTexImage")
        node_n.image = normal
        node_n.location = (-200, -170)
        nt.links.new(mapping.outputs["Vector"], node_n.inputs["Vector"])
        nrm = nt.nodes.new("ShaderNodeNormalMap")
        nrm.location = (0, -170)
        nrm.inputs["Strength"].default_value = normal_strength
        nt.links.new(node_n.outputs["Color"], nrm.inputs["Color"])
        nt.links.new(nrm.outputs["Normal"], bsdf.inputs["Normal"])

        # ORM: R=metallic, G=roughness feed the Principled sockets; the glTF
        # exporter repacks them into the standard metallicRoughness texture.
        # B=AO stays in the source map for future occlusion use.
        orm = bpy.data.images.load(paths["orm"])
        orm.colorspace_settings.name = "Non-Color"
        node_o = nt.nodes.new("ShaderNodeTexImage")
        node_o.image = orm
        node_o.location = (-200, -430)
        nt.links.new(mapping.outputs["Vector"], node_o.inputs["Vector"])
        sep = nt.nodes.new("ShaderNodeSeparateColor")
        sep.location = (0, -430)
        nt.links.new(node_o.outputs["Color"], sep.inputs["Color"])
        nt.links.new(sep.outputs["Red"], bsdf.inputs["Metallic"])
        nt.links.new(sep.outputs["Green"], bsdf.inputs["Roughness"])

    if emission > 0.0:
        bsdf.inputs["Emission Color"].default_value = (0.25, 0.75, 1.0, 1.0)
        bsdf.inputs["Emission Strength"].default_value = emission
    if alpha_blend:
        mat.blend_method = "BLEND"
    return mat
