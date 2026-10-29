"""READ-ONLY diagnostic for undersuit v5 design (VALIDATION_REPORT 5.9).
Maps the first non-arm surface hit from left/front/front-left rays around the verified
front-left hip void, prints skeleton centerline and radial cross-section stats around that
centerline, and identifies islands near the void probe point. Does not modify or save."""
import bpy
import numpy as np
from mathutils import Vector
from mathutils.bvhtree import BVHTree
from mathutils.kdtree import KDTree

PROJ = "/home/user/Cyber-Strike/EXOCOMFLICT_HERO01"
bpy.ops.wm.open_mainfile(filepath=f"{PROJ}/blender/HERO_01_working.blend")
sc = bpy.context.scene
sc.frame_set(0)
bpy.context.view_layer.update()
arm = bpy.data.objects["HERO_01_Armature"]
body = bpy.data.objects["HERO_01_BODY"]
me = body.data
n = len(me.vertices)
gnames = [g.name for g in body.vertex_groups]
print("body matrix_world translation/scale:", tuple(body.matrix_world.translation), tuple(body.matrix_world.to_scale()))
print("polygons:", len(me.polygons))

# Island/arm classification (same method as scripts 35-41).
ne = len(me.edges)
ev = np.empty(ne * 2, dtype=np.int64)
me.edges.foreach_get("vertices", ev)
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
uniq, island = np.unique(roots, return_inverse=True)
co0 = np.empty(n * 3)
me.vertices.foreach_get("co", co0)
P0 = co0.reshape(-1, 3)
W = np.zeros((len(uniq), len(gnames)))
cnt = np.zeros(len(uniq))
for v in me.vertices:
    i = island[v.index]
    cnt[i] += 1
    for g in v.groups:
        W[i, g.group] += g.weight
W /= np.maximum(cnt, 1)[:, None]
ARM = {"Clavicle_L", "Clavicle_R", "UpperArm_L", "UpperArm_R", "Forearm_L",
       "Forearm_R", "Hand_L", "Hand_R", "Weapon_R"}
arm_idx = [gnames.index(a) for a in ARM if a in gnames]
arm_mean = W[:, arm_idx].sum(axis=1)
dom = [gnames[int(np.argmax(W[i]))] for i in range(len(uniq))]
nonarm_vert = np.array([arm_mean[island[v]] < 0.05 for v in range(n)])
poly_isl = np.array([island[p.vertices[0]] for p in me.polygons], dtype=np.int64)

# Skeleton centerline in world coordinates.
print("BONES (head world):")
bone_pts = {}
for bn in ("Hips", "Spine", "Chest", "UpperChest", "Neck"):
    b = arm.data.bones.get(bn)
    if b:
        hw = arm.matrix_world @ b.head_local
        tw = arm.matrix_world @ b.tail_local
        bone_pts[bn] = np.array(hw)
        print(f" {bn}: head={np.round(hw,4)} tail={np.round(tw,4)}")
cl_names = [bn for bn in ("Hips", "Spine", "Chest", "UpperChest", "Neck") if bn in bone_pts]
cl = np.array([bone_pts[bn] for bn in cl_names])
def centerline(z):
    return np.array([np.interp(z, cl[:, 2], cl[:, 0]),
                     np.interp(z, cl[:, 2], cl[:, 1]), z])

# Nearest source verts/islands to the script-37 void probe.
kd = KDTree(n)
for i, co in enumerate(P0):
    kd.insert(co, i)
kd.balance()
probe = Vector((0.146, -0.055, 0.531))
print("NEAREST TO VOID PROBE (0.146,-0.055,0.531):")
for loc, idx, dist in kd.find_n(probe, 8):
    isl = int(island[idx])
    print(f" v={idx} d={dist*1000:.1f}mm isl={isl} size={int(cnt[isl])} dom={dom[isl]} arm={arm_mean[isl]:.2f} co={np.round(P0[idx],4)}")

# Radial stats around the SKELETON centerline (character front=-90deg, left=0deg).
print("RADIAL STATS around skeleton centerline (p50/p72/p90/max, non-arm verts):")
for zk in (0.50, 0.52, 0.54, 0.56, 0.58, 0.60):
    c = centerline(zk)
    m = nonarm_vert & (np.abs(P0[:, 2] - zk) < 0.006)
    pts = P0[m]
    d = pts[:, :2] - c[:2]
    rr = np.linalg.norm(d, axis=1)
    aa = np.rad2deg(np.arctan2(d[:, 1], d[:, 0]))
    cells = []
    for ad in (-80, -60, -40, -20, 0, 20):
        da = np.abs((aa - ad + 180) % 360 - 180)
        vals = rr[da < 4.5]
        if len(vals) >= 3:
            cells.append(f"{ad:+d}:{np.percentile(vals,50):.3f}/{np.percentile(vals,72):.3f}/{np.percentile(vals,90):.3f}/{vals.max():.3f}(n{len(vals)})")
        else:
            cells.append(f"{ad:+d}:--(n{len(vals)})")
    print(f" z={zk:.2f} c=({c[0]:+.3f},{c[1]:+.3f}) " + " ".join(cells))

# BVH ray maps on the evaluated rest mesh.
dg = bpy.context.evaluated_depsgraph_get()
bv = BVHTree.FromObject(body, dg)
def ray_hits(origin, direction, maxh=10):
    out = []
    o = Vector(origin)
    d = Vector(direction).normalized()
    for _ in range(maxh):
        loc, nor, idx, dist = bv.ray_cast(o, d)
        if loc is None:
            break
        out.append((Vector(loc), int(idx)))
        o = Vector(loc) + d * 0.0007
    return out
def first_nonarm(origin, direction):
    for loc, idx in ray_hits(origin, direction):
        if 0 <= idx < len(poly_isl):
            isl = int(poly_isl[idx])
            if arm_mean[isl] < 0.05:
                return loc, isl
    return None, None

loc, isl = first_nonarm((0, -0.45, 0.55), (0, 1, 0))
print("SANITY front center ray z=0.55 first non-arm hit:", None if loc is None else tuple(round(v,4) for v in loc), "isl", isl)

print("LEFT RAY MAP: first non-arm hit x (rows z, cols y). 'VOID'=no non-arm hit")
ys = np.arange(-0.10, 0.041, 0.01)
print("      " + "".join(f" y={y:+.2f}" for y in ys))
for zk in np.arange(0.62, 0.469, -0.01):
    row = []
    for y in ys:
        loc, isl2 = first_nonarm((0.45, float(y), float(zk)), (-1, 0, 0))
        row.append("  VOID " if loc is None else f" {loc.x:+.3f}")
    print(f" z={zk:.2f}" + "".join(row))

print("FRONT RAY MAP: first non-arm hit y (rows z, cols x). 'VOID'=no non-arm hit")
xs = np.arange(0.04, 0.181, 0.01)
print("      " + "".join(f" x={x:+.2f}" for x in xs))
for zk in np.arange(0.62, 0.469, -0.01):
    row = []
    for x in xs:
        loc, isl2 = first_nonarm((float(x), -0.45, float(zk)), (0, 1, 0))
        row.append("  VOID " if loc is None else f" {loc.y:+.3f}")
    print(f" z={zk:.2f}" + "".join(row))

print("FRONT-LEFT DIAGONAL RAY MAP: first non-arm hit location (rows z, cols offset s along (.707,.707)); VOID=no hit")
d = Vector((-0.7071, 0.7071, 0))
p = Vector((0.7071, 0.7071, 0))
ss = np.arange(-0.06, 0.151, 0.015)
print("      " + "".join(f" s={s:+.3f}" for s in ss))
for zk in np.arange(0.60, 0.489, -0.01):
    c = centerline(float(zk))
    row = []
    for s in ss:
        origin = Vector((c[0], c[1], float(zk))) + p * float(s) - d * 0.45
        loc, isl2 = first_nonarm(origin, d)
        row.append("   VOID  " if loc is None else f" ({loc.x:+.2f},{loc.y:+.2f})")
    print(f" z={zk:.2f}" + "".join(row))
print("DONE")
