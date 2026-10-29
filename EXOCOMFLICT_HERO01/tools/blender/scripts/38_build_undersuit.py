"""SUPERSEDED - DO NOT RUN (invalid radial poke metric on loose shells; see 43). Build HERO_01_UNDERSUIT (owner-approved, VALIDATION_REPORT 5.9): a dark inner torso/hip
tube fitted from the body's own torso cross-sections (percentile radii, auto-shrunk until no
poke-through), weighted with the shared spine-chain height field. Additive only - no source
vertex/material touched. Blend saved ONLY if poke-through fraction < 0.2% at rest."""
import bpy
import numpy as np
PROJ="/home/user/Cyber-Strike/EXOCOMFLICT_HERO01"
bpy.ops.wm.open_mainfile(filepath=f"{PROJ}/blender/HERO_01_working.blend")
sc=bpy.context.scene
arm=bpy.data.objects["HERO_01_Armature"]; body=bpy.data.objects["HERO_01_BODY"]
me=body.data; n=len(me.vertices)
gnames=[g.name for g in body.vertex_groups]; ng=len(gnames)
sc.frame_set(0); bpy.context.view_layer.update()
if "HERO_01_UNDERSUIT" in bpy.data.objects:
    bpy.data.objects.remove(bpy.data.objects["HERO_01_UNDERSUIT"], do_unlink=True)
    print("removed previous undersuit")

# islands + weights (for torso-only cross-sections and field fit)
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
print("torso verts for cross-sections:", int(torso_vert.sum()))

# ---- spine field (refit, same method as script 31) ----
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

# ---- tube geometry from torso cross-sections ----
SEG=32
ring_z=np.arange(0.475, 0.7551, 0.015)
centers=[]; radii=[]
for zk in ring_z:
    m=torso_vert & (np.abs(P0[:,2]-zk)<0.012)
    pts=P0[m]
    c=pts.mean(axis=0); centers.append(c)
    d=pts[:,:2]-c[:2]
    r=np.linalg.norm(d, axis=1); a=np.arctan2(d[:,1], d[:,0])
    ab=((a+np.pi)/(2*np.pi)*SEG).astype(int)%SEG
    rr=np.full(SEG, np.nan)
    for s in range(SEG):
        rs=r[ab==s]
        if len(rs)>=3: rr[s]=float(np.percentile(rs, 70))
    # fill NaNs circularly
    good=~np.isnan(rr)
    if good.any():
        idx=np.arange(SEG)
        rr=np.interp(idx, idx[good], rr[good], period=SEG)
    radii.append(rr)
centers=np.array(centers); radii=np.array(radii)
# smooth radii across angle (circular) and z
def csmooth(x):
    return (np.roll(x,1,axis=1)+2*x+np.roll(x,-1,axis=1))/4.0
radii=csmooth(radii)
radii[1:-1]=(radii[:-2]+2*radii[1:-1]+radii[2:])/4.0
print("rings:", len(ring_z), "radius range:", round(float(radii.min()),3), round(float(radii.max()),3))

def build_tube(factor):
    verts=[];
    # bottom cap ring (tucked)
    zc=0.465; c=centers[0]
    for s in range(SEG):
        a=2*np.pi*s/SEG; r=radii[0,s]*factor*0.62
        verts.append((c[0]+r*np.cos(a), c[1]+r*np.sin(a), zc))
    for k,zk in enumerate(ring_z):
        c=centers[k]
        shrink=1.0
        if zk<0.49: shrink=0.90
        if zk>0.74: shrink=0.86
        for s in range(SEG):
            a=2*np.pi*s/SEG; r=radii[k,s]*factor*shrink
            verts.append((c[0]+r*np.cos(a), c[1]+r*np.sin(a), float(zk)))
    # top cap ring (tucked)
    zc=0.762; c=centers[-1]
    for s in range(SEG):
        a=2*np.pi*s/SEG; r=radii[-1,s]*factor*0.62
        verts.append((c[0]+r*np.cos(a), c[1]+r*np.sin(a), zc))
    polys=[]
    rings=len(verts)//SEG
    for k in range(rings-1):
        for s in range(SEG):
            a=k*SEG+s; b=k*SEG+(s+1)%SEG; c2=(k+1)*SEG+(s+1)%SEG; d2=(k+1)*SEG+s
            polys.append((a,b,c2,d2))
    return np.array(verts), polys

def poke_frac(verts):
    # poke if tube vert radial dist (vs its ring center) exceeds nearest body vert radial dist (vs same center) + 0.5mm
    from mathutils import kdtree
    kd=kdtree.KDTree(n)
    for i,p in enumerate(P0): kd.insert(p, i)
    kd.balance()
    bad=0; rings=len(verts)//SEG
    cents=[centers[0]]+list(centers)+[centers[-1]]
    for j,v in enumerate(verts):
        ring=j//SEG; c=cents[ring]
        rt=float(np.linalg.norm(v[:2]-c[:2]))
        co_, idx, dist = kd.find(v)
        rb=float(np.linalg.norm(P0[idx][:2]-c[:2]))
        if rt>rb+0.0005: bad+=1
    return bad/len(verts)

factor=0.97
while True:
    verts, polys = build_tube(factor)
    pf=poke_frac(verts)
    print(f"factor={factor:.2f} poke_frac={pf*100:.2f}%")
    if pf<0.002 or factor<=0.80: break
    factor-=0.02

tm=bpy.data.meshes.new("HERO_01_UNDERSUIT")
tm.from_pydata([tuple(v) for v in verts], [], polys); tm.update()
# ensure outward normals: compare first polygon normal with radial dir
tm.calc_loop_triangles()
p0=tm.polygons[SEG*2]  # a mid ring polygon
c=p0.center; radial=np.array([c.x-centers[2][0], c.y-centers[2][1], 0.0])
if float(np.dot(np.array(p0.normal), radial))<0:
    tm.flip_normals(); print("normals flipped to outward")
tob=bpy.data.objects.new("HERO_01_UNDERSUIT", tm); sc.collection.objects.link(tob)
for name in gnames: tob.vertex_groups.new(name=name)
vg={g.name:g for g in tob.vertex_groups}
for j,v in enumerate(verts):
    fv=field_at(v[2])
    acc={FB[k]: float(fv[k]) for k in range(len(FB)) if fv[k]>1e-4}
    if v[2]<0.470: acc={"Hips": 1.0}
    top=sorted(acc.items(), key=lambda kv:-kv[1])[:4]
    s=sum(vv for _,vv in top) or 1.0
    for bn,val in top:
        if val/s>1e-4: vg[bn].add([j], val/s, 'ADD')
mod=tob.modifiers.new("Armature", 'ARMATURE'); mod.object=arm
tob.parent=body.parent
mat=bpy.data.materials.new("HERO_01_UNDERSUIT_MAT"); mat.use_nodes=True
try: mat.use_backface_culling=False
except Exception as e: print("backface attr:", e)
bsdf=mat.node_tree.nodes["Principled BSDF"]
bsdf.inputs["Base Color"].default_value=(0.055,0.055,0.065,1)
bsdf.inputs["Roughness"].default_value=0.92
bsdf.inputs["Metallic"].default_value=0.0
tm.materials.append(mat)
print(f"UNDERSUIT built: {len(verts)} verts, {len(polys)} polys, factor={factor:.2f}, poke={pf*100:.2f}%")
sc.frame_set(0); bpy.context.view_layer.update()
if pf<0.002:
    bpy.ops.wm.save_mainfile(); print("SAVED blend")
else:
    print(f"NOT SAVED: poke frac {pf*100:.2f}% >= 0.2%")
print("DONE")
