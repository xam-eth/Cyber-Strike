"""READ-ONLY animation audit before the EXOCOMFLICT production animation set.
Lists Actions/slots/fcurves, scene timing, NLA state, and samples the shipped
Weapon_Raise_To_Aim pose/grip metrics. Does not modify or save the blend."""
import bpy
from mathutils import Vector

PROJ = "/home/user/Cyber-Strike/EXOCOMFLICT_HERO01"
bpy.ops.wm.open_mainfile(filepath=f"{PROJ}/blender/HERO_01_working.blend")
sc = bpy.context.scene
arm = bpy.data.objects["HERO_01_Armature"]
weapon = bpy.data.objects.get("HERO_01_WEAPON")
ORDER = ["Root", "Hips", "Spine", "Chest", "UpperChest", "Neck", "Head",
         "Clavicle_R", "UpperArm_R", "Forearm_R", "Hand_R", "Weapon_R",
         "Clavicle_L", "UpperArm_L", "Forearm_L", "Hand_L",
         "UpperLeg_R", "LowerLeg_R", "Foot_R", "Toe_R",
         "UpperLeg_L", "LowerLeg_L", "Foot_L", "Toe_L"]


def action_fcurves(act):
    fc = []
    try:
        for layer in act.layers:
            for strip in layer.strips:
                cb = getattr(strip, "channelbag", None)
                if cb is not None:
                    fc += list(cb.fcurves)
    except Exception as ex:
        print(" layered fcurve enum failed:", ex)
    if not fc:
        try:
            fc = list(act.fcurves)
        except Exception:
            pass
    return fc


print(f"scene fps={sc.render.fps} frame_range={sc.frame_start}..{sc.frame_end}")
print("objects:", [(o.name, o.type) for o in sc.objects])
print("bones:", len(arm.data.bones), [b.name for b in arm.data.bones])
ad = arm.animation_data
print("animation_data:", ad)
if ad:
    print(" active action:", ad.action.name if ad.action else None,
          "slot:", getattr(ad.action_slot, "name", None) if getattr(ad, "action_slot", None) else None)
    print(" nla tracks:", [(t.name, len(t.strips), t.mute) for t in ad.nla_tracks])

for act in bpy.data.actions:
    fc = action_fcurves(act)
    keys = []
    bones = set()
    paths = set()
    for c in fc:
        paths.add(c.data_path)
        if 'pose.bones["' in c.data_path:
            try:
                bones.add(c.data_path.split('pose.bones["', 1)[1].split('"]', 1)[0])
            except Exception:
                pass
        keys += [float(k.co.x) for k in c.keyframe_points]
    print(f"ACTION {act.name!r} users={act.users} fake={act.use_fake_user} "
          f"range={tuple(float(x) for x in act.frame_range)} slots={len(getattr(act, 'slots', []))} "
          f"fcurves={len(fc)} bones={len(bones)} keyframes={len(keys)} "
          f"key_range={(min(keys), max(keys)) if keys else None}")
    missing = [b for b in ORDER if b not in bones]
    if missing:
        print("  bones without fcurves:", missing)

src = bpy.data.actions.get("Weapon_Raise_To_Aim")
if src and weapon:
    if ad is None:
        arm.animation_data_create()
        ad = arm.animation_data
    ad.action = src
    try:
        if len(src.slots):
            ad.action_slot = src.slots[0]
    except Exception as ex:
        print("slot assign:", ex)
    FG0 = Vector((-0.215, -0.062, 0.315))
    GRIP0 = Vector((-0.192, -0.033, 0.452))
    MZ0 = Vector((-0.238, -0.080, 0.205))
    RC0 = Vector((-0.198, -0.045, 0.500))
    DIR_REST = (MZ0 - RC0).normalized()
    for fr in (0, 8, 18, 28, 36, 45):
        sc.frame_set(fr)
        bpy.context.view_layer.update()
        bd = (weapon.matrix_world.to_3x3() @ DIR_REST).normalized()
        hr = arm.pose.bones["Hand_R"].head.copy()
        hl = arm.pose.bones["Hand_L"].head.copy()
        grip = weapon.matrix_world @ GRIP0
        fg = weapon.matrix_world @ FG0
        mz = weapon.matrix_world @ MZ0
        print(f"F{fr:02d} barrel={tuple(round(float(x),3) for x in bd)} "
              f"Rhand->grip={float((hr-grip).length):.4f} Lhand->foregrip={float((hl-fg).length):.4f} "
              f"Hand_R={tuple(round(float(x),3) for x in hr)} Hand_L={tuple(round(float(x),3) for x in hl)} "
              f"muzzle={tuple(round(float(x),3) for x in mz)}")
    for fr in (0, 36):
        sc.frame_set(fr)
        bpy.context.view_layer.update()
        print(f"POSE SAMPLE F{fr}")
        for bn in ("Hips", "Chest", "UpperChest", "Clavicle_R", "Hand_R", "Clavicle_L", "Hand_L"):
            pb = arm.pose.bones[bn]
            print(f" {bn}: mode={pb.rotation_mode} loc={tuple(round(float(x),5) for x in pb.location)} "
                  f"quat={tuple(round(float(x),5) for x in pb.rotation_quaternion)} "
                  f"scale={tuple(round(float(x),5) for x in pb.scale)} head={tuple(round(float(x),3) for x in pb.head)}")
print("DONE (read-only)")
