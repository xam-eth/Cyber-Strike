"""UNRESTRICTED diagnosis (owner: hole persists + 'something gets pulled along' during AIM).
No dominant-bone filter anywhere: (1) scan islands in the torso box with ANY arm/hand/weapon
influence; (2) cross-island pair-growth + true-gap at F36/F45 for ALL island pairs in a wide
torso box; (3) highlight renders: suspect islands in red emissive over clay body, F0 vs F36,
front / front-left-3q / left-profile."""
import bpy, math, os
import numpy as np
from mathutils import Matrix, Vector, kdtree
PROJ="/home/user/Cyber-Strike/EXOCOMFLICT_HERO01"; SHOT=f"{PROJ}/screenshots/diag"; os.makedirs(SHOT, exist_ok=True)
bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.ops.import_scene.gltf(filepath=f"{PROJ}/assets/characters/HERO_01_RIGGED.glb")
sc=bpy.context.scene; sc.render.fps=30; sc.frame_start=0; sc.frame_end=45
arm=[o for o in bpy.data.objects if o.type=='ARMATURE'][0]
body=max([o for o in bpy.data.objects if o.type=='MESH'], key=lambda o: len(o.data.vertices))
me=body.data; n=len(me.vertices)
gnames=[g.name for g in body.vertex_groups]; ng=len(gnames)
print("BODY", body.name, n, "groups:", gnames)
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
vertW=[None]*n; W=np.zeros((len(uniq), ng)); cnt=np.zeros(len(uniq))
for v in me.vertices:
    i=island[v.index]; cnt[i]+=1
    vertW[v.index]={gnames[g.group]: float(g.weight) for g in v.groups}
    for g in v.groups: W[i,g.group]+=g.weight
W/=np.maximum(cnt,1)[:,None]
dom=[gnames[int(np.argmax(W[i]))] for i in range(len(uniq))]
def eval_pos(frame):
    sc.frame_set(frame); bpy.context.view_layer.update()
    dg=bpy.context.evaluated_depsgraph_get()
    eo=body.evaluated_get(dg); em=eo.to_mesh()
    p=np.empty(n*3); em.vertices.foreach_get("co", p); eo.to_mesh_clear()
    return p.reshape(-1,3)
P0=eval_pos(0)
cent=np.array([P0[island==i].mean(axis=0) for i in range(len(uniq))])
bmin=np.array([P0[island==i].min(axis=0) for i in range(len(uniq))])
bmax=np.array([P0[island==i].max(axis=0) for i in range(len(uniq))])
def wtxt(i, k=4):
    o=np.argsort(-W[i])[:k]
    return [(gnames[j], round(float(W[i,j]),3)) for j in o if W[i,j]>0.005]
ARM={"Clavicle_L","Clavicle_R","UpperArm_L","UpperArm_R","Forearm_L","Forearm_R","Hand_L","Hand_R","Weapon_R"}
arm_idx=[gnames.index(a) for a in ARM if a in gnames]
print("--- SCAN: islands in torso box (z 0.44-0.72, |x|<=0.17, |y|<=0.14) with arm influence ---")
suspects=[]
for i in range(len(uniq)):
    c=cent[i]
    if not (0.44<=c[2]<=0.72 and abs(c[0])<=0.17 and abs(c[1])<=0.14): continue
    arm_mean=float(W[i, arm_idx].sum()) if arm_idx else 0.0
    if arm_mean>0.05 or dom[i] in ARM:
        suspects.append(i)
        print(f" SUSPECT isl{i}: {int(cnt[i])}v dom={dom[i]} arm_mean={arm_mean:.2f} top={wtxt(i)} cent=({c[0]:+.3f},{c[1]:+.3f},{c[2]:.3f}) bbox x[{bmin[i][0]:+.3f},{bmax[i][0]:+.3f}] y[{bmin[i][1]:+.3f},{bmax[i][1]:+.3f}] z[{bmin[i][2]:.3f},{bmax[i][2]:.3f}]")
print("SUSPECTS:", suspects)
print("--- SCAN2: islands anywhere with Weapon_R mean weight>0.02 ---")
if "Weapon_R" in gnames:
    wi=gnames.index("Weapon_R")
    for i in range(len(uniq)):
        if W[i,wi]>0.02:
            print(f" WEAPONW isl{i}: {int(cnt[i])}v dom={dom[i]} Weapon_R={W[i,wi]:.3f} top={wtxt(i)} cent=({cent[i][0]:+.3f},{cent[i][1]:+.3f},{cent[i][2]:.3f})")

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
band=np.nonzero((P0[:,2]>0.40)&(P0[:,2]<0.80)&(np.abs(P0[:,0])<0.22)&(np.abs(P0[:,1])<0.18))[0]
pairs=[]
for i in band:
    i=int(i)
    for (co_, idx, dist) in kd0.find_n(P0[i], 10):
        if island[idx]!=island[i]:
            if dist<0.004: pairs.append((i, int(idx), float(dist)))
            break
pv=np.array([p[0] for p in pairs]); pp=np.array([p[1] for p in pairs]); pd0=np.array([p[2] for p in pairs])
d0N,_=nearest_other(kd0, P0, pv)
print("unrestricted touch pairs:", len(pairs))
def metrics(P, tag):
    kd=build_kd(P)
    gpair=np.linalg.norm(P[pv]-P[pp], axis=1)-pd0
    dN,oN=nearest_other(kd, P, pv)
    ggap=dN-d0N
    def agg(vals, others):
        a={}
        for k in range(len(pv)):
            if others[k]<0: continue
            key=(min(int(island[pv[k]]),int(island[others[k]])), max(int(island[pv[k]]),int(island[others[k]])))
            if key not in a or vals[k]>a[key][0]: a[key]=(float(vals[k]), P[int(pv[k])], float(P0[pv[k]][2]))
        return sorted(a.items(), key=lambda kv:-kv[1][0])
    print(f"{tag}: PAIRGROWTH max={gpair.max()*1000:.1f}mm TRUEGAP max={ggap.max()*1000:.1f}mm")
    print(f" {tag} WORST TRUE-GAP pairs (all):")
    for key,(gg,pos,rz) in agg(ggap,oN)[:12]:
        if gg<0.002: break
        print(f"   GAP {key[0]}({dom[key[0]]}) vs {key[1]}({dom[key[1]]}): +{gg*1000:.1f}mm posed=({pos[0]:+.3f},{pos[1]:+.3f},{pos[2]:.3f}) restz={rz:.3f}")
    print(f" {tag} WORST PAIR-GROWTH (waist rest z 0.44-0.68 only):")
    wmask=(P0[pv,2]>=0.44)&(P0[pv,2]<=0.68)
    order=np.argsort(-gpair)
    shown=0
    for k in order:
        if not wmask[k]: continue
        a,b=int(island[pv[k]]),int(island[pp[k]])
        print(f"   GROW {a}({dom[a]}) vs {b}({dom[b]}): +{gpair[k]*1000:.1f}mm rest=({P0[pv[k]][0]:+.3f},{P0[pv[k]][1]:+.3f},{P0[pv[k]][2]:.3f})")
        shown+=1
        if shown>=10: break
metrics(eval_pos(36), "F36")
metrics(eval_pos(45), "F45")

# ---------------- highlight renders ----------------
sus_set=set(suspects)
sus_verts=np.nonzero(np.isin(island, list(sus_set)))[0] if sus_set else np.array([],dtype=int)
print("suspect verts:", len(sus_verts))
if len(sus_verts):
    remap={int(v):j for j,v in enumerate(sus_verts)}
    polys=[]
    for p in me.polygons:
        vs=list(p.vertices)
        if all(int(v) in remap for v in vs): polys.append(tuple(remap[int(v)] for v in vs))
    sm=bpy.data.meshes.new("Suspects")
    sm.from_pydata([tuple(P0[int(v)]) for v in sus_verts], [], polys); sm.update()
    sob=bpy.data.objects.new("Suspects", sm); sc.collection.objects.link(sob)
    for name in gnames: sob.vertex_groups.new(name=name)
    vg={g.name:g for g in sob.vertex_groups}
    for j,v in enumerate(sus_verts):
        for bn,val in vertW[int(v)].items(): vg[bn].add([j], float(val), 'ADD')
    mod=sob.modifiers.new("Arm", 'ARMATURE'); mod.object=arm
    sob.scale=(1.003,1.003,1.003)
    red=bpy.data.materials.new("RedEmissive"); red.use_nodes=True
    bsdf=red.node_tree.nodes["Principled BSDF"]
    bsdf.inputs["Base Color"].default_value=(0.05,0.0,0.0,1)
    bsdf.inputs["Emission Color"].default_value=(1.0,0.05,0.05,1)
    bsdf.inputs["Emission Strength"].default_value=2.5
    sm.materials.append(red)
    clay=bpy.data.materials.new("Clay"); clay.use_nodes=True
    cb=clay.node_tree.nodes["Principled BSDF"]
    cb.inputs["Base Color"].default_value=(0.32,0.33,0.36,1); cb.inputs["Roughness"].default_value=0.9
    if len(me.materials): me.materials[0]=clay
    else: me.materials.append(clay)
sc.render.engine="CYCLES"; sc.cycles.samples=16; sc.cycles.use_denoising=True; sc.cycles.device="CPU"
w=bpy.data.worlds.new("W"); sc.world=w; w.use_nodes=True
w.node_tree.nodes["Background"].inputs[0].default_value=(0.16,0.17,0.19,1)
w.node_tree.nodes["Background"].inputs[1].default_value=0.9
sd=bpy.data.lights.new("Sun","SUN"); sd.energy=3; so=bpy.data.objects.new("Sun",sd); sc.collection.objects.link(so)
so.rotation_euler=(math.radians(52),math.radians(8),math.radians(-38))
cam=bpy.data.objects.new("Cam",bpy.data.cameras.new("Cam")); cam.data.lens=52; sc.collection.objects.link(cam); sc.camera=cam
arm.hide_render=True
TGT=(0,-0.02,0.56)
def shoot(name, frame, loc, target=TGT):
    sc.frame_set(frame); cam.location=loc
    cam.rotation_euler=(Vector(target)-Vector(loc)).to_track_quat('-Z','Y').to_euler()
    sc.render.resolution_x=900; sc.render.resolution_y=900; sc.render.filepath=f"{SHOT}/{name}.png"
    bpy.ops.render.render(write_still=True); print("RENDERED", name)
for f,ft in ((0,"F00"),(36,"F36")):
    shoot(f"sus_{ft}_front", f, (0,-1.15,0.58))
    shoot(f"sus_{ft}_camFR", f, (0.75,-0.85,0.58))
    shoot(f"sus_{ft}_profL", f, (1.15,-0.05,0.58))
print("DONE")
