#!/usr/bin/env python3
"""Gate 04 high-poly authoring for Aetherfall.

Reads the approved Gate 03 Blender source and adds separately named HP_
collections.  These are bake-source details only: no GLB is exported here and
no procedural texture is used in place of physical form.
"""
from __future__ import annotations

import math
import os
import bpy
from mathutils import Vector

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "../.."))
IN_BLEND = os.path.join(ROOT, "source", "aetherfall_base_mesh.blend")
OUT_BLEND = os.path.join(ROOT, "source", "aetherfall_high_poly.blend")


def material(name, color, metallic=0.0, roughness=0.45):
    mat = bpy.data.materials.get(name) or bpy.data.materials.new(name)
    mat.diffuse_color = color
    mat.use_nodes = True
    bsdf = mat.node_tree.nodes.get("Principled BSDF")
    bsdf.inputs["Base Color"].default_value = color
    bsdf.inputs["Metallic"].default_value = metallic
    bsdf.inputs["Roughness"].default_value = roughness
    return mat


PAINT = None
METAL = None
ICE = None
DARK = None
ENERGY = None


def ensure_collection(name):
    coll = bpy.data.collections.get(name)
    if coll is None:
        coll = bpy.data.collections.new(name)
        bpy.context.scene.collection.children.link(coll)
    return coll


def delete_collection(name):
    coll = bpy.data.collections.get(name)
    if coll is None:
        return
    for obj in list(coll.objects):
        bpy.data.objects.remove(obj, do_unlink=True)
    bpy.data.collections.remove(coll)


def mesh_object(coll, name, verts, faces, mat, role, bevel=0.0, segments=2):
    mesh = bpy.data.meshes.new(name)
    mesh.from_pydata(verts, [], faces)
    mesh.materials.append(mat)
    mesh.update()
    obj = bpy.data.objects.new(name, mesh)
    obj["aetherfall_stage"] = "high_poly"
    obj["aetherfall_role"] = role
    obj["aetherfall_bake_source"] = True
    coll.objects.link(obj)
    if bevel:
        modifier = obj.modifiers.new("HP_EdgeRadius", "BEVEL")
        modifier.width = bevel
        modifier.segments = segments
        modifier.limit_method = "ANGLE"
    return obj


def prism_z(coll, name, outline, z0, z1, mat, role, bevel=0.0):
    """Closed, non-rectangular X/Y profile extruded in Z."""
    n = len(outline)
    verts = [(x, y, z0) for x, y in outline] + [(x, y, z1) for x, y in outline]
    faces = [tuple(range(n - 1, -1, -1)), tuple(range(n, n * 2))]
    faces += [(i, (i + 1) % n, n + (i + 1) % n, n + i) for i in range(n)]
    return mesh_object(coll, name, verts, faces, mat, role, bevel)


def facade_plate(coll, name, outline_xz, y_front, depth, mat, role, bevel=0.05):
    """A custom facade plate extruded toward the camera-facing archive front."""
    n = len(outline_xz)
    verts = [(x, y_front, z) for x, z in outline_xz] + [(x, y_front - depth, z) for x, z in outline_xz]
    faces = [tuple(range(n - 1, -1, -1)), tuple(range(n, n * 2))]
    faces += [(i, (i + 1) % n, n + (i + 1) % n, n + i) for i in range(n)]
    return mesh_object(coll, name, verts, faces, mat, role, bevel)


def hex_bolt(coll, name, center, radius, height, mat, role="hex_fastener"):
    x, y, z = center
    outline = []
    for index in range(6):
        angle = math.tau * index / 6 + math.pi / 6
        outline.append((x + math.cos(angle) * radius, y + math.sin(angle) * radius))
    return prism_z(coll, name, outline, z, z + height, mat, role, min(radius * 0.16, 0.025))


def curve_path(coll, name, points, radius, mat, role, resolution=3):
    """Physical tube/cable path. Curves stay editable in the HP source."""
    curve = bpy.data.curves.new(name, "CURVE")
    curve.dimensions = "3D"
    curve.resolution_u = resolution
    curve.bevel_depth = radius
    curve.bevel_resolution = 3
    spline = curve.splines.new("BEZIER")
    spline.bezier_points.add(len(points) - 1)
    for point, co in zip(spline.bezier_points, points):
        point.co = co
        point.handle_left_type = "AUTO"
        point.handle_right_type = "AUTO"
    curve.materials.append(mat)
    obj = bpy.data.objects.new(name, curve)
    obj["aetherfall_stage"] = "high_poly"
    obj["aetherfall_role"] = role
    obj["aetherfall_bake_source"] = True
    coll.objects.link(obj)
    return obj


def archive_hp(coll):
    """Layered facade, real threshold hardware, ribs, vent bays and routing."""
    # Deeply nested threshold: angled jamb armor, two articulated doors and a
    # raised sill. These are physical volumes rather than a decal on the shell.
    facade_plate(coll, "HP_Archive_GateSill", [(-3.4, 0.95), (-2.4, 0.55), (2.5, 0.55), (3.4, 0.95), (2.8, 1.35), (-2.8, 1.35)], 10.18, 0.38, METAL, "threshold_sill", 0.08)
    facade_plate(coll, "HP_Archive_Door_L", [(-2.45, 1.35), (-0.20, 1.35), (-0.38, 9.55), (-1.15, 10.38), (-2.42, 9.76)], 10.10, 0.26, PAINT, "articulated_gate_leaf", 0.08)
    facade_plate(coll, "HP_Archive_Door_R", [(0.20, 1.35), (2.45, 1.35), (2.42, 9.76), (1.15, 10.38), (0.38, 9.55)], 10.10, 0.26, PAINT, "articulated_gate_leaf", 0.08)
    facade_plate(coll, "HP_Archive_GateLintel", [(-3.85, 10.25), (-2.90, 11.60), (0.0, 12.10), (2.90, 11.60), (3.85, 10.25), (3.25, 9.65), (-3.25, 9.65)], 10.17, 0.42, METAL, "gate_lintel", 0.07)
    # Door seam and locking spines create readable engineered hierarchy.
    for side in (-1, 1):
        x = side * 1.28
        curve_path(coll, "HP_Archive_DoorSpine_%s" % ("L" if side < 0 else "R"), [(x, 10.42, 1.75), (x * 1.08, 10.48, 5.2), (x * 0.92, 10.39, 8.9)], 0.075, METAL, "door_locking_spine")
        for z in (2.1, 4.8, 7.5):
            hex_bolt(coll, "HP_Archive_GateBolt_%s_%s" % (side, int(z * 10)), (side * 2.12, 10.44, z), 0.15, 0.11, METAL)
    # Segmented armor plates follow the front arc of the central shell; each
    # has an asymmetric outline so it remains a designed panel, not a tile.
    panel_data = [
        (-6.2, 7.2, 2.6, 7.0), (-4.7, 8.1, 11.4, 17.4), (-2.9, 8.65, 17.1, 22.0),
        (2.9, 8.65, 17.1, 22.0), (4.7, 8.1, 11.4, 17.4), (6.2, 7.2, 2.6, 7.0),
    ]
    for index, (x, y, low, high) in enumerate(panel_data):
        sign = -1 if x < 0 else 1
        outline = [(x - sign * 0.62, low + 0.20), (x + sign * 0.72, low), (x + sign * 0.52, high - 0.35), (x, high), (x - sign * 0.42, high - 0.8)]
        facade_plate(coll, "HP_Archive_ArmorPanel_%02d" % index, outline, y + 0.18, 0.22, PAINT, "facade_armor_plate", 0.055)
        curve_path(coll, "HP_Archive_PanelSeam_%02d" % index, [(x - sign * 0.45, y + 0.43, low + 0.55), (x, y + 0.48, (low + high) * 0.5), (x + sign * 0.28, y + 0.40, high - 0.55)], 0.026, DARK, "panel_seam")
    # Four vertical structural ribs physically bridge the plinth, shell, and
    # crown; their offset cable raceways give the landmark a maintenance story.
    for index, x in enumerate((-7.7, -4.0, 4.0, 7.7)):
        front_y = 6.0 if abs(x) > 6 else 8.0
        curve_path(coll, "HP_Archive_LoadRib_%02d" % index, [(x, front_y, 1.1), (x * 1.04, front_y + 0.55, 10.0), (x * 0.72, front_y - 0.4, 19.5), (x * 0.30, front_y - 1.3, 25.2)], 0.19, METAL, "structural_load_rib")
        curve_path(coll, "HP_Archive_ServiceConduit_%02d" % index, [(x + (0.32 if x < 0 else -0.32), front_y + 0.28, 2.1), (x, front_y + 0.6, 9.5), (x * 0.76, front_y - 0.1, 16.4)], 0.075, DARK, "service_conduit")
    # Wing vent bays: frame, louver blades, and retained fasteners.
    for side in (-1, 1):
        x0 = side * 10.4
        for row in range(5):
            z = 3.2 + row * 1.15
            facade_plate(coll, "HP_Archive_VentBlade_%s_%02d" % ("L" if side < 0 else "R", row), [(x0 - side * 1.15, z), (x0 + side * 1.15, z + 0.18), (x0 + side * 0.98, z + 0.48), (x0 - side * 0.98, z + 0.30)], 5.55, 0.22, METAL, "cooling_louver", 0.025)
        for z in (2.7, 8.9):
            hex_bolt(coll, "HP_Archive_VentBolt_%s_%s" % (side, int(z * 10)), (x0, 5.82, z), 0.12, 0.08, METAL)
    # Crown collar, radial equipment sockets and a reserved emissive core cage.
    curve_path(coll, "HP_Archive_CrownCollar", [(-4.3, 0.0, 22.2), (-2.2, 3.8, 23.4), (0, 4.7, 24.0), (2.2, 3.8, 23.4), (4.3, 0.0, 22.2)], 0.17, METAL, "crown_collar")
    for i, angle in enumerate(range(0, 360, 45)):
        radians = math.radians(angle)
        x, y = math.cos(radians) * 2.0, math.sin(radians) * 2.0
        hex_bolt(coll, "HP_Archive_CrownSocket_%02d" % i, (x, y, 25.35), 0.23, 0.16, METAL, "crown_socket")
    for z in (2.3, 3.7, 5.1):
        curve_path(coll, "HP_Archive_CoreCage_%02d" % int(z * 10), [(-1.55, 7.7, z), (-0.78, 8.7, z + 0.22), (0.78, 8.7, z + 0.22), (1.55, 7.7, z)], 0.11, ENERGY, "objective_core_cage")


def traversal_hp(coll):
    """Continuous walkable engineering: grating, joints, brackets and bundles."""
    # Physical grate bars sit above the deck; their different pitch from the
    # support frames makes the walking surface legible at close camera range.
    for index, y in enumerate([round(-6.25 + step * 0.48, 2) for step in range(27)]):
        outline = [(-2.42, y - 0.055), (2.42, y - 0.035), (2.28, y + 0.095), (-2.35, y + 0.075)]
        prism_z(coll, "HP_Traversal_Grate_%02d" % index, outline, 0.74, 0.84, METAL, "deck_grate", 0.018)
    for side in (-1.78, 1.78):
        curve_path(coll, "HP_Traversal_DeckChannel_%s" % ("L" if side < 0 else "R"), [(side, -6.45, 0.88), (side * 1.02, 0.0, 0.89), (side, 6.45, 0.88)], 0.072, DARK, "deck_drain_channel")
    # Expansion joints, side brackets and structural bolts are modeled so they
    # can later produce real curvature/AO information during the bake.
    for joint, y in enumerate((-5.4, -2.7, 0.0, 2.7, 5.4)):
        prism_z(coll, "HP_Traversal_ExpansionJoint_%02d" % joint, [(-2.48, y - 0.08), (2.48, y - 0.08), (2.48, y + 0.08), (-2.48, y + 0.08)], 0.77, 0.91, DARK, "deck_expansion_joint", 0.02)
        for x in (-2.22, 2.22):
            hex_bolt(coll, "HP_Traversal_JointBolt_%02d_%s" % (joint, "L" if x < 0 else "R"), (x, y, 0.91), 0.105, 0.07, METAL)
    for index, y in enumerate((-5.6, -2.8, 0.0, 2.8, 5.6)):
        for side in (-1, 1):
            x = side * 2.68
            bracket_outline = [(x, y - 0.18), (x + side * 0.28, y - 0.12), (x + side * 0.28, y + 0.12), (x, y + 0.18)]
            prism_z(coll, "HP_Traversal_RailBracket_%02d_%s" % (index, "L" if side < 0 else "R"), bracket_outline, 0.75, 1.18, METAL, "rail_mount_bracket", 0.025)
            hex_bolt(coll, "HP_Traversal_RailBolt_%02d_%s" % (index, "L" if side < 0 else "R"), (x, y, 1.19), 0.095, 0.065, METAL)
        # Under-deck cable bundles connect each structural bay.
        curve_path(coll, "HP_Traversal_CableA_%02d" % index, [(-1.9, y, 0.25), (-0.85, y + 0.32, -1.25), (0.0, y, -1.82), (0.85, y - 0.32, -1.25), (1.9, y, 0.25)], 0.06, DARK, "underdeck_cable_bundle")
        curve_path(coll, "HP_Traversal_CableB_%02d" % index, [(-1.55, y, 0.18), (-0.55, y - 0.22, -1.38), (0.55, y + 0.22, -1.38), (1.55, y, 0.18)], 0.045, METAL, "underdeck_cable_bundle")
    # Service tray has panel lids and access latches rather than a blank strip.
    for index, y in enumerate((-5.2, -2.6, 0.0, 2.6, 5.2)):
        # A service lid is horizontal and follows the tray; it is not a facade decal.
        prism_z(coll, "HP_Traversal_TrayLid_%02d" % index, [(-0.42, y - 0.86), (0.42, y - 0.86), (0.34, y + 0.86), (-0.34, y + 0.86)], 0.86, 0.95, PAINT, "service_tray_lid", 0.025)
        hex_bolt(coll, "HP_Traversal_TrayLatch_%02d" % index, (0.0, y + 0.24, 0.96), 0.09, 0.065, METAL, "service_latch")


def terrain_height(x, y):
    # Same deliberate primary mass function used in the base source, evaluated
    # in Blender coordinates (source Z points toward Blender -Y).
    source_z = -y
    return 4.0 + math.sin(x * 0.21) * 1.3 + math.cos(source_z * 0.18) * 1.1 + math.sin((x + source_z) * 0.38) * 0.55


def terrain_hp(coll):
    """Fracture systems, strata lips, undercuts and ice-anchor damage volumes."""
    # Long split crevasses are actual recessed geometry: a dark lower wedge plus
    # paired icy lips, arranged to direct the eye through the recovery route.
    crevasses = [
        [(-15, -7), (-10, -5), (-5, -5.5), (0, -4.2), (5, -3.5)],
        [(-9, 4), (-5, 3.2), (-1, 4.0), (3, 5.2), (8, 4.4), (13, 5.6)],
        [(-14, 9), (-10, 7.9), (-6, 8.5), (-2, 7.2)],
    ]
    for index, line in enumerate(crevasses):
        low = [(x, y, terrain_height(x, y) + 0.015) for x, y in line]
        curve_path(coll, "HP_Recovery_Crevasse_%02d" % index, low, 0.115, DARK, "split_crevasse")
        offset = 0.20
        left = [(x - offset, y + offset, terrain_height(x - offset, y + offset) + 0.08) for x, y in line]
        right = [(x + offset, y - offset, terrain_height(x + offset, y - offset) + 0.08) for x, y in line]
        curve_path(coll, "HP_Recovery_CrevasseLipL_%02d" % index, left, 0.065, ICE, "fracture_lip")
        curve_path(coll, "HP_Recovery_CrevasseLipR_%02d" % index, right, 0.065, ICE, "fracture_lip")
    # Stratified ledge lips in the lower wall. Custom irregular profiles avoid
    # reading as repeated shelves when the terrain is viewed from the route.
    strata = [
        [(-18, -10), (-13, -9.4), (-8, -9.8), (-4, -9.1), (1, -9.6)],
        [(-2, -11.8), (3, -11.4), (7, -10.7), (11, -11.3), (16, -10.3)],
        [(-17, 11), (-11, 10.2), (-6, 10.8), (-1, 10.0)],
    ]
    for index, line in enumerate(strata):
        points = [(x, y, terrain_height(x, y) + 0.14) for x, y in line]
        curve_path(coll, "HP_Recovery_StrataLip_%02d" % index, points, 0.16, ICE, "strata_ledge_lip")
        undercut = [(x, y + 0.22, terrain_height(x, y + 0.22) - 0.18) for x, y in line]
        curve_path(coll, "HP_Recovery_Undercut_%02d" % index, undercut, 0.10, DARK, "ledge_undercut")
    # Four chipped anchor collars establish terrain-to-structure interaction.
    for index, (x, y) in enumerate(((-12.2, -2.3), (12.2, -2.3), (-8.5, 7.8), (8.5, 7.8))):
        z = terrain_height(x, y)
        outline = [(x - 0.9, y - 0.62), (x + 0.76, y - 0.55), (x + 1.04, y + 0.10), (x + 0.52, y + 0.72), (x - 0.68, y + 0.58), (x - 1.06, y - 0.08)]
        prism_z(coll, "HP_Recovery_AnchorCollar_%02d" % index, outline, z + 0.03, z + 0.34, METAL, "ice_anchor_collar", 0.075)
        for bolt_index, (bx, by) in enumerate(((x - 0.42, y), (x + 0.42, y))):
            hex_bolt(coll, "HP_Recovery_AnchorBolt_%02d_%02d" % (index, bolt_index), (bx, by, z + 0.34), 0.14, 0.12, METAL, "ice_anchor_bolt")
    # Compression fractures around anchor zones are narrow high-poly ridges,
    # placed individually rather than generated as a noise/displacement pass.
    for index, (x, y, dx, dy) in enumerate(((-12, -2, -2, 1), (-11, -1, -1, 2), (12, -2, 2, 1), (11, -1, 1, 2), (-8, 8, -2, 1), (8, 8, 2, 1))):
        curve_path(coll, "HP_Recovery_CompressionCrack_%02d" % index, [(x, y, terrain_height(x, y) + 0.06), (x + dx * 0.6, y + dy * 0.6, terrain_height(x + dx * 0.6, y + dy * 0.6) + 0.05), (x + dx, y + dy, terrain_height(x + dx, y + dy) + 0.04)], 0.042, DARK, "anchor_compression_crack")


def main():
    if not os.path.isfile(IN_BLEND):
        raise RuntimeError("Gate 03 source missing: " + IN_BLEND)
    bpy.ops.wm.open_mainfile(filepath=IN_BLEND)
    for name in ("HP_ARCHIVE", "HP_TRAVERSAL", "HP_TERRAIN"):
        delete_collection(name)
    global PAINT, METAL, ICE, DARK, ENERGY
    PAINT = material("MAT_HP_PaintedTitanium", (0.055, 0.095, 0.13, 1.0), 0.82, 0.28)
    METAL = material("MAT_HP_ExposedAlloy", (0.23, 0.34, 0.40, 1.0), 0.93, 0.20)
    ICE = material("MAT_HP_FracturedIce", (0.13, 0.40, 0.58, 1.0), 0.30, 0.28)
    DARK = material("MAT_HP_Cavity", (0.012, 0.022, 0.031, 1.0), 0.60, 0.50)
    ENERGY = material("MAT_HP_CoreGuide", (0.02, 0.42, 0.85, 1.0), 0.55, 0.22)
    archive_hp(ensure_collection("HP_ARCHIVE"))
    traversal_hp(ensure_collection("HP_TRAVERSAL"))
    terrain_hp(ensure_collection("HP_TERRAIN"))
    scene = bpy.context.scene
    scene["aetherfall_pipeline_gate"] = "04_high_poly_detailing"
    scene["aetherfall_runtime_export"] = "forbidden_until_retopology_uv_bake_pbr_review"
    scene["aetherfall_high_poly_note"] = "HP collections are bake-source only; base mesh collections remain the Gate 03 silhouette source."
    scene.render.engine = "BLENDER_EEVEE"
    bpy.ops.wm.save_as_mainfile(filepath=OUT_BLEND)
    print("Aetherfall Gate 04 High-Poly source written:", OUT_BLEND)


if __name__ == "__main__":
    main()
