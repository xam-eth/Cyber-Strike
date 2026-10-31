"""64 - Audit NEW_HERO_01.glb (owner-supplied replacement hero, 2026-10-31).

READ-ONLY. Imports the new source into an empty scene and reports:
objects/materials, island structure (sizes + bboxes of the largest),
and the owner's core question: how much clearance is there between the
arms and the torso in the source pose (the old hero's hands/waist contact
made clean arm/torso weight separation nearly impossible).

Clearance metric: in horizontal slices, the vertex x-distribution is
split into torso core and arm clusters; we report the empty x-gap
between the torso surface cluster and the nearest arm cluster on each
side, per height band. Plus textured renders (front/side/back/3q/top).

Run: tools/blender/run_bpy.sh tools/blender/scripts/64_audit_new_hero.py
"""
import bpy
import math
import numpy as np
from collections import deque
from mathutils import Vector

SRC = "/home/user/Cyber-Strike/EXOCOMFLICT_HERO01/assets/source/NEW_HERO_01.glb"
OUT = "/home/user/Cyber-Strike/EXOCOMFLICT_HERO01/screenshots/rig"

bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.ops.import_scene.gltf(filepath=SRC)
sc = bpy.context.scene
meshes = [o for o in bpy.data.objects if o.type == "MESH"]
print(f"OBJECTS: {[(o.name, o.type) for o in bpy.data.objects]}", flush=True)
for o in meshes:
    me = o.data
    print(f" MESH {o.name}: verts={len(me.vertices)} polys={len(me.polygons)} "
          f"materials={[m.name if m else None for m in me.materials]} loc={tuple(np.round(o.location,3))} scale={tuple(np.round(o.scale,3))}", flush=True)

body = max(meshes, key=lambda o: len(o.data.vertices))
me = body.data
NV = len(me.vertices)
# world-space coords (apply object matrix in case importer transformed)
MW = np.array(body.matrix_world)
co = np.empty(NV * 3); me.vertices.foreach_get("co", co); co = co.reshape(-1, 3)
co = co @ MW[:3, :3].T + MW[:3, 3]
print(f"BODY world bbox min={np.round(co.min(0),3)} max={np.round(co.max(0),3)}", flush=True)
x, y, z = co[:, 0], co[:, 1], co[:, 2]  # Blender: z = up, -y = front convention TBD by renders
print(f"height range z: [{z.min():.3f},{z.max():.3f}]  width x: [{x.min():.3f},{x.max():.3f}]  depth y: [{y.min():.3f},{y.max():.3f}]", flush=True)

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
cnt = np.bincount(isl, minlength=nid)
order = np.argsort(cnt)[::-1]
print(f"ISLANDS: {nid} total; largest: {[int(cnt[i]) for i in order[:10]]}", flush=True)
for i in order[:12]:
    s = isl == i
    print(f"  isl{i} n={int(cnt[i]):7d} bbox x[{co[s,0].min():+.3f},{co[s,0].max():+.3f}] "
          f"y[{co[s,1].min():+.3f},{co[s,1].max():+.3f}] z[{co[s,2].min():+.3f},{co[s,2].max():+.3f}] "
          f"cen={np.round(co[s].mean(0),3)}", flush=True)

# ---------- arm/torso clearance per height band ----------
print("\nCLEARANCE (empty x-gap between torso cluster and arm cluster, per side/height):", flush=True)
h = z.max() - z.min()
for zlo_f in np.arange(0.30, 0.86, 0.07):
    zlo, zhi = z.min() + zlo_f * h, z.min() + (zlo_f + 0.07) * h
    s = (z >= zlo) & (z < zhi)
    if s.sum() < 200: continue
    xs = np.sort(x[s])
    # 1D clustering on x with 8mm gap threshold
    gaps = np.diff(xs)
    brk = np.nonzero(gaps > 0.008)[0]
    clusters = np.split(xs, brk + 1)
    clusters = [c for c in clusters if len(c) >= 30]
    desc = []
    for c in clusters:
        desc.append(f"x[{c.min():+.3f},{c.max():+.3f}]n{len(c)}")
    # clearance: torso = cluster containing 0 (or nearest); arm = next cluster out each side
    msg = " | ".join(desc)
    print(f" z[{zlo:.3f},{zhi:.3f}) hfrac[{zlo_f:.2f},{zlo_f+0.07:.2f}) clusters: {msg}", flush=True)

# ---------- renders ----------
sc.render.engine = "CYCLES"; sc.cycles.samples = 24; sc.cycles.use_denoising = True; sc.cycles.device = "CPU"
world = bpy.data.worlds.new("W64"); sc.world = world; world.use_nodes = True
world.node_tree.nodes["Background"].inputs[0].default_value = (0.32, 0.33, 0.35, 1)
world.node_tree.nodes["Background"].inputs[1].default_value = 1.0
sd = bpy.data.lights.new("S64", "SUN"); sd.energy = 3.0
so = bpy.data.objects.new("S64", sd); sc.collection.objects.link(so)
so.rotation_euler = (math.radians(52), math.radians(8), math.radians(-38))
cam = bpy.data.objects.new("C64", bpy.data.cameras.new("C64")); sc.collection.objects.link(cam); sc.camera = cam
cen = co.mean(0); mid = (float(cen[0]), float(cen[1]), float(z.min() + 0.52 * h))
R = 1.9
VIEWS = {
    "front": (mid[0], mid[1] - R, mid[2]), "back": (mid[0], mid[1] + R, mid[2]),
    "sideL": (mid[0] + R, mid[1], mid[2]), "sideR": (mid[0] - R, mid[1], mid[2]),
    "3q": (mid[0] + 1.15, mid[1] - 1.35, mid[2] + 0.25),
    "top": (mid[0], mid[1] - 0.02, mid[2] + R),
}
for name, loc in VIEWS.items():
    cam.data.lens = 50
    cam.location = loc
    cam.rotation_euler = (Vector(mid) - Vector(loc)).to_track_quat("-Z", "Y").to_euler()
    sc.render.resolution_x = sc.render.resolution_y = 950
    sc.render.filepath = f"{OUT}/audit64_newhero_{name}.png"
    bpy.ops.render.render(write_still=True)
    print("RENDERED", name, flush=True)
print("DONE 64 (read-only audit)", flush=True)
