"""Minimal glTF skeleton maths for the clip baker.

Pure standard library + numpy; no Blender, no native GL. Everything operates on
the JSON chunk of a .glb, so the result can be verified by re-reading the file.
"""
from __future__ import annotations

import json
import math
import struct
from pathlib import Path

import numpy as np

COMPONENT = {5120: ("b", 1), 5121: ("B", 1), 5122: ("h", 2), 5123: ("H", 2), 5125: ("I", 4), 5126: ("f", 4)}
NCOMP = {"SCALAR": 1, "VEC2": 2, "VEC3": 3, "VEC4": 4, "MAT4": 16}


# --------------------------------------------------------------------------- glb
def read_glb(path):
    data = Path(path).read_bytes()
    magic, version, length = struct.unpack_from("<III", data, 0)
    assert magic == 0x46546C67, "not a GLB"
    off = 12
    js, bin_ = None, b""
    while off < len(data):
        clen, ctype = struct.unpack_from("<II", data, off)
        chunk = data[off + 8 : off + 8 + clen]
        if ctype == 0x4E4F534A:
            js = json.loads(chunk.decode("utf-8"))
        elif ctype == 0x004E4942:
            bin_ = chunk
        off += 8 + clen
    return js, bin_


def write_glb(path, js, bin_):
    js_bytes = json.dumps(js, separators=(",", ":")).encode("utf-8")
    js_bytes += b" " * ((4 - len(js_bytes) % 4) % 4)
    bin_bytes = bin_ + b"\0" * ((4 - len(bin_) % 4) % 4)
    total = 12 + 8 + len(js_bytes) + 8 + len(bin_bytes)
    out = bytearray()
    out += struct.pack("<III", 0x46546C67, 2, total)
    out += struct.pack("<II", len(js_bytes), 0x4E4F534A) + js_bytes
    out += struct.pack("<II", len(bin_bytes), 0x004E4942) + bin_bytes
    Path(path).write_bytes(bytes(out))


def accessor_array(js, bin_, index):
    acc = js["accessors"][index]
    n = NCOMP[acc["type"]]
    fmt, size = COMPONENT[acc["componentType"]]
    count = acc["count"]
    if "bufferView" not in acc:
        return np.zeros((count, n), dtype=np.float64)
    bv = js["bufferViews"][acc["bufferView"]]
    base = bv.get("byteOffset", 0) + acc.get("byteOffset", 0)
    stride = bv.get("byteStride") or n * size
    if stride == n * size:
        arr = np.frombuffer(bin_, dtype="<" + fmt, count=count * n, offset=base)
        arr = arr.reshape(count, n)
    else:
        arr = np.stack(
            [np.frombuffer(bin_, dtype="<" + fmt, count=n, offset=base + i * stride) for i in range(count)]
        )
    arr = arr.astype(np.float64)
    if fmt in ("b", "B", "h", "H", "I") and acc.get("normalized"):
        arr /= float(np.iinfo(np.dtype("<" + fmt)).max)
    return arr


# ------------------------------------------------------------------ quaternions
def q_normalize(q):
    q = np.asarray(q, dtype=np.float64)
    return q / np.linalg.norm(q)


def q_mul(a, b):
    ax, ay, az, aw = a
    bx, by, bz, bw = b
    return np.array(
        [
            aw * bx + ax * bw + ay * bz - az * by,
            aw * by - ax * bz + ay * bw + az * bx,
            aw * bz + ax * by - ay * bx + az * bw,
            aw * bw - ax * bx - ay * by - az * bz,
        ]
    )


def q_conj(q):
    return np.array([-q[0], -q[1], -q[2], q[3]])


def q_rotate(q, v):
    """Rotate vector v by quaternion q."""
    u = np.array(q[:3])
    w = q[3]
    v = np.asarray(v, dtype=np.float64)
    t = 2.0 * np.cross(u, v)
    return v + w * t + np.cross(u, t)


def q_from_matrix(m):
    """Rotation matrix (3x3, columns = basis) -> quaternion."""
    m = np.asarray(m, dtype=np.float64)
    tr = m[0, 0] + m[1, 1] + m[2, 2]
    if tr > 0:
        s = math.sqrt(tr + 1.0) * 2
        w = 0.25 * s
        x = (m[2, 1] - m[1, 2]) / s
        y = (m[0, 2] - m[2, 0]) / s
        z = (m[1, 0] - m[0, 1]) / s
    elif m[0, 0] > m[1, 1] and m[0, 0] > m[2, 2]:
        s = math.sqrt(1.0 + m[0, 0] - m[1, 1] - m[2, 2]) * 2
        w = (m[2, 1] - m[1, 2]) / s
        x = 0.25 * s
        y = (m[0, 1] + m[1, 0]) / s
        z = (m[0, 2] + m[2, 0]) / s
    elif m[1, 1] > m[2, 2]:
        s = math.sqrt(1.0 + m[1, 1] - m[0, 0] - m[2, 2]) * 2
        w = (m[0, 2] - m[2, 0]) / s
        x = (m[0, 1] + m[1, 0]) / s
        y = 0.25 * s
        z = (m[1, 2] + m[2, 1]) / s
    else:
        s = math.sqrt(1.0 + m[2, 2] - m[0, 0] - m[1, 1]) * 2
        w = (m[1, 0] - m[0, 1]) / s
        x = (m[0, 2] + m[2, 0]) / s
        y = (m[1, 2] + m[2, 1]) / s
        z = 0.25 * s
    return q_normalize([x, y, z, w])


def q_matrix(q):
    x, y, z, w = q
    return np.array(
        [
            [1 - 2 * (y * y + z * z), 2 * (x * y - z * w), 2 * (x * z + y * w)],
            [2 * (x * y + z * w), 1 - 2 * (x * x + z * z), 2 * (y * z - x * w)],
            [2 * (x * z - y * w), 2 * (y * z + x * w), 1 - 2 * (x * x + y * y)],
        ]
    )


def q_slerp(a, b, t):
    a = q_normalize(a)
    b = q_normalize(b)
    d = float(np.dot(a, b))
    if d < 0:
        b = -b
        d = -d
    if d > 0.9995:
        return q_normalize(a + t * (b - a))
    theta = math.acos(max(-1.0, min(1.0, d)))
    s = math.sin(theta)
    return q_normalize(a * (math.sin((1 - t) * theta) / s) + b * (math.sin(t * theta) / s))


def q_swing(a, b):
    """Shortest-arc rotation taking unit vector a to unit vector b."""
    a = np.asarray(a, dtype=np.float64)
    b = np.asarray(b, dtype=np.float64)
    a = a / np.linalg.norm(a)
    b = b / np.linalg.norm(b)
    d = float(np.dot(a, b))
    if d > 0.999999:
        return np.array([0.0, 0.0, 0.0, 1.0])
    if d < -0.999999:
        # 180 degrees: pick any perpendicular axis
        axis = np.cross(a, [1.0, 0.0, 0.0])
        if np.linalg.norm(axis) < 1e-6:
            axis = np.cross(a, [0.0, 1.0, 0.0])
        axis /= np.linalg.norm(axis)
        return np.array([axis[0], axis[1], axis[2], 0.0])
    axis = np.cross(a, b)
    w = 1.0 + d
    q = np.array([axis[0], axis[1], axis[2], w])
    return q_normalize(q)


def q_about_axis(axis, angle):
    axis = np.asarray(axis, dtype=np.float64)
    axis = axis / np.linalg.norm(axis)
    s = math.sin(angle / 2)
    return np.array([axis[0] * s, axis[1] * s, axis[2] * s, math.cos(angle / 2)])


def basis_from_forward_up(forward, up):
    """Rotation whose -Z is `forward` and +Y is as close to `up` as possible."""
    f = np.asarray(forward, dtype=np.float64)
    f = f / np.linalg.norm(f)
    u = np.asarray(up, dtype=np.float64)
    z = -f
    x = np.cross(u, z)
    if np.linalg.norm(x) < 1e-6:
        x = np.cross([1.0, 0.0, 0.0], z)
    x = x / np.linalg.norm(x)
    y = np.cross(z, x)
    return np.column_stack([x, y, z])


# --------------------------------------------------------------------- skeleton
class Skeleton:
    """Rest pose + animated pose evaluation for one glTF document."""

    def __init__(self, js, bin_):
        self.js = js
        self.bin = bin_
        self.nodes = js["nodes"]
        self.parent = {}
        for i, node in enumerate(self.nodes):
            for child in node.get("children", []):
                self.parent[child] = i
        self.name = {node.get("name", f"node{i}"): i for i, node in enumerate(self.nodes)}
        self.rest_t = {}
        self.rest_r = {}
        self.rest_s = {}
        for i, node in enumerate(self.nodes):
            if "matrix" in node:
                m = np.array(node["matrix"], dtype=np.float64).reshape(4, 4).T  # column-major
                t = m[:3, 3]
                s = np.linalg.norm(m[:3, :3], axis=0)
                r = q_from_matrix(m[:3, :3] / s)
            else:
                t = np.array(node.get("translation", [0, 0, 0]), dtype=np.float64)
                r = np.array(node.get("rotation", [0, 0, 0, 1]), dtype=np.float64)
                s = np.array(node.get("scale", [1, 1, 1]), dtype=np.float64)
            self.rest_t[i] = t
            self.rest_r[i] = q_normalize(r)
            self.rest_s[i] = s
        self.skin = js.get("skins", [{}])[0]
        self.joints = self.skin.get("joints", [])
        self.animations = {a.get("name", f"clip{i}"): a for i, a in enumerate(js.get("animations", []))}
        self._samplers = {}

    # -- animation -------------------------------------------------------
    def clip_duration(self, clip):
        a = self.animations[clip]
        end = 0.0
        for s in a["samplers"]:
            acc = self.js["accessors"][s["input"]]
            end = max(end, float(acc["max"][0]) if "max" in acc else 0.0)
        return end

    def _track(self, clip, node_index, path):
        key = (clip, node_index, path)
        if key in self._samplers:
            return self._samplers[key]
        a = self.animations[clip]
        out = None
        for ch in a["channels"]:
            tgt = ch["target"]
            if tgt.get("node") == node_index and tgt["path"] == path:
                s = a["samplers"][ch["sampler"]]
                times = accessor_array(self.js, self.bin, s["input"]).reshape(-1)
                values = accessor_array(self.js, self.bin, s["output"])
                interp = s.get("interpolation", "LINEAR")
                out = (times, values, interp)
                break
        self._samplers[key] = out
        return out

    def sample(self, clip, t):
        """Local TRS for every animated node at time t (rest when not animated)."""
        a = self.animations[clip]
        t = max(0.0, t)
        rot, tra, sca = {}, {}, {}
        for ch in a["channels"]:
            tgt = ch["target"]
            node = tgt.get("node")
            if node is None:
                continue
            s = a["samplers"][ch["sampler"]]
            times = accessor_array(self.js, self.bin, s["input"]).reshape(-1)
            values = accessor_array(self.js, self.bin, s["output"])
            n = len(times)
            if t <= times[0]:
                v = values[0]
            elif t >= times[n - 1]:
                v = values[n - 1]
            else:
                i = int(np.searchsorted(times, t) - 1)
                i = max(0, min(i, n - 2))
                span = times[i + 1] - times[i]
                u = 0.0 if span <= 1e-9 else (t - times[i]) / span
                if tgt["path"] == "rotation":
                    v = q_slerp(values[i], values[i + 1], u)
                elif tgt["path"] == "cubic" or s.get("interpolation") == "CUBICSPLINE":
                    v = values[3 * i + 1] * (1 - u) + values[3 * i + 4] * u
                else:
                    v = values[i] * (1 - u) + values[i + 1] * u
            if tgt["path"] == "rotation":
                rot[node] = q_normalize(v)
            elif tgt["path"] == "translation":
                tra[node] = v
            elif tgt["path"] == "scale":
                sca[node] = v
        return rot, tra, sca

    def pose(self, clip, t):
        """Global (rotation, position) for every node, with the clip applied."""
        rot, tra, sca = self.sample(clip, t)
        grot, gpos = {}, {}
        order = self._topological()
        for i in order:
            r = rot.get(i, self.rest_r[i])
            p = tra.get(i, self.rest_t[i])
            s = sca.get(i, self.rest_s[i])
            p = p * s
            par = self.parent.get(i)
            if par is None:
                grot[i] = q_normalize(r)
                gpos[i] = p
            else:
                grot[i] = q_normalize(q_mul(grot[par], r))
                gpos[i] = gpos[par] + q_rotate(grot[par], p)
        return grot, gpos

    def fk(self, rot, tra, sca):
        """Forward kinematics from explicit local TRS dictionaries.

        Any node missing from a dict falls back to its rest value, which is what
        the glTF spec does for channels a clip does not animate.
        """
        grot, gpos = {}, {}
        for i in self._topological():
            r = rot.get(i, self.rest_r[i])
            p = np.asarray(tra.get(i, self.rest_t[i]), dtype=np.float64) * np.asarray(
                sca.get(i, self.rest_s[i]), dtype=np.float64
            )
            par = self.parent.get(i)
            if par is None:
                grot[i] = q_normalize(r)
                gpos[i] = p
            else:
                grot[i] = q_normalize(q_mul(grot[par], r))
                gpos[i] = gpos[par] + q_rotate(grot[par], p)
        return grot, gpos

    def local_pose(self, clip, t):
        """Full local TRS dict for a clip time (rest values for unanimated nodes)."""
        rot, tra, sca = self.sample(clip, t)
        rot = {i: rot.get(i, self.rest_r[i]) for i in range(len(self.nodes))}
        tra = {i: tra.get(i, self.rest_t[i]) for i in range(len(self.nodes))}
        sca = {i: sca.get(i, self.rest_s[i]) for i in range(len(self.nodes))}
        return rot, tra, sca

    def rest_pose(self):
        grot, gpos = {}, {}
        for i in self._topological():
            par = self.parent.get(i)
            p = self.rest_t[i] * self.rest_s[i]
            if par is None:
                grot[i] = q_normalize(self.rest_r[i])
                gpos[i] = p
            else:
                grot[i] = q_normalize(q_mul(grot[par], self.rest_r[i]))
                gpos[i] = gpos[par] + q_rotate(grot[par], p)
        return grot, gpos

    def _topological(self):
        if hasattr(self, "_order"):
            return self._order
        order, stack = [], [i for i in range(len(self.nodes)) if i not in self.parent]
        stack.sort(reverse=True)
        while stack:
            i = stack.pop()
            order.append(i)
            children = sorted(self.nodes[i].get("children", []), reverse=True)
            stack.extend(children)
        self._order = order
        return order

    def bone(self, name):
        return self.name[name]


# ---------------------------------------------------------------- bin writing
class BinWriter:
    """Append typed arrays to the glTF BIN chunk and register accessors."""

    def __init__(self, js, bin_):
        self.js = js
        self.bin = bytearray(bin_)
        # buffers[0] owns the whole chunk; keep its byteLength in sync
        self.js["buffers"][0].setdefault("byteLength", len(bin_))

    def add(self, array, gltf_type, component_type, target=None, minmax=False):
        array = np.asarray(array)
        n = NCOMP[gltf_type]
        if array.ndim == 1:
            array = array.reshape(-1, n)
        flat = array.astype("<f4" if component_type == 5126 else "<u2").tobytes()
        pad = (4 - len(self.bin) % 4) % 4
        self.bin += b"\0" * pad
        offset = len(self.bin)
        self.bin += flat
        bv = {"buffer": 0, "byteOffset": offset, "byteLength": len(flat)}
        if target:
            bv["target"] = target
        self.js["bufferViews"].append(bv)
        acc = {
            "bufferView": len(self.js["bufferViews"]) - 1,
            "componentType": component_type,
            "count": int(array.shape[0]),
            "type": gltf_type,
        }
        if minmax:
            acc["min"] = [float(v) for v in array.min(axis=0)]
            acc["max"] = [float(v) for v in array.max(axis=0)]
        self.js["accessors"].append(acc)
        self.js["buffers"][0]["byteLength"] = len(self.bin)
        return len(self.js["accessors"]) - 1


def decompose(m):
    """4x4 column-major matrix -> (translation, quaternion, scale)."""
    m = np.asarray(m, dtype=np.float64).reshape(4, 4).T
    t = m[:3, 3]
    s = np.linalg.norm(m[:3, :3], axis=0)
    r = q_from_matrix(m[:3, :3] / np.where(s == 0, 1, s))
    return t, r, s
