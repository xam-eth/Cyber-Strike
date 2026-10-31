"""70 - Author Phase-1 weapon-chain clips for NEW_HERO_01 and save the blend.
Owner directive 2026-10-31: animate - without animation the rig cannot be
judged. Clips: Idle (3.0s loop), Weapon_Raise (1.2s), Aim_Idle (3.0s loop),
Fire (0.4s), Weapon_Lower (0.8s) @30fps, built on script 69's verified aim
solve (Child Of rifle on Weapon_R, authoring IK, 20deg torso blade).
Poses are generated parametrically per frame (carry<->aim s-blend + breath/
sway/recoil accents), recorded as evaluated bone matrices, then baked into
clean bone-only Actions (constraints removed). Feet/legs are never keyed
(no Hips translation either) so feet stay mathematically planted.
Saves the working blend ONLY if every gate passes.
Run: tools/blender/run_bpy.sh tools/blender/scripts/70_author_phase1_clips.py
"""
import bpy
import math
import numpy as np
from mathutils import Vector, Matrix, Quaternion

PROJ = "/home/user/Cyber-Strike/EXOCOMFLICT_HERO01"
BLEND = f"{PROJ}/blender/NEW_HERO_01_working.blend"
WEAPON_GLB = f"{PROJ}/assets/weapons/HERO_01_WEAPON.glb"
FPS = 30

MARK_WORLD = {
    "grip": Vector((-0.192, -0.033, 0.452)),
    "foregrip": Vector((-0.215, -0.062, 0.315)),
    "muzzle": Vector((-0.238, -0.080, 0.205)),
    "receiver": Vector((-0.198, -0.045, 0.500)),
}
GRIP_AIM = Vector((-0.118, -0.165, 0.755))
WRIST_L_OFFSET = Vector((0.015, 0.052, -0.038))
POLE_R_AIM = Vector((-0.48, 0.42, 0.42))
POLE_L_AIM = Vector((0.48, 0.42, 0.30))

bpy.ops.wm.open_mainfile(filepath=BLEND)
sc = bpy.context.scene
sc.render.fps = FPS
before = set(o.name for o in bpy.data.objects)
bpy.ops.import_scene.gltf(filepath=WEAPON_GLB)
weapon = max((o for o in bpy.data.objects if o.name not in before and o.type == "MESH"),
             key=lambda o: len(o.data.vertices))
weapon.name = "HERO_01_WEAPON"
Mi = weapon.matrix_world.inverted()
MARK_LOCAL = {k: Mi @ v for k, v in MARK_WORLD.items()}

arm = bpy.data.objects["HERO_01_Armature"]
bones = arm.data.bones
B_WEAPONR_REST = bones["Weapon_R"].matrix_local.copy()
REL_WR_IN_HAND = bones["Hand_R"].matrix_local.inverted() @ B_WEAPONR_REST
WPNR_HEAD = Vector(bones["Weapon_R"].head_local)
g0 = weapon.matrix_world @ MARK_LOCAL["grip"]
W_REST = Matrix.Translation(WPNR_HEAD - g0) @ weapon.matrix_world
loc, quat, scl = W_REST.decompose()
weapon.location = loc; weapon.rotation_mode = "QUATERNION"; weapon.rotation_quaternion = quat; weapon.scale = scl
co = weapon.constraints.new("CHILD_OF")
co.target = arm; co.subtarget = "Weapon_R"
co.inverse_matrix = B_WEAPONR_REST.inverted()
C_OFFSET = B_WEAPONR_REST.inverted() @ W_REST

def marker_world(n):
    return weapon.matrix_world @ MARK_LOCAL[n]

bpy.context.view_layer.objects.active = arm
bpy.ops.object.mode_set(mode="POSE")
bpy.context.view_layer.update()
RESTMAT = {p.name: p.matrix.copy() for p in arm.pose.bones}
for p in arm.pose.bones:
    p.rotation_mode = "QUATERNION"
REST_LOCAL = {}
for b in bones:
    if b.parent:
        REST_LOCAL[b.name] = b.parent.matrix_local.inverted() @ b.matrix_local
    else:
        REST_LOCAL[b.name] = b.matrix_local.copy()

def world_delta_quat(bone, axis_world, deg):
    la = (RESTMAT[bone].to_3x3().inverted() @ Vector(axis_world)).normalized()
    return Quaternion(la, math.radians(deg))

IDENT_Q = Quaternion((1, 0, 0, 0))
# ---- captured AIM torso quaternions (script 69 constants) ----
AIM_Q = {}
for bn, ax, dg in (("Chest", (0, 0, 1), -10), ("UpperChest", (0, 0, 1), -10),
                   ("Neck", (0, 0, 1), 11), ("Head", (0, 0, 1), 9)):
    AIM_Q[bn] = world_delta_quat(bn, ax, dg)
AIM_Q["Head"] = world_delta_quat("Head", (1, 0, 0), 5) @ AIM_Q["Head"]
TORSO_BONES = list(AIM_Q.keys())

# ---- aim IK targets (script 69 solve) ----
bw = np.array(marker_world("muzzle") - marker_world("receiver"), float); bw /= np.linalg.norm(bw)
up_raw = np.array(marker_world("receiver") - marker_world("grip"), float)
up_loc = up_raw - bw * (up_raw @ bw); up_loc /= np.linalg.norm(up_loc)
side_loc = np.cross(bw, up_loc)
FWD = np.array([0.0, -1.0, 0.0]); UPW = np.array([0.0, 0.0, 1.0])
side_w = np.cross(FWD, UPW)
R_aim = np.column_stack([FWD, UPW, side_w]) @ np.column_stack([bw, up_loc, side_loc]).T
g_rest = np.array(marker_world("grip"), float)
Mw_rest = np.array(weapon.matrix_world)
Mw = np.eye(4); Mw[:3, :3] = R_aim @ Mw_rest[:3, :3]
Mw[:3, 3] = R_aim @ (Mw_rest[:3, 3] - g_rest) + np.array(GRIP_AIM)
W_AIM = Matrix(Mw.tolist())
IKE_R_AIM = (W_AIM @ C_OFFSET.inverted()) @ REL_WR_IN_HAND.inverted()
F_AIM = W_AIM @ MARK_LOCAL["foregrip"]
Yd = Vector((0.08, -0.95, 0.30)).normalized()
Xd = Yd.cross(Vector((0, 0, 1))).normalized()
Zd = Xd.cross(Yd).normalized()
IKE_L_AIM = Matrix.Identity(4)
IKE_L_AIM.col[0][:3] = Xd; IKE_L_AIM.col[1][:3] = Yd; IKE_L_AIM.col[2][:3] = Zd
IKE_L_AIM.translation = F_AIM + WRIST_L_OFFSET
IKE_R_REST = bones["Hand_R"].matrix_local.copy()
IKE_L_REST = bones["Hand_L"].matrix_local.copy()

def rest_pole(side):
    S = Vector(bones[f"UpperArm_{side}"].head_local)
    E = Vector(bones[f"Forearm_{side}"].head_local)
    W = Vector(bones[f"Hand_{side}"].head_local)
    axis = (W - S).normalized()
    proj = S + axis * (E - S).dot(axis)
    perp = (E - proj).normalized()
    return E + perp * 0.30
POLE_R_REST = rest_pole("R"); POLE_L_REST = rest_pole("L")

def mk_empty(name):
    e = bpy.data.objects.new(name, None)
    e.empty_display_type = "PLAIN_AXES"; e.empty_display_size = 0.03
    e.hide_render = True
    bpy.context.collection.objects.link(e)
    return e
IKE_R = mk_empty("IKE_R"); IKE_L = mk_empty("IKE_L")
P_R = mk_empty("IKE_R_POLE"); P_L = mk_empty("IKE_L_POLE")
for fname, ike, pole in (("Forearm_R", IKE_R, P_R), ("Forearm_L", IKE_L, P_L)):
    ik = arm.pose.bones[fname].constraints.new("IK")
    ik.target = ike; ik.pole_target = pole; ik.chain_count = 2
for hname, ike in (("Hand_R", IKE_R), ("Hand_L", IKE_L)):
    cr = arm.pose.bones[hname].constraints.new("COPY_ROTATION")
    cr.target = ike; cr.target_space = "WORLD"; cr.owner_space = "POSE"

def decompose_m(M):
    l, q, s = M.decompose()
    return l, q

def blend_mat(A, B, t):
    la, qa = decompose_m(A); lb, qb = decompose_m(B)
    return Matrix.LocRotScale(la.lerp(lb, t), qa.slerp(qb, t), (1, 1, 1))

def smoothstep(t):
    t = max(0.0, min(1.0, t))
    return t * t * (3 - 2 * t)

def eval_keys(keys, f):
    if f <= keys[0][0]: return keys[0][1]
    if f >= keys[-1][0]: return keys[-1][1]
    for (f0, v0), (f1, v1) in zip(keys, keys[1:]):
        if f0 <= f <= f1:
            return v0 + (v1 - v0) * smoothstep((f - f0) / max(1, f1 - f0))
    return keys[-1][1]

def apply_state(s, breath_deg=0.0, recoil=0.0, sway=Vector((0, 0, 0)), head_yaw_deg=0.0):
    e = smoothstep(s)
    for bn in TORSO_BONES:
        q = IDENT_Q.slerp(AIM_Q[bn], e)
        if bn == "Chest" and breath_deg:
            q = world_delta_quat(bn, (1, 0, 0), breath_deg) @ q
        if bn == "UpperChest" and breath_deg:
            q = world_delta_quat(bn, (1, 0, 0), breath_deg * 0.6) @ q
        if bn == "Chest" and recoil:
            q = world_delta_quat(bn, (1, 0, 0), -1.1 * recoil) @ q
        if bn == "Head" and recoil:
            q = world_delta_quat(bn, (1, 0, 0), -0.5 * recoil) @ q
        if bn == "Head" and head_yaw_deg:
            q = world_delta_quat(bn, (0, 0, 1), head_yaw_deg) @ q
        arm.pose.bones[bn].rotation_quaternion = q
    Mr = blend_mat(IKE_R_REST, IKE_R_AIM, e)
    Ml = blend_mat(IKE_L_REST, IKE_L_AIM, e)
    if sway.length > 0:
        Mr.translation += sway; Ml.translation += sway
    if recoil:
        back = Vector((0, 0.016, 0.009)) * recoil
        Mr.translation += back; Ml.translation += back
        Rx = Matrix.Rotation(math.radians(-1.9 * recoil), 4, "X")
        Mr = Matrix.Translation(GRIP_AIM) @ Rx @ Matrix.Translation(-GRIP_AIM) @ Mr
        Ml = Matrix.Translation(GRIP_AIM) @ Rx @ Matrix.Translation(-GRIP_AIM) @ Ml
    IKE_R.matrix_world = Mr
    IKE_L.matrix_world = Ml
    P_R.matrix_world = Matrix.Translation(POLE_R_REST.lerp(POLE_R_AIM, e))
    P_L.matrix_world = Matrix.Translation(POLE_L_REST.lerp(POLE_L_AIM, e))
    bpy.context.view_layer.update()

BONE_ORDER = [b.name for b in bones]
def record_frame(store, f):
    rec = {}
    mats = {p.name: p.matrix.copy() for p in arm.pose.bones}
    for bn in BONE_ORDER:
        b = bones[bn]
        pm = mats[b.parent.name] if b.parent else Matrix.Identity(4)
        basis = REST_LOCAL[bn].inverted() @ pm.inverted() @ mats[bn]
        l, q, s = basis.decompose()
        rec[bn] = (Vector(l), Quaternion(q), Vector(s))
    store[f] = rec
    gw = marker_world("grip"); fw = marker_world("foregrip")
    wl = arm.pose.bones["Hand_L"].matrix.translation
    bd = (marker_world("muzzle") - marker_world("receiver")).normalized()
    ang = math.degrees(math.acos(max(-1.0, min(1.0, bd @ Vector((0, -1, 0))))))
    return dict(grip=tuple(gw), fore_d=(fw - wl).length, barrel=ang)

RECOIL = [0, .55, 1, .82, .6, .42, .28, .17, .09, .04, .01, 0, 0]
CLIPS = {}
def build_clip(name, nframes, fn):
    store = {}; metrics = []
    for f in range(nframes + 1):
        fn(f)
        metrics.append(record_frame(store, f))
    CLIPS[name] = (store, metrics)
    print(f"CLIP {name}: {nframes+1} frames recorded", flush=True)

def breath(f, period=45.0, amp=0.55):
    return amp * math.sin(2 * math.pi * f / period)

build_clip("Idle", 90, lambda f: apply_state(
    0.0, breath_deg=breath(f), sway=Vector((0.0006 * math.sin(2 * math.pi * f / 90.0), 0, 0.0011 * math.sin(2 * math.pi * f / 45.0))),
    head_yaw_deg=1.3 * math.sin(2 * math.pi * f / 90.0)))
RAISE_KEYS = [(0, 0.0), (6, 0.10), (12, 0.38), (20, 0.74), (27, 0.93), (32, 1.0), (36, 1.0)]
build_clip("Weapon_Raise", 36, lambda f: apply_state(
    eval_keys(RAISE_KEYS, f), breath_deg=breath(f) * math.sin(math.pi * f / 36.0)))
build_clip("Aim_Idle", 90, lambda f: apply_state(
    1.0, breath_deg=breath(f, 45.0, 0.4),
    sway=Vector((0.0011 * math.sin(2 * math.pi * f / 90.0), 0, 0.0009 * math.sin(2 * math.pi * f / 45.0 + 1.2)))))
build_clip("Fire", 12, lambda f: apply_state(1.0, recoil=RECOIL[f]))
LOWER_KEYS = [(0, 1.0), (5, 0.80), (11, 0.45), (17, 0.16), (21, 0.03), (24, 0.0)]
build_clip("Weapon_Lower", 24, lambda f: apply_state(
    eval_keys(LOWER_KEYS, f), breath_deg=breath(f) * math.sin(math.pi * f / 24.0)))

# ---- gates on recorded data ----
def basis_delta(a, b):
    (la, qa, _), (lb, qb, _) = a, b
    return (la - lb).length, math.degrees(qa.rotation_difference(qb).angle)
gates = []
for name, (store, metrics) in CLIPS.items():
    # legs/hips identity (feet planted by construction)
    worst = 0.0
    for f, rec in store.items():
        for bn in ("Hips", "UpperLeg_L", "LowerLeg_L", "Foot_L", "Toe_L", "UpperLeg_R", "LowerLeg_R", "Foot_R", "Toe_R", "Root"):
            dl, da = basis_delta(rec[bn], (Vector(), IDENT_Q, Vector((1, 1, 1))))
            worst = max(worst, dl, da / 1000.0)
    gates.append((f"{name}: legs/root identity (worst {worst*1000:.3f} mm-equiv)", worst < 0.0005))
    print(f"GATE {name} legs/root identity worst={worst*1000:.3f}mm", flush=True)
for name in ("Idle", "Aim_Idle"):
    store = CLIPS[name][0]
    n = max(store.keys())
    dmax = 0.0
    for bn in BONE_ORDER:
        dl, da = basis_delta(store[0][bn], store[n][bn])
        dmax = max(dmax, dl * 1000, da)
    gates.append((f"{name}: loop closure ({dmax:.3f} mm/deg)", dmax < 0.5))
    print(f"GATE {name} loop closure max={dmax:.3f}", flush=True)
wr = CLIPS["Weapon_Raise"][1]
print(f"METRIC Raise end: L wrist->foregrip {wr[-1]['fore_d']*1000:.1f} mm, barrel {wr[-1]['barrel']:.2f} deg", flush=True)
gates.append(("Raise ends at aim (barrel<1deg)", wr[-1]["barrel"] < 1.0))
ai = CLIPS["Aim_Idle"][1]
bmax = max(m["barrel"] for m in ai)
print(f"METRIC Aim_Idle barrel sway max {bmax:.2f} deg; fore_d range {min(m['fore_d'] for m in ai)*1000:.1f}-{max(m['fore_d'] for m in ai)*1000:.1f} mm", flush=True)
gates.append(("Aim_Idle barrel sway <1deg", bmax < 1.0))
fi = CLIPS["Fire"][1]
print(f"METRIC Fire barrel: f0 {fi[0]['barrel']:.2f} peak {max(m['barrel'] for m in fi):.2f} end {fi[-1]['barrel']:.2f} deg", flush=True)
gates.append(("Fire recovers to aim", fi[-1]["barrel"] < 0.3 and max(m["barrel"] for m in fi) > 1.0))

# ---- bake into clean actions ----
for p in arm.pose.bones:
    for c in list(p.constraints):
        p.constraints.remove(c)
    p.rotation_quaternion = IDENT_Q; p.location = (0, 0, 0); p.scale = (1, 1, 1)
bpy.context.view_layer.update()
ad = arm.animation_data_create()
FORCE_REST = {"Idle": (0, 90), "Weapon_Raise": (0,), "Weapon_Lower": (24,)}
for name, (store, metrics) in CLIPS.items():
    act = bpy.data.actions.new(name)
    act.use_fake_user = True
    if len(act.slots) == 0:
        act.slots.new(id_type="OBJECT", name=arm.name)
    ad.action = act
    ad.action_slot = act.slots[0]
    for f in sorted(store.keys()):
        rec = store[f]
        force = f in FORCE_REST.get(name, ())
        for bn in BONE_ORDER:
            pb = arm.pose.bones[bn]
            if force:
                pb.location = (0, 0, 0); pb.rotation_quaternion = IDENT_Q; pb.scale = (1, 1, 1)
            else:
                l, q, s = rec[bn]
                pb.location = l; pb.rotation_quaternion = q; pb.scale = s
            pb.keyframe_insert("location", frame=f)
            pb.keyframe_insert("rotation_quaternion", frame=f)
            pb.keyframe_insert("scale", frame=f)
    print(f"BAKED {name}", flush=True)
ad.action = None

# ---- post-bake verification (baked pose vs recorded metrics) ----
worst_grip = 0.0
for name, (store, metrics) in CLIPS.items():
    ad.action = bpy.data.actions[name]
    ad.action_slot = bpy.data.actions[name].slots[0]
    for f in (0, len(metrics) // 2, len(metrics) - 1):
        sc.frame_set(f)
        bpy.context.view_layer.update()
        d = (marker_world("grip") - Vector(metrics[f]["grip"])).length * 1000
        worst_grip = max(worst_grip, d)
    print(f"VERIFY {name}: grip delta so far {worst_grip:.2f} mm", flush=True)
ad.action = None
gates.append((f"baked==authored grip (worst {worst_grip:.2f} mm)", worst_grip < 1.5))

failed = [g for g, ok in gates if not ok]
for g, ok in gates:
    print(("GATE PASS  " if ok else "GATE FAIL  ") + g, flush=True)
assert not failed, f"gates failed: {failed}"

# ---- cleanup + save ----
for e in (IKE_R, IKE_L, P_R, P_L):
    bpy.data.objects.remove(e, do_unlink=True)
for p in arm.pose.bones:
    p.rotation_quaternion = IDENT_Q; p.location = (0, 0, 0); p.scale = (1, 1, 1)
sc.frame_set(0)
sc.frame_start = 0; sc.frame_end = 90
bpy.context.view_layer.objects.active = arm
bpy.ops.object.mode_set(mode="OBJECT")
bpy.context.preferences.filepaths.use_file_compression = True
bpy.ops.wm.save_as_mainfile(filepath=BLEND, compress=True)
print(f"ACTIONS: {[a.name for a in bpy.data.actions]}", flush=True)
print(f"SAVED {BLEND}", flush=True)
print("DONE 70", flush=True)
