"""Numba CPU rasterizer for offline inspection renders (no GPU/Blender in sandbox).
Textured lambert shading, perspective-correct UV, z-buffer. Inspection ONLY -
the deliverable pipeline preserves original GLB attributes untouched."""
import numpy as np, trimesh, sys
from numba import njit
from PIL import Image, ImageDraw
from pathlib import Path

@njit(cache=False)
def raster(sx, sy, invw, shade, u_over_w, v_over_w, faces, tex, img, zbuf, W, H):
    th, tw = tex.shape[0], tex.shape[1]
    for t in range(faces.shape[0]):
        i0, i1, i2 = faces[t,0], faces[t,1], faces[t,2]
        x0,y0 = sx[i0], sy[i0]; x1,y1 = sx[i1], sy[i1]; x2,y2 = sx[i2], sy[i2]
        area = (x1-x0)*(y2-y0) - (y1-y0)*(x2-x0)
        if area <= 0.0:  # backface (y-up framebuffer, CCW front)
            continue
        minx = int(max(0.0, min(x0,min(x1,x2)))); maxx = int(min(W-1.0, max(x0,max(x1,x2))))
        miny = int(max(0.0, min(y0,min(y1,y2)))); maxy = int(min(H-1.0, max(y0,max(y1,y2))))
        if maxx<minx or maxy<miny: continue
        inv_area = 1.0/area
        for py in range(miny, maxy+1):
            fy = py + 0.5
            for px in range(minx, maxx+1):
                fx = px + 0.5
                l0 = ((x1-fx)*(y2-fy) - (y1-fy)*(x2-fx))*inv_area
                l1 = ((x2-fx)*(y0-fy) - (y2-fy)*(x0-fx))*inv_area
                l2 = 1.0 - l0 - l1
                if l0 < 0.0 or l1 < 0.0 or l2 < 0.0: continue
                iw = l0*invw[i0] + l1*invw[i1] + l2*invw[i2]
                if iw <= zbuf[py,px]: continue
                zbuf[py,px] = iw
                sh = (l0*shade[i0] + l1*shade[i1] + l2*shade[i2]) / iw
                u = (l0*u_over_w[i0] + l1*u_over_w[i1] + l2*u_over_w[i2]) / iw
                v = (l0*v_over_w[i0] + l1*v_over_w[i1] + l2*v_over_w[i2]) / iw
                u = u - np.floor(u); v = v - np.floor(v)
                tx = int(u*(tw-1)); ty = int(v*(th-1))
                for c in range(3):
                    val = tex[ty,tx,c]*sh
                    img[py,px,c] = 255.0 if val>255.0 else val

def lookat(eye, target, up):
    eye=np.array(eye,float); target=np.array(target,float); up=np.array(up,float)
    fwd = target-eye; fwd/=np.linalg.norm(fwd)
    right = np.cross(fwd,up); right/=np.linalg.norm(right)
    up2 = np.cross(right,fwd)
    V=np.eye(4); V[0,:3]=right; V[1,:3]=up2; V[2,:3]=-fwd
    V[0,3]=-right@eye; V[1,3]=-up2@eye; V[2,3]=fwd@eye
    return V

def perspective(fovy_deg, aspect, near, far):
    t=1.0/np.tan(np.radians(fovy_deg)/2)
    P=np.zeros((4,4)); P[0,0]=t/aspect; P[1,1]=t; P[2,2]=(far+near)/(near-far); P[2,3]=2*far*near/(near-far); P[3,2]=-1
    return P

def extract_basecolor(path):
    """Pull baseColor texture bytes straight from the GLB (trimesh drops PBR maps)."""
    import io
    from pygltflib import GLTF2
    g = GLTF2().load_binary(str(path))
    blob = g.binary_blob()
    if not g.materials: return None
    pbr = g.materials[0].pbrMetallicRoughness
    if pbr is None or pbr.baseColorTexture is None: return None
    tex = g.textures[pbr.baseColorTexture.index]
    im = g.images[tex.source]
    bv = g.bufferViews[im.bufferView]
    raw = blob[bv.byteOffset or 0:(bv.byteOffset or 0)+bv.byteLength]
    return np.asarray(Image.open(io.BytesIO(raw)).convert("RGB")).astype(np.float32)

def load_world_mesh(path):
    scene = trimesh.load(str(path), process=False, force="scene")
    meshes=[]
    for node in scene.graph.nodes_geometry:
        T, geom_name = scene.graph[node]
        g = scene.geometry[geom_name].copy()
        g.apply_transform(T)
        meshes.append(g)
    mesh = trimesh.util.concatenate(meshes) if len(meshes)>1 else meshes[0]
    bc = extract_basecolor(path)
    if bc is not None: mesh.metadata["basecolor"] = bc
    return mesh

def get_texture(mesh):
    vis = mesh.visual
    uv = np.asarray(vis.uv).astype(np.float64).copy() if getattr(vis,"uv",None) is not None else np.zeros((len(mesh.vertices),2))
    uv[:,1] = 1.0 - uv[:,1]  # trimesh flips V on glTF load; raw GLB texture is top-left origin
    tex = mesh.metadata.get("basecolor")
    if tex is None:
        img=None
        if hasattr(vis,"material") and vis.material is not None:
            m=vis.material
            img = getattr(m,"image",None) or getattr(m,"base_color_texture",None)
        if img is None: return np.full((4,4,3),200.0,np.float32), uv
        tex=np.asarray(img.convert("RGB")).astype(np.float32)
    return tex, uv

def render(mesh, eye, target, W=760, H=950, fov=34.0, light_dir=(0.45,0.8,0.6), bg=(43,47,54), vertex_rgb=None):
    verts=np.asarray(mesh.vertices,float); faces=np.asarray(mesh.faces)
    normals=np.asarray(mesh.vertex_normals,float)
    ld=np.array(light_dir,float); ld/=np.linalg.norm(ld)
    shade_v = 0.34 + 0.66*np.clip(normals@ld,0,None) + 0.12*np.clip(normals@np.array([-ld[0],0.3,-ld[2]]),0,None)
    V=lookat(eye,target,(0,1,0)); P=perspective(fov,W/H,0.05,20.0)
    hom=np.c_[verts,np.ones(len(verts))]
    clip=(P@V@hom.T).T
    w=clip[:,3]
    valid = w>1e-6
    ndc=clip[:,:3]/np.where(valid,w,1)[:,None]
    sx=((ndc[:,0]+1)*0.5*W).astype(np.float64); sy=((ndc[:,1]+1)*0.5*H).astype(np.float64)
    invw=np.where(valid,1.0/np.where(w==0,1,w),0.0)
    if vertex_rgb is not None:
        # encode vertex color through texture path: uv-> 1x1? Instead bake color*shade via shade and fake uv atlas not possible; use per-vertex color as "texture" trick not available -> handled by caller passing small white tex and modulating shade per channel not supported. Fallback: luminance of vertex_rgb.
        lum = (0.299*vertex_rgb[:,0]+0.587*vertex_rgb[:,1]+0.114*vertex_rgb[:,2])
        shade_v = shade_v*(0.35+0.65*lum)
        tex=np.full((2,2,3),255.0,np.float32); uv=np.zeros((len(verts),2))
    else:
        tex,uv = get_texture(mesh)
    img=np.zeros((H,W,3),np.float32); img[:]=bg
    zbuf=np.full((H,W),-1e9)
    fmask = valid[faces].all(axis=1)
    raster(sx,sy,invw,(shade_v*invw).astype(np.float64),(uv[:,0]*invw).astype(np.float64),(uv[:,1]*invw).astype(np.float64),
           faces[fmask].astype(np.int64), tex.astype(np.float32), img, zbuf, W, H)
    out=Image.fromarray(np.flipud(img).clip(0,255).astype(np.uint8))
    return out

VIEWS={ "front_Zplus":([0,0.52,2.0],[0,0.5,0]), "back_Zminus":([0,0.52,-2.0],[0,0.5,0]),
        "side_Xplus":([2.0,0.52,0],[0,0.5,0]), "side_Xminus":([-2.0,0.52,0],[0,0.5,0]),
        "threeq_XZplus":([1.3,0.62,1.3],[0,0.48,0]) }

if __name__=="__main__":
    path, tag, outdir = sys.argv[1], sys.argv[2], Path(sys.argv[3])
    outdir.mkdir(parents=True,exist_ok=True)
    mesh=load_world_mesh(path)
    print(tag,"bounds",mesh.bounds.tolist(),"verts",len(mesh.vertices),"faces",len(mesh.faces))
    for name,(eye,tgt) in VIEWS.items():
        im=render(mesh,eye,tgt)
        d=ImageDraw.Draw(im); d.rectangle([0,0,300,22],fill=(20,20,24)); d.text((6,5),f"{tag} {name} eye={eye}",fill=(255,255,255))
        p=outdir/f"{tag}_{name}.png"; im.save(p); print("wrote",p)
