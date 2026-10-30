"""Compare glTF skin-joint global rest origins between two GLB files.

This is a deliberately small, standard-library-only audit: it reads the
GLB JSON chunk, evaluates node TRS hierarchy, and prints every skin
joint whose global rest origin changed plus selected segment lengths.
It does not use Blender or the .blend file.

Usage:
  python3 compare_glb_bone_rests.py <old.glb> <new.glb>
"""
import json
import math
import struct
import sys


def glb_json(path):
    data = open(path, "rb").read()
    if data[:4] != b"glTF":
        raise ValueError(f"not a GLB: {path}")
    length, chunk_type = struct.unpack_from("<II", data, 12)
    if chunk_type != 0x4E4F534A:
        raise ValueError(f"first GLB chunk is not JSON: {path}")
    return json.loads(data[20:20 + length].decode("utf-8"))


def quat_matrix(q):
    x, y, z, w = [float(v) for v in q]
    n = math.sqrt(x*x + y*y + z*z + w*w)
    x, y, z, w = x/n, y/n, z/n, w/n
    return [
        [1-2*(y*y+z*z), 2*(x*y-z*w), 2*(x*z+y*w), 0.0],
        [2*(x*y+z*w), 1-2*(x*x+z*z), 2*(y*z-x*w), 0.0],
        [2*(x*z-y*w), 2*(y*z+x*w), 1-2*(x*x+y*y), 0.0],
        [0.0, 0.0, 0.0, 1.0],
    ]


def mul(a, b):
    return [[sum(a[i][k] * b[k][j] for k in range(4)) for j in range(4)] for i in range(4)]


def local_matrix(node):
    if "matrix" in node:
        m = node["matrix"]
        return [[float(m[c*4+r]) for c in range(4)] for r in range(4)]
    out = quat_matrix(node.get("rotation", [0, 0, 0, 1]))
    scale = node.get("scale", [1, 1, 1])
    trans = node.get("translation", [0, 0, 0])
    for r in range(3):
        for c in range(3):
            out[r][c] *= float(scale[c])
        out[r][3] = float(trans[r])
    return out


def joint_origins(path):
    doc = glb_json(path)
    nodes = doc["nodes"]
    parents = {}
    for i, node in enumerate(nodes):
        for child in node.get("children", []):
            parents[child] = i
    cache = {}

    def global_matrix(i):
        if i not in cache:
            local = local_matrix(nodes[i])
            cache[i] = mul(global_matrix(parents[i]), local) if i in parents else local
        return cache[i]

    origins = {}
    for joint in doc["skins"][0]["joints"]:
        name = nodes[joint].get("name", str(joint))
        m = global_matrix(joint)
        origins[name] = tuple(float(m[r][3]) for r in range(3))
    return origins


def dist(a, b):
    return math.sqrt(sum((a[i] - b[i]) ** 2 for i in range(3)))


def fmt(v):
    return "(%.4f, %.4f, %.4f)" % v


def main():
    if len(sys.argv) != 3:
        raise SystemExit(__doc__)
    old = joint_origins(sys.argv[1])
    new = joint_origins(sys.argv[2])
    if set(old) != set(new):
        raise SystemExit(f"joint name sets differ: old-only={set(old)-set(new)} new-only={set(new)-set(old)}")
    changed = []
    for name in old:
        d = dist(old[name], new[name])
        if d > 1e-7:
            changed.append((name, d))
    print(f"skin joints compared: {len(old)}")
    print(f"global-rest origins changed: {len(changed)}")
    for name, d in changed:
        print(f" {name}: old={fmt(old[name])} new={fmt(new[name])} delta={d:.4f}")
    for label, origins in (("OLD", old), ("NEW", new)):
        print(f"{label} Forearm_L segment (Forearm_L->Hand_L): {dist(origins['Forearm_L'], origins['Hand_L']):.4f}")
        print(f"{label} Forearm_R segment (Forearm_R->Hand_R): {dist(origins['Forearm_R'], origins['Hand_R']):.4f}")
        print(f"{label} Hand_L origin: {fmt(origins['Hand_L'])}")


if __name__ == "__main__":
    main()
