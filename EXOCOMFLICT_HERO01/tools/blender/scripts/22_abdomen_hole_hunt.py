"""Diagnostic: hunt reported hole at left abdomen. Magenta background = see-through gaps pop.
Part A: shipped patched GLBs (neutral/mid/aim/hold, front/3-4/Profile, some w/o weapon).
Part B: original source GLB at rest (is the gap source-inherent?)."""
import bpy, math, os
from mathutils import Matrix, Vector
PROJ="/home/user/Cyber-Strike/EXOCOMFLICT_HERO01"; SHOT=f"{PROJ}/screenshots/diag"; os.makedirs(SHOT, exist_ok=True)
AB=(0,-0.02,0.56)
CAMS={"front":(0,-1.15,0.58), "camFL":(-0.75,-0.85,0.58), "camFR":(0.75,-0.85,0.58),
      "profL":(1.15,-0.05,0.58), "profR":(-1.15,-0.05,0.58)}

def scene_setup():
    sc=bpy.context.scene
    sc.render.engine="CYCLES"; sc.cycles.samples=16; sc.cycles.use_denoising=True; sc.cycles.device="CPU"
    w=bpy.data.worlds.new("W"); sc.world=w; w.use_nodes=True
    w.node_tree.nodes["Background"].inputs[0].default_value=(1.0,0.1,0.75,1)
    w.node_tree.nodes["Background"].inputs[1].default_value=0.85
    sd=bpy.data.lights.new("Sun","SUN"); sd.energy=3; so=bpy.data.objects.new("Sun",sd); sc.collection.objects.link(so)
    so.rotation_euler=(math.radians(52),math.radians(8),math.radians(-38))
    cam=bpy.data.objects.new("Cam",bpy.data.cameras.new("Cam")); cam.data.lens=52; sc.collection.objects.link(cam); sc.camera=cam
    sc.render.resolution_x=850; sc.render.resolution_y=850
    return sc,cam

def shoot(sc,cam,name,frame,loc,target=AB):
    sc.frame_set(frame); cam.location=loc
    cam.rotation_euler=(Vector(target)-Vector(loc)).to_track_quat('-Z','Y').to_euler()
    sc.render.filepath=f"{SHOT}/{name}.png"
    bpy.ops.render.render(write_still=True); print("RENDERED",name)

def report(tag):
    for m in [o for o in bpy.data.objects if o.type=='MESH']:
        print(tag, m.name, len(m.data.vertices), "dim", [round(float(v),3) for v in m.dimensions], "loc", [round(float(v),3) for v in m.location])

# ---------- Part A: shipped GLBs ----------
bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.ops.import_scene.gltf(filepath=f"{PROJ}/assets/characters/HERO_01_RIGGED.glb")
bpy.ops.import_scene.gltf(filepath=f"{PROJ}/assets/weapons/HERO_01_WEAPON.glb")
sc=bpy.context.scene; sc.render.fps=30; sc.frame_start=0; sc.frame_end=45
arm=[o for o in bpy.data.objects if o.type=='ARMATURE'][0]
for m in [o for o in bpy.data.objects if o.type=='MESH']:
    if len(m.data.vertices)<1000: bpy.data.objects.remove(m, do_unlink=True)
report("SHIPPED")
weapon=[o for o in bpy.data.objects if o.type=='MESH' and "WEAPON" in o.name][0]
sc.frame_set(0); bpy.context.view_layer.update()
weapon.parent=arm; weapon.parent_type='BONE'; weapon.parent_bone="Weapon_R"
bpy.context.view_layer.update(); weapon.matrix_world=Matrix.Identity(4); bpy.context.view_layer.update()
sc,cam=scene_setup(); arm.hide_render=True
for f in (0,18,36,45): shoot(sc,cam,f"ab_F{f:02d}_front",f,CAMS["front"])
for f in (0,36,45):
    shoot(sc,cam,f"ab_F{f:02d}_camFL",f,CAMS["camFL"]); shoot(sc,cam,f"ab_F{f:02d}_camFR",f,CAMS["camFR"])
shoot(sc,cam,"ab_F36_profL",36,CAMS["profL"]); shoot(sc,cam,"ab_F36_profR",36,CAMS["profR"])
weapon.hide_render=True
for k in ("front","camFL","camFR"): shoot(sc,cam,f"abnw_F36_{k}",36,CAMS[k])
weapon.hide_render=False

# ---------- Part B: source GLB at rest ----------
bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.ops.import_scene.gltf(filepath=f"{PROJ}/assets/source/HERO_01.glb")
report("SOURCE")
sc,cam=scene_setup()
for k in ("front","camFL","camFR"): shoot(sc,cam,f"ab_SRC_{k}",0,CAMS[k])
print("DONE")
