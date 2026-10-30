"""Visual verification renders for the Phase-1 weapon chain (script 47).
Renders key frames from Idle / Weapon_Raise / Aim_Idle / Fire / Weapon_Lower in
front-left and left-profile views (the undersuit/hip inspection angles).
Writes screenshots/animation/phase1/*.png. Does NOT save the blend."""
import bpy, math, os
from mathutils import Vector

PROJ = "/home/user/Cyber-Strike/EXOCOMFLICT_HERO01"
OUT = f"{PROJ}/screenshots/animation/phase1"
os.makedirs(OUT, exist_ok=True)
bpy.ops.wm.open_mainfile(filepath=f"{PROJ}/blender/HERO_01_working.blend")
sc = bpy.context.scene
arm = bpy.data.objects["HERO_01_Armature"]
ad = arm.animation_data

def set_action(name):
    act = bpy.data.actions[name]
    ad.action = act
    try:
        if len(act.slots):
            ad.action_slot = act.slots[0]
    except Exception as ex:
        print("slot:", ex)
    return act

sc.render.engine = "CYCLES"
sc.cycles.samples = 16
sc.cycles.use_denoising = True
sc.cycles.device = "CPU"
sc.cycles.seed = 7
w = bpy.data.worlds.new("WPhase1")
sc.world = w
w.use_nodes = True
w.node_tree.nodes["Background"].inputs[0].default_value = (0.16, 0.17, 0.19, 1)
w.node_tree.nodes["Background"].inputs[1].default_value = 0.9
sd = bpy.data.lights.new("SunP1", "SUN")
sd.energy = 3
so = bpy.data.objects.new("SunP1", sd)
sc.collection.objects.link(so)
so.rotation_euler = (math.radians(52), math.radians(8), math.radians(-38))
cam = bpy.data.objects.new("CamP1", bpy.data.cameras.new("CamP1"))
cam.data.lens = 52
sc.collection.objects.link(cam)
sc.camera = cam
arm.hide_render = True
sc.render.resolution_x = 800
sc.render.resolution_y = 800

VIEWS = {
    "fl": ((0.95, -1.25, 0.62), (0, -0.02, 0.52)),
    "left": ((1.35, -0.05, 0.58), (0, -0.02, 0.54)),
}
SHOTS = [
    ("Idle", 0, "fl"), ("Idle", 45, "fl"),
    ("Weapon_Raise", 18, "fl"), ("Weapon_Raise", 36, "fl"), ("Weapon_Raise", 36, "left"),
    ("Aim_Idle", 22, "fl"), ("Aim_Idle", 67, "fl"),
    ("Fire", 2, "fl"), ("Fire", 2, "left"), ("Fire", 7, "fl"),
    ("Weapon_Lower", 12, "fl"), ("Weapon_Lower", 12, "left"), ("Weapon_Lower", 24, "fl"),
]

for action_name, frame, view in SHOTS:
    set_action(action_name)
    sc.frame_set(frame)
    bpy.context.view_layer.update()
    loc, target = VIEWS[view]
    cam.location = loc
    cam.rotation_euler = (Vector(target) - Vector(loc)).to_track_quat('-Z', 'Y').to_euler()
    p = f"{OUT}/phase1_{action_name}_F{frame:02d}_{view}.png"
    sc.render.filepath = p
    bpy.ops.render.render(write_still=True)
    print("RENDERED", p)

set_action("Weapon_Raise_To_Aim")
sc.frame_set(0)
print("DONE (blend not saved)")
