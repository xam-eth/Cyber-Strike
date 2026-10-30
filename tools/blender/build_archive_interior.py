"""Build Aetherfall Phase 3's compact Sentinel Archive vestibule and computer.

The assets use the project's packed PBR maps and preserve Y-up coordinates.
They are intentionally one compact exterior-linked interior, not a generic
multi-room dungeon or an unrelated second world.
"""
import math
import os
import bpy

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "../.."))
OUT = os.path.join(ROOT, "assets", "world", "aetherfall", "archive")
MAPS = os.path.join(ROOT, "assets", "world", "aetherfall", "materials")
SOURCE = os.path.join(ROOT, "source", "aetherfall_archive_interior.blend")
os.makedirs(OUT, exist_ok=True)
bpy.ops.wm.read_factory_settings(use_empty=True)
IMAGE_CACHE = {}


def image(name, non_color=False):
    key = (name, non_color)
    if key not in IMAGE_CACHE:
        result = bpy.data.images.load(os.path.join(MAPS, name + ".png"))
        result.colorspace_settings.name = "Non-Color" if non_color else "sRGB"
        IMAGE_CACHE[key] = result
    return IMAGE_CACHE[key]


def pbr(name, color, metallic, roughness, surface, emission=None):
    result = bpy.data.materials.new(name)
    result.use_nodes = True
    nodes, links = result.node_tree.nodes, result.node_tree.links
    bsdf = nodes.get("Principled BSDF")
    bsdf.inputs["Base Color"].default_value = (*color, 1.0)
    bsdf.inputs["Metallic"].default_value = metallic
    bsdf.inputs["Roughness"].default_value = roughness
    base = nodes.new("ShaderNodeTexImage")
    base.image = image(surface)
    normal = nodes.new("ShaderNodeTexImage")
    normal.image = image(surface + "_normal", True)
    normal_map = nodes.new("ShaderNodeNormalMap")
    normal_map.inputs["Strength"].default_value = .72
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
        strength_socket = bsdf.inputs.get("Emission Strength")
        if color_socket:
            color_socket.default_value = (*emission, 1.0)
        if strength_socket:
            strength_socket.default_value = 2.7
    return result


STEEL = pbr("ArchiveInteriorSteel", (.10, .19, .27), .76, .42, "aether_metal")
DARK = pbr("ArchiveInteriorDark", (.028, .048, .072), .70, .30, "aether_metal")
ICE = pbr("ArchiveInteriorIce", (.28, .56, .84), .10, .34, "aether_ice")
HAZARD = pbr("ArchiveInteriorHazard", (.87, .27, .025), .18, .48, "aether_hazard")
CYAN = pbr("ArchiveInteriorCyan", (.025, .52, .96), .30, .18, "aether_metal", (.02, .75, 1.0))
WHITE = pbr("ArchiveInteriorWhite", (.55, .72, .83), .50, .33, "aether_metal", (.25, .75, 1.0))


def collection(name):
    result = bpy.data.collections.new(name)
    bpy.context.scene.collection.children.link(result)
    return result


def add_to(obj, group, parent):
    for current in list(obj.users_collection):
        current.objects.unlink(obj)
    group.objects.link(obj)
    obj.parent = parent
    return obj


def empty(group, name):
    obj = bpy.data.objects.new(name, None)
    group.objects.link(obj)
    return obj


def bevel(obj, width=.025):
    modifier = obj.modifiers.new("ArchiveChamfer", "BEVEL")
    modifier.width = width
    modifier.segments = 2
    modifier.limit_method = "ANGLE"
    bpy.context.view_layer.objects.active = obj
    bpy.ops.object.modifier_apply(modifier=modifier.name)


def box(group, parent, name, dims, pos, material, chamfer=.025, rotation=None):
    bpy.ops.mesh.primitive_cube_add(size=1.0, location=pos)
    obj = bpy.context.object
    obj.name = name
    obj.dimensions = dims
    bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
    if rotation:
        obj.rotation_euler = rotation
    if chamfer:
        bevel(obj, chamfer)
    obj.data.materials.append(material)
    return add_to(obj, group, parent)


def cylinder(group, parent, name, radius, depth, pos, material, rotation=None, vertices=16):
    bpy.ops.mesh.primitive_cylinder_add(vertices=vertices, radius=radius, depth=depth, location=pos)
    obj = bpy.context.object
    obj.name = name
    if rotation:
        obj.rotation_euler = rotation
    bevel(obj, min(.025, radius * .2))
    obj.data.materials.append(material)
    return add_to(obj, group, parent)


def arch_vestibule():
    group = collection("ArchiveVestibule")
    root = empty(group, "ArchiveVestibuleRoot")
    # Fits inside the re-opened Sentinel Archive shell. Front is local -Z.
    box(group, root, "InteriorFloor", (10.5, .14, 5.5), (0, .52, .85), DARK, .035)
    for x in (-3.5, 0.0, 3.5):
        box(group, root, "FloorPlate_" + str(x), (3.10, .045, 5.04), (x, .615, .85), STEEL, .012)
        box(group, root, "FloorChannel_" + str(x), (.075, .025, 4.7), (x + 1.48, .65, .85), CYAN, .004)
    # Interior lining makes the exterior shell visibly read as an occupied room.
    for x in (-5.04, 5.04):
        box(group, root, "SideLiner_" + str(x), (.16, 5.25, 5.05), (x, 3.15, .85), DARK, .012)
        for z in (-1.35, .30, 1.95, 3.00):
            box(group, root, "SideRib_" + str(x) + str(z), (.17, 4.65, .12), (x * .975, 2.95, z), STEEL, .012)
            box(group, root, "SideDiagnostic_" + str(x) + str(z), (.035, .46, .08), (x * .955, 3.85, z), CYAN, .004)
    # A central opening divides a short vestibule from the one objective room.
    box(group, root, "PartitionWest", (2.72, 5.0, .24), (-3.75, 3.08, .22), STEEL, .025)
    box(group, root, "PartitionEast", (2.72, 5.0, .24), (3.75, 3.08, .22), STEEL, .025)
    box(group, root, "PartitionLintel", (4.75, 1.38, .24), (0, 5.02, .22), DARK, .025)
    for x in (-2.48, 2.48):
        box(group, root, "ThresholdPylon_" + str(x), (.22, 4.35, .35), (x, 2.72, .10), ICE, .02)
        box(group, root, "ThresholdLight_" + str(x), (.06, 2.9, .045), (x * .96, 2.72, .005), CYAN, .005)
    # Ceiling beams frame the compact room while leaving it clearly indoors.
    for z in (-1.45, .22, 1.85, 3.28):
        box(group, root, "CeilingBeam_" + str(z), (10.0, .30, .24), (0, 5.73, z), DARK, .025)
        box(group, root, "CeilingStrip_" + str(z), (5.4, .045, .065), (0, 5.53, z), CYAN, .004)
    # Server pylons and console banks are attached to the room's operational role.
    for x in (-3.82, 3.82):
        cylinder(group, root, "ServerPylon_" + str(x), .48, 3.9, (x, 2.53, 2.65), STEEL, None, 16)
        cylinder(group, root, "ServerPylonGlow_" + str(x), .17, 3.3, (x, 2.65, 2.65), CYAN, None, 16)
        for y in (1.15, 2.35, 3.55):
            cylinder(group, root, "ServerRing_" + str(x) + str(y), .61, .08, (x, y, 2.65), DARK, None, 16)
    for x in (-2.65, 2.65):
        box(group, root, "ConsoleBank_" + str(x), (1.48, 1.18, .62), (x, 1.20, 3.0), STEEL, .025, (math.radians(-12), 0, 0))
        box(group, root, "ConsoleScreen_" + str(x), (.92, .52, .04), (x, 1.48, 2.64), WHITE, .008, (math.radians(-12), 0, 0))
    box(group, root, "RearStatusBand", (5.2, .11, .08), (0, 4.58, 3.36), CYAN, .006)
    return group


def archive_computer():
    group = collection("ArchiveComputer")
    root = empty(group, "ArchiveComputerRoot")
    # 2.7m footprint. This is the unique final data source, not a generic crate.
    box(group, root, "ComputerBase", (2.70, .22, 2.20), (0, .11, 0), DARK, .05)
    cylinder(group, root, "ComputerPedestal", .70, .80, (0, .58, 0), STEEL, None, 20)
    cylinder(group, root, "ComputerRingLower", .94, .10, (0, .34, 0), HAZARD, None, 20)
    cylinder(group, root, "ComputerRingUpper", .79, .08, (0, 1.02, 0), CYAN, None, 20)
    for angle in (0, math.pi * .5, math.pi, math.pi * 1.5):
        x, z = math.sin(angle) * .83, math.cos(angle) * .83
        box(group, root, "ComputerFin_" + str(angle), (.14, 1.42, .48), (x, 1.25, z), STEEL, .018, (0, -angle, math.radians(12) * math.cos(angle)))
        cylinder(group, root, "ComputerBolt_" + str(angle), .065, .07, (x * 1.22, .25, z * 1.02), HAZARD, None, 12)
    box(group, root, "ComputerControlDesk", (1.42, .74, .46), (0, 1.08, -1.10), STEEL, .025, (math.radians(-16), 0, 0))
    box(group, root, "ComputerControlScreen", (.94, .34, .04), (0, 1.31, -1.29), WHITE, .008, (math.radians(-16), 0, 0))
    box(group, root, "ComputerCoreCradle", (1.02, .18, 1.02), (0, 1.30, 0), DARK, .03)
    core = cylinder(group, root, "ArchiveDataCore", .31, .78, (0, 1.84, 0), CYAN, None, 20)
    ring = cylinder(group, root, "DataCoreHalo", .64, .065, (0, 2.13, 0), WHITE, None, 20)
    for angle in (0, math.pi / 3, math.pi * 2 / 3, math.pi, math.pi * 4 / 3, math.pi * 5 / 3):
        x, z = math.sin(angle) * .55, math.cos(angle) * .55
        box(group, root, "DataCoreVane_" + str(angle), (.075, .48, .18), (x, 1.90, z), STEEL, .01, (0, -angle, 0))
    # The authored download animation grows and turns the core. The runtime
    # state machine commits only after its timer and durable profile write.
    core.rotation_mode = "XYZ"
    core.keyframe_insert(data_path="location", frame=1)
    core.keyframe_insert(data_path="scale", frame=1)
    core.keyframe_insert(data_path="rotation_euler", frame=1)
    ring.rotation_mode = "XYZ"
    ring.keyframe_insert(data_path="location", frame=1)
    ring.keyframe_insert(data_path="scale", frame=1)
    core.location.y = 2.10
    core.scale = (.72, 1.18, .72)
    core.rotation_euler = (0, math.tau * 2, 0)
    ring.location.y = 2.32
    ring.scale = (1.16, 1.16, 1.16)
    core.keyframe_insert(data_path="location", frame=48)
    core.keyframe_insert(data_path="scale", frame=48)
    core.keyframe_insert(data_path="rotation_euler", frame=48)
    ring.keyframe_insert(data_path="location", frame=48)
    ring.keyframe_insert(data_path="scale", frame=48)
    if core.animation_data and core.animation_data.action:
        core.animation_data.action.name = "ArchiveComputer_Download"
    return group


def export(group, filename):
    bpy.ops.object.select_all(action="DESELECT")
    for obj in group.objects:
        obj.select_set(True)
    bpy.context.view_layer.objects.active = group.objects[0]
    bpy.ops.export_scene.gltf(
        filepath=os.path.join(OUT, filename),
        export_format="GLB",
        use_selection=True,
        export_yup=False,
        export_animations=True,
        export_materials="EXPORT",
    )


bpy.context.scene.render.fps = 30
bpy.context.scene.frame_start = 1
bpy.context.scene.frame_end = 48
vestibule = arch_vestibule()
computer = archive_computer()
bpy.ops.file.pack_all()
bpy.ops.wm.save_as_mainfile(filepath=SOURCE)
export(vestibule, "archive_vestibule.glb")
export(computer, "archive_computer.glb")
print("Built compact Sentinel Archive interior:", OUT)
