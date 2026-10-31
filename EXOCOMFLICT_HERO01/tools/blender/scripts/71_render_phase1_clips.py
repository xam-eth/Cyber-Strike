"""71 - Render key frames of the Phase-1 clips for visual deformation
inspection (audit only; blend not saved). Focus: waist/belt stillness
while the arms raise (owner's jacket test, now IN MOTION), two-handed
grip through Raise/Fire, armpit quality at aim.
Run: tools/blender/run_bpy.sh tools/blender/scripts/71_render_phase1_clips.py
"""
import bpy
import math
from mathutils import Vector

PROJ = "/home/user/Cyber-Strike/EXOCOMFLICT_HERO01"
BLEND = f"{PROJ}/blender/NEW_HERO_01_working.blend"
OUT = f"{PROJ}/screenshots/rig"

bpy.ops.wm.open_mainfile(filepath=BLEND)
arm = bpy.data.objects["HERO_01_Armature"]
sc = bpy.context.scene
ad = arm.animation_data
print("actions:", [a.name for a in bpy.data.actions], flush=True)

sc.render.engine = "CYCLES"; sc.cycles.samples = 28; sc.cycles.use_denoising = True; sc.cycles.device = "CPU"
world = bpy.data.worlds.new("W71"); sc.world = world; world.use_nodes = True
world.node_tree.nodes["Background"].inputs[0].default_value = (0.32, 0.33, 0.35, 1)
sd = bpy.data.lights.new("S71", "SUN"); sd.energy = 3.2
so = bpy.data.objects.new("S71", sd); sc.collection.objects.link(so)
so.rotation_euler = (math.radians(52), math.radians(8), math.radians(-38))
cam = bpy.data.objects.new("C71", bpy.data.cameras.new("C71")); sc.collection.objects.link(cam); sc.camera = cam

VIEWS = {
    "front": ((0, -1.85, 0.60), (0, -0.02, 0.52), 800),
    "q3": ((1.05, -1.25, 0.85), (0, -0.03, 0.56), 800),
    "waist": ((-0.42, -0.58, 0.64), (-0.06, -0.02, 0.50), 760),
    "hands": ((-0.55, -0.78, 0.92), (-0.07, -0.18, 0.72), 800),
}

def render(tag, view):
    loc, tgt, size = VIEWS[view]
    cam.data.lens = 50; cam.location = loc
    cam.rotation_euler = (Vector(tgt) - Vector(loc)).to_track_quat("-Z", "Y").to_euler()
    sc.render.resolution_x = sc.render.resolution_y = size
    sc.render.filepath = f"{OUT}/audit71_{tag}_{view}.png"
    bpy.ops.render.render(write_still=True)
    print("RENDERED", tag, view, flush=True)

SHOTS = [
    ("Weapon_Raise", 0, ["front"]),
    ("Weapon_Raise", 12, ["front", "waist"]),
    ("Weapon_Raise", 24, ["q3", "waist"]),
    ("Weapon_Raise", 36, ["front", "hands"]),
    ("Aim_Idle", 45, ["q3"]),
    ("Fire", 2, ["hands"]),
    ("Fire", 6, ["q3"]),
    ("Weapon_Lower", 12, ["front"]),
    ("Idle", 45, ["front"]),
]
for clip, f, views in SHOTS:
    act = bpy.data.actions[clip]
    ad.action = act
    if act.slots:
        ad.action_slot = act.slots[0]
    sc.frame_set(f)
    bpy.context.view_layer.update()
    for v in views:
        render(f"{clip}_f{f:02d}", v)
ad.action = None
print("DONE 71", flush=True)
