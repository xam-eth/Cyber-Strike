#!/usr/bin/env python3
"""externalize_character_textures.py -- de-duplicate embedded character texture
maps across GLBs.

hero.glb and enemy_robot_common.glb embed three byte-identical JPEGs
(basecolor / normal / rm; sha256-verified), so the Godot importer produces TWO
copies of every .ctex in web/index.pck -- 4,654,196 bytes of pure duplication.

This tool extracts every embedded image of the given GLBs to the shared
content-addressed store ``game/assets/shared_textures/<sha256>.jpg`` (kept by
the lowest-then-first GLB), rewrites ``images[]`` to relative ``uri``
references from each GLB's own directory, and rebuilds each GLB's BIN chunk
without the image bufferViews (same surgery as
``tools/blender/bake_flagship_detail.py::externalize_images``, which is proven
by 12 bake re-exports + 0/0 Khronos validation). Geometry, materials and
accessor bytes are asserted identical before/after.

Usage:
    .venv/bin/python tools/gltf/externalize_character_textures.py \
        game/assets/characters/hero/hero.glb \
        game/assets/enemies/enemy_robot_common.glb
"""
import hashlib
import json
import os
import struct
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
STORE = os.path.join(ROOT, "game", "assets", "shared_textures")


def parse_glb(path):
    d = open(path, "rb").read()
    assert d[:4] == b"glTF", path
    jl = struct.unpack_from("<I", d, 12)[0]
    j = json.loads(d[20:20 + jl])
    # GLB chunks are 4-byte aligned and the JSON length field already covers
    # its padding, so the next chunk header sits exactly at 20 + jl. (An
    # 8-byte padding assumption here silently shifts every accessor read by
    # 4 bytes whenever jl % 8 == 4.)
    bs = 20 + jl
    if bs + 8 <= len(d) and d[bs + 4:bs + 8] == b"BIN\x00":
        bs += 8
    else:
        bs = len(d)
    return j, d, bs


def read_accessor(j, d, bs, idx):
    a = j["accessors"][idx]
    bv = j["bufferViews"][a["bufferView"]]
    off = bs + bv.get("byteOffset", 0) + a.get("byteOffset", 0)
    n = {"SCALAR": 1, "VEC2": 2, "VEC3": 3, "VEC4": 4, "MAT2": 4, "MAT3": 9, "MAT4": 16}[a["type"]]
    fmt = {5120: "b", 5121: "B", 5122: "h", 5123: "H", 5125: "I", 5126: "f"}[a["componentType"]]
    size = struct.calcsize(fmt) * n * a["count"]
    return d[off:off + size]


def externalize(glb_path):
    j, d, bs = parse_glb(glb_path)
    if not j.get("images"):
        print(f"skip (no images): {glb_path}")
        return
    before = {f"acc{i}": read_accessor(j, d, bs, i) for i in range(len(j.get("accessors", [])))}
    nodes_before = [n.get("name") for n in j.get("nodes", [])]
    mats_before = sorted(m.get("name") for m in j.get("materials", []))

    # 1. extract every embedded image to the shared sha256 store
    rel_dir = os.path.relpath(STORE, os.path.dirname(os.path.abspath(glb_path)))
    for img in j.get("images", []):
        if img.get("uri"):
            continue
        bv = j["bufferViews"][img["bufferView"]]
        off = bs + bv.get("byteOffset", 0)
        blob = d[off:off + bv["byteLength"]]
        sha = hashlib.sha256(blob).hexdigest()
        ext = "png" if blob[:8] == b"\x89PNG\r\n\x1a\n" else "jpg"
        target = os.path.join(STORE, f"{sha}.{ext}")
        if not os.path.exists(target):
            os.makedirs(STORE, exist_ok=True)
            open(target, "wb").write(blob)
        img.clear()
        img["uri"] = f"{rel_dir}/{sha}.{ext}"
        img["name"] = sha[:12]

    # 2. rebuild the BIN chunk keeping only accessor-referenced bufferViews
    used = {a["bufferView"] for a in j.get("accessors", []) if "bufferView" in a}
    new_bin = bytearray()
    remap = {}
    keep = []
    for i, bv in enumerate(j.get("bufferViews", [])):
        if i in used:
            off = len(new_bin)
            while off % 4:
                new_bin.append(0)
                off = len(new_bin)
            start = bs + bv.get("byteOffset", 0)
            new_bin += d[start:start + bv["byteLength"]]
            bv2 = dict(bv)
            bv2["byteOffset"] = off
            remap[i] = len(keep)
            keep.append(bv2)
    j["bufferViews"] = keep
    for a in j.get("accessors", []):
        if "bufferView" in a:
            a["bufferView"] = remap[a["bufferView"]]
    j["buffers"] = [{"byteLength": len(new_bin)}]

    js = json.dumps(j, separators=(",", ":")).encode()
    while len(js) % 4:
        js += b" "
    out = bytearray()
    out += b"glTF" + struct.pack("<II", 2, 12 + 8 + len(js) + 8 + len(new_bin))
    out += struct.pack("<I", len(js)) + b"JSON" + js
    out += struct.pack("<I", len(new_bin)) + b"BIN\x00" + new_bin
    open(glb_path, "wb").write(bytes(out))

    # 3. assert nothing but the image plumbing changed
    j2, d2, bs2 = parse_glb(glb_path)
    after = {f"acc{i}": read_accessor(j2, d2, bs2, i) for i in range(len(j2.get("accessors", [])))}
    assert before == after, f"accessor bytes changed in {glb_path}"
    assert nodes_before == [n.get("name") for n in j2.get("nodes", [])], "nodes changed"
    assert mats_before == sorted(m.get("name") for m in j2.get("materials", [])), "materials changed"
    print(f"externalized {glb_path}: {len(j2.get('images', []))} image(s) -> {rel_dir}/, "
          f"bin {len(d) - bs} -> {len(new_bin)} B")


if __name__ == "__main__":
    for p in sys.argv[1:]:
        externalize(p)
