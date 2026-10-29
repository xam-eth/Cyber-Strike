"""Pair-tracking shell-separation analysis (fixed method): for vertex pairs that touch
across an island boundary at rest in the waist/abdomen zone, track pair distance growth
across frames; aggregate worst island pairs with their dominant bone weights."""
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
print("ISLANDS:", len(uniq))
W=np.zeros((len(uniq), ng)); cnt=np.zeros(len(uniq))
for v in me.vertices:
    i=island[v.index]; cnt[i]+=1
    for g in v.groups: W[i,g.group]+=g.weight
W/=np.maximum(cnt,1)[:,None]
dom=np.array([gnames[int(np.argmax(W[i]))] for i in range(len(uniq))])
def wtxt(i):
    o=np.argsort(-W[i])[:3]
    return [(gnames[j], round(float(W[i,j]),3)) for j in o if W[i,j]>0.01]
def eval_pos(frame):
    sc.frame_set(frame); bpy.context.view_layer.update()
    dg=bpy.context.evaluated_depsgraph_get()
    evobj=body.evaluated_get(dg); em=evobj.to_mesh()
    p=np.empty(n*3, dtype=np.float64); em.vertices.foreach_get("co", p)
    evobj.to_mesh_clear()
    return p.reshape(-1,3)
P0=eval_pos(0)
cent=np.zeros((len(uniq),3))
for i in range(len(uniq)): cent[i]=P0[island==i].mean(axis=0)
kd=kdtree.KDTree(n)
for i,p in enumerate(P0): kd.insert(p, i)
kd.balance()
band=np.nonzero((P0[:,2]>0.42)&(P0[:,2]<0.72)&(np.abs(P0[:,0])<0.20)&(np.abs(P0[:,1])<0.16))[0]
pairs=[]
for i in band:
    i=int(i)
    for (co, idx, dist) in kd.find_n(P0[i], 10):
        if island[idx]!=island[i]:
            if dist<0.004: pairs.append((i, int(idx), float(dist)))
            break
KEEP={"Root","Hips","Spine","Chest","UpperChest","UpperLeg_L","UpperLeg_R"}
pairs=[p for p in pairs if dom[island[p[0]]] in KEEP and dom[island[p[1]]] in KEEP]
print("WAIST-ZONE cross-island touch pairs kept:", len(pairs))
pv=np.array([p[0] for p in pairs]); pp=np.array([p[1] for p in pairs]); pd0=np.array([p[2] for p in pairs])
pair_key=np.array([ (min(int(island[a]),int(island[b])), max(int(island[a]),int(island[b]))) for a,b in zip(pv,pp)])
best={}
for f in list(range(0,46,3)):
    P=eval_pos(f)
    d=np.linalg.norm(P[pv]-P[pp], axis=1); growth=d-pd0
    print(f"FRAME {f:2d}: pair growth max={growth.max()*1000:6.1f}mm  >3mm:{int((growth>0.003).sum()):5d}  >6mm:{int((growth>0.006).sum()):5d}  >10mm:{int((growth>0.010).sum()):5d}")
    for k in np.argsort(-growth)[:60]:
        key=tuple(pair_key[k])
        if key not in best or growth[k]>best[key][0]:
            best[key]=(float(growth[k]), f, int(pv[k]), int(pp[k]), P[int(pv[k])].copy())
print("TOP ISLAND PAIRS BY MAX SEPARATION GROWTH:")
for key,(g,f,v,pa,pos) in sorted(best.items(), key=lambda kv:-kv[1][0])[:12]:
    a,b=key
    print(f" pair {a}({dom[a]}) vs {b}({dom[b]}): max +{g*1000:.1f}mm @F{f} at ({pos[0]:+.3f},{pos[1]:+.3f},{pos[2]:.3f})")
    print(f"    isl{a}: {int(cnt[a])}v cent={np.round(cent[a],3).tolist()} top={wtxt(a)}")
    print(f"    isl{b}: {int(cnt[b])}v cent={np.round(cent[b],3).tolist()} top={wtxt(b)}")
print("DONE")
