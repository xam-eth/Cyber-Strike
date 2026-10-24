extends SceneTree

const MainScene = preload("res://scenes/main.tscn")

var _spawned_enemies: Array[Node3D] = []
var _spawned_archetypes: Array[String] = []
var _defeated_enemies: Array[Node3D] = []
var _completed_waves: Array[int] = []
var _spawn_blocked_count: int = 0


func _initialize() -> void:
	call_deferred("_run_smoke_test")


func _run_smoke_test() -> void:
	var main_scene := MainScene.instantiate()
	main_scene.set("start_wave_session_on_ready", false)
	var wave_director: Node = main_scene.get_node("WaveDirector")
	wave_director.set("base_enemies_per_wave", 3)
	# This fixture exercises varied flanking spawns. The shipped two-Runner
	# introductory wave uses a separate front-facing, clear-lane preference.
	wave_director.set("intro_front_spawn", false)
	wave_director.set("enemies_added_per_wave", 1)
	wave_director.set("max_enemies_per_wave", 5)
	wave_director.set("max_active_enemies", 2)
	wave_director.set("initial_spawn_delay", 0.0)
	wave_director.set("spawn_interval", 0.01)
	wave_director.set("spawn_retry_delay", 0.01)
	wave_director.set("max_spawn_retries", 3)
	wave_director.set("intermission_duration", 0.05)
	root.add_child(main_scene)
	await process_frame

	var player: Node3D = main_scene.get_node("Player")
	var spawn_points: Node3D = main_scene.get_node("SpawnPoints")
	var player_camera: Camera3D = player.get_node(
		"CameraRig/YawPivot/PitchPivot/SpringArm3D/Camera3D"
	)
	var camera_forward := -player_camera.global_basis.z
	camera_forward.y = 0.0
	camera_forward = camera_forward.normalized()
	var cover_position := Vector3(4.0, 0.0, -3.0)
	var target_position := Vector3(0.0, 0.0, -8.0)
	var test_passed := true
	test_passed = (
		_expect(
			(
				int(wave_director.call("get_shooter_count_for_wave", 1, 3)) == 0
				and int(wave_director.call("get_shooter_count_for_wave", 2, 4)) == 1
				and int(wave_director.call("get_shooter_count_for_wave", 4, 6)) == 2
			),
			"shooter composition follows a predictable wave schedule",
		)
		and test_passed
	)
	test_passed = (
		_expect(
			not wave_director.call("is_spawn_position_valid", cover_position),
			"spawn validation rejects a point inside cover",
		)
		and test_passed
	)
	test_passed = (
		_expect(
			not wave_director.call("is_spawn_position_valid", target_position),
			"spawn validation rejects overlap with the training target",
		)
		and test_passed
	)
	wave_director.connect("enemy_spawned", _on_enemy_spawned)
	wave_director.connect("enemy_defeated", _on_enemy_defeated)
	wave_director.connect("wave_completed", _on_wave_completed)
	wave_director.connect("spawn_blocked", _on_spawn_blocked)
	wave_director.call("start_session")

	test_passed = (
		_expect(
			int(wave_director.get("current_wave")) == 1,
			"session starts at wave one",
		)
		and test_passed
	)
	test_passed = (
		_expect(
			int(wave_director.get("current_wave_enemy_count")) == 3,
			"first wave has the configured bounded size",
		)
		and test_passed
	)

	for _frame in 90:
		if int(wave_director.get("active_enemy_count")) >= 2:
			break
		await physics_frame
	test_passed = (
		_expect(
			int(wave_director.get("active_enemy_count")) == 2,
			"active enemy cap is enforced while spawning",
		)
		and test_passed
	)
	var active_enemies: Array = wave_director.call("get_active_enemies")
	for enemy in active_enemies:
		var enemy_node := enemy as Node3D
		var distance := enemy_node.global_position.distance_to(player.global_position)
		test_passed = (
			_expect(
				distance >= float(wave_director.get("minimum_spawn_distance")),
				"spawn does not appear too close to the player",
			)
			and test_passed
		)
		test_passed = (
			_expect(enemy_node.get("_target") == player, "spawned Runner targets the player")
			and test_passed
		)
		var bounds: Vector2 = wave_director.get("arena_half_extents")
		test_passed = (
			_expect(
				(
					absf(enemy_node.global_position.x) < bounds.x
					and absf(enemy_node.global_position.z) < bounds.y
				),
				"spawn remains within arena bounds",
			)
			and test_passed
		)
		var direction_to_spawn := enemy_node.global_position - player.global_position
		direction_to_spawn.y = 0.0
		test_passed = (
			_expect(
				(
					camera_forward.dot(direction_to_spawn.normalized())
					<= float(wave_director.get("camera_front_dot_threshold"))
				),
				"spawn prefers positions outside the direct camera-front cone",
			)
			and test_passed
		)

	for _frame in 180:
		if wave_director.call("get_state_label").begins_with("WAVE 1 CLEAR"):
			break
		var enemies_to_defeat: Array = wave_director.call("get_active_enemies")
		for enemy in enemies_to_defeat:
			(enemy as Node3D).call("apply_damage", 1000.0)
		await physics_frame
	test_passed = (
		_expect(
			wave_director.call("get_state_label").begins_with("WAVE 1 CLEAR"),
			"all wave enemies can be defeated and the wave completes",
		)
		and test_passed
	)
	test_passed = (
		_expect(_spawned_enemies.size() == 3, "all wave enemies spawn exactly once") and test_passed
	)
	test_passed = (
		_expect(
			_spawned_archetypes == ["RUNNER", "RUNNER", "RUNNER"],
			"introductory wave contains only Runners",
		)
		and test_passed
	)
	test_passed = (
		_expect(_defeated_enemies.size() == 3, "each enemy defeat is counted once") and test_passed
	)
	test_passed = (
		_expect(_completed_waves == [1], "wave completion event reports the correct index")
		and test_passed
	)

	for _frame in 90:
		if int(wave_director.get("current_wave")) == 2:
			break
		await physics_frame
	test_passed = (
		_expect(
			(
				int(wave_director.get("current_wave")) == 2
				and int(wave_director.get("current_wave_enemy_count")) == 4
			),
			"intermission advances to the next wave and scales count only",
		)
		and test_passed
	)

	test_passed = (
		_expect(
			int(wave_director.get("current_wave_shooter_count")) == 1,
			"wave two schedules one Shooter after the Runner intro",
		)
		and test_passed
	)
	for _frame in 180:
		if int(wave_director.get("enemies_spawned_this_wave")) >= 4:
			break
		for enemy in wave_director.call("get_active_enemies"):
			(enemy as Node3D).call("apply_damage", 1000.0)
		await physics_frame
	test_passed = (
		_expect(
			(
				_spawned_archetypes.size() == 7
				and _spawned_archetypes[3] == "RUNNER"
				and _spawned_archetypes[4] == "RUNNER"
				and _spawned_archetypes[5] == "RUNNER"
				and _spawned_archetypes[6] == "SHOOTER"
			),
			"wave two spawns its deterministic three-Runner, one-Shooter mix",
		)
		and test_passed
	)
	var shooter_enemy: Node3D
	for enemy in wave_director.call("get_active_enemies"):
		if enemy.is_in_group("shooter_enemies"):
			shooter_enemy = enemy
	test_passed = (
		_expect(is_instance_valid(shooter_enemy), "the scheduled Shooter is alive in wave two")
		and test_passed
	)
	if is_instance_valid(shooter_enemy):
		shooter_enemy.call("apply_damage", 1000.0)
		main_scene.get_node("RewardService").call("award_enemy_defeat", shooter_enemy)
	var run_stats: Node = main_scene.get_node("RunStats")
	test_passed = (
		_expect(
			(
				int(run_stats.get("eliminations")) == 7
				and int(run_stats.get("run_score")) == 700
				and int(run_stats.get("bp_earned")) == 270
			),
			"Runner, Shooter, and wave rewards are each recorded exactly once",
		)
		and test_passed
	)

	var spawned_before_defeat := _spawned_enemies.size()
	player.call("apply_damage", 1000.0)
	test_passed = (
		_expect(
			wave_director.call("get_state_label").begins_with("SESSION OVER"),
			"player defeat ends the wave session",
		)
		and test_passed
	)
	for _frame in 12:
		await physics_frame
	test_passed = (
		_expect(
			_spawned_enemies.size() == spawned_before_defeat,
			"game over stops further spawns",
		)
		and test_passed
	)
	var results := main_scene.get_node("HUD/TouchControls").get("_results_panel") as Control
	test_passed = (
		_expect(
			(
				not results.visible
				and int(main_scene.get("_pending_defeat_wave")) >= 1
				and int(main_scene.get_node("ProgressionService").get("balance")) >= 270
			),
			"earned BP banks while the in-world death motion remains uncovered",
		)
		and test_passed
	)
	main_scene.call("_process", 1.6)
	test_passed = (
		_expect(not results.visible, "the fallen pose is not covered on its first render frame")
		and test_passed
	)
	for _frame in 10:
		await process_frame
	test_passed = (
		_expect(results.visible, "Results follows the full death reveal and rendered pose")
		and test_passed
	)

	main_scene.call("_reset_session")
	for marker in spawn_points.get_children():
		(marker as Marker3D).global_position = player.global_position
	wave_director.call("start_session")
	for _frame in 45:
		if _spawn_blocked_count > 0:
			break
		await physics_frame
	test_passed = (
		_expect(_spawn_blocked_count == 1, "blocked spawn emits one failure event") and test_passed
	)
	# The main scene owns recovery: do not leave the player trapped in a blocked
	# encounter or silently restart while there are no valid spawn markers.
	test_passed = (
		_expect(
			(
				int(main_scene.get("session_mode")) == 0
				and wave_director.call("get_state_label") == "READY"
				and int(wave_director.get("active_enemy_count")) == 0
			),
			"unspawnable defense returns safely to Explore without an automatic retry",
		)
		and test_passed
	)

	main_scene.queue_free()
	await process_frame
	if test_passed:
		print("Wave Director smoke test passed.")
		quit()
	else:
		quit(1)


func _on_enemy_spawned(enemy: Node3D) -> void:
	_spawned_enemies.append(enemy)
	_spawned_archetypes.append("SHOOTER" if enemy.is_in_group("shooter_enemies") else "RUNNER")


func _on_enemy_defeated(enemy: Node3D) -> void:
	_defeated_enemies.append(enemy)


func _on_wave_completed(wave_index: int) -> void:
	_completed_waves.append(wave_index)


func _on_spawn_blocked(_reason: String) -> void:
	_spawn_blocked_count += 1


func _expect(condition: bool, message: String) -> bool:
	if not condition:
		push_error("Wave Director smoke test failed: " + message)
	return condition
