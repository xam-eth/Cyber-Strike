extends SceneTree

const MainScene = preload("res://scenes/main.tscn")
const RunnerScene = preload("res://scenes/enemies/runner.tscn")

var _received_target_damage: Array[float] = []
var _received_player_damage: Array[float] = []


func _initialize() -> void:
	call_deferred("_run_smoke_test")


func _run_smoke_test() -> void:
	var main_scene := MainScene.instantiate()
	main_scene.set("start_wave_session_on_ready", false)
	root.add_child(main_scene)
	await process_frame

	var player: Node3D = main_scene.get_node("Player")
	var target: Node = main_scene.get_node("TrainingDrone")
	var controls: Node = main_scene.get_node("HUD/TouchControls")
	var results_panel: PanelContainer = controls.get("_results_panel")
	var results_retry_button: Button = controls.get("_results_retry_button")
	target.connect("damage_received", _on_target_damage_received)
	player.connect("damage_received", _on_player_damage_received)

	var weapon_controller: Node = player.get_node("WeaponController")
	var muzzle: Marker3D = player.get_node("VisualRoot/WeaponSocket/Muzzle")
	weapon_controller.call("try_fire", player, muzzle, Vector3(0.0, 0.9, -8.0))
	for _frame in 45:
		await physics_frame
		if not _received_target_damage.is_empty():
			break

	var test_passed := true
	test_passed = (
		_expect(not _received_target_damage.is_empty(), "projectile hits the training target")
		and test_passed
	)
	test_passed = (
		_expect(
			is_equal_approx(float(target.get("current_health")), 36.0),
			"target health applies damage"
		)
		and test_passed
	)
	test_passed = (
		_expect(_received_target_damage.size() == 1, "one target damage event is emitted")
		and test_passed
	)
	if not _received_target_damage.is_empty():
		test_passed = (
			_expect(
				is_equal_approx(_received_target_damage[0], 18.0),
				"target event reports applied damage"
			)
			and test_passed
		)
	test_passed = (
		_expect(
			float(controls.get("_hit_confirm_remaining")) > 0.0, "hit marker activates on a hit"
		)
		and test_passed
	)

	var runner := RunnerScene.instantiate() as Node3D
	runner.position = player.global_position + Vector3(1.0, 0.0, 0.0)
	main_scene.add_child(runner)
	await process_frame
	for _frame in 3:
		await physics_frame
		if not _received_player_damage.is_empty():
			break
	test_passed = (
		_expect(not _received_player_damage.is_empty(), "Runner attacks the player in range")
		and test_passed
	)
	test_passed = (
		_expect(
			is_equal_approx(float(player.get("current_health")), 92.0),
			"Runner damage reduces health"
		)
		and test_passed
	)
	if not _received_player_damage.is_empty():
		test_passed = (
			_expect(
				is_equal_approx(_received_player_damage[0], 8.0), "Runner damage amount is applied"
			)
			and test_passed
		)
	test_passed = (
		_expect(
			float(controls.get("_damage_flash_remaining")) > 0.0, "player damage flashes the HUD"
		)
		and test_passed
	)

	controls.call("_on_fire_down")
	test_passed = (
		_expect(bool(player.get("_touch_fire_pressed")), "touch fire press reaches player")
		and test_passed
	)
	main_scene.call("_toggle_pause")
	test_passed = (
		_expect(not bool(player.get("_touch_fire_pressed")), "pause clears held touch fire")
		and test_passed
	)
	main_scene.call("_toggle_pause")

	player.call("apply_damage", 100.0)
	test_passed = (
		_expect(bool(player.call("is_defeated")), "zero health marks player defeated")
		and test_passed
	)
	test_passed = (
		_expect(results_panel.visible, "player defeat opens the results panel") and test_passed
	)
	test_passed = (
		_expect(
			results_retry_button.visible and results_retry_button.text == "RETRY EXPLORE",
			"Explore defeat offers an explicit recovery, not an unsolicited Defense run",
		)
		and test_passed
	)
	results_retry_button.emit_signal("pressed")
	test_passed = (
		_expect(not bool(player.call("is_defeated")), "retry restores the player") and test_passed
	)
	test_passed = (
		_expect(not results_panel.visible, "retry hides the results panel") and test_passed
	)
	test_passed = (
		_expect(
			is_equal_approx(float(player.get("current_health")), 100.0),
			"retry restores player health"
		)
		and test_passed
	)
	test_passed = (
		_expect(is_equal_approx(float(target.get("current_health")), 54.0), "retry restores target")
		and test_passed
	)
	var wave_director: Node = main_scene.get_node("WaveDirector")
	test_passed = (
		_expect(
			(
				int(wave_director.get("current_wave")) == 0
				and int(main_scene.get("session_mode")) == 0
			),
			"retry from an Explore encounter restores safe Explore, not an unsolicited wave",
		)
		and test_passed
	)

	main_scene.queue_free()
	await process_frame
	if test_passed:
		print("Runner and combat feedback smoke test passed.")
		quit()
	else:
		quit(1)


func _on_target_damage_received(amount: float, _current: float, _maximum: float) -> void:
	_received_target_damage.append(amount)


func _on_player_damage_received(amount: float, _current: float, _maximum: float) -> void:
	_received_player_damage.append(amount)


func _expect(condition: bool, message: String) -> bool:
	if not condition:
		push_error("Runner and combat feedback smoke test failed: " + message)
	return condition
