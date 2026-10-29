"""Re-export ONLY HERO_01_RIGGED.glb from the fixed working blend, with the exact
settings of script 18 (weapon/animations GLBs untouched)."""
import bpy, os
PROJ="/home/user/Cyber-Strike/EXOCOMFLICT_HERO01"
bpy.ops.wm.open_mainfile(filepath=f"{PROJ}/blender/HERO_01_working.blend")
arm=bpy.data.objects["HERO_01_Armature"]; body=bpy.data.objects["HERO_01_BODY"]
sc=bpy.context.scene; sc.frame_set(0); bpy.context.view_layer.update()
bpy.ops.object.select_all(action='DESELECT')
for o in (arm, body): o.select_set(True)
bpy.context.view_layer.objects.active=arm
path=f"{PROJ}/assets/characters/HERO_01_RIGGED.glb"
bpy.ops.export_scene.gltf(filepath=path, export_format='GLB', use_selection=True, export_yup=True,
    export_apply=False, export_skins=True, export_def_bones=False,
    export_animations=True, export_animation_mode='ACTIONS',
    export_force_sampling=True, export_optimize_animation_size=False, export_materials='EXPORT')
print("EXPORTED", path, os.path.getsize(path))
print("DONE")
