"""Gated anatomical weight repair (script 56). DO_SAVE=False = trial.

Findings addressed (scripts 50-55, owner critique 2026-10-30):
  A. Six TORSO islands are weighted ~100% to arm bones, so chest/abdomen/
     back panels lift when the arms move (owner's "pinggang terangkat"):
       101 right inner jacket flap, 78+75 left front chest panel,
       55 left front oblique panel, 220+221 lower-back panels.
     -> Reassign every vertex of these islands to the SAME shared
        spine-chain height field the rest of the torso uses (script 31
        method, refitted from current chain-only verts). No arm weight.
  B. Left elbow blend is spread over ~60mm overall and ~160mm inside the
     rigid outer forearm guard (isl53), so flexion visibly bends along
     the forearm instead of hinging at the elbow (owner's antebrachium
     critique).
     -> Apply ONE shared elbow field to all arm-chain verts in the elbow
        zone: UpperArm_L<->Forearm_L smoothstep over s in [-14mm,+14mm]
        around the existing elbow pivot (profile/pinch/shell boundaries
        support the pivot; segment lengths are not changed).
NOT addressed here (structural, script 57): the Hand_L bone segment does
not pass through the left glove at all - its head/tail lie on the thigh
while the glove islands sit ~55mm lateral and ~50mm higher. Correcting
that pivot changes the rest skeleton and requires re-posing the left arm
in every clip, so it is a separate owner-approved re-rig step, not a
weight tweak. No wrist field is applied in this script.

No bone positions, geometry, UVs or materials are touched; only weights
of gated vertex sets. Saves ONLY if DO_SAVE and every gate passes:
F0 displacement == 0, weight sums == 1 (2e-4 tol), <=4 influences, torso
islands arm-free, torso islands immobile under isolated arm rotation,
elbow_L blend width <= 30mm. Trial mode renders verification poses from
the in-memory result.
"""
import math
import os

import bpy
import numpy as np
from mathutils import Matrix, Vector

DO_SAVE = True
PROJ = "/home/user/Cyber-Strike/EXOCOMFLICT_HERO01"
BLEND = f"{PROJ}/blender/HERO_01_working.blend"
SHOT = f"{PROJ}/screenshots/rig"
os.makedirs(SHOT, exist_ok=True)

bpy.ops.wm.open_mainfile(filepath=BLEND)
sc = bpy.context.scene
arm = bpy.data.objects["HERO_01_Armature"]
body = bpy.data.objects["HERO_01_BODY"]
bones = arm.data.bones
orig_action = arm.animation_data.action if arm.animation_data else None
print("ORIG ACTION:", orig_action.name if orig_action else None, "DO_SAVE:", DO_SAVE)


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
NG = len(gnames)


def read_W():
    Wm = np.zeros((n, NG), dtype=np.float64)
    for v in body.data.vertices:
        for ge in v.groups:
            Wm[v.index, ge.group] = ge.weight
    return Wm


W = read_W()
orig_groups = [[ge.group for ge in v.groups] for v in body.data.vertices]

# islands (same union-find ordering as scripts 51-55)
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

TORSO_ISLANDS = {
    101: (1037, (-0.030, -0.070, 0.693)),
    78: (1590, (0.072, -0.077, 0.720)),
    75: (451, (0.111, -0.069, 0.729)),
    55: (1675, (0.104, -0.050, 0.649)),
    220: (2036, (0.094, 0.061, 0.704)),
    221: (1936, (-0.020, 0.056, 0.707)),
}
for isl_id, (exp_n, exp_c) in TORSO_ISLANDS.items():
    got_n = int(cnt[isl_id])
    got_c = icen[isl_id]
    ok = got_n == exp_n and np.linalg.norm(got_c - np.array(exp_c)) < 0.012
    print(f"TARGET isl{isl_id}: n={got_n} (exp {exp_n}) cen={np.round(got_c,3)} exp={exp_c} -> {'OK' if ok else 'MISMATCH'}")
    assert ok, f"island identity mismatch for {isl_id}; aborting"

ARM_B = ["Clavicle_R", "UpperArm_R", "Forearm_R", "Hand_R", "Clavicle_L", "UpperArm_L", "Forearm_L", "Hand_L"]
CHAIN_B = ["Hips", "Spine", "Chest", "UpperChest", "Neck"]


def eval_coords():
    bpy.context.view_layer.update()
    dg = bpy.context.evaluated_depsgraph_get()
    eo = body.evaluated_get(dg)
    em = eo.to_mesh()
    p = np.empty(n * 3, dtype=np.float64)
    em.vertices.foreach_get("co", p)
    eo.to_mesh_clear()
    emw = np.array(eo.matrix_world)
    return p.reshape(-1, 3) @ emw[:3, :3].T + emw[:3, 3]


sc.frame_set(0)
BASE_F0 = eval_coords()
print(f"baseline F0 vs rest max dev = {np.abs(BASE_F0-P0).max()*1000:.3f} mm")

# ------------------------------------------------ fit spine field (script-31 method)
target_mask = np.isin(ISL, list(TORSO_ISLANDS.keys()))
chain_idx = [gidx[b] for b in CHAIN_B]
outside_chain = [i for i in range(NG) if i not in chain_idx]
chain_mask = (W[:, outside_chain].sum(axis=1) < 1e-6) & (W.sum(axis=1) > 0) & (~target_mask)
zbins = np.arange(0.435, 0.8251, 0.004)
field = np.zeros((len(zbins), len(CHAIN_B)))
fcnt = np.zeros(len(zbins))
sel = np.nonzero(chain_mask & (P0[:, 2] >= zbins[0]) & (P0[:, 2] <= zbins[-1]))[0]
bi = np.clip(np.digitize(P0[sel, 2], zbins) - 1, 0, len(zbins) - 1)
for j, bname in enumerate(CHAIN_B):
    field[:, j] = np.bincount(bi, weights=W[sel, gidx[bname]], minlength=len(zbins))
fcnt = np.bincount(bi, minlength=len(zbins)).astype(np.float64)
nz = fcnt > 0
field[nz] /= fcnt[nz][:, None]
run = None
for k in range(len(zbins)):
    if nz[k]:
        run = field[k].copy()
    elif run is not None:
        field[k] = run
run = None
for k in range(len(zbins) - 1, -1, -1):
    if nz[k]:
        run = field[k].copy()
    elif run is not None:
        field[k] = run
ker = np.ones(5) / 5
for j in range(len(CHAIN_B)):
    field[:, j] = np.convolve(np.pad(field[:, j], 2, mode="edge"), ker, mode="valid")
field /= np.maximum(field.sum(axis=1, keepdims=True), 1e-9)
for z in (0.52, 0.57, 0.62, 0.67, 0.72, 0.76, 0.80):
    k = int(np.clip(np.digitize(z, zbins) - 1, 0, len(zbins) - 1))
    print(f"FIELD z={z:.2f}: " + ", ".join(f"{CHAIN_B[j]}={field[k,j]:.3f}" for j in range(len(CHAIN_B)) if field[k, j] > 0.01))


def field_row(z):
    t = (z - zbins[0]) / 0.004
    k0 = int(np.clip(math.floor(t), 0, len(zbins) - 1))
    k1 = min(k0 + 1, len(zbins) - 1)
    f = float(np.clip(t - k0, 0, 1))
    return field[k0] * (1 - f) + field[k1] * f


def seg_proj(Pts, A, B):
    AB = B - A
    L = float(np.linalg.norm(AB))
    t = np.clip(((Pts - A) @ AB) / (L * L), 0.0, 1.0)
    proj = A + t[:, None] * AB
    return t * L, np.linalg.norm(Pts - proj, axis=1), L


def signed_s(p_bone, j_bone, d_pos):
    P, J, D = jpos(p_bone), jpos(j_bone), d_pos
    along_p, d_p, len_p = seg_proj(P0, P, J)
    along_d, d_d, len_d = seg_proj(P0, J, D)
    return np.where(d_d < d_p, along_d, along_p - len_p), np.minimum(d_p, d_d), len_d


def smoothstep(x):
    x = np.clip(x, 0.0, 1.0)
    return x * x * (3.0 - 2.0 * x)


# ------------------------------------------------ build new weights
Wn = W.copy()
changed = np.zeros(n, dtype=bool)

# A. torso islands -> spine field (full replacement, top-4)
tidx = np.nonzero(target_mask)[0]
for vi in tidx:
    row = np.zeros(NG)
    fr = field_row(float(P0[vi, 2]))
    order = np.argsort(-fr)[:4]
    for j in order:
        if fr[j] > 1e-4:
            row[chain_idx[j]] = fr[j]
    ssum = row.sum()
    assert ssum > 0.5, (vi, P0[vi])
    Wn[vi] = row / ssum
    changed[vi] = True
print(f"A torso islands reassigned: {len(tidx)} verts")

# B. left elbow shared hinge field
s_eL, d_eL, len_faL = signed_s("UpperArm_L", "Forearm_L", jpos("Hand_L"))
armL_idx = [gidx[b] for b in ("Clavicle_L", "UpperArm_L", "Forearm_L", "Hand_L")]
outside_armL = [i for i in range(NG) if i not in armL_idx]
zone_e = (d_eL <= 0.055) & (s_eL >= -0.07) & (s_eL <= 0.16) & (W[:, outside_armL].sum(axis=1) < 1e-6)
ua, fa = gidx["UpperArm_L"], gidx["Forearm_L"]
tot = Wn[zone_e, ua] + Wn[zone_e, fa]
f_e = smoothstep((s_eL[zone_e] + 0.014) / 0.028)
Wn[zone_e, fa] = tot * f_e
Wn[zone_e, ua] = tot * (1.0 - f_e)
_zone_changed = np.zeros(n, dtype=bool)
_zone_changed[zone_e] = tot > 1e-6
changed |= _zone_changed
print(f"B elbow_L field applied: {int(zone_e.sum())} zone verts (distal len {len_faL:.3f})")

# (No wrist field: Hand_L pivot itself is misplaced - see header/script 57.)
hl = gidx["Hand_L"]

# prune to top-4 + normalize on changed rows only
for vi in np.nonzero(changed)[0]:
    row = Wn[vi].copy()
    row[row < 1e-4] = 0.0
    if (row > 0).sum() > 4:
        keep = np.argsort(-row)[:4]
        mask = np.zeros(NG, dtype=bool)
        mask[keep] = True
        row[~mask] = 0.0
    ssum = row.sum()
    assert ssum > 0.5, vi
    Wn[vi] = row / ssum

# write back changed verts
vg = {g.name: g for g in body.vertex_groups}
for vi in np.nonzero(changed)[0]:
    vi = int(vi)
    for gi in orig_groups[vi]:
        body.vertex_groups[gi].remove([vi])
    for gi in np.nonzero(Wn[vi] > 1e-4)[0]:
        body.vertex_groups[int(gi)].add([vi], float(Wn[vi, gi]), "ADD")
body.data.update()
print(f"WROTE weights for {int(changed.sum())} verts")

# ------------------------------------------------ gates
gates = []


def gate(name, ok, detail=""):
    print(("PASS " if ok else "FAIL ") + name + (f" [{detail}]" if detail else ""))
    gates.append(bool(ok))


Wp = read_W()
sums = Wp.sum(axis=1)
gate("weight sums == 1", float(np.abs(sums - 1).max()) < 2e-4, f"max dev {np.abs(sums-1).max():.2e}")
gate("zero-weight verts == 0", int((sums <= 1e-6).sum()) == 0)
maxinf = int((Wp > 1e-4).sum(axis=1).max())
gate("max influences <= 4", maxinf <= 4, f"max={maxinf}")
arm_idx = [gidx[b] for b in ARM_B]
for isl_id in TORSO_ISLANDS:
    m = ISL == isl_id
    gate(f"isl{isl_id} arm-free", float(Wp[m][:, arm_idx].sum(axis=1).mean()) < 0.01,
         f"arm avg {Wp[m][:, arm_idx].sum(axis=1).mean():.4f}")

# elbow profile after fix
s_arr, d_arr, len_d = s_eL, d_eL, len_faL
pmask = (d_arr <= 0.043) & (s_arr >= -0.07) & (s_arr <= len_d + 0.02)
bins = {}
for lo in np.arange(-0.07, len_d + 0.01, 0.01):
    selb = pmask & (s_arr >= lo) & (s_arr < lo + 0.01)
    if selb.sum() >= 15:
        bins[round(float(lo + 0.005), 3)] = float(Wp[selb, fa].mean())
crossover = next((k for k in sorted(bins) if k >= 0 and bins[k] >= 0.5), None)
s25 = next((k for k in sorted(bins) if bins[k] >= 0.25), None)
s75 = next((k for k in sorted(bins) if k >= 0 and bins[k] >= 0.75), None)
width = (s75 - s25) if (s25 is not None and s75 is not None) else None
print(" elbow_L profile post:", {k: round(v, 2) for k, v in bins.items()})
gate("elbow_L blend width <= 30mm", width is not None and width <= 0.030, f"width={width} crossover={crossover}")

DOMp = np.argmax(Wp, axis=1)
hl_dom = int((DOMp == hl).sum())
print(f"INFO Hand_L dominant verts = {hl_dom} (unchanged by design; pivot defect is structural, script 57)")

sc.frame_set(0)
F0p = eval_coords()
disp0 = float(np.abs(F0p - BASE_F0).max())
gate("F0 displacement == 0", disp0 < 1e-6, f"max {disp0*1000:.4f} mm")

# isolated arm rotations: torso islands must not move
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


reset_pose()
BASE_ISO = eval_coords()
icen0 = np.stack([np.bincount(ISL, weights=BASE_ISO[:, k]) / cnt for k in range(3)], axis=1)
for tname, bone in (("SHOULDER_R", "UpperArm_R"), ("SHOULDER_L", "UpperArm_L"),
                    ("ELBOW_L", "Forearm_L")):
    reset_pose()
    rot_world(bone, (1, 0, 0), -60 if "SHOULDER" in tname else -55)
    Pp = eval_coords()
    icenP = np.stack([np.bincount(ISL, weights=Pp[:, k]) / cnt for k in range(3)], axis=1)
    worst = max(float(np.linalg.norm(icenP[i] - icen0[i])) for i in TORSO_ISLANDS)
    gate(f"torso islands still under {tname}", worst < 0.001, f"worst centroid disp {worst*1000:.2f} mm")

# ------------------------------------------------ trial renders (in-memory result)
if not DO_SAVE:
    w = bpy.data.worlds.new("FixWorld")
    sc.world = w
    w.use_nodes = True
    w.node_tree.nodes["Background"].inputs[0].default_value = (0.32, 0.33, 0.36, 1)
    w.node_tree.nodes["Background"].inputs[1].default_value = 0.9
    sd = bpy.data.lights.new("FixSun", "SUN")
    sd.energy = 3.0
    so = bpy.data.objects.new("FixSun", sd)
    sc.collection.objects.link(so)
    so.rotation_euler = (math.radians(52), math.radians(8), math.radians(-38))
    cam = bpy.data.objects.new("FixCam", bpy.data.cameras.new("FixCam"))
    sc.collection.objects.link(cam)
    sc.camera = cam
    sc.render.engine = "CYCLES"
    sc.cycles.samples = 24
    sc.cycles.use_denoising = True
    sc.cycles.device = "CPU"
    arm.hide_render = True

    def shoot(name, loc, target, rx=760, ry=900, lens=52):
        cam.data.lens = lens
        cam.location = loc
        cam.rotation_euler = (Vector(target) - Vector(loc)).to_track_quat("-Z", "Y").to_euler()
        sc.render.resolution_x = rx
        sc.render.resolution_y = ry
        sc.render.filepath = f"{SHOT}/{name}.png"
        bpy.ops.render.render(write_still=True)
        print("RENDERED", name)

    reset_pose()
    shoot("fix56_trial_rest_front", (0, -1.85, 0.56), (0, 0, 0.52))
    shoot("fix56_trial_rest_back", (0, 1.85, 0.56), (0, 0, 0.52))
    reset_pose(); rot_world("UpperArm_L", (1, 0, 0), -60); rot_world("UpperArm_R", (1, 0, 0), -60)
    shoot("fix56_trial_shoulders_front", (0, -1.7, 0.62), (0, 0, 0.58))
    shoot("fix56_trial_shoulders_back", (0, 1.7, 0.62), (0, 0, 0.58))
    reset_pose(); rot_world("Forearm_L", (1, 0, 0), -90)
    shoot("fix56_trial_elbowL_sideL", (0.95, -0.35, 0.52), (0.17, -0.02, 0.50), 760, 760, 55)
    # legacy aim F36 with original action restored
    if arm.animation_data and orig_action:
        arm.animation_data.action = orig_action
    sc.frame_set(36)
    bpy.context.view_layer.update()
    shoot("fix56_trial_aimF36_front", (0, -1.7, 0.60), (0, -0.06, 0.56))
    shoot("fix56_trial_aimF36_sideL", (1.55, -0.45, 0.60), (0.02, -0.08, 0.55))

# restore action/frame before any save
if arm.animation_data and orig_action:
    arm.animation_data.action = orig_action
sc.frame_set(0)
bpy.context.view_layer.update()
allok = all(gates)
print(f"GATES: {sum(gates)}/{len(gates)} pass; DO_SAVE={DO_SAVE}")
if DO_SAVE and allok:
    bpy.ops.wm.save_mainfile()
    print("SAVED blend")
elif DO_SAVE:
    print("NOT SAVED (gate failure)")
else:
    print("TRIAL ONLY (not saved)")
print("DONE")
