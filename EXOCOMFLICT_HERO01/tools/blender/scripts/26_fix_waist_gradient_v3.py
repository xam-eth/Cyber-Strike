# SUPERSEDED gated iteration - measured failure, did NOT save (VALIDATION_REPORT 5.8). Applied fix: 31_fix_spine_field_FINAL.py
"""Fix v3 (final approach): enforce ONE shared height-weight field across all torso shells
in the waist->lower-chest band, so inter-shell seams move coherently under any spine pose.
Field is FIT from the asset's own torso-clean weights (binned by rest height, smoothed) to
preserve original flexibility. Applied to: torso-clean verts in z[0.435,0.785] + the proven
UpperLeg_L offender island. Faded at band edges. Dual metrics pre/post: partner-pair growth
and TRUE-GAP (nearest other-island distance growth). Save only if true-gap (excl. leg pairs)
<= 2.0mm at F36/F45 and F0 displacement == 0."""
import bpy
import numpy as np
from mathutils import kdtree
PROJ="/home/user/Cyber-Strike/EXOCOMFLICT_HERO01"
bpy.ops.wm.open_mainfile(filepath=f"{PROJ}/blender/HERO_01_working.blend")
sc=bpy.context.scene
arm=bpy.data.objects["HERO_01_Armature"]; body=bpy.data.objects["HERO_01_BODY"]
me=body.data; n=len(me.vertices)
gnames=[g.name for g in body.vertex_groups]; ng=len(gnames)
for bn in ("Hips","Spine","Chest","UpperChest","Neck"):
    print("BONEHEAD", bn, round(float(arm.data.bones[bn].head_local.z),3))

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
print("ISLANDS:", len(uniq), "verts:", n)
co0=np.empty(n*3); me.vertices.foreach_get("co", co0); P0=co0.reshape(-1,3)
W=np.zeros((len(uniq), ng)); cnt=np.zeros(len(uniq))
vertW=[None]*n
for v in me.vertices:
    i=island[v.index]; cnt[i]+=1
    vertW[v.index]={gnames[g.group]: float(g.weight) for g in v.groups}
    for g in v.groups: W[i,g.group]+=g.weight
W/=np.maximum(cnt,1)[:,None]
dom=[gnames[int(np.argmax(W[i]))] for i in range(len(uniq))]
cent=np.array([P0[island==i].mean(axis=0) for i in range(len(uniq))])
bmax=np.array([P0[island==i].max(axis=0) for i in range(len(uniq))])
LEG={"UpperLeg_L","UpperLeg_R","LowerLeg_L","LowerLeg_R","Foot_L","Foot_R","Toe_L","Toe_R"}
offenders=[i for i in range(len(uniq)) if dom[i] in LEG and cent[i][2]>0.50 and bmax[i][2]>0.55]
print("LEG OFFENDERS:", offenders)

def eval_pos(frame):
    sc.frame_set(frame); bpy.context.view_layer.update()
    dg=bpy.context.evaluated_depsgraph_get()
    eo=body.evaluated_get(dg); em=eo.to_mesh()
    p=np.empty(n*3); em.vertices.foreach_get("co", p); eo.to_mesh_clear()
    return p.reshape(-1,3)

# seam probes + partner pairs (rest)
def build_kd(P):
    kd=kdtree.KDTree(n)
    for i,p in enumerate(P): kd.insert(p, i)
    kd.balance(); return kd
kd0=build_kd(P0)
band=np.nonzero((P0[:,2]>0.42)&(P0[:,2]<0.72)&(np.abs(P0[:,0])<0.20)&(np.abs(P0[:,1])<0.16))[0]
pairs=[]
for i in band:
    i=int(i)
    for (co_, idx, dist) in kd0.find_n(P0[i], 10):
        if island[idx]!=island[i]:
            if dist<0.004: pairs.append((i, int(idx), float(dist)))
            break
KEEP={"Root","Hips","Spine","Chest","UpperChest","UpperLeg_L","UpperLeg_R"}
pairs=[p for p in pairs if dom[island[p[0]]] in KEEP and dom[island[p[1]]] in KEEP]
pv=np.array([p[0] for p in pairs]); pp=np.array([p[1] for p in pairs]); pd0=np.array([p[2] for p in pairs])
def nearest_other(kd, P, idxs, k=40):
    out=np.full(len(idxs), 1e9); other=np.full(len(idxs), -1)
    for j,i in enumerate(idxs):
        for (co_, idx, dist) in kd.find_n(P[int(i)], k):
            if island[idx]!=island[int(i)]:
                out[j]=dist; other[j]=idx; break
    return out, other
d0N, _ = nearest_other(kd0, P0, pv)
print("probes:", len(pv), "d0N found:", int((d0N<1e8).sum()))
LEGPAIR={"UpperLeg_L","UpperLeg_R","LowerLeg_L","LowerLeg_R"}
def metrics(P, tag):
    kd=build_kd(P)
    gpair=np.linalg.norm(P[pv]-P[pp], axis=1)-pd0
    dN, oN = nearest_other(kd, P, pv)
    ggap=dN-d0N
    valid=dN<1e8
    def agg(vals, others):
        a={}
        for k in range(len(pv)):
            if others[k]<0: continue
            key=(min(int(island[pv[k]]),int(island[others[k]])), max(int(island[pv[k]]),int(island[others[k]])))
            if key not in a or vals[k]>a[key][0]: a[key]=(float(vals[k]), P[int(pv[k])])
        return sorted(a.items(), key=lambda kv:-kv[1][0])
    wgap=agg(ggap, oN)
    wgap_noleg=[x for x in wgap if dom[x[0][0]] not in LEGPAIR and dom[x[0][1]] not in LEGPAIR]
    print(f"{tag}: PAIR-GROWTH max={gpair.max()*1000:.1f}mm | TRUE-GAP max={wgap[0][1][0]*1000:.2f}mm, no-leg max={wgap_noleg[0][1][0]*1000:.2f}mm")
    for key,(gg,pos) in wgap_noleg[:6]:
        if gg<0.0015: break
        print(f"   GAP {key[0]}({dom[key[0]]}) vs {key[1]}({dom[key[1]]}): +{gg*1000:.1f}mm at ({pos[0]:+.3f},{pos[1]:+.3f},{pos[2]:.3f})")
    for key,(gg,pos) in wgap[:3]:
        if dom[key[0]] in LEGPAIR or dom[key[1]] in LEGPAIR:
            print(f"   GAP(leg pair, reported only) {key[0]}({dom[key[0]]}) vs {key[1]}({dom[key[1]]}): +{gg*1000:.1f}mm at ({pos[0]:+.3f},{pos[1]:+.3f},{pos[2]:.3f})")
    return float(wgap_noleg[0][1][0])

P0eval=eval_pos(0)
pre_gap=metrics(eval_pos(36), "PRE F36")

# ---- fit shared field from torso-clean verts (excluding offenders) ----
TORSO={"Root","Hips","Spine","Chest","UpperChest"}
off_set=set(offenders)
clean=np.array([ (set(vertW[i].keys())<=TORSO and len(vertW[i])>0 and island[i] not in off_set) for i in range(n)])
FB=["Hips","Spine","Chest","UpperChest","Root"]
zbins=np.arange(0.435, 0.7901, 0.004)
field=np.zeros((len(zbins), len(FB))); fcnt=np.zeros(len(zbins))
sel=np.nonzero(clean & (P0[:,2]>=zbins[0]) & (P0[:,2]<=zbins[-1]))[0]
bi=np.clip(np.digitize(P0[sel,2], zbins)-1, 0, len(zbins)-1)
for k,i in enumerate(sel):
    fcnt[bi[k]]+=1
    for j,bn in enumerate(FB): field[bi[k],j]+=vertW[int(i)].get(bn,0.0)
nz=fcnt>0
field[nz]/=fcnt[nz][:,None]
# fill empty bins by nearest nonempty, then smooth (moving avg width 5), renormalize
idx=np.arange(len(zbins))
last=-1
for k in range(len(zbins)):
    if nz[k]: last=k
    elif last>=0: field[k]=field[last]
last=-1
for k in range(len(zbins)-1,-1,-1):
    if nz[k]: last=k
    elif last>=0 and not nz[k] and fcnt[k]==0 and (k==0 or fcnt[k-1]==0): field[k]=field[last]
ker=np.ones(5)/5
for j in range(len(FB)): field[:,j]=np.convolve(np.pad(field[:,j],2,mode='edge'), ker, mode='valid')
field/=np.maximum(field.sum(axis=1, keepdims=True), 1e-9)
for z in (0.47,0.52,0.57,0.62,0.67,0.72,0.77):
    k=int(np.clip(np.digitize(z, zbins)-1, 0, len(zbins)-1))
    print("FIELD z=%.2f"%z, {FB[j]: round(float(field[k,j]),3) for j in range(len(FB)) if field[k,j]>0.01})
def field_at(z):
    t=(z-zbins[0])/0.004; k0=int(np.clip(np.floor(t),0,len(zbins)-1)); k1=min(k0+1,len(zbins)-1); f=float(np.clip(t-k0,0,1))
    return field[k0]*(1-f)+field[k1]*f
def alpha(z):
    if z<=0.44 or z>=0.78: return 0.0
    if z<0.47: return (z-0.44)/0.03
    if z>0.72: return (0.78-z)/0.06
    return 1.0

apply_idx=[]
for i in range(n):
    z=P0[i][2]
    if 0.435<=z<=0.785 and alpha(z)>0 and (clean[i] or island[i] in off_set): apply_idx.append(i)
print("APPLY verts:", len(apply_idx))
vg={g.name: g for g in body.vertex_groups}
for i in apply_idx:
    z=P0[i][2]; a=alpha(z); fv=field_at(z)
    acc={FB[j]: a*float(fv[j]) for j in range(len(FB)) if fv[j]>1e-4}
    for bn,val in vertW[i].items(): acc[bn]=acc.get(bn,0.0)+(1-a)*val
    top=sorted(acc.items(), key=lambda kv:-kv[1])[:4]
    s=sum(vv for _,vv in top) or 1.0
    for bn in list(vertW[i].keys()): vg[bn].remove([i])
    for bn,val in top:
        if val/s>1e-4: vg[bn].add([i], val/s, 'ADD')
me.update(); print("GRADIENT applied")

post36=metrics(eval_pos(36), "POST F36")
post45=metrics(eval_pos(45), "POST F45")
disp0=float(np.linalg.norm(eval_pos(0)-P0eval, axis=1).max())
print(f"F0 displacement: {disp0*1000:.4f}mm")
sc.frame_set(0); bpy.context.view_layer.update()
if post36<=0.002 and post45<=0.002 and disp0<1e-6:
    bpy.ops.wm.save_mainfile(); print("SAVED blend")
else:
    print(f"NOT SAVED: post36gap={post36*1000:.2f} post45gap={post45*1000:.2f} disp0={disp0}")
print("DONE")
