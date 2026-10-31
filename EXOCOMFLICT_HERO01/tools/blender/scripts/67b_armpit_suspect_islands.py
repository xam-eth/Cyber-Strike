"""67b - Identify the island(s) forming the armpit fin at full arm raise
(audit only). Poses each arm into ~105deg abduction, finds torso-region
verts displaced >30mm, groups by mesh island, prints island stats and
renders the suspects in red over a ghost body.
Run: tools/blender/run_bpy.sh tools/blender/scripts/67b_armpit_suspect_islands.py
"""
import bpy
import math
import numpy as np
from collections import deque
from mathutils import Vector

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

EP = np.empty(len(me.edges) * 2, np.int64); me.edges.foreach_get("vertices", EP); EP = EP.reshape(-1, 2)
adj = [[] for _ in range(NV)]
for a, b in EP:
    adj[a].append(b); adj[b].append(a)
isl = np.full(NV, -1, np.int64); nid = 0
for s0 in range(NV):
    if isl[s0] >= 0: continue
    q = deque([s0]); isl[s0] = nid
    while q:
        u = q.popleft()
        for w_ in adj[u]:
            if isl[w_] < 0: isl[w_] = nid; q.append(w_)
    nid += 1
cnt = np.bincount(isl, minlength=nid)

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
    la = (RESTMAT[bone].to_3x3().inverted() @ Vector(axis_world)).normalized()
    pb.rotation_mode = "AXIS_ANGLE"
    pb.rotation_axis_angle = (math.radians(deg), la.x, la.y, la.z)
    bpy.context.view_layer.update()

suspects_total = np.zeros(NV, bool)
for S, sgn in (("R", 1), ("L", -1)):
    reset()
    rot(f"UpperArm_{S}", (0, 1, 0), 105 * sgn)
    p = evco()
    hand_rest = np.array(arm.data.bones[f"Hand_{S}"].head_local)
    hr = rest[np.linalg.norm(rest - hand_rest, axis=1).argmin()]
    hp = p[np.linalg.norm(rest - hand_rest, axis=1).argmin()]
    d = np.linalg.norm(p - rest, axis=1)
    torso_region = (np.abs(x) < 0.17) & (z > 0.50) & (z < 0.80)
    sus = torso_region & (d > 0.030)
    suspects_total |= sus
    print(f"RAISE_{S}: hand z {hr[2]:.3f}->{hp[2]:.3f} suspect verts={int(sus.sum())}", flush=True)
    by_isl = {}
    for vi in np.nonzero(sus)[0]:
        by_isl.setdefault(int(isl[vi]), []).append(int(vi))
    for iid, vs in sorted(by_isl.items(), key=lambda kv: -len(kv[1])):
        m = isl == iid
        bb = np.stack([co[m].min(0), co[m].max(0)])
        wmean = W[m].mean(0)
        top = np.argsort(wmean)[::-1][:3]
        print(f"  isl{iid:4d} size={int(cnt[iid]):6d} suspects={len(vs):5d} maxdisp={d[m].max()*1000:6.1f}mm "
              f"bbox x[{bb[0,0]:+.3f},{bb[1,0]:+.3f}] y[{bb[0,1]:+.3f},{bb[1,1]:+.3f}] z[{bb[0,2]:+.3f},{bb[1,2]:+.3f}] "
              f"topW " + " ".join(f"{names[t]}={wmean[t]:.2f}" for t in top), flush=True)
reset()
bpy.ops.object.mode_set(mode="OBJECT")

# ---- render suspects red over ghost ----
sc = bpy.context.scene
sc.render.engine = "CYCLES"; sc.cycles.samples = 16; sc.cycles.use_denoising = True; sc.cycles.device = "CPU"
sc.cycles.transparent_max_bounces = 8
world = bpy.data.worlds.new("W67b"); sc.world = world; world.use_nodes = True
world.node_tree.nodes["Background"].inputs[0].default_value = (0.32, 0.33, 0.35, 1)
sd = bpy.data.lights.new("S67b", "SUN"); sd.energy = 3.0
so = bpy.data.objects.new("S67b", sd); sc.collection.objects.link(so)
so.rotation_euler = (math.radians(52), math.radians(8), math.radians(-38))
ghost = body.copy(); ghost.name = "GHOST67b"
ghost.data = me.copy()
GM = bpy.data.materials.new("Ghost67b"); GM.use_nodes = True
nt = GM.node_tree; nt.nodes.clear()
outn = nt.nodes.new("ShaderNodeOutputMaterial")
mix = nt.nodes.new("ShaderNodeMixShader"); mix.inputs[0].default_value = 0.30
trans = nt.nodes.new("ShaderNodeBsdfTransparent")
diff = nt.nodes.new("ShaderNodeBsdfDiffuse"); diff.inputs[0].default_value = (0.75, 0.78, 0.82, 1)
nt.links.new(trans.outputs[0], mix.inputs[1]); nt.links.new(diff.outputs[0], mix.inputs[2])
nt.links.new(mix.outputs[0], outn.inputs[0])
ghost.data.materials.clear(); ghost.data.materials.append(GM)
ghost.modifiers.clear()
sc.collection.objects.link(ghost)
# suspect-only mesh
sus_isl = set(int(i) for i in np.unique(isl[suspects_total]))
keep_faces = []
nv2 = len(me.polygons)
poly_verts = np.empty(len(me.loops), np.int64); me.loops.foreach_get("vertex_index", poly_verts)
loop_start = np.empty(nv2, np.int64); me.polygons.foreach_get("loop_start", loop_start)
loop_total = np.empty(nv2, np.int64); me.polygons.foreach_get("loop_total", loop_total)
faces = []
used = np.zeros(NV, bool)
for pi in range(nv2):
    vs = poly_verts[loop_start[pi]:loop_start[pi] + loop_total[pi]]
    if len(vs) and int(isl[vs[0]]) in sus_isl:
        faces.append([int(v) for v in vs]); used[vs] = True
remap = -np.ones(NV, np.int64); remap[used] = np.arange(int(used.sum()))
med = bpy.data.meshes.new("SUSPECTS67b")
med.from_pydata([tuple(c) for c in co[used]], [], [[int(remap[v]) for v in f] for f in faces])
RED = bpy.data.materials.new("SusRed"); RED.use_nodes = True
em = RED.node_tree.nodes.new("ShaderNodeEmission"); em.inputs[0].default_value = (1, 0.1, 0.05, 1); em.inputs[1].default_value = 2.5
RED.node_tree.links.new(em.outputs[0], RED.node_tree.nodes["Material Output"].inputs[0])
med.materials.append(RED)
sob = bpy.data.objects.new("SUSPECTS67b", med); sc.collection.objects.link(sob)
body.hide_render = True; arm.hide_render = True
cam = bpy.data.objects.new("C67b", bpy.data.cameras.new("C67b")); sc.collection.objects.link(cam); sc.camera = cam
for name, loc, tgt in (("front", (0, -1.6, 0.66), (0, 0, 0.62)), ("back", (0, 1.6, 0.66), (0, 0, 0.62))):
    cam.data.lens = 55; cam.location = loc
    cam.rotation_euler = (Vector(tgt) - Vector(loc)).to_track_quat("-Z", "Y").to_euler()
    sc.render.resolution_x = sc.render.resolution_y = 800
    sc.render.filepath = f"{OUT}/audit67b_suspects_{name}.png"
    bpy.ops.render.render(write_still=True)
    print("RENDERED", name, flush=True)
print(f"SUSPECT ISLANDS: {sorted(sus_isl)}", flush=True)
print("DONE 67b", flush=True)
