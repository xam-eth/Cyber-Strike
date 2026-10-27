#!/usr/bin/env python3
"""Skin each human hero tier to Robot Common's shared 79-joint rig.

The five optimized meshes are kept as separate GLBs. Each gets its own
per-vertex JOINTS_0 / WEIGHTS_0 data on the copied Robot Common skeleton. Human
weights are constrained by connected mesh islands and anatomical bone families
to prevent nearby resting hands from pulling thigh/torso geometry; no mesh is
replaced with procedural geometry. Source meshes stay in
source-assets/characters/human_hero_tiers/.

Run the full build with tools/gltf/build_human_hero_tiers.sh. The standalone
rigging step is useful while iterating:

  .venv/bin/python tools/gltf/rig_human_hero_tiers.py
  .venv/bin/python tools/gltf/rig_human_hero_tiers.py --check
"""
from __future__ import annotations

import copy
import json
import sys
from pathlib import Path
from typing import Any

import numpy as np

HERE = Path(__file__).resolve().parent
ROOT = HERE.parents[1]
sys.path.insert(0, str(HERE))

import rig_enemy_models as rig_builder  # noqa: E402
from asset_identity import identity_for, validate_profile_identity  # noqa: E402
from rigmath import accessor_array, read_glb  # noqa: E402

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

HUMAN_WEIGHTING_METHOD = (
    "Four-nearest copied bone-segment weights constrained by connected mesh-island "
    "anatomical family; ambiguous hand-at-hip islands follow the matching arm."
)
FINGER_BONE_TOKENS = ("Pinky", "Ring", "Mid", "Index", "Thumb")
CORE_BONES = {"BoneRoot", "Hip", "Pelvis", "Waist", "Spine01", "Spine02"}


def _bone_family(name: str) -> str:
    if name in CORE_BONES:
        return "core"
    if any(token in name for token in ("Head", "Eye", "Facial", "Neck")):
        return "head"
    for side in ("L", "R"):
        if not name.startswith(f"{side}_"):
            continue
        if any(token in name for token in ("Thigh", "Calf", "Foot", "Toe", "Knee")):
            return f"{side}_leg"
        if any(token in name for token in ("Upperarm", "Forearm", "Elbow", "Hand", "Clavicle")):
            return f"{side}_arm"
    return "other"


def _labels_from_indices(indices: np.ndarray, vertex_count: int) -> tuple[np.ndarray, np.ndarray]:
    indices = np.asarray(indices, dtype=np.int64).reshape(-1)
    if indices.size % 3:
        raise RuntimeError("human mesh primitive index count is not divisible by three")
    if indices.size and (int(indices.min()) < 0 or int(indices.max()) >= vertex_count):
        raise RuntimeError("human mesh primitive has an out-of-range triangle index")
    parent = np.arange(vertex_count, dtype=np.int64)

    def find(index: int) -> int:
        while parent[index] != index:
            parent[index] = parent[parent[index]]
            index = int(parent[index])
        return index

    def union(first: int, second: int) -> None:
        first_root = find(first)
        second_root = find(second)
        if first_root != second_root:
            parent[second_root] = first_root

    for triangle in indices.reshape(-1, 3):
        first, second, third = (int(value) for value in triangle)
        union(first, second)
        union(second, third)
        union(third, first)

    roots = np.fromiter((find(index) for index in range(vertex_count)), dtype=np.int64, count=vertex_count)
    _unique_roots, labels = np.unique(roots, return_inverse=True)
    sizes = np.bincount(labels, minlength=int(labels.max()) + 1 if len(labels) else 0)
    return labels, sizes


def _triangle_indices(primitive: dict[str, Any], js: dict[str, Any], bin_: bytes, vertex_count: int) -> np.ndarray:
    if "indices" in primitive:
        return accessor_array(js, bin_, int(primitive["indices"])).reshape(-1).astype(np.int64)
    if vertex_count % 3:
        raise RuntimeError("unindexed human mesh does not contain whole triangles")
    return np.arange(vertex_count, dtype=np.int64)


def _segment_distance_matrix(points: np.ndarray, starts: np.ndarray, ends: np.ndarray) -> np.ndarray:
    segments = ends - starts
    lengths_sq = np.einsum("ij,ij->i", segments, segments)
    relative = points[:, None, :] - starts[None, :, :]
    projection = np.einsum("bji,ji->bj", relative, segments)
    projection /= np.maximum(lengths_sq[None, :], 1e-12)
    projection = np.clip(projection, 0.0, 1.0)
    closest = starts[None, :, :] + projection[:, :, None] * segments[None, :, :]
    return np.linalg.norm(points[:, None, :] - closest, axis=2)


def _candidate_bones(family: str, center: np.ndarray, families: np.ndarray, finger: np.ndarray) -> np.ndarray:
    height = float(center[1])
    if family in ("L_leg", "R_leg"):
        allowed = (families == family) | ((families == "core") & (height > 0.36))
    elif family in ("L_arm", "R_arm"):
        allowed = (families == family) | ((families == "core") & (height > 0.57))
    elif family == "head":
        allowed = np.isin(families, ("head", "core"))
    elif height < 0.58:
        allowed = np.isin(families, ("core", "L_leg", "R_leg"))
    elif height < 0.78:
        allowed = np.isin(families, ("core", "L_arm", "R_arm"))
    else:
        allowed = np.isin(families, ("core", "head"))
    allowed &= ~finger
    return allowed


def _human_component_assignments(
    points: np.ndarray,
    primitive: dict[str, Any],
    js: dict[str, Any],
    bin_: bytes,
    starts: np.ndarray,
    ends: np.ndarray,
    skin_indices: np.ndarray,
    deform_names: list[str],
) -> tuple[list[tuple[np.ndarray, np.ndarray, str]], dict[str, Any]]:
    triangle_indices = _triangle_indices(primitive, js, bin_, len(points))
    labels, sizes = _labels_from_indices(triangle_indices, len(points))
    families = np.asarray([_bone_family(name) for name in deform_names])
    finger = np.asarray([any(token in name for token in FINGER_BONE_TOKENS) for name in deform_names])
    nonfinger_indices = np.flatnonzero(~finger)
    if len(nonfinger_indices) < rig_builder.MAX_INFLUENCES:
        raise RuntimeError("Robot Common has too few non-finger bones for human skinning")

    assignments: list[tuple[np.ndarray, np.ndarray, str]] = []
    component_counts: dict[str, int] = {}
    vertex_counts: dict[str, int] = {}
    for component, size in enumerate(sizes):
        vertex_ids = np.flatnonzero(labels == component)
        if vertex_ids.size == 0:
            continue
        component_points = points[vertex_ids]
        center = np.median(component_points, axis=0)
        distances = _segment_distance_matrix(
            component_points,
            starts[nonfinger_indices],
            ends[nonfinger_indices],
        )
        nearest_quantile = np.quantile(distances, 0.20, axis=0)
        primary_segment = int(nonfinger_indices[int(np.argmin(nearest_quantile))])
        family = str(families[primary_segment])

        # In this source pose, the human hands rest against the upper thighs.
        # Small disconnected hand/gear islands in that narrow band are ambiguous
        # to Euclidean distance alone; assign them to the matching arm chain.
        if (
            int(size) <= 100
            and 0.42 <= float(center[1]) < 0.59
            and abs(float(center[0])) > 0.12
        ):
            family = "L_arm" if float(center[0]) > 0.0 else "R_arm"

        candidates = _candidate_bones(family, center, families, finger)
        if int(candidates.sum()) < rig_builder.MAX_INFLUENCES:
            candidates = ~finger
        assignments.append((vertex_ids, candidates, family))
        component_counts[family] = component_counts.get(family, 0) + 1
        vertex_counts[family] = vertex_counts.get(family, 0) + int(vertex_ids.size)

    report = {
        "component_count": int(len(assignments)),
        "components_by_family": dict(sorted(component_counts.items())),
        "vertices_by_family": dict(sorted(vertex_counts.items())),
        "finger_bone_weights": 0,
    }
    return assignments, report


def _human_weight_builder(
    points: np.ndarray,
    primitive: dict[str, Any],
    js: dict[str, Any],
    bin_: bytes,
    starts: np.ndarray,
    ends: np.ndarray,
    skin_indices: np.ndarray,
    deform_names: list[str],
) -> tuple[np.ndarray, np.ndarray]:
    assignments, _report = _human_component_assignments(
        points, primitive, js, bin_, starts, ends, skin_indices, deform_names
    )
    joints = np.zeros((len(points), rig_builder.MAX_INFLUENCES), dtype=np.uint16)
    weights = np.zeros((len(points), rig_builder.MAX_INFLUENCES), dtype=np.float32)
    for vertex_ids, candidates, _family in assignments:
        local_joints, local_weights = rig_builder._weights_for_points(
            points[vertex_ids], starts[candidates], ends[candidates], skin_indices[candidates]
        )
        joints[vertex_ids] = local_joints
        weights[vertex_ids] = local_weights
    return joints, weights


def _validate_human_weighting(
    js: dict[str, Any], bin_: bytes, template_js: dict[str, Any], template_skeleton: Any
) -> dict[str, Any]:
    starts, ends, skin_indices, deform_names = rig_builder._deforming_segments(template_js, template_skeleton)
    skin_names = [js["nodes"][index].get("name", "") for index in js["skins"][0]["joints"]]
    aggregate_components: dict[str, int] = {}
    aggregate_vertices: dict[str, int] = {}
    component_count = 0
    weighted_fingers: set[str] = set()
    mesh_node = next((node for node in js["nodes"] if node.get("mesh") is not None), None)
    if mesh_node is None:
        raise RuntimeError("human runtime GLB has no mesh node")
    mesh = js["meshes"][int(mesh_node["mesh"])]
    for primitive in mesh.get("primitives", []):
        attributes = primitive.get("attributes", {})
        if "POSITION" not in attributes or "JOINTS_0" not in attributes or "WEIGHTS_0" not in attributes:
            raise RuntimeError("human mesh primitive is missing skin attributes")
        points = accessor_array(js, bin_, int(attributes["POSITION"])).astype(np.float64)
        assignments, report = _human_component_assignments(
            points, primitive, js, bin_, starts, ends, skin_indices, deform_names
        )
        joints = accessor_array(js, bin_, int(attributes["JOINTS_0"])).astype(np.int64)
        weights = accessor_array(js, bin_, int(attributes["WEIGHTS_0"])).astype(np.float64)
        if joints.shape != weights.shape or joints.shape != (len(points), rig_builder.MAX_INFLUENCES):
            raise RuntimeError("human skin joint/weight arrays have the wrong shape")
        component_count += int(report["component_count"])
        for family, value in report["components_by_family"].items():
            aggregate_components[family] = aggregate_components.get(family, 0) + int(value)
        for family, value in report["vertices_by_family"].items():
            aggregate_vertices[family] = aggregate_vertices.get(family, 0) + int(value)
        for vertex_ids, candidates, family in assignments:
            used = set(int(value) for value in joints[vertex_ids][weights[vertex_ids] > 1e-6])
            allowed = set(int(value) for value in skin_indices[candidates])
            if not used.issubset(allowed):
                raise RuntimeError(f"human {family} island contains cross-family joint weights")
            for skin_index in used:
                if any(token in skin_names[skin_index] for token in FINGER_BONE_TOKENS):
                    weighted_fingers.add(skin_names[skin_index])
    if weighted_fingers:
        raise RuntimeError(f"human mesh unexpectedly weights finger joints: {sorted(weighted_fingers)}")
    return {
        "component_count": component_count,
        "components_by_family": dict(sorted(aggregate_components.items())),
        "vertices_by_family": dict(sorted(aggregate_vertices.items())),
        "finger_bone_weights": 0,
    }


def _decorate_profile(
    variant: dict[str, Any],
    profile: dict[str, Any],
    template_js: dict,
    template_skeleton: Any,
) -> dict[str, Any]:
    profile["note"] = "Generated by tools/gltf/rig_human_hero_tiers.py; do not edit by hand."
    profile["character_role"] = "player_hero"
    profile["asset_identity"] = identity_for(variant["asset_id"])
    profile["upgrade_track_id"] = "human_operative"
    profile["upgrade_tier"] = variant["tier"]
    profile["rig_template"] = "game/assets/enemies/enemy_robot_common.glb"
    profile["rig_template_sha256"] = rig_builder._sha256(rig_builder.RIG_TEMPLATE_MODEL)

    model_js, model_bin = read_glb(variant["model"])
    weighting = profile["weighting"]
    weighting["method"] = HUMAN_WEIGHTING_METHOD
    weighting["deforming_bones"] = [
        name
        for name in weighting.get("deforming_bones", [])
        if not any(token in name for token in FINGER_BONE_TOKENS)
    ]
    weighting["excluded_finger_bone_tokens"] = list(FINGER_BONE_TOKENS)
    weighting["human_component_report"] = _validate_human_weighting(
        model_js, model_bin, template_js, template_skeleton
    )
    profile["animations"] = (
        "Generated separately by tools/gltf/retarget_human_hero_tiers.py from Robot Common's "
        "animation set plus raise/lower weapon transitions."
    )
    return profile


def _validate_variant(
    variant: dict[str, Any],
    template_js: dict,
    template_skeleton: Any,
    require_animation_clips: bool = True,
) -> dict[str, Any]:
    if not variant["model"].is_file() or not variant["rig"].is_file():
        raise RuntimeError("rigged GLB or rig profile is missing")
    js, bin_ = read_glb(variant["model"])
    clips = js.get("animations", [])
    validation_js = copy.deepcopy(js)
    validation_js["animations"] = []
    checks = rig_builder._validate_variant(
        variant, validation_js, bin_, template_js, template_skeleton
    )
    if checks["joint_count"] != 79:
        raise RuntimeError(f"expected 79 copied joints, got {checks['joint_count']}")
    if require_animation_clips and not clips:
        raise RuntimeError("final hero GLB has no animation clips")

    profile = json.loads(variant["rig"].read_text(encoding="utf-8"))
    validate_profile_identity(profile, variant["asset_id"])
    expected_hashes = {
        "source_model_sha256": rig_builder._sha256(variant["source"]),
        "optimized_mesh_sha256": rig_builder._sha256(variant["optimized"]),
        "rig_template_sha256": rig_builder._sha256(rig_builder.RIG_TEMPLATE_MODEL),
    }
    for field, expected in expected_hashes.items():
        if profile.get(field) != expected:
            raise RuntimeError(f"rig profile has stale {field}")
    if profile.get("verification") != checks:
        raise RuntimeError("stored skin/bind/deformation report differs from the current GLB")
    weighting = profile.get("weighting", {})
    if weighting.get("method") != HUMAN_WEIGHTING_METHOD:
        raise RuntimeError("rig profile does not document component-aware human skin weights")
    if weighting.get("excluded_finger_bone_tokens") != list(FINGER_BONE_TOKENS):
        raise RuntimeError("rig profile does not document the human finger-weight exclusion")
    if int(weighting.get("max_influences", 0)) != rig_builder.MAX_INFLUENCES:
        raise RuntimeError("rig profile has the wrong maximum human skin influence count")
    expected_deforming_bones = [
        name
        for name in rig_builder._deforming_segments(template_js, template_skeleton)[3]
        if not any(token in name for token in FINGER_BONE_TOKENS)
    ]
    if weighting.get("deforming_bones") != expected_deforming_bones:
        raise RuntimeError("rig profile has stale human deforming-bone metadata")
    human_report = _validate_human_weighting(js, bin_, template_js, template_skeleton)
    if weighting.get("human_component_report") != human_report:
        raise RuntimeError("stored connected-island skin report differs from the current GLB")
    if profile.get("character_role") != "player_hero":
        raise RuntimeError("rig profile is not classified as a player hero")
    if profile.get("upgrade_track_id") != "human_operative":
        raise RuntimeError("rig profile has the wrong shared hero upgrade track")
    if int(profile.get("upgrade_tier", 0)) != variant["tier"]:
        raise RuntimeError("rig profile tier does not match the selected T model")
    return checks


def main() -> int:
    template_js, _template_bin, template_skeleton = rig_builder._load_template()
    errors: list[str] = []
    for variant in VARIANTS:
        try:
            if CHECK_ONLY:
                checks = _validate_variant(variant, template_js, template_skeleton)
            else:
                if not variant["optimized"].is_file():
                    raise RuntimeError(f"optimized mesh missing: {variant['optimized']}")
                if not variant["source"].is_file():
                    raise RuntimeError(f"preserved source mesh missing: {variant['source']}")
                profile = rig_builder._build_variant(
                    variant,
                    template_js,
                    _template_bin,
                    template_skeleton,
                    weight_builder=_human_weight_builder,
                )
                variant["rig"].write_text(
                    json.dumps(
                        _decorate_profile(variant, profile, template_js, template_skeleton),
                        indent=2,
                    )
                    + "\n",
                    encoding="utf-8",
                )
                # Re-read and validate exactly what will be passed to the animation step.
                checks = _validate_variant(
                    variant, template_js, template_skeleton, require_animation_clips=False
                )
            print(
                f"T{variant['tier']}: {checks['joint_count']} shared joints · "
                f"{checks['vertex_count']:,} weighted vertices · "
                f"bind error {checks['bind_pose_max_error_m']:.2e}m · "
                "Robot Common deformation probes pass"
            )
        except (OSError, ValueError, RuntimeError, KeyError) as error:
            errors.append(f"T{variant['tier']}: {error}")
    for error in errors:
        print(f"ERROR: {error}", file=sys.stderr)
    return 1 if errors else 0


if __name__ == "__main__":
    raise SystemExit(main())
