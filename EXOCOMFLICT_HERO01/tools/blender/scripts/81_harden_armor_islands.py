"""81 - Hybrid rig Stage B (owner-approved scope, 2026-10-31): harden
blended hard-armor islands to exact single-bone weights in the single
production mesh. Calibrated by /tmp/diag80a/b on the 54-bone blend:
islands via union-find on raw edges (1055); candidate = compact plate
island (bbox diag <100mm) already majority-committed to one bone
(mean weight >=0.65, second bone <=0.25) whose arc extent along that
bone stays within the segment (overshoot <6mm). Hand/finger-dominant
islands are EXCLUDED (glove transverse bands span fingers; script 79
smooth field owns the hands). Result per hardened vert: one group,
weight 1.0.
Validation is CONTROL-RELATIVE: the same anatomical stress pose is
measured BEFORE hardening (control) and after; the gate asserts no
material regression. Rationale: a pre-existing base-rig defect (chest
verts at ~(0.092,0.03,0.677) at weight 1.0 on UpperArm_L tear ~93mm
on arm abduction IDENTICALLY with/without hardening, /tmp/diag80c;
absolute gates would fail Stage B for a script-66-era problem). The
defect is documented in VALIDATION_REPORT for owner decision; repair
is out of Stage B scope.
Gates: untouched checksum, post-purity, hardened-island rigidity,
stretch non-regression vs control, filmstrip renders. Saves ONLY if
gates pass.
Run: tools/blender/run_bpy.sh tools/blender/scripts/81_harden_armor_islands.py
"""
import bpy
import math
import numpy as np
from mathutils import Vector, Quaternion

PROJ = "/home/user/Cyber-Strike/EXOCOMFLICT_HERO01"
BLEND = f"{PROJ}/blender/NEW_HERO_01_working.blend"
OUT = f"{PROJ}/screenshots/rig"
HAND_BONES = {"Hand_L", "Hand_R"} | {f"{f}{k}_{s}" for f in
             ("Thumb", "Index", "Middle", "Ring", "Pinky") for k in (1, 2, 3) for s in ("L", "R")}

bpy.ops.wm.open_mainfile(filepath=BLEND)
arm = bpy.data.objects["HERO_01_Armature"]
body = bpy.data.objects["HERO_01_BODY"]
sc = bpy.context.scene
assert len(arm.data.bones) == 54, f"need Stage A 54-bone blend, found {len(arm.data.bones)}"
me = body.data
nv = len(me.vertices)
V = np.empty(nv * 3); me.vertices.foreach_get("co", V); V = V.reshape(nv, 3)
ne = len(me.edges)
E = np.empty(ne * 2, dtype=np.int64); me.edges.foreach_get("vertices", E); E = E.reshape(ne, 2)
gnames = [g.name for g in body.vertex_groups]
ng = len(gnames)

print("snapshotting weights + accumulating island stats...", flush=True)
snap = []
groups_of = []
for i, v in enumerate(me.vertices):
    gs = [(ge.group, ge.weight) for ge in v.groups]
    groups_of.append(gs)
    snap.append(tuple(sorted((gi_, round(w_, 6)) for gi_, w_ in gs)))

parent = np.arange(nv)
def find(a):
    a = int(a)
    while parent[a] != a:
        parent[a] = parent[parent[a]]; a = int(parent[a])
    return a
for a_, b_ in E:
    ra, rb = find(a_), find(b_)
    if ra != rb:
        parent[max(ra, rb)] = min(ra, rb)
lab = np.array([find(i) for i in range(nv)])
uniq, counts = np.unique(lab, return_counts=True)
isl_of = {int(u): k for k, u in enumerate(uniq)}
isl_idx = np.array([isl_of[int(x)] for x in lab])
K = len(uniq)
Wsum = np.zeros((K, ng))
for i, gs in enumerate(groups_of):
    k = isl_idx[i]
    for gi_, w_ in gs:
        Wsum[k, gi_] += w_
bones = {b.name: b for b in arm.data.bones}

cands = []
for k in range(K):
    n = int(counts[k])
    if n < 40:
        continue
    verts = np.where(isl_idx == k)[0]
    bb = V[verts]
    diag = float(np.linalg.norm(bb.max(axis=0) - bb.min(axis=0)))
    if diag >= 0.100:
        continue
    meanw = Wsum[k] / n
    srt = np.argsort(meanw)[::-1]
    gstar, pstar = int(srt[0]), float(meanw[srt[0]])
    p2 = float(meanw[srt[1]])
    bn = gnames[gstar]
    if pstar < 0.65 or p2 > 0.25 or bn in HAND_BONES or bn not in bones:
        continue
    h = np.array(bones[bn].head_local); t = np.array(bones[bn].tail_local)
    ax = t - h; L = float(np.linalg.norm(ax)); axu = ax / max(L, 1e-9)
    s = (bb - h) @ axu
    over = max(0.0, -float(np.percentile(s, 1))) + max(0.0, float(np.percentile(s, 99)) - L)
    if over >= 0.006:
        continue
    cands.append((k, bn, gstar, n, pstar, diag))
print(f"islands total {K}; hardening candidates: {len(cands)} islands, {sum(c[3] for c in cands)} verts", flush=True)
for c in sorted(cands, key=lambda c: -c[3])[:15]:
    print(f"  isl k={c[0]} {c[1]} n={c[3]} mean={c[4]:.2f} diag={c[5]*1000:.0f}mm", flush=True)
assert 40 <= len(cands) <= 140, f"unexpected candidate count {len(cands)}"

# --- pose machinery + CONTROL measurement (before any weight writes) ---
bpy.context.view_layer.objects.active = arm
bpy.ops.object.mode_set(mode="POSE")
bpy.context.view_layer.update()
RESTMAT = {p.name: p.matrix.copy() for p in arm.pose.bones}
IDENT = Quaternion((1, 0, 0, 0))
FINGERS = ["Thumb", "Index", "Middle", "Ring", "Pinky"]
CURL_SIGNS = {"L": (1, -1), "R": (-1, -1)}
def reset_pose():
    for p in arm.pose.bones:
        p.rotation_mode = "QUATERNION"
        p.rotation_quaternion = IDENT
        p.location = (0, 0, 0)
    bpy.context.view_layer.update()
def world_rot(bone, axis_world, deg):
    la = (RESTMAT[bone].to_3x3().inverted() @ Vector(axis_world)).normalized()
    pb = arm.pose.bones[bone]
    pb.rotation_quaternion = Quaternion(la, math.radians(deg)) @ pb.rotation_quaternion
    bpy.context.view_layer.update()
def swing(bone, target, deg):
    pb = arm.pose.bones[bone]
    d = (Vector(pb.tail) - Vector(pb.head)).normalized()
    ax = d.cross(Vector(target).normalized())
    if ax.length < 1e-6:
        ax = Vector((1, 0, 0))
    ax.normalize()
    la = (RESTMAT[bone].to_3x3().inverted() @ ax).normalized()
    pb.rotation_quaternion = Quaternion(la, math.radians(deg)) @ pb.rotation_quaternion
    bpy.context.view_layer.update()
def curl(side, degs):
    fs, ts = CURL_SIGNS[side]
    for nm in FINGERS:
        sg = ts if nm == "Thumb" else fs
        for k, dg in enumerate(degs):
            pb = arm.pose.bones[f"{nm}{k+1}_{side}"]
            pb.rotation_mode = "QUATERNION"
            pb.rotation_quaternion = Quaternion((1, 0, 0), math.radians(sg * dg))
    bpy.context.view_layer.update()
def apply_stress():
    reset_pose()
    swing("UpperArm_R", (0, -1, -0.1), 65)
    swing("Forearm_R", (0, -1, 0.8), 95)
    swing("UpperArm_L", (1, 0, 0.5), 45)
    swing("Forearm_L", (0.3, 0, 1), 95)
    world_rot("Spine", (0, 0, 1), 20)
    world_rot("Chest", (1, 0, 0), 18)
    swing("UpperLeg_L", (0, -1, -0.2), 50)
    swing("LowerLeg_L", (0, 0.8, -0.5), 85)
    world_rot("Neck", (0, 0, 1), 25)
    curl("R", (55, 65, 35)); curl("L", (55, 65, 35))
def eval_pos():
    dg = bpy.context.evaluated_depsgraph_get()
    eo = body.evaluated_get(dg); m2 = eo.to_mesh()
    P = np.empty(len(m2.vertices) * 3); m2.vertices.foreach_get("co", P); P = P.reshape(-1, 3)
    eo.to_mesh_clear()
    return P
L0 = np.linalg.norm(V[E[:, 0]] - V[E[:, 1]], axis=1)
SEL_E = np.where(L0 > 0.002)[0]
def elong_of(P1):
    return (np.linalg.norm(P1[E[SEL_E, 0]] - P1[E[SEL_E, 1]], axis=1) - L0[SEL_E]) * 1000
apply_stress()
el_ctrl = elong_of(eval_pos())
print(f"CONTROL stress elongation: p99={np.percentile(el_ctrl,99):.1f} p999={np.percentile(el_ctrl,99.9):.1f} max={el_ctrl.max():.1f} mm", flush=True)
reset_pose()

hardened = set()
for k, bn, gstar, n, pstar, diag in cands:
    verts = np.where(isl_idx == k)[0]
    vg = body.vertex_groups[bn]
    for vi in verts:
        for g in body.vertex_groups:
            g.remove([int(vi)])
        vg.add([int(vi)], 1.0, "REPLACE")
        hardened.add(int(vi))
print(f"hardened {len(hardened)} verts in {len(cands)} islands", flush=True)

# --- gates ---
bad = wsum_bad = 0
for i, v in enumerate(me.vertices):
    gs = [(ge.group, ge.weight) for ge in v.groups]
    if i not in hardened:
        if tuple(sorted((gi_, round(w_, 6)) for gi_, w_ in gs)) != snap[i]:
            bad += 1
    else:
        if len(gs) != 1 or abs(gs[0][1] - 1.0) > 1e-6:
            wsum_bad += 1
    if abs(sum(w_ for _, w_ in gs) - 1.0) > 0.01 or len(gs) > 4:
        wsum_bad += 1
print(f"GATE untouched mismatches={bad} weight violations={wsum_bad}", flush=True)
assert bad == 0 and wsum_bad == 0

# --- post-hardening stress measurement + REGRESSION gate vs control ---
def domname(i):
    gs = me.vertices[i].groups
    return gnames[max(gs, key=lambda ge: ge.weight).group] if len(gs) else "-"

apply_stress()
P1 = eval_pos()
el_new = elong_of(P1)
# regression = ABSOLUTE deformation grew (decompression to exact length,
# e.g. -3.4mm -> 0.0 inside hardened plates, is an improvement)
delta = np.abs(el_new) - np.abs(el_ctrl)
n_worse = int((delta > 2.0).sum())
print(f"POST stress elongation: p99={np.percentile(el_new,99):.1f} p999={np.percentile(el_new,99.9):.1f} max={el_new.max():.1f} mm", flush=True)
print(f"REGRESSION: p999 ctrl={np.percentile(el_ctrl,99.9):.1f} -> new={np.percentile(el_new,99.9):.1f}; edges |worse| by >2mm: {n_worse}", flush=True)
for wi in np.argsort(delta)[-8:][::-1]:
    e0, e1 = int(E[SEL_E[wi], 0]), int(E[SEL_E[wi], 1])
    print(f"  DELTA |+{delta[wi]:.1f}|mm (ctrl {el_ctrl[wi]:.1f} -> {el_new[wi]:.1f}) mid={np.round((V[e0]+V[e1])/2,3)} dom {domname(e0)}/{domname(e1)} hard={e0 in hardened}/{e1 in hardened}", flush=True)
# rigidity sanity: edges fully inside hardened islands must keep length
hv = np.zeros(nv, bool); hv[list(hardened)] = True
ie = np.where(hv[E[:, 0]] & hv[E[:, 1]] & (L0 > 0.0005))[0]
rr = np.linalg.norm(P1[E[ie, 0]] - P1[E[ie, 1]], axis=1) / L0[ie]
print(f"GATE hardened-internal edges ({len(ie)}): max|ratio-1|={np.abs(rr-1).max():.4f}", flush=True)
assert np.abs(rr - 1).max() < 0.02
assert np.percentile(el_new, 99.9) <= np.percentile(el_ctrl, 99.9) + 0.5, "p999 elongation regressed"
assert n_worse <= 20, f"{n_worse} edges regressed >2mm"

sc.render.engine = "CYCLES"; sc.cycles.samples = 20; sc.cycles.use_denoising = True; sc.cycles.device = "CPU"
w = bpy.data.worlds.new("W81"); sc.world = w; w.use_nodes = True
w.node_tree.nodes["Background"].inputs[0].default_value = (0.4, 0.4, 0.42, 1)
sd = bpy.data.lights.new("S81", "SUN"); sd.energy = 3.4
so = bpy.data.objects.new("S81", sd); sc.collection.objects.link(so)
so.rotation_euler = (math.radians(50), math.radians(10), math.radians(-35))
cam = bpy.data.objects.new("C81", bpy.data.cameras.new("C81")); sc.collection.objects.link(cam); sc.camera = cam
def shot(tag, loc, tp, size=760, lens=50):
    cam.data.lens = lens; cam.location = loc
    cam.rotation_euler = (Vector(tp) - Vector(loc)).to_track_quat("-Z", "Y").to_euler()
    sc.render.resolution_x = sc.render.resolution_y = size
    sc.render.filepath = f"{OUT}/audit81_{tag}.png"
    bpy.ops.render.render(write_still=True)
    print("RENDERED", tag, flush=True)

shot("stress_front", (0, -1.9, 0.62), (0, -0.02, 0.52), 700)
shot("stress_back", (0, 1.9, 0.62), (0, -0.02, 0.52), 700)
shot("stress_sideR", (-1.9, -0.05, 0.60), (0, -0.02, 0.52), 700)
shot("stress_shoulderR", (-0.55, -0.75, 0.95), (-0.22, -0.02, 0.74), 760)
shot("stress_shoulderL", (0.55, -0.75, 0.95), (0.22, -0.02, 0.74), 760)
reset_pose()
shot("rest_front", (0, -1.85, 0.60), (0, -0.02, 0.52), 640)

bpy.context.preferences.filepaths.use_file_compression = True
bpy.ops.wm.save_as_mainfile(filepath=BLEND, compress=True)
print(f"SAVED {BLEND}", flush=True)
print("DONE 81", flush=True)
