# SUPERSEDED gated iteration - measured failure, did NOT save (VALIDATION_REPORT 5.8). Applied fix: 31_fix_spine_field_FINAL.py
"""Fix v2 (revised after v1 gate-rejection): ONLY leg-dominated islands intruding into the
waist zone (the proven offender class) get weights, transferred ONLY from torso-clean
source vertices (Root/Hips/Spine/Chest/UpperChest influences only) in the waist band.
One smoothing pass, top-4, renormalize. Save blend ONLY if waist max pair-growth <=3mm
at F36/F45 and F0 displacement is exactly zero."""
import bpy
import numpy as np
from mathutils import kdtree
PROJ="/home/user/Cyber-Strike/EXOCOMFLICT_HERO01"
bpy.ops.wm.open_mainfile(filepath=f"{PROJ}/blender/HERO_01_working.blend")
sc=bpy.context.scene
arm=bpy.data.objects["HERO_01_Armature"]; body=bpy.data.objects["HERO_01_BODY"]
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
print("ISLANDS:", len(uniq), "verts:", n)

co0=np.empty(n*3); me.vertices.foreach_get("co", co0); P0=co0.reshape(-1,3)
W=np.zeros((len(uniq), ng)); cnt=np.zeros(len(uniq))
vertW=[None]*n
for v in me.vertices:
    i=island[v.index]; cnt[i]+=1
    vertW[v.index]={gnames[g.group]: float(g.weight) for g in v.groups}
    for g in v.groups: W[i,g.group]+=g.weight
W/=np.maximum(cnt,1)[:,None]
dom=[gnames[int(np.argmax(W[i]))] for i in range(len(uniq))]
cent=np.array([P0[island==i].mean(axis=0) for i in range(len(uniq))])
bmax=np.array([P0[island==i].max(axis=0) for i in range(len(uniq))])
def wtxt(i):
    o=np.argsort(-W[i])[:3]
    return [(gnames[j], round(float(W[i,j]),3)) for j in o if W[i,j]>0.01]

LEG={"UpperLeg_L","UpperLeg_R","LowerLeg_L","LowerLeg_R","Foot_L","Foot_R","Toe_L","Toe_R"}
print("SCAN (print-only) leg-dominated islands reaching bbox_max.z>0.55:")
for i in range(len(uniq)):
    if dom[i] in LEG and bmax[i][2]>0.55:
        print(f"  isl{i}: {int(cnt[i])}v dom={dom[i]} cent={np.round(cent[i],3).tolist()} top={wtxt(i)}")
cand=[i for i in range(len(uniq)) if dom[i] in LEG and cent[i][2]>0.50 and bmax[i][2]>0.55]
print("FIX TARGETS:", cand)

def eval_pos(frame):
    sc.frame_set(frame); bpy.context.view_layer.update()
    dg=bpy.context.evaluated_depsgraph_get()
    eo=body.evaluated_get(dg); em=eo.to_mesh()
    p=np.empty(n*3); em.vertices.foreach_get("co", p); eo.to_mesh_clear()
    return p.reshape(-1,3)
kd=kdtree.KDTree(n)
for i,p in enumerate(P0): kd.insert(p, i)
kd.balance()
band=np.nonzero((P0[:,2]>0.42)&(P0[:,2]<0.72)&(np.abs(P0[:,0])<0.20)&(np.abs(P0[:,1])<0.16))[0]
pairs=[]
for i in band:
    i=int(i)
    for (co_, idx, dist) in kd.find_n(P0[i], 10):
        if island[idx]!=island[i]:
            if dist<0.004: pairs.append((i, int(idx), float(dist)))
            break
KEEP={"Root","Hips","Spine","Chest","UpperChest","UpperLeg_L","UpperLeg_R"}
pairs=[p for p in pairs if dom[island[p[0]]] in KEEP and dom[island[p[1]]] in KEEP]
pv=np.array([p[0] for p in pairs]); pp=np.array([p[1] for p in pairs]); pd0=np.array([p[2] for p in pairs])
def pair_report(P, tag):
    d=np.linalg.norm(P[pv]-P[pp], axis=1); g=d-pd0
    agg={}
    for k in range(len(pv)):
        key=(min(int(island[pv[k]]),int(island[pp[k]])), max(int(island[pv[k]]),int(island[pp[k]])))
        if key not in agg or g[k]>agg[key][0]: agg[key]=(float(g[k]), P[int(pv[k])])
    worst=sorted(agg.items(), key=lambda kv:-kv[1][0])
    print(f"{tag}: max {worst[0][1][0]*1000:.2f}mm; >3mm:{int((g>0.003).sum())} >6mm:{int((g>0.006).sum())}")
    for key,(gg,pos) in worst[:10]:
        if gg<0.002: break
        print(f"   PAIR {key[0]}({dom[key[0]]}) vs {key[1]}({dom[key[1]]}): +{gg*1000:.1f}mm at ({pos[0]:+.3f},{pos[1]:+.3f},{pos[2]:.3f})")
    return float(g.max())
P0eval=eval_pos(0)
pre_max=pair_report(eval_pos(36), "PRE-FIX F36")

# strict torso-clean source pool
TORSO={"Root","Hips","Spine","Chest","UpperChest"}
candset=set(cand)
src=[]
for i in range(n):
    if island[i] in candset: continue
    if not (0.44<=P0[i][2]<=0.74): continue
    if set(vertW[i].keys())<=TORSO and vertW[i]: src.append(i)
src=np.array(src); print("torso-clean source verts:", len(src))
kds=kdtree.KDTree(len(src))
for i in src: kds.insert(P0[int(i)], int(i))
kds.balance()
newW={}
for i in cand:
    for v in np.nonzero(island==i)[0]:
        co_, sidx, dist = kds.find(P0[int(v)])
        newW[int(v)]=dict(vertW[int(sidx)])
adj={}
for a,b in ev:
    a=int(a); b=int(b)
    if a in newW and b in newW and island[a]==island[b]:
        adj.setdefault(a,[]).append(b); adj.setdefault(b,[]).append(a)
sm={}
for v,w in newW.items():
    nbrs=adj.get(v,[])
    if nbrs:
        keys=set(w)
        for u in nbrs: keys|=set(newW[u])
        acc={k2: 0.5*w.get(k2,0.0)+0.5*float(np.mean([newW[u].get(k2,0.0) for u in nbrs])) for k2 in keys}
    else:
        acc=dict(w)
    top=sorted(acc.items(), key=lambda kv:-kv[1])[:4]
    s=sum(vv for _,vv in top) or 1.0
    sm[v]={k2: vv/s for k2,vv in top if vv>1e-4}
vg={g.name: g for g in body.vertex_groups}
for v,w in sm.items():
    for g in body.vertex_groups: g.remove([v])
    for name,val in w.items(): vg[name].add([v], float(val), 'ADD')
me.update()
print("TRANSFER verts:", len(sm))
for i in cand:
    idxs=np.nonzero(island==i)[0]
    agg={}
    for v in idxs:
        for k2,val in sm[int(v)].items(): agg[k2]=agg.get(k2,0.0)+val/len(idxs)
    print(f"  isl{i} NEW mean:", sorted(((k2,round(vv,3)) for k2,vv in agg.items()), key=lambda kv:-kv[1]))

post36=pair_report(eval_pos(36), "POST-FIX F36")
post45=pair_report(eval_pos(45), "POST-FIX F45")
P0b=eval_pos(0)
disp0=float(np.linalg.norm(P0b-P0eval, axis=1).max())
print(f"F0 max displacement pre/post: {disp0*1000:.4f}mm")
sc.frame_set(0); bpy.context.view_layer.update()
if post36<=0.003 and post45<=0.003 and disp0<1e-6:
    bpy.ops.wm.save_mainfile(); print("SAVED blend")
else:
    print(f"NOT SAVED: post36={post36*1000:.2f} post45={post45*1000:.2f} disp0={disp0}")
print("DONE")
