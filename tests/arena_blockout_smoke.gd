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
	await physics_frame

	var arena: Node3D = main_scene.get_node("MissionWorld")
	var player: Node3D = main_scene.get_node("Player")
	var test_passed := true

	var real_world := arena.get_node_or_null("RealFrontierWorld") as Node3D
	test_passed = (
		_expect(real_world != null, "the arena mounts SH-01 Aetherfall under RealFrontierWorld")
		and test_passed
	)
	var arena_meshes: Array[Node] = []
	if real_world != null:
		arena_meshes = real_world.find_children("*", "MeshInstance3D", true, false)
	test_passed = (
		_expect(
			arena_meshes.size() >= 250,
			"Aetherfall carries full modular GLB geometry (%d meshes)" % arena_meshes.size(),
		)
		and test_passed
	)
	test_passed = (
		_expect(arena.get_node_or_null("ArenaFloor") != null, "MissionWorld includes ArenaFloor")
		and test_passed
	)
	test_passed = (
		_expect(
			(
				real_world != null
				and real_world.get_node_or_null("WorldEnvironment") != null
				and real_world.get_node_or_null("Sun") != null
			),
			"Aetherfall includes authored WorldEnvironment and Sun DirectionalLight3D",
		)
		and test_passed
	)

	# Walk east from the Arrival Outpost deck (-30, 1.2, 14) toward the central spine.
	player.global_position = Vector3(-30.0, 1.2, 14.0)
	player.set("velocity", Vector3.ZERO)
	player.call("set_touch_movement", Vector2.RIGHT)
	for _frame in 180:
		await physics_frame
		if player.global_position.x >= -20.0:
			break
	player.call("set_touch_movement", Vector2.ZERO)
	print("Arena traversal ended at player position %s." % player.global_position)
	test_passed = (
		_expect(
			player.global_position.x >= -20.0,
			"player traverses the Arrival Outpost deck on Aetherfall's walkable collision layer",
		)
		and test_passed
	)

	player.global_position = Vector3(-30.0, 1.2, 14.0)
	player.set("velocity", Vector3.ZERO)
	var runner := RunnerScene.instantiate() as Node3D
	runner.position = Vector3(-18.0, 1.2, 14.0)
	main_scene.add_child(runner)
	await process_frame
	var starting_distance := runner.global_position.distance_to(player.global_position)
	for _frame in 300:
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
			ending_distance < starting_distance - 5.0,
			"Runner robot closes distance across the Aetherfall deck",
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
