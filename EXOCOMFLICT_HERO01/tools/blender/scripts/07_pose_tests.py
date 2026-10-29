"""Deformation pose tests on the working rig + bone-parent weapon to Weapon_R."""
import bpy, math, os
from mathutils import Matrix, Vector
PROJ="/home/user/Cyber-Strike/EXOCOMFLICT_HERO01"
REND=f"{PROJ}/screenshots/rig"; os.makedirs(REND, exist_ok=True)
bpy.ops.wm.open_mainfile(filepath=f"{PROJ}/blender/HERO_01_working.blend")
arm=bpy.data.objects["HERO_01_Armature"]; body=bpy.data.objects["HERO_01_BODY"]; weapon=bpy.data.objects["HERO_01_WEAPON"]
# bone-parent weapon to Weapon_R preserving current world transform (identity)
pb_w=arm.pose.bones["Weapon_R"]
weapon.parent=arm; weapon.parent_type='BONE'; weapon.parent_bone="Weapon_R"
weapon.matrix_parent_inverse=(arm.matrix_world @ pb_w.bone.matrix_local).inverted() @ weapon.matrix_world
bpy.context.view_layer.update()
print("weapon world after bone-parent (should be identity):", [round(float(x),4) for x in weapon.matrix_world.translation])
bpy.ops.wm.save_mainfile()
print("saved blend with weapon bone-parent")

def reset_pose():
    for pb in arm.pose.bones:
        pb.matrix=pb.bone.matrix_local.copy()
    bpy.context.view_layer.update()
def rot(name, axis, deg):
    pb=arm.pose.bones[name]
    head=pb.head.copy()
    M=Matrix.Translation(head) @ Matrix.Rotation(math.radians(deg),4,axis) @ Matrix.Translation(-head)
    pb.matrix=M @ pb.matrix
    bpy.context.view_layer.update()
X=(1,0,0); Z=(0,0,1)
# render setup
sc=bpy.context.scene
sc.render.engine="CYCLES"; sc.cycles.samples=16; sc.cycles.use_denoising=True; sc.cycles.device="CPU"
w=bpy.data.worlds.new("W"); sc.world=w; w.use_nodes=True
w.node_tree.nodes["Background"].inputs[0].default_value=(0.16,0.17,0.19,1); w.node_tree.nodes["Background"].inputs[1].default_value=0.9
sd=bpy.data.lights.new("Sun","SUN"); sd.energy=3; so=bpy.data.objects.new("Sun",sd); sc.collection.objects.link(so)
so.rotation_euler=(math.radians(52),math.radians(8),math.radians(-38))
bpy.ops.mesh.primitive_plane_add(size=8, location=(0,0,0)); gnd=bpy.context.active_object
gm=bpy.data.materials.new("Ground"); gm.use_nodes=True; gm.node_tree.nodes["Principled BSDF"].inputs["Base Color"].default_value=(0.23,0.24,0.27,1)
gnd.data.materials.append(gm)
cam=bpy.data.objects.new("Cam",bpy.data.cameras.new("Cam")); cam.data.lens=52; sc.collection.objects.link(cam); sc.camera=cam
arm.hide_render=True
def shoot(name,loc,target=(0,0,0.5)):
    cam.location=loc; cam.rotation_euler=(Vector(target)-Vector(loc)).to_track_quat('-Z','Y').to_euler()
    sc.render.resolution_x=700; sc.render.resolution_y=875
    sc.render.filepath=f"{REND}/{name}.png"; bpy.ops.render.render(write_still=True); print("RENDERED",name)
FRONT=(0,-2.15,0.55); SIDER=(-2.15,0,0.55); THREEQ=(-1.4,-1.4,0.68)
reset_pose(); shoot("pose_T0_neutral_front",FRONT); shoot("pose_T0_neutral_3q",THREEQ,(0,0,0.48))
reset_pose(); rot("Forearm_L",X,-65); rot("Forearm_R",X,-65); shoot("pose_T1_elbows_front",FRONT); shoot("pose_T1_elbows_sideR",SIDER)
reset_pose(); rot("LowerLeg_R",X,55); rot("LowerLeg_L",X,55); rot("UpperLeg_R",X,-18); rot("UpperLeg_L",X,-18); shoot("pose_T2_knees_front",FRONT); shoot("pose_T2_knees_sideR",SIDER)
reset_pose(); rot("UpperArm_R",X,-75); rot("UpperArm_L",X,-75); rot("Forearm_R",X,-20); rot("Forearm_L",X,-20); shoot("pose_T3_armraise_front",FRONT); shoot("pose_T3_armraise_sideR",SIDER)
reset_pose(); rot("Spine",X,-10); rot("Chest",Z,22); rot("UpperChest",Z,10); rot("Head",Z,-18); shoot("pose_T4_spine_front",FRONT); shoot("pose_T4_spine_3q",THREEQ,(0,0,0.48))
reset_pose(); rot("Neck",Z,16); rot("Head",Z,30); shoot("pose_T5_head_front",(-0.3,-0.85,0.88),(0.03,0,0.87))
reset_pose()
print("DONE")
