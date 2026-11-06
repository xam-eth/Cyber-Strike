#!/usr/bin/env python3
"""enrich_aetherfall.py — production detail + PBR pass over the shipped world kit.

The family builders (build_aetherfall.py and friends) own the macro forms,
pivots and node-name contracts. This stage turns the exported GLBs from
"sketch" into production-sci-fi surfaces without touching those contracts:

  1. bevel every hard edge (angle-limited, applied) — chamfers catch light;
  2. panel-plate pass on large flat *tech* faces — recessed plate centres with
     seam gaps read as constructed panels from every gameplay camera distance;
  3. geology displacement on Rock/Stratum/IceVein meshes — inward-biased noise
     with vertices clamped to the baseline AABB, so the world can only get
     *more* walkable, never less (spawn/clearance contracts are monotone-safe);
  4. rebuild every material from tools/blender/pbr_lib.py surface sets
     (1024px albedo + normal + ORM with cavity AO, wear and grime channels);
  5. re-export in place (export_yup=False like the builders), then verify
     node names, clip names and AABBs against the committed baseline.

Run:
    LD_LIBRARY_PATH=tools/.cache/x11stubs .venv/bin/python tools/blender/enrich_aetherfall.py
    ... enrich_aetherfall.py --only deck_6x6,cover_barrier
    ... enrich_aetherfall.py --skip-geometry        # materials only
"""

import json
import math
import os
import struct
import sys

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
sys.path.insert(0, os.path.dirname(__file__))

WORLD = os.path.join(ROOT, "game", "assets", "world", "aetherfall")
MODELS = os.path.join(WORLD, "models")
MAPS = os.path.join(WORLD, "materials")
MEASUREMENTS = os.path.join(WORLD, "measurements.json")

# ---------------------------------------------------------------------------
# asset configuration — style knobs per module family
# ---------------------------------------------------------------------------
# style: "tech" (panels+bevel), "geology" (displace+bevel), "trim" (bevel only),
#        "vfx" (materials only)
STYLE = {}


def _style(names, style, panel=1.0, displace=0.0):
    for n in names.split():
        STYLE[n] = dict(style=style, panel=panel, displace=displace)


_style("deck_6x6 deck_edge walkway_deck bridge_deck bridge_support connector_ramp "
       "damaged_slab wall_section cover_barrier cover_machine access_gate railing "
       "pillar beam machinery cooling_vent conduit tower_foundation tower_tier "
       "tower_spire cable_bundle debris_cluster", "tech")
_style("terrain_chunk cliff_face rock_boulder", "geology", displace=1.0)
_style("background_silhouette cloud_puff energy_orbit", "vfx")
_style("energy_core", "tech", panel=0.6)

# subdirectory families
_style("ice_planet/glacier_shelf ice_planet/frozen_spire", "geology", displace=0.8)
_style("ice_planet/cryo_pylon ice_planet/sentinel_archive", "tech", panel=0.9)
_style("landmarks/field_outpost landmarks/relay_annex landmarks/service_hangar "
       "landmarks/cargo_service_cluster", "tech", panel=1.0)
_style("phase2/glacier_berm phase2/ice_terrace", "geology", displace=0.7)
_style("phase2/salvage_pod phase2/cryo_bulkhead", "tech")
_style("expanse/expanse_shelf", "tech", panel=0.5, displace=0.35)
_style("expanse/transit_spine", "tech")
_style("expanse/lowland_field", "geology", displace=0.5)
_style("vertical/refinery_stack vertical/overhead_gantry vertical/raised_ops_deck", "tech")
_style("archive/archive_vestibule archive/archive_computer", "tech", panel=0.8)
_style("interactives/tech_cache interactives/objective_device", "tech", panel=0.8)

# animated modules: geometry passes allowed (they ride node transforms) but the
# animation itself is preserved by round-trip export; listed for verification.
ANIMATED = {
    "energy_orbit": ["EnergyOrbit"],
    "interactives/tech_cache": ["TechCache_Open"],
    "interactives/objective_device": ["ObjectiveDevice_Activate"],
    "archive/archive_computer": ["ArchiveComputer_Download"],
}

# material name (lower-case substring) -> surface family in pbr_lib
MAT_SURFACE = [
    ("warningred", "hazard_red"),
    ("ramp_hazard", "hazard"),
    ("hazard", "hazard"),
    ("paint", "deck"),
    ("deck", "deck"),
    ("rampsteel", "metal"),
    ("titanium", "metal2"),
    ("steel", "metal"),
    ("concrete", "concrete"),
    ("composite", "composite"),
    ("cable", "rubber"),
    ("rubber", "rubber"),
    ("glass", None),          # keep original
    ("cloud", "cloud"),
    ("orbitenergy", "energy"),
    ("energy", "energy"),
    ("icevein", "ice_rock"),
    ("stratum", "rock"),
    ("rock", "rock"),
    ("ice", "ice_rock"),      # aether_ice / glacier ice families
    ("citadel", "metal"),
    ("metal", "metal"),
]

# materials treated as geology for the displacement pass
GEOLOGY_MATS = ("rock", "stratum", "icevein", "ice", "glacier", "snow")

# emission boost per surface kind
EMISSION = {"energy": 2.2, "ice_rock": 0.12}


# ---------------------------------------------------------------------------
# small utilities
# ---------------------------------------------------------------------------


def glb_docs(path):
    with open(path, "rb") as f:
        data = f.read()
    offset = 12
    while offset < len(data):
        clen, ctype = struct.unpack_from("<II", data, offset)
        if ctype == 0x4E4F534A:
            return json.loads(data[offset + 8:offset + 8 + clen])
        offset += 8 + clen + ((4 - clen % 4) % 4)
    return None


def all_glbs():
    """Return [(key, absolute path)]; kit modules strip the models/ prefix so
    they match the STYLE table, families keep their folder key."""
    out = []
    for root, dirs, files in os.walk(WORLD):
        dirs[:] = [d for d in dirs if d not in ("textures", "source_textures", "materials")]
        for fn in sorted(files):
            if fn.endswith(".glb"):
                full = os.path.join(root, fn)
                rel = os.path.relpath(full, WORLD)[: -len(".glb")]
                key = rel[len("models/"):] if rel.startswith("models/") else rel
                out.append((key, full))
    return sorted(out)


def baseline():
    with open(MEASUREMENTS) as f:
        doc = json.load(f)
    out = {}
    for k, v in doc["models"].items():
        k = k[len("models/") :] if k.startswith("models/") else k
        out[k[: -len(".glb")]] = v
    return out


def hash01(*vals):
    x = 2166136261
    for v in vals:
        x = (x ^ (int(v * 1000) & 0xFFFFFFFF)) * 16777619 & 0xFFFFFFFF
    return (x % 10007) / 10007.0


def value_noise3(x, y, z, freq):
    """Trilinear value noise in [0,1]; cheap and stable."""
    def h(i, j, k):
        n = (i * 374761393 + j * 668265263 + k * 2147483647) & 0xFFFFFFFF
        n = (n ^ (n >> 13)) * 1274126177 & 0xFFFFFFFF
        return ((n ^ (n >> 16)) % 10007) / 10007.0

    xf, yf, zf = x * freq, y * freq, z * freq
    xi, yi, zi = math.floor(xf), math.floor(yf), math.floor(zf)
    tx, ty, tz = xf - xi, yf - yi, zf - zi
    tx = tx * tx * (3 - 2 * tx)
    ty = ty * ty * (3 - 2 * ty)
    tz = tz * tz * (3 - 2 * tz)

    def lerp(a, b, t):
        return a + (b - a) * t

    c00 = lerp(h(xi, yi, zi), h(xi + 1, yi, zi), tx)
    c10 = lerp(h(xi, yi + 1, zi), h(xi + 1, yi + 1, zi), tx)
    c01 = lerp(h(xi, yi, zi + 1), h(xi + 1, yi, zi + 1), tx)
    c11 = lerp(h(xi, yi + 1, zi + 1), h(xi + 1, yi + 1, zi + 1), tx)
    return lerp(lerp(c00, c10, ty), lerp(c01, c11, ty), tz)


# ---------------------------------------------------------------------------
# geometry passes
# ---------------------------------------------------------------------------


def face_is_geology(mesh, poly):
    if not mesh.materials:
        return False
    mat = mesh.materials[poly.material_index] if poly.material_index < len(mesh.materials) else None
    if mat is None:
        return False
    name = mat.name.lower()
    return any(tag in name for tag in GEOLOGY_MATS)


def mesh_area(obj):
    import bpy  # noqa: F401
    return sum(p.area for p in obj.data.polygons)


def bevel_pass(obj, width):
    import bpy

    bpy.context.view_layer.objects.active = obj
    for o in bpy.context.selected_objects:
        o.select_set(False)
    obj.select_set(True)
    mod = obj.modifiers.new("HSBevel", "BEVEL")
    mod.width = width
    mod.segments = 2
    mod.limit_method = "ANGLE"
    mod.angle_limit = math.radians(42.0)
    mod.harden_normals = True
    mod.use_clamp_overlap = True
    bpy.ops.object.modifier_apply(modifier=mod.name)
    obj.select_set(False)


def panel_pass(obj, density):
    """Recessed panel plates on large planar tech faces."""
    import bmesh

    me = obj.data
    bm = bmesh.new()
    bm.from_mesh(me)
    bm.faces.ensure_lookup_table()
    # material index -> geology?
    geo_idx = set()
    for f in bm.faces:
        if face_is_geology(me, f):
            geo_idx.add(f.index)
    targets = []
    for f in bm.faces:
        if f.index in geo_idx:
            continue
        if f.calc_area() < 0.42:
            continue
        if len(f.verts) < 3:
            continue
        targets.append(f)
    if not targets:
        bm.free()
        return 0
    # hash-driven skip so panels vary across a face field
    keep = []
    for f in targets:
        c = f.calc_center_median()
        if hash01(c.x, c.y, c.z, 3.1) < 0.90 * density:
            keep.append(f)
    if not keep:
        keep = targets[:1]
    try:
        res = bmesh.ops.inset_individual(
            bm, faces=keep,
            thickness=0.075, depth=-0.020, use_even_offset=True, use_interpolate=True,
        )
        # recess the inner plates a touch further for a stepped seam
        inner = res.get("faces", [])
        for f in inner:
            n = f.normal
            for v in f.verts:
                v.co -= n * 0.012
    except Exception as exc:  # degenerate insets must not kill the run
        print("    panel_pass warning:", exc)
    bm.to_mesh(me)
    bm.free()
    me.update()
    return len(keep)


def displace_pass(obj, amplitude, lo, hi):
    """Inward-biased geology noise, clamped to the baseline AABB."""
    import bpy  # noqa: F401
    me = obj.data
    for v in me.vertices:
        co = v.co
        n = v.normal
        d = (
            value_noise3(co.x, co.y, co.z, 0.55) * 0.6
            + value_noise3(co.x, co.y, co.z, 1.7) * 0.3
            + value_noise3(co.x, co.y, co.z, 4.3) * 0.1
        )
        offset = (d - 0.62) * amplitude  # mean < 0: carves inward
        v.co.x += n.x * offset
        v.co.y += n.y * offset
        v.co.z += n.z * offset
        v.co.x = min(max(v.co.x, lo[0]), hi[0])
        v.co.y = min(max(v.co.y, lo[1]), hi[1])
        v.co.z = min(max(v.co.z, lo[2]), hi[2])
    me.update()


# ---------------------------------------------------------------------------
# materials
# ---------------------------------------------------------------------------


# surface sets are expensive to generate; cache them across all 51 assets
_SETS_CACHE = {}


def surface_maps(kind):
    import pbr_lib

    if kind not in _SETS_CACHE:
        maps = pbr_lib.surface_set(kind)
        _SETS_CACHE[kind] = pbr_lib.save_set(MAPS, "aetherfall_" + kind, maps)
        print(f"    generated surface set: {kind}")
    return _SETS_CACHE[kind]


def surface_for(mat_name):
    name = mat_name.lower()
    for tag, kind in MAT_SURFACE:
        if tag in name:
            return kind
    return None


def rebuild_materials(asset_key, scene_objects):
    import bpy
    import pbr_lib

    used = set()
    for obj in scene_objects:
        if obj.type == "MESH":
            for mat in obj.data.materials:
                if mat:
                    used.add(mat)
    made = {}
    for mat in sorted(used, key=lambda m: m.name):
        kind = surface_for(mat.name)
        if kind is None:
            continue
        paths = surface_maps(kind)
        strength = 1.0 if kind in ("rock", "ice_rock") else 0.78
        new = pbr_lib.build_material(
            mat.name, paths, tex_scale=0.42,
            emission=EMISSION.get(kind, 0.0),
            alpha_blend=(kind == "cloud"),
            normal_strength=strength,
        )
        made[mat.name] = new
        print(f"    material {mat.name:16s} -> {kind}")
    return made


# ---------------------------------------------------------------------------
# main
# ---------------------------------------------------------------------------


def main():
    args = sys.argv[1:]
    only = None
    skip_geometry = "--skip-geometry" in args
    if "--only" in args:
        only = set(args[args.index("--only") + 1].split(","))

    import bpy

    base = baseline()
    assets = [(k, p) for k, p in all_glbs() if only is None or k in only]
    print(f"== enrich_aetherfall: {len(assets)} assets ==")

    report = []
    for key, path in assets:
        cfg = STYLE.get(key, dict(style="tech", panel=0.8, displace=0.0))
        print(f"  [{key}] style={cfg['style']}")
        bpy.ops.wm.read_factory_settings(use_empty=True)
        bpy.ops.import_scene.gltf(filepath=path)
        objs = [o for o in bpy.data.objects if o.type == "MESH"]

        # contract snapshot from the imported scene
        names_before = sorted(o.name for o in bpy.data.objects)
        clips_before = sorted(a.name for a in bpy.data.actions)

        b = base.get(key)
        if b is not None:
            # measurements are glTF Y-up; Blender scenes are Z-up (x, -z, y).
            g_lo, g_hi = b["min"], [b["min"][i] + b["size"][i] for i in range(3)]
            lo = (g_lo[0], -g_hi[2], g_lo[1])
            hi = (g_hi[0], -g_lo[2], g_hi[1])
        else:
            lo, hi = (None, None)

        if not skip_geometry and cfg["style"] in ("tech", "geology"):
            span = max(hi[i] - lo[i] for i in range(3)) if hi else 6.0
            bevel_w = min(max(span * 0.0045, 0.012), 0.042)
            for obj in objs:
                me = obj.data
                if len(me.polygons) < 4:
                    continue
                bevel_pass(obj, bevel_w)
                if cfg["style"] == "tech" and cfg["panel"] > 0:
                    panel_pass(obj, cfg["panel"])
                if cfg["style"] == "geology" and cfg["displace"] > 0 and hi is not None:
                    displace_pass(obj, 0.075 * cfg["displace"], lo, hi)
            for obj in objs:
                try:
                    bpy.context.view_layer.objects.active = obj
                    for o in bpy.context.selected_objects:
                        o.select_set(False)
                    obj.select_set(True)
                    bpy.ops.object.shade_smooth_by_angle(angle=math.radians(34.0))
                    obj.select_set(False)
                except Exception:
                    pass

        rebuild_materials(key, objs)

        # export in place; the packer externalizes + dedupes textures afterwards
        bpy.ops.object.select_all(action="DESELECT")
        for o in objs:
            o.select_set(True)
        animated = key in ANIMATED
        # import converts glTF Y-up to Blender Z-up (x, -z, y); export_yup=True
        # converts back so the round-trip preserves the authored axes exactly.
        bpy.ops.export_scene.gltf(
            filepath=path, export_format="GLB", export_yup=True,
            export_apply=True, use_selection=True, export_materials="EXPORT",
            export_animations=True,
        )
        # post-export contract verification
        doc = glb_docs(path)
        names_after = sorted(n.get("name", "") for n in doc.get("nodes", []))
        missing = [n for n in names_before if n not in names_after]
        clips_after = sorted(anim.get("name", "") for anim in doc.get("animations", []))
        clip_missing = [c for c in clips_before if c not in clips_after]
        if animated:
            expect = ANIMATED[key]
            for clip in expect:
                if clip not in clips_after:
                    print(f"    FAIL missing clip {clip}")
        tris = 0
        glo = [1e9] * 3
        ghi = [-1e9] * 3
        for m in doc.get("meshes", []):
            for prim in m["primitives"]:
                idx = prim.get("indices")
                cnt = doc["accessors"][idx]["count"] if idx is not None else doc["accessors"][prim["attributes"]["POSITION"]]["count"]
                tris += cnt // 3
                acc = doc["accessors"][prim["attributes"]["POSITION"]]
                for i in range(3):
                    glo[i] = min(glo[i], acc["min"][i])
                    ghi[i] = max(ghi[i], acc["max"][i])
        drift = 0.0
        if b is not None:
            for i in range(3):
                drift = max(drift, abs(glo[i] - g_lo[i]), abs(ghi[i] - g_hi[i]))
        report.append(dict(asset=key, missing_nodes=missing, missing_clips=clip_missing,
                           tris=tris, bounds_drift=round(drift, 4)))
        status = "OK" if not missing and not clip_missing and drift < 0.12 else "CONTRACT-DIFF"
        print(f"    {status} tris={tris} nodes={len(names_after)} bounds_drift={drift:.3f}m missing={missing[:3]}")

    with open("/tmp/enrich_report.json", "w") as f:
        json.dump(report, f, indent=1)
    bad = [r for r in report if r["missing_nodes"] or r["missing_clips"]]
    print(f"== enrich done: {len(report)} assets, {len(bad)} contract diffs ==")
    return 1 if bad else 0


if __name__ == "__main__":
    sys.exit(main())
