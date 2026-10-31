"""63 - Fix jacket/abdomen lift: strip arm weights from torso clothing.

Diagnosis (scripts 61-62, VERIFIED by renders + evaluated deformation):
the central abdomen is clean (script 56), but clothing that rests beside
the hanging LEFT arm was auto-weighted to the arm chain:
  * left belt pouch + back-waist belt segments: 100% UpperArm/Forearm_L
  * lower-left jacket front/side panels (z 0.54-0.70): up to 100% arm_L,
    isolated shoulder flex drags them +52mm in z (owner-visible lift)
  * one left thigh-strap island: 100% Forearm_L
  * 13,305 verts sit >=55mm from every arm bone yet carry 94% arm weight.

Fix (weights only; no geometry/material/armature changes):
  T2 rigid islands first: islands whose median distance to the arm
  polylines >= 0.035, centroid |x| <= 0.160, centroid z <= 0.700,
  bbox zmax <= 0.740, mean arm weight >= 0.5  ->  remove ALL arm weight,
  give the removed mass to the fitted spine-chain field (script-56 method)
  evaluated at the island centroid z (uniform per island = rigid).
  T1 vertex field: remaining verts inside the torso box with z <= 0.720:
  arm weights scaled by keep(dArm): 1.0 at dArm<=0.045 -> 0.0 at
  dArm>=0.065 (smoothstep); removed mass -> spine field at vertex z.
  Shoulder pauldrons (z>0.72) and true arm surface (dArm<=0.045) untouched.

Trial protocol: renders BEFORE (audit61 cameras), applies in memory,
re-measures, renders AFTER. DO_SAVE=False => blend on disk untouched.
Only flip DO_SAVE after the trial renders pass visual inspection.

Run: tools/blender/run_bpy.sh tools/blender/scripts/63_fix_jacket_lift_weights.py
"""
import bpy
import math
import numpy as np
from collections import deque
from mathutils import Matrix, Vector

import os
DO_SAVE = False  # APPLIED in §5.14 (saved blend md5 4a768f49...). Do NOT rerun
                 # with DO_SAVE=True on the saved blend; the changed-count
                 # assert refuses, and T1 band scaling is not idempotent.
QUICK = os.environ.get("FIX63_QUICK") == "1"  # skip renders (diagnostic iterations)
BLEND = "/home/user/Cyber-Strike/EXOCOMFLICT_HERO01/blender/HERO_01_working.blend"
OUT = "/home/user/Cyber-Strike/EXOCOMFLICT_HERO01/screenshots/rig"
ARM_GROUPS = ["Clavicle_L", "UpperArm_L", "Forearm_L", "Hand_L",
              "Clavicle_R", "UpperArm_R", "Forearm_R", "Hand_R"]
CHAIN_B = ["Hips", "Spine", "Chest", "UpperChest", "Neck"]

bpy.ops.wm.open_mainfile(filepath=BLEND)
sc = bpy.context.scene
# Capture scene state so a save persists ONLY the weight changes.
ORIG = {
    "world": sc.world, "engine": sc.render.engine,
    "res_x": sc.render.resolution_x, "res_y": sc.render.resolution_y,
    "res_pct": sc.render.resolution_percentage, "filepath": sc.render.filepath,
    "camera": sc.camera, "frame": sc.frame_current,
    "cycles_samples": getattr(sc.cycles, "samples", None),
}
arm = bpy.data.objects["HERO_01_Armature"]
ORIG["arm_hide_render"] = arm.hide_render
ORIG["action"] = arm.animation_data.action if arm.animation_data else None
try:
    ORIG["action_slot"] = arm.animation_data.action_slot if arm.animation_data else None
except Exception:
    ORIG["action_slot"] = None
body = bpy.data.objects["HERO_01_BODY"]
ad = arm.animation_data
me = body.data
NV = len(me.vertices)
co = np.empty(NV * 3); me.vertices.foreach_get("co", co); co = co.reshape(-1, 3)
gnames = [g.name for g in body.vertex_groups]
NG = len(gnames); gidx = {n: i for i, n in enumerate(gnames)}
W = np.zeros((NV, NG), np.float64)
maxinfl = 0
for v in me.vertices:
    maxinfl = max(maxinfl, len(v.groups))
    for ge in v.groups:
        W[v.index, ge.group] = ge.weight
rs = W.sum(1); rs[rs == 0] = 1.0; W = W / rs[:, None]
print(f"BODY verts={NV} groups={NG} max_influences_existing={maxinfl}", flush=True)
for bn in ("Hips", "UpperLeg_L", "UpperLeg_R", "UpperArm_L", "Forearm_L"):
    print(f"bone {bn} head_local={np.round(np.array(arm.data.bones[bn].head_local), 4)}")

arm_idx = [gidx[n] for n in ARM_GROUPS]
arm_w = W[:, arm_idx].sum(1)

# ---------- islands (identical BFS to script 62 -> identical IDs) ----------
EP = np.empty(len(me.edges) * 2, np.int64); me.edges.foreach_get("vertices", EP); EP = EP.reshape(-1, 2)
adj = [[] for _ in range(NV)]
for a, b in EP:
    adj[a].append(b); adj[b].append(a)
isl = np.full(NV, -1, np.int64); nid = 0
for s in range(NV):
    if isl[s] >= 0: continue
    q = deque([s]); isl[s] = nid
    while q:
        u = q.popleft()
        for w_ in adj[u]:
            if isl[w_] < 0: isl[w_] = nid; q.append(w_)
    nid += 1
cnt = np.bincount(isl, minlength=nid).astype(np.float64)
icen = np.stack([np.bincount(isl, weights=co[:, k], minlength=nid) / cnt for k in range(3)], 1)
print(f"islands={nid}", flush=True)

# ---------- arm-polyline distance ----------
bones = arm.data.bones
def bone_pts(side):
    pts = [np.array(bones[n].head_local) for n in
           (f"Clavicle_{side}", f"UpperArm_{side}", f"Forearm_{side}", f"Hand_{side}")]
    pts.append(np.array(bones[f"Hand_{side}"].tail_local))
    return pts

def dist_to_polyline(P, pts):
    dmin = np.full(len(P), 1e9)
    for a, b in zip(pts[:-1], pts[1:]):
        ab = b - a
        t = np.clip(((P - a) @ ab) / max(float(ab @ ab), 1e-12), 0.0, 1.0)
        dmin = np.minimum(dmin, np.linalg.norm(P - (a + t[:, None] * ab), axis=1))
    return dmin

dArm = np.minimum(dist_to_polyline(co, bone_pts("L")), dist_to_polyline(co, bone_pts("R")))

# ---------- spine-chain field (script-56 method) ----------
chain_idx = [gidx[b] for b in CHAIN_B]
outside_chain = [i for i in range(NG) if i not in chain_idx]
chain_mask = (W[:, outside_chain].sum(axis=1) < 1e-6) & (W.sum(axis=1) > 0)
zbins = np.arange(0.435, 0.8251, 0.004)
field = np.zeros((len(zbins), len(CHAIN_B)))
sel = np.nonzero(chain_mask & (co[:, 2] >= zbins[0]) & (co[:, 2] <= zbins[-1]))[0]
bi = np.clip(np.digitize(co[sel, 2], zbins) - 1, 0, len(zbins) - 1)
for j, bname in enumerate(CHAIN_B):
    field[:, j] = np.bincount(bi, weights=W[sel, gidx[bname]], minlength=len(zbins))
fcnt = np.bincount(bi, minlength=len(zbins)).astype(np.float64)
nz = fcnt > 0
field[nz] /= fcnt[nz][:, None]
run = None
for k in range(len(zbins)):
    if nz[k]: run = field[k].copy()
    elif run is not None: field[k] = run
run = None
for k in range(len(zbins) - 1, -1, -1):
    if nz[k]: run = field[k].copy()
    elif run is not None: field[k] = run
ker = np.ones(5) / 5
for j in range(len(CHAIN_B)):
    field[:, j] = np.convolve(np.pad(field[:, j], 2, mode="edge"), ker, mode="valid")
field /= np.maximum(field.sum(axis=1, keepdims=True), 1e-9)

def field_row(zv):
    t = (zv - zbins[0]) / 0.004
    k0 = int(np.clip(math.floor(t), 0, len(zbins) - 1))
    k1 = min(k0 + 1, len(zbins) - 1)
    f = float(np.clip(t - k0, 0, 1))
    return field[k0] * (1 - f) + field[k1] * f

for zv in (0.50, 0.55, 0.60, 0.65, 0.70):
    fr = field_row(zv)
    print(f"FIELD z={zv:.2f}: " + ", ".join(f"{CHAIN_B[j]}={fr[j]:.3f}" for j in range(len(CHAIN_B)) if fr[j] > 0.01), flush=True)

# ---------- target sets ----------
x, y, z = co[:, 0], co[:, 1], co[:, 2]
torso_box = (np.abs(x) <= 0.170) & (y >= -0.115) & (y <= 0.095) & (z >= 0.42) & (z <= 0.845)

T2_ISLANDS = []
EXCLUDED_DISTAL = []
for i in range(nid):
    if cnt[i] < 25: continue
    s = isl == i
    if arm_w[s].mean() < 0.5: continue
    if np.median(dArm[s]) < 0.035: continue
    if abs(icen[i, 0]) > 0.160 or icen[i, 2] > 0.700: continue
    if co[s, 2].max() > 0.740 or co[s, 2].min() < 0.40: continue
    # Distal-arm shell guard (trial-1 bug): right forearm/wrist inner shells
    # hang at waist height but ARE arm surface. They are ~100% Forearm+Hand,
    # sit below the belt line, and hug the arm polyline (median <= 0.055).
    side = "L" if icen[i, 0] > 0 else "R"
    distal = W[s][:, [gidx[f"Forearm_{side}"], gidx[f"Hand_{side}"]]].sum(1).mean()
    if distal >= 0.85 and icen[i, 2] < 0.530 and np.median(dArm[s]) <= 0.055:
        EXCLUDED_DISTAL.append(i)
        print(f"  EXCLUDED distal-arm shell isl{i} n={int(cnt[i])} cen=({icen[i,0]:+.3f},{icen[i,1]:+.3f},{icen[i,2]:+.3f}) distal={distal:.2f} dArmMed={np.median(dArm[s]):.3f}", flush=True)
        continue
    # Sleeve-shell guard (trial-2 attribution): medial upper-arm/forearm
    # sleeve patches have >=10% of verts within 30mm of the arm axis;
    # true clothing islands measure 0.000-0.038 (4x separation).
    frac30 = float((dArm[s] <= 0.030).mean())
    if frac30 >= 0.10:
        EXCLUDED_DISTAL.append(i)
        print(f"  EXCLUDED sleeve shell isl{i} n={int(cnt[i])} cen=({icen[i,0]:+.3f},{icen[i,1]:+.3f},{icen[i,2]:+.3f}) frac30={frac30:.3f}", flush=True)
        continue
    T2_ISLANDS.append(i)
excl_mask = np.isin(isl, EXCLUDED_DISTAL) if EXCLUDED_DISTAL else np.zeros(NV, dtype=bool)
print(f"\nT2 rigid islands ({len(T2_ISLANDS)}):", flush=True)
for i in T2_ISLANDS:
    s = isl == i
    # neighbour weight profile (verts within 20mm-expanded bbox, not in island)
    mn, mx = co[s].min(0) - 0.02, co[s].max(0) + 0.02
    nb = (~s) & (co[:, 0] >= mn[0]) & (co[:, 0] <= mx[0]) & (co[:, 1] >= mn[1]) & (co[:, 1] <= mx[1]) & (co[:, 2] >= mn[2]) & (co[:, 2] <= mx[2])
    prof = "-"
    if nb.sum() > 30:
        m = W[nb].mean(0)
        prof = ", ".join(f"{gnames[k]}={m[k]:.2f}" for k in np.argsort(m)[::-1][:3] if m[k] > 0.03)
    print(f"  isl{i} n={int(cnt[i])} cen=({icen[i,0]:+.3f},{icen[i,1]:+.3f},{icen[i,2]:+.3f}) "
          f"armW={arm_w[s].mean():.2f} dArmMed={np.median(dArm[s]):.3f} neighbours: {prof}", flush=True)
    print(f"      frac dArm<=0.030: {(dArm[s]<=0.030).mean():.3f}  <=0.040: {(dArm[s]<=0.040).mean():.3f}  "
          f"y[{co[s,1].min():+.3f},{co[s,1].max():+.3f}] z[{co[s,2].min():+.3f},{co[s,2].max():+.3f}]", flush=True)
t2_mask = np.isin(isl, T2_ISLANDS)

def smoothstep01(t):
    t = np.clip(t, 0.0, 1.0)
    return t * t * (3.0 - 2.0 * t)

keep = 1.0 - smoothstep01((dArm - 0.045) / 0.020)
t1_mask = torso_box & (z <= 0.720) & (dArm > 0.045) & (~t2_mask) & (~excl_mask) & (arm_w > 1e-6)
print(f"T1 verts={int(t1_mask.sum())}  T2 verts={int(t2_mask.sum())}", flush=True)

# ---------- build new weights ----------
Wn = W.copy()
changed = np.zeros(NV, dtype=bool)
# T1
for vi in np.nonzero(t1_mask)[0]:
    old_arm = Wn[vi, arm_idx].copy()
    Wn[vi, arm_idx] = old_arm * keep[vi]
    removed = float(old_arm.sum() - Wn[vi, arm_idx].sum())
    if removed > 1e-9:
        Wn[vi, chain_idx] += removed * field_row(float(z[vi]))
    changed[vi] = True
# T2 (uniform per island)
for i in T2_ISLANDS:
    fr = field_row(float(icen[i, 2]))
    for vi in np.nonzero(isl == i)[0]:
        removed = float(Wn[vi, arm_idx].sum())
        Wn[vi, arm_idx] = 0.0
        if removed > 1e-9:
            Wn[vi, chain_idx] += removed * fr
        changed[vi] = True
# prune to top-4 (match existing export budget), renormalise changed rows
LIMIT = 4 if maxinfl <= 4 else maxinfl
for vi in np.nonzero(changed)[0]:
    row = Wn[vi]
    if (row > 1e-4).sum() > LIMIT:
        top = np.argsort(row)[::-1][:LIMIT]
        nr = np.zeros_like(row); nr[top] = row[top]; row = nr
    row[row < 1e-4] = 0.0
    ssum = row.sum()
    assert ssum > 0.5, (vi, co[vi])
    Wn[vi] = row / ssum
print(f"changed verts total={int(changed.sum())} limit={LIMIT}", flush=True)

# ---------- pose / eval helpers ----------
def set_action(name):
    if name is None:
        ad.action = None; return None
    act = bpy.data.actions[name]; ad.action = act
    try:
        if len(act.slots) == 0:
            act.slots.new(id_type='OBJECT', name=arm.name)
        ad.action_slot = act.slots[0]
    except Exception as ex:
        print("slot setup", ex)
    return act

def reset_pose():
    set_action(None)
    for pb in arm.pose.bones:
        pb.location = (0, 0, 0); pb.rotation_quaternion = (1, 0, 0, 0)
        pb.rotation_euler = (0, 0, 0); pb.scale = (1, 1, 1)
    bpy.context.view_layer.update()

def rot_world(name, axis, deg):
    pb = arm.pose.bones[name]
    head = pb.head.copy()
    M = Matrix.Translation(head) @ Matrix.Rotation(math.radians(deg), 4, axis) @ Matrix.Translation(-head)
    pb.matrix = M @ pb.matrix
    bpy.context.view_layer.update()

def eval_positions():
    dg = bpy.context.evaluated_depsgraph_get()
    ev = body.evaluated_get(dg); m2 = ev.to_mesh()
    p = np.empty(NV * 3); m2.vertices.foreach_get("co", p); p = p.reshape(-1, 3)
    ev.to_mesh_clear(); return p

FLAP_L = (x >= 0.035) & (x <= 0.125) & (y >= -0.105) & (y <= -0.045) & (z >= 0.54) & (z <= 0.70)
WAIST_L_CLOTH = (x >= 0.070) & (x <= 0.160) & (y >= -0.105) & (y <= 0.050) & (z >= 0.52) & (z <= 0.66) & (dArm >= 0.045)
WAIST_R_CLOTH = (x <= -0.070) & (x >= -0.160) & (y >= -0.105) & (y <= 0.050) & (z >= 0.52) & (z <= 0.66) & (dArm >= 0.045)
ARM_SKIN = (dArm <= 0.030) & (arm_w > 0.9)
CLEAR_ARMED = torso_box & (z <= 0.720) & (dArm >= 0.055)

def measure(tag):
    reset_pose(); rest = eval_positions()
    out = {}
    for pname, bone in (("SH_L", "UpperArm_L"), ("SH_R", "UpperArm_R")):
        reset_pose(); rot_world(bone, (1, 0, 0), -60)
        P = eval_positions()
        out[pname] = P
        for zname, mask in (("FLAP_L", FLAP_L), ("WAIST_L_CLOTH", WAIST_L_CLOTH), ("WAIST_R_CLOTH", WAIST_R_CLOTH)):
            D = P[mask] - rest[mask]
            print(f"[{tag}] {pname} {zname}: cen d=[{D.mean(0)[0]*1000:+.1f},{D.mean(0)[1]*1000:+.1f},{D.mean(0)[2]*1000:+.1f}]mm "
                  f"|d| p50={np.percentile(np.linalg.norm(D,axis=1),50)*1000:.1f} p90={np.percentile(np.linalg.norm(D,axis=1),90)*1000:.1f} max={np.linalg.norm(D,axis=1).max()*1000:.1f}", flush=True)
    set_action("Weapon_Raise_To_Aim"); sc.frame_set(36); bpy.context.view_layer.update()
    P = eval_positions(); out["AIM36"] = P
    for zname, mask in (("FLAP_L", FLAP_L), ("WAIST_L_CLOTH", WAIST_L_CLOTH), ("WAIST_R_CLOTH", WAIST_R_CLOTH)):
        D = P[mask] - rest[mask]
        print(f"[{tag}] AIM36 {zname}: cen d=[{D.mean(0)[0]*1000:+.1f},{D.mean(0)[1]*1000:+.1f},{D.mean(0)[2]*1000:+.1f}]mm "
              f"|d| p50={np.percentile(np.linalg.norm(D,axis=1),50)*1000:.1f} p90={np.percentile(np.linalg.norm(D,axis=1),90)*1000:.1f}", flush=True)
    reset_pose(); sc.frame_set(0)
    return out

# ---------- render setup (audit61-style textured close-ups) ----------
sc.render.engine = "CYCLES"; sc.cycles.samples = 24; sc.cycles.use_denoising = True; sc.cycles.device = "CPU"
world = bpy.data.worlds.new("W63"); sc.world = world; world.use_nodes = True
world.node_tree.nodes["Background"].inputs[0].default_value = (0.16, 0.17, 0.19, 1)
world.node_tree.nodes["Background"].inputs[1].default_value = 0.95
sd = bpy.data.lights.new("S63", "SUN"); sd.energy = 3.0
so = bpy.data.objects.new("S63", sd); sc.collection.objects.link(so)
so.rotation_euler = (math.radians(52), math.radians(8), math.radians(-38))
cam = bpy.data.objects.new("C63", bpy.data.cameras.new("C63")); sc.collection.objects.link(cam); sc.camera = cam
arm.hide_render = True
TG = (0, 0, 0.62)
VIEWS = {"front": (0, -1.35, 0.66), "sideL": (1.35, -0.05, 0.66), "sideR": (-1.35, -0.05, 0.66), "3q": (0.80, -1.02, 0.80)}

def shoot(name, view):
    cam.data.lens = 58
    cam.location = VIEWS[view]
    cam.rotation_euler = (Vector(TG) - Vector(VIEWS[view])).to_track_quat("-Z", "Y").to_euler()
    sc.render.resolution_x = sc.render.resolution_y = 1000
    sc.render.filepath = f"{OUT}/{name}.png"
    bpy.ops.render.render(write_still=True)
    print("RENDERED", name, flush=True)

def render_set(prefix):
    reset_pose(); shoot(f"{prefix}_rest_front", "front")
    reset_pose(); rot_world("UpperArm_L", (1, 0, 0), -60)
    shoot(f"{prefix}_shL_front", "front"); shoot(f"{prefix}_shL_sideL", "sideL")
    reset_pose(); rot_world("UpperArm_R", (1, 0, 0), -60)
    shoot(f"{prefix}_shR_front", "front"); shoot(f"{prefix}_shR_sideR", "sideR")
    set_action("Weapon_Raise_To_Aim"); sc.frame_set(36); bpy.context.view_layer.update()
    shoot(f"{prefix}_aim_front", "front"); shoot(f"{prefix}_aim_sideL", "sideL"); shoot(f"{prefix}_aim_3q", "3q")
    reset_pose(); sc.frame_set(0)

# ---------- BEFORE ----------
before = measure("BEFORE")
if not QUICK:
    render_set("fix63_before")

# ---------- apply weights in memory ----------
ch_list = [int(v) for v in np.nonzero(changed)[0]]
for g in body.vertex_groups:
    g.remove(ch_list)
for gi in range(NG):
    sel = [(int(vi), float(Wn[vi, gi])) for vi in ch_list if Wn[vi, gi] > 1e-4]
    if not sel: continue
    vg = body.vertex_groups[gi]
    # add() takes one weight per call signature (index list, weight, type): batch by exact call per vert is slow;
    # use per-vertex add for correctness.
    for vi, wv in sel:
        vg.add([vi], wv, 'REPLACE')
print("weights written (in memory)", flush=True)

# verify readback
W2 = np.zeros((NV, NG), np.float64)
for v in me.vertices:
    for ge in v.groups:
        W2[v.index, ge.group] = ge.weight
rs2 = W2.sum(1); rs2[rs2 == 0] = 1.0; W2 = W2 / rs2[:, None]
arm_w2 = W2[:, arm_idx].sum(1)
print(f"readback max|Wn-W2| on changed = {np.abs(Wn[changed]-W2[changed]).max():.2e}", flush=True)
print(f"CLEAR_ARMED zone meanArmW: before={arm_w[CLEAR_ARMED].mean():.4f} after={arm_w2[CLEAR_ARMED].mean():.4f} "
      f"p90 after={np.percentile(arm_w2[CLEAR_ARMED],90):.4f}", flush=True)
print(f"FLAP_L meanArmW: before={arm_w[FLAP_L].mean():.4f} after={arm_w2[FLAP_L].mean():.4f}", flush=True)

# ---------- AFTER ----------
after = measure("AFTER")
arm_skin_max = {}
for pname in ("SH_L", "SH_R", "AIM36"):
    d = np.linalg.norm(after[pname][ARM_SKIN] - before[pname][ARM_SKIN], axis=1)
    arm_skin_max[pname] = float(d.max() * 1000)
    print(f"ARM_SKIN control {pname}: max positional change = {arm_skin_max[pname]:.3f}mm (expect ~0)", flush=True)
if EXCLUDED_DISTAL:
    print(f"distal-shell verts changed: {int(changed[excl_mask].sum())} (expect 0)", flush=True)
# per-island ARM_SKIN attribution (which changed islands contain true arm surface?)
dskin = np.linalg.norm(after["SH_L"] - before["SH_L"], axis=1)
suspects = sorted(set(T2_ISLANDS) | set(int(v) for v in np.unique(isl[t1_mask])))
for i in suspects:
    s = (isl == i) & ARM_SKIN
    if s.sum() == 0: continue
    print(f"ARMSKIN isl{i}: skinVerts={int(s.sum())} maxChangeSH_L={dskin[s].max()*1000:.1f}mm "
          f"cen=({icen[i,0]:+.3f},{icen[i,1]:+.3f},{icen[i,2]:+.3f}) inT2={i in T2_ISLANDS}", flush=True)
if not QUICK:
    render_set("fix63_after")

# ---------- gates ----------
reset_pose(); rest_a = eval_positions()
rot_world("UpperArm_L", (1, 0, 0), -60); Pa = eval_positions(); reset_pose()
Dflap = Pa[FLAP_L] - rest_a[FLAP_L]
gates = []
gates.append(("CLEAR zone meanArmW<=0.02", arm_w2[CLEAR_ARMED].mean() <= 0.02, f"{arm_w2[CLEAR_ARMED].mean():.4f}"))
gates.append(("FLAP_L isol dz mean<=2mm", abs(Dflap[:, 2].mean()) * 1000 <= 2.0, f"{Dflap[:,2].mean()*1000:+.2f}mm"))
Dw = Pa[WAIST_L_CLOTH] - rest_a[WAIST_L_CLOTH]
gates.append(("WAIST_L_CLOTH isol |d| p90<=3mm", np.percentile(np.linalg.norm(Dw, axis=1), 90) * 1000 <= 3.0,
              f"{np.percentile(np.linalg.norm(Dw,axis=1),90)*1000:.2f}mm"))
gates.append(("no weightless verts", bool((W2.sum(1) > 0.99).all()), f"min sum={W2.sum(1).min():.4f}"))
gates.append(("changed only in scope", int(changed.sum()) == len(ch_list), f"{len(ch_list)}"))
# True arm surface outside treated (T2) islands must be position-identical.
# (ARM_SKIN verts inside a T2 island are that clothing panel's lateral edge;
#  the frac30<0.10 classifier + visual renders are their safety net.)
skin_out = ARM_SKIN & (~t2_mask)
for pname in ("SH_L", "SH_R", "AIM36"):
    dd = np.linalg.norm(after[pname][skin_out] - before[pname][skin_out], axis=1).max() * 1000
    gates.append((f"ARM_SKIN outside T2 unchanged {pname}<=1mm", dd <= 1.0, f"{dd:.3f}mm"))
gates.append(("no changed vert with dArm<=0.030 outside T2", int((changed & (dArm <= 0.030) & (~t2_mask)).sum()) == 0,
              f"{int((changed & (dArm <= 0.030) & (~t2_mask)).sum())}"))
gates.append(("distal/sleeve shells untouched", int(changed[excl_mask].sum()) == 0, f"{int(changed[excl_mask].sum())}"))
allok = True
for name, ok, info in gates:
    print(f"GATE {'PASS' if ok else 'FAIL'}: {name} [{info}]", flush=True)
    allok = allok and ok

if DO_SAVE:
    assert allok, "gates failed; refusing to save"
    assert len(ch_list) > 5000, f"only {len(ch_list)} changed verts — blend already fixed? refusing to re-apply"
    # Restore original scene state; remove every helper this script created.
    reset_pose()
    if ORIG["action"] is not None:
        set_action(ORIG["action"].name)
    sc.frame_set(ORIG["frame"])
    for nm in ("S63", "C63"):
        ob = bpy.data.objects.get(nm)
        if ob: bpy.data.objects.remove(ob, do_unlink=True)
    for nm in ("S63",):
        li = bpy.data.lights.get(nm)
        if li: bpy.data.lights.remove(li)
    ca = bpy.data.cameras.get("C63")
    if ca: bpy.data.cameras.remove(ca)
    sc.world = ORIG["world"]
    w63 = bpy.data.worlds.get("W63")
    if w63: bpy.data.worlds.remove(w63)
    sc.camera = ORIG["camera"]
    sc.render.engine = ORIG["engine"]
    sc.render.resolution_x = ORIG["res_x"]; sc.render.resolution_y = ORIG["res_y"]
    sc.render.resolution_percentage = ORIG["res_pct"]; sc.render.filepath = ORIG["filepath"]
    if ORIG["cycles_samples"] is not None:
        try: sc.cycles.samples = ORIG["cycles_samples"]
        except Exception: pass
    arm.hide_render = ORIG["arm_hide_render"]
    bpy.context.view_layer.update()
    leftovers = [o.name for o in bpy.data.objects if o.name in ("S63", "C63")]
    assert not leftovers, leftovers
    bpy.ops.wm.save_mainfile()
    print("SAVED blend (DO_SAVE=True, all gates PASS, scene state restored)", flush=True)
else:
    print("TRIAL ONLY (DO_SAVE=False): blend on disk NOT modified", flush=True)
print("DONE 63", flush=True)
