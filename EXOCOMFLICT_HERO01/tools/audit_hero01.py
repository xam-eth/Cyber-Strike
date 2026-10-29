"""Phase A technical audit for HERO_01.glb (read-only)."""
import json, sys
import numpy as np
from pathlib import Path
from pygltflib import GLTF2
import trimesh
from PIL import Image
import io

ROOT = Path("EXOCOMFLICT_HERO01")
OUT = ROOT/"tools"/"out"; OUT.mkdir(parents=True, exist_ok=True)
TEXDIR = ROOT/"screenshots"/"audit"; TEXDIR.mkdir(parents=True, exist_ok=True)

def audit_glb(path, extract_textures=False, tag=""):
    p = Path(path)
    data = p.read_bytes()
    g = GLTF2().load_binary(str(p))
    blob = g.binary_blob()
    info = {"path": str(p), "file_bytes": len(data),
            "generator": g.asset.generator if g.asset else None,
            "nodes": [], "images": [], "materials": []}
    for i,n in enumerate(g.nodes or []):
        info["nodes"].append({"index":i,"name":n.name,"mesh":n.mesh,"skin":n.skin,
            "translation":n.translation,"rotation":n.rotation,"scale":n.scale,
            "matrix": n.matrix, "children": n.children})
    # POSITION accessor ranges per primitive
    prim_stats=[]
    for mi,m in enumerate(g.meshes or []):
        for pi,prim in enumerate(m.primitives):
            acc = g.accessors[prim.attributes.POSITION]
            idx_acc = g.accessors[prim.indices] if prim.indices is not None else None
            prim_stats.append({"mesh":mi,"mesh_name":m.name,"prim":pi,"mode":prim.mode,
                "material":prim.material,
                "vert_count":acc.count,"pos_min":acc.min,"pos_max":acc.max,
                "index_count": idx_acc.count if idx_acc else None,
                "attrs": [a for a in ["POSITION","NORMAL","TEXCOORD_0","TEXCOORD_1","JOINTS_0","WEIGHTS_0","COLOR_0","TANGENT"] if getattr(prim.attributes,a,None) is not None]})
    info["primitives"]=prim_stats
    for i,im in enumerate(g.images or []):
        rec={"index":i,"name":im.name,"mime":im.mimeType,"bufferView":im.bufferView,"uri":im.uri}
        if im.bufferView is not None and blob:
            bv=g.bufferViews[im.bufferView]
            raw=blob[bv.byteOffset or 0:(bv.byteOffset or 0)+bv.byteLength]
            rec["bytes"]=len(raw)
            try:
                pil=Image.open(io.BytesIO(raw)); rec["size"]=pil.size; rec["mode"]=pil.mode; rec["format"]=pil.format
                if extract_textures:
                    safe="".join(c if c.isalnum() or c in "-_" else "_" for c in (im.name or f"image{i}"))
                    ext = ".png" if "png" in (im.mimeType or "") else ".jpg"
                    (TEXDIR/f"{tag}{safe}{ext}").write_bytes(raw)
                    rec["extracted"]=str(TEXDIR/f"{tag}{safe}{ext}")
            except Exception as e: rec["err"]=str(e)
        info["images"].append(rec)
    for i,m in enumerate(g.materials or []):
        pbr = m.pbrMetallicRoughness
        info["materials"].append({"index":i,"name":m.name,
            "baseColorFactor": pbr.baseColorFactor if pbr else None,
            "metallicFactor": pbr.metallicFactor if pbr else None,
            "roughnessFactor": pbr.roughnessFactor if pbr else None,
            "baseColorTexture": (pbr.baseColorTexture.index if pbr and pbr.baseColorTexture else None),
            "metallicRoughnessTexture": (pbr.metallicRoughnessTexture.index if pbr and pbr.metallicRoughnessTexture else None),
            "normalTexture": (m.normalTexture.index if m.normalTexture else None),
            "normalScale": (m.normalTexture.scale if m.normalTexture else None),
            "emissiveTexture": (m.emissiveTexture.index if m.emissiveTexture else None),
            "emissiveFactor": m.emissiveFactor, "occlusionTexture": (m.occlusionTexture.index if m.occlusionTexture else None),
            "alphaMode": m.alphaMode, "doubleSided": m.doubleSided,
            "extensions": list((m.extensions or {}).keys()) if isinstance(m.extensions,dict) else str(type(m.extensions))})
    info["counts"]={"nodes":len(g.nodes or []),"meshes":len(g.meshes or []),"materials":len(g.materials or []),
        "textures":len(g.textures or []),"images":len(g.images or []),"skins":len(g.skins or []),
        "animations":len(g.animations or []),"accessors":len(g.accessors or []),"bufferViews":len(g.bufferViews or []),
        "buffers":[{"byteLength":b.byteLength} for b in (g.buffers or [])],
        "extensionsUsed": g.extensionsUsed, "extensionsRequired": g.extensionsRequired,
        "scenes": [{"name":s.name,"nodes":s.nodes} for s in (g.scenes or [])], "scene": g.scene}
    if g.skins:
        info["skins"]=[{"name":s.name,"joints":len(s.joints),"skeleton":s.skeleton} for s in g.skins]
    if g.animations:
        info["animations"]=[{"name":a.name,"channels":len(a.channels)} for a in g.animations]
    return info

def mesh_analysis(path):
    scene = trimesh.load(str(path), process=False, force="scene")
    geoms = list(scene.geometry.values())
    mesh = trimesh.util.concatenate(geoms) if len(geoms)>1 else geoms[0]
    v = np.asarray(mesh.vertices); f = np.asarray(mesh.faces)
    res={"verts":int(len(v)),"faces":int(len(f)),
         "bounds_min":v.min(0).round(4).tolist(),"bounds_max":v.max(0).round(4).tolist(),
         "extents":(v.max(0)-v.min(0)).round(4).tolist(),
         "watertight": bool(mesh.is_watertight), "winding_consistent": bool(mesh.is_winding_consistent),
         "euler_number": int(mesh.euler_number)}
    # degenerate faces
    a=v[f[:,0]]; b=v[f[:,1]]; c=v[f[:,2]]
    area=0.5*np.linalg.norm(np.cross(b-a,c-a),axis=1)
    res["degenerate_faces"]=int((area<1e-12).sum()); res["total_area"]=float(area.sum())
    # connected components by shared vertices (union-find over faces)
    parent=np.arange(len(f))
    def find(x):
        while parent[x]!=x:
            parent[x]=parent[parent[x]]; x=parent[x]
        return x
    # group faces by vertex
    order=np.argsort(f.ravel(),kind="stable")
    sorted_verts=f.ravel()[order]; face_ids=np.repeat(np.arange(len(f)),3)[order]
    starts=np.flatnonzero(np.r_[True, sorted_verts[1:]!=sorted_verts[:-1]])
    bounds=np.r_[starts, len(sorted_verts)]
    for s,e in zip(bounds[:-1],bounds[1:]):
        grp=face_ids[s:e]
        if len(grp)>1:
            r=find(int(grp[0]))
            for other in grp[1:]:
                ro=find(int(other))
                if ro!=r: parent[ro]=r
    roots=np.array([find(i) for i in range(len(f))])
    uniq,cnts=np.unique(roots,return_counts=True)
    res["component_count"]=int(len(uniq))
    shells=[]
    for r,cnt in sorted(zip(uniq.tolist(),cnts.tolist()), key=lambda t:-t[1])[:40]:
        mask=roots==r
        vs=np.unique(f[mask])
        vv=v[vs]
        shells.append({"faces":int(cnt),"verts":int(len(vs)),
            "bounds_min":vv.min(0).round(3).tolist(),"bounds_max":vv.max(0).round(3).tolist(),
            "center":vv.mean(0).round(3).tolist(),"extents":(vv.max(0)-vv.min(0)).round(3).tolist()})
    res["top_shells"]=shells
    res["small_shell_faces"]=int(sum(c for _,c in zip(uniq.tolist(),cnts.tolist()) if c<10))
    # height-axis density (axis with max extent)
    ax=int(np.argmax(v.max(0)-v.min(0)))
    h=v[:,ax]; hist,edges=np.histogram(h,bins=20)
    res["longest_axis"]=ax
    res["axis_density"]={"edges":edges.round(3).tolist(),"counts":hist.tolist()}
    return res

print("== HERO_01 (authoritative source) ==")
hero = audit_glb(ROOT/"assets"/"source"/"HERO_01.glb", extract_textures=True, tag="hero01_")
hero["mesh_analysis"]=mesh_analysis(ROOT/"assets"/"source"/"HERO_01.glb")
print(json.dumps(hero, indent=1, default=str)[:6000])
print("\n== repo hero_rigged_source (comparison only) ==")
rig = audit_glb("source-assets/characters/hero/hero_rigged_source.glb")
rig["mesh_analysis"]=mesh_analysis("source-assets/characters/hero/hero_rigged_source.glb")
print("counts:", rig["counts"]); print("prims:", rig["primitives"])
print("rig bounds/extents:", rig["mesh_analysis"]["bounds_min"], rig["mesh_analysis"]["bounds_max"], rig["mesh_analysis"]["extents"])
print("rig verts/faces/components:", rig["mesh_analysis"]["verts"], rig["mesh_analysis"]["faces"], rig["mesh_analysis"]["component_count"])
(OUT/"audit_hero01.json").write_text(json.dumps({"HERO_01":hero,"hero_rigged_source_REF":rig},indent=1,default=str))
print("\nwrote", OUT/"audit_hero01.json")
