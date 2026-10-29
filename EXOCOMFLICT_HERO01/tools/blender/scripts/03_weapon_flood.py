"""Weapon island flood-fill by inter-island proximity + ghost-body joint overlay."""
import bpy, json, math, os
import numpy as np
from mathutils import Vector
from scipy.spatial import cKDTree

PROJ="/home/user/Cyber-Strike/EXOCOMFLICT_HERO01"
OUT=f"{PROJ}/tools/out"; REND=f"{PROJ}/screenshots/audit"

bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.ops.import_scene.gltf(filepath=f"{PROJ}/assets/source/HERO_01.glb")
obj=[o for o in bpy.context.scene.objects if o.type=="MESH"][0]
m=obj.data; nv=len(m.vertices)
co=np.empty(nv*3); m.vertices.foreach_get("co",co); co=co.reshape(-1,3)
mw=np.array(obj.matrix_world); world=(mw[:3,:3]@co.T).T+mw[:3,3]
isl=np.load(f"{OUT}/blender_island_ids.npy"); n_isl=int(isl.max()+1)
centers=np.zeros((n_isl,3)); counts=np.bincount(isl,minlength=n_isl)
for i in range(n_isl): centers[i]=world[isl==i].mean(0)

# island-pair min distances via global KDTree k=8
tree=cKDTree(world)
d,idx=tree.query(world,k=8,workers=-1)
pair_min={}
for a in range(nv):
    ia=isl[a]
    for dd,b in zip(d[a,1:],idx[a,1:]):
        ib=isl[b]
        if ib==ia or dd>0.004: continue
        key=(ia,ib) if ia<ib else (ib,ia)
        if key not in pair_min or dd<pair_min[key]: pair_min[key]=float(dd)
print("island pairs within 4mm:",len(pair_min))

cand=json.load(open(f"{OUT}/weapon_candidates.json"))["weapon_candidate_islands"]
seeds=sorted([i for i in cand if centers[i][2]<0.45])
print("SEEDS (cand with center z<0.45):",len(seeds))
# flood with 2.0mm threshold, record waves; never accept islands with >4000 verts (body shells) unless seed
accepted=set(seeds); frontier=set(seeds); waves=[sorted(seeds)]
for w in range(12):
    new=set()
    for (a,b),dd in pair_min.items():
        if dd>0.002: continue
        if a in frontier and b not in accepted: new.add(b)
        if b in frontier and a not in accepted: new.add(a)
    new={i for i in new if counts[i]<=4000}
    if not new: break
    accepted|=new; frontier=new; waves.append(sorted(new))
    print(f" wave {w+1}: +{len(new)} -> total {len(accepted)} : {sorted(new)}")
review=sorted([i for i in accepted if centers[i][2]>=0.45])
core=sorted([i for i in accepted if centers[i][2]<0.45])
print("CORE:",len(core)," REVIEW(z>=0.45):",[(i,int(counts[i]),np.round(centers[i],3).tolist()) for i in review])
json.dump({"weapon_core":core,"weapon_review":review,"waves":waves}, open(f"{OUT}/weapon_flood.json","w"), indent=1)

def build_mesh(name, island_ids, mat):
    mask=np.isin(isl, np.array(island_ids))
    pv=np.empty(len(m.polygons)*3,dtype=np.int64); m.polygons.foreach_get("vertices",pv); pv=pv.reshape(-1,3)
    faces=pv[mask[pv].all(axis=1)]
    nm=bpy.data.meshes.new(name); nm.from_pydata(world.tolist(),[],faces.tolist()); nm.materials.append(mat)
    o=bpy.data.objects.new(name,nm); bpy.context.scene.collection.objects.link(o); return o
def emat(name, col, emit=0.7):
    mt=bpy.data.materials.new(name); mt.use_nodes=True
    b=mt.node_tree.nodes["Principled BSDF"]; b.inputs["Base Color"].default_value=(*col,1)
    b.inputs["Emission Color"].default_value=(*col,1); b.inputs["Emission Strength"].default_value=emit
    return mt
ghost=bpy.data.materials.new("Ghost"); ghost.use_nodes=True
gb=ghost.node_tree.nodes["Principled BSDF"]; gb.inputs["Base Color"].default_value=(0.6,0.62,0.66,1); gb.inputs["Alpha"].default_value=0.20; gb.inputs["Roughness"].default_value=0.9
obj.data.materials.clear(); obj.data.materials.append(ghost)
core_o=build_mesh("WeaponCore", core, emat("Red",(1,0.05,0.02)))
rev_o=build_mesh("WeaponReview", review, emat("Orange",(1,0.55,0.05))) if review else None

JOINTS=json.load(open(f"{OUT}/joints_proposal.json"))
cyan=emat("Cyan",(0,0.85,1),1.4)
joints=[]
for name,(h,t) in JOINTS.items():
    bpy.ops.mesh.primitive_ico_sphere_add(radius=0.0095, location=h)
    s=bpy.context.active_object; s.data.materials.append(cyan); joints.append(s)
    hv,tv=Vector(h),Vector(t); dv=tv-hv
    bpy.ops.mesh.primitive_cube_add(size=1, location=(hv+tv)/2)
    c=bpy.context.active_object; c.scale=(0.004,0.004,dv.length/2); c.rotation_mode='QUATERNION'; c.rotation_quaternion=dv.to_track_quat('Z','Y')
    c.data.materials.append(cyan); joints.append(c)

sc=bpy.context.scene
sc.render.engine="CYCLES"; sc.cycles.use_denoising=True; sc.cycles.device="CPU"
w=bpy.data.worlds.new("W"); sc.world=w; w.use_nodes=True
w.node_tree.nodes["Background"].inputs[0].default_value=(0.16,0.17,0.19,1); w.node_tree.nodes["Background"].inputs[1].default_value=0.9
sd=bpy.data.lights.new("Sun","SUN"); sd.energy=3; so=bpy.data.objects.new("Sun",sd); sc.collection.objects.link(so)
so.rotation_euler=(math.radians(52),math.radians(8),math.radians(-38))
cam=bpy.data.objects.new("Cam",bpy.data.cameras.new("Cam")); cam.data.lens=52; sc.collection.objects.link(cam); sc.camera=cam
def shoot(name, loc, target, rx=700, ry=875, samples=24, lens=52):
    cam.data.lens=lens; cam.location=loc; cam.rotation_euler=(Vector(target)-Vector(loc)).to_track_quat('-Z','Y').to_euler()
    sc.render.resolution_x=rx; sc.render.resolution_y=ry; sc.cycles.samples=samples
    sc.render.filepath=f"{REND}/{name}.png"; bpy.ops.render.render(write_still=True); print("RENDERED",name)
# weapon closeups (joints hidden)
for o in joints: o.hide_render=True
CU=(-0.175,-0.01,0.42)
shoot("flood_close_front",(-0.175,-0.60,0.44),CU,700,800,20,55)
shoot("flood_close_sideR",(-0.78,-0.01,0.44),CU,700,800,20,55)
obj.hide_render=True
shoot("flood_only_close_front",(-0.175,-0.60,0.44),CU,700,800,20,55)
shoot("flood_only_close_sideR",(-0.78,-0.01,0.44),CU,700,800,20,55)
obj.hide_render=False
# ghost joints full body (weapon meshes hidden)
core_o.hide_render=True
if rev_o: rev_o.hide_render=True
for o in joints: o.hide_render=False
shoot("joints_ghost_front",(0,-2.15,0.55),(0,0,0.5))
shoot("joints_ghost_sideR",(-2.15,0,0.55),(0,0,0.5))
shoot("joints_ghost_sideL",(2.15,0,0.55),(0,0,0.5))
print("DONE")
