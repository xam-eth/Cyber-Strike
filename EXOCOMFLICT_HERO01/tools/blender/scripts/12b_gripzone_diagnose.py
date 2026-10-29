import bpy
import numpy as np
PROJ="/home/user/Cyber-Strike/EXOCOMFLICT_HERO01"; OUT=f"{PROJ}/tools/out"
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
segs={n:(np.array(arm.data.bones[n].head_local),np.array(arm.data.bones[n].tail_local)) for n in DEFORM}
def sd(P,a,b):
    ab=b-a; t=np.clip(((P-a)@ab)/max(ab@ab,1e-12),0,1)
    return float(np.linalg.norm(P-(a+t*ab)))
print("Islands with center within 32mm of Hand_R/Forearm_R segs (grip zone) and their dominants:")
for i in range(int(bisl.max()+1)):
    mask=bisl==i; c=bw[mask].mean(0); avg=W[mask].mean(0); dom=DEFORM[int(avg.argmax())]
    dH=sd(c,*segs["Hand_R"]); dF=sd(c,*segs["Forearm_R"])
    if min(dH,dF)<0.032:
        top=np.argsort(-avg)[:3]
        print(f" isl={i} v={int(mask.sum())} ctr={np.round(c,3).tolist()} dom={dom} dHand={dH:.3f} dFore={dF:.3f} topW={[(DEFORM[t],round(float(avg[t]),2)) for t in top]}")
