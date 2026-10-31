extends Node
## Headless CI validation for NEW_HERO_01 (run with the CICheck scene):
##   godot --headless --path . res://tools/godot/CICheck.tscn
## Prints CI PASS / CI FAIL lines and exits 0 (all pass) or 1 (any fail).
##
## Stage: rig/skinning was proven at vertex level in Blender (scripts
## 64-68); Phase-1 clips were deformation-inspected in Blender renders
## (scripts 69-71, screenshots/rig/audit71_*). This CI proves the ENGINE
## side: GLB import, skeleton rests, weapon seated on Weapon_R, an
## in-engine pose probe, and direct seeks through the Phase-1 chain
## (aim grips/barrel/feet, Fire recoil climb, exact carry returns). It
## does NOT re-prove vertex deformation (that needs rendered pixels).

const AutoRigCheck = preload("res://scripts/validation/auto_rig_check.gd")

var failures := 0

func check(ok: bool, label: String) -> void:
	print(("CI PASS  " if ok else "CI FAIL  ") + label)
	if not ok:
		failures += 1

func _ready() -> void:
	_run()

func _bone_global(skeleton: Skeleton3D, bone: int) -> Vector3:
	return (skeleton.global_transform * skeleton.get_bone_global_pose(bone)).origin

func _run() -> void:
	print("CI INFO Godot version: ", Engine.get_version_info())
	var ps: PackedScene = load("res://scenes/characters/HERO_01.tscn") as PackedScene
	check(ps != null, "HERO_01.tscn loads")
	if ps == null:
		_finish()
		return
	var hero = ps.instantiate()
	add_child(hero)
	await get_tree().process_frame
	await get_tree().process_frame

	var lines: Array = AutoRigCheck.run_checks(hero)
	var auto_fail := 0
	for l in lines:
		print("CI AUTO  ", String(l))
		if String(l).begins_with("FAIL"):
			auto_fail += 1
	check(auto_fail == 0, "auto_rig_check all PASS (%d fail)" % auto_fail)

	var skeleton: Skeleton3D = hero.get("skeleton") as Skeleton3D
	var player: AnimationPlayer = hero.get("animation_player") as AnimationPlayer
	var weapon: Node3D = hero.get("weapon_instance") as Node3D
	var attachment: BoneAttachment3D = hero.get("weapon_attachment") as BoneAttachment3D
	check(skeleton != null and weapon != null, "hero skeleton/weapon resolved")
	print("CI INFO AnimationPlayer: ", "present" if player != null else "absent (no clips authored yet)")
	if attachment != null:
		check(attachment.bone_name == "Weapon_R", "attachment bound to Weapon_R (got '%s')" % attachment.bone_name)
	if skeleton == null or weapon == null:
		_finish()
		return

	var grip: Node3D = weapon.find_child("GripPoint", true, false) as Node3D
	var fore: Node3D = weapon.find_child("ForegripPoint", true, false) as Node3D
	var muzzle: Node3D = weapon.find_child("MuzzlePoint", true, false) as Node3D
	var receiver: Node3D = weapon.find_child("ReceiverPoint", true, false) as Node3D
	check(grip != null and fore != null and muzzle != null and receiver != null, "weapon markers found")
	if grip == null or muzzle == null or receiver == null:
		_finish()
		return

	var b_weapon := skeleton.find_bone("Weapon_R")
	var b_hand_r := skeleton.find_bone("Hand_R")
	var b_ua_r := skeleton.find_bone("UpperArm_R")
	var b_hips := skeleton.find_bone("Hips")
	var b_foot_r := skeleton.find_bone("Foot_R")
	var b_foot_l := skeleton.find_bone("Foot_L")
	check(b_weapon >= 0 and b_hand_r >= 0 and b_ua_r >= 0, "probe bones resolved")

	# The wrapper now auto-starts its AnimationTree (Phase-1 clips exist);
	# disable it and reset to the true bind pose so the rest measurements
	# and the manual pose probe below are not overwritten by Idle.
	if hero.has_method("set_animation_tree_enabled"):
		hero.call("set_animation_tree_enabled", false)
	if player != null:
		player.stop()
	skeleton.reset_bone_poses()
	await get_tree().process_frame
	await get_tree().process_frame

	# --- REST measurements ---
	await get_tree().process_frame
	var grip_rest_d: float = _bone_global(skeleton, b_weapon).distance_to(grip.global_position)
	var bdir: Vector3 = (muzzle.global_position - receiver.global_position).normalized()
	print("CI INFO rest grip<->Weapon_R distance: %.4f m; barrel dir=%s" % [grip_rest_d, str(bdir)])
	check(grip_rest_d <= 0.020, "grip seated on Weapon_R at rest (%.4f m)" % grip_rest_d)
	var hand0 := _bone_global(skeleton, b_hand_r)
	var hips0 := _bone_global(skeleton, b_hips)
	var foot_r0 := _bone_global(skeleton, b_foot_r)
	var foot_l0 := _bone_global(skeleton, b_foot_l)

	# --- POSE PROBE: rotate the right upper arm in-engine ---
	var q0: Quaternion = skeleton.get_bone_pose_rotation(b_ua_r)
	skeleton.set_bone_pose_rotation(b_ua_r, q0 * Quaternion(Vector3.RIGHT, deg_to_rad(-95.0)))
	await get_tree().process_frame
	await get_tree().process_frame
	var hand1 := _bone_global(skeleton, b_hand_r)
	var hips1 := _bone_global(skeleton, b_hips)
	var foot_r1 := _bone_global(skeleton, b_foot_r)
	var foot_l1 := _bone_global(skeleton, b_foot_l)
	var grip_pose_d: float = _bone_global(skeleton, b_weapon).distance_to(grip.global_position)
	var hand_moved: float = hand1.distance_to(hand0)
	print("CI INFO pose probe: Hand_R moved %.4f m; grip<->Weapon_R now %.4f m" % [hand_moved, grip_pose_d])
	check(hand_moved >= 0.15, "arm chain drives Hand_R in-engine (moved %.4f m)" % hand_moved)
	check(grip_pose_d <= 0.020, "weapon follows Weapon_R rigidly under pose (%.4f m)" % grip_pose_d)
	check(hips1.distance_to(hips0) <= 0.001, "hips static during arm probe (moved %.4f m)" % hips1.distance_to(hips0))
	check(foot_r1.distance_to(foot_r0) <= 0.001 and foot_l1.distance_to(foot_l0) <= 0.001, "feet static during arm probe")

	# --- restore rest pose exactly ---
	skeleton.set_bone_pose_rotation(b_ua_r, q0)
	await get_tree().process_frame
	await get_tree().process_frame
	var hand2 := _bone_global(skeleton, b_hand_r)
	check(hand2.distance_to(hand0) <= 0.001, "rest pose restored after probe (drift %.4f m)" % hand2.distance_to(hand0))

	# --- PHASE-1 CLIP SAMPLING (direct AnimationPlayer seeks) ---
	# (the AnimationTree was already disabled above). Skipped with INFO in
	# the rig-only stage (procedural clips owner-rejected 2026-10-31,
	# mocap-retargeted replacements pending; VALIDATION_REPORT 5.17).
	if player == null:
		print("CI INFO clip sampling skipped (no AnimationPlayer; rig-only stage)")
		_finish()
		return
	var b_hand_l := skeleton.find_bone("Hand_L")
	var wr_g = func() -> Vector3: return _bone_global(skeleton, b_weapon)
	# Raise end == aim: barrel forward, grips seated, feet planted.
	var raise_anim := String(hero.call("get_resolved_animation", "Weapon_Raise"))
	check(raise_anim != "", "Weapon_Raise resolved")
	if raise_anim != "":
		player.play(raise_anim)
		player.seek(1.2, true)
		await get_tree().process_frame
		await get_tree().process_frame
		var bd: Vector3 = (muzzle.global_position - receiver.global_position).normalized()
		var ang: float = rad_to_deg(bd.angle_to(Vector3(0, 0, 1)))
		var lw: float = _bone_global(skeleton, b_hand_l).distance_to(fore.global_position)
		print("CI INFO Raise@1.2s barrel=%.2f deg off +Z; L wrist->foregrip=%.4f m; grip=%.4f m" % [ang, lw, wr_g.call().distance_to(grip.global_position)])
		check(ang <= 4.0, "barrel on character forward at aim (%.2f deg)" % ang)
		check(wr_g.call().distance_to(grip.global_position) <= 0.005, "grip stays seated at aim")
		check(absf(lw - 0.119) <= 0.025, "left wrist at foregrip hold (%.4f m, ~0.119 = 66mm x1.8)" % lw)
		check(_bone_global(skeleton, b_foot_r).distance_to(foot_r0) <= 0.002 and _bone_global(skeleton, b_foot_l).distance_to(foot_l0) <= 0.002, "feet planted during Raise")
		check(_bone_global(skeleton, b_hips).distance_to(hips0) <= 0.002, "hips static during Raise")
	# Fire recoil: muzzle climbs then the clip recovers (sampled at peak).
	var fire_anim := String(hero.call("get_resolved_animation", "Fire"))
	check(fire_anim != "", "Fire resolved")
	if fire_anim != "":
		player.play(fire_anim)
		player.seek(0.07, true)
		await get_tree().process_frame
		await get_tree().process_frame
		var bd2: Vector3 = (muzzle.global_position - receiver.global_position).normalized()
		var ang2: float = rad_to_deg(bd2.angle_to(Vector3(0, 0, 1)))
		print("CI INFO Fire@0.07s barrel climb=%.2f deg; grip=%.4f m" % [ang2, wr_g.call().distance_to(grip.global_position)])
		check(ang2 >= 0.7 and ang2 <= 4.0, "Fire recoil climb present and bounded (%.2f deg)" % ang2)
		check(wr_g.call().distance_to(grip.global_position) <= 0.005, "grip stays seated during Fire")
	# Lower ends exactly at rest; Idle frame 0 is the bind pose.
	var lower_anim := String(hero.call("get_resolved_animation", "Weapon_Lower"))
	if lower_anim != "":
		player.play(lower_anim)
		player.seek(0.8, true)
		await get_tree().process_frame
		await get_tree().process_frame
		check(_bone_global(skeleton, b_hand_r).distance_to(hand0) <= 0.005, "Weapon_Lower ends at carry/rest hand")
	var idle_anim := String(hero.call("get_resolved_animation", "Idle"))
	if idle_anim != "":
		player.play(idle_anim)
		player.seek(0.0, true)
		await get_tree().process_frame
		await get_tree().process_frame
		check(_bone_global(skeleton, b_hand_r).distance_to(hand0) <= 0.002, "Idle frame 0 == bind pose hand")
	_finish()

func _finish() -> void:
	print("CI RESULT failures=%d" % failures)
	get_tree().quit(1 if failures > 0 else 0)
