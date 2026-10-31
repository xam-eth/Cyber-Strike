"""Author Stellar Horizon's focused structural landmark set in Blender.

The set is intentionally limited to three navigational buildings and one
service/cargo cluster. They address empty deck silhouettes without filling the
level with generic clutter. All maps are the Aetherfall PBR dependencies and
are packed into the GLB exports.
"""
import math
import os
import bpy

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "../.."))
OUT = os.path.join(ROOT, "assets", "world", "aetherfall", "landmarks")
MATERIALS = os.path.join(ROOT, "assets", "world", "aetherfall", "materials")
SOURCE = os.path.join(ROOT, "source", "aetherfall_landmarks.blend")
os.makedirs(OUT, exist_ok=True)
bpy.ops.wm.read_factory_settings(use_empty=True)

_images = {}


def tex(name, non_color=False):
    key = (name, non_color)
    if key in _images:
        return _images[key]
    path = os.path.join(MATERIALS, name + ".png")
    if not os.path.isfile(path):
        raise RuntimeError("Missing PBR map: " + path)
    result = bpy.data.images.load(path)
    result.colorspace_settings.name = "Non-Color" if non_color else "sRGB"
    _images[key] = result
    return result


def material(name, color, metallic, roughness, surface, emission=None):
    result = bpy.data.materials.new(name)
    result.use_nodes = True
    nodes = result.node_tree.nodes
    links = result.node_tree.links
    bsdf = nodes.get("Principled BSDF")
    bsdf.inputs["Base Color"].default_value = (*color, 1.0)
    bsdf.inputs["Metallic"].default_value = metallic
    bsdf.inputs["Roughness"].default_value = roughness
    base = nodes.new("ShaderNodeTexImage")
    base.name = "BaseColor_" + surface
    base.image = tex(surface)
    normal = nodes.new("ShaderNodeTexImage")
    normal.name = "Normal_" + surface
    normal.image = tex(surface + "_normal", True)
    normal_map = nodes.new("ShaderNodeNormalMap")
    normal_map.inputs["Strength"].default_value = 0.72
    orm = nodes.new("ShaderNodeTexImage")
    orm.name = "ORM_" + surface
    orm.image = tex(surface + "_orm", True)
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
            strength_socket.default_value = 2.1
    return result


STEEL = material("LandmarkSteel", (0.16, 0.26, 0.33), 0.72, 0.48, "aether_metal")
DARK = material("LandmarkDark", (0.045, 0.065, 0.085), 0.7, 0.36, "aether_metal")
CONCRETE = material("LandmarkConcrete", (0.34, 0.36, 0.35), 0.08, 0.79, "aether_concrete")
HAZARD = material("LandmarkHazard", (0.92, 0.31, 0.035), 0.16, 0.5, "aether_hazard")
ENERGY = material("LandmarkEnergy", (0.06, 0.55, 0.9), 0.25, 0.22, "aether_metal", (0.04, 0.67, 1.0))


def link(obj, collection):
    for old in list(obj.users_collection):
        old.objects.unlink(obj)
    collection.objects.link(obj)


def root(collection, name):
    obj = bpy.data.objects.new(name, None)
    obj.empty_display_type = "PLAIN_AXES"
    collection.objects.link(obj)
    return obj


def bevel(obj, width=0.035, segments=2):
    modifier = obj.modifiers.new("EdgeChamfer", "BEVEL")
    modifier.width = width
    modifier.segments = segments
    modifier.limit_method = "ANGLE"
    bpy.context.view_layer.objects.active = obj
    bpy.ops.object.modifier_apply(modifier=modifier.name)


def box(collection, name, dims, pos, mat, parent, bevel_width=0.025, rotation=None):
    bpy.ops.mesh.primitive_cube_add(size=1.0, location=pos)
    obj = bpy.context.object
    obj.name = name
    obj.dimensions = dims
    bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
    if rotation:
        obj.rotation_euler = rotation
    if bevel_width:
        bevel(obj, bevel_width)
    obj.data.materials.append(mat)
    obj.parent = parent
    link(obj, collection)
    return obj


def cylinder(collection, name, radius, depth, pos, mat, parent, rotation=None, vertices=16):
    bpy.ops.mesh.primitive_cylinder_add(vertices=vertices, radius=radius, depth=depth, location=pos)
    obj = bpy.context.object
    obj.name = name
    # Blender cylinders are Z-long. These assets export in Godot's authored
    # X/Y/Z basis, so make the long axis Y before applying an authored offset.
    obj.rotation_euler = (math.pi * .5, 0, 0)
    if rotation:
        obj.rotation_euler = (math.pi * .5 + rotation[0], rotation[1], rotation[2])
    bevel(obj, min(radius * 0.18, 0.026), 2)
    obj.data.materials.append(mat)
    obj.parent = parent
    link(obj, collection)
    return obj


def rod(collection, name, radius, length, pos, rotation, mat, parent):
    return cylinder(collection, name, radius, length, pos, mat, parent, rotation, 12)


def new_collection(name):
    collection = bpy.data.collections.new(name)
    bpy.context.scene.collection.children.link(collection)
    return collection


def field_outpost():
    collection = new_collection("FieldOutpost")
    parent = root(collection, "FieldOutpostRoot")
    # 7.2 x 4.6 x 6.7m arrival landmark; its front faces negative Z.
    box(collection, "OutpostFoundation", (7.2, 0.32, 4.6), (0, 0.16, 0), CONCRETE, parent, 0.05)
    box(collection, "OutpostHull", (6.82, 3.20, 4.16), (0, 1.91, 0), STEEL, parent, 0.045)
    box(collection, "OutpostRoof", (7.12, 0.28, 4.46), (0, 3.65, 0), DARK, parent, 0.05)
    # Front-door composition: panels, recessed vestibule and illuminated access strip.
    box(collection, "OutpostDoorRecess", (1.82, 2.42, 0.09), (0, 1.53, -2.13), DARK, parent, 0.012)
    for x in (-1.18, 1.18):
        box(collection, "OutpostDoorJamb_" + str(x), (0.15, 2.72, 0.15), (x, 1.57, -2.24), HAZARD, parent, 0.012)
    box(collection, "OutpostAccessLight", (1.55, 0.08, 0.06), (0, 2.82, -2.25), ENERGY, parent, 0.008)
    # Side window bands, strakes and corner armour create readable construction layers.
    for x in (-3.46, 3.46):
        box(collection, "OutpostCorner_" + str(x), (0.18, 3.5, 0.22), (x, 1.93, -1.88), DARK, parent, 0.018)
        for z in (-1.18, 0.08, 1.28):
            box(collection, "OutpostSideWindow_" + str(x) + str(z), (0.055, 0.55, 0.86), (x * 0.985, 2.18, z), ENERGY, parent, 0.008)
    for x in (-2.45, -1.7, 1.7, 2.45):
        box(collection, "OutpostFacadeRib_" + str(x), (0.12, 2.82, 0.12), (x, 1.97, -2.16), DARK, parent, 0.015)
    # Rooftop climate equipment and a small comms mast give a non-box silhouette.
    box(collection, "OutpostHVAC", (1.72, 0.62, 1.18), (-1.56, 4.08, 0.42), CONCRETE, parent, 0.04)
    for i in range(4):
        z = -0.30 + i * 0.20
        box(collection, "OutpostHVACLouver_" + str(i), (1.20, 0.10, 0.055), (-1.56, 4.10, z), DARK, parent, 0.004)
    cylinder(collection, "OutpostMast", 0.08, 2.45, (2.12, 4.88, 0.60), DARK, parent, None, 12)
    cylinder(collection, "OutpostBeacon", 0.18, 0.34, (2.12, 6.26, 0.60), ENERGY, parent, None, 16)
    for angle in (-0.32, 0.32):
        box(collection, "OutpostSolarPanel_" + str(angle), (1.50, 0.06, 0.82), (1.18 if angle < 0 else 2.76, 3.95, 0.55), DARK, parent, 0.01, (angle, 0, 0))
    return collection


def relay_annex():
    collection = new_collection("RelayAnnex")
    parent = root(collection, "RelayAnnexRoot")
    # 4.8 x 4.8 x 8.2m vertical relay support; related to the objective device.
    box(collection, "RelayAnnexFoundation", (4.80, 0.30, 4.80), (0, 0.15, 0), CONCRETE, parent, 0.05)
    box(collection, "RelayAnnexCore", (3.56, 5.70, 3.56), (0, 3.15, 0), STEEL, parent, 0.045)
    box(collection, "RelayAnnexCrown", (4.22, 0.32, 4.22), (0, 6.14, 0), DARK, parent, 0.04)
    for x in (-1.92, 1.92):
        for z in (-1.92, 1.92):
            box(collection, "RelayButtress_" + str(x) + str(z), (0.38, 5.95, 0.38), (x, 3.06, z), DARK, parent, 0.025)
    for level in (1.3, 2.55, 3.80, 5.05):
        box(collection, "RelayBand_" + str(level), (3.95, 0.14, 3.95), (0, level, 0), HAZARD, parent, 0.014)
    # Front status panel and ladder make the building legible in third-person view.
    box(collection, "RelayStatusPanel", (1.28, 1.82, 0.08), (0, 3.30, -1.83), DARK, parent, 0.015)
    for y in (2.82, 3.31, 3.80):
        box(collection, "RelayStatusStrip_" + str(y), (0.86, 0.10, 0.04), (0, y, -1.89), ENERGY, parent, 0.006)
    for y in (0.9, 1.45, 2.0, 2.55, 3.10, 3.65, 4.20):
        box(collection, "RelayLadderRung_" + str(y), (0.68, 0.07, 0.06), (1.84, y, -0.8), HAZARD, parent, 0.006)
    for x in (1.57, 2.10):
        rod(collection, "RelayLadderRail_" + str(x), 0.035, 4.15, (x, 2.62, -0.8), (0, 0, 0), DARK, parent)
    cylinder(collection, "RelayMast", 0.12, 2.15, (0, 7.35, 0), DARK, parent, None, 16)
    cylinder(collection, "RelayEmitter", 0.31, 0.50, (0, 8.55, 0), ENERGY, parent, None, 20)
    # Four receiver vanes frame the mast instead of another rectangular roof box.
    for angle in (0, math.pi * .5, math.pi, math.pi * 1.5):
        x, z = math.sin(angle) * 1.22, math.cos(angle) * 1.22
        box(collection, "RelayVane_" + str(angle), (0.14, 1.20, 0.88), (x, 7.1, z), STEEL, parent, 0.018, (0, -angle, 0))
    return collection


def service_hangar():
    collection = new_collection("ServiceHangar")
    parent = root(collection, "ServiceHangarRoot")
    # 10.8 x 5.6 x 6.1m service bay with an open readable entry at negative Z.
    box(collection, "HangarFoundation", (10.8, 0.34, 5.6), (0, 0.17, 0), CONCRETE, parent, 0.05)
    box(collection, "HangarRearWall", (10.18, 3.62, 0.30), (0, 2.0, 2.45), STEEL, parent, 0.035)
    box(collection, "HangarRoof", (10.75, 0.32, 5.45), (0, 4.10, 0), DARK, parent, 0.05)
    for x in (-4.85, -2.45, 2.45, 4.85):
        box(collection, "HangarPost_" + str(x), (0.36, 3.85, 0.36), (x, 2.0, -2.35), STEEL, parent, 0.025)
        box(collection, "HangarWarning_" + str(x), (0.41, 0.72, 0.09), (x, 1.18, -2.57), HAZARD, parent, 0.008)
    for x in (-3.65, -1.22, 1.22, 3.65):
        box(collection, "HangarRoofTruss_" + str(x), (0.18, 0.28, 5.08), (x, 3.83, 0), STEEL, parent, 0.018)
    # Deep rear service modules stop the hangar from reading as an empty wall.
    for x in (-3.9, -1.3, 1.3, 3.9):
        box(collection, "HangarServiceBay_" + str(x), (1.72, 2.12, 0.36), (x, 1.60, 2.20), DARK, parent, 0.022)
        box(collection, "HangarBayLight_" + str(x), (1.20, 0.10, 0.045), (x, 2.55, 1.99), ENERGY, parent, 0.007)
    box(collection, "HangarOverheadRail", (9.4, 0.18, 0.16), (0, 3.40, -0.35), HAZARD, parent, 0.015)
    for x in (-4.0, -1.35, 1.35, 4.0):
        cylinder(collection, "HangarRoofVent_" + str(x), 0.28, 0.70, (x, 4.58, 1.15), CONCRETE, parent, None, 16)
        cylinder(collection, "HangarVentCap_" + str(x), 0.40, 0.10, (x, 4.96, 1.15), DARK, parent, None, 16)
    return collection


def cargo_cluster():
    collection = new_collection("CargoServiceCluster")
    parent = root(collection, "CargoServiceClusterRoot")
    # 3.8 x 3.2m setpiece: cover, delivery story and a small visual-density tool.
    box(collection, "CargoPallet", (3.70, 0.16, 2.80), (0, 0.08, 0), DARK, parent, 0.02)
    box(collection, "CargoCrateLarge", (1.58, 1.35, 1.30), (-0.75, 0.84, 0.18), STEEL, parent, 0.035)
    box(collection, "CargoCrateTop", (1.12, 0.82, 0.96), (-0.88, 1.92, 0.20), HAZARD, parent, 0.03)
    box(collection, "CargoCrateSmall", (0.95, 0.74, 1.12), (1.10, 0.53, -0.45), CONCRETE, parent, 0.028)
    for x in (-1.42, -0.15, 0.56):
        box(collection, "CargoStrap_" + str(x), (0.055, 1.42, 1.38), (x, 0.85, 0.18), DARK, parent, 0.004)
    for x in (1.32, 1.62):
        cylinder(collection, "CargoDrum_" + str(x), 0.29, 1.05, (x, 0.525, 0.76), HAZARD, parent, None, 16)
        cylinder(collection, "CargoDrumCap_" + str(x), 0.23, 0.04, (x, 1.07, 0.76), DARK, parent, None, 16)
    box(collection, "CargoScannerCase", (0.72, 0.33, 0.52), (0.86, 1.08, -0.45), DARK, parent, 0.018)
    box(collection, "CargoScannerLight", (0.42, 0.06, 0.035), (0.86, 1.27, -0.72), ENERGY, parent, 0.005)
    return collection


def export(collection, filename):
    bpy.ops.object.select_all(action="DESELECT")
    for obj in collection.objects:
        obj.select_set(True)
    bpy.context.view_layer.objects.active = collection.objects[0]
    bpy.ops.export_scene.gltf(
        filepath=os.path.join(OUT, filename),
        export_format="GLB",
        use_selection=True,
        export_materials="EXPORT",
        export_yup=False,
    )


collections = [
    (field_outpost(), "field_outpost.glb"),
    (relay_annex(), "relay_annex.glb"),
    (service_hangar(), "service_hangar.glb"),
    (cargo_cluster(), "cargo_service_cluster.glb"),
]
bpy.ops.file.pack_all()
bpy.ops.wm.save_as_mainfile(filepath=SOURCE)
for collection, filename in collections:
    export(collection, filename)
print("Built focused structural landmark set in", OUT)
