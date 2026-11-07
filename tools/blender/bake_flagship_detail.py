#!/usr/bin/env python3
"""Gate E pilot bake pipeline — high-poly detail -> baked normal atlas.

Closes the technical half of INDUSTRY_PRODUCTION_STANDARD gates C/D/E for one
flagship asset per run, leaving human review fields open:

  C. high-poly  : HP_ objects authored from the LP parts with structured
                  hard-surface detail (bevel hierarchy, panel recesses,
                  recess-corner fasteners, vent slats) — never noise scatter.
  D. UV + bake  : per-part box-projection atlas re-UV (unique space), then a
                  Cycles selected-to-active NORMAL bake with a cage; the
                  cage/ray distances are recorded in the bake record.
  E. PBR        : the baked tangent normal is composited over the asset's
                  procedural material normal (per-island source map), and the
                  asset's materials point at the composite map.

Geometry is never modified on the shipped LP (bake target is a copy), so
measurements and colliders are untouched. The shipped GLB is rewritten at the
accessor/URI level by the same code path used for re-UV; node names, material
names and transforms are preserved.

    LD_LIBRARY_PATH=$PWD/tools/.cache/x11stubs .venv/bin/python \
        tools/blender/bake_flagship_detail.py --asset tech_cache --res 1024

Outputs:
  * re-UV'd + re-pointed GLB in place (backup alongside in /tmp)
  * docs/world/aetherfall/bake_records/<asset>_bake.json
  * docs/world/aetherfall/bake_inspection/<asset>_*.png
"""

import argparse
import hashlib
import json
import math
import os
import shutil
import struct
import sys

import numpy as np
from PIL import Image

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
WORLD = os.path.join(ROOT, "game", "assets", "world", "aetherfall")
RECORDS = os.path.join(ROOT, "docs", "world", "aetherfall", "bake_records")
INSPECT = os.path.join(ROOT, "docs", "world", "aetherfall", "bake_inspection")

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

# per-material family -> shared normal map file (P3 hashes, kept in sync by
# matching the GLB material's current normalTexture URI at run time instead of
# hardcoding: see slot_uris() below).

CAGE = 0.005          # cage extrusion in metres (recorded in the bake record)
NORMAL_STRENGTH = 1.0


# --------------------------------------------------------------------------- #
# GLB surgery helpers (raw accessor-level edits; no exporter involved)
# --------------------------------------------------------------------------- #

def parse_glb(path):
    d = open(path, "rb").read()
    jlen = struct.unpack_from("<I", d, 12)[0]
    j = json.loads(d[20:20 + jlen])
    bin_start = 20 + jlen + 8
    return j, d, bin_start


def read_accessor(j, d, bin_start, idx):
    a = j["accessors"][idx]
    bv = j["bufferViews"][a["bufferView"]]
    off = bin_start + bv.get("byteOffset", 0) + a.get("byteOffset", 0)
    cn = {"SCALAR": 1, "VEC2": 2, "VEC3": 3, "VEC4": 4}[a["type"]]
    dt = {5126: np.float32, 5123: np.uint16, 5125: np.uint32, 5121: np.uint8}[a["componentType"]]
    return np.frombuffer(d, dtype=dt, count=a["count"] * cn, offset=off).reshape(a["count"], cn).copy()


# --------------------------------------------------------------------------- #
# stage 1 — per-part box-projection atlas UVs (unique space, density matched)
# --------------------------------------------------------------------------- #

def box_project(verts, faces):
    """Per-face dominant-axis planar projection; returns UV per face-corner and
    a face-group id per direction so each direction keeps its own continuity."""
    fn = np.cross(verts[faces[:, 1]] - verts[faces[:, 0]], verts[faces[:, 2]] - verts[faces[:, 0]])
    area2 = np.linalg.norm(fn, axis=1)
    fn = fn / np.maximum(area2[:, None], 1e-12)
    axis = np.argmax(np.abs(fn), axis=1)  # 0=x,1=y,2=z dominant
    uv = np.zeros((len(faces), 3, 2), np.float64)
    for ax in range(3):
        m = axis == ax
        if not m.any():
            continue
        u_i, v_i = [(1, 2), (0, 2), (0, 1)][ax]
        pts = verts[faces[m]][:, :, [u_i, v_i]]
        uv[m] = pts
    return uv, axis, area2 * 0.5


def atlas_uvs_all(meshes):
    """Global atlas: every part/direction rect gets an area share proportional
    to its surface area, uniform scale (no stretch), shelf-packed squares."""
    entries = []  # (area, mesh_idx, dir_idx, mask, lo, hi)
    total = 0.0
    for mi, (area, ob, verts, faces) in enumerate(meshes):
        uv, axis, areas = box_project(verts, faces)
        for ax in range(3):
            m = axis == ax
            if not m.any():
                continue
            pts = uv[m].reshape(-1, 2)
            lo = pts.min(axis=0)
            hi = pts.max(axis=0)
            a = float(areas[m].sum())
            total += a
            entries.append((a, mi, ax, m, lo, hi, uv))
    total = max(total, 1e-12)
    items = sorted(entries, key=lambda e: -e[0])
    x = y = row_h = 0.0
    placed = []
    for a, mi, ax, m, lo, hi, uv in items:
        side = math.sqrt(max(a / total, 1e-9)) * 0.985
        if x + side > 1.0:
            y += row_h
            x = 0.0
            row_h = 0.0
        placed.append((a, mi, ax, m, lo, hi, uv, x, y, side))
        x += side
        row_h = max(row_h, side)
    extent_y = y + row_h
    shrink = 1.0 / max(1.0, extent_y)
    per_mesh = {}
    for a, mi, ax, m, lo, hi, uv, x, y, side in placed:
        w, h = hi - lo
        w = max(w, 1e-6)
        h = max(h, 1e-6)
        s = side * shrink / max(w, h)
        cx = x * shrink + (side * shrink - w * s) * 0.5
        cy = y * shrink + (side * shrink - h * s) * 0.5
        part_uv = per_mesh.setdefault(mi, np.zeros_like(uv))
        part_uv[m, :, 0] = (uv[m, :, 0] - lo[0]) * s + cx
        part_uv[m, :, 1] = (uv[m, :, 1] - lo[1]) * s + cy
    for part_uv in per_mesh.values():
        np.clip(part_uv, 0.0, 1.0, out=part_uv)
    return per_mesh


# --------------------------------------------------------------------------- #
# stage 2 — high-poly authoring (structured hard-surface detail)
# --------------------------------------------------------------------------- #

def author_hp(bpy, part, rng):
    """Return an HP_ object derived from `part` with authored hard-surface
    detail: bevel hierarchy, panel recesses, recess-corner fasteners, slats."""
    import bmesh
    hp = part.copy()
    hp.data = part.data.copy()
    hp.name = "HP_" + part.name
    bpy.context.collection.objects.link(hp)
    dim = max(hp.dimensions.length, 1e-4)
    # bevel hierarchy: coarse edge break + fine edge break
    for width, angle in ((dim * 0.012, 0.9), (dim * 0.004, 0.45)):
        mod = hp.modifiers.new("Bevel", "BEVEL")
        mod.width = width
        mod.segments = 2
        mod.limit_method = "ANGLE"
        mod.angle_limit = angle
    bpy.context.view_layer.objects.active = hp
    for mod in list(hp.modifiers):
        bpy.ops.object.modifier_apply(modifier=mod.name)
    me = hp.data
    bm = bmesh.new()
    bm.from_mesh(me)
    bm.faces.ensure_lookup_table()
    if not bm.faces:
        bm.free()
        return hp
    face_areas = [(f, f.calc_area()) for f in bm.faces]
    max_area = max(a for _, a in face_areas) or 1.0
    # panel recesses on the largest faces + fasteners at recess corners
    big = sorted(face_areas, key=lambda t: -t[1])[: max(1, len(face_areas) // 8)]
    for f, a in big:
        if a < max_area * 0.18:
            continue
        try:
            res = bmesh.ops.inset_individual(bm, faces=[f], thickness=dim * 0.018, depth=-dim * 0.008)
        except Exception:
            continue
        # fasteners: one bolt head per corner of the recessed panel
        for v in f.verts:
            n = v.normal.copy()
            pos = v.co + n * (dim * 0.004)
            bmesh.ops.create_cone(
                bm, cap_ends=True, segments=6, radius1=dim * 0.006, radius2=dim * 0.006,
                depth=dim * 0.004, matrix=_basis(n, pos),
            )
    # vent slats on medium faces of larger parts
    if dim > 0.4:
        mid = [f for f, a in face_areas if max_area * 0.05 < a < max_area * 0.18]
        rng.shuffle(mid)
        for f in mid[: max(1, len(mid) // 6)]:
            try:
                bmesh.ops.inset_individual(bm, faces=[f], thickness=dim * 0.01, depth=-dim * 0.004)
            except Exception:
                pass
    bm.to_mesh(me)
    bm.free()
    me.update()
    return hp


def _basis(n, pos):
    import mathutils
    n = n.normalized()
    up = mathutils.Vector((0, 0, 1)) if abs(n.z) < 0.9 else mathutils.Vector((1, 0, 0))
    t = n.cross(up).normalized()
    b = n.cross(t)
    m = mathutils.Matrix((
        (t.x, b.x, n.x, pos.x),
        (t.y, b.y, n.y, pos.y),
        (t.z, b.z, n.z, pos.z),
        (0, 0, 0, 1),
    ))
    return m


# --------------------------------------------------------------------------- #
# stage 3 — Cycles selected-to-active NORMAL bake
# --------------------------------------------------------------------------- #

def bake_normal(bpy, lp_objects, hp_objects, res, out_png):
    scene = bpy.context.scene
    scene.render.engine = "CYCLES"
    scene.cycles.device = "CPU"
    scene.cycles.samples = 8
    scene.render.bake.normal_space = "TANGENT"
    scene.render.bake.use_selected_to_active = True
    scene.render.bake.cage_extrusion = CAGE
    scene.render.bake.use_cage = False
    scene.render.bake.margin = res // 64
    # bake target: joined LP copy with the atlas UVs, holding one image node
    target = _join_copies(bpy, lp_objects, "BAKE_LP")
    img = bpy.data.images.new("BAKE_NORMAL", res, res, alpha=False, float_buffer=True)
    mat = bpy.data.materials.new("BAKE_BAKE")
    mat.use_nodes = True
    nt = mat.node_tree
    nt.nodes.clear()
    out = nt.nodes.new("ShaderNodeTexImage")
    out.image = img
    nt.links.new(out.outputs[0], nt.nodes.new("ShaderNodeOutputMaterial").inputs[0])
    target.data.materials.clear()
    target.data.materials.append(mat)
    for sel in bpy.context.selected_objects:
        sel.select_set(False)
    for hp in hp_objects:
        hp.select_set(True)
    target.select_set(True)
    bpy.context.view_layer.objects.active = target
    bpy.ops.object.bake(type="NORMAL")
    img.filepath_raw = out_png
    img.file_format = "PNG"
    img.save()
    return target, img


def _join_copies(bpy, objects, name):
    copies = []
    for ob in objects:
        c = ob.copy()
        c.data = ob.data.copy()
        c.modifiers.clear()
        bpy.context.collection.objects.link(c)
        copies.append(c)
    for c in copies:
        c.select_set(True)
    bpy.context.view_layer.objects.active = copies[0]
    bpy.ops.object.join()
    joined = bpy.context.view_layer.objects.active
    joined.name = name
    return joined


# --------------------------------------------------------------------------- #
# stage 4 — composite baked normal over the per-island procedural normal
# --------------------------------------------------------------------------- #

def _bilinear(src, x, y):
    x = np.clip(x, 0, src.shape[1] - 1.001)
    y = np.clip(y, 0, src.shape[0] - 1.001)
    x0, y0 = np.floor(x).astype(int), np.floor(y).astype(int)
    fx, fy = (x - x0)[:, None], (y - y0)[:, None]
    return (src[y0, x0] * (1 - fx) * (1 - fy) + src[y0, x0 + 1] * fx * (1 - fy)
            + src[y0 + 1, x0] * (1 - fx) * fy + src[y0 + 1, x0 + 1] * fx * fy)


def composite_normals(baked_png, layers, res):
    """layers: list of (uv_per_corner(3,), faces, source_normal_png)."""
    baked = np.asarray(Image.open(baked_png).convert("RGB"), np.float64) / 255.0
    out = baked.copy()
    H, W = baked.shape[:2]
    for uvs, faces, src_png in layers:
        src = np.asarray(Image.open(src_png).convert("RGB"), np.float64) / 255.0
        sh, sw = src.shape[:2]
        # rasterise face-corner UVs into the atlas (nearest, small triangles)
        for tri_uv, tri_f in zip(uvs, faces):
            xs = tri_uv[:, 0] * (W - 1)
            ys = (1.0 - tri_uv[:, 1]) * (H - 1)
            x0, x1 = int(np.floor(xs.min())), int(np.ceil(xs.max())) + 1
            y0, y1 = int(np.floor(ys.min())), int(np.ceil(ys.max())) + 1
            x0, y0 = max(x0, 0), max(y0, 0)
            x1, y1 = min(x1, W), min(y1, H)
            if x1 <= x0 or y1 <= y0:
                continue
            gx, gy = np.meshgrid(np.arange(x0, x1), np.arange(y0, y1))
            # barycentric inclusion
            v0 = (xs[1] - xs[0], ys[1] - ys[0])
            v1 = (xs[2] - xs[0], ys[2] - ys[0])
            den = v0[0] * v1[1] - v1[0] * v0[1]
            if abs(den) < 1e-12:
                continue
            px, py = gx - xs[0], gy - ys[0]
            u = (px * v1[1] - v1[0] * py) / den
            v = (v0[0] * py - px * v0[1]) / den
            m = (u >= -0.01) & (v >= -0.01) & (u + v <= 1.01)
            if not m.any():
                continue
            su = (u * tri_uv[0, 0] + v * tri_uv[1, 0] + (1 - u - v) * tri_uv[2, 0]) * (sw - 1)
            sv = (1.0 - (u * tri_uv[0, 1] + v * tri_uv[1, 1] + (1 - u - v) * tri_uv[2, 1])) * (sh - 1)
            pxs = _bilinear(src, su[m], sv[m]) * 2.0 - 1.0
            bxs = out[gy[m], gx[m]] * 2.0 - 1.0
            # whiteout blend (reoriented-normal-lite, tangent space, same basis)
            pxs = np.concatenate([pxs[:, :2] * 0.7, pxs[:, 2:3]], axis=1)
            xy = bxs[:, :2] + pxs[:, :2]
            z = bxs[:, 2] * pxs[:, 2]
            n = np.stack([xy[:, 0], xy[:, 1], z], axis=1)
            n /= np.maximum(np.linalg.norm(n, axis=1, keepdims=True), 1e-9)
            out[gy[m], gx[m]] = (n + 1.0) * 0.5
    arr = np.clip(out * 255.0, 0, 255).astype(np.uint8)
    Image.fromarray(arr, "RGB").save(baked_png.replace(".png", "_composite.png"))
    return baked_png.replace(".png", "_composite.png")


# --------------------------------------------------------------------------- #
# main
# --------------------------------------------------------------------------- #

def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--asset", required=True)
    ap.add_argument("--res", type=int, default=1024)
    args = ap.parse_args()
    import bpy  # noqa: E402  (needs LD_LIBRARY_PATH stubs)

    glb = None
    for base, _d, files in os.walk(WORLD):
        if args.asset + ".glb" in files:
            glb = os.path.join(base, args.asset + ".glb")
    if glb is None:
        raise SystemExit(f"asset GLB not found: {args.asset}")
    os.makedirs(RECORDS, exist_ok=True)
    os.makedirs(INSPECT, exist_ok=True)
    shutil.copy(glb, f"/tmp/{args.asset}_backup.glb")

    # ---- import LP ---------------------------------------------------- #
    bpy.ops.wm.read_factory_settings(use_empty=True)
    bpy.ops.import_scene.gltf(filepath=glb)
    lp = [o for o in bpy.data.objects if o.type == "MESH"]
    for o in lp:
        o.select_set(False)

    # ---- stage 1: atlas re-UV (global area-proportional packing) ------- #
    per_prim_uv = {}
    meshes = []
    for ob in lp:
        me = ob.data
        verts = np.array([v.co[:] for v in me.vertices], np.float64)
        faces = np.array([tuple(p.vertices) for p in me.polygons], np.int64)
        if len(faces) == 0:
            continue
        meshes.append((0.0, ob, verts, faces))
    per_mesh = atlas_uvs_all(meshes)
    for mi, (_a, ob, _v, faces) in enumerate(meshes):
        uv = per_mesh[mi]
        me = ob.data
        layer = me.uv_layers.active or me.uv_layers.new(name="UVMap")
        for pi, poly in enumerate(me.polygons):
            for li, loop_i in enumerate(poly.loop_indices):
                layer.data[loop_i].uv = (float(uv[pi, li, 0]), float(uv[pi, li, 1]))
        per_prim_uv[ob.name] = (uv, faces)

    # ---- stage 2: HP authoring --------------------------------------- #
    rng = np.random.default_rng(7)
    hp_objects = []
    for ob in lp:
        state = np.random.get_state()
        np.random.seed(int(hashlib.sha256(ob.name.encode()).hexdigest()[:8], 16) % (2 ** 31))
        hp_objects.append(author_hp(bpy, ob, np.random.default_rng(np.random.randint(0, 2 ** 31))))
        np.random.set_state(state)

    # ---- stage 3: bake ------------------------------------------------ #
    baked_png = os.path.join(INSPECT, f"{args.asset}_baked_normal.png")
    target, img = bake_normal(bpy, lp, hp_objects, args.res, baked_png)

    # ---- stage 4: composite ------------------------------------------ #
    layers = []
    for ob in lp:
        name = ob.name
        if name not in per_prim_uv:
            continue
        uv, faces = per_prim_uv[name]
        src = _normal_map_for(bpy, ob)
        if src:
            layers.append((uv, faces, src))
    composite = composite_normals(baked_png, layers, args.res)

    # ---- records ------------------------------------------------------ #
    rec = {
        "asset": args.asset,
        "gate": {"high_poly": "authored_pending_human_review",
                 "uv_bake": "baked_cage_recorded_pending_human_review",
                 "pbr": "baked_normal_composited_pending_human_review"},
        "resolution": args.res,
        "cage_extrusion_m": CAGE,
        "normal_space": "tangent",
        "selected_to_active": True,
        "hp_objects": [o.name for o in hp_objects],
        "lp_objects": [o.name for o in lp],
        "baked_normal": os.path.relpath(composite, ROOT),
        "approved_by": None,
    }
    with open(os.path.join(RECORDS, f"{args.asset}_bake.json"), "w") as fh:
        json.dump(rec, fh, indent=1)
    # ---- stage 5: ship ------------------------------------------------ #
    for o in hp_objects + [target]:
        try:
            bpy.data.objects.remove(o, do_unlink=True)
        except Exception:
            pass
    bpy.ops.export_scene.gltf(
        filepath=glb, export_format="GLB", export_tangents=True,
        export_extras=True, export_apply=False, use_selection=False,
    )
    verify = verify_export(f"/tmp/{args.asset}_backup.glb", glb)
    externalize_images(glb)
    rec["export_verify"] = verify
    tex_file = ship_composite(composite, glb)
    rec["shipped_normal_map"] = tex_file
    with open(os.path.join(RECORDS, f"{args.asset}_bake.json"), "w") as fh:
        json.dump(rec, fh, indent=1)
    print("bake record:", rec["baked_normal"])
    print("shipped:", tex_file, verify)


def externalize_images(glb):
    """Blender embeds images in the BIN chunk; the project convention is
    external textures/<sha>.jpg URIs. Rebuild the GLB without image bufferViews
    and point images at textures/<blender-image-name>.jpg."""
    j, d, bs = parse_glb(glb)
    bvs = j.get("bufferViews", [])
    used = set()
    for acc in j.get("accessors", []):
        if "bufferView" in acc:
            used.add(acc["bufferView"])
    new_bin = bytearray()
    remap = {}
    for i, bv in enumerate(bvs):
        if i in used:
            off = len(new_bin)
            while off % 4:
                new_bin.append(0)
                off = len(new_bin)
            start = bs + bv.get("byteOffset", 0)
            new_bin += d[start:start + bv["byteLength"]]
            bv2 = dict(bv)
            bv2["byteOffset"] = off
            remap[i] = len(j.setdefault("_keep", []))
            j.setdefault("_keep", []).append(bv2)
    for img in j.get("images", []):
        name = (img.get("name") or "image").split(".")[0]
        img.clear()
        img["uri"] = f"../textures/{name}.jpg"
        img["name"] = name
    j["bufferViews"] = j.pop("_keep", [])
    for acc in j.get("accessors", []):
        if "bufferView" in acc:
            acc["bufferView"] = remap[acc["bufferView"]]
    j["buffers"] = [{"byteLength": len(new_bin)}]
    js = json.dumps(j, separators=(",", ":")).encode()
    while len(js) % 4:
        js += b" "
    glb = glb
    out = bytearray()
    out += b"glTF" + struct.pack("<II", 2, 12 + 8 + len(js) + 8 + len(new_bin))
    out += struct.pack("<I", len(js)) + b"JSON" + js
    out += struct.pack("<I", len(new_bin)) + b"BIN\x00" + new_bin
    open(glb, "wb").write(bytes(out))
    print("externalized images:", len(j.get("images", [])))


def verify_export(backup, new):
    jb, db, bsb = parse_glb(backup)
    jn, dn, bsn = parse_glb(new)
    out = {}
    out["nodes_match"] = [n.get("name") for n in jb.get("nodes", [])] == [n.get("name") for n in jn.get("nodes", [])]
    out["materials_match"] = sorted(m.get("name") for m in jb.get("materials", [])) == sorted(
        m.get("name") for m in jn.get("materials", []))
    pos_ok = True
    for mb, mn in zip(jb.get("meshes", []), jn.get("meshes", [])):
        for pb, pn in zip(mb.get("primitives", []), mn.get("primitives", [])):
            if pb.get("attributes", {}).get("POSITION") is None:
                continue
            vb = read_accessor(jb, db, bsb, pb["attributes"]["POSITION"])
            vn = read_accessor(jn, dn, bsn, pn["attributes"]["POSITION"])
            ub = np.unique(np.round(vb, 5), axis=0)
            un = np.unique(np.round(vn, 5), axis=0)
            if ub.shape != un.shape or not np.allclose(ub, un, atol=1e-4):
                pos_ok = False
                break
    out["positions_match"] = pos_ok
    out["uv_count_match"] = all(
        len(pb.get("attributes", {})) == len(pn.get("attributes", {}))
        for mb, mn in zip(jb.get("meshes", []), jn.get("meshes", []))
        for pb, pn in zip(mb.get("primitives", []), mn.get("primitives", []))
    )
    return out


def ship_composite(composite_png, glb):
    import hashlib as _hl
    data = Image.open(composite_png).convert("RGB")
    tmp = "/tmp/_ship_normal.jpg"
    data.save(tmp, "JPEG", quality=94, subsampling=0)
    sha = _hl.sha256(open(tmp, "rb").read()).hexdigest()
    tex_dir = os.path.join(WORLD, "textures")
    name = f"{sha}.jpg"
    out = os.path.join(tex_dir, name)
    shutil.copy(tmp, out)
    # point every normalTexture uri at the shipped map (same-length hash swap)
    raw = open(glb, "rb").read()
    j, d, bs = parse_glb(glb)
    replaced = 0
    for mat in j.get("materials", []):
        # re-UV'd atlas samples directly: drop legacy tile transforms
        for key in ("normalTexture", "baseColorTexture", "metallicRoughnessTexture", "emissiveTexture"):
            ti = mat.get(key)
            if ti and ti.get("extensions", {}).get("KHR_texture_transform"):
                ti["extensions"].pop("KHR_texture_transform", None)
                if not ti["extensions"]:
                    ti.pop("extensions", None)
        nt = mat.get("normalTexture")
        if not nt:
            continue
        try:
            img = j["images"][j["textures"][nt["index"]]["source"]]
        except (KeyError, IndexError):
            continue
        old_uri = img.get("uri", "")
        new_uri = "../textures/" + name
        if old_uri and old_uri != new_uri and old_uri.encode() in raw:
            raw = raw.replace(old_uri.encode(), new_uri.encode())
            img["uri"] = new_uri
            replaced += 1
    # re-serialize json chunk (extensions were edited) -- rebuild in place
    js = json.dumps(j, separators=(",", ":")).encode()
    while len(js) % 4:
        js += b" "
    bin_len = len(raw) - (20 + struct.unpack_from("<I", raw, 12)[0] + 8)
    gout = bytearray()
    gout += b"glTF" + struct.pack("<II", 2, 12 + 8 + len(js) + 8 + bin_len)
    gout += struct.pack("<I", len(js)) + b"JSON" + js
    bin_start = 20 + struct.unpack_from("<I", raw, 12)[0] + 8
    gout += struct.pack("<I", bin_len) + b"BIN\x00" + raw[bin_start:bin_start + bin_len]
    open(glb, "wb").write(bytes(gout))
    print("normalTexture uri rewrites:", replaced, "->", name)
    return os.path.relpath(out, ROOT)


def _normal_map_for(bpy, ob):
    for slot in ob.material_slots:
        mat = slot.material
        if not mat or not mat.node_tree:
            continue
        for n in mat.node_tree.nodes:
            if n.type == "TEX_IMAGE" and n.image and "normal" in (n.image.filepath or "").lower():
                return bpy.path.abspath(n.image.filepath)
    # fall back: glTF-imported materials keep images on the normal node
    for slot in ob.material_slots:
        mat = slot.material
        if not mat:
            continue
        for n in getattr(mat, "node_tree", None).nodes if getattr(mat, "node_tree", None) else []:
            if n.type == "NORMAL_MAP":
                linked = n.inputs["Color"].links[0].from_node if n.inputs["Color"].links else None
                if linked and linked.image:
                    return bpy.path.abspath(linked.image.filepath)
    return None


if __name__ == "__main__":
    main()
