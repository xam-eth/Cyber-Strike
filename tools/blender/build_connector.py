"""Produce the reusable Aetherfall ramp with embedded PBR texture maps.

Local X is travel, Y is up and Z is width. Run build_aetherfall.py first: it
writes the shared material maps used here. The ramp itself remains authored and
exported through Blender, so the world has a native editable source .blend.
"""
import bpy
import os

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), '../..'))
MATERIALS = os.path.join(ROOT, 'assets', 'world', 'aetherfall', 'materials')
bpy.ops.wm.read_factory_settings(use_empty=True)

def texture(name, non_color=False):
    path = os.path.join(MATERIALS, name + '.png')
    if not os.path.isfile(path):
        raise RuntimeError('Missing shared PBR map: ' + path)
    image = bpy.data.images.load(path)
    image.colorspace_settings.name = 'Non-Color' if non_color else 'sRGB'
    return image

def material(name, color, metal, rough, surface):
    m = bpy.data.materials.new(name)
    m.use_nodes = True
    tree = m.node_tree
    p = tree.nodes.get('Principled BSDF')
    p.inputs['Base Color'].default_value = (*color, 1)
    p.inputs['Metallic'].default_value = metal
    p.inputs['Roughness'].default_value = rough
    base = tree.nodes.new('ShaderNodeTexImage')
    base.name = 'BaseColor_' + surface
    base.image = texture(surface)
    base.extension = 'REPEAT'
    tree.links.new(base.outputs['Color'], p.inputs['Base Color'])
    normal = tree.nodes.new('ShaderNodeTexImage')
    normal.name = 'Normal_' + surface
    normal.image = texture(surface + '_normal', non_color=True)
    normal.extension = 'REPEAT'
    normal_map = tree.nodes.new('ShaderNodeNormalMap')
    normal_map.inputs['Strength'].default_value = 0.72
    tree.links.new(normal.outputs['Color'], normal_map.inputs['Color'])
    tree.links.new(normal_map.outputs['Normal'], p.inputs['Normal'])
    orm = tree.nodes.new('ShaderNodeTexImage')
    orm.name = 'ORM_' + surface
    orm.image = texture(surface + '_orm', non_color=True)
    orm.extension = 'REPEAT'
    separate = tree.nodes.new('ShaderNodeSeparateColor')
    separate.mode = 'RGB'
    tree.links.new(orm.outputs['Color'], separate.inputs['Color'])
    tree.links.new(separate.outputs['Red'], p.inputs['Metallic'])
    tree.links.new(separate.outputs['Green'], p.inputs['Roughness'])
    return m

steel = material('RampSteel', (0.15, 0.22, 0.27), 0.65, 0.6, 'aether_metal')
hazard = material('RampHazard', (0.9, 0.5, 0.045), 0.2, 0.6, 'aether_hazard')
def box(name, dims, location, mat):
    bpy.ops.mesh.primitive_cube_add(size=1, location=location)
    obj = bpy.context.object
    obj.name = name
    obj.scale = dims
    bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
    obj.data.materials.append(mat)
    return obj

# Top surface is y=0, sharing exact endpoints with Godot collision.
box('RampDeck', (1, 0.2, 1), (0, -0.1, 0), steel)
for z in (-0.45, 0.45):
    box('SafetyStripe', (1, 0.015, 0.035), (0, 0.0075, z), hazard)
bpy.ops.file.pack_all()
bpy.ops.wm.save_as_mainfile(filepath=os.path.join(ROOT, 'source', 'connector_ramp.blend'))
bpy.ops.export_scene.gltf(filepath=os.path.join(ROOT, 'assets/world/aetherfall/models/connector_ramp.glb'), export_format='GLB', export_yup=False)
