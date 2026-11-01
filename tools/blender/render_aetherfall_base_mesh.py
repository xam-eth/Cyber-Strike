#!/usr/bin/env python3
"""Clay-review renders for Gate 03 Base Mesh; not runtime or final-art output."""
import os
import bpy
from mathutils import Vector


def authored_y_up_to_blender(point):
    x, y, z = point
    return (x, -z, y)

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "../.."))
SOURCE = os.path.join(ROOT, "source", "aetherfall_base_mesh.blend")
OUT = os.path.join(ROOT, "docs", "world", "aetherfall", "base_mesh")
os.makedirs(OUT, exist_ok=True)

bpy.ops.wm.open_mainfile(filepath=SOURCE)
scene = bpy.context.scene
# CPU Cycles keeps the clay review render headless; no viewport/GPU is required.
scene.render.engine = "CYCLES"
scene.cycles.device = "CPU"
scene.cycles.samples = 32
scene.cycles.use_denoising = True
scene.render.resolution_x = 1280
scene.render.resolution_y = 720
scene.render.resolution_percentage = 100
scene.render.image_settings.file_format = "PNG"
scene.world.use_nodes = True
scene.world.node_tree.nodes["Background"].inputs["Color"].default_value = (0.012, 0.024, 0.045, 1.0)
scene.world.node_tree.nodes["Background"].inputs["Strength"].default_value = 0.18
scene.view_settings.look = "AgX - Medium High Contrast"

# A review rig reads base form without pretending that it is final PBR lighting.
for obj in list(scene.objects):
    if obj.name.startswith("Review_"):
        bpy.data.objects.remove(obj, do_unlink=True)

def area(name, location, energy, size, color):
    data = bpy.data.lights.new(name, "AREA")
    data.energy = energy
    data.shape = "DISK"
    data.size = size
    data.color = color
    obj = bpy.data.objects.new(name, data)
    obj.location = authored_y_up_to_blender(location)
    obj.rotation_euler = (0.0, 0.0, 0.0)
    scene.collection.objects.link(obj)
    return obj

key = area("Review_Key", (18, 31, 24), 6000, 12, (0.73, 0.86, 1.0))
fill = area("Review_Fill", (-24, 15, 8), 3600, 10, (0.22, 0.53, 0.76))
rim = area("Review_Rim", (0, 21, -28), 4800, 8, (0.45, 0.78, 1.0))

def look(obj, target):
    obj.rotation_euler = (Vector(target) - obj.location).to_track_quat('-Z', 'Y').to_euler()

look(key, authored_y_up_to_blender((0, 8, 0)))
look(fill, authored_y_up_to_blender((0, 4, 0)))
look(rim, authored_y_up_to_blender((0, 9, 0)))

for camera_name, family, file_name in [
    ("CAM_ArchiveBase", "BM_ARCHIVE", "01_archive_base_clay.png"),
    ("CAM_TraversalBase", "BM_TRAVERSAL", "02_traversal_base_clay.png"),
    ("CAM_RecoveryBase", "BM_TERRAIN", "03_recovery_base_clay.png"),
]:
    # Each family shares the source origin to preserve its authored local
    # coordinates. Isolating it here avoids one family visually masking another.
    for collection_name in ("BM_ARCHIVE", "BM_TRAVERSAL", "BM_TERRAIN"):
        bpy.data.collections[collection_name].hide_render = collection_name != family
    camera = bpy.data.objects.get(camera_name)
    if camera is None:
        raise RuntimeError("Missing review camera " + camera_name)
    scene.camera = camera
    scene.render.filepath = os.path.join(OUT, file_name)
    bpy.ops.render.render(write_still=True)
    print("Rendered", file_name)
