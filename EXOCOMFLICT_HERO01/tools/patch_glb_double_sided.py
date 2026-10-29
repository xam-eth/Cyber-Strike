"""Set glTF material doubleSided=true in a GLB by byte-splicing the JSON chunk.

Why: HERO_01 is 247 open (non-watertight) shells. With single-sided materials,
Godot culls back faces and fine shell detail (straps, weapon panels, fingers)
visually disappears at certain angles while moving, even though the geometry
is intact (Blender/Cycles renders both sides, so Blender previews look fine).
doubleSided=true is the glTF-correct fix for open-shell meshes.

Only the JSON chunk changes (one flag inserted). The BIN chunk (geometry,
weights, animation, textures) is copied byte-for-byte. Re-run after any future
Blender re-export, or disable material Backface Culling in Blender instead.
Stdlib only. Usage: python3 patch_glb_double_sided.py <file.glb> [...]
"""
import hashlib
import json
import struct
import sys

JSON_CHUNK = 0x4E4F534A  # 'JSON'
BIN_CHUNK = 0x004E4942  # 'BIN\0'


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
    assert len(mats) == 1, (path, len(mats))
    if mats[0].get("doubleSided") is True:
        print(f"{path}: already doubleSided, skipped")
        return
    inv_before = (
        len(doc.get("meshes", [])),
        len(doc.get("accessors", [])),
        len(doc.get("skins", [])),
        len(doc.get("animations", [])),
        len(doc.get("nodes", [])),
    )
    bin_len, bin_type = struct.unpack_from("<II", data, jend)
    assert bin_type == BIN_CHUNK, path
    bin_hash = hashlib.sha256(bytes(data[jend:])).hexdigest()

    mi = js_text.index('"materials"')
    ob = js_text.index("{", js_text.index("[", mi))
    new_js = js_text[: ob + 1] + '"doubleSided":true,' + js_text[ob + 1 :]
    raw = new_js.encode("utf-8")
    raw += b" " * ((-len(raw)) % 4)

    out = bytearray(data[:12])
    out += struct.pack("<II", len(raw), JSON_CHUNK)
    out += raw
    out += data[jend:]
    struct.pack_into("<I", out, 8, len(out))

    doc2 = json.loads(bytes(out[20 : 20 + len(raw)]).decode("utf-8"))
    assert doc2["materials"][0].get("doubleSided") is True
    inv_after = (
        len(doc2.get("meshes", [])),
        len(doc2.get("accessors", [])),
        len(doc2.get("skins", [])),
        len(doc2.get("animations", [])),
        len(doc2.get("nodes", [])),
    )
    assert inv_before == inv_after, (inv_before, inv_after)
    assert hashlib.sha256(bytes(out[20 + len(raw) :])).hexdigest() == bin_hash

    open(path, "wb").write(out)
    print(
        f"{path}: {len(data)} -> {len(out)} bytes "
        f"md5={hashlib.md5(out).hexdigest()} sha256={hashlib.sha256(out).hexdigest()}"
    )


if __name__ == "__main__":
    for p in sys.argv[1:]:
        patch(p)
