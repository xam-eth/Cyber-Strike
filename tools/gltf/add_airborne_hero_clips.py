#!/usr/bin/env python3
"""Author ``jump`` / ``fall`` / ``land`` clips into the rigged hero GLBs.

The hero ships twelve authored clips (idle/walk/run/raise_weapon/aim/aim_walk/
aim_run/fire/reload/hit/death/lower_weapon) but the gameplay controller has a
real jump (``jump_velocity``) with no airborne animation -- the legs keep
playing walk/run mid-air. This tool closes that gap WITHOUT new mocap and
WITHOUT re-running the retarget pipeline (whose UAL source GLB is not in the
repository):

* the leg-swing delta is measured from the hero's own ``walk`` clip (the phase
  where each boot is furthest forward / back versus the idle pose), so the
  rotation axes are guaranteed correct for this skeleton,
* the spine lean is measured from ``run``,
* ``jump``  (0.50 s, one-shot): both legs tucked forward on the measured
  forward-swing delta, slight back lean, settling toward the fall pose,
* ``fall``  (0.80 s, loop): legs half-tucked with a small drift, forward lean,
* ``land``  (0.45 s, one-shot): fall pose -> deeper crouch -> idle.

The output clips are ordinary glTF animations appended to the same GLB, so the
Godot import, CharacterVisual clip wiring and the smoke tests treat them like
every other clip. The script is idempotent: a GLB that already has the three
clips is left untouched.

Usage:
    python3 tools/gltf/add_airborne_hero_clips.py [glb ...]
"""
from __future__ import annotations

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
    read_glb,
    write_glb,
)

FPS = 30.0
LEG_CHAINS = {
    "L": ("L_Thigh", "L_Calf", "L_Foot"),
    "R": ("R_Thigh", "R_Calf", "R_Foot"),
}
SPINE_BONES = ("Waist", "Spine01", "Spine02")
FOOT_NODE = {"L": "L_Foot", "R": "R_Foot"}
CLIP_NAMES = ("jump", "fall", "land")


def _scale_quat(q: np.ndarray, factor: float) -> np.ndarray:
    """Scale a rotation's angle by ``factor`` (identity stays identity)."""
    q = q_normalize(np.asarray(q, dtype=np.float64))
    w = float(np.clip(q[3], -1.0, 1.0))
    angle = 2.0 * float(np.arccos(w))
    if angle < 1e-9 or abs(angle - 2.0 * np.pi) < 1e-9:
        return q_normalize(q.copy())
    axis = q[:3] / np.sin(angle / 2.0)
    return q_about_axis(axis, angle * factor)


def _compose(base: dict, deltas: dict, factor: float) -> dict:
    """Apply measured rotation deltas (scaled) on top of a base pose."""
    out = dict(base)
    for node, delta in deltas.items():
        out[node] = q_normalize(q_mul(_scale_quat(delta, factor), base[node]))
    return out


def _measure(sk: Skeleton) -> tuple[dict, dict, dict]:
    """Return (leg forward deltas, leg back deltas, spine-lean delta)."""
    idle_rot, _idle_tra, _idle_sca = sk.local_pose("idle", 0.0)
    walk_dur = sk.clip_duration("walk")
    run_dur = sk.clip_duration("run")
    hip = sk.bone("Hip")

    # --- leg swing axes measured from the walk cycle ----------------------
    phases = np.linspace(0.0, walk_dur, 24, endpoint=False)
    foot_rel_z: dict[str, list[float]] = {"L": [], "R": []}
    walk_rots: dict[str, list[dict]] = {"L": [], "R": []}
    for t in phases:
        grot, gpos = sk.pose("walk", float(t))
        for side, foot_name in FOOT_NODE.items():
            foot = sk.bone(foot_name)
            foot_rel_z[side].append(float(gpos[foot][2] - gpos[hip][2]))
            rot, _tra, _sca = sk.sample("walk", float(t))
            walk_rots[side].append(rot)

    fwd_delta: dict[int, np.ndarray] = {}
    back_delta: dict[int, np.ndarray] = {}
    for side, chain in LEG_CHAINS.items():
        zs = foot_rel_z[side]
        fwd_i = int(np.argmin(zs))  # most negative z = furthest forward (-Z fwd)
        back_i = int(np.argmax(zs))
        for bone in chain:
            node = sk.bone(bone)
            rot_f = walk_rots[side][fwd_i].get(node, idle_rot[node])
            rot_b = walk_rots[side][back_i].get(node, idle_rot[node])
            fwd_delta[node] = q_mul(rot_f, q_conj(idle_rot[node]))
            back_delta[node] = q_mul(rot_b, q_conj(idle_rot[node]))

    # --- spine lean from run (forward lean) ------------------------------
    run_rot, _t, _s = sk.sample("run", run_dur * 0.25)
    spine_delta: dict[int, np.ndarray] = {}
    for bone in SPINE_BONES:
        node = sk.bone(bone)
        spine_delta[node] = q_mul(run_rot.get(node, idle_rot[node]), q_conj(idle_rot[node]))

    return fwd_delta, back_delta, spine_delta


def _build_keys(sk: Skeleton, fwd_delta, back_delta, spine_delta):
    """Keyframe pose dicts for jump / fall / land (all bones, per key)."""
    idle_rot, idle_tra, idle_sca = sk.local_pose("idle", 0.0)
    fall_pose = _compose(_compose(idle_rot, fwd_delta, 0.52), spine_delta, 0.85)
    fall_pose_b = _compose(_compose(idle_rot, fwd_delta, 0.64), spine_delta, 0.9)
    crouch_pose = _compose(_compose(idle_rot, fwd_delta, 1.35), spine_delta, 1.25)
    tuck_pose = _compose(_compose(idle_rot, fwd_delta, 1.3), spine_delta, -0.5)
    tuck_hold = _compose(_compose(idle_rot, fwd_delta, 1.12), spine_delta, -0.35)

    def pack(poses: list[dict], times: list[float]) -> dict:
        return {
            "rot": poses,
            "tra": [dict(idle_tra) for _ in poses],
            "sca": [dict(sk.rest_s) for _ in poses],
            "times": times,
        }

    jump = pack([idle_rot, tuck_pose, tuck_hold, fall_pose], [0.0, 0.12, 0.30, 0.50])
    fall = pack([fall_pose, fall_pose_b, fall_pose], [0.0, 0.40, 0.80])
    land = pack([fall_pose, crouch_pose, _compose(idle_rot, fwd_delta, 0.45), idle_rot],
                [0.0, 0.12, 0.28, 0.45])
    return {"jump": jump, "fall": fall, "land": land}


def _changed_bones(sk: Skeleton, keys: dict) -> list[str]:
    rots = keys["rot"]
    changed = []
    for node in sk.joints:
        base = rots[0][node]
        for pose in rots[1:]:
            dot = abs(float(np.dot(pose[node], base)))
            if dot < 0.99995:
                changed.append(sk.nodes[node].get("name", f"node{node}"))
                break
    return changed


def _add_clip(sk: Skeleton, js: dict, writer: BinWriter, name: str, keys: dict) -> None:
    import build_robot_enemy_clips as build_clips

    changed = _changed_bones(sk, keys)
    build_clips.add_clip(sk, js, writer, name, keys, changed, times=keys["times"])


def _validate(js: dict, sk: Skeleton) -> None:
    names = {a.get("name") for a in js.get("animations", [])}
    for clip in CLIP_NAMES:
        if clip not in names:
            raise RuntimeError(f"missing clip after write: {clip}")
    # jump starts at idle, land ends at idle, fall loops on itself
    idle_rot, _t, _s = sk.local_pose("idle", 0.0)
    j0 = sk.sample("jump", 0.0)[0]
    worst = 0.0
    for node, q in j0.items():
        worst = max(worst, 2.0 * float(np.arccos(min(1.0, abs(float(np.dot(q, idle_rot[node])))))))
    if worst > 0.02:
        raise RuntimeError(f"jump does not start at the idle pose (worst {worst:.4f} rad)")
    fall_dur = sk.clip_duration("fall")
    fa = sk.sample("fall", 0.0)[0]
    fb = sk.sample("fall", fall_dur)[0]
    for node, q in fa.items():
        d = 2.0 * float(np.arccos(min(1.0, abs(float(np.dot(q, fb[node]))))))
        if d > 0.02:
            raise RuntimeError(f"fall clip does not loop (node {node} drifts {d:.4f} rad)")
    for clip in CLIP_NAMES:
        for sampler in sk.animations[clip]["samplers"]:
            if sampler.get("interpolation") != "LINEAR":
                raise RuntimeError(f"{clip}: non-linear sampler")
    print(f"    validated: jump/fall/land present, jump->idle match, fall loops")


def process(path: Path) -> bool:
    js, bin_ = read_glb(path)
    sk = Skeleton(js, bin_)
    existing = {a.get("name") for a in js.get("animations", [])}
    if all(name in existing for name in CLIP_NAMES):
        print(f"  {path.name}: already has {', '.join(CLIP_NAMES)} -- skipped")
        return False
    if any(name in existing for name in CLIP_NAMES):
        raise RuntimeError(f"{path.name}: partial airborne clip set; refusing to guess")
    for needed in ("idle", "walk", "run"):
        if needed not in existing:
            raise RuntimeError(f"{path.name}: missing base clip {needed}")

    fwd_delta, back_delta, spine_delta = _measure(sk)
    keys_all = _build_keys(sk, fwd_delta, back_delta, spine_delta)
    writer = BinWriter(js, bin_)
    for name in CLIP_NAMES:
        _add_clip(sk, js, writer, name, keys_all[name])
        print(f"    wrote clip '{name}' ({len(keys_all[name]['times'])} keys)")

    bin_ = bytes(writer.bin)
    _validate(js, Skeleton(js, bin_))
    write_glb(path, js, bin_)
    print(f"  {path.name}: saved with {len(js['animations'])} clips")
    return True


def main() -> int:
    root = Path(__file__).resolve().parents[2]
    default = [
        root / "game/assets/characters/human_hero_tiers/hero_human_tier_1.glb",
    ]
    kestrel = root / "game/assets/characters/human_hero_tiers/kestrel_hero.glb"
    if kestrel.exists():
        default.append(kestrel)
    for extra in root.glob("game/assets/**/kestrel_hero.glb"):
        if extra not in default:
            default.append(extra)
    targets = [Path(a) for a in sys.argv[1:]] or default
    wrote = 0
    for target in targets:
        print(f"airborne clips -> {target}")
        if process(target):
            wrote += 1
    print(f"done: {wrote} file(s) updated")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
