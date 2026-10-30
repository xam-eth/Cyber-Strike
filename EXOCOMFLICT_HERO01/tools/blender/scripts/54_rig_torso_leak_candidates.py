"""Read-only torso-island leak candidate scan (script 54).

Lists islands whose centroid sits inside a central-torso tube around the
spine centerline but whose average weights are dominated by arm or leg
bones. Island 101 (scripts 51-53) is the confirmed example; this checks
whether it is alone. Also lists islands near each wrist with their
Forearm-vs-Hand balance (left wrist articulation check). No save.
"""
import bpy
import numpy as np

PROJ = "/home/user/Cyber-Strike/EXOCOMFLICT_HERO01"
bpy.ops.wm.open_mainfile(filepath=f"{PROJ}/blender/HERO_01_working.blend")
arm = bpy.data.objects["HERO_01_Armature"]
body = bpy.data.objects["HERO_01_BODY"]

n = len(body.data.vertices)
mw = np.array(body.matrix_world)
co = np.empty(n * 3, dtype=np.float64)
body.data.vertices.foreach_get("co", co)
P0 = co.reshape(-1, 3) @ mw[:3, :3].T + mw[:3, 3]
gnames = [g.name for g in body.vertex_groups]
gidx = {name: i for i, name in enumerate(gnames)}
W = np.zeros((n, len(gnames)), dtype=np.float64)
for vi, v in enumerate(body.data.vertices):
    for ge in v.groups:
        W[vi, ge.group] = ge.weight

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
order = np.argsort(ISL, kind="stable")
sorted_isl = ISL[order]
starts = np.flatnonzero(np.r_[True, sorted_isl[1:] != sorted_isl[:-1]])
ends = np.r_[starts[1:], n]
ibmin = np.zeros((NISL, 3)); ibmax = np.zeros((NISL, 3))
for ii, (s, e) in enumerate(zip(starts, ends)):
    q = P0[order[s:e]]
    ibmin[ii], ibmax[ii] = q.min(axis=0), q.max(axis=0)

SPINE = ["Hips", "Spine", "Chest", "UpperChest", "Neck", "Head"]
ARMS = ["Clavicle_R", "UpperArm_R", "Forearm_R", "Hand_R", "Clavicle_L", "UpperArm_L", "Forearm_L", "Hand_L"]
LEGS = ["UpperLeg_R", "LowerLeg_R", "Foot_R", "Toe_R", "UpperLeg_L", "LowerLeg_L", "Foot_L", "Toe_L"]
iw_spine = iw[:, [gidx[b] for b in SPINE]].sum(axis=1)
iw_arm = iw[:, [gidx[b] for b in ARMS]].sum(axis=1)
iw_leg = iw[:, [gidx[b] for b in LEGS]].sum(axis=1)


def top(i, k=4):
    idx = np.argsort(-iw[i])[:k]
    return ", ".join(f"{gnames[j]}={iw[i,j]:.2f}" for j in idx if iw[i, j] > 0.01)


# spine centerline x(z), y(z) from the actual bone heads
spine_pts = []
for bname in ("Hips", "Spine", "Chest", "UpperChest", "Neck", "Head"):
    spine_pts.append(np.array(arm.matrix_world @ arm.data.bones[bname].head_local))
spine_pts = np.array(spine_pts)


def center_at(z):
    # piecewise-linear between spine bone heads
    zs = spine_pts[:, 2]
    if z <= zs[0]:
        return spine_pts[0, 0], spine_pts[0, 1]
    if z >= zs[-1]:
        return spine_pts[-1, 0], spine_pts[-1, 1]
    i = int(np.searchsorted(zs, z) - 1)
    t = (z - zs[i]) / max(zs[i + 1] - zs[i], 1e-9)
    return (spine_pts[i, 0] * (1 - t) + spine_pts[i + 1, 0] * t,
            spine_pts[i, 1] * (1 - t) + spine_pts[i + 1, 1] * t)


print("=== CENTRAL-TORSO ISLANDS WITH ARM/LEG-DOMINATED WEIGHTS ===")
print("(centroid within dx<0.085, dy<0.090 of spine centerline, z 0.44-0.86, n>=80)")
for i in range(NISL):
    if cnt[i] < 80:
        continue
    z = icen[i, 2]
    if not (0.44 <= z <= 0.86):
        continue
    cx, cy = center_at(z)
    dx, dy = abs(icen[i, 0] - cx), abs(icen[i, 1] - cy)
    if dx >= 0.085 or dy >= 0.090:
        continue
    if iw_arm[i] >= 0.25 or iw_leg[i] >= 0.25:
        print(f" isl={i:3d} n={int(cnt[i]):5d} cen=({icen[i,0]:+.3f},{icen[i,1]:+.3f},{icen[i,2]:+.3f}) d=({dx:.3f},{dy:.3f}) "
              f"spineW={iw_spine[i]:.2f} armW={iw_arm[i]:.2f} legW={iw_leg[i]:.2f} top: {top(i)}")
        print(f"        bbox x[{ibmin[i,0]:+.3f},{ibmax[i,0]:+.3f}] y[{ibmin[i,1]:+.3f},{ibmax[i,1]:+.3f}] z[{ibmin[i,2]:+.3f},{ibmax[i,2]:+.3f}]")

print("\n=== ISLANDS NEAR WRISTS (centroid within 55mm of Hand head/tail axis points) ===")
bones = arm.data.bones
for side in ("R", "L"):
    H = np.array(arm.matrix_world @ bones[f"Hand_{side}"].head_local)
    T = np.array(arm.matrix_world @ bones[f"Hand_{side}"].tail_local)
    print(f" wrist_{side} head={np.round(H,3)} tail={np.round(T,3)}")
    for i in range(NISL):
        if cnt[i] < 40:
            continue
        if min(np.linalg.norm(icen[i] - H), np.linalg.norm(icen[i] - T)) <= 0.055:
            print(f"   isl={i:3d} n={int(cnt[i]):5d} cen=({icen[i,0]:+.3f},{icen[i,1]:+.3f},{icen[i,2]:+.3f}) "
                  f"Forearm={iw[i,gidx[f'Forearm_{side}']]:.2f} Hand={iw[i,gidx[f'Hand_{side}']]:.2f} top: {top(i)}")

print("\n=== PER-BONE DOMINANT COUNTS (sanity) ===")
DOM = np.argmax(W, axis=1)
for name in gnames:
    print(f" {name:12s} dominant={int((DOM==gidx[name]).sum()):6d}  sumW={float(W[:,gidx[name]].sum()):9.1f}")
print("DONE (read-only)")
