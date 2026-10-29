"""Fix weapon parent offset; weights v2 with anatomical chain gating; re-run pose tests."""
import bpy, math, os, json
import numpy as np
from mathutils import Matrix, Vector
PROJ="/home/user/Cyber-Strike/EXOCOMFLICT_HERO01"
OUT=f"{PROJ}/tools/out"; REND=f"{PROJ}/screenshots/rig"
bpy.ops.wm.open_mainfile(filepath=f"{PROJ}/blender/HERO_01_working.blend")
arm=bpy.data.objects["HERO_01_Armature"]; body=bpy.data.objects["HERO_01_BODY"]; weapon=bpy.data.objects["HERO_01_WEAPON"]
# --- fix weapon bone-parent offset: force world = identity (original placement) ---
bpy.context.view_layer.update()
W=weapon.matrix_world.copy()
err=float(np.max(np.abs(np.array(W)-np.eye(4))))
print("weapon world err before:",err)
if err>1e-5:
    weapon.matrix_parent_inverse=weapon.matrix_parent_inverse @ W.inverted()
    bpy.context.view_layer.update()
    err2=float(np.max(np.abs(np.array(weapon.matrix_world)-np.eye(4))))
    print("weapon world err after:",err2)
# --- weights v2 ---
m=body.data; nv=len(m.vertices)
co=np.empty(nv*3); m.vertices.foreach_get("co",co); bw=co.reshape(-1,3)  # body at identity
bisl=np.load(f"{OUT}/body_island_ids.npy"); assert len(bisl)==nv
ne=len(m.edges); bedges=np.empty(ne*2,dtype=np.int64); m.edges.foreach_get("vertices",bedges); bedges=bedges.reshape(-1,2)
DEFORM=[b.name for b in arm.data.bones if b.use_deform]
segs={n:(np.array(arm.data.bones[n].head_local),np.array(arm.data.bones[n].tail_local)) for n in DEFORM}
CHAINS={"SPINE":["Hips","Spine","Chest","UpperChest","Neck","Head"],
 "ARM_R":["Clavicle_R","UpperArm_R","Forearm_R","Hand_R"],
 "ARM_L":["Clavicle_L","UpperArm_L","Forearm_L","Hand_L"],
 "LEG_R":["UpperLeg_R","LowerLeg_R","Foot_R","Toe_R"],
 "LEG_L":["UpperLeg_L","LowerLeg_L","Foot_L","Toe_L"]}
def seg_dist(P,a,b):
    ab=b-a; t=np.clip(((P-a)@ab)/max(ab@ab,1e-12),0,1)
    return np.linalg.norm(P-(a+np.outer(t,ab)),axis=1)
D=np.stack([seg_dist(bw,*segs[n]) for n in DEFORM],axis=1).astype(np.float32)
bidx={n:i for i,n in enumerate(DEFORM)}
allow=np.zeros((nv,len(DEFORM)),dtype=bool)
n_isl=int(bisl.max()+1); chain_counts={}
JOINT_BLEND_MM=0.045
for isl_i in range(n_isl):
    mask=bisl==isl_i; vv=bw[mask]; c=vv.mean(0)
    # distance from island center to each chain (min over its bones)
    dchain={}
    for ch,bones in CHAINS.items():
        dchain[ch]=min(float(seg_dist(c[None,:],*segs[b])[0]) for b in bones)
    primary=min(dchain,key=dchain.get)
    allowed=set(CHAINS[primary])
    # plus any bone within blend radius of island center (joint transitions)
    for n in DEFORM:
        if float(seg_dist(c[None,:],*segs[n])[0])<=JOINT_BLEND_MM: allowed.add(n)
    # belt band lock: waist ring follows pelvis, not thighs
    if 0.495<=c[2]<=0.555 and abs(c[0]-0.02)<0.16 and primary in ("LEG_R","LEG_L"):
        allowed=set(["Hips","Spine"])| {b for b in allowed if b in ("Hips","Spine")}
        primary="SPINE(belt)"
    chain_counts[primary]=chain_counts.get(primary,0)+1
    for n in allowed: allow[mask,bidx[n]]=True
print("island chain assignment:",chain_counts)
W=(1.0/(D+0.004))**3
W=np.where(allow,W,0)
# relative distance cap: drop influences far beyond nearest allowed bone
Dallow=np.where(allow,D,1e9); dmin=Dallow.min(1,keepdims=True)
W=np.where(D<=np.maximum(0.05,2.0*dmin),W,0)
W/=np.maximum(W.sum(1,keepdims=True),1e-12)
# head lock
hi=bidx["Head"]
for isl_i in range(n_isl):
    mask=bisl==isl_i
    if bw[mask].mean(0)[2]>=0.845: W[mask]=0; W[mask,hi]=1.0
# smoothing (intra-island via edges)
for _ in range(2):
    acc=W.copy(); deg=np.ones(nv,dtype=np.float32)
    np.add.at(acc,bedges[:,0],W[bedges[:,1]]*0.5); np.add.at(acc,bedges[:,1],W[bedges[:,0]]*0.5)
    np.add.at(deg,bedges[:,0],0.5); np.add.at(deg,bedges[:,1],0.5)
    W=(acc/deg[:,None]).astype(np.float32)
# rigidify small plates
for isl_i in range(n_isl):
    mask=bisl==isl_i; n=int(mask.sum())
    if n<8 or n>2500: continue
    vv=bw[mask]
    if (vv.max(0)-vv.min(0)).max()>0.09: continue
    avg=W[mask].mean(0); s=avg.sum()
    if s<=1e-9: continue
    avg/=s
    if avg.max()>0.72:
        k=int(avg.argmax()); avg=np.zeros_like(avg); avg[k]=1.0
    W[mask]=avg
idx=np.argpartition(-W,4,axis=1)[:,4:]; np.put_along_axis(W,idx,0,axis=1)
W=np.clip(W,0,None); W/=np.maximum(W.sum(1,keepdims=True),1e-12)
print("zero-weight:",int((W.sum(1)<=1e-6).sum()))
dom=W.argmax(1)
for bi,n in enumerate(DEFORM): print(f" dominant[{n}]={int((dom==bi).sum())}")
for g in list(body.vertex_groups): body.vertex_groups.remove(g)
for bi,name in enumerate(DEFORM):
    g=body.vertex_groups.new(name=name)
    sel=np.flatnonzero(W[:,bi]>1e-4)
    for vi in sel: g.add([int(vi)],float(W[vi,bi]),'REPLACE')
bpy.ops.wm.save_mainfile(); print("SAVED v2")
# --- pose tests (fixed reset: per-bone update, parents-first order) ---
ORDER=["Root","Hips","Spine","Chest","UpperChest","Neck","Head","Clavicle_R","UpperArm_R","Forearm_R","Hand_R","Weapon_R","Clavicle_L","UpperArm_L","Forearm_L","Hand_L","UpperLeg_R","LowerLeg_R","Foot_R","Toe_R","UpperLeg_L","LowerLeg_L","Foot_L","Toe_L"]
def reset_pose():
    for n in ORDER:
        pb=arm.pose.bones[n]; pb.matrix=pb.bone.matrix_local.copy(); bpy.context.view_layer.update()
def rot(name,axis,deg):
    pb=arm.pose.bones[name]; head=pb.head.copy()
    M=Matrix.Translation(head)@Matrix.Rotation(math.radians(deg),4,axis)@Matrix.Translation(-head)
    pb.matrix=M@pb.matrix; bpy.context.view_layer.update()
X=(1,0,0); Z=(0,0,1)
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
reset_pose(); shoot("v2_T0_neutral_front",FRONT); shoot("v2_T0_neutral_3q",THREEQ,(0,0,0.48))
reset_pose(); rot("Forearm_L",X,-65); rot("Forearm_R",X,-65); shoot("v2_T1_elbows_front",FRONT); shoot("v2_T1_elbows_sideR",SIDER)
reset_pose(); rot("LowerLeg_R",X,55); rot("LowerLeg_L",X,55); rot("UpperLeg_R",X,-18); rot("UpperLeg_L",X,-18); shoot("v2_T2_knees_front",FRONT); shoot("v2_T2_knees_sideR",SIDER)
reset_pose(); rot("UpperArm_R",X,-75); rot("UpperArm_L",X,-75); rot("Forearm_R",X,-20); rot("Forearm_L",X,-20); shoot("v2_T3_armraise_front",FRONT); shoot("v2_T3_armraise_sideR",SIDER)
reset_pose(); rot("Spine",X,-10); rot("Chest",Z,22); rot("UpperChest",Z,10); rot("Head",Z,-18); shoot("v2_T4_spine_front",FRONT); shoot("v2_T4_spine_3q",THREEQ,(0,0,0.48))
reset_pose(); rot("Neck",Z,16); rot("Head",Z,30); shoot("v2_T5_head_front",(-0.3,-0.85,0.88),(0.03,0,0.87))
reset_pose(); print("DONE")
