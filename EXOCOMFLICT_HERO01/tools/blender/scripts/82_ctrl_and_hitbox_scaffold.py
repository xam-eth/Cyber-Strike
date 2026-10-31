"""82 - Hybrid rig Stage C part 1 (owner-approved scope, 2026-10-31):
persistent NON-EXPORT authoring layers saved in the working blend:
 * HERO_01_CTRL armature mirroring all 54 deform bones ("_CTRL" suffix),
   driving the deform pose bones via Copy Transforms constraints that
   are created MUTED (retarget/procedural scripts pose DEF bones
   directly; un-mute for manual posing in the Blender UI).
 * Hitbox scaffold: bone-parented EMPTY markers for 19 major body
   segments (Dynamic Injury volumes), hidden + non-render, carrying
   hb_radius/hb_part metadata. INACTIVE by design: gameplay collision
   shapes are authored on the Godot side from this scaffold.
Neither layer is exported (script 83 exports by explicit selection of
the deform armature + body only, same selection script 68 used).
Gates: deform weights byte-identical, 54+54 bones, all constraints
muted, evaluated rest mesh unchanged. Saves blend ONLY if gates pass.
Run: tools/blender/run_bpy.sh tools/blender/scripts/82_ctrl_and_hitbox_scaffold.py
"""
import bpy
import numpy as np
from mathutils import Vector

PROJ = "/home/user/Cyber-Strike/EXOCOMFLICT_HERO01"
BLEND = f"{PROJ}/blender/NEW_HERO_01_working.blend"
HB_BONES = ["Head", "Neck", "UpperChest", "Chest", "Spine", "Hips",
            "UpperArm_L", "Forearm_L", "Hand_L", "UpperArm_R", "Forearm_R", "Hand_R",
            "UpperLeg_L", "LowerLeg_L", "Foot_L", "UpperLeg_R", "LowerLeg_R", "Foot_R"]
HB_PART = {"Head": "head", "Neck": "neck", "UpperChest": "chest", "Chest": "chest",
           "Spine": "abdomen", "Hips": "pelvis"}

bpy.ops.wm.open_mainfile(filepath=BLEND)
arm = bpy.data.objects["HERO_01_Armature"]
body = bpy.data.objects["HERO_01_BODY"]
sc = bpy.context.scene
assert len(arm.data.bones) == 54, f"need 54-bone Stage B blend, found {len(arm.data.bones)}"
assert "HERO_01_CTRL" not in bpy.data.objects, "CTRL armature already exists (not idempotent)"
me = body.data
nv = len(me.vertices)

# baseline: weights snapshot + evaluated rest positions
snap = [tuple(sorted((ge.group, round(ge.weight, 6)) for ge in v.groups)) for v in me.vertices]
def eval_pos():
    dg = bpy.context.evaluated_depsgraph_get()
    eo = body.evaluated_get(dg); m2 = eo.to_mesh()
    P = np.empty(len(m2.vertices) * 3); m2.vertices.foreach_get("co", P); P = P.reshape(-1, 3)
    eo.to_mesh_clear()
    return P
P0 = eval_pos()

# --- CTRL collection + armature ---
ctrl_coll = bpy.data.collections.new("CTRL_non_export")
sc.collection.children.link(ctrl_coll)
ctrl_data = bpy.data.armatures.new("HERO_01_CTRL")
ctrl = bpy.data.objects.new("HERO_01_CTRL", ctrl_data)
ctrl_coll.objects.link(ctrl)
ctrl.hide_render = True
ctrl.show_in_front = True
ctrl_data.display_type = "STICK"

defs = [(b.name, Vector(b.head_local), Vector(b.tail_local),
         b.parent.name if b.parent else None, b.use_connect) for b in arm.data.bones]
bpy.context.view_layer.objects.active = ctrl
bpy.ops.object.mode_set(mode="EDIT")
eb = ctrl_data.edit_bones
made = {}
for name, head, tail, pname, conn in defs:
    b = eb.new(f"{name}_CTRL")
    b.head = head; b.tail = tail
    b.use_deform = False
    b.use_connect = False
    made[name] = b
for name, head, tail, pname, conn in defs:
    if pname:
        made[name].parent = made[pname]
bpy.ops.object.mode_set(mode="OBJECT")
print(f"CTRL armature bones: {len(ctrl_data.bones)}", flush=True)

# --- muted drive constraints DEF pose bone -> CTRL bone ---
n_con = 0
for pb in arm.pose.bones:
    c = pb.constraints.new("COPY_TRANSFORMS")
    c.name = "CTRL_drive (unmute to pose manually)"
    c.target = ctrl
    c.subtarget = f"{pb.name}_CTRL"
    c.mute = True
    n_con += 1
print(f"drive constraints (muted): {n_con}", flush=True)

# --- hitbox scaffold empties (inactive) ---
hb_coll = bpy.data.collections.new("Hitboxes_non_export")
sc.collection.children.link(hb_coll)
n_hb = 0
for bn in HB_BONES:
    b = arm.data.bones[bn]
    L = (Vector(b.tail_local) - Vector(b.head_local)).length
    e = bpy.data.objects.new(f"HB_{bn}", None)
    hb_coll.objects.link(e)
    e.empty_display_type = "CUBE"
    e.empty_display_size = L
    e.parent = arm
    e.parent_type = "BONE"
    e.parent_bone = bn
    e.hide_render = True
    e.hide_viewport = True
    e["hb_part"] = HB_PART.get(bn, "arm" if any(x in bn for x in ("Arm", "Hand")) else "leg")
    e["hb_radius_m"] = 0.06
    e["hb_length_m"] = round(L, 4)
    e["hb_active"] = False
    n_hb += 1
print(f"hitbox scaffold empties: {n_hb}", flush=True)
bpy.context.view_layer.update()

# --- gates ---
bad = 0
for i, v in enumerate(me.vertices):
    if tuple(sorted((ge.group, round(ge.weight, 6)) for ge in v.groups)) != snap[i]:
        bad += 1
P1 = eval_pos()
dev = float(np.abs(P1 - P0).max()) if len(P1) == len(P0) else 999.0
muted_ok = all(c.mute for pb in arm.pose.bones for c in pb.constraints)
print(f"GATE weight mismatches={bad} rest-dev={dev*1000:.3f}mm constraints-muted={muted_ok} "
      f"DEF bones={len(arm.data.bones)} CTRL bones={len(ctrl_data.bones)} HB={n_hb}", flush=True)
assert bad == 0 and dev < 1e-6 and muted_ok
assert len(ctrl_data.bones) == 54 and n_con == 54 and n_hb == len(HB_BONES)

bpy.context.preferences.filepaths.use_file_compression = True
bpy.ops.wm.save_as_mainfile(filepath=BLEND, compress=True)
print(f"SAVED {BLEND}", flush=True)
print("DONE 82", flush=True)
