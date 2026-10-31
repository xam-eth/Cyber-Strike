"""Build Phase 1's outdoor ice-planet and Sentinel Archive assets.

The textures generated here are original procedural PBR maps, not downloaded
reference art. The architecture is deliberately open-to-sky and terrain-bound;
it is not a spaceship hangar kit.
"""
import math
import os
import random
import bpy
import numpy as np
from PIL import Image

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "../.."))
OUT = os.path.join(ROOT, "assets", "world", "aetherfall", "ice_planet")
MAPS = os.path.join(ROOT, "assets", "world", "aetherfall", "materials")
SOURCE = os.path.join(ROOT, "source", "aetherfall_ice_planet.blend")
os.makedirs(OUT, exist_ok=True)
os.makedirs(MAPS, exist_ok=True)
bpy.ops.wm.read_factory_settings(use_empty=True)


def build_ice_maps():
    """Create distinct albedo, normal and ORM maps for frost/ice strata."""
    paths = [os.path.join(MAPS, "aether_ice" + suffix + ".png") for suffix in ("", "_normal", "_orm")]
    if all(os.path.isfile(path) for path in paths):
        return
    size = 512
    rng = np.random.default_rng(1312)
    coarse = rng.random((32, 32), dtype=np.float32)
    coarse_image = Image.fromarray(np.uint8(coarse * 255), "L").resize((size, size), Image.Resampling.BICUBIC)
    height = np.asarray(coarse_image, dtype=np.float32) / 255.0
    fine = rng.normal(0, 0.045, (size, size)).astype(np.float32)
    yy, xx = np.mgrid[0:size, 0:size]
    # Several angular crevasse families; blue shadow collects in their grooves.
    crevasse = np.zeros((size, size), dtype=np.float32)
    for angle, phase, spacing in [(0.19, 18, 47), (-0.42, 61, 71), (0.83, 29, 119)]:
        axis = xx * math.cos(angle) + yy * math.sin(angle) + phase
        distance = np.abs((axis % spacing) - spacing * .5) / (spacing * .5)
        crevasse += np.clip((0.075 - distance) * 12.0, 0, 0.32)
    height = np.clip(height * .52 + fine - crevasse, 0, 1)
    frost = np.clip(height * .7 + .2, 0, 1)
    albedo = np.empty((size, size, 3), dtype=np.uint8)
    albedo[:, :, 0] = np.clip(79 + frost * 126 - crevasse * 48, 0, 255)
    albedo[:, :, 1] = np.clip(120 + frost * 112 - crevasse * 22, 0, 255)
    albedo[:, :, 2] = np.clip(151 + frost * 101 + crevasse * 22, 0, 255)
    dx = np.gradient(height, axis=1)
    dy = np.gradient(height, axis=0)
    normal = np.dstack((-dx * 9.5 + .5, -dy * 9.5 + .5, np.ones_like(height)))
    normal /= np.linalg.norm(normal, axis=2, keepdims=True)
    normal = np.uint8(np.clip((normal * .5 + .5) * 255, 0, 255))
    orm = np.empty((size, size, 3), dtype=np.uint8)
    orm[:, :, 0] = np.uint8(np.clip(205 + height * 45, 0, 255))
    orm[:, :, 1] = np.uint8(np.clip(74 + (1 - height) * 92 + crevasse * 55, 0, 255))
    orm[:, :, 2] = 0
    Image.fromarray(albedo, "RGB").save(paths[0], optimize=True)
    Image.fromarray(normal, "RGB").save(paths[1], optimize=True)
    Image.fromarray(orm, "RGB").save(paths[2], optimize=True)


def build_citadel_metal_maps():
    """Turn the authored weathered-panel albedo into a Citadel PBR material set.

    The source albedo is deliberately separate from the generic kit metal: it
    contains panel breaks, frost, abrasion and fasteners at a building-readable
    scale. Normal and ORM are derived locally so this remains an actual PBR
    material, not a colour-only swap.
    """
    source = os.path.join(ROOT, "assets", "world", "aetherfall", "source_textures", "citadel_weathered_metal_base.png")
    paths = [os.path.join(MAPS, "aether_citadel_metal" + suffix + ".png") for suffix in ("", "_normal", "_orm")]
    if not os.path.isfile(source):
        raise RuntimeError("Missing Citadel source texture: " + source)
    if all(os.path.isfile(path) for path in paths):
        return
    albedo = Image.open(source).convert("RGB").resize((1024, 1024), Image.Resampling.LANCZOS)
    values = np.asarray(albedo, dtype=np.float32) / 255.0
    # Frost and bright chipped edges become relief, while dark seams recess.
    height = np.clip(values[:, :, 0] * .24 + values[:, :, 1] * .58 + values[:, :, 2] * .18, 0.0, 1.0)
    height = np.clip((height - .24) * 1.45, 0.0, 1.0)
    dx = np.gradient(height, axis=1)
    dy = np.gradient(height, axis=0)
    normal = np.dstack((-dx * 18.0, -dy * 18.0, np.ones_like(height)))
    normal /= np.linalg.norm(normal, axis=2, keepdims=True)
    normal = np.uint8(np.clip((normal * .5 + .5) * 255.0, 0, 255))
    # Steel stays metallic, but frost/rubbed panels are visibly rougher; AO
    # darkens the recessed panel seams instead of using a flat ORM constant.
    brightness = values.mean(axis=2)
    roughness = np.clip(.28 + brightness * .48 + (1.0 - height) * .12, 0.20, .88)
    occlusion = np.uint8(np.clip(155 + height * 92, 0, 255))
    orm = np.dstack((np.full_like(occlusion, 224), np.uint8(roughness * 255), occlusion))
    albedo.save(paths[0], optimize=True)
    Image.fromarray(normal, "RGB").save(paths[1], optimize=True)
    Image.fromarray(orm, "RGB").save(paths[2], optimize=True)


build_ice_maps()
build_citadel_metal_maps()
images = {}


def image(name, linear=False):
    key = (name, linear)
    if key not in images:
        result = bpy.data.images.load(os.path.join(MAPS, name + ".png"))
        result.colorspace_settings.name = "Non-Color" if linear else "sRGB"
        images[key] = result
    return images[key]


def pbr(name, color, metal, rough, surface, emission=None):
    result = bpy.data.materials.new(name)
    result.use_nodes = True
    nodes, links = result.node_tree.nodes, result.node_tree.links
    bsdf = nodes.get("Principled BSDF")
    bsdf.inputs["Base Color"].default_value = (*color, 1.0)
    bsdf.inputs["Metallic"].default_value = metal
    bsdf.inputs["Roughness"].default_value = rough
    base = nodes.new("ShaderNodeTexImage")
    base.image = image(surface)
    normal = nodes.new("ShaderNodeTexImage")
    normal.image = image(surface + "_normal", True)
    normal_map = nodes.new("ShaderNodeNormalMap")
    normal_map.inputs["Strength"].default_value = 0.68
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
        color_socket = bsdf.inputs.get("Emission Color") or bsdf.inputs.get("Emission")
        if color_socket:
            color_socket.default_value = (*emission, 1.0)
        strength = bsdf.inputs.get("Emission Strength")
        if strength:
            strength.default_value = 2.5
    return result


ICE = pbr("GlacialIce", (0.42, 0.68, 0.92), 0.02, 0.30, "aether_ice")
ICE_DARK = pbr("BlueIceShadow", (0.11, 0.28, 0.52), 0.05, 0.40, "aether_ice")
# Dedicated 1k Citadel exterior material: weathered structural panels, frost,
# micro-scratches and fasteners, with locally derived normal/ORM maps.
STEEL = pbr("ArchiveSteel", (0.10, 0.19, 0.26), 0.76, 0.43, "aether_citadel_metal")
DARK = pbr("ArchiveDark", (0.03, 0.055, 0.080), 0.68, 0.31, "aether_citadel_metal")
CYAN = pbr("ArchiveDiagnostic", (0.035, 0.48, 0.88), 0.26, 0.20, "aether_metal", (0.03, 0.70, 1.0))
HAZARD = pbr("ArchiveHazard", (0.88, 0.30, 0.025), 0.18, 0.48, "aether_hazard")


def new_collection(name):
    collection = bpy.data.collections.new(name)
    bpy.context.scene.collection.children.link(collection)
    return collection


def root(collection, name):
    result = bpy.data.objects.new(name, None)
    collection.objects.link(result)
    return result


def attach(obj, collection, parent):
    for previous in list(obj.users_collection):
        previous.objects.unlink(obj)
    collection.objects.link(obj)
    obj.parent = parent
    return obj


def bevel(obj, width=0.03):
    modifier = obj.modifiers.new("IcePlanetBevel", "BEVEL")
    modifier.width = width
    modifier.segments = 2
    modifier.limit_method = "ANGLE"
    bpy.context.view_layer.objects.active = obj
    bpy.ops.object.modifier_apply(modifier=modifier.name)


def tile_uv(obj, repeats):
    layer = obj.data.uv_layers.active
    if layer:
        for item in layer.data:
            item.uv *= repeats


def box(collection, parent, name, dims, pos, material, bevel_size=.025, rotation=None, repeats=None):
    bpy.ops.mesh.primitive_cube_add(size=1.0, location=pos)
    obj = bpy.context.object
    obj.name = name
    obj.dimensions = dims
    bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
    if rotation:
        obj.rotation_euler = rotation
    if bevel_size:
        bevel(obj, bevel_size)
    if repeats is None:
        repeats = max(1.0, max(dims) / (4.2 if "Ice" in material.name else 2.35))
    tile_uv(obj, repeats)
    obj.data.materials.append(material)
    return attach(obj, collection, parent)


def cylinder(collection, parent, name, radius, depth, pos, material, rotation=None, sides=16):
    bpy.ops.mesh.primitive_cylinder_add(vertices=sides, radius=radius, depth=depth, location=pos)
    obj = bpy.context.object
    obj.name = name
    # Preserve Godot Y-up in the raw GLB: Blender's cylinder depth starts on Z.
    obj.rotation_euler = (math.pi * .5, 0, 0)
    if rotation:
        obj.rotation_euler = (math.pi * .5 + rotation[0], rotation[1], rotation[2])
    bevel(obj, min(.028, radius * .18))
    tile_uv(obj, max(1.0, depth / (4.2 if "Ice" in material.name else 2.35)))
    obj.data.materials.append(material)
    return attach(obj, collection, parent)


def ice_rock(collection, parent, name, radius, pos, scale, material, seed):
    rng = random.Random(seed)
    bpy.ops.mesh.primitive_ico_sphere_add(subdivisions=2, radius=radius, location=pos)
    obj = bpy.context.object
    obj.name = name
    for vertex in obj.data.vertices:
        co = vertex.co
        variation = .78 + rng.random() * .48
        co.x *= variation
        co.y *= .72 + rng.random() * .55
        co.z *= .75 + rng.random() * .52
    obj.scale = scale
    bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
    bevel(obj, .035)
    tile_uv(obj, max(1.0, max(scale) / 3.0))
    obj.data.materials.append(material)
    return attach(obj, collection, parent)


def ice_spike(collection, parent, name, radius, height, pos, material, lean=0.0):
    """Tall faceted ice shard with its height on Godot Y, not Blender Z."""
    bpy.ops.mesh.primitive_cone_add(vertices=7, radius1=radius, radius2=.16, depth=height, location=pos)
    obj = bpy.context.object
    obj.name = name
    obj.rotation_euler = (math.pi * .5 + lean, lean * .32, lean * .18)
    bevel(obj, .035)
    tile_uv(obj, max(1.0, height / 3.0))
    obj.data.materials.append(material)
    return attach(obj, collection, parent)


def tapered_box(collection, parent, name, w, h, d, top_scale, pos, material,
                bevel_size=.04, rotation=None, repeats=None):
    """Tapered architectural shell for non-blockout tower and pylon silhouettes."""
    bpy.ops.mesh.primitive_cube_add(size=1.0, location=pos)
    obj = bpy.context.object
    obj.name = name
    obj.dimensions = (w, h, d)
    bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
    half_height = h * .5
    for vertex in obj.data.vertices:
        if vertex.co.y > 0.0:
            blend = (vertex.co.y + half_height) / (2.0 * half_height)
            vertex.co.x *= 1.0 - (1.0 - top_scale) * blend
            vertex.co.z *= 1.0 - (1.0 - top_scale) * blend
    obj.data.update()
    if rotation:
        obj.rotation_euler = rotation
    if bevel_size:
        bevel(obj, bevel_size)
    if repeats is None:
        repeats = max(1.0, max(w, h, d) / (4.2 if "Ice" in material.name else 2.35))
    tile_uv(obj, repeats)
    obj.data.materials.append(material)
    return attach(obj, collection, parent)


def brace_xy(collection, parent, name, a, b, thickness=.22, depth=.22, material=STEEL):
    """Manufactured diagonal support in an X/Y facade plane."""
    dx, dy = b[0] - a[0], b[1] - a[1]
    length = math.hypot(dx, dy)
    if length < .001:
        return None
    angle = math.atan2(-dx, dy)
    return box(collection, parent, name, (thickness, length, depth),
               ((a[0] + b[0]) * .5, (a[1] + b[1]) * .5, (a[2] + b[2]) * .5),
               material, .032, (0.0, 0.0, angle))


def torus(collection, parent, name, major_radius, minor_radius, pos, material, sides=40):
    """Y-up energy/service ring; breaks the silhouette beyond stacked boxes."""
    bpy.ops.mesh.primitive_torus_add(major_radius=major_radius, minor_radius=minor_radius,
                                     major_segments=sides, minor_segments=8, location=pos,
                                     rotation=(math.pi * .5, 0.0, 0.0))
    obj = bpy.context.object
    obj.name = name
    tile_uv(obj, max(1.0, major_radius * 2.0 / 2.35))
    obj.data.materials.append(material)
    return attach(obj, collection, parent)


def glacier_shelf():
    collection = new_collection("GlacierShelf")
    parent = root(collection, "GlacierShelfRoot")
    # A 34m wide macro ice formation. Existing placements become unmistakable
    # skyline/route landmarks rather than low, pebble-like perimeter props.
    ice_rock(collection, parent, "GlacierMassWest", 1.0, (-11.5, 5.0, .5), (6.2, 7.6, 5.4), ICE_DARK, 10)
    ice_rock(collection, parent, "GlacierMassCrown", 1.0, (-2.8, 9.2, .3), (7.5, 12.4, 6.4), ICE, 11)
    ice_rock(collection, parent, "GlacierMassEast", 1.0, (7.4, 6.4, -.4), (7.2, 8.9, 5.8), ICE_DARK, 12)
    ice_rock(collection, parent, "GlacierMassFoot", 1.0, (13.8, 3.8, .5), (4.5, 4.9, 4.4), ICE, 13)
    for index, (x, height, radius, lean) in enumerate([
        (-15.4, 11.0, 1.45, -.13), (-8.8, 16.5, 1.72, .09),
        (-.4, 22.0, 2.05, -.06), (8.2, 15.0, 1.66, .12), (15.1, 10.6, 1.34, -.10),
    ]):
        ice_spike(collection, parent, "IceShard_" + str(index), radius, height, (x, height * .5, -3.8), ICE if index % 2 else ICE_DARK, lean)
    # Embedded robot anchors make the formation read as harvested/contested geology.
    for x in (-10.0, 0.5, 11.5):
        cylinder(collection, parent, "FrozenAnchor_" + str(x), .40, 5.2, (x, 2.55, 3.6), STEEL, None, 12)
        cylinder(collection, parent, "AnchorGlow_" + str(x), .18, .16, (x, 5.22, 3.6), CYAN, None, 16)
        box(collection, parent, "AnchorClamp_" + str(x), (1.9, .18, .72), (x, .38, 3.4), DARK, .025, None, 1.5)
    return collection


def frozen_spire():
    collection = new_collection("FrozenSpire")
    parent = root(collection, "FrozenSpireRoot")
    # Distant silhouette is deliberately 26m high and multi-peak, so it reads
    # over the buildings instead of disappearing into the low ground texture.
    for index, (x, z, height, radius, lean) in enumerate([
        (0, 0, 26.0, 3.2, .02), (-3.2, 1.7, 17.5, 2.05, -.12),
        (3.5, -1.4, 20.5, 2.35, .10), (-6.2, -1.0, 11.2, 1.45, -.05),
    ]):
        ice_spike(collection, parent, "SpireShard_" + str(index), radius, height, (x, height * .5, z), ICE if index != 1 else ICE_DARK, lean)
    for y, width in ((3.8, 6.4), (8.2, 5.5), (13.7, 4.4), (18.9, 3.2)):
        box(collection, parent, "SpireIceBand_" + str(y), (width, .20, 3.0), (0, y, 0), ICE_DARK, .02, (0, .28, 0), 2.2)
    return collection


def sentinel_archive():
    collection = new_collection("SentinelArchive")
    parent = root(collection, "SentinelArchiveRoot")
    # 15m x 9m x 11m exterior facility, front toward negative Z before placement rotation.
    box(collection, parent, "ArchiveFoundation", (15.2, .45, 9.2), (0, .23, 0), ICE_DARK, .06)
    # Phase 3 opens the formerly solid core into a real shell. The compact
    # vestibule occupies this volume; the south/front threshold stays clear.
    box(collection, parent, "ArchiveRearShell", (11.7, 7.8, .55), (0, 4.12, 3.65), STEEL, .055)
    for x in (-5.82, 5.82):
        box(collection, parent, "ArchiveSideShell_" + str(x), (.78, 7.8, 5.55), (x, 4.12, .85), STEEL, .055)
    for x in (-4.08, 4.08):
        box(collection, parent, "ArchiveFrontWing_" + str(x), (3.55, 7.8, .55), (x, 4.12, -2.25), STEEL, .055)
    box(collection, parent, "ArchiveFrontLintel", (5.15, 3.0, .55), (0, 6.5, -2.25), STEEL, .055)
    box(collection, parent, "ArchiveRoof", (13.9, .42, 7.75), (0, 8.22, .85), DARK, .06)
    # The framed south/front opening is a physical threshold to the compact
    # interior, not a decorative sealed wall. Door pylons retain its robot ID.
    for x in (-2.45, 2.45):
        box(collection, parent, "DoorPylon_" + str(x), (.38, 5.8, .35), (x, 3.0, -2.4), ICE_DARK, .025)
        box(collection, parent, "DoorGuide_" + str(x), (.08, 4.3, .06), (x * .89, 2.78, -2.65), CYAN, .006)
    box(collection, parent, "DoorDiagnostic", (2.2, .10, .05), (0, 5.05, -2.67), CYAN, .006)
    # Layered side buttresses and frozen cable/pipe interface.
    for x in (-5.9, 5.9):
        box(collection, parent, "ArchiveButtress_" + str(x), (.72, 7.4, 6.8), (x, 3.8, .95), DARK, .035)
        for z in (-.9, 1.2, 2.9):
            box(collection, parent, "ArchiveSideLight_" + str(x) + str(z), (.06, .85, .45), (x * .95, 4.55, z), CYAN, .006)
    for y in (1.6, 3.3, 5.0, 6.7):
        box(collection, parent, "ArchiveFacadeBand_" + str(y), (10.9, .16, .18), (0, y, -2.25), ICE_DARK, .01)
    for x in (-4.4, -2.9, 2.9, 4.4):
        box(collection, parent, "ArchiveFacadeRib_" + str(x), (.18, 6.7, .18), (x, 3.7, -2.32), DARK, .015)
    # Receiver crown gives destination silhouette against open sky.
    cylinder(collection, parent, "ArchiveReceiverBase", 1.25, .46, (0, 8.72, .85), STEEL, None, 20)
    cylinder(collection, parent, "ArchiveReceiverCore", .46, 2.7, (0, 10.25, .85), CYAN, None, 20)
    for angle in (0, math.pi * .5, math.pi, math.pi * 1.5):
        x, z = math.sin(angle) * 1.52, .85 + math.cos(angle) * 1.52
        box(collection, parent, "ReceiverVane_" + str(angle), (.16, 1.55, .98), (x, 10.0, z), STEEL, .018, (0, -angle, 0))
    # Terrain clamp rocks merge the facility visually into the ice plateau.
    ice_rock(collection, parent, "ArchiveIceClampWest", 1.0, (-6.6, 1.3, 2.6), (2.1, 1.8, 2.0), ICE, 51)
    ice_rock(collection, parent, "ArchiveIceClampEast", 1.0, (6.6, 1.3, 2.6), (2.1, 1.8, 2.0), ICE, 52)
    # Macro-scale outer bastion: the vestibule-sized Archive core is retained,
    # while flank towers and a receiver crown make the final destination read
    # as a robot citadel from the overview and long perimeter routes.
    box(collection, parent, "ArchiveCitadelFoundation", (27.0, .72, 17.0), (0, .18, .85), ICE_DARK, .10, None, 5.0)
    for x in (-10.1, 10.1):
        box(collection, parent, "ArchiveCitadelWing_" + str(x), (3.35, 10.4, 10.8), (x, 5.38, .85), STEEL, .075, None, 4.0)
        box(collection, parent, "ArchiveCitadelCap_" + str(x), (4.15, .46, 11.55), (x, 10.78, .85), DARK, .06, None, 3.0)
        for y in (1.7, 4.0, 6.3, 8.6):
            box(collection, parent, "CitadelWingBand_" + str(x) + str(y), (3.62, .13, 11.02), (x, y, .85), HAZARD, .012, None, 2.4)
        for z in (-3.0, .9, 4.6):
            box(collection, parent, "CitadelWingLight_" + str(x) + str(z), (.055, 1.32, .64), (x * .982, 7.45, z), CYAN, .006, None, 1.0)
        box(collection, parent, "ArchiveGatePylon_" + str(x), (2.05, 17.6, 2.75), (x * .91, 8.8, -4.2), DARK, .065, None, 3.4)
        box(collection, parent, "ArchiveGateGuide_" + str(x), (.12, 13.8, .12), (x * .91, 8.9, -5.62), CYAN, .008, None, 1.0)
    box(collection, parent, "ArchiveCitadelBridge", (20.4, .74, 3.15), (0, 13.6, 2.85), STEEL, .06, None, 4.0)
    box(collection, parent, "ArchiveCrownBase", (7.2, 1.0, 6.1), (0, 14.45, 2.15), DARK, .08, None, 2.6)
    cylinder(collection, parent, "ArchiveCrownReceiver", 1.15, 9.0, (0, 19.25, 2.15), CYAN, None, 20)
    for angle in (0, math.pi * .5, math.pi, math.pi * 1.5):
        x, z = math.sin(angle) * 2.2, 2.15 + math.cos(angle) * 2.2
        box(collection, parent, "ArchiveCrownVane_" + str(angle), (.20, 4.0, 1.35), (x, 18.5, z), STEEL, .025, (0, -angle, 0), 1.5)

    # ------------------------------------------------------------------
    # Citadel production architecture: meaningful tiered construction,
    # landing/service decks, support logic and a true command silhouette.
    # All elements are visual-only relative to the retained Phase-3 shell
    # collision, so the known vestibule threshold and traversal stay intact.
    # ------------------------------------------------------------------
    box(collection, parent, "CitadelArrivalApron", (24.5, .34, 7.6), (0, .26, -7.35), STEEL, .055, None, 5.2)
    box(collection, parent, "CitadelArrivalIceFoot", (28.6, .56, 4.5), (0, -.04, -9.7), ICE_DARK, .075, None, 5.0)
    for x in (-8.05, -4.05, 4.05, 8.05):
        box(collection, parent, "CitadelArrivalPlate_" + str(x), (3.45, .07, 6.5), (x, .49, -7.35), DARK, .012, None, 2.2)
        box(collection, parent, "CitadelArrivalGuide_" + str(x), (2.25, .025, .09), (x, .55, -9.95), CYAN, .006)
    # Tiered wing terraces create the broad, inhabited base read instead of two loose towers.
    for side in (-1.0, 1.0):
        sx = side
        box(collection, parent, "CitadelLowerTerrace_" + str(int(sx)), (6.3, .42, 4.25), (sx * 6.9, 1.65, -4.8), STEEL, .045, None, 3.0)
        box(collection, parent, "CitadelMidTerrace_" + str(int(sx)), (5.3, .36, 3.45), (sx * 7.55, 4.85, -2.8), DARK, .045, None, 2.5)
        box(collection, parent, "CitadelUpperTerrace_" + str(int(sx)), (4.45, .32, 3.10), (sx * 8.15, 8.05, -.5), STEEL, .040, None, 2.2)
        box(collection, parent, "CitadelDockPod_" + str(int(sx)), (4.55, 2.35, 3.25), (sx * 6.85, 2.88, -3.32), DARK, .060, None, 2.5)
        box(collection, parent, "CitadelDockRecess_" + str(int(sx)), (3.38, 1.28, .08), (sx * 6.85, 2.96, -5.00), ICE_DARK, .014, None, 1.6)
        box(collection, parent, "CitadelDockLight_" + str(int(sx)), (2.75, .09, .045), (sx * 6.85, 3.82, -5.08), CYAN, .006)
        # Open undersides and X-braces communicate a buildable, load-bearing platform.
        for z in (-6.05, -3.45):
            box(collection, parent, "CitadelTerraceSupport_" + str(int(sx)) + str(z), (.36, 3.0, .36), (sx * 8.9, 1.55, z), STEEL, .025, None, 1.8)
        brace_xy(collection, parent, "CitadelTerraceBraceA_" + str(int(sx)), (sx * 8.9, .25, -6.05), (sx * 6.3, 3.1, -5.3), .24, .18, HAZARD)
        brace_xy(collection, parent, "CitadelTerraceBraceB_" + str(int(sx)), (sx * 8.9, .25, -3.45), (sx * 6.3, 3.1, -4.25), .24, .18, STEEL)
        # Layered mechanical facade: louver rows, side service trunk and status lights.
        for level in (2.05, 3.1, 4.15, 5.2, 6.25, 7.3):
            box(collection, parent, "CitadelWingLouver_" + str(int(sx)) + str(level), (2.48, .10, .13), (sx * 10.0, level, -4.65), DARK, .013, None, 1.7)
        cylinder(collection, parent, "CitadelServiceTrunk_" + str(int(sx)), .34, 7.9, (sx * 11.82, 5.2, 4.18), STEEL, None, 16)
        for y in (2.0, 4.25, 6.5, 8.75):
            torus(collection, parent, "CitadelServiceCollar_" + str(int(sx)) + str(y), .48, .055, (sx * 11.82, y, 4.18), HAZARD, 24)
        # Tall tapered front pylons frame the access rather than a single flat facade.
        tapered_box(collection, parent, "CitadelDockFrame_" + str(int(sx)), 1.85, 11.8, 2.05, .56, (sx * 7.25, 5.95, -5.55), DARK, .065, None, 3.8)
        box(collection, parent, "CitadelDockFrameLight_" + str(int(sx)), (.12, 8.3, .10), (sx * 7.25, 5.9, -6.62), CYAN, .010)
        brace_xy(collection, parent, "CitadelDockBrace_" + str(int(sx)), (sx * 7.65, 1.0, -6.2), (sx * 9.45, 9.35, -5.45), .20, .16, STEEL)

    # Layered central command tower: a tapered shell, armour bands, receiver rings and fins.
    tapered_box(collection, parent, "ArchiveCommandSpine", 6.1, 13.6, 4.9, .36, (0, 14.3, 2.7), DARK, .085, None, 4.6)
    tapered_box(collection, parent, "ArchiveCommandCore", 3.25, 14.5, 2.45, .44, (0, 15.05, 2.05), STEEL, .055, None, 4.2)
    for y, width in ((9.2, 6.25), (11.55, 5.45), (13.9, 4.65), (16.25, 3.85), (18.6, 3.10)):
        box(collection, parent, "ArchiveCommandBand_" + str(y), (width, .17, 4.15), (0, y, .18 + (y - 9.2) * .26), HAZARD if int(y * 10) % 2 else STEEL, .018, None, 2.4)
    for side in (-1.0, 1.0):
        box(collection, parent, "ArchiveCommandFin_" + str(int(side)), (.25, 10.6, 2.45), (side * 2.85, 15.45, 2.68), STEEL, .035, None, 2.8)
        box(collection, parent, "ArchiveCommandLight_" + str(int(side)), (.055, 8.85, .12), (side * 1.38, 15.25, -.62), CYAN, .008)
    torus(collection, parent, "ArchiveCommandHaloLower", 3.15, .13, (0, 18.65, 2.7), STEEL, 48)
    torus(collection, parent, "ArchiveCommandHaloEnergy", 2.48, .09, (0, 20.35, 2.7), CYAN, 48)
    # Two asymmetric communications dishes and a transverse maintenance bridge make a readable skyline.
    for side in (-1.0, 1.0):
        cylinder(collection, parent, "CitadelDishMast_" + str(int(side)), .20, 5.6, (side * 12.5, 13.65, 2.5), DARK, None, 16)
        torus(collection, parent, "CitadelDishRing_" + str(int(side)), 1.48, .10, (side * 12.5, 16.35, 2.5), STEEL, 36)
        box(collection, parent, "CitadelDishNeedle_" + str(int(side)), (.12, 3.25, .12), (side * 12.5, 18.05, 2.5), CYAN, .018)
    box(collection, parent, "CitadelTransverseServiceBridge", (18.6, .38, 1.95), (0, 11.75, -1.1), STEEL, .045, None, 3.7)
    for x in (-7.2, -3.6, 0.0, 3.6, 7.2):
        box(collection, parent, "CitadelBridgeGrate_" + str(x), (2.55, .06, 1.68), (x, 12.00, -1.1), DARK, .008, None, 1.6)
        box(collection, parent, "CitadelBridgeRail_" + str(x), (.09, 1.05, .09), (x, 12.46, -.18), HAZARD, .012)

    return collection


def cryo_pylon():
    collection = new_collection("CryoPylon")
    parent = root(collection, "CryoPylonRoot")
    # Tall exterior robot pylon to bridge architecture and cliff silhouettes.
    cylinder(collection, parent, "PylonBase", 1.25, .48, (0, .24, 0), ICE_DARK, None, 20)
    cylinder(collection, parent, "PylonShaft", .62, 9.8, (0, 5.15, 0), STEEL, None, 16)
    for y in (1.4, 3.2, 5.0, 6.8, 8.6):
        cylinder(collection, parent, "PylonRing_" + str(y), .92, .16, (0, y, 0), ICE_DARK, None, 16)
    for angle in (0, math.pi * .5, math.pi, math.pi * 1.5):
        x, z = math.sin(angle) * 1.0, math.cos(angle) * 1.0
        box(collection, parent, "PylonFin_" + str(angle), (.16, 5.5, .72), (x, 5.5, z), DARK, .018, (0, -angle, 0))
    cylinder(collection, parent, "PylonBeacon", .34, .58, (0, 10.35, 0), CYAN, None, 20)
    return collection


def export(collection, filename):
    bpy.ops.object.select_all(action="DESELECT")
    for obj in collection.objects:
        obj.select_set(True)
    bpy.context.view_layer.objects.active = collection.objects[0]
    bpy.ops.export_scene.gltf(filepath=os.path.join(OUT, filename), export_format="GLB", use_selection=True, export_materials="EXPORT", export_yup=False)


sets = [
    (glacier_shelf(), "glacier_shelf.glb"),
    (frozen_spire(), "frozen_spire.glb"),
    (sentinel_archive(), "sentinel_archive.glb"),
    (cryo_pylon(), "cryo_pylon.glb"),
]
bpy.ops.file.pack_all()
bpy.ops.wm.save_as_mainfile(filepath=SOURCE)
for collection, filename in sets:
    export(collection, filename)
print("Built Phase 1 ice planet assets in", OUT)
