"""Stress comparison OLD vs NEW GLB (same probes/method as 33) + magenta stress renders (NEW)."""
import bpy, math, os
import numpy as np
from mathutils import Matrix, Vector, kdtree
PROJ="/home/user/Cyber-Strike/EXOCOMFLICT_HERO01"; SHOT=f"{PROJ}/screenshots/diag"
NEW=f"{PROJ}/assets/characters/HERO_01_RIGGED.glb"; OLD="/tmp/HERO_01_RIGGED_PREFIX.glb"
CAP=0.035
def load(glb):
    bpy.ops.wm.read_factory_settings(use_empty=True)
    bpy.ops.import_scene.gltf(filepath=glb)
    sc=bpy.context.scene; sc.render.fps=30; sc.frame_start=0; sc.frame_end=45
    arm=[o for o in bpy.data.objects if o.type=='ARMATURE'][0]
    for m in [o for o in bpy.data.objects if o.type=='MESH']:
        if len(m.data.vertices)<1000: bpy.data.objects.remove(m, do_unlink=True)
    body=max([o for o in bpy.data.objects if o.type=='MESH'], key=lambda o: len(o.data.vertices))
    return sc, arm, body
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
def build_kd(P):
    kd=kdtree.KDTree(len(P))
    for i,p in enumerate(P): kd.insert(p, i)
    kd.balance(); return kd
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
def run_metrics(glb, label):
    sc, arm, body = load(glb)
    island, n = islands_of(body)
    gnames=[g.name for g in body.vertex_groups]; ng=len(gnames)
    W=np.zeros((island.max()+1, ng)); cnt=np.zeros(island.max()+1)
    for v in body.data.vertices:
        i=island[v.index]; cnt[i]+=1
        for g in v.groups: W[i,g.group]+=g.weight
    W/=np.maximum(cnt,1)[:,None]
    dom=[gnames[int(np.argmax(W[i]))] for i in range(len(W))]
    P0=eval_pos(sc, body, n, 0); kd0=build_kd(P0)
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
    hip_mask=(P0[pv,2]>=0.44)&(P0[pv,2]<0.53)
    LEGPAIR={"UpperLeg_L","UpperLeg_R","LowerLeg_L","LowerLeg_R"}
    def metrics(P, tag):
        kd=build_kd(P)
        dN,oN=nearest_other(kd, P, island, pv)
        ggap=dN-d0N
        agg={}
        for k in range(len(pv)):
            if oN[k]<0: continue
            key=(min(int(island[pv[k]]),int(island[oN[k]])), max(int(island[pv[k]]),int(island[oN[k]])))
            if key not in agg or ggap[k]>agg[key][0]: agg[key]=(float(ggap[k]), P[int(pv[k])])
        noleg=[v[0] for k,v in agg.items() if dom[k[0]] not in LEGPAIR and dom[k[1]] not in LEGPAIR]
        print(f"{label} {tag}: GAP waist={ggap[waist_mask].max()*1000:.2f}mm hip[0.44,0.53)={ggap[hip_mask].max()*1000:.2f}mm no-leg global={max(noleg)*1000:.2f}mm")
    def rot(name, axis, deg):
        pb=arm.pose.bones[name]; head=pb.head.copy()
        M=Matrix.Translation(head)@Matrix.Rotation(math.radians(deg),4,axis)@Matrix.Translation(-head)
        pb.matrix=M@pb.matrix; bpy.context.view_layer.update()
    metrics(eval_pos(sc, body, n, 36), "F36")
    sc.frame_set(0); rot("Spine",(0,0,1),15); rot("Chest",(0,0,1),25); metrics(eval_pos(sc, body, n), "STRESS yaw")
    sc.frame_set(0); rot("Spine",(1,0,0),20); rot("Chest",(1,0,0),15); metrics(eval_pos(sc, body, n), "STRESS bend")
    sc.frame_set(0); rot("Spine",(0,1,0),12); rot("Chest",(0,1,0),18); metrics(eval_pos(sc, body, n), "STRESS side")
    return sc, arm, body, rot
run_metrics(OLD, "OLD")
sc, arm, body, rot = run_metrics(NEW, "NEW")
# stress renders on NEW (magenta, body only)
sc.render.engine="CYCLES"; sc.cycles.samples=16; sc.cycles.use_denoising=True; sc.cycles.device="CPU"
w=bpy.data.worlds.new("W"); sc.world=w; w.use_nodes=True
w.node_tree.nodes["Background"].inputs[0].default_value=(1.0,0.1,0.75,1)
w.node_tree.nodes["Background"].inputs[1].default_value=0.85
sd=bpy.data.lights.new("Sun","SUN"); sd.energy=3; so=bpy.data.objects.new("Sun",sd); sc.collection.objects.link(so)
so.rotation_euler=(math.radians(52),math.radians(8),math.radians(-38))
cam=bpy.data.objects.new("Cam",bpy.data.cameras.new("Cam")); cam.data.lens=52; sc.collection.objects.link(cam); sc.camera=cam
arm.hide_render=True
def shoot_pose(name, loc, target=(0,-0.02,0.56)):
    cam.location=loc
    cam.rotation_euler=(Vector(target)-Vector(loc)).to_track_quat('-Z','Y').to_euler()
    sc.render.resolution_x=850; sc.render.resolution_y=850; sc.render.filepath=f"{SHOT}/{name}.png"
    bpy.ops.render.render(write_still=True); print("RENDERED", name)
sc.frame_set(0); rot("Spine",(0,0,1),15); rot("Chest",(0,0,1),25)
shoot_pose("fix_NEW_STRESSyaw_front", (0,-1.15,0.58))
shoot_pose("fix_NEW_STRESSyaw_camFR", (0.75,-0.85,0.58))
sc.frame_set(0); rot("Spine",(1,0,0),20); rot("Chest",(1,0,0),15)
shoot_pose("fix_NEW_STRESSbend_front", (0,-1.15,0.58))
print("DONE")
