#!/usr/bin/env python3
"""Audit Aetherfall's assembled layout using conservative world-space AABBs.

This is a composition diagnostic, not collision, navigation, render, or art-quality
proof. It reads the same assembly JSON files used by ``scripts/aetherfall.gd`` and
GLB POSITION-accessor bounds, applies each placement's yaw, and fails only on a
small set of formerly-clashing landmark pairs.  Intentional nested assembly is
recorded in the accompanying layout-review document rather than silently ignored.

Run from the repository root:
    python3 tools/qa/audit_aetherfall_layout.py
"""

from __future__ import annotations

import json
import math
import struct
from functools import lru_cache
from pathlib import Path
from typing import Any

ROOT = Path(__file__).resolve().parents[2]
ASSET_ROOT = ROOT / "assets/world/aetherfall"

# These pairs must remain spatially separate. A failure means their *conservative*
# rotated GLB AABBs share at least 1 square metre in plan and 0.3 m in height.
# Intended integrations are documented in docs/world/aetherfall/layout_review/.
CLEARANCE_PAIRS = (
    ("sentinel_archive_exterior", "west_refinery_stack"),
    ("sentinel_archive_exterior", "east_refinery_stack"),
    ("sentinel_archive_exterior", "horizon_relay_annex"),
    ("sentinel_archive_exterior", "east_service_hangar"),
    ("sentinel_archive_exterior", "west_raised_ops_deck"),
    ("sentinel_archive_exterior", "archive_west_berm"),
    ("west_glacier_wall", "west_outer_glacier"),
    ("east_glacier_wall", "east_outer_glacier"),
    ("west_glacier_wall", "west_refinery_stack"),
    ("east_glacier_wall", "east_refinery_stack"),
    ("east_refinery_stack", "east_service_hangar"),
    ("west_raised_ops_deck", "west_basin_ice_terrace"),
    ("horizon_relay_annex", "east_service_hangar"),
)


def identity() -> list[list[float]]:
    return [[1.0, 0.0, 0.0, 0.0], [0.0, 1.0, 0.0, 0.0], [0.0, 0.0, 1.0, 0.0], [0.0, 0.0, 0.0, 1.0]]


def multiply(a: list[list[float]], b: list[list[float]]) -> list[list[float]]:
    return [[sum(a[row][k] * b[k][col] for k in range(4)) for col in range(4)] for row in range(4)]


def node_matrix(node: dict[str, Any]) -> list[list[float]]:
    if "matrix" in node:
        # glTF stores matrices in column-major order.
        values = node["matrix"]
        return [[values[row + 4 * column] for column in range(4)] for row in range(4)]

    x, y, z, w = node.get("rotation", [0.0, 0.0, 0.0, 1.0])
    sx, sy, sz = node.get("scale", [1.0, 1.0, 1.0])
    tx, ty, tz = node.get("translation", [0.0, 0.0, 0.0])
    return [
        [(1 - 2 * y * y - 2 * z * z) * sx, (2 * x * y - 2 * z * w) * sy, (2 * x * z + 2 * y * w) * sz, tx],
        [(2 * x * y + 2 * z * w) * sx, (1 - 2 * x * x - 2 * z * z) * sy, (2 * y * z - 2 * x * w) * sz, ty],
        [(2 * x * z - 2 * y * w) * sx, (2 * y * z + 2 * x * w) * sy, (1 - 2 * x * x - 2 * y * y) * sz, tz],
        [0.0, 0.0, 0.0, 1.0],
    ]


def transform_point(matrix: list[list[float]], point: list[float]) -> tuple[float, float, float]:
    values = [sum(matrix[row][column] * (point[column] if column < 3 else 1.0) for column in range(4)) for row in range(3)]
    return values[0], values[1], values[2]


@lru_cache(maxsize=None)
def local_bounds(relative_glb: str) -> tuple[tuple[float, float, float], tuple[float, float, float]]:
    """Return scene bounds from POSITION accessor min/max values in a GLB."""
    payload = (ASSET_ROOT / relative_glb).read_bytes()
    magic, version, _length, json_size, json_type = struct.unpack_from("<IIIII", payload, 0)
    assert magic == 0x46546C67 and version == 2 and json_type == 0x4E4F534A, relative_glb
    gltf = json.loads(payload[20 : 20 + json_size])
    points: list[tuple[float, float, float]] = []

    def visit(node_index: int, parent: list[list[float]]) -> None:
        node = gltf["nodes"][node_index]
        world = multiply(parent, node_matrix(node))
        if "mesh" in node:
            for primitive in gltf["meshes"][node["mesh"]]["primitives"]:
                accessor = gltf["accessors"][primitive["attributes"]["POSITION"]]
                low, high = accessor["min"], accessor["max"]
                for px in (low[0], high[0]):
                    for py in (low[1], high[1]):
                        for pz in (low[2], high[2]):
                            points.append(transform_point(world, [px, py, pz]))
        for child in node.get("children", []):
            visit(child, world)

    scenes = gltf.get("scenes", [{"nodes": list(range(len(gltf["nodes"]))) }])
    for root_node in scenes[gltf.get("scene", 0)].get("nodes", []):
        visit(root_node, identity())
    assert points, f"No positioned mesh bounds in {relative_glb}"
    return tuple(min(point[axis] for point in points) for axis in range(3)), tuple(max(point[axis] for point in points) for axis in range(3))


def rotate_y_bounds(low: tuple[float, float, float], high: tuple[float, float, float], yaw_degrees: float) -> tuple[tuple[float, float, float], tuple[float, float, float]]:
    cosine, sine = math.cos(math.radians(yaw_degrees)), math.sin(math.radians(yaw_degrees))
    points = [(cosine * x + sine * z, y, -sine * x + cosine * z) for x in (low[0], high[0]) for y in (low[1], high[1]) for z in (low[2], high[2])]
    return tuple(min(point[axis] for point in points) for axis in range(3)), tuple(max(point[axis] for point in points) for axis in range(3))


def world_bounds(relative_glb: str, position: list[float], yaw_degrees: float, scale: float = 1.0) -> tuple[tuple[float, float, float], tuple[float, float, float]]:
    low, high = rotate_y_bounds(*local_bounds(relative_glb), yaw_degrees)
    return (
        tuple(position[axis] + low[axis] * scale for axis in range(3)),
        tuple(position[axis] + high[axis] * scale for axis in range(3)),
    )


def add(entries: dict[str, dict[str, Any]], identifier: str, relative_glb: str, position: list[float], yaw_degrees: float, group: str, scale: float = 1.0) -> None:
    assert identifier not in entries, f"Duplicate layout identifier: {identifier}"
    low, high = world_bounds(relative_glb, position, yaw_degrees, scale)
    entries[identifier] = {"id": identifier, "asset": relative_glb, "group": group, "low": low, "high": high}


def assembled_entries() -> dict[str, dict[str, Any]]:
    entries: dict[str, dict[str, Any]] = {}

    # The original core is included in the inventory even though this audit does
    # not treat floor/terrain attachment as a collision failure.
    layout = json.loads((ASSET_ROOT / "layout.json").read_text())
    for placement in layout["placements"]:
        add(
            entries,
            placement["name"],
            f"models/{placement['asset']}.glb",
            placement["pos"],
            placement["rot"][1],
            "core",
            placement.get("scale", 1.0),
        )

    families = (
        ("verticality.json", "vertical", "vertical/"),
        ("landmarks.json", "landmark", "landmarks/"),
        ("ice_planet_phase1.json", "ice", "ice_planet/"),
        ("phase2_cover.json", "phase2", "phase2/"),
    )
    for file_name, group, folder in families:
        for placement in json.loads((ASSET_ROOT / file_name).read_text())["placements"]:
            add(entries, placement["id"], folder + placement["asset"] + ".glb", placement["position"], placement.get("rotation_degrees", [0.0, 0.0, 0.0])[1], group)

    archive = json.loads((ASSET_ROOT / "archive_phase3.json").read_text())
    interior = archive["interior"]
    add(entries, interior["id"], "archive/archive_vestibule.glb", interior["position"], interior["rotation_degrees"][1], "archive")
    local_computer = archive["computer"]["local_position"]
    # The interior yaw is 180°, so transform the local computer position accordingly.
    computer_position = [interior["position"][0] - local_computer[0], interior["position"][1] + local_computer[1], interior["position"][2] - local_computer[2]]
    add(entries, archive["computer"]["id"], "archive/archive_computer.glb", computer_position, 0.0, "archive")

    for interactive in json.loads((ASSET_ROOT / "stellar_horizon_slice.json").read_text())["interactives"]:
        add(entries, interactive["id"], f"interactives/{interactive['kind']}.glb", interactive["position"], interactive.get("rotation_degrees", [0.0, 0.0, 0.0])[1], "interactive")

    expanse = json.loads((ASSET_ROOT / "world_expansion.json").read_text())
    for lowland in expanse["lowland_fields"]:
        add(entries, lowland["id"], f"expanse/{lowland['asset']}.glb", lowland["position"], 0.0, "expanse")
    for shelf in expanse["shelves"]:
        add(entries, shelf["id"], f"expanse/{shelf['asset']}.glb", shelf["position"], shelf["rotation_degrees"][1], "expanse")
    return entries


def overlap(a: dict[str, Any], b: dict[str, Any]) -> tuple[float, float, float]:
    plan_x = max(0.0, min(a["high"][0], b["high"][0]) - max(a["low"][0], b["low"][0]))
    height = max(0.0, min(a["high"][1], b["high"][1]) - max(a["low"][1], b["low"][1]))
    plan_z = max(0.0, min(a["high"][2], b["high"][2]) - max(a["low"][2], b["low"][2]))
    return plan_x, height, plan_z


def main() -> None:
    entries = assembled_entries()
    failures: list[str] = []
    print(f"Aetherfall layout AABB audit: {len(entries)} authored setpieces/interactives")
    for first, second in CLEARANCE_PAIRS:
        assert first in entries and second in entries, f"Watch pair refers to an unknown placement: {first}, {second}"
        dx, dy, dz = overlap(entries[first], entries[second])
        plan_area = dx * dz
        status = "CLEAR" if plan_area < 1.0 or dy < 0.3 else "OVERLAP"
        print(f"{status:7} {first} / {second}: plan={plan_area:.2f}m2, height={dy:.2f}m")
        if status == "OVERLAP":
            failures.append(f"{first} / {second} ({plan_area:.2f}m2, {dy:.2f}m high)")
    assert not failures, "Unapproved high-risk setpiece overlap(s): " + "; ".join(failures)
    print("PASS: high-risk landmark, cover, and perimeter pairs are spatially separate by the conservative AABB rule.")


if __name__ == "__main__":
    main()
