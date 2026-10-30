extends SceneTree

## TECH HUNT 0 contract: real guard actors, explicit Secure, permanent profile
## writes, both mission-complete choices, Endless coexistence, and death/retry.
const MainScene = preload("res://scenes/main.tscn")
const FrontEndScene = preload("res://scenes/ui/front_end.tscn")
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
	await _exercise_escalating_guidance(main)
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
	var choice_summary := (hud.get("_results_summary") as Label).text
	_expect(
		choice_summary.contains("TIER 2") and choice_summary.contains("106 HP"),
		"Mission Complete choice explicitly previews Tier 2 (106 HP) unlock on Extract",
	)
	(hud.get("_results_retry_button") as Button).pressed.emit()
	await process_frame
	_expect(
		(hud.get("_state") as HudState).results_mode == "results",
		"Extract transitions from the choice to ordinary Results",
	)
	var results_title := (hud.get("_results_title") as Label).text
	var results_reward := (hud.get("_results_reward_label") as Label).text
	var results_summary := (hud.get("_results_summary") as Label).text
	_expect(
		(
			results_title == AegisText.t("results.extracted_title")
			and results_reward == AegisText.t("results.banked", [20])
			and results_summary.contains("ARC SHOOTER")
			and results_summary.contains("TIER 2")
			and results_summary.contains("106 HP")
			and results_summary.contains("RESET")
		),
		"Extraction Results explain +20 BP banked, kept blueprint, Tier 2 promotion, and reset run state",
	)
	_expect(
		(
			progression.completed_runs == 1
			and progression.balance == 20
			and int(main.get_node("RunStats").get("eliminations")) == 2
		),
		"Extract banks the 2 primary guard eliminations (+20 BP) and one completed run once",
	)
	_expect(
		(hud.get("_results_explore_button") as Button).text == AegisText.t("results.explore"),
		"Extract results reset the secondary button label from Continue-to-Endless back to Explore",
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
	await _exercise_tier2_redeploy(EXTRACT_PROFILE)


func _exercise_escalating_guidance(main: Node) -> void:
	var player := main.get_node("Player") as CharacterBody3D
	var hud := main.get_node("HUD/TouchControls") as TouchControls
	var hud_state := hud.get("_state") as HudState
	var camera_rig: Node = player.get_node("CameraRig")
	var yaw_pivot := camera_rig.get_node("YawPivot") as Node3D
	player.set_physics_process(false)
	player.global_position = Vector3(0.0, 0.1, 32.0)
	yaw_pivot.rotation.y = 0.0
	await physics_frame
	main.call("advance_recovery_guidance", 0.1)
	_expect(
		(
			main.call("recovery_guidance_stage") == "area"
			and hud_state.recovery_detail.contains(AegisText.t("recovery.dir_ahead"))
		),
		"distant player receives Area guidance with AHEAD bearing toward Seed Vault",
	)
	yaw_pivot.rotation.y = PI
	main.call("_update_recovery")
	_expect(
		hud_state.recovery_detail.contains(AegisText.t("recovery.dir_behind")),
		"turning 180 degrees flips directional guidance to BEHIND",
	)
	yaw_pivot.rotation.y = 0.0
	player.global_position = Vector3(0.0, 0.1, 18.0)
	await physics_frame
	main.call("advance_recovery_guidance", 0.1)
	_expect(
		main.call("recovery_guidance_stage") == "local",
		"closing within 22m escalates Area guidance to Local approach guidance",
	)
	main.call("advance_recovery_guidance", 12.5)
	var seed_visual := main.get_node("RecoveryCaches/Cache_verdant_seed_vault") as Node3D
	var seed_beacon := seed_visual.get_node("GuidanceBeacon") as MeshInstance3D
	var seed_label := seed_visual.get_node("RecoveryLabel") as Label3D
	_expect(
		(
			main.call("recovery_guidance_stage") == "stuck"
			and seed_beacon.visible
			and seed_label.no_depth_test
		),
		"12s without objective progress triggers Stuck waypoint hint and through-cover beacon",
	)
	player.global_position = Vector3(0.0, 0.1, 14.0)
	await physics_frame
	main.call("advance_recovery_guidance", 0.1)
	_expect(
		main.call("recovery_guidance_stage") == "local" and not seed_label.no_depth_test,
		"resuming forward progress clears the Stuck hint back to Local guidance",
	)


func _exercise_tier2_redeploy(profile_path: String) -> void:
	var fe := FrontEndScene.instantiate()
	fe.set("boot_stage", &"HERO")
	var fe_prog := fe.get_node("ProgressionService") as ProgressionService
	fe_prog.profile_path = profile_path
	root.add_child(fe)
	await process_frame
	await process_frame
	fe.call("go_to", &"HERO", {})
	await process_frame
	var hero_stage := fe.get("_current") as Control
	var tier_btn := hero_stage.get("_tier_button") as Button
	_expect(
		tier_btn != null and not tier_btn.disabled and fe_prog.owned_tier() == 2,
		"completed run unlocks Operative Tier 2 selection on HERO stage",
	)
	tier_btn.pressed.emit()
	await process_frame
	var tier_label := hero_stage.get("_tier_label") as Label
	_expect(
		(
			fe_prog.fieldable_tier() == 2
			and tier_label.text.contains("TIER 2")
			and tier_label.text.contains("HP 106")
		),
		"selecting Tier 2 updates HERO vitals readout to 106 HP",
	)
	fe.call("go_to", &"DASHBOARD", {})
	await process_frame
	var dash_stage := fe.get("_current") as Control
	var dash_hero := dash_stage.get("_hero_status") as Label
	_expect(
		dash_hero.text.contains("TIER 2") and dash_hero.text.contains("HP 106"),
		"DASHBOARD reflects Tier 2 and 106 HP before redeploy",
	)
	fe.queue_free()
	await process_frame

	var redeployed := await _make_main(profile_path)
	var player := redeployed.get_node("Player") as CharacterBody3D
	var hud := redeployed.get_node("HUD/TouchControls") as TouchControls
	var hud_state := hud.get("_state") as HudState
	_expect(
		(
			is_equal_approx(float(player.get("max_health")), 106.0)
			and is_equal_approx(float(player.get("current_health")), 106.0)
			and is_equal_approx(float(player.call("tier_damage_reduction")), 0.03)
		),
		"redeploying at Tier 2 spawns Sable with 106 vitals and 3% damage reduction",
	)
	_expect(
		(
			redeployed.call("recovery_cache_state", PRIMARY) == "secured"
			and hud_state.recovery_title == AegisText.t("recovery.optional_task", ["LAB CACHE"])
		),
		"redeploying into Verdant keeps Seed Vault secured and guides toward Lab Cache",
	)
	redeployed.queue_free()
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
