"""Reassemble exported kit in Blender and render a non-Godot design preview.

Blender imports glTF Y-up to its Z-up coordinates. A Godot position (x,y,z)
therefore becomes Blender (x,-z,y). The output is not an in-engine screenshot.
"""
import bpy, json, math, os, sys
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
background.inputs['Strength'].default_value = 0.7
sun_data = bpy.data.lights.new('Sun', 'SUN')
sun_data.energy = 3.2
sun_data.color = (1, 0.88, 0.74)
sun = bpy.data.objects.new('Sun', sun_data)
scene.collection.objects.link(sun)
sun.rotation_euler = (math.radians(28), math.radians(-25), math.radians(-35))

def add_area(name, location, target, energy, colour, size):
    data = bpy.data.lights.new(name, 'AREA')
    data.energy = energy
    data.shape = 'DISK'
    data.size = size
    data.color = colour
    light = bpy.data.objects.new(name, data)
    light.location = location
    light.rotation_euler = (Vector(target) - light.location).to_track_quat('-Z', 'Y').to_euler()
    scene.collection.objects.link(light)

# Broad sources reveal roughness and normal response instead of leaving the
# metal kit black under a single sun. These exist only in this Blender preview.
add_area('WarmKey', (-28, -36, 42), (0, 22, 8), 1400, (1.0, 0.69, 0.46), 22)
add_area('CoolFill', (38, -10, 27), (0, 20, 4), 950, (0.40, 0.65, 1.0), 18)
scene.view_settings.look = 'AgX - Medium High Contrast'
scene.view_settings.exposure = 0.65
cam_data = bpy.data.cameras.new('ReviewCamera')
cam = bpy.data.objects.new('ReviewCamera', cam_data)
scene.collection.objects.link(cam)
scene.camera = cam
detail = '--detail' in sys.argv
if detail:
    # Close inspection of deck, painted trim and tower materials.
    cam.location = (25, -37, 13)
    target = Vector((0, -1, 0.5))
    cam_data.lens = 52
else:
    cam.location = (45, -75, 34)
    target = Vector((0, 26, 17))
    cam_data.lens = 35
cam.rotation_euler = (target - cam.location).to_track_quat('-Z', 'Y').to_euler()
scene.render.engine = 'CYCLES'
scene.cycles.samples = 16
scene.render.resolution_x = 960
scene.render.resolution_y = 540
scene.render.resolution_percentage = 100
scene.render.image_settings.file_format = 'PNG'
scene.render.filepath = os.path.join(OUT, 'blender_pbr_detail.png' if detail else 'blender_design_preview.png')
bpy.ops.render.render(write_still=True)
print('Blender preview saved:', scene.render.filepath)
