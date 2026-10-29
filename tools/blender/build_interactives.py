"""Build the two authored, reusable Stellar Horizon interaction props.

This script creates one editable Blender source and two GLB exports.  Both use
Aetherfall's embedded PBR maps; the cache and objective device are deliberately
separate assets so their collision, range trigger and game state live in Godot
scenes rather than in a unique level mesh.

Run with the project bpy virtual environment:
  LD_LIBRARY_PATH=/tmp/xlibs .venv/bin/python tools/blender/build_interactives.py
"""
import math
import os
import bpy

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "../.."))
OUT = os.path.join(ROOT, "assets", "world", "aetherfall", "interactives")
MATERIALS = os.path.join(ROOT, "assets", "world", "aetherfall", "materials")
SOURCE = os.path.join(ROOT, "source", "aetherfall_interactives.blend")
os.makedirs(OUT, exist_ok=True)
bpy.ops.wm.read_factory_settings(use_empty=True)

_IMAGE_CACHE = {}


def image(name, non_color=False):
    key = (name, non_color)
    if key in _IMAGE_CACHE:
        return _IMAGE_CACHE[key]
    path = os.path.join(MATERIALS, name + ".png")
    if not os.path.isfile(path):
        raise RuntimeError("Missing shared PBR map: " + path)
    value = bpy.data.images.load(path)
    value.colorspace_settings.name = "Non-Color" if non_color else "sRGB"
    _IMAGE_CACHE[key] = value
    return value


def pbr(name, color, metallic, roughness, surface, emission=None):
    value = bpy.data.materials.new(name)
    value.use_nodes = True
    nodes = value.node_tree.nodes
    links = value.node_tree.links
    bsdf = nodes.get("Principled BSDF")
    bsdf.inputs["Base Color"].default_value = (*color, 1.0)
    bsdf.inputs["Metallic"].default_value = metallic
    bsdf.inputs["Roughness"].default_value = roughness
    base = nodes.new("ShaderNodeTexImage")
    base.name = "BaseColor_" + surface
    base.image = image(surface)
    normal = nodes.new("ShaderNodeTexImage")
    normal.name = "Normal_" + surface
    normal.image = image(surface + "_normal", True)
    normal_map = nodes.new("ShaderNodeNormalMap")
    normal_map.inputs["Strength"].default_value = 0.72
    orm = nodes.new("ShaderNodeTexImage")
    orm.name = "ORM_" + surface
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
        strength_socket = bsdf.inputs.get("Emission Strength")
        if color_socket:
            color_socket.default_value = (*emission, 1.0)
        if strength_socket:
            strength_socket.default_value = 2.6
    return value


STEEL = pbr("InteractiveSteel", (0.17, 0.25, 0.31), 0.72, 0.49, "aether_metal")
DARK = pbr("InteractiveDark", (0.055, 0.075, 0.09), 0.72, 0.36, "aether_metal")
HAZARD = pbr("InteractiveHazard", (0.92, 0.34, 0.035), 0.18, 0.49, "aether_hazard")
ENERGY = pbr("InteractiveEnergy", (0.08, 0.55, 0.82), 0.28, 0.25, "aether_metal", (0.05, 0.72, 1.0))


def in_collection(obj, collection):
    for existing in list(obj.users_collection):
        existing.objects.unlink(obj)
    collection.objects.link(obj)


def bevel(obj, amount=0.035, segments=2):
    modifier = obj.modifiers.new("EdgeChamfer", "BEVEL")
    modifier.width = amount
    modifier.segments = segments
    modifier.limit_method = "ANGLE"
    bpy.context.view_layer.objects.active = obj
    bpy.ops.object.modifier_apply(modifier=modifier.name)
    return obj


def box(collection, name, dimensions, location, material, parent=None, chamfer=0.025):
    bpy.ops.mesh.primitive_cube_add(size=1.0, location=location)
    obj = bpy.context.object
    obj.name = name
    obj.dimensions = dimensions
    bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
    if chamfer:
        bevel(obj, chamfer)
    obj.data.materials.append(material)
    if parent:
        obj.parent = parent
    in_collection(obj, collection)
    return obj


def cylinder(collection, name, radius, depth, location, material, parent=None, vertices=16):
    bpy.ops.mesh.primitive_cylinder_add(vertices=vertices, radius=radius, depth=depth, location=location)
    obj = bpy.context.object
    obj.name = name
    bevel(obj, min(0.025, radius * 0.2), 2)
    obj.data.materials.append(material)
    if parent:
        obj.parent = parent
    in_collection(obj, collection)
    return obj


def rod(collection, name, radius, length, location, rotation, material, parent=None):
    obj = cylinder(collection, name, radius, length, location, material, parent, 12)
    obj.rotation_euler = rotation
    return obj


def empty(collection, name, location=(0, 0, 0), parent=None):
    obj = bpy.data.objects.new(name, None)
    obj.empty_display_type = "PLAIN_AXES"
    obj.location = location
    if parent:
        obj.parent = parent
    collection.objects.link(obj)
    return obj


def export_collection(collection, filename):
    bpy.ops.object.select_all(action="DESELECT")
    for obj in collection.objects:
        obj.select_set(True)
    bpy.context.view_layer.objects.active = collection.objects[0]
    bpy.ops.export_scene.gltf(
        filepath=os.path.join(OUT, filename),
        export_format="GLB",
        use_selection=True,
        export_yup=False,
        export_animations=True,
        export_materials="EXPORT",
    )


def build_tech_cache():
    collection = bpy.data.collections.new("TechCache")
    bpy.context.scene.collection.children.link(collection)
    root = empty(collection, "TechCacheRoot")
    # Footprint: 2.6 m wide, 1.5 m deep, 1.35 m tall. Bottom rests at Y=0.
    box(collection, "CacheBase", (2.60, 0.22, 1.50), (0, 0.11, 0), DARK, root, 0.045)
    box(collection, "CacheLowerHull", (2.42, 0.68, 1.34), (0, 0.49, 0), STEEL, root, 0.04)
    box(collection, "CacheFacePanel", (1.46, 0.42, 0.045), (0, 0.64, -0.695), DARK, root, 0.01)
    box(collection, "CacheStatusStrip", (1.13, 0.06, 0.055), (0, 0.78, -0.735), ENERGY, root, 0.008)
    for x in (-1.08, 1.08):
        box(collection, "CacheCornerRail_" + str(x), (0.10, 0.77, 0.12), (x, 0.59, -0.62), HAZARD, root, 0.018)
    for x in (-0.86, -0.29, 0.29, 0.86):
        box(collection, "CacheVent_" + str(x), (0.09, 0.31, 0.055), (x, 0.52, -0.76), DARK, root, 0.005)
    for x in (-1.08, 1.08):
        for z in (-0.56, 0.56):
            cylinder(collection, "CacheFoot_" + str(x) + str(z), 0.105, 0.12, (x, 0.06, z), DARK, root, 12)
    # Lid pivots from the rear edge and is keyed in Blender as the authored state animation.
    pivot = empty(collection, "TechCacheLidPivot", (0, 1.13, 0.61), root)
    lid = box(collection, "TechCacheLid", (2.38, 0.16, 1.28), (0, 0, -0.64), STEEL, pivot, 0.042)
    box(collection, "LidEnergyRail", (1.62, 0.035, 0.065), (0, 0.105, -0.57), ENERGY, pivot, 0.008)
    for x in (-0.95, 0.95):
        rod(collection, "LidHinge_" + str(x), 0.065, 0.40, (x, -0.02, 0.01), (0, math.pi / 2, 0), DARK, pivot)
    for x in (-0.89, 0.89):
        for z in (-0.43, 0.35):
            cylinder(collection, "LidBolt_" + str(x) + str(z), 0.045, 0.055, (x, 0.11, z), HAZARD, pivot, 12)
    pivot.rotation_mode = "XYZ"
    pivot.rotation_euler = (0, 0, 0)
    pivot.keyframe_insert(data_path="rotation_euler", frame=1)
    pivot.rotation_euler = (math.radians(70), 0, 0)
    pivot.keyframe_insert(data_path="rotation_euler", frame=36)
    if pivot.animation_data and pivot.animation_data.action:
        pivot.animation_data.action.name = "TechCache_Open"
    return collection


def build_objective_device():
    collection = bpy.data.collections.new("ObjectiveDevice")
    bpy.context.scene.collection.children.link(collection)
    root = empty(collection, "ObjectiveDeviceRoot")
    # Footprint: 1.8 m square; deliberately compact enough for the central deck.
    box(collection, "RelayBase", (1.82, 0.22, 1.82), (0, 0.11, 0), DARK, root, 0.045)
    cylinder(collection, "RelayPedestal", 0.57, 0.76, (0, 0.60, 0), STEEL, root, 20)
    cylinder(collection, "RelayRingLower", 0.77, 0.10, (0, 0.44, 0), HAZARD, root, 20)
    cylinder(collection, "RelayRingUpper", 0.65, 0.08, (0, 0.99, 0), ENERGY, root, 20)
    core = cylinder(collection, "ObjectiveCore", 0.23, 0.70, (0, 1.30, 0), ENERGY, root, 20)
    core.scale = (0.78, 0.78, 0.78)
    for angle in (0, math.pi * 0.5, math.pi, math.pi * 1.5):
        x, z = math.sin(angle) * 0.69, math.cos(angle) * 0.69
        rod(collection, "RelayStrut_" + str(angle), 0.055, 1.18, (x, 0.79, z), (math.radians(17) * math.cos(angle), 0, math.radians(17) * math.sin(angle)), STEEL, root)
        box(collection, "RelayFin_" + str(angle), (0.21, 0.62, 0.10), (x, 1.16, z), DARK, root, 0.012)
    panel = box(collection, "RelayControlPanel", (0.58, 0.43, 0.10), (0, 0.75, -0.93), STEEL, root, 0.015)
    box(collection, "RelayControlLight", (0.32, 0.05, 0.035), (0, 0.79, -0.99), ENERGY, root, 0.007)
    for x in (-0.68, 0.68):
        for z in (-0.68, 0.68):
            cylinder(collection, "RelayFoot_" + str(x) + str(z), 0.105, 0.12, (x, 0.06, z), DARK, root, 12)
    core.rotation_mode = "XYZ"
    core.keyframe_insert(data_path="location", frame=1)
    core.keyframe_insert(data_path="scale", frame=1)
    core.keyframe_insert(data_path="rotation_euler", frame=1)
    core.location.y = 1.50
    core.scale = (1.0, 1.0, 1.0)
    core.rotation_euler = (0, math.tau, 0)
    core.keyframe_insert(data_path="location", frame=42)
    core.keyframe_insert(data_path="scale", frame=42)
    core.keyframe_insert(data_path="rotation_euler", frame=42)
    if core.animation_data and core.animation_data.action:
        core.animation_data.action.name = "ObjectiveDevice_Activate"
    return collection


bpy.context.scene.render.fps = 30
bpy.context.scene.frame_start = 1
bpy.context.scene.frame_end = 42
cache_collection = build_tech_cache()
device_collection = build_objective_device()
bpy.ops.file.pack_all()
bpy.ops.wm.save_as_mainfile(filepath=SOURCE)
export_collection(cache_collection, "tech_cache.glb")
export_collection(device_collection, "objective_device.glb")
print("Built interactive props:", OUT)
