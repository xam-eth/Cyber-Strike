"""Structural Hand_L re-rig with exact world-deformation preservation.

Owner approved (2026-10-30) after scripts 57-59 proved the old Hand_L
segment passes through the thigh while the glove is elsewhere.

Chosen rest geometry (scripts 58/59):
- new wrist head = (0.2441, -0.0118, 0.4961) in world/armature space:
  cross-section centre at profile s=0.118, forearm length 0.1192
  (right control: 0.1193), 4 mm proximal to the first glove island;
- new tail = head + normalized(glove_centroid-head) * 0.056, ending
  around the fingertips and pointing through the glove centroid.

Animation conversion:
Script 58 proved D_HandL == D_ForearmL in every shipped action/frame
(Hand_L local basis is identity throughout), where
D = pose_matrix @ inverse(rest_matrix). After moving the rest bones,
this script keys Forearm_L at every integer frame to
P' = D_old @ Rest'_ForearmL and keys Hand_L identity. That preserves
the same deformation matrix, so the actual glove/world trajectory and
weapon grip stay unchanged while the new wrist can articulate in
future clips. Wrist weights only redistribute each vertex's existing
Forearm_L+Hand_L total (all other groups untouched), which is also
trajectory-neutral under the same D equality.

The blend is saved ONLY if DO_SAVE and every gate passes. Trial mode
renders rest/flex/aim checks from the in-memory result.
"""
import math
import os

import bpy
import numpy as np
from mathutils import Matrix, Quaternion, Vector

PROJ = "/home/user/Cyber-Strike/EXOCOMFLICT_HERO01"
BLEND = f"{PROJ}/blender/HERO_01_working.blend"
OUT = f"{PROJ}/screenshots/rig"
DO_SAVE = True

NEW_HEAD_WORLD = Vector((0.2441, -0.0118, 0.4961))
HAND_LEN = 0.056
ORDER = ["Root", "Hips", "Spine", "Chest", "UpperChest", "Neck", "Head",
         "Clavicle_R", "UpperArm_R", "Forearm_R", "Hand_R", "Weapon_R",
         "Clavicle_L", "UpperArm_L", "Forearm_L", "Hand_L",
         "UpperLeg_R", "LowerLeg_R", "Foot_R", "Toe_R",
         "UpperLeg_L", "LowerLeg_L", "Foot_L", "Toe_L"]
EXPECTED_ACTIONS = ["Aim_Idle", "Fire", "Idle", "Weapon_Lower", "Weapon_Raise", "Weapon_Raise_To_Aim"]
GLOVE_IDS = [52, 19, 2, 26, 156]
SHELL_IDS = [53, 72]

bpy.ops.wm.open_mainfile(filepath=BLEND)
sc = bpy.context.scene
arm = bpy.data.objects["HERO_01_Armature"]
body = bpy.data.objects["HERO_01_BODY"]
weapon = bpy.data.objects["HERO_01_WEAPON"]
if arm.animation_data is None:
    arm.animation_data_create()
ad = arm.animation_data
for pb in arm.pose.bones:
    pb.rotation_mode = 'QUATERNION'

PASS = 0
FAIL = 0


def gate(name, cond, detail=""):
    global PASS, FAIL
    if cond:
        PASS += 1
        print(f"PASS {name} {detail}")
    else:
        FAIL += 1
        print(f"FAIL {name} {detail}")
    return cond


def set_action(name):
    if name is None:
        ad.action = None
        return None
    act = bpy.data.actions[name]
    ad.action = act
    try:
        if len(act.slots) == 0:
            act.slots.new(id_type='OBJECT', name=arm.name)
        ad.action_slot = act.slots[0]
    except Exception as ex:
        print("slot setup", ex)
    return act


def action_fcurves(act):
    fc = []
    try:
        for layer in act.layers:
            for strip in layer.strips:
                cb = getattr(strip, "channelbag", None)
                if cb is not None and hasattr(cb, "fcurves"):
                    fc += list(cb.fcurves)
    except Exception:
        pass
    if not fc:
        try:
            fc = list(act.fcurves)
        except Exception:
            pass
    return fc


def jpos(name, tail=False):
    b = arm.data.bones[name]
    return arm.matrix_world @ (b.tail_local if tail else b.head_local)


def deform(pb):
    return pb.matrix @ pb.bone.matrix_local.inverted()


def mat_diff(a, b):
    rel = a @ b.inverted()
    trans = float(rel.to_translation().length)
    q = rel.to_3x3().to_quaternion()
    rot = math.degrees(2 * math.acos(min(1.0, abs(float(q.w)))))
    return trans, rot


def evaluated_coords():
    dg = bpy.context.evaluated_depsgraph_get()
    eo = body.evaluated_get(dg)
    em = eo.to_mesh()
    p = np.empty(n * 3, dtype=np.float64)
    em.vertices.foreach_get("co", p)
    eo.to_mesh_clear()
    emw = np.array(eo.matrix_world, dtype=np.float64)
    return p.reshape(-1, 3) @ emw[:3, :3].T + emw[:3, 3]


def reset_pose():
    set_action(None)
    for pb in arm.pose.bones:
        pb.location = (0, 0, 0)
        pb.rotation_quaternion = (1, 0, 0, 0)
        pb.rotation_euler = (0, 0, 0)
        pb.scale = (1, 1, 1)
    bpy.context.view_layer.update()


# ---------------------------------------------------------------------------
# Load mesh/weights/islands and assert the audited identities.
# ---------------------------------------------------------------------------
n = len(body.data.vertices)
mw = np.array(body.matrix_world, dtype=np.float64)
co = np.empty(n * 3, dtype=np.float64)
body.data.vertices.foreach_get("co", co)
P0 = co.reshape(-1, 3) @ mw[:3, :3].T + mw[:3, 3]
gnames = [g.name for g in body.vertex_groups]
gidx = {name: i for i, name in enumerate(gnames)}
W0 = np.zeros((n, len(gnames)), dtype=np.float64)
for v in body.data.vertices:
    for ge in v.groups:
        W0[v.index, ge.group] = ge.weight

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
cnt = np.bincount(ISL).astype(np.float64)
icen = np.stack([np.bincount(ISL, weights=P0[:, k]) / cnt for k in range(3)], axis=1)
for iid in SHELL_IDS + GLOVE_IDS:
    gate(f"island {iid} identity", icen[iid, 0] > 0.13 and 0.40 < icen[iid, 2] < 0.65,
         f"cen={np.round(icen[iid],3)} n={int(cnt[iid])}")

glove_mask = np.isin(ISL, GLOVE_IDS)
shell_mask = np.isin(ISL, SHELL_IDS)
combined_mask = glove_mask | shell_mask
subset_ids = np.flatnonzero(combined_mask)
glove_c = P0[glove_mask].mean(axis=0)
new_head_np = np.array(NEW_HEAD_WORLD, dtype=np.float64)
tail_dir = glove_c - new_head_np
tail_dir /= np.linalg.norm(tail_dir)
new_tail_np = new_head_np + tail_dir * HAND_LEN
NEW_TAIL_WORLD = Vector(new_tail_np)
print("glove centroid", np.round(glove_c, 4), "new head", np.round(new_head_np, 4), "new tail", np.round(new_tail_np, 4))
print("armature matrix_world:\n", np.round(np.array(arm.matrix_world), 4))

old_head = jpos("Hand_L")
old_tail = jpos("Hand_L", True)
elbow = jpos("Forearm_L")
gate("old Hand_L head asserted", float((old_head - Vector((0.190, -0.015, 0.410))).length) < 0.002, f"{tuple(np.round(old_head,3))}")
gate("old Hand_L tail asserted", float((old_tail - Vector((0.200, -0.020, 0.340))).length) < 0.002, f"{tuple(np.round(old_tail,3))}")
old_rest = {name: arm.data.bones[name].matrix_local.copy() for name in ORDER}
old_lengths = {name: float(arm.data.bones[name].length) for name in ORDER}

actions_now = sorted(a.name for a in bpy.data.actions)
gate("six expected actions", actions_now == EXPECTED_ACTIONS, f"{actions_now}")

# ---------------------------------------------------------------------------
# Pre-record old deformation trajectories and evaluated glove-zone geometry.
# ---------------------------------------------------------------------------
FG0 = Vector((-0.215, -0.062, 0.315))
old_Dfore = {}
old_D_samples = {}
old_subset_samples = {}
old_glove_samples = {}
sample_frames = {}
pre_max_d_trans = 0.0
pre_max_d_rot = 0.0
pre_max_hand_loc = 0.0
pre_max_hand_qdev = 0.0
for aname in EXPECTED_ACTIONS:
    act = set_action(aname)
    lo, hi = [int(round(x)) for x in act.frame_range]
    frames = list(range(lo, hi + 1))
    samples = sorted(set([lo, lo + (hi - lo) // 3, lo + 2 * (hi - lo) // 3, hi]))
    if aname == "Weapon_Raise_To_Aim":
        samples = sorted(set(samples + [24, 36]))
    if aname == "Fire":
        samples = sorted(set(samples + [2]))
    sample_frames[aname] = samples
    old_Dfore[aname] = {}
    old_D_samples[aname] = {}
    old_subset_samples[aname] = {}
    old_glove_samples[aname] = {}
    for f in frames:
        sc.frame_set(f)
        bpy.context.view_layer.update()
        pf = arm.pose.bones["Forearm_L"]
        ph = arm.pose.bones["Hand_L"]
        Df = deform(pf)
        Dh = deform(ph)
        old_Dfore[aname][f] = Df.copy()
        tr, ro = mat_diff(Dh, Df)
        pre_max_d_trans = max(pre_max_d_trans, tr)
        pre_max_d_rot = max(pre_max_d_rot, ro)
        pre_max_hand_loc = max(pre_max_hand_loc, float(ph.location.length))
        pre_max_hand_qdev = max(pre_max_hand_qdev, 1.0 - min(1.0, abs(float(ph.rotation_quaternion.w))))
        if f in samples:
            old_D_samples[aname][f] = {bname: deform(arm.pose.bones[bname]).copy() for bname in ORDER}
            P = evaluated_coords()
            old_subset_samples[aname][f] = P[subset_ids].copy()
            fg = np.array(weapon.matrix_world @ FG0, dtype=np.float64)
            old_glove_samples[aname][f] = (P[glove_mask].mean(axis=0), fg)
    print(f"PRE {aname}: frames {lo}-{hi}, samples {samples}")
gate("pre D_HandL == D_ForearmL all actions/frames", pre_max_d_trans < 1e-6 and pre_max_d_rot < 1e-4,
     f"max trans={pre_max_d_trans*1000:.4f}mm rot={pre_max_d_rot:.5f}deg")
gate("pre Hand_L local basis identity", pre_max_hand_loc < 1e-7 and pre_max_hand_qdev < 1e-10,
     f"loc={pre_max_hand_loc:.2e} qdev={pre_max_hand_qdev:.2e}")

# ---------------------------------------------------------------------------
# Move only Forearm_L tail / Hand_L head+tail in the rest skeleton.
# ---------------------------------------------------------------------------
reset_pose()
sc.frame_set(0)
inv_arm_mw = arm.matrix_world.inverted()
new_head_local = inv_arm_mw @ NEW_HEAD_WORLD
new_tail_local = inv_arm_mw @ NEW_TAIL_WORLD
bpy.context.view_layer.objects.active = arm
arm.select_set(True)
bpy.ops.object.mode_set(mode='EDIT')
eb_fore = arm.data.edit_bones["Forearm_L"]
eb_hand = arm.data.edit_bones["Hand_L"]
print("EDIT before Forearm_L", tuple(np.round(eb_fore.head, 4)), tuple(np.round(eb_fore.tail, 4)), "roll", float(eb_fore.roll))
print("EDIT before Hand_L", tuple(np.round(eb_hand.head, 4)), tuple(np.round(eb_hand.tail, 4)), "roll", float(eb_hand.roll))
eb_fore.tail = new_head_local
eb_hand.head = new_head_local
eb_hand.tail = new_tail_local
eb_fore.roll = 0.0
eb_hand.roll = 0.0
print("EDIT after Forearm_L", tuple(np.round(eb_fore.head, 4)), tuple(np.round(eb_fore.tail, 4)), "len", float(eb_fore.length))
print("EDIT after Hand_L", tuple(np.round(eb_hand.head, 4)), tuple(np.round(eb_hand.tail, 4)), "len", float(eb_hand.length))
bpy.ops.object.mode_set(mode='POSE')
reset_pose()
new_rest = {name: arm.data.bones[name].matrix_local.copy() for name in ORDER}
new_lengths = {name: float(arm.data.bones[name].length) for name in ORDER}
new_head_actual = jpos("Hand_L")
new_tail_actual = jpos("Hand_L", True)
gate("new Hand_L head exact", float((new_head_actual - NEW_HEAD_WORLD).length) < 0.0002, f"{tuple(np.round(new_head_actual,4))}")
gate("new Hand_L tail exact", float((new_tail_actual - NEW_TAIL_WORLD).length) < 0.0002, f"{tuple(np.round(new_tail_actual,4))}")
gate("new forearm length near right control", abs(new_lengths["Forearm_L"] - new_lengths["Forearm_R"]) < 0.004,
     f"L={new_lengths['Forearm_L']:.4f} R={new_lengths['Forearm_R']:.4f}")
gate("new hand length", abs(new_lengths["Hand_L"] - HAND_LEN) < 0.0005, f"{new_lengths['Hand_L']:.4f}")
max_other_rest = 0.0
for bname in ORDER:
    if bname in ("Forearm_L", "Hand_L"):
        continue
    d = float(np.abs(np.array(new_rest[bname]) - np.array(old_rest[bname])).max())
    max_other_rest = max(max_other_rest, d)
gate("all other rest bones unchanged", max_other_rest < 1e-7, f"max matrix delta={max_other_rest:.2e}")

# ---------------------------------------------------------------------------
# Wrist weights: split only existing Forearm_L+Hand_L totals.
# ---------------------------------------------------------------------------
EL_np = np.array(elbow, dtype=np.float64)
axis = glove_c - EL_np
axis /= np.linalg.norm(axis)
rel_head = P0 - new_head_np
s_rel = rel_head @ axis
d_axis = np.sqrt(np.maximum(np.einsum('ij,ij->i', rel_head, rel_head) - s_rel * s_rel, 0.0))
fa = gidx["Forearm_L"]
ha = gidx["Hand_L"]
ua = gidx["UpperArm_L"]
ca = gidx["Clavicle_L"]
fh_total = W0[:, fa] + W0[:, ha]
arm_total = fh_total + W0[:, ua] + W0[:, ca]
zone = (fh_total > 0.001) & (arm_total > 0.95) & (d_axis <= 0.070) & (s_rel >= -0.055) & (s_rel <= 0.085)
t = np.clip((s_rel[zone] + 0.010) / 0.020, 0.0, 1.0)
f_hand = t * t * (3.0 - 2.0 * t)
new_hand = fh_total[zone] * f_hand
new_fore = fh_total[zone] * (1.0 - f_hand)
changed_ids = np.flatnonzero(zone)[(np.abs(new_hand - W0[zone, ha]) > 1e-7) | (np.abs(new_fore - W0[zone, fa]) > 1e-7)]
print(f"WRIST WEIGHTS zone={int(zone.sum())} changed={len(changed_ids)}")
vg_fore = body.vertex_groups["Forearm_L"]
vg_hand = body.vertex_groups["Hand_L"]
zone_index = {int(v): i for i, v in enumerate(np.flatnonzero(zone))}
for vid in changed_ids:
    zi = zone_index[int(vid)]
    vg_fore.remove([int(vid)])
    vg_hand.remove([int(vid)])
    if new_fore[zi] > 1e-6:
        vg_fore.add([int(vid)], float(new_fore[zi]), 'REPLACE')
    if new_hand[zi] > 1e-6:
        vg_hand.add([int(vid)], float(new_hand[zi]), 'REPLACE')

Wp = np.zeros_like(W0)
for v in body.data.vertices:
    for ge in v.groups:
        Wp[v.index, ge.group] = ge.weight
sums = Wp.sum(axis=1)
max_infl = int((Wp > 1e-6).sum(axis=1).max())
other_max_delta = 0.0
for gi, gname in enumerate(gnames):
    if gname not in ("Forearm_L", "Hand_L"):
        other_max_delta = max(other_max_delta, float(np.abs(Wp[:, gi] - W0[:, gi]).max()))
gate("weight sums preserved", float(np.abs(sums - 1).max()) < 2e-4, f"max dev={np.abs(sums-1).max():.2e}")
gate("max influences <=4", max_infl <= 4, f"max={max_infl}")
gate("non-Forearm/Hand weights untouched", other_max_delta < 1e-7, f"max delta={other_max_delta:.2e}")
DOM = np.argmax(Wp, axis=1)
hand_dom = int((DOM == ha).sum())
gate("Hand_L dominant verts >500", hand_dom > 500, f"count={hand_dom} (was 0)")
for iid in GLOVE_IDS:
    m = ISL == iid
    print(f" glove isl={iid}: Forearm avg={Wp[m,fa].mean():.3f} Hand avg={Wp[m,ha].mean():.3f} HandDom={int((DOM[m]==ha).sum())}/{int(m.sum())}")
gate("glove islands Hand avg >0.55", float(Wp[glove_mask, ha].mean()) > 0.55,
     f"avg Hand={Wp[glove_mask,ha].mean():.3f} Forearm={Wp[glove_mask,fa].mean():.3f}")

# Independent profile along the new two-segment polyline E->W->T.
def seg_project(Pts, A, B):
    AB = B - A
    denom = float(AB @ AB)
    tt = np.clip(((Pts - A) @ AB) / denom, 0.0, 1.0)
    pr = A + tt[:, None] * AB
    return np.linalg.norm(Pts - pr, axis=1), tt * math.sqrt(denom)

d1, s1 = seg_project(P0, EL_np, new_head_np)
d2, s2 = seg_project(P0, new_head_np, new_tail_np)
use2 = d2 < d1
s_poly = np.where(use2, s2, s1 - float(np.linalg.norm(new_head_np - EL_np)))
d_poly = np.where(use2, d2, d1)
sel = (d_poly <= 0.040) & (arm_total > 0.95) & (fh_total > 0.05) & (s_poly >= -0.06) & (s_poly <= 0.07)
bins = []
for lo in np.arange(-0.060, 0.070, 0.005):
    m = sel & (s_poly >= lo) & (s_poly < lo + 0.005)
    if int(m.sum()) >= 20:
        bins.append((float(lo + 0.0025), float(Wp[m, fa].mean()), float(Wp[m, ha].mean()), int(m.sum())))
for b in bins:
    print(f" wrist profile s={b[0]:+.3f} Fore={b[1]:.3f} Hand={b[2]:.3f} n={b[3]}")
cross = None
for (s1b, f1b, h1b, _), (s2b, f2b, h2b, _) in zip(bins, bins[1:]):
    r1 = h1b / max(f1b + h1b, 1e-9)
    r2 = h2b / max(f2b + h2b, 1e-9)
    if r1 < 0.5 <= r2:
        cross = s1b + (0.5 - r1) * (s2b - s1b) / max(r2 - r1, 1e-9)
        break
ratios = [(s, h / max(f + h, 1e-9)) for s, f, h, _ in bins]
s25 = next((s for s, r in ratios if r >= 0.25), None)
s75 = next((s for s, r in ratios if r >= 0.75), None)
width = (s75 - s25) if s25 is not None and s75 is not None else 9
gate("new wrist crossover within 10mm", cross is not None and abs(cross) <= 0.010, f"crossover={cross}")
gate("new wrist blend width <=30mm", width <= 0.030, f"width={width:.3f} s25={s25} s75={s75}")

# F0 must be exact after edit bones + weights.
reset_pose()
sc.frame_set(0)
P_rest = evaluated_coords()
f0_max = float(np.linalg.norm(P_rest - P0, axis=1).max())
gate("F0 displacement == 0", f0_max < 0.00001, f"max={f0_max*1000:.4f}mm")

# ---------------------------------------------------------------------------
# Convert actions. Only Forearm_L/Hand_L receive (dense) new keys.
# ---------------------------------------------------------------------------
rest_fore_new = arm.data.bones["Forearm_L"].matrix_local.copy()
rest_hand_new = arm.data.bones["Hand_L"].matrix_local.copy()
conversion_max = {}
for aname in EXPECTED_ACTIONS:
    act = set_action(aname)
    lo, hi = [int(round(x)) for x in act.frame_range]
    prev_q = None
    max_tr = 0.0
    max_ro = 0.0
    max_hand_tr = 0.0
    max_hand_ro = 0.0
    for f in range(lo, hi + 1):
        sc.frame_set(f)
        bpy.context.view_layer.update()
        D = old_Dfore[aname][f]
        pf = arm.pose.bones["Forearm_L"]
        ph = arm.pose.bones["Hand_L"]
        pf.matrix = D @ rest_fore_new
        bpy.context.view_layer.update()
        ph.location = (0, 0, 0)
        ph.rotation_quaternion = (1, 0, 0, 0)
        ph.scale = (1, 1, 1)
        bpy.context.view_layer.update()
        q = pf.rotation_quaternion.copy()
        if prev_q is not None and float(prev_q.dot(q)) < 0:
            pf.rotation_quaternion = Quaternion((-q.w, -q.x, -q.y, -q.z))
            q = pf.rotation_quaternion.copy()
            bpy.context.view_layer.update()
        prev_q = q
        pf.keyframe_insert("location", frame=f)
        pf.keyframe_insert("rotation_quaternion", frame=f)
        ph.keyframe_insert("location", frame=f)
        ph.keyframe_insert("rotation_quaternion", frame=f)
        tr, ro = mat_diff(deform(pf), D)
        thr, rho = mat_diff(deform(ph), D)
        max_tr = max(max_tr, tr); max_ro = max(max_ro, ro)
        max_hand_tr = max(max_hand_tr, thr); max_hand_ro = max(max_hand_ro, rho)
    conversion_max[aname] = (max_tr, max_ro, max_hand_tr, max_hand_ro)
    for c in action_fcurves(act):
        if 'Forearm_L' in c.data_path or 'Hand_L' in c.data_path:
            for kp in c.keyframe_points:
                kp.interpolation = 'BEZIER'
                kp.handle_left_type = 'AUTO_CLAMPED'
                kp.handle_right_type = 'AUTO_CLAMPED'
            c.update()
    gate(f"{aname}: converted D_Forearm exact", max_tr < 0.00005 and max_ro < 0.01,
         f"max {max_tr*1000:.3f}mm/{max_ro:.4f}deg")
    gate(f"{aname}: converted D_Hand exact", max_hand_tr < 0.00005 and max_hand_ro < 0.01,
         f"max {max_hand_tr*1000:.3f}mm/{max_hand_ro:.4f}deg")

# Compare all-bone D matrices and evaluated left-arm geometry at samples.
max_all_tr = 0.0
max_all_ro = 0.0
max_subset_disp = 0.0
max_glove_offset_delta = 0.0
for aname in EXPECTED_ACTIONS:
    act = set_action(aname)
    for f in sample_frames[aname]:
        sc.frame_set(f)
        bpy.context.view_layer.update()
        for bname in ORDER:
            tr, ro = mat_diff(deform(arm.pose.bones[bname]), old_D_samples[aname][f][bname])
            max_all_tr = max(max_all_tr, tr)
            max_all_ro = max(max_all_ro, ro)
        P = evaluated_coords()
        disp = float(np.linalg.norm(P[subset_ids] - old_subset_samples[aname][f], axis=1).max())
        max_subset_disp = max(max_subset_disp, disp)
        old_g, old_fg = old_glove_samples[aname][f]
        new_g = P[glove_mask].mean(axis=0)
        new_fg = np.array(weapon.matrix_world @ FG0, dtype=np.float64)
        max_glove_offset_delta = max(max_glove_offset_delta, float(np.linalg.norm((new_g - new_fg) - (old_g - old_fg))))
gate("all-bone deformation matrices preserved at samples", max_all_tr < 0.00005 and max_all_ro < 0.01,
     f"max {max_all_tr*1000:.3f}mm/{max_all_ro:.4f}deg")
gate("evaluated forearm/glove geometry preserved at samples", max_subset_disp < 0.0001,
     f"max displacement={max_subset_disp*1000:.3f}mm over {len(subset_ids)} verts")
gate("glove-to-foregrip offset preserved", max_glove_offset_delta < 0.0001,
     f"max offset-vector delta={max_glove_offset_delta*1000:.3f}mm")

# ---------------------------------------------------------------------------
# Isolated articulation tests on the new pivot.
# ---------------------------------------------------------------------------
def rot_world(name, axis, deg):
    pb = arm.pose.bones[name]
    head = pb.head.copy()
    M = Matrix.Translation(head) @ Matrix.Rotation(math.radians(deg), 4, axis) @ Matrix.Translation(-head)
    pb.matrix = M @ pb.matrix
    bpy.context.view_layer.update()


reset_pose()
BASE = evaluated_coords()
prox_shell = (ISL == 53) & (s_rel < -0.035)
thigh_mask = np.isin(ISL, [87, 59])
for test_name, bone, deg in (("HAND_FLEX", "Hand_L", -40), ("FOREARM_FLEX", "Forearm_L", -55)):
    reset_pose()
    rot_world(bone, (1, 0, 0), deg)
    P = evaluated_coords()
    dg = float(np.linalg.norm(P[glove_mask].mean(axis=0) - BASE[glove_mask].mean(axis=0)))
    dp = float(np.linalg.norm(P[prox_shell].mean(axis=0) - BASE[prox_shell].mean(axis=0))) if np.any(prox_shell) else 0
    dt = float(np.linalg.norm(P[thigh_mask].mean(axis=0) - BASE[thigh_mask].mean(axis=0))) if np.any(thigh_mask) else 0
    print(f"ISO {test_name}: glove centroid={dg*1000:.1f}mm proximalShell={dp*1000:.1f}mm thigh={dt*1000:.3f}mm")
    if bone == "Hand_L":
        gate("isolated Hand_L moves glove", dg > 0.008, f"{dg*1000:.1f}mm")
        gate("isolated Hand_L leaves proximal forearm shell", dp < 0.004, f"{dp*1000:.1f}mm")
        gate("isolated Hand_L leaves thigh", dt < 0.0001, f"{dt*1000:.3f}mm")
    else:
        gate("isolated Forearm_L carries glove", dg > 0.020, f"{dg*1000:.1f}mm")

print(f"GATES: {PASS}/{PASS+FAIL} pass; DO_SAVE={DO_SAVE}")

# ---------------------------------------------------------------------------
# Trial renders (no save) or final save.
# ---------------------------------------------------------------------------
if not DO_SAVE:
    os.makedirs(OUT, exist_ok=True)
    sc.render.engine = "CYCLES"
    sc.cycles.samples = 24
    sc.cycles.use_denoising = True
    sc.cycles.device = "CPU"
    w = bpy.data.worlds.new("Fix60World")
    sc.world = w
    w.use_nodes = True
    w.node_tree.nodes["Background"].inputs[0].default_value = (0.16, 0.17, 0.19, 1)
    w.node_tree.nodes["Background"].inputs[1].default_value = 0.95
    sd = bpy.data.lights.new("Fix60Sun", "SUN")
    sd.energy = 3
    so = bpy.data.objects.new("Fix60Sun", sd)
    sc.collection.objects.link(so)
    so.rotation_euler = (math.radians(52), math.radians(8), math.radians(-38))
    cam = bpy.data.objects.new("Fix60Cam", bpy.data.cameras.new("Fix60Cam"))
    sc.collection.objects.link(cam)
    sc.camera = cam
    arm.hide_render = True

    def shoot(name, loc, target, rx=900, ry=900, lens=56):
        cam.data.lens = lens
        cam.location = loc
        cam.rotation_euler = (Vector(target) - Vector(loc)).to_track_quat('-Z', 'Y').to_euler()
        sc.render.resolution_x = rx
        sc.render.resolution_y = ry
        sc.render.filepath = f"{OUT}/{name}.png"
        bpy.ops.render.render(write_still=True)
        print("RENDERED", name)

    marker_mat = bpy.data.materials.new("Fix60Marker")
    marker_mat.use_nodes = True
    mb = marker_mat.node_tree.nodes["Principled BSDF"]
    mb.inputs["Base Color"].default_value = (0, 1, 0.3, 1)
    mb.inputs["Emission Color"].default_value = (0, 1, 0.3, 1)
    mb.inputs["Emission Strength"].default_value = 1.0
    markers = []

    def add_markers():
        clear_markers()
        bpy.context.view_layer.update()
        for loc, rad, nm in ((arm.pose.bones["Forearm_L"].head, 0.010, "M_ELBOW"),
                             (arm.pose.bones["Hand_L"].head, 0.010, "M_WRIST"),
                             (arm.pose.bones["Hand_L"].tail, 0.008, "M_TAIL")):
            bpy.ops.mesh.primitive_ico_sphere_add(radius=rad, location=loc)
            o = bpy.context.active_object
            o.name = nm
            o.data.materials.append(marker_mat)
            markers.append(o)

    def clear_markers():
        for o in list(markers):
            bpy.data.objects.remove(o, do_unlink=True)
        markers.clear()

    weapon.hide_render = True
    reset_pose(); add_markers()
    shoot("fix60_trial_wrist_rest_front", (0.245, -0.62, 0.51), (0.245, -0.012, 0.492))
    shoot("fix60_trial_wrist_rest_sideL", (0.78, -0.02, 0.51), (0.245, -0.012, 0.492))
    reset_pose(); rot_world("Hand_L", (1, 0, 0), -40); add_markers()
    shoot("fix60_trial_wrist_flex_front", (0.245, -0.62, 0.51), (0.245, -0.012, 0.492))
    shoot("fix60_trial_wrist_flex_sideL", (0.78, -0.02, 0.51), (0.245, -0.012, 0.492))
    clear_markers()
    weapon.hide_render = False
    set_action("Weapon_Raise_To_Aim")
    sc.frame_set(36)
    bpy.context.view_layer.update()
    shoot("fix60_trial_aimF36_sideL", (1.9, -0.2, 0.62), (0, 0, 0.52), 800, 1000, 52)
    shoot("fix60_trial_aimF36_front", (0, -2.0, 0.58), (0, 0, 0.52), 800, 1000, 52)
    sc.frame_set(0)
    print("TRIAL ONLY — blend not saved")
elif FAIL == 0:
    reset_pose()
    set_action("Weapon_Raise_To_Aim")
    sc.frame_start = 0
    sc.frame_end = 90
    sc.frame_set(0)
    bpy.context.view_layer.update()
    bpy.ops.wm.save_mainfile()
    print("SAVED blend")
else:
    print("NOT SAVED — gate failures present")
print("DONE")
