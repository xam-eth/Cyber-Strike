"""Read-only island/fold audit for HERO_01 (script 51), follow-up to 50.

Script 50 showed: elbow/knee weight crossovers sit at the bone pivots, but
the arm SEGMENT LENGTHS are strongly asymmetric (forearm L 0.177 vs R
0.119). This script therefore asks geometry-first questions, independent
of the current weights where possible:

  1. CENTERLINE PINCH: slice the rest mesh along each straight limb axis
     (shoulder->wrist, hip->ankle). A joint fold usually appears as a
     local minimum of cross-section radius and/or a centerline kink.
     Compare pinch locations with the current bone pivots.
  2. ISLANDS ALONG THE CHAIN + JOINT-CROSSING ISLANDS: the source is 223
     loose shells; if one rigid armor shell straddles a fold, the visible
     bend happens at the shell edge instead of the anatomical joint.
  3. WAIST ISLANDS UNDER ARM ROTATION: rotate only shoulder/elbow bones
     and list every island whose rest centroid lies in the waist region,
     with its average weights, so a moving "waist flap" can be identified
     as either a real arm shell passing through the region or a torso
     island carrying arm weights (a true leak).

Nothing is saved. Run via tools/blender/run_bpy.sh.
"""
import math

import bpy
import numpy as np
from mathutils import Matrix

PROJ = "/home/user/Cyber-Strike/EXOCOMFLICT_HERO01"
BLEND = f"{PROJ}/blender/HERO_01_working.blend"

bpy.ops.wm.open_mainfile(filepath=BLEND)
sc = bpy.context.scene
sc.frame_set(0)
arm = bpy.data.objects["HERO_01_Armature"]
body = bpy.data.objects["HERO_01_BODY"]
bones = arm.data.bones


def jpos(name, tail=False):
    b = bones[name]
    return np.array(arm.matrix_world @ (b.tail_local if tail else b.head_local))


def to_world(mat_np, pts):
    return pts @ mat_np[:3, :3].T + mat_np[:3, 3]


n = len(body.data.vertices)
co = np.empty(n * 3, dtype=np.float64)
body.data.vertices.foreach_get("co", co)
P0 = to_world(np.array(body.matrix_world), co.reshape(-1, 3))
gnames = [g.name for g in body.vertex_groups]
gidx = {name: i for i, name in enumerate(gnames)}
W = np.zeros((n, len(gnames)), dtype=np.float64)
for vi, v in enumerate(body.data.vertices):
    for ge in v.groups:
        W[vi, ge.group] = ge.weight
DOM = np.argmax(W, axis=1)

# ---------------------------------------------------------------- islands
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
imin = np.stack([np.minimum.at(np.full(NISL, 1e9), ISL, P0[:, k]) if False else
                 np.array([P0[ISL == i, k].min() if False else 0 for i in range(0)]) for k in range(3)], axis=1) if False else None
# bbox via pandas-free loop over sorted order
order = np.argsort(ISL, kind="stable")
sorted_isl = ISL[order]
starts = np.flatnonzero(np.r_[True, sorted_isl[1:] != sorted_isl[:-1]])
ends = np.r_[starts[1:], n]
ibmin = np.zeros((NISL, 3))
ibmax = np.zeros((NISL, 3))
for ii, (s, e) in enumerate(zip(starts, ends)):
    q = P0[order[s:e]]
    ibmin[ii] = q.min(axis=0)
    ibmax[ii] = q.max(axis=0)
iw_avg = np.stack([np.bincount(ISL, weights=W[:, gi]) / cnt for gi in range(len(gnames))], axis=1)
print(f"BODY verts={n} islands={NISL} groups={len(gnames)}")


def top_weights(i, k=3):
    row = iw_avg[i]
    idx = np.argsort(-row)[:k]
    return ", ".join(f"{gnames[j]}={row[j]:.2f}" for j in idx if row[j] > 0.01)


def seg_proj(Pts, A, B):
    AB = B - A
    L = float(np.linalg.norm(AB))
    t = np.clip(((Pts - A) @ AB) / (L * L), 0.0, 1.0)
    proj = A + t[:, None] * AB
    return t * L, np.linalg.norm(Pts - proj, axis=1), L


# ---------------------------------------------------------------- 1. centerline pinch
print("\n=== 1. LIMB CENTERLINE SLICES (rest geometry only) ===")


def limb_slices(name, A, B, joint_pos, joint_label, side_mask, radius=0.060, step=0.01):
    axis = B - A
    L = float(np.linalg.norm(axis))
    u = axis / L
    rel = P0 - A
    along = rel @ u
    radial_vec = rel - along[:, None] * u
    radial = np.linalg.norm(radial_vec, axis=1)
    print(f"\n--- {name}: axis length={L:.3f}; current {joint_label} projects to "
          f"s={float((joint_pos-A)@u):.3f} ({100*float((joint_pos-A)@u)/L:.0f}%), offset from axis="
          f"{float(np.linalg.norm((joint_pos-A)-((joint_pos-A)@u)*u))*1000:.1f}mm ---")
    rows = []
    s_vals = np.arange(step / 2, L, step)
    for s in s_vals:
        sel = side_mask & (np.abs(along - s) <= step / 2) & (radial <= radius)
        if sel.sum() < 40:
            rows.append((s, int(sel.sum()), None, None, None))
            continue
        cen = P0[sel].mean(axis=0)
        v = P0[sel] - cen
        vperp = v - (v @ u)[:, None] * u
        rr = np.linalg.norm(vperp, axis=1)
        rows.append((s, int(sel.sum()), cen, float(np.percentile(rr, 90)), float(np.sqrt((rr ** 2).mean()))))
    p90 = np.array([r[3] if r[3] is not None else np.nan for r in rows])
    smooth = np.convolve(np.nan_to_num(p90, nan=np.nanmean(p90)), np.ones(3) / 3, mode="same")
    for i, (s, c, cen, r90, rrms) in enumerate(rows):
        if cen is None:
            print(f"  s={s:.3f} ({100*s/L:4.0f}%) n={c:4d}  (empty)")
        else:
            print(f"  s={s:.3f} ({100*s/L:4.0f}%) n={c:4d} cen=({cen[0]:+.3f},{cen[1]:+.3f},{cen[2]:+.3f}) "
                  f"r90={r90*1000:5.1f}mm rrms={rrms*1000:5.1f}mm smooth_r90={smooth[i]*1000:5.1f}mm")
    cand = []
    for i in range(1, len(rows) - 1):
        s = rows[i][0]
        if 0.20 * L <= s <= 0.82 * L and smooth[i] <= smooth[i - 1] and smooth[i] <= smooth[i + 1]:
            cand.append((float(smooth[i]), float(s)))
    cand.sort()
    js = float((joint_pos - A) @ u)
    print(f"  pinch candidates (local r90 minima, mid-limb): " +
          (", ".join(f"s={s:.3f} ({100*s/L:.0f}%, r90~{v*1000:.0f}mm, {abs(s-js)*1000:.0f}mm from current {joint_label})" for v, s in cand[:4]) or "none"))
    return cand


for side in ("R", "L"):
    smask = (P0[:, 0] < -0.035) if side == "R" else (P0[:, 0] > 0.055)
    smask &= (P0[:, 2] > 0.34) & (P0[:, 2] < 0.82) & (np.abs(P0[:, 1]) < 0.10)
    limb_slices(f"ARM_{side} shoulder->wrist", jpos(f"UpperArm_{side}"), jpos(f"Hand_{side}"),
                jpos(f"Forearm_{side}"), "elbow", smask)
for side in ("R", "L"):
    smask = (P0[:, 0] < 0.02) if side == "R" else (P0[:, 0] > 0.05)
    smask &= (P0[:, 2] < 0.56) & (np.abs(P0[:, 1]) < 0.12)
    limb_slices(f"LEG_{side} hip->ankle", jpos(f"UpperLeg_{side}"), jpos(f"Foot_{side}"),
                jpos(f"LowerLeg_{side}"), "knee", smask, radius=0.065)

# ---------------------------------------------------------------- 2. islands along chains + crossing joints
print("\n=== 2. ISLANDS ALONG LIMB CHAINS (centroid within 60mm of polyline, n>=80) ===")


def chain_islands(name, joints, joint_marks):
    # arc length / distance of every vertex to the polyline
    best_d = np.full(n, 1e9)
    best_s = np.zeros(n)
    offset = 0.0
    marks = []
    for i in range(len(joints) - 1):
        along, d, L = seg_proj(P0, joints[i], joints[i + 1])
        upd = d < best_d
        best_d[upd] = d[upd]
        best_s[upd] = offset + along[upd]
        offset += L
        marks.append(offset)
    icen_d = np.zeros(NISL)
    icen_s = np.zeros(NISL)
    # island centroid projected the same way
    bd = np.full(NISL, 1e9)
    bs = np.zeros(NISL)
    off = 0.0
    for i in range(len(joints) - 1):
        along, d, L = seg_proj(icen, joints[i], joints[i + 1])
        upd = d < bd
        bd[upd] = d[upd]
        bs[upd] = off + along[upd]
        off += L
    sel = [i for i in range(NISL) if bd[i] <= 0.06 and cnt[i] >= 80]
    sel.sort(key=lambda i: bs[i])
    print(f"\n--- {name} (joint arc marks: {', '.join(f'{lab}@{v:.3f}' for lab, v in joint_marks)}) ---")
    for i in sel:
        span = ibmax[i] - ibmin[i]
        print(f"  arc={bs[i]:.3f} isl={i:3d} n={int(cnt[i]):5d} cen=({icen[i,0]:+.3f},{icen[i,1]:+.3f},{icen[i,2]:+.3f}) "
              f"maxspan={span.max():.3f} avgW: {top_weights(i)}")
    return best_s, best_d


chain_data = {}
for side in ("R", "L"):
    ua = float(np.linalg.norm(jpos(f"Forearm_{side}") - jpos(f"UpperArm_{side}")))
    fa = float(np.linalg.norm(jpos(f"Hand_{side}") - jpos(f"Forearm_{side}")))
    chain_data[f"arm_{side}"] = chain_islands(
        f"ARM_{side}", [jpos(f"UpperArm_{side}"), jpos(f"Forearm_{side}"), jpos(f"Hand_{side}"), jpos(f"Hand_{side}", True)],
        [("elbow", ua), ("wrist", ua + fa)])
    th = float(np.linalg.norm(jpos(f"LowerLeg_{side}") - jpos(f"UpperLeg_{side}")))
    sh = float(np.linalg.norm(jpos(f"Foot_{side}") - jpos(f"LowerLeg_{side}")))
    chain_data[f"leg_{side}"] = chain_islands(
        f"LEG_{side}", [jpos(f"UpperLeg_{side}"), jpos(f"LowerLeg_{side}"), jpos(f"Foot_{side}"), jpos(f"Toe_{side}", True)],
        [("knee", th), ("ankle", th + sh)])

print("\n--- JOINT-CROSSING ISLANDS (>=30 verts and >=10% of near-joint verts on EACH side) ---")


def crossing(name, p_bone, j_bone, d_pos, prox_bone, dist_bone, radius=0.055):
    P, J, D = jpos(p_bone), jpos(j_bone), d_pos
    along_p, d_p, len_p = seg_proj(P0, P, J)
    along_d, d_d, len_d = seg_proj(P0, J, D)
    s = np.where(d_d < d_p, along_d, along_p - len_p)
    near = (np.minimum(d_p, d_d) <= radius) & (s >= -0.09) & (s <= len_d + 0.02)
    print(f" {name}:")
    found = False
    for i in range(NISL):
        sel = near & (ISL == i)
        c = int(sel.sum())
        if c < 60:
            continue
        npro = int((sel & (s < -0.01)).sum())
        ndis = int((sel & (s > 0.01)).sum())
        if npro >= 30 and ndis >= 30 and npro >= 0.1 * c and ndis >= 0.1 * c:
            found = True
            print(f"   isl={i:3d} total_n={int(cnt[i]):5d} near={c} prox={npro} dist={ndis} "
                  f"s_range=[{s[sel].min():+.3f},{s[sel].max():+.3f}] "
                  f"avgW {prox_bone}={iw_avg[i, gidx[prox_bone]]:.2f} {dist_bone}={iw_avg[i, gidx[dist_bone]]:.2f} "
                  f"cen=({icen[i,0]:+.3f},{icen[i,1]:+.3f},{icen[i,2]:+.3f}) top: {top_weights(i)}")
    if not found:
        print("   (none)")


for side in ("R", "L"):
    crossing(f"elbow_{side}", f"UpperArm_{side}", f"Forearm_{side}", jpos(f"Hand_{side}"), f"UpperArm_{side}", f"Forearm_{side}")
    crossing(f"knee_{side}", f"UpperLeg_{side}", f"LowerLeg_{side}", jpos(f"Foot_{side}"), f"UpperLeg_{side}", f"LowerLeg_{side}")
    crossing(f"shoulder_{side}", f"Clavicle_{side}", f"UpperArm_{side}", jpos(f"Forearm_{side}"), f"Clavicle_{side}", f"UpperArm_{side}")
    crossing(f"wrist_{side}", f"Forearm_{side}", f"Hand_{side}", jpos(f"Hand_{side}", True), f"Forearm_{side}", f"Hand_{side}")
    crossing(f"hip_{side}", "Hips", f"UpperLeg_{side}", jpos(f"LowerLeg_{side}"), "Hips", f"UpperLeg_{side}", radius=0.065)
    crossing(f"ankle_{side}", f"LowerLeg_{side}", f"Foot_{side}", jpos(f"Toe_{side}", True), f"LowerLeg_{side}", f"Foot_{side}")
crossing("neck_base", "UpperChest", "Neck", jpos("Head"), "UpperChest", "Neck", radius=0.05)

# ---------------------------------------------------------------- 3. waist islands under arm rotations
print("\n=== 3. WAIST-REGION ISLANDS UNDER ISOLATED ARM ROTATIONS ===")
if arm.animation_data:
    arm.animation_data.action = None


def reset_pose():
    for pb in arm.pose.bones:
        pb.location = (0.0, 0.0, 0.0)
        pb.rotation_quaternion = (1.0, 0.0, 0.0, 0.0)
        pb.rotation_euler = (0.0, 0.0, 0.0)
        pb.scale = (1.0, 1.0, 1.0)
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
    return to_world(np.array(eo.matrix_world), p.reshape(-1, 3))


reset_pose()
BASE = eval_coords()
icen0 = np.stack([np.bincount(ISL, weights=BASE[:, k]) / cnt for k in range(3)], axis=1)

SPINECHAIN = ["Root", "Hips", "Spine", "Chest", "UpperChest", "Neck", "Head"]
ARMS_ALL = ["Clavicle_R", "UpperArm_R", "Forearm_R", "Hand_R", "Clavicle_L", "UpperArm_L", "Forearm_L", "Hand_L"]
iw_spine = iw_avg[:, [gidx[b] for b in SPINECHAIN if b in gidx]].sum(axis=1)
iw_arm = iw_avg[:, [gidx[b] for b in ARMS_ALL]].sum(axis=1)

waist_isl = [i for i in range(NISL)
             if abs(icen[i, 0]) < 0.23 and abs(icen[i, 1]) < 0.16 and 0.44 < icen[i, 2] < 0.70 and cnt[i] >= 40]
print(f" waist-region islands (centroid |x|<0.23, |y|<0.16, z 0.44-0.70, n>=40): {len(waist_isl)}")

for tname, bone, axis, deg in [
    ("SHOULDER_R -60X", "UpperArm_R", (1, 0, 0), -60),
    ("SHOULDER_L -60X", "UpperArm_L", (1, 0, 0), -60),
    ("ELBOW_R -55X", "Forearm_R", (1, 0, 0), -55),
    ("ELBOW_L -55X", "Forearm_L", (1, 0, 0), -55),
]:
    reset_pose()
    rot_world(bone, axis, deg)
    P = eval_coords()
    icenP = np.stack([np.bincount(ISL, weights=P[:, k]) / cnt for k in range(3)], axis=1)
    idisp = np.linalg.norm(icenP - icen0, axis=1)
    vdisp = np.linalg.norm(P - BASE, axis=1)
    imax = np.zeros(NISL)
    np.maximum.at(imax, ISL, vdisp)
    print(f" TEST {tname}: waist islands with centroid displacement > 2mm:")
    rows = [(idisp[i], i) for i in waist_isl if idisp[i] > 0.002]
    rows.sort(reverse=True)
    if not rows:
        print("   (none)")
    for d, i in rows:
        cls = "TORSO" if iw_spine[i] >= 0.5 else ("ARM" if iw_arm[i] >= 0.5 else "MIXED")
        print(f"   isl={i:3d} {cls:5s} n={int(cnt[i]):5d} cen=({icen[i,0]:+.3f},{icen[i,1]:+.3f},{icen[i,2]:+.3f}) "
              f"cen_disp={d*1000:6.1f}mm max_vert={imax[i]*1000:6.1f}mm spineW={iw_spine[i]:.2f} armW={iw_arm[i]:.2f} top: {top_weights(i)}")

reset_pose()
print("\nDONE (read-only, blend not saved)")
