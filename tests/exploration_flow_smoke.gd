extends SceneTree

## Contract for the user-selected flow: boot into safe Explore, opt in with an
## explicit action, prepare before wave 1, then always allow returning to safety.
const MainScene = preload("res://scenes/main.tscn")

var _failures: int = 0


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var main := MainScene.instantiate()
	main.get_node("ProgressionService").set("profile_path", "")
	root.add_child(main)
	await process_frame
	var wave := main.get_node("WaveDirector")
	var player := main.get_node("Player")
	var drone := main.get_node("TrainingDrone")
	var hud := main.get_node("HUD/TouchControls")
	var start := hud.get("_defense_button") as Button
	var objective := hud.get("_wave_title_label") as Label
	var health_before := float(player.get("current_health"))
	_expect(
		(
			not bool(main.get("start_wave_session_on_ready"))
			and int(main.get("session_mode")) == 0
			and int(wave.get("current_wave")) == 0
			and start.visible
			and objective.text.contains("EXPLORE")
		),
		"boot defaults to safe Explore with a clearly labeled Defense action",
	)
	# Simulate sixty seconds of idle time without a real-time delay. Check the
	# WaveDirector after actual physics frames too: only an explicit action may
	# change its state, not elapsed time or a HUD redraw.
	main.call("_process", 60.0)
	for _frame in 12:
		await physics_frame
	_expect(
		(
			int(wave.get("current_wave")) == 0
			and not bool(wave.get("_session_running"))
			and wave.call("get_active_enemies").is_empty()
			and is_equal_approx(float(player.get("current_health")), health_before)
		),
		"sixty simulated seconds and live physics do not spawn or damage in Explore",
	)
	var binding_found := false
	for binding in InputMap.action_get_events("start_defense"):
		if binding is InputEventKey and binding.physical_keycode == KEY_B:
			binding_found = true
	_expect(binding_found, "B has a discoverable keyboard action for Defense")
	var armory_key := false
	for binding in InputMap.action_get_events("open_armory"):
		if binding is InputEventKey and binding.physical_keycode == KEY_U:
			armory_key = true
	_expect(armory_key, "U opens the wallet and armory on desktop")

	# Exercise the actual mobile touch dispatcher, not just the signal handler.
	hud.call("set_touch_mode", true)
	hud.call("apply_layout_for_size", Vector2(390.0, 844.0), 1.0)
	await process_frame
	_tap(hud, start)
	_expect(
		(
			int(main.get("session_mode")) == 1
			and start.disabled
			and start.text.contains("DEFENSE IN")
			and (hud.get("_wave_enemy_label") as Label).text == "GET READY · SPAWNS MARKED"
			and int(wave.get("current_wave")) == 0
		),
		"touching START DEFENSE enters a visible preparation, not instant combat",
	)
	main.call("_process", 3.9)
	await physics_frame
	_expect(
		int(wave.get("current_wave")) == 0 and wave.call("get_active_enemies").is_empty(),
		"no enemy may spawn before the preparation countdown expires",
	)
	var escape := hud.get("_pause_restart_button") as Button
	main.call("_toggle_pause")
	# Container/overlay rects are settled on the next frame. Tapping the old
	# rect immediately after opening Pause misses the actual button in headless.
	await process_frame
	_expect(paused and escape.text == "CANCEL DEFENSE", "preparation can be cancelled")
	_tap(hud, escape)
	_expect(
		(
			not paused
			and int(main.get("session_mode")) == 0
			and int(wave.get("current_wave")) == 0
			and wave.call("get_active_enemies").is_empty()
		),
		"cancelling preparation returns to safe Explore without a reward",
	)

	_tap(hud, start)
	main.call("_process", 5.1)
	_expect(
		(
			int(main.get("session_mode")) == 2
			and int(wave.get("current_wave")) == 1
			and objective.text == "WAVE 01"
		),
		"the first wave begins only after an explicit start plus countdown",
	)
	_expect(
		(
			not drone.visible
			and not drone.is_in_group("enemies")
			and drone.collision_layer == 0
			and int(wave.get("current_wave_enemy_count")) == 2
		),
		"Defense hides the practice dummy and introduces only two real Runners",
	)
	var camera := player.get_node("CameraRig/YawPivot/PitchPivot/SpringArm3D/Camera3D") as Camera3D
	var threat := Node3D.new()
	main.add_child(threat)
	threat.global_position = player.global_position + Vector3(0.0, 0.0, 8.0)
	var enemies: Array[Node3D] = [threat]
	var portrait_bearings := HudHostileBearings.collect(
		camera, enemies, Vector2(390.0, 844.0), true
	)
	var landscape_bearings := HudHostileBearings.collect(
		camera, enemies, Vector2(844.0, 390.0), false
	)
	var portrait_marker: Vector2 = (
		portrait_bearings[0]["position"] if not portrait_bearings.is_empty() else Vector2.ZERO
	)
	var landscape_marker: Vector2 = (
		landscape_bearings[0]["position"] if not landscape_bearings.is_empty() else Vector2.ZERO
	)
	_expect(
		(
			portrait_bearings.size() == 1
			and landscape_bearings.size() == 1
			and portrait_marker.y > 480.0
			and portrait_marker.y < 540.0
			and landscape_marker.x > 280.0
			and landscape_marker.x < 600.0
			and landscape_marker.y < 285.0
		),
		"offscreen hostiles cue direction above thumb controls in both orientations",
	)
	var lower_threat_direction := HudHostileBearings._projected_direction(
		Vector2(240.0, 770.0), Rect2(Vector2(40.0, 224.0), Vector2(310.0, 299.0)), Vector2.UP, false
	)
	_expect(
		lower_threat_direction.y > 0.9,
		"a nearby Runner hidden below the thumb cluster points DOWN, not up",
	)
	threat.queue_free()
	var valid_spawns: Array[Marker3D] = []
	for child in main.get_node("SpawnPoints").get_children():
		if child is Marker3D and wave.call("is_spawn_position_valid", child.global_position):
			valid_spawns.append(child as Marker3D)
	var intro_marker := wave.call("_choose_intro_marker", valid_spawns) as Marker3D
	if intro_marker != null:
		for _frame in 100:
			if int(wave.get("active_enemy_count")) > 0:
				break
			await physics_frame
		var spawned: Array[Node3D] = wave.call("get_active_enemies")
		_expect(
			(
				not spawned.is_empty()
				and spawned[0].global_position.distance_to(intro_marker.global_position) < 3.0
			),
			"the first Runner uses a visible front lane when a clear one exists",
		)
	var flank_marker := wave.call("_choose_intro_flank_marker", valid_spawns) as Marker3D
	_expect(flank_marker != null, "the second intro Runner has a clear, forward flank")
	if flank_marker != null:
		var from_player: Vector3 = flank_marker.global_position - player.global_position
		from_player.y = 0.0
		var forward := -camera.global_basis.z
		forward.y = 0.0
		var alignment := forward.normalized().dot(from_player.normalized())
		_expect(
			(
				alignment > 0.0
				and alignment < float(wave.get("camera_front_dot_threshold"))
				and bool(wave.call("_has_player_sight_line", flank_marker.global_position))
			),
			"intro flank remains visible without stacking both enemies on the center ray",
		)

	# End a run using the visible pause action, not a test-only director call.
	# Simulated earned BP represents the reward granted by real wave/kill signals.
	main.get_node("RunStats").call("award_battle_points", 25)
	main.call("_toggle_pause")
	await process_frame
	_expect(paused and escape.text == "FINISH RUN · RESULTS", "Defense offers a cash-out")
	_tap(hud, escape)
	var results := hud.get("_results_panel") as Control
	_expect(
		(
			not paused
			and int(main.get("session_mode")) == 3
			and results.visible
			and wave.call("get_active_enemies").is_empty()
			and int(main.get_node("ProgressionService").get("balance")) == 25
			and (hud.get("_results_reward_label") as Label).text == "+25 BP BANKED"
			and (hud.get("_results_goal_progress_label") as Label).text.contains("95 TO GO")
			and is_equal_approx((hud.get("_results_goal_bar") as ProgressBar).value, 25.0)
		),
		"FINISH RUN opens Results, banks earned BP and stops enemies",
	)
	# Retry must prepare again; RETURN TO EXPLORE must not spawn.
	var retry := hud.get("_results_retry_button") as Button
	var explore := hud.get("_results_explore_button") as Button
	_expect(
		results.visible and retry.is_visible_in_tree() and explore.is_visible_in_tree(),
		"results display distinct RETRY and RETURN TO EXPLORE actions",
	)
	var camera_rig := player.get_node("CameraRig") as Node3D
	var yaw_pivot := camera_rig.get_node("YawPivot") as Node3D
	var pitch_pivot := camera_rig.get_node("YawPivot/PitchPivot") as Node3D
	var authored_pitch := pitch_pivot.rotation.x
	camera_rig.call("apply_look_delta", Vector2(100.0, 220.0))
	var chosen_yaw := yaw_pivot.rotation.y
	_expect(
		pitch_pivot.rotation.x < authored_pitch - 0.3,
		"a prior fight can leave the camera pitched toward the floor",
	)
	retry.pressed.emit()
	_expect(
		(
			int(main.get("session_mode")) == 1
			and int(wave.get("current_wave")) == 0
			and is_equal_approx(pitch_pivot.rotation.x, authored_pitch)
			and is_equal_approx(yaw_pivot.rotation.y, chosen_yaw)
		),
		"RETRY re-centers the horizon without turning the player or spawning immediately",
	)
	main.call("_process", 5.1)
	wave.call("end_session")
	camera_rig.call("apply_look_delta", Vector2(0.0, 185.0))
	explore.pressed.emit()
	_expect(
		(
			int(main.get("session_mode")) == 0
			and not results.visible
			and int(wave.get("current_wave")) == 0
			and drone.visible
			and drone.is_in_group("enemies")
			and is_equal_approx(pitch_pivot.rotation.x, authored_pitch)
		),
		"RETURN TO EXPLORE restores the harmless target and a readable horizon",
	)

	main.queue_free()
	await process_frame
	if _failures > 0:
		printerr("Exploration flow smoke: %d failure(s)" % _failures)
		quit(1)
	else:
		print("Exploration flow smoke: PASS")
		quit()


func _tap(hud: Control, button: Button) -> void:
	var position := button.get_global_rect().get_center()
	var touch := InputEventScreenTouch.new()
	touch.index = 61
	touch.position = position
	touch.pressed = true
	hud.call("_input", touch)
	touch.pressed = false
	hud.call("_input", touch)


func _expect(condition: bool, label: String) -> void:
	if condition:
		print("  PASS: ", label)
	else:
		printerr("  FAIL: ", label)
		_failures += 1
