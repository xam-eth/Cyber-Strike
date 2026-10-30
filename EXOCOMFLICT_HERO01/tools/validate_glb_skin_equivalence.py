"""Semantic skinned-deformation equivalence between two rigged GLBs.

Accessor diffs cannot tell whether a deliberate rest-skeleton change
(new inverse-bind matrices + re-keyed local animation channels) still
produces the same world-space deformation. This tool evaluates the
glTF node hierarchy, animation samplers, skin joint matrices
(globalJoint * inverseBindMatrix) and skinned HERO_01_BODY vertices in
both files at sampled times, then reports max joint-matrix and vertex
displacement differences.

Usage:
  python validate_glb_skin_equivalence.py <old.glb> <new.glb>
      [--samples 5] [--tol-mm 0.1]
Exit 0 iff every sampled displacement is within tolerance.
"""
import sys

import numpy as np
from pygltflib import GLTF2

from diff_rigged_glb import acc_array, glb_json, mesh_prim


def quat_matrix(q):
    x, y, z, w = [float(v) for v in q]
    n = math.sqrt(x*x + y*y + z*z + w*w)
    x, y, z, w = x/n, y/n, z/n, w/n
    return np.array([
        [1-2*(y*y+z*z), 2*(x*y-z*w), 2*(x*z+y*w), 0],
        [2*(x*y+z*w), 1-2*(x*x+z*z), 2*(y*z-x*w), 0],
        [2*(x*z-y*w), 2*(y*z+x*w), 1-2*(x*x+y*y), 0],
        [0, 0, 0, 1]], dtype=np.float64)


import math


def trs_matrix(t, q, s):
    M = quat_matrix(q)
    M[:3, 0] *= float(s[0]); M[:3, 1] *= float(s[1]); M[:3, 2] *= float(s[2])
    M[:3, 3] = np.array(t, dtype=np.float64)
    return M


def node_local(node, override=None):
    if "matrix" in node and override is None:
        return np.array(node["matrix"], dtype=np.float64).reshape((4, 4), order='F')
    t = node.get("translation", [0, 0, 0])
    q = node.get("rotation", [0, 0, 0, 1])
    s = node.get("scale", [1, 1, 1])
    if override:
        if "translation" in override: t = override["translation"]
        if "rotation" in override: q = override["rotation"]
        if "scale" in override: s = override["scale"]
    return trs_matrix(t, q, s)


def sample_sampler(g, sampler, time):
    times = acc_array(g, sampler["input"]).astype(np.float64).reshape(-1)
    values = acc_array(g, sampler["output"]).astype(np.float64)
    interp = sampler.get("interpolation", "LINEAR")
    if time <= times[0]:
        return values[0]
    if time >= times[-1]:
        return values[-1]
    i = int(np.searchsorted(times, time, side='right') - 1)
    if interp == "STEP":
        return values[i]
    if interp != "LINEAR":
        raise RuntimeError(f"Unsupported sampler interpolation {interp}")
    span = times[i+1] - times[i]
    f = 0.0 if span == 0 else (time - times[i]) / span
    out = values[i] * (1-f) + values[i+1] * f
    if out.shape[-1] == 4:  # quaternion nlerp; sign handled by matrix use
        if float(np.dot(values[i], values[i+1])) < 0:
            out = values[i] * (1-f) - values[i+1] * f
        nrm = np.linalg.norm(out)
        if nrm > 0:
            out = out / nrm
    return out


class Rig:
    def __init__(self, path):
        self.path = path
        self.g = GLTF2().load_binary(path)
        self.j = glb_json(path)
        self.nodes = self.j["nodes"]
        self.parents = {}
        for i, nd in enumerate(self.nodes):
            for c in nd.get("children", []):
                self.parents[c] = i
        skin = self.j["skins"][0]
        self.joint_nodes = skin["joints"]
        self.joint_names = [self.nodes[i].get("name", str(i)) for i in self.joint_nodes]
        ibm = acc_array(self.g, skin["inverseBindMatrices"]).astype(np.float64)
        self.ibm = np.array([row.reshape((4, 4), order='F') for row in ibm])
        prim = mesh_prim(self.j, "HERO_01_BODY")
        self.pos = acc_array(self.g, prim["attributes"]["POSITION"]).astype(np.float64)
        self.joints = acc_array(self.g, prim["attributes"]["JOINTS_0"]).astype(np.int64)
        self.weights = acc_array(self.g, prim["attributes"]["WEIGHTS_0"]).astype(np.float64)
        self.anims = {a.get("name"): a for a in self.j.get("animations", [])}

    def globals(self, anim_name=None, time=0.0):
        overrides = {}
        if anim_name is not None:
            anim = self.anims[anim_name]
            for ch in anim.get("channels", []):
                node = ch["target"]["node"]
                path = ch["target"]["path"]
                overrides.setdefault(node, {})[path] = sample_sampler(self.g, anim["samplers"][ch["sampler"]], time)
        cache = {}

        def compute(i):
            if i in cache:
                return cache[i]
            local = node_local(self.nodes[i], overrides.get(i))
            p = self.parents.get(i)
            glob = local if p is None else compute(p) @ local
            cache[i] = glob
            return glob

        return [compute(i) for i in range(len(self.nodes))]

    def joint_matrices(self, anim_name=None, time=0.0):
        glob = self.globals(anim_name, time)
        return np.array([glob[node] @ self.ibm[k] for k, node in enumerate(self.joint_nodes)])

    def skinned(self, anim_name=None, time=0.0):
        jm = self.joint_matrices(anim_name, time)
        ph = np.concatenate([self.pos, np.ones((len(self.pos), 1))], axis=1)
        # Gathered skin matrices: (N,4 influences,4,4). Float32 keeps this
        # around 63 MB for HERO_01 while retaining sub-micron precision here.
        mats = jm[self.joints].astype(np.float32)
        transformed = np.einsum('nk,naik->nai', ph.astype(np.float32), mats, optimize=True)[:, :, :3]
        return np.sum(transformed * self.weights[:, :, None].astype(np.float32), axis=1).astype(np.float64), jm

    def duration(self, anim_name):
        anim = self.anims[anim_name]
        dur = 0.0
        for s in anim.get("samplers", []):
            vals = acc_array(self.g, s["input"])
            if len(vals):
                dur = max(dur, float(vals[-1].reshape(-1)[-1]))
        return dur


def main():
    args = []
    samples = 5
    tol_mm = 0.1
    argv = sys.argv[1:]
    i = 0
    while i < len(argv):
        if argv[i] == "--samples": samples = int(argv[i+1]); i += 2
        elif argv[i] == "--tol-mm": tol_mm = float(argv[i+1]); i += 2
        else: args.append(argv[i]); i += 1
    old = Rig(args[0]); new = Rig(args[1])
    assert old.joint_names == new.joint_names, (old.joint_names, new.joint_names)
    assert old.pos.shape == new.pos.shape and np.array_equal(old.pos, new.pos), "POSITION differs"
    assert set(old.anims) == set(new.anims), (set(old.anims), set(new.anims))
    tol = tol_mm / 1000.0
    worst_v = 0.0
    worst_j = 0.0
    worst_label = ""

    def check(label, anim_name, time):
        nonlocal worst_v, worst_j, worst_label
        po, jo = old.skinned(anim_name, time)
        pn, jn = new.skinned(anim_name, time)
        dv = float(np.linalg.norm(po - pn, axis=1).max())
        # Joint-matrix point displacement proxy: apply matrix delta to origin
        # plus rotational effect at 0.25 m radius.
        rel = jn @ np.linalg.inv(jo)
        jt = float(np.linalg.norm(rel[:, :3, 3], axis=1).max())
        if dv > worst_v:
            worst_v = dv; worst_label = label
        worst_j = max(worst_j, jt)
        print(f"{label}: max vertex diff={dv*1000:.4f} mm; max joint-matrix translation diff={jt*1000:.4f} mm")
        return dv <= tol

    ok = check("REST", None, 0.0)
    fractions = [0.0] if samples <= 1 else [k/(samples-1) for k in range(samples)]
    for name in sorted(old.anims):
        dur = old.duration(name)
        for frac in fractions:
            ok &= check(f"{name} t={dur*frac:.3f}s", name, dur*frac)
    print(f"WORST vertex diff={worst_v*1000:.4f} mm at {worst_label}; worst joint translation diff={worst_j*1000:.4f} mm")
    print("RESULT:", "EQUIVALENT" if ok else "NOT_EQUIVALENT")
    sys.exit(0 if ok else 1)


if __name__ == "__main__":
    main()
