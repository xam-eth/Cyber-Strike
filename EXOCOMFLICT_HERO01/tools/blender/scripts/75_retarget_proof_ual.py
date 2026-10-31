"""75 - Retarget PROOF (owner-chosen mocap path, 2026-10-31).
Retargets two Quaternius UAL clips (CC0, J-Ponzo glTF mirror cloned to
/tmp/ual) onto HERO_01 by world-space rotation-delta transfer + scaled
hips trajectory, bakes proof-only Actions, and renders dense filmstrips
for the owner's visual verdict. Blend is NOT saved; nothing is exported.
The identical method will be used for owner-supplied Mixamo FBX clips.
Run: tools/blender/run_bpy.sh tools/blender/scripts/75_retarget_proof_ual.py
"""
import bpy
import math
from mathutils import Vector, Matrix, Quaternion

PROJ = "/home/user/Cyber-Strike/EXOCOMFLICT_HERO01"
BLEND = f"{PROJ}/blender/NEW_HERO_01_working.blend"
UAL = "/tmp/ual/glTF/AnimationLibrary_Godot_Standard.gltf"
OUT = f"{PROJ}/screenshots/rig"

MAP = {  # target (HERO_01) -> source (UAL DEF)
    "Hips": "DEF-hips", "Spine": "DEF-spine.001", "Chest": "DEF-spine.002",
    "UpperChest": "DEF-spine.003", "Neck": "DEF-neck", "Head": "DEF-head",
    "Clavicle_L": "DEF-shoulder.L", "UpperArm_L": "DEF-upper_arm.L",
    "Forearm_L": "DEF-forearm.L", "Hand_L": "DEF-hand.L",
    "Clavicle_R": "DEF-shoulder.R", "UpperArm_R": "DEF-upper_arm.R",
    "Forearm_R": "DEF-forearm.R", "Hand_R": "DEF-hand.R",
    "UpperLeg_L": "DEF-thigh.L", "LowerLeg_L": "DEF-shin.L", "Foot_L": "DEF-foot.L", "Toe_L": "DEF-toe.L",
    "UpperLeg_R": "DEF-thigh.R", "LowerLeg_R": "DEF-shin.R", "Foot_R": "DEF-foot.R", "Toe_R": "DEF-toe.R",
}
CLIPS = ["Idle_Loop", "Walk_Loop"]

bpy.ops.wm.open_mainfile(filepath=BLEND)
sc = bpy.context.scene
sc.render.fps = 30
tgt = bpy.data.objects["HERO_01_Armature"]
before = set(o.name for o in bpy.data.objects)
bpy.ops.import_scene.gltf(filepath=UAL)
src = next(o for o in bpy.data.objects if o.name not in before and o.type == "ARMATURE")
for o in list(bpy.data.objects):
    if o.name not in before and o.type == "MESH":
        bpy.data.objects.remove(o, do_unlink=True)
print(f"SOURCE armature {src.name} loc={tuple(src.location)} scale={tuple(src.scale)}", flush=True)
assert Vector(src.location).length < 1e-6 and (Vector(src.scale) - Vector((1, 1, 1))).length < 1e-6

tb = tgt.data.bones
BONE_ORDER = [b.name for b in tb]
REST_LOCAL = {}
REST_Q_T = {}
REST_HEAD = {}
for b in tb:
    REST_Q_T[b.name] = b.matrix_local.to_quaternion()
    REST_HEAD[b.name] = Vector(b.head_local)
    REST_LOCAL[b.name] = (b.parent.matrix_local.inverted() @ b.matrix_local) if b.parent else b.matrix_local.copy()
REST_Q_S = {b.name: b.matrix_local.to_quaternion() for b in src.data.bones}
# Rest-pose direction alignment (T-pose source vs A-pose target): S_bone is
# the minimal swing taking the TARGET rest bone direction onto the SOURCE
# rest bone direction. World orientation transfer becomes
#   Rw_t(f) = Rw_s(f) * Rw_s_rest^-1 * S * Rw_t_rest
# which makes target bone WORLD DIRECTIONS equal the source's at every
# frame (no double-counting of the T->A rest difference on the arms).
SWING = {}
for tbn, sbn in MAP.items():
    d_t = (Vector(tb[tbn].tail_local) - Vector(tb[tbn].head_local)).normalized()
    d_s = (Vector(src.data.bones[sbn].tail_local) - Vector(src.data.bones[sbn].head_local)).normalized()
    SWING[tbn] = d_t.rotation_difference(d_s)
    print(f"SWING {tbn}: {math.degrees(SWING[tbn].angle):.1f} deg", flush=True)
HIPS_REST_T = REST_HEAD["Hips"].copy()
HIPS_REST_S = Vector(src.data.bones["DEF-hips"].head_local)
LEG_T = 0.2201 + 0.1865
LEG_S = (0.932 - 0.532) + (0.532 - 0.104)
RATIO = LEG_T / LEG_S
print(f"hip trajectory scale ratio (legs): {RATIO:.3f}", flush=True)
IDENT = Quaternion((1, 0, 0, 0))

sad = src.animation_data
tad = tgt.animation_data_create()
bpy.context.view_layer.objects.active = tgt
bpy.ops.object.mode_set(mode="POSE")

def elbow_dir(side):
    S = Vector(tgt.pose.bones[f"UpperArm_{side}"].matrix.translation)
    E = Vector(tgt.pose.bones[f"Forearm_{side}"].matrix.translation)
    W = Vector(tgt.pose.bones[f"Hand_{side}"].matrix.translation)
    axis = (W - S).normalized()
    proj = S + axis * (E - S).dot(axis)
    d = E - proj
    return d.normalized() if d.length > 1e-6 else Vector()

for clip in CLIPS:
    act = bpy.data.actions[clip]
    sad.action = act
    if act.slots:
        sad.action_slot = act.slots[0]
    f0, f1 = int(act.frame_range[0]), int(act.frame_range[1])
    frames = list(range(f0, f1 + 1))
    # --- pass 1: record source deltas + hips trajectory ---
    rec = {}
    hips_traj = {}
    for f in frames:
        sc.frame_set(f)
        bpy.context.view_layer.update()
        hips_traj[f] = Vector(src.pose.bones["DEF-hips"].matrix.translation)
        rec[f] = {sb: (p.matrix.to_quaternion()) for sb, p in ((sb, src.pose.bones[sb]) for sb in MAP.values())}
    drift = hips_traj[frames[-1]] - hips_traj[frames[0]]
    print(f"CLIP {clip}: frames {f0}-{f1} hips drift xy=({drift.x:.3f},{drift.y:.3f}) z={drift.z:.3f}", flush=True)
    span = max(1, frames[-1] - frames[0])
    def hips_t(f):
        t = (f - frames[0]) / span
        p = hips_traj[f] - Vector((drift.x * t, drift.y * t, 0))
        d = (p - HIPS_REST_S) * RATIO
        return HIPS_REST_T + d
    # --- pass 2: compose target world matrices; find ankle-z correction ---
    world = {}
    min_ankle = 1e9
    for f in frames:
        W = {}
        for bn in BONE_ORDER:
            b = tb[bn]
            if bn in MAP:
                Rw = rec[f][MAP[bn]] @ REST_Q_S[MAP[bn]].inverted() @ SWING[bn] @ REST_Q_T[bn]
            elif b.parent is not None:
                # unmapped (Weapon_R): follow parent rigidly
                Rp_delta = W[b.parent.name].to_quaternion() @ REST_Q_T[b.parent.name].inverted()
                Rw = Rp_delta @ REST_Q_T[bn]
            else:
                Rw = REST_Q_T[bn]
            if b.parent is None:
                pw = REST_HEAD[bn].copy()
            elif bn == "Hips":
                pw = hips_t(f)
            else:
                pn = b.parent.name
                d = REST_HEAD[bn] - REST_HEAD[pn]
                Rp = W[pn].to_quaternion() @ REST_Q_T[pn].inverted()
                pw = W[pn].translation + (Rp @ d)
            m = Matrix.LocRotScale(pw, Rw, (1, 1, 1))
            W[bn] = m
        world[f] = W
        min_ankle = min(min_ankle, W["Foot_L"].translation.z, W["Foot_R"].translation.z)
    ankle_rest = REST_HEAD["Foot_L"].z
    zoff = ankle_rest - min_ankle
    print(f"  ankle min z {min_ankle:.4f} vs rest {ankle_rest:.4f} -> hips z offset {zoff*1000:+.1f} mm", flush=True)
    # --- pass 3: basis extraction + bake ---
    nact = bpy.data.actions.new("UALRET_" + clip)
    nact.use_fake_user = True
    if len(nact.slots) == 0:
        nact.slots.new(id_type="OBJECT", name=tgt.name)
    tad.action = nact; tad.action_slot = nact.slots[0]
    # recompose with z offset applied through Hips position only (children follow via FK offsets)
    for f in frames:
        W = world[f]
        # shift whole-body world positions by zoff (rigid vertical shift)
        for bn in BONE_ORDER:
            b = tb[bn]
            m = W[bn].copy()
            m.translation.z += zoff
            pm = W[b.parent.name].copy() if b.parent else Matrix.Identity(4)
            if b.parent:
                pm.translation.z += zoff
            basis = REST_LOCAL[bn].inverted() @ pm.inverted() @ m
            l, q, s = basis.decompose()
            pb = tgt.pose.bones[bn]
            pb.location = l; pb.rotation_mode = "QUATERNION"; pb.rotation_quaternion = q; pb.scale = s
            pb.keyframe_insert("location", frame=f)
            pb.keyframe_insert("rotation_quaternion", frame=f)
            pb.keyframe_insert("scale", frame=f)
    print(f"BAKED UALRET_{clip}", flush=True)
    # sanity: elbow directions across the clip (anatomical = +Y behind)
    bad = 0
    for f in frames[::3]:
        sc.frame_set(f); bpy.context.view_layer.update()
        for side in ("L", "R"):
            d = elbow_dir(side)
            if d.length > 0.5 and d.y < 0:
                bad += 1
                print(f"  WARN {clip} f{f} elbow {side} points forward {tuple(round(v,2) for v in d)}", flush=True)
    print(f"  elbow-forward warnings: {bad}", flush=True)
    tad.action = None

# --- filmstrips ---
src.hide_render = True
sc.render.engine = "CYCLES"; sc.cycles.samples = 16; sc.cycles.use_denoising = True; sc.cycles.device = "CPU"
world_w = bpy.data.worlds.new("W75"); sc.world = world_w; world_w.use_nodes = True
world_w.node_tree.nodes["Background"].inputs[0].default_value = (0.32, 0.33, 0.35, 1)
sd = bpy.data.lights.new("S75", "SUN"); sd.energy = 3.2
so = bpy.data.objects.new("S75", sd); sc.collection.objects.link(so)
so.rotation_euler = (math.radians(52), math.radians(8), math.radians(-38))
cam = bpy.data.objects.new("C75", bpy.data.cameras.new("C75")); sc.collection.objects.link(cam); sc.camera = cam

def shot(tag, loc, tgtp):
    cam.data.lens = 50; cam.location = loc
    cam.rotation_euler = (Vector(tgtp) - Vector(loc)).to_track_quat("-Z", "Y").to_euler()
    sc.render.resolution_x = sc.render.resolution_y = 520
    sc.render.filepath = f"{OUT}/audit75_{tag}.png"
    bpy.ops.render.render(write_still=True)
    print("RENDERED", tag, flush=True)

PLAN = [("UALRET_Idle_Loop", [0.0, 0.33, 0.66], ["front"]),
        ("UALRET_Walk_Loop", [0.0, 0.25, 0.5, 0.75], ["sideR", "front"])]
for aname, fracs, views in PLAN:
    a = bpy.data.actions[aname]
    tad.action = a
    if a.slots:
        tad.action_slot = a.slots[0]
    f0, f1 = int(a.frame_range[0]), int(a.frame_range[1])
    for fr in fracs:
        f = int(round(f0 + fr * (f1 - f0)))
        sc.frame_set(f); bpy.context.view_layer.update()
        for v in views:
            if v == "front":
                shot(f"{aname}_f{f:02d}_front", (0, -1.85, 0.60), (0, -0.02, 0.52))
            else:
                shot(f"{aname}_f{f:02d}_sideR", (-1.75, -0.10, 0.62), (-0.03, -0.04, 0.54))
tad.action = None
print("DONE 75 (blend NOT saved)", flush=True)
