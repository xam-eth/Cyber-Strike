"""Read-only highlight renders for rig-audit islands (script 52).

Renders the body in clay with selected loose-shell islands (ids from
script 51's union-find ordering, reproduced here) redrawn as emissive
offset overlays, plus cyan joint spheres at the current bone heads.
Nothing is saved to the blend; PNGs go to screenshots/rig/.

Islands of interest from script 51:
  101 magenta - front-center chest/abdomen centroid, avg Clavicle_R .50 /
                UpperArm_R .47, moved 43mm under isolated shoulder_R.
   70 cyan    - crosses shoulder_R (UpperArm .61 / Clavicle .34).
   22 green   - at shoulder_R head (Clavicle .45 / UpperArm .41).
    3 orange  - right upper-arm shell ending near elbow_R.
  190 yellow  - right upper-arm/elbow shell.
   53 red     - huge left forearm-side shell spanning across elbow_L.
  161 blue    - Hips/Spine island whose centroid lies on the left-arm path.
"""
import math
import os

import bpy
import numpy as np
from mathutils import Vector

PROJ = "/home/user/Cyber-Strike/EXOCOMFLICT_HERO01"
BLEND = f"{PROJ}/blender/HERO_01_working.blend"
OUT = f"{PROJ}/screenshots/rig"
os.makedirs(OUT, exist_ok=True)

bpy.ops.wm.open_mainfile(filepath=BLEND)
sc = bpy.context.scene
arm = bpy.data.objects["HERO_01_Armature"]
body = bpy.data.objects["HERO_01_BODY"]
for name in ("HERO_01_WEAPON", "HERO_01_UNDERSUIT"):
    if name in bpy.data.objects:
        bpy.data.objects[name].hide_render = True
if arm.animation_data:
    arm.animation_data.action = None
for pb in arm.pose.bones:
    pb.location = (0.0, 0.0, 0.0)
    pb.rotation_quaternion = (1.0, 0.0, 0.0, 0.0)
    pb.scale = (1.0, 1.0, 1.0)
sc.frame_set(0)
bpy.context.view_layer.update()
arm.hide_render = True

n = len(body.data.vertices)
ne = len(body.data.edges)
ev = np.empty(ne * 2, dtype=np.int64)
body.data.edges.foreach_get("vertices", ev)
ev = ev.reshape(-1, 2)
parent = np.arange(n, dtype=np.int64)


def find(a):
    while parent[a] != a:
        parent[a] = parent[parent[a]]
        a = parent[a]
    return a


for a, b in ev:
    ra, rb = find(int(a)), find(int(b))
    if ra != rb:
        parent[ra] = rb
roots = np.array([find(i) for i in range(n)])
_, ISL = np.unique(roots, return_inverse=True)
print("islands:", int(ISL.max() + 1))

mw = np.array(body.matrix_world)
co = np.empty(n * 3, dtype=np.float64)
body.data.vertices.foreach_get("co", co)
WORLD = co.reshape(-1, 3) @ mw[:3, :3].T + mw[:3, 3]
nrm = np.empty(n * 3, dtype=np.float64)
body.data.vertices.foreach_get("normal", nrm)
NRM = nrm.reshape(-1, 3) @ mw[:3, :3].T

body.data.calc_loop_triangles()
tris = np.array([t.vertices for t in body.data.loop_triangles], dtype=np.int64)
tri_isl = ISL[tris[:, 0]]

# clay body
clay = bpy.data.materials.new("AuditClay")
clay.use_nodes = True
bsdf = clay.node_tree.nodes["Principled BSDF"]
bsdf.inputs["Base Color"].default_value = (0.52, 0.54, 0.58, 1)
bsdf.inputs["Roughness"].default_value = 0.85
body.data.materials.clear()
body.data.materials.append(clay)


def emissive(name, rgb):
    m = bpy.data.materials.new(name)
    m.use_nodes = True
    b = m.node_tree.nodes["Principled BSDF"]
    b.inputs["Base Color"].default_value = (*rgb, 1)
    b.inputs["Emission Color"].default_value = (*rgb, 1)
    b.inputs["Emission Strength"].default_value = 0.85
    b.inputs["Roughness"].default_value = 0.6
    return m


HIGHLIGHTS = {
    101: (1.0, 0.05, 0.85),
    70: (0.0, 0.85, 1.0),
    22: (0.1, 1.0, 0.25),
    3: (1.0, 0.5, 0.0),
    190: (1.0, 0.9, 0.0),
    53: (1.0, 0.08, 0.05),
    161: (0.15, 0.3, 1.0),
}
for isl_id, rgb in HIGHLIGHTS.items():
    vmask = ISL == isl_id
    vids = np.flatnonzero(vmask)
    remap = {int(v): i for i, v in enumerate(vids)}
    faces = []
    for t in tris[tri_isl == isl_id]:
        if vmask[t[0]] and vmask[t[1]] and vmask[t[2]]:
            faces.append([remap[int(t[0])], remap[int(t[1])], remap[int(t[2])]])
    pts = WORLD[vids] + NRM[vids] * 0.0016
    me = bpy.data.meshes.new(f"HL_{isl_id}")
    me.from_pydata(pts.tolist(), [], faces)
    ob = bpy.data.objects.new(f"HL_{isl_id}", me)
    sc.collection.objects.link(ob)
    me.materials.append(emissive(f"HLmat_{isl_id}", rgb))
    c = WORLD[vids].mean(axis=0)
    print(f"HL isl={isl_id} verts={len(vids)} faces={len(faces)} centroid=({c[0]:+.3f},{c[1]:+.3f},{c[2]:+.3f})")

# joint spheres at current bone heads
jmat = emissive("JointCyan", (0.0, 0.95, 1.0))
JOINTS = ["Hips", "Spine", "Chest", "UpperChest", "Neck", "Head",
          "Clavicle_R", "UpperArm_R", "Forearm_R", "Hand_R",
          "Clavicle_L", "UpperArm_L", "Forearm_L", "Hand_L",
          "UpperLeg_R", "LowerLeg_R", "Foot_R", "UpperLeg_L", "LowerLeg_L", "Foot_L"]
for name in JOINTS:
    h = arm.matrix_world @ arm.data.bones[name].head_local
    bpy.ops.mesh.primitive_ico_sphere_add(radius=0.0105, location=h)
    o = bpy.context.active_object
    o.name = "J_" + name
    o.data.materials.append(jmat)

sc.render.engine = "CYCLES"
sc.cycles.samples = 24
sc.cycles.use_denoising = True
sc.cycles.device = "CPU"
w = bpy.data.worlds.new("AuditWorld")
sc.world = w
w.use_nodes = True
w.node_tree.nodes["Background"].inputs[0].default_value = (0.16, 0.17, 0.19, 1)
w.node_tree.nodes["Background"].inputs[1].default_value = 0.95
sd = bpy.data.lights.new("Sun", "SUN")
sd.energy = 3.0
so = bpy.data.objects.new("Sun", sd)
sc.collection.objects.link(so)
so.rotation_euler = (math.radians(52), math.radians(8), math.radians(-38))
cam = bpy.data.objects.new("Cam", bpy.data.cameras.new("Cam"))
sc.collection.objects.link(cam)
sc.camera = cam


def shoot(name, loc, target, rx=850, ry=1000, lens=52):
    cam.data.lens = lens
    cam.location = loc
    cam.rotation_euler = (Vector(target) - Vector(loc)).to_track_quat("-Z", "Y").to_euler()
    sc.render.resolution_x = rx
    sc.render.resolution_y = ry
    sc.render.filepath = f"{OUT}/{name}.png"
    bpy.ops.render.render(write_still=True)
    print("RENDERED", name)


shoot("audit51_hl_front", (0, -1.85, 0.56), (0, 0, 0.52))
shoot("audit51_hl_sideR", (-1.7, -0.25, 0.58), (-0.10, 0, 0.55))
shoot("audit51_hl_sideL", (1.7, -0.25, 0.58), (0.14, 0, 0.55))
shoot("audit51_hl_shoulderR_close", (-0.48, -0.62, 0.74), (-0.07, -0.01, 0.68), 850, 850, 55)
shoot("audit51_hl_elbowL_close", (0.55, -0.55, 0.56), (0.175, -0.005, 0.53), 850, 850, 55)
print("DONE (read-only)")
