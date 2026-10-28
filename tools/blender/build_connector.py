"""Produce a reusable unit ramp beam. Local X is travel, Y is up, Z is width."""
import bpy, os
ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), '../..'))
bpy.ops.wm.read_factory_settings(use_empty=True)

def material(name, color, metal, rough):
    m = bpy.data.materials.new(name)
    m.use_nodes = True
    p = m.node_tree.nodes.get('Principled BSDF')
    p.inputs['Base Color'].default_value = (*color, 1)
    p.inputs['Metallic'].default_value = metal
    p.inputs['Roughness'].default_value = rough
    return m

steel = material('RampSteel', (0.15, 0.22, 0.27), 0.65, 0.6)
hazard = material('RampHazard', (0.9, 0.5, 0.045), 0.2, 0.6)
def box(name, dims, location, mat):
    bpy.ops.mesh.primitive_cube_add(size=1, location=location)
    obj = bpy.context.object
    obj.name = name
    obj.scale = dims
    bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
    obj.data.materials.append(mat)
    return obj
# Top surface at y=0. Mesh and collider therefore share the same endpoints.
box('RampDeck', (1, 0.2, 1), (0, -0.1, 0), steel)
for z in (-0.45, 0.45):
    box('SafetyStripe', (1, 0.015, 0.035), (0, 0.0075, z), hazard)
bpy.ops.wm.save_as_mainfile(filepath=os.path.join(ROOT, 'source', 'connector_ramp.blend'))
bpy.ops.export_scene.gltf(filepath=os.path.join(ROOT, 'assets/world/aetherfall/models/connector_ramp.glb'), export_format='GLB', export_yup=False)
