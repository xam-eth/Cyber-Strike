"""Adjudicate weapon/body boundary islands with color-coded close-ups + ghost joints."""
import bpy, json, math, os
import numpy as np
from mathutils import Vector

PROJ="/home/user/Cyber-Strike/EXOCOMFLICT_HERO01"
OUT=f"{PROJ}/tools/out"; REND=f"{PROJ}/screenshots/audit"

bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.ops.import_scene.gltf(filepath=f"{PROJ}/assets/source/HERO_01.glb")
obj=[o for o in bpy.context.scene.objects if o.type=="MESH"][0]
m=obj.data; nv=len(m.vertices)
co=np.empty(nv*3); m.vertices.foreach_get("co",co); co=co.reshape(-1,3)
mw=np.array(obj.matrix_world); world=(mw[:3,:3]@co.T).T+mw[:3,3]
isl=np.load(f"{OUT}/blender_island_ids.npy"); n_isl=int(isl.max()+1)
stats={}
for i in range(n_isl):
    vv=world[isl==i]
    stats[i]=(int(len(vv)),vv.mean(0),vv.min(0),vv.max(0))
cand=json.load(open(f"{OUT}/weapon_candidates.json"))["weapon_candidate_islands"]
cand=[int(c) for c in cand]
print("== corridor islands NOT in cand40 (bbox intersects rifle corridor) ==")
for i in range(n_isl):
    if i in cand: continue
    n,c,mn,mx=stats[i]
    if n<30: continue
    if mx[0]<-0.07 and mn[0]>-0.28 and mx[2]>0.10 and mn[2]<0.70 and mn[1]<0.06 and mx[1]>-0.11 and c[0]<-0.10:
        print(f" CORR isl={i:3d} v={n:5d} ctr=({c[0]:+.3f},{c[1]:+.3f},{c[2]:.3f}) x[{mn[0]:+.3f},{mx[0]:+.3f}] y[{mn[1]:+.3f},{mx[1]:+.3f}] z[{mn[2]:.3f},{mx[2]:.3f}]")
grip_suspects=[i for i in cand if -0.215<=stats[i][1][0]<=-0.14 and 0.42<=stats[i][1][2]<=0.515 and -0.055<=stats[i][1][1]<=0.01]
core=[i for i in cand if i not in grip_suspects]
print("GRIP SUSPECTS:",grip_suspects); print("CORE:",len(core))
json.dump({"cand40":cand,"core":core,"grip_suspects":grip_suspects,"boundary":{"i45":45,"i40":40,"i32":32,"i224":224}}, open(f"{OUT}/weapon_groups.json","w"), indent=1)

def emat(name,col,emit=0.55):
    mt=bpy.data.materials.new(name); mt.use_nodes=True
    b=mt.node_tree.nodes["Principled BSDF"]; b.inputs["Base Color"].default_value=(*col,1)
    b.inputs["Emission Color"].default_value=(*col,1); b.inputs["Emission Strength"].default_value=emit
    return mt
def build(name, ids, mat):
    if not ids: return None
    mask=np.isin(isl,np.array(ids))
    pv=np.empty(len(m.polygons)*3,dtype=np.int64); m.polygons.foreach_get("vertices",pv); pv=pv.reshape(-1,3)
    faces=pv[mask[pv].all(axis=1)]
    nm=bpy.data.meshes.new(name); nm.from_pydata(world.tolist(),[],faces.tolist()); nm.materials.append(mat)
    o=bpy.data.objects.new(name,nm); bpy.context.scene.collection.objects.link(o); return o
ghost=bpy.data.materials.new("Ghost"); ghost.use_nodes=True
gb=ghost.node_tree.nodes["Principled BSDF"]; gb.inputs["Base Color"].default_value=(0.6,0.62,0.66,1); gb.inputs["Alpha"].default_value=0.18; gb.inputs["Roughness"].default_value=0.9
obj.data.materials.clear(); obj.data.materials.append(ghost)
objs=[build("G_core",core,emat("DarkRed",(0.75,0.04,0.02))),
      build("G_grip",grip_suspects,emat("Yellow",(0.95,0.8,0.05))),
      build("G_45",[45],emat("Orange",(1,0.45,0.0))),
      build("G_40",[40],emat("Magenta",(0.9,0.05,0.8))),
      build("G_32",[32],emat("CyanB",(0.05,0.75,0.9))),
      build("G_224",[224],emat("Green",(0.15,0.85,0.25)))]
JOINTS=json.load(open(f"{OUT}/joints_proposal.json"))
cyan=emat("Cyan",(0,0.85,1),1.4); joints=[]
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
cam=bpy.data.objects.new("Cam",bpy.data.cameras.new("Cam")); sc.collection.objects.link(cam); sc.camera=cam
def shoot(name,loc,target,rx=750,ry=750,samples=20,lens=55):
    cam.data.lens=lens; cam.location=loc; cam.rotation_euler=(Vector(target)-Vector(loc)).to_track_quat('-Z','Y').to_euler()
    sc.render.resolution_x=rx; sc.render.resolution_y=ry; sc.cycles.samples=samples
    sc.render.filepath=f"{REND}/{name}.png"; bpy.ops.render.render(write_still=True); print("RENDERED",name)
for o in joints: o.hide_render=True
T=(-0.175,-0.015,0.47)
shoot("class_close_front",(-0.175,-0.55,0.49),T)
shoot("class_close_sideR",(-0.72,-0.015,0.49),T)
shoot("class_close_threeq",(-0.52,-0.42,0.60),T)
obj.hide_render=True
shoot("class_only_front",(-0.175,-0.55,0.49),T)
shoot("class_only_sideR",(-0.72,-0.015,0.49),T)
obj.hide_render=False
for o in objs:
    if o: o.hide_render=True
for o in joints: o.hide_render=False
shoot("joints_ghost_front",(0,-2.15,0.55),(0,0,0.5),700,875,24,52)
shoot("joints_ghost_sideR",(-2.15,0,0.55),(0,0,0.5),700,875,24,52)
shoot("joints_ghost_sideL",(2.15,0,0.55),(0,0,0.5),700,875,24,52)
print("DONE")
