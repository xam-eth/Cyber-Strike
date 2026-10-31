"""Armor-purity audit on the SHIPPED GLB (owner hybrid-rig spec, 2026-10-31).
Question: are hard-armor islands already effectively rigid (single-bone)
under the current skinning, or do large armor shells blend across joints
(would justify splitting into bone-attached rigid meshes)?
Reads HERO_01_RIGGED.glb (POSITION/JOINTS_0/WEIGHTS_0/indices), welds
verts by rounded position, finds islands, reports per-island dominant
joint share + the largest blended islands + region checks around
shoulders/chest/helmet/knees/shins/forearms.
Run: .venv/bin/python EXOCOMFLICT_HERO01/tools/analyze_armor_purity.py
"""
import struct
import numpy as np
from pygltflib import GLTF2

GLB = "/home/user/Cyber-Strike/EXOCOMFLICT_HERO01/assets/characters/HERO_01_RIGGED.glb"
g = GLTF2().load(GLB)

def acc_array(idx):
    a = g.accessors[idx]; bv = g.bufferViews[a.bufferView]
    data = g.binary_blob()
    off = (bv.byteOffset or 0) + (a.byteOffset or 0)
    comp = {5126: "f", 5123: "H", 5125: "I", 5121: "B"}[a.componentType]
    n = {"SCALAR": 1, "VEC2": 2, "VEC3": 3, "VEC4": 4}[a.type]
    return np.array(struct.unpack_from("<" + comp * n * a.count, data, off)).reshape(a.count, n)

prim = g.meshes[0].primitives[0]
POS = acc_array(prim.attributes.POSITION).astype(np.float64)
JNT = acc_array(prim.attributes.JOINTS_0).astype(np.int64)
WGT = acc_array(prim.attributes.WEIGHTS_0).astype(np.float64)
IDX = acc_array(prim.indices).reshape(-1, 3).astype(np.int64)
JOINT_NAMES = [g.nodes[j].name for j in g.skins[0].joints]
print(f"verts={len(POS)} tris={len(IDX)} joints={len(JOINT_NAMES)}")

# NOTE: intentionally NO position welding - Tripo shells touch/intersect,
# so welding would fuse separate islands. Raw exported topology it is.
nw = len(POS)

# connected components over triangle edges (label propagation)
lab = np.arange(nw, dtype=np.int64)
E = np.concatenate([IDX[:, [0, 1]], IDX[:, [1, 2]], IDX[:, [2, 0]]])
Ew = E
for it in range(200):
    m = np.minimum(lab[Ew[:, 0]], lab[Ew[:, 1]])
    new = lab.copy()
    np.minimum.at(new, Ew[:, 0], m)
    np.minimum.at(new, Ew[:, 1], m)
    # pointer jumping
    new = new[new]
    if (new == lab).all():
        break
    lab = new
_, isl = np.unique(lab, return_inverse=True)
nisl = isl.max() + 1
print(f"islands={nisl} (iters={it})")
vert_isl = isl

# per-vertex dominant joint weight
dom_w = WGT.max(axis=1)
dom_j = JNT[np.arange(len(POS)), WGT.argmax(axis=1)]

# per-island stats (use original exported verts)
sizes = np.bincount(vert_isl, minlength=nisl)
order = np.argsort(-sizes)
rigid_verts = 0
rows = []
for i in order:
    m = vert_isl == i
    if sizes[i] < 30:
        continue
    # dominant joint by summed weight
    s = np.zeros(len(JOINT_NAMES))
    np.add.at(s, JNT[m].ravel(), WGT[m].ravel())
    top = int(np.argmax(s))
    share = s[top] / s.sum()
    cen = POS[m].mean(axis=0)
    rows.append((int(sizes[i]), JOINT_NAMES[top], share, cen))
    if share >= 0.99:
        rigid_verts += int(sizes[i])
big = [r for r in rows if r[0] >= 30]
tot_big = sum(r[0] for r in big)
print(f"verts in islands>=30: {tot_big}; rigid-clean (>=99% one joint): {rigid_verts} = {100.0*rigid_verts/max(tot_big,1):.1f}%")
print("\nLARGEST BLENDED islands (share<0.99), glTF coords (x=left+, y=up, z=forward+):")
blended = sorted([r for r in big if r[2] < 0.99], key=lambda r: -r[0])[:22]
for sz, jn, sh, cen in blended:
    print(f"  {sz:7d}v top={jn:12s} share={sh:.3f} centroid=({cen[0]:+.3f},{cen[1]:.3f},{cen[2]:+.3f})")
print("\nLARGEST RIGID islands (already single-bone):")
for sz, jn, sh, cen in sorted([r for r in big if r[2] >= 0.99], key=lambda r: -r[0])[:12]:
    print(f"  {sz:7d}v {jn:12s} share={sh:.3f} centroid=({cen[0]:+.3f},{cen[1]:.3f},{cen[2]:+.3f})")

# named region checks: islands (any size>=30) whose centroid lies in a sphere
def region(name, center, r):
    c = np.array(center)
    sel = [row for row in big if np.linalg.norm(row[3] - c) < r]
    if not sel:
        print(f"REGION {name}: none"); return
    worst = min(sel, key=lambda row: row[2])
    tot = sum(row[0] for row in sel)
    print(f"REGION {name}: {len(sel)} islands {tot}v; worst share {worst[2]:.3f} ({worst[1]}, {worst[0]}v)")
# glTF-space anatomical anchors (skeleton units, height .9813): shoulder y .795 x +- .135; chest front z ~ -.09 in blender = +z forward in glTF? Blender -Y fwd -> glTF +Z fwd; Blender (x,y,z)->glTF (x, z, -y)
region("pauldron_R", (-0.17, 0.80, 0.00), 0.085)
region("pauldron_L", (0.17, 0.80, 0.00), 0.085)
region("chest_front", (0.0, 0.73, 0.10), 0.10)
region("helmet", (0.0, 0.90, 0.01), 0.09)
region("knee_R", (-0.097, 0.285, 0.02), 0.075)
region("knee_L", (0.097, 0.285, 0.02), 0.075)
region("shin_R", (-0.115, 0.19, 0.01), 0.075)
region("forearm_R", (-0.31, 0.615, 0.03), 0.08)
region("forearm_L", (0.31, 0.615, 0.03), 0.08)
print("DONE")
