"""Skeleton-only ANIMATIONS export + compressed final .blend save."""
import bpy, os
PROJ="/home/user/Cyber-Strike/EXOCOMFLICT_HERO01"
bpy.ops.wm.open_mainfile(filepath=f"{PROJ}/blender/HERO_01_working.blend")
arm=bpy.data.objects["HERO_01_Armature"]
bpy.ops.object.select_all(action='DESELECT'); arm.select_set(True)
bpy.context.view_layer.objects.active=arm
bpy.context.scene.frame_set(0)
path=f"{PROJ}/animations/HERO_01_ANIMATIONS.glb"
try:
    bpy.ops.export_scene.gltf(filepath=path, export_format='GLB', use_selection=True, export_yup=True,
        export_animations=True, export_animation_mode='ACTIONS', export_force_sampling=True,
        export_optimize_animation_size=False)
except TypeError as e:
    print("fallback:", e)
    bpy.ops.export_scene.gltf(filepath=path, export_format='GLB', use_selection=True, export_yup=True, export_animations=True)
print("ANIMATIONS skeleton-only:", os.path.getsize(path))
bpy.ops.outliner.orphans_purge(do_local_ids=True, do_linked_ids=True, do_recursive=True)
bpy.ops.wm.save_mainfile(compress=True)
print("blend size:", os.path.getsize(f"{PROJ}/blender/HERO_01_working.blend"))
print("DONE")
