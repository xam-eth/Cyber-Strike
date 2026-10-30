"""Accessor-level diff of the HERO_01_BODY primitive between two rigged GLBs.

Proves whether an additive change (e.g. the script-43 undersuit mesh or new
Phase-1 animations) left the original body geometry/weights, skin inverse-bind
matrices, body material, and pre-existing animation data intact.

Body/skin/material comparisons are always exact. Animation channels are
compared semantically by (target node name, path), never by sampler index.
By default animation arrays must also be exact; pass --anim-tol to allow a
documented floating-point re-export tolerance (Phase-1 multi-action export
moved the legacy clip by <=4.8e-07, i.e. float32 epsilon scale).

Usage:
  python diff_rigged_glb.py <old.glb> <new.glb> [--mesh HERO_01_BODY] [--anim-tol 1e-6]
Exit code 0 = body exact and old animations exact/within stated tolerance.
"""
import json
import struct
import sys

import numpy as np
from pygltflib import GLTF2

DT = {5126: np.float32, 5123: np.uint16, 5125: np.uint32, 5121: np.uint8, 5120: np.int8, 5122: np.int16}
NCOMP = {"SCALAR": 1, "VEC2": 2, "VEC3": 3, "VEC4": 4, "MAT4": 16}


def glb_json(path):
    data = open(path, "rb").read()
    assert data[:4] == b"glTF", path
    clen, ctype = struct.unpack_from("<II", data, 12)
    assert ctype == 0x4E4F534A, path
    return json.loads(data[20 : 20 + clen].decode("utf-8"))


def acc_array(g, idx):
    a = g.accessors[idx]
    bv = g.bufferViews[a.bufferView]
    blob = g.binary_blob()
    dt = DT[a.componentType]
    ncomp = NCOMP[a.type]
    start = (bv.byteOffset or 0) + (a.byteOffset or 0)
    itemsize = np.dtype(dt).itemsize
    if bv.byteStride and bv.byteStride != ncomp * itemsize:
        return np.ndarray(
            shape=(a.count, ncomp), dtype=dt, buffer=blob,
            offset=start, strides=(bv.byteStride, itemsize),
        ).copy()
    return np.frombuffer(blob, dtype=dt, count=a.count * ncomp, offset=start).reshape(a.count, ncomp)


def mesh_prim(gltf_json, name):
    for m in gltf_json.get("meshes", []):
        if m.get("name") == name:
            return m["primitives"][0]
    raise KeyError(name)


def channel_map(g, gltf_json, anim):
    out = {}
    for ch in anim.get("channels", []):
        s = anim["samplers"][ch["sampler"]]
        key = (gltf_json["nodes"][ch["target"]["node"]]["name"], ch["target"]["path"])
        out[key] = (s.get("interpolation", "LINEAR"), acc_array(g, s["input"]), acc_array(g, s["output"]))
    return out


def main():
    mesh_name = "HERO_01_BODY"
    anim_tol = 0.0
    args = []
    argv = sys.argv[1:]
    i = 0
    while i < len(argv):
        if argv[i] == "--mesh" and i + 1 < len(argv):
            mesh_name = argv[i + 1]
            i += 2
        elif argv[i] == "--anim-tol" and i + 1 < len(argv):
            anim_tol = float(argv[i + 1])
            i += 2
        else:
            args.append(argv[i])
            i += 1
    old_p, new_p = args[0], args[1]
    go, gn = GLTF2().load_binary(old_p), GLTF2().load_binary(new_p)
    jo, jn = glb_json(old_p), glb_json(new_p)
    ok = True
    anim_exact = True

    po, pn = mesh_prim(jo, mesh_name), mesh_prim(jn, mesh_name)
    print(f"mesh {mesh_name}: old material idx={po.get('material')} new material idx={pn.get('material')}")
    for attr in ("POSITION", "NORMAL", "TEXCOORD_0", "JOINTS_0", "WEIGHTS_0"):
        ao = acc_array(go, po["attributes"][attr])
        an = acc_array(gn, pn["attributes"][attr])
        eq = ao.shape == an.shape and bool(np.array_equal(ao, an))
        maxd = float(np.abs(ao.astype(np.float64) - an.astype(np.float64)).max()) if ao.shape == an.shape else -1
        print(f" {attr}: shape {ao.shape} vs {an.shape} identical={eq} max_abs_diff={maxd}")
        ok &= eq
    io = acc_array(go, po["indices"])
    inew = acc_array(gn, pn["indices"])
    eq = io.shape == inew.shape and bool(np.array_equal(io, inew))
    print(f" INDICES: shape {io.shape} vs {inew.shape} identical={eq}")
    ok &= eq

    mo = jo["materials"][po["material"]]
    mn = jn["materials"][pn["material"]]
    eq = mo == mn
    print(f" body MATERIAL json identical={eq} name old={mo.get('name')} new={mn.get('name')}")
    if not eq:
        print("  old:", json.dumps(mo, sort_keys=True)[:500])
        print("  new:", json.dumps(mn, sort_keys=True)[:500])
    ok &= eq

    so, sn = jo["skins"][0], jn["skins"][0]
    names_o = [jo["nodes"][j]["name"] for j in so["joints"]]
    names_n = [jn["nodes"][j]["name"] for j in sn["joints"]]
    eq_names = names_o == names_n
    ibm_o = acc_array(go, so["inverseBindMatrices"])
    ibm_n = acc_array(gn, sn["inverseBindMatrices"])
    eq_ibm = ibm_o.shape == ibm_n.shape and bool(np.array_equal(ibm_o, ibm_n))
    print(f" skin joints identical={eq_names} ({len(names_o)} vs {len(names_n)}); IBM identical={eq_ibm}")
    ok &= eq_names and eq_ibm

    ao_list = {a.get("name"): a for a in jo.get("animations", [])}
    an_list = {a.get("name"): a for a in jn.get("animations", [])}
    print(f" animations old={list(ao_list)} new={list(an_list)} anim_tol={anim_tol:g}")
    for name in ao_list:
        a_old, a_new = ao_list[name], an_list.get(name)
        if a_new is None:
            print(f"  {name}: MISSING in new")
            ok = False
            anim_exact = False
            continue
        mo_ch = channel_map(go, jo, a_old)
        mn_ch = channel_map(gn, jn, a_new)
        same_keys = set(mo_ch) == set(mn_ch)
        exact_differing = 0
        tol_bad = 0
        max_in = 0.0
        max_out = 0.0
        if same_keys:
            for key in mo_ch:
                io_interp, xo, yo = mo_ch[key]
                in_interp, xn, yn = mn_ch[key]
                exact = (io_interp == in_interp and xo.shape == xn.shape and yo.shape == yn.shape
                         and np.array_equal(xo, xn) and np.array_equal(yo, yn))
                if not exact:
                    exact_differing += 1
                if io_interp != in_interp or xo.shape != xn.shape or yo.shape != yn.shape:
                    tol_bad += 1
                    continue
                di = float(np.abs(xo.astype(np.float64) - xn.astype(np.float64)).max()) if xo.size else 0.0
                do = float(np.abs(yo.astype(np.float64) - yn.astype(np.float64)).max()) if yo.size else 0.0
                max_in = max(max_in, di)
                max_out = max(max_out, do)
                if di > anim_tol or do > anim_tol:
                    tol_bad += 1
        else:
            tol_bad = 1
        anim_exact &= same_keys and exact_differing == 0
        print(f"  {name}: channels {len(mo_ch)} vs {len(mn_ch)}; exact_differing={exact_differing}; "
              f"max_input_diff={max_in:.3g}; max_output_diff={max_out:.3g}; within_tol={same_keys and tol_bad == 0}")
        ok &= same_keys and tol_bad == 0

    print(f" meshes old={[m.get('name') for m in jo.get('meshes', [])]}")
    print(f" meshes new={[m.get('name') for m in jn.get('meshes', [])]}")
    print(f" materials old={[m.get('name') for m in jo.get('materials', [])]}")
    print(f" materials new={[m.get('name') for m in jn.get('materials', [])]}")
    if ok and anim_exact:
        result = "IDENTICAL"
    elif ok:
        result = "COMPATIBLE_WITHIN_ANIM_TOL (body/skin/material exact)"
    else:
        result = "DIFFERENCES FOUND"
    print("RESULT:", result)
    sys.exit(0 if ok else 1)


if __name__ == "__main__":
    main()
