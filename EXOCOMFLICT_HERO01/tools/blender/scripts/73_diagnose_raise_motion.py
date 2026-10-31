"""73 - FORENSIC diagnosis of the owner-REJECTED Phase-1 Raise (2026-10-31).
Owner verdict after watching the motion in Godot: hands/shoulders/elbows
all anatomically wrong, no proper joint folds. This script does NOT fix
anything. It (a) measures per-frame joint anatomy of Weapon_Raise
(elbow bend direction/angle, wrist bend vs forearm, left-hand distance
to the moving foregrip during transit - never checked before, only the
endpoint was), and (b) renders a dense front/side filmstrip + elbow
closeups so the failure modes are visible frame by frame.
Run: tools/blender/run_bpy.sh tools/blender/scripts/73_diagnose_raise_motion.py
"""
import bpy
import math
from mathutils import Vector

PROJ = "/home/user/Cyber-Strike/EXOCOMFLICT_HERO01"
BLEND = f"{PROJ}/blender/NEW_HERO_01_working.blend"
OUT = f"{PROJ}/screenshots/rig"
MARK_WORLD = {
    "foregrip": Vector((-0.215, -0.062, 0.315)),
    "grip": Vector((-0.192, -0.033, 0.452)),
}

bpy.ops.wm.open_mainfile(filepath=BLEND)
arm = bpy.data.objects["HERO_01_Armature"]
weapon = bpy.data.objects["HERO_01_WEAPON"]
sc = bpy.context.scene
ad = arm.animation_data

# marker locals from rest (frame 0 of Raise == bind pose, weapon at rest seat)
act = bpy.data.actions["Weapon_Raise"]
ad.action = act
if act.slots:
    ad.action_slot = act.slots[0]
sc.frame_set(0)
bpy.context.view_layer.update()
Mi = weapon.matrix_world.inverted()
MARK_LOCAL = {k: Mi @ v for k, v in MARK_WORLD.items()}

def jp(name):
    return Vector(arm.pose.bones[name].matrix.translation)

def elbow_stats(side):
    S = jp(f"UpperArm_{side}"); E = jp(f"Forearm_{side}"); W = jp(f"Hand_{side}")
    axis = (W - S).normalized()
    proj = S + axis * (E - S).dot(axis)
    edir = E - proj
    ln = edir.length
    d = edir / ln if ln > 1e-6 else Vector((0, 0, 0))
    ang = math.degrees((S - E).angle(W - E))
    return d, ang

def wrist_bend(side):
    fy = Vector(arm.pose.bones[f"Forearm_{side}"].matrix.col[1][:3]).normalized()
    hy = Vector(arm.pose.bones[f"Hand_{side}"].matrix.col[1][:3]).normalized()
    return math.degrees(fy.angle(hy))

print("f | elbR dir(x,y,z) ang | elbL dir ang | wristR wristL | Lhand->foregrip mm  (Blender: -Y=forward, +Y=behind, anatomical elbow points +Y/back & down)", flush=True)
for f in range(0, 37, 2):
    sc.frame_set(f)
    bpy.context.view_layer.update()
    dR, aR = elbow_stats("R"); dL, aL = elbow_stats("L")
    fg = weapon.matrix_world @ MARK_LOCAL["foregrip"]
    dw = (jp("Hand_L") - fg).length * 1000
    print(f"{f:2d} | R({dR.x:+.2f},{dR.y:+.2f},{dR.z:+.2f}) {aR:5.1f} | L({dL.x:+.2f},{dL.y:+.2f},{dL.z:+.2f}) {aL:5.1f} | {wrist_bend('R'):5.1f} {wrist_bend('L'):5.1f} | {dw:6.1f}", flush=True)

# ---- filmstrip renders ----
sc.render.engine = "CYCLES"; sc.cycles.samples = 16; sc.cycles.use_denoising = True; sc.cycles.device = "CPU"
world = bpy.data.worlds.new("W73"); sc.world = world; world.use_nodes = True
world.node_tree.nodes["Background"].inputs[0].default_value = (0.32, 0.33, 0.35, 1)
sd = bpy.data.lights.new("S73", "SUN"); sd.energy = 3.2
so = bpy.data.objects.new("S73", sd); sc.collection.objects.link(so)
so.rotation_euler = (math.radians(52), math.radians(8), math.radians(-38))
cam = bpy.data.objects.new("C73", bpy.data.cameras.new("C73")); sc.collection.objects.link(cam); sc.camera = cam

def shot(tag, loc, tgt, size=480):
    cam.data.lens = 50; cam.location = loc
    cam.rotation_euler = (Vector(tgt) - Vector(loc)).to_track_quat("-Z", "Y").to_euler()
    sc.render.resolution_x = sc.render.resolution_y = size
    sc.render.filepath = f"{OUT}/audit73_{tag}.png"
    bpy.ops.render.render(write_still=True)
    print("RENDERED", tag, flush=True)

for f in range(0, 37, 4):
    sc.frame_set(f)
    bpy.context.view_layer.update()
    shot(f"raise_f{f:02d}_front", (0, -1.85, 0.60), (0, -0.02, 0.52))
    shot(f"raise_f{f:02d}_sideR", (-1.75, -0.10, 0.62), (-0.03, -0.04, 0.54))

# elbow/shoulder fold closeups at deep-bend frames
sc.frame_set(36); bpy.context.view_layer.update()
eR = jp("Forearm_R"); eL = jp("Forearm_L")
shot("raise_f36_elbowR", tuple(eR + Vector((-0.34, -0.26, 0.10))), tuple(eR), 640)
shot("raise_f36_elbowL", tuple(eL + Vector((0.30, -0.30, 0.08))), tuple(eL), 640)
shot("raise_f36_shoulderL", (0.52, -0.62, 0.98), (0.10, -0.05, 0.80), 640)
print("DONE 73", flush=True)
