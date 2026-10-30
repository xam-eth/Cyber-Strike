"""Read-only anatomical rig audit for HERO_01 (script 50).

Purpose: answer the owner's 2026-10-30 rigging critique with measurements
before any new animation work:
  * Are the anatomical pivots (shoulder/elbow/wrist/hip/knee/ankle/neck)
    placed at the mesh's actual folds?
  * Does each weight transition happen AT the joint, or is the blend zone
    shifted into the distal segment (e.g. bending "in the forearm")?
  * Do arm/shoulder weights leak into the waist?

Method (all on the working blend, NOTHING is saved):
  1. Rest skeleton geometry: bone heads/tails, joint-to-joint segment
     lengths and L/R asymmetry, rest bend angles.
  2. Pivot-in-volume check: centroid of body vertices inside a sphere
     around each joint vs the bone head position.
  3. Weight profiles along each limb chain across every joint: average
     proximal vs distal bone weight in 10 mm bins of signed distance from
     the joint. Reports crossover point (distal >= 0.5) and blend width.
  4. Region leakage: total arm/leg weight inside central waist/chest masks.
  5. Isolated joint rotations: rotate ONE joint, compare evaluated-mesh
     displacement against the rigid-rotation expectation along the distal
     segment (ratio ~1.0 = rigid hinge at the pivot; a long ramp toward
     1.0 = blend zone spread into the segment), and measure how much the
     central waist moves when only arm joints rotate.

Run: tools/blender/run_bpy.sh tools/blender/scripts/50_rig_anatomy_audit.py
"""
import math

import bpy
import numpy as np
from mathutils import Matrix, Vector

PROJ = "/home/user/Cyber-Strike/EXOCOMFLICT_HERO01"
BLEND = f"{PROJ}/blender/HERO_01_working.blend"
ARM_NAME = "HERO_01_Armature"
BODY_NAME = "HERO_01_BODY"

FLAGS = []

# ---------------------------------------------------------------- load
bpy.ops.wm.open_mainfile(filepath=BLEND)
sc = bpy.context.scene
sc.frame_set(0)
arm = bpy.data.objects[ARM_NAME]
body = bpy.data.objects[BODY_NAME]
print("OBJECTS:", [o.name for o in bpy.data.objects])

MW = np.array(body.matrix_world)
ARM_MW = np.array(arm.matrix_world)


def to_world(mat_np, pts):
    return pts @ mat_np[:3, :3].T + mat_np[:3, 3]


n = len(body.data.vertices)
co = np.empty(n * 3, dtype=np.float64)
body.data.vertices.foreach_get("co", co)
P0 = to_world(MW, co.reshape(-1, 3))

gnames = [g.name for g in body.vertex_groups]
gidx = {name: i for i, name in enumerate(gnames)}
W = np.zeros((n, len(gnames)), dtype=np.float64)
for vi, v in enumerate(body.data.vertices):
    for ge in v.groups:
        W[vi, ge.group] = ge.weight
DOM = np.argmax(W, axis=1)
print(f"BODY verts={n} vertex_groups={len(gnames)}")

# ---------------------------------------------------------------- skeleton rest geometry
bones = arm.data.bones


def jpos(name, tail=False):
    b = bones[name]
    v = Vector(b.tail_local if tail else b.head_local)
    return np.array(arm.matrix_world @ v)


print("\n=== 1. REST SKELETON (head -> tail, bone length) ===")
for b in bones:
    h, t = jpos(b.name), jpos(b.name, True)
    print(f" {b.name:12s} head=({h[0]:+.3f},{h[1]:+.3f},{h[2]:+.3f}) "
          f"tail=({t[0]:+.3f},{t[1]:+.3f},{t[2]:+.3f}) len={np.linalg.norm(t-h):.3f} "
          f"parent={b.parent.name if b.parent else '-'} use_deform={b.use_deform}")


def seg(a, b):
    return float(np.linalg.norm(jpos(b) - jpos(a)))


print("\n--- joint-to-joint segment lengths + L/R asymmetry ---")
SEGDEF = [
    ("clavicle (Clav head->UpperArm head)", "Clavicle_{s}", "UpperArm_{s}"),
    ("upper arm (shoulder->elbow)", "UpperArm_{s}", "Forearm_{s}"),
    ("forearm (elbow->wrist)", "Forearm_{s}", "Hand_{s}"),
    ("thigh (hip->knee)", "UpperLeg_{s}", "LowerLeg_{s}"),
    ("shin (knee->ankle)", "LowerLeg_{s}", "Foot_{s}"),
]
for label, a, b in SEGDEF:
    lr = seg(a.format(s="L"), b.format(s="L"))
    rr = seg(a.format(s="R"), b.format(s="R"))
    asym = abs(lr - rr) / max(lr, rr) * 100.0
    print(f" {label:38s} L={lr:.3f} R={rr:.3f} asym={asym:.1f}%")
    if asym > 12.0:
        FLAGS.append(f"SEGMENT ASYMMETRY {asym:.1f}% > 12%: {label} (L={lr:.3f} vs R={rr:.3f})")

for side in ("L", "R"):
    ua = seg(f"UpperArm_{side}", f"Forearm_{side}")
    fa = seg(f"Forearm_{side}", f"Hand_{side}")
    th = seg(f"UpperLeg_{side}", f"LowerLeg_{side}")
    sh = seg(f"LowerLeg_{side}", f"Foot_{side}")
    print(f" ratios {side}: forearm/upperarm={fa/ua:.2f}  shin/thigh={sh/th:.2f}  "
          f"(typical human ~0.80-0.95 / ~0.85-1.0; stylized assets vary, L-vs-R consistency matters most)")
    bend_e = 180.0 - math.degrees(math.acos(np.clip(
        np.dot((jpos(f'UpperArm_{side}') - jpos(f'Forearm_{side}')) /
               np.linalg.norm(jpos(f'UpperArm_{side}') - jpos(f'Forearm_{side}')),
               (jpos(f'Hand_{side}') - jpos(f'Forearm_{side}')) /
               np.linalg.norm(jpos(f'Hand_{side}') - jpos(f'Forearm_{side}'))), -1, 1)))
    bend_k = 180.0 - math.degrees(math.acos(np.clip(
        np.dot((jpos(f'UpperLeg_{side}') - jpos(f'LowerLeg_{side}')) /
               np.linalg.norm(jpos(f'UpperLeg_{side}') - jpos(f'LowerLeg_{side}')),
               (jpos(f'Foot_{side}') - jpos(f'LowerLeg_{side}')) /
               np.linalg.norm(jpos(f'Foot_{side}') - jpos(f'LowerLeg_{side}'))), -1, 1)))
    print(f" rest bend {side}: elbow={bend_e:.1f} deg from straight, knee={bend_k:.1f} deg from straight")

# ---------------------------------------------------------------- pivot in local mesh volume
print("\n=== 2. PIVOT vs LOCAL MESH CENTROID (sphere around joint) ===")
JOINTS = [
    ("shoulder", "UpperArm_{s}", ["Clavicle_{s}", "UpperArm_{s}", "UpperChest", "Chest"], 0.050),
    ("elbow", "Forearm_{s}", ["UpperArm_{s}", "Forearm_{s}"], 0.038),
    ("wrist", "Hand_{s}", ["Forearm_{s}", "Hand_{s}"], 0.034),
    ("hip", "UpperLeg_{s}", ["Hips", "UpperLeg_{s}"], 0.055),
    ("knee", "LowerLeg_{s}", ["UpperLeg_{s}", "LowerLeg_{s}"], 0.042),
    ("ankle", "Foot_{s}", ["LowerLeg_{s}", "Foot_{s}"], 0.038),
]
for label, jb, adj, radius in JOINTS:
    for side in ("L", "R"):
        J = jpos(jb.format(s=side))
        d = np.linalg.norm(P0 - J, axis=1)
        sphere = d <= radius
        adj_idx = [gidx[a.format(s=side)] for a in adj if a.format(s=side) in gidx]
        adj_mask = sphere & np.isin(DOM, adj_idx)
        for tag, m in (("all", sphere), ("adj-dom", adj_mask)):
            if m.sum() < 30:
                print(f" {label}_{side} {tag}: too few verts ({int(m.sum())})")
                continue
            cen = P0[m].mean(axis=0)
            off = J - cen
            rms = float(np.sqrt(((P0[m] - cen) ** 2).sum(axis=1).mean()))
            print(f" {label}_{side} {tag:7s} n={int(m.sum()):5d} centroid=({cen[0]:+.3f},{cen[1]:+.3f},{cen[2]:+.3f}) "
                  f"pivot-centroid=({off[0]:+.3f},{off[1]:+.3f},{off[2]:+.3f}) |off|={np.linalg.norm(off)*1000:.1f}mm rms_r={rms*1000:.1f}mm")
            if tag == "adj-dom" and np.linalg.norm(off) > 0.45 * rms and np.linalg.norm(off) > 0.012:
                FLAGS.append(f"PIVOT OFFSET {label}_{side}: {np.linalg.norm(off)*1000:.1f}mm from adjacent-dominant centroid (rms radius {rms*1000:.1f}mm)")

# neck pivot
J = jpos("Neck")
d = np.linalg.norm(P0 - J, axis=1)
m = (d <= 0.045) & np.isin(DOM, [gidx["UpperChest"], gidx["Neck"], gidx["Head"]])
cen = P0[m].mean(axis=0)
print(f" neck     adj-dom n={int(m.sum()):5d} centroid=({cen[0]:+.3f},{cen[1]:+.3f},{cen[2]:+.3f}) "
      f"|off|={np.linalg.norm(J-cen)*1000:.1f}mm")

# ---------------------------------------------------------------- weight profiles across joints


def seg_proj(Pts, A, B):
    AB = B - A
    L = float(np.linalg.norm(AB))
    t = np.clip(((Pts - A) @ AB) / (L * L), 0.0, 1.0)
    proj = A + t[:, None] * AB
    return t * L, np.linalg.norm(Pts - proj, axis=1), L


def profile(name, p_bone, j_bone, d_pos, prox_bones, dist_bones, radius):
    P, J, D = jpos(p_bone), jpos(j_bone), d_pos
    along_p, d_p, len_p = seg_proj(P0, P, J)
    along_d, d_d, len_d = seg_proj(P0, J, D)
    s = np.where(d_d < d_p, along_d, along_p - len_p)
    dmin = np.minimum(d_p, d_d)
    mask = (dmin <= radius) & (s >= -0.07) & (s <= len_d + 0.02)
    prox_w = W[:, [gidx[b] for b in prox_bones]].sum(axis=1)
    dist_w = W[:, [gidx[b] for b in dist_bones]].sum(axis=1)
    print(f"\n--- PROFILE {name}: joint at s=0, distal segment length={len_d:.3f}, radius={radius} ---")
    print("    s_center   n    proxW  distW   (prox=" + "+".join(prox_bones) + " dist=" + "+".join(dist_bones) + ")")
    crossover = None
    first25 = None
    first75 = None
    edges = np.arange(-0.07, len_d + 0.021, 0.01)
    for i in range(len(edges) - 1):
        lo, hi = edges[i], edges[i + 1]
        sel = mask & (s >= lo) & (s < hi)
        cnt = int(sel.sum())
        if cnt < 15:
            continue
        cen = 0.5 * (lo + hi)
        pw, dw = float(prox_w[sel].mean()), float(dist_w[sel].mean())
        print(f"    {cen:+.3f}  {cnt:5d}  {pw:.3f}  {dw:.3f}")
        if cen >= 0:
            if crossover is None and dw >= 0.5:
                crossover = cen
            if first25 is None and dw >= 0.25:
                first25 = cen
            if first75 is None and dw >= 0.75:
                first75 = cen
    width = (first75 - first25) if (first25 is not None and first75 is not None) else None
    print(f"  => crossover(dist>=0.5) at s={crossover if crossover is None else round(crossover,3)} "
          f"({('%.0f%% of distal segment' % (100*crossover/len_d)) if crossover is not None else 'never'}), "
          f"blend width 0.25->0.75 = {width if width is None else round(width,3)} "
          f"({('%.0f%%' % (100*width/len_d)) if width is not None else '-'})")
    if crossover is not None and crossover > 0.015:
        FLAGS.append(f"PROFILE {name}: distal-weight crossover {crossover*1000:.0f}mm PAST the joint into the distal segment")
    if width is not None and width > 0.40 * len_d:
        FLAGS.append(f"PROFILE {name}: blend width {width:.3f} = {100*width/len_d:.0f}% of distal segment (long soft zone)")
    return {"s": s, "mask": mask, "len_d": len_d, "J": J}


print("\n=== 3. WEIGHT PROFILES ACROSS JOINTS ===")
prof = {}
for side in ("R", "L"):
    prof[f"elbow_{side}"] = profile(f"elbow_{side}", f"UpperArm_{side}", f"Forearm_{side}", jpos(f"Hand_{side}"),
                                    [f"UpperArm_{side}"], [f"Forearm_{side}"], 0.043)
    prof[f"knee_{side}"] = profile(f"knee_{side}", f"UpperLeg_{side}", f"LowerLeg_{side}", jpos(f"Foot_{side}"),
                                   [f"UpperLeg_{side}"], [f"LowerLeg_{side}"], 0.05)
    prof[f"shoulder_{side}"] = profile(f"shoulder_{side}", f"Clavicle_{side}", f"UpperArm_{side}", jpos(f"Forearm_{side}"),
                                       ["Chest", "UpperChest", f"Clavicle_{side}"], [f"UpperArm_{side}"], 0.055)
    prof[f"hip_{side}"] = profile(f"hip_{side}", "Hips", f"UpperLeg_{side}", jpos(f"LowerLeg_{side}"),
                                  ["Hips", "Spine"], [f"UpperLeg_{side}"], 0.06)
    prof[f"wrist_{side}"] = profile(f"wrist_{side}", f"Forearm_{side}", f"Hand_{side}", jpos(f"Hand_{side}", True),
                                    [f"Forearm_{side}"], [f"Hand_{side}"], 0.04)
    prof[f"ankle_{side}"] = profile(f"ankle_{side}", f"LowerLeg_{side}", f"Foot_{side}", jpos(f"Toe_{side}", True),
                                    [f"LowerLeg_{side}"], [f"Foot_{side}"], 0.045)
prof["neckbase"] = profile("neck_base", "UpperChest", "Neck", jpos("Head"),
                           ["Chest", "UpperChest"], ["Neck"], 0.045)
prof["headbase"] = profile("head_base", "Neck", "Head", jpos("Head", True),
                           ["Neck"], ["Head"], 0.05)

# spine field by height
print("\n--- spine-chain weight field by rest height (central trunk |x|<0.16, |y|<0.12) ---")
trunk = (np.abs(P0[:, 0]) < 0.16) & (np.abs(P0[:, 1]) < 0.12) & (P0[:, 2] > 0.40) & (P0[:, 2] < 0.90)
ARM_BONES = [gidx[b] for b in ("Clavicle_R", "UpperArm_R", "Forearm_R", "Hand_R", "Clavicle_L", "UpperArm_L", "Forearm_L", "Hand_L")]
LEG_BONES = [gidx[b] for b in ("UpperLeg_R", "LowerLeg_R", "Foot_R", "Toe_R", "UpperLeg_L", "LowerLeg_L", "Foot_L", "Toe_L")]
for zlo in np.arange(0.42, 0.90, 0.03):
    sel = trunk & (P0[:, 2] >= zlo) & (P0[:, 2] < zlo + 0.03)
    if sel.sum() < 20:
        continue
    vals = {b: float(W[sel, gidx[b]].mean()) for b in ("Hips", "Spine", "Chest", "UpperChest", "Neck", "Head")}
    print(f" z {zlo:.2f}-{zlo+0.03:.2f} n={int(sel.sum()):5d} " +
          " ".join(f"{k}={v:.2f}" for k, v in vals.items()) +
          f"  armTot={float(W[sel][:, ARM_BONES].sum(axis=1).mean()):.3f} legTot={float(W[sel][:, LEG_BONES].sum(axis=1).mean()):.3f}")

# ---------------------------------------------------------------- region leakage
print("\n=== 4. REGION WEIGHT LEAKAGE (rest-geometry masks) ===")


def region(name, mask):
    arm_tot = W[mask][:, ARM_BONES].sum(axis=1)
    leg_tot = W[mask][:, LEG_BONES].sum(axis=1)
    dom_names, counts = np.unique(DOM[mask], return_counts=True)
    top = sorted(zip(counts, [gnames[i] for i in dom_names]), reverse=True)[:6]
    print(f" {name}: n={int(mask.sum())} armW mean={arm_tot.mean():.4f} max={arm_tot.max():.3f} "
          f"cnt>0.05={int((arm_tot>0.05).sum())} >0.25={int((arm_tot>0.25).sum())} >0.5={int((arm_tot>0.5).sum())} | "
          f"legW mean={leg_tot.mean():.4f} cnt>0.25={int((leg_tot>0.25).sum())} | dominant: " +
          ", ".join(f"{nm}:{c}" for c, nm in top))
    return arm_tot


waist_center = (np.abs(P0[:, 0]) < 0.13) & (np.abs(P0[:, 1]) < 0.11) & (P0[:, 2] > 0.50) & (P0[:, 2] < 0.64)
waist_wide = (np.abs(P0[:, 0]) < 0.20) & (np.abs(P0[:, 1]) < 0.14) & (P0[:, 2] > 0.50) & (P0[:, 2] < 0.64)
chest_center = (np.abs(P0[:, 0]) < 0.11) & (np.abs(P0[:, 1]) < 0.12) & (P0[:, 2] > 0.66) & (P0[:, 2] < 0.82)
pelvis_center = (np.abs(P0[:, 0]) < 0.13) & (np.abs(P0[:, 1]) < 0.11) & (P0[:, 2] > 0.43) & (P0[:, 2] < 0.53)
aw = region("waist_center", waist_center)
region("waist_wide", waist_wide)
region("chest_center", chest_center)
region("pelvis_center", pelvis_center)
if float(aw.mean()) > 0.03 or int((aw > 0.25).sum()) > 100:
    FLAGS.append(f"WAIST LEAK: central waist arm weight mean={aw.mean():.4f}, verts>0.25={int((aw>0.25).sum())}")

# dominant-bone bounding boxes for arm bones (where do arm-driven verts actually live?)
print("\n--- dominant-vertex extents per arm bone (rest) ---")
for b in ("Clavicle_R", "UpperArm_R", "Forearm_R", "Hand_R", "Clavicle_L", "UpperArm_L", "Forearm_L", "Hand_L"):
    m = DOM == gidx[b]
    if m.sum() == 0:
        print(f" {b:12s} dominant verts = 0")
        continue
    q = P0[m]
    print(f" {b:12s} n={int(m.sum()):6d} x[{q[:,0].min():+.3f},{q[:,0].max():+.3f}] "
          f"y[{q[:,1].min():+.3f},{q[:,1].max():+.3f}] z[{q[:,2].min():+.3f},{q[:,2].max():+.3f}]")

# ---------------------------------------------------------------- isolated rotations
print("\n=== 5. ISOLATED JOINT ROTATIONS (evaluated mesh, no save) ===")
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
    bpy.context.view_layer.update()
    dg = bpy.context.evaluated_depsgraph_get()
    eo = body.evaluated_get(dg)
    em = eo.to_mesh()
    p = np.empty(n * 3, dtype=np.float64)
    em.vertices.foreach_get("co", p)
    eo.to_mesh_clear()
    return to_world(np.array(eo.matrix_world), p.reshape(-1, 3))


reset_pose()
BASE = eval_coords()
base_dev = float(np.abs(BASE - P0).max())
print(f" baseline evaluated-vs-rest max deviation = {base_dev*1000:.2f} mm")


def disp_stats(tag, P, mask):
    d = np.linalg.norm(P[mask] - BASE[mask], axis=1) if mask.sum() else np.zeros(1)
    print(f"   {tag:28s} n={int(mask.sum()):6d} disp mean={d.mean()*1000:7.2f}mm p95={np.percentile(d,95)*1000:7.2f}mm max={d.max()*1000:7.2f}mm")
    return d


def hinge_ratio(test_name, prof_key, P, deg):
    pr = prof[prof_key]
    s, mask, J, len_d = pr["s"], pr["mask"], pr["J"], pr["len_d"]
    r = np.linalg.norm(BASE - J, axis=1)
    expected = 2.0 * math.sin(math.radians(abs(deg)) / 2.0) * r
    actual = np.linalg.norm(P - BASE, axis=1)
    print(f"   hinge ratio along distal segment ({test_name}); 1.0 = rigid rotation about the pivot:")
    fb = None
    for lo in np.arange(0.0, 0.91, 0.1):
        sel = mask & (s >= lo * len_d) & (s < (lo + 0.1) * len_d) & (expected > 0.004)
        if sel.sum() < 15:
            continue
        ratio = float(np.median(actual[sel] / expected[sel]))
        print(f"     s/len {lo:.1f}-{lo+0.1:.1f} n={int(sel.sum()):5d} median actual/expected = {ratio:.3f}")
        if fb is None and ratio >= 0.9:
            fb = lo
    if fb is not None and fb > 0.3:
        FLAGS.append(f"HINGE {test_name}: distal segment only reaches rigid-hinge motion at ~{fb*100:.0f}% of segment length (bend spread into segment)")
    return fb


TESTS = [
    ("ELBOW_R flex -55X", "Forearm_R", (1, 0, 0), -55, "elbow_R"),
    ("ELBOW_L flex -55X", "Forearm_L", (1, 0, 0), -55, "elbow_L"),
    ("KNEE_R flex +55X", "LowerLeg_R", (1, 0, 0), 55, "knee_R"),
    ("KNEE_L flex +55X", "LowerLeg_L", (1, 0, 0), 55, "knee_L"),
    ("SHOULDER_R raise fwd -60X", "UpperArm_R", (1, 0, 0), -60, None),
    ("SHOULDER_L raise fwd -60X", "UpperArm_L", (1, 0, 0), -60, None),
    ("HIP_R flex -45X", "UpperLeg_R", (1, 0, 0), -45, None),
    ("NECK yaw +25Z", "Neck", (0, 0, 1), 25, None),
]
for tname, bone, axis, deg, pkey in TESTS:
    reset_pose()
    rot_world(bone, axis, deg)
    P = eval_coords()
    print(f" TEST {tname}:")
    if pkey:
        hinge_ratio(tname, pkey, P, deg)
    if "ELBOW" in tname or "SHOULDER" in tname:
        dw = disp_stats("central waist", P, waist_center)
        if float(np.percentile(dw, 95)) > 0.003 or float(dw.max()) > 0.01:
            FLAGS.append(f"WAIST MOVES under {tname}: waist disp p95={np.percentile(dw,95)*1000:.2f}mm max={dw.max()*1000:.2f}mm")
        disp_stats("central chest", P, chest_center)
    if "HIP" in tname:
        disp_stats("central pelvis", P, pelvis_center)
    if "NECK" in tname:
        head_mask = DOM == gidx["Head"]
        disp_stats("head-dominant verts", P, head_mask)
        disp_stats("central chest", P, chest_center)

reset_pose()
print("\n=== AUDIT FLAGS (thresholds are heuristics; profiles above are the evidence) ===")
if FLAGS:
    for f in FLAGS:
        print(" FLAG:", f)
else:
    print(" (none)")
print("DONE (read-only, blend not saved)")
