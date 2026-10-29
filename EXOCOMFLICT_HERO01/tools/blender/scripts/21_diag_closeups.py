"""Diagnostic: shipped GLBs only, aim-pose close-ups matching owner's Godot camera presets.
Checks whether 'missing detail' is geometric (shell gaps when posed) or Godot-rendering only."""
import bpy, math, os
from mathutils import Matrix, Vector
PROJ="/home/user/Cyber-Strike/EXOCOMFLICT_HERO01"; SHOT=f"{PROJ}/screenshots/diag"; os.makedirs(SHOT, exist_ok=True)
bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.ops.import_scene.gltf(filepath=f"{PROJ}/assets/characters/HERO_01_RIGGED.glb")
bpy.ops.import_scene.gltf(filepath=f"{PROJ}/assets/weapons/HERO_01_WEAPON.glb")
sc=bpy.context.scene; sc.render.fps=30; sc.frame_start=0; sc.frame_end=45
arm=[o for o in bpy.data.objects if o.type=='ARMATURE'][0]
meshes=[o for o in bpy.data.objects if o.type=='MESH']
for m in meshes:
    if len(m.data.vertices)<1000: bpy.data.objects.remove(m, do_unlink=True)
meshes=[o for o in bpy.data.objects if o.type=='MESH']
weapon=[m for m in meshes if "WEAPON" in m.name][0]
print("meshes:", [(m.name, len(m.data.vertices)) for m in meshes])
sc.frame_set(0); bpy.context.view_layer.update()
weapon.parent=arm; weapon.parent_type='BONE'; weapon.parent_bone="Weapon_R"
bpy.context.view_layer.update()
weapon.matrix_world=Matrix.Identity(4); bpy.context.view_layer.update()
sc.render.engine="CYCLES"; sc.cycles.samples=24; sc.cycles.use_denoising=True; sc.cycles.device="CPU"
w=bpy.data.worlds.new("W"); sc.world=w; w.use_nodes=True
w.node_tree.nodes["Background"].inputs[0].default_value=(0.16,0.17,0.19,1); w.node_tree.nodes["Background"].inputs[1].default_value=0.9
sd=bpy.data.lights.new("Sun","SUN"); sd.energy=3; so=bpy.data.objects.new("Sun",sd); sc.collection.objects.link(so)
so.rotation_euler=(math.radians(52),math.radians(8),math.radians(-38))
bpy.ops.mesh.primitive_plane_add(size=8, location=(0,0,0)); gnd=bpy.context.active_object
gm=bpy.data.materials.new("Ground"); gm.use_nodes=True; gm.node_tree.nodes["Principled BSDF"].inputs["Base Color"].default_value=(0.23,0.24,0.27,1)
gnd.data.materials.append(gm)
cam=bpy.data.objects.new("Cam",bpy.data.cameras.new("Cam")); cam.data.lens=52; sc.collection.objects.link(cam); sc.camera=cam
arm.hide_render=True
def shoot(name,frame,loc,target,rx=1000,ry=1000):
    sc.frame_set(frame); cam.location=loc
    cam.rotation_euler=(Vector(target)-Vector(loc)).to_track_quat('-Z','Y').to_euler()
    sc.render.resolution_x=rx; sc.render.resolution_y=ry; sc.render.filepath=f"{SHOT}/{name}.png"
    bpy.ops.render.render(write_still=True); print("RENDERED",name)
# Godot CloseWeapon preset converted: cam(-1.1,1.4,1.5)->tgt(-0.1,1.3,0.35) @1.8 => Blender below
CW_C=(-0.611,-0.833,0.778); CW_T=(-0.056,-0.194,0.722)
CH_C=(-0.389,-0.639,0.806); CH_T=(-0.028,-0.139,0.722)
shoot("diag_F36_closeweapon",36,CW_C,CW_T)
shoot("diag_F00_closeweapon",0,CW_C,CW_T)
shoot("diag_F36_closehands",36,CH_C,CH_T)
shoot("diag_F36_shoulderR",36,(-0.45,-0.55,0.80),(-0.06,-0.10,0.72))
shoot("diag_F36_back",36,(0,1.9,0.60),(0,0,0.52),800,1000)
print("DONE")
