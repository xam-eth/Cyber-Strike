"""Blender bpy: author a looping emissive tower orbit and export GLB + source."""
import bpy, math, os
ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), '../..'))
bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.ops.mesh.primitive_torus_add(major_radius=7.7, minor_radius=0.065, major_segments=64, minor_segments=8)
ring = bpy.context.object
ring.name = 'EnergyOrbit'
mat = bpy.data.materials.new('OrbitEnergy')
mat.use_nodes = True
bsdf = mat.node_tree.nodes.get('Principled BSDF')
bsdf.inputs['Base Color'].default_value = (0.02, 0.45, 0.8, 1)
bsdf.inputs['Emission Color'].default_value = (0.03, 0.65, 1.0, 1)
bsdf.inputs['Emission Strength'].default_value = 3.0
ring.data.materials.append(mat)
bpy.ops.mesh.primitive_uv_sphere_add(segments=16, ring_count=8, radius=0.28, location=(7.7, 0, 0))
bead = bpy.context.object
bead.name = 'OrbitBeacon'
bead.data.materials.append(mat)
bead.parent = ring
ring.rotation_euler = (0.30, 0, 0)
ring.keyframe_insert(data_path='rotation_euler', frame=1)
ring.rotation_euler = (0.30, 0, math.tau)
ring.keyframe_insert(data_path='rotation_euler', frame=241)
bpy.context.scene.frame_end = 241
bpy.ops.wm.save_as_mainfile(filepath=os.path.join(ROOT, 'source', 'energy_orbit.blend'))
bpy.ops.export_scene.gltf(filepath=os.path.join(ROOT, 'assets/world/aetherfall/models/energy_orbit.glb'), export_format='GLB', export_animations=True)
