"""Build Phase-1 weapon-chain Actions for EXOCOMFLICT (owner priority 2026-10-30).

Creates ONLY the first deformation-validation chain:
  Idle -> Weapon_Raise -> Aim_Idle -> Fire -> Weapon_Lower
All clips are derived from the already-verified Weapon_Raise_To_Aim pose path.
No mesh, weights, materials, bones, or the source Action are modified.

Design choices for deformation safety:
- Idle/Aim_Idle breathing is applied mainly through Spine/Chest/UpperChest so
  both arms and the weapon move coherently; the two-hand grip cannot shear.
- Fire recoil is a common upper-torso impulse (no Weapon_R-only rotation), so
  the support hand stays on the foregrip by construction.
- Weapon_Raise is the source motion resampled to its stable-aim point (F36).
- Weapon_Lower is the same verified path reversed at 1.5x speed.
- Legs/feet remain at the source rest pose in every Phase-1 clip.

The blend is saved ONLY if every numeric gate at the bottom passes.
Blender 4.5 slotted Actions are handled with the same pattern as script 15.
"""
import bpy, math
from mathutils import Matrix, Quaternion, Vector

PROJ = "/home/user/Cyber-Strike/EXOCOMFLICT_HERO01"
BLEND = f"{PROJ}/blender/HERO_01_working.blend"
bpy.ops.wm.open_mainfile(filepath=BLEND)
sc = bpy.context.scene
arm = bpy.data.objects["HERO_01_Armature"]
weapon = bpy.data.objects["HERO_01_WEAPON"]
if arm.animation_data is None:
    arm.animation_data_create()
ad = arm.animation_data
src = bpy.data.actions.get("Weapon_Raise_To_Aim")
if src is None:
    raise RuntimeError("Source action Weapon_Raise_To_Aim not found")

ORDER = ["Root", "Hips", "Spine", "Chest", "UpperChest", "Neck", "Head",
         "Clavicle_R", "UpperArm_R", "Forearm_R", "Hand_R", "Weapon_R",
         "Clavicle_L", "UpperArm_L", "Forearm_L", "Hand_L",
         "UpperLeg_R", "LowerLeg_R", "Foot_R", "Toe_R",
         "UpperLeg_L", "LowerLeg_L", "Foot_L", "Toe_L"]
for pb in arm.pose.bones:
    pb.rotation_mode = 'QUATERNION'

# Weapon reference points in weapon-local/rest-authored coordinates (script 15).
FG0 = Vector((-0.215, -0.062, 0.315))
GRIP0 = Vector((-0.192, -0.033, 0.452))
MZ0 = Vector((-0.238, -0.080, 0.205))
RC0 = Vector((-0.198, -0.045, 0.500))
DIR_REST = (MZ0 - RC0).normalized()
FORWARD = Vector((0, -1, 0))


def set_action(act):
    ad.action = act
    if act is not None:
        try:
            if len(act.slots) == 0:
                act.slots.new(id_type='OBJECT', name=arm.name)
            ad.action_slot = act.slots[0]
        except Exception as ex:
            print("slot setup:", ex)


def action_fcurves(act):
    fc = []
    try:
        for layer in act.layers:
            for strip in layer.strips:
                cb = getattr(strip, "channelbag", None)
                if cb is not None and hasattr(cb, "fcurves"):
                    fc += list(cb.fcurves)
    except Exception:
        pass
    if not fc:
        try:
            fc = list(act.fcurves)
        except Exception:
            pass
    return fc


def current_basis():
    return {n: (arm.pose.bones[n].location.copy(),
                arm.pose.bones[n].rotation_quaternion.copy(),
                arm.pose.bones[n].scale.copy()) for n in ORDER}


def current_world():
    return {n: arm.pose.bones[n].matrix.copy() for n in ORDER}


def source_basis_at(frame):
    set_action(src)
    sc.frame_set(int(frame))
    bpy.context.view_layer.update()
    return current_basis()


def source_world_at(frame):
    set_action(src)
    sc.frame_set(int(frame))
    bpy.context.view_layer.update()
    return current_world()


def apply_basis(snap):
    for n in ORDER:
        loc, quat, scale = snap[n]
        pb = arm.pose.bones[n]
        pb.location = loc.copy()
        pb.rotation_quaternion = quat.copy()
        pb.scale = scale.copy()
    bpy.context.view_layer.update()


def apply_world(snap):
    for n in ORDER:
        arm.pose.bones[n].matrix = snap[n].copy()
        bpy.context.view_layer.update()


def rot_world(name, axis, deg):
    if abs(deg) < 1e-9:
        return
    pb = arm.pose.bones[name]
    head = pb.head.copy()
    m = Matrix.Translation(head) @ Matrix.Rotation(math.radians(deg), 4, axis) @ Matrix.Translation(-head)
    pb.matrix = m @ pb.matrix
    bpy.context.view_layer.update()


def create_action(name):
    old = bpy.data.actions.get(name)
    if old is not None:
        if ad.action == old:
            set_action(src)
        bpy.data.actions.remove(old)
    act = bpy.data.actions.new(name)
    act.use_fake_user = True
    return act


def key_all(act, frame):
    set_action(act)
    ok = 0
    for n in ORDER:
        pb = arm.pose.bones[n]
        ok += bool(pb.keyframe_insert("location", frame=frame))
        ok += bool(pb.keyframe_insert("rotation_quaternion", frame=frame))
    return ok


def finish_action(act):
    fc = action_fcurves(act)
    for c in fc:
        for kp in c.keyframe_points:
            kp.interpolation = 'BEZIER'
            kp.handle_left_type = 'AUTO_CLAMPED'
            kp.handle_right_type = 'AUTO_CLAMPED'
        c.update()
    print(f"ACTION {act.name}: range={tuple(float(x) for x in act.frame_range)} fcurves={len(fc)}")


def negate_quat(q):
    return Quaternion((-q.w, -q.x, -q.y, -q.z))


def make_sampled(name, samples):
    """samples = [(out_frame, basis_snapshot), ...] with quaternion continuity."""
    fixed = []
    prev = {}
    for out_frame, snap in samples:
        ns = {}
        for n in ORDER:
            loc, quat, scale = snap[n]
            q = quat.copy()
            if n in prev and prev[n].dot(q) < 0:
                q = negate_quat(q)
            prev[n] = q
            ns[n] = (loc.copy(), q, scale.copy())
        fixed.append((out_frame, ns))
    act = create_action(name)
    for out_frame, snap in fixed:
        set_action(None)
        sc.frame_set(int(out_frame))
        apply_basis(snap)
        key_all(act, int(out_frame))
    finish_action(act)
    return act


def make_idle():
    base = source_world_at(0)
    act = create_action("Idle")
    for out_frame in range(0, 91, 15):
        set_action(None)
        sc.frame_set(out_frame)
        apply_world(base)
        phase = 2 * math.pi * out_frame / 90.0
        s = math.sin(phase)
        sway = math.sin(2 * phase)
        rot_world("Spine", (1, 0, 0), -0.22 * s)
        rot_world("Chest", (1, 0, 0), -0.42 * s)
        rot_world("Chest", (0, 0, 1), 0.12 * sway)
        rot_world("UpperChest", (1, 0, 0), -0.30 * s)
        rot_world("UpperChest", (0, 0, 1), -0.08 * sway)
        rot_world("Neck", (1, 0, 0), 0.25 * s)
        rot_world("Head", (1, 0, 0), 0.20 * s)
        rot_world("Head", (0, 0, 1), -0.08 * sway)
        rot_world("Clavicle_R", (0, 1, 0), 0.18 * s)
        rot_world("Clavicle_L", (0, 1, 0), -0.18 * s)
        rot_world("UpperArm_R", (1, 0, 0), 0.08 * s)
        rot_world("UpperArm_L", (1, 0, 0), 0.08 * s)
        key_all(act, out_frame)
    finish_action(act)
    return act


def make_aim_idle():
    base = source_world_at(36)
    act = create_action("Aim_Idle")
    for out_frame in range(0, 91, 15):
        set_action(None)
        sc.frame_set(out_frame)
        apply_world(base)
        phase = 2 * math.pi * out_frame / 90.0
        s = math.sin(phase)
        sway = math.sin(2 * phase)
        rot_world("Spine", (1, 0, 0), -0.10 * s)
        rot_world("Chest", (1, 0, 0), -0.22 * s)
        rot_world("UpperChest", (1, 0, 0), -0.18 * s)
        rot_world("UpperChest", (0, 0, 1), 0.08 * sway)
        rot_world("Neck", (1, 0, 0), 0.15 * s)
        rot_world("Head", (1, 0, 0), 0.12 * s)
        rot_world("Head", (0, 0, 1), -0.05 * sway)
        rot_world("Clavicle_R", (0, 1, 0), 0.08 * s)
        rot_world("Clavicle_L", (0, 1, 0), -0.08 * s)
        key_all(act, out_frame)
    finish_action(act)
    return act


def make_fire():
    base = source_world_at(36)
    act = create_action("Fire")
    envelope = {0: 0.0, 1: 0.75, 2: 1.0, 4: 0.55, 7: 0.22, 9: -0.06, 12: 0.0}
    for out_frame, e in envelope.items():
        set_action(None)
        sc.frame_set(out_frame)
        apply_world(base)
        # Negative world-X rotation pitches the -Y barrel upward (muzzle climb).
        rot_world("Spine", (1, 0, 0), -0.25 * e)
        rot_world("Chest", (1, 0, 0), -0.65 * e)
        rot_world("UpperChest", (1, 0, 0), -0.95 * e)
        rot_world("UpperChest", (0, 0, 1), 0.25 * e)
        rot_world("Neck", (1, 0, 0), 0.35 * e)
        rot_world("Head", (1, 0, 0), 0.30 * e)
        rot_world("Head", (0, 0, 1), -0.12 * e)
        rot_world("Clavicle_R", (0, 1, 0), 0.10 * e)
        rot_world("Clavicle_L", (0, 1, 0), -0.10 * e)
        key_all(act, out_frame)
    finish_action(act)
    return act


# ---------------------------------------------------------------------------
# Build all Phase-1 actions.
# ---------------------------------------------------------------------------
sc.render.fps = 30
base_rest_world = source_world_at(0)
base_aim_world = source_world_at(36)

raise_samples = [(f, source_basis_at(float(f))) for f in range(0, 37, 3)]
lower_samples = [(f, source_basis_at(36.0 - 1.5 * f)) for f in range(0, 25, 2)]

actions = {}
actions["Idle"] = make_idle()
actions["Weapon_Raise"] = make_sampled("Weapon_Raise", raise_samples)
actions["Aim_Idle"] = make_aim_idle()
actions["Fire"] = make_fire()
actions["Weapon_Lower"] = make_sampled("Weapon_Lower", lower_samples)


# ---------------------------------------------------------------------------
# Numeric gates. Any failure raises before saving.
# ---------------------------------------------------------------------------
def metrics_at(act, frame):
    set_action(act)
    sc.frame_set(int(frame))
    bpy.context.view_layer.update()
    bd = (weapon.matrix_world.to_3x3() @ DIR_REST).normalized()
    hr = arm.pose.bones["Hand_R"].head.copy()
    hl = arm.pose.bones["Hand_L"].head.copy()
    grip = weapon.matrix_world @ GRIP0
    fg = weapon.matrix_world @ FG0
    return {
        "barrel": bd,
        "barrel_deg": math.degrees(bd.angle(FORWARD)),
        "r_grip": float((hr - grip).length),
        "l_grip": float((hl - fg).length),
        "hand_r": hr,
        "hand_l": hl,
        "foot_r": arm.pose.bones["Foot_R"].head.copy(),
        "foot_l": arm.pose.bones["Foot_L"].head.copy(),
        "basis": current_basis(),
        "world": current_world(),
    }


def require(cond, msg):
    print(("PASS " if cond else "FAIL ") + msg)
    if not cond:
        raise RuntimeError("Phase-1 animation gate failed: " + msg)


# Rest references from the source action itself.
set_action(src)
sc.frame_set(0)
bpy.context.view_layer.update()
rest_foot_r = arm.pose.bones["Foot_R"].head.copy()
rest_foot_l = arm.pose.bones["Foot_L"].head.copy()
rest_barrel = (weapon.matrix_world.to_3x3() @ DIR_REST).normalized()

for name, act in actions.items():
    lo, hi = (float(x) for x in act.frame_range)
    frames = list(range(int(lo), int(hi) + 1))
    ms = [metrics_at(act, f) for f in frames]
    max_r_dev = max(abs(m["r_grip"] - 0.0168) for m in ms)
    max_foot = max(max(float((m["foot_r"] - rest_foot_r).length),
                       float((m["foot_l"] - rest_foot_l).length)) for m in ms)
    finite = all(all(math.isfinite(float(c)) for c in m["hand_r"]) and
                 all(math.isfinite(float(c)) for c in m["hand_l"]) for m in ms)
    require(finite, f"{name}: sampled bone positions finite")
    require(max_r_dev <= 0.0015, f"{name}: right grip deviation {max_r_dev:.4f} <= 0.0015")
    require(max_foot <= 0.0015, f"{name}: feet planted, max foot-head drift {max_foot:.4f} <= 0.0015")

    if name == "Idle":
        b0, b90 = ms[0]["basis"], ms[-1]["basis"]
        max_q = 0.0
        for bn in ORDER:
            d = abs(b0[bn][1].dot(b90[bn][1]))
            max_q = max(max_q, 1.0 - min(1.0, d))
        hr_range = max(float((m["hand_r"] - ms[0]["hand_r"]).length) for m in ms)
        require(hi == 90, "Idle: duration 90 frames / 3.0 s")
        require(max_q <= 1e-5, f"Idle: loop endpoint quaternion closure {max_q:.2e} <= 1e-5")
        require(hr_range <= 0.012, f"Idle: right-hand breathing excursion {hr_range:.4f} <= 0.012")

    if name == "Weapon_Raise":
        contact = [m for f, m in zip(frames, ms) if f >= 24]
        require(hi == 36, "Weapon_Raise: duration 36 frames / 1.2 s")
        require(ms[-1]["barrel_deg"] <= 0.5, f"Weapon_Raise: final barrel error {ms[-1]['barrel_deg']:.3f} deg <= 0.5")
        require(max(m["l_grip"] for m in contact) <= 0.008,
                f"Weapon_Raise: contact-phase left grip <= 0.008 (got {max(m['l_grip'] for m in contact):.4f})")

    if name == "Aim_Idle":
        b0, b90 = ms[0]["basis"], ms[-1]["basis"]
        max_q = 0.0
        for bn in ORDER:
            d = abs(b0[bn][1].dot(b90[bn][1]))
            max_q = max(max_q, 1.0 - min(1.0, d))
        require(hi == 90, "Aim_Idle: duration 90 frames / 3.0 s")
        require(max_q <= 1e-5, f"Aim_Idle: loop endpoint quaternion closure {max_q:.2e} <= 1e-5")
        require(max(m["barrel_deg"] for m in ms) <= 1.0,
                f"Aim_Idle: max barrel sway {max(m['barrel_deg'] for m in ms):.3f} deg <= 1.0")
        require(max(m["l_grip"] for m in ms) <= 0.005,
                f"Aim_Idle: left grip <= 0.005 (got {max(m['l_grip'] for m in ms):.4f})")

    if name == "Fire":
        peak = max(m["barrel_deg"] for m in ms)
        require(hi == 12, "Fire: duration 12 frames / 0.4 s")
        require(1.0 <= peak <= 4.0, f"Fire: peak muzzle climb {peak:.3f} deg in [1,4]")
        require(ms[0]["barrel_deg"] <= 0.5 and ms[-1]["barrel_deg"] <= 0.5,
                "Fire: starts and recovers to stable aim")
        require(max(m["l_grip"] for m in ms) <= 0.005,
                f"Fire: left grip <= 0.005 (got {max(m['l_grip'] for m in ms):.4f})")

    if name == "Weapon_Lower":
        end_barrel_err = math.degrees(ms[-1]["barrel"].angle(rest_barrel))
        require(hi == 24, "Weapon_Lower: duration 24 frames / 0.8 s")
        require(ms[0]["barrel_deg"] <= 0.5, "Weapon_Lower: starts at stable aim")
        require(ms[0]["l_grip"] <= 0.005, "Weapon_Lower: starts with support grip closed")
        require(end_barrel_err <= 0.5, f"Weapon_Lower: ends at rest barrel direction (err {end_barrel_err:.3f} deg)")

# Restore shipped active action/frame, widen timeline for the 3 s loops, save.
set_action(src)
sc.frame_start = 0
sc.frame_end = 90
sc.frame_set(0)
bpy.context.view_layer.update()
bpy.ops.wm.save_mainfile()
print("SAVED blend with Phase-1 actions:", [a.name for a in bpy.data.actions])
print("DONE")
