"""Targeted fix: islands that detach in elbow pose AND are LEG-dominant in forearm band."""
import bpy, math
import numpy as np
from mathutils import Matrix, Vector
from scipy.spatial import cKDTree
PROJ="/home/user/Cyber-Strike/EXOCOMFLICT_HERO01"; OUT=f"{PROJ}/tools/out"; REND=f"{PROJ}/screenshots/rig"
bpy.ops.wm.open_mainfile(filepath=f"{PROJ}/blender/HERO_01_working.blend")
arm=bpy.data.objects["HERO_01_Armature"]; body=bpy.data.objects["HERO_01_BODY"]
m=body.data; nv=len(m.vertices)
co=np.empty(nv*3); m.vertices.foreach_get("co",co); bw=co.reshape(-1,3)
bisl=np.load(f"{OUT}/body_island_ids.npy"); n_isl=int(bisl.max()+1)
DEFORM=[b.name for b in arm.data.bones if b.use_deform]; bidx={n:i for i,n in enumerate(DEFORM)}
gi={g.name:g.index for g in body.vertex_groups}
W=np.zeros((nv,len(DEFORM)),dtype=np.float32); bmap={gi[b]:i for i,b in enumerate(DEFORM) if b in gi}
for v in m.vertices:
    for g in v.groups:
        if g.group in bmap: W[v.index,bmap[g.group]]=g.weight
segs={n:(np.array(arm.data.bones[n].head_local),np.array(arm.data.bones[n].tail_local)) for n in DEFORM}
def sd(P,a,b):
    ab=b-a; t=np.clip(((P-a)@ab)/max(ab@ab,1e-12),0,1)
    return np.linalg.norm(P-(a+np.outer(t,ab)),axis=1)
rest_c=np.stack([bw[bisl==i].mean(0) for i in range(n_isl)])
tree=cKDTree(rest_c); pairs=tree.query_pairs(r=0.035)
neigh={i:set() for i in range(n_isl)}
for a,b in pairs: neigh[a].add(b); neigh[b].add(a)
ORDER=["Root","Hips","Spine","Chest","UpperChest","Neck","Head","Clavicle_R","UpperArm_R","Forearm_R","Hand_R","Weapon_R","Clavicle_L","UpperArm_L","Forearm_L","Hand_L","UpperLeg_R","LowerLeg_R","Foot_R","Toe_R","UpperLeg_L","LowerLeg_L","Foot_L","Toe_L"]
def reset_pose():
    for n in ORDER:
        pb=arm.pose.bones[n]; pb.matrix=pb.bone.matrix_local.copy(); bpy.context.view_layer.update()
def rot(name,deg):
    pb=arm.pose.bones[name]; head=pb.head.copy()
    M=Matrix.Translation(head)@Matrix.Rotation(math.radians(deg),4,(1,0,0))@Matrix.Translation(-head)
    pb.matrix=M@pb.matrix; bpy.context.view_layer.update()
reset_pose(); rot("Forearm_R",-65); rot("Forearm_L",-65)
dg=bpy.context.evaluated_depsgraph_get(); ev=body.evaluated_get(dg); em=ev.to_mesh()
eco=np.empty(nv*3); em.vertices.foreach_get("co",eco); eco=eco.reshape(-1,3); ev.to_mesh_clear()
pc=np.stack([eco[bisl==i].mean(0) for i in range(n_isl)])
LEG={"UpperLeg_R","LowerLeg_R","Foot_R","Toe_R","UpperLeg_L","LowerLeg_L","Foot_L","Toe_L"}
targets=[]
for i in range(n_isl):
    if not neigh[i]: continue
    growth=float(np.median([np.linalg.norm(pc[i]-pc[j])-np.linalg.norm(rest_c[i]-rest_c[j]) for j in neigh[i]]))
    if growth<=0.015: continue
    c=rest_c[i]; dom=DEFORM[int(W[bisl==i].mean(0).argmax())]
    if dom not in LEG: continue
    side=dom[-1]
    if not (0.42<=c[2]<=0.56): continue
    if float(sd(c[None,:],*segs[f"Forearm_{side}"])[0])>0.060: continue
    targets.append(i); print(f"TARGET isl={i} v={int((bisl==i).sum())} ctr={np.round(c,3).tolist()} dom={dom} growth={growth:.3f}")
reset_pose()
for i in targets:
    mask=bisl==i; c=rest_c[i]; side="R" if c[0]<0.02 else "L"
    bones=[f"UpperArm_{side}",f"Forearm_{side}",f"Hand_{side}"]
    D=np.stack([sd(bw[mask],*segs[b]) for b in bones],axis=1)
    Wl=(1.0/(D+0.004))**3; Wl/=Wl.sum(1,keepdims=True)
    avg=Wl.mean(0); avg/=avg.sum()  # rigid island average, consistent with neighbors
    W[mask]=0
    for k,b in enumerate(bones): W[mask,bidx[b]]=avg[k]
    print(f" isl {i} -> {list(zip(bones,np.round(avg,2).tolist()))}")
if targets:
    aff=np.flatnonzero(np.isin(bisl,np.array(targets)))
    for bi,name in enumerate(DEFORM):
        g=body.vertex_groups[name]; g.remove([int(x) for x in aff])
        for vi in aff:
            if W[vi,bi]>1e-4: g.add([int(vi)],float(W[vi,bi]),'REPLACE')
    bpy.ops.wm.save_mainfile(); print("SAVED fix")
# verify renders
sc=bpy.context.scene
sc.render.engine="CYCLES"; sc.cycles.samples=14; sc.cycles.use_denoising=True; sc.cycles.device="CPU"
w=bpy.data.worlds.new("W"); sc.world=w; w.use_nodes=True
w.node_tree.nodes["Background"].inputs[0].default_value=(0.16,0.17,0.19,1); w.node_tree.nodes["Background"].inputs[1].default_value=0.9
sd2=bpy.data.lights.new("Sun","SUN"); sd2.energy=3; so=bpy.data.objects.new("Sun",sd2); sc.collection.objects.link(so)
so.rotation_euler=(math.radians(52),math.radians(8),math.radians(-38))
bpy.ops.mesh.primitive_plane_add(size=8, location=(0,0,0)); gnd=bpy.context.active_object
gm=bpy.data.materials.new("Ground"); gm.use_nodes=True; gm.node_tree.nodes["Principled BSDF"].inputs["Base Color"].default_value=(0.23,0.24,0.27,1)
gnd.data.materials.append(gm)
cam=bpy.data.objects.new("Cam",bpy.data.cameras.new("Cam")); cam.data.lens=52; sc.collection.objects.link(cam); sc.camera=cam
arm.hide_render=True
def shoot(name,loc,target=(0,0,0.5)):
    cam.location=loc; cam.rotation_euler=(Vector(target)-Vector(loc)).to_track_quat('-Z','Y').to_euler()
    sc.render.resolution_x=700; sc.render.resolution_y=875; sc.render.filepath=f"{REND}/{name}.png"
    bpy.ops.render.render(write_still=True); print("RENDERED",name)
rot("Forearm_L",-65); rot("Forearm_R",-65); shoot("v6_T1_elbows_front",(0,-2.15,0.55))
reset_pose(); rot("UpperArm_R",-75); rot("UpperArm_L",-75); rot("Forearm_R",-20); rot("Forearm_L",-20); shoot("v6_T3_armraise_front",(0,-2.15,0.55))
reset_pose(); print("DONE")
