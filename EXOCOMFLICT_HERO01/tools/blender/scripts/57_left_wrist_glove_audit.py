"""Read-only left wrist/glove audit (script 57).

Script 56's wrist_L zone matched 0 verts: vertices near Hand_L are not
arm-chain-only. This script lists every island with vertices near the
Hand_L segment, its weight composition, and measures which bone actually
moves those islands under isolated Forearm_L / Hand_L / UpperLeg_L
rotations. No save.
"""
import math

import bpy
import numpy as np
from mathutils import Matrix

PROJ = "/home/user/Cyber-Strike/EXOCOMFLICT_HERO01"
bpy.ops.wm.open_mainfile(filepath=f"{PROJ}/blender/HERO_01_working.blend")
sc = bpy.context.scene
sc.frame_set(0)
arm = bpy.data.objects["HERO_01_Armature"]
body = bpy.data.objects["HERO_01_BODY"]
bones = arm.data.bones


def jpos(name, tail=False):
    b = bones[name]
    return np.array(arm.matrix_world @ (b.tail_local if tail else b.head_local))


n = len(body.data.vertices)
mw = np.array(body.matrix_world)
co = np.empty(n * 3, dtype=np.float64)
body.data.vertices.foreach_get("co", co)
P0 = co.reshape(-1, 3) @ mw[:3, :3].T + mw[:3, 3]
gnames = [g.name for g in body.vertex_groups]
gidx = {name: i for i, name in enumerate(gnames)}
W = np.zeros((n, len(gnames)), dtype=np.float64)
for v in body.data.vertices:
    for ge in v.groups:
        W[v.index, ge.group] = ge.weight
DOM = np.argmax(W, axis=1)

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
NISL = int(ISL.max() + 1)
cnt = np.bincount(ISL).astype(np.float64)
icen = np.stack([np.bincount(ISL, weights=P0[:, k]) / cnt for k in range(3)], axis=1)
iw = np.stack([np.bincount(ISL, weights=W[:, gi]) / cnt for gi in range(len(gnames))], axis=1)


def top(i, k=4):
    idx = np.argsort(-iw[i])[:k]
    return ", ".join(f"{gnames[j]}={iw[i,j]:.2f}" for j in idx if iw[i, j] > 0.01)


def seg_dist(Pts, A, B):
    AB = B - A
    t = np.clip(((Pts - A) @ AB) / (AB @ AB), 0, 1)
    proj = A + t[:, None] * AB
    return np.linalg.norm(Pts - proj, axis=1), t * float(np.linalg.norm(AB))


H, T = jpos("Hand_L"), jpos("Hand_L", True)
E = jpos("Forearm_L")
print(f"Hand_L head={np.round(H,3)} tail={np.round(T,3)} elbow={np.round(E,3)}")
d_hand, s_hand = seg_dist(P0, H, T)
d_fore, s_fore = seg_dist(P0, E, H)
near = np.minimum(d_hand, np.where(s_fore > 0.13, d_fore, 1e9)) <= 0.030
print(f"near wrist/hand verts (<=30mm of Hand segment or distal 47mm of forearm): {int(near.sum())}")
doms, counts = np.unique(DOM[near], return_counts=True)
print(" dominant among near verts:", ", ".join(f"{gnames[i]}:{c}" for i, c in sorted(zip(doms, counts), key=lambda t: -t[1])))

cand = []
for i in range(NISL):
    m = near & (ISL == i)
    c = int(m.sum())
    if c >= 15:
        cand.append((c, i))
cand.sort(reverse=True)
print("\nISLANDS WITH >=15 VERTS NEAR LEFT WRIST/HAND:")
for c, i in cand:
    m = ISL == i
    q = P0[m]
    print(f" isl={i:3d} total={int(cnt[i]):5d} near={c:5d} cen=({icen[i,0]:+.3f},{icen[i,1]:+.3f},{icen[i,2]:+.3f}) "
          f"bbox x[{q[:,0].min():+.3f},{q[:,0].max():+.3f}] y[{q[:,1].min():+.3f},{q[:,1].max():+.3f}] z[{q[:,2].min():+.3f},{q[:,2].max():+.3f}]")
    print(f"        avgW island: {top(i,5)} | near-vert avg: " +
          ", ".join(f"{b}={W[near & (ISL==i), gidx[b]].mean():.2f}" for b in ("UpperArm_L", "Forearm_L", "Hand_L", "UpperLeg_L", "Hips") if W[near & (ISL == i), gidx[b]].mean() > 0.01))

# Hand-region boxes in rest space, for comparison with the right glove.
for side in ("L", "R"):
    Hh, Tt = jpos(f"Hand_{side}"), jpos(f"Hand_{side}", True)
    d, s = seg_dist(P0, Hh, Tt)
    sel = d <= 0.028
    print(f"\nHAND SEGMENT {side}: verts<=28mm={int(sel.sum())}")
    for b in ("UpperArm_" + side, "Forearm_" + side, "Hand_" + side, "UpperLeg_" + side, "Hips"):
        print(f"   avg {b}={W[sel,gidx[b]].mean():.3f} max={W[sel,gidx[b]].max():.3f}")
    doms, counts = np.unique(DOM[sel], return_counts=True)
    print("   dominant:", ", ".join(f"{gnames[i]}:{c}" for i, c in sorted(zip(doms, counts), key=lambda t: -t[1])[:6]))

# Which bone actually moves the candidate islands?
if arm.animation_data:
    arm.animation_data.action = None


def reset_pose():
    for pb in arm.pose.bones:
        pb.location = (0, 0, 0)
        pb.rotation_quaternion = (1, 0, 0, 0)
        pb.rotation_euler = (0, 0, 0)
        pb.scale = (1, 1, 1)
    bpy.context.view_layer.update()


def rot_world(name, axis, deg):
    pb = arm.pose.bones[name]
    head = pb.head.copy()
    M = Matrix.Translation(head) @ Matrix.Rotation(math.radians(deg), 4, axis) @ Matrix.Translation(-head)
    pb.matrix = M @ pb.matrix
    bpy.context.view_layer.update()


def eval_coords():
    dg = bpy.context.evaluated_depsgraph_get()
    eo = body.evaluated_get(dg)
    em = eo.to_mesh()
    p = np.empty(n * 3, dtype=np.float64)
    em.vertices.foreach_get("co", p)
    eo.to_mesh_clear()
    emw = np.array(eo.matrix_world)
    return p.reshape(-1, 3) @ emw[:3, :3].T + emw[:3, 3]


reset_pose()
BASE = eval_coords()
icen0 = np.stack([np.bincount(ISL, weights=BASE[:, k]) / cnt for k in range(3)], axis=1)
tests = [("Forearm_L -55X", "Forearm_L", -55), ("Hand_L -40X", "Hand_L", -40), ("UpperLeg_L -35X", "UpperLeg_L", -35)]
disp = {}
for tname, bone, deg in tests:
    reset_pose()
    rot_world(bone, (1, 0, 0), deg)
    P = eval_coords()
    ic = np.stack([np.bincount(ISL, weights=P[:, k]) / cnt for k in range(3)], axis=1)
    disp[tname] = np.linalg.norm(ic - icen0, axis=1)
print("\nISLAND CENTROID DISPLACEMENT (mm) under isolated rotations:")
for c, i in cand:
    print(f" isl={i:3d} total={int(cnt[i]):5d} near={c:5d}  " +
          "  ".join(f"{t}={disp[t][i]*1000:6.1f}" for t, _, _ in tests) + f"  | {top(i)}")
reset_pose()
print("DONE (read-only)")
