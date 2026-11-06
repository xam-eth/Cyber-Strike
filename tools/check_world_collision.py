#!/usr/bin/env python3
"""check_world_collision.py -- pre-CI replication of collision_integrity_smoke.

The smoke test casts a 27-ray multi-axis grid through each solid placement's
AABB in-engine and demands its own collider blocks at least one ray. This
checker replays the exact grid against the exported GLB triangles (the same
geometry the runtime trimesh is built from), so a geometry pass that thins a
lattice into ray-threadable wreckage is caught before CI.

Usage: python3 tools/check_world_collision.py [--models game/assets/world/aetherfall/models]
"""
import argparse
import json
import struct
import sys
from pathlib import Path

import numpy as np

ROOT = Path(__file__).resolve().parents[1]

# Mirrors tests/collision_integrity_smoke.gd (ray-checked solids). Keys match
# measurements.json entries; kit assets live under models/, family assets in
# sibling family directories (ice_planet/, archive/, ...).
RAY_SOLIDS = [
    "models/terrain_chunk",
    "models/cliff_face",
    "models/rock_boulder",
    "models/energy_core",
    "models/debris_cluster",
    "models/railing",  # body-only in the smoke (ring); checked here as well -- harmless
]
ICE_PLANET = [
    "ice_planet/glacier_shelf",
    "ice_planet/frozen_spire",
    "ice_planet/cryo_pylon",
]


def read_glb(path: Path):
    data = path.read_bytes()
    assert data[:4] == b"glTF", path
    off = 12
    json_chunk = None
    bin_chunk = None
    while off < len(data):
        clen, ctype = struct.unpack_from("<II", data, off)
        off += 8
        chunk = data[off : off + clen]
        off += clen
        if ctype == 0x4E4F534A:
            json_chunk = json.loads(chunk)
        elif ctype == 0x004E4942:
            bin_chunk = chunk
    return json_chunk, bin_chunk


def collect_triangles(gltf, bin_chunk):
    """World-space triangles of every mesh instance (node transforms applied)."""
    meshes = gltf.get("meshes", [])
    nodes = gltf.get("nodes", [])
    accessors = gltf.get("accessors", [])
    views = gltf.get("bufferViews", [])
    tris = []

    def mat_of(node):
        m = np.eye(4)
        if "matrix" in node:
            m = np.array(node["matrix"], dtype=np.float64).reshape(4, 4, order="F")
        else:
            if "translation" in node:
                t = np.eye(4)
                t[:3, 3] = node["translation"]
                m = m @ t
            if "rotation" in node:
                x, y, z, w = node["rotation"]
                r = np.eye(4)
                r[:3, :3] = np.array(
                    [
                        [1 - 2 * (y * y + z * z), 2 * (x * y - z * w), 2 * (x * z + y * w)],
                        [2 * (x * y + z * w), 1 - 2 * (x * x + z * z), 2 * (y * z - x * w)],
                        [2 * (x * z - y * w), 2 * (y * z + x * w), 1 - 2 * (x * x + y * y)],
                    ]
                )
                m = m @ r
            if "scale" in node:
                s = np.eye(4)
                s[0, 0], s[1, 1], s[2, 2] = node["scale"]
                m = m @ s
        return m

    def acc_vec3(idx):
        acc = accessors[idx]
        view = views[acc.get("bufferView", 0)]
        off = view.get("byteOffset", 0) + acc.get("byteOffset", 0)
        n = acc["count"]
        arr = np.frombuffer(bin_chunk, dtype="<f4", count=n * 3, offset=off)
        return arr.reshape(n, 3)

    def walk(node_idx, parent):
        node = nodes[node_idx]
        m = parent @ mat_of(node)
        if "mesh" in node:
            for prim in meshes[node["mesh"]].get("primitives", []):
                pos = acc_vec3(prim["attributes"]["POSITION"]) @ m[:3, :3].T + m[:3, 3]
                if "indices" in prim:
                    acc = accessors[prim["indices"]]
                    view = views[acc.get("bufferView", 0)]
                    ioff = view.get("byteOffset", 0) + acc.get("byteOffset", 0)
                    fmt = {5121: "<u1", 5123: "<u2", 5125: "<u4"}[acc["componentType"]]
                    idx = np.frombuffer(bin_chunk, dtype=fmt, count=acc["count"], offset=ioff)
                else:
                    idx = np.arange(len(pos), dtype=np.uint32)
                tris.append(pos[idx.reshape(-1, 3)])
        for child in node.get("children", []):
            walk(child, m)

    roots = set(range(len(nodes)))
    for node in nodes:
        for child in node.get("children", []):
            roots.discard(child)
    for r in sorted(roots):
        walk(r, np.eye(4))
    return np.concatenate(tris, axis=0) if tris else np.zeros((0, 3, 3))


def ray_hits(tris, origin, to):
    """Count segment-triangle intersections (Möller–Trumbore, double-sided)."""
    d = to - origin
    v0, v1, v2 = tris[:, 0], tris[:, 1], tris[:, 2]
    e1, e2 = v1 - v0, v2 - v0
    pv = np.cross(d, e2)
    det = np.einsum("ij,ij->i", e1, pv)
    ok = np.abs(det) > 1e-12
    inv = np.zeros_like(det)
    inv[ok] = 1.0 / det[ok]
    tv = origin - v0
    u = np.einsum("ij,ij->i", tv, pv) * inv
    qv = np.cross(tv, e1)
    v = np.einsum("j,ij->i", d, qv) * inv
    t = np.einsum("ij,ij->i", e2, qv) * inv
    hit = ok & (u >= -1e-6) & (v >= -1e-6) & (u + v <= 1 + 1e-6) & (t >= -1e-6) & (t <= 1 + 1e-6)
    return int(np.count_nonzero(hit))


def grid_hits(tris):
    """The smoke's exact 27-ray grid through the combined AABB.

    Returns the number of DISTINCT rays (of 27) that intersect the geometry --
    the smoke asserts >= 1.
    """
    pts = tris.reshape(-1, 3)
    lo = pts.min(axis=0)
    hi = pts.max(axis=0)
    size = hi - lo
    center = (lo + hi) / 2
    rays_hit = 0
    for axis in range(3):
        for i1 in range(-1, 2):
            for i2 in range(-1, 2):
                offset = np.zeros(3)
                if axis == 0:
                    offset = np.array([size[0] * 0.32 * i1, 0.0, size[2] * 0.32 * i2])
                    frm = center + offset + np.array([0.0, size[1] * 0.5 + 2.0, 0.0])
                    to = center + offset - np.array([0.0, size[1] * 0.5 + 2.0, 0.0])
                elif axis == 1:
                    offset = np.array([0.0, size[1] * 0.32 * i1, size[2] * 0.32 * i2])
                    frm = center + offset + np.array([size[0] * 0.5 + 2.0, 0.0, 0.0])
                    to = center + offset - np.array([size[0] * 0.5 + 2.0, 0.0, 0.0])
                else:
                    offset = np.array([size[0] * 0.32 * i1, size[1] * 0.32 * i2, 0.0])
                    frm = center + offset + np.array([0.0, 0.0, size[2] * 0.5 + 2.0])
                    to = center + offset - np.array([0.0, 0.0, size[2] * 0.5 + 2.0])
                if ray_hits(tris, frm, to) > 0:
                    rays_hit += 1
    return rays_hit


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--models", default=str(ROOT / "game/assets/world/aetherfall"))
    args = ap.parse_args()
    models = Path(args.models)

    failures = []
    targets = RAY_SOLIDS + ICE_PLANET
    for name in targets:
        path = models / f"{name}.glb"
        if not path.exists():
            failures.append(f"{name}: missing {path}")
            continue
        gltf, bin_chunk = read_glb(path)
        tris = collect_triangles(gltf, bin_chunk)
        if len(tris) < 4:
            failures.append(f"{name}: too few triangles ({len(tris)})")
            continue
        hits = grid_hits(tris)
        status = "OK " if hits >= 1 else "FAIL"
        if hits < 1:
            failures.append(f"{name}: 0/27 rays blocked (ray-threadable geometry)")
        print(f"{status} {name}: {len(tris)} tris, {hits}/27 rays blocked")

    if failures:
        print(f"\nCOLLISION CHECK FAILED ({len(failures)}):")
        for f in failures:
            print(f"  - {f}")
        return 1
    print(f"\nCOLLISION CHECK PASSED ({len(targets)} assets)")
    return 0


if __name__ == "__main__":
    sys.exit(main())
