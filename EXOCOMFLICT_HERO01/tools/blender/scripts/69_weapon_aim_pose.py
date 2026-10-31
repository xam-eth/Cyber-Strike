"""69 v2 - NEW_HERO_01 animation foundation (TRIAL, does not save the blend):
attach the separate rifle to Weapon_R exactly as Godot does (grip-aligned,
via Child Of - Blender BONE parenting anchors at the bone tail, measured
54.4mm error in v1), solve the two-handed AIM pose with authoring IK +
torso blade (support-side forward - otherwise the foregrip is physically
out of the left arm's 0.327m reach), measure grips/barrel/clearances,
render inspection views. Script 70 reuses these constants to author clips.
Run: tools/blender/run_bpy.sh tools/blender/scripts/69_weapon_aim_pose.py
"""
import bpy
import math
import numpy as np
from mathutils import Vector, Matrix, Quaternion
from mathutils.kdtree import KDTree

PROJ = "/home/user/Cyber-Strike/EXOCOMFLICT_HERO01"
BLEND = f"{PROJ}/blender/NEW_HERO_01_working.blend"
WEAPON_GLB = f"{PROJ}/assets/weapons/HERO_01_WEAPON.glb"
OUT = f"{PROJ}/screenshots/rig"

MARK_WORLD = {
    "grip": Vector((-0.192, -0.033, 0.452)),
    "foregrip": Vector((-0.215, -0.062, 0.315)),
    "muzzle": Vector((-0.238, -0.080, 0.205)),
    "receiver": Vector((-0.198, -0.045, 0.500)),
}
GRIP_AIM = Vector((-0.118, -0.165, 0.755))
WRIST_L_OFFSET = Vector((0.015, 0.052, -0.038))
POLE_R = Vector((-0.48, 0.42, 0.42))
POLE_L = Vector((0.48, 0.42, 0.30))

bpy.ops.wm.open_mainfile(filepath=BLEND)
before = set(o.name for o in bpy.data.objects)
bpy.ops.import_scene.gltf(filepath=WEAPON_GLB)
new_objs = [o for o in bpy.data.objects if o.name not in before]
weapon = max((o for o in new_objs if o.type == "MESH"), key=lambda o: len(o.data.vertices))
wm = weapon.data
Wco = np.empty(len(wm.vertices) * 3); wm.vertices.foreach_get("co", Wco); Wco = Wco.reshape(-1, 3)
Mi = weapon.matrix_world.inverted()
MARK_LOCAL = {k: Mi @ v for k, v in MARK_WORLD.items()}

arm = bpy.data.objects["HERO_01_Armature"]
body = bpy.data.objects["HERO_01_BODY"]
bones = arm.data.bones
B_WEAPONR_REST = bones["Weapon_R"].matrix_local.copy()
REL_WR_IN_HAND = bones["Hand_R"].matrix_local.inverted() @ B_WEAPONR_REST
WPNR_HEAD = Vector(bones["Weapon_R"].head_local)

# grip-align at rest + Child Of follow (world = bone_world @ B_rest^-1 @ W_REST)
g0 = weapon.matrix_world @ MARK_LOCAL["grip"]
W_REST = Matrix.Translation(WPNR_HEAD - g0) @ weapon.matrix_world
loc, quat, scl = W_REST.decompose()
weapon.location = loc; weapon.rotation_mode = "QUATERNION"; weapon.rotation_quaternion = quat; weapon.scale = scl
co = weapon.constraints.new("CHILD_OF")
co.target = arm; co.subtarget = "Weapon_R"
co.inverse_matrix = B_WEAPONR_REST.inverted()
bpy.context.view_layer.update()
print(f"weapon ChildOf bound; grip at rest err={(weapon.matrix_world @ MARK_LOCAL['grip'] - WPNR_HEAD).length*1000:.2f} mm", flush=True)
C_OFFSET = B_WEAPONR_REST.inverted() @ W_REST

def marker_world(name):
    return weapon.matrix_world @ MARK_LOCAL[name]

def pb_world(bone):
    return arm.pose.bones[bone].matrix.copy()

bpy.context.view_layer.objects.active = arm
bpy.ops.object.mode_set(mode="POSE")
RESTMAT = {}
bpy.context.view_layer.update()
for p in arm.pose.bones:
    RESTMAT[p.name] = p.matrix.copy()
    p.rotation_mode = "QUATERNION"

def rot_world(bone, axis_world, deg):
    p = arm.pose.bones[bone]
    la = (RESTMAT[bone].to_3x3().inverted() @ Vector(axis_world)).normalized()
    p.rotation_quaternion = Quaternion(la, math.radians(deg)) @ p.rotation_quaternion
    bpy.context.view_layer.update()

# tracking verification
rot_world("UpperArm_R", (0, 1, 0), 60)
print(f"TRACKING posed: {(marker_world('grip') - pb_world('Weapon_R').translation).length*1000:.2f} mm", flush=True)
for p in arm.pose.bones:
    p.rotation_quaternion = Quaternion((1, 0, 0, 0)); p.location = (0, 0, 0); p.scale = (1, 1, 1)
bpy.context.view_layer.update()
print(f"TRACKING rest: {(marker_world('grip') - pb_world('Weapon_R').translation).length*1000:.2f} mm", flush=True)

# torso blade + head counter (support shoulder forward; 20deg total -
# 30deg sheared the abdominal suit too hard in the first iteration)
rot_world("Chest", (0, 0, 1), -10)
rot_world("UpperChest", (0, 0, 1), -10)
rot_world("Neck", (0, 0, 1), 11)
rot_world("Head", (0, 0, 1), 9)
rot_world("Head", (1, 0, 0), 5)

# ---------------- AIM solve ----------------
bw = np.array(marker_world("muzzle") - marker_world("receiver"), float); bw /= np.linalg.norm(bw)
up_raw = np.array(marker_world("receiver") - marker_world("grip"), float)
up_loc = up_raw - bw * (up_raw @ bw); up_loc /= np.linalg.norm(up_loc)
side_loc = np.cross(bw, up_loc)
FWD = np.array([0.0, -1.0, 0.0]); UPW = np.array([0.0, 0.0, 1.0])
side_w = np.cross(FWD, UPW)
R_aim = np.column_stack([FWD, UPW, side_w]) @ np.column_stack([bw, up_loc, side_loc]).T
g_rest = np.array(marker_world("grip"), float)
Mw_rest = np.array(weapon.matrix_world)
Mw_aim = np.eye(4)
Mw_aim[:3, :3] = R_aim @ Mw_rest[:3, :3]
Mw_aim[:3, 3] = R_aim @ (Mw_rest[:3, 3] - g_rest) + np.array(GRIP_AIM)
W_AIM = Matrix(Mw_aim.tolist())
HANDR_REQ = (W_AIM @ C_OFFSET.inverted()) @ REL_WR_IN_HAND.inverted()
F_AIM = W_AIM @ MARK_LOCAL["foregrip"]

def mk_empty(name, matrix):
    e = bpy.data.objects.new(name, None)
    e.empty_display_type = "PLAIN_AXES"; e.empty_display_size = 0.03
    e.hide_render = True
    bpy.context.collection.objects.link(e)
    e.matrix_world = matrix
    return e

ike_r = mk_empty("IKE_R", HANDR_REQ)
pole_r = mk_empty("IKE_R_POLE", Matrix.Translation(POLE_R))
Yd = Vector((0.08, -0.95, 0.30)).normalized()
Xd = Yd.cross(Vector((0, 0, 1))).normalized()
Zd = Xd.cross(Yd).normalized()
ML = Matrix.Identity(4)
ML.col[0][:3] = Xd; ML.col[1][:3] = Yd; ML.col[2][:3] = Zd
ML.translation = F_AIM + WRIST_L_OFFSET
ike_l = mk_empty("IKE_L", ML)
pole_l = mk_empty("IKE_L_POLE", Matrix.Translation(POLE_L))
for fname, ike, pole in (("Forearm_R", ike_r, pole_r), ("Forearm_L", ike_l, pole_l)):
    ik = arm.pose.bones[fname].constraints.new("IK")
    ik.target = ike; ik.pole_target = pole; ik.chain_count = 2
for hname, ike in (("Hand_R", ike_r), ("Hand_L", ike_l)):
    cr = arm.pose.bones[hname].constraints.new("COPY_ROTATION")
    cr.target = ike; cr.target_space = "WORLD"; cr.owner_space = "POSE"
bpy.context.view_layer.update()

bdir = (marker_world("muzzle") - marker_world("receiver")).normalized()
ang = math.degrees(math.acos(max(-1.0, min(1.0, bdir @ Vector((0, -1, 0))))))
print(f"AIM barrel vs forward: {ang:.2f} deg", flush=True)
print(f"AIM grip<->Weapon_R: {(marker_world('grip') - pb_world('Weapon_R').translation).length*1000:.2f} mm; grip={tuple(round(v,3) for v in marker_world('grip'))}", flush=True)
fw = marker_world("foregrip"); wl = pb_world("Hand_L").translation
print(f"AIM L wrist->foregrip: {(fw - wl).length*1000:.1f} mm  wrist={tuple(round(v,3) for v in wl)} fore={tuple(round(v,3) for v in fw)}", flush=True)
dg = bpy.context.evaluated_depsgraph_get()
eo = body.evaluated_get(dg); em = eo.to_mesh()
eco = np.empty(len(em.vertices) * 3); em.vertices.foreach_get("co", eco); eco = eco.reshape(-1, 3)
eo.to_mesh_clear()
torso = eco[(np.abs(eco[:, 0]) < 0.145) & (eco[:, 2] > 0.55) & (eco[:, 2] < 0.86)]
kt = KDTree(len(torso))
for i, c in enumerate(torso): kt.insert(c, i)
kt.balance()
Ww2 = np.array([weapon.matrix_world @ Vector(c) for c in Wco[::7]])
dmin = 1e9; near = 0
for c in Ww2:
    _, _, d = kt.find(c)
    dmin = min(dmin, d)
    if d < 0.004: near += 1
print(f"CLEARANCE weapon<->torso: min={dmin*1000:.1f} mm, samples <4mm: {near}/{len(Ww2)}", flush=True)

bpy.ops.object.mode_set(mode="OBJECT")
sc = bpy.context.scene
sc.render.engine = "CYCLES"; sc.cycles.samples = 28; sc.cycles.use_denoising = True; sc.cycles.device = "CPU"
world = bpy.data.worlds.new("W69"); sc.world = world; world.use_nodes = True
world.node_tree.nodes["Background"].inputs[0].default_value = (0.32, 0.33, 0.35, 1)
sd = bpy.data.lights.new("S69", "SUN"); sd.energy = 3.2
so = bpy.data.objects.new("S69", sd); sc.collection.objects.link(so)
so.rotation_euler = (math.radians(52), math.radians(8), math.radians(-38))
cam = bpy.data.objects.new("C69", bpy.data.cameras.new("C69")); sc.collection.objects.link(cam); sc.camera = cam
def render(tag, loc, tgt, size=780):
    cam.data.lens = 50; cam.location = loc
    cam.rotation_euler = (Vector(tgt) - Vector(loc)).to_track_quat("-Z", "Y").to_euler()
    sc.render.resolution_x = sc.render.resolution_y = size
    sc.render.filepath = f"{OUT}/audit69_{tag}.png"
    bpy.ops.render.render(write_still=True)
    print("RENDERED", tag, flush=True)
render("aim_front", (0, -1.8, 0.68), (0, -0.02, 0.58))
render("aim_3q", (1.05, -1.25, 0.85), (0, -0.03, 0.60))
render("aim_sideR", (-1.55, -0.25, 0.72), (-0.05, -0.03, 0.62))
render("aim_hands", (-0.55, -0.75, 0.92), (-0.07, -0.16, 0.72), 800)
render("aim_left", (0.75, -0.85, 0.90), (0.03, -0.16, 0.70), 800)
print("DONE 69 v2 (trial - blend NOT saved)", flush=True)
