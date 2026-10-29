"""SUPERSEDED - DO NOT RUN (full tube followed belt/gear envelope, covered source undershirt, failed silhouette gate; see 43). Build HERO_01_UNDERSUIT v3 (owner-approved, VALIDATION_REPORT 5.9). v2 had a 180-degree
angle-mapping bug (radii applied opposite to where measured) and an emissive-red threshold
washed out by AgX. v3: correct bin-center angles; gate = silhouette test (red pixels OUTSIDE
the body-only silhouette = poke => shrink+retry; red INSIDE silhouette = visible through
genuine shell openings, acceptable in dark material). Phase 1 finds factor; phase 2 reopens
the blend pristine, rebuilds with dark material only, saves. Source geometry untouched."""
import bpy, math, os
import numpy as np
from mathutils import Vector
from PIL import Image, ImageFilter
PROJ="/home/user/Cyber-Strike/EXOCOMFLICT_HERO01"; SHOT=f"{PROJ}/screenshots/diag"; os.makedirs(SHOT, exist_ok=True)
BLEND=f"{PROJ}/blender/HERO_01_working.blend"
bpy.ops.wm.open_mainfile(filepath=BLEND)
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
W=np.zeros((len(uniq), ng)); cnt=np.zeros(len(uniq))
vertW=[None]*n
for v in me.vertices:
    i=island[v.index]; cnt[i]+=1
    vertW[v.index]={gnames[g.group]: float(g.weight) for g in v.groups}
    for g in v.groups: W[i,g.group]+=g.weight
W/=np.maximum(cnt,1)[:,None]
ARM={"Clavicle_L","Clavicle_R","UpperArm_L","UpperArm_R","Forearm_L","Forearm_R","Hand_L","Hand_R","Weapon_R"}
arm_idx=[gnames.index(a) for a in ARM if a in gnames]
arm_mean=W[:, arm_idx].sum(axis=1)
torso_vert=np.array([arm_mean[island[v]]<0.05 for v in range(n)])
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
SEG=32; DANG=2*np.pi/SEG
def bin_angle(s): return -np.pi + (s+0.5)*DANG
ring_z=np.arange(0.475, 0.7401, 0.015)
centers=[]; radii=[]
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
    radii.append(np.minimum(rr, mx*0.97))
centers=np.array(centers); radii=np.array(radii)
for _ in range(2): radii=(np.roll(radii,1,axis=1)+2*radii+np.roll(radii,-1,axis=1))/4.0
radii[1:-1]=(radii[:-2]+2*radii[1:-1]+radii[2:])/4.0
radii=np.maximum(radii, 0.035)
print("rings:", len(ring_z), "radius range:", round(float(radii.min()),3), round(float(radii.max()),3))
print("center[waist z~0.55]:", np.round(centers[5],3), "center[chest z~0.70]:", np.round(centers[15],3))
def build_tube(factor):
    verts=[]
    c=centers[0]
    for s in range(SEG):
        a=bin_angle(s); r=radii[0,s]*factor*0.62
        verts.append((c[0]+r*np.cos(a), c[1]+r*np.sin(a), 0.465))
    for k,zk in enumerate(ring_z):
        c=centers[k]; shrink=0.90 if zk<0.49 else (0.88 if zk>0.725 else 1.0)
        for s in range(SEG):
            a=bin_angle(s); r=radii[k,s]*factor*shrink
            verts.append((c[0]+r*np.cos(a), c[1]+r*np.sin(a), float(zk)))
    c=centers[-1]
    for s in range(SEG):
        a=bin_angle(s); r=radii[-1,s]*factor*0.62
        verts.append((c[0]+r*np.cos(a), c[1]+r*np.sin(a), 0.748))
    polys=[]; rings=len(verts)//SEG
    for k in range(rings-1):
        for s in range(SEG):
            polys.append((k*SEG+s, k*SEG+(s+1)%SEG, (k+1)*SEG+(s+1)%SEG, (k+1)*SEG+s))
    return np.array(verts), polys
def make_object(verts, polys, mat):
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
    tm.materials.append(mat)
    return tob
red=bpy.data.materials.new("TMP_RED"); red.use_nodes=True
rb=red.node_tree.nodes["Principled BSDF"]
rb.inputs["Base Color"].default_value=(0,0,0,1); rb.inputs["Emission Color"].default_value=(1,0.03,0.03,1); rb.inputs["Emission Strength"].default_value=1.6
# render setup (phase 1 only; never saved)
sc.render.engine="CYCLES"; sc.cycles.samples=8; sc.cycles.use_denoising=False; sc.cycles.device="CPU"
try: sc.view_settings.view_transform='Standard'
except Exception as ex: print("view transform:", ex)
w=bpy.data.worlds.new("W"); sc.world=w; w.use_nodes=True
w.node_tree.nodes["Background"].inputs[0].default_value=(0.16,0.17,0.19,1)
w.node_tree.nodes["Background"].inputs[1].default_value=0.9
sd=bpy.data.lights.new("Sun","SUN"); sd.energy=3; so=bpy.data.objects.new("Sun",sd); sc.collection.objects.link(so)
so.rotation_euler=(math.radians(52),math.radians(8),math.radians(-38))
cam=bpy.data.objects.new("Cam",bpy.data.cameras.new("Cam")); cam.data.lens=52; sc.collection.objects.link(cam); sc.camera=cam
arm.hide_render=True
VIEWS=[("front",(0,-1.6,0.56)),("back",(0,1.6,0.56)),("left",(1.6,0,0.56)),("right",(-1.6,0,0.56)),
       ("fl",(1.15,-1.15,0.62)),("fr",(-1.15,-1.15,0.62)),("top",(0.6,-0.9,1.5))]
TARGET=Vector((0,0,0.56))
def render_view(name, loc, tag):
    cam.location=loc
    cam.rotation_euler=(TARGET-Vector(loc)).to_track_quat('-Z','Y').to_euler()
    sc.render.resolution_x=700; sc.render.resolution_y=700
    p=f"{SHOT}/usgate3_{tag}_{name}.png"; sc.render.filepath=p
    bpy.ops.render.render(write_still=True)
    return p
def body_mask(path):
    a=np.asarray(Image.open(path).convert("RGB")).astype(int)
    bg=np.median(np.concatenate([a[:8,:8].reshape(-1,3), a[:8,-8:].reshape(-1,3), a[-8:,:8].reshape(-1,3), a[-8:,-8:].reshape(-1,3)]), axis=0)
    m=(np.abs(a-bg).max(axis=2)>18)
    im=Image.fromarray((m*255).astype(np.uint8)).filter(ImageFilter.MaxFilter(5))
    return np.asarray(im)>0
def red_mask(path):
    a=np.asarray(Image.open(path).convert("RGB")).astype(int)
    return (a[:,:,0]>150)&((a[:,:,0]-a[:,:,1])>40)&((a[:,:,0]-a[:,:,2])>40)
# masks once (body only), F0 + F36
masks={}
for fr,views in [(0,VIEWS),(36,[v for v in VIEWS if v[0] in ("front","fl","left","top","back")])]:
    sc.frame_set(fr); bpy.context.view_layer.update()
    for name,loc in views:
        p=render_view(name, loc, f"F{fr:02d}mask")
        masks[(fr,name)]=body_mask(p)
    print(f"masks F{fr} done")
def gate(fr, views):
    sc.frame_set(fr); bpy.context.view_layer.update()
    worst=0; tot_in=0
    for name,loc in views:
        p=render_view(name, loc, f"F{fr:02d}red")
        rm=red_mask(p); mk=masks[(fr,name)]
        poke=int((rm & ~mk).sum()); inside=int((rm & mk).sum())
        worst=max(worst,poke); tot_in+=inside
        print(f"  F{fr} {name}: poke={poke} inside_visible={inside}")
    return worst, tot_in
factor=0.94; passed=False
for attempt in range(4):
    verts, polys = build_tube(factor)
    tob=make_object(verts, polys, red)
    print(f"ATTEMPT factor={factor:.2f} verts={len(verts)}")
    w0,_=gate(0, VIEWS); w36,_=gate(36, [v for v in VIEWS if v[0] in ("front","fl","left","top","back")])
    print(f" -> worst poke F0={w0} F36={w36}")
    if w0<20 and w36<20:
        passed=True
        # preview with dark-ish check later in verify script; keep red renders for record
        bpy.data.objects.remove(tob, do_unlink=True)
        break
    bpy.data.objects.remove(tob, do_unlink=True); factor-=0.04
print("PHASE1 passed:", passed, "factor:", round(factor,2))
if passed:
    # PHASE 2: pristine reopen, rebuild with dark material only, save
    bpy.ops.wm.open_mainfile(filepath=BLEND)
    sc=bpy.context.scene
    arm=bpy.data.objects["HERO_01_Armature"]; body=bpy.data.objects["HERO_01_BODY"]
    dark=bpy.data.materials.new("HERO_01_UNDERSUIT_MAT"); dark.use_nodes=True
    try: dark.use_backface_culling=False
    except Exception: pass
    db=dark.node_tree.nodes["Principled BSDF"]
    db.inputs["Base Color"].default_value=(0.055,0.055,0.065,1); db.inputs["Roughness"].default_value=0.92; db.inputs["Metallic"].default_value=0.0
    verts, polys = build_tube(factor)
    tob=make_object(verts, polys, dark)
    sc.frame_set(0); bpy.context.view_layer.update()
    bpy.ops.wm.save_mainfile(); print(f"SAVED blend (factor={factor:.2f}, verts={len(verts)})")
else:
    print("NOT SAVED: silhouette gate failed")
print("DONE")
