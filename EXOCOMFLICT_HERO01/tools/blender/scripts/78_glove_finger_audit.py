"""78 - Glove/finger feasibility audit (owner hybrid-rig spec: finger bones?).
Renders both gloves close-up at rest and counts mesh islands in the
Hand-dominant region (are fingers separate shells with articulations,
or one fused mitt?). Audit only; blend not saved.
Run: tools/blender/run_bpy.sh tools/blender/scripts/78_glove_finger_audit.py
"""
import bpy
import math
import numpy as np
from mathutils import Vector

PROJ = "/home/user/Cyber-Strike/EXOCOMFLICT_HERO01"
BLEND = f"{PROJ}/blender/NEW_HERO_01_working.blend"
OUT = f"{PROJ}/screenshots/rig"

bpy.ops.wm.open_mainfile(filepath=BLEND)
arm = bpy.data.objects["HERO_01_Armature"]
body = bpy.data.objects["HERO_01_BODY"]
sc = bpy.context.scene
me = body.data
nv = len(me.vertices)
V = np.empty(nv * 3); me.vertices.foreach_get("co", V); V = V.reshape(nv, 3)
ne = len(me.edges)
E = np.empty(ne * 2, dtype=np.int64); me.edges.foreach_get("vertices", E); E = E.reshape(ne, 2)

# dominant group per vertex (single python pass over deform groups)
gname = [g.name for g in body.vertex_groups]
dom = np.full(nv, -1, dtype=np.int64)
for i, v in enumerate(me.vertices):
    best, bw = -1, -1.0
    for ge in v.groups:
        if ge.weight > bw:
            bw, best = ge.weight, ge.group
    dom[i] = best

for side in ("L", "R"):
    gi = gname.index(f"Hand_{side}")
    sel = np.where(dom == gi)[0]
    # union-find within selection
    pos = {int(v): k for k, v in enumerate(sel)}
    parent = list(range(len(sel)))
    def find(a):
        while parent[a] != a:
            parent[a] = parent[parent[a]]; a = parent[a]
        return a
    for a, b in E:
        ia, ib = pos.get(int(a)), pos.get(int(b))
        if ia is not None and ib is not None:
            ra, rb = find(ia), find(ib)
            if ra != rb:
                parent[ra] = rb
    roots = {}
    for k, v in enumerate(sel):
        roots.setdefault(find(k), []).append(int(v))
    islands = sorted(roots.values(), key=len, reverse=True)
    print(f"HAND_{side}: {len(sel)} verts dominant, {len(islands)} islands; top sizes: {[len(i) for i in islands[:12]]}", flush=True)
    for isl in islands[:8]:
        c = V[isl].mean(axis=0)
        ext = V[isl].max(axis=0) - V[isl].min(axis=0)
        print(f"   isl {len(isl):6d}v centroid=({c[0]:+.3f},{c[1]:+.3f},{c[2]:.3f}) extent=({ext[0]:.3f},{ext[1]:.3f},{ext[2]:.3f})", flush=True)

# renders
sc.render.engine = "CYCLES"; sc.cycles.samples = 28; sc.cycles.use_denoising = True; sc.cycles.device = "CPU"
w = bpy.data.worlds.new("W78"); sc.world = w; w.use_nodes = True
w.node_tree.nodes["Background"].inputs[0].default_value = (0.32, 0.33, 0.35, 1)
sd = bpy.data.lights.new("S78", "SUN"); sd.energy = 3.4
so = bpy.data.objects.new("S78", sd); sc.collection.objects.link(so)
so.rotation_euler = (math.radians(50), math.radians(10), math.radians(-35))
cam = bpy.data.objects.new("C78", bpy.data.cameras.new("C78")); sc.collection.objects.link(cam); sc.camera = cam
def shot(tag, loc, tp):
    cam.data.lens = 55; cam.location = loc
    cam.rotation_euler = (Vector(tp) - Vector(loc)).to_track_quat("-Z", "Y").to_euler()
    sc.render.resolution_x = sc.render.resolution_y = 760
    sc.render.filepath = f"{OUT}/audit78_{tag}.png"
    bpy.ops.render.render(write_still=True)
    print("RENDERED", tag, flush=True)
# wrists at (+-0.355, 0.062?, ...) Blender space: anatomical L=+X; wrist head ~(+-0.355,0.062,0.572) in glTF -> Blender (x,-z,y): y=-0.062
shot("glove_R_top", (-0.50, -0.30, 0.72), (-0.375, -0.06, 0.54))
shot("glove_R_side", (-0.62, -0.10, 0.55), (-0.375, -0.06, 0.54))
shot("glove_L_top", (0.50, -0.30, 0.72), (0.375, -0.06, 0.54))
print("DONE 78", flush=True)
