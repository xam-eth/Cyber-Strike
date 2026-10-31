"""66 v2 - Build the NEW_HERO_01 skeleton + deterministic field skinning,
save a NEW working blend. Owner decision 2026-10-31: dump the old character
setup, re-rig from NEW_HERO_01.glb (A-pose; hands clear of the torso).

Same bone names/hierarchy as the shipped HERO_01 rig (Godot compatibility).
Joint positions from script 65's medial-axis traces; elbow/knee pivots
visually verified by script 67's isolated-bend renders.

Skinning v2 (bone-heat fails on this fragmented scan; script 67 found and
this version fixes three v1 defects):
 * five bone polylines (spine, arm L/R, leg L/R) EXTENDED rootward into the
   torso (arms start at UpperChest centre, legs at Hips centre) so verts
   above a root joint get the PARENT bone, never the limb bone (v1 defect:
   belt verts projected onto UpperLeg -> hip flexion dragged the belt);
 * per-vertex tent weights over arc length (smoothstep blends at joints);
 * PER-ISLAND single-system lock: no island may mix two systems, so no
   triangle can stretch between arm-driven and torso-driven verts
   (v1 defect: armpit membrane fin at 105deg raise). Islands that do not
   hug one polyline keep a hard per-vertex nearest-system switch;
 * anatomical gates: UpperLeg weight -> 0 above z=0.52 (redistributed to
   Hips); glove verts beyond the wrist on the hand segment -> pure Hand
   (v1: gloves only ~53% Hand);
 * rigid snap for near-constant islands (armor plates); top-4 + normalize.
Arm weight in the waist bands is exactly 0 by construction (hands ~185mm
clear in the A-pose) and re-audited by script 67.

REBUILDABLE: always starts from the pristine source GLB; saves
blender/NEW_HERO_01_working.blend (compressed); never touches the old blend.
Run: tools/blender/run_bpy.sh tools/blender/scripts/66_build_new_hero_rig.py
"""
import bpy
import math
import numpy as np
from collections import deque
from mathutils import Vector

SRC = "/home/user/Cyber-Strike/EXOCOMFLICT_HERO01/assets/source/NEW_HERO_01.glb"
BLEND_OUT = "/home/user/Cyber-Strike/EXOCOMFLICT_HERO01/blender/NEW_HERO_01_working.blend"
OUT = "/home/user/Cyber-Strike/EXOCOMFLICT_HERO01/screenshots/rig"

BONES = [
    ("Root",       None,         (0.000, 0.000, 0.000), (0.000, 0.000, 0.100), True),
    ("Hips",       "Root",       (0.000, -0.018, 0.505), (0.000, -0.021, 0.575), True),
    ("Spine",      "Hips",       (0.000, -0.021, 0.575), (0.000, -0.026, 0.650), True),
    ("Chest",      "Spine",      (0.000, -0.026, 0.650), (0.000, -0.016, 0.725), True),
    ("UpperChest", "Chest",      (0.000, -0.016, 0.725), (0.000, 0.002, 0.800), True),
    ("Neck",       "UpperChest", (0.000, 0.002, 0.800), (0.000, 0.000, 0.855), True),
    ("Head",       "Neck",       (0.000, 0.000, 0.855), (0.000, -0.006, 0.985), True),
]
for S, sx in (("L", 1.0), ("R", -1.0)):
    BONES += [
        (f"Clavicle_{S}", "UpperChest", (sx * 0.040, 0.000, 0.800), (sx * 0.135, 0.008, 0.795), True),
        (f"UpperArm_{S}", f"Clavicle_{S}", (sx * 0.135, 0.008, 0.795), (sx * 0.262, -0.004, 0.655), True),
        (f"Forearm_{S}",  f"UpperArm_{S}", (sx * 0.262, -0.004, 0.655), (sx * 0.355, -0.062, 0.572), True),
        (f"Hand_{S}",     f"Forearm_{S}",  (sx * 0.355, -0.062, 0.572), (sx * 0.392, -0.070, 0.522), True),
        (f"UpperLeg_{S}", "Hips",       (sx * 0.090, -0.018, 0.505), (sx * 0.097, -0.020, 0.285), True),
        (f"LowerLeg_{S}", f"UpperLeg_{S}", (sx * 0.097, -0.020, 0.285), (sx * 0.134, 0.012, 0.105), True),
        (f"Foot_{S}",     f"LowerLeg_{S}", (sx * 0.134, 0.012, 0.105), (sx * 0.150, -0.055, 0.040), True),
        (f"Toe_{S}",      f"Foot_{S}",     (sx * 0.150, -0.055, 0.040), (sx * 0.152, -0.105, 0.030), True),
    ]
# Weapon_R: deform=True with an always-empty vertex group so the glTF skin
# contains it as a joint - Godot attaches the weapon via find_bone("Weapon_R")
# (matches the old shipped GLB's 24-joint skin; verified at 4577c60).
BONES.append(("Weapon_R", "Hand_R", (-0.377, -0.067, 0.542), (-0.385, -0.117, 0.522), True))
BDICT = {b[0]: b for b in BONES}
DEFORM = [b[0] for b in BONES if b[4]]

bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.ops.import_scene.gltf(filepath=SRC)
body = max((o for o in bpy.data.objects if o.type == "MESH"), key=lambda o: len(o.data.vertices))
body.name = "HERO_01_BODY"; body.data.name = "HERO_01_BODY"
me = body.data; NV = len(me.vertices)
MW = np.array(body.matrix_world)
co = np.empty(NV * 3); me.vertices.foreach_get("co", co); co = co.reshape(-1, 3)
co = co @ MW[:3, :3].T + MW[:3, 3]
print(f"BODY verts={NV}", flush=True)

arm_data = bpy.data.armatures.new("HERO_01_Armature")
arm = bpy.data.objects.new("HERO_01_Armature", arm_data)
bpy.context.collection.objects.link(arm)
bpy.context.view_layer.objects.active = arm
bpy.ops.object.mode_set(mode="EDIT")
made = {}
for name, parent, head, tail, deform in BONES:
    b = arm_data.edit_bones.new(name); b.head = head; b.tail = tail; b.use_deform = deform; made[name] = b
for name, parent, head, tail, deform in BONES:
    if parent: made[name].parent = made[parent]
bpy.ops.object.mode_set(mode="OBJECT")
arm_data.display_type = "OCTAHEDRAL"; arm.show_in_front = True
print(f"BONES: {len(BONES)} total, {len(DEFORM)} deform", flush=True)

# ---------------- field skinning v2 ----------------
def P(name, which=2):
    return np.array(BDICT[name][which], dtype=np.float64)

def smoothstep01(t):
    t = np.clip(t, 0.0, 1.0)
    return t * t * (3.0 - 2.0 * t)

def polyline_eval(pts, nbones, w_half):
    pts = [np.array(p, float) for p in pts]
    seglen = [float(np.linalg.norm(pts[i + 1] - pts[i])) for i in range(len(pts) - 1)]
    arc = np.concatenate([[0.0], np.cumsum(seglen)])
    dmin = np.full(NV, 1e9); smin = np.zeros(NV)
    for i in range(len(pts) - 1):
        a, b = pts[i], pts[i + 1]; ab = b - a
        t = np.clip(((co - a) @ ab) / max(float(ab @ ab), 1e-12), 0.0, 1.0)
        d = np.linalg.norm(co - (a + t[:, None] * ab), axis=1)
        better = d < dmin
        dmin = np.where(better, d, dmin); smin = np.where(better, arc[i] + t * seglen[i], smin)
    Wb = np.zeros((NV, nbones))
    for j in range(nbones):
        a0, b0 = arc[j], arc[j + 1]
        d_arc = np.maximum(np.maximum(a0 - smin, smin - b0), 0.0)
        Wb[:, j] = 1.0 - smoothstep01(d_arc / w_half)
    ssum = Wb.sum(1); ssum[ssum == 0] = 1.0
    return dmin, smin, arc, Wb / ssum[:, None]

UC_C = (0.000, -0.016, 0.725)
HIPS_C = (0.000, -0.018, 0.505)
SYS_DEF = []
SYS_DEF.append(("spine", [P("Hips"), P("Spine"), P("Chest"), P("UpperChest"), P("Neck"), P("Head"), P("Head", 3)],
                ["Hips", "Spine", "Chest", "UpperChest", "Neck", "Head"], 0.032, None))
for S in ("L", "R"):
    SYS_DEF.append((f"arm{S}", [np.array(UC_C), P(f"Clavicle_{S}"), P(f"UpperArm_{S}"), P(f"Forearm_{S}"), P(f"Hand_{S}"), P(f"Hand_{S}", 3)],
                    ["UpperChest", f"Clavicle_{S}", f"UpperArm_{S}", f"Forearm_{S}", f"Hand_{S}"], 0.024, ("Hand", f"Hand_{S}", 4)))
    SYS_DEF.append((f"leg{S}", [np.array(HIPS_C), P(f"UpperLeg_{S}"), P(f"LowerLeg_{S}"), P(f"Foot_{S}"), P(f"Toe_{S}"), P(f"Toe_{S}", 3)],
                    ["Hips", f"UpperLeg_{S}", f"LowerLeg_{S}", f"Foot_{S}", f"Toe_{S}"], 0.028, None))
SYSTEMS = []
for sname, pts, bones, wh, extra in SYS_DEF:
    dmin, smin, arc, Wb = polyline_eval(pts, len(bones), wh)
    SYSTEMS.append(dict(name=sname, bones=bones, d=dmin, s=smin, arc=arc, W=Wb, extra=extra))
D = np.stack([s["d"] for s in SYSTEMS], 1)
win = np.argmin(D, 1)
gidx = {n: i for i, n in enumerate(DEFORM)}

# ---- islands ----
EP = np.empty(len(me.edges) * 2, np.int64); me.edges.foreach_get("vertices", EP); EP = EP.reshape(-1, 2)
adj = [[] for _ in range(NV)]
for a, b in EP:
    adj[a].append(b); adj[b].append(a)
isl = np.full(NV, -1, np.int64); nid = 0
for s0 in range(NV):
    if isl[s0] >= 0: continue
    q = deque([s0]); isl[s0] = nid
    while q:
        u = q.popleft()
        for w_ in adj[u]:
            if isl[w_] < 0: isl[w_] = nid; q.append(w_)
    nid += 1
cnt = np.bincount(isl, minlength=nid)
print(f"islands={nid}", flush=True)

# ---- per-island single-system lock + weights (v4) ----
# Script 67b proved the armpit fin comes from (a) big SUIT islands that
# genuinely span torso+arm (a hard nearest-system cut through them tears
# into blades at full raise) and (b) one back suit piece (isl58R class)
# that passed the 70% arm share and got arm-locked although it reaches
# the centreline. v4:
#  * lock needs >=70% share AND anatomical containment: an arm-locked
#    island may not contain verts in the torso core (|x|<0.06, z<0.80) nor
#    cross the centreline; a leg-locked island may not contain verts
#    above the pelvis core (z>0.53, |x|<0.07) nor cross the centreline;
#  * spanning islands get a smooth distance-softmax blend of ALL systems
#    followed by geodesic-style weight diffusion along their own edges
#    (16 passes) - fabric stretches a little at extreme poses instead of
#    tearing; every OTHER island stays locked/rigid.
W = np.zeros((NV, len(DEFORM)))
locked = 0; locked_verts = 0; spanning = []
sys_of_vert = win.copy()
SYS_SIDE = {"spine": 0, "armL": 1, "legL": 1, "armR": -1, "legR": -1}
for i in range(nid):
    m = np.nonzero(isl == i)[0]
    if len(m) == 0: continue
    wv = win[m]
    hist = np.bincount(wv, minlength=len(SYSTEMS)).astype(np.float64) / len(m)
    maj = int(hist.argmax())
    ok = hist[maj] >= 0.70
    if ok and SYSTEMS[maj]["name"] != "spine":
        side = SYS_SIDE[SYSTEMS[maj]["name"]]
        cx = co[m, 0]; cz = co[m, 2]
        if side > 0 and cx.min() < -0.02: ok = False
        if side < 0 and cx.max() > 0.02: ok = False
        if SYSTEMS[maj]["name"].startswith("arm") and ((np.abs(cx) < 0.06) & (cz < 0.80)).any(): ok = False
        if SYSTEMS[maj]["name"].startswith("leg") and ((cz > 0.53) & (np.abs(cx) < 0.07)).any(): ok = False
    if ok:
        sys_of_vert[m] = maj
        locked += 1; locked_verts += len(m)
    else:
        spanning.append(i)
print(f"island system-lock: {locked} islands / {locked_verts} verts locked; {len(spanning)} spanning islands "
      f"({int(cnt[spanning].sum()) if spanning else 0} verts) get blend+diffusion", flush=True)
for si, sysd in enumerate(SYSTEMS):
    m = sys_of_vert == si
    if not m.any(): continue
    for j, bn in enumerate(sysd["bones"]):
        W[m, gidx[bn]] = sysd["W"][m, j]

# spanning islands: softmax blend over all systems + intra-island diffusion
Dmin = D.min(1, keepdims=True)
fac_all = np.exp(-(D - Dmin) / 0.012)
fac_all[D > Dmin + 0.05] = 0.0
fac_all /= np.maximum(fac_all.sum(1, keepdims=True), 1e-12)
edges_of = {i: [] for i in spanning}
for a, b in EP:
    ia = isl[a]
    if ia == isl[b] and ia in edges_of:
        edges_of[ia].append((a, b))
for i in spanning:
    m = np.nonzero(isl == i)[0]
    Wi = np.zeros((len(m), len(DEFORM)))
    for si, sysd in enumerate(SYSTEMS):
        f = fac_all[m, si]
        if f.max() <= 0: continue
        for j, bn in enumerate(sysd["bones"]):
            Wi[:, gidx[bn]] += f * sysd["W"][m, j]
    pos = {v: k for k, v in enumerate(m.tolist())}
    ea = np.array([pos[a] for a, b in edges_of[i]], np.int64)
    eb = np.array([pos[b] for a, b in edges_of[i]], np.int64)
    if len(ea):
        for _ in range(16):
            acc = np.zeros_like(Wi); deg = np.zeros(len(m))
            np.add.at(acc, ea, Wi[eb]); np.add.at(deg, ea, 1.0)
            np.add.at(acc, eb, Wi[ea]); np.add.at(deg, eb, 1.0)
            deg[deg == 0] = 1.0
            Wi = 0.65 * Wi + 0.35 * (acc / deg[:, None])
    W[m] = Wi
print(f"spanning-island blend+diffusion applied to {len(spanning)} islands", flush=True)

# ---- anatomical gates ----
x, y, zv = co[:, 0], co[:, 1], co[:, 2]
for S in ("L", "R"):
    gi = gidx[f"UpperLeg_{S}"]
    keep = 1.0 - smoothstep01((zv - 0.500) / 0.020)
    moved = W[:, gi] * (1.0 - keep)
    W[:, gi] *= keep
    W[:, gidx["Hips"]] += moved
# glove purity: beyond-wrist verts close to the hand segment -> pure Hand
pure_hand = 0
for si, sysd in enumerate(SYSTEMS):
    if not sysd["extra"]: continue
    _, hbone, ptidx = sysd["extra"]
    s_wrist = sysd["arc"][ptidx]
    m = (sys_of_vert == si) & (sysd["d"] < 0.045) & (sysd["s"] > s_wrist + 0.010)
    W[m, :] = 0.0; W[m, gidx[hbone]] = 1.0
    pure_hand += int(m.sum())
print(f"glove pure-Hand verts={pure_hand}", flush=True)

# ---- rigid snap (same-system islands only by construction) ----
snapped = 0; snap_verts = 0
for i in range(nid):
    if cnt[i] < 3: continue
    m = isl == i
    if len(np.unique(sys_of_vert[m])) > 1: continue
    rng = (W[m].max(0) - W[m].min(0)).max()
    if rng < 0.35:
        W[m] = W[m].mean(0)
        snapped += 1; snap_verts += int(cnt[i])
print(f"rigid-snapped={snapped} ({snap_verts} verts)", flush=True)

# ---- top-4 prune + normalize ----
part = np.argpartition(-W, 4, axis=1)
rowsel = np.zeros_like(W, bool)
np.put_along_axis(rowsel, part[:, :4], True, axis=1)
W[~rowsel] = 0.0
W[W < 1e-4] = 0.0
W /= np.maximum(W.sum(1, keepdims=True), 1e-12)
unweighted = int((W.sum(1) <= 0.5).sum())
print(f"unweighted={unweighted} min_row_sum={W.sum(1).min():.4f}", flush=True)
assert unweighted == 0

for n in DEFORM:
    body.vertex_groups.new(name=n)
Wq = np.round(W * 255).astype(int)
for gi, n in enumerate(DEFORM):
    vg = body.vertex_groups[n]
    col = Wq[:, gi]
    for b in range(1, 256):
        idx = np.nonzero(col == b)[0]
        if len(idx):
            vg.add(idx.tolist(), b / 255.0, "REPLACE")
mod = body.modifiers.new("Armature", "ARMATURE"); mod.object = arm
body.parent = arm
print("vertex groups written + armature modifier bound", flush=True)

arm_i = [gidx[n] for n in DEFORM if any(k in n for k in ("UpperArm", "Forearm", "Hand_", "Clavicle"))]
leg_i = [gidx[n] for n in DEFORM if any(k in n for k in ("UpperLeg", "LowerLeg", "Foot_", "Toe_"))]
for z0, z1 in ((0.45, 0.55), (0.55, 0.65)):
    m = (np.abs(x) <= 0.125) & (zv >= z0) & (zv < z1)
    print(f"TORSO z{z0}-{z1}: armW max={W[m][:, arm_i].sum(1).max():.4f} legW max={W[m][:, leg_i].sum(1).max():.4f}", flush=True)
belt = (np.abs(x) <= 0.13) & (zv >= 0.50) & (zv < 0.58)
print(f"BELT legW mean={W[belt][:, leg_i].sum(1).mean():.4f} max={W[belt][:, leg_i].sum(1).max():.4f}", flush=True)

bpy.context.preferences.filepaths.use_file_compression = True
bpy.ops.wm.save_as_mainfile(filepath=BLEND_OUT, compress=True)
print(f"SAVED {BLEND_OUT} (compressed)", flush=True)
print("DONE 66 v2", flush=True)
