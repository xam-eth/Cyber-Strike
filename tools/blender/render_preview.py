"""Reassemble exported kit in Blender and render a non-Godot design preview.

Blender imports glTF Y-up to its Z-up coordinates. A Godot position (x,y,z)
therefore becomes Blender (x,-z,y). The output is not an in-engine screenshot.
"""
import bpy, json, math, os
from mathutils import Vector, Matrix
ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), '../..'))
BASE = os.path.join(ROOT, 'assets/world/aetherfall')
OUT = os.path.join(ROOT, 'docs', 'previews')
os.makedirs(OUT, exist_ok=True)
bpy.ops.wm.read_factory_settings(use_empty=True)
scene = bpy.context.scene
layout = json.load(open(os.path.join(BASE, 'layout.json')))
assets = sorted({item['asset'] for item in layout['placements']})
collections = {}
for key in assets:
    before = set(bpy.data.objects)
    bpy.ops.import_scene.gltf(filepath=os.path.join(BASE, 'models', key + '.glb'))
    objects = set(bpy.data.objects) - before
    coll = bpy.data.collections.new('kit_' + key)
    for obj in objects:
        for old in list(obj.users_collection):
            old.objects.unlink(obj)
        coll.objects.link(obj)
    collections[key] = coll
for item in layout['placements']:
    node = bpy.data.objects.new(item['name'], None)
    node.instance_type = 'COLLECTION'
    node.instance_collection = collections[item['asset']]
    x, y, z = item['pos']
    rx, ry, rz = item['rot']
    node.location = (x, -z, y)
    node.rotation_euler = (math.radians(rx), math.radians(-rz), math.radians(ry))
    node.scale = (item['scale'],) * 3
    scene.collection.objects.link(node)
# The review includes the separate ramp kit, placed with the same basis as Godot.
before = set(bpy.data.objects)
bpy.ops.import_scene.gltf(filepath=os.path.join(BASE, 'models', 'connector_ramp.glb'))
coll = bpy.data.collections.new('kit_connector_ramp')
for obj in set(bpy.data.objects) - before:
    for old in list(obj.users_collection):
        old.objects.unlink(obj)
    coll.objects.link(obj)
conversion = Matrix(((1, 0, 0), (0, 0, -1), (0, 1, 0)))
for item in json.load(open(os.path.join(BASE, 'connectors.json')))['connectors']:
    start, end = Vector(item['from']), Vector(item['to'])
    delta = end - start
    forward = delta.normalized()
    side = forward.cross(Vector((0, 1, 0))).normalized()
    normal = side.cross(forward).normalized()
    basis = Matrix((forward, normal, side)).transposed()
    node = bpy.data.objects.new(item['name'], None)
    node.instance_type = 'COLLECTION'
    node.instance_collection = coll
    scene.collection.objects.link(node)
    node.rotation_euler = (conversion @ basis @ conversion.inverted()).to_euler()
    node.scale = (delta.length, item['width'], 1)
    node.location = conversion @ ((start + end) / 2)

scene.world = bpy.data.worlds.new('Sky')
scene.world.use_nodes = True
background = scene.world.node_tree.nodes.get('Background')
background.inputs['Color'].default_value = (0.26, 0.36, 0.47, 1)
background.inputs['Strength'].default_value = 0.45
sun_data = bpy.data.lights.new('Sun', 'SUN')
sun_data.energy = 2.4
sun_data.color = (1, 0.88, 0.74)
sun = bpy.data.objects.new('Sun', sun_data)
scene.collection.objects.link(sun)
sun.rotation_euler = (math.radians(28), math.radians(-25), math.radians(-35))
cam_data = bpy.data.cameras.new('ReviewCamera')
cam = bpy.data.objects.new('ReviewCamera', cam_data)
scene.collection.objects.link(cam)
scene.camera = cam
cam.location = (45, -75, 34)
target = Vector((0, 26, 17))
cam.rotation_euler = (target - cam.location).to_track_quat('-Z', 'Y').to_euler()
cam_data.lens = 35
scene.render.engine = 'CYCLES'
scene.cycles.samples = 16
scene.render.resolution_x = 960
scene.render.resolution_y = 540
scene.render.resolution_percentage = 100
scene.render.image_settings.file_format = 'PNG'
scene.render.filepath = os.path.join(OUT, 'blender_design_preview.png')
bpy.ops.render.render(write_still=True)
print('Blender preview saved:', scene.render.filepath)
