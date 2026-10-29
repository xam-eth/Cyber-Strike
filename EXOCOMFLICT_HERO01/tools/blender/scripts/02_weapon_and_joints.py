"""Identify weapon islands by spatial isolation; propose joints; overlay renders."""
import bpy, json, math, os
import numpy as np
from mathutils import Vector

PROJ="/home/user/Cyber-Strike/EXOCOMFLICT_HERO01"
OUT=f"{PROJ}/tools/out"; REND=f"{PROJ}/screenshots/audit"; os.makedirs(REND, exist_ok=True)

bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.ops.import_scene.gltf(filepath=f"{PROJ}/assets/source/HERO_01.glb")
obj=[o for o in bpy.context.scene.objects if o.type=="MESH"][0]
m=obj.data; nv=len(m.vertices)
co=np.empty(nv*3); m.vertices.foreach_get("co",co); co=co.reshape(-1,3)
mw=np.array(obj.matrix_world); world=(mw[:3,:3]@co.T).T+mw[:3,3]
isl=np.load(f"{OUT}/blender_island_ids.npy"); assert len(isl)==nv, (len(isl),nv)
n_isl=int(isl.max()+1)
# per-island stats
stats=[]
for i in range(n_isl):
    mask=isl==i; vv=world[mask]
    stats.append((i,int(mask.sum()),vv.mean(0),vv.min(0),vv.max(0)))
# weapon region: character right side (-X), vertical rifle z 0.12..0.58, front y<=0.04
cand=[]
for i,n,c,mn,mx in stats:
    if n<15: continue
    if mx[0] < -0.115 and mn[2] > 0.10 and mx[2] < 0.60 and c[1] < 0.03:
        cand.append(i)
print(f"WEAPON CANDIDATES (islands fully right-side x_max<-0.115, z 0.10..0.60): {len(cand)}")
tot=0
for i in cand:
    _,n,c,mn,mx=stats[i]; tot+=n
    print(f" CAND isl={i:3d} verts={n:5d} center=({c[0]:+.3f},{c[1]:+.3f},{c[2]:.3f}) x[{mn[0]:+.3f},{mx[0]:+.3f}] y[{mn[1]:+.3f},{mx[1]:+.3f}] z[{mn[2]:.3f},{mx[2]:.3f}]")
print("candidate verts total:",tot)
json.dump({"weapon_candidate_islands":cand}, open(f"{OUT}/weapon_candidates.json","w"), indent=1)

# build candidate-only mesh for rendering
cand_mask=np.isin(isl, np.array(cand))
npol=len(m.polygons)
pv=np.empty(npol*3,dtype=np.int64)
# triangles: use loops via polygons vertices (assumes tris)
m.polygons.foreach_get("vertices", pv); pv=pv.reshape(-1,3)
face_ok=cand_mask[pv].all(axis=1)
faces=pv[face_ok]
print("candidate faces:",len(faces),"of",npol)
wmesh=bpy.data.meshes.new("CandMesh")
wmesh.from_pydata(world.tolist(), [], faces.tolist())
wobj=bpy.data.objects.new("WeaponCandidates", wmesh); bpy.context.scene.collection.objects.link(wobj)
red=bpy.data.materials.new("Red"); red.use_nodes=True
bsdf=red.node_tree.nodes["Principled BSDF"]; bsdf.inputs["Base Color"].default_value=(1,0.05,0.02,1); bsdf.inputs["Emission Color"].default_value=(1,0.05,0.02,1); bsdf.inputs["Emission Strength"].default_value=0.6
wmesh.materials.append(red)
clay=bpy.data.materials.new("Clay"); clay.use_nodes=True
clay.node_tree.nodes["Principled BSDF"].inputs["Base Color"].default_value=(0.55,0.56,0.6,1)
clay.node_tree.nodes["Principled BSDF"].inputs["Roughness"].default_value=0.9
obj.data.materials.clear(); obj.data.materials.append(clay)

JOINTS={ # name: (head, tail) world Blender coords - proposal v1 from slice centroids
 "Root":((0.015,0.0,0.0),(0.015,0.0,0.10)),
 "Hips":((0.015,-0.005,0.52),(0.018,-0.005,0.575)),
 "Spine":((0.018,-0.005,0.575),(0.025,-0.005,0.65)),
 "Chest":((0.025,-0.005,0.65),(0.035,-0.008,0.735)),
 "UpperChest":((0.035,-0.008,0.735),(0.042,-0.01,0.79)),
 "Neck":((0.042,-0.01,0.79),(0.043,-0.015,0.845)),
 "Head":((0.043,-0.015,0.845),(0.043,-0.02,0.95)),
 "Clavicle_R":((0.035,-0.015,0.76),(-0.065,-0.005,0.745)),
 "UpperArm_R":((-0.065,-0.005,0.745),(-0.15,0.005,0.575)),
 "Forearm_R":((-0.15,0.005,0.575),(-0.185,-0.025,0.465)),
 "Hand_R":((-0.185,-0.025,0.465),(-0.20,-0.04,0.40)),
 "Weapon_R":((-0.192,-0.033,0.452),(-0.207,-0.04,0.38)),
 "Clavicle_L":((0.035,-0.015,0.76),(0.145,-0.005,0.75)),
 "UpperArm_L":((0.145,-0.005,0.75),(0.165,-0.005,0.585)),
 "Forearm_L":((0.165,-0.005,0.585),(0.19,-0.015,0.41)),
 "Hand_L":((0.19,-0.015,0.41),(0.20,-0.02,0.34)),
 "UpperLeg_R":((-0.08,-0.01,0.51),(-0.115,-0.005,0.275)),
 "LowerLeg_R":((-0.115,-0.005,0.275),(-0.098,0.012,0.095)),
 "Foot_R":((-0.098,0.012,0.095),(-0.11,-0.06,0.04)),
 "Toe_R":((-0.11,-0.06,0.04),(-0.11,-0.09,0.025)),
 "UpperLeg_L":((0.11,-0.01,0.51),(0.152,-0.005,0.275)),
 "LowerLeg_L":((0.152,-0.005,0.275),(0.178,0.012,0.095)),
 "Foot_L":((0.178,0.012,0.095),(0.19,-0.06,0.04)),
 "Toe_L":((0.19,-0.06,0.04),(0.19,-0.09,0.025)),
}
json.dump(JOINTS, open(f"{OUT}/joints_proposal.json","w"), indent=1)
cyan=bpy.data.materials.new("JointMat"); cyan.use_nodes=True
cb=cyan.node_tree.nodes["Principled BSDF"]; cb.inputs["Base Color"].default_value=(0,0.9,1,1); cb.inputs["Emission Color"].default_value=(0,0.9,1,1); cb.inputs["Emission Strength"].default_value=1.2
joint_objs=[]
for name,(h,t) in JOINTS.items():
    bpy.ops.mesh.primitive_ico_sphere_add(radius=0.0095, location=h)
    s=bpy.context.active_object; s.name="J_"+name; s.data.materials.append(cyan); joint_objs.append(s)
    # bone line as stretched cube between head/tail
    hv,tv=Vector(h),Vector(t); mid=(hv+tv)/2; d=tv-hv
    bpy.ops.mesh.primitive_cube_add(size=1, location=mid)
    c=bpy.context.active_object; c.name="B_"+name
    c.scale=(0.004,0.004,d.length/2); c.rotation_mode='QUATERNION'; c.rotation_quaternion=d.to_track_quat('Z','Y')
    c.data.materials.append(cyan); joint_objs.append(c)

sc=bpy.context.scene
sc.render.engine="CYCLES"; sc.cycles.samples=16; sc.cycles.use_denoising=True; sc.cycles.device="CPU"
sc.render.resolution_x=700; sc.render.resolution_y=875
w=bpy.data.worlds.new("W"); sc.world=w; w.use_nodes=True
w.node_tree.nodes["Background"].inputs[0].default_value=(0.16,0.17,0.19,1); w.node_tree.nodes["Background"].inputs[1].default_value=0.9
sd=bpy.data.lights.new("Sun","SUN"); sd.energy=3; so=bpy.data.objects.new("Sun",sd); sc.collection.objects.link(so)
so.rotation_euler=(math.radians(52),math.radians(8),math.radians(-38))
cam_data=bpy.data.cameras.new("Cam"); cam_data.lens=52
cam=bpy.data.objects.new("Cam",cam_data); sc.collection.objects.link(cam); sc.camera=cam
def shoot(name, loc, target=(0,0,0.5)):
    cam.location=loc; cam.rotation_euler=(Vector(target)-Vector(loc)).to_track_quat('-Z','Y').to_euler()
    sc.render.filepath=f"{REND}/{name}.png"; bpy.ops.render.render(write_still=True); print("RENDERED",name)
# A: candidates highlighted on body, joints hidden
for o in joint_objs: o.hide_render=True
shoot("weapon_cand_front",(0,-2.15,0.55)); shoot("weapon_cand_sideR",(-2.15,0,0.55))
# B: candidates only
obj.hide_render=True
shoot("weapon_cand_only_front",(0,-2.15,0.55)); shoot("weapon_cand_only_sideR",(-2.15,0,0.55))
# C: joints on body, candidates normal visibility off (hide cand mesh, body back)
obj.hide_render=False; wobj.hide_render=True
for o in joint_objs: o.hide_render=False
shoot("joints_front",(0,-2.15,0.55)); shoot("joints_sideR",(-2.15,0,0.55)); shoot("joints_sideL",(2.15,0,0.55))
print("DONE")
