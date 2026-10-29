import json, struct, os
import numpy as np
from pygltflib import GLTF2
PROJ="/home/user/Cyber-Strike/EXOCOMFLICT_HERO01"
def load(p):
    g=GLTF2().load_binary(p); return g
def acc_data(g, idx):
    a=g.accessors[idx]; bv=g.bufferViews[a.bufferView]
    raw=g.binary_blob()[bv.byteOffset+(a.byteOffset or 0):]
    dt={5126:np.float32,5123:np.uint16,5125:np.uint32,5121:np.uint8}[a.componentType]
    ncomp={"SCALAR":1,"VEC2":2,"VEC3":3,"VEC4":4,"MAT4":16}[a.type]
    return np.frombuffer(raw,dtype=dt,count=a.count*ncomp).reshape(a.count,ncomp)
out={}
for label,p in [("RIGGED",f"{PROJ}/assets/characters/HERO_01_RIGGED.glb"),
                ("ANIMATIONS",f"{PROJ}/animations/HERO_01_ANIMATIONS.glb"),
                ("WEAPON",f"{PROJ}/assets/weapons/HERO_01_WEAPON.glb")]:
    g=load(p); info={"file":os.path.basename(p),"bytes":os.path.getsize(p)}
    info["nodes"]=[n.name for n in g.nodes]
    info["meshes"]=[]
    for m in g.meshes:
        prim=m.primitives[0]; pos=acc_data(g,prim.attributes.POSITION)
        e={"name":m.name,"verts":int(pos.shape[0]),"attrs":sorted([a for a in vars(prim.attributes) if getattr(prim.attributes,a) is not None])}
        if getattr(prim.attributes,"WEIGHTS_0",None) is not None:
            w=acc_data(g,prim.attributes.WEIGHTS_0).astype(np.float32)
            e["weight_sum_min"]=float(w.sum(1).min()); e["weight_sum_max"]=float(w.sum(1).max())
            e["zero_weight_verts"]=int((w.sum(1)<1e-6).sum())
        info["meshes"].append(e)
    info["skins"]=[{"joints":len(s.joints),"joint_names":[g.nodes[j].name for j in s.joints]} for s in (g.skins or [])]
    info["animations"]=[]
    for a in (g.animations or []):
        dur=0.0
        for s in a.samplers:
            t=acc_data(g,s.input); dur=max(dur,float(t.max()))
        info["animations"].append({"name":a.name,"channels":len(a.channels),"duration_s":round(dur,3)})
    info["images"]=len(g.images or []); info["materials"]=len(g.materials or [])
    out[label]=info
    print(f"== {label} {info['bytes']}B meshes={info['meshes']} skins={[s['joints'] for s in info['skins']]} anims={info['animations']} images={info['images']} mats={info['materials']}")
json.dump(out,open(f"{PROJ}/tools/out/export_validation.json","w"),indent=1)
print("joint names RIGGED:", out["RIGGED"]["skins"][0]["joint_names"] if out["RIGGED"]["skins"] else None)
print("nodes RIGGED:", out["RIGGED"]["nodes"][:8], "... total", len(out["RIGGED"]["nodes"]))
