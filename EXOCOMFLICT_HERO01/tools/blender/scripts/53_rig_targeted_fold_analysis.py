"""Read-only targeted fold analysis (script 53), follow-up to 50-52.

For the specific shells highlighted in script 52 renders, print:
  * bbox / centroid,
  * signed arc range relative to the relevant joint (elbow/shoulder),
  * average proximal-vs-distal weights in 10mm arc bins INSIDE the shell,
so we can see exactly where a shell's deformation transition sits.

Also estimates limb centerlines from arm/leg-classified islands only
(excluding the mis-weighted torso flap isl101) in horizontal slices, and
extrapolates the upper-arm/thigh centerline to the shoulder/hip height
for comparison with the current pivots. Nothing is saved.
"""
import bpy
import numpy as np

PROJ = "/home/user/Cyber-Strike/EXOCOMFLICT_HERO01"
BLEND = f"{PROJ}/blender/HERO_01_working.blend"

bpy.ops.wm.open_mainfile(filepath=BLEND)
sc = bpy.context.scene
sc.frame_set(0)
arm = bpy.data.objects["HERO_01_Armature"]
body = bpy.data.objects["HERO_01_BODY"]
bones = arm.data.bones


def jpos(name, tail=False):
    b = bones[name]
    return np.array(arm.matrix_world @ (b.tail_local if tail else b.head_local))


n = len(body.data.vertices)
mw = np.array(body.matrix_world)
co = np.empty(n * 3, dtype=np.float64)
body.data.vertices.foreach_get("co", co)
P0 = co.reshape(-1, 3) @ mw[:3, :3].T + mw[:3, 3]
gnames = [g.name for g in body.vertex_groups]
gidx = {name: i for i, name in enumerate(gnames)}
W = np.zeros((n, len(gnames)), dtype=np.float64)
for vi, v in enumerate(body.data.vertices):
    for ge in v.groups:
        W[vi, ge.group] = ge.weight

# islands (same union-find ordering as scripts 51/52)
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
iw_avg = np.stack([np.bincount(ISL, weights=W[:, gi]) / cnt for gi in range(len(gnames))], axis=1)
icen = np.stack([np.bincount(ISL, weights=P0[:, k]) / cnt for k in range(3)], axis=1)


def seg_proj(Pts, A, B):
    AB = B - A
    L = float(np.linalg.norm(AB))
    t = np.clip(((Pts - A) @ AB) / (L * L), 0.0, 1.0)
    proj = A + t[:, None] * AB
    return t * L, np.linalg.norm(Pts - proj, axis=1), L


def signed_s(p_bone, j_bone, d_pos):
    P, J, D = jpos(p_bone), jpos(j_bone), d_pos
    along_p, d_p, len_p = seg_proj(P0, P, J)
    along_d, d_d, len_d = seg_proj(P0, J, D)
    return np.where(d_d < d_p, along_d, along_p - len_p), len_d


def island_report(isl_id, s, prox_bones, dist_bones, joint_label):
    m = ISL == isl_id
    q = P0[m]
    print(f"\n ISLAND {isl_id}: n={int(m.sum())} centroid=({q[:,0].mean():+.3f},{q[:,1].mean():+.3f},{q[:,2].mean():+.3f})")
    print(f"   bbox x[{q[:,0].min():+.3f},{q[:,0].max():+.3f}] y[{q[:,1].min():+.3f},{q[:,1].max():+.3f}] "
          f"z[{q[:,2].min():+.3f},{q[:,2].max():+.3f}]  s-vs-{joint_label} range [{s[m].min():+.3f},{s[m].max():+.3f}]")
    pw = W[:, [gidx[b] for b in prox_bones]].sum(axis=1)
    dw = W[:, [gidx[b] for b in dist_bones]].sum(axis=1)
    print(f"   avgW prox({'+'.join(prox_bones)})={pw[m].mean():.3f} dist({'+'.join(dist_bones)})={dw[m].mean():.3f}")
    print("   arc bins inside shell (s<0 = proximal side of joint):")
    edges = np.arange(math_floor(s[m].min()), s[m].max() + 0.011, 0.01) if False else np.arange(-0.10, 0.21, 0.01)
    for i in range(len(edges) - 1):
        sel = m & (s >= edges[i]) & (s < edges[i + 1])
        if sel.sum() < 10:
            continue
        print(f"    s {edges[i]:+.2f}..{edges[i+1]:+.2f} n={int(sel.sum()):5d} proxW={pw[sel].mean():.3f} distW={dw[sel].mean():.3f} zmean={P0[sel,2].mean():.3f}")


def math_floor(x):
    return x


print("=== TARGETED SHELLS vs ELBOW (right arm) ===")
s_eR, _ = signed_s("UpperArm_R", "Forearm_R", jpos("Hand_R"))
for isl in (3, 190, 21, 4, 7, 43, 9):
    island_report(isl, s_eR, ["UpperArm_R"], ["Forearm_R"], "elbow_R")

print("\n=== TARGETED SHELLS vs ELBOW (left arm) ===")
s_eL, _ = signed_s("UpperArm_L", "Forearm_L", jpos("Hand_L"))
for isl in (53, 148, 68, 72, 12, 8):
    island_report(isl, s_eL, ["UpperArm_L"], ["Forearm_L"], "elbow_L")

print("\n=== TARGETED SHELLS vs SHOULDER_R ===")
s_sR, _ = signed_s("Clavicle_R", "UpperArm_R", jpos("Forearm_R"))
for isl in (101, 70, 22, 14):
    island_report(isl, s_sR, ["Chest", "UpperChest", "Clavicle_R"], ["UpperArm_R"], "shoulder_R")

print("\n=== ISLAND 101 (magenta flap) FULL WEIGHT BREAKDOWN ===")
m = ISL == 101
order = np.argsort(-iw_avg[101])
print("  avg weights:", ", ".join(f"{gnames[j]}={iw_avg[101,j]:.3f}" for j in order if iw_avg[101, j] > 0.005))
for zlo in np.arange(0.58, 0.80, 0.02):
    sel = m & (P0[:, 2] >= zlo) & (P0[:, 2] < zlo + 0.02)
    if sel.sum() < 5:
        continue
    vals = {b: float(W[sel, gidx[b]].mean()) for b in ("Hips", "Spine", "Chest", "UpperChest", "Clavicle_R", "UpperArm_R", "Forearm_R")}
    print(f"  z {zlo:.2f}-{zlo+0.02:.2f} n={int(sel.sum()):4d} " + " ".join(f"{k}={v:.2f}" for k, v in vals.items()))

# ------------------------------------------------ centerlines from classified islands
ARM_B = ["Clavicle_R", "UpperArm_R", "Forearm_R", "Hand_R", "Clavicle_L", "UpperArm_L", "Forearm_L", "Hand_L"]
LEG_B = ["UpperLeg_R", "LowerLeg_R", "Foot_R", "Toe_R", "UpperLeg_L", "LowerLeg_L", "Foot_L", "Toe_L"]
iw_arm = iw_avg[:, [gidx[b] for b in ARM_B]].sum(axis=1)
iw_leg = iw_avg[:, [gidx[b] for b in LEG_B]].sum(axis=1)
arm_isl = (iw_arm >= 0.5)
arm_isl[101] = False  # known torso flap mis-weighted to arm
leg_isl = (iw_leg >= 0.5)
vert_arm = arm_isl[ISL]
vert_leg = leg_isl[ISL]


def centerline(name, vmask, zlo, zhi, xsign):
    print(f"\n--- CENTERLINE {name} (horizontal slices of classified-island verts) ---")
    pts = []
    for z in np.arange(zlo, zhi, 0.02):
        sel = vmask & (P0[:, 2] >= z) & (P0[:, 2] < z + 0.02)
        if xsign < 0:
            sel &= P0[:, 0] < 0.0
        else:
            sel &= P0[:, 0] > 0.04
        if sel.sum() < 40:
            continue
        c = P0[sel].mean(axis=0)
        rr = np.linalg.norm(P0[sel][:, :2] - c[:2], axis=1)
        pts.append((z + 0.01, c, int(sel.sum()), float(np.percentile(rr, 90))))
        print(f"  z={z+0.01:.3f} n={int(sel.sum()):5d} cen=({c[0]:+.3f},{c[1]:+.3f}) r90_xy={np.percentile(rr,90)*1000:.1f}mm")
    return pts


def extrapolate(pts, zfit_lo, zfit_hi, ztarget, label, current):
    sel = [(z, c) for z, c, nn, rr in pts if zfit_lo <= z <= zfit_hi]
    if len(sel) < 3:
        print(f"  {label}: not enough slices to fit")
        return
    Z = np.array([z for z, c in sel])
    X = np.array([c[0] for z, c in sel])
    Y = np.array([c[1] for z, c in sel])
    ax, bx = np.polyfit(Z, X, 1)
    ay, by = np.polyfit(Z, Y, 1)
    px, py = ax * ztarget + bx, ay * ztarget + by
    print(f"  {label}: centerline fit z[{zfit_lo},{zfit_hi}] -> at z={ztarget:.3f}: ({px:+.3f},{py:+.3f}) "
          f"vs current pivot ({current[0]:+.3f},{current[1]:+.3f},{current[2]:+.3f}) "
          f"delta=({px-current[0]:+.3f},{py-current[1]:+.3f}) |d|={np.hypot(px-current[0], py-current[1])*1000:.1f}mm")


for side, xs in (("R", -1), ("L", 1)):
    pts = centerline(f"ARM_{side}", vert_arm, 0.36, 0.80, xs)
    extrapolate(pts, 0.60, 0.71, float(jpos(f"UpperArm_{side}")[2]), f"shoulder_{side}", jpos(f"UpperArm_{side}"))
    extrapolate(pts, 0.60, 0.71, float(jpos(f"Forearm_{side}")[2]), f"elbow_{side} (upper-arm line)", jpos(f"Forearm_{side}"))
for side, xs in (("R", -1), ("L", 1)):
    pts = centerline(f"LEG_{side}", vert_leg, 0.04, 0.54, xs)
    extrapolate(pts, 0.34, 0.48, float(jpos(f"UpperLeg_{side}")[2]), f"hip_{side}", jpos(f"UpperLeg_{side}"))
    extrapolate(pts, 0.34, 0.48, float(jpos(f"LowerLeg_{side}")[2]), f"knee_{side} (thigh line)", jpos(f"LowerLeg_{side}"))

print("\nDONE (read-only)")
