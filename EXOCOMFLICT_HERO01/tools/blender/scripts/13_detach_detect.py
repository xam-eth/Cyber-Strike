"""Find islands that detach from rest-neighbors in arm poses (floater identification)."""
import bpy, math
import numpy as np
from mathutils import Matrix
from scipy.spatial import cKDTree
PROJ="/home/user/Cyber-Strike/EXOCOMFLICT_HERO01"; OUT=f"{PROJ}/tools/out"
bpy.ops.wm.open_mainfile(filepath=f"{PROJ}/blender/HERO_01_working.blend")
arm=bpy.data.objects["HERO_01_Armature"]; body=bpy.data.objects["HERO_01_BODY"]
m=body.data; nv=len(m.vertices)
co=np.empty(nv*3); m.vertices.foreach_get("co",co); bw=co.reshape(-1,3)
bisl=np.load(f"{OUT}/body_island_ids.npy"); n_isl=int(bisl.max()+1)
DEFORM=[b.name for b in arm.data.bones if b.use_deform]
gi={g.name:g.index for g in body.vertex_groups}
W=np.zeros((nv,len(DEFORM)),dtype=np.float32); bmap={gi[b]:i for i,b in enumerate(DEFORM) if b in gi}
for v in m.vertices:
    for g in v.groups:
        if g.group in bmap: W[v.index,bmap[g.group]]=g.weight
rest_c=np.stack([bw[bisl==i].mean(0) for i in range(n_isl)])
tree=cKDTree(rest_c)
pairs=tree.query_pairs(r=0.035)
neigh={i:set() for i in range(n_isl)}
for a,b in pairs: neigh[a].add(b); neigh[b].add(a)
ORDER=["Root","Hips","Spine","Chest","UpperChest","Neck","Head","Clavicle_R","UpperArm_R","Forearm_R","Hand_R","Weapon_R","Clavicle_L","UpperArm_L","Forearm_L","Hand_L","UpperLeg_R","LowerLeg_R","Foot_R","Toe_R","UpperLeg_L","LowerLeg_L","Foot_L","Toe_L"]
def reset_pose():
    for n in ORDER:
        pb=arm.pose.bones[n]; pb.matrix=pb.bone.matrix_local.copy(); bpy.context.view_layer.update()
def rot(name,axis,deg):
    pb=arm.pose.bones[name]; head=pb.head.copy()
    M=Matrix.Translation(head)@Matrix.Rotation(math.radians(deg),4,axis)@Matrix.Translation(-head)
    pb.matrix=M@pb.matrix; bpy.context.view_layer.update()
def eval_centers():
    dg=bpy.context.evaluated_depsgraph_get(); ev=body.evaluated_get(dg); em=ev.to_mesh()
    eco=np.empty(nv*3); em.vertices.foreach_get("co",eco); eco=eco.reshape(-1,3); ev.to_mesh_clear()
    return np.stack([eco[bisl==i].mean(0) for i in range(n_isl)])
for label,rots in [("T1_elbows",[("Forearm_R",-65),("Forearm_L",-65)]),("T3_armraise",[("UpperArm_R",-75),("UpperArm_L",-75),("Forearm_R",-20),("Forearm_L",-20)])]:
    reset_pose()
    for n,d in rots: rot(n,(1,0,0),d)
    pc=eval_centers()
    print(f"== {label}: detached islands (median neighbor-distance growth > 15mm) ==")
    for i in range(n_isl):
        if not neigh[i]: continue
        growth=np.median([np.linalg.norm(pc[i]-pc[j])-np.linalg.norm(rest_c[i]-rest_c[j]) for j in neigh[i]])
        if growth>0.015:
            avg=W[bisl==i].mean(0); top=np.argsort(-avg)[:4]
            print(f" isl={i} v={int((bisl==i).sum())} restCtr={np.round(rest_c[i],3).tolist()} growth={growth:.3f} topW={[(DEFORM[t],round(float(avg[t]),2)) for t in top]}")
reset_pose(); print("DONE (no changes)")
