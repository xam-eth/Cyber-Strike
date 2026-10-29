"""Quantitative shell-separation analysis on shipped HERO_01_RIGGED.glb. NOTE: v1 method -
k=10 nearest search saturates (1e9 sentinel leak); superseded by 23b pair-tracking."""
import bpy, os
import numpy as np
from mathutils import kdtree
PROJ="/home/user/Cyber-Strike/EXOCOMFLICT_HERO01"
bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.ops.import_scene.gltf(filepath=f"{PROJ}/assets/characters/HERO_01_RIGGED.glb")
sc=bpy.context.scene; sc.render.fps=30; sc.frame_start=0; sc.frame_end=45
body=max([o for o in bpy.data.objects if o.type=='MESH'], key=lambda o: len(o.data.vertices))
me=body.data; n=len(me.vertices); print("BODY", body.name, n, "verts, groups:", [g.name for g in body.vertex_groups])
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
def eval_pos(frame):
    sc.frame_set(frame); bpy.context.view_layer.update()
    dg=bpy.context.evaluated_depsgraph_get()
    em=body.evaluated_get(dg).to_mesh()
    p=np.empty(n*3, dtype=np.float64); em.vertices.foreach_get("co", p)
    body.evaluated_get(dg).to_mesh_clear()
    return p.reshape(-1,3)
P0=eval_pos(0)
band=(P0[:,2]>0.42)&(P0[:,2]<0.80)&(np.abs(P0[:,0])<0.20)&(np.abs(P0[:,1])<0.16)
band_idx=np.nonzero(band)[0]; print("BAND verts:", len(band_idx))
def build_kd(P):
    kd=kdtree.KDTree(n)
    for i,p in enumerate(P): kd.insert(p, i)
    kd.balance(); return kd
def nearest_other(kd, P, idxs):
    out=np.full(len(idxs), 1e9); other=np.full(len(idxs), -1)
    for j,i in enumerate(idxs):
        for (co, idx, dist) in kd.find_n(P[i], 10):
            if island[idx]!=island[i]:
                out[j]=dist; other[j]=idx; break
    return out, other
kd0=build_kd(P0)
d0, o0 = nearest_other(kd0, P0, band_idx)
seam = d0 < 0.004
seam_idx = band_idx[seam]; seam_d0 = d0[seam]
print(f"SEAM verts (d0<4mm norm): {len(seam_idx)}")
def island_weights(iid):
    idxs=np.nonzero(island==iid)[0]
    agg={}
    for vi in idxs:
        for g in me.vertices[int(vi)].groups:
            agg[g.group]=agg.get(g.group,0.0)+g.weight
    tot=[(body.vertex_groups[g].name, round(w/len(idxs),3)) for g,w in agg.items()]
    return sorted(tot, key=lambda t:-t[1])[:3], len(idxs)
for f in (12,18,24,30,36,45):
    P=eval_pos(f); kd=build_kd(P)
    dF, oF = nearest_other(kd, P, seam_idx)
    sep=dF-seam_d0
    print(f"FRAME {f}: sep max={sep.max()*1000:.1f}mm-norm (sentinel-contaminated, see 23b)")
print("DONE")
