extends SceneTree

const MainScene = preload("res://scenes/main.tscn")
const ImpactBurstScript = preload("res://scripts/weapons/impact_burst.gd")


class DamageReceiver:
	extends StaticBody3D
	var damage_calls: Array[float] = []

	func apply_damage(amount: float, _source: Node = null) -> void:
		damage_calls.append(amount)


func _initialize() -> void:
	call_deferred("_run_smoke_test")


func _run_smoke_test() -> void:
	var main_scene := MainScene.instantiate()
	main_scene.set("start_wave_session_on_ready", false)
	main_scene.get_node("ProgressionService").set("profile_path", "")
	root.add_child(main_scene)
	await process_frame
	var progression := main_scene.get_node("ProgressionService") as ProgressionService
	progression.balance = 250
	var arc_unlocked := progression.unlock_weapon(&"arc_shooter")

	var player: Node3D = main_scene.get_node("Player")
	var weapon_controller: Node = player.get_node("WeaponController")
	var muzzle: Marker3D = player.get_node("VisualRoot/WeaponSocket/Muzzle")
	var weapon_button := main_scene.get_node("HUD/TouchControls").get("_weapon_button") as Button
	var touch_weapon_name := (
		main_scene.get_node("HUD/TouchControls").get("_touch_ammo_chip").get("weapon_label")
		as Label
	)
	var test_passed := true

	test_passed = (
		_expect(arc_unlocked, "the fixture purchases Arc before slot selection") and test_passed
	)
	test_passed = (
		_expect(bool(player.call("select_weapon", 2)), "Arc Shooter can be selected by slot")
		and test_passed
	)
	test_passed = (
		_expect(
			(
				weapon_controller.call("get_current_weapon_name") == "Arc Shooter"
				and weapon_button.text.is_empty()
				and String(weapon_button.get_meta("aegis_state", "")) == "swap"
				and touch_weapon_name.text == "ARC"
			),
			"Arc selection updates the mobile weapon label",
		)
		and test_passed
	)
	var arc_definition: Resource = weapon_controller.call("get_current_definition")
	test_passed = (
		_expect(
			(
				arc_definition.get("weapon_id") == &"arc_shooter"
				and int(arc_definition.get("chain_count")) == 2
				and is_equal_approx(float(arc_definition.get("chain_radius")), 5.0)
				and is_equal_approx(float(arc_definition.get("chain_damage_multiplier")), 0.7)
			),
			"Arc resource configures two chained targets and damage falloff",
		)
		and test_passed
	)

	var blocked_direct := _create_receiver(main_scene, Vector3(0.34, 1.18, 3.8))
	var blocked_chain := _create_receiver(main_scene, Vector3(2.0, 1.18, 3.8))
	var front_blocker := _create_blocker(
		main_scene, Vector3(0.34, 1.18, 6.0), Vector3(3.0, 3.0, 0.3)
	)
	await physics_frame
	var blocked_fire: bool = weapon_controller.call(
		"try_fire", player, muzzle, blocked_direct.global_position
	)
	var immediate_repeat: bool = weapon_controller.call(
		"try_fire", player, muzzle, blocked_direct.global_position
	)
	test_passed = (
		_expect(
			blocked_fire and not immediate_repeat,
			"Arc shot fires once and respects its cooldown",
		)
		and test_passed
	)
	for _frame in 4:
		await physics_frame
	test_passed = (
		_expect(
			blocked_direct.damage_calls.is_empty() and blocked_chain.damage_calls.is_empty(),
			"Arc beam blocked by cover cannot hit or chain through it",
		)
		and test_passed
	)
	for _frame in 35:
		await physics_frame
	front_blocker.queue_free()
	blocked_direct.queue_free()
	blocked_chain.queue_free()
	await process_frame
	await physics_frame

	var direct_target := _create_receiver(main_scene, Vector3(0.34, 1.18, 3.8))
	var closer_occluded_target := _create_receiver(main_scene, Vector3(1.5, 1.18, 3.8))
	var visible_target := _create_receiver(main_scene, Vector3(-1.0, 1.18, 0.8))
	var third_chain_target := _create_receiver(main_scene, Vector3(5.8, 1.18, 3.8))
	var chain_blocker := _create_blocker(
		main_scene, Vector3(0.9, 1.18, 3.8), Vector3(0.3, 2.0, 0.6)
	)
	await physics_frame
	var chain_fire: bool = weapon_controller.call(
		"try_fire", player, muzzle, direct_target.global_position
	)
	var chain_repeat: bool = weapon_controller.call(
		"try_fire", player, muzzle, direct_target.global_position
	)
	test_passed = (
		_expect(chain_fire and not chain_repeat, "Arc cooldown throttles repeated chain shots")
		and test_passed
	)
	for _frame in 45:
		await physics_frame
		if (
			not direct_target.damage_calls.is_empty()
			and not closer_occluded_target.damage_calls.is_empty()
		):
			break
	test_passed = (
		_expect(
			(
				direct_target.damage_calls.size() == 1
				and is_equal_approx(direct_target.damage_calls[0], 20.0)
			),
			"Arc beam damages its primary target exactly once",
		)
		and test_passed
	)
	var arc_spark := false
	for candidate in get_nodes_in_group(ImpactBurstScript.BURST_GROUP):
		if (candidate as Node3D).global_position.distance_to(direct_target.global_position) < 0.55:
			arc_spark = true
	test_passed = (
		_expect(arc_spark, "Arc creates a real impact spark at the beam hit") and test_passed
	)
	test_passed = (
		_expect(
			(
				visible_target.damage_calls.size() == 1
				and is_equal_approx(visible_target.damage_calls[0], 14.0)
			),
			"Arc skips a closer target behind cover and chains to a farther visible target",
		)
		and test_passed
	)
	test_passed = (
		_expect(
			(
				closer_occluded_target.damage_calls.size() == 1
				and is_equal_approx(closer_occluded_target.damage_calls[0], 9.8)
			),
			"Arc can chain onward from its first jump without duplicate damage",
		)
		and test_passed
	)
	test_passed = (
		_expect(
			third_chain_target.damage_calls.is_empty(),
			"Arc stops after two hops even when a third in-range target is available",
		)
		and test_passed
	)

	for target in [
		direct_target, closer_occluded_target, visible_target, third_chain_target, chain_blocker
	]:
		target.queue_free()
	await process_frame
	for _frame in 35:
		await physics_frame

	var radius_primary := _create_receiver(main_scene, Vector3(0.34, 1.18, 3.8))
	var radius_first_target := _create_receiver(main_scene, Vector3(-1.66, 1.18, 3.8))
	var radius_limited_target := _create_receiver(main_scene, Vector3(0.34, 1.18, -1.1))
	await physics_frame
	var radius_fire: bool = weapon_controller.call(
		"try_fire", player, muzzle, radius_primary.global_position
	)
	for _frame in 15:
		await physics_frame
		if not radius_first_target.damage_calls.is_empty():
			break
	test_passed = (
		_expect(radius_fire, "Arc can fire a fresh shot after its cooldown") and test_passed
	)
	test_passed = (
		_expect(
			(
				radius_primary.damage_calls.size() == 1
				and is_equal_approx(radius_primary.damage_calls[0], 20.0)
				and radius_first_target.damage_calls.size() == 1
				and is_equal_approx(radius_first_target.damage_calls[0], 14.0)
			),
			"Arc applies configured damage to the primary and first chain target",
		)
		and test_passed
	)
	test_passed = (
		_expect(
			radius_limited_target.damage_calls.is_empty(),
			"Arc measures chain radius from the previous hop, not the primary hit",
		)
		and test_passed
	)

	main_scene.queue_free()
	await process_frame
	if test_passed:
		print("Arc weapon smoke test passed.")
		quit()
	else:
		quit(1)


func _create_receiver(parent: Node, at_position: Vector3) -> DamageReceiver:
	var receiver := DamageReceiver.new()
	receiver.name = "ArcDamageReceiver"
	receiver.position = at_position
	receiver.collision_layer = 2
	receiver.collision_mask = 0
	var shape := SphereShape3D.new()
	shape.radius = 0.42
	var collision_shape := CollisionShape3D.new()
	collision_shape.shape = shape
	receiver.add_child(collision_shape)
	parent.add_child(receiver)
	return receiver


func _create_blocker(parent: Node, at_position: Vector3, size: Vector3) -> StaticBody3D:
	var blocker := StaticBody3D.new()
	blocker.name = "ArcBlocker"
	blocker.position = at_position
	blocker.collision_layer = 1
	blocker.collision_mask = 0
	var shape := BoxShape3D.new()
	shape.size = size
	var collision_shape := CollisionShape3D.new()
	collision_shape.shape = shape
	blocker.add_child(collision_shape)
	parent.add_child(blocker)
	return blocker


func _expect(condition: bool, message: String) -> bool:
	if not condition:
		push_error("Arc weapon smoke test failed: " + message)
	return condition
