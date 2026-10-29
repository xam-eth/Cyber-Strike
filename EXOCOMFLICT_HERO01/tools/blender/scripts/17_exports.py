"""Export HERO_01_RIGGED.glb (with clip), HERO_01_WEAPON.glb, HERO_01_ANIMATIONS.glb (no materials), then roundtrip-validate."""
import bpy, math, os, json
from mathutils import Vector
PROJ="/home/user/Cyber-Strike/EXOCOMFLICT_HERO01"
CHAR=f"{PROJ}/assets/characters"; WEAP=f"{PROJ}/assets/weapons"; ANIM=f"{PROJ}/animations"; REND=f"{PROJ}/screenshots/rig"
for d in [CHAR,WEAP,ANIM]: os.makedirs(d,exist_ok=True)
bpy.ops.wm.open_mainfile(filepath=f"{PROJ}/blender/HERO_01_working.blend")
arm=bpy.data.objects["HERO_01_Armature"]; body=bpy.data.objects["HERO_01_BODY"]; weapon=bpy.data.objects["HERO_01_WEAPON"]
sc=bpy.context.scene; sc.frame_set(0); bpy.context.view_layer.update()
def select(objs):
    bpy.ops.object.select_all(action='DESELECT')
    for o in objs: o.select_set(True)
    bpy.context.view_layer.objects.active=objs[0]
def export(path,objs,**kw):
    select(objs)
    base=dict(filepath=path, export_format='GLB', use_selection=True, export_yup=True,
              export_apply=False, export_skins=True, export_def_bones=False)
    base.update(kw)
    try:
        bpy.ops.export_scene.gltf(**base)
    except TypeError as e:
        print("export kw fallback:", e)
        for k in ["export_animation_mode","export_force_sampling","export_optimize_animation_size"]:
            base.pop(k,None)
        bpy.ops.export_scene.gltf(**base)
    print("EXPORTED", path, os.path.getsize(path))
export(f"{CHAR}/HERO_01_RIGGED.glb",[arm,body], export_animations=True, export_animation_mode='ACTIONS',
       export_force_sampling=True, export_optimize_animation_size=False, export_materials='EXPORT')
export(f"{ANIM}/HERO_01_ANIMATIONS.glb",[arm,body], export_animations=True, export_animation_mode='ACTIONS',
       export_force_sampling=True, export_optimize_animation_size=False, export_materials='NONE')
# weapon: duplicate unparented at world identity
dup=weapon.copy(); dup.data=weapon.data.copy(); sc.collection.objects.link(dup)
dup.parent=None; dup.matrix_world=weapon.matrix_world.copy()
bpy.context.view_layer.update()
print("weapon dup world:", [round(float(x),4) for x in dup.matrix_world.translation])
export(f"{WEAP}/HERO_01_WEAPON.glb",[dup], export_animations=False, export_materials='EXPORT')
bpy.data.objects.remove(dup, do_unlink=True)
# --- roundtrip: fresh scene, import RIGGED, render neutral + F36 ---
bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.ops.import_scene.gltf(filepath=f"{CHAR}/HERO_01_RIGGED.glb")
sc=bpy.context.scene; sc.render.fps=30; sc.frame_start=0; sc.frame_end=45
print("RT objects:", [(o.name,o.type) for o in bpy.data.objects])
print("RT actions:", [a.name for a in bpy.data.actions])
rt_arm=[o for o in bpy.data.objects if o.type=='ARMATURE'][0]
print("RT bones:", len(rt_arm.data.bones), [b.name for b in rt_arm.data.bones])
for a in bpy.data.actions: print(" action", a.name, "range", tuple(a.frame_range))
sc.render.engine="CYCLES"; sc.cycles.samples=16; sc.cycles.use_denoising=True; sc.cycles.device="CPU"
w=bpy.data.worlds.new("W"); sc.world=w; w.use_nodes=True
w.node_tree.nodes["Background"].inputs[0].default_value=(0.16,0.17,0.19,1); w.node_tree.nodes["Background"].inputs[1].default_value=0.9
sd=bpy.data.lights.new("Sun","SUN"); sd.energy=3; so=bpy.data.objects.new("Sun",sd); sc.collection.objects.link(so)
so.rotation_euler=(math.radians(52),math.radians(8),math.radians(-38))
bpy.ops.mesh.primitive_plane_add(size=8, location=(0,0,0)); gnd=bpy.context.active_object
gm=bpy.data.materials.new("Ground"); gm.use_nodes=True; gm.node_tree.nodes["Principled BSDF"].inputs["Base Color"].default_value=(0.23,0.24,0.27,1)
gnd.data.materials.append(gm)
cam=bpy.data.objects.new("Cam",bpy.data.cameras.new("Cam")); cam.data.lens=52; sc.collection.objects.link(cam); sc.camera=cam
rt_arm.hide_render=True
def shoot(name,frame,loc,target=(0,0,0.5)):
    sc.frame_set(frame); cam.location=loc
    cam.rotation_euler=(Vector(target)-Vector(loc)).to_track_quat('-Z','Y').to_euler()
    sc.render.resolution_x=700; sc.render.resolution_y=875; sc.render.filepath=f"{REND}/{name}.png"
    bpy.ops.render.render(write_still=True); print("RENDERED",name)
shoot("rt_neutral_front",0,(0,-2.15,0.55))
shoot("rt_aim_F36_3q",36,(-1.4,-1.4,0.68),(0,0,0.48))
print("DONE")
