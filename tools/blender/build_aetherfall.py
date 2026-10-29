#!/usr/bin/env python3
"""
build_aetherfall.py — EXOCOMFLICT: STELLAR HORIZON · SH-01 AETHERFALL.

Generates the custom Aetherfall architectural kit (GLB) with Blender 4.5 LTS
(runs headless through the `bpy` module), assembles the world, bakes the
procedural surface textures, and writes:

    assets/world/aetherfall/models/<asset>.glb      one GLB per module
    assets/world/aetherfall/materials/*.png         baked surface maps
    assets/world/aetherfall/layout.json             every placement
    assets/world/aetherfall/measurements.json        per-asset bounds

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
MODEL_DIR = os.path.join(ROOT, "assets/world/aetherfall/models")
MAT_DIR = os.path.join(ROOT, "assets/world/aetherfall/materials")
SOURCE_TEX_DIR = os.path.join(ROOT, "assets/world/aetherfall/source_textures")
WORLD_DIR = os.path.join(ROOT, "assets/world/aetherfall")
LAYOUT_PATH = os.path.join(ROOT, "assets/world/aetherfall/layout.json")
MEASURE_PATH = os.path.join(ROOT, "assets/world/aetherfall/measurements.json")

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
    get_mat("Rock", base=(0.44, 0.42, 0.39, 1.0), rough=0.95, metal=0.0, tex="aether_rock")
    get_mat("Stratum", base=(0.50, 0.47, 0.43, 1.0), rough=0.92, metal=0.0, tex="aether_rock")
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
# Primitive helpers. UVs come with the primitives; boxes keep their 0..1
# per-face UV map, so the baked textures tile without a smart-project pass.
# ---------------------------------------------------------------------------
def new_collection(name):
    c = bpy.data.collections.get(name)
    if c is None:
        c = bpy.data.collections.new(name)
    return c

def _relink(obj, coll):
    for c in list(obj.users_collection):
        c.objects.unlink(obj)
    coll.objects.link(obj)

def mbox(coll, name, dims, pos=(0.0, 0.0, 0.0), matname="Steel", bevel=0.02,
         bevel_seg=3, rot=(0.0, 0.0, 0.0)):
    bpy.ops.mesh.primitive_cube_add(size=2.0, location=pos, rotation=rot)
    o = bpy.context.active_object
    o.name = name
    o.scale = (dims[0] / 2.0, dims[1] / 2.0, dims[2] / 2.0)
    bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
    if bevel > 0.0:
        mod = o.modifiers.new("B", "BEVEL")
        mod.width = bevel
        mod.segments = max(3, bevel_seg)
        mod.limit_method = 'ANGLE'
        mod.angle_limit = math.radians(32.0)
        try:
            mod.harden_normals = True
        except Exception:
            pass
    o.data.materials.append(get_mat(matname))
    _relink(o, coll)
    return o

def mcyl(coll, name, radius, depth, pos=(0.0, 0.0, 0.0), matname="Steel",
         bevel=0.02, verts=16, rot=(0.0, 0.0, 0.0)):
    bpy.ops.mesh.primitive_cylinder_add(radius=radius, depth=depth,
                                        location=pos, vertices=max(12, verts), rotation=rot)
    o = bpy.context.active_object
    o.name = name
    # Cylinder depth starts on Blender Z; author the kit with Y as height.
    o.rotation_euler = (-math.pi / 2.0 + rot[0], rot[1], rot[2])
    if bevel > 0.0:
        mod = o.modifiers.new("B", "BEVEL")
        mod.width = bevel
        mod.segments = 3
        mod.limit_method = 'ANGLE'
        mod.angle_limit = math.radians(32.0)
        try:
            mod.harden_normals = True
        except Exception:
            pass
    o.data.materials.append(get_mat(matname))
    _relink(o, coll)
    return o

def msphere(coll, name, radius, pos=(0.0, 0.0, 0.0), matname="Rock",
            segments=16, rings=10):
    bpy.ops.mesh.primitive_uv_sphere_add(radius=radius, location=pos,
                                         segments=max(18, segments), ring_count=max(12, rings))
    o = bpy.context.active_object
    o.name = name
    o.data.materials.append(get_mat(matname))
    _relink(o, coll)
    return o

def mtorus(coll, name, major, minor, pos=(0.0, 0.0, 0.0), matname="Steel",
           major_segments=32, minor_segments=8, rot=(0.0, 0.0, 0.0)):
    """A clean hard-surface ring in the kit's Y-up orientation."""
    bpy.ops.mesh.primitive_torus_add(major_radius=major, minor_radius=minor,
                                     major_segments=major_segments, minor_segments=minor_segments,
                                     location=pos, rotation=(math.pi / 2.0 + rot[0], rot[1], rot[2]))
    o = bpy.context.active_object
    o.name = name
    o.data.materials.append(get_mat(matname))
    _relink(o, coll)
    return o

def add_bolt(coll, name, pos, radius=0.08, height=0.10, matname="Titanium"):
    return mcyl(coll, name, radius, height, pos, matname, bevel=0.018, verts=12)

def brace_xy(coll, name, a, b, thickness=0.18, depth=0.18, matname="Steel"):
    """Rectangular diagonal brace between two points in the authored X/Y plane."""
    dx, dy = b[0] - a[0], b[1] - a[1]
    length = math.hypot(dx, dy)
    if length < 0.001:
        return None
    angle = math.atan2(-dx, dy)
    return mbox(coll, name, (thickness, length, depth),
                ((a[0] + b[0]) * 0.5, (a[1] + b[1]) * 0.5, (a[2] + b[2]) * 0.5),
                matname, bevel=0.045, rot=(0.0, 0.0, angle))

def grid_mesh(coll, name, size, seg, pos, height_fn, matname,
              base_rot=(0.0, 0.0, 0.0), uv_scale=0.5):
    """A subdivided, displaced grid built directly with bmesh (Blender 4.5's
    plane operator no longer takes a subdivision count). UVs are a metric grid
    so the baked textures repeat on a fixed world scale."""
    import bmesh
    me = bpy.data.meshes.new(name)
    bm = bmesh.new()
    half = size / 2.0
    grid = []
    for i in range(seg + 1):
        row = []
        for j in range(seg + 1):
            x = -half + (size * j / seg)
            z = -half + (size * i / seg)
            row.append(bm.verts.new((x, 0.0, z)))
        grid.append(row)
    bm.verts.ensure_lookup_table()
    for row in grid:
        for v in row:
            v.co.y = height_fn(v.co.x, v.co.z)
    for i in range(seg):
        for j in range(seg):
            a = grid[i][j]; b = grid[i][j + 1]
            c = grid[i + 1][j + 1]; d = grid[i + 1][j]
            bm.faces.new((a, d, c, b))
    bm.normal_update()
    uvl = bm.loops.layers.uv.new("UVMap")
    for face in bm.faces:
        for loop in face.loops:
            loop[uvl].uv = (loop.vert.co.x * uv_scale, loop.vert.co.z * uv_scale)
    bm.to_mesh(me)
    bm.free()
    o = bpy.data.objects.new(name, me)
    o.location = pos
    o.rotation_euler = base_rot
    o.data.materials.append(get_mat(matname))
    coll.objects.link(o)
    return o

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

def tapered_box(coll, name, w, h, d, top_scale=0.6, pos=(0.0, 0.0, 0.0),
                matname="Steel", bevel=0.05, bevel_seg=2):
    bpy.ops.mesh.primitive_cube_add(size=2.0, location=pos)
    o = bpy.context.active_object
    o.name = name
    o.scale = (w / 2.0, h / 2.0, d / 2.0)
    bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
    me = o.data
    top = h / 2.0
    for v in me.vertices:
        if v.co.y > 0.0:
            t = (v.co.y + top) / (2.0 * top)
            v.co.x *= (1.0 - (1.0 - top_scale) * t)
            v.co.z *= (1.0 - (1.0 - top_scale) * t)
    me.update()
    if bevel > 0.0:
        mod = o.modifiers.new("B", "BEVEL")
        mod.width = bevel
        mod.segments = bevel_seg
        mod.limit_method = 'ANGLE'
    me.materials.append(get_mat(matname))
    _relink(o, coll)
    return o

def reg(key, coll):
    ASSETS[key] = coll
    if coll.name not in [c.name for c in SCENE_COLL.children]:
        SCENE_COLL.children.link(coll)
    print("  asset", key, "->", coll.name)

# ---------------------------- geology + architecture ----------------------
def b_terrain_chunk():
    coll = new_collection("A_terrain_chunk")
    grid_mesh(coll, "TerrainMass", 46.0, 32, (0.0, 0.0, 0.0),
              lambda x, z: -3.0 + 2.6 * noise2(x * 0.17, z * 0.17, 4, 7.0),
              "Rock", base_rot=(0.0, 0.0, 0.0), uv_scale=0.09)
    for i in range(3):
        a = math.radians(120.0 * i + 20.0)
        r = 15.0 + i * 5.0
        mbox(coll, "TerrainBlob%d" % i, (12.0, 3.0, 12.0),
             (math.cos(a) * r, -1.0 + i * 0.7, math.sin(a) * r), "Rock", bevel=1.2)
    mbox(coll, "TerrainScar", (18.0, 1.2, 6.0), (14.0, -0.4, -10.0), "Rock", bevel=0.6)
    reg("terrain_chunk", coll)
    return coll

def b_cliff_face():
    coll = new_collection("A_cliff_face")
    grid_mesh(coll, "CliffMass", 26.0, 32, (0.0, 0.0, 0.0),
              lambda x, z: 3.0 - 9.0 * noise2(x * 0.22, z * 0.22, 4, 11.0),
              "Rock", base_rot=(0.0, 0.0, 0.0), uv_scale=0.14)
    mbox(coll, "CliffShelf", (26.0, 2.0, 7.0), (0.0, 1.0, -4.0), "Rock", bevel=1.0)
    for i in range(5):
        a = math.radians(20.0 + 32.0 * i)
        mbox(coll, "CliffRock%d" % i, (3.0, 3.0, 3.0),
             (math.cos(a) * 11.0, -2.0 + (i % 3), math.sin(a) * 11.0 - 2.0),
             "Rock", bevel=0.8)
    for i in range(4):
        mcyl(coll, "CliffBolt%d" % i, 0.28, 2.6, (-9.0 + i * 6.0, 1.0, -3.2),
             "Steel", bevel=0.06, verts=8)
    reg("cliff_face", coll)
    return coll

def b_rock_boulder():
    coll = new_collection("A_rock_boulder")
    o = msphere(coll, "BoulderMain", 3.0, (0.0, 1.5, 0.0), "Rock", segments=14, rings=10)
    for v in o.data.vertices:
        v.co *= (1.0 + 0.35 * noise2(v.co.x, v.co.y, 3, 3.0))
    o.data.update()
    mbox(coll, "BoulderChunkA", (2.2, 1.6, 2.0), (2.4, 0.6, 1.0), "Rock", bevel=0.5)
    mbox(coll, "BoulderChunkB", (1.8, 1.2, 1.6), (-2.2, 0.5, -1.2), "Rock", bevel=0.4)
    reg("rock_boulder", coll)
    return coll

def b_deck_6x6():
    coll = new_collection("A_deck_6x6")
    mbox(coll, "DeckPlate", (6.0, 0.5, 6.0), (0.0, 0.0, 0.0), "PaintedSteel", bevel=0.08)
    mbox(coll, "DeckInset", (5.0, 0.08, 5.0), (0.0, 0.27, 0.0), "Concrete", bevel=0.04)
    for i in range(2):
        mbox(coll, "DeckSeam%d" % i, (6.2, 0.06, 0.16), (0.0, 0.28, -2.0 + i * 4.0), "Steel", bevel=0.03)
        mbox(coll, "DeckSeamZ%d" % i, (0.16, 0.06, 6.2), (-2.0 + i * 4.0, 0.28, 0.0), "Steel", bevel=0.03)
    for i in range(4):
        mcyl(coll, "DeckBolt%d" % i, 0.14, 0.3,
             ((-1.6 if i % 2 else 1.6), 0.3, (-1.6 if i < 2 else 1.6)), "Steel", bevel=0.03, verts=8)
    reg("deck_6x6", coll)
    return coll

def b_deck_edge():
    coll = new_collection("A_deck_edge")
    mbox(coll, "DeckEdgePlate", (6.0, 0.5, 0.6), (0.0, 0.0, 0.0), "PaintedSteel", bevel=0.08)
    mbox(coll, "DeckEdgeHazard", (6.0, 0.2, 0.64), (0.0, 0.3, 0.0), "Hazard", bevel=0.04)
    mbox(coll, "DeckEdgeRim", (6.0, 0.5, 0.16), (0.0, 0.0, 0.34), "Steel", bevel=0.05)
    for i in range(4):
        mcyl(coll, "DeckEdgeBolt%d" % i, 0.12, 0.3,
             ((-2.6 if i % 2 else 2.6), 0.3, 0.0), "Steel", bevel=0.03, verts=8)
    reg("deck_edge", coll)
    return coll

def b_pillar():
    coll = new_collection("A_pillar")
    mbox(coll, "PillarBase", (1.8, 0.5, 1.8), (0.0, 0.25, 0.0), "Concrete", bevel=0.15)
    mbox(coll, "PillarWeb", (1.0, 5.0, 1.0), (0.0, 3.0, 0.0), "Steel", bevel=0.1)
    mbox(coll, "PillarFlangeA", (1.4, 0.35, 1.0), (0.0, 1.5, 0.0), "Steel", bevel=0.06)
    mbox(coll, "PillarFlangeB", (1.4, 0.35, 1.0), (0.0, 4.5, 0.0), "Steel", bevel=0.06)
    mbox(coll, "PillarCap", (1.6, 0.4, 1.6), (0.0, 5.7, 0.0), "Steel", bevel=0.12)
    reg("pillar", coll)
    return coll

def b_beam():
    coll = new_collection("A_beam")
    mbox(coll, "BeamCore", (1.0, 0.7, 8.0), (0.0, 0.0, 0.0), "Steel", bevel=0.08)
    mbox(coll, "BeamFlange", (0.35, 0.9, 8.0), (0.0, 0.0, 0.0), "Composite", bevel=0.05)
    for i in range(4):
        mbox(coll, "BeamClip%d" % i, (0.5, 0.3, 0.5), (0.0, 0.0, -3.0 + i * 2.0), "Steel", bevel=0.05)
    reg("beam", coll)
    return coll

def b_wall_section():
    coll = new_collection("A_wall_section")
    mbox(coll, "WallBody", (4.0, 3.0, 0.4), (0.0, 1.5, 0.0), "Composite", bevel=0.06)
    mbox(coll, "WallBase", (4.2, 0.4, 0.5), (0.0, 0.2, 0.0), "Concrete", bevel=0.08)
    mbox(coll, "WallCap", (4.2, 0.3, 0.5), (0.0, 3.15, 0.0), "Steel", bevel=0.06)
    for i in range(3):
        mbox(coll, "WallPanel%d" % i, (1.0, 1.4, 0.1),
             (-1.2 + i * 1.2, 1.6, 0.22), "Composite", bevel=0.04)
    for i in range(3):
        mcyl(coll, "WallBolt%d" % i, 0.1, 0.4, (-1.8 + i * 1.8, 3.4, 0.0),
             "Steel", bevel=0.03, verts=8)
    reg("wall_section", coll)
    return coll

print("== Aetherfall build: stage 3 geology + architecture ==")
b_terrain_chunk(); b_cliff_face(); b_rock_boulder()
b_deck_6x6(); b_deck_edge(); b_pillar(); b_beam(); b_wall_section()


# ---------------------------- tower --------------------------------------
def b_tower_foundation():
    coll = new_collection("A_tower_foundation")
    mbox(coll, "Footing", (16.0, 3.0, 16.0), (0.0, 1.5, 0.0), "Concrete", bevel=0.25)
    mbox(coll, "FootingStep", (18.0, 1.0, 18.0), (0.0, 0.4, 0.0), "Concrete", bevel=0.2)
    for i in range(4):
        a = math.radians(45.0 + 90.0 * i)
        mcyl(coll, "Anchor%d" % i, 0.35, 1.6, (math.cos(a) * 7.0, 3.9, math.sin(a) * 7.0),
             "Steel", bevel=0.05, verts=10)
    mbox(coll, "FoundationRing", (14.0, 1.0, 14.0), (0.0, 3.2, 0.0), "Steel", bevel=0.12)
    for i in range(4):
        mbox(coll, "AccessStep%d" % i, (1.4, 0.5, 3.0), (-6.0 + i * 4.0, 1.0, 7.6), "Steel", bevel=0.1)
    for i in range(4):
        a = math.radians(45.0 + 90.0 * i)
        mcyl(coll, "ServiceConduit%d" % i, 0.55, 5.0,
             (math.cos(a) * 5.4, 5.5, math.sin(a) * 5.4), "Steel", bevel=0.08, verts=12)
    reg("tower_foundation", coll)
    return coll

def b_tower_tier():
    coll = new_collection("A_tower_tier")
    tapered_box(coll, "TierShaft", 12.0, 11.0, 12.0, 0.72, (0.0, 5.5, 0.0), "Steel", bevel=0.15)
    mbox(coll, "TierRing", (13.0, 0.9, 13.0), (0.0, 0.7, 0.0), "Steel", bevel=0.12)
    mbox(coll, "TierRing2", (12.4, 0.5, 12.4), (0.0, 1.2, 0.0), "Composite", bevel=0.08)
    for i in range(3):
        mbox(coll, "TierPanel%d" % i, (12.2, 1.1, 12.2), (0.0, 2.5 + i * 3.0, 0.0), "Composite", bevel=0.1)
    for sx in (-1.0, 1.0):
        mcyl(coll, "TierConduit%d" % int(sx * 10), 0.45, 11.0, (sx * 5.2, 5.5, 5.2), "Steel", bevel=0.07, verts=10)
        mcyl(coll, "TierConduitE%d" % int(sx * 10), 0.32, 11.0, (sx * 5.2, 5.5, 5.4), "Energy", bevel=0.05, verts=10)
    for i in range(4):
        a = math.radians(45.0 + 90.0 * i)
        mbox(coll, "TierStrut%d" % i, (0.5, 0.5, 9.0), (math.cos(a) * 6.0, 5.5, math.sin(a) * 6.0),
             "Steel", bevel=0.08)
    mbox(coll, "TierGlazing", (12.3, 1.6, 12.3), (0.0, 8.6, 0.0), "Glass", bevel=0.05)
    reg("tower_tier", coll)
    return coll

def b_tower_spire():
    coll = new_collection("A_tower_spire")
    tapered_box(coll, "SpireShaft", 6.0, 12.0, 6.0, 0.35, (0.0, 6.0, 0.0), "Steel", bevel=0.12)
    mbox(coll, "SpireRing", (7.4, 0.7, 7.4), (0.0, 0.6, 0.0), "Steel", bevel=0.1)
    mbox(coll, "SpireEnergyRing", (7.6, 0.5, 7.6), (0.0, 1.6, 0.0), "Energy", bevel=0.06)
    for i in range(4):
        a = math.radians(45.0 + 90.0 * i)
        mcyl(coll, "SpireStrut%d" % i, 0.25, 12.0, (math.cos(a) * 3.0, 6.0, math.sin(a) * 3.0),
             "Steel", bevel=0.04, verts=8)
    mcyl(coll, "SpireAntenna", 0.18, 6.0, (0.0, 13.0, 0.0), "Steel", bevel=0.04, verts=8)
    reg("tower_spire", coll)
    return coll

def b_energy_core():
    coll = new_collection("A_energy_core")
    mcyl(coll, "CoreCylinder", 2.4, 7.0, (0.0, 3.5, 0.0), "Energy", bevel=0.3, verts=20)
    mcyl(coll, "CoreHousing", 3.4, 8.0, (0.0, 4.0, 0.0), "Glass", bevel=0.3, verts=20)
    for i in range(6):
        a = math.radians(60.0 * i)
        mcyl(coll, "CoreRing%d" % i, 3.6, 0.4, (math.cos(a) * 3.6, 1.0 + i * 1.1, math.sin(a) * 3.6),
             "Energy", bevel=0.08, verts=12)
    mbox(coll, "CoreBase", (8.0, 1.0, 8.0), (0.0, 0.2, 0.0), "Steel", bevel=0.2)
    reg("energy_core", coll)
    return coll

# ---------------------------- bridges / walkways -------------------------
def b_bridge_deck():
    coll = new_collection("A_bridge_deck")
    mbox(coll, "BridgeDeck", (6.0, 0.7, 8.0), (0.0, 0.0, 0.0), "PaintedSteel", bevel=0.08)
    for i in range(4):
        mbox(coll, "BridgeJoint%d" % i, (6.2, 0.25, 0.18), (0.0, 0.05, -3.2 + i * 2.1), "Steel", bevel=0.04)
    mbox(coll, "BridgeHazard", (6.0, 0.12, 8.0), (0.0, 0.38, 0.0), "Hazard", bevel=0.02)
    for side in (-1.0, 1.0):
        for i in range(3):
            mbox(coll, "BridgePost%d%d" % (int(side * 10), i), (0.24, 1.3, 0.24),
                 (side * 2.9, 0.95, -2.5 + i * 2.5), "Steel", bevel=0.05)
        mbox(coll, "BridgeRailTop%d" % int(side * 10), (0.16, 0.16, 8.0), (side * 2.9, 1.42, 0.0), "Steel", bevel=0.03)
        mbox(coll, "BridgeRailMid%d" % int(side * 10), (0.12, 0.12, 8.0), (side * 2.9, 0.85, 0.0), "Steel", bevel=0.02)
    mbox(coll, "BridgeDucting", (0.9, 0.5, 8.0), (-2.4, 0.75, 0.0), "Steel", bevel=0.06)
    reg("bridge_deck", coll)
    return coll

def b_bridge_support():
    coll = new_collection("A_bridge_support")
    tapered_box(coll, "Pylon", 3.0, 14.0, 3.0, 0.75, (0.0, 7.0, 0.0), "Steel", bevel=0.15)
    mbox(coll, "PylonFoot", (6.0, 2.0, 6.0), (0.0, 1.0, 0.0), "Concrete", bevel=0.3)
    mbox(coll, "PylonCap", (5.0, 1.0, 5.0), (0.0, 14.5, 0.0), "Steel", bevel=0.15)
    for i in range(3):
        mbox(coll, "PylonBracer%d" % i, (0.4, 0.4, 4.0), (2.6, 4.0 + i * 3.0, 0.0), "Steel", bevel=0.06)
        mbox(coll, "PylonBracerB%d" % i, (4.0, 0.4, 0.4), (0.0, 4.0 + i * 3.0, 2.6), "Steel", bevel=0.06)
    for side in (-1.0, 1.0):
        mbox(coll, "PylonBeam%d" % int(side * 10), (0.6, 0.9, 7.0), (side * 3.0, 13.0, 0.0), "Steel", bevel=0.1)
    reg("bridge_support", coll)
    return coll

def b_walkway_deck():
    coll = new_collection("A_walkway_deck")
    mbox(coll, "WalkwayDeck", (1.6, 0.35, 6.0), (0.0, 0.0, 0.0), "PaintedSteel", bevel=0.05)
    for i in range(3):
        mbox(coll, "WalkwayRib%d" % i, (1.7, 0.18, 0.2), (0.0, -0.12, -2.0 + i * 2.0), "Steel", bevel=0.03)
    for side in (-1.0, 1.0):
        for i in range(3):
            mbox(coll, "WalkwayPost%d%d" % (int(side * 10), i), (0.12, 1.2, 0.12),
                 (side * 0.7, 0.9, -2.0 + i * 2.0), "Steel", bevel=0.03)
        mbox(coll, "WalkwayRail%d" % int(side * 10), (0.09, 0.09, 6.0), (side * 0.7, 1.28, 0.0), "Steel", bevel=0.02)
    mbox(coll, "WalkwayTray", (0.5, 0.35, 6.0), (0.0, 0.55, 0.0), "Steel", bevel=0.04)
    for i in range(4):
        mcyl(coll, "WalkwayCable%d" % i, 0.07, 6.0, (-0.1, 0.75, -2.4 + i * 1.6), "Cable", bevel=0.02, verts=6)
    reg("walkway_deck", coll)
    return coll

def b_damaged_slab():
    coll = new_collection("A_damaged_slab")
    mbox(coll, "BrokenSlabA", (7.0, 0.8, 6.0), (-1.0, 1.0, 0.0), "Concrete", bevel=0.15,
         rot=(0.0, 0.0, math.radians(6.0)))
    mbox(coll, "BrokenSlabB", (5.0, 0.7, 5.0), (2.0, 0.4, 1.0), "Concrete", bevel=0.15,
         rot=(0.0, 0.0, math.radians(-9.0)))
    for i in range(4):
        mcyl(coll, "BrokenRebar%d" % i, 0.08, 2.4, (-2.0 + i * 1.4, 1.6, -1.0), "Steel", bevel=0.02, verts=6)
    mbox(coll, "BrokenDebris", (2.0, 1.0, 2.0), (3.4, 0.3, -2.0), "Rock", bevel=0.4)
    reg("damaged_slab", coll)
    return coll

# ---------------------------- industrial detail ---------------------------
def b_machinery():
    coll = new_collection("A_machinery")
    mbox(coll, "MachineHousing", (4.0, 3.0, 3.6), (0.0, 1.8, 0.0), "Steel", bevel=0.12)
    mbox(coll, "MachineBase", (4.6, 0.7, 4.2), (0.0, 0.4, 0.0), "Concrete", bevel=0.15)
    mbox(coll, "MachineTop", (3.6, 0.4, 3.2), (0.0, 3.2, 0.0), "Composite", bevel=0.1)
    mcyl(coll, "MachineStack", 0.45, 3.0, (1.1, 3.9, 0.6), "Steel", bevel=0.1, verts=12)
    mcyl(coll, "MachineStackTop", 0.7, 0.5, (1.1, 5.3, 0.6), "Composite", bevel=0.1, verts=12)
    mcyl(coll, "MachinePipe", 0.3, 2.6, (-1.3, 2.2, 1.4), "Steel", bevel=0.06, verts=10)
    mbox(coll, "MachinePanel", (1.6, 1.4, 0.15), (0.0, 2.0, 1.85), "Composite", bevel=0.06)
    for i in range(2):
        mcyl(coll, "MachineGauge%d" % i, 0.22, 0.12, (-0.5 + i * 1.0, 2.0, 1.95), "Titanium", bevel=0.04, verts=10)
    reg("machinery", coll)
    return coll

def b_cooling_vent():
    coll = new_collection("A_cooling_vent")
    mcyl(coll, "VentHousing", 1.6, 3.4, (0.0, 1.7, 0.0), "Steel", bevel=0.15, verts=16)
    mcyl(coll, "VentCap", 1.9, 0.6, (0.0, 3.6, 0.0), "Composite", bevel=0.15, verts=16)
    mcyl(coll, "VentBase", 2.2, 0.6, (0.0, 0.3, 0.0), "Concrete", bevel=0.15, verts=16)
    for i in range(6):
        a = math.radians(60.0 * i)
        mbox(coll, "VentLouver%d" % i, (0.9, 0.12, 0.3), (math.cos(a) * 1.6, 3.0, math.sin(a) * 1.6),
             "Steel", bevel=0.04)
    mcyl(coll, "VentFan", 0.9, 0.2, (0.0, 3.5, 0.0), "Steel", bevel=0.05, verts=12)
    reg("cooling_vent", coll)
    return coll

def b_conduit():
    coll = new_collection("A_conduit")
    mcyl(coll, "ConduitPipe", 0.34, 6.0, (0.0, 3.0, 0.0), "Steel", bevel=0.06, verts=12)
    mcyl(coll, "ConduitInner", 0.24, 6.0, (0.0, 3.0, 0.0), "Energy", bevel=0.04, verts=12)
    for i in range(3):
        mbox(coll, "ConduitBracket%d" % i, (0.7, 0.18, 0.18), (0.0, 2.0 + i * 2.0, 0.5), "Steel", bevel=0.04)
        mbox(coll, "ConduitStrap%d" % i, (0.16, 0.5, 0.16), (0.4, 2.0 + i * 2.0, 0.0), "Steel", bevel=0.04)
    reg("conduit", coll)
    return coll

def b_cable_bundle():
    coll = new_collection("A_cable_bundle")
    mbox(coll, "CableTray", (0.8, 0.3, 6.0), (0.0, 0.0, 0.0), "Steel", bevel=0.06)
    for i in range(5):
        mcyl(coll, "Cable%d" % i, 0.11, 6.0, (-0.25 + i * 0.12, 0.22, 0.0), "Cable", bevel=0.03, verts=6)
    for i in range(3):
        mbox(coll, "CableTrayBracket%d" % i, (0.2, 0.5, 0.2), (0.0, -0.4, -2.0 + i * 2.0), "Steel", bevel=0.04)
    reg("cable_bundle", coll)
    return coll

def b_railing():
    coll = new_collection("A_railing")
    for i in range(4):
        mbox(coll, "RailingPost%d" % i, (0.14, 1.3, 0.14), (-2.7 + i * 1.8, 0.65, 0.0), "Steel", bevel=0.04)
    mbox(coll, "RailingTop", (0.1, 0.1, 6.0), (0.0, 1.28, 0.0), "Steel", bevel=0.03)
    mbox(coll, "RailingMid", (0.08, 0.08, 6.0), (0.0, 0.72, 0.0), "Steel", bevel=0.02)
    mbox(coll, "RailingBase", (0.5, 0.14, 6.0), (0.0, 0.05, 0.0), "Steel", bevel=0.03)
    reg("railing", coll)
    return coll

def b_debris_cluster():
    coll = new_collection("A_debris_cluster")
    for i in range(5):
        a = math.radians(30.0 + 70.0 * i)
        r = 1.6 + (i % 3) * 0.8
        mbox(coll, "Debris%d" % i, (1.4, 0.8, 1.4), (math.cos(a) * r, 0.4, math.sin(a) * r),
             "Steel" if i % 2 else "Concrete", bevel=0.3,
             rot=(0.0, math.radians(i * 37.0), math.radians(i * 21.0)))
    mcyl(coll, "DebrisPipe", 0.3, 2.0, (0.0, 1.0, 0.0), "Steel", bevel=0.08, verts=10)
    reg("debris_cluster", coll)
    return coll

# ---------------------------- gameplay objects -----------------------------
def b_cover_barrier():
    coll = new_collection("A_cover_barrier")
    mbox(coll, "CoverBody", (2.4, 1.2, 0.6), (0.0, 0.6, 0.0), "Steel", bevel=0.08)
    mbox(coll, "CoverTop", (2.5, 0.2, 0.7), (0.0, 1.2, 0.0), "Composite", bevel=0.06)
    mbox(coll, "CoverHazard", (2.4, 0.18, 0.62), (0.0, 1.15, 0.0), "Hazard", bevel=0.03)
    for side in (-1.0, 1.0):
        mbox(coll, "CoverEnd%d" % int(side * 10), (0.2, 1.2, 0.6), (side * 1.2, 0.6, 0.0), "Steel", bevel=0.06)
    reg("cover_barrier", coll)
    return coll

def b_cover_machine():
    coll = new_collection("A_cover_machine")
    mbox(coll, "CoverMachineBody", (4.0, 2.4, 2.6), (0.0, 1.2, 0.0), "Steel", bevel=0.12)
    mbox(coll, "CoverMachineBase", (4.6, 0.6, 3.2), (0.0, 0.3, 0.0), "Concrete", bevel=0.15)
    mbox(coll, "CoverMachineTop", (3.6, 0.3, 2.4), (0.0, 2.4, 0.0), "Composite", bevel=0.1)
    mcyl(coll, "CoverMachineStack", 0.35, 1.6, (1.2, 2.9, 0.4), "Steel", bevel=0.08, verts=10)
    mbox(coll, "CoverMachineHazard", (4.0, 0.2, 2.6), (0.0, 1.35, 0.0), "Hazard", bevel=0.04)
    reg("cover_machine", coll)
    return coll

def b_access_gate():
    coll = new_collection("A_access_gate")
    mbox(coll, "GatePostL", (0.7, 5.0, 0.7), (-3.2, 2.5, 0.0), "Steel", bevel=0.1)
    mbox(coll, "GatePostR", (0.7, 5.0, 0.7), (3.2, 2.5, 0.0), "Steel", bevel=0.1)
    mbox(coll, "GateLintel", (7.2, 0.8, 0.8), (0.0, 5.0, 0.0), "Steel", bevel=0.1)
    mbox(coll, "GateWarning", (7.2, 0.5, 0.1), (0.0, 4.4, 0.4), "Hazard", bevel=0.04)
    for i in range(2):
        mbox(coll, "GateStrut%d" % i, (0.4, 0.4, 6.0), (-1.6 + i * 3.2, 2.5, 0.0), "Steel", bevel=0.06)
    mbox(coll, "GateBar", (6.0, 0.2, 0.2), (0.0, 3.0, 0.0), "Energy", bevel=0.04)
    reg("access_gate", coll)
    return coll

# ---------------------------- environmental ------------------------------
def b_background_silhouette():
    coll = new_collection("A_background_silhouette")
    tapered_box(coll, "DistTower", 10.0, 34.0, 10.0, 0.5, (0.0, 17.0, 0.0), "Composite", bevel=0.4)
    mbox(coll, "DistTowerTop", (6.0, 3.0, 6.0), (0.0, 35.0, 0.0), "Composite", bevel=0.4)
    mbox(coll, "DistShedA", (16.0, 8.0, 10.0), (-14.0, 4.0, -6.0), "Composite", bevel=0.4)
    mbox(coll, "DistShedB", (12.0, 6.0, 8.0), (16.0, 3.0, -4.0), "Composite", bevel=0.4)
    mbox(coll, "DistPlatform", (24.0, 1.2, 6.0), (2.0, -1.0, 10.0), "Composite", bevel=0.4)
    mcyl(coll, "DistStack", 0.9, 10.0, (12.0, 5.0, -6.0), "Composite", bevel=0.4, verts=10)
    reg("background_silhouette", coll)
    return coll

def b_cloud_puff():
    coll = new_collection("A_cloud_puff")
    m = get_mat("Cloud", base=(0.95, 0.96, 0.98, 1.0), rough=1.0, metal=0.0)
    try:
        m.blend_method = 'BLEND'
    except Exception:
        pass
    try:
        m.surface_render_method = 'DITHERED'
    except Exception:
        pass
    for i in range(7):
        a = math.radians(45.0 * i + 12.0)
        r = 2.4 + (i % 3) * 1.1
        o = msphere(coll, "CloudPuff%d" % i, 2.2 + (i % 3) * 0.7,
                    (math.cos(a) * r, 0.0, math.sin(a) * r), "Cloud", segments=10, rings=6)
        for v in o.data.vertices:
            v.co *= (1.0 + 0.25 * noise2(v.co.x, v.co.z, 2, float(i)))
        o.data.update()
    reg("cloud_puff", coll)
    return coll

print("== Aetherfall build: stage 4 tower + bridges + details ==")
b_tower_foundation(); b_tower_tier(); b_tower_spire(); b_energy_core()
b_bridge_deck(); b_bridge_support(); b_walkway_deck(); b_damaged_slab()
b_machinery(); b_cooling_vent(); b_conduit(); b_cable_bundle(); b_railing(); b_debris_cluster()
b_cover_barrier(); b_cover_machine(); b_access_gate()
b_background_silhouette(); b_cloud_puff()


# ---------------------------- form enrichment -----------------------------
def enrich_asset_forms():
    """Add silhouette, construction logic and close-range detail to all kit roles.

    Existing named walking meshes and pivots remain untouched so the Godot
    builder's floor/collider contract continues to work. Detail stays within
    the authored footprint wherever that module receives a proxy collider.
    """
    # Geology: satellite rocks, shelves and visible strata break the primitive masses.
    terrain = ASSETS["terrain_chunk"]
    for i in range(20):
        a = math.radians(i * 47.0 + 11.0)
        radius = 6.0 + (i % 5) * 3.45
        x, z = math.cos(a) * radius, math.sin(a) * radius
        y = -2.45 + 2.6 * noise2(x * 0.17, z * 0.17, 4, 7.0)
        rock = msphere(terrain, "TerrainOutcrop%02d" % i, 0.34 + (i % 4) * 0.16,
                       (x, y, z), "Rock", segments=10, rings=7)
        rock.scale = (1.0 + (i % 3) * 0.25, 0.55 + (i % 2) * 0.25, 0.8 + (i % 4) * 0.12)
    cliff = ASSETS["cliff_face"]
    for i in range(9):
        x = -10.5 + i * 2.65
        mbox(cliff, "CliffStrata%02d" % i, (2.1, 0.38 + (i % 3) * 0.12, 1.4),
             (x, -0.6 + (i % 4) * 0.55, -5.5 + (i % 2) * 0.45), "Stratum", bevel=0.22,
             rot=(0.0, math.radians(-8 + i * 6), math.radians((-1) ** i * 4)))
    boulder = ASSETS["rock_boulder"]
    for i in range(6):
        a = math.radians(i * 58.0)
        r = 2.0 + (i % 2) * 1.0
        chip = msphere(boulder, "BoulderChip%02d" % i, 0.45 + (i % 3) * 0.17,
                       (math.cos(a) * r, 0.35 + (i % 2) * 0.25, math.sin(a) * r),
                       "Rock", segments=12, rings=8)
        chip.scale = (1.3, 0.7, 1.0)

    # Platform kit: panel rhythm, seat plates and a denser fastener language.
    deck = ASSETS["deck_6x6"]
    for ix in (-2.45, -0.82, 0.82, 2.45):
        for iz in (-2.45, -0.82, 0.82, 2.45):
            add_bolt(deck, "DeckFastener_%d_%d" % (int(ix * 10), int(iz * 10)), (ix, 0.33, iz), 0.075, 0.09)
    for i in range(3):
        mbox(deck, "DeckServiceChannel%d" % i, (0.10, 0.055, 4.85), (-1.65 + i * 1.65, 0.325, 0.0), "Titanium", bevel=0.018)
    mbox(deck, "DeckServiceHatch", (1.18, 0.055, 0.82), (0.0, 0.33, -1.1), "Composite", bevel=0.035)
    edge = ASSETS["deck_edge"]
    for i in range(6):
        add_bolt(edge, "EdgeFastener%02d" % i, (-2.35 + i * 0.94, 0.34, -0.18), 0.065, 0.08)
    for i in range(3):
        mbox(edge, "EdgeStiffener%d" % i, (0.17, 0.42, 0.17), (-2.0 + i * 2.0, 0.08, 0.0), "Steel", bevel=0.03)

    # Structural kit: web stiffeners, gussets, recessed panels and anchor hardware.
    pillar = ASSETS["pillar"]
    for y in (1.0, 2.6, 4.1):
        mbox(pillar, "PillarGusset%.0f" % (y * 10), (1.5, 0.12, 1.45), (0.0, y, 0.0), "Titanium", bevel=0.035)
    for x in (-0.58, 0.58):
        for z in (-0.58, 0.58):
            add_bolt(pillar, "PillarAnchor_%d_%d" % (int(x * 10), int(z * 10)), (x, 0.54, z), 0.08, 0.11)
    beam = ASSETS["beam"]
    for z in (-3.2, -1.9, -0.6, 0.7, 2.0, 3.3):
        mbox(beam, "BeamWebStiffener%d" % int((z + 4) * 10), (1.08, 0.95, 0.11), (0.0, 0.0, z), "Titanium", bevel=0.025)
    mbox(beam, "BeamTopFlange", (1.32, 0.12, 8.0), (0.0, 0.39, 0.0), "Steel", bevel=0.025)
    mbox(beam, "BeamBottomFlange", (1.32, 0.12, 8.0), (0.0, -0.39, 0.0), "Steel", bevel=0.025)
    wall = ASSETS["wall_section"]
    for i in range(5):
        mbox(wall, "WallLouver%02d" % i, (2.9, 0.12, 0.16), (0.0, 0.72 + i * 0.34, 0.29), "Titanium", bevel=0.022)
    for x in (-1.7, 1.7):
        for y in (0.65, 2.55):
            mbox(wall, "WallRivet_%d_%d" % (int(x*10), int(y*10)), (0.14, 0.14, 0.11), (x, y, 0.29), "Titanium", bevel=0.02)
    mbox(wall, "WallStatusStrip", (2.8, 0.10, 0.10), (0.0, 2.72, 0.30), "Energy", bevel=0.018)

    # Tower: ringed massing, exterior panel seams, anchors and readable energy hardware.
    foundation = ASSETS["tower_foundation"]
    for i in range(16):
        a = math.tau * i / 16.0
        add_bolt(foundation, "FoundationBolt%02d" % i, (math.cos(a) * 7.7, 3.96, math.sin(a) * 7.7), 0.12, 0.16)
    for i in range(4):
        a = math.tau * i / 4.0 + math.pi / 4.0
        brace_xy(foundation, "FoundationBrace%d" % i,
                 (math.cos(a) * 4.8, 3.4, math.sin(a) * 4.8),
                 (math.cos(a) * 7.0, 6.2, math.sin(a) * 7.0), 0.25, 0.24, "Steel")
    mtorus(foundation, "FoundationEnergyRing", 5.5, 0.13, (0.0, 4.1, 0.0), "Energy", 48, 10)
    tier = ASSETS["tower_tier"]
    for level in range(4):
        y = 1.75 + level * 2.25
        for side in (-1.0, 1.0):
            mbox(tier, "TierRibX_%d_%d" % (level, int(side)), (0.28, 1.55, 10.8), (side * 5.72, y, 0.0), "Titanium", bevel=0.035)
            mbox(tier, "TierRibZ_%d_%d" % (level, int(side)), (10.8, 1.55, 0.28), (0.0, y, side * 5.72), "Titanium", bevel=0.035)
    for y in (1.5, 4.0, 6.5, 9.0):
        mtorus(tier, "TierBand%d" % int(y * 10), 5.95, 0.11, (0.0, y, 0.0), "Steel", 40, 8)
    spire = ASSETS["tower_spire"]
    for i in range(4):
        a = math.tau * i / 4.0 + math.pi / 4.0
        mbox(spire, "SpireFin%d" % i, (0.22, 6.0, 2.4), (math.cos(a) * 2.2, 6.4, math.sin(a) * 2.2), "Titanium", bevel=0.05,
             rot=(0.0, a, 0.0))
    mtorus(spire, "SpireHalo", 2.7, 0.10, (0.0, 9.6, 0.0), "Energy", 36, 8)
    core = ASSETS["energy_core"]
    for y in (1.4, 3.5, 5.7):
        mtorus(core, "CoreHalo%d" % int(y * 10), 3.0, 0.14, (0.0, y, 0.0), "Energy", 40, 8)
    for i in range(8):
        a = math.tau * i / 8.0
        mbox(core, "CoreEmitter%02d" % i, (0.32, 0.55, 0.65), (math.cos(a) * 2.85, 3.5, math.sin(a) * 2.85), "Titanium", bevel=0.06,
             rot=(0.0, -a, 0.0))

    # Traversal structures: grating, bolts, diagonal braces and mount plates.
    bridge = ASSETS["bridge_deck"]
    for z in (-3.25, -2.15, -1.05, 0.05, 1.15, 2.25, 3.35):
        mbox(bridge, "BridgeGrate%d" % int((z + 4) * 10), (5.35, 0.055, 0.075), (0.0, 0.415, z), "Titanium", bevel=0.012)
    for x in (-2.45, 2.45):
        for z in (-3.2, -1.1, 1.1, 3.2):
            add_bolt(bridge, "BridgeBolt_%d_%d" % (int(x*10), int(z*10)), (x, 0.43, z), 0.065, 0.08)
    support = ASSETS["bridge_support"]
    for z in (-1.7, 1.7):
        brace_xy(support, "PylonCrossA_%d" % int(z * 10), (-2.05, 2.2, z), (2.05, 11.8, z), 0.25, 0.22)
        brace_xy(support, "PylonCrossB_%d" % int(z * 10), (2.05, 2.2, z), (-2.05, 11.8, z), 0.25, 0.22)
    walkway = ASSETS["walkway_deck"]
    for z in (-2.55, -1.7, -0.85, 0.0, 0.85, 1.7, 2.55):
        mbox(walkway, "WalkwayGrate%d" % int((z + 3) * 10), (1.38, 0.045, 0.07), (0.0, 0.21, z), "Titanium", bevel=0.012)
    for side in (-1.0, 1.0):
        for z in (-1.0, 1.0):
            brace_xy(walkway, "WalkwayBrace_%d_%d" % (int(side), int(z*10)), (side * 0.61, 0.25, z - 0.45), (side * 0.61, 1.05, z + 0.45), 0.055, 0.055)
    slab = ASSETS["damaged_slab"]
    for i in range(8):
        mbox(slab, "SlabCrack%02d" % i, (0.06, 0.045, 1.3 + (i % 3) * 0.35), (-2.8 + i * 0.72, 1.46 - (i % 2) * 0.35, -0.7 + (i % 3) * 0.75), "Rubber", bevel=0.008,
             rot=(0.0, math.radians(i * 21), math.radians((-1) ** i * 7)))

    # Industrial props: service panels, louvers, clamps and readable controls.
    machine = ASSETS["machinery"]
    for i in range(8):
        mbox(machine, "MachineLouver%02d" % i, (2.85, 0.11, 0.12), (0.0, 0.75 + i * 0.26, 1.88), "Titanium", bevel=0.018)
    for x in (-1.62, 1.62):
        for y in (0.75, 2.7):
            add_bolt(machine, "MachineBolt_%d_%d" % (int(x*10), int(y*10)), (x, y, 1.98), 0.065, 0.075)
    for i in range(3):
        mbox(machine, "MachineIndicator%d" % i, (0.16, 0.16, 0.08), (-0.38 + i * 0.38, 2.85, 1.9), "Energy", bevel=0.025)
    vent = ASSETS["cooling_vent"]
    for i in range(8):
        a = math.tau * i / 8.0
        mbox(vent, "VentBlade%02d" % i, (0.22, 0.08, 1.15), (math.cos(a) * 0.38, 3.76, math.sin(a) * 0.38), "Titanium", bevel=0.03,
             rot=(0.0, a, math.radians(15)))
    mtorus(vent, "VentGuard", 1.35, 0.08, (0.0, 3.82, 0.0), "Steel", 32, 8)
    conduit = ASSETS["conduit"]
    for i in range(5):
        mtorus(conduit, "ConduitCollar%d" % i, 0.38, 0.05, (0.0, 0.8 + i * 1.1, 0.0), "Titanium", 20, 6)
    cables = ASSETS["cable_bundle"]
    for z in (-2.4, -1.2, 0.0, 1.2, 2.4):
        mbox(cables, "CableClamp%d" % int((z+3)*10), (0.72, 0.08, 0.16), (0.0, 0.43, z), "Titanium", bevel=0.02)
    rail = ASSETS["railing"]
    for i in range(4):
        x = -2.7 + i * 1.8
        mbox(rail, "RailingFoot%d" % i, (0.42, 0.08, 0.42), (x, 0.05, 0.0), "Titanium", bevel=0.025)
        brace_xy(rail, "RailingBraceA%d" % i, (x, 0.16, -0.08), (x, 0.93, -0.08), 0.06, 0.06)
    debris = ASSETS["debris_cluster"]
    for i in range(8):
        a = math.radians(i * 43.0)
        shard = msphere(debris, "DebrisShard%02d" % i, 0.26 + (i % 3) * 0.10, (math.cos(a) * (1.0 + (i % 3)), 0.22, math.sin(a) * (1.0 + (i % 3))), "Rock", 10, 7)
        shard.scale = (1.5, 0.55, 0.7)

    # Cover/gate modules: panels, handles, gauges, mounts and control hardware.
    barrier = ASSETS["cover_barrier"]
    for x in (-0.75, 0.0, 0.75):
        mbox(barrier, "BarrierRib%d" % int(x * 10), (0.12, 0.82, 0.14), (x, 0.65, 0.36), "Titanium", bevel=0.025)
    mbox(barrier, "BarrierLight", (1.15, 0.10, 0.07), (0.0, 0.94, 0.37), "Energy", bevel=0.018)
    cover_machine = ASSETS["cover_machine"]
    for i in range(6):
        mbox(cover_machine, "CoverVent%02d" % i, (2.8, 0.10, 0.13), (0.0, 0.48 + i * 0.25, 1.42), "Titanium", bevel=0.018)
    for x in (-1.45, 1.45):
        mcyl(cover_machine, "CoverPipe%d" % int(x * 10), 0.18, 2.2, (x, 2.85, -0.65), "Steel", bevel=0.035, verts=12)
    gate = ASSETS["access_gate"]
    for side in (-1.0, 1.0):
        x = side * 3.2
        for y in (0.55, 1.5, 2.45, 3.4):
            mbox(gate, "GatePlate_%d_%d" % (int(side), int(y*10)), (0.78, 0.17, 0.82), (x, y, 0.0), "Titanium", bevel=0.025)
            add_bolt(gate, "GateBolt_%d_%d" % (int(side), int(y*10)), (x + side * 0.38, y, 0.28), 0.055, 0.07)
    mbox(gate, "GateControlBox", (0.62, 1.05, 0.46), (2.35, 1.05, 0.52), "Composite", bevel=0.06)
    mbox(gate, "GateControlLight", (0.18, 0.18, 0.06), (2.35, 1.23, 0.77), "Energy", bevel=0.018)

    # Distant assets get a little hierarchy but remain light-weight silhouettes.
    background = ASSETS["background_silhouette"]
    for i in range(3):
        mbox(background, "DistAntenna%d" % i, (0.22, 6.0 + i * 1.8, 0.22), (-4.0 + i * 4.0, 35.0 + i, 0.0), "Steel", bevel=0.03)
    for i in range(5):
        mbox(background, "DistWindow%d" % i, (1.2, 0.3, 0.08), (-12.0 + i * 5.0, 5.0 + (i % 2), -11.05), "Energy", bevel=0.012)
    cloud = ASSETS["cloud_puff"]
    for i in range(5):
        a = math.radians(72.0 * i + 18.0)
        o = msphere(cloud, "CloudWisp%02d" % i, 0.9 + (i % 2) * 0.3, (math.cos(a) * 5.5, 0.5 + (i % 2), math.sin(a) * 4.3), "Cloud", 14, 8)
        o.scale = (2.0, 0.5, 1.4)
    print("== Aetherfall build: enhanced all 27 reusable asset forms ==")

enrich_asset_forms()


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
    m = export_asset(key, coll)
    m = MEASUREMENTS[key]


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
