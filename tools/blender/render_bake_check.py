#!/usr/bin/env python3
"""Quick textured inspection renders of baked Aetherfall ground/hull assets.

    LD_LIBRARY_PATH=$PWD/tools/.cache/x11stubs .venv/bin/python tools/blender/render_bake_check.py deck_6x6 wall_section lowland_field
"""
import math
import os
import sys

import bpy

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
WORLD = os.path.join(ROOT, "game", "assets", "world", "aetherfall")
OUT = os.path.join(ROOT, "docs", "world", "aetherfall", "bake_inspection")


def find_glb(name):
    if "/" in name:
        return name
    for base, _d, files in os.walk(WORLD):
        for f in files:
            if f == name + ".glb":
                return os.path.join(base, f)
    raise SystemExit(f"not found: {name}")


def render(asset):
    tag = os.path.splitext(os.path.basename(asset.rstrip("/")))[0]
    if "/" in asset:
        tag += "_prebake"
    bpy.ops.wm.read_factory_settings(use_empty=True)
    scene = bpy.context.scene
    scene.render.engine = "CYCLES"
    scene.cycles.samples = 48
    scene.cycles.use_denoising = True
    scene.render.resolution_x = 800
    scene.render.resolution_y = 600
    scene.render.image_settings.file_format = "PNG"
    try:
        scene.view_settings.view_transform = "ACES"
    except Exception:
        scene.view_settings.view_transform = "AgX"

    bpy.ops.import_scene.gltf(filepath=find_glb(asset))
    # world: soft studio sky (neutral-cool like Aetherfall IBL)
    world = bpy.data.worlds.new("w")
    scene.world = world
    world.use_nodes = True
    bg = world.node_tree.nodes["Background"]
    bg.inputs[0].default_value = (0.20, 0.26, 0.34, 1.0)
    bg.inputs[1].default_value = 0.7

    # key + rim lights
    for loc, energy, size in [((4, -3, 5), 900, 3.0), ((-5, 2, 3), 350, 4.0)]:
        ld = bpy.data.lights.new("L", "AREA")
        ld.energy, ld.size = energy, size
        lo = bpy.data.objects.new("L", ld)
        scene.collection.objects.link(lo)
        lo.location = loc
        d = lo.location.copy()
        lo.rotation_euler = (math.radians(50), 0, math.atan2(-loc[0], -loc[1]))

    # frame the model
    import mathutils
    pts = []
    for ob in scene.objects:
        if ob.type == "MESH":
            pts += [ob.matrix_world @ mathutils.Vector(c) for c in ob.bound_box]
    ctr = sum(pts, mathutils.Vector()) / len(pts)
    radius = max((p - ctr).length for p in pts)
    cam = bpy.data.cameras.new("cam")
    co = bpy.data.objects.new("cam", cam)
    scene.collection.objects.link(co)
    scene.camera = co
    dist = radius * 1.9
    co.location = ctr + mathutils.Vector((dist * 0.72, -dist * 0.62, dist * 0.52))
    direction = ctr - co.location
    co.rotation_euler = direction.to_track_quat("-Z", "Y").to_euler()

    scene.render.filepath = os.path.join(OUT, f"{tag}_studio_check.png")
    bpy.ops.render.render(write_still=True)
    print("rendered", scene.render.filepath)


if __name__ == "__main__":
    for a in sys.argv[1:]:
        render(a)
