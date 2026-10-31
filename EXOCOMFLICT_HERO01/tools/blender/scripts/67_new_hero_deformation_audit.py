"""67 - NEW_HERO_01 skinning proof: weight audits + isolated-joint
deformation battery with zoomed textured renders (AUDIT ONLY - poses are
probes, nothing is saved).

Headline test = the owner's defect on the old asset: raising an arm must NOT
move the waist/abdomen/belt. Also: elbow fold on the elbow pivot, knee fold,
hip crease, wrist, spine belt-line, rigid helmet.

Run: tools/blender/run_bpy.sh tools/blender/scripts/67_new_hero_deformation_audit.py
"""
import bpy
import math
import numpy as np
from mathutils import Vector, Matrix

BLEND = "/home/user/Cyber-Strike/EXOCOMFLICT_HERO01/blender/NEW_HERO_01_working.blend"
OUT = "/home/user/Cyber-Strike/EXOCOMFLICT_HERO01/screenshots/rig"

bpy.ops.wm.open_mainfile(filepath=BLEND)
body = bpy.data.objects["HERO_01_BODY"]
arm = bpy.data.objects["HERO_01_Armature"]
me = body.data; NV = len(me.vertices)
names = [g.name for g in body.vertex_groups]; G = {n: i for i, n in enumerate(names)}
W = np.zeros((NV, len(names)), np.float32)
for vi, v in enumerate(me.vertices):
    for g in v.groups:
        W[vi, g.group] = g.weight
co = np.empty(NV * 3); me.vertices.foreach_get("co", co); co = co.reshape(-1, 3).astype(np.float64)
x, y, z = co[:, 0], co[:, 1], co[:, 2]
def sw(*ns):
    return W[:, [G[n] for n in ns]].sum(1)

print("== WEIGHT AUDITS ==", flush=True)
armw = sw(*[n for n in names if any(k in n for k in ("UpperArm", "Forearm", "Hand_", "Clavicle"))])
for z0, z1 in ((0.45, 0.50), (0.50, 0.55), (0.55, 0.60), (0.60, 0.65), (0.65, 0.70), (0.70, 0.72)):
    m = (np.abs(x) <= 0.125) & (z >= z0) & (z < z1)
    print(f"TORSO band z{z0:.2f}-{z1:.2f}: n={int(m.sum())} armW mean={armw[m].mean():.4f} max={armw[m].max():.3f} n>0.02={int((armw[m] > 0.02).sum())}", flush=True)
legw = sw(*[n for n in names if any(k in n for k in ("UpperLeg", "LowerLeg", "Foot_", "Toe_"))])
belt = (np.abs(x) <= 0.13) & (z >= 0.50) & (z < 0.58)
print(f"BELT legW mean={legw[belt].mean():.4f} max={legw[belt].max():.3f} n>0.02={int((legw[belt] > 0.02).sum())}/{int(belt.sum())}", flush=True)
for S in ("L", "R"):
    hb = arm.data.bones[f"Hand_{S}"]
    wrist = np.array(hb.head_local); hdir = np.array(hb.tail_local) - wrist
    hdir = hdir / np.linalg.norm(hdir)
    rel = co - wrist
    along = rel @ hdir
    perp = np.linalg.norm(rel - along[:, None] * hdir[None, :], axis=1)
    dm = (along > 0.010) & (perp < 0.045)
    hw = sw(f"Hand_{S}")[dm]
    print(f"HAND_{S} beyond-wrist: n={int(dm.sum())} HandW mean={hw.mean():.3f} pure(>0.95)={100.0 * (hw > 0.95).mean():.1f}%", flush=True)
helm = z >= 0.87
print(f"HELMET z>0.87: HeadW mean={sw('Head')[helm].mean():.3f} pure={100.0*(sw('Head')[helm]>0.95).mean():.1f}%", flush=True)
boot = z <= 0.085
print(f"BOOT z<0.085: Foot+Toe mean={(sw('Foot_L','Toe_L','Foot_R','Toe_R'))[boot].mean():.3f}", flush=True)
chestplate = (np.abs(x) <= 0.09) & (z >= 0.66) & (z < 0.78)
print(f"CHEST core: Spine/Chest/UpperChest mean={sw('Spine','Chest','UpperChest')[chestplate].mean():.3f}", flush=True)

def evco():
    dg = bpy.context.evaluated_depsgraph_get()
    eo = body.evaluated_get(dg)
    em = eo.to_mesh()
    a = np.empty(len(em.vertices) * 3); em.vertices.foreach_get("co", a)
    MWm = np.array(eo.matrix_world); a2 = a.reshape(-1, 3)
    a2 = a2 @ MWm[:3, :3].T + MWm[:3, 3]
    eo.to_mesh_clear()
    return a2

rest = evco()
bpy.context.view_layer.objects.active = arm
bpy.ops.object.mode_set(mode="POSE")
RESTMAT = {}
bpy.context.view_layer.update()
for pb in arm.pose.bones:
    RESTMAT[pb.name] = pb.matrix.copy()

def reset():
    for pb in arm.pose.bones:
        pb.rotation_mode = "AXIS_ANGLE"
        pb.rotation_axis_angle = (0.0, 1.0, 0.0, 0.0)
        pb.location = (0, 0, 0); pb.scale = (1, 1, 1)
    bpy.context.view_layer.update()

def rot(bone, axis_world, deg):
    pb = arm.pose.bones[bone]
    M3 = RESTMAT[bone].to_3x3().inverted()
    la = (M3 @ Vector(axis_world)).normalized()
    pb.rotation_mode = "AXIS_ANGLE"
    pb.rotation_axis_angle = (math.radians(deg), la.x, la.y, la.z)
    bpy.context.view_layer.update()

def disp(mask, posed):
    d = np.linalg.norm(posed - rest, axis=1)
    return float(d[mask].mean() * 1000), float(d[mask].max() * 1000)

waist = (np.abs(x) <= 0.125) & (z >= 0.45) & (z < 0.58)
waist_strict = (np.abs(x) <= 0.110) & (z >= 0.50) & (z < 0.60)  # belt/abdomen only, no thigh tops
pelvis = (np.abs(x) <= 0.125) & (z >= 0.42) & (z < 0.50)
chestm = (np.abs(x) <= 0.10) & (z >= 0.64) & (z < 0.74)
results = {}
def measure(tag, masks):
    p = evco()
    out = {}
    for mn, mask in masks.items():
        out[mn] = disp(mask, p)
        print(f"{tag} [{mn}] mean={out[mn][0]:.2f}mm max={out[mn][1]:.2f}mm", flush=True)
    results[tag] = out
    return p

print("== ISOLATED POSE PROBES ==", flush=True)
reset(); rot("UpperArm_R", (0, 1, 0), 105); rot("UpperArm_L", (1, 0, 0), 88)
measure("RAISE_ARMS", {"waist": waist, "waist_strict": waist_strict, "pelvis": pelvis, "chest": chestm})
reset(); rot("Forearm_L", (-0.74, 0, -0.67), -112)
measure("ELBOW_L", {"waist": waist, "chest": chestm})
reset(); rot("UpperLeg_R", (1, 0, 0), 85)
measure("HIP_R", {"waist": waist, "waist_strict": waist_strict, "Lleg": (x > 0.03) & (z < 0.45)})
reset(); rot("LowerLeg_L", (1, 0, 0), -102)
measure("KNEE_L", {"thighL": (x > 0.03) & (z >= 0.33) & (z < 0.48)})
reset(); rot("Chest", (0, 0, 1), -26); rot("Spine", (1, 0, 0), 14)
measure("SPINE", {"pelvis": pelvis})
reset(); rot("Neck", (0, 0, 1), 30); rot("Head", (1, 0, 0), -12)
measure("HEAD", {"chest": chestm, "waist": waist})
reset(); rot("Hand_R", (1, 0, 0), -42)
measure("WRIST_R", {"forearmR": (x < -0.24) & (x > -0.33) & (z > 0.58) & (z < 0.68)})

# ---- renders ----
bpy.ops.object.mode_set(mode="OBJECT")
sc = bpy.context.scene
sc.render.engine = "CYCLES"; sc.cycles.samples = 32; sc.cycles.use_denoising = True; sc.cycles.device = "CPU"
world = bpy.data.worlds.new("W67"); sc.world = world; world.use_nodes = True
world.node_tree.nodes["Background"].inputs[0].default_value = (0.32, 0.33, 0.35, 1)
world.node_tree.nodes["Background"].inputs[1].default_value = 1.0
sd = bpy.data.lights.new("S67", "SUN"); sd.energy = 3.2
so = bpy.data.objects.new("S67", sd); sc.collection.objects.link(so)
so.rotation_euler = (math.radians(52), math.radians(8), math.radians(-38))
cam = bpy.data.objects.new("C67", bpy.data.cameras.new("C67")); sc.collection.objects.link(cam); sc.camera = cam
bpy.context.view_layer.objects.active = arm
bpy.ops.object.mode_set(mode="POSE")

def render(tag, loc, tgt, size=800, lens=55):
    cam.data.lens = lens; cam.location = loc
    cam.rotation_euler = (Vector(tgt) - Vector(loc)).to_track_quat("-Z", "Y").to_euler()
    sc.render.resolution_x = sc.render.resolution_y = size
    sc.render.filepath = f"{OUT}/audit67_{tag}.png"
    bpy.ops.render.render(write_still=True)
    print("RENDERED", tag, flush=True)

reset(); rot("UpperArm_R", (0, 1, 0), 105); rot("UpperArm_L", (1, 0, 0), 88)
render("raisearms_front", (0, -1.85, 0.55), (0, -0.01, 0.50))
render("raisearmR_waist_zoom", (-0.42, -0.55, 0.62), (-0.10, -0.01, 0.52), 750)
reset(); rot("Forearm_L", (-0.74, 0, -0.67), -112)
render("elbowL_bend", (0.72, -0.72, 0.78), (0.24, -0.01, 0.63), 750)
reset(); rot("UpperLeg_R", (1, 0, 0), 85); rot("LowerLeg_R", (1, 0, 0), -88)
render("hipkneeR_sit", (-0.85, -1.10, 0.55), (-0.05, -0.02, 0.40), 800)
render("kneeR_zoom", (-0.55, -0.75, 0.30), (-0.10, -0.16, 0.28), 700)
reset(); rot("LowerLeg_L", (1, 0, 0), -102)
render("kneeL_back", (1.25, 0.25, 0.42), (0.08, 0.02, 0.30), 750)
reset(); rot("Neck", (0, 0, 1), 30); rot("Head", (1, 0, 0), -12)
render("head_turn", (0.38, -0.62, 0.92), (0.0, -0.01, 0.82), 700)
reset(); rot("Chest", (0, 0, 1), -26); rot("Spine", (1, 0, 0), 14)
render("spine_twist", (0.15, -1.55, 0.66), (0, -0.01, 0.56), 800)
bpy.ops.object.mode_set(mode="OBJECT")
for o in (so, cam): bpy.data.objects.remove(o, do_unlink=True)
bpy.data.lights.remove(sd); bpy.data.cameras.remove(bpy.data.cameras["C67"]); bpy.data.worlds.remove(world)
sc.world = None; sc.camera = None
print("DONE 67 (audit only - blend NOT saved)", flush=True)
