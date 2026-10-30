"""Read-only design audit for the approved Hand_L structural re-rig.

Outputs the evidence needed before moving any edit bone:
  1. cross-section radius along the left forearm/glove axis (wrist pinch);
  2. the same measurement on the known-good right side as a control;
  3. glove centroid/extent in rest pose and at legacy aim frame 36;
  4. whether Forearm_L and Hand_L share the same deformation matrix in
     every shipped action. If they do, the new rest skeleton can preserve
     the existing world-space glove trajectory exactly while only the
     local Forearm_L/Hand_L pose bases are re-keyed;
  5. rest-bone axes/rolls useful for choosing the new bone rolls.

No file is saved.
"""
import math

import bpy
import numpy as np
from mathutils import Matrix, Vector

PROJ = "/home/user/Cyber-Strike/EXOCOMFLICT_HERO01"
bpy.ops.wm.open_mainfile(filepath=f"{PROJ}/blender/HERO_01_working.blend")
sc = bpy.context.scene
arm = bpy.data.objects["HERO_01_Armature"]
body = bpy.data.objects["HERO_01_BODY"]
weapon = bpy.data.objects["HERO_01_WEAPON"]
bones = arm.data.bones
if arm.animation_data is None:
    arm.animation_data_create()
ad = arm.animation_data


def set_action(name):
    act = bpy.data.actions[name]
    ad.action = act
    try:
        if len(act.slots) == 0:
            act.slots.new(id_type='OBJECT', name=arm.name)
        ad.action_slot = act.slots[0]
    except Exception as ex:
        print("slot setup", ex)
    return act


def jpos(name, tail=False):
    b = bones[name]
    return np.array(arm.matrix_world @ (b.tail_local if tail else b.head_local), dtype=np.float64)


n = len(body.data.vertices)
mw = np.array(body.matrix_world, dtype=np.float64)
co = np.empty(n * 3, dtype=np.float64)
body.data.vertices.foreach_get("co", co)
P0 = co.reshape(-1, 3) @ mw[:3, :3].T + mw[:3, 3]
gnames = [g.name for g in body.vertex_groups]
gidx = {name: i for i, name in enumerate(gnames)}
W = np.zeros((n, len(gnames)), dtype=np.float64)
for v in body.data.vertices:
    for ge in v.groups:
        W[v.index, ge.group] = ge.weight

# Island ids must match scripts 51-57 (same union-find ordering).
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

GLOVE_L_IDS = [52, 19, 2, 26, 156]
SHELL_L_IDS = [53, 72]
print("ISLAND ASSERTIONS LEFT:")
for i in SHELL_L_IDS + GLOVE_L_IDS:
    top = np.argsort(-iw[i])[:4]
    print(f" isl={i:3d} n={int(cnt[i]):5d} cen={np.round(icen[i],3)} " +
          ", ".join(f"{gnames[j]}={iw[i,j]:.2f}" for j in top if iw[i,j] > 0.01))
    assert icen[i, 0] > 0.13 and 0.40 < icen[i, 2] < 0.65

glove_l_mask = np.isin(ISL, GLOVE_L_IDS)
shell_l_mask = np.isin(ISL, SHELL_L_IDS)
glove_l_centroid = P0[glove_l_mask].mean(axis=0)
combined_l_mask = glove_l_mask | shell_l_mask

# Right-side control islands: forearm/hand islands around the known glove.
right_ids = []
for i in range(NISL):
    if cnt[i] < 40:
        continue
    fh = iw[i, gidx["Forearm_R"]] + iw[i, gidx["Hand_R"]]
    if fh > 0.55 and icen[i, 0] < -0.11 and 0.38 < icen[i, 2] < 0.53 and abs(icen[i, 1]) < 0.06:
        right_ids.append(i)
print("\nRIGHT CONTROL ISLAND IDS:", right_ids)
for i in right_ids:
    print(f" isl={i:3d} n={int(cnt[i]):5d} cen={np.round(icen[i],3)} "
          f"F={iw[i,gidx['Forearm_R']]:.2f} H={iw[i,gidx['Hand_R']]:.2f}")
right_mask = np.isin(ISL, right_ids)


def profile(name, start, target, mask):
    axis0 = target - start
    axis_len = float(np.linalg.norm(axis0))
    axis = axis0 / axis_len
    # Stable perpendicular basis.
    ref = np.array([1.0, 0.0, 0.0])
    if abs(float(axis @ ref)) > 0.85:
        ref = np.array([0.0, 1.0, 0.0])
    u = ref - axis * float(ref @ axis)
    u /= np.linalg.norm(u)
    v = np.cross(axis, u)
    rel = P0[mask] - start
    s = rel @ axis
    pu = rel @ u
    pv = rel @ v
    rows = []
    step = 0.004
    for lo in np.arange(0.0, axis_len + 0.025, step):
        m = (s >= lo) & (s < lo + step)
        if int(m.sum()) < 20:
            continue
        uu, vv = pu[m], pv[m]
        cu = 0.5 * (np.percentile(uu, 2.5) + np.percentile(uu, 97.5))
        cv = 0.5 * (np.percentile(vv, 2.5) + np.percentile(vv, 97.5))
        ru = 0.5 * (np.percentile(uu, 97.5) - np.percentile(uu, 2.5))
        rv = 0.5 * (np.percentile(vv, 97.5) - np.percentile(vv, 2.5))
        center = start + axis * (lo + step / 2) + u * cu + v * cv
        centroid = P0[mask][m].mean(axis=0)
        rows.append({
            "s": float(lo + step / 2), "n": int(m.sum()),
            "center": center, "centroid": centroid,
            "ru": float(ru), "rv": float(rv),
            "rgeom": float(math.sqrt(max(ru * rv, 0.0))),
            "area": float(math.pi * ru * rv),
        })
    print(f"\nPROFILE {name}: start={np.round(start,3)} target={np.round(target,3)} axis_len={axis_len:.3f}")
    for r in rows:
        if r["s"] >= 0.045:
            print(f" s={r['s']:.3f} n={r['n']:5d} center={np.round(r['center'],3)} "
                  f"centroid={np.round(r['centroid'],3)} ru/rv={r['ru']*1000:.1f}/{r['rv']*1000:.1f}mm "
                  f"rgeom={r['rgeom']*1000:.1f}mm area={r['area']*1e6:.0f}mm2")
    distal = [r for r in rows if 0.065 <= r["s"] <= axis_len * 0.98]
    if distal:
        best = min(distal, key=lambda r: r["rgeom"])
        print(f" PINCH {name}: s={best['s']:.3f} center={np.round(best['center'],4)} centroid={np.round(best['centroid'],4)} rgeom={best['rgeom']*1000:.1f}mm")
    return rows, axis, u, v


EL = jpos("Forearm_L")
ER = jpos("Forearm_R")
HR = jpos("Hand_R")
TR = jpos("Hand_R", True)
rows_l, axis_l, ul, vl = profile("LEFT elbow->glove-centroid", EL, glove_l_centroid, combined_l_mask)
rows_r, axis_r, ur, vr = profile("RIGHT elbow->hand-tail (control)", ER, TR, right_mask)

# Where does the known-good right wrist sit relative to its profile/glove?
if np.any(right_mask):
    rc = P0[right_mask].mean(axis=0)
    print("\nRIGHT CONTROL GEOMETRY:")
    print(" selected centroid", np.round(rc, 4), "hand head", np.round(HR, 4), "tail", np.round(TR, 4))
    print(" head->centroid", np.round(rc - HR, 4), "len", float(np.linalg.norm(rc - HR)))
    s_head = float((HR - ER) @ axis_r)
    print(f" right wrist profile s={s_head:.3f}")

print("\nLEFT GLOVE REST GEOMETRY:")
q = P0[glove_l_mask]
print(" glove islands centroid", np.round(glove_l_centroid, 4))
print(" glove bbox min", np.round(q.min(axis=0), 4), "max", np.round(q.max(axis=0), 4))
qs = P0[combined_l_mask]
print(" forearm+palm+glove centroid", np.round(qs.mean(axis=0), 4))
print(" old Hand_L head", np.round(jpos('Hand_L'), 4), "tail", np.round(jpos('Hand_L', True), 4))
print(" glove-centroid - old-head", np.round(glove_l_centroid - jpos('Hand_L'), 4),
      "distance", float(np.linalg.norm(glove_l_centroid - jpos('Hand_L'))))

# Rest bone frames/rolls.
print("\nREST BONE FRAMES (armature local matrix columns X/Y/Z + head):")
for name in ("Forearm_L", "Hand_L", "Forearm_R", "Hand_R"):
    b = bones[name]
    M = np.array(b.matrix_local)
    eb = arm.data.edit_bones[name] if arm.mode == 'EDIT' else None
    print(f" {name}: len={b.length:.4f} parent={b.parent.name if b.parent else None} use_connect={b.use_connect}")
    print("   head", np.round(M[:3, 3], 4), "X", np.round(M[:3, 0], 3), "Y", np.round(M[:3, 1], 3), "Z", np.round(M[:3, 2], 3))

# Deformation-matrix equality / local basis in every action.
FG0 = Vector((-0.215, -0.062, 0.315))


def deform_matrix(pb):
    return pb.matrix @ pb.bone.matrix_local.inverted()


def mat_angle_deg(M):
    q = M.to_3x3().to_quaternion()
    return math.degrees(2 * math.acos(min(1.0, abs(q.w))))


print("\nACTION DEFORMATION CHECK: D = pose_matrix @ inverse(rest_matrix)")
for aname in sorted(a.name for a in bpy.data.actions):
    act = set_action(aname)
    lo, hi = [int(round(x)) for x in act.frame_range]
    max_trans = 0.0
    max_rot = 0.0
    max_hand_loc = 0.0
    max_hand_qdev = 0.0
    max_fore_loc = 0.0
    worst = None
    for f in range(lo, hi + 1):
        sc.frame_set(f)
        bpy.context.view_layer.update()
        pf = arm.pose.bones["Forearm_L"]
        ph = arm.pose.bones["Hand_L"]
        Df = deform_matrix(pf)
        Dh = deform_matrix(ph)
        rel = Dh @ Df.inverted()
        trans = float(rel.to_translation().length)
        rot = mat_angle_deg(rel)
        if trans > max_trans or rot > max_rot:
            worst = f
        max_trans = max(max_trans, trans)
        max_rot = max(max_rot, rot)
        max_hand_loc = max(max_hand_loc, float(ph.location.length))
        max_hand_qdev = max(max_hand_qdev, 1.0 - min(1.0, abs(float(ph.rotation_quaternion.w))))
        max_fore_loc = max(max_fore_loc, float(pf.location.length))
    print(f" {aname:22s} frames {lo:3d}-{hi:3d}: max |Dhand-Dfore| trans={max_trans*1000:.3f}mm rot={max_rot:.4f}deg "
          f"(worst F{worst}); Hand_L basis loc<={max_hand_loc:.6f}, 1-|qw|<={max_hand_qdev:.2e}; Forearm loc<={max_fore_loc:.6f}")


def evaluated_coords():
    dg = bpy.context.evaluated_depsgraph_get()
    eo = body.evaluated_get(dg)
    em = eo.to_mesh()
    p = np.empty(n * 3, dtype=np.float64)
    em.vertices.foreach_get("co", p)
    eo.to_mesh_clear()
    emw = np.array(eo.matrix_world, dtype=np.float64)
    return p.reshape(-1, 3) @ emw[:3, :3].T + emw[:3, 3]


set_action("Weapon_Raise_To_Aim")
for frame in (0, 24, 36, 45):
    sc.frame_set(frame)
    bpy.context.view_layer.update()
    P = evaluated_coords()
    gc = P[glove_l_mask].mean(axis=0)
    sc_c = P[combined_l_mask].mean(axis=0)
    fg = np.array(weapon.matrix_world @ FG0)
    old_head = np.array(arm.pose.bones["Hand_L"].head)
    elbow = np.array(arm.pose.bones["Forearm_L"].head)
    print(f"LEGACY F{frame}: glove={np.round(gc,4)} combined={np.round(sc_c,4)} FG={np.round(fg,4)} "
          f"glove-FG={np.round(gc-fg,4)} |glove-FG|={np.linalg.norm(gc-fg):.4f}; "
          f"oldHead-FG={np.linalg.norm(old_head-fg):.4f}; elbow={np.round(elbow,4)}")

# Candidate lengths for a small grid around likely wrist z values.
print("\nCANDIDATE WRIST LENGTHS FROM PROFILE CENTERS:")
for r in rows_l:
    if 0.075 <= r["s"] <= 0.135 and int(round(r["s"] * 1000)) % 8 < 4:
        c = r["center"]
        d = glove_l_centroid - c
        print(f" s={r['s']:.3f} head={np.round(c,4)} forearm_len={np.linalg.norm(c-EL):.4f} "
              f"head->gloveCentroid={np.round(d,4)} len={np.linalg.norm(d):.4f} rgeom={r['rgeom']*1000:.1f}mm")

print("DONE (read-only; blend not saved)")
