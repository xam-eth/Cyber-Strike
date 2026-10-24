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
	# The blockout used to be procedural geometry. It is now the staged real world,
	# so what this test guards is that the arena still exists as a place to fight
	# in: a real reactor, a lit environment and a walkable floor.
	var real_world := arena.get_node_or_null("RealFrontierWorld") as Node3D
	test_passed = (
		_expect(real_world != null, "the arena is the staged real GLB world") and test_passed
	)
	var arena_meshes: Array[Node] = (
		real_world.find_children("*", "MeshInstance3D", true, false) if real_world != null else []
	)
	test_passed = (
		_expect(
			arena_meshes.size() >= 400,
			"the arena's geometry comes from the real asset file (%d meshes)" % arena_meshes.size(),
		)
		and test_passed
	)
	for required_node in ["ArenaFloor", "ArenaEnvironment", "FrontierDaylightSun"]:
		test_passed = (
			_expect(
				arena.get_node_or_null(required_node) != null,
				"blockout includes " + required_node,
			)
			and test_passed
		)

	player.global_position = Vector3(5.5, 0.0, 5.5)
	player.set("velocity", Vector3.ZERO)
	player.call("set_touch_movement", Vector2.RIGHT)
	for _frame in 120:
		await physics_frame
		if player.global_position.x >= 10.2:
			break
	player.call("set_touch_movement", Vector2.ZERO)
	print("Arena traversal ended at player position %s." % player.global_position)
	test_passed = (
		_expect(
			player.global_position.x >= 10.2,
			"player can cross the arena floor on the real world's collision layer",
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
