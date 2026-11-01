#!/usr/bin/env python3
"""Gate 04 clay-review renders for High-Poly geometry, never runtime output."""
import os
import bpy
from mathutils import Vector

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "../.."))
SOURCE = os.path.join(ROOT, "source", "aetherfall_high_poly.blend")
OUT = os.path.join(ROOT, "docs", "world", "aetherfall", "high_poly")
os.makedirs(OUT, exist_ok=True)

bpy.ops.wm.open_mainfile(filepath=SOURCE)
scene = bpy.context.scene
scene.render.engine = "CYCLES"
scene.cycles.device = "CPU"
scene.cycles.samples = 32
scene.cycles.use_denoising = True
scene.render.resolution_x = 1280
scene.render.resolution_y = 720
scene.render.resolution_percentage = 100
scene.render.image_settings.file_format = "PNG"
scene.world.use_nodes = True
scene.world.node_tree.nodes["Background"].inputs["Color"].default_value = (0.006, 0.012, 0.024, 1.0)
scene.world.node_tree.nodes["Background"].inputs["Strength"].default_value = 0.16
scene.view_settings.look = "AgX - Medium High Contrast"

for obj in list(scene.objects):
    if obj.name.startswith("HPReview_"):
        bpy.data.objects.remove(obj, do_unlink=True)


def area(name, location, energy, size, color, target):
    data = bpy.data.lights.new(name, "AREA")
    data.energy = energy
    data.shape = "DISK"
    data.size = size
    data.color = color
    obj = bpy.data.objects.new(name, data)
    obj.location = location
    obj.rotation_euler = (Vector(target) - obj.location).to_track_quat('-Z', 'Y').to_euler()
    scene.collection.objects.link(obj)


area("HPReview_Key", (16, -24, 28), 5200, 11, (0.64, 0.82, 1.0), (0, 1, 8))
area("HPReview_Fill", (-18, 15, 13), 2800, 9, (0.12, 0.43, 0.80), (0, 0, 6))
area("HPReview_Rim", (2, 12, 26), 4200, 8, (0.42, 0.72, 1.0), (0, 0, 11))

for camera_name, base_collection, hp_collection, output_name in [
    ("CAM_ArchiveBase", "BM_ARCHIVE", "HP_ARCHIVE", "01_archive_high_poly_clay.png"),
    ("CAM_TraversalBase", "BM_TRAVERSAL", "HP_TRAVERSAL", "02_traversal_high_poly_clay.png"),
    ("CAM_RecoveryBase", "BM_TERRAIN", "HP_TERRAIN", "03_recovery_high_poly_clay.png"),
]:
    for collection_name in ("BM_ARCHIVE", "BM_TRAVERSAL", "BM_TERRAIN", "HP_ARCHIVE", "HP_TRAVERSAL", "HP_TERRAIN"):
        bpy.data.collections[collection_name].hide_render = collection_name not in (base_collection, hp_collection)
    camera = bpy.data.objects.get(camera_name)
    if camera is None:
        raise RuntimeError("Missing review camera " + camera_name)
    scene.camera = camera
    scene.render.filepath = os.path.join(OUT, output_name)
    bpy.ops.render.render(write_still=True)
    print("Rendered", output_name)
