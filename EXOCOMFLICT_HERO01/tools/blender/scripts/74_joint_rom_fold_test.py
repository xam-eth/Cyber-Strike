"""74 - Controlled single-joint ROM skin-fold test (post-rejection, 2026-10-31).
Question: does the SKIN fold correctly when each joint is posed
CORRECTLY (anatomical direction, single joint at a time)? This separates
rig/skin quality from the rejected animation's bad poses (script 73).
Each test starts from bind pose, swings ONE joint by a world-axis
rotation derived from the bone directions, measures the resulting joint
angle + mesh edge-stretch near the joint, and renders a zoom.
Blend NOT saved.
Run: tools/blender/run_bpy.sh tools/blender/scripts/74_joint_rom_fold_test.py
"""
import bpy
import math
import numpy as np
from mathutils import Vector, Quaternion

PROJ = "/home/user/Cyber-Strike/EXOCOMFLICT_HERO01"
BLEND = f"{PROJ}/blender/NEW_HERO_01_working.blend"
OUT = f"{PROJ}/screenshots/rig"

bpy.ops.wm.open_mainfile(filepath=BLEND)
arm = bpy.data.objects["HERO_01_Armature"]
body = bpy.data.objects["HERO_01_BODY"]
sc = bpy.context.scene
bpy.context.view_layer.objects.active = arm
bpy.ops.object.mode_set(mode="POSE")
bpy.context.view_layer.update()
RESTMAT = {p.name: p.matrix.copy() for p in arm.pose.bones}
RESTHEAD = {p.name: Vector(p.head) for p in arm.pose.bones}
IDENT = Quaternion((1, 0, 0, 0))

def reset_pose():
    for p in arm.pose.bones:
        p.rotation_mode = "QUATERNION"
        p.rotation_quaternion = IDENT
        p.location = (0, 0, 0)
    bpy.context.view_layer.update()

def world_quat(bone, axis_world, deg):
    la = (RESTMAT[bone].to_3x3().inverted() @ Vector(axis_world)).normalized()
    return Quaternion(la, math.radians(deg))

def bone_dir_at_rest(bone):
    pb = arm.pose.bones[bone]
    return (Vector(pb.tail) - Vector(pb.head))

def swing(bone, target_dir_world, deg):
    """Rotate bone about world axis = dir x target (swings dir toward target)."""
    d = bone_dir_at_rest(bone).normalized()
    ax = d.cross(Vector(target_dir_world).normalized())
    if ax.length < 1e-6:
        ax = Vector((1, 0, 0))
    ax.normalize()
    pb = arm.pose.bones[bone]
    pb.rotation_quaternion = world_quat(bone, ax, deg) @ pb.rotation_quaternion
    bpy.context.view_layer.update()

def joint_angle(parent_bone, bone):
    S = Vector(arm.pose.bones[parent_bone].head)
    E = Vector(arm.pose.bones[bone].head)
    # child end: use tail of bone
    W = Vector(arm.pose.bones[bone].tail)
    return math.degrees((S - E).angle(W - E))

# rest geometry for edge stretch
me0 = body.data
nv = len(me0.vertices)
V0 = np.empty(nv * 3, dtype=np.float64)
me0.vertices.foreach_get("co", V0)
V0 = V0.reshape(nv, 3)
ne = len(me0.edges)
EIDX = np.empty(ne * 2, dtype=np.int64)
me0.edges.foreach_get("vertices", EIDX)
EIDX = EIDX.reshape(ne, 2)
L0 = np.linalg.norm(V0[EIDX[:, 0]] - V0[EIDX[:, 1]], axis=1)

def edge_stretch(center, radius=0.08):
    dg = bpy.context.evaluated_depsgraph_get()
    eo = body.evaluated_get(dg)
    me = eo.to_mesh()
    V = np.empty(len(me.vertices) * 3, dtype=np.float64)
    me.vertices.foreach_get("co", V)
    V = V.reshape(-1, 3)
    eo.to_mesh_clear()
    c = np.array(center)
    near = (np.linalg.norm(V0[EIDX[:, 0]] - c, axis=1) < radius) & (np.linalg.norm(V0[EIDX[:, 1]] - c, axis=1) < radius)
    if near.sum() == 0:
        return 0, 0.0, 0.0
    L = np.linalg.norm(V[EIDX[near, 0]] - V[EIDX[near, 1]], axis=1)
    r = L / np.maximum(L0[near], 1e-9)
    return int(near.sum()), float(np.percentile(r, 99)), float(r.max())

# render setup
sc.render.engine = "CYCLES"; sc.cycles.samples = 24; sc.cycles.use_denoising = True; sc.cycles.device = "CPU"
world = bpy.data.worlds.new("W74"); sc.world = world; world.use_nodes = True
world.node_tree.nodes["Background"].inputs[0].default_value = (0.32, 0.33, 0.35, 1)
sd = bpy.data.lights.new("S74", "SUN"); sd.energy = 3.2
so = bpy.data.objects.new("S74", sd); sc.collection.objects.link(so)
so.rotation_euler = (math.radians(52), math.radians(8), math.radians(-38))
cam = bpy.data.objects.new("C74", bpy.data.cameras.new("C74")); sc.collection.objects.link(cam); sc.camera = cam

def render(tag, center, offset, size=640):
    loc = Vector(center) + Vector(offset)
    cam.data.lens = 50; cam.location = tuple(loc)
    cam.rotation_euler = (Vector(center) - loc).to_track_quat("-Z", "Y").to_euler()
    sc.render.resolution_x = sc.render.resolution_y = size
    sc.render.filepath = f"{OUT}/audit74_{tag}.png"
    bpy.ops.render.render(write_still=True)
    print("RENDERED", tag, flush=True)

FWD = (0, -1, 0)
tests = []
def run(tag, bone, target, deg, parent_for_angle, cam_off, full=False):
    reset_pose()
    swing(bone, target, deg)
    center = Vector(arm.pose.bones[bone].head)
    ang = joint_angle(parent_for_angle, bone) if parent_for_angle else -1
    n, p99, mx = edge_stretch(center)
    print(f"TEST {tag}: swing {bone} {deg}deg -> joint angle {ang:.1f}; edges {n} stretch p99 {p99:.3f} max {mx:.3f}", flush=True)
    render(tag, center, cam_off)
    if full:
        render(tag + "_full", (0, -0.02, 0.52), (0.0, -1.85, 0.10), 560)

# rest elbow joint angle is ~158 (script 73); swing deg chosen to land near targets
run("elbowR_j135", "Forearm_R", FWD, 23, "UpperArm_R", (-0.30, -0.30, 0.06))
run("elbowR_j090", "Forearm_R", FWD, 68, "UpperArm_R", (-0.30, -0.30, 0.06))
run("elbowR_j050", "Forearm_R", FWD, 108, "UpperArm_R", (-0.30, -0.30, 0.06))
run("elbowL_j090", "Forearm_L", FWD, 68, "UpperArm_L", (0.30, -0.30, 0.06))
run("shoulderR_flex45", "UpperArm_R", FWD, 45, None, (-0.38, -0.30, 0.10))
run("shoulderR_flex90", "UpperArm_R", FWD, 90, None, (-0.38, -0.30, 0.10), full=True)
run("shoulderR_abd", "UpperArm_R", (-1, 0, 0.35), 55, None, (-0.30, -0.42, 0.14))
run("shoulderL_flexcross", "UpperArm_L", (0.30, -1, 0), 80, None, (0.34, -0.34, 0.10), full=True)
run("wristR_flex", "Hand_R", FWD, 30, "Forearm_R", (-0.26, -0.26, 0.05))
run("kneeL_j090", "LowerLeg_L", (0, 1, 0), 85, "UpperLeg_L", (0.28, -0.30, 0.02))
run("hipL_flex60", "UpperLeg_L", FWD, 60, None, (0.30, -0.36, 0.02))
reset_pose()
print("DONE 74", flush=True)
