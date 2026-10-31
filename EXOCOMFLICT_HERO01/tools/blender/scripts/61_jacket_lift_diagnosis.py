"""Read-only zoom diagnosis for the owner's jacket/abdomen lift complaint.

The previous torso-island checks were centroid/box limited. This script
starts from the actual visual region and asks, for every island touching
that region:
  * how far does it move under isolated UpperArm/Forearm rotations?
  * how far/up does it move in Weapon_Raise_To_Aim F36?
  * which bones' deformation matrices contribute that movement?

It renders close-up textured poses and clay highlight views of the
strongest torso-region candidates. Nothing is saved to the blend.
"""
import math
import os

import bpy
import numpy as np
from mathutils import Matrix, Vector

PROJ = "/home/user/Cyber-Strike/EXOCOMFLICT_HERO01"
OUT = f"{PROJ}/screenshots/rig"
os.makedirs(OUT, exist_ok=True)
bpy.ops.wm.open_mainfile(filepath=f"{PROJ}/blender/HERO_01_working.blend")
sc = bpy.context.scene
arm = bpy.data.objects["HERO_01_Armature"]
body = bpy.data.objects["HERO_01_BODY"]
weapon = bpy.data.objects["HERO_01_WEAPON"]
if arm.animation_data is None:
    arm.animation_data_create()
ad = arm.animation_data
ORDER = ["Root", "Hips", "Spine", "Chest", "UpperChest", "Neck", "Head",
         "Clavicle_R", "UpperArm_R", "Forearm_R", "Hand_R", "Weapon_R",
         "Clavicle_L", "UpperArm_L", "Forearm_L", "Hand_L",
         "UpperLeg_R", "LowerLeg_R", "Foot_R", "Toe_R",
         "UpperLeg_L", "LowerLeg_L", "Foot_L", "Toe_L"]


def set_action(name):
    if name is None:
        ad.action = None
        return None
    act = bpy.data.actions[name]
    ad.action = act
    try:
        if len(act.slots) == 0:
            act.slots.new(id_type='OBJECT', name=arm.name)
        ad.action_slot = act.slots[0]
    except Exception as ex:
        print("slot setup", ex)
    return act


def reset_pose():
    set_action(None)
    for pb in arm.pose.bones:
        pb.location = (0, 0, 0)
        pb.rotation_quaternion = (1, 0, 0, 0)
        pb.rotation_euler = (0, 0, 0)
        pb.scale = (1, 1, 1)
    bpy.context.view_layer.update()


def rot_world(name, axis, deg):
    pb = arm.pose.bones[name]
    head = pb.head.copy()
    M = Matrix.Translation(head) @ Matrix.Rotation(math.radians(deg), 4, axis) @ Matrix.Translation(-head)
    pb.matrix = M @ pb.matrix
    bpy.context.view_layer.update()


n = len(body.data.vertices)


def evaluated_coords():
    dg = bpy.context.evaluated_depsgraph_get()
    eo = body.evaluated_get(dg)
    em = eo.to_mesh()
    p = np.empty(n * 3, dtype=np.float64)
    em.vertices.foreach_get("co", p)
    eo.to_mesh_clear()
    emw = np.array(eo.matrix_world, dtype=np.float64)
    return p.reshape(-1, 3) @ emw[:3, :3].T + emw[:3, 3]


reset_pose()
sc.frame_set(0)
P0 = evaluated_coords()
gnames = [g.name for g in body.vertex_groups]
gidx = {name: i for i, name in enumerate(gnames)}
W = np.zeros((n, len(gnames)), dtype=np.float64)
for v in body.data.vertices:
    for ge in v.groups:
        W[v.index, ge.group] = ge.weight

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
NISL = int(ISL.max() + 1)
cnt = np.bincount(ISL).astype(np.float64)
icen = np.stack([np.bincount(ISL, weights=P0[:, k]) / cnt for k in range(3)], axis=1)
iw = np.stack([np.bincount(ISL, weights=W[:, gi]) / cnt for gi in range(len(gnames))], axis=1)
ibmin = np.zeros((NISL, 3)); ibmax = np.zeros((NISL, 3))
for k in range(3):
    ibmin[:, k] = np.minimum.reduceat(np.where(np.arange(n) >= 0, P0[:, k], 0), np.r_[0, np.cumsum(cnt[:-1]).astype(int)]) if False else [P0[ISL == i, k].min() for i in range(NISL)]
    ibmax[:, k] = [P0[ISL == i, k].max() for i in range(NISL)]

SPINE = ["Hips", "Spine", "Chest", "UpperChest", "Neck"]
ARM_L = ["Clavicle_L", "UpperArm_L", "Forearm_L", "Hand_L"]
ARM_R = ["Clavicle_R", "UpperArm_R", "Forearm_R", "Hand_R"]
LEGS = ["UpperLeg_L", "LowerLeg_L", "Foot_L", "Toe_L", "UpperLeg_R", "LowerLeg_R", "Foot_R", "Toe_R"]


def cats(i):
    return (float(sum(iw[i, gidx[b]] for b in SPINE)),
            float(sum(iw[i, gidx[b]] for b in ARM_L)),
            float(sum(iw[i, gidx[b]] for b in ARM_R)),
            float(sum(iw[i, gidx[b]] for b in LEGS)))


def top_weights(i, k=4):
    idx = np.argsort(-iw[i])[:k]
    return ", ".join(f"{gnames[j]}={iw[i,j]:.2f}" for j in idx if iw[i, j] > 0.01)


def island_centroids(P):
    return np.stack([np.bincount(ISL, weights=P[:, k]) / cnt for k in range(3)], axis=1)


# Torso/jacket region, deliberately wider than the script-54 centroid tube.
TORSO_POTENTIAL = []
for i in range(NISL):
    intersects = not (ibmax[i, 0] < -0.215 or ibmin[i, 0] > 0.215 or
                      ibmax[i, 1] < -0.135 or ibmin[i, 1] > 0.135 or
                      ibmax[i, 2] < 0.420 or ibmin[i, 2] > 0.770)
    if cnt[i] >= 30 and intersects and abs(icen[i, 0]) <= 0.215 and 0.420 <= icen[i, 2] <= 0.770:
        TORSO_POTENTIAL.append(i)
print(f"TORSO/JACKET potential islands: {len(TORSO_POTENTIAL)}")

BASE_C = island_centroids(P0)
TESTS = [
    ("SHOULDER_L_FLEX", [("UpperArm_L", (1, 0, 0), -60)]),
    ("SHOULDER_R_FLEX", [("UpperArm_R", (1, 0, 0), -60)]),
    ("SHOULDERS_BOTH_FLEX", [("UpperArm_L", (1, 0, 0), -60), ("UpperArm_R", (1, 0, 0), -60)]),
    ("ELBOW_L_FLEX", [("Forearm_L", (1, 0, 0), -55)]),
    ("ELBOW_R_FLEX", [("Forearm_R", (1, 0, 0), -55)]),
]
iso_disp = {}
for tname, rots in TESTS:
    reset_pose()
    for bone, axis, deg in rots:
        rot_world(bone, axis, deg)
    P = evaluated_coords()
    C = island_centroids(P)
    iso_disp[tname] = C - BASE_C

print("\nTORSO-REGION ISLANDS MOVING UNDER ISOLATED ARM ROTATIONS")
print("(centroid |disp| in mm; dz in mm; sorted by worst isolated displacement)")
ranked = []
for i in TORSO_POTENTIAL:
    vals = []
    for tname, _ in TESTS:
        dvec = iso_disp[tname][i]
        vals.append((float(np.linalg.norm(dvec)), float(dvec[2]), tname))
    vals.sort(reverse=True)
    ranked.append((vals[0][0], i, vals))
ranked.sort(reverse=True)
for worst, i, vals in ranked:
    if worst < 0.001:
        continue
    sp, al, ar, leg = cats(i)
    print(f" isl={i:3d} n={int(cnt[i]):5d} cen=({icen[i,0]:+.3f},{icen[i,1]:+.3f},{icen[i,2]:+.3f}) "
          f"bbox x[{ibmin[i,0]:+.3f},{ibmax[i,0]:+.3f}] y[{ibmin[i,1]:+.3f},{ibmax[i,1]:+.3f}] z[{ibmin[i,2]:+.3f},{ibmax[i,2]:+.3f}]")
    print(f"      cats spine={sp:.2f} armL={al:.2f} armR={ar:.2f} leg={leg:.2f}; top {top_weights(i)}")
    print("      " + "  ".join(f"{t}={d*1000:.1f}(dz{dz*1000:+.1f})" for d, dz, t in vals))

# Spatial zones matching the owner's wording.
ZONES = {
    "FRONT_ABDOMEN": (P0[:, 1] <= -0.045) & (np.abs(P0[:, 0]) <= 0.145) & (P0[:, 2] >= 0.44) & (P0[:, 2] <= 0.65),
    "JACKET_SIDE_L": (P0[:, 0] >= 0.055) & (P0[:, 0] <= 0.215) & (np.abs(P0[:, 1]) <= 0.13) & (P0[:, 2] >= 0.44) & (P0[:, 2] <= 0.73),
    "JACKET_SIDE_R": (P0[:, 0] <= -0.055) & (P0[:, 0] >= -0.215) & (np.abs(P0[:, 1]) <= 0.13) & (P0[:, 2] >= 0.44) & (P0[:, 2] <= 0.73),
    "WAIST_HEM": (np.abs(P0[:, 0]) <= 0.19) & (np.abs(P0[:, 1]) <= 0.13) & (P0[:, 2] >= 0.43) & (P0[:, 2] <= 0.58),
    "FRONT_CHEST": (P0[:, 1] <= -0.045) & (np.abs(P0[:, 0]) <= 0.16) & (P0[:, 2] > 0.65) & (P0[:, 2] <= 0.80),
}
print("\nZONE WEIGHT COMPOSITION + ISOLATED DISPLACEMENT")
zone_iso = {}
for zname, mask in ZONES.items():
    ids = np.flatnonzero(mask)
    zone_iso[zname] = {}
    avg = W[mask].mean(axis=0) if len(ids) else np.zeros(len(gnames))
    top = np.argsort(-avg)[:6]
    print(f"{zname}: verts={len(ids)} top " + ", ".join(f"{gnames[j]}={avg[j]:.3f}" for j in top if avg[j] > 0.005))
for tname, rots in TESTS:
    reset_pose()
    for bone, axis, deg in rots:
        rot_world(bone, axis, deg)
    P = evaluated_coords()
    for zname, mask in ZONES.items():
        d = P[mask].mean(axis=0) - P0[mask].mean(axis=0)
        zone_iso[zname][tname] = d
for zname in ZONES:
    print(zname + ": " + "  ".join(
        f"{t} |d|={np.linalg.norm(zone_iso[zname][t])*1000:.1f} dz={zone_iso[zname][t][2]*1000:+.1f}" for t, _ in TESTS))

# Actual aim pose and deformation contribution by bone.
set_action("Weapon_Raise_To_Aim")
sc.frame_set(36)
bpy.context.view_layer.update()
P36 = evaluated_coords()
C36 = island_centroids(P36)
Dmat = {}
for bname in ORDER:
    pb = arm.pose.bones[bname]
    Dmat[bname] = np.array(pb.matrix @ pb.bone.matrix_local.inverted(), dtype=np.float64)
Ph = np.concatenate([P0, np.ones((n, 1))], axis=1)
# contribution[b] for all verts, retained one bone at a time and reduced by island.
contrib_island = {i: {} for i in TORSO_POTENTIAL}
contrib_zone = {z: {} for z in ZONES}
for bname in gnames:
    delta = (Ph @ (Dmat[bname] - np.eye(4)).T)[:, :3] * W[:, gidx[bname]][:, None]
    # Island mean contribution.
    vals = np.stack([np.bincount(ISL, weights=delta[:, k]) / cnt for k in range(3)], axis=1)
    for i in TORSO_POTENTIAL:
        contrib_island[i][bname] = vals[i]
    for zname, mask in ZONES.items():
        contrib_zone[zname][bname] = delta[mask].mean(axis=0) if np.any(mask) else np.zeros(3)

print("\nACTUAL AIM F36 ZONE DISPLACEMENT + BONE CONTRIBUTIONS")
for zname, mask in ZONES.items():
    total = P36[mask].mean(axis=0) - P0[mask].mean(axis=0)
    print(f"{zname}: total d={np.round(total*1000,1)}mm |d|={np.linalg.norm(total)*1000:.1f} dz={total[2]*1000:+.1f}")
    ordered = sorted(contrib_zone[zname].items(), key=lambda kv: np.linalg.norm(kv[1]), reverse=True)
    for bname, vec in ordered[:7]:
        if np.linalg.norm(vec) > 0.0002:
            print(f"    {bname:12s} contrib={np.round(vec*1000,1)}mm |c|={np.linalg.norm(vec)*1000:.1f} dz={vec[2]*1000:+.1f}")

print("\nACTUAL AIM F36 TORSO-REGION ISLANDS (worst centroid displacement)")
actual_ranked = sorted(TORSO_POTENTIAL, key=lambda i: np.linalg.norm(C36[i]-BASE_C[i]), reverse=True)
for i in actual_ranked[:45]:
    d = C36[i] - BASE_C[i]
    if np.linalg.norm(d) < 0.001:
        continue
    ordered = sorted(contrib_island[i].items(), key=lambda kv: np.linalg.norm(kv[1]), reverse=True)[:4]
    sp, al, ar, leg = cats(i)
    print(f" isl={i:3d} n={int(cnt[i]):5d} cen=({icen[i,0]:+.3f},{icen[i,1]:+.3f},{icen[i,2]:+.3f}) d={np.round(d*1000,1)} |d|={np.linalg.norm(d)*1000:.1f}")
    print(f"      cats spine={sp:.2f} armL={al:.2f} armR={ar:.2f}; top {top_weights(i)}")
    print("      contrib " + ", ".join(f"{b}:{np.round(v*1000,1)}" for b, v in ordered if np.linalg.norm(v) > 0.0002))

# Candidate overlays: strongest isolated movers in the clothing core.
# The wider ranked list is dominated by the arms themselves; the owner's
# jacket/abdomen region is the central shell (|centroid x| <= 0.14).
CORE_RANKED = [(worst, i, vals) for worst, i, vals in ranked if abs(icen[i, 0]) <= 0.140]
print("\nCLOTHING-CORE ISOLATED MOVERS (|centroid x| <= 0.140):")
for worst, i, vals in CORE_RANKED:
    if worst < 0.001:
        continue
    sp, al, ar, leg = cats(i)
    print(f" core isl={i:3d} n={int(cnt[i]):5d} cen=({icen[i,0]:+.3f},{icen[i,1]:+.3f},{icen[i,2]:+.3f}) worst={worst*1000:.1f}mm")
    print(f"      bbox x[{ibmin[i,0]:+.3f},{ibmax[i,0]:+.3f}] y[{ibmin[i,1]:+.3f},{ibmax[i,1]:+.3f}] z[{ibmin[i,2]:+.3f},{ibmax[i,2]:+.3f}]")
    print(f"      cats spine={sp:.2f} armL={al:.2f} armR={ar:.2f} leg={leg:.2f}; top {top_weights(i)}")
    print("      " + "  ".join(f"{t}={d*1000:.1f}(dz{dz*1000:+.1f})" for d, dz, t in vals))
CANDIDATES = [i for worst, i, _ in CORE_RANKED if worst >= 0.003][:14]
print("\nHIGHLIGHT CANDIDATE ISLANDS (ranked palette order):", CANDIDATES)

# ---------------- renders ----------------
sc.render.engine = "CYCLES"
sc.cycles.samples = 24
sc.cycles.use_denoising = True
sc.cycles.device = "CPU"
world = bpy.data.worlds.new("Audit61World")
sc.world = world
world.use_nodes = True
world.node_tree.nodes["Background"].inputs[0].default_value = (0.16, 0.17, 0.19, 1)
world.node_tree.nodes["Background"].inputs[1].default_value = 0.95
sd = bpy.data.lights.new("Audit61Sun", "SUN")
sd.energy = 3.0
so = bpy.data.objects.new("Audit61Sun", sd)
sc.collection.objects.link(so)
so.rotation_euler = (math.radians(52), math.radians(8), math.radians(-38))
cam = bpy.data.objects.new("Audit61Cam", bpy.data.cameras.new("Audit61Cam"))
sc.collection.objects.link(cam)
sc.camera = cam
arm.hide_render = True
if "HERO_01_UNDERSUIT" in bpy.data.objects:
    bpy.data.objects["HERO_01_UNDERSUIT"].hide_render = False


def shoot(name, loc, target=(0, 0, 0.60), lens=58):
    cam.data.lens = lens
    cam.location = loc
    cam.rotation_euler = (Vector(target) - Vector(loc)).to_track_quat('-Z', 'Y').to_euler()
    sc.render.resolution_x = 950
    sc.render.resolution_y = 950
    sc.render.filepath = f"{OUT}/{name}.png"
    bpy.ops.render.render(write_still=True)
    print("RENDERED", name)


FRONT = (0, -0.92, 0.62)
SIDEL = (0.92, -0.08, 0.62)
SIDER = (-0.92, -0.08, 0.62)
THREEQ = (-0.62, -0.62, 0.68)
weapon.hide_render = True
reset_pose(); shoot("audit61_torso_rest_front", FRONT)
reset_pose(); rot_world("UpperArm_L", (1, 0, 0), -60); shoot("audit61_torso_shoulderL_front", FRONT); shoot("audit61_torso_shoulderL_sideL", SIDEL)
reset_pose(); rot_world("UpperArm_R", (1, 0, 0), -60); shoot("audit61_torso_shoulderR_front", FRONT); shoot("audit61_torso_shoulderR_sideR", SIDER)
weapon.hide_render = False
set_action("Weapon_Raise_To_Aim"); sc.frame_set(36); bpy.context.view_layer.update()
shoot("audit61_torso_aimF36_front", FRONT)
shoot("audit61_torso_aimF36_sideL", SIDEL)
shoot("audit61_torso_aimF36_sideR", SIDER)
shoot("audit61_torso_aimF36_3q", THREEQ)

# Clay overlays for ranked candidates (rest pose).
reset_pose()
weapon.hide_render = True
clay = bpy.data.materials.new("Audit61Clay")
clay.use_nodes = True
clay.node_tree.nodes["Principled BSDF"].inputs["Base Color"].default_value = (0.52, 0.54, 0.58, 1)
clay.node_tree.nodes["Principled BSDF"].inputs["Roughness"].default_value = 0.85
body.data.materials.clear(); body.data.materials.append(clay)
nrm = np.empty(n * 3, dtype=np.float64)
body.data.vertices.foreach_get("normal", nrm)
mw3 = np.array(body.matrix_world)[:3, :3]
NRM = nrm.reshape(-1, 3) @ mw3.T
body.data.calc_loop_triangles()
tris = np.array([t.vertices for t in body.data.loop_triangles], dtype=np.int64)
tri_isl = ISL[tris[:, 0]]
PALETTE = [(1,0.05,0.05),(1,0.5,0),(1,0.9,0),(0.2,1,0.2),(0,0.9,1),(0.2,0.35,1),(0.65,0.15,1),(1,0.1,0.8),
           (0.6,1,0.8),(1,0.75,0.45),(0.75,1,0.35),(0.4,0.75,1),(0.9,0.45,1),(1,0.35,0.6)]


def emissive(name, rgb):
    m = bpy.data.materials.new(name); m.use_nodes = True
    b = m.node_tree.nodes["Principled BSDF"]
    b.inputs["Base Color"].default_value = (*rgb, 1)
    b.inputs["Emission Color"].default_value = (*rgb, 1)
    b.inputs["Emission Strength"].default_value = 0.8
    b.inputs["Roughness"].default_value = 0.6
    return m


for rank, iid in enumerate(CANDIDATES):
    rgb = PALETTE[rank % len(PALETTE)]
    vmask = ISL == iid
    vids = np.flatnonzero(vmask)
    remap = {int(v0): j for j, v0 in enumerate(vids)}
    faces = []
    for t in tris[tri_isl == iid]:
        if vmask[t[0]] and vmask[t[1]] and vmask[t[2]]:
            faces.append([remap[int(t[0])], remap[int(t[1])], remap[int(t[2])]])
    pts = P0[vids] + NRM[vids] * 0.0016
    me = bpy.data.meshes.new(f"HL61_{iid}")
    me.from_pydata(pts.tolist(), [], faces)
    ob = bpy.data.objects.new(f"HL61_{iid}", me)
    sc.collection.objects.link(ob)
    me.materials.append(emissive(f"HL61mat_{iid}", rgb))
    print(f"HIGHLIGHT rank={rank} isl={iid} color={rgb} verts={len(vids)} cen={np.round(icen[iid],3)}")
shoot("audit61_candidates_front", FRONT)
shoot("audit61_candidates_sideL", SIDEL)
shoot("audit61_candidates_sideR", SIDER)
shoot("audit61_candidates_back", (0, 0.92, 0.62))
print("DONE (read-only; blend not saved)")
