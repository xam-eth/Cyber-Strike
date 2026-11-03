"""88 - PHASE-1 STATIONARY WEAPON CHAIN from the owner's Mixamo downloads
(Drive 'animation' folder, 2026-11-03): Rifle Idle -> Idle (loop window),
Rifle Aiming Idle -> Aim_Idle, Rifle Aim To Down -> Weapon_Lower and
(time-reversed) Weapon_Raise, Reload -> Reload (walking-reload window,
in-place). Retarget = script-85/86 world-direction SWING transfer
(52 bone pairs incl. 30 fingers) + script-86 two-bone foregrip seat on
the aimed/idle clips (NOT on Reload: the left hand must leave the
fore-end to work the magazine). Seat targets the UN-calibrated weapon
orientation (the transform Godot's auto-calibration produces), so the
baked wrists are Godot-true; script 86's extra barrel-alignment
rotation is measured for Fire and reported, not repeated.
Existing clips Fire/Walk/Run/Roll are stolen from the shipped GLB and
preserved; the UAL test Idle/Reload are replaced by the rifle versions.
Export: script-83 recipe + doubleSided patch + pygltflib verification
(9 animations, durations asserted). Blend NOT saved.
Run: tools/blender/run_bpy.sh tools/blender/scripts/88_phase1_chain_retarget.py
"""
import bpy
import math
import os
from mathutils import Vector, Matrix, Quaternion

PROJ = "/home/user/Cyber-Strike/EXOCOMFLICT_HERO01"
ROOT = "/home/user/Cyber-Strike"
BLEND = f"{PROJ}/blender/NEW_HERO_01_working.blend"
WEAPON_GLB = f"{PROJ}/assets/weapons/HERO_01_WEAPON.glb"
GLB_OUT = f"{PROJ}/assets/characters/HERO_01_RIGGED.glb"
OUT = f"{PROJ}/screenshots/rig"

# Sources declare 60 fps in FBX (diag88fps2: key placement follows the
# file rate; the importer also flips scene fps to 60 -> export must be
# forced back to 30). Bake grid stays 30 fps: stride = 2 src frames.
# (out_name, fbx, src_frame_a, src_frame_b, n_out_frames, seat)
CLIPS = [
    ("Idle",         "Rifle Idle.fbx",        151, 253,  52, True),   # best loop window (diag88b: poseDelta 0.025m), 1.70s
    ("Aim_Idle",     "Rifle Aiming Idle.fbx",   1, 187,  94, True),   # closed loop; first pose == AimToDown first pose, 3.10s
    ("Weapon_Lower", "Rifle Aim To Down.fbx",   1,  91,  46, True),   # natural speed 1.50s (no retime)
    ("Weapon_Raise", "Rifle Aim To Down.fbx",  91,   1,  46, True),   # time-reversed twin, 1.50s
    ("Reload",       "Reload.fbx",             58, 202,  73, False),  # mag-manipulation window of the walking reload, 2.40s
]
EXP_DUR = {"Fire": 1.400, "Idle": 1.700, "Weapon_Raise": 1.500, "Aim_Idle": 3.100,
           "Weapon_Lower": 1.500, "Reload": 2.400, "Walk": 1.333, "Run": 0.667, "Roll": 1.467}

MAP = {
    "Hips": "mixamorig:Hips", "Spine": "mixamorig:Spine", "Chest": "mixamorig:Spine1",
    "UpperChest": "mixamorig:Spine2", "Neck": "mixamorig:Neck", "Head": "mixamorig:Head",
    "Clavicle_L": "mixamorig:LeftShoulder", "UpperArm_L": "mixamorig:LeftArm",
    "Forearm_L": "mixamorig:LeftForeArm", "Hand_L": "mixamorig:LeftHand",
    "Clavicle_R": "mixamorig:RightShoulder", "UpperArm_R": "mixamorig:RightArm",
    "Forearm_R": "mixamorig:RightForeArm", "Hand_R": "mixamorig:RightHand",
    "UpperLeg_L": "mixamorig:LeftUpLeg", "LowerLeg_L": "mixamorig:LeftLeg",
    "Foot_L": "mixamorig:LeftFoot", "Toe_L": "mixamorig:LeftToeBase",
    "UpperLeg_R": "mixamorig:RightUpLeg", "LowerLeg_R": "mixamorig:RightLeg",
    "Foot_R": "mixamorig:RightFoot", "Toe_R": "mixamorig:RightToeBase",
}
for _st, _ss in (("L", "Left"), ("R", "Right")):
    for _f in ("Thumb", "Index", "Middle", "Ring", "Pinky"):
        for _k in (1, 2, 3):
            MAP[f"{_f}{_k}_{_st}"] = f"mixamorig:{_ss}Hand{_f}{_k}"
MARK_IMPORT = {
    "grip": Vector((-0.192, -0.033, 0.452)), "foregrip": Vector((-0.215, -0.062, 0.315)),
    "muzzle": Vector((-0.238, -0.080, 0.205)), "receiver": Vector((-0.198, -0.045, 0.500)),
}

bpy.ops.wm.open_mainfile(filepath=BLEND)
sc = bpy.context.scene
sc.render.fps = 30
sc.render.fps_base = 1.0
tgt = bpy.data.objects["HERO_01_Armature"]
body = bpy.data.objects["HERO_01_BODY"]
assert len(tgt.data.bones) == 54, f"target must be Rig v2 (54 bones), found {len(tgt.data.bones)}"
tb = tgt.data.bones
BONE_ORDER = [b.name for b in tb]
REST_LOCAL, REST_Q_T, REST_HEAD = {}, {}, {}
for b in tb:
    REST_Q_T[b.name] = b.matrix_local.to_quaternion()
    REST_HEAD[b.name] = Vector(b.head_local)
    REST_LOCAL[b.name] = (b.parent.matrix_local.inverted() @ b.matrix_local) if b.parent else b.matrix_local.copy()
LEG_T = (REST_HEAD["LowerLeg_L"] - REST_HEAD["UpperLeg_L"]).length + (REST_HEAD["Foot_L"] - REST_HEAD["LowerLeg_L"]).length
HIPS_REST_T = REST_HEAD["Hips"].copy()
tad = tgt.animation_data_create() if not tgt.animation_data else tgt.animation_data

# ---- steal clips to PRESERVE from the shipped GLB (script-87 pattern) ----
PRESERVE = ("Fire", "Walk", "Run", "Roll")
_pre_acts = set(bpy.data.actions)
_pre_objs = set(bpy.data.objects)
bpy.ops.import_scene.gltf(filepath=GLB_OUT)
stolen = {}
for a in list(bpy.data.actions):
    if a not in _pre_acts:
        if a.name in PRESERVE:
            a.use_fake_user = True
            stolen[a.name] = a
        else:
            bpy.data.actions.remove(a)
assert set(stolen) == set(PRESERVE), f"stolen={sorted(stolen)} expected {PRESERVE}"
for o in list(bpy.data.objects):
    if o not in _pre_objs:
        bpy.data.objects.remove(o, do_unlink=True)
print(f"STOLEN preserved clips: {sorted(stolen)}", flush=True)

# ---- weapon attach (script 86, UN-calibrated = Godot-true) ----
before2 = set(o.name for o in bpy.data.objects)
bpy.ops.import_scene.gltf(filepath=WEAPON_GLB)
weapon = max((o for o in bpy.data.objects if o.name not in before2 and o.type == "MESH"), key=lambda o: len(o.data.vertices))
Mi = weapon.matrix_world.inverted()
MARK_LOCAL = {k: Mi @ v for k, v in MARK_IMPORT.items()}
B_WR = tb["Weapon_R"].matrix_local.copy()
g0 = weapon.matrix_world @ MARK_LOCAL["grip"]
W_REST = Matrix.Translation(Vector(tb["Weapon_R"].head_local) - g0) @ weapon.matrix_world
loc, quat, scl = W_REST.decompose()
weapon.location = loc; weapon.rotation_mode = "QUATERNION"; weapon.rotation_quaternion = quat; weapon.scale = scl
co = weapon.constraints.new("CHILD_OF"); co.target = tgt; co.subtarget = "Weapon_R"; co.inverse_matrix = B_WR.inverted()
def marker(n):
    return weapon.matrix_world @ MARK_LOCAL[n]
def jp(n):
    return Vector(tgt.pose.bones[n].matrix.translation)

# ---- Fire vs Godot-true weapon orientation (measure, don't guess) ----
bpy.context.view_layer.objects.active = tgt
tad.action = stolen["Fire"]
if stolen["Fire"].slots:
    tad.action_slot = stolen["Fire"].slots[0]
fa, fb = (int(v) for v in stolen["Fire"].frame_range)
cants, wrists = [], []
for f in range(fa, fb + 1, 3):
    sc.frame_set(f); bpy.context.view_layer.update()
    bd = (marker("muzzle") - marker("receiver")).normalized()
    hd = (jp("Hand_L") - jp("Hand_R")).normalized()
    cants.append(math.degrees(bd.angle(hd)))
    wrists.append((jp("Hand_L") - marker("foregrip")).length * 1000)
print(f"FIRE-GODOT-TRUTH (un-calibrated weapon): barrel-vs-handaxis mean={sum(cants)/len(cants):.1f}deg "
      f"max={max(cants):.1f}deg; wrist->foregrip mean={sum(wrists)/len(wrists):.1f}mm max={max(wrists):.1f}mm", flush=True)

# ---- per-source retarget machinery (script 86, generalized) ----
def wq(M):
    return M.to_3x3().normalized().to_quaternion()

def bake_clip(out_name, fbx_name, s0, s1, n_out, seat):
    path = os.path.join(ROOT, fbx_name)
    before = set(o.name for o in bpy.data.objects)
    bpy.ops.import_scene.fbx(filepath=path)
    # FBX importer flips scene fps to the file rate (60); keys are already
    # placed by frame number, so just restore the 30 fps bake grid.
    sc.render.fps = 30
    sc.render.fps_base = 1.0
    src = next(o for o in bpy.data.objects if o.name not in before and o.type == "ARMATURE")
    for o in list(bpy.data.objects):
        if o.name not in before and o.type == "MESH":
            bpy.data.objects.remove(o, do_unlink=True)
    src_act = src.animation_data.action
    _mt = [t for t in MAP if t not in tb]
    _ms = [s for s in MAP.values() if s not in src.data.bones]
    assert not _mt and not _ms, f"MAP incomplete for {fbx_name}: tgt{_mt} src{_ms}"
    src.hide_render = True
    bpy.context.view_layer.update()
    MW = src.matrix_world.copy()
    toe_dir = (MW @ Vector(src.data.bones["mixamorig:LeftToeBase"].head_local)) - (MW @ Vector(src.data.bones["mixamorig:LeftFoot"].head_local))
    FC = Quaternion((0, 0, 1), math.pi) if toe_dir.y > 0 else Quaternion((1, 0, 0, 0))
    def corr_q(q):
        return FC @ q @ FC.inverted()
    def corr_v(v):
        return FC @ v
    def src_rest_head(n):
        return corr_v(MW @ Vector(src.data.bones[n].head_local))
    def src_rest_dir(n):
        b = src.data.bones[n]
        return corr_v(((MW @ Vector(b.tail_local)) - (MW @ Vector(b.head_local))).normalized())
    REST_Q_S = {n: corr_q(wq(MW @ src.data.bones[n].matrix_local)) for n in MAP.values()}
    SWING = {}
    for tbn, sbn in MAP.items():
        d_t = (Vector(tb[tbn].tail_local) - Vector(tb[tbn].head_local)).normalized()
        SWING[tbn] = d_t.rotation_difference(src_rest_dir(sbn))
    a = src_rest_head("mixamorig:LeftUpLeg"); b = src_rest_head("mixamorig:LeftLeg"); c = src_rest_head("mixamorig:LeftFoot")
    RATIO = LEG_T / ((b - a).length + (c - b).length)
    HIPS_REST_S = src_rest_head("mixamorig:Hips")
    # sample source at (possibly fractional / reversed) times
    times = [s0 + (s1 - s0) * (i / (n_out - 1)) for i in range(n_out)]
    rec, hips_traj = {}, {}
    for i, t in enumerate(times):
        fi = int(math.floor(t))
        sc.frame_set(fi, subframe=t - fi)
        bpy.context.view_layer.update()
        hips_traj[i] = corr_v(Vector((MW @ src.pose.bones["mixamorig:Hips"].matrix).translation))
        rec[i] = {sbn: corr_q(wq(MW @ src.pose.bones[sbn].matrix)) for sbn in MAP.values()}
    drift = hips_traj[n_out - 1] - hips_traj[0]
    def hips_t(i):
        t = i / (n_out - 1)
        p = hips_traj[i] - Vector((drift.x * t, drift.y * t, 0))
        return HIPS_REST_T + (p - HIPS_REST_S) * RATIO
    world, min_ankle = {}, 1e9
    for i in range(n_out):
        W = {}
        for bn in BONE_ORDER:
            b = tb[bn]
            if bn in MAP:
                Rw = rec[i][MAP[bn]] @ REST_Q_S[MAP[bn]].inverted() @ SWING[bn] @ REST_Q_T[bn]
            elif b.parent is not None:
                Rw = (W[b.parent.name].to_quaternion() @ REST_Q_T[b.parent.name].inverted()) @ REST_Q_T[bn]
            else:
                Rw = REST_Q_T[bn]
            if b.parent is None:
                pw = REST_HEAD[bn].copy()
            elif bn == "Hips":
                pw = hips_t(i)
            else:
                pn = b.parent.name
                Rp = W[pn].to_quaternion() @ REST_Q_T[pn].inverted()
                pw = W[pn].translation + Rp @ (REST_HEAD[bn] - REST_HEAD[pn])
            W[bn] = Matrix.LocRotScale(pw, Rw, (1, 1, 1))
        world[i] = W
        min_ankle = min(min_ankle, W["Foot_L"].translation.z, W["Foot_R"].translation.z)
    zoff = REST_HEAD["Foot_L"].z - min_ankle
    # key onto a fresh action (name freed by steal-cleanup / src renames)
    if out_name in bpy.data.actions:
        bpy.data.actions[out_name].name = f"OLD_{out_name}_88"
    nact = bpy.data.actions.new(out_name); nact.use_fake_user = True
    assert nact.name == out_name, f"action name collision: got {nact.name}"
    if len(nact.slots) == 0:
        nact.slots.new(id_type="OBJECT", name=tgt.name)
    tad.action = nact; tad.action_slot = nact.slots[0]
    if bpy.context.object and bpy.context.object.mode != "POSE":
        bpy.ops.object.mode_set(mode="POSE")
    for i in range(n_out):
        W = world[i]
        for bn in BONE_ORDER:
            b = tb[bn]
            m = W[bn].copy(); m.translation.z += zoff
            pm = W[b.parent.name].copy() if b.parent else Matrix.Identity(4)
            if b.parent: pm.translation.z += zoff
            basis = REST_LOCAL[bn].inverted() @ pm.inverted() @ m
            l, q, s = basis.decompose()
            pb = tgt.pose.bones[bn]
            pb.location = l; pb.rotation_mode = "QUATERNION"; pb.rotation_quaternion = q; pb.scale = s
            pb.keyframe_insert("location", frame=i); pb.keyframe_insert("rotation_quaternion", frame=i); pb.keyframe_insert("scale", frame=i)
    print(f"CLIP {out_name}: {fbx_name} src {s0}->{s1} -> {n_out}f ({(n_out-1)/30:.2f}s) "
          f"drift=({drift.x:.3f},{drift.y:.3f},{drift.z:.3f}) zoff={zoff*1000:+.1f}mm seat={seat}", flush=True)
    # pre-seat wrist distance (proof value of the seat / honesty for Reload)
    ds = []
    for i in range(0, n_out, 2):
        sc.frame_set(i); bpy.context.view_layer.update()
        ds.append((jp("Hand_L") - marker("foregrip")).length * 1000)
    print(f"  PRE-SEAT wrist->foregrip mm: first={ds[0]:.1f} last={ds[-1]:.1f} max={max(ds):.1f}", flush=True)
    if seat:
        FING_L = {f"{nm}{k}_L" for nm in ("Thumb", "Index", "Middle", "Ring", "Pinky") for k in (1, 2, 3)}
        SUBTREE = [bn for bn in BONE_ORDER if bn in ("UpperArm_L", "Forearm_L", "Hand_L") or bn in FING_L]
        seat_deficit = 0.0
        for i in range(n_out):
            sc.frame_set(i); bpy.context.view_layer.update()
            WE = {bn: tgt.pose.bones[bn].matrix.copy() for bn in BONE_ORDER}
            F = marker("foregrip")
            S = Vector(WE["UpperArm_L"].translation); E0 = Vector(WE["Forearm_L"].translation); W0 = Vector(WE["Hand_L"].translation)
            L1 = (E0 - S).length; L2 = (W0 - E0).length
            dvec = F - S; dist = dvec.length; dirv = dvec / dist
            seat_deficit = max(seat_deficit, dist - (L1 + L2))
            d = max(abs(L1 - L2) + 1e-5, min(dist, L1 + L2 - 1e-5))
            aa = (L1 * L1 - L2 * L2 + d * d) / (2.0 * d)
            h = math.sqrt(max(L1 * L1 - aa * aa, 0.0))
            pole = E0 - (S + dirv * (E0 - S).dot(dirv))
            pole = pole.normalized() if pole.length > 1e-6 else Vector((0, 0, -1))
            E1 = S + dirv * aa + pole * h
            T = S + dirv * d
            W2 = {}
            q1 = (E0 - S).normalized().rotation_difference((E1 - S).normalized())
            W2["UpperArm_L"] = Matrix.LocRotScale(S, q1 @ WE["UpperArm_L"].to_quaternion(), (1, 1, 1))
            q2 = (W0 - E0).normalized().rotation_difference((T - E1).normalized())
            W2["Forearm_L"] = Matrix.LocRotScale(E1, q2 @ WE["Forearm_L"].to_quaternion(), (1, 1, 1))
            W2["Hand_L"] = Matrix.LocRotScale(T, WE["Hand_L"].to_quaternion(), (1, 1, 1))
            for bn in SUBTREE:
                if bn in W2:
                    continue
                pn = tb[bn].parent.name
                PM = W2.get(pn, WE[pn])
                Rp = PM.to_quaternion() @ REST_Q_T[pn].inverted()
                pw = PM.translation + Rp @ (REST_HEAD[bn] - REST_HEAD[pn])
                W2[bn] = Matrix.LocRotScale(pw, WE[bn].to_quaternion(), (1, 1, 1))
            for bn in SUBTREE:
                pn = tb[bn].parent.name
                pm = W2.get(pn, WE[pn])
                basis = REST_LOCAL[bn].inverted() @ pm.inverted() @ W2[bn]
                l, q, s = basis.decompose()
                pb = tgt.pose.bones[bn]
                pb.location = l; pb.rotation_mode = "QUATERNION"; pb.rotation_quaternion = q; pb.scale = s
                pb.keyframe_insert("location", frame=i); pb.keyframe_insert("rotation_quaternion", frame=i); pb.keyframe_insert("scale", frame=i)
        post = []
        for i in range(n_out):
            sc.frame_set(i); bpy.context.view_layer.update()
            post.append((jp("Hand_L") - marker("foregrip")).length * 1000)
        post.sort()
        print(f"  POST-SEAT wrist->foregrip mm: p50={post[len(post)//2]:.1f} p95={post[int(len(post)*0.95)]:.1f} "
              f"max={post[-1]:.1f} reach_deficit={seat_deficit*1000:.1f}mm", flush=True)
        assert post[-1] < 40.0, f"foregrip seat failed on {out_name}"
    # fold screening (script-87 style; character faces -Y)
    bad_e = bad_k = 0
    rng = {k: [1e9, -1e9] for k in ("eL", "eR", "kL", "kR", "sL", "sR")}
    def ang_at(P, A, B):
        v1 = (A - P).normalized(); v2 = (B - P).normalized()
        return math.degrees(math.acos(max(-1.0, min(1.0, v1.dot(v2)))))
    def apex_fwd(S, E, W):
        ax = (W - S).normalized(); d = E - (S + ax * (E - S).dot(ax))
        return d.normalized().y if d.length > 1e-6 else 0.0
    for i in range(0, n_out, 2):
        sc.frame_set(i); bpy.context.view_layer.update()
        for side in ("L", "R"):
            S, E, Wd = jp(f"UpperArm_{side}"), jp(f"Forearm_{side}"), jp(f"Hand_{side}")
            ea = ang_at(E, S, Wd)
            rng[f"e{side}"][0] = min(rng[f"e{side}"][0], ea); rng[f"e{side}"][1] = max(rng[f"e{side}"][1], ea)
            if apex_fwd(S, E, Wd) < -0.35:
                bad_e += 1
            H, K, A = jp(f"UpperLeg_{side}"), jp(f"LowerLeg_{side}"), jp(f"Foot_{side}")
            ka = ang_at(K, H, A)
            rng[f"k{side}"][0] = min(rng[f"k{side}"][0], ka); rng[f"k{side}"][1] = max(rng[f"k{side}"][1], ka)
            if apex_fwd(H, K, A) > 0.35:
                bad_k += 1
            sh = ang_at(S, jp("Hips"), E)
            rng[f"s{side}"][0] = min(rng[f"s{side}"][0], sh); rng[f"s{side}"][1] = max(rng[f"s{side}"][1], sh)
    print(f"  FOLDS {out_name}: elbow-fwd-bad={bad_e} knee-back-bad={bad_k}; deg "
          + " ".join(f"{k}[{v[0]:.0f}..{v[1]:.0f}]" for k, v in rng.items()), flush=True)
    # cleanup source
    bpy.data.objects.remove(src, do_unlink=True)
    if src_act and src_act.name in bpy.data.actions:
        bpy.data.actions.remove(src_act)
    return nact

baked = {}
for cfg in CLIPS:
    baked[cfg[0]] = bake_clip(*cfg)
print(f"BAKED all: {sorted(baked)}", flush=True)

# ---- filmstrips (weapon attached; script-86 render setup) ----
if bpy.context.object and bpy.context.object.mode != "OBJECT":
    bpy.ops.object.mode_set(mode="OBJECT")
sc.render.engine = "CYCLES"; sc.cycles.samples = 16; sc.cycles.use_denoising = True; sc.cycles.device = "CPU"
w = bpy.data.worlds.new("W88"); sc.world = w; w.use_nodes = True
w.node_tree.nodes["Background"].inputs[0].default_value = (0.32, 0.33, 0.35, 1)
sd = bpy.data.lights.new("S88", "SUN"); sd.energy = 3.2
so = bpy.data.objects.new("S88", sd); sc.collection.objects.link(so)
so.rotation_euler = (math.radians(52), math.radians(8), math.radians(-38))
cam = bpy.data.objects.new("C88", bpy.data.cameras.new("C88")); sc.collection.objects.link(cam); sc.camera = cam
def shot(tag, loc, tp, size=520):
    cam.data.lens = 50; cam.location = loc
    cam.rotation_euler = (Vector(tp) - Vector(loc)).to_track_quat("-Z", "Y").to_euler()
    sc.render.resolution_x = sc.render.resolution_y = size
    sc.render.filepath = f"{OUT}/audit88_{tag}.png"
    bpy.ops.render.render(write_still=True)
    print("RENDERED", tag, flush=True)
def use(act):
    tad.action = act
    if act.slots:
        tad.action_slot = act.slots[0]
def strip(name, frames, views):
    use(baked[name])
    for f in frames:
        sc.frame_set(f); bpy.context.view_layer.update()
        for vn, loc, tp, sz in views:
            shot(f"{name}_f{f:03d}_{vn}", loc, tp, sz)
FRONT = ("front", (0, -1.85, 0.60), (0, -0.02, 0.52), 520)
SIDER = ("sideR", (-1.75, -0.10, 0.62), (-0.03, -0.04, 0.54), 520)
HANDS = ("hands", (-0.55, -0.78, 0.92), (-0.07, -0.18, 0.72), 700)
strip("Idle", [0, 25], [FRONT, SIDER])
strip("Aim_Idle", [46], [FRONT, SIDER, HANDS])
strip("Weapon_Raise", [0, 22, 45], [SIDER])
strip("Weapon_Lower", [22], [SIDER])
strip("Reload", [0, 18, 36, 54, 72], [FRONT])
strip("Reload", [36], [HANDS])

# ---- export (script-83 recipe; identity-based action cleanup) ----
import subprocess, sys as _sys, hashlib, struct
import numpy as np
KEEP_OBJS = set(baked.values()) | set(stolen.values())
for a in list(bpy.data.actions):
    if a not in KEEP_OBJS:
        bpy.data.actions.remove(a)
names = sorted(a.name for a in bpy.data.actions)
assert names == sorted(EXP_DUR), f"action set {names} != expected {sorted(EXP_DUR)}"
bpy.data.objects.remove(weapon, do_unlink=True)
sc.render.fps = 30
sc.render.fps_base = 1.0
assert sc.render.fps == 30 and sc.render.fps_base == 1.0, "export fps must be 30 (FBX importer flips it to 60)"
bpy.ops.object.select_all(action="DESELECT")
for o in (tgt, body):
    o.select_set(True)
bpy.context.view_layer.objects.active = tgt
bpy.ops.export_scene.gltf(filepath=GLB_OUT, export_format="GLB", use_selection=True, export_yup=True,
                          export_apply=False, export_skins=True, export_def_bones=False,
                          export_animations=True, export_animation_mode="ACTIONS",
                          export_force_sampling=True, export_optimize_animation_size=False,
                          export_materials="EXPORT")
print(f"EXPORTED {GLB_OUT} {os.path.getsize(GLB_OUT)} bytes", flush=True)
r = subprocess.run([_sys.executable, f"{PROJ}/tools/patch_glb_double_sided.py", GLB_OUT],
                   capture_output=True, text=True)
print(r.stdout.strip() or r.stderr.strip(), flush=True)
assert r.returncode == 0, "doubleSided patch failed"

from pygltflib import GLTF2
g = GLTF2().load(GLB_OUT)
def accessor_array(gltf, idx):
    acc = gltf.accessors[idx]
    bv = gltf.bufferViews[acc.bufferView]
    buf = gltf.buffers[bv.buffer]
    data = gltf.get_data_from_buffer_uri(buf.uri) if buf.uri else gltf.binary_blob()
    off = (bv.byteOffset or 0) + (acc.byteOffset or 0)
    comp = {5126: ("f", 4), 5123: ("H", 2), 5125: ("I", 4), 5121: ("B", 1)}[acc.componentType]
    ncomp = {"SCALAR": 1, "VEC2": 2, "VEC3": 3, "VEC4": 4, "MAT4": 16}[acc.type]
    fmt = "<" + comp[0] * ncomp * acc.count
    return np.array(struct.unpack_from(fmt, data, off), dtype=np.float64).reshape(acc.count, ncomp)
assert all(m.doubleSided for m in g.materials), "materials must be doubleSided"
joints = [g.nodes[j].name for j in g.skins[0].joints]
assert len(g.skins) == 1 and len(joints) == 54, f"skins={len(g.skins)} joints={len(joints)}"
prim = g.meshes[0].primitives[0]
ws = accessor_array(g, prim.attributes.WEIGHTS_0).sum(axis=1)
assert ws.min() > 0.999 and ws.max() < 1.001, f"weight sums {ws.min()}..{ws.max()}"
got = {}
for a in g.animations or []:
    dur = 0.0
    for smp in a.samplers:
        dur = max(dur, float(accessor_array(g, smp.input).max()))
    got[a.name] = round(dur, 3)
print("ANIMATIONS in GLB:", got, flush=True)
assert set(got) == set(EXP_DUR), f"anim set mismatch {set(got) ^ set(EXP_DUR)}"
for k, v in EXP_DUR.items():
    assert abs(got[k] - v) <= 0.06, f"duration mismatch {k}: got {got[k]}s expected ~{v}s"
md5 = hashlib.md5(open(GLB_OUT, "rb").read()).hexdigest()
print(f"joints=54 weights ok; GLB md5 {md5}", flush=True)

# ---- reimport proof: Aim_Idle from the exported file alone ----
bpy.ops.wm.read_factory_settings(use_empty=True)
sc2 = bpy.context.scene
sc2.render.fps = 30
bpy.ops.import_scene.gltf(filepath=GLB_OUT)
sc2.render.engine = "CYCLES"; sc2.cycles.samples = 16; sc2.cycles.use_denoising = True; sc2.cycles.device = "CPU"
w2 = bpy.data.worlds.new("WR88"); sc2.world = w2; w2.use_nodes = True
w2.node_tree.nodes["Background"].inputs[0].default_value = (0.32, 0.33, 0.35, 1)
sd2 = bpy.data.lights.new("SR88", "SUN"); sd2.energy = 3.2
so2 = bpy.data.objects.new("SR88", sd2); sc2.collection.objects.link(so2)
so2.rotation_euler = (math.radians(52), math.radians(8), math.radians(-38))
cam2 = bpy.data.objects.new("CR88", bpy.data.cameras.new("CR88")); sc2.collection.objects.link(cam2); sc2.camera = cam2
print("REIMPORT actions:", [a.name for a in bpy.data.actions], flush=True)
wact = next(a for a in bpy.data.actions if "Aim_Idle" in a.name)
arm2 = next(o for o in bpy.data.objects if o.type == "ARMATURE")
ad2 = arm2.animation_data_create() if not arm2.animation_data else arm2.animation_data
ad2.action = wact
if wact.slots:
    ad2.action_slot = wact.slots[0]
fmid = int(round((wact.frame_range[0] + wact.frame_range[1]) / 2))
sc2.frame_set(fmid); bpy.context.view_layer.update()
def shot2(tag, loc, tp, size=640):
    cam2.data.lens = 50; cam2.location = loc
    cam2.rotation_euler = (Vector(tp) - Vector(loc)).to_track_quat("-Z", "Y").to_euler()
    sc2.render.resolution_x = sc2.render.resolution_y = size
    sc2.render.filepath = f"{OUT}/audit88_{tag}.png"
    bpy.ops.render.render(write_still=True)
    print("RENDERED reimport", tag, flush=True)
shot2(f"reimport_aim_f{fmid}_south", (0.9, -1.5, 0.75), (0, 0, 0.5))
shot2(f"reimport_aim_f{fmid}_north", (0.9, 1.5, 0.75), (0, 0, 0.5))
print("DONE 88 (blend NOT saved; GLB carries Fire+Phase1 chain+Walk+Run+Roll)", flush=True)
