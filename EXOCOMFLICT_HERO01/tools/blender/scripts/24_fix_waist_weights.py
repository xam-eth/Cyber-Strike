# SUPERSEDED gated iteration - measured failure, did NOT save (VALIDATION_REPORT 5.8). Applied fix: 31_fix_spine_field_FINAL.py
"""Fix waist shell separation (owner report: hole at left abdomen during aim).
Phase 1: scan for limb-dominated islands sitting in the torso/waist zone.
Phase 2: full cross-island pair-separation aggregation at F36 (pre-fix, in-blend).
Phase 3: nearest-vertex weight transfer for offender islands (+1 smoothing pass, top-4, renormalize).
Phase 4: re-run pair aggregation post-fix; save blend ONLY if waist-zone max growth <= 3mm."""
import bpy
import numpy as np
from mathutils import kdtree
PROJ="/home/user/Cyber-Strike/EXOCOMFLICT_HERO01"
bpy.ops.wm.open_mainfile(filepath=f"{PROJ}/blender/HERO_01_working.blend")
sc=bpy.context.scene
arm=bpy.data.objects["HERO_01_Armature"]; body=bpy.data.objects["HERO_01_BODY"]
me=body.data; n=len(me.vertices)
gnames=[g.name for g in body.vertex_groups]; ng=len(gnames)
print("BODY verts:", n, "groups:", ng)

# islands
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
print("ISLANDS:", len(uniq))

co0=np.empty(n*3); me.vertices.foreach_get("co", co0); P0=co0.reshape(-1,3)
W=np.zeros((len(uniq), ng)); cnt=np.zeros(len(uniq))
vertW=[None]*n
for v in me.vertices:
    i=island[v.index]; cnt[i]+=1
    w={gnames[g.group]: g.weight for g in v.groups}
    vertW[v.index]=w
    for g in v.groups: W[i,g.group]+=g.weight
W/=np.maximum(cnt,1)[:,None]
dom=[gnames[int(np.argmax(W[i]))] for i in range(len(uniq))]
cent=np.array([P0[island==i].mean(axis=0) for i in range(len(uniq))])
bmax=np.array([P0[island==i].max(axis=0) for i in range(len(uniq))])
bmin=np.array([P0[island==i].min(axis=0) for i in range(len(uniq))])
def wtxt(i):
    o=np.argsort(-W[i])[:3]
    return [(gnames[j], round(float(W[i,j]),3)) for j in o if W[i,j]>0.01]

# Phase 1: offender scan
LEG={"UpperLeg_L","UpperLeg_R","LowerLeg_L","LowerLeg_R","Foot_L","Foot_R","Toe_L","Toe_R"}
ARMLOW={"Forearm_L","Forearm_R","Hand_L","Hand_R","Weapon_R"}
cand=[]
for i in range(len(uniq)):
    c=cent[i]
    if dom[i] in LEG and c[2]>0.50 and bmax[i][2]>0.55: cand.append(i)
    elif dom[i] in ARMLOW and abs(c[0])<0.15 and abs(c[1])<0.13 and 0.45<c[2]<0.75: cand.append(i)
print("OFFENDER islands:", cand)
for i in cand:
    print(f"  isl{i}: {int(cnt[i])}v dom={dom[i]} top={wtxt(i)} cent={np.round(cent[i],3).tolist()} bbox_z=[{bmin[i][2]:.3f},{bmax[i][2]:.3f}] bbox_x=[{bmin[i][0]:+.3f},{bmax[i][0]:+.3f}]")

# Phase 2/4: pair separation aggregation at a frame
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
print("waist touch pairs:", len(pairs))
def pair_report(P, tag):
    d=np.linalg.norm(P[pv]-P[pp], axis=1); g=d-pd0
    agg={}
    for k in range(len(pv)):
        key=(min(int(island[pv[k]]),int(island[pp[k]])), max(int(island[pv[k]]),int(island[pp[k]])))
        if key not in agg or g[k]>agg[key][0]: agg[key]=(float(g[k]), P[int(pv[k])])
    worst=sorted(agg.items(), key=lambda kv:-kv[1][0])
    print(f"{tag}: max growth {worst[0][1][0]*1000:.2f}mm; pairs>3mm:{int((g>0.003).sum())} >6mm:{int((g>0.006).sum())}")
    for key,(gg,pos) in worst[:8]:
        if gg<0.0025: break
        print(f"   {key[0]}({dom[key[0]]}) vs {key[1]}({dom[key[1]]}): +{gg*1000:.1f}mm at ({pos[0]:+.3f},{pos[1]:+.3f},{pos[2]:.3f})")
    return float(g.max())
sc.frame_set(0)
pre=eval_pos(36); pre_max=pair_report(pre, "PRE-FIX F36")

# Phase 3: nearest-vertex weight transfer
candset=set(cand)
src_idx=np.array([i for i in range(n) if island[i] not in candset])
kds=kdtree.KDTree(len(src_idx))
for j,i in enumerate(src_idx): kds.insert(P0[i], int(i))
kds.balance()
newW={}
for i in cand:
    for v in np.nonzero(island==i)[0]:
        co_, sidx, dist = kds.find(P0[int(v)])
        newW[int(v)]=dict(vertW[int(sidx)])
# one smoothing iteration within each island
adj={}
for a,b in ev:
    a=int(a); b=int(b)
    if a in newW and b in newW and island[a]==island[b]:
        adj.setdefault(a,[]).append(b); adj.setdefault(b,[]).append(a)
sm={}
for v,w in newW.items():
    acc=dict(w)
    nbrs=adj.get(v,[])
    if nbrs:
        for u in nbrs:
            for k2,val in newW[u].items(): acc[k2]=acc.get(k2,0.0)+val/len(nbrs)
        acc={k2: 0.5*w.get(k2,0.0)+0.5*(acc[k2]-w.get(k2,0.0)) if k2 in w else 0.5*acc[k2] for k2 in acc}
        # simpler correct recompute:
        acc={}
        for k2 in set(w)|set().union(*[set(newW[u]) for u in nbrs]):
            acc[k2]=0.5*w.get(k2,0.0)+0.5*float(np.mean([newW[u].get(k2,0.0) for u in nbrs]))
    top=sorted(acc.items(), key=lambda kv:-kv[1])[:4]
    s=sum(vv for _,vv in top) or 1.0
    sm[v]={k2: vv/s for k2,vv in top if vv>1e-4}
# apply
vg_by_name={g.name: g for g in body.vertex_groups}
for v,w in sm.items():
    for g in body.vertex_groups: g.remove([v])
    for name,val in w.items(): vg_by_name[name].add([v], float(val), 'ADD')
me.update()
print("TRANSFER applied to verts:", len(sm))
for i in cand:
    idxs=np.nonzero(island==i)[0]
    agg={}
    for v in idxs:
        for k2,val in sm[int(v)].items(): agg[k2]=agg.get(k2,0.0)+val/len(idxs)
    print(f"  isl{i} NEW mean weights:", sorted(((k2,round(vv,3)) for k2,vv in agg.items()), key=lambda kv:-kv[1])[:4])

# Phase 4: verify + gated save
post=eval_pos(36); post_max=pair_report(post, "POST-FIX F36")
post45=eval_pos(45); pair_report(post45, "POST-FIX F45")
sc.frame_set(0); bpy.context.view_layer.update()
if post_max<=0.003:
    bpy.ops.wm.save_mainfile(); print("SAVED blend (max growth %.2fmm <= 3mm)"%(post_max*1000))
else:
    print("NOT SAVED: post-fix max growth %.2fmm > 3mm"%(post_max*1000))
print("DONE")
