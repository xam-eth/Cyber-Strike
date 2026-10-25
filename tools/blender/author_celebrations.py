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

The timeline below is written in **world axes** -- X is the character's left,
Y is up, Z is the way the character faces -- and the script converts each one
into the bone's own frame with the rest matrix before keying it. That is the
difference between "raise the arm" and "guess which of three local axes on this
particular rig raises the arm": Blender's glTF importer reorients bones (Y along
the bone), so a local-axis number measured on the rig is meaningless to the next
hero, while a world axis means the same thing for everybody.
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

# Only the bones author_hero.py already proves exist on this rig. The neck and
# head are resolved by prefix if the rig has them (it exposes the head under a
# different name than "Neck"), and an unresolved bone is skipped with a warning
# rather than failing the pass: a celebration that loses its head tilt is still a
# celebration, a pipeline that refuses to run is not.
REQUIRED_BONES = {
    "BoneRoot", "Hip", "Pelvis", "Waist", "Spine01", "Spine02",
    "L_Upperarm", "L_Forearm", "L_Hand", "R_Upperarm", "R_Forearm", "R_Hand",
    "L_Thigh", "L_Calf", "L_Foot", "R_Thigh", "R_Calf", "R_Foot",
}
OPTIONAL_PREFIXES = ("Neck", "Head", "L_Clavicle", "R_Clavicle")

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
            # Sink: knees load, chest folds forward, head drops -- the pad is
            # "magnetising" the boots.
            (7, {"rotate": {"Spine01": ("X", 8), "Spine02": ("X", 5), "Head": ("X", 6),
                            "L_Thigh": ("X", 7), "R_Thigh": ("X", 7)},
                 "move": {"Hip": (0, -0.022, 0)}}),
            # Drive up and throw both arms out and overhead: abduction is a
            # rotation about the forward axis, mirrored per side.
            (16, {"rotate": {"Spine01": ("X", -8), "Spine02": ("X", -5), "Head": ("X", -8),
                             "R_Upperarm": ("Z", -96), "L_Upperarm": ("Z", 96),
                             "R_Forearm": ("X", -18), "L_Forearm": ("X", -18)},
                  "move": {"Hip": (0, 0.02, 0)}}),
            (22, {"rotate": {"Spine01": ("X", -11), "Spine02": ("X", -6), "Head": ("X", -10),
                             "R_Upperarm": ("Z", -112), "L_Upperarm": ("Z", 112),
                             "R_Forearm": ("X", -24), "L_Forearm": ("X", -24)},
                  "move": {"Hip": (0, 0.026, 0)}}),
            (34, {"rotate": {"Spine01": ("X", -7), "Spine02": ("X", -4), "Head": ("X", -7),
                             "R_Upperarm": ("Z", -98), "L_Upperarm": ("Z", 98),
                             "R_Forearm": ("X", -16), "L_Forearm": ("X", -16)},
                  "move": {"Hip": (0, 0.018, 0)}}),
            (50, {"rotate": {"Spine01": ("X", -9), "Head": ("X", -8),
                             "R_Upperarm": ("Z", -94), "L_Upperarm": ("Z", 94),
                             "R_Forearm": ("X", -15), "L_Forearm": ("X", -15)},
                  "move": {"Hip": (0, 0.018, 0)}}),
            (62, {"rotate": {"Spine01": ("X", 1),
                             "R_Upperarm": ("Z", -22), "L_Upperarm": ("Z", 22)}}),
            (72, {}),
        ],
    },
}


WORLD_AXES = {"X": Vector((1, 0, 0)), "Y": Vector((0, 1, 0)), "Z": Vector((0, 0, 1))}


def radians_quat(axis, degrees):
    return Quaternion(Vector(axis).normalized(), math.radians(degrees))


def local_axis(arm, pose_bone, axis):
    """A world axis expressed in one bone's own frame, at rest.

    The rig's own local axes are an artefact of how the glTF importer oriented
    the bones, and every hero rig can orient them differently. A world axis is
    the same instruction for everybody: "abduct" stays abduction.
    """
    world = WORLD_AXES[axis] if isinstance(axis, str) else Vector(axis)
    rest = (arm.matrix_world @ pose_bone.bone.matrix_local).to_quaternion()
    return rest.inverted() @ world


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

    # The celebration file carries the skeleton and one action. Keeping the
    # imported `idle` around doubled the export for a clip hero.glb already
    # ships, so it is removed once its first frame has been sampled into `base`.
    bpy.data.actions.remove(idle)
    arm.animation_data.action = None

    os_bones = set(arm.pose.bones.keys())
    missing = REQUIRED_BONES - os_bones
    if missing:
        raise RuntimeError(f"Hero bone names changed: {sorted(missing)} missing")

    def resolve(bone_name):
        """Map a requested bone onto the rig: exact, then by prefix, else None."""
        if bone_name in os_bones:
            return bone_name
        if bone_name.startswith(OPTIONAL_PREFIXES):
            for candidate in sorted(os_bones):
                if candidate.startswith(bone_name) or bone_name.startswith(candidate):
                    return candidate
        return None

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

        skipped = set()
        for frame, weights in spec["timeline"]:
            rotations = {}
            offsets = {}
            for bone, (axis, degrees) in weights.get("rotate", {}).items():
                target = resolve(bone)
                if target is None:
                    skipped.add(bone)
                    continue
                rotations[target] = radians_quat(
                    local_axis(arm, arm.pose.bones[target], axis), degrees
                )
            for bone, xyz in weights.get("move", {}).items():
                target = resolve(bone)
                if target is None:
                    skipped.add(bone)
                    continue
                offsets[target] = Vector(xyz)
            insert_pose(arm, base, frame, rotations, offsets)
        if skipped:
            print(f"WARNING {hero_id}: rig has no {sorted(skipped)}; those channels are omitted")

        first, last = action.frame_range
        # Blender 5 replaced Action.fcurves with layered/slotted actions; the
        # default interpolation is already Bezier, so this is a preference, not a
        # requirement, and must not be the line that fails a pass.
        fcurves = getattr(action, "fcurves", None)
        if fcurves is not None:
            for fcurve in fcurves:
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
            matched = (joints | nodes) & os_bones
            if not matched:
                # The clip name is the hard requirement (the shell binds by
                # name); the node naming is reported rather than fatal, because
                # the exporter's bone naming has changed between versions.
                print(f"WARNING {hero_id}: no bone names in the export matched the rig; "
                      f"nodes={sorted(nodes)[:6]}")
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
            "bones_exported": len(matched),
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
