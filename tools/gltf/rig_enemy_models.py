#!/usr/bin/env python3
"""Apply the Robot Common enemy skeleton to the two supplied static enemy meshes.

The GLB hierarchy, 79-joint skin, bind matrices and rest pose are copied from
``game/assets/enemies/enemy_robot_common.glb``. The enemy meshes get their own
per-vertex JOINTS_0 / WEIGHTS_0 attributes, derived from proximity to the copied
bone segments. Enemy-specific clips are deliberately not embedded: the enemies
can receive their own animations later while keeping this shared skeleton.

This is a deterministic glTF skinning build, not a Blender autorig or a visual
weight-paint review. ``--check`` verifies the exported GLB by re-reading it,
checking rest-pose identity, and probing deformations with Robot Common's clips in
memory without copying those clips into the enemy files.

Usage:
  .venv/bin/python tools/gltf/rig_enemy_models.py
  .venv/bin/python tools/gltf/rig_enemy_models.py --check
"""
from __future__ import annotations

import copy
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

from asset_identity import identity_for, validate_profile_identity  # noqa: E402
from rigmath import BinWriter, Skeleton, accessor_array, read_glb, write_glb  # noqa: E402

RIG_TEMPLATE_MODEL = ROOT / "game/assets/enemies/enemy_robot_common.glb"
VARIANTS = (
    {
        "asset_id": "enemy_iron_sentinel",
        "source": ROOT / "source-assets/enemies/enemy_iron_sentinel_source.glb",
        "optimized": ROOT / "tools/gltf/build/enemies/enemy_iron_sentinel.glb",
        "model": ROOT / "game/assets/enemies/enemy_iron_sentinel.glb",
        "rig": ROOT / "game/assets/enemies/enemy_iron_sentinel_rig.json",
    },
    {
        "asset_id": "enemy_iron_warden_boss",
        "source": ROOT / "source-assets/enemies/enemy_iron_warden_boss_source.glb",
        "optimized": ROOT / "tools/gltf/build/enemies/enemy_iron_warden_boss.glb",
        "model": ROOT / "game/assets/enemies/enemy_iron_warden_boss.glb",
        "rig": ROOT / "game/assets/enemies/enemy_iron_warden_boss_rig.json",
    },
)

HELPER_BONES = {"neutral_bone", "L_KneeShareBone", "R_KneeShareBone", "L_ElbowShareBone", "R_ElbowShareBone"}
MAX_INFLUENCES = 4
WEIGHT_EPSILON = 0.02
MAX_REST_ERROR = 0.0002
MAX_POSE_RADIUS = 2.5
PROBE_CLIPS = ("walk", "run", "aim", "death")
CHECK_ONLY = "--check" in sys.argv


def _variant_label(variant: dict) -> str:
    return str(variant.get("asset_id", variant.get("enemy_id", "<unknown asset>")))


def _sha256(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest()


def _parent_map(nodes: list[dict[str, Any]]) -> dict[int, int]:
    parents: dict[int, int] = {}
    for parent, node in enumerate(nodes):
        for child in node.get("children", []):
            if child in parents:
                raise RuntimeError(f"GLB node {child} has more than one parent")
            parents[child] = parent
    return parents


def _source_skeleton_region(template_js: dict[str, Any]) -> tuple[int, int, set[int]]:
    skins = template_js.get("skins", [])
    if len(skins) != 1:
        raise RuntimeError(f"Robot Common enemy must contain one skin; got {len(skins)}")
    skin = skins[0]
    joint_nodes = skin.get("joints", [])
    mesh_nodes = [
        index
        for index, node in enumerate(template_js["nodes"])
        if node.get("skin") == 0 and node.get("mesh") is not None
    ]
    if not joint_nodes or len(mesh_nodes) != 1:
        raise RuntimeError("Robot Common enemy must have one skinned mesh and a non-empty joint list")

    parents = _parent_map(template_js["nodes"])
    source_mesh_node = mesh_nodes[0]
    armature_root = parents.get(source_mesh_node)
    if armature_root is None:
        raise RuntimeError("Robot Common enemy mesh is not parented under its armature root")

    # The Common GLB's mesh and joint hierarchy are siblings under Armature.
    # Verify every skin joint descends from that same root before copying it.
    region: set[int] = {armature_root}
    for joint in joint_nodes:
        current: int | None = joint
        while current is not None:
            region.add(current)
            if current == armature_root:
                break
            current = parents.get(current)
        if current != armature_root:
            raise RuntimeError(
                f"Common joint {template_js['nodes'][joint].get('name', joint)!r} "
                "does not descend from its armature root"
            )
    if source_mesh_node in region:
        raise RuntimeError("Common skinned mesh unexpectedly lies inside the joint hierarchy")
    return source_mesh_node, armature_root, region


def _deforming_segments(
    template_js: dict[str, Any], template_skeleton: Skeleton
) -> tuple[np.ndarray, np.ndarray, np.ndarray, list[str]]:
    """Return target-joint ids and rest-pose segments for automatic weighting."""
    skin = template_js["skins"][0]
    joint_nodes = skin["joints"]
    joint_to_skin_index = {node_index: skin_index for skin_index, node_index in enumerate(joint_nodes)}
    _, global_pos = template_skeleton.rest_pose()
    starts: list[np.ndarray] = []
    ends: list[np.ndarray] = []
    skin_indices: list[int] = []
    names: list[str] = []

    for node_index in joint_nodes:
        name = template_js["nodes"][node_index].get("name", f"node{node_index}")
        if name in HELPER_BONES or "ShareBone" in name:
            continue
        start = np.asarray(global_pos[node_index], dtype=np.float64)

        children = [
            child
            for child in template_js["nodes"][node_index].get("children", [])
            if child in joint_to_skin_index
            and template_js["nodes"][child].get("name", "") not in HELPER_BONES
            and "ShareBone" not in template_js["nodes"][child].get("name", "")
        ]
        primary_children = [
            child
            for child in children
            if "Twist" not in template_js["nodes"][child].get("name", "")
        ]
        if len(primary_children) == 1:
            endpoint = np.asarray(global_pos[primary_children[0]], dtype=np.float64)
        elif len(primary_children) == 0 and len(children) == 1:
            endpoint = np.asarray(global_pos[children[0]], dtype=np.float64)
        else:
            endpoint = start.copy()
        # A short or branching bone is represented by its joint point. Long
        # segments cover the limb surface more consistently than point-only
        # nearest-bone weights.
        if np.linalg.norm(endpoint - start) < 0.008:
            endpoint = start.copy()

        starts.append(start)
        ends.append(endpoint)
        skin_indices.append(joint_to_skin_index[node_index])
        names.append(name)

    if len(starts) < MAX_INFLUENCES:
        raise RuntimeError("The copied skeleton has too few deforming bones")
    return (
        np.asarray(starts, dtype=np.float64),
        np.asarray(ends, dtype=np.float64),
        np.asarray(skin_indices, dtype=np.uint16),
        names,
    )


def _weights_for_points(
    points: np.ndarray, starts: np.ndarray, ends: np.ndarray, skin_indices: np.ndarray
) -> tuple[np.ndarray, np.ndarray]:
    vertex_count = len(points)
    joints = np.zeros((vertex_count, MAX_INFLUENCES), dtype=np.uint16)
    weights = np.zeros((vertex_count, MAX_INFLUENCES), dtype=np.float32)
    segment = ends - starts
    lengths_sq = np.einsum("ij,ij->i", segment, segment)
    chunks = 4096

    for first in range(0, vertex_count, chunks):
        last = min(first + chunks, vertex_count)
        chunk = points[first:last]
        relative = chunk[:, None, :] - starts[None, :, :]
        projection = np.einsum("bji,ji->bj", relative, segment)
        projection /= np.maximum(lengths_sq[None, :], 1e-12)
        projection = np.clip(projection, 0.0, 1.0)
        closest = starts[None, :, :] + projection[:, :, None] * segment[None, :, :]
        delta = chunk[:, None, :] - closest
        distances_sq = np.einsum("bji,bji->bj", delta, delta)
        nearest = np.argpartition(distances_sq, MAX_INFLUENCES - 1, axis=1)[:, :MAX_INFLUENCES]
        nearest_distances = np.take_along_axis(distances_sq, nearest, axis=1)
        order = np.argsort(nearest_distances, axis=1)
        nearest = np.take_along_axis(nearest, order, axis=1)
        nearest_distances = np.take_along_axis(nearest_distances, order, axis=1)

        scores = 1.0 / (nearest_distances + WEIGHT_EPSILON * WEIGHT_EPSILON)
        scores /= np.maximum(scores.sum(axis=1, keepdims=True), 1e-12)
        joints[first:last] = skin_indices[nearest]
        weights[first:last] = scores.astype(np.float32)

    sums = weights.sum(axis=1, keepdims=True)
    weights /= np.maximum(sums, 1e-12)
    return joints, weights


def _quaternion_rotate_batch(quaternion: np.ndarray, points: np.ndarray) -> np.ndarray:
    vector = quaternion[:3]
    twice_cross = 2.0 * np.cross(vector, points)
    return points + quaternion[3] * twice_cross + np.cross(vector, twice_cross)


def _skin_points(
    points: np.ndarray,
    joints: np.ndarray,
    weights: np.ndarray,
    joint_nodes: list[int],
    global_rot: dict[int, np.ndarray],
    global_pos: dict[int, np.ndarray],
    inverse_bind: np.ndarray,
) -> np.ndarray:
    deformed = np.zeros_like(points, dtype=np.float64)
    for skin_index, node_index in enumerate(joint_nodes):
        for lane in range(MAX_INFLUENCES):
            selected = np.flatnonzero(joints[:, lane] == skin_index)
            if selected.size == 0:
                continue
            bind_matrix = inverse_bind[skin_index]
            bind_space = points[selected] @ bind_matrix[:3, :3].T + bind_matrix[:3, 3]
            posed = _quaternion_rotate_batch(global_rot[node_index], bind_space)
            posed += global_pos[node_index]
            deformed[selected] += posed * weights[selected, lane, None]
    return deformed


def _load_template() -> tuple[dict[str, Any], bytes, Skeleton]:
    if not RIG_TEMPLATE_MODEL.exists():
        raise RuntimeError(f"Robot Common rig template missing: {RIG_TEMPLATE_MODEL}")
    template_js, template_bin = read_glb(RIG_TEMPLATE_MODEL)
    skeleton = Skeleton(template_js, template_bin)
    if len(template_js.get("skins", [])) != 1:
        raise RuntimeError("Robot Common rig template must have exactly one skin")
    if len(template_js["skins"][0].get("joints", [])) < 70:
        raise RuntimeError("Robot Common rig template unexpectedly has fewer than 70 joints")
    return template_js, template_bin, skeleton


def _build_variant(
    variant: dict, template_js: dict[str, Any], template_bin: bytes, template_skeleton: Skeleton
) -> dict:
    if not variant["optimized"].exists():
        raise RuntimeError(f"Optimized mesh is missing: {variant['optimized']}")
    js, bin_ = read_glb(variant["optimized"])
    if js.get("skins") or js.get("animations"):
        raise RuntimeError(f"{variant['optimized']} must be a static mesh before rigging")
    mesh_nodes = [index for index, node in enumerate(js["nodes"]) if node.get("mesh") is not None]
    if len(mesh_nodes) != 1 or len(js.get("scenes", [])) != 1:
        raise RuntimeError(f"{_variant_label(variant)}: expected one mesh node in one scene")
    mesh_node = mesh_nodes[0]

    source_mesh_node, armature_root, region = _source_skeleton_region(template_js)
    source_skin = template_js["skins"][0]
    source_joint_nodes = source_skin["joints"]
    mapping: dict[int, int] = {source_mesh_node: mesh_node}
    sorted_region = sorted(region)
    for offset, source_node in enumerate(sorted_region):
        mapping[source_node] = len(js["nodes"]) + offset
    for source_node in sorted_region:
        copied = copy.deepcopy(template_js["nodes"][source_node])
        copied["children"] = [
            mapping[child]
            for child in copied.get("children", [])
            if child == source_mesh_node or child in region
        ]
        js["nodes"].append(copied)

    armature_node = mapping[armature_root]
    # Match the Common hierarchy: the actual mesh is a child of Armature, beside
    # the copied bone tree. The enemy's source scene root is replaced by this
    # same armature root, not by a second transform or generated geometry.
    js["scenes"][0]["nodes"] = [armature_node]
    js["nodes"][mesh_node]["skin"] = 0

    writer = BinWriter(js, bin_)
    inverse_bind = accessor_array(template_js, template_bin, source_skin["inverseBindMatrices"])
    inverse_bind_accessor = writer.add(inverse_bind, "MAT4", 5126, minmax=False)
    skin = copy.deepcopy(source_skin)
    skin["joints"] = [mapping[index] for index in source_joint_nodes]
    skin["skeleton"] = armature_node
    skin["inverseBindMatrices"] = inverse_bind_accessor
    js["skins"] = [skin]

    starts, ends, deform_skin_indices, deform_names = _deforming_segments(template_js, template_skeleton)
    all_weight_reports = []
    mesh_index = js["nodes"][mesh_node]["mesh"]
    for primitive in js["meshes"][mesh_index].get("primitives", []):
        position_accessor = primitive.get("attributes", {}).get("POSITION")
        if position_accessor is None:
            raise RuntimeError(f"{_variant_label(variant)}: primitive is missing POSITION")
        points = accessor_array(js, writer.bin, position_accessor).astype(np.float64)
        joints, weights = _weights_for_points(points, starts, ends, deform_skin_indices)
        primitive.setdefault("attributes", {})["JOINTS_0"] = writer.add(
            joints, "VEC4", 5123, target=34962, minmax=True
        )
        primitive["attributes"]["WEIGHTS_0"] = writer.add(
            weights, "VEC4", 5126, target=34962, minmax=True
        )
        all_weight_reports.append(
            {
                "vertices": int(len(points)),
                "max_weight_sum_error": float(np.max(np.abs(weights.sum(axis=1) - 1.0))),
                "nonzero_joint_count": int(np.unique(joints[weights > 1e-6]).size),
            }
        )

    js["animations"] = []
    variant["model"].parent.mkdir(parents=True, exist_ok=True)
    write_glb(variant["model"], js, writer.bin)
    output_js, output_bin = read_glb(variant["model"])
    checks = _validate_variant(variant, output_js, output_bin, template_js, template_skeleton)

    metadata = {
        "note": "Generated by tools/gltf/rig_enemy_models.py; do not edit by hand.",
        "model": variant["model"].name,
        "character_role": (
            "player_hero"
            if identity_for(variant["asset_id"])["role"] == "hero"
            else "enemy"
        ),
        "asset_identity": identity_for(variant["asset_id"]),
        "source_model": variant["source"].name,
        "source_model_sha256": _sha256(variant["source"]),
        "optimized_mesh_sha256": _sha256(variant["optimized"]),
        "rig_template": "game/assets/enemies/enemy_robot_common.glb",
        "rig_template_sha256": _sha256(RIG_TEMPLATE_MODEL),
        "skeleton_root": output_js["nodes"][output_js["skins"][0]["skeleton"]].get("name"),
        "joint_count": len(output_js["skins"][0]["joints"]),
        "joint_names": [output_js["nodes"][index].get("name") for index in output_js["skins"][0]["joints"]],
        "weighting": {
            "method": "Four nearest copied bone segments with inverse-square distance weights.",
            "excluded_helper_bones": sorted(HELPER_BONES),
            "deforming_bones": deform_names,
            "max_influences": MAX_INFLUENCES,
            "epsilon_m": WEIGHT_EPSILON,
        },
        "animations": "None embedded; enemy-specific clips can be authored on this shared skeleton later.",
        "verification": checks,
        "primitive_weights": all_weight_reports,
    }
    variant["rig"].write_text(json.dumps(metadata, indent=2) + "\n", encoding="utf-8")
    return metadata


def _validate_variant(
    variant: dict,
    js: dict[str, Any],
    bin_: bytes,
    template_js: dict[str, Any],
    template_skeleton: Skeleton,
) -> dict:
    skins = js.get("skins", [])
    if len(skins) != 1:
        raise RuntimeError(f"{_variant_label(variant)}: expected one copied robot skin, got {len(skins)}")
    skin = skins[0]
    template_skin = template_js["skins"][0]
    if len(skin.get("joints", [])) != len(template_skin["joints"]):
        raise RuntimeError(f"{_variant_label(variant)}: joint count differs from Common")
    joint_names = [js["nodes"][index].get("name") for index in skin["joints"]]
    template_joint_names = [template_js["nodes"][index].get("name") for index in template_skin["joints"]]
    if joint_names != template_joint_names:
        raise RuntimeError(f"{_variant_label(variant)}: copied joint order differs from Common")
    if js.get("animations", []):
        raise RuntimeError(f"{_variant_label(variant)}: enemy-specific animations should not be embedded yet")

    mesh_nodes = [index for index, node in enumerate(js["nodes"]) if node.get("mesh") is not None]
    if len(mesh_nodes) != 1 or js["nodes"][mesh_nodes[0]].get("skin") != 0:
        raise RuntimeError(f"{_variant_label(variant)}: mesh node does not reference the copied skin")
    parent = _parent_map(js["nodes"])
    if parent.get(mesh_nodes[0]) != skin.get("skeleton"):
        raise RuntimeError(f"{_variant_label(variant)}: mesh is not parented to the copied armature root")

    mesh_index = js["nodes"][mesh_nodes[0]]["mesh"]
    primitives = js["meshes"][mesh_index].get("primitives", [])
    if not primitives:
        raise RuntimeError(f"{_variant_label(variant)}: no mesh primitives found")
    all_points: list[np.ndarray] = []
    all_joint_arrays: list[np.ndarray] = []
    all_weight_arrays: list[np.ndarray] = []
    total_vertices = 0
    max_weight_sum_error = 0.0
    for primitive in primitives:
        attributes = primitive.get("attributes", {})
        if "JOINTS_0" not in attributes or "WEIGHTS_0" not in attributes:
            raise RuntimeError(f"{_variant_label(variant)}: primitive is missing skin attributes")
        points = accessor_array(js, bin_, attributes["POSITION"]).astype(np.float64)
        joints = accessor_array(js, bin_, attributes["JOINTS_0"]).astype(np.int64)
        weights = accessor_array(js, bin_, attributes["WEIGHTS_0"]).astype(np.float64)
        if joints.shape != weights.shape or joints.shape != (len(points), MAX_INFLUENCES):
            raise RuntimeError(f"{_variant_label(variant)}: skin attributes do not match vertex count")
        if not np.isfinite(points).all() or not np.isfinite(weights).all():
            raise RuntimeError(f"{_variant_label(variant)}: non-finite vertex or skin data")
        if np.any(joints < 0) or np.any(joints >= len(skin["joints"])):
            raise RuntimeError(f"{_variant_label(variant)}: vertex references an unknown joint")
        if np.any(weights < 0.0) or np.any(weights > 1.0 + 1e-6):
            raise RuntimeError(f"{_variant_label(variant)}: invalid skin weight range")
        local_error = float(np.max(np.abs(weights.sum(axis=1) - 1.0)))
        max_weight_sum_error = max(max_weight_sum_error, local_error)
        if local_error > 1e-5:
            raise RuntimeError(f"{_variant_label(variant)}: vertex weights do not sum to one")
        all_points.append(points)
        all_joint_arrays.append(joints)
        all_weight_arrays.append(weights)
        total_vertices += len(points)

    ibm_accessor = skin.get("inverseBindMatrices")
    if ibm_accessor is None:
        raise RuntimeError(f"{_variant_label(variant)}: inverse bind matrices are missing")
    inverse_bind = accessor_array(js, bin_, ibm_accessor).reshape(-1, 4, 4).transpose(0, 2, 1)
    if inverse_bind.shape != (len(skin["joints"]), 4, 4) or not np.isfinite(inverse_bind).all():
        raise RuntimeError(f"{_variant_label(variant)}: inverse bind matrices are invalid")

    common_rest_rot, common_rest_pos = template_skeleton.rest_pose()
    rest_parts = [
        _skin_points(points, joints, weights, template_skin["joints"], common_rest_rot, common_rest_pos, inverse_bind)
        for points, joints, weights in zip(all_points, all_joint_arrays, all_weight_arrays)
    ]
    rest_error = max(
        float(np.max(np.linalg.norm(deformed - points, axis=1)))
        for points, deformed in zip(all_points, rest_parts)
    )
    if rest_error > MAX_REST_ERROR:
        raise RuntimeError(f"{_variant_label(variant)}: bind pose alters the mesh by {rest_error:.6f}m")

    # Probe deformations against Robot Common's clips in memory; these clips are only
    # used for verification and are intentionally not shipped in enemy GLBs.
    pose_reports = {}
    for clip in PROBE_CLIPS:
        if clip not in template_skeleton.animations:
            raise RuntimeError(f"Robot Common rig template is missing probe clip {clip!r}")
        duration = template_skeleton.clip_duration(clip)
        p95_displacement = 0.0
        max_radius = 0.0
        for phase in (0.25, 0.5, 0.75):
            local_pose = template_skeleton.local_pose(clip, duration * phase)
            global_rot, global_pos = template_skeleton.fk(*local_pose)
            for points, joints, weights in zip(all_points, all_joint_arrays, all_weight_arrays):
                deformed = _skin_points(
                    points, joints, weights, template_skin["joints"], global_rot, global_pos, inverse_bind
                )
                displacement = np.linalg.norm(deformed - points, axis=1)
                p95_displacement = max(p95_displacement, float(np.quantile(displacement, 0.95)))
                max_radius = max(max_radius, float(np.max(np.linalg.norm(deformed, axis=1))))
        if not math.isfinite(p95_displacement) or max_radius > MAX_POSE_RADIUS:
            raise RuntimeError(f"{_variant_label(variant)}/{clip}: deformation probe produced invalid bounds")
        if p95_displacement < 0.002:
            raise RuntimeError(f"{_variant_label(variant)}/{clip}: copied weights do not respond to the clip")
        pose_reports[clip] = {
            "p95_displacement_m": round(p95_displacement, 6),
            "max_radius_m": round(max_radius, 6),
        }

    # Check that each copied joint retains the same name and parent as Common.
    output_skeleton = Skeleton(js, bin_)
    for source_index in template_skin["joints"]:
        name = template_js["nodes"][source_index].get("name", f"node{source_index}")
        target_index = output_skeleton.name.get(name)
        if target_index is None:
            raise RuntimeError(f"{_variant_label(variant)}: copied bone {name!r} is missing")
        source_parent = template_skeleton.parent.get(source_index)
        target_parent = output_skeleton.parent.get(target_index)
        source_parent_name = template_js["nodes"][source_parent].get("name") if source_parent is not None else None
        target_parent_name = js["nodes"][target_parent].get("name") if target_parent is not None else None
        if source_parent_name != target_parent_name:
            raise RuntimeError(f"{_variant_label(variant)}: parent mismatch for bone {name!r}")

    return {
        "joint_count": len(skin["joints"]),
        "vertex_count": total_vertices,
        "weight_sum_max_error": round(max_weight_sum_error, 9),
        "bind_pose_max_error_m": round(rest_error, 9),
        "deformation_probes": pose_reports,
    }


def _main() -> int:
    template_js, template_bin, template_skeleton = _load_template()
    if CHECK_ONLY:
        errors = []
        for variant in VARIANTS:
            try:
                if not variant["model"].exists() or not variant["rig"].exists():
                    raise RuntimeError("rigged GLB or rig profile is missing")
                js, bin_ = read_glb(variant["model"])
                checks = _validate_variant(variant, js, bin_, template_js, template_skeleton)
                metadata = json.loads(variant["rig"].read_text(encoding="utf-8"))
                validate_profile_identity(metadata, variant["asset_id"])
                if metadata.get("character_role") != "enemy":
                    raise RuntimeError("rig profile is not classified as an enemy")
                if metadata.get("rig_template_sha256") != _sha256(RIG_TEMPLATE_MODEL):
                    raise RuntimeError("rig profile is stale for the current Common template")
                if metadata.get("source_model_sha256") != _sha256(variant["source"]):
                    raise RuntimeError("rig profile is stale for the preserved enemy source")
                if metadata.get("optimized_mesh_sha256") != _sha256(variant["optimized"]):
                    raise RuntimeError("rig profile is stale for the optimized mesh")
                if metadata.get("verification") != checks:
                    raise RuntimeError("stored rig verification report differs from the current GLB")
                print(
                    f"{_variant_label(variant)}: {checks['joint_count']} shared joints · "
                    f"{checks['vertex_count']:,} weighted vertices · "
                    f"bind error {checks['bind_pose_max_error_m']:.2e}m · deformation probes pass"
                )
            except (OSError, ValueError, RuntimeError, KeyError) as error:
                errors.append(f"{_variant_label(variant)}: {error}")
        for error in errors:
            print(f"ERROR: {error}", file=sys.stderr)
        return 1 if errors else 0

    for variant in VARIANTS:
        report = _build_variant(variant, template_js, template_bin, template_skeleton)
        print(
            f"{_variant_label(variant)}: {report['joint_count']} shared joints · "
            f"{sum(item['vertices'] for item in report['primitive_weights']):,} weighted vertices · "
            f"bind error {report['verification']['bind_pose_max_error_m']:.2e}m · "
            f"probes " + ", ".join(
                f"{clip} {data['p95_displacement_m']:.3f}m"
                for clip, data in report['verification']['deformation_probes'].items()
            )
        )
    return 0


if __name__ == "__main__":
    raise SystemExit(_main())
