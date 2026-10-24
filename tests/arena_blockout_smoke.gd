extends SceneTree

const MainScene = preload("res://scenes/main.tscn")
const RunnerScene = preload("res://scenes/enemies/runner.tscn")


func _initialize() -> void:
	call_deferred("_run_smoke_test")


func _run_smoke_test() -> void:
	var main_scene := MainScene.instantiate()
	main_scene.set("start_wave_session_on_ready", false)
	root.add_child(main_scene)
	await process_frame
	await physics_frame

	var arena: Node3D = main_scene.get_node("NeonFrontier")
	var player: Node3D = main_scene.get_node("Player")
	var test_passed := true
	for required_node in ["CentralReactor", "ServiceDeck", "ServiceRamp", "ArenaEnvironment"]:
		test_passed = (
			_expect(
				arena.get_node_or_null(required_node) != null,
				"blockout includes " + required_node,
			)
			and test_passed
		)
	var beacon_count := 0
	for child in arena.get_children():
		if str(child.name).ends_with("_Beacon"):
			beacon_count += 1
	test_passed = (
		_expect(
			(
				beacon_count == main_scene.get_node("SpawnPoints").get_child_count() - 1
				and main_scene.get_node_or_null("SpawnPoints/SpawnSouth") != null
				and arena.get_node_or_null("SpawnSouth_Beacon") == null
				and arena.get_node_or_null("SpawnSouth_Core") == null
			),
			"combat south spawn remains, but its near-camera decorative beacon is hidden",
		)
		and test_passed
	)

	player.global_position = Vector3(5.5, 0.0, 5.5)
	player.set("velocity", Vector3.ZERO)
	player.call("set_touch_movement", Vector2.RIGHT)
	for _frame in 120:
		await physics_frame
		if player.global_position.x >= 10.2 and player.global_position.y >= 0.4:
			break
	player.call("set_touch_movement", Vector2.ZERO)
	print("Service ramp test ended at player position %s." % player.global_position)
	test_passed = (
		_expect(
			player.global_position.x >= 10.2 and player.global_position.y >= 0.4,
			"player can walk up the low service ramp onto the deck",
		)
		and test_passed
	)

	player.global_position = Vector3(0.0, 0.0, 8.0)
	player.set("velocity", Vector3.ZERO)
	var runner := RunnerScene.instantiate() as Node3D
	runner.position = Vector3(12.0, 0.0, 0.0)
	main_scene.add_child(runner)
	await process_frame
	var starting_distance := runner.global_position.distance_to(player.global_position)
	for _frame in 360:
		await physics_frame
	var ending_distance := runner.global_position.distance_to(player.global_position)
	print(
		(
			"Runner route test distance: %.2f -> %.2f (Runner %s, player %s)."
			% [starting_distance, ending_distance, runner.global_position, player.global_position]
		)
	)
	test_passed = (
		_expect(
			ending_distance < starting_distance - 8.0,
			"Runner closes distance through the updated cover/ramp layout",
		)
		and test_passed
	)

	main_scene.queue_free()
	await process_frame
	if test_passed:
		print("Arena blockout smoke test passed.")
		quit()
	else:
		quit(1)


func _expect(condition: bool, message: String) -> bool:
	if not condition:
		push_error("Arena blockout smoke test failed: " + message)
	return condition
