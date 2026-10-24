extends SceneTree

const MainScene = preload("res://scenes/main.tscn")
const ImpactBurstScript = preload("res://scripts/weapons/impact_burst.gd")
const NovaShockwaveScript = preload("res://scripts/weapons/nova_shockwave.gd")


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
	progression.balance = 500
	var nova_unlocked := progression.unlock_weapon(&"nova_launcher")
	var arc_unlocked := progression.unlock_weapon(&"arc_shooter")

	var player: Node3D = main_scene.get_node("Player")
	var weapon_controller: Node = player.get_node("WeaponController")
	var muzzle: Marker3D = player.get_node("VisualRoot/WeaponSocket/Muzzle")
	var controls: Node = main_scene.get_node("HUD/TouchControls")
	var weapon_button := controls.get("_weapon_button") as Button
	var weapon_meta := controls.get("_desktop_weapon_meta") as Label
	var ammo_chip := controls.get("_touch_ammo_chip") as Control
	var weapon_name := ammo_chip.get("weapon_label") as Label
	var touch_ammo := ammo_chip.get("value_label") as Label
	var test_passed := true
	test_passed = (
		_expect(
			nova_unlocked and arc_unlocked, "fixture spends earned BP to unlock its test weapons"
		)
		and test_passed
	)
	test_passed = (
		_expect(
			weapon_meta.text.contains("24/24") and touch_ammo.text == "24/24",
			"desktop and touch HUD start with a full Pulse magazine",
		)
		and test_passed
	)

	test_passed = (
		_expect(
			weapon_controller.get("weapon_definitions").size() == 3,
			"Pulse Rifle, Nova Launcher, and Arc Shooter are loaded as data definitions",
		)
		and test_passed
	)
	var pulse_definition: Resource = weapon_controller.call("get_current_definition")
	test_passed = (
		_expect(
			(
				pulse_definition.get("weapon_id") == &"pulse_rifle"
				and is_equal_approx(float(pulse_definition.get("damage")), 18.0)
				and is_equal_approx(float(pulse_definition.get("fire_rate")), 5.0)
			),
			"Pulse Rifle keeps its original damage and fire rate",
		)
		and test_passed
	)
	test_passed = (
		_expect(
			bool(weapon_controller.call("select_weapon", -1)) == false,
			"invalid weapon indexes are rejected",
		)
		and test_passed
	)
	test_passed = (
		_expect(
			(
				weapon_button.text.is_empty()
				and weapon_button.icon != null
				and String(weapon_button.get_meta("aegis_state", "")) == "swap"
				and weapon_name.text == "PULSE"
			),
			"icon-only SWAP keeps weapon identity in the adjacent ammo readout",
		)
		and test_passed
	)

	weapon_button.emit_signal("pressed")
	test_passed = (
		_expect(
			(
				weapon_controller.call("get_current_weapon_name") == "Nova Launcher"
				and weapon_name.text == "NOVA"
				and touch_ammo.text == "6/6"
			),
			"mobile weapon button selects Nova and updates its label",
		)
		and test_passed
	)
	weapon_button.emit_signal("pressed")
	test_passed = (
		_expect(
			(
				weapon_controller.call("get_current_weapon_name") == "Arc Shooter"
				and weapon_name.text == "ARC"
				and touch_ammo.text == "12/12"
			),
			"mobile weapon button reaches Arc Shooter and updates its label",
		)
		and test_passed
	)
	weapon_button.emit_signal("pressed")
	test_passed = (
		_expect(
			weapon_controller.call("get_current_weapon_name") == "Pulse Rifle",
			"mobile weapon button cycles back to Pulse Rifle",
		)
		and test_passed
	)

	var key_down := InputEventKey.new()
	key_down.physical_keycode = KEY_E
	key_down.pressed = true
	Input.parse_input_event(key_down)
	await physics_frame
	await physics_frame
	var key_up := InputEventKey.new()
	key_up.physical_keycode = KEY_E
	key_up.pressed = false
	Input.parse_input_event(key_up)
	test_passed = (
		_expect(
			weapon_controller.call("get_current_weapon_name") == "Nova Launcher",
			"desktop E input cycles to Nova Launcher",
		)
		and test_passed
	)

	weapon_button.emit_signal("pressed")
	weapon_button.emit_signal("pressed")
	var pulse_target := _create_receiver(main_scene, Vector3(0.34, 1.18, 3.8))
	var blocker := _create_blocker(main_scene, Vector3(0.34, 1.18, 6.0))
	await physics_frame
	test_passed = (
		_expect(
			weapon_controller.call("get_current_weapon_name") == "Pulse Rifle",
			"touch switching can restore Pulse before firing",
		)
		and test_passed
	)

	# Over-the-shoulder targeting must not shoot a projectile through cover when
	# the barrel itself clips a wall. Place a small solid box at the real GLB
	# muzzle, rather than guessing a weapon position from the player origin.
	var near_wall := StaticBody3D.new()
	near_wall.name = "WallAtMuzzle"
	near_wall.position = muzzle.global_position
	near_wall.collision_layer = 1
	near_wall.collision_mask = 0
	var near_shape := CollisionShape3D.new()
	var near_box := BoxShape3D.new()
	near_box.size = Vector3(0.25, 0.25, 0.25)
	near_shape.shape = near_box
	near_wall.add_child(near_shape)
	main_scene.add_child(near_wall)
	await physics_frame
	var blocked_fire: bool = weapon_controller.call(
		"try_fire", player, muzzle, pulse_target.global_position
	)
	test_passed = (
		_expect(
			not blocked_fire and int(weapon_controller.call("get_current_ammo")) == 24,
			"a muzzle inside world cover cannot spawn a shot or spend ammunition",
		)
		and test_passed
	)
	near_wall.queue_free()
	await physics_frame

	var first_fire: bool = weapon_controller.call(
		"try_fire", player, muzzle, pulse_target.global_position
	)
	var immediate_repeat: bool = weapon_controller.call(
		"try_fire", player, muzzle, pulse_target.global_position
	)
	test_passed = (
		_expect(first_fire and not immediate_repeat, "Pulse cooldown rejects an immediate repeat")
		and test_passed
	)
	for _frame in 10:
		await physics_frame
	test_passed = (
		_expect(pulse_target.damage_calls.is_empty(), "Pulse projectile is blocked by cover")
		and test_passed
	)
	for _frame in 8:
		await physics_frame
	blocker.queue_free()
	await process_frame
	await physics_frame
	var recovered_fire: bool = weapon_controller.call(
		"try_fire", player, muzzle, pulse_target.global_position
	)
	var repeat_during_cooldown: bool = weapon_controller.call(
		"try_fire", player, muzzle, pulse_target.global_position
	)
	test_passed = (
		_expect(
			recovered_fire and not repeat_during_cooldown,
			"Pulse can fire again after cooldown and is throttled again",
		)
		and test_passed
	)
	for _frame in 30:
		await physics_frame
		if not pulse_target.damage_calls.is_empty():
			break
	test_passed = (
		_expect(
			(
				int(weapon_controller.call("get_current_ammo")) == 22
				and touch_ammo.text == "22/24"
				and weapon_meta.text.contains("22/24")
			),
			"each successful Pulse shot spends a round and updates both HUDs",
		)
		and test_passed
	)
	test_passed = (
		_expect(
			(
				pulse_target.damage_calls.size() == 1
				and is_equal_approx(pulse_target.damage_calls[0], 18.0)
			),
			"Pulse projectile hits its target once for the original damage",
		)
		and test_passed
	)
	var pulse_spark := false
	for candidate in get_nodes_in_group(ImpactBurstScript.BURST_GROUP):
		if (candidate as Node3D).global_position.distance_to(pulse_target.global_position) < 0.55:
			pulse_spark = true
	test_passed = (
		_expect(pulse_spark, "a real Pulse impact emits sparks at the collision point")
		and test_passed
	)

	weapon_button.emit_signal("pressed")
	var nova_definition: Resource = weapon_controller.call("get_current_definition")
	test_passed = (
		_expect(
			(
				nova_definition.get("weapon_id") == &"nova_launcher"
				and is_equal_approx(float(nova_definition.get("splash_damage")), 24.0)
				and is_equal_approx(float(nova_definition.get("splash_radius")), 4.0)
			),
			"Nova data definition configures a distinct blast radius and damage",
		)
		and test_passed
	)

	pulse_target.queue_free()
	await process_frame
	var nova_direct := _create_receiver(main_scene, Vector3(0.34, 1.18, 3.8))
	var nova_nearby := _create_receiver(main_scene, Vector3(2.0, 1.18, 3.8))
	var nova_outside := _create_receiver(main_scene, Vector3(6.5, 1.18, 3.8))
	await physics_frame
	var nova_fire: bool = weapon_controller.call(
		"try_fire", player, muzzle, nova_direct.global_position
	)
	var nova_repeat: bool = weapon_controller.call(
		"try_fire", player, muzzle, nova_direct.global_position
	)
	test_passed = (
		_expect(nova_fire and not nova_repeat, "Nova Launcher has an independent cooldown")
		and test_passed
	)
	var nova_round := main_scene.find_child("NovaProjectile", true, false) as Node3D
	if nova_round != null:
		var nova_core := nova_round.get_node("NovaCore") as MeshInstance3D
		var nova_trail := nova_round.get_node("NovaTrail") as MeshInstance3D
		test_passed = (
			_expect(
				(
					not nova_core.visible
					and not nova_trail.visible
					and (nova_core.mesh as SphereMesh).radius <= 0.12
				),
				"Nova fires from muzzle but waits until clear of camera to reveal a small bolt",
			)
			and test_passed
		)
	else:
		test_passed = _expect(false, "Nova round exists after firing") and test_passed
	for _frame in 45:
		await physics_frame
		if not nova_direct.damage_calls.is_empty() and not nova_nearby.damage_calls.is_empty():
			break
	test_passed = (
		_expect(
			(
				nova_direct.damage_calls.size() == 1
				and is_equal_approx(nova_direct.damage_calls[0], 34.0)
			),
			"Nova projectile applies direct impact damage once",
		)
		and test_passed
	)
	test_passed = (
		_expect(
			(
				nova_nearby.damage_calls.size() == 1
				and is_equal_approx(nova_nearby.damage_calls[0], 24.0)
			),
			"Nova explosion damages a nearby target once",
		)
		and test_passed
	)
	test_passed = (
		_expect(
			nova_outside.damage_calls.is_empty(),
			"Nova explosion does not damage targets outside its radius",
		)
		and test_passed
	)
	var nova_spark := false
	for candidate in get_nodes_in_group(ImpactBurstScript.BURST_GROUP):
		var burst := candidate as CPUParticles3D
		if (
			burst != null
			and burst.amount == 28
			and burst.global_position.distance_to(nova_direct.global_position) < 0.55
		):
			nova_spark = true
	test_passed = (
		_expect(nova_spark, "a real Nova detonation emits a distinct spark burst") and test_passed
	)
	var shock_found := false
	for candidate in get_nodes_in_group(NovaShockwaveScript.GROUP):
		var shock := candidate as Node3D
		if shock == null or shock.global_position.distance_to(nova_direct.global_position) > 0.6:
			continue
		var surface := shock.get_node_or_null("ImpactSurface") as Node3D
		var band := shock.get_node_or_null("ImpactSurface/BlastFront") as MeshInstance3D
		shock_found = (
			surface != null
			and band != null
			and band.mesh is ArrayMesh
			and shock.get("blast_radius") == 4.0
			and surface.global_position.y >= 0.12
		)
	test_passed = (
		_expect(
			shock_found,
			"a real Nova direct/splash hit grounds a radius-4 shockfront above the FBX floor",
		)
		and test_passed
	)
	test_passed = (
		_expect(
			int(weapon_controller.call("get_current_ammo")) == 5 and touch_ammo.text == "5/6",
			"Nova has its own live six-round magazine",
		)
		and test_passed
	)
	# Drive the last-round transition without firing five slow explosives just
	# to reach it. All earlier shots used the real projectile/cooldown path.
	var magazines: Array = weapon_controller.get("_magazines")
	var cooldowns: Array = weapon_controller.get("_cooldowns")
	magazines[1] = 1
	cooldowns[1] = 0.0
	var final_round: bool = weapon_controller.call(
		"try_fire", player, muzzle, nova_direct.global_position
	)
	var rejected_during_reload: bool = weapon_controller.call(
		"try_fire", player, muzzle, nova_direct.global_position
	)
	test_passed = (
		_expect(
			(
				final_round
				and not rejected_during_reload
				and weapon_controller.call("is_reloading")
				and touch_ammo.text == "RELOAD"
				and weapon_meta.text.contains("RELOADING")
			),
			"empty magazine auto-reloads and locks fire in both HUDs",
		)
		and test_passed
	)
	for _frame in 145:
		await physics_frame
	test_passed = (
		_expect(
			(
				not weapon_controller.call("is_reloading")
				and int(weapon_controller.call("get_current_ammo")) == 6
				and touch_ammo.text == "6/6"
			),
			"reload restores the magazine and its fixed-width ammo label",
		)
		and test_passed
	)
	var next_round: bool = weapon_controller.call(
		"try_fire", player, muzzle, nova_direct.global_position
	)
	var manual_reload: bool = weapon_controller.call("request_reload")
	test_passed = (
		_expect(
			next_round and manual_reload and not weapon_controller.call("request_reload"),
			"G can reload early, but a duplicate request does not restart its timer",
		)
		and test_passed
	)
	weapon_controller.call("reset_ammo")
	test_passed = (
		_expect(
			(
				not weapon_controller.call("is_reloading")
				and int(weapon_controller.call("get_current_ammo")) == 6
			),
			"a fresh run refills all magazines and cancels reloading",
		)
		and test_passed
	)

	main_scene.queue_free()
	await process_frame
	if test_passed:
		print("Weapon system smoke test passed.")
		quit()
	else:
		quit(1)


func _create_receiver(parent: Node, at_position: Vector3) -> DamageReceiver:
	var receiver := DamageReceiver.new()
	receiver.name = "DamageReceiver"
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


func _create_blocker(parent: Node, at_position: Vector3) -> StaticBody3D:
	var blocker := StaticBody3D.new()
	blocker.name = "WeaponBlocker"
	blocker.position = at_position
	blocker.collision_layer = 1
	blocker.collision_mask = 0
	var shape := BoxShape3D.new()
	shape.size = Vector3(3.0, 3.0, 0.3)
	var collision_shape := CollisionShape3D.new()
	collision_shape.shape = shape
	blocker.add_child(collision_shape)
	parent.add_child(blocker)
	return blocker


func _expect(condition: bool, message: String) -> bool:
	if not condition:
		push_error("Weapon system smoke test failed: " + message)
	return condition
