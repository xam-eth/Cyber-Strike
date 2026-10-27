"""Assemble the Aetherfall world from the exported modules and render the
technical screenshots.

Runs as its own process: the exported .glb modules are imported back and
instanced, the source objects are hidden, then Cycles renders four hero
angles.  Writes layout.json (the placement manifest the Godot builder reads).

    LD_LIBRARY_PATH=/tmp/xlibs python3 tools/blender/assemble_aetherfall.py
"""

import os
import json
import math

import bpy
from mathutils import Vector as MV, Euler

ROOT = "/home/user/Cyber-Strike"
WORLD_DIR = os.path.join(ROOT, "game/assets/world/aetherfall")
MODEL_DIR = os.path.join(WORLD_DIR, "models")
SHOT_DIR = os.path.join(ROOT, "docs/world/aetherfall/shots")
os.makedirs(SHOT_DIR, exist_ok=True)

KEYS = ["terrain_chunk", "cliff_face", "rock_boulder", "deck_6x6", "deck_edge",
        "pillar", "beam", "wall_section", "tower_foundation", "tower_tier",
        "tower_spire", "energy_core", "bridge_deck", "bridge_support",
        "walkway_deck", "damaged_slab", "machinery", "cooling_vent", "conduit",
        "cable_bundle", "railing", "debris_cluster", "cover_barrier",
        "cover_machine", "access_gate", "background_silhouette", "cloud_puff"]

bpy.ops.wm.read_factory_settings(use_empty=True)
scene = bpy.context.scene
SCENE_COLL = scene.collection


# ---------------------------------------------------------------------------
# import modules
# ---------------------------------------------------------------------------
COLLS = {}


def import_module(key):
    path = os.path.join(MODEL_DIR, key + ".glb")
    before = set(bpy.data.objects)
    bpy.ops.import_scene.gltf(filepath=path)
    new = [o for o in bpy.data.objects if o not in before]
    coll = bpy.data.collections.new("M_" + key)
    SCENE_COLL.children.link(coll)
    for o in new:
        for c in list(o.users_collection):
            c.objects.unlink(o)
        coll.objects.link(o)
        o.hide_viewport = True
        o.hide_render = True
    COLLS[key] = coll
    print("  imported", key, "->", coll.name, "(%d objs)" % len(new))


print("== Aetherfall: import modules ==")
for k in KEYS:
    import_module(k)


# ---------------------------------------------------------------------------
# placement
# ---------------------------------------------------------------------------
PLACEMENTS = []


def place(key, name, pos, rot=(0.0, 0.0, 0.0), scale=1.0):
    """Instantiate a module by duplicating its meshes (Collection instancing is
    disabled by hiding the source, which also hides the instance here)."""
    coll = COLLS[key]
    nm = name or "%s_%03d" % (key, len(PLACEMENTS))
    rot_e = Euler((float(rot[0]), float(rot[1]), float(rot[2])), 'XYZ')
    made = []
    for src in coll.all_objects:
        if src.type != 'MESH':
            continue
        new_o = bpy.data.objects.new(nm + "__" + src.name, src.data)
        new_o.location = (float(pos[0]), float(pos[1]), float(pos[2]))
        new_o.rotation_euler = (rot_e.to_matrix() @ Euler(src.rotation_euler, 'XYZ').to_matrix()).to_euler('XYZ')
        new_o.scale = (float(scale), float(scale), float(scale))
        for mod in src.modifiers:
            try:
                m2 = new_o.modifiers.new(mod.name, mod.type)
                for prop in mod.bl_rna.properties.keys():
                    if prop in ('name', 'type'):
                        continue
                    try:
                        setattr(m2, prop, getattr(mod, prop))
                    except Exception:
                        pass
            except Exception:
                pass
        SCENE_COLL.objects.link(new_o)
        made.append(new_o)
    PLACEMENTS.append({
        "asset": key, "name": nm,
        "pos": [round(float(pos[0]), 3), round(float(pos[1]), 3), round(float(pos[2]), 3)],
        "rot": [round(math.degrees(float(rot[0])), 2),
                round(math.degrees(float(rot[1])), 2),
                round(math.degrees(float(rot[2])), 2)],
        "scale": round(float(scale), 4),
        "objects": len(made),
    })
    return made


TOWER = (0.0, 0.0, -26.0)

# ---- central Energy Tower (landmark, ~48 m) -------------------------------
place("tower_foundation", None, TOWER)
place("tower_tier", None, (0.0, 8.5, -26.0))
place("tower_tier", None, (0.0, 18.1, -26.0), scale=0.75)
place("tower_tier", None, (0.0, 25.7, -26.0), scale=0.62)
place("tower_spire", None, (0.0, 29.0, -26.0))
place("energy_core", None, (0.0, 20.0, -26.0))

# ---- main combat platform ---------------------------------------------------
for ix in range(-36, 37, 6):
    for iz in range(-15, 16, 6):
        place("deck_6x6", None, (ix, 0.0, iz))
for ix in range(-36, 37, 6):
    place("deck_edge", None, (ix, 0.0, -18.0), rot=(0.0, math.pi / 2.0, 0.0))
    place("deck_edge", None, (ix, 0.0, 18.0), rot=(0.0, math.pi / 2.0, 0.0))
for iz in range(-12, 16, 6):
    place("deck_edge", None, (38.0, 0.0, iz))
    place("deck_edge", None, (-38.0, 0.0, iz))
for ix in (-30.0, -18.0, 0.0, 18.0, 30.0):
    for iz in (-12.0, 0.0, 12.0):
        place("pillar", None, (ix, -6.1, iz))
for iz in (-12.0, -4.0, 4.0, 12.0):
    place("beam", None, (38.0, 6.4, iz))
    place("beam", None, (-38.0, 6.4, iz))
    place("beam", None, (0.0, 6.6, iz))

# ---- gameplay cover + enforced cover ---------------------------------------
for ix in (-26.0, -13.0, 13.0, 26.0):
    place("cover_barrier", None, (ix, 0.0, 8.0))
place("cover_machine", None, (-30.0, 0.0, -4.0))
place("cover_machine", None, (30.0, 0.0, 4.0))
place("cover_machine", None, (8.0, 0.0, 12.0))
for iz in (-12.0, 0.0, 12.0):
    place("conduit", None, (38.0, 4.4, iz), rot=(0.0, math.pi / 2.0, 0.0))
place("machinery", None, (-24.0, 0.0, -8.0))
place("machinery", None, (22.0, 0.0, 14.0))
place("cooling_vent", None, (-16.0, 0.0, 14.0))
place("access_gate", None, (0.0, 0.0, 21.0))
place("wall_section", None, (-30.0, 0.0, 18.0), rot=(0.0, math.pi / 2.0, 0.0))
place("wall_section", None, (30.0, 0.0, 18.0), rot=(0.0, math.pi / 2.0, 0.0))

# ---- primary elevated bridge (route A, intact) ------------------------------
for ix in (42.0, 50.0, 58.0):
    place("bridge_deck", None, (ix, 5.0, 0.0), rot=(0.0, math.pi / 2.0, 0.0))
place("bridge_support", None, (44.0, -10.0, 0.0))
place("bridge_support", None, (60.0, -10.0, 0.0))
for ix in (42.0, 50.0, 58.0):
    place("railing", None, (ix, 5.1, 3.1), rot=(0.0, math.pi / 2.0, 0.0))
place("damaged_slab", None, (64.0, 5.0, 0.0))

# ---- secondary elevated catwalk (route B, hazardous) ------------------------
for ix in (-41.0, -47.0, -53.0, -59.0):
    place("walkway_deck", None, (ix, 6.5, 8.0), rot=(0.0, math.pi / 2.0, 0.0))
    place("cable_bundle", None, (ix, 7.3, 8.0), rot=(0.0, math.pi / 2.0, 0.0))
for ix in (-44.0, -56.0):
    place("pillar", None, (ix, 0.3, 8.0))
for ix in (-55.0, -61.0):
    for iz in (6.0, 12.0):
        place("deck_6x6", None, (ix, 6.5, iz))

# ---- lower canyon approach (switchback descent) -----------------------------
for zz, yy in [(19.0, 0.0), (23.0, -1.6), (27.0, -3.2), (31.0, -4.8), (35.0, -6.4)]:
    place("deck_6x6", None, (0.0, yy, zz))
for tx, ty, tz in [(-34, -9, 24), (-22, -13, 30), (-10, -17, 36), (2, -19, 40),
                   (14, -17, 36), (26, -13, 30), (38, -9, 24), (0, -21, 44),
                   (-26, -14, 46), (26, -14, 46)]:
    place("terrain_chunk", None, (tx, ty, tz), rot=(0.0, math.radians(15 + (tz % 3) * 12), 0.0))
for tx in (-30.0, 0.0, 30.0):
    place("cliff_face", None, (tx, -13.0, 19.0))
for tx, ty, tz in [(-36, -4, 28), (-18, -6, 34), (20, -5, 32), (34, -3, 28), (-2, -9, 38), (28, -8, 38)]:
    place("rock_boulder", None, (tx, ty, tz), scale=0.75 + 0.2 * (tz % 3))
for tx, ty, tz in [(-30, -2, 32), (26, -4, 36), (0, -6, 30)]:
    place("machinery", None, (tx, ty, tz))
for tx, ty, tz in [(-22, -3, 38), (22, -5, 34), (-6, -8, 42)]:
    place("debris_cluster", None, (tx, ty, tz))
place("cooling_vent", None, (0.0, -6.0, 36.0))
place("access_gate", None, (0.0, -3.0, 40.0))

# ---- main canyon (north, behind the tower) + cloud fill ----------------------
for tx in (-46.0, 46.0, 0.0):
    place("cliff_face", None, (tx, -18.0 if tx else -20.0, -50.0 if tx else -62.0))
for tx, ty, tz in [(-30, -26, -54), (30, -26, -54), (0, -30, -70)]:
    place("terrain_chunk", None, (tx, ty, tz))
for tx, ty, tz in [(-40, -30, -60), (40, -30, -60), (0, -34, -74), (-20, -32, -68), (20, -32, -68)]:
    place("rock_boulder", None, (tx, ty, tz), scale=1.2)
for ix in range(-5, 6):
    place("cloud_puff", None, (ix * 14.0, -38.0, -58.0))

# ---- distant background silhouette + far cliffs -----------------------------
for tx, ty, tz, sc in [(-120, -4, -150, 1.6), (-40, -4, -170, 1.2), (40, -4, -170, 1.2),
                       (120, -4, -150, 1.6), (-150, -10, -70, 1.4), (150, -10, -70, 1.4),
                       (0, -8, -190, 2.0)]:
    place("background_silhouette", None, (tx, ty, tz), scale=sc)
for tx in (-90.0, 90.0):
    place("cliff_face", None, (tx, -12.0, -90.0), scale=1.8)
for tx in (-140.0, 140.0):
    place("cliff_face", None, (tx, -16.0, -40.0), scale=1.8)

print("== Aetherfall: %d placements ==" % len(PLACEMENTS))

# ---------------------------------------------------------------------------
# layout manifest
# ---------------------------------------------------------------------------
layout = {
    "schema": "aetherfall.layout/1",
    "unit": "meters",
    "up": "Y",
    "tower": list(TOWER),
    "tower_height_approx": 48.7,
    "platform": {"center": [0.0, 0.0, 0.0], "half": [38.0, 0.0, 18.0]},
    "deck_top_y": 0.25,
    "bridge_y": 5.0,
    "walkway_y": 6.5,
    "routes": [
        {"name": "central", "from": [-18.0, 0.0, 14.0], "to": [8.0, 0.0, -12.0],
         "width": 6.0, "cover": "cover_barrier"},
        {"name": "east_bridge", "from": [38.0, 0.0, 0.0], "to": [62.0, 5.0, 0.0],
         "width": 6.0, "cover": "railing"},
        {"name": "west_catwalk", "from": [-38.0, 0.0, 6.0], "to": [-62.0, 6.5, 8.0],
         "width": 1.6, "cover": "cover_machine"},
        {"name": "lower_approach", "from": [0.0, 0.0, 18.0], "to": [0.0, -6.4, 35.0],
         "width": 6.0, "cover": "cliff_face"},
    ],
    "spawn": {"primary": [-30.0, 1.2, 14.0], "secondary": [30.0, 1.2, 14.0]},
    "cover_spots": [
        [-30.0, 0.0, -4.0], [30.0, 0.0, 4.0], [8.0, 0.0, 12.0],
        [-26.0, 0.0, 8.0], [-13.0, 0.0, 8.0], [13.0, 0.0, 8.0], [26.0, 0.0, 8.0],
    ],
    "placements": PLACEMENTS,
}
with open(os.path.join(WORLD_DIR, "layout.json"), "w") as f:
    json.dump(layout, f, indent=1)
print("== Aetherfall: wrote layout.json ==")

# ---------------------------------------------------------------------------
# lighting + camera + render
# ---------------------------------------------------------------------------
scene.world = bpy.data.worlds.new("AetherfallSky")
scene.world.color = (0.34, 0.55, 0.76)

sun_data = bpy.data.lights.new(name="AetherfallSun", type='SUN')
sun_data.energy = 5.0
sun_data.color = (0.96, 0.93, 0.86)
sun_obj = bpy.data.objects.new("Sun", sun_data)
SCENE_COLL.objects.link(sun_obj)
D = MV((0.0, -0.55, -0.84)).normalized()
sun_obj.rotation_euler = D.to_track_quat('-Z', 'Y').to_euler()

hemi = bpy.data.lights.new(name="Hemi", type='AREA')
hemi.energy = 260.0
hemi.size = 60.0
hemi_obj = bpy.data.objects.new("Hemi", hemi)
SCENE_COLL.objects.link(hemi_obj)

scene.render.engine = 'CYCLES'
scene.cycles.device = 'CPU'
scene.cycles.samples = 12
scene.render.resolution_x = 1280
scene.render.resolution_y = 720
scene.render.film_transparent = False
scene.render.image_settings.file_format = 'PNG'
scene.render.image_settings.color_mode = 'RGBA'

SHOTS = [
    ("01_hero_tower", (0.0, 8.0, 36.0), (0.0, 26.0, -26.0)),
    ("02_combat_platform", (-26.0, 10.0, 18.0), (0.0, 3.0, -8.0)),
    ("03_lower_approach", (0.0, 6.0, 44.0), (0.0, -6.0, 16.0)),
    ("04_canyon_vista", (0.0, -18.0, 54.0), (0.0, -2.0, -30.0)),
    ("05_layout_overview", (0.0, 96.0, 104.0), (0.0, -6.0, -20.0)),
]

cam_data = bpy.data.cameras.new("Cam")
cam_data.lens = 42.0
cam_obj = bpy.data.objects.new("Cam", cam_data)
SCENE_COLL.objects.link(cam_obj)
scene.camera = cam_obj

print("== Aetherfall: rendering ==")
for name, cp, tp in SHOTS:
    cam_data.lens = 30.0 if name.endswith("overview") else 42.0
    cam_obj.location = cp
    direction = MV(tp) - MV(cp)
    cam_obj.rotation_euler = direction.to_track_quat('-Z', 'Y').to_euler()
    scene.render.filepath = os.path.join(SHOT_DIR, name + ".png")
    bpy.ops.render.render(write_still=True)
    print("  rendered", name, os.path.getsize(os.path.join(SHOT_DIR, name + ".png")))

print("== Aetherfall: done ==")
