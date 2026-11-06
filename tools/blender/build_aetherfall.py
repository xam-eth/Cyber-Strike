#!/usr/bin/env python3
"""
build_aetherfall.py — EXOCOMFLICT: STELLAR HORIZON · SH-01 AETHERFALL.

Generates the custom Aetherfall architectural kit (GLB) with Blender 4.5 LTS
(runs headless through the `bpy` module), assembles the world, bakes the
procedural surface textures, and writes:

    game/assets/world/aetherfall/models/<asset>.glb      one GLB per module
    game/assets/world/aetherfall/materials/*.png         baked surface maps
    game/assets/world/aetherfall/layout.json             every placement
    game/assets/world/aetherfall/measurements.json        per-asset bounds

Every module is authored on a documented pivot so the Godot builder can place
it by its own centre, and every collider in Godot is derived from the same
bounds — the same discipline `StationKit` uses for the station kit.

Run:
    LD_LIBRARY_PATH=<stub-libs> python3 tools/blender/build_aetherfall.py
"""
import bpy, math, os, json, random, sys

def V3(x=0.0, y=0.0, z=0.0):
    return (float(x), float(y), float(z))

def add(a, b):
    return (a[0] + b[0], a[1] + b[1], a[2] + b[2])

def mul(a, s):
    return (a[0] * s, a[1] * s, a[2] * s)

def sub(a, b):
    return (a[0] - b[0], a[1] - b[1], a[2] - b[2])

Vector3 = V3

random.seed(20260101)

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "../.."))
MODEL_DIR = os.path.join(ROOT, "game/assets/world/aetherfall/models")
MAT_DIR = os.path.join(ROOT, "game/assets/world/aetherfall/materials")
SOURCE_TEX_DIR = os.path.join(ROOT, "game/assets/world/aetherfall/source_textures")
WORLD_DIR = os.path.join(ROOT, "game/assets/world/aetherfall")
LAYOUT_PATH = os.path.join(ROOT, "game/assets/world/aetherfall/layout.json")
MEASURE_PATH = os.path.join(ROOT, "game/assets/world/aetherfall/measurements.json")

os.makedirs(MODEL_DIR, exist_ok=True)
os.makedirs(MAT_DIR, exist_ok=True)
SCENE_COLL = bpy.context.scene.collection

# ---------------------------------------------------------------------------
# World layout. One source of truth; the Godot builder reads layout.json.
# ---------------------------------------------------------------------------
TOWER = Vector3(0.0, 0.0, -30.0)
PLATFORM_CENTER = Vector3(0.0, 0.0, 2.0)
PLATFORM_HALF = Vector3(38.0, 0.0, 18.0)      # 76 m x 36 m combat platform
CANYON_CENTER_Z = -18.0
CANYON_FLOOR_Y = -46.0
BRIDGE_Y = 5.0
WALKWAY_Y = 6.5
DECK_Y = 0.0

# ---------------------------------------------------------------------------
# Procedural textures (baked with numpy; no scanned assets are claimed).
# ---------------------------------------------------------------------------
import numpy as np

from PIL import Image as PILImage

def save_png(name, arr):
    """Write a float RGBA array to a PNG with Pillow (Blender's own image
    save() drops the buffer for generated images in this build)."""
    path = os.path.join(MAT_DIR, name + ".png")
    img = arr.astype(np.float32)
    img = np.clip(img, 0.0, 1.0)
    PILImage.fromarray((img * 255.0).astype(np.uint8), "RGBA").save(path)
    return path

def blend_source_texture(procedural, filename, amount):
    """Mix an authored AI source albedo with a procedural tile.

    The source contributes believable abrasion/cracks/mineral detail while the
    procedural base retains repeat-safe panel language and palette control.
    """
    path = os.path.join(SOURCE_TEX_DIR, filename)
    if not os.path.isfile(path):
        return procedural
    src = PILImage.open(path).convert("RGBA").resize(
        (procedural.shape[1], procedural.shape[0]), PILImage.Resampling.LANCZOS)
    arr = np.asarray(src, dtype=np.float32) / 255.0
    out = procedural.copy()
    out[..., :3] = np.clip(procedural[..., :3] * (1.0 - amount) + arr[..., :3] * amount, 0.0, 1.0)
    return out

def tex_deck(size=512):
    """Manufactured deck plate: panel grid, seam lines, rivets, wear."""
    y, x = np.mgrid[0:size, 0:size].astype(np.float32) / size
    base = np.zeros((size, size, 4), np.float32)
    base[..., 0] = 0.30; base[..., 1] = 0.34; base[..., 2] = 0.38; base[..., 3] = 1.0
    noise = np.random.default_rng(7).normal(0, 0.03, (size, size))
    base[..., 0] += noise; base[..., 1] += noise; base[..., 2] += noise
    # panel grid every 1/4
    gx = np.abs((x * 4) % 1 - 0.5)
    gz = np.abs((y * 4) % 1 - 0.5)
    line = np.minimum(gx * 14.0, 1.0) * np.minimum(gz * 14.0, 1.0)
    seam = 1.0 - np.clip(np.minimum(np.abs((x*4)%1-0.5)*10, np.abs((y*4)%1-0.5)*10), 0, 1) * 0
    dark = np.clip(1.0 - np.minimum(gx, gz) * 12.0, 0, 1)
    base[..., :3] *= (1.0 - dark * 0.55)[..., None]
    base[..., :3] += line[..., None] * 0.06
    # rivets at grid intersections
    rv = (np.abs((x*4)%1 - 0.5) < 0.03) & (np.abs((y*4)%1 - 0.5) < 0.03)
    base[..., 0] = np.where(rv, 0.42, base[..., 0])
    base[..., 1] = np.where(rv, 0.46, base[..., 1])
    base[..., 2] = np.where(rv, 0.50, base[..., 2])
    # hazard stripe along one edge band
    stripe = np.zeros((size, size), np.float32)
    band = (np.abs((y - 0.06) / 0.03) < 1.0)
    stripe[band] = 1.0
    r = np.mod(np.floor(x * 10), 2) < 1
    base[..., 0] = np.where(band & r, 0.85, base[..., 0])
    base[..., 1] = np.where(band & r, 0.55, base[..., 1])
    base[..., 2] = np.where(band & r, 0.12, base[..., 2])
    return base

def tex_concrete(size=512):
    y, x = np.mgrid[0:size, 0:size].astype(np.float32) / size
    base = np.zeros((size, size, 4), np.float32)
    rng = np.random.default_rng(11)
    for c in range(3):
        base[..., c] = 0.42 + rng.normal(0, 0.05, (size, size))
    base[..., :3] += rng.normal(0, 0.03, (size, size, 3))
    # cracks
    for _ in range(14):
        t = np.linspace(0, 1, 60)
        xs = rng.uniform(0, 1) + t * rng.uniform(-0.2, 0.2)
        ys = rng.uniform(0, 1) + t * rng.uniform(-0.2, 0.2)
        for i in range(len(t) - 1):
            px, py = int(xs[i] * size), int(ys[i] * size)
            base[max(0, py):py + 2, max(0, px):px + 2, :3] *= 0.55
    # stains
    for _ in range(6):
        cx, cy = rng.uniform(0, 1), rng.uniform(0, 1)
        r = rng.uniform(0.03, 0.12)
        d = np.sqrt((x - cx) ** 2 + (y - cy) ** 2)
        m = np.clip(1.0 - d / r, 0, 1)
        base[..., 0] *= (1 - m * 0.3); base[..., 1] *= (1 - m * 0.32); base[..., 2] *= (1 - m * 0.3)
    return base

def tex_rock(size=512):
    """Subtle coherent sediment, not separate RGB phase-shifted stripes."""
    y, x = np.mgrid[0:size, 0:size].astype(np.float32) / size
    rng = np.random.default_rng(23)
    def noise(res):
        pixels = (rng.random((res, res)) * 255).astype(np.uint8)
        return np.asarray(PILImage.fromarray(pixels).resize((size, size), PILImage.Resampling.BICUBIC), dtype=np.float32) / 255.0
    broad = noise(12)
    detail = noise(65)
    warped = y + 0.035 * (broad - 0.5) + 0.012 * np.sin(x * 13.0)
    layers = np.sin(warped * math.pi * 13.0) * 0.025
    grain = rng.normal(0, 0.012, (size, size))
    variation = (broad - 0.5) * 0.12 + (detail - 0.5) * 0.07 + layers + grain
    base = np.empty((size, size, 4), np.float32)
    for c, tint in enumerate((0.42, 0.405, 0.38)):
        base[..., c] = tint + variation
    base[..., 3] = 1.0
    return base

def tex_ice_rock(size=512):
    """Blue glacial mineral: layered ice, trapped particulate and fracture veins.
    It is a surface source for the exterior geology rather than a flat colour."""
    y, x = np.mgrid[0:size, 0:size].astype(np.float32) / size
    rng = np.random.default_rng(61)
    grain = rng.normal(0.0, 0.035, (size, size))
    bands = 0.5 + 0.5 * np.sin((y * 13.0 + 0.35 * np.sin(x * 9.0)) * math.pi)
    base = np.zeros((size, size, 4), np.float32)
    base[..., 0] = 0.105 + bands * 0.10 + grain
    base[..., 1] = 0.225 + bands * 0.20 + grain
    base[..., 2] = 0.32 + bands * 0.28 + grain
    # Long dark cryo-fractures prevent the ice from reading as a blue painted box.
    for _ in range(22):
        xx = rng.uniform(0, 1)
        slope = rng.uniform(-0.24, 0.24)
        width = rng.uniform(0.0015, 0.004)
        line = np.abs(x - (xx + (y - 0.5) * slope))
        crack = np.clip(1.0 - line / width, 0.0, 1.0)
        base[..., :3] *= (1.0 - crack[..., None] * rng.uniform(0.28, 0.52))
    # Thin pale pressure seams on several horizontal shelves.
    seam = np.minimum.reduce([np.abs(y - v) for v in (0.16, 0.37, 0.61, 0.83)])
    pale = np.clip(1.0 - seam / 0.007, 0.0, 1.0)
    base[..., :3] += pale[..., None] * np.array([0.08, 0.18, 0.23])
    base[..., 3] = 1.0
    return base


def tex_metal(size=512, seed=31):
    """Weathered brushed metal: scratches, edge wear, stains."""
    rng = np.random.default_rng(seed)
    base = np.zeros((size, size, 4), np.float32)
    base[..., 0] = 0.55; base[..., 1] = 0.58; base[..., 2] = 0.61; base[..., 3] = 1.0
    # brushed grain
    g = rng.normal(0, 0.06, (size, size))
    for c in range(3):
        base[..., c] += np.roll(g, rng.integers(0, size), axis=0) * 0.6
    # scratches
    for _ in range(220):
        t = np.linspace(0, 1, int(rng.uniform(30, 120)))
        xs = rng.uniform(0, 1) + t * rng.uniform(-0.02, 0.02)
        ys = rng.uniform(0, 1) + t * rng.uniform(-0.02, 0.02)
        for i in range(len(t) - 1):
            px, py = int(xs[i] * size), int(ys[i] * size)
            base[max(0, py):py + 1, max(0, px):px + 1, :3] *= rng.uniform(0.6, 0.9)
    # stains
    for _ in range(4):
        cx, cy = rng.uniform(0, 1), rng.uniform(0, 1)
        r = rng.uniform(0.05, 0.18)
        d = np.sqrt((x_ := np.mgrid[0:size, 0:size][1] / size - cx) ** 2 + (np.mgrid[0:size, 0:size][0] / size - cy) ** 2)
        m = np.clip(1.0 - d / r, 0, 1)
        base[..., 0] *= (1 - m * 0.25); base[..., 1] *= (1 - m * 0.27); base[..., 2] *= (1 - m * 0.3)
    return base

def tex_composite(size=512):
    """Carbon-composite panel: dark resin, woven fibers and light abrasion."""
    y, x = np.mgrid[0:size, 0:size].astype(np.float32) / size
    rng = np.random.default_rng(57)
    # The weave must be almost invisible from an overview; otherwise each
    # box UV repeats into an implausible checker pattern.
    weave_a = (np.sin((x + y) * math.pi * 16.0) * 0.5 + 0.5)
    weave_b = (np.sin((x - y) * math.pi * 16.0) * 0.5 + 0.5)
    fiber = np.maximum(weave_a, weave_b)
    grain = rng.normal(0.0, 0.008, (size, size))
    value = 0.185 + fiber * 0.014 + grain
    base = np.empty((size, size, 4), np.float32)
    base[..., 0] = value * 0.80
    base[..., 1] = value * 0.91
    base[..., 2] = value * 1.05
    base[..., 3] = 1.0
    # Broad, restrained dust deposits—not high contrast camouflage.
    for _ in range(7):
        cx, cy = rng.uniform(0, 1), rng.uniform(0, 1)
        radius = rng.uniform(0.05, 0.17)
        mask = np.clip(1.0 - np.hypot(x - cx, y - cy) / radius, 0.0, 1.0)
        base[..., :3] += mask[..., None] * 0.014
    return base

def tex_rubber(size=512):
    """Matte anti-slip rubber with small molded dimples."""
    y, x = np.mgrid[0:size, 0:size].astype(np.float32) / size
    rng = np.random.default_rng(83)
    dimples = np.cos(x * math.pi * 48.0) * np.cos(y * math.pi * 48.0)
    grain = rng.normal(0.0, 0.022, (size, size))
    value = 0.070 + dimples * 0.018 + grain
    base = np.empty((size, size, 4), np.float32)
    base[..., 0] = value * 0.88
    base[..., 1] = value * 0.94
    base[..., 2] = value
    base[..., 3] = 1.0
    return base

def tex_hazard(size=512, red=False):
    """Weathered safety paint. The diagonal dark band reads on trim faces."""
    y, x = np.mgrid[0:size, 0:size].astype(np.float32) / size
    rng = np.random.default_rng(101 if not red else 107)
    stripe = (np.floor((x * 5.0 - y * 5.0) % 1.0 * 2.0) == 0)
    paint = np.empty((size, size, 3), np.float32)
    if red:
        paint[...] = (0.56, 0.045, 0.028)
    else:
        paint[...] = (0.90, 0.39, 0.025)
    paint[stripe] *= np.array((0.16, 0.18, 0.20), np.float32)
    paint += rng.normal(0.0, 0.025, (size, size, 1))
    # chipped flecks reveal a dull substrate.
    chips = rng.random((size, size)) > 0.987
    paint[chips] = np.array((0.22, 0.24, 0.25), np.float32)
    base = np.empty((size, size, 4), np.float32)
    base[..., :3] = np.clip(paint, 0.0, 1.0)
    base[..., 3] = 1.0
    return base

def tex_energy(size=256):
    """Emissive energy: soft radial glow + circuit veins."""
    y, x = np.mgrid[0:size, 0:size].astype(np.float32) / size
    base = np.zeros((size, size, 4), np.float32)
    d = np.sqrt((x - 0.5) ** 2 + (y - 0.5) ** 2)
    g = np.clip(1.0 - d / 0.6, 0, 1) ** 1.5
    base[..., 0] = 0.20 + 0.6 * g
    base[..., 1] = 0.65 + 0.35 * g
    base[..., 2] = 1.0
    base[..., 3] = 1.0
    # circuit veins
    rng = np.random.default_rng(5)
    for _ in range(16):
        t = np.linspace(0, 1, 40)
        xs = rng.uniform(0, 1) + t * rng.uniform(-0.4, 0.4)
        ys = rng.uniform(0, 1) + t * rng.uniform(-0.4, 0.4)
        for i in range(len(t) - 1):
            px, py = int(xs[i] * size), int(ys[i] * size)
            base[max(0, py):py + 2, max(0, px):px + 2, 0] = np.maximum(base[max(0, py):py + 2, max(0, px):px + 2, 0], 0.4)
    return base

def tex_cloud(size=256):
    """Soft cloud puff with alpha."""
    y, x = np.mgrid[0:size, 0:size].astype(np.float32) / size
    rng = np.random.default_rng(9)
    base = np.zeros((size, size, 4), np.float32)
    d = np.sqrt((x - 0.5) ** 2 + (y - 0.5) ** 2)
    a = np.clip(1.0 - d / 0.45, 0, 1) ** 1.3
    base[..., 0] = 0.93; base[..., 1] = 0.95; base[..., 2] = 0.98
    base[..., 3] = a
    for _ in range(28):
        cx, cy = rng.uniform(0.2, 0.8), rng.uniform(0.2, 0.8)
        r = rng.uniform(0.08, 0.2)
        dd = np.sqrt((x - cx) ** 2 + (y - cy) ** 2)
        m = np.clip(1.0 - dd / r, 0, 1) ** 1.5
        base[..., 3] = np.maximum(base[..., 3], m * rng.uniform(0.25, 0.7))
    return base

def _normal_from_height(height, strength):
    """Generate a tangent-space normal map from a procedural height field."""
    dy, dx = np.gradient(height)
    nx = -dx * strength
    ny = -dy * strength
    nz = np.ones_like(height)
    length = np.sqrt(nx * nx + ny * ny + nz * nz)
    normal = np.empty((*height.shape, 4), np.float32)
    normal[..., 0] = nx / length * 0.5 + 0.5
    normal[..., 1] = ny / length * 0.5 + 0.5
    normal[..., 2] = nz / length * 0.5 + 0.5
    normal[..., 3] = 1.0
    return normal

def _pbr_set(name, albedo, roughness, metallic, strength):
    """Derive normal and packed metallic/roughness/AO maps.

    These are authored procedural PBR maps, not photographs or scan data.
    The ORM channel order is R=metallic, G=roughness, B=ambient occlusion.
    """
    lum = albedo[..., 0] * 0.2126 + albedo[..., 1] * 0.7152 + albedo[..., 2] * 0.0722
    lo, hi = np.percentile(lum, (4, 96))
    height = np.clip((lum - lo) / max(hi - lo, 0.001), 0.0, 1.0)
    # PBR maps intentionally use 256² low-frequency variation: detailed enough
    # for the kit, compressible in every individually embedded GLB.
    pbr_size = 256
    height = np.asarray(PILImage.fromarray((height * 255).astype(np.uint8)).resize(
        (pbr_size, pbr_size), PILImage.Resampling.BICUBIC), dtype=np.float32) / 255.0
    rng = np.random.default_rng(sum(ord(c) for c in name) + 331)
    micro_src = ((rng.random((32, 32)) * 255).astype(np.uint8))
    micro = np.asarray(PILImage.fromarray(micro_src).resize(
        (pbr_size, pbr_size), PILImage.Resampling.BICUBIC), dtype=np.float32) / 255.0 - 0.5
    height = np.clip(height * 0.68 + micro * 0.12 + 0.16, 0.0, 1.0)
    normal_path = save_png(name + "_normal", _normal_from_height(height, strength))
    rough = np.clip(roughness + (0.50 - height) * 0.20 + micro * 0.06, 0.04, 0.98)
    metal = np.clip(metallic + micro * 0.04, 0.0, 1.0)
    ao = np.clip(0.76 + height * 0.24, 0.0, 1.0)
    orm = np.empty((*height.shape, 4), np.float32)
    orm[..., 0] = metal
    orm[..., 1] = rough
    orm[..., 2] = ao
    orm[..., 3] = 1.0
    orm_path = save_png(name + "_orm", orm)
    normal = bpy.data.images.load(normal_path)
    orm_img = bpy.data.images.load(orm_path)
    normal.colorspace_settings.name = 'Non-Color'
    orm_img.colorspace_settings.name = 'Non-Color'
    return normal, orm_img

def bake_textures():
    specs = {
        "aether_deck": (lambda s=512: blend_source_texture(tex_deck(s), "ai_weathered_steel.png", 0.36), 0.48, 0.42, 10.0),
        "aether_concrete": (lambda s=512: blend_source_texture(tex_concrete(s), "ai_poured_concrete.png", 0.72), 0.87, 0.00, 5.0),
        "aether_rock": (lambda s=512: blend_source_texture(tex_rock(s), "ai_sedimentary_rock.png", 0.30), 0.93, 0.00, 7.0),
        "aether_ice_rock": (tex_ice_rock, 0.78, 0.03, 8.5),
        "aether_metal": (lambda s=512: blend_source_texture(tex_metal(s), "ai_weathered_steel.png", 0.70), 0.38, 0.88, 5.5),
        "aether_metal2": (lambda s=512: blend_source_texture(tex_metal(s, seed=97), "ai_weathered_steel.png", 0.52), 0.28, 0.96, 4.0),
        "aether_composite": (tex_composite, 0.56, 0.12, 3.5),
        "aether_rubber": (tex_rubber, 0.82, 0.00, 8.0),
        "aether_hazard": (tex_hazard, 0.43, 0.10, 5.0),
        "aether_warning": (lambda s=512: tex_hazard(s, red=True), 0.48, 0.10, 5.0),
        "aether_energy": (tex_energy, None, None, None),
        "aether_cloud": (tex_cloud, None, None, None),
    }
    out = {}
    global PBR
    PBR = {}
    for name, (fn, rough, metal, strength) in specs.items():
        size = 512 if name not in ("aether_energy", "aether_cloud") else 256
        arr = fn(size)
        path = save_png(name, arr)
        img = bpy.data.images.load(path)
        img.colorspace_settings.name = 'sRGB'
        out[name] = img
        if rough is not None:
            normal, orm = _pbr_set(name, arr, rough, metal, strength)
            PBR[name] = {"normal": normal, "orm": orm}
        print("  texture", name, img.size[:], "PBR" if name in PBR else "colour")
    return out

print("== Aetherfall build: stage 1 textures ==")
TEX = bake_textures()

# ---------------------------------------------------------------------------
# Material library. Names are the contract with the Godot palette: the
# builder maps material names to AetherfallTokens the same way
# ScifiKitLibrary maps the station kit's "Orange" surface per model.
# ---------------------------------------------------------------------------
MATS = {}

def _principled(m):
    nt = m.node_tree
    b = nt.nodes.get("Principled BSDF")
    return b

def get_mat(name, base=(0.5, 0.5, 0.5, 1.0), rough=0.62, metal=0.25,
            tex=None, emission=None, emission_strength=0.0, alpha=1.0,
            transmission=0.0):
    if name in MATS:
        return MATS[name]
    m = bpy.data.materials.new(name)
    m.use_nodes = True
    b = _principled(m)
    b.inputs["Base Color"].default_value = (base[0], base[1], base[2], alpha)
    b.inputs["Roughness"].default_value = rough
    b.inputs["Metallic"].default_value = metal
    b.inputs["Specular IOR Level"].default_value = 0.55
    if transmission > 0.0:
        b.inputs["Transmission Weight"].default_value = transmission
        b.inputs["Transmission Weight"].default_value = transmission
    if emission is not None:
        b.inputs["Emission Color"].default_value = (emission[0], emission[1], emission[2], 1.0)
        b.inputs["Emission Strength"].default_value = emission_strength
    if tex is not None:
        img = TEX[tex]
        texnode = m.node_tree.nodes.new("ShaderNodeTexImage")
        texnode.name = "BaseColor_" + tex
        texnode.image = img
        texnode.interpolation = 'Linear'
        texnode.extension = 'REPEAT'
        img.colorspace_settings.name = 'sRGB'
        m.node_tree.links.new(texnode.outputs["Color"], b.inputs["Base Color"])
        if tex in PBR:
            normal_node = m.node_tree.nodes.new("ShaderNodeTexImage")
            normal_node.name = "Normal_" + tex
            normal_node.image = PBR[tex]["normal"]
            normal_node.interpolation = 'Linear'
            normal_node.extension = 'REPEAT'
            normal_map = m.node_tree.nodes.new("ShaderNodeNormalMap")
            normal_map.inputs["Strength"].default_value = 0.72
            m.node_tree.links.new(normal_node.outputs["Color"], normal_map.inputs["Color"])
            m.node_tree.links.new(normal_map.outputs["Normal"], b.inputs["Normal"])
            orm_node = m.node_tree.nodes.new("ShaderNodeTexImage")
            orm_node.name = "ORM_" + tex
            orm_node.image = PBR[tex]["orm"]
            orm_node.interpolation = 'Linear'
            orm_node.extension = 'REPEAT'
            separate = m.node_tree.nodes.new("ShaderNodeSeparateColor")
            separate.mode = 'RGB'
            m.node_tree.links.new(orm_node.outputs["Color"], separate.inputs["Color"])
            m.node_tree.links.new(separate.outputs["Red"], b.inputs["Metallic"])
            m.node_tree.links.new(separate.outputs["Green"], b.inputs["Roughness"])
        if emission is not None:
            b.inputs["Emission Color"].default_value = (emission[0], emission[1], emission[2], 1.0)
            b.inputs["Emission Strength"].default_value = emission_strength
    MATS[name] = m
    return m

def palette_materials():
    """The Aetherfall surface library, one entry per material category."""
    get_mat("Steel", base=(0.42, 0.45, 0.48, 1.0), rough=0.55, metal=0.85, tex="aether_metal")
    get_mat("PaintedSteel", base=(0.30, 0.34, 0.39, 1.0), rough=0.5, metal=0.35, tex="aether_deck")
    get_mat("Titanium", base=(0.55, 0.58, 0.62, 1.0), rough=0.35, metal=0.95, tex="aether_metal2")
    get_mat("Concrete", base=(0.52, 0.51, 0.50, 1.0), rough=0.85, metal=0.02, tex="aether_concrete")
    get_mat("Composite", base=(0.16, 0.19, 0.22, 1.0), rough=0.7, metal=0.1, tex="aether_composite")
    get_mat("Rock", base=(0.16, 0.29, 0.40, 1.0), rough=0.82, metal=0.03, tex="aether_ice_rock")
    get_mat("Stratum", base=(0.10, 0.20, 0.29, 1.0), rough=0.90, metal=0.02, tex="aether_ice_rock")
    get_mat("IceVein", base=(0.25, 0.62, 0.82, 1.0), rough=0.32, metal=0.05,
            tex="aether_ice_rock", emission=(0.08, 0.26, 0.38), emission_strength=0.14)
    get_mat("Glass", base=(0.35, 0.55, 0.68, 0.35), rough=0.08, metal=0.05,
            emission=(0.35, 0.72, 1.0), emission_strength=0.35, transmission=0.6)
    get_mat("Rubber", base=(0.10, 0.10, 0.11, 1.0), rough=0.85, metal=0.0, tex="aether_rubber")
    get_mat("Cable", base=(0.14, 0.15, 0.17, 1.0), rough=0.8, metal=0.0, tex="aether_rubber")
    get_mat("Energy", base=(0.10, 0.45, 0.85, 1.0), rough=0.4, metal=0.1,
            tex="aether_energy", emission=(0.25, 0.70, 1.0), emission_strength=2.4)
    get_mat("Hazard", base=(0.85, 0.55, 0.12, 1.0), rough=0.5, metal=0.1, tex="aether_hazard")
    get_mat("WarningRed", base=(0.8, 0.2, 0.2, 1.0), rough=0.5, metal=0.1, tex="aether_warning")
    print("  materials:", len(MATS))

palette_materials()

# ---------------------------------------------------------------------------
# Authored mesh ownership. Aetherfall's visible kit is made of closed lofts,
# extrusions and terrain volumes; no primitive blockout helpers remain.
# ---------------------------------------------------------------------------
def new_collection(name):
    c = bpy.data.collections.get(name)
    if c is None:
        c = bpy.data.collections.new(name)
    return c

ASSETS = {}          # key -> bpy.data.collections.new("A_<key>")

def noise2(x, z, oct=4, seed=7):
    s = 0.0
    amp = 1.0
    freq = 1.0
    for _ in range(oct):
        s += amp * (math.sin(x * freq * 1.31 + seed) * math.cos(z * freq * 1.07 + seed * 1.7)
                    + 0.5 * math.sin((x + z) * freq * 0.63 + seed * 2.3))
        amp *= 0.5
        freq *= 2.1
    return s / 1.7


# ---------------------------------------------------------------------------
# Authored mesh helpers.  These deliberately make closed, shaped volumes (not
# tiled planes nor scaled cubes) so the exterior reads as geology and machinery
# from both ground-level and distant cameras.
# ---------------------------------------------------------------------------
def mesh_object(coll, name, verts, faces, matnames, face_mats=None, uv_scale=0.12):
    me = bpy.data.meshes.new(name)
    me.from_pydata(verts, [], faces)
    me.materials.clear()
    for matname in matnames:
        me.materials.append(get_mat(matname))
    me.uv_layers.new(name="UVMap")
    for poly in me.polygons:
        poly.use_smooth = False
        if face_mats is not None and poly.index < len(face_mats):
            poly.material_index = face_mats[poly.index]
        for li in poly.loop_indices:
            v = me.vertices[me.loops[li].vertex_index].co
            # One authored UV unit covers a compact service-scale region. The
            # multiplier keeps PBR maps physically repeating on canyon-scale
            # geometry instead of becoming a single stretched colour field.
            metric_scale = uv_scale * 3.0
            me.uv_layers.active.data[li].uv = (v.x * metric_scale, v.z * metric_scale + v.y * metric_scale * 0.15)
    me.update()
    obj = bpy.data.objects.new(name, me)
    coll.objects.link(obj)
    return obj

def irregular_outline(radius_x, radius_z, count=12, seed=1.0, phase=0.0):
    out = []
    for i in range(count):
        a = phase + math.tau * i / count
        jitter = 0.84 + 0.15 * (0.5 + 0.5 * noise2(math.cos(a) * 2.7, math.sin(a) * 2.7, 3, seed))
        out.append((math.cos(a) * radius_x * jitter, math.sin(a) * radius_z * jitter))
    return out

def outline_prism(coll, name, outline, y0, y1, matname, side_mat=None, pos=(0.0, 0.0, 0.0), uv_scale=0.12):
    """An extruded, non-rectilinear plate/ledge. Outline coordinates are X/Z."""
    # Concise kit calls may pass UV scale as the final positional value.
    if isinstance(pos, (int, float)):
        uv_scale = float(pos)
        pos = (0.0, 0.0, 0.0)
    n = len(outline)
    verts = [(x + pos[0], y0 + pos[1], z + pos[2]) for x, z in outline]
    verts += [(x + pos[0], y1 + pos[1], z + pos[2]) for x, z in outline]
    faces = [tuple(range(n - 1, -1, -1)), tuple(range(n, 2 * n))]
    face_mats = [1 if side_mat else 0, 0]
    for i in range(n):
        j = (i + 1) % n
        faces.append((i, j, n + j, n + i))
        face_mats.append(1 if side_mat else 0)
    return mesh_object(coll, name, verts, faces, [matname] + ([side_mat] if side_mat else []), face_mats, uv_scale)

def loft_volume(coll, name, rings, matname, sides=8, phase=0.0, side_mat=None, uv_scale=0.12):
    """Closed taper/stepped shell from (y, radius_x, radius_z, cx, cz) rings."""
    verts = []
    for y, rx, rz, cx, cz in rings:
        for i in range(sides):
            a = phase + math.tau * i / sides
            # Controlled asymmetric wobble stops identical cylinders/cubes.
            wobble = 1.0 + 0.045 * math.sin(i * 4.7 + y * 0.71)
            verts.append((cx + math.cos(a) * rx * wobble, y, cz + math.sin(a) * rz * wobble))
    faces = [tuple(range(sides - 1, -1, -1))]
    face_mats = [1 if side_mat else 0]
    for ring in range(len(rings) - 1):
        off = ring * sides
        for i in range(sides):
            j = (i + 1) % sides
            faces.append((off + i, off + j, off + sides + j, off + sides + i))
            face_mats.append(0)
    end = (len(rings) - 1) * sides
    faces.append(tuple(end + i for i in range(sides)))
    face_mats.append(1 if side_mat else 0)
    return mesh_object(coll, name, verts, faces, [matname] + ([side_mat] if side_mat else []), face_mats, uv_scale)

def terrain_volume(coll, name, size_x, size_z, seg, top_fn, bottom, matname="Rock"):
    """Watertight displaced terrain: a top surface, deep mass, and visible cliff walls."""
    verts = []
    for layer in range(2):
        for iz in range(seg + 1):
            z = -size_z * 0.5 + size_z * iz / seg
            for ix in range(seg + 1):
                x = -size_x * 0.5 + size_x * ix / seg
                y = top_fn(x, z) if layer == 0 else bottom
                verts.append((x, y, z))
    stride = seg + 1
    top_offset = 0
    bot_offset = stride * stride
    faces = []; face_mats = []
    def q(a, b, c, d, mi):
        faces.append((a, b, c, d)); face_mats.append(mi)
    for iz in range(seg):
        for ix in range(seg):
            a = top_offset + iz * stride + ix
            q(a, a + stride, a + stride + 1, a + 1, 0)
            b = bot_offset + iz * stride + ix
            q(b + 1, b + stride + 1, b + stride, b, 1)
    # Four sides give the terrain physical depth from the canyon and from the sky.
    for ix in range(seg):
        a = ix; b = ix + 1
        q(a, b, bot_offset + b, bot_offset + a, 1)
        a = seg * stride + ix; b = a + 1
        q(b, a, bot_offset + a, bot_offset + b, 1)
    for iz in range(seg):
        a = iz * stride; b = a + stride
        q(b, a, bot_offset + a, bot_offset + b, 1)
        a = iz * stride + seg; b = a + stride
        q(a, b, bot_offset + b, bot_offset + a, 1)
    return mesh_object(coll, name, verts, faces, [matname, "Stratum"], face_mats, 0.095)

def rock_boulder_mesh(coll, name, radius, matname="Rock", seed=1.0):
    rings, sides = 8, 13
    verts = []
    for j in range(rings + 1):
        v = j / rings
        polar = math.pi * v
        for i in range(sides):
            a = math.tau * i / sides
            irregular = 0.76 + 0.36 * (0.5 + 0.5 * noise2(math.cos(a) * 2.0 + v, math.sin(a) * 2.0, 3, seed))
            r = radius * irregular
            verts.append((math.cos(a) * math.sin(polar) * r, math.cos(polar) * radius * (0.9 + 0.15 * irregular), math.sin(a) * math.sin(polar) * r))
    faces = []
    for j in range(rings):
        for i in range(sides):
            a = j * sides + i; b = j * sides + (i + 1) % sides
            faces.append((a, b, b + sides, a + sides))
    # A boulder still uses metre-scale texture density; its UVs must repeat
    # across the large cryo faces instead of stretching one map over the shell.
    return mesh_object(coll, name, verts, faces, [matname], None, 0.55)

def facade_fin(coll, name, angle, radius, y0, y1, width, depth, matname="Steel"):
    """Tapered exterior fin with a deliberate radial orientation."""
    ca, sa = math.cos(angle), math.sin(angle)
    tx, tz = -sa, ca
    cx, cz = ca * radius, sa * radius
    outline = [(-width, -depth), (width, -depth * 0.55), (width * 0.72, depth), (-width * 0.72, depth * 0.7)]
    world = [(cx + tx * x + ca * z, cz + tz * x + sa * z) for x, z in outline]
    return outline_prism(coll, name, world, y0, y1, matname, "Composite", uv_scale=0.18)
def vertical_profile(coll, name, profile, z0, z1, matname, side_mat=None, uv_scale=0.18):
    """Extrude an X/Y silhouette through Z for gates, walls and combat cover."""
    n = len(profile)
    verts = [(x, y, z0) for x, y in profile] + [(x, y, z1) for x, y in profile]
    faces = [tuple(range(n - 1, -1, -1)), tuple(range(n, 2 * n))]
    face_mats = [1 if side_mat else 0, 0]
    for i in range(n):
        j = (i + 1) % n
        faces.append((i, j, n + j, n + i)); face_mats.append(1 if side_mat else 0)
    return mesh_object(coll, name, verts, faces, [matname] + ([side_mat] if side_mat else []), face_mats, uv_scale)



def reg(key, coll):
    ASSETS[key] = coll
    if coll.name not in [c.name for c in SCENE_COLL.children]:
        SCENE_COLL.children.link(coll)
    print("  asset", key, "->", coll.name)

# ---------------------------- geology + architecture ----------------------
def b_terrain_chunk():
    coll = new_collection("A_terrain_chunk")
    # This is a deep landform; the visible sides carry horizontal mineral strata.
    def height(x, z):
        rim = 1.9 * math.sin(z * 0.11) + 1.1 * math.cos(x * 0.13)
        erosion = 3.1 * noise2(x * 0.11, z * 0.11, 5, 17.0)
        shelf = 1.15 * math.sin((z + x * 0.22) * 0.34)
        return 1.5 + rim + erosion + shelf
    terrain_volume(coll, "GlacialTerrainMass", 48.0, 48.0, 28, height, -22.0)
    # Receding shelves make the chunk read as a cut glacier rather than a noise plane.
    for level, scale in [(-8.2, 0.91), (-13.2, 0.78), (-17.8, 0.63)]:
        outline_prism(coll, "StrataShelf_%s" % str(abs(level)).replace('.', '_'),
                      irregular_outline(22.5 * scale, 22.5 * scale, 15, 40.0 + level),
                      level - 0.55, level, "Stratum", "Rock", uv_scale=0.09)
    # Blue pressure seams have a narrative role: they lead toward the Archive tower.
    for i, x in enumerate((-11.0, -3.5, 5.0, 13.0)):
        outline_prism(coll, "CryoSeam%d" % i,
                      [(x - 0.42, -18.0), (x + 0.22, -17.8), (x + 0.75, 13.0), (x - 0.25, 13.4)],
                      -0.08, 0.12, "IceVein", uv_scale=0.2)
    reg("terrain_chunk", coll)
    return coll
def b_cliff_face():
    coll = new_collection("A_cliff_face")
    # A stepped, irregular escarpment with real face depth; not a displaced plane.
    sx, levels, rows = 30.0, 17, 15
    verts = []
    for back in (False, True):
        for iy in range(levels + 1):
            y = -12.0 + 20.0 * iy / levels
            terrace = 1.25 * math.floor((y + 12.0) / 4.2)
            for ix in range(rows + 1):
                x = -sx * 0.5 + sx * ix / rows
                broken = noise2(x * 0.23, y * 0.20, 4, 29.0) * 1.45
                z = (-5.1 + terrace + broken) if not back else (7.0 + 0.38 * broken)
                verts.append((x, y, z))
    stride = rows + 1; half = (levels + 1) * stride
    faces=[]; mats=[]
    def q(a,b,c,d,mi): faces.append((a,b,c,d)); mats.append(mi)
    for iy in range(levels):
        for ix in range(rows):
            a=iy*stride+ix; q(a,a+1,a+stride+1,a+stride,0)
            b=half+iy*stride+ix; q(b+stride,b+stride+1,b+1,b,1)
    for iy in range(levels):
        a=iy*stride; b=a+stride; q(a,b,half+b,half+a,1)
        a=iy*stride+rows; b=a+stride; q(b,a,half+a,half+b,1)
    for ix in range(rows):
        a=ix; b=ix+1; q(b,a,half+a,half+b,1)
        a=levels*stride+ix; b=a+1; q(a,b,half+b,half+a,1)
    mesh_object(coll,"EscarpmentVolume",verts,faces,["Rock","Stratum"],mats,0.11)
    # Ice shelves and anchored extraction braces relate the cliff to robot occupation.
    for i, y in enumerate((-6.6, -2.3, 2.1, 5.5)):
        outline_prism(coll, "ErosionLedge%d" % i,
                      [(-14.8, -5.7 + i * 0.35), (14.6, -5.1 + i * 0.28), (13.7, -3.8 + i * 0.25), (-13.9, -4.0 + i * 0.22)],
                      y - 0.42, y, "Stratum", "Rock", uv_scale=0.11)
    for i, x in enumerate((-10.0, -3.2, 4.0, 10.8)):
        facade_fin(coll, "AnchorButtress%d" % i, math.pi, 4.8, -7.0, 4.2, 0.48, 0.55, "Steel")
    reg("cliff_face", coll)
    return coll
def b_rock_boulder():
    coll = new_collection("A_rock_boulder")
    rock_boulder_mesh(coll, "FacetedCryoBoulder", 3.7, "Rock", 43.0)
    outline_prism(coll, "BoulderIcePlate", irregular_outline(2.5, 1.5, 9, 4.0), -1.8, -1.45, "Stratum", "Rock")
    # A fracture plate makes the boulder useful as both cover and direction marker.
    outline_prism(coll, "BoulderVein", [(-0.24,-2.1),(0.42,-1.9),(0.62,2.0),(-0.12,2.3)], -0.15, 0.05, "IceVein")
    reg("rock_boulder", coll)
    return coll
def b_deck_6x6():
    coll = new_collection("A_deck_6x6")
    # Chamfered armour plate plus recessed service bay and underside sub-frame.
    outline = [(-2.55,-3.0),(2.25,-3.0),(3.0,-2.25),(3.0,2.4),(2.35,3.0),(-2.35,3.0),(-3.0,2.2),(-3.0,-2.35)]
    outline_prism(coll, "ChamferedDeckArmour", outline, -0.38, 0.10, "PaintedSteel", "Steel", uv_scale=0.22)
    inset = [(x * 0.78, z * 0.76) for x,z in outline]
    outline_prism(coll, "RecessedServiceBay", inset, 0.08, 0.145, "Composite", "Steel", uv_scale=0.3)
    # Four distinct retaining rails interrupt the tiled silhouette with functional seams.
    for i, (x,z,w,d) in enumerate([(0,-2.34,4.0,0.16),(2.32,0,0.16,3.9),(0,2.28,3.7,0.14),(-2.35,0,0.14,3.8)]):
        rail=[(x-w/2,z-d/2),(x+w/2,z-d/2),(x+w/2,z+d/2),(x-w/2,z+d/2)]
        outline_prism(coll,"DeckRetention%d"%i,rail,0.13,0.24,"Steel","Composite",uv_scale=0.45)
    for i, x in enumerate((-1.65, 0.0, 1.65)):
        rail=[(x-0.13,-2.42),(x+0.13,-2.42),(x+0.13,2.38),(x-0.13,2.38)]
        outline_prism(coll,"DeckUndersideRib%d"%i,rail,-0.64,-0.38,"Steel","Composite",uv_scale=0.3)
    reg("deck_6x6", coll)
    return coll
def b_deck_edge():
    coll = new_collection("A_deck_edge")
    # An angled safety fascia gives the platform a thick outer silhouette.
    outline=[(-3.0,-0.48),(2.45,-0.48),(3.0,-0.20),(3.0,0.42),(-2.65,0.42),(-3.0,0.16)]
    outline_prism(coll,"EdgeArmour",outline,-0.40,0.13,"PaintedSteel","Steel",uv_scale=0.26)
    hazard=[(-2.76,-0.30),(2.25,-0.30),(2.72,-0.10),(2.72,0.04),(-2.7,0.04)]
    outline_prism(coll,"EdgeHazardInset",hazard,0.13,0.20,"Hazard","Steel",uv_scale=0.5)
    for i,x in enumerate((-2.15,-0.65,0.85,2.25)):
        outline_prism(coll,"EdgeTie%d"%i,[(x-0.06,-0.54),(x+0.06,-0.54),(x+0.08,0.47),(x-0.08,0.47)],-0.55,-0.36,"Steel","Composite",uv_scale=0.4)
    reg("deck_edge", coll)
    return coll
def b_pillar():
    coll = new_collection("A_pillar")
    outline_prism(coll,"PillarFoot",irregular_outline(1.05,1.05,6,12.0),0.0,0.45,"Concrete","Steel",uv_scale=0.3)
    loft_volume(coll,"PillarTaper",[(0.4,0.65,0.65,0,0),(2.1,0.48,0.48,0,0),(4.9,0.54,0.54,0,0),(5.6,0.84,0.84,0,0)],"Steel",6,0.0,"Composite",0.3)
    for i in range(3):
        facade_fin(coll,"PillarClamp%d"%i,math.radians(90),0.50,1.35+i*1.45,1.62+i*1.45,0.12,0.16,"Titanium")
    reg("pillar",coll)
    return coll
def b_beam():
    coll = new_collection("A_beam")
    # Hexagonal service girder has web and lower cable raceway, not a plain box.
    outline=[(-0.48,-4.0),(0.30,-4.0),(0.52,-3.55),(0.52,3.55),(0.30,4.0),(-0.48,4.0),(-0.67,3.55),(-0.67,-3.55)]
    outline_prism(coll,"FacetedBeam",outline,-0.35,0.32,"Steel","Composite",uv_scale=0.24)
    outline_prism(coll,"BeamCableRaceway",[(-0.30,-3.75),(0.12,-3.75),(0.28,3.75),(-0.20,3.75)],-0.56,-0.34,"Composite","Steel",uv_scale=0.38)
    reg("beam",coll)
    return coll
def b_wall_section():
    coll = new_collection("A_wall_section")
    profile=[(-2.1,0.0),(-1.78,2.65),(-1.22,3.15),(1.45,3.15),(2.1,2.58),(1.9,0.0)]
    vertical_profile(coll,"RecessedWallShell",profile,-0.26,0.16,"Composite","Steel",0.24)
    # Layered service panels on the face form meaningful facade recesses.
    for i,x in enumerate((-1.15,0.0,1.15)):
        p=[(x-0.42,0.55),(x-0.30,2.22),(x+0.28,2.42),(x+0.44,0.6)]
        vertical_profile(coll,"WallServicePanel%d"%i,p,0.14,0.29,"Steel","Composite",0.32)
    vertical_profile(coll,"WallCrown",[(-1.7,2.65),(-1.05,3.38),(1.2,3.38),(1.75,2.62)],-0.32,0.29,"Titanium","Composite",0.24)
    reg("wall_section",coll)
    return coll
print("== Aetherfall build: stage 3 geology + architecture ==")
b_terrain_chunk(); b_cliff_face(); b_rock_boulder()
b_deck_6x6(); b_deck_edge(); b_pillar(); b_beam(); b_wall_section()


# ---------------------------- tower --------------------------------------
def b_tower_foundation():
    coll = new_collection("A_tower_foundation")
    # Archive tower base is a multi-level docking plinth rather than a solid cube.
    outline_prism(coll,"ArchivePlinthOuter",irregular_outline(10.7,10.0,10,8.0,0.15),-0.5,0.45,"Concrete","Stratum",uv_scale=0.11)
    outline_prism(coll,"ArchivePlinthStep",irregular_outline(8.9,8.4,10,9.0,0.15),0.43,1.18,"Steel","Composite",uv_scale=0.16)
    outline_prism(coll,"ArchiveSocket",irregular_outline(6.9,6.5,10,10.0,0.15),1.12,2.25,"Composite","Steel",uv_scale=0.18)
    for i in range(8):
        a=math.tau*i/8.0+math.pi/8.0
        facade_fin(coll,"FoundationButtress%d"%i,a,8.6,0.0,5.8,0.72,0.72,"Steel")
    # Inward cyan guidance segments identify the entrance-facing side of the landmark.
    for i in range(4):
        a=math.radians(205+i*10)
        facade_fin(coll,"FoundationGuide%d"%i,a,6.7,1.85,2.13,0.14,0.22,"Energy")
    reg("tower_foundation",coll)
    return coll
def b_tower_tier():
    coll = new_collection("A_tower_tier")
    # Stepped ten-sided archive shell: silhouette, deep shadow bands, and exterior fins.
    rings=[(0.0,6.45,6.15,0,0),(0.7,6.75,6.45,0,0),(1.25,5.95,5.65,0,0),(7.65,4.75,4.50,0,0),(8.25,5.25,4.98,0,0),(9.25,4.45,4.20,0,0)]
    loft_volume(coll,"ArchiveTierShell",rings,"Steel",10,math.pi/10.0,"Composite",0.16)
    # Recessed dark belt is intentionally set behind fins to create facade depth.
    belt=[(1.65,5.77,5.48,0,0),(3.0,5.49,5.20,0,0),(3.4,5.52,5.23,0,0),(4.7,5.25,4.98,0,0)]
    loft_volume(coll,"ArchiveRecessBelt",belt,"Composite",10,math.pi/10.0,"Steel",0.22)
    for i in range(10):
        a=math.tau*i/10.0+math.pi/10.0
        facade_fin(coll,"ArchiveVerticalFin%d"%i,a,5.75,0.85,8.45,0.34,0.42,"Titanium")
        # Narrow energy telltales create a readable hierarchy without flattening the facade.
        if i in (0,1,4,5,8):
            facade_fin(coll,"ArchiveEnergyTrace%d"%i,a,5.96,2.2,6.8,0.075,0.13,"Energy")
    reg("tower_tier",coll)
    return coll
def b_tower_spire():
    coll = new_collection("A_tower_spire")
    rings=[(0.0,4.7,4.4,0,0),(0.6,5.15,4.85,0,0),(1.2,3.7,3.45,0,0),(8.6,2.05,1.85,0,0),(10.2,2.65,2.35,0,0),(12.4,1.15,1.0,0,0),(18.5,0.13,0.13,0,0)]
    loft_volume(coll,"ArchiveSpireShell",rings,"Steel",8,math.pi/8.0,"Composite",0.18)
    loft_volume(coll,"SpireEnergyCollar",[(1.35,4.0,3.7,0,0),(1.86,4.0,3.7,0,0)],"Energy",8,math.pi/8.0,"Steel",0.22)
    # Three off-axis sensor vanes avoid a generic single-point tower silhouette.
    for i,a in enumerate((math.radians(15),math.radians(135),math.radians(255))):
        cx,cz=math.cos(a)*2.5,math.sin(a)*2.5
        loft_volume(coll,"SensorVane%d"%i,[(5.0,0.38,0.28,cx,cz),(14.0,0.22,0.16,cx*1.65,cz*1.65),(16.0,0.05,0.05,cx*2.0,cz*2.0)],"Titanium",5,a,"Composite",0.25)
    reg("tower_spire",coll)
    return coll
def b_energy_core():
    coll = new_collection("A_energy_core")
    # A nested hex-core with containment petals provides the Archive objective landmark.
    loft_volume(coll,"CorePlinth",[(0.0,5.8,5.35,0,0),(0.55,6.35,5.85,0,0),(1.1,5.15,4.75,0,0)],"Steel",8,math.pi/8,"Composite",0.2)
    loft_volume(coll,"CoreContainment",[(1.0,4.3,3.9,0,0),(6.7,3.42,3.1,0,0),(7.7,2.52,2.28,0,0)],"Glass",8,math.pi/8,"Steel",0.22)
    loft_volume(coll,"CoreEnergyColumn",[(1.25,2.62,2.35,0,0),(7.35,2.12,1.93,0,0)],"Energy",8,math.pi/8,"Steel",0.27)
    for i in range(6):
        a=math.tau*i/6.0
        facade_fin(coll,"CorePetal%d"%i,a,4.65,1.15,6.75,0.3,0.34,"Titanium")
    reg("energy_core",coll)
    return coll
# ---------------------------- bridges / walkways -------------------------
def b_bridge_deck():
    coll = new_collection("A_bridge_deck")
    outline=[(-2.85,-4.0),(2.35,-4.0),(3.0,-3.25),(3.0,3.3),(2.35,4.0),(-2.45,4.0),(-3.0,3.15),(-3.0,-3.35)]
    outline_prism(coll,"BridgeArmourDeck",outline,-0.46,0.16,"PaintedSteel","Steel",0.22)
    outline_prism(coll,"BridgeServiceChannel",[(-0.44,-3.72),(0.45,-3.72),(0.55,3.7),(-0.32,3.7)],0.15,0.26,"Composite","Steel",0.34)
    for side in (-1.0,1.0):
        for i,z in enumerate((-2.9,0.0,2.9)):
            loft_volume(coll,"BridgeRailPost%d%d"%(int(side*10),i),[(0.15,0.15,0.15,side*2.72,z),(1.55,0.11,0.11,side*2.72,z)],"Steel",5,0.0,"Composite",0.4)
        outline_prism(coll,"BridgeRail%d"%int(side*10),[(side*2.88,-3.9),(side*2.88+side*0.12,-3.9),(side*2.88+side*0.12,3.9),(side*2.88,3.9)],1.43,1.58,"Titanium","Steel",0.35)
    reg("bridge_deck",coll)
    return coll
def b_bridge_support():
    coll = new_collection("A_bridge_support")
    loft_volume(coll,"CanyonPylon",[(0.0,3.15,2.8,0,0),(1.8,3.55,3.15,0,0),(3.0,1.7,1.55,0,0),(13.4,1.06,0.95,0,0),(14.6,2.25,2.0,0,0)],"Steel",6,math.pi/6,"Composite",0.18)
    outline_prism(coll,"PylonFoot",irregular_outline(4.3,3.8,7,18.0),0.0,1.3,"Concrete","Stratum",0.14)
    for i,a in enumerate((math.radians(45),math.radians(135),math.radians(225),math.radians(315))):
        facade_fin(coll,"PylonBrace%d"%i,a,2.25,2.0,11.5,0.32,0.45,"Titanium")
    reg("bridge_support",coll)
    return coll
def b_walkway_deck():
    coll = new_collection("A_walkway_deck")
    outline=[(-0.86,-3.0),(0.63,-3.0),(0.9,-2.65),(0.9,2.65),(0.58,3.0),(-0.7,3.0),(-0.92,2.62),(-0.92,-2.66)]
    outline_prism(coll,"CatwalkArmour",outline,-0.30,0.13,"PaintedSteel","Steel",0.3)
    for i,z in enumerate((-2.0,0.0,2.0)):
        outline_prism(coll,"CatwalkTread%d"%i,[(-0.62,z-0.12),(0.62,z-0.12),(0.70,z+0.10),(-0.66,z+0.10)],0.13,0.19,"Titanium","Steel",0.45)
    # Actual edge protection and cable tray give the recovery catwalk a purpose.
    for side in (-1.0, 1.0):
        x = side * 0.73
        for i,z in enumerate((-2.55, -0.85, 0.85, 2.55)):
            loft_volume(coll,"WalkwayPost%d%d"%(int(side*10),i),[(0.0,0.075,0.075,x,z),(1.18,0.055,0.055,x,z)],"Steel",5,0.0,"Composite",0.55)
        outline_prism(coll,"WalkwayRail%d"%int(side*10),[(x-0.05,-3.0),(x+0.05,-3.0),(x+0.05,3.0),(x-0.05,3.0)],1.10,1.20,"Titanium","Steel",0.45)
    outline_prism(coll,"WalkwayCableTray",[(-0.18,-2.88),(0.18,-2.88),(0.18,2.88),(-0.18,2.88)],0.23,0.36,"Composite","Steel",0.55)
    reg("walkway_deck",coll)
    return coll
def b_damaged_slab():
    coll = new_collection("A_damaged_slab")
    # Broken route marker: separated plates create a navigable visual warning.
    for i,(x,z,scale) in enumerate(((-2.5,-0.8,1.0),(0.5,0.25,1.2),(2.8,-1.2,0.78),(-1.2,1.6,0.85))):
        outline=[(x-1.3*scale,z-1.0*scale),(x+1.15*scale,z-0.9*scale),(x+1.4*scale,z+0.75*scale),(x-1.0*scale,z+1.1*scale)]
        outline_prism(coll,"FracturedPlate%d"%i,outline,-0.45-i*0.08,0.05,"PaintedSteel","Steel",0.24)
    # A collapsed upright rib gives the route break a real vertical hazard silhouette.
    vertical_profile(coll,"CollapsedRib",[(-1.7,0.0),(-1.2,2.65),(-0.72,2.88),(-0.3,0.0)],-1.6,-0.85,"Concrete","Stratum",0.22)
    outline_prism(coll,"DamagedEnergyLeak",[(-0.18,-2.6),(0.35,-2.4),(0.52,2.3),(-0.08,2.6)],-0.06,0.05,"Energy",None,0.45)
    reg("damaged_slab",coll)
    return coll
# ---------------------------- industrial detail ---------------------------
def b_machinery():
    coll = new_collection("A_machinery")
    outline_prism(coll,"MachineFoot",irregular_outline(2.35,1.9,7,31.0),0.0,0.52,"Concrete","Steel",0.2)
    loft_volume(coll,"MachineBody",[(0.48,2.1,1.75,0,0),(1.0,2.35,1.98,0,0),(3.4,1.65,1.42,0,0),(4.55,0.82,0.72,0,0)],"Steel",7,0.12,"Composite",0.22)
    loft_volume(coll,"MachineCoolantNeck",[(3.1,0.64,0.55,0.82,0.2),(5.45,0.42,0.34,1.12,0.2)],"Titanium",6,0.0,"Steel",0.35)
    facade_fin(coll,"MachineEnergyPanel",math.radians(90),2.02,1.25,3.35,0.24,0.13,"Energy")
    reg("machinery",coll)
    return coll
def b_cooling_vent():
    coll = new_collection("A_cooling_vent")
    loft_volume(coll,"VentHousing",[(0.0,2.25,2.25,0,0),(0.45,2.55,2.55,0,0),(2.35,2.1,2.1,0,0),(3.3,1.62,1.62,0,0)],"Steel",10,math.pi/10,"Composite",0.24)
    loft_volume(coll,"VentThroat",[(0.3,1.58,1.58,0,0),(2.52,1.30,1.30,0,0)],"Composite",10,math.pi/10,"Steel",0.35)
    for i in range(8):
        a=math.tau*i/8
        facade_fin(coll,"VentBlade%d"%i,a,1.0,2.42,3.18,0.12,0.19,"Titanium")
    reg("cooling_vent",coll)
    return coll
def b_conduit():
    coll = new_collection("A_conduit")
    loft_volume(coll,"ConduitArmour",[(0.0,0.45,0.45,0,0),(6.0,0.36,0.36,0,0)],"Steel",8,math.pi/8,"Composite",0.45)
    loft_volume(coll,"ConduitEnergyCore",[(0.12,0.22,0.22,0,0),(5.88,0.18,0.18,0,0)],"Energy",7,0.0,"Steel",0.6)
    for i,y in enumerate((1.0,3.0,5.0)):
        outline_prism(coll,"ConduitCollar%d"%i,irregular_outline(0.62,0.62,6,44+i),y-0.10,y+0.10,"Titanium","Steel",0.8)
    reg("conduit",coll)
    return coll
def b_cable_bundle():
    coll = new_collection("A_cable_bundle")
    # Five separated conduits on an armoured tray preserve the readable cable silhouette.
    outline_prism(coll,"CableTray",[(-0.46,-3.0),(0.46,-3.0),(0.46,3.0),(-0.46,3.0)],-0.16,0.08,"Steel","Composite",0.45)
    for i,x in enumerate((-0.28,-0.14,0.0,0.14,0.28)):
        outline_prism(coll,"CableRun%d"%i,[(x-0.055,-2.88),(x+0.055,-2.88),(x+0.055,2.88),(x-0.055,2.88)],0.09,0.22,"Cable","Steel",0.7)
    reg("cable_bundle",coll)
    return coll
def b_railing():
    coll = new_collection("A_railing")
    # Two complete edge rails span the 6 m bridge section; posts now connect to them.
    for side in (-1.0, 1.0):
        x = side * 2.7
        for i,z in enumerate((-2.65,-0.88,0.88,2.65)):
            loft_volume(coll,"RailPost%d%d"%(int(side*10),i),[(0.0,0.11,0.11,x,z),(1.32,0.075,0.075,x,z)],"Steel",5,0.0,"Composite",0.55)
        for name,y,thick in (("RailTop",1.24,0.12),("RailMid",0.68,0.085)):
            outline_prism(coll,name+str(int(side*10)),[(x-thick/2,-3.0),(x+thick/2,-3.0),(x+thick/2,3.0),(x-thick/2,3.0)],y-thick/2,y+thick/2,"Titanium","Steel",0.5)
    outline_prism(coll,"RailKick",[(-2.9,-3.0),(2.9,-3.0),(2.9,3.0),(-2.9,3.0)],0.02,0.16,"Steel","Composite",0.5)
    reg("railing",coll)
    return coll
def b_debris_cluster():
    coll = new_collection("A_debris_cluster")
    # Purposeful wreck pieces: an overturned housing, fractured plating, and a live cable end.
    rock_boulder_mesh(coll,"WreckedHousing",1.95,"Steel",55.0)
    for i,(x,z,sc) in enumerate(((-2.3,0.7,0.9),(1.7,-1.1,1.1),(0.9,1.9,0.7))):
        outline_prism(coll,"WreckPlate%d"%i,[(x-1.0*sc,z-0.7*sc),(x+0.9*sc,z-0.9*sc),(x+1.1*sc,z+0.65*sc),(x-0.7*sc,z+0.8*sc)],0.05,0.34,"Steel","Composite",0.3)
    loft_volume(coll,"ExposedCable",[(0.0,0.22,0.22,-0.55,0.0),(2.2,0.14,0.14,-0.2,0.6)],"Energy",7,0.0,"Steel",0.55)
    reg("debris_cluster",coll)
    return coll
# ---------------------------- gameplay objects -----------------------------
def b_cover_barrier():
    coll = new_collection("A_cover_barrier")
    profile=[(-1.32,0.0),(-1.2,0.95),(-0.72,1.28),(0.88,1.28),(1.3,0.88),(1.18,0.0)]
    vertical_profile(coll,"ArmouredCover",profile,-0.36,0.34,"Steel","Composite",0.32)
    vertical_profile(coll,"CoverHazardMark",[(-0.92,0.83),(-0.70,1.10),(0.74,1.10),(0.98,0.83)],0.335,0.39,"Hazard","Steel",0.55)
    reg("cover_barrier",coll)
    return coll
def b_cover_machine():
    coll = new_collection("A_cover_machine")
    outline_prism(coll,"MachineCoverFoot",irregular_outline(2.35,1.7,7,67.0),0.0,0.48,"Concrete","Steel",0.22)
    loft_volume(coll,"MachineCoverShell",[(0.4,2.0,1.48,0,0),(1.15,2.18,1.62,0,0),(2.45,1.65,1.32,0,0),(3.2,1.15,0.94,0,0)],"Steel",7,0.15,"Composite",0.25)
    facade_fin(coll,"MachineCoverTrace",math.radians(90),1.85,1.05,2.45,0.13,0.12,"Energy")
    reg("cover_machine",coll)
    return coll
def b_access_gate():
    coll = new_collection("A_access_gate")
    # Two tapered pylons frame a real threshold with a segmented energy seal.
    outline_prism(coll,"GateThreshold",[(-3.9,-3.0),(3.75,-2.9),(4.05,-2.1),(4.05,2.3),(3.45,3.0),(-3.6,2.85),(-4.0,2.1)],-0.34,0.12,"PaintedSteel","Steel",0.20)
    for side in (-1.0,1.0):
        loft_volume(coll,"GatePylon%d"%int(side*10),[(0.0,0.54,0.54,side*3.15,0),(4.3,0.42,0.42,side*3.15,0),(5.25,0.78,0.68,side*3.15,0)],"Steel",6,0.0,"Composite",0.3)
    vertical_profile(coll,"GateLintel",[(-3.72,4.45),(-3.12,5.4),(3.12,5.4),(3.72,4.45)],-0.45,0.42,"Titanium","Composite",0.22)
    for i,x in enumerate((-2.1,-0.7,0.7,2.1)):
        vertical_profile(coll,"GateSeal%d"%i,[(x-0.10,1.1),(x+0.10,1.1),(x+0.10,4.15),(x-0.10,4.15)],-0.04,0.08,"Energy","Steel",0.45)
    reg("access_gate",coll)
    return coll
# ---------------------------- environmental ------------------------------
def b_background_silhouette():
    coll = new_collection("A_background_silhouette")
    # Distributed robot settlement massing: several asymmetrical production silhouettes.
    specs=[(-15,-6,15,23,10),(0,1,6,42,9),(15,-4,12,29,8),(27,5,7,19,6),(-29,4,8,25,7)]
    for i,(x,z,base,h,r) in enumerate(specs):
        rings=[(base,r,r*0.78,x,z),(base+2.0,r*1.14,r*0.94,x,z),(base+h*0.68,r*0.62,r*0.54,x,z),(base+h,r*0.27,r*0.21,x,z)]
        loft_volume(coll,"SkylineHabitat%d"%i,rings,"Composite",7+(i%3),0.15*i,"Steel",0.075)
        # A narrow cyan maintenance spine makes the distant mass legible through haze.
        a=0.52+i*0.67
        facade_fin(coll,"SkylineSpine%d"%i,a,r*0.76,base+2.5,base+h*0.76,0.12,0.2,"Energy")
    # Broken elevated transfer rim provides a horizon line behind the main tower.
    outline_prism(coll,"RemoteTransferRim",[(-34,-1.4),(32,-1.0),(35,1.0),(8,1.55),(-31,1.2)],-2.4,-1.0,"Steel","Composite",uv_scale=0.14)
    for i,x in enumerate((-25,-8,11,27)):
        outline_prism(coll,"RemoteRimPier%d"%i,[(x-0.8,-1.6),(x+0.7,-1.5),(x+0.45,1.4),(x-0.52,1.35)],-8.5,-1.0,"Composite","Steel",uv_scale=0.14)
    reg("background_silhouette",coll)
    return coll
def b_cloud_puff():
    coll = new_collection("A_cloud_puff")
    m = get_mat("Cloud", base=(0.72, 0.86, 0.96, 1.0), rough=0.96, metal=0.0)
    try: m.surface_render_method = 'DITHERED'
    except Exception: pass
    # Low-density irregular vapour masses supplement, rather than replace, the procedural sky.
    for i in range(6):
        a=math.tau*i/6.0+0.2
        r=2.2+(i%3)*0.95
        o=rock_boulder_mesh(coll,"VapourMass%d"%i,2.0+(i%2)*0.65,"Cloud",81+i)
        o.location=(math.cos(a)*r, (i%2)*0.35, math.sin(a)*r)
        o.scale=(1.45,0.42,1.0)
    reg("cloud_puff",coll)
    return coll

print("== Aetherfall build: stage 4 tower + bridges + details ==")
b_tower_foundation(); b_tower_tier(); b_tower_spire(); b_energy_core()
b_bridge_deck(); b_bridge_support(); b_walkway_deck(); b_damaged_slab()
b_machinery(); b_cooling_vent(); b_conduit(); b_cable_bundle(); b_railing(); b_debris_cluster()
b_cover_barrier(); b_cover_machine(); b_access_gate()
b_background_silhouette(); b_cloud_puff()


def _rot_mat(r):
    cx, sx = math.cos(r[0]), math.sin(r[0])
    cy, sy = math.cos(r[1]), math.sin(r[1])
    cz, sz = math.cos(r[2]), math.sin(r[2])
    return ((cy * cz, cy * sz, -sy),
            (sx * sy * cz - cx * sz, sx * sy * sz + cx * cz, sx * cy),
            (cx * sy * cz + sx * sz, cx * sy * sz - sx * cz, cx * cy))

def asset_bounds(coll):
    """World-space AABB.  Pure property math — never touches matrix_world or the
    dependency graph, which segfault in this headless/stubbed bpy build."""
    lo = [1e9, 1e9, 1e9]
    hi = [-1e9, -1e9, -1e9]
    for o in coll.all_objects:
        if o.type != 'MESH':
            continue
        R = _rot_mat(o.rotation_euler)
        sx, sy, sz = o.scale
        lx, ly, lz = o.location
        for v in o.bound_box:
            x, y, z = v[0], v[1], v[2]
            wx = R[0][0] * x * sx + R[0][1] * y * sy + R[0][2] * z * sz + lx
            wy = R[1][0] * x * sx + R[1][1] * y * sy + R[1][2] * z * sz + ly
            wz = R[2][0] * x * sx + R[2][1] * y * sy + R[2][2] * z * sz + lz
            for i, w in enumerate((wx, wy, wz)):
                if w < lo[i]:
                    lo[i] = w
                if w > hi[i]:
                    hi[i] = w
    return lo, hi

def center_collection(coll):
    lo, hi = asset_bounds(coll)
    cx = (lo[0] + hi[0]) / 2.0
    cy = (lo[1] + hi[1]) / 2.0
    cz = (lo[2] + hi[2]) / 2.0
    for o in coll.all_objects:
        if o.type == 'MESH':
            o.location = (o.location[0] - cx, o.location[1] - cy, o.location[2] - cz)
    lo2, hi2 = asset_bounds(coll)
    return (hi2[0] - lo2[0], hi2[1] - lo2[1], hi2[2] - lo2[2])

def export_asset(key, coll):
    objs = [o for o in coll.all_objects if o.type == 'MESH']
    bpy.ops.object.select_all(action='DESELECT')
    for o in objs:
        o.select_set(True)
    path = os.path.join(MODEL_DIR, key + ".glb")
    bpy.ops.export_scene.gltf(
        filepath=path, export_format="GLB", export_yup=True,
        export_apply=True, use_selection=True, export_materials="EXPORT")
    for o in objs:
        o.select_set(False)
    return None

MEASUREMENTS = {}
bpy.context.view_layer.update()
print("== Aetherfall build: stage 5 centre + measure ==")
for key, coll in ASSETS.items():
    size = center_collection(coll)
    lo, hi = asset_bounds(coll)
    MEASUREMENTS[key] = {
        "size": [round(size[0], 3), round(size[1], 3), round(size[2], 3)],
        "center": [round((lo[i] + hi[i]) / 2.0, 3) for i in range(3)],
        "objects": sum(1 for o in coll.all_objects if o.type == 'MESH'),
        "tris": sum(len(o.data.polygons) * 2 for o in coll.all_objects if o.type == 'MESH'),
    }
    print("  %-22s %s  %d meshes %d tris" % (key, MEASUREMENTS[key]["size"],
                                              MEASUREMENTS[key]["objects"], MEASUREMENTS[key]["tris"]))

print("== Aetherfall build: stage 5b export ==")
for key, coll in ASSETS.items():
    m = export_asset(key, coll)
    m = MEASUREMENTS[key]
# ---------------------------- form enrichment -----------------------------


def _rot_mat(r):
    cx, sx = math.cos(r[0]), math.sin(r[0])
    cy, sy = math.cos(r[1]), math.sin(r[1])
    cz, sz = math.cos(r[2]), math.sin(r[2])
    return ((cy * cz, cy * sz, -sy),
            (sx * sy * cz - cx * sz, sx * sy * sz + cx * cz, sx * cy),
            (cx * sy * cz + sx * sz, cx * sy * sz - sx * cz, cx * cy))

def asset_bounds(coll):
    """World-space AABB.  Pure property math — never touches matrix_world or the
    dependency graph, which segfault in this headless/stubbed bpy build."""
    lo = [1e9, 1e9, 1e9]
    hi = [-1e9, -1e9, -1e9]
    for o in coll.all_objects:
        if o.type != 'MESH':
            continue
        R = _rot_mat(o.rotation_euler)
        sx, sy, sz = o.scale
        lx, ly, lz = o.location
        for v in o.bound_box:
            x, y, z = v[0], v[1], v[2]
            wx = R[0][0] * x * sx + R[0][1] * y * sy + R[0][2] * z * sz + lx
            wy = R[1][0] * x * sx + R[1][1] * y * sy + R[1][2] * z * sz + ly
            wz = R[2][0] * x * sx + R[2][1] * y * sy + R[2][2] * z * sz + lz
            for i, w in enumerate((wx, wy, wz)):
                if w < lo[i]:
                    lo[i] = w
                if w > hi[i]:
                    hi[i] = w
    return lo, hi

def center_collection(coll):
    lo, hi = asset_bounds(coll)
    cx = (lo[0] + hi[0]) / 2.0
    cy = (lo[1] + hi[1]) / 2.0
    cz = (lo[2] + hi[2]) / 2.0
    for o in coll.all_objects:
        if o.type == 'MESH':
            o.location = (o.location[0] - cx, o.location[1] - cy, o.location[2] - cz)
    lo2, hi2 = asset_bounds(coll)
    return (hi2[0] - lo2[0], hi2[1] - lo2[1], hi2[2] - lo2[2])

def export_asset(key, coll):
    objs = [o for o in coll.all_objects if o.type == 'MESH']
    bpy.ops.object.select_all(action='DESELECT')
    for o in objs:
        o.select_set(True)
    path = os.path.join(MODEL_DIR, key + ".glb")
    # The kit is authored in Y-up coordinates already; Blender's default
    # Z-up to Y-up conversion would rotate the world a second time.
    bpy.ops.export_scene.gltf(
        filepath=path, export_format="GLB", export_yup=False,
        export_apply=True, use_selection=True, export_materials="EXPORT")
    for o in objs:
        o.select_set(False)
    return None

# Production rebuilds can export one visible asset family at a time while the
# single editable .blend remains the source of truth. A blank value exports all.
EXPORT_ONLY = {key for key in os.environ.get("AETHERFALL_EXPORT_ONLY", "").split(",") if key}
if EXPORT_ONLY:
    unknown = EXPORT_ONLY - set(ASSETS)
    if unknown:
        raise RuntimeError("Unknown AETHERFALL_EXPORT_ONLY keys: %s" % sorted(unknown))
    print("== Aetherfall export filter: %s ==" % ", ".join(sorted(EXPORT_ONLY)))

MEASUREMENTS = {}
bpy.context.view_layer.update()
print("== Aetherfall build: stage 5 centre + measure ==")
for key, coll in ASSETS.items():
    size = center_collection(coll)
    lo, hi = asset_bounds(coll)
    MEASUREMENTS[key] = {
        "size": [round(size[0], 3), round(size[1], 3), round(size[2], 3)],
        "center": [round((lo[i] + hi[i]) / 2.0, 3) for i in range(3)],
        "objects": sum(1 for o in coll.all_objects if o.type == 'MESH'),
        "tris": sum(len(o.data.polygons) * 2 for o in coll.all_objects if o.type == 'MESH'),
    }
    print("  %-22s %s  %d meshes %d tris" % (key, MEASUREMENTS[key]["size"],
                                              MEASUREMENTS[key]["objects"], MEASUREMENTS[key]["tris"]))

bpy.ops.file.pack_all()
bpy.ops.wm.save_as_mainfile(filepath=os.path.join(ROOT, "source", "aetherfall_kit.blend"))
print("== Aetherfall build: stage 5b export ==")
for key, coll in ASSETS.items():
    if EXPORT_ONLY and key not in EXPORT_ONLY:
        continue
    export_asset(key, coll)


# ---------------------------------------------------------------------------
# Assembled world
# ---------------------------------------------------------------------------
SCENE_COLL = bpy.context.scene.collection
PLACEMENTS = []
_masters_hidden = False
_place_id = [0]

def place(key, name, pos, rot=(0.0, 0.0, 0.0), scale=1.0):
    coll = ASSETS[key]
    _place_id[0] += 1
    n = name if name else "%s_%03d" % (key, _place_id[0])
    inst = bpy.data.objects.new(n, None)
    inst.empty_display_type = 'PLAIN_AXES'
    inst.empty_display_size = 0.4
    inst.instance_type = 'COLLECTION'
    inst.instance_collection = coll
    inst.location = (float(pos[0]), float(pos[1]), float(pos[2]))
    inst.rotation_euler = (float(rot[0]), float(rot[1]), float(rot[2]))
    inst.scale = (float(scale), float(scale), float(scale))
    SCENE_COLL.objects.link(inst)
    PLACEMENTS.append({
        "asset": key, "name": n,
        "pos": [round(float(pos[0]), 3), round(float(pos[1]), 3), round(float(pos[2]), 3)],
        "rot": [round(math.degrees(float(rot[0])), 2), round(math.degrees(float(rot[1])), 2),
                round(math.degrees(float(rot[2])), 2)],
        "scale": round(float(scale), 4),
    })
    return inst

# ---- measurements + layout manifest ---------------------------------------
import json
mf = {"schema": "aetherfall.measurements/1", "unit": "meters",
      "note": "Authored pivot = mesh centre (centred on its own AABB before export), "
              "so Godot box colliders derive from the same numbers.",
      "assets": MEASUREMENTS}
with open(os.path.join(WORLD_DIR, "measurements.json"), "w") as f:
    json.dump(mf, f, indent=2, sort_keys=True)
print("== Aetherfall build: wrote measurements.json (%d assets) ==" % len(MEASUREMENTS))
