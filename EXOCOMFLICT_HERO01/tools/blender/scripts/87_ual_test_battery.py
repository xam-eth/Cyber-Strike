"""87 - RIG TEST BATTERY on Rig v2: retarget five CC0 Quaternius UAL
clips (J-Ponzo glTF mirror, github J-Ponzo/gltf-universal-animation-
library, /tmp/ual) so the owner can judge EVERY bone/fold in motion:
  Idle_Loop -> Idle, Walk_Loop -> Walk, Sprint_Loop -> Run,
  Pistol_Reload -> Reload, Roll -> Roll (extreme full-body folds).
Method = script 75 world-direction transfer (owner-accepted proof)
extended to the 30 finger bones (DEF-f_*/thumb 1:1), timing-correct:
UAL is 24 fps; source poses are sampled at fractional frames onto the
30 fps bake grid so exported durations stay true. Root XY drift pinned
(in-place loops). No weapon prop (pure rig judgment; weapon carry is
proven by Fire/script 86). The shipped `Fire` action is preserved by
stealing it back from the current GLB before the multi-clip export.
Per clip: elbow/knee anatomical-direction warnings + fold-excursion
ranges printed; filmstrips audit87_*; export over HERO_01_RIGGED.glb
(script-83 recipe) + pygltflib verify + reimport proof renders.
Blend NOT saved.
Run: tools/blender/run_bpy.sh tools/blender/scripts/87_ual_test_battery.py
"""
import bpy
import math
import os, subprocess, sys as _sys, hashlib, struct
import numpy as np
from mathutils import Vector, Matrix, Quaternion

PROJ = "/home/user/Cyber-Strike/EXOCOMFLICT_HERO01"
BLEND = f"{PROJ}/blender/NEW_HERO_01_working.blend"
UAL = "/tmp/ual/glTF/AnimationLibrary_Godot_Standard.gltf"
GLB_OUT = f"{PROJ}/assets/characters/HERO_01_RIGGED.glb"
OUT = f"{PROJ}/screenshots/rig"
SRC_FPS = 24.0

MAP = {
    "Hips": "DEF-hips", "Spine": "DEF-spine.001", "Chest": "DEF-spine.002",
    "UpperChest": "DEF-spine.003", "Neck": "DEF-neck", "Head": "DEF-head",
    "Clavicle_L": "DEF-shoulder.L", "UpperArm_L": "DEF-upper_arm.L",
    "Forearm_L": "DEF-forearm.L", "Hand_L": "DEF-hand.L",
    "Clavicle_R": "DEF-shoulder.R", "UpperArm_R": "DEF-upper_arm.R",
    "Forearm_R": "DEF-forearm.R", "Hand_R": "DEF-hand.R",
    "UpperLeg_L": "DEF-thigh.L", "LowerLeg_L": "DEF-shin.L", "Foot_L": "DEF-foot.L", "Toe_L": "DEF-toe.L",
    "UpperLeg_R": "DEF-thigh.R", "LowerLeg_R": "DEF-shin.R", "Foot_R": "DEF-foot.R", "Toe_R": "DEF-toe.R",
}
for _st, _ss in (("L", "L"), ("R", "R")):
    for _k in (1, 2, 3):
        MAP[f"Thumb{_k}_{_st}"] = f"DEF-thumb.0{_k}.{_ss}"
        MAP[f"Index{_k}_{_st}"] = f"DEF-f_index.0{_k}.{_ss}"
        MAP[f"Middle{_k}_{_st}"] = f"DEF-f_middle.0{_k}.{_ss}"
        MAP[f"Ring{_k}_{_st}"] = f"DEF-f_ring.0{_k}.{_ss}"
        MAP[f"Pinky{_k}_{_st}"] = f"DEF-f_pinky.0{_k}.{_ss}"
CLIPS = [("Idle_Loop", "Idle"), ("Walk_Loop", "Walk"), ("Sprint_Loop", "Run"),
         ("Pistol_Reload", "Reload"), ("Roll", "Roll")]

bpy.ops.wm.open_mainfile(filepath=BLEND)
sc = bpy.context.scene
tgt = bpy.data.objects["HERO_01_Armature"]

# Import ORDER matters (run-1 bug): the glTF importer converts keyframe
# SECONDS to frames using the CURRENT scene fps. UAL is authored at
# 24 fps -> import it while scene fps = 24 so its frame numbers stay
# native; the shipped Fire GLB is 30 fps based -> steal it after
# switching the scene to 30 fps (bake/export grid).
sc.render.fps = 24
before = set(o.name for o in bpy.data.objects)
bpy.ops.import_scene.gltf(filepath=UAL)
src = next(o for o in bpy.data.objects if o.name not in before and o.type == "ARMATURE")
for o in list(bpy.data.objects):
    if o.name not in before and o.type == "MESH":
        bpy.data.objects.remove(o, do_unlink=True)
assert Vector(src.location).length < 1e-6 and (Vector(src.scale) - Vector((1, 1, 1))).length < 1e-6

# --- preserve shipped Fire: steal the action from the current GLB ---
# (scene now at the 30 fps bake/export grid so Fire keeps its timing)
sc.render.fps = 30
before = set(o.name for o in bpy.data.objects)
_pre_acts = set(bpy.data.actions)
bpy.ops.import_scene.gltf(filepath=GLB_OUT)
fire_act = next(a for a in bpy.data.actions if a.name == "Fire")
fire_act.use_fake_user = True
for o in list(bpy.data.objects):
    if o.name not in before:
        bpy.data.objects.remove(o, do_unlink=True)
print(f"PRESERVED Fire action (frames {fire_act.frame_range[0]}-{fire_act.frame_range[1]})", flush=True)
# The stolen GLB may also carry Idle/Walk/... from a previous run of
# this script; drop those copies NOW so actions.new(<clip>) below can
# never collide into "<clip>.001" while the export keeps the stale one
# (run-2 bug: exported durations silently stayed at run-1 timings).
for a in list(bpy.data.actions):
    if a not in _pre_acts and a.name in ("Idle", "Walk", "Run", "Reload", "Roll"):
        bpy.data.actions.remove(a)
assert len(tgt.data.bones) == 54
_mt = [t for t in MAP if t not in tgt.data.bones]
_ms = [s for s in MAP.values() if s not in src.data.bones]
assert not _mt and not _ms, f"MAP incomplete tgt{_mt} src{_ms}"
print(f"UAL src={src.name} MAP ok: {len(MAP)} pairs (22 body + 30 fingers)", flush=True)

tb = tgt.data.bones
BONE_ORDER = [b.name for b in tb]
REST_LOCAL, REST_Q_T, REST_HEAD = {}, {}, {}
for b in tb:
    REST_Q_T[b.name] = b.matrix_local.to_quaternion()
    REST_HEAD[b.name] = Vector(b.head_local)
    REST_LOCAL[b.name] = (b.parent.matrix_local.inverted() @ b.matrix_local) if b.parent else b.matrix_local.copy()
REST_Q_S = {b.name: b.matrix_local.to_quaternion() for b in src.data.bones}
SWING = {}
for tbn, sbn in MAP.items():
    d_t = (Vector(tb[tbn].tail_local) - Vector(tb[tbn].head_local)).normalized()
    d_s = (Vector(src.data.bones[sbn].tail_local) - Vector(src.data.bones[sbn].head_local)).normalized()
    SWING[tbn] = d_t.rotation_difference(d_s)
print("SWING UpperArm_R %.1f deg, Thumb1_R %.1f deg" % (
    math.degrees(SWING["UpperArm_R"].angle), math.degrees(SWING["Thumb1_R"].angle)), flush=True)
HIPS_REST_T = REST_HEAD["Hips"].copy()
HIPS_REST_S = Vector(src.data.bones["DEF-hips"].head_local)
def _hd(names, heads):
    return sum((heads[b] - heads[a]).length for a, b in zip(names, names[1:]))
LEG_T = _hd(["UpperLeg_L", "LowerLeg_L", "Foot_L"], REST_HEAD)
_srchead = {b.name: Vector(b.head_local) for b in src.data.bones}
LEG_S = _hd(["DEF-thigh.L", "DEF-shin.L", "DEF-foot.L"], _srchead)
RATIO = LEG_T / LEG_S
print(f"hip trajectory scale ratio (legs): {RATIO:.3f}", flush=True)

sad = src.animation_data
tad = tgt.animation_data_create()
bpy.context.view_layer.objects.active = tgt
bpy.ops.object.mode_set(mode="POSE")

def jp(n):
    return Vector(tgt.pose.bones[n].matrix.translation)
def fold_dir(a, b, c):
    A, B, C = jp(a), jp(b), jp(c)
    axis = (C - A).normalized()
    d = B - (A + axis * (B - A).dot(axis))
    return d.normalized() if d.length > 1e-6 else Vector()
def joint_angle(a, b, c):
    A, B, C = jp(a), jp(b), jp(c)
    return math.degrees((A - B).angle(C - B))

baked = {}
for srcname, outname in CLIPS:
    act = bpy.data.actions[srcname]
    if act.name == outname:
        act.name = f"SRC_{srcname}"  # free the target name (UAL 'Roll' collides)
    sad.action = act
    if act.slots:
        sad.action_slot = act.slots[0]
    sf0, sf1 = float(act.frame_range[0]), float(act.frame_range[1])
    dur = (sf1 - sf0) / SRC_FPS
    tframes = list(range(0, int(round(dur * 30.0)) + 1))
    rec, hips_traj = {}, {}
    for tf in tframes:
        sf = sf0 + (tf / 30.0) * SRC_FPS
        sc.frame_set(int(math.floor(sf)), subframe=sf - math.floor(sf))
        bpy.context.view_layer.update()
        hips_traj[tf] = Vector(src.pose.bones["DEF-hips"].matrix.translation)
        rec[tf] = {sb: src.pose.bones[sb].matrix.to_quaternion() for sb in MAP.values()}
    drift = hips_traj[tframes[-1]] - hips_traj[tframes[0]]
    span = max(1, tframes[-1] - tframes[0])
    print(f"CLIP {srcname} -> {outname}: src {sf0}-{sf1} ({dur:.2f}s) bake frames 0-{tframes[-1]} drift=({drift.x:.3f},{drift.y:.3f},{drift.z:.3f})", flush=True)
    def hips_t(f, _tr=hips_traj, _fr=tframes, _dr=drift, _sp=span):
        t = (f - _fr[0]) / _sp
        p = _tr[f] - Vector((_dr.x * t, _dr.y * t, 0))
        return HIPS_REST_T + (p - HIPS_REST_S) * RATIO
    world, min_ankle = {}, 1e9
    for f in tframes:
        W = {}
        for bn in BONE_ORDER:
            b = tb[bn]
            if bn in MAP:
                Rw = rec[f][MAP[bn]] @ REST_Q_S[MAP[bn]].inverted() @ SWING[bn] @ REST_Q_T[bn]
            elif b.parent is not None:
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
                Rp = W[pn].to_quaternion() @ REST_Q_T[pn].inverted()
                pw = W[pn].translation + Rp @ (REST_HEAD[bn] - REST_HEAD[pn])
            W[bn] = Matrix.LocRotScale(pw, Rw, (1, 1, 1))
        world[f] = W
        min_ankle = min(min_ankle, W["Foot_L"].translation.z, W["Foot_R"].translation.z)
    zoff = REST_HEAD["Foot_L"].z - min_ankle
    nact = bpy.data.actions.new(outname); nact.use_fake_user = True
    assert nact.name == outname, f"action name collision: got {nact.name}"
    if len(nact.slots) == 0:
        nact.slots.new(id_type="OBJECT", name=tgt.name)
    tad.action = nact; tad.action_slot = nact.slots[0]
    for f in tframes:
        W = world[f]
        for bn in BONE_ORDER:
            b = tb[bn]
            m = W[bn].copy(); m.translation.z += zoff
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
    baked[outname] = nact
    print(f"BAKED {outname} (zoff {zoff*1000:+.1f}mm)", flush=True)
    # anatomical sanity: elbow apex must point BACKWARD (+Y), knee FORWARD (-Y)
    bad_e = bad_k = 0
    angs = {"elbowL": [], "elbowR": [], "kneeL": [], "kneeR": [], "shL": [], "shR": []}
    for f in tframes[::2]:
        sc.frame_set(f); bpy.context.view_layer.update()
        for side in ("L", "R"):
            d = fold_dir(f"UpperArm_{side}", f"Forearm_{side}", f"Hand_{side}")
            if d.length > 0.5 and d.y < -0.1: bad_e += 1
            d = fold_dir(f"UpperLeg_{side}", f"LowerLeg_{side}", f"Foot_{side}")
            if d.length > 0.5 and d.y > 0.1: bad_k += 1
            angs[f"elbow{side}"].append(joint_angle(f"UpperArm_{side}", f"Forearm_{side}", f"Hand_{side}"))
            angs[f"knee{side}"].append(joint_angle(f"UpperLeg_{side}", f"LowerLeg_{side}", f"Foot_{side}"))
            angs[f"sh{side}"].append(joint_angle(f"Chest", f"UpperArm_{side}", f"Forearm_{side}"))
    rng = " ".join(f"{k}[{min(v):.0f}..{max(v):.0f}]" for k, v in angs.items())
    print(f"  FOLDS {outname}: elbow-fwd-bad={bad_e} knee-back-bad={bad_k}; joint angle ranges deg: {rng}", flush=True)
    tad.action = None

# sanity: preserved Fire still drives tgt
tad.action = fire_act
if fire_act.slots:
    tad.action_slot = fire_act.slots[0]
sc.frame_set(20); bpy.context.view_layer.update()
moved = (jp("Hand_R") - REST_HEAD["Hand_R"]).length
print(f"FIRE-PRESERVE check: Hand_R displacement @f20 = {moved*1000:.0f} mm", flush=True)
assert moved > 0.05, "stolen Fire action does not drive the target"
tad.action = None

# ---- filmstrips (audit87_*) ----
src.hide_render = True
sc.render.engine = "CYCLES"; sc.cycles.samples = 16; sc.cycles.use_denoising = True; sc.cycles.device = "CPU"
w = bpy.data.worlds.new("W87"); sc.world = w; w.use_nodes = True
w.node_tree.nodes["Background"].inputs[0].default_value = (0.32, 0.33, 0.35, 1)
sd = bpy.data.lights.new("S87", "SUN"); sd.energy = 3.2
so = bpy.data.objects.new("S87", sd); sc.collection.objects.link(so)
so.rotation_euler = (math.radians(52), math.radians(8), math.radians(-38))
cam = bpy.data.objects.new("C87", bpy.data.cameras.new("C87")); sc.collection.objects.link(cam); sc.camera = cam
def shot(tag, loc, tp, size=520):
    cam.data.lens = 50; cam.location = loc
    cam.rotation_euler = (Vector(tp) - Vector(loc)).to_track_quat("-Z", "Y").to_euler()
    sc.render.resolution_x = sc.render.resolution_y = size
    sc.render.filepath = f"{OUT}/audit87_{tag}.png"
    bpy.ops.render.render(write_still=True)
    print("RENDERED", tag, flush=True)
PLAN = {
    "Idle":   ([0.0, 0.5], ["front"]),
    "Walk":   ([0.0, 0.25, 0.5, 0.75], ["front", "sideR"]),
    "Run":    ([0.0, 0.25, 0.5, 0.75], ["front", "sideR"]),
    "Reload": ([0.0, 0.3, 0.55, 0.8], ["front"]),
    "Roll":   ([0.0, 0.2, 0.4, 0.6, 0.8], ["sideR"]),
}
for cname, (fracs, views) in PLAN.items():
    a = baked[cname]
    tad.action = a
    if a.slots:
        tad.action_slot = a.slots[0]
    f0, f1 = int(a.frame_range[0]), int(a.frame_range[1])
    for fr in fracs:
        f = int(round(f0 + fr * (f1 - f0)))
        sc.frame_set(f); bpy.context.view_layer.update()
        for v in views:
            if v == "front":
                shot(f"{cname}_f{f:02d}_front", (0, -1.85, 0.60), (0, -0.02, 0.52))
            else:
                shot(f"{cname}_f{f:02d}_sideR", (-1.75, -0.10, 0.62), (-0.03, -0.04, 0.54))
    if cname == "Reload":
        f = int(round(f0 + 0.55 * (f1 - f0)))
        sc.frame_set(f); bpy.context.view_layer.update()
        shot(f"Reload_f{f:02d}_hands", (-0.55, -0.78, 0.92), (-0.07, -0.18, 0.72), 700)
tad.action = None

# ---- export all six clips (script-83/86 recipe) ----
body = bpy.data.objects["HERO_01_BODY"]
bpy.data.objects.remove(src, do_unlink=True)
KEEP = {"Fire", "Idle", "Walk", "Run", "Reload", "Roll"}
KEEP_OBJS = set(baked.values()) | {fire_act}
for a in list(bpy.data.actions):
    if a not in KEEP_OBJS:
        bpy.data.actions.remove(a)
assert sorted(a.name for a in bpy.data.actions) == sorted(KEEP), [a.name for a in bpy.data.actions]
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
assert r.returncode == 0, f"doubleSided patch failed: {r.stderr}"
print("doubleSided patch ok", flush=True)

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
assert all(m.doubleSided for m in g.materials)
anims = g.animations or []
got = {}
for a in anims:
    got[a.name] = max(float(accessor_array(g, s.input).max()) for s in a.samplers)
print("ANIMATIONS in GLB:", {k: round(v, 3) for k, v in sorted(got.items())}, flush=True)
assert set(got) == KEEP, f"animation set mismatch {set(got) ^ KEEP}"
EXP_DUR = {"Fire": 1.400, "Idle": 2.500, "Walk": 1.333, "Run": 0.667, "Reload": 1.667, "Roll": 1.458}
for k, v in EXP_DUR.items():
    assert abs(got[k] - v) <= 0.06, f"duration mismatch {k}: got {got[k]:.3f}s expected ~{v}s (timing/stale-action bug)"
joints = [g.nodes[j].name for j in g.skins[0].joints]
assert len(joints) == 54, len(joints)
prim = g.meshes[0].primitives[0]
wts = accessor_array(g, prim.attributes.WEIGHTS_0); ws = wts.sum(axis=1)
assert ws.min() > 0.999 and ws.max() < 1.001
print(f"joints=54 weights ok; GLB md5 {hashlib.md5(open(GLB_OUT,'rb').read()).hexdigest()}", flush=True)

# ---- reimport proof: Walk renders from the file itself ----
bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.ops.import_scene.gltf(filepath=GLB_OUT)
sc2 = bpy.context.scene
sc2.render.engine = "CYCLES"; sc2.cycles.samples = 16; sc2.cycles.use_denoising = True; sc2.cycles.device = "CPU"
w2 = bpy.data.worlds.new("WR87"); sc2.world = w2; w2.use_nodes = True
w2.node_tree.nodes["Background"].inputs[0].default_value = (0.32, 0.33, 0.35, 1)
sd2 = bpy.data.lights.new("SR87", "SUN"); sd2.energy = 3.2
so2 = bpy.data.objects.new("SR87", sd2); sc2.collection.objects.link(so2)
so2.rotation_euler = (math.radians(52), math.radians(8), math.radians(-38))
cam2 = bpy.data.objects.new("CR87", bpy.data.cameras.new("CR87")); sc2.collection.objects.link(cam2); sc2.camera = cam2
arm2 = next(o for o in bpy.data.objects if o.type == "ARMATURE")
ad2 = arm2.animation_data
wact = next(a for a in bpy.data.actions if a.name == "Walk")
ad2.action = wact
if wact.slots:
    ad2.action_slot = wact.slots[0]
fmid = int(round((wact.frame_range[0] + wact.frame_range[1]) / 2))
sc2.frame_set(fmid); bpy.context.view_layer.update()
def shot2(tag, loc, tp, size=640):
    cam2.data.lens = 50; cam2.location = loc
    cam2.rotation_euler = (Vector(tp) - Vector(loc)).to_track_quat("-Z", "Y").to_euler()
    sc2.render.resolution_x = sc2.render.resolution_y = size
    sc2.render.filepath = f"{OUT}/audit87_{tag}.png"
    bpy.ops.render.render(write_still=True)
    print("RENDERED reimport", tag, flush=True)
shot2(f"reimport_walk_f{fmid:02d}_south", (0.9, -1.5, 0.75), (0, 0, 0.5))
shot2(f"reimport_walk_f{fmid:02d}_north", (0.9, 1.5, 0.75), (0, 0, 0.5))
print("DONE 87 (blend NOT saved; GLB now carries Fire+Idle+Walk+Run+Reload+Roll)", flush=True)
