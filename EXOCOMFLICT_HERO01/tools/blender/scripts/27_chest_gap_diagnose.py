# Read-only diagnostic supporting VALIDATION_REPORT 5.8 (no modifications).
"""Diagnostic (read-only): PRE-fix true-gap values for the pairs that remained worst after
v3 gradient + weight composition of involved islands (are seam verts torso-clean?)."""
import bpy
import numpy as np
from mathutils import kdtree
PROJ="/home/user/Cyber-Strike/EXOCOMFLICT_HERO01"
bpy.ops.wm.open_mainfile(filepath=f"{PROJ}/blender/HERO_01_working.blend")
sc=bpy.context.scene
body=bpy.data.objects["HERO_01_BODY"]; me=body.data; n=len(me.vertices)
gnames=[g.name for g in body.vertex_groups]; ng=len(gnames)
ne=len(me.edges); ev=np.empty(ne*2, dtype=np.int64)
me.edges.foreach_get("vertices", ev); ev=ev.reshape(-1,2)
parent=np.arange(n, dtype=np.int64)
def find(a):
    while parent[a]!=a:
        parent[a]=parent[parent[a]]; a=parent[a]
    return a
for a,b in ev:
    ra,rb=find(int(a)),find(int(b))
    if ra!=rb: parent[ra]=rb
roots=np.array([find(i) for i in range(n)])
uniq, island=np.unique(roots, return_inverse=True)
co0=np.empty(n*3); me.vertices.foreach_get("co", co0); P0=co0.reshape(-1,3)
vertW=[None]*n; W=np.zeros((len(uniq), ng)); cnt=np.zeros(len(uniq))
for v in me.vertices:
    i=island[v.index]; cnt[i]+=1
    vertW[v.index]={gnames[g.group]: float(g.weight) for g in v.groups}
    for g in v.groups: W[i,g.group]+=g.weight
W/=np.maximum(cnt,1)[:,None]
dom=[gnames[int(np.argmax(W[i]))] for i in range(len(uniq))]
TORSO={"Root","Hips","Spine","Chest","UpperChest"}
for iid in (71,102,104,113,132,212,214,25):
    idxs=np.nonzero(island==iid)[0]
    o=np.argsort(-W[iid])[:5]
    top=[(gnames[j], round(float(W[iid,j]),3)) for j in o if W[iid,j]>0.005]
    cleanfrac=float(np.mean([set(vertW[int(v)].keys())<=TORSO for v in idxs]))
    cen=P0[idxs].mean(axis=0); mn=P0[idxs].min(axis=0); mx=P0[idxs].max(axis=0)
    print(f"ISL {iid}: {len(idxs)}v dom={dom[iid]} top={top} cleanfrac={cleanfrac:.2f} cent={np.round(cen,3).tolist()} zrange=[{mn[2]:.3f},{mx[2]:.3f}] xrange=[{mn[0]:+.3f},{mx[0]:+.3f}] yrange=[{mn[1]:+.3f},{mx[1]:+.3f}]")

def eval_pos(frame):
    sc.frame_set(frame); bpy.context.view_layer.update()
    dg=bpy.context.evaluated_depsgraph_get()
    eo=body.evaluated_get(dg); em=eo.to_mesh()
    p=np.empty(n*3); em.vertices.foreach_get("co", p); eo.to_mesh_clear()
    return p.reshape(-1,3)
def build_kd(P):
    kd=kdtree.KDTree(n)
    for i,p in enumerate(P): kd.insert(p, i)
    kd.balance(); return kd
kd0=build_kd(P0)
band=np.nonzero((P0[:,2]>0.42)&(P0[:,2]<0.72)&(np.abs(P0[:,0])<0.20)&(np.abs(P0[:,1])<0.16))[0]
probes=[]
for i in band:
    i=int(i)
    for (co_, idx, dist) in kd0.find_n(P0[i], 10):
        if island[idx]!=island[i]:
            if dist<0.004: probes.append(i)
            break
probes=np.array(probes)
def nearest_other(kd, P, idxs, k=40):
    out=np.full(len(idxs), 1e9); other=np.full(len(idxs), -1)
    for j,i in enumerate(idxs):
        for (co_, idx, dist) in kd.find_n(P[int(i)], k):
            if island[idx]!=island[int(i)]:
                out[j]=dist; other[j]=idx; break
    return out, other
d0N,_=nearest_other(kd0, P0, probes)
P36=eval_pos(36); kd36=build_kd(P36)
dN,oN=nearest_other(kd36, P36, probes)
ggap=dN-d0N
WANT=[(71,102),(71,104),(102,104),(113,132),(212,214),(25,132)]
for (a,b) in WANT:
    best=-1; bk=-1
    for k in range(len(probes)):
        if oN[k]<0: continue
        key=(min(int(island[probes[k]]),int(island[oN[k]])), max(int(island[probes[k]]),int(island[oN[k]])))
        if key==(a,b) and ggap[k]>best: best=float(ggap[k]); bk=k
    if bk>=0:
        v=int(probes[bk]); u=int(oN[bk])
        print(f"PRE GAP {a}v{b}: +{best*1000:.2f}mm | probe v{v} isl{island[v]} rest={np.round(P0[v],3).tolist()} W={ {k2:round(vv,3) for k2,vv in vertW[v].items()} } clean={set(vertW[v])<=TORSO} || nearest v{u} isl{island[u]} rest={np.round(P0[u],3).tolist()} W={ {k2:round(vv,3) for k2,vv in vertW[u].items()} } clean={set(vertW[u])<=TORSO}")
    else:
        print(f"PRE GAP {a}v{b}: no probe pair found")
print("DONE")
