"""Accessor-level diff of the HERO_01_BODY primitive between two rigged GLBs.

Proves whether an additive change (e.g. the script-43 undersuit mesh) left the
original body geometry/weights, skin inverse-bind matrices, body material, and
animation sampler data byte-identical. Usage:
  python diff_rigged_glb.py <old.glb> <new.glb> [--mesh HERO_01_BODY]
Exit code 0 = body primitive/skin/animation/material identical; 1 = differences.
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


def main():
    args = [a for a in sys.argv[1:] if not a.startswith("--mesh")]
    mesh_name = "HERO_01_BODY"
    if "--mesh" in sys.argv:
        mesh_name = sys.argv[sys.argv.index("--mesh") + 1]
        args = [a for a in args if a != mesh_name]
    old_p, new_p = args[0], args[1]
    go, gn = GLTF2().load_binary(old_p), GLTF2().load_binary(new_p)
    jo, jn = glb_json(old_p), glb_json(new_p)
    ok = True

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
    print(f" animations old={list(ao_list)} new={list(an_list)}")
    for name in ao_list:
        a_old, a_new = ao_list[name], an_list.get(name)
        if a_new is None:
            print(f"  {name}: MISSING in new")
            ok = False
            continue
        same = len(a_old["samplers"]) == len(a_new["samplers"]) and len(a_old["channels"]) == len(a_new["channels"])
        nsamp_bad = 0
        if same:
            for s_old, s_new in zip(a_old["samplers"], a_new["samplers"]):
                for key in ("input", "output"):
                    x = acc_array(go, s_old[key])
                    y = acc_array(gn, s_new[key])
                    if x.shape != y.shape or not np.array_equal(x, y):
                        nsamp_bad += 1
        print(f"  {name}: channels {len(a_old['channels'])} vs {len(a_new['channels'])}; sampler arrays differing={nsamp_bad}")
        ok &= same and nsamp_bad == 0

    print(f" meshes old={[m.get('name') for m in jo.get('meshes', [])]}")
    print(f" meshes new={[m.get('name') for m in jn.get('meshes', [])]}")
    print(f" materials old={[m.get('name') for m in jo.get('materials', [])]}")
    print(f" materials new={[m.get('name') for m in jn.get('materials', [])]}")
    print("RESULT:", "IDENTICAL" if ok else "DIFFERENCES FOUND")
    sys.exit(0 if ok else 1)


if __name__ == "__main__":
    main()
