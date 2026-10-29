import bpy, math, os
from mathutils import Matrix, Vector
PROJ="/home/user/Cyber-Strike/EXOCOMFLICT_HERO01"
CHAR=f"{PROJ}/assets/characters"; WEAP=f"{PROJ}/assets/weapons"; ANIM=f"{PROJ}/animations"; REND=f"{PROJ}/screenshots/rig"
bpy.ops.wm.open_mainfile(filepath=f"{PROJ}/blender/HERO_01_working.blend")
arm=bpy.data.objects["HERO_01_Armature"]; body=bpy.data.objects["HERO_01_BODY"]; weapon=bpy.data.objects["HERO_01_WEAPON"]
sc=bpy.context.scene
ORDER=["Root","Hips","Spine","Chest","UpperChest","Neck","Head","Clavicle_R","UpperArm_R","Forearm_R","Hand_R","Weapon_R","Clavicle_L","UpperArm_L","Forearm_L","Hand_L","UpperLeg_R","LowerLeg_R","Foot_R","Toe_R","UpperLeg_L","LowerLeg_L","Foot_L","Toe_L"]
def key_all(F):
    for n in ORDER:
        pb=arm.pose.bones[n]; pb.keyframe_insert("location",frame=F); pb.keyframe_insert("rotation_quaternion",frame=F)
def rot(name,axis,deg):
    pb=arm.pose.bones[name]; head=pb.head.copy()
    M=Matrix.Translation(head)@Matrix.Rotation(math.radians(deg),4,axis)@Matrix.Translation(-head)
    pb.matrix=M@pb.matrix; bpy.context.view_layer.update()
# F0 exact rest
sc.frame_set(0)
for n in ORDER:
    pb=arm.pose.bones[n]; pb.matrix=pb.bone.matrix_local.copy(); bpy.context.view_layer.update()
key_all(0)
bpy.context.view_layer.update()
print("weapon world @F0 after exact-rest:", [round(float(x),5) for x in weapon.matrix_world.translation])
# F45 settle: copy F36 pose + micro settle
sc.frame_set(36); bpy.context.view_layer.update()
pose36={n:arm.pose.bones[n].matrix.copy() for n in ORDER}
sc.frame_set(45)
for n in ORDER:
    arm.pose.bones[n].matrix=pose36[n]; bpy.context.view_layer.update()
rot("Chest",(1,0,0),-0.4); rot("Head",(1,0,0),0.4)
key_all(45)
act=arm.animation_data.action; fc=[]
try:
    for layer in act.layers:
        for strip in layer.strips: fc+=list(strip.channelbag.fcurves)
except Exception: pass
if not fc: fc=list(act.fcurves)
for c in fc:
    for kp in c.keyframe_points:
        kp.interpolation='BEZIER'; kp.handle_left_type='AUTO_CLAMPED'; kp.handle_right_type='AUTO_CLAMPED'
    c.update()
print("action range:", tuple(act.frame_range))
sc.frame_set(0); bpy.ops.wm.save_mainfile(); print("SAVED polish")
def select(objs):
    bpy.ops.object.select_all(action='DESELECT')
    for o in objs: o.select_set(True)
    bpy.context.view_layer.objects.active=objs[0]
def export(path,objs,**kw):
    select(objs)
    base=dict(filepath=path, export_format='GLB', use_selection=True, export_yup=True,
              export_apply=False, export_skins=True, export_def_bones=False)
    base.update(kw); bpy.ops.export_scene.gltf(**base)
    print("EXPORTED", path, os.path.getsize(path))
export(f"{CHAR}/HERO_01_RIGGED.glb",[arm,body], export_animations=True, export_animation_mode='ACTIONS',
       export_force_sampling=True, export_optimize_animation_size=False, export_materials='EXPORT')
export(f"{ANIM}/HERO_01_ANIMATIONS.glb",[arm,body], export_animations=True, export_animation_mode='ACTIONS',
       export_force_sampling=True, export_optimize_animation_size=False, export_materials='NONE')
arm.data.pose_position='REST'; bpy.context.view_layer.update()
print("weapon world @REST:", [round(float(x),5) for x in weapon.matrix_world.translation])
dup=weapon.copy(); dup.data=weapon.data.copy(); sc.collection.objects.link(dup)
dup.parent=None; dup.matrix_world=weapon.matrix_world.copy(); bpy.context.view_layer.update()
export(f"{WEAP}/HERO_01_WEAPON.glb",[dup], export_animations=False, export_materials='EXPORT')
bpy.data.objects.remove(dup, do_unlink=True)
arm.data.pose_position='POSE'
# roundtrip
bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.ops.import_scene.gltf(filepath=f"{CHAR}/HERO_01_RIGGED.glb")
sc=bpy.context.scene; sc.render.fps=30; sc.frame_start=0; sc.frame_end=45
for a in bpy.data.actions: print(" RT action", a.name, tuple(a.frame_range))
rt_arm=[o for o in bpy.data.objects if o.type=='ARMATURE'][0]
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
