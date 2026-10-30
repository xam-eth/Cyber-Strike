"""Read-only candidate-pivot renders for the Hand_L re-rig (script 59).

Recomputes the script-58 cross-section centers, marks candidate wrist
heads as colored spheres, measures glove principal-axis/tail candidates,
and renders left-glove close-ups. Nothing is saved to the blend.

Candidate sphere colors:
  s=0.106 blue, 0.114 cyan, 0.118 green, 0.122 yellow,
  0.130 orange, 0.138 red. Island53 shell is pale yellow, island72
inner-forearm mint, glove/finger islands coral.
"""
import math
import os

import bpy
import numpy as np
from mathutils import Vector

PROJ = "/home/user/Cyber-Strike/EXOCOMFLICT_HERO01"
OUT = f"{PROJ}/screenshots/rig"
os.makedirs(OUT, exist_ok=True)
bpy.ops.wm.open_mainfile(filepath=f"{PROJ}/blender/HERO_01_working.blend")
sc = bpy.context.scene
arm = bpy.data.objects["HERO_01_Armature"]
body = bpy.data.objects["HERO_01_BODY"]
for name in ("HERO_01_WEAPON", "HERO_01_UNDERSUIT"):
    if name in bpy.data.objects:
        bpy.data.objects[name].hide_render = True
if arm.animation_data:
    arm.animation_data.action = None
for pb in arm.pose.bones:
    pb.location = (0, 0, 0)
    pb.rotation_quaternion = (1, 0, 0, 0)
    pb.scale = (1, 1, 1)
sc.frame_set(0)
bpy.context.view_layer.update()
arm.hide_render = True

n = len(body.data.vertices)
mw = np.array(body.matrix_world)
co = np.empty(n * 3, dtype=np.float64)
body.data.vertices.foreach_get("co", co)
P0 = co.reshape(-1, 3) @ mw[:3, :3].T + mw[:3, 3]
nrm = np.empty(n * 3, dtype=np.float64)
body.data.vertices.foreach_get("normal", nrm)
NRM = nrm.reshape(-1, 3) @ mw[:3, :3].T

ne = len(body.data.edges)
ev = np.empty(ne * 2, dtype=np.int64)
body.data.edges.foreach_get("vertices", ev)
ev = ev.reshape(-1, 2)
parent = np.arange(n, dtype=np.int64)


def find(a):
    while parent[a] != a:
        parent[a] = parent[parent[a]]
        a = parent[a]
    return a


for a, b in ev:
    ra, rb = find(int(a)), find(int(b))
    if ra != rb:
        parent[ra] = rb
roots = np.array([find(i) for i in range(n)])
_, ISL = np.unique(roots, return_inverse=True)

GLOVE_IDS = [52, 19, 2, 26, 156]
SHELL_IDS = [53, 72]
glove_mask = np.isin(ISL, GLOVE_IDS)
shell_mask = np.isin(ISL, SHELL_IDS)
combined = glove_mask | shell_mask
glove_c = P0[glove_mask].mean(axis=0)
EL = np.array(arm.matrix_world @ arm.data.bones["Forearm_L"].head_local)
axis0 = glove_c - EL
axis = axis0 / np.linalg.norm(axis0)
ref = np.array([1.0, 0, 0])
u = ref - axis * float(ref @ axis)
u /= np.linalg.norm(u)
v = np.cross(axis, u)
rel = P0[combined] - EL
s_all = rel @ axis
pu = rel @ u
pv = rel @ v
rows = {}
for lo in np.arange(0.0, 0.17, 0.004):
    m = (s_all >= lo) & (s_all < lo + 0.004)
    if int(m.sum()) < 20:
        continue
    cu = 0.5 * (np.percentile(pu[m], 2.5) + np.percentile(pu[m], 97.5))
    cv = 0.5 * (np.percentile(pv[m], 2.5) + np.percentile(pv[m], 97.5))
    center = EL + axis * (lo + 0.002) + u * cu + v * cv
    rows[float(lo + 0.002)] = center

CANDS = {
    0.106: (0.05, 0.25, 1.0, "blue"),
    0.114: (0.0, 0.9, 1.0, "cyan"),
    0.118: (0.05, 1.0, 0.25, "green"),
    0.122: (1.0, 0.9, 0.05, "yellow"),
    0.130: (1.0, 0.45, 0.05, "orange"),
    0.138: (1.0, 0.08, 0.08, "red"),
}
print("CANDIDATES:")
cand_points = {}
combined_ids = np.flatnonzero(combined)
s_by_vertex = np.full(n, np.nan)
s_by_vertex[combined_ids] = s_all
for skey, (r, g, b, label) in CANDS.items():
    nearest = min(rows, key=lambda x: abs(x - skey))
    c = rows[nearest]
    cand_points[skey] = c
    distal = combined & (s_by_vertex > nearest + 0.015)
    pts = P0[distal]
    cen = pts.mean(axis=0)
    # Principal axis of points distal to the candidate.
    X = pts - cen
    _, _, vt = np.linalg.svd(X, full_matrices=False)
    paxis = vt[0]
    if float(paxis @ (cen - c)) < 0:
        paxis = -paxis
    ds = (pts - c) @ paxis
    tip_c = pts[ds >= np.percentile(ds, 90)].mean(axis=0)
    d_centroid = glove_c - c
    print(f" s={nearest:.3f} {label:6s} head={np.round(c,4)} forearm_len={np.linalg.norm(c-EL):.4f}")
    print(f"    head->glove-centroid={np.round(d_centroid,4)} len={np.linalg.norm(d_centroid):.4f}; "
          f"distal centroid={np.round(cen,4)} paxis={np.round(paxis,3)}; distal90 centroid={np.round(tip_c,4)} len={np.linalg.norm(tip_c-c):.4f}")
    for L in (0.050, 0.058, 0.068):
        tail = c + paxis * L
        print(f"    tail L={L:.3f}: {np.round(tail,4)}")

# s ranges of each relevant island along the same axis.
print("\nISLAND S RANGES (axis elbow->glove centroid):")
for iid in SHELL_IDS + GLOVE_IDS:
    vals = s_by_vertex[ISL == iid]
    vals = vals[np.isfinite(vals)]
    print(f" isl={iid:3d} s min/med/max={vals.min():.3f}/{np.median(vals):.3f}/{vals.max():.3f}")

# Clay + island overlays.
clay = bpy.data.materials.new("CandidateClay")
clay.use_nodes = True
bsdf = clay.node_tree.nodes["Principled BSDF"]
bsdf.inputs["Base Color"].default_value = (0.52, 0.54, 0.58, 1)
bsdf.inputs["Roughness"].default_value = 0.85
body.data.materials.clear()
body.data.materials.append(clay)


def emissive(name, rgb, strength=0.75):
    m = bpy.data.materials.new(name)
    m.use_nodes = True
    b = m.node_tree.nodes["Principled BSDF"]
    b.inputs["Base Color"].default_value = (*rgb, 1)
    b.inputs["Emission Color"].default_value = (*rgb, 1)
    b.inputs["Emission Strength"].default_value = strength
    b.inputs["Roughness"].default_value = 0.6
    return m


body.data.calc_loop_triangles()
tris = np.array([t.vertices for t in body.data.loop_triangles], dtype=np.int64)
tri_isl = ISL[tris[:, 0]]
HL = {53: (1.0, 0.82, 0.35), 72: (0.45, 1.0, 0.82)}
for iid in GLOVE_IDS:
    HL[iid] = (1.0, 0.36, 0.32)
for iid, rgb in HL.items():
    vmask = ISL == iid
    vids = np.flatnonzero(vmask)
    remap = {int(v0): i for i, v0 in enumerate(vids)}
    faces = []
    for t in tris[tri_isl == iid]:
        if vmask[t[0]] and vmask[t[1]] and vmask[t[2]]:
            faces.append([remap[int(t[0])], remap[int(t[1])], remap[int(t[2])]])
    pts = P0[vids] + NRM[vids] * 0.0015
    me = bpy.data.meshes.new(f"HL59_{iid}")
    me.from_pydata(pts.tolist(), [], faces)
    ob = bpy.data.objects.new(f"HL59_{iid}", me)
    sc.collection.objects.link(ob)
    me.materials.append(emissive(f"HL59mat_{iid}", rgb, 0.55))

for skey, c in cand_points.items():
    r, g, b, label = CANDS[skey]
    bpy.ops.mesh.primitive_ico_sphere_add(radius=0.0075, location=Vector(c))
    o = bpy.context.active_object
    o.name = f"CAND_{label}_{skey:.3f}"
    o.data.materials.append(emissive(f"CandMat_{label}", (r, g, b), 1.2))

# Elbow marker white.
bpy.ops.mesh.primitive_ico_sphere_add(radius=0.009, location=Vector(EL))
o = bpy.context.active_object
o.name = "ELBOW_L"
o.data.materials.append(emissive("ElbowWhite", (1, 1, 1), 1.0))

sc.render.engine = "CYCLES"
sc.cycles.samples = 24
sc.cycles.use_denoising = True
sc.cycles.device = "CPU"
w = bpy.data.worlds.new("CandidateWorld")
sc.world = w
w.use_nodes = True
w.node_tree.nodes["Background"].inputs[0].default_value = (0.16, 0.17, 0.19, 1)
w.node_tree.nodes["Background"].inputs[1].default_value = 0.95
sd = bpy.data.lights.new("Sun", "SUN")
sd.energy = 3.0
so = bpy.data.objects.new("Sun", sd)
sc.collection.objects.link(so)
so.rotation_euler = (math.radians(52), math.radians(8), math.radians(-38))
cam = bpy.data.objects.new("CandCam", bpy.data.cameras.new("CandCam"))
sc.collection.objects.link(cam)
sc.camera = cam


def shoot(name, loc, target=(0.245, -0.012, 0.492), lens=58):
    cam.data.lens = lens
    cam.location = loc
    cam.rotation_euler = (Vector(target) - Vector(loc)).to_track_quat("-Z", "Y").to_euler()
    sc.render.resolution_x = 900
    sc.render.resolution_y = 900
    sc.render.filepath = f"{OUT}/{name}.png"
    bpy.ops.render.render(write_still=True)
    print("RENDERED", name)


shoot("audit59_wrist_candidates_front", (0.245, -0.62, 0.51))
shoot("audit59_wrist_candidates_sideL", (0.78, -0.02, 0.51))
shoot("audit59_wrist_candidates_3q", (0.58, -0.48, 0.60))
print("DONE (read-only)")
