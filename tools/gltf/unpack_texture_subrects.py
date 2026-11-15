#!/usr/bin/env python3
"""Unpack KHR_texture_transform sub-rect slots into standalone seamless tiles.

Why: sub-rect packing and tiling UVs cannot coexist. Kit materials pack their
usable tile into a canvas region (offset [0, 0.58], scale [0.42]) and address it
via KHR_texture_transform, while metric UVs run well past 1.0. Sampling then
wraps/clamps outside the packed region, which shows as streak/smear artifacts
on large surfaces (deck, hull, ice masses).

Fix: every unique (image, transform) pair is cropped to its own content-addressed
file and material slots re-point at the crop with the transform removed.
  * baked atlas assets (UV <= 1) sample identical pixels — crop(uv*s+o) is the
    same picture as uv over the crop;
  * tiling assets (UV > 1) finally get correct REPEAT sampling of the tile;
  * UVs are never modified, so the UV>1.5 kit contract stays intact;
  * orphaned canvases are pruned by tools/gltf/pack_world_textures.mjs, which
    usually frees PCK budget (crop pixels ~0.18x of the canvas).

    python3 tools/gltf/unpack_texture_subrects.py game/assets/world/aetherfall [--dry-run]
"""
import argparse
import hashlib
import json
import os
import struct
import sys

from PIL import Image

SLOTS = ("baseColorTexture", "metallicRoughnessTexture", "normalTexture",
         "occlusionTexture", "emissiveTexture")
# encode profile follows upgrade_closeup_textures.mjs: albedo q92 4:2:0,
# normal q94 4:4:4, everything else (packed ORM etc.) q96 4:4:4.
QUALITY = {"baseColorTexture": 92, "normalTexture": 94}


def parse_glb(path):
    d = open(path, "rb").read()
    jlen = struct.unpack_from("<I", d, 12)[0]
    j = json.loads(d[20:20 + jlen])
    return j, d


def glb_chunks(path, j, d):
    """Return (json_bytes_padded, bin_bytes) with the original BIN chunk."""
    jlen = struct.unpack_from("<I", d, 12)[0]
    bin_start = 20 + jlen + 8
    bin_len = struct.unpack_from("<I", d, bin_start - 4)[0]
    return d[20:20 + jlen], d[bin_start:bin_start + bin_len]


def write_glb(path, j, bin_bytes):
    jb = json.dumps(j, separators=(",", ":")).encode()
    jb += b" " * ((4 - len(jb) % 4) % 4)
    total = 12 + 8 + len(jb) + 8 + len(bin_bytes)
    out = struct.pack("<III", 0x46546C67, 2, total) + struct.pack("<I", len(jb)) + b"JSON" + jb
    out += struct.pack("<I", len(bin_bytes)) + b"BIN\x00" + bin_bytes
    open(path, "wb").write(out)


def transform_of(slot):
    tr = (slot.get("extensions") or {}).get("KHR_texture_transform")
    if not tr:
        return None
    return (tuple(tr.get("offset", (0.0, 0.0))), tuple(tr.get("scale", (1.0, 1.0))),
            float(tr.get("rotation", 0.0)))


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("world")
    ap.add_argument("--dry-run", action="store_true")
    ap.add_argument("--prune-dead-images", action="store_true",
                    help="drop image entries no texture references (post-unpack cleanup)")
    args = ap.parse_args()
    world = os.path.abspath(args.world)
    tex_dir = os.path.join(world, "textures")

    glbs = []
    for base, _d, files in os.walk(world):
        for f in sorted(files):
            if f.endswith(".glb"):
                glbs.append(os.path.join(base, f))

    if args.prune_dead_images:
        changed_n = 0
        for path in glbs:
            j, d = parse_glb(path)
            images = j.get("images", [])
            used = sorted({t["source"] for t in j.get("textures", [])})
            if len(used) == len(images):
                continue
            remap = {old: new for new, old in enumerate(used)}
            j["images"] = [images[i] for i in used]
            for t in j.get("textures", []):
                t["source"] = remap[t["source"]]
            _jb, bin_bytes = glb_chunks(path, j, d)
            if not args.dry_run:
                write_glb(path, j, bin_bytes)
            changed_n += 1
            print(("prune images: " if not args.dry_run else "would prune images: ")
                  + os.path.relpath(path, world))
        print(f"glbs compacted: {changed_n}")
        return

    # pass 1 — collect unique (image_uri, transform) -> slot kinds using it
    combos = {}          # (uri, transform) -> set(slot kinds)
    per_glb = []         # (path, j, d, [(slot_ref...) ])
    for path in glbs:
        j, d = parse_glb(path)
        uses = []
        for m in j.get("materials", []):
            pbr = m.get("pbrMetallicRoughness", {})
            for kind in SLOTS:
                slot = pbr.get(kind) if kind in ("baseColorTexture", "metallicRoughnessTexture") else m.get(kind)
                if not slot:
                    continue
                tr = transform_of(slot)
                if tr is None or tr[2] != 0.0:
                    continue  # untouched: no transform, or rotation we don't repack
                tex = j["textures"][slot["index"]]
                uri = j["images"][tex["source"]].get("uri")
                if not uri:
                    continue  # embedded image: skip (none in this world)
                combos.setdefault((uri, tr), set()).add(kind)
                uses.append((m, kind, slot, uri, tr))
        per_glb.append((path, j, d, uses))

    if not combos:
        print("no transformed slots found — nothing to do")
        return

    # pass 2 — crop each unique combo to a content-addressed file
    crops = {}           # (uri, tr) -> new_filename
    for (uri, tr), kinds in sorted(combos.items()):
        (off_x, off_y), (sc_x, sc_y), _rot = tr
        src = os.path.join(tex_dir, os.path.basename(uri))
        im = Image.open(src)
        w, h = im.size
        # glTF UV origin is bottom-left; PIL crop origin is top-left.
        box = (round(off_x * w), round((1.0 - off_y - sc_y) * h),
               round((off_x + sc_x) * w), round((1.0 - off_y) * h))
        crop = im.crop(box)
        if crop.mode != "RGB":
            crop = crop.convert("RGB")
        quality = 96
        for k in kinds:
            quality = min(quality, QUALITY.get(k, 96))
        subsampling = 0 if quality >= 94 else 2  # 4:4:4 for normal/ORM, 4:2:0 albedo
        import io
        buf = io.BytesIO()
        crop.save(buf, "JPEG", quality=quality, subsampling=subsampling)
        data = buf.getvalue()
        name = hashlib.sha256(data).hexdigest() + ".jpg"
        print(f"{os.path.basename(uri)[:16]}.. {tr} -> {name[:16]}.. {crop.size} "
              f"q{quality} kinds={sorted(kinds)}")
        crops[(uri, tr)] = name
        if not args.dry_run:
            open(os.path.join(tex_dir, name), "wb").write(data)

    # pass 3 — rewrite GLB material slots (URI swap + drop transform)
    rewritten = 0
    for path, j, d, uses in per_glb:
        if not uses:
            continue
        changed = False
        img_index = {}   # new_filename -> image index in this GLB
        for m, kind, slot, uri, tr in uses:
            new_name = crops[(uri, tr)]
            if new_name not in img_index:
                j.setdefault("images", []).append({"uri": "../textures/" + new_name, "mimeType": "image/jpeg"})
                img_index[new_name] = len(j["images"]) - 1
                changed = True
            tex = j["textures"][slot["index"]]
            if tex["source"] != img_index[new_name]:
                tex["source"] = img_index[new_name]
                changed = True
            ext = slot.get("extensions") or {}
            if "KHR_texture_transform" in ext:
                del ext["KHR_texture_transform"]
                if not ext:
                    del slot["extensions"]
                changed = True
        if changed:
            still_used = any(
                transform_of(s)
                for m in j.get("materials", [])
                for k in SLOTS
                for s in [m.get(k) if k in ("baseColorTexture", "metallicRoughnessTexture") else m.get(k)]
                if s
            )
            if not still_used:
                used = j.get("extensionsUsed") or []
                if "KHR_texture_transform" in used:
                    used.remove("KHR_texture_transform")
                    if used:
                        j["extensionsUsed"] = used
                    else:
                        j.pop("extensionsUsed", None)
                req = j.get("extensionsRequired") or []
                if "KHR_texture_transform" in req:
                    req.remove("KHR_texture_transform")
                    if req:
                        j["extensionsRequired"] = req
                    else:
                        j.pop("extensionsRequired", None)
            if not args.dry_run:
                _jb, bin_bytes = glb_chunks(path, j, d)
                write_glb(path, j, bin_bytes)
            rewritten += 1
            print(("would rewrite: " if args.dry_run else "rewritten: ") + os.path.relpath(path, world))

    print(f"combos unpacked: {len(combos)} | glbs rewritten: {rewritten}")


if __name__ == "__main__":
    main()
