"""Void hunt: does the torso surface itself have holes that arm shells cover at rest?
(1) finite true-gap list for TORSO-island probes in front-left box (+ capped/vacated count);
(2) torso-only renders (arm/clavicle/hand islands removed) magenta F0/F36 x3 views;
(3) full textured OLD-vs-NEW comparison from left profile (angle never rendered before)."""
import bpy, math, os
import numpy as np
from mathutils import Matrix, Vector, kdtree
PROJ="/home/user/Cyber-Strike/EXOCOMFLICT_HERO01"; SHOT=f"{PROJ}/screenshots/diag"; os.makedirs(SHOT, exist_ok=True)
NEW=f"{PROJ}/assets/characters/HERO_01_RIGGED.glb"; OLD="/tmp/HERO_01_RIGGED_PREFIX.glb"; WEAP=f"{PROJ}/assets/weapons/HERO_01_WEAPON.glb"
ARM={"Clavicle_L","Clavicle_R","UpperArm_L","UpperArm_R","Forearm_L","Forearm_R","Hand_L","Hand_R","Weapon_R"}

def load(glb, with_weapon=False):
    bpy.ops.wm.read_factory_settings(use_empty=True)
    bpy.ops.import_scene.gltf(filepath=glb)
    if with_weapon: bpy.ops.import_scene.gltf(filepath=WEAP)
    sc=bpy.context.scene; sc.render.fps=30; sc.frame_start=0; sc.frame_end=45
    arm=[o for o in bpy.data.objects if o.type=='ARMATURE'][0]
    for m in [o for o in bpy.data.objects if o.type=='MESH']:
        if len(m.data.vertices)<1000: bpy.data.objects.remove(m, do_unlink=True)
    body=max([o for o in bpy.data.objects if o.type=='MESH'], key=lambda o: len(o.data.vertices))
    weap=None
    if with_weapon:
        weap=[o for o in bpy.data.objects if o.type=='MESH' and "WEAPON" in o.name][0]
        sc.frame_set(0); bpy.context.view_layer.update()
        weap.parent=arm; weap.parent_type='BONE'; weap.parent_bone="Weapon_R"
        bpy.context.view_layer.update(); weap.matrix_world=Matrix.Identity(4); bpy.context.view_layer.update()
    return sc, arm, body, weap

def analyze(body):
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
    arm_idx=[gnames.index(a) for a in ARM if a in gnames]
    arm_mean=W[:, arm_idx].sum(axis=1) if arm_idx else np.zeros(len(uniq))
    return island, vertW, W, cnt, dom, arm_mean, gnames, n

def eval_pos(sc, body, n, frame):
    sc.frame_set(frame); bpy.context.view_layer.update()
    dg=bpy.context.evaluated_depsgraph_get()
    eo=body.evaluated_get(dg); em=eo.to_mesh()
    p=np.empty(n*3); em.vertices.foreach_get("co", p); eo.to_mesh_clear()
    return p.reshape(-1,3)

def build_kd(P):
    kd=kdtree.KDTree(len(P))
    for i,p in enumerate(P): kd.insert(p, i)
    kd.balance(); return kd
CAP=0.035
def nearest_other(kd, P, island, idxs, k=40):
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

def render_setup(world_rgb, strength):
    sc=bpy.context.scene
    sc.render.engine="CYCLES"; sc.cycles.samples=16; sc.cycles.use_denoising=True; sc.cycles.device="CPU"
    w=bpy.data.worlds.new("W"); sc.world=w; w.use_nodes=True
    w.node_tree.nodes["Background"].inputs[0].default_value=(*world_rgb,1)
    w.node_tree.nodes["Background"].inputs[1].default_value=strength
    sd=bpy.data.lights.new("Sun","SUN"); sd.energy=3; so=bpy.data.objects.new("Sun",sd); sc.collection.objects.link(so)
    so.rotation_euler=(math.radians(52),math.radians(8),math.radians(-38))
    cam=bpy.data.objects.new("Cam",bpy.data.cameras.new("Cam")); cam.data.lens=52; sc.collection.objects.link(cam); sc.camera=cam
    return cam
def shoot(sc, cam, name, frame, loc, target=(0,-0.02,0.56)):
    sc.frame_set(frame); cam.location=loc
    cam.rotation_euler=(Vector(target)-Vector(loc)).to_track_quat('-Z','Y').to_euler()
    sc.render.resolution_x=900; sc.render.resolution_y=900; sc.render.filepath=f"{SHOT}/{name}.png"
    bpy.ops.render.render(write_still=True); print("RENDERED", name)

# ---------- (1) finite gap list, torso probes, front-left box ----------
sc, arm, body, _ = load(NEW)
island, vertW, W, cnt, dom, arm_mean, gnames, n = analyze(body)
P0=eval_pos(sc, body, n, 0); P36=eval_pos(sc, body, n, 36)
torso_isl=set(int(i) for i in range(len(W)) if arm_mean[i]<0.05)
FL=(P0[:,0]>=0.03)&(P0[:,0]<=0.17)&(P0[:,1]>=-0.12)&(P0[:,1]<=-0.05)&(P0[:,2]>=0.44)&(P0[:,2]<=0.65)
probes=np.array([int(v) for v in np.nonzero(FL)[0] if int(island[v]) in torso_isl])
kd0=build_kd(P0); kd36=build_kd(P36)
d0N,_=nearest_other(kd0, P0, island, probes)
keep=d0N<0.006; probes=probes[keep]; d0N=d0N[keep]
dN,oN=nearest_other(kd36, P36, island, probes)
g=dN-d0N
capped=np.nonzero(oN<0)[0]
print(f"torso probes FL box: {len(probes)} | vacated(capped) at F36: {len(capped)}")
from collections import Counter
cc=Counter(int(island[probes[k]]) for k in capped)
for iid,c in cc.most_common(8):
    sel=[probes[k] for k in capped if int(island[probes[k]])==iid]
    zz=P0[sel,2]; xx=P0[sel,0]
    print(f" VACATED isl{iid}({dom[iid]}): {c} probes x[{xx.min():+.3f},{xx.max():+.3f}] z[{zz.min():.3f},{zz.max():.3f}]")
fin=np.nonzero(oN>=0)[0]
print("--- worst FINITE true-gap (torso probes, front-left box, F36) ---")
for k in fin[np.argsort(-g[fin])[:15]]:
    v=int(probes[k]); u=int(oN[k])
    print(f"  +{g[k]*1000:5.1f}mm isl{int(island[v])}({dom[int(island[v])]}) rest=({P0[v][0]:+.3f},{P0[v][1]:+.3f},{P0[v][2]:.3f}) -> isl{int(island[u])}({dom[int(island[u])]}) posed=({P36[v][0]:+.3f},{P36[v][1]:+.3f},{P36[v][2]:.3f})")

# ---------- (2) torso-only renders ----------
tverts=np.array([v for v in range(n) if int(island[v]) in torso_isl])
remap={int(v):j for j,v in enumerate(tverts)}
polys=[]
for p in body.data.polygons:
    vs=list(p.vertices)
    if all(int(v) in remap for v in vs): polys.append(tuple(remap[int(v)] for v in vs))
tm=bpy.data.meshes.new("TorsoOnly")
tm.from_pydata([tuple(P0[int(v)]) for v in tverts], [], polys); tm.update()
tob=bpy.data.objects.new("TorsoOnly", tm); sc.collection.objects.link(tob)
for name in gnames: tob.vertex_groups.new(name=name)
vg={g.name:g for g in tob.vertex_groups}
for j,v in enumerate(tverts):
    for bn,val in vertW[int(v)].items(): vg[bn].add([j], float(val), 'ADD')
mod=tob.modifiers.new("Arm", 'ARMATURE'); mod.object=arm
clay=bpy.data.materials.new("Clay"); clay.use_nodes=True
cb=clay.node_tree.nodes["Principled BSDF"]
cb.inputs["Base Color"].default_value=(0.32,0.33,0.36,1); cb.inputs["Roughness"].default_value=0.9
tm.materials.append(clay)
body.hide_render=True
cam=render_setup((1.0,0.1,0.75), 0.85); arm.hide_render=True
for f,ft in ((0,"F00"),(36,"F36")):
    shoot(sc, cam, f"void_{ft}_front", f, (0,-1.15,0.58))
    shoot(sc, cam, f"void_{ft}_camFR", f, (0.75,-0.85,0.58))
    shoot(sc, cam, f"void_{ft}_profL", f, (1.15,-0.05,0.58))

# ---------- (3) textured OLD vs NEW, left profile + camFR, F36 ----------
for glb, tag in ((OLD,"OLD"),(NEW,"NEW")):
    sc, arm, body, weap = load(glb, with_weapon=True)
    cam=render_setup((0.16,0.17,0.19), 0.9); arm.hide_render=True
    sc.cycles.samples=24
    shoot(sc, cam, f"cmp_{tag}_F36_profL", 36, (1.15,-0.05,0.58))
    if tag=="NEW": shoot(sc, cam, "cmp_NEW_F36_camFR", 36, (0.75,-0.85,0.58))
print("DONE")
