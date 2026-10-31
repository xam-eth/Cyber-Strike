"""62 - Vertex-level jacket/abdomen diagnosis (READ-ONLY).

Script 61 proved waist-accessory islands are 100% arm-weighted and showed the
front jacket flap jutting with the raised arm in side view. Island averages
cannot describe the flap/abdomen if they belong to the giant main shell, so
this script works per-vertex:

* distance from every BODY vertex to each arm bone polyline
  (Clavicle -> UpperArm -> Forearm -> Hand), separating arm surface from
  torso clothing that merely rests near the hanging arm;
* front-flap / abdomen / waist-accessory spatial zones, their island
  composition, arm-weight mass and vertical (z-bin) leakage profile;
* isolated shoulder-flex displacement statistics per zone (centroid and
  per-vertex percentiles), driven through the real armature modifier;
* waist-region island classification by arm-polyline distance: belt/pouch
  accessories sit well off the arm axis, true arm shells hug it;
* renders: an RGB weight heat-map (R=left arm, G=spine chain, B=right arm)
  and a clay render highlighting clear-clothing vertices that still carry
  arm weight.

Run: tools/blender/run_bpy.sh tools/blender/scripts/62_jacket_vertex_diagnosis.py
Never saves the blend.
"""
import bpy
import numpy as np
from collections import deque
from mathutils import Matrix, Vector

BLEND = "/home/user/Cyber-Strike/EXOCOMFLICT_HERO01/blender/HERO_01_working.blend"
OUT = "/home/user/Cyber-Strike/EXOCOMFLICT_HERO01/screenshots/rig"
SPINE = ["Hips", "Spine", "Chest", "UpperChest"]
ARM_L = ["Clavicle_L", "UpperArm_L", "Forearm_L", "Hand_L"]
ARM_R = ["Clavicle_R", "UpperArm_R", "Forearm_R", "Hand_R"]
LEG = ["UpperLeg_L", "LowerLeg_L", "Foot_L", "UpperLeg_R", "LowerLeg_R", "Foot_R"]

bpy.ops.wm.open_mainfile(filepath=BLEND)
ARM = bpy.data.objects["HERO_01_Armature"]
BODY = bpy.data.objects["HERO_01_BODY"]
me = BODY.data
NV = len(me.vertices)
co = np.empty(NV * 3); me.vertices.foreach_get("co", co); co = co.reshape(-1, 3)
gnames = [g.name for g in BODY.vertex_groups]
gidx = {n: i for i, n in enumerate(gnames)}
W = np.zeros((NV, len(gnames)), np.float64)
for v in me.vertices:
    for ge in v.groups:
        W[v.index, ge.group] = ge.weight
rs = W.sum(1); rs[rs == 0] = 1.0; W = W / rs[:, None]

def wsum(names):
    return W[:, [gidx[n] for n in names if n in gidx]].sum(1)

armL_w, armR_w, spine_w, leg_w = wsum(ARM_L), wsum(ARM_R), wsum(SPINE), wsum(LEG)
arm_w = armL_w + armR_w

# ---------- islands ----------
EP = np.empty(len(me.edges) * 2, np.int64); me.edges.foreach_get("vertices", EP); EP = EP.reshape(-1, 2)
adj = [[] for _ in range(NV)]
for a, b in EP:
    adj[a].append(b); adj[b].append(a)
isl = np.full(NV, -1, np.int64); nid = 0
for s in range(NV):
    if isl[s] >= 0: continue
    q = deque([s]); isl[s] = nid
    while q:
        u = q.popleft()
        for w_ in adj[u]:
            if isl[w_] < 0: isl[w_] = nid; q.append(w_)
    nid += 1
cnt = np.bincount(isl, minlength=nid).astype(np.float64)
print(f"BODY verts={NV} islands={nid} largest_island_verts={int(cnt.max())}")

# ---------- distance to arm polylines ----------
bones = ARM.data.bones
def bone_pts(side):
    pts = []
    for n in [f"Clavicle_{side}", f"UpperArm_{side}", f"Forearm_{side}", f"Hand_{side}"]:
        pts.append(np.array(bones[n].head_local))
    pts.append(np.array(bones[f"Hand_{side}"].tail_local))
    return pts

def dist_to_polyline(P, pts):
    dmin = np.full(len(P), 1e9)
    for a, b in zip(pts[:-1], pts[1:]):
        ab = b - a
        t = np.clip(((P - a) @ ab) / max(float(ab @ ab), 1e-12), 0.0, 1.0)
        proj = a + t[:, None] * ab
        dmin = np.minimum(dmin, np.linalg.norm(P - proj, axis=1))
    return dmin

dL = dist_to_polyline(co, bone_pts("L"))
dR = dist_to_polyline(co, bone_pts("R"))
dArm = np.minimum(dL, dR)
print("arm-polyline distance percentiles (all verts): " +
      " ".join(f"p{p}={np.percentile(dArm, p):.3f}" for p in (10, 25, 50, 75, 90)))

# ---------- evaluated positions for isolated poses ----------
dg = bpy.context.evaluated_depsgraph_get()
def eval_positions():
    ev = BODY.evaluated_get(dg); m2 = ev.to_mesh()
    p = np.empty(NV * 3); m2.vertices.foreach_get("co", p); p = p.reshape(-1, 3)
    ev.to_mesh_clear(); return p

def clear_pose():
    for pb in ARM.pose.bones:
        pb.rotation_mode = "XYZ"; pb.rotation_euler = (0, 0, 0); pb.location = (0, 0, 0)

ARM.animation_data.action = None
clear_pose(); bpy.context.view_layer.update()
rest_pos = eval_positions()
print(f"rest eval max|co-rest|={np.abs(rest_pos - co).max():.2e}")

poses = {}
for tag, bone in [("SHOULDER_L", "UpperArm_L"), ("SHOULDER_R", "UpperArm_R")]:
    clear_pose(); ARM.pose.bones[bone].rotation_euler[0] = np.radians(-60.0)
    bpy.context.view_layer.update(); poses[tag] = eval_positions()
clear_pose(); bpy.context.view_layer.update()

# ---------- zones ----------
x, y, z = co[:, 0], co[:, 1], co[:, 2]
ZONES = {
    "FLAP_L": (x >= 0.035) & (x <= 0.125) & (y >= -0.105) & (y <= -0.045) & (z >= 0.46) & (z <= 0.84),
    "FLAP_R": (x <= -0.035) & (x >= -0.125) & (y >= -0.105) & (y <= -0.045) & (z >= 0.46) & (z <= 0.84),
    "ABDOMEN_CORE": (np.abs(x) <= 0.085) & (y >= -0.105) & (y <= -0.030) & (z >= 0.46) & (z <= 0.68),
    "WAIST_ACC_L": (x >= 0.070) & (x <= 0.160) & (y >= -0.105) & (y <= 0.050) & (z >= 0.52) & (z <= 0.66),
    "WAIST_ACC_R": (x <= -0.070) & (x >= -0.160) & (y >= -0.105) & (y <= 0.050) & (z >= 0.52) & (z <= 0.66),
    "JACKET_LOWER_L": (x >= 0.080) & (x <= 0.160) & (y >= -0.090) & (y <= 0.070) & (z >= 0.60) & (z <= 0.78),
    "JACKET_LOWER_R": (x <= -0.080) & (x >= -0.160) & (y >= -0.090) & (y <= 0.070) & (z >= 0.60) & (z <= 0.78),
}
torso_box = (np.abs(x) <= 0.170) & (y >= -0.115) & (y <= 0.095) & (z >= 0.42) & (z <= 0.845)
ZONES["CLEAR_CLOTHING"] = torso_box & (dArm >= 0.055)
ZONES["CLEAR_CLOTHING_ARMED"] = ZONES["CLEAR_CLOTHING"] & (arm_w > 0.05)
ZONES["TRANSITION_ARMED"] = torso_box & (dArm >= 0.040) & (dArm < 0.070) & (arm_w > 0.05)

def top_groups(mask, n=6):
    if mask.sum() == 0: return "-"
    m = W[mask].mean(0)
    return ", ".join(f"{gnames[i]}={m[i]:.3f}" for i in np.argsort(m)[::-1][:n] if m[i] > 0.004)

def island_mix(mask, n=5):
    if mask.sum() == 0: return "-"
    c = np.bincount(isl[mask], minlength=nid)
    out = []
    for i in np.argsort(c)[::-1][:n]:
        if c[i] == 0: break
        sel = mask & (isl == i)
        out.append(f"isl{i}:{c[i]}v armW={arm_w[sel].mean():.2f} islSize={int(cnt[i])}")
    return " | ".join(out)

print("\n================ ZONES ================")
for name, mask in ZONES.items():
    n = int(mask.sum())
    print(f"\n{name}: verts={n} meanArmW={arm_w[mask].mean() if n else 0:.3f} "
          f"meanSpineW={spine_w[mask].mean() if n else 0:.3f} meanLegW={leg_w[mask].mean() if n else 0:.3f}")
    print(f"  top: {top_groups(mask)}")
    print(f"  islands: {island_mix(mask)}")
    if n:
        print(f"  dArm p10/p50/p90 = {np.percentile(dArm[mask],10):.3f}/{np.percentile(dArm[mask],50):.3f}/{np.percentile(dArm[mask],90):.3f}"
              f"  armW p50/p90/max = {np.percentile(arm_w[mask],50):.2f}/{np.percentile(arm_w[mask],90):.2f}/{arm_w[mask].max():.2f}")
    for tag, P in poses.items():
        if n == 0: break
        D = P[mask] - rest_pos[mask]
        dn = np.linalg.norm(D, axis=1)
        cen = D.mean(0)
        print(f"  {tag}: centroid d=[{cen[0]*1000:+.1f},{cen[1]*1000:+.1f},{cen[2]*1000:+.1f}]mm "
              f"per-vert |d| p50={np.percentile(dn,50)*1000:.1f} p90={np.percentile(dn,90)*1000:.1f} max={dn.max()*1000:.1f} dz p90={np.percentile(D[:,2],90)*1000:+.1f}")

print("\n================ FLAP Z-BINS (0.04) ================")
for name in ("FLAP_L", "FLAP_R"):
    mask = ZONES[name]
    side_w = armL_w if name.endswith("_L") else armR_w
    P = poses["SHOULDER_L"] if name.endswith("_L") else poses["SHOULDER_R"]
    print(name)
    for zlo in np.arange(0.46, 0.84, 0.04):
        m = mask & (z >= zlo) & (z < zlo + 0.04)
        if m.sum() < 20: continue
        D = P[m] - rest_pos[m]
        print(f"  z[{zlo:.2f},{zlo+0.04:.2f}) n={int(m.sum()):5d} armSideW mean={side_w[m].mean():.3f} p90={np.percentile(side_w[m],90):.3f} "
              f"spineW={spine_w[m].mean():.3f} dArm p50={np.percentile(dArm[m],50):.3f} "
              f"isol |d| p50={np.percentile(np.linalg.norm(D,axis=1),50)*1000:.1f}mm dz mean={D[:,2].mean()*1000:+.1f}mm")

print("\n================ WAIST-REGION ISLAND CLASSIFICATION ================")
icen = np.stack([np.bincount(isl, weights=co[:, k], minlength=nid) / cnt for k in range(3)], 1)
rows = []
for i in range(nid):
    if cnt[i] < 25: continue
    sel = isl == i
    mn, mx = co[sel].min(0), co[sel].max(0)
    if not (mx[2] >= 0.52 and mn[2] <= 0.66 and mx[0] >= 0.06 and mn[0] <= 0.17 or
            mx[2] >= 0.52 and mn[2] <= 0.66 and mn[0] <= -0.06 and mx[0] >= -0.17):
        # keep only islands intersecting the waist side bands
        if not (mx[2] >= 0.52 and mn[2] <= 0.66 and ((mx[0] >= 0.06 and mn[0] <= 0.17) or (mn[0] <= -0.06 and mx[0] >= -0.17))):
            continue
    if arm_w[sel].mean() < 0.30: continue
    dim = mx - mn
    rows.append((float(np.median(dArm[sel])), i, sel, mn, mx, dim))
rows.sort(reverse=True)
for dmed, i, sel, mn, mx, dim in rows:
    print(f" isl={i:3d} n={int(cnt[i]):5d} cen=({icen[i,0]:+.3f},{icen[i,1]:+.3f},{icen[i,2]:+.3f}) "
          f"dim=({dim[0]:.3f},{dim[1]:.3f},{dim[2]:.3f}) dArmMed={dmed:.3f} armW={arm_w[sel].mean():.2f} "
          f"{'ACCESSORY?' if dmed >= 0.040 else 'arm-shell?'} top {top_groups(sel, 3)}")

# ---------- renders ----------
scene = bpy.context.scene
scene.render.engine = "CYCLES"
scene.cycles.samples = 16
scene.cycles.use_denoising = True
scene.cycles.device = "CPU"
scene.render.resolution_x = scene.render.resolution_y = 1100
scene.render.resolution_percentage = 100
world = bpy.data.worlds.new("W62"); world.use_nodes = True
world.node_tree.nodes["Background"].inputs[0].default_value = (0.32, 0.33, 0.35, 1)
world.node_tree.nodes["Background"].inputs[1].default_value = 1.0
scene.world = world
sun_data = bpy.data.lights.new("S62", "SUN"); sun_data.energy = 3.0
sun = bpy.data.objects.new("S62", sun_data); scene.collection.objects.link(sun)
sun.rotation_euler = (np.radians(55), np.radians(15), np.radians(-35))
cam_data = bpy.data.cameras.new("C62"); cam_data.type = "ORTHO"; cam_data.ortho_scale = 0.62
cam = bpy.data.objects.new("C62", cam_data); scene.collection.objects.link(cam); scene.camera = cam

def look(cam, loc, target):
    cam.location = loc
    d = Vector(target) - Vector(loc)
    cam.rotation_euler = d.to_track_quat("-Z", "Y").to_euler()

T = (0.0, -0.01, 0.63)
VIEWS = {
    "front": ((0, -1.5, 0.63), T), "sideL": ((1.5, -0.01, 0.63), T),
    "sideR": ((-1.5, -0.01, 0.63), T), "back": ((0, 1.5, 0.63), T),
    "3q": ((0.85, -1.05, 0.78), T),
}

def render_views(prefix, views=("front", "sideL", "sideR", "back")):
    for v in views:
        look(cam, *VIEWS[v])
        scene.render.filepath = f"{OUT}/{prefix}_{v}.png"
        bpy.ops.render.render(write_still=True)
        print("RENDERED", prefix, v)

# Heat-map copy: R=armL, G=spine, B=armR (+0.06 floor so unweighted reads dark)
heat = BODY.copy(); heat.data = me.copy(); heat.name = "HEAT62"
scene.collection.objects.link(heat)
hm = heat.data
hm.materials.clear()
colattr = hm.color_attributes.new(name="RigHeat", type="FLOAT_COLOR", domain="POINT")
rgba = np.zeros((NV, 4), np.float32)
rgba[:, 0] = 0.06 + 0.94 * armL_w
rgba[:, 1] = 0.06 + 0.94 * spine_w
rgba[:, 2] = 0.06 + 0.94 * armR_w
rgba[:, 3] = 1.0
colattr.data.foreach_set("color", rgba.ravel())
hmat = bpy.data.materials.new("RigHeatMat"); hmat.use_nodes = True
nt = hmat.node_tree
bsdf = nt.nodes["Principled BSDF"]; bsdf.inputs["Roughness"].default_value = 0.7
attr = nt.nodes.new("ShaderNodeAttribute"); attr.attribute_name = "RigHeat"
nt.links.new(attr.outputs["Color"], bsdf.inputs["Base Color"])
hm.materials.append(hmat)
for p in hm.polygons: p.material_index = 0
for o in bpy.data.objects:
    if o.type == "MESH" and o is not heat: o.hide_render = True
ARM.hide_render = True
render_views("audit62_heatmap", views=("front", "sideL", "sideR", "back", "3q"))

# Clay copy: clear-clothing armed verts magenta, transition armed yellow.
heat.hide_render = True
clay = BODY.copy(); clay.data = me.copy(); clay.name = "CLAY62"
scene.collection.objects.link(clay)
clay.hide_render = False  # copy() inherited hide_render=True from BODY
cm = clay.data; cm.materials.clear()
def simple_mat(name, color):
    m = bpy.data.materials.new(name); m.use_nodes = True
    m.node_tree.nodes["Principled BSDF"].inputs["Base Color"].default_value = (*color, 1)
    m.node_tree.nodes["Principled BSDF"].inputs["Roughness"].default_value = 0.85
    return m
cm.materials.append(simple_mat("ClayBase62", (0.55, 0.57, 0.60)))
cm.materials.append(simple_mat("ClayClear62", (1.0, 0.05, 0.75)))
cm.materials.append(simple_mat("ClayTrans62", (1.0, 0.85, 0.0)))
LP = np.empty(len(cm.loops), np.int64); cm.loops.foreach_get("vertex_index", LP)
PS = np.empty(len(cm.polygons), np.int64); cm.polygons.foreach_get("loop_start", PS)
PT = np.empty(len(cm.polygons), np.int64); cm.polygons.foreach_get("loop_total", PT)
clear_mask = ZONES["CLEAR_CLOTHING_ARMED"]; trans_mask = ZONES["TRANSITION_ARMED"]
for pi in range(len(cm.polygons)):
    vs = LP[PS[pi]:PS[pi] + PT[pi]]
    if clear_mask[vs].mean() >= 0.5: cm.polygons[pi].material_index = 1
    elif trans_mask[vs].mean() >= 0.5: cm.polygons[pi].material_index = 2
    else: cm.polygons[pi].material_index = 0
render_views("audit62_clearclothing", views=("front", "sideL", "sideR", "back", "3q"))

# Candidate-island identification: one unique colour per suspect island.
import colorsys
CAND62 = [147, 146, 134, 119, 185, 124, 13, 125, 47, 187, 106, 43, 182, 123, 110, 48, 25, 60]
cm.materials.clear()
cm.materials.append(simple_mat("ClayBase62b", (0.45, 0.47, 0.50)))
for k, iid in enumerate(CAND62):
    cm.materials.append(simple_mat(f"Isl62_{iid}", colorsys.hsv_to_rgb(k / len(CAND62), 0.95, 1.0)))
    sel = isl == iid
    print(f"ISLCOLOR idx={k+1} isl={iid} n={int(cnt[iid])} cen=({icen[iid,0]:+.3f},{icen[iid,1]:+.3f},{icen[iid,2]:+.3f}) hue={k/len(CAND62):.2f}", flush=True)
slot = {iid: k + 1 for k, iid in enumerate(CAND62)}
for pi in range(len(cm.polygons)):
    v0 = LP[PS[pi]]
    cm.polygons[pi].material_index = slot.get(int(isl[v0]), 0)
render_views("audit62_islands", views=("front", "sideL", "sideR", "back"))
print("DONE 62 (read-only; blend not saved)")
