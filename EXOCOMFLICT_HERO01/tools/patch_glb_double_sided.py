"""Set glTF material doubleSided=true for ALL materials in a GLB by byte-splicing
the JSON chunk.

Why: HERO_01 is 247 open (non-watertight) shells. With single-sided materials,
Godot culls back faces and fine shell detail (straps, weapon panels, fingers)
visually disappears at certain angles while moving, even though the geometry
is intact (Blender/Cycles renders both sides, so Blender previews look fine).
doubleSided=true is the glTF-correct fix for open-shell meshes. As of the
undersuit fix (VALIDATION_REPORT 5.9) the rigged GLB carries two materials
(original body material + hidden undersuit), so every material is patched.

Only the JSON chunk changes (one flag inserted/replaced per material). The BIN
chunk (geometry, weights, animation, textures) is copied byte-for-byte.
Re-run after any future Blender re-export, or disable material Backface
Culling in Blender instead. Stdlib only.
Usage: python3 patch_glb_double_sided.py <file.glb> [...]
"""
import hashlib
import json
import re
import struct
import sys

JSON_CHUNK = 0x4E4F534A  # 'JSON'
BIN_CHUNK = 0x004E4942  # 'BIN\0'


def material_object_ranges(js_text: str):
    """Return [(start, end_inclusive)] for each top-level object in the
    top-level "materials" array, scanning with string/escape awareness."""
    mi = js_text.index('"materials"')
    i = js_text.index("[", mi) + 1
    ranges = []
    depth = 0
    in_str = False
    esc = False
    obj_start = None
    while i < len(js_text):
        ch = js_text[i]
        if in_str:
            if esc:
                esc = False
            elif ch == "\\":
                esc = True
            elif ch == '"':
                in_str = False
        elif ch == '"':
            in_str = True
        elif ch == "{":
            if depth == 0:
                obj_start = i
            depth += 1
        elif ch == "}":
            depth -= 1
            if depth == 0 and obj_start is not None:
                ranges.append((obj_start, i))
                obj_start = None
        elif ch == "]" and depth == 0:
            break
        i += 1
    return ranges


def patch(path: str) -> None:
    data = bytearray(open(path, "rb").read())
    assert data[:4] == b"glTF", path
    total = struct.unpack_from("<I", data, 8)[0]
    assert total == len(data), (path, total, len(data))
    clen, ctype = struct.unpack_from("<II", data, 12)
    assert ctype == JSON_CHUNK, path
    jstart, jend = 20, 20 + clen
    js_text = bytes(data[jstart:jend]).decode("utf-8")
    doc = json.loads(js_text)
    mats = doc.get("materials", [])
    if mats and all(m.get("doubleSided") is True for m in mats):
        print(f"{path}: all {len(mats)} material(s) already doubleSided, skipped")
        return
    inv_before = (
        len(doc.get("meshes", [])),
        len(doc.get("accessors", [])),
        len(doc.get("skins", [])),
        len(doc.get("animations", [])),
        len(doc.get("nodes", [])),
        len(mats),
    )
    bin_len, bin_type = struct.unpack_from("<II", data, jend)
    assert bin_type == BIN_CHUNK, path
    bin_hash = hashlib.sha256(bytes(data[jend:])).hexdigest()

    ranges = material_object_ranges(js_text)
    assert len(ranges) == len(mats), (path, len(ranges), len(mats))
    new_js = js_text
    patched = 0
    # Edit from the last material backwards so earlier offsets stay valid.
    for idx in range(len(mats) - 1, -1, -1):
        if mats[idx].get("doubleSided") is True:
            continue
        start, end = ranges[idx]
        segment = new_js[start : end + 1]
        if '"doubleSided"' in segment:
            segment2, cnt = re.subn(
                r'"doubleSided"\s*:\s*false', '"doubleSided":true', segment, count=1
            )
            assert cnt == 1, (path, idx, segment[:80])
        else:
            j = start + 1
            while new_js[j] in " \t\r\n":
                j += 1
            insertion = (
                '"doubleSided":true' if new_js[j] == "}" else '"doubleSided":true,'
            )
            segment2 = segment[:1] + insertion + segment[1:]
        new_js = new_js[:start] + segment2 + new_js[end + 1 :]
        patched += 1

    raw = new_js.encode("utf-8")
    raw += b" " * ((-len(raw)) % 4)

    out = bytearray(data[:12])
    out += struct.pack("<II", len(raw), JSON_CHUNK)
    out += raw
    out += data[jend:]
    struct.pack_into("<I", out, 8, len(out))

    doc2 = json.loads(bytes(out[20 : 20 + len(raw)]).decode("utf-8"))
    assert all(m.get("doubleSided") is True for m in doc2.get("materials", []))
    inv_after = (
        len(doc2.get("meshes", [])),
        len(doc2.get("accessors", [])),
        len(doc2.get("skins", [])),
        len(doc2.get("animations", [])),
        len(doc2.get("nodes", [])),
        len(doc2.get("materials", [])),
    )
    assert inv_before == inv_after, (inv_before, inv_after)
    assert hashlib.sha256(bytes(out[20 + len(raw) :])).hexdigest() == bin_hash

    open(path, "wb").write(out)
    print(
        f"{path}: patched {patched}/{len(mats)} material(s); {len(data)} -> {len(out)} bytes "
        f"md5={hashlib.md5(out).hexdigest()} sha256={hashlib.sha256(out).hexdigest()}"
    )


if __name__ == "__main__":
    for p in sys.argv[1:]:
        patch(p)
