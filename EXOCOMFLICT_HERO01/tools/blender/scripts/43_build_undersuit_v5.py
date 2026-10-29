"""Build HERO_01_UNDERSUIT v5: LOCAL inner patch fitted by BVH ray casts around the
SKELETON centerline (script 42 ray map). Owner-approved additive fix (VALIDATION_REPORT 5.9).
v4 used a gear-biased cross-section centroid and a red test colour that collides with the
gold armour palette. v5: for z 0.500-0.586 and angles -52..+18 deg (front=-90, left=0),
cast outside-in radial rays, take the first non-arm surface radius, interpolate across the
measured side gap, and inset the patch behind that surface with tucked edges. Gate uses a
PURE GREEN emissive (absent from the palette): no green outside the body silhouette, almost
none visible at F0, green plug visible in the hip slit at F36. Blend saved only after a
pristine reopen/rebuild with the final dark material. Source geometry/materials untouched."""
import bpy, math, os
import numpy as np
from mathutils import Vector
from mathutils.bvhtree import BVHTree
from PIL import Image, ImageFilter

PROJ = "/home/user/Cyber-Strike/EXOCOMFLICT_HERO01"
SHOT = f"{PROJ}/screenshots/diag"
BLEND = f"{PROJ}/blender/HERO_01_working.blend"
os.makedirs(SHOT, exist_ok=True)

bpy.ops.wm.open_mainfile(filepath=BLEND)
sc = bpy.context.scene
arm = bpy.data.objects["HERO_01_Armature"]
body = bpy.data.objects["HERO_01_BODY"]
me = body.data
n = len(me.vertices)
gnames = [g.name for g in body.vertex_groups]
ng = len(gnames)
sc.frame_set(0)
bpy.context.view_layer.update()
if "HERO_01_UNDERSUIT" in bpy.data.objects:
    bpy.data.objects.remove(bpy.data.objects["HERO_01_UNDERSUIT"], do_unlink=True)

# Island map + non-arm classification.
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
W = np.zeros((len(uniq), ng))
cnt = np.zeros(len(uniq))
vertW = [None] * n
for v in me.vertices:
    i = island[v.index]
    cnt[i] += 1
    vertW[v.index] = {gnames[g.group]: float(g.weight) for g in v.groups}
    for g in v.groups:
        W[i, g.group] += g.weight
W /= np.maximum(cnt, 1)[:, None]
ARM = {"Clavicle_L", "Clavicle_R", "UpperArm_L", "UpperArm_R", "Forearm_L",
       "Forearm_R", "Hand_L", "Hand_R", "Weapon_R"}
arm_idx = [gnames.index(a) for a in ARM if a in gnames]
arm_mean = W[:, arm_idx].sum(axis=1)
poly_isl = np.array([island[p.vertices[0]] for p in me.polygons], dtype=np.int64)

# Script-31 shared spine height field (for patch weights).
CHAIN = {"Root", "Hips", "Spine", "Chest", "UpperChest", "Neck"}
FB = ["Hips", "Spine", "Chest", "UpperChest", "Neck", "Root"]
chain = np.array([(set(vertW[i].keys()) <= CHAIN and len(vertW[i]) > 0) for i in range(n)])
zbins = np.arange(0.435, 0.8251, 0.004)
field = np.zeros((len(zbins), len(FB)))
fcnt = np.zeros(len(zbins))
sel = np.nonzero(chain & (P0[:, 2] >= zbins[0]) & (P0[:, 2] <= zbins[-1]))[0]
bi = np.clip(np.digitize(P0[sel, 2], zbins) - 1, 0, len(zbins) - 1)
for k, i in enumerate(sel):
    fcnt[bi[k]] += 1
    for j, bn in enumerate(FB):
        field[bi[k], j] += vertW[int(i)].get(bn, 0.0)
nz = fcnt > 0
field[nz] /= fcnt[nz][:, None]
run = None
for k in range(len(zbins)):
    if nz[k]:
        run = field[k]
    elif run is not None:
        field[k] = run
run = None
for k in range(len(zbins) - 1, -1, -1):
    if nz[k]:
        run = field[k]
    elif run is not None and fcnt[k] == 0:
        field[k] = run
ker = np.ones(5) / 5
for j in range(len(FB)):
    field[:, j] = np.convolve(np.pad(field[:, j], 2, mode='edge'), ker, mode='valid')
field /= np.maximum(field.sum(axis=1, keepdims=True), 1e-9)
def field_at(z):
    z = float(np.clip(z, zbins[0], zbins[-1]))
    t = (z - zbins[0]) / 0.004
    k0 = int(np.clip(np.floor(t), 0, len(zbins) - 1))
    k1 = min(k0 + 1, len(zbins) - 1)
    f = float(np.clip(t - k0, 0, 1))
    return field[k0] * (1 - f) + field[k1] * f

# Skeleton centerline.
cl = []
for bn in ("Hips", "Spine", "Chest", "UpperChest", "Neck"):
    b = arm.data.bones.get(bn)
    if b:
        cl.append(np.array(arm.matrix_world @ b.head_local))
cl = np.array(cl)
def centerline(z):
    return np.array([np.interp(z, cl[:, 2], cl[:, 0]),
                     np.interp(z, cl[:, 2], cl[:, 1]), float(z)])

# BVH radial fit: first non-arm surface radius per (z, angle).
dg = bpy.context.evaluated_depsgraph_get()
bv = BVHTree.FromObject(body, dg)
def first_nonarm_radius(c, d):
    o = Vector(c) + d * 0.38
    inward = -d
    for _ in range(16):
        loc, nor, idx, dist = bv.ray_cast(o, inward)
        if loc is None:
            return np.nan
        isl = int(poly_isl[idx]) if 0 <= int(idx) < len(poly_isl) else -1
        if isl < 0 or arm_mean[isl] >= 0.05:
            o = Vector(loc) + inward * 0.0007
            continue
        r = float((Vector(loc) - Vector(c)).dot(d))
        return r if 0.070 <= r <= 0.20 else np.nan
    return np.nan

ring_z = np.linspace(0.500, 0.586, 13)
angles_deg = np.linspace(-52.0, 18.0, 25)
angles = np.deg2rad(angles_deg)
centers = np.array([centerline(z) for z in ring_z])
raw = np.full((len(ring_z), len(angles)), np.nan)
for zi, zk in enumerate(ring_z):
    c = centers[zi]
    for ai, a in enumerate(angles):
        d = Vector((math.cos(a), math.sin(a), 0.0))
        raw[zi, ai] = first_nonarm_radius(c, d)
valid = ~np.isnan(raw)
print(f"ray fit: valid {int(valid.sum())}/{raw.size} cells; radius range "
      f"{np.nanmin(raw):.3f}..{np.nanmax(raw):.3f}")
fit = raw.copy()
for zi in range(fit.shape[0]):
    row = fit[zi]
    good = ~np.isnan(row)
    idx = np.arange(len(row))
    if good.sum() >= 2:
        row[:] = np.interp(idx, idx[good], row[good])
    elif good.sum() == 1:
        row[:] = row[good][0]
for ai in range(fit.shape[1]):
    col = fit[:, ai]
    good = ~np.isnan(col)
    idx = np.arange(len(col))
    if good.sum() >= 2:
        col[:] = np.interp(idx, idx[good], col[good])
fit = np.nan_to_num(fit, nan=0.11)
# Smooth, but never outward past a measured surface radius.
sm = fit.copy()
for _ in range(2):
    sm[:, 1:-1] = (sm[:, :-2] + 2 * sm[:, 1:-1] + sm[:, 2:]) / 4.0
sm[1:-1, :] = (sm[:-2, :] + 2 * sm[1:-1, :] + sm[2:, :]) / 4.0
fit_r = np.where(valid, np.minimum(sm, raw), sm)
for zi in (1, 4, 7, 10):
    cells = []
    for ad in (-50, -35, -20, -5, 10):
        ai = int(np.argmin(np.abs(angles_deg - ad)))
        cells.append(f"{ad:+d}:{fit_r[zi,ai]:.3f}{'' if valid[zi,ai] else '(interp)'}")
    print(f" ring z={ring_z[zi]:.3f} c=({centers[zi][0]:+.3f},{centers[zi][1]:+.3f}) " + " ".join(cells))

def build_patch(base_inset):
    verts = []
    nzr, na = fit_r.shape
    for zi, zk in enumerate(ring_z):
        c = centers[zi]
        ztuck = 1.0 if zi in (0, nzr - 1) else (0.5 if zi in (1, nzr - 2) else 0.0)
        for ai, a in enumerate(angles):
            atuck = 1.0 if ai in (0, na - 1) else (0.5 if ai in (1, na - 2) else 0.0)
            inset = base_inset + 0.016 * max(ztuck, atuck)
            r = max(0.028, fit_r[zi, ai] - inset)
            verts.append((float(c[0] + r * np.cos(a)), float(c[1] + r * np.sin(a)), float(zk)))
    polys = []
    for zi in range(nzr - 1):
        for ai in range(na - 1):
            polys.append((zi * na + ai, zi * na + ai + 1,
                          (zi + 1) * na + ai + 1, (zi + 1) * na + ai))
    return np.array(verts), polys

def make_object(verts, polys, mat):
    tm = bpy.data.meshes.new("HERO_01_UNDERSUIT")
    tm.from_pydata([tuple(v) for v in verts], [], polys)
    tm.update()
    tm.calc_loop_triangles()
    na = len(angles)
    test_poly = tm.polygons[(len(ring_z) // 2) * (na - 1) + na // 2]
    c = test_poly.center
    ctr = centers[len(ring_z) // 2]
    radial = np.array([c.x - ctr[0], c.y - ctr[1], 0.0])
    if float(np.dot(np.array(test_poly.normal), radial)) < 0:
        tm.flip_normals()
    for p in tm.polygons:
        p.use_smooth = True
    tob = bpy.data.objects.new("HERO_01_UNDERSUIT", tm)
    sc.collection.objects.link(tob)
    for name in gnames:
        tob.vertex_groups.new(name=name)
    vg = {g.name: g for g in tob.vertex_groups}
    for j, v in enumerate(verts):
        fv = field_at(v[2])
        acc = {FB[k]: float(fv[k]) for k in range(len(FB)) if fv[k] > 1e-4}
        top = sorted(acc.items(), key=lambda kv: -kv[1])[:4]
        s = sum(vv for _, vv in top) or 1.0
        for bn, val in top:
            if val / s > 1e-4:
                vg[bn].add([j], val / s, 'ADD')
    mod = tob.modifiers.new("Armature", 'ARMATURE')
    mod.object = arm
    tob.parent = body.parent
    tm.materials.append(mat)
    return tob

# Phase-1 GREEN gate (never saved).
green = bpy.data.materials.new("TMP_GREEN")
green.use_nodes = True
gb = green.node_tree.nodes["Principled BSDF"]
gb.inputs["Base Color"].default_value = (0, 0, 0, 1)
gb.inputs["Emission Color"].default_value = (0.03, 1, 0.03, 1)
gb.inputs["Emission Strength"].default_value = 1.6
sc.render.engine = "CYCLES"
sc.cycles.samples = 8
sc.cycles.use_denoising = False
sc.cycles.device = "CPU"
sc.cycles.seed = 7
try:
    sc.view_settings.view_transform = 'Standard'
except Exception as ex:
    print("view transform:", ex)
w = bpy.data.worlds.new("W")
sc.world = w
w.use_nodes = True
w.node_tree.nodes["Background"].inputs[0].default_value = (0.16, 0.17, 0.19, 1)
w.node_tree.nodes["Background"].inputs[1].default_value = 0.9
sd = bpy.data.lights.new("Sun", "SUN")
sd.energy = 3
so = bpy.data.objects.new("Sun", sd)
sc.collection.objects.link(so)
so.rotation_euler = (math.radians(52), math.radians(8), math.radians(-38))
cam = bpy.data.objects.new("Cam", bpy.data.cameras.new("Cam"))
cam.data.lens = 52
sc.collection.objects.link(cam)
sc.camera = cam
arm.hide_render = True
VIEWS = [("front", (0, -1.15, 0.56)), ("back", (0, 1.15, 0.56)),
         ("left", (1.15, -0.05, 0.56)), ("right", (-1.15, 0, 0.56)),
         ("fl", (0.82, -0.82, 0.60)), ("fr", (-0.82, -0.82, 0.60))]
TARGET = Vector((0, -0.02, 0.55))
def render_view(name, loc, tag):
    cam.location = loc
    cam.rotation_euler = (TARGET - Vector(loc)).to_track_quat('-Z', 'Y').to_euler()
    sc.render.resolution_x = 700
    sc.render.resolution_y = 700
    p = f"{SHOT}/usgate5_{tag}_{name}.png"
    sc.render.filepath = p
    bpy.ops.render.render(write_still=True)
    return p
def green_mask(path):
    a = np.asarray(Image.open(path).convert("RGB")).astype(int)
    return (a[:, :, 1] > 150) & ((a[:, :, 1] - a[:, :, 0]) > 60) & ((a[:, :, 1] - a[:, :, 2]) > 60)
def body_mask(path):
    a = np.asarray(Image.open(path).convert("RGB")).astype(int)
    bg = np.median(np.concatenate([
        a[:8, :8].reshape(-1, 3), a[:8, -8:].reshape(-1, 3),
        a[-8:, :8].reshape(-1, 3), a[-8:, -8:].reshape(-1, 3)]), axis=0)
    m = (np.abs(a - bg).max(axis=2) > 18)
    im = Image.fromarray((m * 255).astype(np.uint8)).filter(ImageFilter.MaxFilter(5))
    return np.asarray(im) > 0
def mask_bbox(m):
    ys, xs = np.nonzero(m)
    return None if len(xs) == 0 else (int(xs.min()), int(ys.min()), int(xs.max()), int(ys.max()))

masks = {}
for fr in (0, 36):
    sc.frame_set(fr)
    bpy.context.view_layer.update()
    base = []
    for name, loc in VIEWS:
        p = render_view(name, loc, f"F{fr:02d}mask")
        masks[(fr, name)] = body_mask(p)
        base.append(int(green_mask(p).sum()))
    print(f"masks F{fr} done; baseline green px per view={base}")

def gate(fr):
    sc.frame_set(fr)
    bpy.context.view_layer.update()
    worst = 0
    stats = {}
    for name, loc in VIEWS:
        p = render_view(name, loc, f"F{fr:02d}grn")
        gm = green_mask(p)
        mk = masks[(fr, name)]
        poke = int((gm & ~mk).sum())
        inside = int((gm & mk).sum())
        stats[name] = (poke, inside, mask_bbox(gm & mk))
        worst = max(worst, poke)
        print(f"  F{fr} {name}: poke={poke} inside_visible={inside} bbox={stats[name][2]}")
    return worst, stats

passed = False
win_inset = None
for base_inset in (0.014, 0.020, 0.026, 0.032):
    verts, polys = build_patch(base_inset)
    tob = make_object(verts, polys, green)
    print(f"ATTEMPT base_inset={base_inset*1000:.0f}mm verts={len(verts)} polys={len(polys)}")
    w0, s0 = gate(0)
    w36, s36 = gate(36)
    f0_inside_max = max(v[1] for v in s0.values())
    plug = s36["left"][1] + s36["fl"][1]
    print(f" -> worst poke F0={w0} F36={w36}; F0 inside max={f0_inside_max}; F36 plug px={plug}")
    bpy.data.objects.remove(tob, do_unlink=True)
    if w0 < 20 and w36 < 20 and f0_inside_max < 150 and 100 <= plug <= 9000:
        passed = True
        win_inset = base_inset
        break
print("PHASE1 passed:", passed, "base_inset:", win_inset)

if passed:
    bpy.ops.wm.open_mainfile(filepath=BLEND)
    sc = bpy.context.scene
    arm = bpy.data.objects["HERO_01_Armature"]
    body = bpy.data.objects["HERO_01_BODY"]
    if "HERO_01_UNDERSUIT" in bpy.data.objects:
        bpy.data.objects.remove(bpy.data.objects["HERO_01_UNDERSUIT"], do_unlink=True)
    dark = bpy.data.materials.new("HERO_01_UNDERSUIT_MAT")
    dark.use_nodes = True
    try:
        dark.use_backface_culling = False
    except Exception:
        pass
    db = dark.node_tree.nodes["Principled BSDF"]
    db.inputs["Base Color"].default_value = (0.055, 0.055, 0.065, 1)
    db.inputs["Roughness"].default_value = 0.92
    db.inputs["Metallic"].default_value = 0.0
    verts, polys = build_patch(win_inset)
    tob = make_object(verts, polys, dark)
    sc.frame_set(0)
    bpy.context.view_layer.update()
    bpy.ops.wm.save_mainfile()
    print(f"SAVED blend (base_inset={win_inset*1000:.0f}mm, verts={len(verts)}, polys={len(polys)})")
else:
    print("NOT SAVED: v5 gate failed")
print("DONE")
