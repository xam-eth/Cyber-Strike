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


build_ice_maps()
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
STEEL = pbr("ArchiveSteel", (0.10, 0.19, 0.26), 0.76, 0.43, "aether_metal")
DARK = pbr("ArchiveDark", (0.03, 0.055, 0.080), 0.68, 0.31, "aether_metal")
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


def box(collection, parent, name, dims, pos, material, bevel_size=.025, rotation=None):
    bpy.ops.mesh.primitive_cube_add(size=1.0, location=pos)
    obj = bpy.context.object
    obj.name = name
    obj.dimensions = dims
    bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
    if rotation:
        obj.rotation_euler = rotation
    if bevel_size:
        bevel(obj, bevel_size)
    obj.data.materials.append(material)
    return attach(obj, collection, parent)


def cylinder(collection, parent, name, radius, depth, pos, material, rotation=None, sides=16):
    bpy.ops.mesh.primitive_cylinder_add(vertices=sides, radius=radius, depth=depth, location=pos)
    obj = bpy.context.object
    obj.name = name
    if rotation:
        obj.rotation_euler = rotation
    bevel(obj, min(.028, radius * .18))
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
    obj.data.materials.append(material)
    return attach(obj, collection, parent)


def glacier_shelf():
    collection = new_collection("GlacierShelf")
    parent = root(collection, "GlacierShelfRoot")
    # 18m wide sloped ice/rock wall, open to sky and suitable as perimeter mass.
    ice_rock(collection, parent, "GlacierMassA", 1.0, (-5.6, 3.0, 0), (4.9, 4.5, 2.8), ICE_DARK, 10)
    ice_rock(collection, parent, "GlacierMassB", 1.0, (-1.6, 4.8, .4), (4.7, 6.8, 3.1), ICE, 11)
    ice_rock(collection, parent, "GlacierMassC", 1.0, (3.6, 3.7, -.2), (5.5, 5.1, 3.4), ICE_DARK, 12)
    ice_rock(collection, parent, "GlacierMassD", 1.0, (7.0, 2.3, .3), (3.5, 3.2, 2.5), ICE, 13)
    for index, x in enumerate((-7.6, -4.2, .5, 4.5, 7.8)):
        bpy.ops.mesh.primitive_cone_add(vertices=7, radius1=.72 + (index % 2) * .2, radius2=.12, depth=3.0 + index * .32, location=(x, 3.1 + index * .28, -2.55))
        shard = bpy.context.object
        shard.name = "IceShard_" + str(index)
        shard.rotation_euler = (.05 * index, .19 * index, .11 * index)
        shard.data.materials.append(ICE)
        attach(shard, collection, parent)
    # Half-buried robot anchors tell an extraction story without an indoor wall.
    for x in (-5.0, 1.8, 6.0):
        cylinder(collection, parent, "FrozenAnchor_" + str(x), .34, 3.3, (x, 1.6, 2.5), STEEL, None, 12)
        cylinder(collection, parent, "AnchorGlow_" + str(x), .16, .12, (x, 3.3, 2.5), CYAN, None, 16)
    return collection


def frozen_spire():
    collection = new_collection("FrozenSpire")
    parent = root(collection, "FrozenSpireRoot")
    # Narrow tall silhouette for far/mid shots; layered ice plates avoid a cone read.
    for index, (x, z, height, radius) in enumerate([(0, 0, 13.5, 2.1), (-1.7, .8, 8.5, 1.3), (1.6, -.7, 9.7, 1.45)]):
        bpy.ops.mesh.primitive_cone_add(vertices=6, radius1=radius, radius2=.18, depth=height, location=(x, height * .5, z))
        shard = bpy.context.object
        shard.name = "SpireShard_" + str(index)
        shard.rotation_euler = (.08 * index, .22 * index, .12 * index)
        shard.data.materials.append(ICE if index != 1 else ICE_DARK)
        attach(shard, collection, parent)
    for y in (2.6, 5.4, 8.2):
        box(collection, parent, "SpireIceBand_" + str(y), (2.55, .16, 2.15), (0, y, 0), ICE_DARK, .015, (0, .3, 0))
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
    bpy.ops.export_scene.gltf(filepath=os.path.join(OUT, filename), export_format="GLB", use_selection=True, export_materials="EXPORT")


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
