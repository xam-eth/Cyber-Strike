extends Node
## Headless CI validation for HERO_01 (run with the CICheck scene):
##   godot --headless --path . res://tools/godot/CICheck.tscn
## Prints CI PASS / CI FAIL lines and exits 0 (all pass) or 1 (any fail).
## Measures grips, barrel direction and root/feet stability in-engine.

const AutoRigCheck = preload("res://scripts/validation/auto_rig_check.gd")

var failures := 0

func check(ok: bool, label: String) -> void:
	print(("CI PASS  " if ok else "CI FAIL  ") + label)
	if not ok:
		failures += 1

func _ready() -> void:
	_run()

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
	check(skeleton != null and player != null and weapon != null, "hero skeleton/player/weapon resolved")
	if attachment != null:
		check(attachment.bone_name == "Weapon_R", "attachment bound to Weapon_R (got '%s')" % attachment.bone_name)
	if skeleton == null or player == null or weapon == null:
		_finish()
		return

	var grip: Node3D = weapon.find_child("GripPoint", true, false) as Node3D
	var fore: Node3D = weapon.find_child("ForegripPoint", true, false) as Node3D
	var muzzle: Node3D = weapon.find_child("MuzzlePoint", true, false) as Node3D
	var receiver: Node3D = weapon.find_child("ReceiverPoint", true, false) as Node3D
	check(grip != null and fore != null and muzzle != null and receiver != null, "weapon markers found")

	var anim := ""
	for a in player.get_animation_list():
		if String(a).ends_with("Weapon_Raise_To_Aim"):
			anim = String(a)
	check(anim != "", "Weapon_Raise_To_Aim present in AnimationPlayer")
	if anim == "" or grip == null or fore == null or muzzle == null or receiver == null:
		_finish()
		return

	player.play(anim)
	player.speed_scale = 0.0
	var b_hand_r := skeleton.find_bone("Hand_R")
	var b_hand_l := skeleton.find_bone("Hand_L")
	var b_hips := skeleton.find_bone("Hips")
	var b_foot_r := skeleton.find_bone("Foot_R")
	var b_foot_l := skeleton.find_bone("Foot_L")
	var hips0 := Vector3.INF
	var foot_r0 := Vector3.INF
	var foot_l0 := Vector3.INF
	var dr_values: Array = []
	for t in [0.0, 0.4, 0.8, 1.2, 1.5]:
		player.seek(t, true)
		await get_tree().process_frame
		await get_tree().process_frame
		var hr_g: Vector3 = (skeleton.global_transform * skeleton.get_bone_global_pose(b_hand_r)).origin
		var hl_g: Vector3 = (skeleton.global_transform * skeleton.get_bone_global_pose(b_hand_l)).origin
		var d_r: float = hr_g.distance_to(grip.global_position)
		var d_l: float = hl_g.distance_to(fore.global_position)
		dr_values.append(d_r)
		var bdir: Vector3 = (muzzle.global_position - receiver.global_position).normalized()
		print("CI SAMPLE t=%.2f  dHandR->grip=%.4f m  dHandL->foregrip=%.4f m  barrel=%s" % [t, d_r, d_l, str(bdir)])
		if t == 0.0:
			hips0 = (skeleton.global_transform * skeleton.get_bone_global_pose(b_hips)).origin
			foot_r0 = (skeleton.global_transform * skeleton.get_bone_global_pose(b_foot_r)).origin
			foot_l0 = (skeleton.global_transform * skeleton.get_bone_global_pose(b_foot_l)).origin
		if t >= 1.2:
			check(d_l <= 0.012, "support-hand grip at hold t=%.1f (%.4f m)" % [t, d_l])
			var ang: float = rad_to_deg(bdir.angle_to(Vector3(0, 0, 1)))
			print("CI INFO  barrel angle to +Z at t=%.1f: %.1f deg" % [t, ang])
			check(ang <= 6.0, "barrel aligned to character forward (+Z) at t=%.1f" % t)

	var dr_min: float = dr_values.min()
	var dr_max: float = dr_values.max()
	check(dr_max - dr_min <= 0.004, "right grip constant across clip (spread %.4f m)" % (dr_max - dr_min))
	check(absf(dr_max - 0.0306) <= 0.006, "right grip ~= 0.017 x 1.8 scale (max %.4f m)" % dr_max)

	player.seek(1.2, true)
	await get_tree().process_frame
	await get_tree().process_frame
	var hips1: Vector3 = (skeleton.global_transform * skeleton.get_bone_global_pose(b_hips)).origin
	var foot_r1: Vector3 = (skeleton.global_transform * skeleton.get_bone_global_pose(b_foot_r)).origin
	var foot_l1: Vector3 = (skeleton.global_transform * skeleton.get_bone_global_pose(b_foot_l)).origin
	check(hips1.distance_to(hips0) <= 0.001, "hips static (in-place clip, moved %.4f m)" % hips1.distance_to(hips0))
	check(foot_r1.distance_to(foot_r0) <= 0.001 and foot_l1.distance_to(foot_l0) <= 0.001, "feet planted (no slide)")
	_finish()

func _finish() -> void:
	print("CI RESULT failures=%d" % failures)
	get_tree().quit(1 if failures > 0 else 0)
