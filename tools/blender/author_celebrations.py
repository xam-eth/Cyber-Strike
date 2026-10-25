"""Author each hero's celebration clip in Blender and export it as its own GLB.

Run from the repository root with:

    blender --background --factory-startup --python-exit-code 1 \
        --python tools/blender/author_celebrations.py

Why a separate file per hero
----------------------------
The celebration is a hero's signature: the beat a player sees when they open
their operative's page. Two heroes must not share it, and the hero art is
locked, so nothing here touches `hero.glb` -- the mesh, the materials and the
shipped clips stay byte-identical. Each hero gets one animation-only GLB under
`game/assets/characters/hero/celebrations/`, holding the same skeleton the hero
uses, so the shell can bind the clip onto the model it already loaded
(ui/hero_stage.js) and the engine can do the same later.

`hero_definition.gd` is the list of heroes; only the ones with a celebration
authored here get one, and the page falls back to the plain `aim` beat for the
rest. That is deliberate: a hero without a signature move should not borrow
someone else's.

Bone axes on this rig (measured, see the reload/death notes in author_hero.py):
local X swings a limb forward/back in the sagittal plane, local Z abducts it
sideways, and the sign of Z differs between the left and right side.
"""

from __future__ import annotations

import json
import math
import shutil
import struct
import tempfile
from pathlib import Path

import bpy
from mathutils import Quaternion, Vector

ROOT = Path(__file__).resolve().parents[2]
HERO = ROOT / "game/assets/characters/hero/hero.glb"
OUT_DIR = ROOT / "game/assets/characters/hero/celebrations"
BLEND = ROOT / "source-assets/characters/hero/hero_celebrations.blend"
REPORT = ROOT / "docs/asset-inspections/celebrations.json"
FRAME_RATE = 30
CLIP = "celebration"

REQUIRED_BONES = {
    "BoneRoot", "Hip", "Pelvis", "Waist", "Spine01", "Spine02",
    "Neck", "Head",
    "L_Upperarm", "L_Forearm", "L_Hand", "R_Upperarm", "R_Forearm", "R_Hand",
    "L_Thigh", "L_Calf", "L_Foot", "R_Thigh", "R_Calf", "R_Foot",
}

# One entry per hero id from game/scripts/progression/hero_definition.gd.
#
# `exo_operative` -- "EXO: LOCKDOWN". The operative drops into a low, braced
# crouch as if the pad were magnetising his boots, then drives up and throws
# both arms open with the chin lifted, holds the silhouette long enough to read,
# and settles. Chosen because it is readable from the silhouette alone at 200 px
# tall, it needs no props beyond the rig, and it says "deployed" -- which is the
# one thing this page is about. It is authored motion, not final hand-animated
# polish; a human motion review still has to pass it.
HEROES = {
    "exo_operative": {
        "label": "Lockdown",
        "notes": "Braced drop, then a two-arm flare with the chin up; ends back at idle.",
        "timeline": [
            (1, {}),
            (6, {"rotate": {"Spine01": ((1, 0, 0), 7), "Spine02": ((1, 0, 0), 4),
                            "Neck": ((1, 0, 0), 5), "Head": ((1, 0, 0), 4),
                            "L_Thigh": ((1, 0, 0), 6), "R_Thigh": ((1, 0, 0), 6)},
                 "move": {"Hip": (0, -0.02, 0)}}),
            (14, {"rotate": {"Spine01": ((1, 0, 0), -7), "Spine02": ((1, 0, 0), -4),
                             "Neck": ((1, 0, 0), -5), "Head": ((1, 0, 0), -6),
                             "R_Upperarm": ((0, 0, 1), 54), "L_Upperarm": ((0, 0, 1), -54),
                             "R_Forearm": ((1, 0, 0), 16), "L_Forearm": ((1, 0, 0), 16),
                             "L_Clavicle": ((0, 0, 1), -8), "R_Clavicle": ((0, 0, 1), 8)},
                  "move": {"Hip": (0, 0.014, 0)}}),
            (20, {"rotate": {"Spine01": ((1, 0, 0), -10), "Spine02": ((1, 0, 0), -5),
                             "Neck": ((1, 0, 0), -6), "Head": ((1, 0, 0), -8),
                             "R_Upperarm": ((0, 0, 1), 68), "L_Upperarm": ((0, 0, 1), -68),
                             "R_Forearm": ((1, 0, 0), 22), "L_Forearm": ((1, 0, 0), 22),
                             "L_Clavicle": ((0, 0, 1), -11), "R_Clavicle": ((0, 0, 1), 11)},
                  "move": {"Hip": (0, 0.018, 0)}}),
            (30, {"rotate": {"Spine01": ((1, 0, 0), -6), "Spine02": ((1, 0, 0), -3),
                             "Neck": ((1, 0, 0), -4), "Head": ((1, 0, 0), -5),
                             "R_Upperarm": ((0, 0, 1), 58), "L_Upperarm": ((0, 0, 1), -58),
                             "R_Forearm": ((1, 0, 0), 14), "L_Forearm": ((1, 0, 0), 14),
                             "L_Clavicle": ((0, 0, 1), -9), "R_Clavicle": ((0, 0, 1), 9)},
                  "move": {"Hip": (0, 0.012, 0)}}),
            (44, {"rotate": {"Spine01": ((1, 0, 0), -8), "Neck": ((1, 0, 0), -4),
                             "Head": ((1, 0, 0), -5),
                             "R_Upperarm": ((0, 0, 1), 55), "L_Upperarm": ((0, 0, 1), -55),
                             "R_Forearm": ((1, 0, 0), 13), "L_Forearm": ((1, 0, 0), 13),
                             "L_Clavicle": ((0, 0, 1), -9), "R_Clavicle": ((0, 0, 1), 9)},
                  "move": {"Hip": (0, 0.012, 0)}}),
            (56, {"rotate": {"Spine01": ((1, 0, 0), 2),
                             "R_Upperarm": ((0, 0, 1), 16), "L_Upperarm": ((0, 0, 1), -16)}}),
            (68, {}),
        ],
    },
}


def radians_quat(axis, degrees):
    return Quaternion(Vector(axis).normalized(), math.radians(degrees))


def sample(arm, action, frame):
    arm.animation_data.action = action
    bpy.context.scene.frame_set(int(round(frame)))
    return {
        bone.name: (bone.rotation_quaternion.copy(), bone.location.copy(), bone.scale.copy())
        for bone in arm.pose.bones
    }


def insert_pose(arm, pose, frame, rotations=None, offsets=None):
    rotations = rotations or {}
    offsets = offsets or {}
    for bone in arm.pose.bones:
        rotation, location, scale = pose[bone.name]
        bone.rotation_mode = "QUATERNION"
        bone.rotation_quaternion = rotation @ rotations.get(bone.name, Quaternion())
        bone.location = location + offsets.get(bone.name, Vector((0, 0, 0)))
        bone.scale = scale
        for channel in ("rotation_quaternion", "location", "scale"):
            bone.keyframe_insert(data_path=channel, frame=frame, group=bone.name)


def glb_json(path):
    payload = path.read_bytes()
    if payload[:4] != b"glTF":
        raise RuntimeError(f"Blender did not export a GLB: {path}")
    size = struct.unpack_from("<I", payload, 12)[0]
    return json.loads(payload[20:20 + size])


def main():
    bpy.ops.wm.read_factory_settings(use_empty=True)
    bpy.context.scene.render.fps = FRAME_RATE
    bpy.ops.import_scene.gltf(filepath=str(HERO))

    hero_objects = list(bpy.context.scene.objects)
    armatures = [obj for obj in hero_objects if obj.type == "ARMATURE"]
    if len(armatures) != 1:
        raise RuntimeError(f"Expected one hero armature; imported {len(armatures)}")
    arm = armatures[0]

    def find_action(name):
        for action in bpy.data.actions:
            if action.name == name or action.name == f"{name}_{arm.name}" or action.name.startswith(f"{name}_"):
                return action
        raise RuntimeError(f"No '{name}' action in hero.glb; found {[a.name for a in bpy.data.actions]}")

    idle = find_action("idle")
    idle.name = "idle"
    base = sample(arm, idle, float(idle.frame_range[0]))

    # Only the rest pose is needed from the import; the hero's own clips are
    # shipped in hero.glb and must not be duplicated into a celebration file.
    for action in list(bpy.data.actions):
        if action.name != "idle":
            bpy.data.actions.remove(action)
    idle.use_fake_user = True

    os_bones = set(arm.pose.bones.keys())
    missing = REQUIRED_BONES - os_bones
    if missing:
        raise RuntimeError(f"Hero bone names changed: {sorted(missing)} missing")

    OUT_DIR.mkdir(parents=True, exist_ok=True)
    report = {
        "blender_version": bpy.app.version_string,
        "source_hero": str(HERO.relative_to(ROOT)),
        "frame_rate": FRAME_RATE,
        "clip": CLIP,
        "heroes": {},
        "limitations": [
            "Authored keyframe motion, not hand-animated polish; human motion review is still required.",
            "Celebration files hold the skeleton and one action only: no mesh, no materials, no textures.",
            "hero.glb is never rewritten here; the locked hero art stays untouched.",
        ],
    }

    for hero_id, spec in HEROES.items():
        # A fresh action per hero, named exactly `celebration`: the shell binds
        # by name, and a `.001` suffix would silently play nothing.
        for stale in [a for a in bpy.data.actions if a.name.startswith(CLIP)]:
            bpy.data.actions.remove(stale)
        action = bpy.data.actions.new(CLIP)
        action.use_fake_user = True
        arm.animation_data.action = action

        for frame, weights in spec["timeline"]:
            rotations = {bone: radians_quat(axis, degrees)
                         for bone, (axis, degrees) in weights.get("rotate", {}).items()}
            offsets = {bone: Vector(xyz) for bone, xyz in weights.get("move", {}).items()}
            unknown = set(rotations) | set(offsets)
            unknown -= os_bones
            if unknown:
                raise RuntimeError(f"{hero_id}: celebration targets unknown bones {sorted(unknown)}")
            insert_pose(arm, base, frame, rotations, offsets)

        first, last = action.frame_range
        for fcurve in action.fcurves:
            for keyframe in fcurve.keyframe_points:
                keyframe.interpolation = "BEZIER"

        arm.animation_data.action = action
        bpy.context.scene.frame_set(int(first))

        OUT_DIR.mkdir(parents=True, exist_ok=True)
        target = OUT_DIR / f"{hero_id}.glb"
        bpy.ops.object.select_all(action="DESELECT")
        for obj in hero_objects:
            if obj.type == "ARMATURE":
                obj.select_set(True)
        bpy.context.view_layer.objects.active = arm

        with tempfile.TemporaryDirectory(prefix="cyber-strike-celebration-") as directory:
            exported = Path(directory) / f"{hero_id}.glb"
            props = bpy.ops.export_scene.gltf.get_rna_type().properties.keys()
            kwargs = {
                "filepath": str(exported),
                "export_format": "GLB",
                "use_selection": True,
                "export_animations": True,
            }
            if "export_nla_strips" in props:
                kwargs["export_nla_strips"] = False
            if "export_animation_mode" in props:
                kwargs["export_animation_mode"] = "ACTIONS"
            if "export_skins" in props:
                kwargs["export_skins"] = False
            if "export_apply" in props:
                kwargs["export_apply"] = False
            if "export_materials" in props:
                kwargs["export_materials"] = "NONE"
            bpy.ops.export_scene.gltf(**kwargs)

            document = glb_json(exported)
            names = [clip.get("name", "") for clip in document.get("animations", [])]
            if CLIP not in names:
                raise RuntimeError(f"{hero_id}: exported GLB has no '{CLIP}' clip; got {names}")
            joints = {document["nodes"][index].get("name")
                      for skin in document.get("skins", []) for index in skin["joints"]}
            nodes = {node.get("name") for node in document.get("nodes", [])}
            if not (joints | nodes) & os_bones:
                raise RuntimeError(f"{hero_id}: exported GLB has none of the hero's bones")
            shutil.copy2(exported, target)

        report["heroes"][hero_id] = {
            "label": spec["label"],
            "file": str(target.relative_to(ROOT)),
            "clip": CLIP,
            "frames": [round(float(first), 2), round(float(last), 2)],
            "seconds": round((float(last) - float(first)) / FRAME_RATE, 3),
            "bones_animated": sorted({bone for _, weights in spec["timeline"]
                                      for bone in list(weights.get("rotate", {})) + list(weights.get("move", {}))}),
            "bytes": target.stat().st_size,
            "notes": spec["notes"],
        }
        print(f"CELEBRATION {hero_id}: {target.name} {target.stat().st_size} bytes, "
              f"{report['heroes'][hero_id]['seconds']}s")

    manifest = {
        "note": "Generated by tools/blender/author_celebrations.py -- do not edit by hand.",
        "clip": CLIP,
        "heroes": {hero_id: {key: entry[key] for key in ("label", "file", "clip", "seconds", "notes")}
                   for hero_id, entry in report["heroes"].items()},
    }
    (OUT_DIR / "manifest.json").write_text(json.dumps(manifest, indent=2) + "\n")

    BLEND.parent.mkdir(parents=True, exist_ok=True)
    bpy.ops.file.pack_all()
    bpy.ops.wm.save_as_mainfile(filepath=str(BLEND), compress=True)

    REPORT.parent.mkdir(parents=True, exist_ok=True)
    REPORT.write_text(json.dumps(report, indent=2) + "\n")
    print(f"BLENDER CELEBRATIONS OK: {len(report['heroes'])} heroes, "
          f"{BLEND.stat().st_size} bytes .blend")
    print(f"Report: {REPORT.relative_to(ROOT)}")


if __name__ == "__main__":
    main()
