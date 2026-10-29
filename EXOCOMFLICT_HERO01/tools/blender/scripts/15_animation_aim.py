"""Author Weapon_Raise_To_Aim (45f @30fps): analytic two-bone arm IK in world space,
weapon foregrip sampled for support hand, wrist pitch auto-corrected to level barrel."""
import bpy, math, os
import numpy as np
from mathutils import Matrix, Vector
PROJ="/home/user/Cyber-Strike/EXOCOMFLICT_HERO01"; REND=f"{PROJ}/screenshots/animation"; os.makedirs(REND, exist_ok=True)
bpy.ops.wm.open_mainfile(filepath=f"{PROJ}/blender/HERO_01_working.blend")
arm=bpy.data.objects["HERO_01_Armature"]; weapon=bpy.data.objects["HERO_01_WEAPON"]
sc=bpy.context.scene; sc.render.fps=30; sc.frame_start=0; sc.frame_end=45
ORDER=["Root","Hips","Spine","Chest","UpperChest","Neck","Head","Clavicle_R","UpperArm_R","Forearm_R","Hand_R","Weapon_R","Clavicle_L","UpperArm_L","Forearm_L","Hand_L","UpperLeg_R","LowerLeg_R","Foot_R","Toe_R","UpperLeg_L","LowerLeg_L","Foot_L","Toe_L"]
for pb in arm.pose.bones: pb.rotation_mode='QUATERNION'
def reset_pose():
    for n in ORDER:
        pb=arm.pose.bones[n]; pb.matrix=pb.bone.matrix_local.copy(); bpy.context.view_layer.update()
def rot(name,axis,deg):
    if abs(deg)<1e-9: return
    pb=arm.pose.bones[name]; head=pb.head.copy()
    M=Matrix.Translation(head)@Matrix.Rotation(math.radians(deg),4,axis)@Matrix.Translation(-head)
    pb.matrix=M@pb.matrix; bpy.context.view_layer.update()
def aim_bone(name,target):
    pb=arm.pose.bones[name]; head=pb.head.copy()
    cur=(pb.tail-head).normalized(); des=(Vector(target)-head).normalized()
    q=cur.rotation_difference(des)
    M=Matrix.Translation(head)@q.to_matrix().to_4x4()@Matrix.Translation(-head)
    pb.matrix=M@pb.matrix; bpy.context.view_layer.update()
def solve_elbow(S,W,L1,L2,pole):
    S,W,pole=Vector(S),Vector(W),Vector(pole)
    d=max(min((W-S).length,(L1+L2)*0.999),abs(L1-L2)*1.001)
    axis=(W-S).normalized()
    a=(L1*L1-L2*L2+d*d)/(2*d); h=math.sqrt(max(L1*L1-a*a,0.0))
    mid=S+axis*a
    perp=pole-mid; perp-=axis*perp.dot(axis)
    if perp.length<1e-6: perp=Vector((0,0,-1))
    return mid+perp.normalized()*h
LEN={n:arm.pose.bones[n].bone.length for n in ["UpperArm_R","Forearm_R","UpperArm_L","Forearm_L"]}
def pose_arm(side,wrist,pole_off):
    S=arm.pose.bones[f"UpperArm_{side}"].head.copy()
    E=solve_elbow(S,Vector(wrist),LEN[f"UpperArm_{side}"],LEN[f"Forearm_{side}"],S+Vector(pole_off))
    aim_bone(f"UpperArm_{side}",E); aim_bone(f"Forearm_{side}",Vector(wrist))
    return E
X=(1,0,0); Z=(0,0,1)
def pose_spine(a):
    rot("Spine",X,-4*a); rot("Chest",Z,-10*a); rot("Chest",X,-2*a); rot("UpperChest",Z,-6*a)
    rot("Neck",Z,9*a); rot("Neck",X,-5*a); rot("Head",Z,7*a); rot("Head",X,-7*a)
FG0=Vector((-0.215,-0.062,0.315)); GRIP0=Vector((-0.192,-0.033,0.452))
MZ0=Vector((-0.238,-0.080,0.205)); RC0=Vector((-0.198,-0.045,0.50))
DIR_REST=(MZ0-RC0).normalized()
def barrel_dir():
    bpy.context.view_layer.update()
    return (weapon.matrix_world.to_3x3()@DIR_REST).normalized()
WR={0:tuple(arm.pose.bones["Hand_R"].bone.head_local),8:(-0.175,-0.05,0.50),18:(-0.12,-0.12,0.62),28:(-0.06,-0.13,0.70),36:(-0.035,-0.132,0.712),45:(-0.035,-0.132,0.712)}
AMT={0:0.0,8:0.22,18:0.55,28:0.88,36:1.0,45:1.0}
POLE_R=(-0.18,0.12,-0.30); POLE_L=(0.20,0.10,-0.30)
def align_wrist(amount):
    from mathutils import Quaternion
    tgt=Vector((0,-1,0))
    for _ in range(2):
        d=barrel_dir(); q=d.rotation_difference(tgt)
        q=Quaternion((1,0,0,0)).slerp(q,amount)
        pb=arm.pose.bones["Hand_R"]; head=pb.head.copy()
        M=Matrix.Translation(head)@q.to_matrix().to_4x4()@Matrix.Translation(-head)
        pb.matrix=M@pb.matrix; bpy.context.view_layer.update()
    d=barrel_dir(); print(f" align({amount}) -> barrel {tuple(round(float(x),3) for x in d)}")
RAMP={0:0.0,8:0.1,18:0.35,28:0.85,36:1.0,45:1.0}
# action setup
if arm.animation_data is None: arm.animation_data_create()
for a in list(bpy.data.actions):
    if a.name.startswith("Weapon_Raise_To_Aim"): bpy.data.actions.remove(a)
act=bpy.data.actions.new("Weapon_Raise_To_Aim"); act.use_fake_user=True
arm.animation_data.action=act
try:
    if len(act.slots)==0: act.slots.new(id_type='OBJECT', name=arm.name)
    arm.animation_data.action_slot=act.slots[0]
except Exception as e: print("slot setup:",e)
def key_bones(names,frame):
    ok=0
    for n in names:
        pb=arm.pose.bones[n]
        ok+=bool(pb.keyframe_insert("location",frame=frame)); ok+=bool(pb.keyframe_insert("rotation_quaternion",frame=frame))
    return ok
# STEP A: spine + right arm (+ all bones keyed)
for K in [0,8,18,28,36,45]:
    sc.frame_set(K); reset_pose(); pose_spine(AMT[K]); pose_arm("R",WR[K],POLE_R); align_wrist(RAMP[K])
    n=key_bones(ORDER,K); print(f"frame {K}: keyed {n}")
# STEP B: sample foregrip world positions
FG={}
for F in [18,24,28,32,36,45]:
    sc.frame_set(F); bpy.context.view_layer.update()
    FG[F]=weapon.matrix_world@FG0; print(f"FG[{F}]={tuple(round(float(x),3) for x in FG[F])}")
# STEP C: left arm
LW0=Vector(arm.pose.bones["Hand_L"].bone.head_local)
def lerpv(a,b,t): return a+(b-a)*t
LTGT={0:LW0, 8:lerpv(LW0,Vector((0.18,-0.04,0.44)),0.6), 18:lerpv(LW0,FG[18],0.65), 24:FG[24], 28:FG[28], 32:FG[32], 36:FG[36], 45:FG[45]}
for F in [0,8,18,24,28,32,36,45]:
    sc.frame_set(F); pose_arm("L",LTGT[F],POLE_L)
    n=key_bones(["Clavicle_L","UpperArm_L","Forearm_L","Hand_L"],F); print(f"left frame {F}: keyed {n}")
# interpolation: auto-clamped bezier
fc=[]
try:
    for layer in act.layers:
        for strip in layer.strips: fc+=list(strip.channelbag.fcurves)
except Exception as e: print("fcurve enum:",e)
if not fc:
    try: fc=list(act.fcurves)
    except Exception as e: print("legacy fcurves:",e)
print("FCURVES:",len(fc))
for c in fc:
    for kp in c.keyframe_points:
        kp.interpolation='BEZIER'; kp.handle_left_type='AUTO_CLAMPED'; kp.handle_right_type='AUTO_CLAMPED'
    c.update()
# validation samples
for F in [0,12,24,36,45]:
    sc.frame_set(F); bpy.context.view_layer.update()
    bd=barrel_dir(); mz=weapon.matrix_world@MZ0
    grip_w=weapon.matrix_world@GRIP0; fg_w=weapon.matrix_world@FG0
    hr=arm.pose.bones["Hand_R"].head.copy(); hl=arm.pose.bones["Hand_L"].head.copy()
    print(f"F{F}: barrel={tuple(round(float(x),3) for x in bd)} muzzle={tuple(round(float(x),3) for x in mz)} Rhand->grip={float((hr-grip_w).length):.3f} Lhand->foregrip={float((hl-fg_w).length):.3f}")
sc.frame_set(0)
bpy.ops.wm.save_mainfile(); print("SAVED with animation")
# renders
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
def shoot(name,frame,loc,target=(0,0,0.5),rx=700,ry=875,lens=52):
    sc.frame_set(frame); cam.data.lens=lens; cam.location=loc
    cam.rotation_euler=(Vector(target)-Vector(loc)).to_track_quat('-Z','Y').to_euler()
    sc.render.resolution_x=rx; sc.render.resolution_y=ry; sc.render.filepath=f"{REND}/{name}.png"
    bpy.ops.render.render(write_still=True); print("RENDERED",name)
FRONT=(0,-2.15,0.55); SIDER=(-2.15,0,0.55); THREEQ=(-1.4,-1.4,0.68)
for F in [0,12,24,36]:
    shoot(f"aim_F{F:02d}_front",F,FRONT); shoot(f"aim_F{F:02d}_sideR",F,SIDER); shoot(f"aim_F{F:02d}_3q",F,THREEQ,(0,0,0.48))
shoot("aim_F36_closeup",36,(-0.55,-0.75,0.85),(-0.05,-0.18,0.71),800,800,55)
sc.frame_set(0); print("DONE")
