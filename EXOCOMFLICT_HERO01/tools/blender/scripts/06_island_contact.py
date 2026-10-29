"""Per-island contact renders (textured) for weapon/hand adjudication."""
import bpy, json, math, os
import numpy as np
from mathutils import Vector
PROJ="/home/user/Cyber-Strike/EXOCOMFLICT_HERO01"
OUT=f"{PROJ}/tools/out"; REND=f"{PROJ}/screenshots/audit/islands"; os.makedirs(REND, exist_ok=True)
bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.ops.import_scene.gltf(filepath=f"{PROJ}/assets/source/HERO_01.glb")
obj=[o for o in bpy.context.scene.objects if o.type=="MESH"][0]
m=obj.data; nv=len(m.vertices)
co=np.empty(nv*3); m.vertices.foreach_get("co",co); co=co.reshape(-1,3)
mw=np.array(obj.matrix_world); world=(mw[:3,:3]@co.T).T+mw[:3,3]
isl=np.load(f"{OUT}/blender_island_ids.npy")
grp=json.load(open(f"{OUT}/weapon_groups.json"))
cand=grp["cand40"]; suspects=grp["grip_suspects"]; core=grp["core"]
centers={i:world[isl==i].mean(0) for i in cand+[45,40,32]}
T=sorted(set(suspects+[i for i in core if centers[i][2]>=0.40]+[45,40,32]))
print("TARGET ISLANDS:",T)
vg=obj.vertex_groups.new(name="ISO")
md=obj.modifiers.new("IsoMask",'MASK'); md.vertex_group="ISO"; md.threshold=0.5
sc=bpy.context.scene
sc.render.engine="CYCLES"; sc.cycles.samples=10; sc.cycles.use_denoising=True; sc.cycles.device="CPU"
sc.render.resolution_x=300; sc.render.resolution_y=300
w=bpy.data.worlds.new("W"); sc.world=w; w.use_nodes=True
w.node_tree.nodes["Background"].inputs[0].default_value=(0.25,0.26,0.29,1); w.node_tree.nodes["Background"].inputs[1].default_value=1.1
sd=bpy.data.lights.new("Sun","SUN"); sd.energy=3.5; so=bpy.data.objects.new("Sun",sd); sc.collection.objects.link(so)
so.rotation_euler=(math.radians(50),math.radians(10),math.radians(-35))
cam=bpy.data.objects.new("Cam",bpy.data.cameras.new("Cam")); cam.data.lens=50; sc.collection.objects.link(cam); sc.camera=cam
ALL=list(range(nv))
for i in T:
    vv=world[isl==i]; c=vv.mean(0); ext=(vv.max(0)-vv.min(0))
    # PCA dims (4*std along principal axes)
    X=vv-c; cov=X.T@X/max(len(vv)-1,1); ev=np.linalg.eigvalsh(cov)[::-1]
    pca=(4*np.sqrt(np.maximum(ev,0))).round(3).tolist()
    print(f"ISL {i:3d} v={len(vv):5d} ctr=({c[0]:+.3f},{c[1]:+.3f},{c[2]:.3f}) bboxExt={ext.round(3).tolist()} pcaDims={pca}")
    vg.remove(ALL)
    vg.add([int(x) for x in np.flatnonzero(isl==i)], 1.0, 'REPLACE')
    r=float(ext.max())*0.5+0.012; dist=r*3.4
    for view,off in (("side",(-dist,0,0)),("front",(0,-dist,0))):
        loc=(c[0]+off[0],c[1]+off[1],c[2]+off[2])
        cam.location=loc; cam.rotation_euler=(Vector(c.tolist())-Vector(loc)).to_track_quat('-Z','Y').to_euler()
        sc.render.filepath=f"{REND}/isl{i:03d}_{view}.png"; bpy.ops.render.render(write_still=True)
    print(" rendered",i)
json.dump({"contact_islands":T}, open(f"{OUT}/contact_islands.json","w"))
print("DONE")
