"""Focused hunt at FRONT-LEFT abdomen/hip (all doms): (1) true-gap worst pairs for probes in the
front-left box; (2) vertex-level arm-weight scan in the box; (3) per-island internal edge-stretch."""
import bpy
import numpy as np
from mathutils import kdtree
PROJ="/home/user/Cyber-Strike/EXOCOMFLICT_HERO01"
bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.ops.import_scene.gltf(filepath=f"{PROJ}/assets/characters/HERO_01_RIGGED.glb")
sc=bpy.context.scene; sc.render.fps=30; sc.frame_start=0; sc.frame_end=45
body=max([o for o in bpy.data.objects if o.type=='MESH'], key=lambda o: len(o.data.vertices))
me=body.data; n=len(me.vertices)
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
vertW=[None]*n; W=np.zeros((len(uniq), ng)); cnt=np.zeros(len(uniq))
for v in me.vertices:
    i=island[v.index]; cnt[i]+=1
    vertW[v.index]={gnames[g.group]: float(g.weight) for g in v.groups}
    for g in v.groups: W[i,g.group]+=g.weight
W/=np.maximum(cnt,1)[:,None]
dom=[gnames[int(np.argmax(W[i]))] for i in range(len(uniq))]
def wtxt(i,k=4):
    o=np.argsort(-W[i])[:k]
    return [(gnames[j], round(float(W[i,j]),3)) for j in o if W[i,j]>0.005]
def eval_pos(frame):
    sc.frame_set(frame); bpy.context.view_layer.update()
    dg=bpy.context.evaluated_depsgraph_get()
    eo=body.evaluated_get(dg); em=eo.to_mesh()
    p=np.empty(n*3); em.vertices.foreach_get("co", p); eo.to_mesh_clear()
    return p.reshape(-1,3)
P0=eval_pos(0); P36=eval_pos(36); P45=eval_pos(45)
ARM={"Clavicle_L","Clavicle_R","UpperArm_L","UpperArm_R","Forearm_L","Forearm_R","Hand_L","Hand_R","Weapon_R"}
def inbox(P, x0,x1,y0,y1,z0,z1):
    return (P[:,0]>=x0)&(P[:,0]<=x1)&(P[:,1]>=y0)&(P[:,1]<=y1)&(P[:,2]>=z0)&(P[:,2]<=z1)
FL=inbox(P0, 0.03,0.17,-0.12,-0.05,0.44,0.65)
print("front-left box verts:", int(FL.sum()))
print("--- vertex-level ARM-weight scan in front-left box (arm weight sum>0.10) ---")
from collections import Counter
bad=Counter()
for v in np.nonzero(FL)[0]:
    s=sum(w for bn,w in vertW[int(v)].items() if bn in ARM)
    if s>0.10: bad[int(island[v])]+=1
for iid,c in bad.most_common(15):
    print(f" isl{iid}: {c} verts w/ arm>0.10 | dom={dom[iid]} top={wtxt(iid)} totalverts={int(cnt[iid])}")
if not bad: print(" (none)")
def build_kd(P):
    kd=kdtree.KDTree(n)
    for i,p in enumerate(P): kd.insert(p, i)
    kd.balance(); return kd
CAP=0.035
def nearest_other(kd, P, idxs, k=40):
    out=np.full(len(idxs), CAP); other=np.full(len(idxs), -1)
    for j,i in enumerate(idxs):
        i=int(i); found=False
        for (co_, idx, dist) in kd.find_n(P[i], k):
            if island[idx]!=island[i]: out[j]=dist; other[j]=idx; found=True; break
        if not found:
            best=CAP; bi=-1
            for (co_, idx, dist) in kd.find_range(P[i], CAP):
                if island[idx]!=island[i] and dist<best: best=dist; bi=idx
            if bi>=0: out[j]=best; other[j]=bi
    return out, other
kd0=build_kd(P0)
probes=np.nonzero(FL)[0]
d0N,o0=nearest_other(kd0, P0, probes)
keep=d0N<0.006
probes=probes[keep]; d0N=d0N[keep]
print("front-left seam probes (d0N<6mm):", len(probes))
for P,tag in ((P36,"F36"),(P45,"F45")):
    kd=build_kd(P)
    dN,oN=nearest_other(kd, P, probes)
    g=dN-d0N
    print(f"--- {tag} worst true-gap probes in front-left box ---")
    for k in np.argsort(-g)[:15]:
        v=int(probes[k]); u=int(oN[k]) if oN[k]>=0 else -1
        print(f"  +{g[k]*1000:5.1f}mm v{v} isl{int(island[v])}({dom[int(island[v])]}) rest=({P0[v][0]:+.3f},{P0[v][1]:+.3f},{P0[v][2]:.3f}) W={ {a:round(b,2) for a,b in vertW[v].items()} } -> isl{int(island[u]) if u>=0 else -1}({dom[int(island[u])] if u>=0 else '?'}) posed=({P[v][0]:+.3f},{P[v][1]:+.3f},{P[v][2]:.3f})")
print("--- per-island INTERNAL edge stretch (torso box islands) F36/F0 ---")
e0=np.linalg.norm(P0[ev[:,0]]-P0[ev[:,1]], axis=1)
e36=np.linalg.norm(P36[ev[:,0]]-P36[ev[:,1]], axis=1)
ratio=np.where(e0>1e-7, e36/np.maximum(e0,1e-7), 1.0)
isl_e=island[ev[:,0]]
mx=np.zeros(len(uniq)); np.maximum.at(mx, isl_e, ratio)
cent=np.array([P0[island==i].mean(axis=0) for i in range(len(uniq))])
order=np.argsort(-mx)
shown=0
for i in order:
    c=cent[i]
    if not (0.40<=c[2]<=0.80 and abs(c[0])<=0.20 and abs(c[1])<=0.16): continue
    if mx[i]<1.15: break
    print(f" isl{int(i)}: maxEdgeRatio={mx[i]:.2f} {int(cnt[i])}v dom={dom[i]} top={wtxt(int(i))} cent=({c[0]:+.3f},{c[1]:+.3f},{c[2]:.3f})")
    shown+=1
    if shown>=15: break
print("DONE")
