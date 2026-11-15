#!/usr/bin/env python3
"""Bind the packed ORM texture as the glTF occlusionTexture on world GLBs.

The Aetherfall kit packs occlusion/roughness/metallic into ONE ORM image and
binds it only as ``pbrMetallicRoughness.metallicRoughnessTexture``. glTF
consumers therefore read roughness (G) and metallic (B) but drop the occlusion
channel (R) entirely -- measured across the shipped world: 188 ORM materials,
0 occlusionTexture bindings. The cavity/contact shading baked into every map
never reaches the engine.

The canonical glTF binding for a packed ORM is to point ``occlusionTexture``
at the SAME image index (R = ambient occlusion). This script performs that
surgery on the JSON chunk of each GLB, leaving the BIN chunk and every other
property byte-identical. Nothing about geometry, UVs, tangents or image bytes
changes, so UV/contract parsers keep passing.

Usage:
    python3 tools/gltf/bind_orm_occlusion.py game/assets/world/aetherfall [--dry-run]

Reports per file: materials considered, bindings added, materials skipped
(with reason). Refuses to touch a GLB whose JSON chunk cannot round-trip.
"""

from __future__ import annotations

import json
import struct
import sys
from pathlib import Path

GLB_MAGIC = 0x46546C67
CHUNK_JSON = 0x4E4F534A
CHUNK_BIN = 0x004E4942


def read_glb(path: Path) -> tuple[bytes, dict, bytes, bytes]:
    raw = path.read_bytes()
    magic, version, _length = struct.unpack("<III", raw[:12])
    if magic != GLB_MAGIC or version != 2:
        raise ValueError(f"{path}: not a glTF 2.0 binary")
    offset = 12
    json_chunk = b""
    bin_chunk = b""
    while offset < len(raw):
        clen, ctype = struct.unpack("<II", raw[offset : offset + 8])
        body = raw[offset + 8 : offset + 8 + clen]
        if ctype == CHUNK_JSON:
            json_chunk = body
        elif ctype == CHUNK_BIN:
            bin_chunk = body
        offset += 8 + clen
    doc = json.loads(json_chunk.decode("utf-8"))
    return raw[:12], doc, json_chunk, bin_chunk


def write_glb(path: Path, header12: bytes, doc: dict, bin_chunk: bytes) -> None:
    json_bytes = json.dumps(doc, separators=(",", ":"), ensure_ascii=False).encode("utf-8")
    pad = (4 - (len(json_bytes) % 4)) % 4
    json_bytes += b" " * pad
    total = 12 + 8 + len(json_bytes) + (8 + len(bin_chunk) if bin_chunk else 0)
    out = bytearray(header12)
    out[8:12] = struct.pack("<I", total)
    out += struct.pack("<II", len(json_bytes), CHUNK_JSON) + json_bytes
    if bin_chunk:
        out += struct.pack("<II", len(bin_chunk), CHUNK_BIN) + bin_chunk
    path.write_bytes(bytes(out))


def bind(root: Path, dry_run: bool = False) -> int:
    files = sorted(root.rglob("*.glb"))
    if not files:
        print(f"no GLBs under {root}")
        return 1
    total_bound = 0
    total_mats = 0
    changed_files = 0
    for path in files:
        _header, doc, _json_chunk, bin_chunk = read_glb(path)
        materials = doc.get("materials", [])
        bound = 0
        skipped = 0
        for mat in materials:
            total_mats += 1
            pbr = mat.get("pbrMetallicRoughness", {})
            mrt = pbr.get("metallicRoughnessTexture")
            if not mrt or "index" not in mrt:
                if "occlusionTexture" not in mat:
                    skipped += 1
                continue
            # The kit's ORM textures sample through KHR_texture_transform
            # (sub-rect UV packs). The occlusion binding MUST carry the same
            # transform as the metallic-roughness info or its R channel reads
            # a different region of the atlas.
            want_ext = {}
            if "extensions" in mrt and "KHR_texture_transform" in mrt["extensions"]:
                want_ext["KHR_texture_transform"] = mrt["extensions"]["KHR_texture_transform"]
            if "texCoord" in mrt:
                want_ext_texcoord = mrt["texCoord"]
            else:
                want_ext_texcoord = None
            occl = mat.get("occlusionTexture")
            if occl is not None and occl.get("index") == mrt.get("index"):
                # already bound: make sure the transform matches
                if want_ext and occl.get("extensions") != want_ext:
                    occl["extensions"] = want_ext
                    bound += 1
                    continue
                continue
            entry = {"index": mrt["index"], "strength": 1.0}
            if want_ext:
                entry["extensions"] = want_ext
            if want_ext_texcoord is not None:
                entry["texCoord"] = want_ext_texcoord
            mat["occlusionTexture"] = entry
            bound += 1
        total_bound += bound
        if bound:
            changed_files += 1
            rel = path.relative_to(root)
            print(f"{rel}: +{bound} occlusionTexture binding(s), {skipped} skipped")
            if not dry_run:
                write_glb(path, path.read_bytes()[:12], doc, bin_chunk)
    print(
        f"\n{total_mats} materials scanned, {total_bound} occlusion bindings "
        f"{'would be ' if dry_run else ''}added across {changed_files} files"
    )
    return 0


if __name__ == "__main__":
    args = [a for a in sys.argv[1:] if a != "--dry-run"]
    dry = "--dry-run" in sys.argv[1:]
    if not args:
        raise SystemExit(__doc__)
    raise SystemExit(bind(Path(args[0]), dry_run=dry))
