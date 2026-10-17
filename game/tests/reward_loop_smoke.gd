extends SceneTree

const MainScene = preload("res://scenes/main.tscn")


func _initialize() -> void:
	call_deferred("_run_smoke_test")


func _run_smoke_test() -> void:
	var main_scene := MainScene.instantiate()
	main_scene.set("start_wave_session_on_ready", false)
	var wave_director: Node = main_scene.get_node("WaveDirector")
	wave_director.set("base_enemies_per_wave", 1)
	wave_director.set("enemies_added_per_wave", 0)
	wave_director.set("max_enemies_per_wave", 1)
	wave_director.set("max_active_enemies", 1)
	wave_director.set("initial_spawn_delay", 0.0)
	wave_director.set("spawn_interval", 0.0)
	wave_director.set("intermission_duration", 2.0)
	root.add_child(main_scene)
	await process_frame
	wave_director.call("start_session")

	var run_stats: Node = main_scene.get_node("RunStats")
	var reward_service: Node = main_scene.get_node("RewardService")
	var test_passed := true
	test_passed = (
		_expect(bool(run_stats.get("is_run_active")), "wave start activates the run clock")
		and test_passed
	)

	for _frame in 120:
		if int(wave_director.get("active_enemy_count")) == 1:
			break
		await physics_frame
	test_passed = (
		_expect(int(wave_director.get("active_enemy_count")) == 1, "one Runner spawns")
		and test_passed
	)
	for _frame in 24:
		await physics_frame
	test_passed = (
		_expect(float(run_stats.get("survival_seconds")) > 0.1, "run time accumulates while active")
		and test_passed
	)

	var active_enemies: Array = wave_director.call("get_active_enemies")
	if not active_enemies.is_empty():
		var enemy := active_enemies[0] as Node3D
		reward_service.call("award_enemy_defeat", enemy)
		test_passed = (
			_expect(
				int(run_stats.get("run_score")) == 0 and int(run_stats.get("bp_earned")) == 0,
				"active enemies do not award rewards before defeat",
			)
			and test_passed
		)
		enemy.call("apply_damage", 1000.0)
		reward_service.call("award_enemy_defeat", enemy)
		reward_service.call("award_wave_completion", 1)
	else:
		test_passed = (
			_expect(false, "a spawned Runner is available for the elimination test") and test_passed
		)

	test_passed = (
		_expect(
			(
				int(run_stats.get("eliminations")) == 1
				and int(run_stats.get("run_score")) == 100
				and int(run_stats.get("bp_earned")) == 110
			),
			"Runner and wave rewards update run stats exactly once",
		)
		and test_passed
	)
	var status_label := main_scene.get_node("HUD/TouchControls").get("_status_label") as Label
	test_passed = (
		_expect(
			(
				status_label.text.contains("Score: 100")
				and status_label.text.contains("BP earned: 110")
			),
			"HUD displays actual run score and BP earned",
		)
		and test_passed
	)
	test_passed = (
		_expect(
			status_label.autowrap_mode != TextServer.AUTOWRAP_OFF,
			"HUD wraps the extended reward status text",
		)
		and test_passed
	)
	test_passed = (
		_expect(
			wave_director.call("get_state_label").begins_with("WAVE 1 CLEAR"),
			"rewarded elimination completes the one-enemy wave",
		)
		and test_passed
	)

	wave_director.call("end_session")
	var results_panel := (
		main_scene.get_node("HUD/TouchControls").get("_results_panel") as PanelContainer
	)
	var results_summary := main_scene.get_node("HUD/TouchControls").get("_results_summary") as Label
	var results_retry_button := (
		main_scene.get_node("HUD/TouchControls").get("_results_retry_button") as Button
	)
	test_passed = (
		_expect(results_panel.visible, "session end opens the results panel") and test_passed
	)
	test_passed = (
		_expect(
			(
				results_summary.text.contains("WAVE REACHED")
				and results_summary.text.contains("1")
				and results_summary.text.contains("ELIMINATIONS")
				and results_summary.text.contains("RUN SCORE")
				and results_summary.text.contains("100")
				and results_summary.text.contains("BATTLE POINTS")
				and results_summary.text.contains("+110")
			),
			"results show actual wave, elimination, score, and BP values",
		)
		and test_passed
	)
	test_passed = (
		_expect(not bool(run_stats.get("is_run_active")), "session end stops the run clock")
		and test_passed
	)
	var final_survival_time := float(run_stats.get("survival_seconds"))
	for _frame in 12:
		await physics_frame
	test_passed = (
		_expect(
			is_equal_approx(float(run_stats.get("survival_seconds")), final_survival_time),
			"run time stays frozen after game over",
		)
		and test_passed
	)

	results_retry_button.emit_signal("pressed")
	test_passed = (
		_expect(not results_panel.visible, "retry hides the results panel") and test_passed
	)
	test_passed = (
		_expect(
			(
				int(run_stats.get("eliminations")) == 0
				and int(run_stats.get("run_score")) == 0
				and int(run_stats.get("bp_earned")) == 0
				and is_equal_approx(float(run_stats.get("survival_seconds")), 0.0)
			),
			"retry resets run-only stats and rewards",
		)
		and test_passed
	)

	main_scene.queue_free()
	await process_frame
	if test_passed:
		print("Reward loop smoke test passed.")
		quit()
	else:
		quit(1)


func _expect(condition: bool, message: String) -> bool:
	if not condition:
		push_error("Reward loop smoke test failed: " + message)
	return condition
