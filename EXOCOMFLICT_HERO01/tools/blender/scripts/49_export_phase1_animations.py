"""Final Phase-1 animation exports (scripts 46-48 must pass first).

Exports BOTH shipped animation-bearing GLBs with the established script
18/32/44 settings:
- assets/characters/HERO_01_RIGGED.glb  (armature + body + undersuit + all Actions)
- animations/HERO_01_ANIMATIONS.glb     (skeleton-only, all Actions)
Weapon GLB is untouched. After this script, run:
  python3 tools/patch_glb_double_sided.py assets/characters/HERO_01_RIGGED.glb
  .venv/bin/python tools/validate_exports.py
  .venv/bin/python tools/diff_rigged_glb.py <pre-phase1-rigged.glb> assets/characters/HERO_01_RIGGED.glb --anim-tol 1e-6
"""
import bpy, os

PROJ = "/home/user/Cyber-Strike/EXOCOMFLICT_HERO01"
bpy.ops.wm.open_mainfile(filepath=f"{PROJ}/blender/HERO_01_working.blend")
# The blend may have been saved in Pose Mode (script 60); selection operators
# below only poll in Object Mode.
if bpy.context.object is not None and bpy.context.object.mode != 'OBJECT':
    bpy.ops.object.mode_set(mode='OBJECT')
arm = bpy.data.objects["HERO_01_Armature"]
body = bpy.data.objects["HERO_01_BODY"]
under = bpy.data.objects["HERO_01_UNDERSUIT"]
sc = bpy.context.scene
sc.frame_set(0)
bpy.context.view_layer.update()

expected = ["Aim_Idle", "Fire", "Idle", "Weapon_Lower", "Weapon_Raise", "Weapon_Raise_To_Aim"]
have = sorted(a.name for a in bpy.data.actions)
print("ACTIONS IN BLEND:", have)
if have != expected:
    raise RuntimeError(f"Unexpected action set: {have} != {expected}")


def select(objs):
    bpy.ops.object.select_all(action='DESELECT')
    for o in objs:
        o.select_set(True)
    bpy.context.view_layer.objects.active = objs[0]


select([arm, body, under])
rigged_path = f"{PROJ}/assets/characters/HERO_01_RIGGED.glb"
bpy.ops.export_scene.gltf(filepath=rigged_path, export_format='GLB', use_selection=True, export_yup=True,
    export_apply=False, export_skins=True, export_def_bones=False,
    export_animations=True, export_animation_mode='ACTIONS',
    export_force_sampling=True, export_optimize_animation_size=False, export_materials='EXPORT')
print("EXPORTED RIGGED", rigged_path, os.path.getsize(rigged_path))

select([arm])
anim_path = f"{PROJ}/animations/HERO_01_ANIMATIONS.glb"
bpy.ops.export_scene.gltf(filepath=anim_path, export_format='GLB', use_selection=True, export_yup=True,
    export_animations=True, export_animation_mode='ACTIONS', export_force_sampling=True,
    export_optimize_animation_size=False)
print("EXPORTED ANIMATIONS", anim_path, os.path.getsize(anim_path))
print("DONE")
