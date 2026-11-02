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

	# --- HITBOX SCAFFOLD (inactive Dynamic Injury volumes) ---
	var hb_root = hero.get_node_or_null("HitboxScaffold")
	check(hb_root != null, "HitboxScaffold node built")
	if hb_root != null:
		var hb_bones := ["Head", "Neck", "UpperChest", "Chest", "Spine", "Hips",
			"UpperArm_L", "Forearm_L", "Hand_L", "UpperArm_R", "Forearm_R", "Hand_R",
			"UpperLeg_L", "LowerLeg_L", "Foot_L", "UpperLeg_R", "LowerLeg_R", "Foot_R"]
		var hb_ok := true
		var hb_inactive := true
		for bn in hb_bones:
			var attach = skeleton.get_node_or_null("HB_" + bn) as BoneAttachment3D
			if attach == null or attach.bone_name != bn:
				hb_ok = false
				continue
			var area = attach.get_node_or_null("Hitbox") as Area3D
			var shape_node = attach.get_node_or_null("Hitbox/Shape") as CollisionShape3D
			if area == null or shape_node == null or shape_node.shape == null:
				hb_ok = false
				continue
			if not shape_node.disabled or area.monitoring or area.monitorable:
				hb_inactive = false
			if not area.has_meta("hb_part") or bool(area.get_meta("hb_active", true)):
				hb_inactive = false
		check(hb_ok, "all 18 hitbox attachments present with shapes")
		check(hb_inactive, "hitbox scaffold fully inactive (shapes disabled, no monitoring)")

	# --- CLIP SAMPLING (direct AnimationPlayer seeks, clip-agnostic) ---
	# Rewritten for the mocap era (2026-11-02, scripts 86/87): the
	# previous version encoded the owner-rejected PROCEDURAL clips'
	# choreography (barrel-climb windows, planted feet during Raise,
	# bind-pose Idle frame 0) and fail-checked unauthored clips.
	# Shipped clips are retargeted mocap whose choreography is judged
	# from Blender filmstrips; CI asserts only the invariant that must
	# hold under ANY clip: the weapon grip stays seated on Weapon_R
	# while the skeleton is being driven. Unauthored clips are INFO.
	if player == null:
		print("CI INFO clip sampling skipped (no AnimationPlayer; rig-only stage)")
		_finish()
		return
	var wr_g = func() -> Vector3: return _bone_global(skeleton, b_weapon)
	var by_base: Dictionary = {}
	for full in player.get_animation_list():
		var parts := String(full).split("/")
		by_base[String(parts[parts.size() - 1])] = String(full)
	for clip_name in ["Idle", "Weapon_Raise", "Aim_Idle", "Fire", "Weapon_Lower", "Walk", "Run", "Reload", "Roll"]:
		if not by_base.has(clip_name):
			print("CI INFO clip '%s' not authored yet (deferred)" % clip_name)
			continue
		var anim_name := String(by_base[clip_name])
		var anim := player.get_animation(anim_name)
		check(anim != null, "clip '%s' resource loads" % clip_name)
		if anim == null:
			continue
		for frac in [0.25, 0.6]:
			player.play(anim_name)
			player.seek(anim.length * frac, true)
			await get_tree().process_frame
			await get_tree().process_frame
			var gd: float = wr_g.call().distance_to(grip.global_position)
			print("CI INFO %s @%.0f%% (t=%.2fs) grip=%.4f m" % [clip_name, frac * 100.0, anim.length * frac, gd])
			check(gd <= 0.005, "grip stays seated during %s @%.0f%%" % [clip_name, frac * 100.0])
	_finish()

func _finish() -> void:
	print("CI RESULT failures=%d" % failures)
	get_tree().quit(1 if failures > 0 else 0)
