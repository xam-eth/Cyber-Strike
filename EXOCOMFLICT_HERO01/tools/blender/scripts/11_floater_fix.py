"""Detect and fix the floating island near right hip (elbow-pose displacement audit)."""
import bpy, math, os
import numpy as np
from mathutils import Matrix, Vector
PROJ="/home/user/Cyber-Strike/EXOCOMFLICT_HERO01"
OUT=f"{PROJ}/tools/out"; REND=f"{PROJ}/screenshots/rig"
bpy.ops.wm.open_mainfile(filepath=f"{PROJ}/blender/HERO_01_working.blend")
arm=bpy.data.objects["HERO_01_Armature"]; body=bpy.data.objects["HERO_01_BODY"]
m=body.data; nv=len(m.vertices)
co=np.empty(nv*3); m.vertices.foreach_get("co",co); bw=co.reshape(-1,3)
bisl=np.load(f"{OUT}/body_island_ids.npy")
DEFORM=[b.name for b in arm.data.bones if b.use_deform]
gi={g.name:g.index for g in body.vertex_groups}
W=np.zeros((nv,len(DEFORM)),dtype=np.float32); bmap={gi[b]:i for i,b in enumerate(DEFORM) if b in gi}
for v in m.vertices:
    for g in v.groups:
        if g.group in bmap: W[v.index,bmap[g.group]]=g.weight
ORDER=["Root","Hips","Spine","Chest","UpperChest","Neck","Head","Clavicle_R","UpperArm_R","Forearm_R","Hand_R","Weapon_R","Clavicle_L","UpperArm_L","Forearm_L","Hand_L","UpperLeg_R","LowerLeg_R","Foot_R","Toe_R","UpperLeg_L","LowerLeg_L","Foot_L","Toe_L"]
def reset_pose():
    for n in ORDER:
        pb=arm.pose.bones[n]; pb.matrix=pb.bone.matrix_local.copy(); bpy.context.view_layer.update()
def rot(name,axis,deg):
    pb=arm.pose.bones[name]; head=pb.head.copy()
    M=Matrix.Translation(head)@Matrix.Rotation(math.radians(deg),4,axis)@Matrix.Translation(-head)
    pb.matrix=M@pb.matrix; bpy.context.view_layer.update()
reset_pose(); rot("Forearm_R",(1,0,0),-65); rot("Forearm_L",(1,0,0),-65)
dg=bpy.context.evaluated_depsgraph_get(); ev=body.evaluated_get(dg); em=ev.to_mesh()
eco=np.empty(nv*3); em.vertices.foreach_get("co",eco); eco=eco.reshape(-1,3)
ev.to_mesh_clear()
rows=[]
for i in range(int(bisl.max()+1)):
    mask=bisl==i; c=bw[mask].mean(0); d=float(np.linalg.norm(eco[mask].mean(0)-c))
    avg=W[mask].mean(0); top=np.argsort(-avg)[:3]
    rows.append((i,int(mask.sum()),c,d,[(DEFORM[t],round(float(avg[t]),2)) for t in top]))
sus=[r for r in rows if r[3]>0.008 and r[2][2]<0.55 and r[2][0]>-0.24]
print("SUSPECT displaced lower-body islands in elbow pose:")
for r in sorted(sus,key=lambda r:-r[3]): print(f" isl={r[0]} v={r[1]} ctr={np.round(r[2],3).tolist()} disp={r[3]:.3f} topW={r[4]}")
# fix: reassign suspect islands to nearest among SPINE+same-side LEG chain
segs={n:(np.array(arm.data.bones[n].head_local),np.array(arm.data.bones[n].tail_local)) for n in DEFORM}
def seg_dist(P,a,b):
    ab=b-a; t=np.clip(((P-a)@ab)/max(ab@ab,1e-12),0,1)
    return np.linalg.norm(P-(a+np.outer(t,ab)),axis=1)
bidx={n:i for i,n in enumerate(DEFORM)}
fixed=[]
for r in sus:
    i=r[0]; mask=bisl==i; c=r[2]
    side="R" if c[0]<0.02 else "L"
    bones=["Hips","Spine",f"UpperLeg_{side}",f"LowerLeg_{side}"]
    D=np.stack([seg_dist(bw[mask],*segs[b]) for b in bones],axis=1)
    Wloc=(1.0/(D+0.004))**3; Wloc/=Wloc.sum(1,keepdims=True)
    W[mask]=0
    for k,b in enumerate(bones): W[mask,bidx[b]]=Wloc[:,k]
    fixed.append(i)
print("FIXED islands:",fixed)
if fixed:
    for bi,name in enumerate(DEFORM):
        g=body.vertex_groups[name]
        aff=np.flatnonzero(np.isin(bisl,np.array(fixed)))
        g.remove([int(x) for x in aff])
        sel=[int(vi) for vi in aff if W[vi,bi]>1e-4]
        for vi in sel: g.add([vi],float(W[vi,bi]),'REPLACE')
reset_pose(); bpy.ops.wm.save_mainfile(); print("SAVED")
# verify render T1 front
sc=bpy.context.scene
sc.render.engine="CYCLES"; sc.cycles.samples=14; sc.cycles.use_denoising=True; sc.cycles.device="CPU"
w=bpy.data.worlds.new("W"); sc.world=w; w.use_nodes=True
w.node_tree.nodes["Background"].inputs[0].default_value=(0.16,0.17,0.19,1); w.node_tree.nodes["Background"].inputs[1].default_value=0.9
sd=bpy.data.lights.new("Sun","SUN"); sd.energy=3; so=bpy.data.objects.new("Sun",sd); sc.collection.objects.link(so)
so.rotation_euler=(math.radians(52),math.radians(8),math.radians(-38))
bpy.ops.mesh.primitive_plane_add(size=8, location=(0,0,0)); gnd=bpy.context.active_object
gm=bpy.data.materials.new("Ground"); gm.use_nodes=True; gm.node_tree.nodes["Principled BSDF"].inputs["Base Color"].default_value=(0.23,0.24,0.27,1)
gnd.data.materials.append(gm)
cam=bpy.data.objects.new("Cam",bpy.data.cameras.new("Cam")); cam.data.lens=52; sc.collection.objects.link(cam); sc.camera=cam
arm.hide_render=True
rot("Forearm_L",(1,0,0),-65); rot("Forearm_R",(1,0,0),-65)
cam.location=(0,-2.15,0.55); cam.rotation_euler=(Vector((0,0,0.5))-Vector((0,-2.15,0.55))).to_track_quat('-Z','Y').to_euler()
sc.render.resolution_x=700; sc.render.resolution_y=875; sc.render.filepath=f"{REND}/v5_T1_elbows_front.png"
bpy.ops.render.render(write_still=True); print("RENDERED verify")
reset_pose(); print("DONE")
