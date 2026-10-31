"""79 - Hybrid rig Stage A v5 (owner-approved scope, 2026-10-31): finger bones.
Adds 15 finger bones per hand -> 54 joints. Lessons baked in from v1-v4
(all rejected by gates/renders): the glove surface is CONTINUOUS across
fingers (Tripo transverse bands), so weights must be a smooth field over
ALL finger polylines with lateral falloff (webbing blends neighbor
fingers), top-4 pruned. Axes come from distal tip clusters; MCP from
the wrist->tip proportion; joints refined by arc-slice centroids.
Gates: untouched checksum, per-bone count/p95-distance, curl
displacement sanity, hand edge-stretch under full curl (fin detector).
Saves ONLY if all gates pass; requires clean 24-bone base.
Run: tools/blender/run_bpy.sh tools/blender/scripts/79_add_finger_bones.py
"""
import bpy
import math
import numpy as np
from mathutils import Vector, Quaternion

PROJ = "/home/user/Cyber-Strike/EXOCOMFLICT_HERO01"
BLEND = f"{PROJ}/blender/NEW_HERO_01_working.blend"
OUT = f"{PROJ}/screenshots/rig"
FINGERS = ["Thumb", "Index", "Middle", "Ring", "Pinky"]

bpy.ops.wm.open_mainfile(filepath=BLEND)
arm = bpy.data.objects["HERO_01_Armature"]
body = bpy.data.objects["HERO_01_BODY"]
sc = bpy.context.scene
assert len(arm.data.bones) == 24, f"need clean 24-bone base, found {len(arm.data.bones)}"
me = body.data
nv = len(me.vertices)
V = np.empty(nv * 3); me.vertices.foreach_get("co", V); V = V.reshape(nv, 3)
ne = len(me.edges)
E = np.empty(ne * 2, dtype=np.int64); me.edges.foreach_get("vertices", E); E = E.reshape(ne, 2)

print("snapshotting weights...", flush=True)
snap = []
dom = np.full(nv, -1, dtype=np.int64)
for i, v in enumerate(me.vertices):
    snap.append(tuple(sorted((ge.group, round(ge.weight, 6)) for ge in v.groups)))
    bw, best = -1.0, -1
    for ge in v.groups:
        if ge.weight > bw:
            bw, best = ge.weight, ge.group
    dom[i] = best
gname0 = [g.name for g in body.vertex_groups]

def kmeans2d(X, k=5, iters=80):
    seeds = [0]
    dmin = np.linalg.norm(X - X[0], axis=1)
    for _ in range(k - 1):
        seeds.append(int(np.argmax(dmin)))
        dmin = np.minimum(dmin, np.linalg.norm(X - X[seeds[-1]], axis=1))
    C = X[seeds].astype(float)
    lab = np.zeros(len(X), int)
    for _ in range(iters):
        d = np.linalg.norm(X[:, None, :] - C[None, :, :], axis=2)
        nl = np.argmin(d, axis=1)
        if (nl == lab).all():
            break
        lab = nl
        for j in range(k):
            if (lab == j).any():
                C[j] = X[lab == j].mean(axis=0)
    return lab, C

def polyline_arc_dist(Pts, joints):
    """Per-point (arc_length, lateral_dist) against a 4-point polyline."""
    J = [np.array(j, float) for j in joints]
    cum = [0.0]
    for si in range(3):
        cum.append(cum[-1] + float(np.linalg.norm(J[si + 1] - J[si])))
    arc = np.zeros(len(Pts)); dst = np.full(len(Pts), 1e18)
    for si in range(3):
        a = J[si]; ab = J[si + 1] - a
        t = np.clip(((Pts - a) @ ab) / max(float(ab @ ab), 1e-12), 0, 1)
        q = a + np.outer(t, ab)
        d = np.linalg.norm(Pts - q, axis=1)
        better = d < dst
        dst[better] = d[better]
        arc[better] = cum[si] + t[better] * float(np.linalg.norm(ab))
    return arc, dst, cum[-1]

hand_info = {}
for side in ("L", "R"):
    gi = gname0.index(f"Hand_{side}")
    sel = np.where(dom == gi)[0]
    P = V[sel]
    mu = P.mean(axis=0)
    cov = np.cov((P - mu).T)
    _e, evecs = np.linalg.eigh(cov)
    u, v, w = evecs[:, 2], evecs[:, 1], evecs[:, 0]
    wrist = np.array(arm.data.bones[f"Hand_{side}"].head_local, float)
    elbow = np.array(arm.data.bones[f"Forearm_{side}"].head_local, float)
    if np.dot(u, wrist - elbow) < 0:
        u = -u
    if np.dot(np.cross(u, v), w) < 0:
        v, w = -v, -w
    pu, pv, pw = (P - mu) @ u, (P - mu) @ v, (P - mu) @ w
    # VERIFIED (renders + reach profile diag79j): glove fingers TOUCH
    # (no histogram valleys), thumb zone = pv beyond the reach cliff
    # (p98 pu drops ~28->18mm). Fingers: 4 equal pv columns over the
    # pre-cliff zone, each snapped to its fingertip centroid twice.
    bins = np.arange(-0.027, 0.027, 0.001)
    ctr = 0.5 * (bins[:-1] + bins[1:])
    reach = np.full(len(ctr), -1.0)
    for bi in range(len(ctr)):
        m = (pv >= bins[bi]) & (pv < bins[bi + 1])
        if m.sum() >= 8:
            reach[bi] = np.percentile(pu[m], 98)
    cliff = None; best = 0.005
    for bi in range(len(ctr) - 3):
        if 0.006 < ctr[bi] < 0.022 and reach[bi] > 0 and reach[bi + 3] > 0:
            drop = reach[bi] - reach[bi + 3]
            if drop > best:
                best, cliff = drop, ctr[bi] + 0.0015
    assert cliff is not None, (side, "no thumb cliff")
    lo_bin = next(ctr[bi] for bi in range(len(ctr)) if reach[bi] > 0.015)
    zone_w = (cliff - lo_bin) / 4.0
    col_c = [lo_bin + zone_w * (i + 0.5) for i in range(4)]
    # thumb always at +pv in this PCA frame (VERIFIED both hands)
    finger_names = ["Pinky", "Ring", "Middle", "Index"]
    th_mask = pv > cliff
    assert th_mask.sum() >= 300, (side, int(th_mask.sum()))
    th_idx = np.where(th_mask)[0]
    th_top = th_idx[pu[th_idx] >= np.percentile(pu[th_idx], 88)]
    thumb_tip = P[th_top].mean(axis=0)
    fingers = []
    for nm, cc in zip(finger_names, col_c):
        tip = None
        for _snap in range(2):
            col = np.where(np.abs(pv - cc) < zone_w * 0.55)[0]
            top = col[pu[col] >= np.percentile(pu[col], 93)]
            tip = P[top].mean(axis=0)
            cc = float(((tip - mu) @ v))
        mcp = wrist + (tip - wrist) * 0.55
        fingers.append(dict(name=nm, joints=[Vector(x) for x in
                        (mcp, mcp + (tip - mcp) * 0.42, mcp + (tip - mcp) * 0.70, tip)]))
    mcp = wrist + (thumb_tip - wrist) * 0.40
    fingers.insert(0, dict(name="Thumb", joints=[Vector(x) for x in
                    (mcp, mcp + (thumb_tip - mcp) * 0.45, mcp + (thumb_tip - mcp) * 0.72, thumb_tip)]))
    # palm faces UP (+Z world) in this A-pose (VERIFIED by renders)
    palmar = w * (1.0 if w[2] > 0 else -1.0)
    print(f"  {side}: cliff pv={cliff*1000:.0f}mm zone [{lo_bin*1000:.0f}..{cliff*1000:.0f}] cols {[round(c*1000) for c in col_c]} thumb_tip={np.round(thumb_tip,3)} nth={int(th_mask.sum())}", flush=True)
    # refine joints twice by arc-slice centroids (lateral<7mm only)
    for _it in range(2):
        A = []; D = []
        for fd in fingers:
            arc, dst, tot = polyline_arc_dist(P, fd["joints"])
            A.append(arc / max(tot, 1e-9)); D.append(dst)
        A = np.stack(A, axis=1); D = np.stack(D, axis=1)
        assign = np.argmin(D, axis=1)
        for fi, fd in enumerate(fingers):
            rows = np.where(assign == fi)[0]
            ar = A[rows, fi]; di_ = D[rows, fi]
            prev = [np.array(j, float) for j in fd["joints"]]
            pcum = [0.0]
            for si in range(3):
                pcum.append(pcum[-1] + float(np.linalg.norm(prev[si + 1] - prev[si])))
            def at_frac(fr):
                tgt = fr * pcum[-1]
                for si in range(3):
                    if tgt <= pcum[si + 1] or si == 2:
                        seg = max(pcum[si + 1] - pcum[si], 1e-9)
                        return prev[si] + (prev[si + 1] - prev[si]) * ((tgt - pcum[si]) / seg)
            joints = []
            for lo, hi in ((0.0, 0.12), (0.36, 0.48), (0.64, 0.76), (0.95, 1.01)):
                m = (ar >= lo) & (ar <= hi) & (di_ < 0.009)
                if m.sum() >= 12:
                    joints.append(Vector(P[rows][m].mean(axis=0)))
                else:
                    joints.append(Vector(at_frac((lo + hi) / 2)))
            fd["joints"] = joints
    for fd in fingers:
        segs = [round((fd["joints"][i + 1] - fd["joints"][i]).length * 1000) for i in range(3)]
        tot = sum(segs)
        print(f"  {side} {fd['name']}: segs {segs}mm total {tot}mm", flush=True)
        assert all(4 <= s <= 26 for s in segs) and 20 <= tot <= 65, (side, fd["name"], segs)
    palm_c = Vector(P[pu < np.percentile(pu, 20)].mean(axis=0))
    hand_info[side] = dict(sel=sel, fingers=fingers, palmar=Vector(palmar), pu=pu, palm_c=palm_c)

# --- bones ---
# Roll from TRUE flexion axes: finger X = MCP-row direction; thumb X =
# axis that swings its tip toward the palm centre. (Guessed dorsal from
# PCA/+Z gave only 3mm tip approach at 40deg -- axis was wrong.)
bpy.context.view_layer.objects.active = arm
bpy.ops.object.mode_set(mode="EDIT")
eb = arm.data.edit_bones
new_bones = []
for side in ("L", "R"):
    fds = {fd["name"]: fd for fd in hand_info[side]["fingers"]}
    row_dir = (fds["Index"]["joints"][0] - fds["Pinky"]["joints"][0]).normalized()
    palm_c = hand_info[side]["palm_c"]
    fdir = Vector((0, 0, 0))
    for nm in ("Index", "Middle", "Ring", "Pinky"):
        fdir += (fds[nm]["joints"][3] - fds[nm]["joints"][0]).normalized()
    fdir.normalize()
    dorsal = row_dir.cross(fdir).normalized()
    if dorsal.dot(fds["Middle"]["joints"][0] - palm_c) < 0:
        dorsal = -dorsal
    print(f"  {side} row_dir={tuple(round(x,2) for x in row_dir)} dorsal={tuple(round(x,2) for x in dorsal)}", flush=True)
    for fd in hand_info[side]["fingers"]:
        parent = eb[f"Hand_{side}"]
        for k in range(3):
            b = eb.new(f"{fd['name']}{k+1}_{side}")
            b.head = fd["joints"][k]; b.tail = fd["joints"][k + 1]
            b.parent = parent; b.use_connect = False; b.use_deform = True
            Y = (b.tail - b.head).normalized()
            # fingers flex about knuckle-row axis; thumb sweeps the palm
            # plane in grip -> its flexion axis is the palm normal (dorsal)
            Xw = dorsal if fd["name"] == "Thumb" else row_dir
            Zw = Xw.cross(Y).normalized()
            b.align_roll(Zw)
            new_bones.append(b.name)
            parent = b
bpy.ops.object.mode_set(mode="POSE")
assert len(arm.data.bones) == 54
for bn in new_bones:
    body.vertex_groups.new(name=bn)
print(f"created {len(new_bones)} finger bones (54 total)", flush=True)

# --- weights: smooth field over ALL finger polylines + adjacency smoothing.
# Original non-Hand minority weights (e.g. Forearm at wrist) are preserved:
# the field only redistributes the original Hand share. 3 Laplacian passes
# over field verts + 1-ring make weights continuous across the field edge
# (top-4 prune happens only at write time).
LAT_R = 0.012
orig = []
for i in range(nv):
    orig.append({gname0[gi_]: w_ for gi_, w_ in snap[i]})
W = [dict(o) for o in orig]
field_verts = set()
for side in ("L", "R"):
    info = hand_info[side]; sel = info["sel"]; P = V[sel]
    F = []
    for fd in info["fingers"]:
        arc, dst, tot = polyline_arc_dist(P, fd["joints"])
        pts = fd["joints"]
        cum = [0.0]
        for si in range(3):
            cum.append(cum[-1] + (pts[si + 1] - pts[si]).length)
        a, b_, c_ = cum[1], cum[2] - cum[1], cum[3] - cum[2]
        stations = [(f"Hand_{side}", -0.004), (f"{fd['name']}1_{side}", a / 2),
                    (f"{fd['name']}2_{side}", a + b_ / 2), (f"{fd['name']}3_{side}", a + b_ + c_ / 2)]
        h = 0.9 * sorted([a, b_, c_])[1]
        F.append((arc, dst, stations, h))
    for r in range(len(sel)):
        ws = {}
        hand_w = 0.0
        maxlat = 0.0
        ht_at_max = 0.0
        for arc, dst, stations, h in F:
            # smoothstep: 1.0 within 5mm of axis (finger radius), ->0 at LAT_R
            t = max(0.0, min(1.0, (LAT_R - dst[r]) / (LAT_R - 0.005)))
            lat = t * t * (3 - 2 * t)
            if lat <= 0:
                continue
            if lat > maxlat:
                maxlat = lat
                ht_at_max = max(0.0, 1.0 - abs(arc[r] - stations[0][1]) / h)
            for bn_, s0 in stations:
                wgt = max(0.0, 1.0 - abs(arc[r] - s0) / h) * lat
                if bn_ == f"Hand_{side}":
                    hand_w = max(hand_w, wgt)
                elif wgt > 0.001:
                    ws[bn_] = ws.get(bn_, 0.0) + wgt
        # Hand fallback scaled by proximal-arc factor (floor 0.35): fingertip
        # surface verts (lat~1) get none; far palm/thenar verts stay Hand
        hand_w = max(hand_w, (1.0 - maxlat) * max(ht_at_max, 0.35))
        if not ws:
            continue
        ws[f"Hand_{side}"] = hand_w
        tot = sum(ws.values())
        ws = {k: v / tot for k, v in ws.items() if v / tot > 0.03}
        tot = sum(ws.values())
        ws = {k: v / tot for k, v in ws.items()}
        vi = int(sel[r])
        hs = orig[vi].get(f"Hand_{side}", 0.0)
        new = {g: w_ for g, w_ in orig[vi].items() if g != f"Hand_{side}"}
        for g, w_ in ws.items():
            new[g] = new.get(g, 0.0) + w_ * hs
        W[vi] = new
        field_verts.add(vi)
# adjacency (field verts + 2-ring become smoothing candidates)
adj = {}
for a_, b_ in E:
    a_, b_ = int(a_), int(b_)
    adj.setdefault(a_, []).append(b_)
    adj.setdefault(b_, []).append(a_)
cand = set(field_verts)
for vi in list(field_verts):
    for nb in adj.get(vi, []):
        cand.add(nb)
        cand.update(adj.get(nb, []))
for _pass in range(5):
    W2 = {}
    for vi in cand:
        acc = {}
        nbs = adj[vi]
        for nb in nbs:
            for g, w_ in W[nb].items():
                acc[g] = acc.get(g, 0.0) + w_ / len(nbs)
        merged = {g: 0.6 * W[vi].get(g, 0.0) + 0.4 * acc.get(g, 0.0)
                  for g in set(W[vi]) | set(acc)}
        t2 = sum(merged.values())
        W2[vi] = {g: w_ / t2 for g, w_ in merged.items() if w_ > 0.0005}
    for vi, d in W2.items():
        W[vi] = d
touched = set()
fb_names = set(new_bones)
for vi in cand:
    d = W[vi]
    if sum(w_ for g, w_ in d.items() if g in fb_names) < 0.005:
        continue
    top = sorted(d.items(), key=lambda kv: -kv[1])[:4]
    t2 = sum(v for _, v in top)
    for g in body.vertex_groups:
        g.remove([vi])
    for bn_, wgt in top:
        body.vertex_groups[bn_].add([vi], wgt / t2, "REPLACE")
    touched.add(vi)
print(f"re-weighted {len(touched)} finger verts (field {len(field_verts)}, smoothed {len(cand)})", flush=True)

# --- GATES ---
bad = wsum_bad = 0
vert_groups = []
for i, v in enumerate(me.vertices):
    gs = [(ge.group, ge.weight) for ge in v.groups]
    vert_groups.append(gs)
    if i not in touched:
        if tuple(sorted((gi_, round(w_, 6)) for gi_, w_ in gs)) != snap[i]:
            bad += 1
    s = sum(w_ for _, w_ in gs)
    tol = 1e-3 if i in touched else 0.01
    if abs(s - 1.0) > tol or len(gs) > 4:
        wsum_bad += 1
print(f"GATE untouched mismatches={bad} weight violations={wsum_bad}", flush=True)
assert bad == 0 and wsum_bad == 0

def seg_dist(p, a, b):
    ab = b - a
    t = max(0.0, min(1.0, (p - a).dot(ab) / max(ab.dot(ab), 1e-12)))
    return (p - (a + ab * t)).length
audit_fail = []
fb_idx = {body.vertex_groups[bn].index for bn in new_bones}
for bn in new_bones:
    gi = body.vertex_groups[bn].index
    # smooth-field audit: verts where this bone is the DOMINANT finger bone
    selb = []
    for i in range(nv):
        wb = 0.0; wmax_f = 0.0
        for g_, w_ in vert_groups[i]:
            if g_ in fb_idx:
                wmax_f = max(wmax_f, w_)
                if g_ == gi:
                    wb = w_
        if wb > 0.2 and wb >= wmax_f:
            selb.append(i)
    if len(selb) < 25:
        audit_fail.append((bn, f"only {len(selb)} dominant verts")); continue
    bb = arm.data.bones[bn]
    d = np.array([seg_dist(Vector(V[i]), Vector(bb.head_local), Vector(bb.tail_local)) for i in selb])
    p95 = float(np.percentile(d, 95))
    print(f"AUDIT {bn}: {len(selb)}v p95={p95*1000:.1f}mm max={d.max()*1000:.1f}mm", flush=True)
    # thumb+thenar is a thicker structure (~8-10mm radius) than fingers (~5mm)
    lim = 0.011 if bn.startswith("Thumb") else 0.0085
    if p95 > lim:
        audit_fail.append((bn, f"p95 {p95*1000:.1f}mm"))
assert not audit_fail, audit_fail

def set_curl(side, degs, sign, tsign=None):
    for nm in FINGERS:
        sg = tsign if (nm == "Thumb" and tsign is not None) else sign
        for k, dg in enumerate(degs):
            pb = arm.pose.bones[f"{nm}{k+1}_{side}"]
            pb.rotation_mode = "QUATERNION"
            pb.rotation_quaternion = Quaternion((1, 0, 0), math.radians(sg * dg))
    bpy.context.view_layer.update()
signs = {}
for side in ("L", "R"):
    palm_c = hand_info[side]["palm_c"]
    tip = lambda: Vector(arm.pose.bones[f"Index3_{side}"].tail)
    ttip = lambda: Vector(arm.pose.bones[f"Thumb3_{side}"].tail)
    d_rest = (tip() - palm_c).length
    set_curl(side, (40, 0, 0), +1); d_plus = (tip() - palm_c).length
    set_curl(side, (40, 0, 0), -1); d_minus = (tip() - palm_c).length
    fs = +1 if d_plus < d_minus else -1
    set_curl(side, (0, 0, 0), +1)
    t_rest = (ttip() - palm_c).length
    # thumb-only probe (fingers held at rest via degs on thumb only)
    for sg in (+1, -1):
        for k in range(3):
            arm.pose.bones[f"Thumb{k+1}_{side}"].rotation_quaternion = Quaternion((1, 0, 0), math.radians(sg * 40 if k == 0 else 0))
        bpy.context.view_layer.update()
        if sg == +1: t_plus = (ttip() - palm_c).length
        else: t_minus = (ttip() - palm_c).length
    ts = +1 if t_plus < t_minus else -1
    set_curl(side, (0, 0, 0), +1)
    signs[side] = (fs, ts)
    print(f"curl sign {side}: fingers {fs} (rest {d_rest*1000:.0f} + {d_plus*1000:.0f} - {d_minus*1000:.0f}) thumb {ts} (rest {t_rest*1000:.0f} + {t_plus*1000:.0f} - {t_minus*1000:.0f}) mm", flush=True)
    assert min(d_plus, d_minus) < d_rest - 0.005
    assert min(t_plus, t_minus) < t_rest - 0.002
hand_verts = sorted(set(int(v) for s in ("L", "R") for v in hand_info[s]["sel"]))
def eval_pos():
    dg = bpy.context.evaluated_depsgraph_get()
    eo = body.evaluated_get(dg); m2 = eo.to_mesh()
    P = np.empty(len(m2.vertices) * 3); m2.vertices.foreach_get("co", P); P = P.reshape(-1, 3)
    eo.to_mesh_clear()
    return P
P0 = eval_pos()
set_curl("R", (40, 50, 25), *signs["R"]); set_curl("L", (40, 50, 25), *signs["L"])
P1 = eval_pos()
disp = np.linalg.norm(P1[hand_verts] - P0[hand_verts], axis=1)
maxflen = 0.0
for s in ("L", "R"):
    for fd in hand_info[s]["fingers"]:
        maxflen = max(maxflen, sum((fd["joints"][i + 1] - fd["joints"][i]).length for i in range(3)))
bound = 2.0 * maxflen + 0.01
print(f"GATE curl displacement max={disp.max()*1000:.1f}mm bound={bound*1000:.0f}mm", flush=True)
assert disp.max() < bound
hv = np.zeros(nv, bool); hv[hand_verts] = True
emask = hv[E[:, 0]] & hv[E[:, 1]]
L0 = np.linalg.norm(V[E[:, 0]] - V[E[:, 1]], axis=1)
sel_e = np.where(emask & (L0 > 0.0005))[0]
r = np.linalg.norm(P1[E[sel_e, 0]] - P1[E[sel_e, 1]], axis=1) / L0[sel_e]
print(f"GATE hand edge-stretch ({len(sel_e)} edges): p99={np.percentile(r,99):.2f} p999={np.percentile(r,99.9):.2f} max={r.max():.2f}", flush=True)
tv = np.zeros(nv, bool); tv[list(touched)] = True
bnd = tv[E[sel_e, 0]] != tv[E[sel_e, 1]]
if bnd.any():
    print(f"  boundary edges ({int(bnd.sum())}): p99={np.percentile(r[bnd],99):.2f} max={r[bnd].max():.2f}; internal p99={np.percentile(r[~bnd],99):.2f} max={r[~bnd].max():.2f}", flush=True)
# localize: worst edges + per-finger stats
gnames_now = [g.name for g in body.vertex_groups]
def domname(i):
    gs = vert_groups[i]
    return gnames_now[max(gs, key=lambda gw: gw[1])[0]] if gs else "-"
worst = np.argsort(r)[-12:][::-1]
def wvec(i):
    return {gnames_now[g_]: round(w_, 2) for g_, w_ in sorted(vert_groups[i], key=lambda gw: -gw[1])[:4]}
for wi in worst:
    e0, e1 = int(E[sel_e[wi], 0]), int(E[sel_e[wi], 1])
    midp = (V[e0] + V[e1]) / 2
    print(f"  WORST r={r[wi]:.1f} mid={np.round(midp,3)} L0={L0[sel_e[wi]]*1000:.1f}mm dom {domname(e0)}/{domname(e1)}", flush=True)
    print(f"    v0 {np.round(V[e0],3)} {wvec(e0)}", flush=True)
    print(f"    v1 {np.round(V[e1],3)} {wvec(e1)}", flush=True)
for s_ in ("L", "R"):
    for fd in hand_info[s_]["fingers"]:
        js = [tuple(round(x, 3) for x in j) for j in fd["joints"]]
        print(f"  JOINTS {s_} {fd['name']}: {js}", flush=True)
# shrinkage too (fins collapse as well as stretch)
print(f"  shrink: p1={np.percentile(r,1):.2f} min={r.min():.2f} frac(r>2)={(r>2).mean()*100:.2f}% frac(r>1.5)={(r>1.5).mean()*100:.2f}%", flush=True)
# Gate on edges with L0>=2mm only for max — sub-mm scan slivers have unstable ratios.
_long = L0[sel_e] >= 0.002
print(f"GATE long-edge stretch (L0>=2mm, {_long.sum()} edges): p99={np.percentile(r[_long],99):.2f} p999={np.percentile(r[_long],99.9):.2f} max={r[_long].max():.2f}", flush=True)
# absolute elongation gate — a >6mm absolute tear is a fin regardless of L0
_elong = (np.linalg.norm(P1[E[sel_e,0]]-P1[E[sel_e,1]],axis=1) - L0[sel_e])*1000
print(f"GATE absolute elongation mm: p99={np.percentile(_elong,99):.2f} p999={np.percentile(_elong,99.9):.2f} max={_elong.max():.2f}", flush=True)
print(f"pcts(50,90,95,99,99.9)={np.percentile(r,[50,90,95,99,99.9]).round(2)}", flush=True)
for wi in np.argsort(_elong)[-8:][::-1]:
    e0, e1 = int(E[sel_e[wi], 0]), int(E[sel_e[wi], 1])
    print(f"  ELONG {_elong[wi]:.1f}mm mid={np.round((V[e0]+V[e1])/2,3)} L0={L0[sel_e[wi]]*1000:.1f}mm dom {domname(e0)}/{domname(e1)}", flush=True)
assert np.percentile(r, 99) < 3.6 and np.percentile(r[_long],99.9) < 3.5 and r[_long].max() < 4.5 and np.percentile(_elong, 99.9) < 5.5
# full fist for the visual evidence renders
set_curl("R", (55, 65, 35), *signs["R"]); set_curl("L", (55, 65, 35), *signs["L"])

sc.render.engine = "CYCLES"; sc.cycles.samples = 24; sc.cycles.use_denoising = True; sc.cycles.device = "CPU"
w = bpy.data.worlds.new("W79"); sc.world = w; w.use_nodes = True
w.node_tree.nodes["Background"].inputs[0].default_value = (0.32, 0.33, 0.35, 1)
sd = bpy.data.lights.new("S79", "SUN"); sd.energy = 3.4
so = bpy.data.objects.new("S79", sd); sc.collection.objects.link(so)
so.rotation_euler = (math.radians(50), math.radians(10), math.radians(-35))
cam = bpy.data.objects.new("C79", bpy.data.cameras.new("C79")); sc.collection.objects.link(cam); sc.camera = cam
def shot(tag, loc, tp, size=760):
    cam.data.lens = 55; cam.location = loc
    cam.rotation_euler = (Vector(tp) - Vector(loc)).to_track_quat("-Z", "Y").to_euler()
    sc.render.resolution_x = sc.render.resolution_y = size
    sc.render.filepath = f"{OUT}/audit79_{tag}.png"
    bpy.ops.render.render(write_still=True)
    print("RENDERED", tag, flush=True)
shot("curl_R_palm", (-0.375, 0.22, 0.56), (-0.375, -0.06, 0.53))
shot("curl_R_top", (-0.50, -0.30, 0.72), (-0.375, -0.06, 0.54))
shot("curl_L_palm", (0.375, 0.22, 0.56), (0.375, -0.06, 0.53))
set_curl("R", (0, 0, 0), 1); set_curl("L", (0, 0, 0), 1)
shot("rest_front", (0, -1.85, 0.60), (0, -0.02, 0.52), 640)

bpy.context.preferences.filepaths.use_file_compression = True
bpy.ops.wm.save_as_mainfile(filepath=BLEND, compress=True)
print(f"SAVED {BLEND}", flush=True)
print("DONE 79", flush=True)
