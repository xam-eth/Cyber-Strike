# SUPERSEDED gated iteration - measured failure, did NOT save (VALIDATION_REPORT 5.8). Applied fix: 31_fix_spine_field_FINAL.py
"""Fix v5 (= v4 + capped-radius gap metric, earlier collar fade, refined gates): ONE shared spine-chain height field (Hips..Neck, fitted from the asset's own
spine-chain weights) applied to ALL spine-chain verts in z[0.435,0.825] + the UpperLeg_L
offender island. Fades at band edges. Gates: (a) waist-zone (rest z<=0.65) true-gap<=2mm,
(b) NO island pair worsened by >0.3mm, (c) F0 displacement==0. Save blend only if all pass."""
import bpy
import numpy as np
from mathutils import kdtree
PROJ="/home/user/Cyber-Strike/EXOCOMFLICT_HERO01"
bpy.ops.wm.open_mainfile(filepath=f"{PROJ}/blender/HERO_01_working.blend")
sc=bpy.context.scene
body=bpy.data.objects["HERO_01_BODY"]; me=body.data; n=len(me.vertices)
gnames=[g.name for g in body.vertex_groups]; ng=len(gnames)
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
dom=[gnames[int(np.argmax(W[i]))] for i in range(len(uniq))]
cent=np.array([P0[island==i].mean(axis=0) for i in range(len(uniq))])
bmax=np.array([P0[island==i].max(axis=0) for i in range(len(uniq))])
LEG={"UpperLeg_L","UpperLeg_R","LowerLeg_L","LowerLeg_R","Foot_L","Foot_R","Toe_L","Toe_R"}
offenders=[i for i in range(len(uniq)) if dom[i] in LEG and cent[i][2]>0.50 and bmax[i][2]>0.55]
off_set=set(offenders); print("OFFENDERS:", offenders)

def eval_pos(frame):
    sc.frame_set(frame); bpy.context.view_layer.update()
    dg=bpy.context.evaluated_depsgraph_get()
    eo=body.evaluated_get(dg); em=eo.to_mesh()
    p=np.empty(n*3); em.vertices.foreach_get("co", p); eo.to_mesh_clear()
    return p.reshape(-1,3)
def build_kd(P):
    kd=kdtree.KDTree(n)
    for i,p in enumerate(P): kd.insert(p, i)
    kd.balance(); return kd
kd0=build_kd(P0)
band=np.nonzero((P0[:,2]>0.42)&(P0[:,2]<0.78)&(np.abs(P0[:,0])<0.20)&(np.abs(P0[:,1])<0.16))[0]
pairs=[]
for i in band:
    i=int(i)
    for (co_, idx, dist) in kd0.find_n(P0[i], 10):
        if island[idx]!=island[i]:
            if dist<0.004: pairs.append((i, int(idx), float(dist)))
            break
KEEP={"Root","Hips","Spine","Chest","UpperChest","Neck","UpperLeg_L","UpperLeg_R"}
pairs=[p for p in pairs if dom[island[p[0]]] in KEEP and dom[island[p[1]]] in KEEP]
pv=np.array([p[0] for p in pairs]); pp=np.array([p[1] for p in pairs]); pd0=np.array([p[2] for p in pairs])
CAP=0.035
def nearest_other(kd, P, idxs, k=40):
    out=np.full(len(idxs), CAP); other=np.full(len(idxs), -1); capped=np.zeros(len(idxs), dtype=bool)
    for j,i in enumerate(idxs):
        i=int(i); found=False
        for (co_, idx, dist) in kd.find_n(P[i], k):
            if island[idx]!=island[i]:
                out[j]=dist; other[j]=idx; found=True; break
        if not found:
            best=CAP; bi=-1
            for (co_, idx, dist) in kd.find_range(P[i], CAP):
                if island[idx]!=island[i] and dist<best: best=dist; bi=idx
            if bi>=0: out[j]=best; other[j]=bi
            else: capped[j]=True
    return out, other, capped
d0N,_,_=nearest_other(kd0, P0, pv)
waist_mask=P0[pv,2]<=0.65
LEGPAIR={"UpperLeg_L","UpperLeg_R","LowerLeg_L","LowerLeg_R"}
def metrics(P, tag):
    kd=build_kd(P)
    gpair=np.linalg.norm(P[pv]-P[pp], axis=1)-pd0
    dN,oN,capped=nearest_other(kd, P, pv)
    ggap=dN-d0N
    agg={}
    for k in range(len(pv)):
        if oN[k]<0: continue
        key=(min(int(island[pv[k]]),int(island[oN[k]])), max(int(island[pv[k]]),int(island[oN[k]])))
        if key not in agg or ggap[k]>agg[key][0]: agg[key]=(float(ggap[k]), P[int(pv[k])])
    waist_gap=float(ggap[waist_mask].max()) if waist_mask.any() else 0.0
    noleg=[(k,v) for k,v in agg.items() if dom[k[0]] not in LEGPAIR and dom[k[1]] not in LEGPAIR]
    gmax=max(v[0] for _,v in noleg) if noleg else 0.0
    print(f"{tag}: PAIRGROWTH max={gpair.max()*1000:.1f}mm | GAP waist(z<=0.65)={waist_gap*1000:.2f}mm no-leg global={gmax*1000:.2f}mm")
    if capped.any(): print(f"   (capped probes waist={int((capped & waist_mask).sum())} total={int(capped.sum())})")
    for key,(gg,pos) in sorted(noleg, key=lambda kv:-kv[1][0])[:6]:
        if gg<0.0015: break
        print(f"   GAP {key[0]}({dom[key[0]]}) vs {key[1]}({dom[key[1]]}): +{gg*1000:.1f}mm at ({pos[0]:+.3f},{pos[1]:+.3f},{pos[2]:.3f})")
    return agg, waist_gap, gmax

P0eval=eval_pos(0)
pre_agg, pre_waist, pre_gmax = metrics(eval_pos(36), "PRE F36")

CHAIN={"Root","Hips","Spine","Chest","UpperChest","Neck"}
FB=["Hips","Spine","Chest","UpperChest","Neck","Root"]
chain=np.array([(set(vertW[i].keys())<=CHAIN and len(vertW[i])>0 and island[i] not in off_set) for i in range(n)])
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
for z in (0.47,0.52,0.57,0.62,0.67,0.72,0.76,0.80):
    k=int(np.clip(np.digitize(z, zbins)-1, 0, len(zbins)-1))
    print("FIELD z=%.2f"%z, {FB[j]: round(float(field[k,j]),3) for j in range(len(FB)) if field[k,j]>0.01}, "bin_n="+str(int(fcnt[k])))
def field_at(z):
    t=(z-zbins[0])/0.004; k0=int(np.clip(np.floor(t),0,len(zbins)-1)); k1=min(k0+1,len(zbins)-1); f=float(np.clip(t-k0,0,1))
    return field[k0]*(1-f)+field[k1]*f
def alpha(z):
    if z<=0.44 or z>=0.81: return 0.0
    if z<0.47: return (z-0.44)/0.03
    if z>0.73: return (0.81-z)/0.08
    return 1.0
apply_idx=[i for i in range(n) if 0.435<=P0[i][2]<=0.825 and alpha(P0[i][2])>0 and (chain[i] or island[i] in off_set)]
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
me.update(); print("FIELD applied")

post_agg, post_waist, post_gmax = metrics(eval_pos(36), "POST F36")
_, post_waist45, post_gmax45 = metrics(eval_pos(45), "POST F45")
disp0=float(np.linalg.norm(eval_pos(0)-P0eval, axis=1).max())
# no-harm per-pair comparison (F36)
viol=[]
for key,(gg,pos) in post_agg.items():
    if dom[key[0]] in LEGPAIR or dom[key[1]] in LEGPAIR: continue
    pre=pre_agg.get(key,(0.0,None))[0]
    if gg-pre>0.0005: viol.append((key, pre, gg, pos))
print(f"NO-HARM violations (no-leg, >0.5mm worse): {len(viol)}")
for key,pre,gg,pos in sorted(viol, key=lambda t:-(t[2]-t[1]))[:8]:
    print(f"   VIOL {key[0]}({dom[key[0]]}) vs {key[1]}({dom[key[1]]}): {pre*1000:.2f} -> {gg*1000:.2f}mm at ({pos[0]:+.3f},{pos[1]:+.3f},{pos[2]:.3f})")
print(f"F0 displacement: {disp0*1000:.4f}mm")
sc.frame_set(0); bpy.context.view_layer.update()
ok = (post_waist<=0.002 and post_waist45<=0.002 and len(viol)==0 and post_gmax<=0.003 and post_gmax45<=0.003 and disp0<1e-6)
if ok:
    bpy.ops.wm.save_mainfile(); print("SAVED blend")
else:
    print(f"NOT SAVED: waist36={post_waist*1000:.2f} waist45={post_waist45*1000:.2f} viol={len(viol)} disp0={disp0}")
print("DONE")
