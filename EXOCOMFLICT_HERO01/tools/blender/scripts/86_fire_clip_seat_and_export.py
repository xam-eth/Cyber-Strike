"""86 - FIRST SHIPPED CLIP `Fire`: script-85 retarget + FOREGRIP SEAT
correction + bake + export into HERO_01_RIGGED.glb + verification.
Seat method: after the script-85 bake (measured on the evaluated pose,
script-76 marker method), per frame solve a two-bone IK for the LEFT
arm (UpperArm_L/Forearm_L) that swings the mocap wrist exactly onto
the rifle foregrip point, preserving the mocap elbow plane and the
mocap hand orientation; left fingers re-follow by FK. The weapon hangs
off Hand_R only, so the seat target is independent of the correction.
Root drift stays pinned (in-place advance) as in scripts 76/85.
Export follows script 83 (selection: deform armature + body) with the
single action named exactly `Fire`; pygltflib roundtrip asserts
(54 joints, exactly 1 animation `Fire`, weights, bbox, duration) and a
reimport proof render close the loop. Blend NOT saved.
Owner context (2026-11-02): un-pend the pipeline end-to-end with the
mocap already on hand instead of waiting for stationary downloads;
Idle/Weapon_Raise/Aim_Idle/Weapon_Lower still need stationary mocap.
Run: tools/blender/run_bpy.sh tools/blender/scripts/86_fire_clip_seat_and_export.py
"""
import bpy
import math
from mathutils import Vector, Matrix, Quaternion

PROJ = "/home/user/Cyber-Strike/EXOCOMFLICT_HERO01"
BLEND = f"{PROJ}/blender/NEW_HERO_01_working.blend"
FBX = "/home/user/Cyber-Strike/Firing Rifle.fbx"
WEAPON_GLB = f"{PROJ}/assets/weapons/HERO_01_WEAPON.glb"
OUT = f"{PROJ}/screenshots/rig"

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
# 85: finger extension (Mixamo has 4 segments/finger; map 1..3, drop tip 4)
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
tgt = bpy.data.objects["HERO_01_Armature"]
before = set(o.name for o in bpy.data.objects)
bpy.ops.import_scene.fbx(filepath=FBX)
src = next(o for o in bpy.data.objects if o.name not in before and o.type == "ARMATURE")
for o in list(bpy.data.objects):
    if o.name not in before and o.type == "MESH":
        bpy.data.objects.remove(o, do_unlink=True)
src_act = src.animation_data.action
print(f"SOURCE {src.name} action={src_act.name if src_act else None}", flush=True)
# 85 sanity: final rig = 54 bones; every mapped bone must exist on both sides
assert len(tgt.data.bones) == 54, f"target must be Rig v2 (54 bones), found {len(tgt.data.bones)}"
_missing_t = [t for t in MAP if t not in tgt.data.bones]
_missing_s = [s for s in MAP.values() if s not in src.data.bones]
assert not _missing_t and not _missing_s, f"MAP incomplete: tgt{_missing_t} src{_missing_s}"
print(f"MAP ok: {len(MAP)} bone pairs (22 body + 30 fingers)", flush=True)
bpy.context.view_layer.update()

MW = src.matrix_world.copy()
def src_rest_world(bone_name):
    b = src.data.bones[bone_name]
    return MW @ b.matrix_local
def wq(M):
    return M.to_3x3().normalized().to_quaternion()
# facing: target faces -Y; flip source world data 180deg about Z if needed
toe_dir = (MW @ Vector(src.data.bones["mixamorig:LeftToeBase"].head_local)) - (MW @ Vector(src.data.bones["mixamorig:LeftFoot"].head_local))
FACE = Quaternion((0, 0, 1), math.pi) if toe_dir.y > 0 else Quaternion((1, 0, 0, 0))
print(f"source toe dir world={tuple(round(v,3) for v in toe_dir)} -> face flip={'180' if toe_dir.y > 0 else 'none'}", flush=True)
FC = FACE
def corr_q(q):
    return FC @ q @ FC.inverted()
def corr_v(v):
    return FC @ v

REST_Q_S = {n: corr_q(wq(src_rest_world(n))) for n in MAP.values()}
def src_rest_head(n):
    return corr_v(MW @ Vector(src.data.bones[n].head_local))
def src_rest_dir(n):
    b = src.data.bones[n]
    return corr_v(((MW @ Vector(b.tail_local)) - (MW @ Vector(b.head_local))).normalized())

tb = tgt.data.bones
BONE_ORDER = [b.name for b in tb]
REST_LOCAL, REST_Q_T, REST_HEAD = {}, {}, {}
for b in tb:
    REST_Q_T[b.name] = b.matrix_local.to_quaternion()
    REST_HEAD[b.name] = Vector(b.head_local)
    REST_LOCAL[b.name] = (b.parent.matrix_local.inverted() @ b.matrix_local) if b.parent else b.matrix_local.copy()
SWING = {}
for tbn, sbn in MAP.items():
    d_t = (Vector(tb[tbn].tail_local) - Vector(tb[tbn].head_local)).normalized()
    SWING[tbn] = d_t.rotation_difference(src_rest_dir(sbn))
print("SWING UpperArm_R %.1f deg, UpperLeg_R %.1f deg" % (math.degrees(SWING["UpperArm_R"].angle), math.degrees(SWING["UpperLeg_R"].angle)), flush=True)

def leg_len_src():
    a = src_rest_head("mixamorig:LeftUpLeg"); b = src_rest_head("mixamorig:LeftLeg"); c = src_rest_head("mixamorig:LeftFoot")
    return (b - a).length + (c - b).length
LEG_T = (REST_HEAD["LowerLeg_L"] - REST_HEAD["UpperLeg_L"]).length + (REST_HEAD["Foot_L"] - REST_HEAD["LowerLeg_L"]).length
RATIO = LEG_T / leg_len_src()
HIPS_REST_T = REST_HEAD["Hips"].copy()
HIPS_REST_S = src_rest_head("mixamorig:Hips")
print(f"leg ratio {RATIO:.3f} (tgt {LEG_T:.3f} / src {leg_len_src():.3f})", flush=True)

# ---- weapon: seat + Child Of (script 69 method) ----
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

# ---- retarget ----
f0, f1 = int(src_act.frame_range[0]), int(src_act.frame_range[1])
frames = list(range(f0, f1 + 1))
rec, hips_traj = {}, {}
for f in frames:
    sc.frame_set(f); bpy.context.view_layer.update()
    hips_traj[f] = corr_v(Vector((MW @ src.pose.bones["mixamorig:Hips"].matrix).translation))
    rec[f] = {sbn: corr_q(wq(MW @ src.pose.bones[sbn].matrix)) for sbn in MAP.values()}
drift = hips_traj[frames[-1]] - hips_traj[frames[0]]
span = max(1, frames[-1] - frames[0])
def hips_t(f):
    t = (f - frames[0]) / span
    p = hips_traj[f] - Vector((drift.x * t, drift.y * t, 0))
    return HIPS_REST_T + (p - HIPS_REST_S) * RATIO
print(f"frames {f0}-{f1} drift=({drift.x:.3f},{drift.y:.3f},{drift.z:.3f}) m", flush=True)

world, min_ankle = {}, 1e9
for f in frames:
    W = {}
    for bn in BONE_ORDER:
        b = tb[bn]
        if bn in MAP:
            Rw = rec[f][MAP[bn]] @ REST_Q_S[MAP[bn]].inverted() @ SWING[bn] @ REST_Q_T[bn]
        elif b.parent is not None:
            Rw = (W[b.parent.name].to_quaternion() @ REST_Q_T[b.parent.name].inverted()) @ REST_Q_T[bn]
        else:
            Rw = REST_Q_T[bn]
        if b.parent is None:
            pw = REST_HEAD[bn].copy()
        elif bn == "Hips":
            pw = hips_t(f)
        else:
            pn = b.parent.name
            Rp = W[pn].to_quaternion() @ REST_Q_T[pn].inverted()
            pw = W[pn].translation + Rp @ (REST_HEAD[bn] - REST_HEAD[pn])
        W[bn] = Matrix.LocRotScale(pw, Rw, (1, 1, 1))
    world[f] = W
    min_ankle = min(min_ankle, W["Foot_L"].translation.z, W["Foot_R"].translation.z)
zoff = REST_HEAD["Foot_L"].z - min_ankle
print(f"ankle z offset {zoff*1000:+.1f} mm", flush=True)

bpy.context.view_layer.objects.active = tgt
bpy.ops.object.mode_set(mode="POSE")
tad = tgt.animation_data_create()
nact = bpy.data.actions.new("Fire"); nact.use_fake_user = True
if len(nact.slots) == 0:
    nact.slots.new(id_type="OBJECT", name=tgt.name)
tad.action = nact; tad.action_slot = nact.slots[0]
for f in frames:
    W = world[f]
    for bn in BONE_ORDER:
        b = tb[bn]
        m = W[bn].copy(); m.translation.z += zoff
        pm = W[b.parent.name].copy() if b.parent else Matrix.Identity(4)
        if b.parent: pm.translation.z += zoff
        basis = REST_LOCAL[bn].inverted() @ pm.inverted() @ m
        l, q, s = basis.decompose()
        pb = tgt.pose.bones[bn]
        pb.location = l; pb.rotation_mode = "QUATERNION"; pb.rotation_quaternion = q; pb.scale = s
        pb.keyframe_insert("location", frame=f); pb.keyframe_insert("rotation_quaternion", frame=f); pb.keyframe_insert("scale", frame=f)
print("BAKED Fire (pre-seat)", flush=True)

def jp(n):
    return Vector(tgt.pose.bones[n].matrix.translation)

# ---- weapon-axis CALIBRATION (constant, in Hand_R space) ----
# Mocap hands hold an imagined rifle; our rifle's in-hand orientation was
# authored against another pose, so the barrel crosses the body. Solve
# one constant rotation about the grip that aims the barrel axis at the
# average left-wrist position (in right-hand local space).
acc_p, acc_b = Vector(), Vector()
for f in frames[::3]:
    sc.frame_set(f); bpy.context.view_layer.update()
    HR = tgt.pose.bones["Hand_R"].matrix
    acc_p += HR.inverted() @ jp("Hand_L")
    bd = (marker("muzzle") - marker("receiver")).normalized()
    acc_b += HR.to_quaternion().inverted() @ bd
d_local = acc_p.normalized(); bd_local = acc_b.normalized()
Q_local = bd_local.rotation_difference(d_local)
print(f"CALIBRATION rotation {math.degrees(Q_local.angle):.1f} deg (barrel->two-hand axis, Hand_R space); mean hand spacing {(acc_p / len(frames[::3])).length:.3f} units", flush=True)
Q_world_rest = REST_Q_T["Hand_R"] @ Q_local @ REST_Q_T["Hand_R"].inverted()
grip_rest = Vector(tb["Weapon_R"].head_local)
W_REST2 = Matrix.Translation(grip_rest) @ Q_world_rest.to_matrix().to_4x4() @ Matrix.Translation(-grip_rest) @ W_REST
loc2, quat2, scl2 = W_REST2.decompose()
weapon.location = loc2; weapon.rotation_quaternion = quat2; weapon.scale = scl2
bpy.context.view_layer.update()

# ---- per-frame weapon metrics on the baked result ----
def jp(n):
    return Vector(tgt.pose.bones[n].matrix.translation)
print("f | barrel_deg | Lwrist->foregrip mm | elbR_y elbL_y | grip mm", flush=True)
worst = {"barrel": 0, "fore": 0}
for f in frames[::2]:
    sc.frame_set(f); bpy.context.view_layer.update()
    bd = (marker("muzzle") - marker("receiver")).normalized()
    ang = math.degrees(bd.angle(Vector((0, -1, 0))))
    dw = (jp("Hand_L") - marker("foregrip")).length * 1000
    # distance wrist->barrel segment (grip..muzzle)
    A, B, P = marker("grip"), marker("muzzle"), jp("Hand_L")
    AB = B - A; t = max(0.0, min(1.0, (P - A).dot(AB) / AB.dot(AB)))
    dl = (P - (A + AB * t)).length * 1000
    print(f"    wrist->barrel-line {dl:.1f} mm @t={t:.2f}", flush=True)
    def ey(side):
        S, E, Wp = jp(f"UpperArm_{side}"), jp(f"Forearm_{side}"), jp(f"Hand_{side}")
        ax = (Wp - S).normalized(); pr = S + ax * (E - S).dot(ax); d = E - pr
        return (d.normalized().y if d.length > 1e-6 else 0.0)
    gm = (jp("Weapon_R") - marker("grip")).length * 1000
    worst["barrel"] = max(worst["barrel"], ang); worst["fore"] = max(worst["fore"], dw)
    print(f"{f:3d} | {ang:6.2f} | {dw:7.1f} | {ey('R'):+.2f} {ey('L'):+.2f} | {gm:.1f}", flush=True)
print(f"WORST barrel {worst['barrel']:.2f} deg, foregrip dist {worst['fore']:.1f} mm", flush=True)

# ---- FOREGRIP SEAT correction (86): two-bone IK on the left arm ----
# Per frame, on the EVALUATED pre-seat pose: swing UpperArm_L/Forearm_L
# so the wrist lands exactly on the foregrip marker, preserving the
# mocap elbow plane and mocap hand orientation; L fingers follow by FK.
print("SEAT: solving left-arm IK onto foregrip...", flush=True)
FING_L = {f"{nm}{k}_L" for nm in ("Thumb", "Index", "Middle", "Ring", "Pinky") for k in (1, 2, 3)}
SUBTREE = [bn for bn in BONE_ORDER if bn in ("UpperArm_L", "Forearm_L", "Hand_L") or bn in FING_L]
seat_deficit = 0.0
for f in frames:
    sc.frame_set(f); bpy.context.view_layer.update()
    WE = {bn: tgt.pose.bones[bn].matrix.copy() for bn in BONE_ORDER}
    F = marker("foregrip")
    S = Vector(WE["UpperArm_L"].translation); E0 = Vector(WE["Forearm_L"].translation); W0 = Vector(WE["Hand_L"].translation)
    L1 = (E0 - S).length; L2 = (W0 - E0).length
    dvec = F - S; dist = dvec.length; dirv = dvec / dist
    seat_deficit = max(seat_deficit, dist - (L1 + L2))
    d = max(abs(L1 - L2) + 1e-5, min(dist, L1 + L2 - 1e-5))
    a = (L1 * L1 - L2 * L2 + d * d) / (2.0 * d)
    h = math.sqrt(max(L1 * L1 - a * a, 0.0))
    pole = E0 - (S + dirv * (E0 - S).dot(dirv))
    pole = pole.normalized() if pole.length > 1e-6 else Vector((0, 0, -1))
    E1 = S + dirv * a + pole * h
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
        pb.keyframe_insert("location", frame=f); pb.keyframe_insert("rotation_quaternion", frame=f); pb.keyframe_insert("scale", frame=f)
print(f"SEAT done; max reach deficit {seat_deficit*1000:.1f} mm (<=0 = always reachable)", flush=True)
post = []
for f in frames:
    sc.frame_set(f); bpy.context.view_layer.update()
    post.append((jp("Hand_L") - marker("foregrip")).length * 1000)
post.sort()
print(f"POST-SEAT wrist->foregrip mm: p50={post[len(post)//2]:.1f} p95={post[int(len(post)*0.95)]:.1f} max={post[-1]:.1f} (pre-seat worst {worst['fore']:.1f})", flush=True)
assert post[-1] < 40.0, "foregrip seat failed"

# ---- filmstrip (post-seat, audit86_*) ----
src.hide_render = True
sc.render.engine = "CYCLES"; sc.cycles.samples = 16; sc.cycles.use_denoising = True; sc.cycles.device = "CPU"
w = bpy.data.worlds.new("W86"); sc.world = w; w.use_nodes = True
w.node_tree.nodes["Background"].inputs[0].default_value = (0.32, 0.33, 0.35, 1)
sd = bpy.data.lights.new("S86", "SUN"); sd.energy = 3.2
so = bpy.data.objects.new("S86", sd); sc.collection.objects.link(so)
so.rotation_euler = (math.radians(52), math.radians(8), math.radians(-38))
cam = bpy.data.objects.new("C86", bpy.data.cameras.new("C86")); sc.collection.objects.link(cam); sc.camera = cam
def shot(tag, loc, tp, size=520):
    cam.data.lens = 50; cam.location = loc
    cam.rotation_euler = (Vector(tp) - Vector(loc)).to_track_quat("-Z", "Y").to_euler()
    sc.render.resolution_x = sc.render.resolution_y = size
    sc.render.filepath = f"{OUT}/audit86_{tag}.png"
    bpy.ops.render.render(write_still=True)
    print("RENDERED", tag, flush=True)
for fr in (0.0, 0.15, 0.3, 0.45, 0.6, 0.75, 0.9, 1.0):
    f = int(round(f0 + fr * (f1 - f0)))
    sc.frame_set(f); bpy.context.view_layer.update()
    shot(f"firing_f{f:02d}_front", (0, -1.85, 0.60), (0, -0.02, 0.52))
    shot(f"firing_f{f:02d}_sideR", (-1.75, -0.10, 0.62), (-0.03, -0.04, 0.54))
for fr in (0.35, 0.65):
    f = int(round(f0 + fr * (f1 - f0)))
    sc.frame_set(f); bpy.context.view_layer.update()
    shot(f"firing_f{f:02d}_hands", (-0.55, -0.78, 0.92), (-0.07, -0.18, 0.72), 700)
f = int(round(f0 + 0.5 * (f1 - f0)))
sc.frame_set(f); bpy.context.view_layer.update()
shot(f"firing_f{f:02d}_q3", (1.05, -1.25, 0.85), (0, -0.03, 0.56), 700)
shot(f"firing_f{f:02d}_shoulderL", (0.55, -0.75, 0.95), (0.22, -0.02, 0.74), 700)

# ---- export HERO_01_RIGGED.glb WITH the Fire clip (script-83 recipe) ----
import os, subprocess, sys as _sys, hashlib, struct
import numpy as np
GLB_OUT = f"{PROJ}/assets/characters/HERO_01_RIGGED.glb"
body = bpy.data.objects["HERO_01_BODY"]
# clean scene of retarget-source data so ACTIONS export contains only Fire
bpy.data.objects.remove(src, do_unlink=True)
for a in list(bpy.data.actions):
    if a != nact:
        bpy.data.actions.remove(a)
assert [a.name for a in bpy.data.actions] == ["Fire"], [a.name for a in bpy.data.actions]
if bpy.context.object and bpy.context.object.mode != "OBJECT":
    bpy.ops.object.mode_set(mode="OBJECT")
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
anims = g.animations or []
print(f"skins={len(g.skins)} animations={len(anims)} names={[a.name for a in anims]}", flush=True)
assert len(g.skins) == 1 and len(anims) == 1 and anims[0].name == "Fire", "need exactly one animation named Fire"
print(f"Fire channels={len(anims[0].channels)} samplers={len(anims[0].samplers)}", flush=True)
dur = 0.0
for smp in anims[0].samplers:
    tarr = accessor_array(g, smp.input)
    dur = max(dur, float(tarr.max()))
print(f"Fire duration = {dur:.4f} s", flush=True)
joints = [g.nodes[j].name for j in g.skins[0].joints]
EXPECTED = ["Root", "Hips", "Spine", "Chest", "UpperChest", "Neck", "Head",
            "Clavicle_L", "UpperArm_L", "Forearm_L", "Hand_L",
            "Clavicle_R", "UpperArm_R", "Forearm_R", "Hand_R", "Weapon_R",
            "UpperLeg_L", "LowerLeg_L", "Foot_L", "Toe_L",
            "UpperLeg_R", "LowerLeg_R", "Foot_R", "Toe_R"]
EXPECTED += [f"{fn}{k}_{s}" for fn in ("Thumb","Index","Middle","Ring","Pinky") for k in (1,2,3) for s in ("L","R")]
assert sorted(joints) == sorted(EXPECTED), f"joint mismatch: {set(joints) ^ set(EXPECTED)}"
prim = g.meshes[0].primitives[0]
pos = accessor_array(g, prim.attributes.POSITION)
wts = accessor_array(g, prim.attributes.WEIGHTS_0)
ws = wts.sum(axis=1)
print(f"verts={len(pos)} WEIGHTS_0 sum min={ws.min():.4f} max={ws.max():.4f} zero_rows={int((ws<=0).sum())}", flush=True)
assert ws.min() > 0.999 and ws.max() < 1.001
md5 = hashlib.md5(open(GLB_OUT, "rb").read()).hexdigest()
print(f"GLB md5 {md5}", flush=True)

# ---- reimport proof: the exported file animates standalone ----
bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.ops.import_scene.gltf(filepath=GLB_OUT)
sc2 = bpy.context.scene
sc2.render.engine = "CYCLES"; sc2.cycles.samples = 16; sc2.cycles.use_denoising = True; sc2.cycles.device = "CPU"
w2 = bpy.data.worlds.new("WR86"); sc2.world = w2; w2.use_nodes = True
w2.node_tree.nodes["Background"].inputs[0].default_value = (0.32, 0.33, 0.35, 1)
sd2 = bpy.data.lights.new("SR86", "SUN"); sd2.energy = 3.2
so2 = bpy.data.objects.new("SR86", sd2); sc2.collection.objects.link(so2)
so2.rotation_euler = (math.radians(52), math.radians(8), math.radians(-38))
cam2 = bpy.data.objects.new("CR86", bpy.data.cameras.new("CR86")); sc2.collection.objects.link(cam2); sc2.camera = cam2
acts = [a.name for a in bpy.data.actions]
print("REIMPORT actions:", acts, flush=True)
act = next(a for a in bpy.data.actions if "Fire" in a.name)
fmid = int(round((act.frame_range[0] + act.frame_range[1]) / 2))
sc2.frame_set(fmid); bpy.context.view_layer.update()
def shot2(tag, loc, tp, size=640):
    cam2.data.lens = 50; cam2.location = loc
    cam2.rotation_euler = (Vector(tp) - Vector(loc)).to_track_quat("-Z", "Y").to_euler()
    sc2.render.resolution_x = sc2.render.resolution_y = size
    sc2.render.filepath = f"{OUT}/audit86_{tag}.png"
    bpy.ops.render.render(write_still=True)
    print("RENDERED reimport", tag, flush=True)
shot2(f"reimport_f{fmid:02d}_south", (0.9, -1.5, 0.75), (0, 0, 0.5))
shot2(f"reimport_f{fmid:02d}_north", (0.9, 1.5, 0.75), (0, 0, 0.5))
print("DONE 86 (blend NOT saved; GLB exported with Fire)", flush=True)
