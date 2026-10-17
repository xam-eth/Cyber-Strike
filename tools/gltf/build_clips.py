#!/usr/bin/env python3
"""Bake the hero's combat clips (aim, fire) into the rigged hero GLB.

Why this exists
---------------
The Tripo hero arrived with ``idle``, ``run`` and ``walk`` only — no aiming and
no firing, which is exactly what a third-person shooter needs. There is no
Blender in this environment (the bpy wheel needs native GL libraries this image
does not ship), so the clips are authored here, in glTF space, with analytic
two-bone IK on the real skeleton:

* ``aim``  holds the rifle up, both hands on the weapon, breathing, loops.
* ``fire`` is the aim pose plus a recoil impulse that settles back into it.

The right hand is solved to a fixed point in the character's local space and the
wrist keeps the forearm's natural orientation, so the pose does not depend on
where the shoulder happens to be. ``hero_rig.json`` records the resulting
weapon attach rotation and scale — the weapon is then parented to the hand bone
with those numbers, and its baked ``MuzzlePoint`` is what the shot effect is
placed on. That is the whole trick behind "the flash comes out of the barrel":
the muzzle is a node in the rifle mesh, not a hand-tuned offset.

Run:  .venv/bin/python tools/gltf/build_clips.py [--check]
"""
from __future__ import annotations

import json
import math
import sys
from pathlib import Path

import numpy as np

sys.path.insert(0, str(Path(__file__).resolve().parent))
from rigmath import (  # noqa: E402
    BinWriter,
    Skeleton,
    q_about_axis,
    q_conj,
    q_mul,
    q_normalize,
    q_rotate,
    q_swing,
    accessor_array,
    read_glb,
    write_glb,
)

ROOT = Path(__file__).resolve().parents[2]
HERO = ROOT / "game/assets/characters/hero/hero.glb"
RIG_JSON = ROOT / "game/assets/characters/hero/hero_rig.json"

FPS = 30
AIM_SECONDS = 2.0
FIRE_SECONDS = 0.5

# --- pose targets, in hero-local metres (the mesh is 1.0 m tall, faces +Z) ---
RIGHT_HAND = np.array([-0.035, 0.660, 0.120])
RIGHT_POLE = np.array([-0.42, 0.52, -0.10])  # elbow points out, back and down
LEFT_POLE = np.array([0.50, 0.46, -0.02])  # support elbow drops below the rifle

GUN_SCALE = 0.40  # weapon units -> hero model units (0.40 * 1.78 m = 0.71 m)
GUN_MUZZLE = np.array([0.0, 0.16121, -0.67008])  # from rifle_points.json
GUN_SUPPORT = np.array([0.0, 0.050, -0.28])  # left hand on the handguard

# local +Y is the bone axis for this rig (Blender convention), so a rotation
# about local X pitches the bone forward/back.
PITCH_AXIS = np.array([1.0, 0.0, 0.0])


def two_bone_ik(sk, rot, tra, sca, upper_name, fore_name, hand_name, target, pole):
    """Place the hand at `target`; returns (rot, hand_pos, elbow_pos, reach_ratio)."""
    upper, fore, hand = sk.name[upper_name], sk.name[fore_name], sk.name[hand_name]
    grot, gpos = sk.fk(rot, tra, sca)
    origin = gpos[upper]
    l1 = float(np.linalg.norm(tra[fore]))
    l2 = float(np.linalg.norm(tra[hand]))

    delta = np.asarray(target, dtype=np.float64) - origin
    dist = float(np.linalg.norm(delta))
    reach = dist / (l1 + l2)
    dist = min(max(dist, abs(l1 - l2) + 1e-4), l1 + l2 - 1e-4)
    direction = delta / max(float(np.linalg.norm(delta)), 1e-9)
    clamped_target = origin + direction * dist

    along = (l1 * l1 - l2 * l2 + dist * dist) / (2 * dist)
    height = math.sqrt(max(0.0, l1 * l1 - along * along))
    pole_dir = np.asarray(pole, dtype=np.float64) - origin
    pole_dir = pole_dir - direction * float(np.dot(pole_dir, direction))
    if np.linalg.norm(pole_dir) < 1e-6:
        pole_dir = np.cross(direction, [0.0, 1.0, 0.0])
    pole_dir = pole_dir / np.linalg.norm(pole_dir)
    elbow = origin + direction * along + pole_dir * height

    # 1. swing the upper arm so the elbow lands on the IK solution
    current = gpos[fore] - origin
    new_global = q_mul(q_swing(current, elbow - origin), grot[upper])
    parent = sk.parent[upper]
    rot[upper] = q_mul(q_conj(grot[parent]), new_global)

    # 2. then swing the forearm so the wrist lands on the (clamped) target
    grot2, gpos2 = sk.fk(rot, tra, sca)
    current = gpos2[hand] - gpos2[fore]
    new_fore = q_mul(q_swing(current, clamped_target - gpos2[fore]), grot2[fore])
    rot[fore] = q_mul(q_conj(grot2[sk.parent[fore]]), new_fore)

    grot3, gpos3 = sk.fk(rot, tra, sca)
    return rot, gpos3[hand], elbow, reach


def gun_transform(rot, tra, sca, sk, offset_local):
    """Hero-space transform of the rifle: grip at the hand, barrel along +Z."""
    grot, gpos = sk.fk(rot, tra, sca)
    hand = sk.name["R_Hand"]
    hand_q = grot[hand]
    hand_p = gpos[hand]

    def to_hero(p_gun):
        v = q_rotate(hand_q, q_rotate(offset_local, np.asarray(p_gun) * GUN_SCALE))
        return hand_p + v

    barrel = q_mul(hand_q, offset_local)
    return to_hero, barrel, hand_p


def solve_pose(sk, base, hand_target, hand_pitch, breath, attach):
    """One aim frame: breathing, right-arm IK, wrist pitch, support-arm IK."""
    base_rot, base_tra, base_sca = base
    rot = dict(base_rot)
    tra = dict(base_tra)
    sca = dict(base_sca)

    for bone, amount in (("Spine01", 0.010), ("Spine02", 0.007), ("NeckTwist02", 0.005)):
        i = sk.name[bone]
        rot[i] = q_mul(rot[i], q_about_axis(PITCH_AXIS, -amount * breath))

    rot, right_hand, elbow, reach_r = two_bone_ik(
        sk, rot, tra, sca, "R_Upperarm", "R_Forearm", "R_Hand", hand_target, RIGHT_POLE
    )
    if abs(hand_pitch) > 1e-9:
        hand = sk.name["R_Hand"]
        rot[hand] = q_mul(rot[hand], q_about_axis(PITCH_AXIS, hand_pitch))

    to_hero, barrel_q, hand_p = gun_transform(rot, tra, sca, sk, attach)
    support = to_hero(GUN_SUPPORT)
    rot, left_hand, _, reach_l = two_bone_ik(
        sk, rot, tra, sca, "L_Upperarm", "L_Forearm", "L_Hand", support, LEFT_POLE
    )
    return rot, tra, sca, {
        "right_hand": right_hand,
        "left_hand": left_hand,
        "elbow": elbow,
        "reach_right": reach_r,
        "reach_left": reach_l,
        "support": support,
    }


def build_attach(sk, base):
    """Weapon socket rotation that makes the barrel point along hero +Z."""
    rot, tra, sca, _ = solve_pose(sk, base, RIGHT_HAND, 0.0, 0.0, np.array([0.0, 0.0, 0.0, 1.0]))
    grot, _ = sk.fk(rot, tra, sca)
    # -Z forward and +Y up means a 180 deg yaw: basis X=-X, Y=+Y, Z=-Z.
    gun_target_q = np.array([0.0, 1.0, 0.0, 0.0])
    return q_normalize(q_mul(q_conj(grot[sk.name["R_Hand"]]), gun_target_q))


def build_aim(sk, attach):
    base = sk.local_pose("idle", 0.0)
    frames = int(round(AIM_SECONDS * FPS)) + 1
    keys = {"rot": [], "tra": [], "sca": []}
    report = {}
    for f in range(frames):
        t = f / FPS
        breath = math.sin(2.0 * math.pi * t / AIM_SECONDS)
        rot, tra, sca, info = solve_pose(sk, base, RIGHT_HAND, 0.0, breath, attach)
        keys["rot"].append({i: rot[i].copy() for i in sk.joints})
        keys["tra"].append({i: tra[i].copy() for i in sk.joints})
        keys["sca"].append({i: sca[i].copy() for i in sk.joints})
        report = info
    return keys, report, base


def build_fire(sk, base, attach):
    """Aim pose + recoil: the grip is driven back into the shoulder and the
    wrist pitches up, so the muzzle travels backwards and rises."""
    frames = int(round(FIRE_SECONDS * FPS)) + 1
    rest = RIGHT_HAND.copy()

    def frame_at(k, pitch_sign):
        target = rest + np.array([0.0, 0.010 * k, -0.030 * k])
        rot, tra, sca, info = solve_pose(sk, base, target, pitch_sign * math.radians(3.6) * k, 0.0, attach)
        return rot, tra, sca, info

    def muzzle_of(rot, tra, sca):
        to_hero, _, _ = gun_transform(rot, tra, sca, sk, attach)
        return to_hero(GUN_MUZZLE)

    rest_rot, rest_tra, rest_sca, _ = frame_at(0.0, 1.0)
    rest_muzzle = muzzle_of(rest_rot, rest_tra, rest_sca)
    sign = 1.0
    probe = frame_at(1.0, sign)
    if muzzle_of(*probe[:3])[1] < rest_muzzle[1]:
        sign = -1.0
        probe = frame_at(1.0, sign)
    peak = muzzle_of(*probe[:3])
    assert (peak - rest_muzzle)[2] < -0.005, "recoil must drive the muzzle backwards"

    keys = {"rot": [], "tra": [], "sca": []}
    for f in range(frames):
        t = f / FPS
        k = (t / 0.06) if t < 0.06 else math.exp(-(t - 0.06) / 0.11)
        rot, tra, sca, _ = frame_at(k, sign)
        keys["rot"].append({i: rot[i].copy() for i in sk.joints})
        keys["tra"].append({i: tra[i].copy() for i in sk.joints})
        keys["sca"].append({i: sca[i].copy() for i in sk.joints})
    return keys, float((peak - rest_muzzle)[2]), rest_muzzle, float(peak[1] - rest_muzzle[1])


CARRY_DIRECTION = np.array([0.0, -0.75, 0.66])  # muzzle forward and ~49 deg down


def carry_socket_rotation(sk, base, attach):
    """Socket rotation that turns the lowered rifle into a carry angle.

    The socket is authored for the aim pose, so with the arms down the barrel
    points sideways. Rotating the socket (not the wrist) keeps the hand's
    animation natural and lets the game blend aim <-> carry smoothly.
    """
    base_rot, base_tra, base_sca = base
    grot, _ = sk.fk(base_rot, base_tra, base_sca)
    hand_q = grot[sk.name["R_Hand"]]
    barrel = q_rotate(q_mul(hand_q, attach), np.array([0.0, 0.0, -1.0]))
    desired = CARRY_DIRECTION / np.linalg.norm(CARRY_DIRECTION)
    world_swing = q_swing(barrel, desired)
    socket = q_normalize(q_mul(q_mul(q_conj(hand_q), q_mul(world_swing, hand_q)), attach))
    check = q_rotate(q_mul(hand_q, socket), np.array([0.0, 0.0, -1.0]))
    return socket, barrel, desired, check


def recenter_hips(js, sk, writer, clip, threshold=0.05):
    """Some Tripo clips park the whole body away from the node origin.

    `run` ships with the hips offset ~0.55 units forward of the rest position
    (constant across the clip), so the avatar would slide ahead of its collider
    during the whole run. Subtract that constant offset — the stride, the bob
    and every limb angle stay untouched — so the clip is in place.
    """
    anim = sk.animations[clip]
    hip = sk.name["Hip"]
    for ch in anim["channels"]:
        tgt = ch["target"]
        if tgt["path"] != "translation" or tgt.get("node") != hip:
            continue
        sampler = anim["samplers"][ch["sampler"]]
        values = accessor_array(js, writer.bin, sampler["output"])
        offset = values.mean(axis=0) - sk.rest_t[hip]
        distance = float(np.linalg.norm(offset))
        if distance < threshold:
            return 0.0
        sampler["output"] = writer.add(values - offset, "VEC3", 5126)
        return distance
    return 0.0


def add_clip(sk, js, writer, name, keys, changed_bones):
    """Write one animation: full channels, 1 key for untouched bones."""
    n = len(keys["rot"])
    times = np.arange(n, dtype=np.float64) / FPS
    time_acc = writer.add(times.reshape(-1, 1), "SCALAR", 5126, minmax=True)

    changed = {sk.name[b] for b in changed_bones}
    anim = {"name": name, "channels": [], "samplers": []}
    for node in sk.joints:
        for path, table, gtype in (
            ("rotation", "rot", "VEC4"),
            ("translation", "tra", "VEC3"),
            ("scale", "sca", "VEC3"),
        ):
            count = n if (path == "rotation" and node in changed) else 1
            seq = np.stack([keys[table][i][node] for i in range(n)])
            if count == 1:
                seq = seq[0:1]
                inp = writer.add(np.array([[0.0]]), "SCALAR", 5126, minmax=True)
            else:
                inp = time_acc
            if path == "rotation":
                # keep quaternions on the same hemisphere, otherwise LINEAR
                # interpolation takes the long way round
                seq = seq.copy()
                for i in range(1, len(seq)):
                    if float(np.dot(seq[i], seq[i - 1])) < 0:
                        seq[i] = -seq[i]
                seq = seq / np.linalg.norm(seq, axis=1, keepdims=True)
            out = writer.add(seq, gtype, 5126)
            anim["samplers"].append({"input": inp, "output": out, "interpolation": "LINEAR"})
            anim["channels"].append(
                {"sampler": len(anim["samplers"]) - 1, "target": {"node": node, "path": path}}
            )
    js["animations"].append(anim)


def main():
    check_only = "--check" in sys.argv
    js, bin_ = read_glb(HERO)
    sk = Skeleton(js, bin_)
    for clip in ("idle", "run", "walk"):
        assert clip in sk.animations, f"missing source clip {clip}"

    attach = build_attach(sk, sk.local_pose("idle", 0.0))
    aim_keys, report, base = build_aim(sk, attach)
    fire_keys, muzzle_dz, rest_muzzle, muzzle_dy = build_fire(sk, base, attach)

    # ---- verification numbers (these are what the report prints) ----------
    grot, gpos = sk.fk(aim_keys["rot"][0], aim_keys["tra"][0], aim_keys["sca"][0])
    hand_err = float(np.linalg.norm(gpos[sk.name["R_Hand"]] - RIGHT_HAND))
    to_hero, barrel_q, hand_p = gun_transform(aim_keys["rot"][0], aim_keys["tra"][0], aim_keys["sca"][0], sk, attach)
    muzzle_hero = to_hero(GUN_MUZZLE)
    barrel_dir = q_rotate(barrel_q, np.array([0.0, 0.0, -1.0]))
    pitch = math.degrees(math.asin(max(-1.0, min(1.0, barrel_dir[1]))))
    left_err = float(np.linalg.norm(gpos[sk.name["L_Hand"]] - report["support"]))

    recentered = {}
    carry_rot, carry_before, carry_desired, carry_check = carry_socket_rotation(sk, sk.local_pose("idle", 0.0), attach)

    if not check_only:
        writer = BinWriter(js, bin_)
        recentered = {clip: recenter_hips(js, sk, writer, clip) for clip in ("idle", "walk", "run")}
        js["animations"] = [a for a in js["animations"] if a.get("name") not in ("aim", "fire")]
        add_clip(sk, js, writer, "aim", aim_keys, ["R_Upperarm", "R_Forearm", "L_Upperarm", "L_Forearm",
                                                   "Spine01", "Spine02", "NeckTwist02"])
        add_clip(sk, js, writer, "fire", fire_keys, ["R_Upperarm", "R_Forearm", "R_Hand",
                                                     "L_Upperarm", "L_Forearm", "Spine01", "Spine02"])
        write_glb(HERO, js, writer.bin)

    RIG_JSON.parent.mkdir(parents=True, exist_ok=True)
    rig = {
        "note": "Generated by tools/gltf/build_clips.py — do not edit by hand.",
        "model": "hero.glb",
        "units": "hero model is 1.0 unit tall; CharacterVisual scales it to target_height",
        "skeleton": "Armature",
        "hand_bone": "R_Hand",
        "weapon_socket": {
            "aim_rotation_xyzw": [round(float(v), 6) for v in attach],
            "carry_rotation_xyzw": [round(float(v), 6) for v in carry_rot],
            "offset": [0.0, 0.018, 0.0],
            "scale_model_units": GUN_SCALE,
        },
        "weapon_muzzle_local": [round(float(v), 5) for v in GUN_MUZZLE],
        "clips": {
            "aim": {"seconds": AIM_SECONDS, "loop": True},
            "fire": {"seconds": FIRE_SECONDS, "loop": False},
        },
        "aim_pose": {
            "right_hand": [round(float(v), 4) for v in report["right_hand"]],
            "left_hand": [round(float(v), 4) for v in report["left_hand"]],
            "support": [round(float(v), 4) for v in report["support"]],
            "reach_right": round(report["reach_right"], 4),
            "reach_left": round(report["reach_left"], 4),
            "muzzle": [round(float(v), 4) for v in muzzle_hero],
            "barrel_dir": [round(float(v), 4) for v in barrel_dir],
            "barrel_pitch_deg": round(pitch, 2),
        },
        "recoil": {
            "muzzle_back_m": round(muzzle_dz, 4),
            "muzzle_up_m": round(muzzle_dy, 4),
        },
        "carry": {
            "barrel_before": [round(float(v), 3) for v in carry_before],
            "barrel_desired": [round(float(v), 3) for v in carry_desired],
            "barrel_after": [round(float(v), 3) for v in carry_check],
        },
    }
    RIG_JSON.write_text(json.dumps(rig, indent=2) + "\n")

    print(f"hand IK error {hand_err * 1000:.2f} mm · support error {left_err * 1000:.2f} mm "
          f"· reach {report['reach_right']:.2f}/{report['reach_left']:.2f}")
    print(f"muzzle {np.round(muzzle_hero, 3)} · barrel dir {np.round(barrel_dir, 3)} (pitch {pitch:+.2f} deg)")
    print(f"recoil: muzzle {muzzle_dz * 1000:+.1f} mm back, {muzzle_dy * 1000:+.1f} mm up "
          f"(rest z={rest_muzzle[2]:.3f})")
    print(f"attach rotation (xyzw) {np.round(attach, 4)}")
    print("recentered: " + ", ".join(f"{k} {v:.2f}" for k, v in recentered.items()))
    print(f"carry socket: barrel {np.round(carry_before, 2)} -> {np.round(carry_check, 2)} "
          f"(want {np.round(carry_desired, 2)})")
    print(f"hero.glb {HERO.stat().st_size / 1e6:.2f} MB")

    ok = (hand_err < 0.002 and left_err < 0.01 and pitch < 1.5
          and muzzle_dz < -0.015 and muzzle_dy > 0.002
          and float(np.linalg.norm(carry_check - carry_desired)) < 0.01)
    return 0 if ok else 1


if __name__ == "__main__":
    raise SystemExit(main())
