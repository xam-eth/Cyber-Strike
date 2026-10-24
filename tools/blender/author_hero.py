"""Inspect the *actual* shipped hero/rifle in Blender, author additive clips and export.

Run from the repository root with:
    blender --background --factory-startup --python tools/blender/author_hero.py

This script is deliberately independent of the glTF-space baker. It imports the
already-in-game GLBs, checks their armature, names, clips, weapon markers and
measured bounds, and makes a .blend source file. Aim locomotion is sampled from
both existing actions so the lower body keeps walking/running while the upper
body aims. Reload/hit/death are modest keyframed actions, not a claim of final
human-approved deformation. The runner smoke-tests the Blender GLB before
publishing it; a visual motion review is still necessary.
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
RIFLE = ROOT / "game/assets/weapons/futuristic_rifle/rifle.glb"
# Keep the editable .blend outside the Godot project root. Godot's editor
# tries to import .blend as another scene, competing with hero.glb and causing
# incomplete project imports in CI; only the exported GLB belongs in game/.
BLEND = ROOT / "source-assets/characters/hero/hero_source.blend"
REPORT = ROOT / "docs/asset-inspections/hero-blender.json"
REQUIRED = {"idle", "walk", "run", "aim", "fire"}
AUTHORED = {"aim_walk", "aim_run", "reload", "hit", "death"}
REQUIRED_BONES = {
    "BoneRoot", "Hip", "Pelvis", "Waist", "Spine01", "Spine02",
    "L_Upperarm", "L_Forearm", "L_Hand", "R_Upperarm", "R_Forearm", "R_Hand",
    "L_Thigh", "L_Calf", "L_Foot", "R_Thigh", "R_Calf", "R_Foot",
}
FRAME_RATE = 30


def bounds(objects):
    vertices = [obj.matrix_world @ Vector(corner) for obj in objects if obj.type == "MESH" for corner in obj.bound_box]
    if not vertices:
        raise RuntimeError("No mesh vertices/bounds could be inspected")
    return {"min": [round(min(v[i] for v in vertices), 5) for i in range(3)],
            "max": [round(max(v[i] for v in vertices), 5) for i in range(3)]}


def inspect_actions(arm):
    # Blender's glTF importer appends the target armature name to imported
    # action names ("aim_Armature", etc.). Resolve that relationship explicitly
    # rather than treating the original five GLB clips as absent.
    actions = {}
    for name in REQUIRED:
        choices = [action for action in bpy.data.actions
                   if action.name == name or action.name == f"{name}_{arm.name}"]
        if len(choices) != 1:
            raise RuntimeError(f"Cannot resolve imported {name!r} action: {[a.name for a in bpy.data.actions]}")
        choices[0].name = name
        actions[name] = choices[0]
    if arm.animation_data is None:
        arm.animation_data_create()
    return actions


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


def new_action(arm, name):
    action = bpy.data.actions.new(name)
    action.use_fake_user = True
    arm.animation_data.action = action
    return action


def upper_body(name):
    """Keep the aiming torso level above a moving pelvis and leg cycle.

    Hip parents *both* Pelvis and Waist on this exact rig. If the moving Hip's
    run lean is retained while copying aim's Waist and arm channels, the
    inherited tilt sends the barrel about 22 degrees below the reticle at
    0.3 s of aim_run. Keeping Hip in aim while Pelvis/legs move preserves the
    leg cycle without tipping the whole weapon over.
    """
    return name in {"Hip", "Waist", "Spine01", "Spine02"} or name.startswith((
        "L_Upperarm", "L_Forearm", "L_Elbow", "L_Hand", "L_Clavicle",
        "L_Pinky", "L_Ring", "L_Mid", "L_Index", "L_Thumb",
        "R_Upperarm", "R_Forearm", "R_Elbow", "R_Hand", "R_Clavicle",
        "R_Pinky", "R_Ring", "R_Mid", "R_Index", "R_Thumb",
        "Neck", "Head", "Facial", "L_Eye", "R_Eye",
    ))


def locomotion_aim(arm, source, aiming, name):
    start, finish = map(float, source.frame_range)
    duration = max(1.0, finish - start)
    steady = sample(arm, aiming, float(aiming.frame_range[0]))
    poses = []
    # Include closing frame so the exported loop lands back at the start.
    for step in range(13):
        moving = sample(arm, source, start + duration * step / 12.0)
        mixed = {bone: steady[bone] if upper_body(bone) else moving[bone] for bone in moving}
        poses.append((1.0 + duration * step / 12.0, mixed))
    action = new_action(arm, name)
    for frame, pose in poses:
        insert_pose(arm, pose, frame)
    return action


def radians_quat(axis, degrees):
    return Quaternion(axis, math.radians(degrees))


def keyframed_reaction(arm, source, name, timeline):
    base = sample(arm, source, float(source.frame_range[0]))
    action = new_action(arm, name)
    for frame, weights in timeline:
        rotations = {}
        offsets = {}
        for bone_name, (axis, degrees) in weights.get("rotate", {}).items():
            rotations[bone_name] = radians_quat(axis, degrees)
        for bone_name, xyz in weights.get("move", {}).items():
            offsets[bone_name] = Vector(xyz)
        insert_pose(arm, base, frame, rotations, offsets)
    return action


def glb_json(path):
    payload = path.read_bytes()
    if payload[:4] != b"glTF":
        raise RuntimeError(f"Blender did not export a GLB: {path}")
    size = struct.unpack_from("<I", payload, 12)[0]
    return json.loads(payload[20:20 + size])


def main():
    bpy.ops.object.select_all(action="SELECT")
    bpy.ops.object.delete(use_global=False)
    bpy.context.scene.render.fps = FRAME_RATE
    bpy.ops.import_scene.gltf(filepath=str(HERO))
    hero_objects = list(bpy.context.scene.objects)
    armatures = [obj for obj in hero_objects if obj.type == "ARMATURE"]
    if len(armatures) != 1:
        raise RuntimeError(f"Expected one real hero armature; imported {len(armatures)}")
    arm = armatures[0]
    bones = set(arm.pose.bones.keys())
    if not REQUIRED_BONES <= bones:
        raise RuntimeError(f"Hero bone names changed: {sorted(REQUIRED_BONES - bones)} missing")
    actions = inspect_actions(arm)
    arm.animation_data.action = actions["aim"]
    # The input is also the *previous* export on subsequent authoring runs.
    # Remove its generated clips before baking replacements: Blender would
    # otherwise rename the new actions with .001 and silently keep the old
    # animation under the name Godot plays. Imported actions may also carry
    # the armature suffix, depending on Blender's glTF importer version.
    stale = [action for action in bpy.data.actions
             if any(action.name == clip or action.name.startswith(f"{clip}_")
                    or action.name.startswith(f"{clip}.") for clip in AUTHORED)]
    for action in stale:
        bpy.data.actions.remove(action)
    hero_bounds = bounds(hero_objects)
    skeleton = [{"name": bone.name, "parent": bone.parent.name if bone.parent else None,
                 "head": [round(v, 5) for v in bone.head_local],
                 "tail": [round(v, 5) for v in bone.tail_local]}
                for bone in arm.data.bones]

    bpy.ops.import_scene.gltf(filepath=str(RIFLE))
    weapon_objects = [obj for obj in bpy.context.scene.objects if obj not in hero_objects]
    weapon_bounds = bounds(weapon_objects)
    muzzle = next((obj for obj in weapon_objects if obj.name == "MuzzlePoint"), None)
    grip = next((obj for obj in weapon_objects if obj.name == "GripPoint"), None)
    if muzzle is None or grip is None:
        raise RuntimeError("Imported rifle has no measured MuzzlePoint / GripPoint markers")
    weapon_report = {"bounds_m": weapon_bounds,
                     "muzzle_m": [round(v, 5) for v in muzzle.matrix_world.translation],
                     "grip_m": [round(v, 5) for v in grip.matrix_world.translation],
                     "rigged": any(obj.type == "ARMATURE" for obj in weapon_objects),
                     "objects": [obj.name for obj in weapon_objects]}

    # Keep the rifle as a *separate* reference collection. The runtime socket
    # uses the measured MuzzlePoint, so applying an arbitrary Blender parent/
    # offset here would invalidate the transform that already passes Godot QA.
    collection = bpy.data.collections.new("Rifle_reference__runtime_socket_in_Godot")
    bpy.context.scene.collection.children.link(collection)
    for obj in weapon_objects:
        for parent in list(obj.users_collection):
            parent.objects.unlink(obj)
        collection.objects.link(obj)
        obj.hide_render = True
    report = {
        "source_hero": str(HERO.relative_to(ROOT)), "source_rifle": str(RIFLE.relative_to(ROOT)),
        "blender_version": bpy.app.version_string, "hero_bounds_model_units": hero_bounds,
        "armature": arm.name, "bone_count": len(skeleton), "bones": skeleton,
        "original_actions": {name: list(map(float, action.frame_range)) for name, action in actions.items()},
        "rifle": weapon_report,
        "limitations": ["Runtime hero is scaled from a 1-unit source to 1.78 m.",
                        "Rifle is one combined mesh: no detachable magazine or authored bolt mechanism.",
                        "Reload is a keyframed handling cue, not simulated finger articulation.",
                        "Death uses a keyframed side fall; it is not a physics ragdoll.",
                        "Headless Blender inspection + automated Godot QA do not replace human motion review."],
    }

    locomotion_aim(arm, actions["walk"], actions["aim"], "aim_walk")
    locomotion_aim(arm, actions["run"], actions["aim"], "aim_run")
    # Recharge gesture, reviewed after a real 390x844 player-camera capture:
    # the original 13-degree support-arm bend stayed hidden by the torso and
    # the clip=reload trace was NOT visual evidence. Without inventing a
    # detachable magazine on this single-mesh rifle, stage a clearly readable
    # ENERGY-CELL CHECK: shoulder the gun, briefly twist the upper torso so
    # the receiver/left support palm can be seen from the rear player camera,
    # hold while pressing the cell latch, then settle back into aim. The first
    # Blender take flared the left elbow by -22 degrees Z, but in WebGL it
    # left the support palm isolated ~30 px from the rifle; it was visually
    # unreadable as an actual reload. Keep the X forearm bend that moves the
    # left hand along the weapon, using a restrained spine *bone-local Y*
    # turn to expose the gesture instead. Browser F7 at the positive turn had
    # muzzle x=-0.105 m (CSS≈140 px, behind the helmet): use the opposite turn
    # so the actual rifle has a chance to silhouette on the player's right.
    # Neither root motion nor a detachable magazine is fabricated. The right
    # trigger hand still drives the actual weapon socket, and Godot retimes
    # the clip to the ammo reload time. 1=ready, 8=withdraw, 17-25=receiver
    # hold, 35=regrip, 46=ready. Recheck the in-game camera before accepting.
    keyframed_reaction(arm, actions["aim"], "reload", [
        (1, {}),
        (8, {"rotate": {"Spine01": ((0, 1, 0), -7),
                        "R_Hand": ((1, 0, 0), 8),
                        "L_Upperarm": ((1, 0, 0), 9),
                        "L_Forearm": ((1, 0, 0), -18)}}),
        (17, {"rotate": {"Spine01": ((0, 1, 0), -20),
                         "Spine02": ((0, 0, 1), 4),
                         "R_Hand": ((1, 0, 0), 24),
                         "L_Upperarm": ((1, 0, 0), 16),
                         "L_Forearm": ((-0.97, 0, 0.25), 39),
                         "L_Hand": ((1, 0, 0), 34)}}),
        (25, {"rotate": {"Spine01": ((0, 1, 0), -20),
                         "Spine02": ((0, 0, 1), 4),
                         "R_Hand": ((1, 0, 0), 22),
                         "L_Upperarm": ((1, 0, 0), 15),
                         "L_Forearm": ((-0.97, 0, 0.25), 38),
                         "L_Hand": ((1, 0, 0), 30)}}),
        (35, {"rotate": {"Spine01": ((0, 1, 0), -8),
                         "R_Hand": ((1, 0, 0), 9),
                         "L_Upperarm": ((1, 0, 0), 7),
                         "L_Forearm": ((-0.97, 0, 0.25), 14),
                         "L_Hand": ((1, 0, 0), 11)}}),
        (46, {}),
    ])
    keyframed_reaction(arm, actions["aim"], "hit", [
        (1, {}), (4, {"rotate": {"Spine01": ((1, 0, 0), -11),
                               "Spine02": ((0, 0, 1), 8), "R_Clavicle": ((0, 0, 1), -6)}}),
        (10, {"rotate": {"Spine01": ((1, 0, 0), 4), "Spine02": ((0, 0, 1), -3)}}),
        (17, {}),
    ])
    # Stage a readable sideways collapse around the measured BoneRoot pivot
    # (~1 m above the floor), not a fold of Spine01 while sinking Hip through
    # the deck. BoneRoot's local (.95,-.05,.30) axis maps to viewer +Z and a
    # -90-degree roll leaves the rifle hand above the body. Offsets are in the
    # *bone's pose space*: [-.12,-.17,+.36] drops the world-space hip ~0.74 m.
    # The intermediate lean keeps the boots on the floor while weight shifts;
    # the end pose lies on its left side. This is authored motion, not a ragdoll.
    roll_axis = (0.95, -0.05, 0.30)
    death_mid = {"rotate": {"BoneRoot": (roll_axis, -42),
                            "Spine01": ((1, 0, 0), -8),
                            "L_Thigh": ((1, 0, 0), -14),
                            "R_Thigh": ((1, 0, 0), -8)},
                 "move": {"BoneRoot": (-0.035, -0.048, 0.102)}}
    death_rest = {"rotate": {"BoneRoot": (roll_axis, -90),
                             "Spine01": ((1, 0, 0), -15),
                             "L_Thigh": ((1, 0, 0), -24),
                             "L_Calf": ((1, 0, 0), 30),
                             "R_Thigh": ((1, 0, 0), -10),
                             "R_Calf": ((1, 0, 0), 15)},
                  "move": {"BoneRoot": (-0.124, -0.169, 0.359)}}
    keyframed_reaction(arm, actions["idle"], "death", [
        (1, {}),
        (8, {"rotate": {"BoneRoot": (roll_axis, -9)}}),
        (19, death_mid),
        (32, death_rest),
        (46, death_rest),
    ])
    # Show the aim pose when opening the .blend, with reference rifle hidden but
    # available for direct viewport inspection. Keep all new actions in file.
    arm.animation_data.action = actions["aim"]
    bpy.context.scene.frame_set(1)
    BLEND.parent.mkdir(parents=True, exist_ok=True)
    bpy.ops.file.pack_all()
    bpy.ops.wm.save_as_mainfile(filepath=str(BLEND), compress=True)

    bpy.ops.object.select_all(action="DESELECT")
    for obj in hero_objects:
        obj.hide_render = False
        obj.select_set(True)
    bpy.context.view_layer.objects.active = arm
    with tempfile.TemporaryDirectory(prefix="cyber-strike-blender-") as directory:
        exported = Path(directory) / "hero.glb"
        props = bpy.ops.export_scene.gltf.get_rna_type().properties.keys()
        kwargs = {"filepath": str(exported), "export_format": "GLB", "use_selection": True,
                  "export_animations": True}
        if "export_nla_strips" in props:
            kwargs["export_nla_strips"] = False
        if "export_animation_mode" in props:
            kwargs["export_animation_mode"] = "ACTIONS"
        bpy.ops.export_scene.gltf(**kwargs)
        document = glb_json(exported)
        names = {clip.get("name", "") for clip in document.get("animations", [])}
        expected = REQUIRED | {"aim_walk", "aim_run", "reload", "hit", "death"}
        if not expected <= names:
            raise RuntimeError(f"Exported GLB is missing {sorted(expected - names)}; got {sorted(names)}")
        joints = {document["nodes"][index].get("name")
                  for skin in document.get("skins", []) for index in skin["joints"]}
        if not REQUIRED_BONES <= joints:
            raise RuntimeError(f"Exported skeleton changed bones: {sorted(REQUIRED_BONES - joints)}")
        shutil.copy2(exported, HERO)
        report["exported_actions"] = sorted(names)
        report["exported_hero_bytes"] = HERO.stat().st_size
        report["blend_bytes"] = BLEND.stat().st_size
    REPORT.parent.mkdir(parents=True, exist_ok=True)
    REPORT.write_text(json.dumps(report, indent=2) + "\n")
    print(f"BLENDER HERO OK: {len(skeleton)} real bones, {len(report['exported_actions'])} clips, "
          f"{HERO.stat().st_size} bytes GLB, {BLEND.stat().st_size} bytes .blend")
    print(f"Inspection: {REPORT.relative_to(ROOT)}")


if __name__ == "__main__":
    main()
