"""SUPERSEDED - DO NOT RUN (gear-biased centroid + red/gold false positives; patch overlayed source pants shell; see 43). Build HERO_01_UNDERSUIT v4: LOCAL inner patch behind the verified front-left hip slit.
Owner-approved additive fix (VALIDATION_REPORT 5.9). v1 radial metric invalid; v2 had a
180-degree angle bug; v3 full torso tube followed belt/gear envelope and covered source
undershirt detail. v4 instead fits only the front-left sector (z 0.485-0.605, angle -82..+24
deg where front=-90 and character-left=0), inset behind the measured surface with deeply
tucked edges. Gate: red-material renders must be almost invisible at F0, never outside the
body silhouette, and visible only as a plug in the hip slit at F36. Blend saved only after a
pristine reopen/rebuild with the final dark material. Source geometry/materials untouched."""
import bpy, math, os
import numpy as np
from mathutils import Vector
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

# Island map and non-arm vertex classification.
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
nonarm_vert = np.array([arm_mean[island[v]] < 0.05 for v in range(n)])

# Refit script-31 shared spine height field for patch weights.
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

# Fit only the measured front-left sector around the void.
ring_z = np.arange(0.485, 0.6051, 0.010)
angles_deg = np.linspace(-82.0, 24.0, 27)
angles = np.deg2rad(angles_deg)
centers = []
fit_r = []
for zk in ring_z:
    m = nonarm_vert & (np.abs(P0[:, 2] - zk) < 0.008)
    pts = P0[m]
    lo = np.percentile(pts[:, :2], 2, axis=0)
    hi = np.percentile(pts[:, :2], 98, axis=0)
    c = np.array([(lo[0] + hi[0]) * 0.5, (lo[1] + hi[1]) * 0.5, zk])
    centers.append(c)
    d = pts[:, :2] - c[:2]
    rr = np.linalg.norm(d, axis=1)
    aa = np.arctan2(d[:, 1], d[:, 0])
    row = []
    for a in angles:
        da = np.abs((aa - a + np.pi) % (2 * np.pi) - np.pi)
        vals = rr[da < np.deg2rad(4.5)]
        if len(vals) < 5:
            vals = rr[da < np.deg2rad(8.0)]
        if len(vals) < 3:
            row.append(np.nan)
        else:
            # p72 tracks the clothing surface while rejecting a minority of
            # protruding gear vertices; explicit inset is applied later.
            row.append(float(np.percentile(vals, 72)))
    row = np.array(row, dtype=float)
    good = ~np.isnan(row)
    if good.any():
        idx = np.arange(len(row))
        row[:] = np.interp(idx, idx[good], row[good])
    fit_r.append(row)
centers = np.array(centers)
fit_r = np.array(fit_r)
# Gentle smoothing in angle and z; no periodic wrap because this is an open sector.
for _ in range(2):
    fit_r[:, 1:-1] = (fit_r[:, :-2] + 2 * fit_r[:, 1:-1] + fit_r[:, 2:]) / 4.0
fit_r[1:-1, :] = (fit_r[:-2, :] + 2 * fit_r[1:-1, :] + fit_r[2:, :]) / 4.0
print("patch rings:", len(ring_z), "angles:", len(angles_deg),
      "fit radius range:", round(float(fit_r.min()), 3), round(float(fit_r.max()), 3))
for zi in (2, 5, 8, 11):
    ai = int(np.argmin(np.abs(angles_deg + 20)))
    print(f" ring z={ring_z[zi]:.3f} center={np.round(centers[zi],3)} fit_r(-20deg)={fit_r[zi,ai]:.3f}")

def build_patch(base_inset):
    verts = []
    nzr, na = fit_r.shape
    for zi, zk in enumerate(ring_z):
        c = centers[zi]
        ztuck = 1.0 if zi in (0, nzr - 1) else (0.5 if zi in (1, nzr - 2) else 0.0)
        for ai, a in enumerate(angles):
            atuck = 1.0 if ai in (0, na - 1) else (0.5 if ai in (1, na - 2) else 0.0)
            inset = base_inset + 0.018 * max(ztuck, atuck)
            r = max(0.025, fit_r[zi, ai] - inset)
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
    # Orient the central polygon outward from the local body axis.
    na = len(angles)
    test_poly = tm.polygons[(len(ring_z) // 2) * (na - 1) + na // 2]
    c = test_poly.center
    radial = np.array([c.x - centers[len(ring_z) // 2][0],
                       c.y - centers[len(ring_z) // 2][1], 0.0])
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

# Phase-1 red gate. Nothing in this phase is saved.
red = bpy.data.materials.new("TMP_RED")
red.use_nodes = True
rb = red.node_tree.nodes["Principled BSDF"]
rb.inputs["Base Color"].default_value = (0, 0, 0, 1)
rb.inputs["Emission Color"].default_value = (1, 0.03, 0.03, 1)
rb.inputs["Emission Strength"].default_value = 1.6
sc.render.engine = "CYCLES"
sc.cycles.samples = 8
sc.cycles.use_denoising = False
sc.cycles.device = "CPU"
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
    p = f"{SHOT}/usgate4_{tag}_{name}.png"
    sc.render.filepath = p
    bpy.ops.render.render(write_still=True)
    return p
def body_mask(path):
    a = np.asarray(Image.open(path).convert("RGB")).astype(int)
    bg = np.median(np.concatenate([
        a[:8, :8].reshape(-1, 3), a[:8, -8:].reshape(-1, 3),
        a[-8:, :8].reshape(-1, 3), a[-8:, -8:].reshape(-1, 3)]), axis=0)
    m = (np.abs(a - bg).max(axis=2) > 18)
    im = Image.fromarray((m * 255).astype(np.uint8)).filter(ImageFilter.MaxFilter(5))
    return np.asarray(im) > 0
def red_mask(path):
    a = np.asarray(Image.open(path).convert("RGB")).astype(int)
    return (a[:, :, 0] > 150) & ((a[:, :, 0] - a[:, :, 1]) > 40) & ((a[:, :, 0] - a[:, :, 2]) > 40)
def mask_bbox(m):
    ys, xs = np.nonzero(m)
    if len(xs) == 0:
        return None
    return (int(xs.min()), int(ys.min()), int(xs.max()), int(ys.max()))

masks = {}
for fr in (0, 36):
    sc.frame_set(fr)
    bpy.context.view_layer.update()
    for name, loc in VIEWS:
        p = render_view(name, loc, f"F{fr:02d}mask")
        masks[(fr, name)] = body_mask(p)
    print(f"masks F{fr} done")

def gate(fr):
    sc.frame_set(fr)
    bpy.context.view_layer.update()
    worst_poke = 0
    stats = {}
    for name, loc in VIEWS:
        p = render_view(name, loc, f"F{fr:02d}red")
        rm = red_mask(p)
        mk = masks[(fr, name)]
        poke = int((rm & ~mk).sum())
        inside = int((rm & mk).sum())
        stats[name] = (poke, inside, mask_bbox(rm & mk))
        worst_poke = max(worst_poke, poke)
        print(f"  F{fr} {name}: poke={poke} inside_visible={inside} bbox={stats[name][2]}")
    return worst_poke, stats

passed = False
win_inset = None
for base_inset in (0.012, 0.018, 0.024, 0.030):
    verts, polys = build_patch(base_inset)
    tob = make_object(verts, polys, red)
    print(f"ATTEMPT base_inset={base_inset*1000:.0f}mm verts={len(verts)} polys={len(polys)}")
    w0, s0 = gate(0)
    w36, s36 = gate(36)
    f0_inside_max = max(v[1] for v in s0.values())
    plug = s36["left"][1] + s36["fl"][1]
    print(f" -> worst poke F0={w0} F36={w36}; F0 inside max={f0_inside_max}; F36 plug px={plug}")
    bpy.data.objects.remove(tob, do_unlink=True)
    if w0 < 20 and w36 < 20 and f0_inside_max < 100 and 50 <= plug <= 5000:
        passed = True
        win_inset = base_inset
        break
print("PHASE1 passed:", passed, "base_inset:", win_inset)

if passed:
    # Phase 2: pristine reopen, rebuild only the final dark patch, then save.
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
    print("NOT SAVED: local-patch gate failed")
print("DONE")
