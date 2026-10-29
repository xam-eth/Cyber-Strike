"""Separate weapon, build humanoid armature, skin weights (auto attempt -> proximity + island rules)."""
import bpy, json, math, os
import numpy as np
from mathutils import Vector

PROJ="/home/user/Cyber-Strike/EXOCOMFLICT_HERO01"
OUT=f"{PROJ}/tools/out"; REND=f"{PROJ}/screenshots/rig"
os.makedirs(REND, exist_ok=True); os.makedirs(f"{PROJ}/blender", exist_ok=True)

bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.ops.import_scene.gltf(filepath=f"{PROJ}/assets/source/HERO_01.glb")
obj=[o for o in bpy.context.scene.objects if o.type=="MESH"][0]
obj.name="HERO_01_BODY"; obj.data.name="HERO_01_BODY"
print("OBJ matrix_world:\n", np.array(obj.matrix_world).round(4))
bpy.context.view_layer.objects.active=obj; obj.select_set(True)
bpy.ops.object.transform_apply(location=True, rotation=True, scale=True)

# --- weapon separation by island ids (vertex order = audit import order) ---
isl=np.load(f"{OUT}/blender_island_ids.npy")
cand=[int(c) for c in json.load(open(f"{OUT}/weapon_candidates.json"))["weapon_candidate_islands"]]
# v2 rule (contact-sheet adjudicated): lateral of hand centerline OR below grip = weapon.
# Ambiguous grip-zone islands stay with BODY so the modeled hand remains intact.
_mw0=np.array(obj.matrix_world); _co0=np.empty(len(obj.data.vertices)*3); obj.data.vertices.foreach_get("co",_co0); _w0=(_mw0[:3,:3]@_co0.reshape(-1,3).T).T+_mw0[:3,3]
_ctr={i:_w0[isl==i].mean(0) for i in set(cand)|{45,40,32}}
WEAPON_ISLANDS=sorted(i for i in (set(cand)|{45,40}) if _ctr[i][0] < -0.188 or _ctr[i][2] < 0.42)
print("WEAPON ISLANDS v2:", WEAPON_ISLANDS)
print("returned to body:", sorted((set(cand)|{45,40,32})-set(WEAPON_ISLANDS)))
json.dump({"weapon_islands_final_v1":WEAPON_ISLANDS}, open(f"{OUT}/weapon_final.json","w"), indent=1)
mask=np.isin(isl, np.array(WEAPON_ISLANDS))
m=obj.data; assert len(mask)==len(m.vertices)
import bmesh as _bm
bpy.context.view_layer.objects.active=obj; obj.select_set(True)
bpy.ops.object.mode_set(mode='EDIT')
_b=_bm.from_edit_mesh(m); _b.verts.ensure_lookup_table()
for v in _b.verts: v.select_set(bool(mask[v.index]))
_b.select_flush_mode(); _bm.update_edit_mesh(m)
print("selected for weapon:", int(mask.sum()))
bpy.ops.mesh.separate(type='SELECTED'); bpy.ops.object.mode_set(mode='OBJECT')
meshes=[o for o in bpy.context.scene.objects if o.type=="MESH"]
weapon=min(meshes, key=lambda o: len(o.data.vertices)); body=max(meshes, key=lambda o: len(o.data.vertices))
weapon.name="HERO_01_WEAPON"; weapon.data.name="HERO_01_WEAPON"
body.name="HERO_01_BODY"; body.data.name="HERO_01_BODY"
print(f"SEPARATED body verts={len(body.data.vertices)} weapon verts={len(weapon.data.vertices)} weapon polys={len(weapon.data.polygons)}")
assert len(weapon.data.vertices)>15000, "weapon separation failed"

def world_verts(o):
    n=len(o.data.vertices); co=np.empty(n*3); o.data.vertices.foreach_get("co",co); co=co.reshape(-1,3)
    mw=np.array(o.matrix_world); return (mw[:3,:3]@co.T).T+mw[:3,3]
def islands_of(o):
    n=len(o.data.vertices); ne=len(o.data.edges)
    ev=np.empty(ne*2,dtype=np.int64); o.data.edges.foreach_get("vertices",ev); ev=ev.reshape(-1,2)
    parent=np.arange(n)
    def find(x):
        while parent[x]!=x:
            parent[x]=parent[parent[x]]; x=parent[x]
        return x
    for a,b in ev:
        ra,rb=find(int(a)),find(int(b))
        if ra!=rb: parent[rb]=ra
    roots=np.array([find(i) for i in range(n)])
    _,inv=np.unique(roots,return_inverse=True)
    return inv, ev
bw=world_verts(body); bisl, bedges = islands_of(body)
print("body islands:", int(bisl.max()+1))

# --- armature ---
J=json.load(open(f"{OUT}/joints_proposal.json"))
J["UpperLeg_R"][1]=[-0.105,-0.005,0.275]; J["LowerLeg_R"][0]=[-0.105,-0.005,0.275]
for s in ("R","L"):
    J[f"Foot_{s}"][1][1]=-0.048; J[f"Toe_{s}"][0][1]=-0.048; J[f"Toe_{s}"][1][1]=-0.075; J[f"Toe_{s}"][1][2]=0.028
json.dump(J, open(f"{OUT}/joints_final_v1.json","w"), indent=1)
PARENTS={"Root":None,"Hips":("Root",False),"Spine":("Hips",True),"Chest":("Spine",True),"UpperChest":("Chest",True),
 "Neck":("UpperChest",True),"Head":("Neck",True),
 "Clavicle_R":("UpperChest",False),"UpperArm_R":("Clavicle_R",True),"Forearm_R":("UpperArm_R",True),"Hand_R":("Forearm_R",True),"Weapon_R":("Hand_R",False),
 "Clavicle_L":("UpperChest",False),"UpperArm_L":("Clavicle_L",True),"Forearm_L":("UpperArm_L",True),"Hand_L":("Forearm_L",True),
 "UpperLeg_R":("Hips",False),"LowerLeg_R":("UpperLeg_R",True),"Foot_R":("LowerLeg_R",True),"Toe_R":("Foot_R",True),
 "UpperLeg_L":("Hips",False),"LowerLeg_L":("UpperLeg_L",True),"Foot_L":("LowerLeg_L",True),"Toe_L":("Foot_L",True)}
NODEFORM={"Root","Weapon_R"}
arm_data=bpy.data.armatures.new("HERO_01_Armature")
arm=bpy.data.objects.new("HERO_01_Armature", arm_data); bpy.context.scene.collection.objects.link(arm)
bpy.context.view_layer.objects.active=arm; bpy.ops.object.mode_set(mode='EDIT')
for name,(h,t) in J.items():
    b=arm_data.edit_bones.new(name); b.head=h; b.tail=t; b.use_deform=name not in NODEFORM
for name,par in PARENTS.items():
    if par:
        b=arm_data.edit_bones[name]; b.parent=arm_data.edit_bones[par[0]]; b.use_connect=par[1]
bpy.ops.object.mode_set(mode='OBJECT')
print("BONES:", [b.name for b in arm_data.bones])

DEFORM=[b.name for b in arm_data.bones if b.use_deform]
# --- attempt Blender automatic weights, measure coverage ---
bpy.ops.object.select_all(action='DESELECT'); body.select_set(True); arm.select_set(True)
bpy.context.view_layer.objects.active=arm
try:
    bpy.ops.object.parent_set(type='ARMATURE_AUTO')
    print("ARMATURE_AUTO done; vertex groups now:", [g.name for g in body.vertex_groups][:8], "... total", len(body.vertex_groups))
except Exception as e:
    print("ARMATURE_AUTO failed:", e)
def read_weights(o, bones):
    gi={g.name:g.index for g in o.vertex_groups}
    W=np.zeros((len(o.data.vertices), len(bones)), dtype=np.float32)
    bmap={gi[b]:i for i,b in enumerate(bones) if b in gi}
    for v in o.data.vertices:
        for g in v.groups:
            if g.group in bmap: W[v.index, bmap[g.group]]=g.weight
    return W
W=read_weights(body, DEFORM)
zero=int((W.sum(1)<=1e-6).sum()); print(f"AUTO coverage: zero-weight verts {zero}/{len(W)} ({100*zero/len(W):.1f}%)")

# --- proximity weights (point-to-bone-segment), used where auto is missing/weak ---
segs={}
for name in DEFORM:
    b=arm_data.bones[name]; segs[name]=(np.array(b.head_local), np.array(b.tail_local))
def seg_dist(P,a,b):
    ab=b-a; t=np.clip(((P-a)@ab)/max(ab@ab,1e-12),0,1)
    proj=a+np.outer(t,ab); return np.linalg.norm(P-proj,axis=1)
D=np.stack([seg_dist(bw,*segs[n]) for n in DEFORM],axis=1).astype(np.float32)
WP=(1.0/(D+0.004))**3
WP/=WP.sum(1,keepdims=True)
# blend policy: verts with auto total>0.5 keep auto (normalized); others take proximity
auto_tot=W.sum(1)
Wn=np.where(auto_tot[:,None]>1e-6, W/np.maximum(auto_tot,1e-9)[:,None], 0)
use_auto=(auto_tot>0.5)[:,None]
W=np.where(use_auto, Wn, WP).astype(np.float32)
print(f"weights source: auto {int((auto_tot>0.5).sum())} verts, proximity {int((auto_tot<=0.5).sum())} verts")
# head/face lock: islands with center z>=0.845 -> Head
hi=DEFORM.index("Head")
for i in range(int(bisl.max()+1)):
    mask=bisl==i; c=bw[mask].mean(0)
    if c[2]>=0.845:
        W[mask]=0; W[mask,hi]=1.0
# edge smoothing (2 iterations, intra-island only since edges don't cross islands)
for _ in range(2):
    acc=W.copy(); deg=np.ones(len(W),dtype=np.float32)
    np.add.at(acc, bedges[:,0], W[bedges[:,1]]*0.5); np.add.at(acc, bedges[:,1], W[bedges[:,0]]*0.5)
    np.add.at(deg, bedges[:,0], 0.5); np.add.at(deg, bedges[:,1], 0.5)
    W=(acc/deg[:,None]).astype(np.float32)
# island rigidification for small plates
for i in range(int(bisl.max()+1)):
    mask=bisl==i; n=int(mask.sum())
    if n<8 or n>2500: continue
    vv=bw[mask]
    if (vv.max(0)-vv.min(0)).max()>0.09: continue
    avg=W[mask].mean(0); avg/=max(avg.sum(),1e-9)
    if avg.max()>0.72:
        avg=np.zeros_like(avg); avg[int(np.argmax(W[mask].mean(0)))]=1.0
    W[mask]=avg
# top-4 + normalize
idx=np.argpartition(-W,4,axis=1)[:,4:]
np.put_along_axis(W,idx,0,axis=1)
W=np.clip(W,0,None); W/=np.maximum(W.sum(1,keepdims=True),1e-9)
zero2=int((W.sum(1)<=1e-6).sum()); print("FINAL zero-weight verts:",zero2)
dom=W.argmax(1)
for bi,n in enumerate(DEFORM): print(f" dominant[{n}]={int((dom==bi).sum())}")
# write back to vertex groups
for g in list(body.vertex_groups): body.vertex_groups.remove(g)
for bi,name in enumerate(DEFORM):
    g=body.vertex_groups.new(name=name)
    sel=np.flatnonzero(W[:,bi]>1e-4)
    for vi in sel: g.add([int(vi)], float(W[vi,bi]), 'REPLACE')
if not any(md.type=='ARMATURE' for md in body.modifiers):
    md=body.modifiers.new("Armature",'ARMATURE'); md.object=arm
body.parent=arm
np.save(f"{OUT}/body_island_ids.npy", bisl.astype(np.int32))
bpy.ops.wm.save_mainfile(filepath=f"{PROJ}/blender/HERO_01_working.blend")
print("SAVED blend")

# --- separation verification renders (helpers not saved) ---
sc=bpy.context.scene
sc.render.engine="CYCLES"; sc.cycles.samples=24; sc.cycles.use_denoising=True; sc.cycles.device="CPU"
w=bpy.data.worlds.new("W"); sc.world=w; w.use_nodes=True
w.node_tree.nodes["Background"].inputs[0].default_value=(0.16,0.17,0.19,1); w.node_tree.nodes["Background"].inputs[1].default_value=0.9
sd=bpy.data.lights.new("Sun","SUN"); sd.energy=3; so=bpy.data.objects.new("Sun",sd); sc.collection.objects.link(so)
so.rotation_euler=(math.radians(52),math.radians(8),math.radians(-38))
bpy.ops.mesh.primitive_plane_add(size=8, location=(0,0,0)); gnd=bpy.context.active_object
gm=bpy.data.materials.new("Ground"); gm.use_nodes=True; gm.node_tree.nodes["Principled BSDF"].inputs["Base Color"].default_value=(0.23,0.24,0.27,1)
gnd.data.materials.append(gm)
cam=bpy.data.objects.new("Cam",bpy.data.cameras.new("Cam")); cam.data.lens=52; sc.collection.objects.link(cam); sc.camera=cam
arm.hide_render=True
def shoot(name,loc,target,rx=700,ry=875,lens=52):
    cam.data.lens=lens; cam.location=loc; cam.rotation_euler=(Vector(target)-Vector(loc)).to_track_quat('-Z','Y').to_euler()
    sc.render.resolution_x=rx; sc.render.resolution_y=ry
    sc.render.filepath=f"{REND}/{name}.png"; bpy.ops.render.render(write_still=True); print("RENDERED",name)
weapon.hide_render=True
shoot("sep_body_hand_front",(-0.17,-0.55,0.48),(-0.17,-0.01,0.44),700,800,55)
shoot("sep_body_hand_sideR",(-0.72,-0.01,0.48),(-0.17,-0.01,0.44),700,800,55)
body.hide_render=True; weapon.hide_render=False; gnd.hide_render=True
shoot("sep_weapon_front",(-0.20,-0.85,0.40),(-0.20,-0.03,0.38),700,900,52)
shoot("sep_weapon_sideR",(-1.05,-0.03,0.40),(-0.20,-0.03,0.38),700,900,52)
body.hide_render=False; gnd.hide_render=False
shoot("sep_both_threeq",(-1.4,-1.4,0.68),(0,0,0.48),760,950,52)
print("DONE")
