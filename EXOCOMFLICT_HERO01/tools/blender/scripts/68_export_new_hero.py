"""68 - Export NEW_HERO_01 RIGGED GLB (same path/settings family as the old
shipped pipeline, script 32) and verify the result:
 * export to assets/characters/HERO_01_RIGGED.glb (Godot references this
   exact path; ScaleRoot x1.8 in HERO_01.tscn still applies: 0.981*1.8);
 * roundtrip-verify the GLB with pygltflib: 24 skin joints incl. Weapon_R,
   vertex count, weight sums, materials/images, rest bbox vs the pristine
   source (positions must be untouched modulo axis conversion);
 * render rest pose front/side/back for the visual-preservation comparison
   against script 64's source-baseline renders.
Run: tools/blender/run_bpy.sh tools/blender/scripts/68_export_new_hero.py
"""
import bpy
import math
import os
import struct
import numpy as np
from mathutils import Vector

PROJ = "/home/user/Cyber-Strike/EXOCOMFLICT_HERO01"
BLEND = f"{PROJ}/blender/NEW_HERO_01_working.blend"
SRC = f"{PROJ}/assets/source/NEW_HERO_01.glb"
GLB_OUT = f"{PROJ}/assets/characters/HERO_01_RIGGED.glb"
OUT = f"{PROJ}/screenshots/rig"

bpy.ops.wm.open_mainfile(filepath=BLEND)
arm = bpy.data.objects["HERO_01_Armature"]
body = bpy.data.objects["HERO_01_BODY"]
sc = bpy.context.scene
sc.frame_set(0)
bpy.context.view_layer.objects.active = arm
bpy.ops.object.mode_set(mode="POSE")
for pb in arm.pose.bones:
    pb.rotation_mode = "AXIS_ANGLE"; pb.rotation_axis_angle = (0.0, 1.0, 0.0, 0.0)
    pb.location = (0, 0, 0); pb.scale = (1, 1, 1)
bpy.ops.object.mode_set(mode="OBJECT")
bpy.context.view_layer.update()
assert len(bpy.data.actions) == 0, f"unexpected actions: {[a.name for a in bpy.data.actions]}"
dg = bpy.context.evaluated_depsgraph_get()
eo = body.evaluated_get(dg)
bbw = [eo.matrix_world @ Vector(c) for c in eo.bound_box]
print("rest world bbox z:[%.4f, %.4f] x:[%.3f, %.3f]" % (min(v.z for v in bbw), max(v.z for v in bbw), min(v.x for v in bbw), max(v.x for v in bbw)), flush=True)

bpy.ops.object.select_all(action="DESELECT")
for o in (arm, body):
    o.select_set(True)
bpy.context.view_layer.objects.active = arm
bpy.ops.export_scene.gltf(filepath=GLB_OUT, export_format="GLB", use_selection=True, export_yup=True,
                          export_apply=False, export_skins=True, export_def_bones=False,
                          export_animations=True, export_animation_mode="ACTIONS",
                          export_force_sampling=True, export_optimize_animation_size=False,
                          export_materials="EXPORT")
print(f"EXPORTED {GLB_OUT} {os.path.getsize(GLB_OUT)} bytes", flush=True)

# Open-shell scan meshes need doubleSided materials in Godot or backface
# culling makes fine detail vanish at glancing angles (VALIDATION_REPORT
# 5.6). The patcher splices only the JSON chunk; BIN stays byte-identical.
import subprocess, sys as _sys
r = subprocess.run([_sys.executable, f"{PROJ}/tools/patch_glb_double_sided.py", GLB_OUT],
                   capture_output=True, text=True)
print(r.stdout.strip() or r.stderr.strip(), flush=True)
assert r.returncode == 0, "doubleSided patch failed"

# ---------------- roundtrip verify (pygltflib) ----------------
from pygltflib import GLTF2
g = GLTF2().load(GLB_OUT)
print("meshes:", [(m.name, len(m.primitives)) for m in g.meshes], flush=True)
print("materials:", [m.name for m in g.materials], "images:", len(g.images), "textures:", len(g.textures), flush=True)
assert all(m.doubleSided for m in g.materials), "materials must be doubleSided for Godot"
print("materials doubleSided: OK", flush=True)
print("skins:", len(g.skins), "animations:", len(g.animations or []), flush=True)
assert len(g.skins) == 1
joints = [g.nodes[j].name for j in g.skins[0].joints]
print("joints(%d):" % len(joints), joints, flush=True)
EXPECTED = ["Root", "Hips", "Spine", "Chest", "UpperChest", "Neck", "Head",
            "Clavicle_L", "UpperArm_L", "Forearm_L", "Hand_L",
            "Clavicle_R", "UpperArm_R", "Forearm_R", "Hand_R", "Weapon_R",
            "UpperLeg_L", "LowerLeg_L", "Foot_L", "Toe_L",
            "UpperLeg_R", "LowerLeg_R", "Foot_R", "Toe_R"]
assert sorted(joints) == sorted(EXPECTED), f"joint mismatch: {set(joints) ^ set(EXPECTED)}"

def accessor_array(gltf, idx):
    acc = gltf.accessors[idx]
    bv = gltf.bufferViews[acc.bufferView]
    buf = gltf.buffers[bv.buffer]
    data = gltf.get_data_from_buffer_uri(buf.uri) if buf.uri else gltf.binary_blob()
    off = (bv.byteOffset or 0) + (acc.byteOffset or 0)
    comp = {5126: ("f", 4), 5123: ("H", 2), 5125: ("I", 4), 5121: ("B", 1)}[acc.componentType]
    ncomp = {"SCALAR": 1, "VEC2": 2, "VEC3": 3, "VEC4": 4, "MAT4": 16}[acc.type]
    fmt = "<" + comp[0] * ncomp * acc.count
    arr = np.array(struct.unpack_from(fmt, data, off), dtype=np.float64).reshape(acc.count, ncomp)
    return arr, acc

prim = g.meshes[0].primitives[0]
pos, pacc = accessor_array(g, prim.attributes.POSITION)
print(f"verts={len(pos)} pos bbox min={pos.min(0)} max={pos.max(0)}", flush=True)
# exporter duplicates some verts at loop-data seams (UV/normal splits):
# count may exceed the source's 527406 slightly; unique positions must not.
assert 527406 <= len(pos) <= int(527406 * 1.02), len(pos)
uniq = np.unique(np.round(pos, 5), axis=0)
print(f"unique positions={len(uniq)} (source 527406)", flush=True)
assert len(uniq) <= 527406
assert prim.attributes.JOINTS_0 is not None and prim.attributes.WEIGHTS_0 is not None
wts, _ = accessor_array(g, prim.attributes.WEIGHTS_0)
jnts, _ = accessor_array(g, prim.attributes.JOINTS_0)
ws = wts.sum(1)
print(f"WEIGHTS_0: sum min={ws.min():.4f} max={ws.max():.4f} zero_rows={int((ws < 0.5).sum())} joint_idx_max={int(jnts.max())} normalized={g.accessors[prim.attributes.WEIGHTS_0].normalized}", flush=True)
if g.accessors[prim.attributes.WEIGHTS_0].normalized:
    ws = ws / 255.0 if wts.max() > 1.5 else ws
    print(f" (normalized accessor; rescaled sum min={ws.min():.4f} max={ws.max():.4f})", flush=True)
assert (ws < 0.5).sum() == 0

gs = GLTF2().load(SRC)
sprim = gs.meshes[0].primitives[0]
sacc = gs.accessors[sprim.attributes.POSITION]
print("source pos min/max:", sacc.min, sacc.max, flush=True)
# glTF(Y-up) both sides: source is already glTF; export re-emitted from
# Blender Z-up with export_yup -> same axis convention expected.
for ax in range(3):
    assert abs(pos.min(0)[ax] - sacc.min[ax]) < 0.002, (ax, pos.min(0)[ax], sacc.min[ax])
    assert abs(pos.max(0)[ax] - sacc.max[ax]) < 0.002, (ax, pos.max(0)[ax], sacc.max[ax])
print("REST BBOX MATCHES SOURCE within 2mm (geometry untouched)", flush=True)

# ---------------- rest renders ----------------
sc.render.engine = "CYCLES"; sc.cycles.samples = 32; sc.cycles.use_denoising = True; sc.cycles.device = "CPU"
world = bpy.data.worlds.new("W68"); sc.world = world; world.use_nodes = True
world.node_tree.nodes["Background"].inputs[0].default_value = (0.32, 0.33, 0.35, 1)
sd = bpy.data.lights.new("S68", "SUN"); sd.energy = 3.2
so = bpy.data.objects.new("S68", sd); sc.collection.objects.link(so)
so.rotation_euler = (math.radians(52), math.radians(8), math.radians(-38))
cam = bpy.data.objects.new("C68", bpy.data.cameras.new("C68")); sc.collection.objects.link(cam); sc.camera = cam
TG = (0.0, -0.01, 0.50)
for name, loc in {"front": (0, -1.9, 0.52), "back": (0, 1.9, 0.52), "sideL": (1.9, -0.01, 0.52), "3q": (1.15, -1.35, 0.75)}.items():
    cam.data.lens = 50; cam.location = loc
    cam.rotation_euler = (Vector(TG) - Vector(loc)).to_track_quat("-Z", "Y").to_euler()
    sc.render.resolution_x = sc.render.resolution_y = 950
    sc.render.filepath = f"{OUT}/audit68_rest_{name}.png"
    bpy.ops.render.render(write_still=True)
    print("RENDERED", name, flush=True)
print("DONE 68", flush=True)
