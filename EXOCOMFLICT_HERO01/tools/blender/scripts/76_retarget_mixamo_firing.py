"""76 - Retarget owner-supplied Mixamo 'Firing Rifle.fbx' onto NEW_HERO_01
(commit 087936e of the session branch). Same world-orientation transfer
as the UAL proof (script 75) + world-space source reading (FBX armature
is scaled 0.01 / axis-rotated) + facing correction + in-scene rifle
(Child Of on Weapon_R, script 69 method) with per-frame grip/barrel
metrics and a dense filmstrip for the owner's verdict.
Blend NOT saved; nothing exported. Proof stage only.
Run: tools/blender/run_bpy.sh tools/blender/scripts/76_retarget_mixamo_firing.py
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
nact = bpy.data.actions.new("MIXRET_Firing_Rifle"); nact.use_fake_user = True
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
print("BAKED MIXRET_Firing_Rifle", flush=True)

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

# ---- filmstrip ----
src.hide_render = True
sc.render.engine = "CYCLES"; sc.cycles.samples = 16; sc.cycles.use_denoising = True; sc.cycles.device = "CPU"
w = bpy.data.worlds.new("W76"); sc.world = w; w.use_nodes = True
w.node_tree.nodes["Background"].inputs[0].default_value = (0.32, 0.33, 0.35, 1)
sd = bpy.data.lights.new("S76", "SUN"); sd.energy = 3.2
so = bpy.data.objects.new("S76", sd); sc.collection.objects.link(so)
so.rotation_euler = (math.radians(52), math.radians(8), math.radians(-38))
cam = bpy.data.objects.new("C76", bpy.data.cameras.new("C76")); sc.collection.objects.link(cam); sc.camera = cam
def shot(tag, loc, tp, size=520):
    cam.data.lens = 50; cam.location = loc
    cam.rotation_euler = (Vector(tp) - Vector(loc)).to_track_quat("-Z", "Y").to_euler()
    sc.render.resolution_x = sc.render.resolution_y = size
    sc.render.filepath = f"{OUT}/audit77_{tag}.png"
    bpy.ops.render.render(write_still=True)
    print("RENDERED", tag, flush=True)
for fr in (0.0, 0.25, 0.5, 0.75, 1.0):
    f = int(round(f0 + fr * (f1 - f0)))
    sc.frame_set(f); bpy.context.view_layer.update()
    shot(f"firing_f{f:02d}_front", (0, -1.85, 0.60), (0, -0.02, 0.52))
    shot(f"firing_f{f:02d}_sideR", (-1.75, -0.10, 0.62), (-0.03, -0.04, 0.54))
f = int(round(f0 + 0.5 * (f1 - f0)))
sc.frame_set(f); bpy.context.view_layer.update()
shot(f"firing_f{f:02d}_hands", (-0.55, -0.78, 0.92), (-0.07, -0.18, 0.72), 700)
shot(f"firing_f{f:02d}_q3", (1.05, -1.25, 0.85), (0, -0.03, 0.56), 700)
tad.action = None
print("DONE 76 (blend NOT saved)", flush=True)
