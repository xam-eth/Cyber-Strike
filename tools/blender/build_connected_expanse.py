"""Build the large connected Aetherfall Expanse traversal kit.

This is a deliberately small reusable kit for a continuous outdoor world:
wide ice shelves make route turns readable, exposed transit spans connect every
legacy endpoint into a loop, and lower ice fields catch falls without an
invisible boundary. The new materials are original 768px PBR maps with
micro-fracture, frost, scratch and panel detail for close-range readability.
"""
import math
import os
import random
import bpy
import numpy as np
from PIL import Image

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "../.."))
OUT = os.path.join(ROOT, "assets", "world", "aetherfall", "expanse")
MAPS = os.path.join(ROOT, "assets", "world", "aetherfall", "materials")
SOURCE = os.path.join(ROOT, "source", "aetherfall_connected_expanse.blend")
os.makedirs(OUT, exist_ok=True)
bpy.ops.wm.read_factory_settings(use_empty=True)


def resize_noise(rng, coarse, size):
    data = np.uint8(rng.random(coarse) * 255)
    return np.asarray(Image.fromarray(data, "L").resize((size, size), Image.Resampling.BICUBIC), dtype=np.float32) / 255.0


def normal_from_height(height, strength=8.0):
    dx = np.gradient(height, axis=1)
    dy = np.gradient(height, axis=0)
    normal = np.dstack((-dx * strength, -dy * strength, np.ones_like(height)))
    normal /= np.maximum(np.linalg.norm(normal, axis=2, keepdims=True), 1e-5)
    return np.uint8(np.clip((normal * .5 + .5) * 255, 0, 255))


def save_maps(name, albedo, height, metallic, roughness, ao):
    Image.fromarray(np.uint8(np.clip(albedo, 0, 255)), "RGB").save(os.path.join(MAPS, name + ".png"), optimize=True)
    Image.fromarray(normal_from_height(height), "RGB").save(os.path.join(MAPS, name + "_normal.png"), optimize=True)
    orm = np.dstack((np.uint8(np.clip(metallic * 255, 0, 255)), np.uint8(np.clip(roughness * 255, 0, 255)), np.uint8(np.clip(ao * 255, 0, 255))))
    Image.fromarray(orm, "RGB").save(os.path.join(MAPS, name + "_orm.png"), optimize=True)


def build_hd_maps():
    """Original 768px maps. Existing embedded GLBs stay unchanged; this kit
    deliberately uses a sharper texture family without rewriting the whole repo.
    """
    required = []
    for name in ("aether_expanse_ice", "aether_expanse_metal", "aether_expanse_hazard"):
        required += [os.path.join(MAPS, name + suffix + ".png") for suffix in ("", "_normal", "_orm")]
    if all(os.path.isfile(path) for path in required):
        return
    size = 768
    yy, xx = np.mgrid[0:size, 0:size]

    rng = np.random.default_rng(9821)
    broad = resize_noise(rng, (38, 38), size)
    medium = resize_noise(rng, (155, 155), size)
    grain = rng.normal(0.0, .055, (size, size)).astype(np.float32)
    height = np.clip(.50 * broad + .35 * medium + grain, 0, 1)
    crevasse = np.zeros((size, size), dtype=np.float32)
    for angle, offset, spacing, width in [(0.18, 113, 97, .042), (-.51, 491, 163, .028), (.83, 211, 229, .021)]:
        axis = xx * math.cos(angle) + yy * math.sin(angle) + offset
        folded = np.abs((axis % spacing) - spacing * .5) / (spacing * .5)
        crevasse += np.clip((width - folded) / max(width, .001), 0, 1)
    crevasse = np.clip(crevasse, 0, 1)
    ice_h = np.clip(height - crevasse * .24, 0, 1)
    frost = np.clip(.28 + ice_h * .72, 0, 1)
    ice = np.dstack((
        55 + frost * 142 - crevasse * 48,
        104 + frost * 130 - crevasse * 36,
        145 + frost * 107 + crevasse * 5,
    ))
    save_maps("aether_expanse_ice", ice, ice_h, np.full_like(ice_h, .05), np.clip(.22 + (1 - ice_h) * .42 + crevasse * .18, 0, 1), np.clip(.76 + ice_h * .22 - crevasse * .20, 0, 1))

    rng = np.random.default_rng(3117)
    m_base = .48 * resize_noise(rng, (52, 52), size) + .34 * resize_noise(rng, (205, 205), size) + rng.normal(0, .035, (size, size))
    scratches = np.zeros((size, size), dtype=np.float32)
    for angle, phase, spacing in [(0.04, 29, 31), (-.06, 87, 53), (.23, 14, 121)]:
        axis = xx * math.cos(angle) + yy * math.sin(angle) + phase
        distance = np.abs((axis % spacing) - spacing * .5) / (spacing * .5)
        scratches += np.clip((.022 - distance) * 38, 0, .34)
    m_h = np.clip(m_base - scratches, 0, 1)
    patina = np.clip(.2 + resize_noise(rng, (26, 26), size) * .7, 0, 1)
    metal = np.dstack((
        34 + m_h * 52 + patina * 11,
        55 + m_h * 67 + patina * 17,
        70 + m_h * 79 + patina * 22,
    ))
    save_maps("aether_expanse_metal", metal, m_h, np.full_like(m_h, .78), np.clip(.27 + (1 - m_h) * .34 + scratches * .28, 0, 1), np.clip(.72 + m_h * .23, 0, 1))

    stripe = ((xx // 84) % 2).astype(np.float32)
    stripe = np.where((xx % 84) < 8, .14, stripe)
    h_h = .35 + stripe * .22 + rng.normal(0, .025, (size, size))
    hazard = np.dstack((168 + stripe * 67, 45 + stripe * 32, 12 + stripe * 8))
    save_maps("aether_expanse_hazard", hazard, np.clip(h_h, 0, 1), np.full_like(h_h, .20), np.full_like(h_h, .43), np.full_like(h_h, .88))


build_hd_maps()
IMAGES = {}


def image(name, non_color=False):
    key = (name, non_color)
    if key not in IMAGES:
        value = bpy.data.images.load(os.path.join(MAPS, name + ".png"))
        value.colorspace_settings.name = "Non-Color" if non_color else "sRGB"
        IMAGES[key] = value
    return IMAGES[key]


def pbr(name, color, metallic, roughness, surface, emission=None):
    material = bpy.data.materials.new(name)
    material.use_nodes = True
    nodes, links = material.node_tree.nodes, material.node_tree.links
    bsdf = nodes.get("Principled BSDF")
    bsdf.inputs["Base Color"].default_value = (*color, 1.0)
    bsdf.inputs["Metallic"].default_value = metallic
    bsdf.inputs["Roughness"].default_value = roughness
    base = nodes.new("ShaderNodeTexImage")
    base.image = image(surface)
    normal = nodes.new("ShaderNodeTexImage")
    normal.image = image(surface + "_normal", True)
    normal_map = nodes.new("ShaderNodeNormalMap")
    normal_map.inputs["Strength"].default_value = .78
    orm = nodes.new("ShaderNodeTexImage")
    orm.image = image(surface + "_orm", True)
    split = nodes.new("ShaderNodeSeparateColor")
    split.mode = "RGB"
    links.new(base.outputs["Color"], bsdf.inputs["Base Color"])
    links.new(normal.outputs["Color"], normal_map.inputs["Color"])
    links.new(normal_map.outputs["Normal"], bsdf.inputs["Normal"])
    links.new(orm.outputs["Color"], split.inputs["Color"])
    links.new(split.outputs["Red"], bsdf.inputs["Metallic"])
    links.new(split.outputs["Green"], bsdf.inputs["Roughness"])
    if emission:
        out = bsdf.inputs.get("Emission Color") or bsdf.inputs.get("Emission")
        strength = bsdf.inputs.get("Emission Strength")
        if out:
            out.default_value = (*emission, 1.0)
        if strength:
            strength.default_value = 2.4
    return material


ICE = pbr("ExpanseIceHD", (.37, .68, .96), .06, .30, "aether_expanse_ice")
ICE_DARK = pbr("ExpanseIceShadowHD", (.08, .24, .48), .09, .40, "aether_expanse_ice")
METAL = pbr("ExpanseMetalHD", (.12, .25, .36), .78, .39, "aether_expanse_metal")
DARK = pbr("ExpanseDarkHD", (.028, .052, .081), .72, .30, "aether_expanse_metal")
HAZARD = pbr("ExpanseHazardHD", (.90, .28, .018), .20, .42, "aether_expanse_hazard")
CYAN = pbr("ExpanseDiagnosticHD", (.02, .60, 1.0), .30, .18, "aether_expanse_metal", (.02, .78, 1.0))


def make_collection(name):
    value = bpy.data.collections.new(name)
    bpy.context.scene.collection.children.link(value)
    return value


def root(collection, name):
    obj = bpy.data.objects.new(name, None)
    collection.objects.link(obj)
    return obj


def attach(obj, collection, parent):
    for previous in list(obj.users_collection):
        previous.objects.unlink(obj)
    collection.objects.link(obj)
    obj.parent = parent
    return obj


def bevel(obj, amount=.025):
    modifier = obj.modifiers.new("ExpanseBevel", "BEVEL")
    modifier.width = amount
    modifier.segments = 2
    modifier.limit_method = "ANGLE"
    bpy.context.view_layer.objects.active = obj
    bpy.ops.object.modifier_apply(modifier=modifier.name)


def tile_uv(obj, repeats):
    layer = obj.data.uv_layers.active
    if layer:
        for item in layer.data:
            item.uv *= repeats


def box(collection, parent, name, dims, pos, material, chamfer=.025, repeats=1.0, rotation=None):
    bpy.ops.mesh.primitive_cube_add(size=1.0, location=pos)
    obj = bpy.context.object
    obj.name = name
    obj.dimensions = dims
    bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
    if rotation:
        obj.rotation_euler = rotation
    if chamfer:
        bevel(obj, chamfer)
    tile_uv(obj, repeats)
    obj.data.materials.append(material)
    return attach(obj, collection, parent)


def cylinder(collection, parent, name, radius, depth, pos, material, sides=16):
    bpy.ops.mesh.primitive_cylinder_add(vertices=sides, radius=radius, depth=depth, location=pos)
    obj = bpy.context.object
    obj.name = name
    bevel(obj, min(.026, radius * .2))
    tile_uv(obj, max(1.0, depth / 2.0))
    obj.data.materials.append(material)
    return attach(obj, collection, parent)


def ice_rock(collection, parent, name, pos, scale, material, seed):
    rng = random.Random(seed)
    bpy.ops.mesh.primitive_ico_sphere_add(subdivisions=2, radius=1.0, location=pos)
    obj = bpy.context.object
    obj.name = name
    for vertex in obj.data.vertices:
        vertex.co.x *= .72 + rng.random() * .55
        vertex.co.y *= .60 + rng.random() * .64
        vertex.co.z *= .70 + rng.random() * .58
    obj.scale = scale
    bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
    bevel(obj, .03)
    tile_uv(obj, max(1.0, max(scale) / 3.0))
    obj.data.materials.append(material)
    return attach(obj, collection, parent)


def lower_meshes(collection, offset):
    """Normalize each reusable asset so its intended walk surface is Y=0."""
    for obj in collection.objects:
        if obj.type == "MESH":
            obj.location.y -= offset


def expanse_shelf():
    collection = make_collection("ExpanseShelf")
    parent = root(collection, "ExpanseShelfRoot")
    # 28 x 24m route-turn platform; it is a deliberate broad landform, not a prop.
    box(collection, parent, "ShelfMass", (28.0, .62, 24.0), (0, 0, 0), ICE_DARK, .09, 6.0)
    box(collection, parent, "ShelfTop", (25.4, .16, 21.4), (0, .38, 0), ICE, .045, 5.6)
    for x in (-8.2, 0.0, 8.2):
        box(collection, parent, "ShelfPlate_" + str(x), (6.4, .055, 19.6), (x, .515, 0), METAL, .015, 4.5)
        box(collection, parent, "ShelfGuide_" + str(x), (.09, .035, 18.2), (x + 2.78, .57, 0), CYAN, .004, 4.0)
    for i, (x, z) in enumerate([(-12, -9), (12, -8), (-11, 9), (11, 9)]):
        ice_rock(collection, parent, "ShelfIceAnchor_" + str(i), (x, 1.25, z), (2.7, 1.8, 2.3), ICE if i % 2 else ICE_DARK, 181 + i)
        cylinder(collection, parent, "ShelfPylon_" + str(i), .26, 2.8, (x * .83, 1.42, z * .78), METAL, 12)
        cylinder(collection, parent, "ShelfBeacon_" + str(i), .14, .25, (x * .83, 2.92, z * .78), CYAN, 16)
    for x in (-9.5, -4.7, .1, 4.9, 9.7):
        box(collection, parent, "ShelfEdgeFracture_" + str(x), (2.7, .22, .38), (x, .63, -10.4), DARK, .018, 1.4, (0, .14, 0))
    # ShelfTop is the walk surface; diagnostic/rock details intentionally rise above it.
    lower_meshes(collection, .46)
    return collection


def transit_spine():
    collection = make_collection("TransitSpine")
    parent = root(collection, "TransitSpineRoot")
    # Nominal 12m X-long segment, scaled only along X by the runtime route loader.
    box(collection, parent, "TransitDeck", (12.0, .28, 5.20), (0, 0, 0), METAL, .045, 3.2)
    box(collection, parent, "TransitIceInlay", (11.15, .07, 2.25), (0, .17, 0), ICE_DARK, .018, 2.8)
    for x in (-5, -3, -1, 1, 3, 5):
        box(collection, parent, "TransitCrossRib_" + str(x), (.15, .17, 5.34), (x, .20, 0), DARK, .015, 1.2)
        box(collection, parent, "TransitCenterMarker_" + str(x), (.38, .035, .11), (x, .235, 0), CYAN, .004, 1.0)
    # Low curbs and edge beacons read as engineering, but are intentionally not
    # collision rails: a player can leave the exposed route and reach the lowlands.
    for z in (-2.53, 2.53):
        box(collection, parent, "TransitEdgeCurb_" + str(z), (11.7, .12, .10), (0, .17, z), HAZARD, .009, 2.9)
    for x in (-5.5, 5.5):
        for z in (-2.38, 2.38):
            cylinder(collection, parent, "TransitBeacon_" + str(x) + str(z), .09, .48, (x, .40, z), CYAN, 12)
    for x in (-4.0, 0.0, 4.0):
        box(collection, parent, "TransitUndersideStrut_" + str(x), (.16, .95, .18), (x, -.52, 0), DARK, .018, 1.0, (0, 0, math.radians(18)))
    # Cross ribs are the walk surface; beacons remain slightly above it.
    lower_meshes(collection, .285)
    return collection


def lowland_field():
    collection = make_collection("LowlandField")
    parent = root(collection, "LowlandFieldRoot")
    # 80 x 72m catch basin. Repeated config placements form a continuous lower
    # ice sea under the whole expanded loop, not a lethal void or invisible wall.
    box(collection, parent, "LowlandBase", (80.0, .34, 72.0), (0, 0, 0), ICE_DARK, .075, 16.0)
    box(collection, parent, "LowlandSheet", (76.8, .10, 68.8), (0, .22, 0), ICE, .035, 15.0)
    for i, (x, z, sx, sz) in enumerate([(-24, -18, 13, 10), (8, -21, 17, 12), (29, 8, 13, 16), (-17, 17, 19, 13), (2, 22, 11, 15)]):
        ice_rock(collection, parent, "LowlandRidge_" + str(i), (x, .85, z), (sx / 4.2, 1.10 + i % 2 * .35, sz / 4.2), ICE if i % 2 else ICE_DARK, 550 + i)
    for i, (x, z, length, angle) in enumerate([(-31, 4, 17, .08), (-3, -5, 21, -.13), (24, -12, 13, .18), (13, 26, 18, -.08)]):
        box(collection, parent, "LowlandCrevasse_" + str(i), (length, .10, .38), (x, .34, z), DARK, .012, 2.5, (0, angle, 0))
        box(collection, parent, "LowlandGlow_" + str(i), (length * .62, .024, .06), (x, .405, z), CYAN, .004, 1.0, (0, angle, 0))
    for i, (x, z) in enumerate([(-32, -25), (35, -25), (-35, 26), (34, 26)]):
        cylinder(collection, parent, "LowlandAnchor_" + str(i), .42, 3.5, (x, 1.45, z), METAL, 16)
        cylinder(collection, parent, "LowlandAnchorLight_" + str(i), .18, .16, (x, 3.28, z), CYAN, 16)
    # LowlandSheet is the walk surface; crevasse glow stays as non-collision detail.
    lower_meshes(collection, .27)
    return collection


def export(collection, filename):
    bpy.ops.object.select_all(action="DESELECT")
    for obj in collection.objects:
        obj.select_set(True)
    bpy.context.view_layer.objects.active = collection.objects[0]
    bpy.ops.export_scene.gltf(filepath=os.path.join(OUT, filename), export_format="GLB", use_selection=True, export_materials="EXPORT")


shelf = expanse_shelf()
spine = transit_spine()
lowland = lowland_field()
bpy.ops.file.pack_all()
bpy.ops.wm.save_as_mainfile(filepath=SOURCE)
for collection, filename in [(shelf, "expanse_shelf.glb"), (spine, "transit_spine.glb"), (lowland, "lowland_field.glb")]:
    export(collection, filename)
print("Built connected Aetherfall Expanse:", OUT)
