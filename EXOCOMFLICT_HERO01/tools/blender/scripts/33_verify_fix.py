"""Final verification of the waist-gap fix on the SHIPPED (new) HERO_01_RIGGED.glb:
A) true-gap metrics at F36/F45; B) spine stress poses (yaw/bend/side) beyond the clip;
C) renders: magenta waist macro PRE-fix GLB vs NEW GLB, magenta front F0/F36, gray beauty."""
import bpy, math, os
import numpy as np
from mathutils import Matrix, Vector, kdtree
PROJ="/home/user/Cyber-Strike/EXOCOMFLICT_HERO01"; SHOT=f"{PROJ}/screenshots/diag"; os.makedirs(SHOT, exist_ok=True)
NEW=f"{PROJ}/assets/characters/HERO_01_RIGGED.glb"; OLD="/tmp/HERO_01_RIGGED_PREFIX.glb"; WEAP=f"{PROJ}/assets/weapons/HERO_01_WEAPON.glb"

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

def islands_of(body):
    me=body.data; n=len(me.vertices)
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
    _, island=np.unique(roots, return_inverse=True)
    return island, n

def eval_pos(sc, body, n, frame=None):
    if frame is not None: sc.frame_set(frame)
    bpy.context.view_layer.update()
    dg=bpy.context.evaluated_depsgraph_get()
    eo=body.evaluated_get(dg); em=eo.to_mesh()
    p=np.empty(n*3); em.vertices.foreach_get("co", p); eo.to_mesh_clear()
    return p.reshape(-1,3)

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

def build_kd(P):
    kd=kdtree.KDTree(len(P))
    for i,p in enumerate(P): kd.insert(p, i)
    kd.balance(); return kd

# ---------------- A + B: metrics on NEW ----------------
sc, arm, body, _ = load(NEW)
island, n = islands_of(body)
gnames=[g.name for g in body.vertex_groups]; ng=len(gnames)
W=np.zeros((island.max()+1, ng)); cnt=np.zeros(island.max()+1)
for v in body.data.vertices:
    i=island[v.index]; cnt[i]+=1
    for g in v.groups: W[i,g.group]+=g.weight
W/=np.maximum(cnt,1)[:,None]
dom=[gnames[int(np.argmax(W[i]))] for i in range(len(W))]
P0=eval_pos(sc, body, n, 0)
kd0=build_kd(P0)
band=np.nonzero((P0[:,2]>0.42)&(P0[:,2]<0.78)&(np.abs(P0[:,0])<0.20)&(np.abs(P0[:,1])<0.16))[0]
pairs=[]
for i in band:
    i=int(i)
    for (co_, idx, dist) in kd0.find_n(P0[i], 10):
        if island[idx]!=island[i]:
            if dist<0.004: pairs.append((i, int(idx), float(dist)))
            break
KEEP={"Root","Hips","Spine","Chest","UpperChest","Neck","UpperLeg_L","UpperLeg_R"}
pairs=[p for p in pairs if dom[island[p[0]]] in KEEP and dom[island[p[1]]] in KEEP]
pv=np.array([p[0] for p in pairs]); pp=np.array([p[1] for p in pairs]); pd0=np.array([p[2] for p in pairs])
d0N,_=nearest_other(kd0, P0, island, pv)
waist_mask=(P0[pv,2]>=0.53)&(P0[pv,2]<=0.65)
LEGPAIR={"UpperLeg_L","UpperLeg_R","LowerLeg_L","LowerLeg_R"}
def metrics(P, tag):
    kd=build_kd(P)
    gpair=np.linalg.norm(P[pv]-P[pp], axis=1)-pd0
    dN,oN=nearest_other(kd, P, island, pv)
    ggap=dN-d0N
    agg={}
    for k in range(len(pv)):
        if oN[k]<0: continue
        key=(min(int(island[pv[k]]),int(island[oN[k]])), max(int(island[pv[k]]),int(island[oN[k]])))
        if key not in agg or ggap[k]>agg[key][0]: agg[key]=(float(ggap[k]), P[int(pv[k])])
    noleg=[(k,v) for k,v in agg.items() if dom[k[0]] not in LEGPAIR and dom[k[1]] not in LEGPAIR]
    gmax=max(v[0] for _,v in noleg)
    print(f"{tag}: PAIRGROWTH max={gpair.max()*1000:.1f}mm | GAP waist[0.53,0.65]={ggap[waist_mask].max()*1000:.2f}mm no-leg global={gmax*1000:.2f}mm")
    for key,(gg,pos) in sorted(noleg, key=lambda kv:-kv[1][0])[:4]:
        if gg<0.0015: break
        print(f"   GAP {key[0]}({dom[key[0]]}) vs {key[1]}({dom[key[1]]}): +{gg*1000:.1f}mm at ({pos[0]:+.3f},{pos[1]:+.3f},{pos[2]:.3f})")
    return float(ggap[waist_mask].max())
metrics(eval_pos(sc, body, n, 36), "NEW F36")
metrics(eval_pos(sc, body, n, 45), "NEW F45")
def rot(name, axis, deg):
    pb=arm.pose.bones[name]; head=pb.head.copy()
    M=Matrix.Translation(head)@Matrix.Rotation(math.radians(deg),4,axis)@Matrix.Translation(-head)
    pb.matrix=M@pb.matrix; bpy.context.view_layer.update()
sc.frame_set(0); rot("Spine",(0,0,1),15); rot("Chest",(0,0,1),25)
metrics(eval_pos(sc, body, n), "STRESS yaw+15/+25")
sc.frame_set(0); rot("Spine",(0,0,1),-15); rot("Chest",(0,0,1),-25)
metrics(eval_pos(sc, body, n), "STRESS yaw-15/-25")
sc.frame_set(0); rot("Spine",(1,0,0),20); rot("Chest",(1,0,0),15)
metrics(eval_pos(sc, body, n), "STRESS fwd-bend 20/15")
sc.frame_set(0); rot("Spine",(0,1,0),12); rot("Chest",(0,1,0),18)
metrics(eval_pos(sc, body, n), "STRESS side-bend 12/18")
sc.frame_set(0); bpy.context.view_layer.update()

# ---------------- C: renders ----------------
def render_setup(world_rgb, strength, ground=False):
    sc=bpy.context.scene
    sc.render.engine="CYCLES"; sc.cycles.samples=24; sc.cycles.use_denoising=True; sc.cycles.device="CPU"
    w=bpy.data.worlds.new("W"); sc.world=w; w.use_nodes=True
    w.node_tree.nodes["Background"].inputs[0].default_value=(*world_rgb,1)
    w.node_tree.nodes["Background"].inputs[1].default_value=strength
    sd=bpy.data.lights.new("Sun","SUN"); sd.energy=3; so=bpy.data.objects.new("Sun",sd); sc.collection.objects.link(so)
    so.rotation_euler=(math.radians(52),math.radians(8),math.radians(-38))
    if ground:
        bpy.ops.mesh.primitive_plane_add(size=8, location=(0,0,0)); gnd=bpy.context.active_object
        gm=bpy.data.materials.new("Ground"); gm.use_nodes=True
        gm.node_tree.nodes["Principled BSDF"].inputs["Base Color"].default_value=(0.23,0.24,0.27,1)
        gnd.data.materials.append(gm)
    cam=bpy.data.objects.new("Cam",bpy.data.cameras.new("Cam")); cam.data.lens=52; sc.collection.objects.link(cam); sc.camera=cam
    return cam
def shoot(sc, cam, name, frame, loc, target, rx=900, ry=900):
    sc.frame_set(frame); cam.location=loc
    cam.rotation_euler=(Vector(target)-Vector(loc)).to_track_quat('-Z','Y').to_euler()
    sc.render.resolution_x=rx; sc.render.resolution_y=ry; sc.render.filepath=f"{SHOT}/{name}.png"
    bpy.ops.render.render(write_still=True); print("RENDERED", name)
WAIST_CAM=(0.28,-0.34,0.63); WAIST_TGT=(0.06,-0.07,0.60)
FRONT_CAM=(0,-1.15,0.58); FRONT_TGT=(0,-0.02,0.56)
# OLD (pre-fix) waist macro, magenta, body only
sc, arm, body, _ = load(OLD)
cam=render_setup((1.0,0.1,0.75), 0.85); arm.hide_render=True
shoot(sc, cam, "fix_PREFIX_F36_waist", 36, WAIST_CAM, WAIST_TGT)
# NEW waist macro + front views (weapon attached for front/beauty)
sc, arm, body, weap = load(NEW, with_weapon=True)
cam=render_setup((1.0,0.1,0.75), 0.85); arm.hide_render=True
weap.hide_render=True
shoot(sc, cam, "fix_NEW_F36_waist", 36, WAIST_CAM, WAIST_TGT)
weap.hide_render=False
shoot(sc, cam, "fix_NEW_F36_front", 36, FRONT_CAM, FRONT_TGT, 850, 850)
shoot(sc, cam, "fix_NEW_F00_front", 0, FRONT_CAM, FRONT_TGT, 850, 850)
# beauty, gray bg + ground
sc, arm, body, weap = load(NEW, with_weapon=True)
cam=render_setup((0.16,0.17,0.19), 0.9, ground=True); arm.hide_render=True
shoot(sc, cam, "fix_NEW_F36_closeweapon", 36, (-0.611,-0.833,0.778), (-0.056,-0.194,0.722), 1000, 1000)
print("DONE")
