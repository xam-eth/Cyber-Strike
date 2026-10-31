"""72 - Export NEW_HERO_01 Phase-1 animation GLBs (pattern of script 49):
- assets/characters/HERO_01_RIGGED.glb (armature + body + 5 clips;
  the in-blend weapon object is NOT selected/exported)
- animations/HERO_01_ANIMATIONS.glb (skeleton-only + same 5 clips)
Then doubleSided-patch RIGGED and roundtrip-verify: clip names/durations,
24 joints, and that POSITION/WEIGHTS_0/JOINTS_0 payloads are IDENTICAL to
the pre-animation shipped GLB (pass its path as argv after '--').
Run: tools/blender/run_bpy.sh tools/blender/scripts/72_export_phase1_newhero.py -- /tmp/pre_anim_rigged.glb
"""
import bpy
import os
import struct
import subprocess
import sys
import numpy as np

PROJ = "/home/user/Cyber-Strike/EXOCOMFLICT_HERO01"
BLEND = f"{PROJ}/blender/NEW_HERO_01_working.blend"
RIGGED = f"{PROJ}/assets/characters/HERO_01_RIGGED.glb"
ANIM = f"{PROJ}/animations/HERO_01_ANIMATIONS.glb"
argv = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
PRE = argv[0] if argv else None

bpy.ops.wm.open_mainfile(filepath=BLEND)
if bpy.context.object is not None and bpy.context.object.mode != "OBJECT":
    bpy.ops.object.mode_set(mode="OBJECT")
arm = bpy.data.objects["HERO_01_Armature"]
body = bpy.data.objects["HERO_01_BODY"]
sc = bpy.context.scene
sc.frame_set(0)
if arm.animation_data:
    arm.animation_data.action = None
bpy.context.view_layer.update()

expected = ["Aim_Idle", "Fire", "Idle", "Weapon_Lower", "Weapon_Raise"]
have = sorted(a.name for a in bpy.data.actions)
print("ACTIONS IN BLEND:", have, flush=True)
assert have == expected, f"{have} != {expected}"

def select(objs):
    bpy.ops.object.select_all(action="DESELECT")
    for o in objs:
        o.select_set(True)
    bpy.context.view_layer.objects.active = objs[0]

select([arm, body])
bpy.ops.export_scene.gltf(filepath=RIGGED, export_format="GLB", use_selection=True, export_yup=True,
                          export_apply=False, export_skins=True, export_def_bones=False,
                          export_animations=True, export_animation_mode="ACTIONS",
                          export_force_sampling=True, export_optimize_animation_size=False,
                          export_materials="EXPORT")
print(f"EXPORTED RIGGED {os.path.getsize(RIGGED)}", flush=True)
r = subprocess.run([sys.executable, f"{PROJ}/tools/patch_glb_double_sided.py", RIGGED], capture_output=True, text=True)
print(r.stdout.strip() or r.stderr.strip(), flush=True)
assert r.returncode == 0

select([arm])
bpy.ops.export_scene.gltf(filepath=ANIM, export_format="GLB", use_selection=True, export_yup=True,
                          export_animations=True, export_animation_mode="ACTIONS",
                          export_force_sampling=True, export_optimize_animation_size=False)
print(f"EXPORTED ANIMATIONS {os.path.getsize(ANIM)}", flush=True)

from pygltflib import GLTF2
def acc_array(gltf, idx):
    acc = gltf.accessors[idx]
    bv = gltf.bufferViews[acc.bufferView]
    data = gltf.binary_blob()
    off = (bv.byteOffset or 0) + (acc.byteOffset or 0)
    comp = {5126: "f", 5123: "H", 5125: "I", 5121: "B"}[acc.componentType]
    n = {"SCALAR": 1, "VEC2": 2, "VEC3": 3, "VEC4": 4}[acc.type]
    return np.array(struct.unpack_from("<" + comp * n * acc.count, data, off)).reshape(acc.count, n)

def anim_durations(gltf):
    out = {}
    for a in gltf.animations or []:
        mx = 0.0
        for s in a.samplers:
            t = acc_array(gltf, s.input)
            mx = max(mx, float(t.max()))
        out[a.name] = mx
    return out

g = GLTF2().load(RIGGED)
durs = anim_durations(g)
print("RIGGED animations:", durs, flush=True)
EXP_DUR = {"Idle": 3.0, "Weapon_Raise": 1.2, "Aim_Idle": 3.0, "Fire": 0.4, "Weapon_Lower": 0.8}
for k, v in EXP_DUR.items():
    assert k in durs and abs(durs[k] - v) < 0.05, (k, durs.get(k))
joints = [g.nodes[j].name for j in g.skins[0].joints]
assert len(joints) == 24 and "Weapon_R" in joints
assert all(m.doubleSided for m in g.materials)
ga = GLTF2().load(ANIM)
da = anim_durations(ga)
print("ANIMATIONS file:", da, "meshes:", len(ga.meshes or []), flush=True)
assert sorted(da.keys()) == sorted(EXP_DUR.keys())

if PRE and os.path.exists(PRE):
    gp = GLTF2().load(PRE)
    for label, getidx in (("POSITION", lambda p: p.attributes.POSITION),
                          ("WEIGHTS_0", lambda p: p.attributes.WEIGHTS_0),
                          ("JOINTS_0", lambda p: p.attributes.JOINTS_0),
                          ("NORMAL", lambda p: p.attributes.NORMAL),
                          ("TEXCOORD_0", lambda p: p.attributes.TEXCOORD_0)):
        a1 = acc_array(g, getidx(g.meshes[0].primitives[0])).astype(np.float64)
        a2 = acc_array(gp, getidx(gp.meshes[0].primitives[0])).astype(np.float64)
        same = a1.shape == a2.shape and np.array_equal(a1, a2)
        print(f"DIFF {label}: identical={same} shape={a1.shape} vs {a2.shape} maxdelta={(np.abs(a1-a2).max() if a1.shape==a2.shape else -1)}", flush=True)
        assert same, f"{label} changed vs pre-animation GLB"
    jp = [gp.nodes[j].name for j in gp.skins[0].joints]
    print(f"DIFF joints identical order: {joints == jp}", flush=True)
    assert joints == jp
print("DONE 72", flush=True)
