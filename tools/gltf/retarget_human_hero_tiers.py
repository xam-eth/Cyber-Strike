#!/usr/bin/env python3
"""Retarget Robot Common's animation set onto the five human hero tier rigs.

The human GLBs have independently generated skin weights on the copied 79-joint
Robot Common skeleton. This tool transfers idle/walk/run, weapon aim/fire/reload,
hit, and death motion, then authors explicit raise/lower-weapon transition clips.
The original human meshes and the Robot Common enemy template are never modified.

Usage:
  .venv/bin/python tools/gltf/retarget_human_hero_tiers.py
  .venv/bin/python tools/gltf/retarget_human_hero_tiers.py --check
"""
from __future__ import annotations

import hashlib
import json
import math
import sys
from pathlib import Path
from typing import Any

import numpy as np

HERE = Path(__file__).resolve().parent
ROOT = HERE.parents[1]
sys.path.insert(0, str(HERE))

import build_robot_enemy_clips as build_clips  # noqa: E402
import retarget_robot_enemy_variants as robot_retarget  # noqa: E402
import rig_enemy_models as rig_builder  # noqa: E402
import rig_human_hero_tiers as hero_rigging  # noqa: E402
from asset_identity import identity_for, validate_profile_identity  # noqa: E402
from rigmath import BinWriter, Skeleton, accessor_array, q_slerp, q_rotate, read_glb, write_glb  # noqa: E402

SOURCE_ROBOT = ROOT / "game/assets/enemies/enemy_robot_common.glb"
ANIMATION_NAMES = (
    "idle",
    "walk",
    "run",
    "raise_weapon",
    "aim",
    "aim_walk",
    "aim_run",
    "fire",
    "reload",
    "hit",
    "death",
    "lower_weapon",
)
LOOPING_CLIPS = {"idle", "walk", "run", "aim", "aim_walk", "aim_run"}
TRANSITION_SECONDS = {"raise_weapon": 0.8, "lower_weapon": 0.7}
CHECK_ONLY = "--check" in sys.argv
VARIANTS = tuple(
    {
        "asset_id": f"hero_human_tier_{tier}",
        "tier": tier,
        "source": ROOT / f"source-assets/characters/human_hero_tiers/hero_human_tier_{tier}_source.glb",
        "optimized": ROOT / f"tools/gltf/build/human_hero_tiers/hero_human_tier_{tier}.glb",
        "model": ROOT / f"game/assets/characters/human_hero_tiers/hero_human_tier_{tier}.glb",
        "rig": ROOT / f"game/assets/characters/human_hero_tiers/hero_human_tier_{tier}_rig.json",
    }
    for tier in range(1, 6)
)


def _sha256(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest()


def _map_source_pose(source: Skeleton, target: Skeleton, pose: tuple[dict, dict, dict]) -> tuple[dict, dict, dict]:
    """Map a full source pose to target node indices by the copied joint names."""
    mapped = (
        {index: np.asarray(value, dtype=np.float64).copy() for index, value in target.rest_r.items()},
        {index: np.asarray(value, dtype=np.float64).copy() for index, value in target.rest_t.items()},
        {index: np.asarray(value, dtype=np.float64).copy() for index, value in target.rest_s.items()},
    )
    for target_index in target.joints:
        name = target.nodes[target_index].get("name", f"node{target_index}")
        source_index = source.name.get(name)
        if source_index is None or source_index not in source.joints:
            raise RuntimeError(f"target joint {name!r} is missing from Robot Common")
        for table_index in range(3):
            mapped[table_index][target_index] = np.asarray(
                pose[table_index][source_index], dtype=np.float64
            ).copy()
    return mapped


def _transition_frames(
    target: Skeleton,
    start_pose: tuple[dict, dict, dict],
    end_pose: dict[str, dict[int, np.ndarray]],
    duration: float,
) -> tuple[np.ndarray, list[dict[str, dict[int, np.ndarray]]]]:
    frames_count = int(round(duration * build_clips.FPS)) + 1
    times = np.arange(frames_count, dtype=np.float64) / build_clips.FPS
    frames: list[dict[str, dict[int, np.ndarray]]] = []
    tables = {"rot": 0, "tra": 1, "sca": 2}
    for frame_index, time in enumerate(times):
        linear = float(time / duration) if duration > 0.0 else 1.0
        eased = linear * linear * (3.0 - 2.0 * linear)
        frame: dict[str, dict[int, np.ndarray]] = {key: {} for key in tables}
        for key, table_index in tables.items():
            for joint in target.joints:
                start = np.asarray(start_pose[table_index][joint], dtype=np.float64)
                end = np.asarray(end_pose[key][joint], dtype=np.float64)
                frame[key][joint] = (
                    q_slerp(start, end, eased)
                    if key == "rot"
                    else start * (1.0 - eased) + end * eased
                )
        frames.append(frame)
    return times, frames


def _keys_as_frames(keys: dict[str, list[dict[int, np.ndarray]]]) -> list[dict[str, dict[int, np.ndarray]]]:
    return [
        {path: keys[path][frame_index] for path in ("rot", "tra", "sca")}
        for frame_index in range(len(keys["rot"]))
    ]


def _pose_error(
    skeleton: Skeleton,
    clip_a: str,
    time_a: float,
    clip_b: str,
    time_b: float,
) -> dict[str, float]:
    pose_a = skeleton.local_pose(clip_a, time_a)
    pose_b = skeleton.local_pose(clip_b, time_b)
    max_rotation = 0.0
    max_translation = 0.0
    max_scale = 0.0
    for joint in skeleton.joints:
        qa = np.asarray(pose_a[0][joint], dtype=np.float64)
        qb = np.asarray(pose_b[0][joint], dtype=np.float64)
        dot = abs(float(np.dot(qa, qb)))
        max_rotation = max(max_rotation, 2.0 * math.acos(float(np.clip(dot, -1.0, 1.0))))
        max_translation = max(
            max_translation,
            float(np.linalg.norm(np.asarray(pose_a[1][joint]) - np.asarray(pose_b[1][joint]))),
        )
        max_scale = max(
            max_scale,
            float(np.linalg.norm(np.asarray(pose_a[2][joint]) - np.asarray(pose_b[2][joint]))),
        )
    return {
        "max_rotation_deg": round(math.degrees(max_rotation), 8),
        "max_translation_m": round(max_translation, 9),
        "max_scale_delta": round(max_scale, 9),
    }


def _transition_report(skeleton: Skeleton) -> dict[str, dict[str, float]]:
    raise_duration = skeleton.clip_duration("raise_weapon")
    lower_duration = skeleton.clip_duration("lower_weapon")
    return {
        "raise_starts_at_idle": _pose_error(skeleton, "raise_weapon", 0.0, "idle", 0.0),
        "raise_ends_at_aim": _pose_error(skeleton, "raise_weapon", raise_duration, "aim", 0.0),
        "lower_starts_at_aim": _pose_error(skeleton, "lower_weapon", 0.0, "aim", 0.0),
        "lower_ends_at_idle": _pose_error(skeleton, "lower_weapon", lower_duration, "idle", 0.0),
    }



def _validate_animation_tracks(js: dict, bin_: bytes, skeleton: Skeleton) -> None:
    joint_nodes = set(skeleton.joints)
    for animation in js.get("animations", []):
        name = str(animation.get("name", "unnamed"))
        channels = animation.get("channels", [])
        samplers = animation.get("samplers", [])
        if not channels:
            raise RuntimeError(f"{name}: animation has no target channels")
        seen_targets: set[tuple[int, str]] = set()
        for channel in channels:
            target = channel.get("target", {})
            node = target.get("node")
            path = str(target.get("path", ""))
            if node not in joint_nodes or path not in {"rotation", "translation", "scale"}:
                raise RuntimeError(f"{name}: channel targets a non-joint or unsupported path")
            if path == "scale":
                raise RuntimeError(f"{name}: bone-scale animation channel remains")
            if (node, path) in seen_targets:
                raise RuntimeError(f"{name}: duplicate channel for joint {node}/{path}")
            seen_targets.add((node, path))
            sampler_index = int(channel.get("sampler", -1))
            if sampler_index < 0 or sampler_index >= len(samplers):
                raise RuntimeError(f"{name}: channel has an invalid sampler index")
            sampler = samplers[sampler_index]
            times = accessor_array(js, bin_, int(sampler["input"])).reshape(-1)
            values = accessor_array(js, bin_, int(sampler["output"]))
            if not np.isfinite(times).all() or not np.isfinite(values).all() or times.size == 0:
                raise RuntimeError(f"{name}: sampler contains empty or non-finite data")
            if len(times) > 1 and np.any(np.diff(times) <= 0.0):
                raise RuntimeError(f"{name}: sampler key times are not strictly increasing")
            if sampler.get("interpolation", "LINEAR") != "LINEAR":
                raise RuntimeError(f"{name}: unexpected interpolation mode")
            if values.shape[0] != times.shape[0]:
                raise RuntimeError(f"{name}: sampler input/output key counts differ")


def _validate_transitions(report: dict[str, dict[str, float]]) -> None:
    for boundary, error in report.items():
        if (
            error["max_rotation_deg"] > 0.05
            or error["max_translation_m"] > 0.0001
            or error["max_scale_delta"] > 0.0001
        ):
            raise RuntimeError(f"weapon transition discontinuity at {boundary}: {error}")


def _build_variant(variant: dict[str, Any], source: Skeleton) -> dict[str, Any]:
    if not variant["model"].is_file() or not variant["rig"].is_file():
        raise RuntimeError("rigged model/profile missing; run rig_human_hero_tiers.py first")
    js, bin_ = read_glb(variant["model"])
    if js.get("animations"):
        raise RuntimeError("rigged target already has clips; rebuild from prepare/rig steps first")
    target = Skeleton(js, bin_)
    source_names = [source.nodes[index].get("name") for index in source.joints]
    target_names = [target.nodes[index].get("name") for index in target.joints]
    if target_names != source_names:
        raise RuntimeError(
            f"T{variant['tier']}: target joint order does not exactly match Robot Common"
        )
    if len(target.joints) != 79:
        raise RuntimeError(f"T{variant['tier']}: expected 79 joints; got {len(target.joints)}")
    for name in source_names:
        source_index = source.name[name]
        target_index = target.name[name]
        source_parent = source.parent.get(source_index)
        target_parent = target.parent.get(target_index)
        source_parent_name = source.nodes[source_parent].get("name") if source_parent is not None else None
        target_parent_name = target.nodes[target_parent].get("name") if target_parent is not None else None
        if source_parent_name != target_parent_name:
            raise RuntimeError(f"T{variant['tier']}: copied hierarchy differs at bone {name!r}")

    source_height = robot_retarget._mesh_height(source.js, source.bin)
    target_height = robot_retarget._mesh_height(js, bin_)
    if not (0.95 <= source_height <= 1.05 and 0.95 <= target_height <= 1.05):
        raise RuntimeError(
            f"T{variant['tier']}: expected 1 m units, Common={source_height:.4f}, "
            f"human={target_height:.4f}"
        )
    unit_ratio = target_height / source_height
    target_idle_local = _map_source_pose(source, target, source.local_pose("idle", 0.0))

    # The same calibrated hand/weapon socket recipe is used on the copied rig.
    base_right_hand = robot_retarget.BASE_RIGHT_HAND.copy() * unit_ratio
    base_right_pole = robot_retarget.BASE_RIGHT_POLE.copy() * unit_ratio
    base_left_pole = robot_retarget.BASE_LEFT_POLE.copy() * unit_ratio
    model_weapon_scale = robot_retarget.BASE_GUN_SCALE * unit_ratio
    previous_settings = (
        build_clips.RIGHT_HAND,
        build_clips.RIGHT_POLE,
        build_clips.LEFT_POLE,
        build_clips.GUN_SCALE,
    )
    build_clips.RIGHT_HAND = base_right_hand
    build_clips.RIGHT_POLE = base_right_pole
    build_clips.LEFT_POLE = base_left_pole
    build_clips.GUN_SCALE = model_weapon_scale
    try:
        attach = build_clips.build_attach(target, target_idle_local)
        aim_keys, aim_report, aim_base = build_clips.build_aim(
            target, attach, base=target_idle_local
        )
        fire_keys, muzzle_back, rest_muzzle, muzzle_up = build_clips.build_fire(
            target, aim_base, attach
        )
        carry = build_clips.carry_socket_rotation(target, target_idle_local, attach)

        aim_local = tuple(
            {index: np.asarray(value, dtype=np.float64).copy() for index, value in table.items()}
            for table in aim_base
        )
        for table_index, path in enumerate(("rot", "tra", "sca")):
            for joint in target.joints:
                aim_local[table_index][joint] = np.asarray(
                    aim_keys[path][0][joint], dtype=np.float64
                ).copy()
        aim_frame = {
            path: {joint: np.asarray(aim_keys[path][0][joint]).copy() for joint in target.joints}
            for path in ("rot", "tra", "sca")
        }

        writer = BinWriter(js, bin_)
        clip_reports: list[dict[str, Any]] = []

        idle_times, idle_frames = robot_retarget._retarget_clip(
            source, target, "idle", "idle", target_idle_local, unit_ratio
        )
        clip_reports.append(robot_retarget._write_clip(target, writer, "idle", idle_times, idle_frames))

        for clip in ("walk", "run"):
            times, frames = robot_retarget._retarget_clip(
                source, target, clip, "idle", target_idle_local, unit_ratio
            )
            clip_reports.append(robot_retarget._write_clip(target, writer, clip, times, frames))

        raise_times, raise_frames = _transition_frames(
            target, target_idle_local, aim_frame, TRANSITION_SECONDS["raise_weapon"]
        )
        clip_reports.append(
            robot_retarget._write_clip(target, writer, "raise_weapon", raise_times, raise_frames)
        )

        aim_times = np.arange(len(aim_keys["rot"]), dtype=np.float64) / build_clips.FPS
        clip_reports.append(
            robot_retarget._write_clip(
                target, writer, "aim", aim_times, _keys_as_frames(aim_keys)
            )
        )

        for clip in ("aim_walk", "aim_run"):
            movement_clip = "walk" if clip == "aim_walk" else "run"
            times, frames = robot_retarget._mixed_aim_locomotion(
                source,
                target,
                movement_clip,
                clip,
                target_idle_local,
                aim_frame,
                unit_ratio,
            )
            clip_reports.append(robot_retarget._write_clip(target, writer, clip, times, frames))

        clip_reports.append(
            robot_retarget._write_clip(
                target,
                writer,
                "fire",
                np.arange(len(fire_keys["rot"]), dtype=np.float64) / build_clips.FPS,
                _keys_as_frames(fire_keys),
            )
        )

        for clip in ("reload", "hit"):
            times, frames = robot_retarget._retarget_clip(
                source, target, clip, "aim", aim_local, unit_ratio
            )
            clip_reports.append(robot_retarget._write_clip(target, writer, clip, times, frames))

        times, frames = robot_retarget._retarget_clip(
            source, target, "death", "idle", target_idle_local, unit_ratio
        )
        clip_reports.append(robot_retarget._write_clip(target, writer, "death", times, frames))

        lower_times, lower_frames = _transition_frames(
            target, aim_local, _as_joint_pose(target_idle_local, target), TRANSITION_SECONDS["lower_weapon"]
        )
        clip_reports.append(
            robot_retarget._write_clip(target, writer, "lower_weapon", lower_times, lower_frames)
        )

        by_name = {animation.get("name", ""): animation for animation in js["animations"]}
        if set(by_name) != set(ANIMATION_NAMES):
            raise RuntimeError(f"T{variant['tier']}: clip build mismatch: {sorted(by_name)}")
        js["animations"] = [by_name[name] for name in ANIMATION_NAMES]
        write_glb(variant["model"], js, writer.bin)
        robot_retarget.strip_file(variant["model"])
    finally:
        (
            build_clips.RIGHT_HAND,
            build_clips.RIGHT_POLE,
            build_clips.LEFT_POLE,
            build_clips.GUN_SCALE,
        ) = previous_settings

    # Analytic checks ensure hands and the weapon socket solve on the copied rig.
    aim_global = target.fk(aim_keys["rot"][0], aim_keys["tra"][0], aim_keys["sca"][0])
    hand_error = float(np.linalg.norm(aim_global[1][target.name["R_Hand"]] - base_right_hand))
    support_error = float(
        np.linalg.norm(aim_global[1][target.name["L_Hand"]] - aim_report["support"])
    )
    old_gun_scale = build_clips.GUN_SCALE
    build_clips.GUN_SCALE = model_weapon_scale
    try:
        to_hero, barrel_q, _hand_position = build_clips.gun_transform(
            aim_keys["rot"][0], aim_keys["tra"][0], aim_keys["sca"][0], target, attach
        )
        muzzle = to_hero(build_clips.GUN_MUZZLE)
    finally:
        build_clips.GUN_SCALE = old_gun_scale
    barrel_direction = q_rotate(barrel_q, np.array([0.0, 0.0, -1.0]))
    barrel_pitch = math.degrees(math.asin(float(np.clip(barrel_direction[1], -1.0, 1.0))))
    carry_error = float(np.linalg.norm(carry[2] - carry[3]))
    if hand_error >= 0.002 or support_error >= 0.01 or abs(barrel_pitch) >= 1.5 or carry_error >= 0.01:
        raise RuntimeError(
            f"T{variant['tier']}: weapon pose check failed: hand={hand_error:.4f}, "
            f"support={support_error:.4f}, barrel={barrel_pitch:.2f} deg, carry={carry_error:.4f}"
        )

    final_js, final_bin = read_glb(variant["model"])
    final_skeleton = Skeleton(final_js, final_bin)
    transition_checks = _transition_report(final_skeleton)
    _validate_transitions(transition_checks)
    clip_durations = {
        clip: round(final_skeleton.clip_duration(clip), 4) for clip in ANIMATION_NAMES
    }
    for clip, duration in clip_durations.items():
        if duration <= 0.0:
            raise RuntimeError(f"T{variant['tier']}: generated clip {clip!r} has no duration")

    profile = json.loads(variant["rig"].read_text(encoding="utf-8"))
    source_names = [source.nodes[index].get("name") for index in source.joints]
    target_names = [final_skeleton.nodes[index].get("name") for index in final_skeleton.joints]
    profile.update(
        {
            "note": "Generated by tools/gltf/retarget_human_hero_tiers.py; do not edit by hand.",
            "model": variant["model"].name,
            "asset_identity": identity_for(variant["asset_id"]),
            "source_robot_common_model": SOURCE_ROBOT.name,
            "source_robot_common_sha256": _sha256(SOURCE_ROBOT),
            "source_variant_sha256": _sha256(variant["source"]),
            "retarget_method": (
                "Robot Common's idle/walk/run/aim/fire/reload/hit/death motion is transferred by named "
                "joint and common-pose deltas onto the copied 79-joint rig. Root/Hip translation is "
                "transferred only when the source joint moves in that clip. The human mesh keeps its own "
                "per-tier vertex weights. Weapon raise/lower transitions are generated from idle and aim."
            ),
            "units": "source and target meshes use one-metre model units",
            "model_height_units": round(target_height, 6),
            "skeleton": "Armature",
            "hand_bone": "R_Hand",
            "weapon_socket": {
                "aim_rotation_xyzw": [round(float(value), 6) for value in attach],
                "carry_rotation_xyzw": [round(float(value), 6) for value in carry[0]],
                "offset": [0.0, 0.018, 0.0],
                "scale_model_units": round(float(model_weapon_scale), 6),
            },
            "weapon_muzzle_local": [round(float(value), 5) for value in build_clips.GUN_MUZZLE],
            "clips": {
                clip: {
                    "seconds": clip_durations[clip],
                    "loop": clip in LOOPING_CLIPS,
                    "description": _clip_description(clip),
                }
                for clip in ANIMATION_NAMES
            },
            "retarget": {
                "source_joint_count": len(source_names),
                "target_joint_count": len(target_names),
                "mapped_joint_count": len(set(source_names) & set(target_names)),
                "unmapped_source_joints": sorted(set(source_names) - set(target_names)),
                "target_only_joints": sorted(set(target_names) - set(source_names)),
                "translation_bones": sorted(robot_retarget.TRANSLATION_JOINTS),
            },
            "aim_pose": {
                "right_hand": [round(float(value), 4) for value in aim_report["right_hand"]],
                "left_hand": [round(float(value), 4) for value in aim_report["left_hand"]],
                "support": [round(float(value), 4) for value in aim_report["support"]],
                "reach_right": round(float(aim_report["reach_right"]), 4),
                "reach_left": round(float(aim_report["reach_left"]), 4),
                "hand_ik_error_m": round(hand_error, 6),
                "support_ik_error_m": round(support_error, 6),
                "muzzle": [round(float(value), 4) for value in muzzle],
                "barrel_dir": [round(float(value), 4) for value in barrel_direction],
                "barrel_pitch_deg": round(barrel_pitch, 3),
            },
            "recoil": {
                "muzzle_back_m": round(float(muzzle_back), 4),
                "muzzle_up_m": round(float(muzzle_up), 4),
            },
            "carry": {
                "barrel_before": [round(float(value), 3) for value in carry[1]],
                "barrel_desired": [round(float(value), 3) for value in carry[2]],
                "barrel_after": [round(float(value), 3) for value in carry[3]],
                "socket_error": round(carry_error, 6),
            },
            "weapon_transition_checks": transition_checks,
            "animation_build_reports": clip_reports,
        }
    )
    variant["rig"].write_text(json.dumps(profile, indent=2) + "\n", encoding="utf-8")
    return profile


def _as_joint_pose(
    pose: tuple[dict, dict, dict], target: Skeleton
) -> dict[str, dict[int, np.ndarray]]:
    return {
        path: {joint: np.asarray(pose[table][joint]).copy() for joint in target.joints}
        for table, path in enumerate(("rot", "tra", "sca"))
    }


def _clip_description(clip: str) -> str:
    return {
        "idle": "Breathing idle loop.",
        "walk": "In-place forward walking cycle.",
        "run": "In-place forward running cycle.",
        "raise_weapon": "One-shot transition from idle to the two-handed ready/aim pose.",
        "aim": "Two-handed weapon-ready pose with subtle breathing.",
        "aim_walk": "Walking cycle blended with the upper-body aim pose.",
        "aim_run": "Running cycle blended with the upper-body aim pose.",
        "fire": "Aim pose with a short weapon recoil impulse.",
        "reload": "Reload motion retargeted from Robot Common.",
        "hit": "Hit reaction retargeted from Robot Common.",
        "death": "Death/fall motion retargeted from Robot Common.",
        "lower_weapon": "One-shot transition from the two-handed aim pose back to idle.",
    }[clip]


def _check_variant(
    variant: dict[str, Any],
    source: Skeleton,
    template_js: dict,
    template_skeleton: Skeleton,
) -> dict[str, Any]:
    if not variant["model"].is_file() or not variant["rig"].is_file():
        raise RuntimeError("runtime GLB or rig profile is missing")
    js, bin_ = read_glb(variant["model"])
    skeleton = Skeleton(js, bin_)
    _validate_animation_tracks(js, bin_, skeleton)
    if tuple(skeleton.animations) != ANIMATION_NAMES:
        raise RuntimeError(
            f"clip set/order mismatch: {tuple(skeleton.animations)} != {ANIMATION_NAMES}"
        )
    for clip in ANIMATION_NAMES:
        if skeleton.clip_duration(clip) <= 0.0:
            raise RuntimeError(f"clip {clip!r} has no duration")
    robot_retarget._validate_aim_locomotion(skeleton, f"T{variant['tier']}")
    target_joint_names = robot_retarget._joint_names(skeleton)
    for clip in ("walk", "run", "death"):
        expected_translation = robot_retarget._dynamic_translation_joints(source, clip) & target_joint_names
        actual_translation = robot_retarget._dynamic_translation_joints(skeleton, clip)
        if actual_translation != expected_translation:
            raise RuntimeError(
                f"{clip} dynamic root/hip tracks {sorted(actual_translation)} "
                f"!= Robot Common {sorted(expected_translation)}"
            )
    skin_checks = hero_rigging._validate_variant(variant, template_js, template_skeleton)
    profile = json.loads(variant["rig"].read_text(encoding="utf-8"))
    validate_profile_identity(profile, variant["asset_id"])
    if profile.get("source_robot_common_sha256") != _sha256(SOURCE_ROBOT):
        raise RuntimeError("rig profile is stale for the current Robot Common clips/template")
    if profile.get("source_variant_sha256") != _sha256(variant["source"]):
        raise RuntimeError("rig profile is stale for the preserved human source")
    if profile.get("model") != variant["model"].name:
        raise RuntimeError("rig profile model name does not match this tier")
    if profile.get("upgrade_track_id") != "human_operative" or int(profile.get("upgrade_tier", 0)) != variant["tier"]:
        raise RuntimeError("rig profile hero track/tier does not match the selected model")
    clip_profiles = profile.get("clips", {})
    if set(clip_profiles) != set(ANIMATION_NAMES):
        raise RuntimeError("rig profile does not document exactly the required animation clips")
    for clip in ANIMATION_NAMES:
        if abs(float(clip_profiles[clip].get("seconds", 0.0)) - skeleton.clip_duration(clip)) > 0.0002:
            raise RuntimeError(f"rig profile has stale duration for {clip!r}")
    transitions = _transition_report(skeleton)
    _validate_transitions(transitions)
    if profile.get("weapon_transition_checks") != transitions:
        raise RuntimeError("stored weapon transition continuity checks are stale")
    aim = profile.get("aim_pose", {})
    if float(aim.get("hand_ik_error_m", math.inf)) >= 0.002:
        raise RuntimeError("right-hand weapon grip IK is outside tolerance")
    if float(aim.get("support_ik_error_m", math.inf)) >= 0.01:
        raise RuntimeError("left-hand weapon support IK is outside tolerance")
    if abs(float(aim.get("barrel_pitch_deg", math.inf))) >= 1.5:
        raise RuntimeError("weapon aim socket is not level")
    if float(profile.get("carry", {}).get("socket_error", math.inf)) >= 0.01:
        raise RuntimeError("carry socket check failed")
    if skin_checks["joint_count"] != 79:
        raise RuntimeError("skin verification did not retain all 79 shared joints")
    return {"skin": skin_checks, "transitions": transitions, "clips": len(skeleton.animations)}


def main() -> int:
    if not SOURCE_ROBOT.is_file():
        raise RuntimeError(f"Robot Common animation source is missing: {SOURCE_ROBOT}")
    source = Skeleton(*read_glb(SOURCE_ROBOT))
    template_js, _template_bin, template_skeleton = rig_builder._load_template()
    missing = sorted(set(ANIMATION_NAMES) - {"raise_weapon", "lower_weapon"} - set(source.animations))
    if missing:
        raise RuntimeError(f"Robot Common is missing source clips required for retargeting: {missing}")
    if len(source.joints) != 79:
        raise RuntimeError(f"Robot Common rig expected 79 joints, found {len(source.joints)}")

    errors: list[str] = []
    for variant in VARIANTS:
        try:
            if CHECK_ONLY:
                report = _check_variant(variant, source, template_js, template_skeleton)
            else:
                _build_variant(variant, source)
                report = _check_variant(variant, source, template_js, template_skeleton)
            print(
                f"T{variant['tier']}: {report['clips']} clips · "
                f"{report['skin']['joint_count']} joints · "
                f"{report['skin']['vertex_count']:,} independently weighted vertices · "
                "raise/lower transitions and weapon IK pass"
            )
        except (OSError, ValueError, RuntimeError, KeyError) as error:
            errors.append(f"T{variant['tier']}: {error}")
    for error in errors:
        print(f"ERROR: {error}", file=sys.stderr)
    return 1 if errors else 0


if __name__ == "__main__":
    raise SystemExit(main())
