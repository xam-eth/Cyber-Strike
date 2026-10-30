"""Author Phase 2 cover, sight-break and terrace assets for Aetherfall.

All four assets are reusable PBR setpieces with intentional tactical roles:
berms are low hard cover, salvage pods are directional cover, cryo bulkheads
break long sightlines, and terraces make the basin read as layered terrain.
"""
import math
import os
import random
import bpy

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "../.."))
OUT = os.path.join(ROOT, "assets", "world", "aetherfall", "phase2")
MAPS = os.path.join(ROOT, "assets", "world", "aetherfall", "materials")
SOURCE = os.path.join(ROOT, "source", "aetherfall_phase2_cover.blend")
os.makedirs(OUT, exist_ok=True)
bpy.ops.wm.read_factory_settings(use_empty=True)
images = {}


def image(name, linear=False):
    key = (name, linear)
    if key not in images:
        value = bpy.data.images.load(os.path.join(MAPS, name + ".png"))
        value.colorspace_settings.name = "Non-Color" if linear else "sRGB"
        images[key] = value
    return images[key]


def pbr(name, color, metal, rough, surface, emission=None):
    material = bpy.data.materials.new(name)
    material.use_nodes = True
    nodes, links = material.node_tree.nodes, material.node_tree.links
    bsdf = nodes.get("Principled BSDF")
    bsdf.inputs["Base Color"].default_value = (*color, 1.0)
    bsdf.inputs["Metallic"].default_value = metal
    bsdf.inputs["Roughness"].default_value = rough
    base = nodes.new("ShaderNodeTexImage")
    base.image = image(surface)
    normal = nodes.new("ShaderNodeTexImage")
    normal.image = image(surface + "_normal", True)
    normal_map = nodes.new("ShaderNodeNormalMap")
    normal_map.inputs["Strength"].default_value = .70
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
            strength.default_value = 2.35
    return material


ICE = pbr("Phase2Ice", (.40, .67, .92), .02, .30, "aether_ice")
ICE_DARK = pbr("Phase2IceShadow", (.08, .25, .50), .05, .42, "aether_ice")
STEEL = pbr("Phase2Steel", (.10, .20, .28), .76, .44, "aether_metal")
DARK = pbr("Phase2Dark", (.035, .06, .09), .70, .32, "aether_metal")
HAZARD = pbr("Phase2Hazard", (.88, .29, .025), .18, .48, "aether_hazard")
CYAN = pbr("Phase2Cyan", (.03, .50, .88), .24, .20, "aether_metal", (.03, .72, 1.0))


def col(name):
    collection = bpy.data.collections.new(name)
    bpy.context.scene.collection.children.link(collection)
    return collection


def root(collection, name):
    item = bpy.data.objects.new(name, None)
    collection.objects.link(item)
    return item


def attach(obj, collection, parent):
    for old in list(obj.users_collection):
        old.objects.unlink(obj)
    collection.objects.link(obj)
    obj.parent = parent
    return obj


def bevel(obj, width=.028):
    modifier = obj.modifiers.new("Phase2Bevel", "BEVEL")
    modifier.width = width
    modifier.segments = 2
    modifier.limit_method = "ANGLE"
    bpy.context.view_layer.objects.active = obj
    bpy.ops.object.modifier_apply(modifier=modifier.name)


def box(collection, parent, name, dims, pos, mat, bevel_size=.025, rot=None):
    bpy.ops.mesh.primitive_cube_add(size=1.0, location=pos)
    obj = bpy.context.object
    obj.name = name
    obj.dimensions = dims
    bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
    if rot:
        obj.rotation_euler = rot
    if bevel_size:
        bevel(obj, bevel_size)
    obj.data.materials.append(mat)
    return attach(obj, collection, parent)


def cylinder(collection, parent, name, radius, depth, pos, mat, rot=None, sides=16):
    bpy.ops.mesh.primitive_cylinder_add(vertices=sides, radius=radius, depth=depth, location=pos)
    obj = bpy.context.object
    obj.name = name
    if rot:
        obj.rotation_euler = rot
    bevel(obj, min(.026, radius * .18))
    obj.data.materials.append(mat)
    return attach(obj, collection, parent)


def ice_rock(collection, parent, name, pos, scale, material, seed):
    rng = random.Random(seed)
    bpy.ops.mesh.primitive_ico_sphere_add(subdivisions=2, radius=1.0, location=pos)
    obj = bpy.context.object
    obj.name = name
    for vertex in obj.data.vertices:
        vertex.co.x *= .75 + rng.random() * .55
        vertex.co.y *= .65 + rng.random() * .60
        vertex.co.z *= .75 + rng.random() * .48
    obj.scale = scale
    bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
    bevel(obj, .03)
    obj.data.materials.append(material)
    return attach(obj, collection, parent)


def glacier_berm():
    collection = col("GlacierBerm")
    parent = root(collection, "GlacierBermRoot")
    # Width 5.3m, average cover height 1.7m; irregular so it reads as terrain.
    ice_rock(collection, parent, "BermCore", (0, .86, 0), (2.55, 1.15, 1.15), ICE_DARK, 300)
    ice_rock(collection, parent, "BermLeft", (-1.75, .95, -.28), (1.12, 1.20, .88), ICE, 301)
    ice_rock(collection, parent, "BermRight", (1.78, .72, .28), (1.35, .92, .92), ICE, 302)
    for i, x in enumerate((-1.15, .25, 1.35)):
        bpy.ops.mesh.primitive_cone_add(vertices=6, radius1=.38, radius2=.08, depth=1.9 + .22 * i, location=(x, 1.15, -.72))
        shard = bpy.context.object
        shard.name = "BermShard_" + str(i)
        shard.rotation_euler = (.05 * i, .2 * i, .09 * i)
        shard.data.materials.append(ICE)
        attach(shard, collection, parent)
    box(collection, parent, "FrozenCableTray", (3.4, .18, .22), (0, 1.02, .86), DARK, .012)
    for x in (-1.18, 0, 1.18):
        box(collection, parent, "CableIndicator_" + str(x), (.18, .10, .04), (x, 1.12, .99), CYAN, .004)
    return collection


def salvage_pod():
    collection = col("SalvagePod")
    parent = root(collection, "SalvagePodRoot")
    # 4.3m robot salvage unit: directional hard cover with mechanical story.
    box(collection, parent, "PodBase", (4.25, .36, 3.10), (0, .18, 0), DARK, .045)
    box(collection, parent, "PodHull", (3.68, 1.75, 2.52), (0, 1.08, 0), STEEL, .045)
    box(collection, parent, "PodFrontArmor", (2.65, 1.20, .30), (0, 1.12, -1.40), ICE_DARK, .025)
    for x in (-1.52, 1.52):
        cylinder(collection, parent, "PodWheel_" + str(x), .56, .34, (x, .62, .92), DARK, (math.pi * .5, 0, 0), 16)
        cylinder(collection, parent, "PodHub_" + str(x), .21, .38, (x, .62, .92), CYAN, (math.pi * .5, 0, 0), 16)
    box(collection, parent, "PodToolArm", (.36, .36, 2.35), (1.35, 1.65, -.85), STEEL, .025, (0, -.32, 0))
    cylinder(collection, parent, "PodToolHead", .42, .58, (1.75, 1.63, -1.9), DARK, (math.pi * .5, 0, 0), 16)
    box(collection, parent, "PodDiagnostic", (1.65, .18, .06), (0, 1.66, -1.62), CYAN, .006)
    for x in (-1.2, 0, 1.2):
        box(collection, parent, "PodHullRib_" + str(x), (.12, 1.20, .13), (x, 1.2, -1.39), HAZARD, .01)
    return collection


def cryo_bulkhead():
    collection = col("CryoBulkhead")
    parent = root(collection, "CryoBulkheadRoot")
    # 6.8m wide / 5m high sightline breaker, intentionally not a roof or corridor.
    box(collection, parent, "BulkheadFoot", (6.75, .36, 1.15), (0, .18, 0), ICE_DARK, .045)
    for x in (-2.75, 2.75):
        box(collection, parent, "BulkheadPillar_" + str(x), (.65, 4.85, 1.0), (x, 2.55, 0), STEEL, .035)
        cylinder(collection, parent, "BulkheadPipe_" + str(x), .27, 5.25, (x * .83, 2.7, .52), ICE, None, 16)
    box(collection, parent, "BulkheadCrossbar", (6.25, .62, .92), (0, 4.92, 0), DARK, .04)
    box(collection, parent, "BulkheadCore", (4.48, 3.45, .52), (0, 2.65, .10), STEEL, .035)
    for y in (1.55, 2.55, 3.55):
        box(collection, parent, "BulkheadVent_" + str(y), (3.22, .12, .08), (0, y, -.22), DARK, .006)
    for x in (-1.75, 0, 1.75):
        box(collection, parent, "BulkheadLight_" + str(x), (.44, .10, .04), (x, 4.25, -.43), CYAN, .004)
    for x in (-2.1, 2.1):
        box(collection, parent, "BulkheadBrace_" + str(x), (.16, 3.9, .20), (x, 2.55, -.58), HAZARD, .012, (0, 0, -.30 if x < 0 else .30))
    return collection


def ice_terrace():
    collection = col("IceTerrace")
    parent = root(collection, "IceTerraceRoot")
    # 8m broad terraced ledge (max 2.2m high) for a visible layered basin edge.
    box(collection, parent, "TerraceBase", (8.2, .40, 5.2), (0, .20, 0), ICE_DARK, .05)
    box(collection, parent, "TerraceStepLow", (7.4, .55, 4.35), (0, .58, -.15), ICE, .045)
    box(collection, parent, "TerraceStepHigh", (5.8, .65, 3.30), (0, 1.18, .25), ICE_DARK, .045)
    ice_rock(collection, parent, "TerraceRockWest", (-3.25, 1.48, .7), (1.55, 1.25, 1.45), ICE, 411)
    ice_rock(collection, parent, "TerraceRockEast", (3.25, 1.52, -.3), (1.65, 1.32, 1.35), ICE_DARK, 412)
    for x in (-2.15, 0, 2.15):
        box(collection, parent, "TerracePlate_" + str(x), (1.35, .10, 1.65), (x, 1.55, .3), DARK, .01)
        box(collection, parent, "TerraceMarker_" + str(x), (.62, .055, .06), (x, 1.63, -.43), CYAN, .004)
    return collection


def export(collection, filename):
    bpy.ops.object.select_all(action="DESELECT")
    for obj in collection.objects:
        obj.select_set(True)
    bpy.context.view_layer.objects.active = collection.objects[0]
    bpy.ops.export_scene.gltf(filepath=os.path.join(OUT, filename), export_format="GLB", use_selection=True, export_materials="EXPORT")


sets = [
    (glacier_berm(), "glacier_berm.glb"),
    (salvage_pod(), "salvage_pod.glb"),
    (cryo_bulkhead(), "cryo_bulkhead.glb"),
    (ice_terrace(), "ice_terrace.glb"),
]
bpy.ops.file.pack_all()
bpy.ops.wm.save_as_mainfile(filepath=SOURCE)
for collection, filename in sets:
    export(collection, filename)
print("Built Phase 2 cover assets in", OUT)
