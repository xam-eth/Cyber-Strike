"""83 - Hybrid rig Stage C part 2: export Rig v2 GLB (54 joints) with the
script-68 recipe and roundtrip-verify it:
 * export by SELECTION (deform armature + body only) so the CTRL
   armature and hitbox scaffold from script 82 never leave the blend;
 * pygltflib roundtrip: exactly 54 skin joints (24 body incl Weapon_R
   + 30 finger bones), no _CTRL joints, weight sums, 0 animations,
   rest bbox vs pristine source (geometry untouched);
 * doubleSided material patch (Godot open-shell requirement, script 68);
 * rest renders for visual-preservation comparison vs script 68 baseline.
Blend NOT re-saved (pose identity reset is export-local).
Run: tools/blender/run_bpy.sh tools/blender/scripts/83_export_rig_v2.py
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
assert len(arm.data.bones) == 54
assert "HERO_01_CTRL" in bpy.data.objects, "run script 82 first"
sc.frame_set(0)
bpy.context.view_layer.objects.active = arm
bpy.ops.object.mode_set(mode="POSE")
for pb in arm.pose.bones:
    pb.rotation_mode = "AXIS_ANGLE"; pb.rotation_axis_angle = (0.0, 1.0, 0.0, 0.0)
    pb.location = (0, 0, 0); pb.scale = (1, 1, 1)
bpy.ops.object.mode_set(mode="OBJECT")
bpy.context.view_layer.update()
assert len(bpy.data.actions) == 0, f"unexpected actions: {[a.name for a in bpy.data.actions]}"

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

import subprocess, sys as _sys
r = subprocess.run([_sys.executable, f"{PROJ}/tools/patch_glb_double_sided.py", GLB_OUT],
                   capture_output=True, text=True)
print(r.stdout.strip() or r.stderr.strip(), flush=True)
assert r.returncode == 0, "doubleSided patch failed"

from pygltflib import GLTF2
g = GLTF2().load(GLB_OUT)
print("meshes:", [(m.name, len(m.primitives)) for m in g.meshes], flush=True)
print("materials:", [m.name for m in g.materials], "images:", len(g.images), "textures:", len(g.textures), flush=True)
assert all(m.doubleSided for m in g.materials), "materials must be doubleSided for Godot"
print("skins:", len(g.skins), "animations:", len(g.animations or []), flush=True)
assert len(g.skins) == 1 and len(g.animations or []) == 0
joints = [g.nodes[j].name for j in g.skins[0].joints]
print("joints(%d):" % len(joints), joints, flush=True)
EXPECTED = ["Root", "Hips", "Spine", "Chest", "UpperChest", "Neck", "Head",
            "Clavicle_L", "UpperArm_L", "Forearm_L", "Hand_L",
            "Clavicle_R", "UpperArm_R", "Forearm_R", "Hand_R", "Weapon_R",
            "UpperLeg_L", "LowerLeg_L", "Foot_L", "Toe_L",
            "UpperLeg_R", "LowerLeg_R", "Foot_R", "Toe_R"]
FINGERS = ["Thumb", "Index", "Middle", "Ring", "Pinky"]
EXPECTED += [f"{f}{k}_{s}" for f in FINGERS for k in (1, 2, 3) for s in ("L", "R")]
assert sorted(joints) == sorted(EXPECTED), f"joint mismatch: {set(joints) ^ set(EXPECTED)}"
assert not any("_CTRL" in j or j.startswith("HB_") for j in joints)

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
assert 527406 <= len(pos) <= int(527406 * 1.02), len(pos)
uniq = np.unique(np.round(pos, 5), axis=0)
print(f"unique positions={len(uniq)} (source 527406)", flush=True)
assert len(uniq) <= 527406
assert prim.attributes.JOINTS_0 is not None and prim.attributes.WEIGHTS_0 is not None
wts, _ = accessor_array(g, prim.attributes.WEIGHTS_0)
jnts, _ = accessor_array(g, prim.attributes.JOINTS_0)
ws = wts.sum(1)
print(f"WEIGHTS_0: sum min={ws.min():.4f} max={ws.max():.4f} zero_rows={int((ws < 0.5).sum())} joint_idx_max={int(jnts.max())}", flush=True)
if g.accessors[prim.attributes.WEIGHTS_0].normalized and wts.max() > 1.5:
    ws = ws / 255.0
assert (ws < 0.5).sum() == 0
assert int(jnts.max()) < 54
# every finger joint actually used by some vertex
used = set(int(x) for x in np.unique(jnts[wts > 0.01 if wts.max() <= 1.5 else wts > 3]))
missing = [joints[i] for i in range(54) if i not in used]
print("joints unused by skin weights:", missing, flush=True)
assert set(missing) <= {"Weapon_R", "Root"}, missing  # motion root + attachment bone carry no skin by design

gs = GLTF2().load(SRC)
sprim = gs.meshes[0].primitives[0]
sacc = gs.accessors[sprim.attributes.POSITION]
for ax in range(3):
    assert abs(pos.min(0)[ax] - sacc.min[ax]) < 0.002, (ax, pos.min(0)[ax], sacc.min[ax])
    assert abs(pos.max(0)[ax] - sacc.max[ax]) < 0.002, (ax, pos.max(0)[ax], sacc.max[ax])
print("REST BBOX MATCHES SOURCE within 2mm (geometry untouched)", flush=True)

sc.render.engine = "CYCLES"; sc.cycles.samples = 32; sc.cycles.use_denoising = True; sc.cycles.device = "CPU"
world = bpy.data.worlds.new("W83"); sc.world = world; world.use_nodes = True
world.node_tree.nodes["Background"].inputs[0].default_value = (0.32, 0.33, 0.35, 1)
sd = bpy.data.lights.new("S83", "SUN"); sd.energy = 3.2
so = bpy.data.objects.new("S83", sd); sc.collection.objects.link(so)
so.rotation_euler = (math.radians(52), math.radians(8), math.radians(-38))
cam = bpy.data.objects.new("C83", bpy.data.cameras.new("C83")); sc.collection.objects.link(cam); sc.camera = cam
TG = (0.0, -0.01, 0.50)
for name, loc in {"front": (0, -1.9, 0.52), "back": (0, 1.9, 0.52), "sideL": (1.9, -0.01, 0.52), "3q": (1.15, -1.35, 0.75)}.items():
    cam.data.lens = 50; cam.location = loc
    cam.rotation_euler = (Vector(TG) - Vector(loc)).to_track_quat("-Z", "Y").to_euler()
    sc.render.resolution_x = sc.render.resolution_y = 950
    sc.render.filepath = f"{OUT}/audit83_rest_{name}.png"
    bpy.ops.render.render(write_still=True)
    print("RENDERED", name, flush=True)
print("DONE 83", flush=True)
