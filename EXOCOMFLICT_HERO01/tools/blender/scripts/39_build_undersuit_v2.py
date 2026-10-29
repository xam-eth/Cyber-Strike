"""SUPERSEDED - DO NOT RUN (180-deg angle bug + AgX-washed red threshold; see 43). Build HERO_01_UNDERSUIT v2 (owner-approved, VALIDATION_REPORT 5.9). v1's radial poke metric
was invalid on loose-shell geometry; v2 gates on RENDERS: tube in red emissive must be
invisible (<50 red px/view) from 7 orbit angles at F0 in full assembly. Auto-shrinks on fail.
Additive only; blend saved only on pass. Dark material restored before save."""
import bpy, math, os
import numpy as np
from mathutils import Vector
from PIL import Image
PROJ="/home/user/Cyber-Strike/EXOCOMFLICT_HERO01"; SHOT=f"{PROJ}/screenshots/diag"; os.makedirs(SHOT, exist_ok=True)
bpy.ops.wm.open_mainfile(filepath=f"{PROJ}/blender/HERO_01_working.blend")
sc=bpy.context.scene
arm=bpy.data.objects["HERO_01_Armature"]; body=bpy.data.objects["HERO_01_BODY"]
me=body.data; n=len(me.vertices)
gnames=[g.name for g in body.vertex_groups]; ng=len(gnames)
sc.frame_set(0); bpy.context.view_layer.update()
if "HERO_01_UNDERSUIT" in bpy.data.objects:
    bpy.data.objects.remove(bpy.data.objects["HERO_01_UNDERSUIT"], do_unlink=True)
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
co0=np.empty(n*3); me.vertices.foreach_get("co", co0); P0=co0.reshape(-1,3)
vertW=[None]*n; W=np.zeros((len(uniq), ng)); cnt=np.zeros(len(uniq))
for v in me.vertices:
    i=island[v.index]; cnt[i]+=1
    vertW[v.index]={gnames[g.group]: float(g.weight) for g in v.groups}
    for g in v.groups: W[i,g.group]+=g.weight
W/=np.maximum(cnt,1)[:,None]
ARM={"Clavicle_L","Clavicle_R","UpperArm_L","UpperArm_R","Forearm_L","Forearm_R","Hand_L","Hand_R","Weapon_R"}
arm_idx=[gnames.index(a) for a in ARM if a in gnames]
arm_mean=W[:, arm_idx].sum(axis=1)
torso_vert=np.array([arm_mean[island[v]]<0.05 for v in range(n)])
print("torso verts:", int(torso_vert.sum()))
# spine field refit (script 31 method)
CHAIN={"Root","Hips","Spine","Chest","UpperChest","Neck"}
FB=["Hips","Spine","Chest","UpperChest","Neck","Root"]
chain=np.array([(set(vertW[i].keys())<=CHAIN and len(vertW[i])>0) for i in range(n)])
zbins=np.arange(0.435, 0.8251, 0.004)
field=np.zeros((len(zbins), len(FB))); fcnt=np.zeros(len(zbins))
sel=np.nonzero(chain & (P0[:,2]>=zbins[0]) & (P0[:,2]<=zbins[-1]))[0]
bi=np.clip(np.digitize(P0[sel,2], zbins)-1, 0, len(zbins)-1)
for k,i in enumerate(sel):
    fcnt[bi[k]]+=1
    for j,bn in enumerate(FB): field[bi[k],j]+=vertW[int(i)].get(bn,0.0)
nz=fcnt>0; field[nz]/=fcnt[nz][:,None]
run=None
for k in range(len(zbins)):
    if nz[k]: run=field[k]
    elif run is not None: field[k]=run
run=None
for k in range(len(zbins)-1,-1,-1):
    if nz[k]: run=field[k]
    elif run is not None and fcnt[k]==0: field[k]=run
ker=np.ones(5)/5
for j in range(len(FB)): field[:,j]=np.convolve(np.pad(field[:,j],2,mode='edge'), ker, mode='valid')
field/=np.maximum(field.sum(axis=1, keepdims=True), 1e-9)
def field_at(z):
    z=float(np.clip(z, zbins[0], zbins[-1]))
    t=(z-zbins[0])/0.004; k0=int(np.clip(np.floor(t),0,len(zbins)-1)); k1=min(k0+1,len(zbins)-1); f=float(np.clip(t-k0,0,1))
    return field[k0]*(1-f)+field[k1]*f
SEG=32
ring_z=np.arange(0.475, 0.7401, 0.015)
centers=[]; radii=[]; binmax=[]
for zk in ring_z:
    m=torso_vert & (np.abs(P0[:,2]-zk)<0.012)
    pts=P0[m]; c=pts.mean(axis=0); centers.append(c)
    d=pts[:,:2]-c[:2]; r=np.linalg.norm(d, axis=1); a=np.arctan2(d[:,1], d[:,0])
    ab=((a+np.pi)/(2*np.pi)*SEG).astype(int)%SEG
    rr=np.full(SEG, np.nan); mx=np.full(SEG, np.nan)
    for s in range(SEG):
        rs=r[ab==s]
        if len(rs)>=3: rr[s]=float(np.percentile(rs,70)); mx[s]=float(rs.max())
    for arr in (rr,mx):
        good=~np.isnan(arr)
        if good.any():
            idx=np.arange(SEG); arr[:]=np.interp(idx, idx[good], arr[good], period=SEG)
    radii.append(np.minimum(rr, mx*0.97)); binmax.append(mx)
centers=np.array(centers); radii=np.array(radii)
radii=(np.roll(radii,1,axis=1)+2*radii+np.roll(radii,-1,axis=1))/4.0
radii[1:-1]=(radii[:-2]+2*radii[1:-1]+radii[2:])/4.0
radii=np.maximum(radii, 0.035)
print("rings:", len(ring_z), "radius range:", round(float(radii.min()),3), round(float(radii.max()),3))
def build_tube(factor):
    verts=[]
    c=centers[0]
    for s in range(SEG):
        a=2*np.pi*s/SEG; r=radii[0,s]*factor*0.62
        verts.append((c[0]+r*np.cos(a), c[1]+r*np.sin(a), 0.465))
    for k,zk in enumerate(ring_z):
        c=centers[k]; shrink=0.90 if zk<0.49 else (0.88 if zk>0.725 else 1.0)
        for s in range(SEG):
            a=2*np.pi*s/SEG; r=radii[k,s]*factor*shrink
            verts.append((c[0]+r*np.cos(a), c[1]+r*np.sin(a), float(zk)))
    c=centers[-1]
    for s in range(SEG):
        a=2*np.pi*s/SEG; r=radii[-1,s]*factor*0.62
        verts.append((c[0]+r*np.cos(a), c[1]+r*np.sin(a), 0.748))
    polys=[]; rings=len(verts)//SEG
    for k in range(rings-1):
        for s in range(SEG):
            polys.append((k*SEG+s, k*SEG+(s+1)%SEG, (k+1)*SEG+(s+1)%SEG, (k+1)*SEG+s))
    return np.array(verts), polys
# materials
dark=bpy.data.materials.new("HERO_01_UNDERSUIT_MAT"); dark.use_nodes=True
try: dark.use_backface_culling=False
except Exception: pass
db=dark.node_tree.nodes["Principled BSDF"]
db.inputs["Base Color"].default_value=(0.055,0.055,0.065,1); db.inputs["Roughness"].default_value=0.92; db.inputs["Metallic"].default_value=0.0
red=bpy.data.materials.new("TMP_RED"); red.use_nodes=True
rb=red.node_tree.nodes["Principled BSDF"]
rb.inputs["Base Color"].default_value=(0.05,0,0,1); rb.inputs["Emission Color"].default_value=(1,0.05,0.05,1); rb.inputs["Emission Strength"].default_value=3.0
def make_object(verts, polys):
    tm=bpy.data.meshes.new("HERO_01_UNDERSUIT")
    tm.from_pydata([tuple(v) for v in verts], [], polys); tm.update()
    tm.calc_loop_triangles()
    p0=tm.polygons[SEG*2]; c=p0.center
    radial=np.array([c.x-centers[2][0], c.y-centers[2][1], 0.0])
    if float(np.dot(np.array(p0.normal), radial))<0: tm.flip_normals()
    tob=bpy.data.objects.new("HERO_01_UNDERSUIT", tm); sc.collection.objects.link(tob)
    for name in gnames: tob.vertex_groups.new(name=name)
    vg={g.name:g for g in tob.vertex_groups}
    for j,v in enumerate(verts):
        fv=field_at(v[2]); acc={FB[k]: float(fv[k]) for k in range(len(FB)) if fv[k]>1e-4}
        if v[2]<0.470: acc={"Hips":1.0}
        top=sorted(acc.items(), key=lambda kv:-kv[1])[:4]; s=sum(vv for _,vv in top) or 1.0
        for bn,val in top:
            if val/s>1e-4: vg[bn].add([j], val/s, 'ADD')
    mod=tob.modifiers.new("Armature", 'ARMATURE'); mod.object=arm
    tob.parent=body.parent
    tm.materials.append(red)
    return tob
# render gate setup
sc.render.engine="CYCLES"; sc.cycles.samples=8; sc.cycles.use_denoising=False; sc.cycles.device="CPU"
w=bpy.data.worlds.new("W"); sc.world=w; w.use_nodes=True
w.node_tree.nodes["Background"].inputs[0].default_value=(0.16,0.17,0.19,1)
w.node_tree.nodes["Background"].inputs[1].default_value=0.9
sd=bpy.data.lights.new("Sun","SUN"); sd.energy=3; so=bpy.data.objects.new("Sun",sd); sc.collection.objects.link(so)
so.rotation_euler=(math.radians(52),math.radians(8),math.radians(-38))
cam=bpy.data.objects.new("Cam",bpy.data.cameras.new("Cam")); cam.data.lens=52; sc.collection.objects.link(cam); sc.camera=cam
arm.hide_render=True
VIEWS=[("front",(0,-1.6,0.56)),("back",(0,1.6,0.56)),("left",(1.6,0,0.56)),("right",(-1.6,0,0.56)),
       ("fl",(1.15,-1.15,0.62)),("fr",(-1.15,-1.15,0.62)),("top",(0.6,-0.9,1.5))]
def red_count(path):
    a=np.asarray(Image.open(path).convert("RGB")).astype(int)
    return int(((a[:,:,0]>140)&(a[:,:,1]<90)&(a[:,:,2]<90)).sum())
def gate(tob):
    worst=0
    for name,loc in VIEWS:
        cam.location=loc
        cam.rotation_euler=(Vector((0,0,0.56))-Vector(loc)).to_track_quat('-Z','Y').to_euler()
        sc.render.resolution_x=700; sc.render.resolution_y=700
        p=f"{SHOT}/usgate_{name}.png"; sc.render.filepath=p
        bpy.ops.render.render(write_still=True)
        rc=red_count(p); worst=max(worst, rc)
        print(f"  view {name}: red px = {rc}")
    return worst
factor=0.96; passed=False
for attempt in range(4):
    verts, polys = build_tube(factor)
    tob=make_object(verts, polys)
    sc.frame_set(0); bpy.context.view_layer.update()
    print(f"ATTEMPT factor={factor:.2f} verts={len(verts)}")
    worst=gate(tob)
    print(f" -> worst red px {worst}")
    if worst<50: passed=True; break
    bpy.data.objects.remove(tob, do_unlink=True); factor-=0.03
if passed:
    tob.data.materials[0]=dark
    # preview: plugged slit at F36 left profile with real material
    sc.cycles.samples=24; sc.cycles.use_denoising=True
    sc.frame_set(36); cam.location=(1.15,-0.05,0.58)
    cam.rotation_euler=(Vector((0,-0.02,0.56))-Vector((1.15,-0.05,0.58))).to_track_quat('-Z','Y').to_euler()
    sc.render.resolution_x=900; sc.render.resolution_y=900; sc.render.filepath=f"{SHOT}/us_preview_F36_profL.png"
    bpy.ops.render.render(write_still=True); print("RENDERED us_preview_F36_profL")
    sc.frame_set(0); bpy.context.view_layer.update()
    bpy.ops.wm.save_mainfile(); print(f"SAVED blend (factor={factor:.2f})")
else:
    print("NOT SAVED: poke gate failed at all factors")
print("DONE")
