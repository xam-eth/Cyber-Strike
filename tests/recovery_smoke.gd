extends SceneTree

## TECH HUNT 0 contract: real guard actors, explicit Secure, permanent profile
## writes, both mission-complete choices, Endless coexistence, and death/retry.
const MainScene = preload("res://scenes/main.tscn")
const WORLD_ID := &"verdant_bloom"
const PRIMARY := &"verdant_seed_vault"
const OPTIONAL := &"verdant_crashed_lab"
const CONTINUE_PROFILE := "user://recovery-continue-smoke.cfg"
const EXTRACT_PROFILE := "user://recovery-extract-smoke.cfg"

var _failures := 0
var _last_guard_error := ""


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	_remove_profile(CONTINUE_PROFILE)
	_remove_profile(EXTRACT_PROFILE)
	var previous := WorldSelection.override_selection(WORLD_ID)
	await _exercise_continue_and_death()
	await _exercise_death_retry_and_extract()
	WorldSelection.override_selection(previous)
	_remove_profile(CONTINUE_PROFILE)
	_remove_profile(EXTRACT_PROFILE)
	if _failures == 0:
		print("RECOVERY smoke test passed.")
		quit()
	else:
		quit(1)


func _exercise_continue_and_death() -> void:
	var main := await _make_main(CONTINUE_PROFILE)
	var wave: Node = main.get_node("WaveDirector")
	_expect(
		wave.get("current_wave") == 0 and wave.call("get_active_enemies").is_empty(),
		"Verdant landing has no automatic combat",
	)
	await _secure_primary(main)
	var progression := main.get_node("ProgressionService") as ProgressionService
	_expect(
		progression.is_cache_secured(PRIMARY) and progression.has_blueprint(&"arc_shooter"),
		"primary Secure persists Arc blueprint immediately",
	)
	_expect(paused, "primary Secure opens the explicit mission-complete choice")
	var hud := main.get_node("HUD/TouchControls") as TouchControls
	_expect(
		(hud.get("_state") as HudState).results_mode == "extraction",
		"Results surface becomes Extract versus Continue",
	)
	(hud.get("_results_explore_button") as Button).pressed.emit()
	_expect(not paused, "Continue releases the mission-complete overlay")
	for _frame in 30:
		if int(wave.get("current_wave")) > 0:
			break
		await physics_frame
	_expect(int(wave.get("current_wave")) == 1, "Continue enters the existing Endless wave loop")
	wave.set_physics_process(false)
	for enemy in wave.call("get_active_enemies"):
		(enemy as Node).set_physics_process(false)
	var wave_before: Array[int] = [
		int(wave.get("current_wave")),
		int(wave.get("current_wave_enemy_count")),
		int(wave.get("enemies_spawned_this_wave")),
		int(wave.get("enemies_defeated_this_wave")),
	]

	var player := main.get_node("Player") as CharacterBody3D
	player.global_position = Vector3(-38.0, 0.1, 38.0)
	player.set("velocity", Vector3.ZERO)
	await physics_frame
	await physics_frame
	main.call("_update_recovery")
	_expect(
		(hud.get("_state") as HudState).recovery_action == "engage",
		"optional cache remains interactable during Endless",
	)
	main.call("_on_recovery_action")
	_expect(wave.call("guard_group_size", OPTIONAL) == 2, "Endless spawns the optional guard group")
	_expect(_wave_values(wave) == wave_before, "guard spawning does not alter wave counters")
	for enemy in wave.call("get_guard_group", OPTIONAL):
		(enemy as Node3D).call("apply_damage", 1000.0)
	await process_frame
	_expect(_wave_values(wave) == wave_before, "guard defeats do not alter wave counters")
	_expect(
		main.call("recovery_cache_state", OPTIONAL) == "ready",
		"optional guard clear makes its cache Ready",
	)
	main.call("_update_recovery")
	main.call("_on_recovery_action")
	var wallet_after_secure := progression.balance
	_expect(
		progression.is_cache_secured(OPTIONAL) and wallet_after_secure == 80,
		"optional Secure immediately writes its permanent 80 BP",
	)
	_expect(
		(
			not main.call("_secure_cache", main.call("_optional_cache"))
			and progression.balance == wallet_after_secure
		),
		"duplicate optional Secure grants no additional BP",
	)
	var run_bp_before_death: int = main.get_node("RunStats").get("bp_earned")
	player.call("apply_damage", 1000.0)
	await process_frame
	_expect(
		progression.is_cache_secured(PRIMARY) and progression.is_cache_secured(OPTIONAL),
		"death after Secure cannot erase either permanent cache",
	)
	main.queue_free()
	await process_frame
	paused = false
	var reloaded := await _reload_profile(CONTINUE_PROFILE)
	_expect(
		reloaded.has_blueprint(&"arc_shooter") and reloaded.is_cache_secured(OPTIONAL),
		"secured blueprint and optional cache survive a full profile reload",
	)
	_expect(
		(
			reloaded.balance == wallet_after_secure + run_bp_before_death
			and reloaded.completed_runs == 1
		),
		"death banks the existing run BP exactly once in addition to secured cache BP",
	)
	reloaded.queue_free()
	await process_frame


func _exercise_death_retry_and_extract() -> void:
	var main := await _make_main(EXTRACT_PROFILE)
	var progression := main.get_node("ProgressionService") as ProgressionService
	var player := main.get_node("Player") as CharacterBody3D
	player.set_physics_process(false)
	player.global_position = Vector3(0.0, 0.1, 7.0)
	await physics_frame
	await physics_frame
	main.call("_update_recovery")
	main.call("_on_recovery_action")
	_expect(
		main.get_node("WaveDirector").call("guard_group_size", PRIMARY) == 2,
		"death-before fixture has live primary guards",
	)
	player.call("apply_damage", 1000.0)
	await process_frame
	_expect(
		not progression.has_blueprint(&"arc_shooter") and progression.balance == 0,
		"death before Secure grants no blueprint or cache BP",
	)
	var hud := main.get_node("HUD/TouchControls") as TouchControls
	(hud.get("_results_retry_button") as Button).pressed.emit()
	await process_frame
	_expect(
		not progression.has_blueprint(&"arc_shooter") and not player.call("is_defeated"),
		"retry resets the unfinished attempt without inventing permanent tech",
	)

	await _secure_primary(main)
	(hud.get("_results_retry_button") as Button).pressed.emit()
	await process_frame
	_expect(
		(hud.get("_state") as HudState).results_mode == "results",
		"Extract transitions from the choice to ordinary Results",
	)
	_expect(
		progression.completed_runs == 1 and progression.balance == 0,
		"Extract banks a zero-wave Recovery run exactly once",
	)
	main.call("_extract_from_recovery")
	_expect(progression.completed_runs == 1, "repeated Extract cannot bank a second run")
	main.queue_free()
	await process_frame
	paused = false
	var reloaded := await _reload_profile(EXTRACT_PROFILE)
	_expect(
		(
			reloaded.is_cache_secured(PRIMARY)
			and reloaded.has_blueprint(&"arc_shooter")
			and reloaded.completed_runs == 1
		),
		"Extract persists the blueprint and one completed run after reload",
	)
	reloaded.queue_free()
	await process_frame


func _secure_primary(main: Node) -> void:
	var player := main.get_node("Player") as CharacterBody3D
	player.set_physics_process(false)
	player.global_position = Vector3(0.0, 0.1, 7.0)
	player.set("velocity", Vector3.ZERO)
	await physics_frame
	await physics_frame
	main.call("_update_recovery")
	var hud := main.get_node("HUD/TouchControls") as TouchControls
	_expect(
		(hud.get("_state") as HudState).recovery_action == "engage",
		"nearby guarded cache offers explicit Engage",
	)
	_last_guard_error = ""
	main.call("_on_recovery_action")
	var wave: Node = main.get_node("WaveDirector")
	_expect(
		wave.call("guard_group_size", PRIMARY) == 2,
		"Engage spawns two real primary guards · " + _last_guard_error,
	)
	_expect(
		(
			int(wave.get("current_wave_enemy_count")) == 0
			and int(wave.get("enemies_spawned_this_wave")) == 0
		),
		"primary guards are not wave enemies",
	)
	var hud_state := hud.get("_state") as HudState
	_expect(
		(
			hud_state.recovery_guard_count == 2
			and hud_state.recovery_detail == AegisText.t("recovery.guards_active", [2])
			and not (hud.get("_defense_button") as Button).visible
		),
		"live guards replace generic Defense with visible Secure-locked guidance",
	)
	main.call("_request_defense")
	_expect(
		int(main.get("session_mode")) == 0 and int(wave.get("current_wave")) == 0,
		"Defense cannot bypass or mix with an active Recovery encounter",
	)
	var primary: RecoveryCacheDefinition = main.call("_primary_cache")
	_expect(
		not main.call("_secure_cache", primary),
		"Secure cannot bypass incomplete guards",
	)
	for enemy in wave.call("get_guard_group", PRIMARY):
		(enemy as Node3D).call("apply_damage", 1000.0)
	await process_frame
	_expect(
		main.call("recovery_cache_state", PRIMARY) == "ready",
		"real guard elimination changes primary to Ready",
	)
	main.call("_update_recovery")
	_expect(
		(
			(hud.get("_state") as HudState).recovery_action == "secure"
			and (hud.get("_state") as HudState).recovery_guard_count == 0
			and (hud.get("_defense_button") as Button).visible
		),
		"Ready cache restores explicit Secure rather than another guard spawn",
	)
	main.call("_on_recovery_action")
	_expect(
		main.call("recovery_cache_state", PRIMARY) == "secured",
		"explicit Secure completes the primary cache",
	)


func _make_main(profile_path: String) -> Node:
	var main := MainScene.instantiate()
	main.set("start_wave_session_on_ready", false)
	main.set("defense_preparation_seconds", 0.05)
	main.get_node("ProgressionService").set("profile_path", profile_path)
	root.add_child(main)
	(main.get_node("WaveDirector") as Node).connect(
		"guard_group_spawn_failed", _record_guard_spawn_failed
	)
	await process_frame
	await physics_frame
	await physics_frame
	return main


func _reload_profile(profile_path: String) -> ProgressionService:
	var profile := ProgressionService.new()
	profile.profile_path = profile_path
	root.add_child(profile)
	await process_frame
	return profile


func _record_guard_spawn_failed(_group_id: StringName, reason: String) -> void:
	_last_guard_error = reason


func _wave_values(wave: Node) -> Array[int]:
	return [
		int(wave.get("current_wave")),
		int(wave.get("current_wave_enemy_count")),
		int(wave.get("enemies_spawned_this_wave")),
		int(wave.get("enemies_defeated_this_wave")),
	]


func _remove_profile(profile_path: String) -> void:
	if FileAccess.file_exists(profile_path):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(profile_path))


func _expect(condition: bool, message: String) -> bool:
	if not condition:
		_failures += 1
		push_error("RECOVERY smoke test failed: " + message)
	return condition
