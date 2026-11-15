#!/usr/bin/env python3
"""Normalize GLB NORMAL/TANGENT accessors in place (fixes
ACCESSOR_VECTOR3_NON_UNIT after Blender re-export in the bake pipeline).

Float32 component size is fixed, so writes are byte-safe in place.

    python3 tools/gltf/normalize_glb_normals.py game/assets/world/aetherfall/expanse/expanse_shelf.glb ...
"""
import json
import struct
import sys

import numpy as np


def fix_glb(path: str) -> int:
    d = open(path, "rb").read()
    jlen = struct.unpack_from("<I", d, 12)[0]
    j = json.loads(d[20:20 + jlen])
    bin_start = 20 + jlen + 8
    fixed = 0
    for prim_targets in [
        p.get("attributes", {}) for m in j.get("meshes", []) for p in m.get("primitives", [])
    ]:
        for attr in ("NORMAL", "TANGENT"):
            idx = prim_targets.get(attr)
            if idx is None:
                continue
            acc = j["accessors"][idx]
            if acc.get("componentType") != 5126:  # float32 only
                continue
            bv = j["bufferViews"][acc["bufferView"]]
            off = bin_start + bv.get("byteOffset", 0) + acc.get("byteOffset", 0)
            n = acc["count"]
            cn = 4 if acc["type"] == "VEC4" else 3
            arr = np.frombuffer(d, dtype=np.float32, count=n * cn, offset=off).reshape(n, cn).copy()
            xyz = arr[:, :3]
            lens = np.linalg.norm(xyz, axis=1)
            bad = np.abs(lens - 1.0) > 1e-3
            if not bad.any():
                continue
            zero = lens < 1e-6
            ok = bad & ~zero
            xyz[ok] /= lens[ok, None]
            xyz[zero] = np.array([1.0, 0.0, 0.0], np.float32)  # degenerate tri fallback
            if cn == 4:
                arr[zero, 3] = 1.0
            arr[:, :3] = xyz
            raw = arr.tobytes()
            d = d[:off] + raw + d[off + len(raw):]  # same length
            fixed += int(bad.sum())
    if fixed:
        open(path, "wb").write(d)
    return fixed


if __name__ == "__main__":
    total = 0
    for p in sys.argv[1:]:
        n = fix_glb(p)
        print(f"{p}: normalized {n} vectors")
        total += n
    print(f"total: {total}")
