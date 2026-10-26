#!/usr/bin/env python3
"""Retarget Robot Common combat clips onto the Rare and Epic robot enemy rigs.

The source GLBs have different rest transforms, so copying Robot Common animation
channels is not retargeting. This baker transfers each bone's *global motion
relative to its reference pose* onto the target rig's own idle/aim pose, derives
new target-local rotations through the target hierarchy, and preserves each
target's bone lengths. Root/Hip translation deltas are scaled by the measured
model-height ratio only when that joint actually moves in the source clip; a
static Hip inherits BoneRoot motion rather than counteracting it. Missing
``neutral_bone`` on Rare is intentionally left at its target rest pose; every
other source joint must map by name and parent.

Target-specific aim/fire and weapon socket transforms are solved with the same
analytic two-bone IK used for Common. Aim-walk/run combine that target-specific
aim pose with retargeted target locomotion. The script writes new GLTF animation
channels into each optimized GLB; the two source GLBs remain unchanged.

This is a deterministic data-space retarget and geometric IK check, not a
human visual review. Run the Godot smoke suite and inspect the exported models
in an editor/browser before calling the deformation visually verified.

Usage:
  .venv/bin/python tools/gltf/retarget_robot_enemy_variants.py
  .venv/bin/python tools/gltf/retarget_robot_enemy_variants.py --check
"""
from __future__ import annotations

import hashlib
import json
import math
import sys
from pathlib import Path

import numpy as np

HERE = Path(__file__).resolve().parent
ROOT = HERE.parents[1]
sys.path.insert(0, str(HERE))

import build_robot_enemy_clips as build_clips  # noqa: E402
from asset_identity import identity_for, validate_profile_identity  # noqa: E402
from rigmath import (  # noqa: E402
    BinWriter,
    Skeleton,
    accessor_array,
    q_conj,
    q_mul,
    q_normalize,
    q_rotate,
    read_glb,
    write_glb,
)
from strip_static_scale_tracks import strip_file  # noqa: E402

SOURCE_ROBOT = ROOT / "game/assets/enemies/enemy_robot_common.glb"
REQUIRED_CLIPS = ("idle", "walk", "run", "aim", "aim_walk", "aim_run", "fire", "reload", "hit", "death")
OPTIONAL_MISSING_JOINTS = {"neutral_bone"}
TRANSLATION_JOINTS = {"BoneRoot", "Hip"}

VARIANTS = (
    {
        "enemy_id": "enemy_robot_tier_2_rare",
        "display_name": "Rare Robot Enemy",
        "source": ROOT / "source-assets/enemies/enemy_robot_tier_2_rare_source.glb",
        "model": ROOT / "game/assets/enemies/enemy_robot_tier_2_rare.glb",
        "rig": ROOT / "game/assets/enemies/enemy_robot_tier_2_rare_rig.json",
    },
    {
        "enemy_id": "enemy_robot_tier_3_epic",
        "display_name": "Epic Robot Enemy",
        "source": ROOT / "source-assets/enemies/enemy_robot_tier_3_epic_source.glb",
        "model": ROOT / "game/assets/enemies/enemy_robot_tier_3_epic.glb",
        "rig": ROOT / "game/assets/enemies/enemy_robot_tier_3_epic_rig.json",
    },
)

CHECK_ONLY = "--check" in sys.argv

# build_robot_enemy_clips.py is the canonical weapon/IK recipe. Its target points and gun
# size are authored for a 1 m tall robot; the inputs are temporarily scaled to
# the target model's measured height and restored after each variant.
BASE_RIGHT_HAND = build_clips.RIGHT_HAND.copy()
BASE_RIGHT_POLE = build_clips.RIGHT_POLE.copy()
BASE_LEFT_POLE = build_clips.LEFT_POLE.copy()
BASE_GUN_SCALE = float(build_clips.GUN_SCALE)


def _sha256(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest()


def _joint_names(skeleton: Skeleton) -> set[str]:
    return {skeleton.nodes[index].get("name", f"node{index}") for index in skeleton.joints}


def _mesh_height(js: dict, bin_: bytes) -> float:
    points = []
    for mesh in js.get("meshes", []):
        for primitive in mesh.get("primitives", []):
            accessor = primitive.get("attributes", {}).get("POSITION")
            if accessor is not None:
                points.append(accessor_array(js, bin_, accessor))
    if not points:
        raise RuntimeError("GLB has no POSITION attributes")
    positions = np.concatenate(points, axis=0)
    return float(positions[:, 1].max() - positions[:, 1].min())


def _animation_times(skeleton: Skeleton, clip: str) -> tuple[np.ndarray, float]:
    animation = skeleton.animations.get(clip)
    if animation is None:
        raise RuntimeError(f"missing source clip {clip!r}")
    chunks = []
    for sampler in animation.get("samplers", []):
        values = accessor_array(skeleton.js, skeleton.bin, sampler["input"]).reshape(-1)
        if values.size:
            chunks.append(values)
    if not chunks:
        return np.array([0.0], dtype=np.float64), 0.0
    times = np.unique(np.concatenate(chunks).astype(np.float64))
    return times, float(times[0])


def _upper_body(name: str) -> bool:
    """The authored aim-locomotion mask from the robot rig upper-body mask."""
    return name in {"Hip", "Waist", "Spine01", "Spine02"} or name.startswith(
        (
            "L_Upperarm", "L_Forearm", "L_Elbow", "L_Hand", "L_Clavicle",
            "L_Pinky", "L_Ring", "L_Mid", "L_Index", "L_Thumb",
            "R_Upperarm", "R_Forearm", "R_Elbow", "R_Hand", "R_Clavicle",
            "R_Pinky", "R_Ring", "R_Mid", "R_Index", "R_Thumb",
            "Neck", "Head", "Facial", "L_Eye", "R_Eye",
        )
    )


def _mapped_source_index(source: Skeleton, target: Skeleton, target_index: int) -> int | None:
    name = target.nodes[target_index].get("name", f"node{target_index}")
    source_index = source.name.get(name)
    if source_index is None or source_index not in source.joints:
        return None
    return source_index


def _retarget_pose(
    source: Skeleton,
    target: Skeleton,
    source_local: tuple[dict, dict, dict],
    source_global: tuple[dict, dict],
    source_base_local: tuple[dict, dict, dict],
    source_base_global: tuple[dict, dict],
    target_base_local: tuple[dict, dict, dict],
    target_base_global: tuple[dict, dict],
    unit_ratio: float,
    dynamic_translation_joints: set[str],
) -> dict[str, dict[int, np.ndarray]]:
    """Apply global source deltas to a target pose without changing bone lengths."""
    src_pose_rot, src_pose_tra, src_pose_scale = source_local
    src_base_rot, src_base_tra, src_base_scale = source_base_local
    target_base_rot, target_base_tra, target_base_scale = target_base_local
    src_pose_global_rot, src_pose_global_pos = source_global
    src_base_global_rot, src_base_global_pos = source_base_global
    target_base_global_rot, target_base_global_pos = target_base_global

    target_local_rot = {index: np.asarray(value, dtype=np.float64).copy() for index, value in target_base_rot.items()}
    target_local_tra = {index: np.asarray(value, dtype=np.float64).copy() for index, value in target_base_tra.items()}
    target_local_scale = {index: np.asarray(value, dtype=np.float64).copy() for index, value in target_base_scale.items()}
    desired_global_rot: dict[int, np.ndarray] = {}
    desired_global_pos: dict[int, np.ndarray] = {}
    translation_delta: dict[int, np.ndarray] = {}
    target_joints = set(target.joints)

    # Scale changes are relative to the source reference, never copied as a raw
    # target scale. Current source clips keep scale static, but retaining the
    # ratio makes the retargeter safe if a later action adds scale animation.
    for target_index in target.joints:
        source_index = _mapped_source_index(source, target, target_index)
        if source_index is None:
            continue
        source_scale = np.asarray(src_pose_scale[source_index], dtype=np.float64)
        reference_scale = np.asarray(src_base_scale[source_index], dtype=np.float64)
        safe_reference = np.where(np.abs(reference_scale) < 1e-8, 1.0, reference_scale)
        target_local_scale[target_index] = (
            np.asarray(target_base_scale[target_index], dtype=np.float64)
            * source_scale
            / safe_reference
        )

    # Compute desired global rotations in hierarchy order. For a mapped joint,
    # the source's motion delta is left-applied to the target reference pose.
    for index in target._topological():
        parent = target.parent.get(index)
        name = target.nodes[index].get("name", f"node{index}")
        source_index = _mapped_source_index(source, target, index) if index in target_joints else None
        if source_index is not None:
            delta = q_mul(src_pose_global_rot[source_index], q_conj(src_base_global_rot[source_index]))
            desired_global_rot[index] = q_normalize(
                q_mul(delta, target_base_global_rot[index])
            )
        elif parent is None:
            desired_global_rot[index] = q_normalize(target_base_rot[index])
        else:
            desired_global_rot[index] = q_normalize(
                q_mul(desired_global_rot[parent], target_base_rot[index])
            )

        if source_index is not None and name in dynamic_translation_joints:
            local_delta = (
                np.asarray(src_pose_tra[source_index], dtype=np.float64)
                - np.asarray(src_base_tra[source_index], dtype=np.float64)
            ) * np.asarray(src_base_scale[source_index], dtype=np.float64)
            source_parent = source.parent.get(source_index)
            if source_parent is not None:
                local_delta = q_rotate(src_base_global_rot[source_parent], local_delta)
            translation_delta[index] = np.asarray(local_delta, dtype=np.float64) * unit_ratio

    # Convert the desired global rotations back to target-local rotations.
    # Doing this after the hierarchy pass preserves each target parent/rest
    # orientation while transferring the source pose's global motion.
    for index in target._topological():
        if index not in target_joints:
            continue
        parent = target.parent.get(index)
        target_local_rot[index] = (
            q_normalize(q_mul(q_conj(desired_global_rot[parent]), desired_global_rot[index]))
            if parent is not None
            else desired_global_rot[index]
        )

    # Rebuild target positions from the target's own local bone lengths. Only
    # root/hip translation deltas are transferred; rotating a shoulder must
    # not stretch the target's arm to match the Robot Common model's proportions.
    for index in target._topological():
        parent = target.parent.get(index)
        scale = np.asarray(target_local_scale[index], dtype=np.float64)
        name = target.nodes[index].get("name", f"node{index}")
        if parent is None:
            if index in translation_delta:
                wanted = np.asarray(target_base_global_pos[index]) + translation_delta[index]
                safe_scale = np.where(np.abs(scale) < 1e-8, 1.0, scale)
                target_local_tra[index] = wanted / safe_scale
                desired_global_pos[index] = wanted
            else:
                target_local_tra[index] = np.asarray(target_base_tra[index], dtype=np.float64).copy()
                desired_global_pos[index] = target_local_tra[index] * scale
            continue

        if index in translation_delta:
            wanted = np.asarray(target_base_global_pos[index]) + translation_delta[index]
            parent_delta = wanted - desired_global_pos[parent]
            local = q_rotate(q_conj(desired_global_rot[parent]), parent_delta)
            safe_scale = np.where(np.abs(scale) < 1e-8, 1.0, scale)
            target_local_tra[index] = local / safe_scale
            desired_global_pos[index] = wanted
        else:
            target_local_tra[index] = np.asarray(target_base_tra[index], dtype=np.float64).copy()
            local_position = target_local_tra[index] * scale
            desired_global_pos[index] = desired_global_pos[parent] + q_rotate(
                desired_global_rot[parent], local_position
            )

    # Only skin joints are animation targets. Root/mesh nodes retain their GLTF
    # transforms and the target model's bind data remains untouched.
    return {
        "rot": {index: target_local_rot[index] for index in target.joints},
        "tra": {index: target_local_tra[index] for index in target.joints},
        "sca": {index: target_local_scale[index] for index in target.joints},
    }


def _retarget_clip(
    source: Skeleton,
    target: Skeleton,
    clip: str,
    source_reference_clip: str,
    target_reference_local: tuple[dict, dict, dict],
    unit_ratio: float,
) -> tuple[np.ndarray, list[dict[str, dict[int, np.ndarray]]]]:
    source_reference_local = source.local_pose(source_reference_clip, 0.0)
    source_reference_global = source.fk(*source_reference_local)
    target_reference_global = target.fk(*target_reference_local)
    raw_times, start = _animation_times(source, clip)
    dynamic_translation_joints = _dynamic_translation_joints(source, clip)
    frames = []
    for raw_time in raw_times:
        local = source.local_pose(clip, float(raw_time))
        global_pose = source.fk(*local)
        frames.append(
            _retarget_pose(
                source,
                target,
                local,
                global_pose,
                source_reference_local,
                source_reference_global,
                target_reference_local,
                target_reference_global,
                unit_ratio,
                dynamic_translation_joints,
            )
        )
    return raw_times - start, frames


def _mixed_aim_locomotion(
    source: Skeleton,
    target: Skeleton,
    locomotion_clip: str,
    composite_clip: str,
    target_idle_local: tuple[dict, dict, dict],
    target_aim_frame: dict[str, dict[int, np.ndarray]],
    unit_ratio: float,
) -> tuple[np.ndarray, list[dict[str, dict[int, np.ndarray]]]]:
    source_reference_local = source.local_pose("idle", 0.0)
    source_reference_global = source.fk(*source_reference_local)
    target_reference_global = target.fk(*target_idle_local)
    composite_times, composite_start = _animation_times(source, composite_clip)
    locomotion_times, locomotion_start = _animation_times(source, locomotion_clip)
    composite_duration = max(float(composite_times[-1] - composite_start), 1e-8)
    locomotion_duration = max(float(locomotion_times[-1] - locomotion_start), 1e-8)
    output_times = composite_times - composite_start
    dynamic_translation_joints = _dynamic_translation_joints(source, locomotion_clip)
    frames = []

    for output_time in output_times:
        phase = float(output_time) / composite_duration
        source_time = locomotion_start + phase * locomotion_duration
        local = source.local_pose(locomotion_clip, source_time)
        movement = _retarget_pose(
            source,
            target,
            local,
            source.fk(*local),
            source_reference_local,
            source_reference_global,
            target_idle_local,
            target_reference_global,
            unit_ratio,
            dynamic_translation_joints,
        )
        frame = {path: {} for path in ("rot", "tra", "sca")}
        for index in target.joints:
            name = target.nodes[index].get("name", f"node{index}")
            source_pose = target_aim_frame if _upper_body(name) else movement
            for path in frame:
                frame[path][index] = np.asarray(source_pose[path][index], dtype=np.float64).copy()
        frames.append(frame)
    return output_times, frames


def _is_dynamic(sequence: np.ndarray, path: str) -> bool:
    if len(sequence) < 2:
        return False
    if path == "rotation":
        dots = np.abs(sequence @ sequence[0])
        angles = 2.0 * np.arccos(np.clip(dots, -1.0, 1.0))
        return float(np.max(angles)) > 1e-5
    return float(np.max(np.linalg.norm(sequence - sequence[0], axis=1))) > 1e-6


def _dynamic_translation_joints(source: Skeleton, clip: str) -> set[str]:
    """Return root/hip joints with real per-clip translation motion.

    A static Hip offset in a death clip must remain part of the target rig's
    rest hierarchy; applying it as a second root-motion track can counteract a
    moving BoneRoot and leave the model floating.
    """
    animation = source.animations.get(clip)
    if animation is None:
        raise RuntimeError(f"missing source clip {clip!r}")
    dynamic: set[str] = set()
    for channel in animation.get("channels", []):
        target = channel.get("target", {})
        if target.get("path") != "translation":
            continue
        node = int(target.get("node", -1))
        name = source.nodes[node].get("name", f"node{node}") if 0 <= node < len(source.nodes) else ""
        if name not in TRANSLATION_JOINTS:
            continue
        sampler_index = int(channel.get("sampler", -1))
        samplers = animation.get("samplers", [])
        if sampler_index < 0 or sampler_index >= len(samplers):
            raise RuntimeError(f"{clip}: invalid translation sampler for {name}")
        sampler = samplers[sampler_index]
        values = accessor_array(source.js, source.bin, int(sampler["output"])).reshape(-1, 3)
        if _is_dynamic(values, "translation"):
            dynamic.add(name)
    return dynamic


def _validate_aim_locomotion(skeleton: Skeleton, label: str) -> dict[str, dict[str, float]]:
    """Ensure aim-locomotion is time-locked, keeps aim, and reuses the gait pose."""
    reports: dict[str, dict[str, float]] = {}
    for composite, movement in (("aim_walk", "walk"), ("aim_run", "run")):
        composite_times, composite_start = _animation_times(skeleton, composite)
        movement_times, movement_start = _animation_times(skeleton, movement)
        composite_times = composite_times - composite_start
        movement_times = movement_times - movement_start
        if composite_times.shape != movement_times.shape or np.max(
            np.abs(composite_times - movement_times), initial=0.0
        ) > 1e-5:
            raise RuntimeError(f"{label}: {composite} key times do not match {movement}")

        duration = float(composite_times[-1])
        sample_times = np.linspace(0.0, duration, 7)
        aim_rot, aim_tra, aim_scale = skeleton.local_pose("aim", 0.0)
        max_upper_rotation = 0.0
        max_upper_translation = 0.0
        max_lower_rotation = 0.0
        max_lower_translation = 0.0
        max_scale_delta = 0.0
        foot_positions: dict[int, list[np.ndarray]] = {}
        feet = [skeleton.name[name] for name in ("L_Foot", "R_Foot") if name in skeleton.name]

        for sample_time in sample_times:
            composite_pose = skeleton.local_pose(composite, float(sample_time))
            movement_pose = skeleton.local_pose(movement, float(sample_time))
            composite_global = skeleton.fk(*composite_pose)
            for index in skeleton.joints:
                name = skeleton.nodes[index].get("name", f"node{index}")
                reference_pose = (aim_rot, aim_tra, aim_scale) if _upper_body(name) else movement_pose
                max_scale_delta = max(
                    max_scale_delta,
                    float(np.linalg.norm(composite_pose[2][index] - reference_pose[2][index])),
                )
                dot = abs(float(np.dot(composite_pose[0][index], reference_pose[0][index])))
                angle = 2.0 * math.acos(float(np.clip(dot, -1.0, 1.0)))
                translation = float(
                    np.linalg.norm(composite_pose[1][index] - reference_pose[1][index])
                )
                if _upper_body(name):
                    max_upper_rotation = max(max_upper_rotation, angle)
                    max_upper_translation = max(max_upper_translation, translation)
                else:
                    max_lower_rotation = max(max_lower_rotation, angle)
                    max_lower_translation = max(max_lower_translation, translation)
            for foot in feet:
                foot_positions.setdefault(foot, []).append(composite_global[1][foot].copy())

        if max_upper_rotation > math.radians(0.1) or max_upper_translation > 2e-4:
            raise RuntimeError(
                f"{label}: {composite} upper body drifts from aim "
                f"({math.degrees(max_upper_rotation):.3f}°, {max_upper_translation:.6f} m)"
            )
        if max_lower_rotation > math.radians(0.1) or max_lower_translation > 2e-4:
            raise RuntimeError(
                f"{label}: {composite} lower body does not match {movement} "
                f"({math.degrees(max_lower_rotation):.3f}°, {max_lower_translation:.6f} m)"
            )
        if max_scale_delta > 2e-4:
            raise RuntimeError(f"{label}: {composite} changes joint scale")
        if feet and max(
            float(np.max(np.linalg.norm(np.stack(points) - points[0], axis=1)))
            for points in foot_positions.values()
        ) < 0.005:
            raise RuntimeError(f"{label}: {composite} has no measurable foot motion")
        reports[composite] = {
            "duration_s": round(duration, 6),
            "upper_rotation_deg": round(math.degrees(max_upper_rotation), 5),
            "lower_rotation_deg": round(math.degrees(max_lower_rotation), 5),
            "lower_translation_m": round(max_lower_translation, 7),
        }
    return reports


def _write_clip(
    skeleton: Skeleton,
    writer: BinWriter,
    name: str,
    times: np.ndarray,
    frames: list[dict[str, dict[int, np.ndarray]]],
) -> dict:
    if len(frames) != len(times) or not frames:
        raise RuntimeError(f"{name}: animation frame/time mismatch")
    if len(times) > 1 and np.any(np.diff(times) <= 0.0):
        raise RuntimeError(f"{name}: key times must be strictly increasing")

    shared_time_accessor = writer.add(
        np.asarray(times, dtype=np.float64).reshape(-1, 1),
        "SCALAR",
        5126,
        minmax=True,
    )
    animation = {"name": name, "channels": [], "samplers": []}
    dynamic_channels = 0

    for node in skeleton.joints:
        for path, table, gltf_type in (
            ("rotation", "rot", "VEC4"),
            ("translation", "tra", "VEC3"),
            ("scale", "sca", "VEC3"),
        ):
            sequence = np.stack([frame[table][node] for frame in frames]).astype(np.float64)
            dynamic = _is_dynamic(sequence, path)
            if path == "scale" and not dynamic and np.allclose(
                sequence[0], skeleton.rest_s[node], rtol=0.0, atol=2e-5
            ):
                continue
            if path == "rotation":
                sequence = sequence.copy()
                for frame_index in range(1, len(sequence)):
                    if float(np.dot(sequence[frame_index], sequence[frame_index - 1])) < 0.0:
                        sequence[frame_index] = -sequence[frame_index]
                lengths = np.linalg.norm(sequence, axis=1, keepdims=True)
                sequence = sequence / np.maximum(lengths, 1e-12)
            if dynamic:
                input_accessor = shared_time_accessor
                output_values = sequence
                dynamic_channels += 1
            else:
                input_accessor = writer.add(
                    np.array([[0.0]], dtype=np.float64),
                    "SCALAR",
                    5126,
                    minmax=True,
                )
                output_values = sequence[:1]
            output_accessor = writer.add(output_values, gltf_type, 5126)
            animation["samplers"].append(
                {"input": input_accessor, "output": output_accessor, "interpolation": "LINEAR"}
            )
            animation["channels"].append(
                {
                    "sampler": len(animation["samplers"]) - 1,
                    "target": {"node": node, "path": path},
                }
            )

    skeleton.js.setdefault("animations", []).append(animation)
    return {"name": name, "seconds": float(times[-1]), "dynamic_channels": dynamic_channels}


def _build_variant(variant: dict, source: Skeleton) -> dict:
    if not variant["model"].exists():
        raise RuntimeError(f"optimized model missing: {variant['model']}")
    js, bin_ = read_glb(variant["model"])
    target = Skeleton(js, bin_)
    if not CHECK_ONLY and set(target.animations) != {"idle"}:
        raise RuntimeError(
            f"{variant['enemy_id']}: expected a clean optimized GLB with only idle; "
            "run tools/gltf/build_robot_enemy_variants.sh before retargeting."
        )
    source_joints = _joint_names(source)
    target_joints = _joint_names(target)
    missing = sorted(source_joints - target_joints)
    extra = sorted(target_joints - source_joints)
    unexpected_missing = sorted(set(missing) - OPTIONAL_MISSING_JOINTS)
    if unexpected_missing or extra:
        raise RuntimeError(
            f"{variant['enemy_id']}: skeleton mapping mismatch; missing={unexpected_missing}, extra={extra}"
        )

    for name in sorted(source_joints & target_joints):
        source_index = source.name[name]
        target_index = target.name[name]
        source_parent = source.parent.get(source_index)
        target_parent = target.parent.get(target_index)
        source_parent_name = source.nodes[source_parent].get("name") if source_parent is not None else None
        target_parent_name = target.nodes[target_parent].get("name") if target_parent is not None else None
        if source_parent_name != target_parent_name:
            raise RuntimeError(
                f"{variant['enemy_id']}: {name} parent differs ({source_parent_name} vs {target_parent_name})"
            )

    source_height = _mesh_height(source.js, source.bin)
    target_height = _mesh_height(js, bin_)
    if not (0.95 <= source_height <= 1.05 and 0.95 <= target_height <= 1.05):
        raise RuntimeError(
            f"{variant['enemy_id']}: expected one-metre model units, got Common={source_height:.4f}, "
            f"target={target_height:.4f}"
        )
    unit_ratio = target_height / source_height

    # Retain the target's own idle clip and start from its first authored pose.
    idle_local = target.local_pose("idle", 0.0)
    right_hand_target = BASE_RIGHT_HAND * unit_ratio
    model_weapon_scale = BASE_GUN_SCALE * unit_ratio
    old_aim = build_clips.RIGHT_HAND, build_clips.RIGHT_POLE, build_clips.LEFT_POLE, build_clips.GUN_SCALE
    build_clips.RIGHT_HAND = right_hand_target
    build_clips.RIGHT_POLE = BASE_RIGHT_POLE * unit_ratio
    build_clips.LEFT_POLE = BASE_LEFT_POLE * unit_ratio
    build_clips.GUN_SCALE = model_weapon_scale
    try:
        attach = build_clips.build_attach(target, idle_local)
        aim_keys, aim_report, idle_base = build_clips.build_aim(target, attach)
        fire_keys, muzzle_back, rest_muzzle, muzzle_up = build_clips.build_fire(target, idle_base, attach)
        carry = build_clips.carry_socket_rotation(target, idle_local, attach)
        aim_local = tuple({index: np.asarray(value).copy() for index, value in table.items()} for table in idle_base)
        for path, key_name in ((0, "rot"), (1, "tra"), (2, "sca")):
            for index in target.joints:
                aim_local[path][index] = np.asarray(aim_keys[key_name][0][index]).copy()
        aim_frame = {
            path: {index: np.asarray(aim_keys[path][0][index]).copy() for index in target.joints}
            for path in ("rot", "tra", "sca")
        }

        # prepare_robot_enemy_variants.mjs regenerates a clean optimized GLB before this step. Keep
        # its native idle and append the retargeted clips exactly once.
        js["animations"] = [
            animation for animation in js.get("animations", []) if animation.get("name") == "idle"
        ]
        # The Skeleton object holds references into this JSON document, so its
        # idle clip remains available after the animation list is trimmed.
        writer = BinWriter(js, bin_)
        clip_reports = []

        for clip in ("walk", "run"):
            times, frames = _retarget_clip(
                source,
                target,
                clip,
                "idle",
                idle_local,
                unit_ratio,
            )
            clip_reports.append(_write_clip(target, writer, clip, times, frames))

        # Aim and fire are solved for this target skeleton; using Common's baked
        # wrist/socket transforms directly would undo the retarget.
        for clip, keys in (("aim", aim_keys), ("fire", fire_keys)):
            times = np.arange(len(keys["rot"]), dtype=np.float64) / build_clips.FPS
            frames = [
                {path: keys[path][frame] for path in ("rot", "tra", "sca")}
                for frame in range(len(times))
            ]
            clip_reports.append(_write_clip(target, writer, clip, times, frames))

        for clip in ("reload", "hit"):
            times, frames = _retarget_clip(
                source,
                target,
                clip,
                "aim",
                aim_local,
                unit_ratio,
            )
            clip_reports.append(_write_clip(target, writer, clip, times, frames))

        for clip in ("aim_walk", "aim_run"):
            movement_clip = "walk" if clip == "aim_walk" else "run"
            times, frames = _mixed_aim_locomotion(
                source,
                target,
                movement_clip,
                clip,
                idle_local,
                aim_frame,
                unit_ratio,
            )
            clip_reports.append(_write_clip(target, writer, clip, times, frames))

        times, frames = _retarget_clip(
            source,
            target,
            "death",
            "idle",
            idle_local,
            unit_ratio,
        )
        clip_reports.append(_write_clip(target, writer, "death", times, frames))
        # Present the imported animations in a predictable order. The native
        # target idle remains first, followed by the Robot Common-derived clip names.
        by_name = {animation.get("name", ""): animation for animation in js["animations"]}
        js["animations"] = [by_name[name] for name in REQUIRED_CLIPS]
        write_glb(variant["model"], js, writer.bin)
        strip_file(variant["model"])
    finally:
        build_clips.RIGHT_HAND, build_clips.RIGHT_POLE, build_clips.LEFT_POLE, build_clips.GUN_SCALE = old_aim

    # Geometric IK/weapon checks use the target rig, not screenshots. The
    # separate Godot smoke test checks the imported socket and clip playback.
    aim_global = target.fk(aim_keys["rot"][0], aim_keys["tra"][0], aim_keys["sca"][0])
    hand_error = float(np.linalg.norm(aim_global[1][target.name["R_Hand"]] - right_hand_target))
    left_error = float(np.linalg.norm(aim_global[1][target.name["L_Hand"]] - aim_report["support"]))
    original_gun_scale = build_clips.GUN_SCALE
    build_clips.GUN_SCALE = model_weapon_scale
    try:
        to_hero, barrel_q, _hand_position = build_clips.gun_transform(
            aim_keys["rot"][0], aim_keys["tra"][0], aim_keys["sca"][0], target, attach
        )
        muzzle_character = to_hero(build_clips.GUN_MUZZLE)
    finally:
        build_clips.GUN_SCALE = original_gun_scale
    barrel_direction = q_rotate(barrel_q, np.array([0.0, 0.0, -1.0]))
    pitch = math.degrees(math.asin(float(np.clip(barrel_direction[1], -1.0, 1.0))))
    carry_error = float(np.linalg.norm(carry[2] - carry[3]))
    if hand_error >= 0.002 or left_error >= 0.01 or pitch >= 1.5 or carry_error >= 0.01:
        raise RuntimeError(
            f"{variant['enemy_id']}: IK check failed: hand={hand_error:.4f}, "
            f"support={left_error:.4f}, pitch={pitch:.2f}, carry={carry_error:.4f}"
        )

    rig = {
        "note": "Generated by tools/gltf/retarget_robot_enemy_variants.py — do not edit by hand.",
        "model": variant["model"].name,
        "character_role": "enemy",
        "asset_identity": identity_for(variant["enemy_id"]),
        "source_robot_common_model": "enemy_robot_common.glb",
        "source_robot_common_sha256": _sha256(SOURCE_ROBOT),
        "source_variant_sha256": _sha256(variant["source"]),
        "retarget_method": (
            "Global source pose deltas relative to Robot Common idle/aim are applied to the target's own "
            "idle/IK aim reference. Target-local rotations are rebuilt through the matching hierarchy; "
            "target bone lengths are preserved. Root/Hip translation is transferred only when that joint "
            "moves in the source clip."
        ),
        "units": "model height is measured in GLB space; the receiving character setup fits it to target height",
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
            "idle": {"seconds": round(target.clip_duration("idle"), 3), "loop": True},
            **{
                report["name"]: {"seconds": round(report["seconds"], 3), "loop": report["name"] in {
                    "walk", "run", "aim", "aim_walk", "aim_run"
                }}
                for report in clip_reports
            },
        },
        "retarget": {
            "source_joint_count": len(source_joints),
            "target_joint_count": len(target_joints),
            "mapped_joint_count": len(source_joints & target_joints),
            "unmapped_source_joints": missing,
            "target_only_joints": extra,
            "translation_bones": sorted(TRANSLATION_JOINTS),
        },
        "aim_pose": {
            "right_hand": [round(float(value), 4) for value in aim_report["right_hand"]],
            "left_hand": [round(float(value), 4) for value in aim_report["left_hand"]],
            "support": [round(float(value), 4) for value in aim_report["support"]],
            "reach_right": round(float(aim_report["reach_right"]), 4),
            "reach_left": round(float(aim_report["reach_left"]), 4),
            "hand_ik_error_m": round(hand_error, 6),
            "support_ik_error_m": round(left_error, 6),
            "muzzle": [round(float(value), 4) for value in muzzle_character],
            "barrel_dir": [round(float(value), 4) for value in barrel_direction],
            "barrel_pitch_deg": round(pitch, 3),
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
    }
    variant["rig"].parent.mkdir(parents=True, exist_ok=True)
    variant["rig"].write_text(json.dumps(rig, indent=2) + "\n")
    return rig


def _validate_variant(variant: dict, common_sha: str, source: Skeleton) -> list[str]:
    errors = []
    if not variant["model"].exists():
        return [f"{variant['enemy_id']}: missing runtime GLB {variant['model']}"]
    if not variant["rig"].exists():
        return [f"{variant['enemy_id']}: missing rig profile {variant['rig']}"]
    js, bin_ = read_glb(variant["model"])
    skeleton = Skeleton(js, bin_)
    names = set(skeleton.animations)
    if names != set(REQUIRED_CLIPS):
        errors.append(f"{variant['enemy_id']}: clips {sorted(names)} != {sorted(REQUIRED_CLIPS)}")
    if not (70 <= len(skeleton.joints) <= 80):
        errors.append(f"{variant['enemy_id']}: unexpected joint count {len(skeleton.joints)}")
    if "R_Hand" not in skeleton.name or "BoneRoot" not in skeleton.name:
        errors.append(f"{variant['enemy_id']}: required hand/root bone missing")
    if any(
        channel.get("target", {}).get("path") == "scale"
        and channel.get("target", {}).get("node") in set(skeleton.joints)
        for animation in js.get("animations", [])
        for channel in animation.get("channels", [])
    ):
        errors.append(f"{variant['enemy_id']}: bone-scale animation channels remain")
    for clip in REQUIRED_CLIPS:
        if clip in skeleton.animations and skeleton.clip_duration(clip) <= 0.0:
            errors.append(f"{variant['enemy_id']}: {clip} has no duration")

    try:
        _validate_aim_locomotion(skeleton, variant["enemy_id"])
    except RuntimeError as error:
        errors.append(str(error))
    target_joint_names = _joint_names(skeleton)
    for clip in ("walk", "run", "death"):
        expected_translation = _dynamic_translation_joints(source, clip) & target_joint_names
        actual_translation = _dynamic_translation_joints(skeleton, clip)
        if actual_translation != expected_translation:
            errors.append(
                f"{variant['enemy_id']}: {clip} dynamic root/hip tracks "
                f"{sorted(actual_translation)} != source {sorted(expected_translation)}"
            )

    try:
        rig = json.loads(variant["rig"].read_text())
    except (OSError, json.JSONDecodeError) as error:
        return errors + [f"{variant['enemy_id']}: rig JSON failed to parse ({error})"]
    try:
        validate_profile_identity(rig, variant["enemy_id"])
    except RuntimeError as error:
        errors.append(str(error))
    if rig.get("character_role") != "enemy":
        errors.append(f"{variant['enemy_id']}: rig profile is not classified as an enemy")
    if rig.get("source_robot_common_sha256") != common_sha:
        errors.append(f"{variant['enemy_id']}: stale Robot Common animation source hash")
    if rig.get("source_variant_sha256") != _sha256(variant["source"]):
        errors.append(f"{variant['enemy_id']}: stale source GLB hash")
    if rig.get("model") != variant["model"].name:
        errors.append(f"{variant['enemy_id']}: rig model name does not match runtime GLB")
    if rig.get("hand_bone") != "R_Hand":
        errors.append(f"{variant['enemy_id']}: weapon hand socket is not R_Hand")
    if rig.get("retarget", {}).get("unmapped_source_joints") != ["neutral_bone"] and variant["enemy_id"] == "enemy_robot_tier_2_rare":
        errors.append(f"{variant['enemy_id']}: only neutral_bone may be omitted from the target")
    aim = rig.get("aim_pose", {})
    if float(aim.get("hand_ik_error_m", math.inf)) >= 0.002:
        errors.append(f"{variant['enemy_id']}: right-hand IK error is outside tolerance")
    if float(aim.get("support_ik_error_m", math.inf)) >= 0.01:
        errors.append(f"{variant['enemy_id']}: support-hand IK error is outside tolerance")
    if abs(float(aim.get("barrel_pitch_deg", math.inf))) >= 1.5:
        errors.append(f"{variant['enemy_id']}: aim barrel is not level")
    if float(rig.get("carry", {}).get("socket_error", math.inf)) >= 0.01:
        errors.append(f"{variant['enemy_id']}: carry socket check failed")
    return errors


def main() -> int:
    if not SOURCE_ROBOT.exists():
        raise RuntimeError(f"Robot Common runtime enemy missing: {SOURCE_ROBOT}")
    source = Skeleton(*read_glb(SOURCE_ROBOT))
    missing_common_clips = sorted(set(REQUIRED_CLIPS) - set(source.animations))
    if missing_common_clips:
        raise RuntimeError(f"Robot Common runtime enemy is missing clips: {missing_common_clips}")
    common_sha = _sha256(SOURCE_ROBOT)
    errors: list[str] = []

    for variant in VARIANTS:
        if CHECK_ONLY:
            errors.extend(_validate_variant(variant, common_sha, source))
            if not errors:
                print(f"{variant['enemy_id']}: GLB, 10 clips, rig/profile hashes, gait and translation checks pass")
            continue
        rig = _build_variant(variant, source)
        errors.extend(_validate_variant(variant, common_sha, source))
        report = rig["aim_pose"]
        print(
            f"{variant['enemy_id']}: {rig['retarget']['mapped_joint_count']}/"
            f"{rig['retarget']['target_joint_count']} joints · {len(rig['clips'])} clips · "
            f"hand IK {report['hand_ik_error_m'] * 1000:.3f} mm · "
            f"support {report['support_ik_error_m'] * 1000:.3f} mm · "
            f"barrel pitch {report['barrel_pitch_deg']:+.3f}°"
        )

    for error in errors:
        print(f"ERROR: {error}", file=sys.stderr)
    return 1 if errors else 0


if __name__ == "__main__":
    raise SystemExit(main())
