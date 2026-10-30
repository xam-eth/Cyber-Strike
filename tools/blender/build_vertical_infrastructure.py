"""Build connected multi-level industrial infrastructure for Aetherfall.

These are structural setpieces, not scatter props: refinery stacks provide
vertical mass, the overhead gantry frames the central combat/readability space,
and the raised operations deck introduces a second navigational silhouette.
"""
import math
import os
import bpy

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "../.."))
OUT = os.path.join(ROOT, "assets", "world", "aetherfall", "vertical")
MAPS = os.path.join(ROOT, "assets", "world", "aetherfall", "materials")
SOURCE = os.path.join(ROOT, "source", "aetherfall_vertical_infrastructure.blend")
os.makedirs(OUT, exist_ok=True)
bpy.ops.wm.read_factory_settings(use_empty=True)
images = {}


def image(name, linear=False):
    key = (name, linear)
    if key not in images:
        item = bpy.data.images.load(os.path.join(MAPS, name + ".png"))
        item.colorspace_settings.name = "Non-Color" if linear else "sRGB"
        images[key] = item
    return images[key]


def pbr(name, color, metal, rough, surface, emit=None):
    item = bpy.data.materials.new(name)
    item.use_nodes = True
    nodes, links = item.node_tree.nodes, item.node_tree.links
    bsdf = nodes.get("Principled BSDF")
    bsdf.inputs["Base Color"].default_value = (*color, 1.0)
    bsdf.inputs["Metallic"].default_value = metal
    bsdf.inputs["Roughness"].default_value = rough
    base = nodes.new("ShaderNodeTexImage")
    base.image = image(surface)
    normal = nodes.new("ShaderNodeTexImage")
    normal.image = image(surface + "_normal", True)
    normal_map = nodes.new("ShaderNodeNormalMap")
    normal_map.inputs["Strength"].default_value = 0.72
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
    if emit:
        color_socket = bsdf.inputs.get("Emission Color") or bsdf.inputs.get("Emission")
        if color_socket:
            color_socket.default_value = (*emit, 1.0)
        strength = bsdf.inputs.get("Emission Strength")
        if strength:
            strength.default_value = 2.3
    return item


STEEL = pbr("VerticalSteel", (0.14, 0.24, 0.30), 0.75, 0.47, "aether_metal")
DARK = pbr("VerticalDark", (0.035, 0.055, 0.075), 0.7, 0.34, "aether_metal")
CONCRETE = pbr("VerticalConcrete", (0.34, 0.36, 0.36), 0.06, 0.80, "aether_concrete")
HAZARD = pbr("VerticalHazard", (0.88, 0.29, 0.025), 0.18, 0.48, "aether_hazard")
CYAN = pbr("VerticalCyan", (0.05, 0.56, 0.92), 0.24, 0.20, "aether_metal", (0.03, 0.74, 1.0))


def collection(name):
    item = bpy.data.collections.new(name)
    bpy.context.scene.collection.children.link(item)
    return item


def parent_root(col, name):
    item = bpy.data.objects.new(name, None)
    col.objects.link(item)
    return item


def link(obj, col, parent):
    for old in list(obj.users_collection):
        old.objects.unlink(obj)
    col.objects.link(obj)
    obj.parent = parent
    return obj


def bevel(obj, width=0.03):
    modifier = obj.modifiers.new("ConstructionBevel", "BEVEL")
    modifier.width = width
    modifier.segments = 2
    modifier.limit_method = "ANGLE"
    bpy.context.view_layer.objects.active = obj
    bpy.ops.object.modifier_apply(modifier=modifier.name)


def box(col, parent, name, dims, pos, mat, bevel_size=0.025, rot=None):
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
    return link(obj, col, parent)


def cylinder(col, parent, name, radius, depth, pos, mat, rot=None, sides=16):
    bpy.ops.mesh.primitive_cylinder_add(vertices=sides, radius=radius, depth=depth, location=pos)
    obj = bpy.context.object
    obj.name = name
    if rot:
        obj.rotation_euler = rot
    bevel(obj, min(0.025, radius * 0.18))
    obj.data.materials.append(mat)
    return link(obj, col, parent)


def refinery_stack():
    col = collection("RefineryStack")
    root = parent_root(col, "RefineryStackRoot")
    # 9m x 6m x 13m: three-tier refinery/receiver block.
    box(col, root, "Foundation", (9.0, 0.40, 6.0), (0, .2, 0), CONCRETE, .06)
    box(col, root, "MainCore", (5.9, 9.6, 3.7), (0, 5.0, .25), STEEL, .05)
    for level in (1.1, 3.2, 5.3, 7.4, 9.5):
        box(col, root, "ServiceBand_" + str(level), (6.45, .16, 4.15), (0, level, .25), HAZARD, .012)
    for x in (-3.95, 3.95):
        box(col, root, "CornerFrame_" + str(x), (.42, 10.6, .42), (x, 5.3, -2.45), DARK, .03)
        cylinder(col, root, "ProcessTank_" + str(x), .84, 7.5, (x * .79, 4.1, 1.68), CONCRETE, None, 20)
        cylinder(col, root, "TankCap_" + str(x), 1.02, .16, (x * .79, 7.92, 1.68), DARK, None, 20)
    # Vertical pipe runs and cross connections produce industrial depth.
    for x in (-2.25, -1.55, 1.55, 2.25):
        cylinder(col, root, "PipeRise_" + str(x), .16, 10.8, (x, 5.65, -1.78), DARK, None, 12)
        for y in (2.0, 5.1, 8.2):
            cylinder(col, root, "PipeCollar_" + str(x) + str(y), .25, .13, (x, y, -1.78), HAZARD, None, 12)
    for y in (2.2, 5.0, 7.8):
        cylinder(col, root, "CrossPipe_" + str(y), .19, 5.6, (0, y, -1.55), STEEL, (0, math.pi * .5, 0), 12)
    # Stacked front control faces, lamps and an exterior ladder.
    for y in (2.0, 4.55, 7.1):
        box(col, root, "ControlFace_" + str(y), (2.4, 1.55, .12), (0, y, -1.68), DARK, .014)
        box(col, root, "ControlLight_" + str(y), (1.55, .10, .045), (0, y + .4, -1.77), CYAN, .005)
    for y in (.9, 1.55, 2.2, 2.85, 3.5, 4.15, 4.8, 5.45, 6.1, 6.75, 7.4):
        box(col, root, "LadderRung_" + str(y), (.8, .07, .06), (3.88, y, -.72), HAZARD, .005)
    for x in (3.55, 4.20):
        cylinder(col, root, "LadderRail_" + str(x), .04, 7.5, (x, 4.2, -.72), DARK, None, 12)
    box(col, root, "RoofDeck", (7.2, .28, 4.8), (0, 10.0, .2), DARK, .04)
    for x in (-2.5, 0, 2.5):
        cylinder(col, root, "RoofVent_" + str(x), .36, 1.1, (x, 10.7, .8), CONCRETE, None, 16)
    cylinder(col, root, "SignalMast", .13, 2.55, (0, 11.5, -.3), DARK, None, 16)
    cylinder(col, root, "SignalBeacon", .29, .48, (0, 13.0, -.3), CYAN, None, 20)
    return col


def overhead_gantry():
    col = collection("OverheadGantry")
    root = parent_root(col, "OverheadGantryRoot")
    # 24m-wide overhead service bridge, deck at y=7m and open visual underneath.
    for x in (-10.9, 10.9):
        box(col, root, "GantryFoot_" + str(x), (2.0, .35, 3.8), (x, .18, 0), CONCRETE, .045)
        for z in (-1.25, 1.25):
            box(col, root, "GantryColumn_" + str(x) + str(z), (.38, 6.75, .38), (x, 3.55, z), STEEL, .025)
        box(col, root, "GantryTowerCap_" + str(x), (2.1, .34, 3.2), (x, 6.85, 0), DARK, .035)
    box(col, root, "BridgeDeck", (23.1, .34, 2.9), (0, 7.0, 0), STEEL, .045)
    for x in (-8.5, -5.7, -2.9, 0, 2.9, 5.7, 8.5):
        box(col, root, "BridgeRib_" + str(x), (.19, .45, 3.5), (x, 6.84, 0), DARK, .016)
        box(col, root, "BridgeLight_" + str(x), (.64, .055, .1), (x, 6.74, -1.34), CYAN, .005)
    for z in (-1.3, 1.3):
        box(col, root, "BridgeRail_" + str(z), (22.6, .65, .1), (0, 7.45, z), DARK, .012)
    # Four pipe lines over the deck break the long horizontal plane.
    for z in (-.85, -.28, .28, .85):
        cylinder(col, root, "OverheadPipe_" + str(z), .17, 21.8, (0, 7.72, z), CONCRETE if z < 0 else STEEL, (0, math.pi * .5, 0), 12)
    for x in (-8, -4, 0, 4, 8):
        box(col, root, "PipeBrace_" + str(x), (.12, .8, 2.35), (x, 7.55, 0), HAZARD, .01)
    # Diagonal braces are visible from QA overview and prevent a flat silhouette.
    for x, sign in [(-10.2, 1), (10.2, -1)]:
        box(col, root, "DiagonalBrace_" + str(x), (.22, 7.0, .22), (x, 3.6, 0), DARK, .015, (0, 0, sign * .55))
    return col


def raised_ops_deck():
    col = collection("RaisedOpsDeck")
    root = parent_root(col, "RaisedOpsDeckRoot")
    # 10 x 6m deck at 5m; visual second level with tanks and guarded perimeter.
    for x in (-4.2, 4.2):
        for z in (-2.25, 2.25):
            box(col, root, "OpsLeg_" + str(x) + str(z), (.48, 4.9, .48), (x, 2.45, z), STEEL, .025)
    box(col, root, "OpsDeck", (10.0, .36, 6.0), (0, 5.0, 0), DARK, .045)
    for x in (-4.45, 4.45):
        box(col, root, "OpsRailX_" + str(x), (.1, .72, 5.8), (x, 5.5, 0), HAZARD, .01)
    for z in (-2.65, 2.65):
        box(col, root, "OpsRailZ_" + str(z), (9.0, .72, .1), (0, 5.5, z), HAZARD, .01)
    for x in (-2.7, 0, 2.7):
        cylinder(col, root, "OpsTank_" + str(x), .68, 1.75, (x, 6.05, .65), CONCRETE, None, 20)
        cylinder(col, root, "OpsTankGlow_" + str(x), .28, .08, (x, 6.98, .65), CYAN, None, 16)
    box(col, root, "OpsConsole", (2.6, 1.4, .72), (0, 5.9, -1.65), STEEL, .03)
    box(col, root, "OpsConsoleStrip", (1.6, .12, .05), (0, 6.2, -2.05), CYAN, .006)
    # Visible stair mass toward the lower level; steps are individual geometry.
    for i in range(8):
        box(col, root, "OpsStep_" + str(i), (2.2, .30, .66), (0, .3 + i * .59, -3.0 - i * .38), DARK, .015)
    return col


def export(col, filename):
    bpy.ops.object.select_all(action="DESELECT")
    for obj in col.objects:
        obj.select_set(True)
    bpy.context.view_layer.objects.active = col.objects[0]
    bpy.ops.export_scene.gltf(filepath=os.path.join(OUT, filename), export_format="GLB", use_selection=True, export_materials="EXPORT")


sets = [(refinery_stack(), "refinery_stack.glb"), (overhead_gantry(), "overhead_gantry.glb"), (raised_ops_deck(), "raised_ops_deck.glb")]
bpy.ops.file.pack_all()
bpy.ops.wm.save_as_mainfile(filepath=SOURCE)
for col, filename in sets:
    export(col, filename)
print("Built vertical infrastructure in", OUT)
