"""Final dark-material verification renders for the undersuit fix (script 43).
Opens the working blend (source of the exported GLB), renders ON/OFF pairs by toggling
HERO_01_UNDERSUIT.hide_render: F0 pairs must be pixel-identical (invisible at rest);
F36 pairs show the plug filling the front-left hip slit. Writes us_ON/OFF renders and
hip crops to screenshots/diag. Does NOT save the blend."""
import bpy, math, os
import numpy as np
from mathutils import Vector
from PIL import Image

PROJ = "/home/user/Cyber-Strike/EXOCOMFLICT_HERO01"
SHOT = f"{PROJ}/screenshots/diag"
os.makedirs(SHOT, exist_ok=True)
bpy.ops.wm.open_mainfile(filepath=f"{PROJ}/blender/HERO_01_working.blend")
sc = bpy.context.scene
arm = bpy.data.objects["HERO_01_Armature"]
under = bpy.data.objects["HERO_01_UNDERSUIT"]
print("undersuit material:", under.data.materials[0].name if under.data.materials else None)

sc.render.engine = "CYCLES"
sc.cycles.samples = 20
sc.cycles.use_denoising = True
sc.cycles.device = "CPU"
sc.cycles.seed = 7
w = bpy.data.worlds.new("WVerify")
sc.world = w
w.use_nodes = True
w.node_tree.nodes["Background"].inputs[0].default_value = (0.16, 0.17, 0.19, 1)
w.node_tree.nodes["Background"].inputs[1].default_value = 0.9
sd = bpy.data.lights.new("SunV", "SUN")
sd.energy = 3
so = bpy.data.objects.new("SunV", sd)
sc.collection.objects.link(so)
so.rotation_euler = (math.radians(52), math.radians(8), math.radians(-38))
cam = bpy.data.objects.new("CamV", bpy.data.cameras.new("CamV"))
cam.data.lens = 52
sc.collection.objects.link(cam)
sc.camera = cam
arm.hide_render = True
sc.render.resolution_x = 900
sc.render.resolution_y = 900
TARGET = Vector((0, -0.02, 0.55))
VIEWS = {
    "front": (0, -1.15, 0.56),
    "fl": (0.82, -0.82, 0.60),
    "left": (1.15, -0.05, 0.56),
}

def render(frame, view, on):
    sc.frame_set(frame)
    under.hide_render = not on
    bpy.context.view_layer.update()
    loc = VIEWS[view]
    cam.location = loc
    cam.rotation_euler = (TARGET - Vector(loc)).to_track_quat('-Z', 'Y').to_euler()
    p = f"{SHOT}/us_{'ON' if on else 'OFF'}_F{frame:02d}_{view}.png"
    sc.render.filepath = p
    bpy.ops.render.render(write_still=True)
    print("RENDERED", p)
    return p

pairs = [(0, "front"), (0, "fl"), (0, "left"), (36, "fl"), (36, "left")]
paths = {}
for frame, view in pairs:
    paths[(frame, view, True)] = render(frame, view, True)
    paths[(frame, view, False)] = render(frame, view, False)
paths[(36, "front", True)] = render(36, "front", True)
under.hide_render = False

def pixdiff(pa, pb):
    a = np.asarray(Image.open(pa).convert("RGB")).astype(int)
    b = np.asarray(Image.open(pb).convert("RGB")).astype(int)
    d = np.abs(a - b).max(axis=2)
    return float(d.mean()), float((d > 12).mean() * 100.0)

for frame, view in pairs:
    mean_d, pct = pixdiff(paths[(frame, view, True)], paths[(frame, view, False)])
    print(f"DIFF F{frame} {view}: mean_abs={mean_d:.3f} pct_px_gt12={pct:.3f}%")

# Hip crops (gate bbox at 700px scaled to 900px, expanded).
def crop(src, box, dst):
    im = Image.open(src).crop(box)
    im = im.resize((im.width * 2, im.height * 2), Image.LANCZOS)
    im.save(dst)
    print("CROP", dst)

crop(paths[(36, "left", True)], (330, 350, 560, 560), f"{SHOT}/crop_us_ON_F36_left.png")
crop(paths[(36, "left", False)], (330, 350, 560, 560), f"{SHOT}/crop_us_OFF_F36_left.png")
crop(paths[(36, "fl", True)], (410, 270, 650, 570), f"{SHOT}/crop_us_ON_F36_fl.png")
crop(paths[(36, "fl", False)], (410, 270, 650, 570), f"{SHOT}/crop_us_OFF_F36_fl.png")
print("DONE (blend not saved)")
