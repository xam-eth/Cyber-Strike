"""65 - Landmark estimation for NEW_HERO_01 skeleton (READ-ONLY).

Imports the new source, traces limb medial axes through thin height
slices (cluster centroids), estimates joint positions (shoulder/elbow/
wrist, hip/knee/ankle, spine chain), and renders clay views with the
estimated skeleton drawn as small sphere markers for visual inspection
BEFORE any armature is built (script 66).

Character faces -Y (front render, script 64); anatomical LEFT = +X.
Run: tools/blender/run_bpy.sh tools/blender/scripts/65_new_hero_landmarks.py
"""
import bpy
import math
import numpy as np
from mathutils import Vector

SRC = "/home/user/Cyber-Strike/EXOCOMFLICT_HERO01/assets/source/NEW_HERO_01.glb"
OUT = "/home/user/Cyber-Strike/EXOCOMFLICT_HERO01/screenshots/rig"

bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.ops.import_scene.gltf(filepath=SRC)
sc = bpy.context.scene
body = max((o for o in bpy.data.objects if o.type == "MESH"), key=lambda o: len(o.data.vertices))
me = body.data
NV = len(me.vertices)
MW = np.array(body.matrix_world)
co = np.empty(NV * 3); me.vertices.foreach_get("co", co); co = co.reshape(-1, 3)
co = co @ MW[:3, :3].T + MW[:3, 3]
x, y, z = co[:, 0], co[:, 1], co[:, 2]
H = z.max() - z.min()
print(f"NV={NV} H={H:.3f} bbox x[{x.min():+.3f},{x.max():+.3f}] y[{y.min():+.3f},{y.max():+.3f}] z[{z.min():+.3f},{z.max():+.3f}]", flush=True)

def clusters_1d(vals, pts, gap=0.010, minn=25):
    order = np.argsort(vals)
    v = vals[order]; p = pts[order]
    brk = np.nonzero(np.diff(v) > gap)[0]
    out = []
    for grp in np.split(np.arange(len(v)), brk + 1):
        if len(grp) >= minn:
            out.append(p[grp])
    return out

# ---- torso centerline + half-width per slice ----
print("\nTORSO slices (z, centroid of central cluster, x halfwidth, y range):", flush=True)
torso_line = {}
for zc in np.arange(0.45, 0.86, 0.03):
    s = (z >= zc - 0.015) & (z < zc + 0.015)
    if s.sum() < 200: continue
    cls = clusters_1d(x[s], co[s])
    central = min(cls, key=lambda c: abs(c[:, 0].mean()))
    torso_line[round(zc, 2)] = central.mean(0)
    print(f" z={zc:.2f} cen={np.round(central.mean(0),3)} xhw={(central[:,0].max()-central[:,0].min())/2:.3f} "
          f"y[{central[:,1].min():+.3f},{central[:,1].max():+.3f}] n={len(central)}", flush=True)

# ---- arm medial axes: for each side, cluster centroids per slice ----
def trace_arm(side_sign, ztop, zbot):
    pts = []
    for zc in np.arange(ztop, zbot - 0.001, -0.02):
        s = (z >= zc - 0.010) & (z < zc + 0.010) & (np.sign(x) == side_sign) & (np.abs(x) > 0.09)
        if s.sum() < 40: continue
        cls = clusters_1d(x[s], co[s])
        if not cls: continue
        # arm cluster = the one whose centroid is most lateral & substantial
        cand = max(cls, key=lambda c: (len(c) >= 40) * abs(c[:, 0].mean()))
        pts.append((zc, cand.mean(0), len(cand), (cand[:, 0].max() - cand[:, 0].min()),
                    (cand[:, 1].max() - cand[:, 1].min())))
    return pts

for name, sgn in (("LEFT(+X)", 1), ("RIGHT(-X)", -1)):
    print(f"\nARM {name} medial trace (slice z, centroid, n, xwidth, ydepth):", flush=True)
    pts = trace_arm(sgn, 0.82, 0.48)
    for zc, cen, n, xw, yd in pts:
        print(f" z={zc:.2f} cen=({cen[0]:+.3f},{cen[1]:+.3f},{cen[2]:+.3f}) n={n:5d} xw={xw:.3f} yd={yd:.3f}", flush=True)
    # curvature along the trace -> elbow candidate
    P = np.array([p[1] for p in pts])
    if len(P) >= 5:
        v1 = P[1:-1] - P[:-2]; v2 = P[2:] - P[1:-1]
        v1 /= np.linalg.norm(v1, axis=1, keepdims=True); v2 /= np.linalg.norm(v2, axis=1, keepdims=True)
        ang = np.degrees(np.arccos(np.clip((v1 * v2).sum(1), -1, 1)))
        k = int(np.argmax(ang)) + 1
        print(f" ELBOW candidate (max direction change {ang.max():.1f}deg): slice z={pts[k][0]:.2f} cen={np.round(P[k],3)}", flush=True)
        print(f" trace ends: top={np.round(P[0],3)} bottom(hand)={np.round(P[-1],3)}", flush=True)

# ---- leg medial axes ----
def trace_leg(side_sign):
    pts = []
    for zc in np.arange(0.52, 0.03, -0.02):
        s = (z >= zc - 0.010) & (z < zc + 0.010) & (np.sign(x) == side_sign) & (np.abs(x) > 0.02)
        if s.sum() < 40: continue
        cls = clusters_1d(x[s], co[s])
        if not cls: continue
        cand = max(cls, key=len)
        pts.append((zc, cand.mean(0), len(cand), (cand[:, 0].max() - cand[:, 0].min()),
                    (cand[:, 1].max() - cand[:, 1].min()), cand[:, 1].min()))
    return pts

for name, sgn in (("LEFT(+X)", 1), ("RIGHT(-X)", -1)):
    print(f"\nLEG {name} medial trace (z, cen, n, xwidth, ydepth, front_y_min):", flush=True)
    pts = trace_leg(sgn)
    for zc, cen, n, xw, yd, fymin in pts:
        print(f" z={zc:.2f} cen=({cen[0]:+.3f},{cen[1]:+.3f},{cen[2]:+.3f}) n={n:5d} xw={xw:.3f} yd={yd:.3f} frontY={fymin:+.3f}", flush=True)

# ---- head/neck ----
for zc in np.arange(0.80, 0.99, 0.02):
    s = (z >= zc - 0.010) & (z < zc + 0.010)
    if s.sum() < 50: continue
    print(f" HEAD/NECK z={zc:.2f} cen={np.round(co[s].mean(0),3)} n={int(s.sum())} xw={x[s].max()-x[s].min():.3f}", flush=True)

# ---- feet: toe direction per side (lowest verts) ----
for name, sgn in (("LEFT(+X)", 1), ("RIGHT(-X)", -1)):
    s = (z < 0.09) & (np.sign(x) == sgn) & (np.abs(x) > 0.02)
    if s.sum():
        print(f" FOOT {name}: n={int(s.sum())} x[{x[s].min():+.3f},{x[s].max():+.3f}] y[{y[s].min():+.3f},{y[s].max():+.3f}] cen={np.round(co[s].mean(0),3)}", flush=True)
print("DONE 65", flush=True)
