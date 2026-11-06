#!/usr/bin/env python3
"""Gate 03 source authoring for Aetherfall.

This script intentionally does NOT export a runtime GLB. It creates three
reviewable Base Mesh families in a Blender source scene: Sentinel Archive,
traversal section, and glacial recovery cliff. High-poly detail, retopology,
UVs, bakes and PBR textures are separate later gates.
"""
from __future__ import annotations

import math
import os
import bpy
from mathutils import Vector

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "../.."))
OUT_BLEND = os.path.join(ROOT, "source", "aetherfall_base_mesh.blend")


def material(name: str, color: tuple[float, float, float, float]) -> bpy.types.Material:
    existing = bpy.data.materials.get(name)
    if existing:
        return existing
    mat = bpy.data.materials.new(name)
    mat.diffuse_color = color
    mat.use_nodes = True
    principled = mat.node_tree.nodes.get("Principled BSDF")
    principled.inputs["Base Color"].default_value = color
    principled.inputs["Roughness"].default_value = 0.72
    return mat


ARCHIVE_CLAY = None
TERRAIN_CLAY = None
TRAVERSAL_CLAY = None
ENERGY_GUIDE = None


def collection(name: str) -> bpy.types.Collection:
    coll = bpy.data.collections.get(name)
    if coll is None:
        coll = bpy.data.collections.new(name)
        bpy.context.scene.collection.children.link(coll)
    return coll


def authored_y_up_to_blender(point):
    """The design coordinates are X/right, Y/up, Z/forward; Blender is Z-up."""
    x, y, z = point
    return (x, -z, y)


def mesh_object(coll: bpy.types.Collection, name: str, verts, faces, mat, role: str) -> bpy.types.Object:
    mesh = bpy.data.meshes.new(name)
    mesh.from_pydata([authored_y_up_to_blender(vertex) for vertex in verts], [], faces)
    mesh.materials.append(mat)
    mesh.update()
    obj = bpy.data.objects.new(name, mesh)
    obj["aetherfall_stage"] = "base_mesh"
    obj["aetherfall_role"] = role
    coll.objects.link(obj)
    return obj


def prism_xz(coll, name, outline, y0, y1, mat, role):
    """Closed X/Z profile extrusion. This is authored topology, not a cube."""
    count = len(outline)
    verts = [(x, y0, z) for x, z in outline] + [(x, y1, z) for x, z in outline]
    faces = [tuple(range(count - 1, -1, -1)), tuple(range(count, count * 2))]
    for index in range(count):
        nxt = (index + 1) % count
        faces.append((index, nxt, count + nxt, count + index))
    return mesh_object(coll, name, verts, faces, mat, role)


def vertical_profile(coll, name, outline, z0, z1, mat, role):
    """Closed X/Y profile extrusion for facade frames and buttresses."""
    count = len(outline)
    verts = [(x, y, z0) for x, y in outline] + [(x, y, z1) for x, y in outline]
    faces = [tuple(range(count - 1, -1, -1)), tuple(range(count, count * 2))]
    for index in range(count):
        nxt = (index + 1) % count
        faces.append((index, nxt, count + nxt, count + index))
    return mesh_object(coll, name, verts, faces, mat, role)


def loft(coll, name, rings, sides, mat, role, phase=0.0):
    """A deliberately asymmetric closed architectural/geological volume."""
    verts = []
    for y, rx, rz, cx, cz in rings:
        for index in range(sides):
            angle = phase + math.tau * index / sides
            # Tiny controlled variance avoids a regular primitive profile while
            # preserving a clean Base Mesh silhouette for later retopology.
            variance = 1.0 + math.sin(index * 3.73 + y * 0.23) * 0.035
            verts.append((cx + math.cos(angle) * rx * variance, y, cz + math.sin(angle) * rz * variance))
    faces = [tuple(range(sides - 1, -1, -1))]
    for ring in range(len(rings) - 1):
        offset = ring * sides
        for index in range(sides):
            nxt = (index + 1) % sides
            faces.append((offset + index, offset + nxt, offset + sides + nxt, offset + sides + index))
    top = (len(rings) - 1) * sides
    faces.append(tuple(top + index for index in range(sides)))
    return mesh_object(coll, name, verts, faces, mat, role)


def build_archive_base(coll):
    """Functional landmark base form: plinth, gate void, shell, wings, crown."""
    # The visible base is intentionally decomposed around an actual threshold;
    # it is not a solid tower with a door texture painted on it.
    prism_xz(
        coll, "BM_Archive_ArrivalPlinth",
        [(-13, -10), (10, -10), (14, -6), (14, 8), (10, 12), (-11, 12), (-14, 8), (-14, -6)],
        0.0, 1.2, ARCHIVE_CLAY, "arrival_plinth",
    )
    loft(
        coll, "BM_Archive_CentralShell",
        [(1.0, 8.5, 7.4, 0, 0), (4.0, 9.4, 8.3, 0, 0), (18.0, 7.1, 6.4, 0, 0), (22.0, 5.4, 5.1, 0, 0)],
        10, ARCHIVE_CLAY, "central_shell", math.pi / 10.0,
    )
    # Full-height gate frame establishes the archive access void at the front.
    vertical_profile(
        coll, "BM_Archive_GateFrame",
        [(-4.7, 0.8), (-5.9, 4.0), (-5.9, 11.8), (-4.2, 14.2), (4.2, 14.2), (5.9, 11.8), (5.9, 4.0), (4.7, 0.8), (2.7, 0.8), (2.7, 10.7), (-2.7, 10.7), (-2.7, 0.8)],
        -8.65, -10.0, TRAVERSAL_CLAY, "archive_threshold",
    )
    # Wings and buttresses turn the primary shell into an anchored building.
    for side in (-1.0, 1.0):
        loft(
            coll, "BM_Archive_ServiceWing_%s" % ("L" if side < 0 else "R"),
            [(1.0, 3.4, 4.8, side * 10.3, 1.0), (8.0, 3.9, 5.4, side * 10.3, 1.0), (13.0, 2.5, 3.9, side * 9.7, 0.5)],
            7, ARCHIVE_CLAY, "service_wing", 0.16,
        )
        vertical_profile(
            coll, "BM_Archive_Buttress_%s" % ("L" if side < 0 else "R"),
            [(side * 13.2, 0.5), (side * 10.3, 0.5), (side * 7.2, 16.0), (side * 9.0, 18.5), (side * 11.3, 11.5)],
            -4.8, 4.8, ARCHIVE_CLAY, "load_buttress",
        )
    loft(
        coll, "BM_Archive_Crown",
        [(21.5, 5.6, 5.2, 0, 0), (24.0, 4.0, 3.6, 0, 0), (29.0, 2.2, 1.9, 0, 0), (35.0, 0.32, 0.32, 0, 0)],
        8, ARCHIVE_CLAY, "command_crown", math.pi / 8.0,
    )
    # This is an explicit objective placeholder that preserves the future core
    # volume; high-poly machinery is a later gate.
    loft(
        coll, "BM_Archive_DataCoreVolume",
        [(3.0, 2.1, 1.9, 0, -3.6), (11.5, 1.8, 1.6, 0, -3.6)],
        8, ENERGY_GUIDE, "objective_core_volume", math.pi / 8.0,
    )


def build_traversal_base(coll):
    """A bridge section with a real load path: deck, truss, rails, service tray."""
    prism_xz(
        coll, "BM_Traversal_Deck",
        [(-3.0, -7.0), (2.4, -7.0), (3.1, -6.2), (3.1, 6.0), (2.2, 7.0), (-2.5, 7.0), (-3.1, 6.2), (-3.1, -6.2)],
        0.0, 0.72, TRAVERSAL_CLAY, "bridge_deck",
    )
    # Under-deck truss frames are broad Base Mesh forms, not final greeble.
    for z in (-5.6, -2.8, 0.0, 2.8, 5.6):
        vertical_profile(
            coll, "BM_Traversal_Truss_%02d" % int(z * 10),
            [(-2.75, -4.8), (-2.3, -4.8), (0.0, -0.3), (2.3, -4.8), (2.75, -4.8), (0.65, -0.3), (0.0, -2.6), (-0.65, -0.3)],
            z - 0.16, z + 0.16, TRAVERSAL_CLAY, "under_deck_truss",
        )
    for side in (-1.0, 1.0):
        x = side * 2.75
        for z in (-5.8, -2.0, 2.0, 5.8):
            loft(coll, "BM_Traversal_RailPost_%s_%s" % (int(side), int(z * 10)), [(0.65, 0.11, 0.11, x, z), (2.05, 0.075, 0.075, x, z)], 5, TRAVERSAL_CLAY, "rail_post")
        prism_xz(coll, "BM_Traversal_Rail_%s" % int(side), [(x - 0.09, -7.0), (x + 0.09, -7.0), (x + 0.09, 7.0), (x - 0.09, 7.0)], 1.88, 2.08, TRAVERSAL_CLAY, "handrail")
    prism_xz(coll, "BM_Traversal_ServiceTray", [(-0.52, -6.7), (0.52, -6.7), (0.52, 6.7), (-0.52, 6.7)], 0.74, 1.18, TRAVERSAL_CLAY, "service_tray")


def cliff_height(x, z):
    broad = math.sin(x * 0.21) * 1.3 + math.cos(z * 0.18) * 1.1
    cut = math.sin((x + z) * 0.38) * 0.55
    return 4.0 + broad + cut


def build_terrain_base(coll):
    """Watertight recovery cliff with primary mass and navigable shelf breaks."""
    width, depth, grid = 42.0, 28.0, 16
    verts = []
    # top and deep base grids make a closed geological mass, suitable for later sculpting.
    for layer in (0, 1):
        for zi in range(grid + 1):
            z = -depth * 0.5 + depth * zi / grid
            for xi in range(grid + 1):
                x = -width * 0.5 + width * xi / grid
                y = cliff_height(x, z) if layer == 0 else -17.0
                verts.append((x, y, z))
    stride = grid + 1
    bottom = stride * stride
    faces = []
    for zi in range(grid):
        for xi in range(grid):
            top = zi * stride + xi
            faces.append((top, top + 1, top + stride + 1, top + stride))
            low = bottom + zi * stride + xi
            faces.append((low + stride, low + stride + 1, low + 1, low))
    for xi in range(grid):
        faces.append((xi + 1, xi, bottom + xi, bottom + xi + 1))
        rear = grid * stride + xi
        faces.append((rear, rear + 1, bottom + rear + 1, bottom + rear))
    for zi in range(grid):
        left = zi * stride
        faces.append((left, left + stride, bottom + left + stride, bottom + left))
        right = zi * stride + grid
        faces.append((right + stride, right, bottom + right, bottom + right + stride))
    mesh_object(coll, "BM_Recovery_GlacierMass", verts, faces, TERRAIN_CLAY, "watertight_glacier_mass")
    # Shelf forms are intentional landing/recovery levels, not scattered pebbles.
    for index, (y, scale) in enumerate(((-3.8, 0.94), (-8.4, 0.78), (-12.5, 0.61))):
        outline = []
        for point in range(12):
            angle = math.tau * point / 12.0
            radius = 1.0 + math.sin(point * 2.81 + index) * 0.13
            outline.append((math.cos(angle) * 19.0 * scale * radius, math.sin(angle) * 12.5 * scale * radius))
        prism_xz(coll, "BM_Recovery_Shelf_%d" % index, outline, y - 0.8, y, TERRAIN_CLAY, "erosion_shelf")
    # Mechanical anchor volume reserves a meaningful terrain/structure connection.
    for side in (-1.0, 1.0):
        vertical_profile(
            coll, "BM_Recovery_Anchor_%s" % int(side),
            [(side * 15.8, -5.0), (side * 13.2, -5.0), (side * 10.0, 6.0), (side * 11.8, 8.0), (side * 14.4, 3.0)],
            -3.4, -1.8, TRAVERSAL_CLAY, "cliff_anchor",
        )


def add_camera(coll):
    camera_data = [
        # Pulled-back review framing so the whole primary silhouette is readable.
        ("CAM_ArchiveBase", (45.0, 34.0, -72.0), (0.0, 12.0, -2.0), 35.0),
        ("CAM_TraversalBase", (23.0, 16.0, 23.0), (0.0, -0.8, 0.0), 38.0),
        ("CAM_RecoveryBase", (55.0, 42.0, 55.0), (0.0, -5.0, 0.0), 35.0),
    ]
    for name, position, target, lens in camera_data:
        data = bpy.data.cameras.new(name)
        data.lens = lens
        obj = bpy.data.objects.new(name, data)
        obj.location = authored_y_up_to_blender(position)
        direction = Vector(authored_y_up_to_blender(target)) - obj.location
        obj.rotation_euler = direction.to_track_quat('-Z', 'Y').to_euler()
        obj["aetherfall_stage"] = "base_mesh_review"
        coll.objects.link(obj)


def main():
    global ARCHIVE_CLAY, TERRAIN_CLAY, TRAVERSAL_CLAY, ENERGY_GUIDE
    bpy.ops.object.select_all(action="SELECT")
    bpy.ops.object.delete(use_global=False)
    for coll in list(bpy.data.collections):
        if coll.name.startswith("BM_") or coll.name.startswith("CAM_"):
            bpy.data.collections.remove(coll)
    ARCHIVE_CLAY = material("MAT_BM_ArchiveClay", (0.19, 0.24, 0.29, 1.0))
    TERRAIN_CLAY = material("MAT_BM_TerrainClay", (0.18, 0.30, 0.39, 1.0))
    TRAVERSAL_CLAY = material("MAT_BM_TraversalClay", (0.28, 0.31, 0.32, 1.0))
    ENERGY_GUIDE = material("MAT_BM_EnergyGuide", (0.06, 0.55, 0.76, 1.0))
    ARCHIVE_CLAY.node_tree.nodes["Principled BSDF"].inputs["Metallic"].default_value = 0.72
    TRAVERSAL_CLAY.node_tree.nodes["Principled BSDF"].inputs["Metallic"].default_value = 0.68
    terrain = collection("BM_TERRAIN")
    archive = collection("BM_ARCHIVE")
    traversal = collection("BM_TRAVERSAL")
    cameras = collection("CAM_BASE_MESH_REVIEW")
    build_terrain_base(terrain)
    build_archive_base(archive)
    build_traversal_base(traversal)
    add_camera(cameras)
    bpy.context.scene["aetherfall_pipeline_gate"] = "03_base_mesh"
    bpy.context.scene["aetherfall_runtime_export"] = "forbidden_until_hp_retopo_uv_bake_review"
    # bpy 5 package exposes the Eevee engine under this compatibility enum.
    bpy.context.scene.render.engine = "BLENDER_EEVEE"
    bpy.ops.wm.save_as_mainfile(filepath=OUT_BLEND)
    print("Aetherfall Gate 03 Base Mesh source written:", OUT_BLEND)


if __name__ == "__main__":
    main()
