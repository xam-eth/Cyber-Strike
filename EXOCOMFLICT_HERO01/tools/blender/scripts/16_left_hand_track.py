"""Re-key support (left) hand densely against final interpolated weapon motion."""
import bpy, math
from mathutils import Matrix, Vector
PROJ="/home/user/Cyber-Strike/EXOCOMFLICT_HERO01"; REND=f"{PROJ}/screenshots/animation"
bpy.ops.wm.open_mainfile(filepath=f"{PROJ}/blender/HERO_01_working.blend")
arm=bpy.data.objects["HERO_01_Armature"]; weapon=bpy.data.objects["HERO_01_WEAPON"]; sc=bpy.context.scene
def aim_bone(name,target):
    pb=arm.pose.bones[name]; head=pb.head.copy()
    cur=(pb.tail-head).normalized(); des=(Vector(target)-head).normalized()
    q=cur.rotation_difference(des)
    M=Matrix.Translation(head)@q.to_matrix().to_4x4()@Matrix.Translation(-head)
    pb.matrix=M@pb.matrix; bpy.context.view_layer.update()
def solve_elbow(S,W,L1,L2,pole):
    S,W,pole=Vector(S),Vector(W),Vector(pole)
    d=max(min((W-S).length,(L1+L2)*0.999),abs(L1-L2)*1.001)
    axis=(W-S).normalized(); a=(L1*L1-L2*L2+d*d)/(2*d); h=math.sqrt(max(L1*L1-a*a,0.0))
    mid=S+axis*a; perp=pole-mid; perp-=axis*perp.dot(axis)
    if perp.length<1e-6: perp=Vector((0,0,-1))
    return mid+perp.normalized()*h
L1=arm.pose.bones["UpperArm_L"].bone.length; L2=arm.pose.bones["Forearm_L"].bone.length
FG0=Vector((-0.215,-0.062,0.315)); LW0=Vector(arm.pose.bones["Hand_L"].bone.head_local)
def fg_at(F):
    sc.frame_set(F); bpy.context.view_layer.update(); return weapon.matrix_world@FG0
def key_left(F):
    for n in ["Clavicle_L","UpperArm_L","Forearm_L","Hand_L"]:
        pb=arm.pose.bones[n]; pb.keyframe_insert("location",frame=F); pb.keyframe_insert("rotation_quaternion",frame=F)
CONTACT=[21,24,27,30,33,36,40,45]
for F in CONTACT:
    tgt=fg_at(F)
    S=arm.pose.bones["UpperArm_L"].head.copy()
    E=solve_elbow(S,tgt,L1,L2,S+Vector((0.20,0.10,-0.30)))
    aim_bone("UpperArm_L",E); aim_bone("Forearm_L",tgt); key_left(F)
# re-clamp all handles
act=arm.animation_data.action; fc=[]
try:
    for layer in act.layers:
        for strip in layer.strips: fc+=list(strip.channelbag.fcurves)
except Exception: pass
if not fc: fc=list(act.fcurves)
for c in fc:
    for kp in c.keyframe_points:
        kp.interpolation='BEZIER'; kp.handle_left_type='AUTO_CLAMPED'; kp.handle_right_type='AUTO_CLAMPED'
    c.update()
print("grip validation (Lhand->foregrip, metres):")
worst=0
for F in range(0,46,2):
    sc.frame_set(F); bpy.context.view_layer.update()
    d=float((arm.pose.bones["Hand_L"].head-(weapon.matrix_world@FG0)).length)
    if F>=21: worst=max(worst,d)
    print(f" F{F}: {d:.3f}")
print(f"WORST contact-phase (F>=21): {worst:.3f}")
sc.frame_set(0); bpy.ops.wm.save_mainfile(); print("SAVED v2 animation")
# renders (subset)
sc.render.engine="CYCLES"; sc.cycles.samples=16; sc.cycles.use_denoising=True; sc.cycles.device="CPU"
w=bpy.data.worlds.new("W"); sc.world=w; w.use_nodes=True
w.node_tree.nodes["Background"].inputs[0].default_value=(0.16,0.17,0.19,1); w.node_tree.nodes["Background"].inputs[1].default_value=0.9
sd=bpy.data.lights.new("Sun","SUN"); sd.energy=3; so=bpy.data.objects.new("Sun",sd); sc.collection.objects.link(so)
so.rotation_euler=(math.radians(52),math.radians(8),math.radians(-38))
bpy.ops.mesh.primitive_plane_add(size=8, location=(0,0,0)); gnd=bpy.context.active_object
gm=bpy.data.materials.new("Ground"); gm.use_nodes=True; gm.node_tree.nodes["Principled BSDF"].inputs["Base Color"].default_value=(0.23,0.24,0.27,1)
gnd.data.materials.append(gm)
cam=bpy.data.objects.new("Cam",bpy.data.cameras.new("Cam")); cam.data.lens=52; sc.collection.objects.link(cam); sc.camera=cam
arm.hide_render=True
def shoot(name,frame,loc,target=(0,0,0.5),rx=700,ry=875,lens=52):
    sc.frame_set(frame); cam.data.lens=lens; cam.location=loc
    cam.rotation_euler=(Vector(target)-Vector(loc)).to_track_quat('-Z','Y').to_euler()
    sc.render.resolution_x=rx; sc.render.resolution_y=ry; sc.render.filepath=f"{REND}/{name}.png"
    bpy.ops.render.render(write_still=True); print("RENDERED",name)
shoot("aim_F24_3q",24,(-1.4,-1.4,0.68),(0,0,0.48))
shoot("aim_F36_front",36,(0,-2.15,0.55))
shoot("aim_F36_3q",36,(-1.4,-1.4,0.68),(0,0,0.48))
shoot("aim_F36_sideR",36,(-2.15,0,0.55))
shoot("aim_F36_closeup",36,(-0.55,-0.75,0.85),(-0.05,-0.18,0.71),800,800,55)
sc.frame_set(0); print("DONE")
