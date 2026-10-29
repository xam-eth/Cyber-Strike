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
ARM=["Clavicle_R","UpperArm_R","Forearm_R","Hand_R","Clavicle_L","UpperArm_L","Forearm_L","Hand_L"]
LEG=["UpperLeg_R","LowerLeg_R","Foot_R","Toe_R","UpperLeg_L","LowerLeg_L","Foot_L","Toe_L"]
SPINE=["Hips","Spine","Chest","UpperChest","Neck","Head"]
print("FLAG = dominant ARM but center closer to LEG/SPINE than ARM (z<0.55), or dominant LEG closer to ARM:")
for i in range(int(bisl.max()+1)):
    mask=bisl==i; c=bw[mask].mean(0); avg=W[mask].mean(0); dom=DEFORM[int(avg.argmax())]
    dA=min(sd(c,*segs[b]) for b in ARM); dL=min(sd(c,*segs[b]) for b in LEG); dS=min(sd(c,*segs[b]) for b in SPINE)
    flag=None
    if dom in ARM and c[2]<0.55 and min(dL,dS) < dA-0.004: flag="ARM-dominant but LEG/SPINE nearer"
    if dom in LEG and c[2]>0.40 and dA < dL-0.004: flag="LEG-dominant but ARM nearer"
    if flag:
        top=np.argsort(-avg)[:3]
        print(f" isl={i} v={int(mask.sum())} ctr={np.round(c,3).tolist()} dom={dom} dARM={dA:.3f} dLEG={dL:.3f} dSPINE={dS:.3f} topW={[(DEFORM[t],round(float(avg[t]),2)) for t in top]} :: {flag}")
print("DIAGNOSE DONE (no changes saved)")
