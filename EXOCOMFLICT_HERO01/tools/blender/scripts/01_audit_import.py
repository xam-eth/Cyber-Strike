"""Phase A in Blender: import HERO_01.glb, measure islands/joint landmarks, baseline renders."""
import bpy, json, math, os
import numpy as np
from mathutils import Vector

PROJ="/home/user/Cyber-Strike/EXOCOMFLICT_HERO01"
SRC=f"{PROJ}/assets/source/HERO_01.glb"
OUT=f"{PROJ}/tools/out"; os.makedirs(OUT, exist_ok=True)
REND=f"{PROJ}/screenshots/baseline"; os.makedirs(REND, exist_ok=True)

bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.ops.import_scene.gltf(filepath=SRC)

info={"objects":[]}
mesh_obj=None
for o in bpy.context.scene.objects:
    rec={"name":o.name,"type":o.type,"location":list(o.location),"rotation_euler_deg":[math.degrees(a) for a in o.rotation_euler],"scale":list(o.scale),"dimensions":list(o.dimensions)}
    if o.type=="MESH":
        mesh_obj=o; m=o.data
        rec["verts"]=len(m.vertices); rec["edges"]=len(m.edges); rec["polygons"]=len(m.polygons)
        rec["materials"]=[ms.material.name if ms.material else None for ms in o.material_slots]
        rec["uv_layers"]=[l.name for l in m.uv_layers]
        rec["vertex_groups"]=[g.name for g in o.vertex_groups]
        rec["modifiers"]=[md.type for md in o.modifiers]
        rec["bound_box_world_min"]=list(o.matrix_world @ Vector(o.bound_box[0]))
        rec["bound_box_world_max"]=list(o.matrix_world @ Vector(o.bound_box[6]))
    info["objects"].append(rec)
info["images"]=[{"name":im.name,"size":list(im.size),"filepath":im.filepath} for im in bpy.data.images]
info["materials"]=[]
for mt in bpy.data.materials:
    info["materials"].append({"name":mt.name,"use_nodes":mt.use_nodes,"nodes":[n.type for n in mt.node_tree.nodes] if mt.use_nodes and mt.node_tree else []})
print(json.dumps(info,indent=1))

m=mesh_obj.data
nv=len(m.vertices)
co=np.empty(nv*3); m.vertices.foreach_get("co",co); co=co.reshape(-1,3)
mw=np.array(mesh_obj.matrix_world)
world=(mw[:3,:3]@co.T).T+mw[:3,3]
ne=len(m.edges); ev=np.empty(ne*2,dtype=np.int64); m.edges.foreach_get("vertices",ev); ev=ev.reshape(-1,2)
# union-find islands
parent=np.arange(nv)
def find(x):
    while parent[x]!=x:
        parent[x]=parent[parent[x]]; x=parent[x]
    return x
for a,b in ev:
    ra,rb=find(int(a)),find(int(b))
    if ra!=rb: parent[rb]=ra
roots=np.array([find(i) for i in range(nv)])
uniq,inv,cnt=np.unique(roots,return_inverse=True,return_counts=True)
print(f"ISLANDS: {len(uniq)}  (verts={nv} edges={ne})")
np.save(f"{OUT}/blender_island_ids.npy", inv.astype(np.int32))
islands=[]
order=np.argsort(-cnt)
for rank,oi in enumerate(order[:80]):
    mask=inv==oi; vv=world[mask]
    islands.append({"island":int(oi),"verts":int(cnt[oi]),"center":[round(float(x),4) for x in vv.mean(0)],
        "min":[round(float(x),4) for x in vv.min(0)],"max":[round(float(x),4) for x in vv.max(0)],
        "extents":[round(float(x),4) for x in (vv.max(0)-vv.min(0))]})
json.dump({"blender_info":info,"island_count":int(len(uniq)),"top_islands":islands}, open(f"{OUT}/blender_audit.json","w"), indent=1)
for isl in islands[:25]: print("ISL",isl)

# --- joint landmark slices (Blender world: Z-up, character faces -Y, height ~1) ---
X,Y,Z=world[:,0],world[:,1],world[:,2]
print(f"WORLD BOUNDS min={world.min(0).round(3)} max={world.max(0).round(3)}")
def band(label, zlo, zhi, mask_extra=None):
    mask=(Z>=zlo)&(Z<zhi)
    if mask_extra is not None: mask&=mask_extra
    if mask.sum()<10: print(label,"<empty>"); return
    c=world[mask].mean(0); print(f"{label:28s} n={mask.sum():6d} centroid=({c[0]:+.3f},{c[1]:+.3f},{c[2]:.3f}) x[{X[mask].min():+.3f},{X[mask].max():+.3f}] y[{Y[mask].min():+.3f},{Y[mask].max():+.3f}]")
print("-- torso/head (all x) --")
for zlo in [0.95,0.90,0.85,0.80,0.75,0.70,0.65,0.60,0.55,0.50,0.45]:
    band(f"z {zlo:.2f}-{zlo+0.05:.2f}", zlo, zlo+0.05)
print("-- legs split L/R (x<0 / x>0), z<0.55 --")
for zlo in [0.50,0.45,0.40,0.35,0.30,0.25,0.20,0.15,0.10,0.05,0.00]:
    band(f"leg R x<0 z{zlo:.2f}", zlo, zlo+0.05, X<0); band(f"leg L x>0 z{zlo:.2f}", zlo, zlo+0.05, X>0)
print("-- arms split (|x|>0.11), upper body --")
for zlo in [0.80,0.75,0.70,0.65,0.60,0.55,0.50,0.45,0.40,0.35,0.30,0.25]:
    band(f"arm R x<-0.11 z{zlo:.2f}", zlo, zlo+0.05, X<-0.11); band(f"arm L x>0.11 z{zlo:.2f}", zlo, zlo+0.05, X>0.11)

# --- baseline Cycles renders ---
sc=bpy.context.scene
sc.render.engine="CYCLES"; sc.cycles.samples=24; sc.cycles.use_denoising=True; sc.cycles.device="CPU"
sc.render.resolution_x=760; sc.render.resolution_y=950; sc.render.resolution_percentage=100
w=bpy.data.worlds.new("W"); sc.world=w; w.use_nodes=True
bg=w.node_tree.nodes["Background"]; bg.inputs[0].default_value=(0.16,0.17,0.19,1); bg.inputs[1].default_value=0.9
sun_data=bpy.data.lights.new("Sun","SUN"); sun_data.energy=3.0; sun_data.angle=math.radians(12)
sun=bpy.data.objects.new("Sun",sun_data); sc.collection.objects.link(sun); sun.rotation_euler=(math.radians(52),math.radians(8),math.radians(-38))
fill_data=bpy.data.lights.new("Fill","SUN"); fill_data.energy=0.7
fill=bpy.data.objects.new("Fill",fill_data); sc.collection.objects.link(fill); fill.rotation_euler=(math.radians(70),0,math.radians(150))
bpy.ops.mesh.primitive_plane_add(size=8, location=(0,0,0))
ground=bpy.context.active_object; gmat=bpy.data.materials.new("Ground"); gmat.use_nodes=True
gmat.node_tree.nodes["Principled BSDF"].inputs["Base Color"].default_value=(0.23,0.24,0.27,1)
gmat.node_tree.nodes["Principled BSDF"].inputs["Roughness"].default_value=0.95
ground.data.materials.append(gmat)
cam_data=bpy.data.cameras.new("Cam"); cam_data.lens=52
cam=bpy.data.objects.new("Cam",cam_data); sc.collection.objects.link(cam); sc.camera=cam
def shoot(name, loc, target=(0,0,0.5)):
    cam.location=loc
    d=(Vector(target)-Vector(loc)); cam.rotation_euler=d.to_track_quat('-Z','Y').to_euler()
    sc.render.filepath=f"{REND}/hero01_blender_{name}.png"
    bpy.ops.render.render(write_still=True); print("RENDERED",name)
shoot("front",(0,-2.15,0.55)); shoot("back",(0,2.15,0.55))
shoot("side_weapon_R",(-2.15,0,0.55)); shoot("side_L",(2.15,0,0.55))
shoot("threeq_front_R",(-1.4,-1.4,0.68),(0,0,0.48))
print("DONE")
