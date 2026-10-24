extends SceneTree

const PlayerScene = preload("res://scenes/player/player.tscn")
const ShooterScene = preload("res://scenes/enemies/shooter.tscn")

var _attack_results: Array[bool] = []
var _player_damage: Array[float] = []
var _eliminated_count: int = 0


func _initialize() -> void:
	call_deferred("_run_smoke_test")


func _run_smoke_test() -> void:
	var test_root := Node3D.new()
	root.add_child(test_root)
	_add_box_body(test_root, Vector3(0.0, -0.1, 0.0), Vector3(40.0, 0.2, 40.0))

	var player := PlayerScene.instantiate() as Node3D
	player.position = Vector3(0.0, 0.0, 8.0)
	test_root.add_child(player)

	var shooter := ShooterScene.instantiate() as Node3D
	shooter.set("target_path", NodePath("../Player"))
	shooter.set("attack_windup", 0.25)
	shooter.set("attack_interval", 0.5)
	shooter.set("preferred_range", 12.0)
	shooter.set("minimum_standoff", 6.0)
	shooter.set("max_attack_range", 20.0)
	shooter.set("detection_range", 28.0)
	shooter.position = Vector3(0.0, 0.0, -4.0)
	var aim_marker := shooter.get_node("AimMarker") as MeshInstance3D
	shooter.connect("attack_resolved", _on_attack_resolved)
	shooter.connect("eliminated", _on_shooter_eliminated)
	player.connect("damage_received", _on_player_damage_received)
	test_root.add_child(shooter)
	await process_frame

	var test_passed := true
	var wall := _add_box_body(test_root, Vector3(0.0, 1.5, 2.0), Vector3(2.0, 3.0, 0.5))
	for _frame in 36:
		await physics_frame
	test_passed = (
		_expect(
			(
				_attack_results.is_empty()
				and is_equal_approx(float(player.get("current_health")), 100.0)
			),
			"world cover blocks the Shooter's ranged attack",
		)
		and test_passed
	)
	wall.queue_free()
	await physics_frame

	for _frame in 90:
		if bool(shooter.call("is_winding_up")):
			break
		await physics_frame
	test_passed = (
		_expect(
			bool(shooter.call("is_winding_up")) and aim_marker.visible,
			"an exposed target receives a visible attack telegraph",
		)
		and test_passed
	)
	var original_player_position := player.global_position
	player.global_position += Vector3(4.0, 0.0, 0.0)
	for _frame in 30:
		if not _attack_results.is_empty():
			break
		await physics_frame
	test_passed = (
		_expect(
			(
				_attack_results.size() == 1
				and not _attack_results[0]
				and is_equal_approx(float(player.get("current_health")), 100.0)
			),
			"moving during the windup dodges the locked shot",
		)
		and test_passed
	)

	player.global_position = original_player_position
	for _frame in 90:
		if bool(shooter.call("is_winding_up")):
			break
		await physics_frame
	for _frame in 45:
		if _attack_results.size() >= 2:
			break
		await physics_frame
	test_passed = (
		_expect(
			(
				_attack_results.size() >= 2
				and _attack_results[1]
				and is_equal_approx(float(player.get("current_health")), 92.0)
				and _player_damage.size() == 1
				and is_equal_approx(_player_damage[0], 8.0)
			),
			"a successful ranged attack routes configured damage through PlayerController",
		)
		and test_passed
	)

	# An occluded shooter must eventually find an angle instead of remaining a
	# stationary turret behind the same cover for the entire wave.
	var second_wall := _add_box_body(test_root, Vector3(0.0, 1.5, 2.0), Vector3(2.0, 3.0, 0.5))
	shooter.global_position = Vector3(0.0, 0.0, -4.0)
	shooter.set("_attack_cooldown", 0.0)
	var farthest_lateral := 0.0
	for _frame in 170:
		await physics_frame
		farthest_lateral = maxf(farthest_lateral, absf(shooter.global_position.x))
	test_passed = (
		_expect(
			farthest_lateral > 1.2,
			"a Shooter blocked by cover repositions laterally instead of freezing",
		)
		and test_passed
	)
	second_wall.queue_free()

	shooter.call("apply_damage", 1000.0)
	shooter.call("apply_damage", 1000.0)
	test_passed = (
		_expect(
			bool(shooter.call("is_defeated")) and _eliminated_count == 1,
			"Shooter death emits elimination exactly once",
		)
		and test_passed
	)
	test_passed = (
		_expect(
			shooter.is_in_group("enemies") and shooter.is_in_group("shooter_enemies"),
			"Shooter is identified as an enemy archetype for waves and rewards",
		)
		and test_passed
	)

	test_root.queue_free()
	await process_frame
	if test_passed:
		print("Shooter enemy smoke test passed.")
		quit()
	else:
		quit(1)


func _add_box_body(parent: Node3D, position: Vector3, size: Vector3) -> StaticBody3D:
	var body := StaticBody3D.new()
	body.collision_layer = 1
	body.position = position
	var collision_shape := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = size
	collision_shape.shape = shape
	body.add_child(collision_shape)
	parent.add_child(body)
	return body


func _on_attack_resolved(hit_target: bool) -> void:
	_attack_results.append(hit_target)


func _on_player_damage_received(amount: float, _current: float, _maximum: float) -> void:
	_player_damage.append(amount)


func _on_shooter_eliminated() -> void:
	_eliminated_count += 1


func _expect(condition: bool, message: String) -> bool:
	if not condition:
		push_error("Shooter enemy smoke test failed: " + message)
	return condition
