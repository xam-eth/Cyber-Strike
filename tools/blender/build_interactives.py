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
COMPOSITE = pbr("InteractiveComposite", (0.18, 0.31, 0.40), 0.34, 0.43, "aether_composite")
HAZARD = pbr("InteractiveHazard", (0.92, 0.34, 0.035), 0.18, 0.49, "aether_hazard")
WARNING = pbr("InteractiveWarning", (0.95, 0.58, 0.06), 0.13, 0.46, "aether_warning")
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


def tile_uv(obj, repeats):
    layer = obj.data.uv_layers.active
    if layer:
        for item in layer.data:
            item.uv *= repeats


def box(collection, name, dimensions, location, material, parent=None, chamfer=0.025, repeats=1.0):
    bpy.ops.mesh.primitive_cube_add(size=1.0, location=location)
    obj = bpy.context.object
    obj.name = name
    obj.dimensions = dimensions
    bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
    if chamfer:
        bevel(obj, chamfer, 3)
    tile_uv(obj, repeats)
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
    """Production-detail reference prop for the later kit refinement pass.

    The collision/range remains deliberately simple in Godot. The visual itself
    moves beyond a blockout: panel breaks, recessed controls, mechanical locks,
    cable glands, cartridge cradle and a properly layered animated lid make the
    cache readable as a field-built robot access device at close range.
    """
    collection = bpy.data.collections.new("TechCache")
    bpy.context.scene.collection.children.link(collection)
    root = empty(collection, "TechCacheRoot")
    # 2.6m x 1.5m x 1.35m retained so the existing Godot collision proxy and
    # interaction range stay valid. Every broad surface tiles its PBR map.
    box(collection, "CacheBaseSkid", (2.60, 0.16, 1.50), (0, 0.08, 0), DARK, root, .055, 2.8)
    box(collection, "CacheLowerHull", (2.42, 0.42, 1.34), (0, 0.37, 0), STEEL, root, .055, 3.2)
    box(collection, "CacheUpperHull", (2.30, 0.42, 1.24), (0, 0.78, 0), COMPOSITE, root, .045, 3.0)
    for x in (-1.12, 1.12):
        box(collection, "CacheArmoredCorner_" + str(x), (.16, .88, .16), (x, .52, -.54), HAZARD, root, .022, 1.0)
        box(collection, "CacheRearCorner_" + str(x), (.13, .76, .13), (x, .54, .54), DARK, root, .020, 1.0)
    # Side seams, service rails and attachment plates break the former single box silhouette.
    for side in (-1, 1):
        x = side * 1.225
        box(collection, "CacheSideRail_" + str(side), (.06, .58, 1.05), (x, .56, 0), DARK, root, .012, 2.5)
        for z in (-.39, 0.0, .39):
            box(collection, "CacheSideBrace_" + str(side) + str(z), (.09, .30, .07), (x * 1.02, .69, z), WARNING, root, .010, 1.0)
        box(collection, "CacheCableGland_" + str(side), (.09, .14, .19), (x * 1.04, .35, .31), COMPOSITE, root, .014, 1.0)
    # Front is an actual access panel: recessed screen, gasket, data slots, latch and vents.
    box(collection, "CacheFaceRecess", (1.72, .48, .055), (0, .67, -.696), DARK, root, .014, 2.0)
    box(collection, "CacheFacePanel", (1.53, .36, .038), (0, .67, -.735), COMPOSITE, root, .010, 1.6)
    box(collection, "CacheDisplayFrame", (.78, .18, .030), (0, .81, -.762), DARK, root, .006, 1.0)
    box(collection, "CacheDisplay", (.67, .09, .026), (0, .81, -.782), ENERGY, root, .004, 1.0)
    box(collection, "CacheStatusStrip", (1.22, .045, .030), (0, .95, -.770), ENERGY, root, .004, 1.0)
    box(collection, "CacheDataSlot", (.34, .08, .026), (-.53, .62, -.782), DARK, root, .004, 1.0)
    box(collection, "CacheDataSlotGlow", (.20, .022, .022), (-.53, .62, -.800), ENERGY, root, .002, 1.0)
    box(collection, "CacheLatchHousing", (.30, .20, .06), (.54, .65, -.770), DARK, root, .012, 1.0)
    box(collection, "CacheLatch", (.14, .11, .042), (.54, .65, -.812), HAZARD, root, .008, 1.0)
    for x in (-.82, -.65, -.31, -.14, .14, .31, .70, .87):
        box(collection, "CacheVent_" + str(x), (.075, .22, .026), (x, .48, -.778), DARK, root, .004, 1.0)
    # Reinforced feet and underside braces give it a functional placed-on-ground read.
    for x in (-1.07, 1.07):
        for z in (-.55, .55):
            box(collection, "CacheFoot_" + str(x) + str(z), (.22, .15, .20), (x, .075, z), DARK, root, .025, 1.0)
            box(collection, "CacheFootPad_" + str(x) + str(z), (.15, .035, .13), (x, .008, z), COMPOSITE, root, .008, 1.0)
    for x in (-.72, .72):
        box(collection, "CacheUndersideBrace_" + str(x), (.10, .18, 1.06), (x, .18, 0), DARK, root, .012, 2.2)
    # Lid pivots from the rear edge and retains the named authored animation.
    pivot = empty(collection, "TechCacheLidPivot", (0, 1.12, .61), root)
    box(collection, "TechCacheLid", (2.38, .16, 1.28), (0, 0, -.64), STEEL, pivot, .052, 3.3)
    box(collection, "LidInset", (1.92, .045, .91), (0, .095, -.62), COMPOSITE, pivot, .018, 3.0)
    box(collection, "LidEnergyRail", (1.68, .028, .068), (0, .126, -.55), ENERGY, pivot, .006, 1.0)
    for x in (-.78, 0, .78):
        box(collection, "LidSpine_" + str(x), (.11, .075, 1.02), (x, .12, -.62), DARK, pivot, .012, 2.2)
    for z in (-.94, -.30, .30):
        box(collection, "LidCrossRail_" + str(z), (1.93, .062, .08), (0, .125, z), DARK, pivot, .010, 2.4)
    for x in (-.98, .98):
        box(collection, "LidHingeBlock_" + str(x), (.22, .18, .12), (x, -.02, .015), DARK, pivot, .025, 1.0)
        box(collection, "LidHingePin_" + str(x), (.32, .07, .07), (x, -.095, .015), WARNING, pivot, .014, 1.0)
    for x in (-.92, .92):
        for z in (-.83, -.16, .48):
            box(collection, "LidBolt_" + str(x) + str(z), (.09, .035, .09), (x, .13, z), HAZARD, pivot, .012, 1.0)
    # The removable archive credential cartridge is visible only once the lid opens.
    box(collection, "CredentialCradle", (1.46, .14, .52), (0, 1.05, .02), DARK, root, .026, 1.7)
    box(collection, "CredentialDataCore", (.68, .22, .30), (0, 1.19, -.04), COMPOSITE, root, .028, 1.4)
    box(collection, "CredentialEnergySeal", (.45, .030, .17), (0, 1.315, -.04), ENERGY, root, .006, 1.0)
    for x in (-.48, .48):
        box(collection, "CradleClamp_" + str(x), (.10, .25, .34), (x, 1.18, .01), WARNING, root, .012, 1.0)
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
