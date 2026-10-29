"""Final proof from EXPORTED files only: import RIGGED+WEAPON GLBs, attach, render key frames."""
import bpy, math
from mathutils import Matrix, Vector
PROJ="/home/user/Cyber-Strike/EXOCOMFLICT_HERO01"; SHOT=f"{PROJ}/screenshots"
bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.ops.import_scene.gltf(filepath=f"{PROJ}/assets/characters/HERO_01_RIGGED.glb")
bpy.ops.import_scene.gltf(filepath=f"{PROJ}/assets/weapons/HERO_01_WEAPON.glb")
sc=bpy.context.scene; sc.render.fps=30; sc.frame_start=0; sc.frame_end=45
arm=[o for o in bpy.data.objects if o.type=='ARMATURE'][0]
meshes=[o for o in bpy.data.objects if o.type=='MESH']
print("meshes:", [(m.name, len(m.data.vertices)) for m in meshes])
for m in meshes:
    if len(m.data.vertices)<1000: bpy.data.objects.remove(m, do_unlink=True)
meshes=[o for o in bpy.data.objects if o.type=='MESH']
weapon=[m for m in meshes if "WEAPON" in m.name][0]
print("weapon obj:", weapon.name)
sc.frame_set(0); bpy.context.view_layer.update()
weapon.parent=arm; weapon.parent_type='BONE'; weapon.parent_bone="Weapon_R"
bpy.context.view_layer.update()
weapon.matrix_world=Matrix.Identity(4); bpy.context.view_layer.update()
err=max(abs(float(weapon.matrix_world[i][j])-(1.0 if i==j else 0.0)) for i in range(4) for j in range(4))
print(f"weapon world identity err @F0: {err:.2e}")
GRIP0=Vector((-0.192,-0.033,0.452))
for F in [0,36]:
    sc.frame_set(F); bpy.context.view_layer.update()
    d=float((weapon.matrix_world@GRIP0-arm.pose.bones["Hand_R"].head).length)
    print(f"F{F}: grip->Hand_R dist {d:.3f}")
sc.render.engine="CYCLES"; sc.cycles.samples=24; sc.cycles.use_denoising=True; sc.cycles.device="CPU"
w=bpy.data.worlds.new("W"); sc.world=w; w.use_nodes=True
w.node_tree.nodes["Background"].inputs[0].default_value=(0.16,0.17,0.19,1); w.node_tree.nodes["Background"].inputs[1].default_value=0.9
sd=bpy.data.lights.new("Sun","SUN"); sd.energy=3; so=bpy.data.objects.new("Sun",sd); sc.collection.objects.link(so)
so.rotation_euler=(math.radians(52),math.radians(8),math.radians(-38))
bpy.ops.mesh.primitive_plane_add(size=8, location=(0,0,0)); gnd=bpy.context.active_object
gm=bpy.data.materials.new("Ground"); gm.use_nodes=True; gm.node_tree.nodes["Principled BSDF"].inputs["Base Color"].default_value=(0.23,0.24,0.27,1)
gnd.data.materials.append(gm)
cam=bpy.data.objects.new("Cam",bpy.data.cameras.new("Cam")); cam.data.lens=52; sc.collection.objects.link(cam); sc.camera=cam
arm.hide_render=True
def shoot(name,frame,loc,target=(0,0,0.5),rx=800,ry=1000):
    sc.frame_set(frame); cam.location=loc
    cam.rotation_euler=(Vector(target)-Vector(loc)).to_track_quat('-Z','Y').to_euler()
    sc.render.resolution_x=rx; sc.render.resolution_y=ry; sc.render.filepath=f"{SHOT}/{name}.png"
    bpy.ops.render.render(write_still=True); print("RENDERED",name)
shoot("01_neutral_pose",0,(0,-2.15,0.55))
shoot("02_weapon_raised",24,(-1.4,-1.4,0.68),(0,0,0.48))
shoot("03_final_aim_front",36,(0,-2.15,0.55))
shoot("03b_final_aim_3q",36,(-1.4,-1.4,0.68),(0,0,0.48))
shoot("04_final_aim_sideR",36,(-2.15,0,0.55))
print("DONE")
