extends SceneTree

## SH-01 Aetherfall Recovery & Extraction contract: real 3D robot guard squads
## (including armored Enforcer + Iron Warden), multi-cache chaining across
## Horizon Relay -> Sentinel Archive, optional Arrival Outpost & East Hangar
## caches (Arc Shooter blueprint + permanent BP), Endless coexistence, and
## tier-free Operative redeploy.
const MainScene = preload("res://scenes/main.tscn")
const FrontEndScene = preload("res://scenes/ui/front_end.tscn")
const WORLD_ID := &"aetherfall"
const RELAY := &"aetherfall_horizon_relay"
const ARCHIVE := &"aetherfall_archive_vault"
const OUTPOST_OPT := &"aetherfall_primary_tech_cache"
const HANGAR_OPT := &"aetherfall_hangar_cache"
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
		"Aetherfall landing has no automatic wave combat",
	)
	await _exercise_escalating_guidance(main)
	await _secure_cache_at(main, RELAY, Vector3(8.0, 1.2, 8.6), 4)
	_expect(not paused, "securing first required cache chains to Sentinel Archive without pausing")
	await _secure_cache_at(main, ARCHIVE, Vector3(8.0, 1.2, -12.6), 5)
	var progression := main.get_node("ProgressionService") as ProgressionService
	_expect(
		(
			progression.is_cache_secured(RELAY)
			and progression.is_cache_secured(ARCHIVE)
			and progression.has_blueprint(&"breach_capacitor")
			and progression.has_blueprint(&"storm_conductor")
		),
		"securing both required landmarks persists Breach Capacitor and Storm Conductor schematics",
	)
	_expect(paused, "securing final required landmark opens explicit mission-complete choice")
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
	_expect(int(wave.get("current_wave")) == 1, "Continue enters the Endless wave loop")
	wave.set_physics_process(false)
	for enemy in wave.call("get_active_enemies"):
		(enemy as Node).set_physics_process(false)
	var wave_before := _wave_values(wave)

	await _secure_cache_at(main, HANGAR_OPT, Vector3(30.0, 1.2, 11.2), 3)
	_expect(
		_wave_values(wave) == wave_before, "guard encounters do not alter Endless wave counters"
	)
	_expect(
		progression.is_cache_secured(HANGAR_OPT) and progression.has_blueprint(&"arc_shooter"),
		"East Hangar cache persists Arc Shooter blueprint + 95 permanent BP",
	)
	var wallet_after_secure := progression.balance
	var player := main.get_node("Player") as CharacterBody3D
	var run_bp_before_death: int = main.get_node("RunStats").get("bp_earned")
	player.call("apply_damage", 1000.0)
	await process_frame
	main.queue_free()
	await process_frame
	paused = false
	var reloaded := await _reload_profile(CONTINUE_PROFILE)
	_expect(
		(
			reloaded.has_blueprint(&"arc_shooter")
			and reloaded.has_blueprint(&"breach_capacitor")
			and reloaded.has_blueprint(&"storm_conductor")
			and reloaded.balance == wallet_after_secure + run_bp_before_death
			and reloaded.completed_runs == 1
		),
		"secured schematics and permanent + run BP survive profile reload without duplication",
	)
	reloaded.queue_free()
	await process_frame


func _exercise_death_retry_and_extract() -> void:
	var main := await _make_main(EXTRACT_PROFILE)
	var progression := main.get_node("ProgressionService") as ProgressionService
	var player := main.get_node("Player") as CharacterBody3D
	player.set_physics_process(false)
	player.global_position = Vector3(8.0, 1.2, 8.6)
	await physics_frame
	await physics_frame
	main.call("_update_recovery")
	main.call("_on_recovery_action")
	_expect(
		main.get_node("WaveDirector").call("guard_group_size", RELAY) == 4,
		"death-before fixture spawns 4 Horizon Relay guards",
	)
	player.call("apply_damage", 1000.0)
	await process_frame
	_expect(
		not progression.has_blueprint(&"breach_capacitor") and progression.balance == 0,
		"death before Secure grants no schematic or cache BP",
	)
	var hud := main.get_node("HUD/TouchControls") as TouchControls
	(hud.get("_results_retry_button") as Button).pressed.emit()
	await process_frame
	_expect(
		not progression.has_blueprint(&"breach_capacitor") and not player.call("is_defeated"),
		"retry resets unfinished attempt cleanly",
	)

	await _secure_cache_at(main, RELAY, Vector3(8.0, 1.2, 8.6), 4)
	await _secure_cache_at(main, ARCHIVE, Vector3(8.0, 1.2, -12.6), 5)
	var choice_summary := (hud.get("_results_summary") as Label).text
	_expect(
		choice_summary.contains("SABLE") and not choice_summary.contains("TIER"),
		"Mission Complete choice logs expedition with zero hero-tier text",
	)
	(hud.get("_results_retry_button") as Button).pressed.emit()
	await process_frame
	_expect(
		(hud.get("_state") as HudState).results_mode == "results",
		"Extract transitions from Mission Complete choice to Results",
	)
	var results_title := (hud.get("_results_title") as Label).text
	var results_summary := (hud.get("_results_summary") as Label).text
	_expect(
		(
			results_title == AegisText.t("results.extracted_title")
			and results_summary.contains("STORM CONDUCTOR")
			and results_summary.contains("RESET")
			and not results_summary.contains("TIER")
		),
		"Extraction Results explain secured schematics, expedition count, and clean reset",
	)
	main.call("_extract_from_recovery")
	_expect(progression.completed_runs == 1, "repeated Extract cannot bank a second run")
	main.queue_free()
	await process_frame
	paused = false
	await _exercise_redeploy_continuity(EXTRACT_PROFILE)


func _exercise_escalating_guidance(main: Node) -> void:
	var player := main.get_node("Player") as CharacterBody3D
	var hud := main.get_node("HUD/TouchControls") as TouchControls
	var hud_state := hud.get("_state") as HudState
	var camera_rig: Node = player.get_node("CameraRig")
	var yaw_pivot := camera_rig.get_node("YawPivot") as Node3D
	player.set_physics_process(false)
	player.global_position = Vector3(8.0, 1.2, 42.0)
	yaw_pivot.rotation.y = 0.0
	await physics_frame
	main.call("advance_recovery_guidance", 0.1)
	_expect(
		(
			main.call("recovery_guidance_stage") == "area"
			and hud_state.recovery_detail.contains(AegisText.t("recovery.dir_ahead"))
		),
		"distant player receives Area guidance with AHEAD bearing toward Horizon Relay",
	)
	yaw_pivot.rotation.y = PI
	main.call("_update_recovery")
	_expect(
		hud_state.recovery_detail.contains(AegisText.t("recovery.dir_behind")),
		"turning 180 degrees flips directional guidance to BEHIND",
	)
	yaw_pivot.rotation.y = 0.0
	player.global_position = Vector3(8.0, 1.2, 24.0)
	await physics_frame
	main.call("advance_recovery_guidance", 0.1)
	_expect(
		main.call("recovery_guidance_stage") == "local",
		"closing within 22m escalates Area guidance to Local approach guidance",
	)
	main.call("advance_recovery_guidance", 12.5)
	var relay_visual := main.get_node("RecoveryCaches/Cache_aetherfall_horizon_relay") as Node3D
	var relay_beacon := relay_visual.get_node("GuidanceBeacon") as MeshInstance3D
	var relay_label := relay_visual.get_node("RecoveryLabel") as Label3D
	_expect(
		(
			main.call("recovery_guidance_stage") == "stuck"
			and relay_beacon.visible
			and relay_label.no_depth_test
		),
		"12s without progress triggers Stuck waypoint hint and through-cover beacon",
	)


func _exercise_redeploy_continuity(profile_path: String) -> void:
	var fe := FrontEndScene.instantiate()
	fe.set("boot_stage", &"HERO")
	var fe_prog := fe.get_node("ProgressionService") as ProgressionService
	fe_prog.profile_path = profile_path
	root.add_child(fe)
	await process_frame
	await process_frame
	fe.call("go_to", &"DASHBOARD", {})
	await process_frame
	var dash_stage := fe.get("_current") as Control
	var dash_hero := dash_stage.get("_hero_status") as Label
	_expect(
		dash_hero.text.contains("HP 110") and not dash_hero.text.contains("TIER"),
		"DASHBOARD reflects Sable 110 HP with zero hero-tier label",
	)
	fe.queue_free()
	await process_frame

	var redeployed := await _make_main(profile_path)
	var player := redeployed.get_node("Player") as CharacterBody3D
	var hud := redeployed.get_node("HUD/TouchControls") as TouchControls
	var hud_state := hud.get("_state") as HudState
	_expect(
		(
			is_equal_approx(float(player.get("max_health")), 110.0)
			and is_equal_approx(float(player.call("tier_damage_reduction")), 0.06)
		),
		"redeploying spawns Sable with canonical 110 vitals and 6% armor DR",
	)
	_expect(
		(
			redeployed.call("recovery_cache_state", RELAY) == "secured"
			and redeployed.call("recovery_cache_state", ARCHIVE) == "secured"
			and hud_state.recovery_title.contains("OPTIONAL")
		),
		"redeploying into Aetherfall keeps required landmarks secured and guides toward optional caches",
	)
	redeployed.queue_free()
	await process_frame


func _secure_cache_at(
	main: Node, cache_id: StringName, approach_pos: Vector3, expected_guards: int
) -> void:
	var player := main.get_node("Player") as CharacterBody3D
	player.set_physics_process(false)
	player.global_position = approach_pos
	player.set("velocity", Vector3.ZERO)
	await physics_frame
	await physics_frame
	main.call("_update_recovery")
	var hud := main.get_node("HUD/TouchControls") as TouchControls
	_expect(
		(hud.get("_state") as HudState).recovery_action == "engage",
		"%s offers explicit Engage when approached" % cache_id,
	)
	_last_guard_error = ""
	main.call("_on_recovery_action")
	var wave: Node = main.get_node("WaveDirector")
	_expect(
		wave.call("guard_group_size", cache_id) == expected_guards,
		"%s spawns %d real 3D robot guards · %s" % [cache_id, expected_guards, _last_guard_error],
	)
	for enemy in wave.call("get_guard_group", cache_id):
		if enemy.has_method("apply_emp_disrupt"):
			enemy.call("apply_emp_disrupt", player)
		(enemy as Node3D).call("apply_damage", 2000.0)
	await process_frame
	_expect(
		main.call("recovery_cache_state", cache_id) == "ready",
		"%s guard elimination transitions cache to Ready" % cache_id,
	)
	main.call("_update_recovery")
	main.call("_on_recovery_action")
	_expect(
		main.call("recovery_cache_state", cache_id) == "secured",
		"explicit Secure completes %s" % cache_id,
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
