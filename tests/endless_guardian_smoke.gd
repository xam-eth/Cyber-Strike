extends SceneTree

## Track 2 contract: Guardian (`Iron Warden`) verb-exam combat rules, Endless
## escalation schedule & bounded toughness caps, HUD GuardianCard telemetry +
## responsive non-overlap across desktop/mobile viewports, and single-bank rewards.
const MainScene = preload("res://scenes/main.tscn")
const GuardianScene = preload("res://scenes/enemies/guardian.tscn")

var _failures := 0


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	await _test_guardian_combat_verbs()
	await _test_endless_schedule_and_hud()
	if _failures == 0:
		print("Endless & Guardian smoke test passed.")
		quit()
	else:
		quit(1)


func _test_guardian_combat_verbs() -> void:
	var arena := Node3D.new()
	root.add_child(arena)
	var floor_body := StaticBody3D.new()
	var floor_shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(60.0, 1.0, 60.0)
	floor_shape.shape = box
	floor_shape.position = Vector3(0.0, -0.5, 0.0)
	floor_body.add_child(floor_shape)
	arena.add_child(floor_body)

	var main_scene := MainScene.instantiate()
	main_scene.set("start_wave_session_on_ready", false)
	main_scene.get_node("ProgressionService").set("profile_path", "")
	arena.add_child(main_scene)
	await process_frame
	await physics_frame

	var player := main_scene.get_node("Player") as CharacterBody3D
	player.set_physics_process(false)
	player.global_position = Vector3(0.0, 0.1, 8.0)

	var guardian := GuardianScene.instantiate() as CharacterBody3D
	guardian.set("target_path", player.get_path())
	main_scene.get_node("WaveEnemies").add_child(guardian)
	guardian.global_position = Vector3(0.0, 0.1, 0.0)
	await process_frame
	await physics_frame

	_expect(
		bool(guardian.call("is_shielded")) and String(guardian.call("get_phase_id")) == "fortified",
		"Guardian enters combat in FORTIFIED barrier state",
	)
	var start_hp := float(guardian.get("current_health"))
	guardian.call("apply_damage", 20.0)
	var after_fortified_shot := float(guardian.get("current_health"))
	_expect(
		is_equal_approx(start_hp - after_fortified_shot, 9.0),
		"frontal barrier dampens ordinary gunfire to 0.45x without full immunity",
	)

	# Trigger salvo windup and prove relocation dodges the locked blast zone.
	guardian.set("_salvo_cooldown_remaining", 0.0)
	guardian.set("salvo_windup", 0.25)
	await physics_frame
	await physics_frame
	_expect(
		(
			bool(guardian.call("is_winding_up"))
			and (guardian.get_node("AimMarker") as Node3D).visible
			and (guardian.get_node("SalvoRing") as Node3D).visible
		),
		"salvo lock shows explicit aim marker and floor blast ring",
	)
	var player_hp_before := float(player.get("current_health"))
	player.global_position = Vector3(6.0, 0.1, 8.0)
	for _frame in 30:
		if bool(guardian.call("is_exposed")):
			break
		await physics_frame
	_expect(
		is_equal_approx(float(player.get("current_health")), player_hp_before),
		"relocating outside the locked blast radius cleanly avoids salvo damage",
	)
	_expect(
		(
			bool(guardian.call("is_exposed"))
			and not (guardian.get_node("ShieldMesh") as Node3D).visible
		),
		"completing a salvo opens the unshielded EXPOSED punish window",
	)

	# Reset to FORTIFIED, move player within EMP radius, and prove EMP shatters the shield.
	guardian.call("reset_guardian")
	guardian.global_position = Vector3(0.0, 0.1, 2.0)
	player.global_position = Vector3(0.0, 0.1, 7.0)
	await physics_frame
	_expect(bool(guardian.call("is_shielded")), "reset restores the Guardian barrier")
	var fired_emp := bool(player.call("activate_skill"))
	var emp_dmg := float(player.get("emp_pulse_damage"))
	var expected_after_emp := 135.0 - emp_dmg * 1.5
	_expect(
		(
			fired_emp
			and bool(guardian.call("is_exposed"))
			and is_equal_approx(float(guardian.get("current_health")), expected_after_emp)
		),
		"EMP Pulse shatters the Guardian barrier and deals exposed 1.5x damage",
	)
	var before_punish := float(guardian.get("current_health"))
	guardian.call("apply_damage", 20.0)
	_expect(
		is_equal_approx(before_punish - float(guardian.get("current_health")), 30.0),
		"punish-window shots deal 1.5x critical damage to the exposed core",
	)

	arena.queue_free()
	await process_frame


func _test_endless_schedule_and_hud() -> void:
	var main_scene := MainScene.instantiate()
	main_scene.set("start_wave_session_on_ready", false)
	main_scene.get_node("ProgressionService").set("profile_path", "")
	var wave: Node = main_scene.get_node("WaveDirector")
	wave.set("initial_spawn_delay", 0.0)
	wave.set("spawn_interval", 0.01)
	wave.set("intermission_duration", 0.04)
	root.add_child(main_scene)
	await process_frame

	_expect(
		(
			not bool(wave.call("is_guardian_wave", 1))
			and not bool(wave.call("is_guardian_wave", 2))
			and bool(wave.call("is_guardian_wave", 3))
			and not bool(wave.call("is_guardian_wave", 4))
			and bool(wave.call("is_guardian_wave", 6))
			and int(wave.call("get_guardian_count_for_wave", 9, 8)) == 2
		),
		"Guardian waves schedule strictly on milestone waves (3, 6, 9...) without spamming",
	)
	_expect(
		(
			is_equal_approx(float(wave.call("get_health_scale_for_wave", 5)), 1.0)
			and float(wave.call("get_health_scale_for_wave", 6)) > 1.05
			and is_equal_approx(float(wave.call("get_health_scale_for_wave", 20)), 1.35)
		),
		"Endless toughness stays 1.0x through wave 5 and hard-caps at 1.35x",
	)

	# Guard-group integration: a cache guarded by a Guardian works without touching wave counters.
	var guard_ok := bool(
		(
			wave
			. call(
				"spawn_guard_group",
				&"guardian_cache_probe",
				[{"enemy_id": &"guardian", "position": Vector3(0.0, 0.1, -4.0)}],
			)
		)
	)
	_expect(
		guard_ok and int(wave.call("guard_group_size", &"guardian_cache_probe")) == 1,
		"WaveDirector spawns a Guardian guard group without starting a wave",
	)
	for member in wave.call("get_guard_group", &"guardian_cache_probe"):
		(member as Node3D).call("apply_damage", 1000.0)
	await process_frame
	_expect(
		(
			int(wave.call("guard_group_size", &"guardian_cache_probe")) == 0
			and int(wave.get("current_wave")) == 0
		),
		"clearing a Guardian guard group leaves wave counters untouched",
	)

	# Activate Endless mode and advance through Wave 1 -> Wave 2 -> Wave 3 (Guardian milestone).
	wave.call("set_endless_mode", true)
	wave.call("start_session")
	for _step in 240:
		if int(wave.get("current_wave")) >= 3 and wave.call("get_active_guardian") != null:
			break
		if int(wave.get("current_wave")) < 3:
			for enemy in wave.call("get_active_enemies"):
				(enemy as Node3D).call("apply_damage", 1000.0)
		await physics_frame

	var active_guardian := wave.call("get_active_guardian") as Node3D
	wave.set("intermission_duration", 2.0)
	_expect(
		int(wave.get("current_wave")) == 3 and is_instance_valid(active_guardian),
		"Wave 3 spawns a live Iron Warden Guardian in Endless mode",
	)

	var hud := main_scene.get_node("HUD/TouchControls") as TouchControls
	var guardian_card := hud.get("_guardian_card") as Control
	var guardian_phase := hud.get("_guardian_phase_label") as Label
	_expect(
		guardian_card != null and guardian_card.visible,
		"HUD GuardianCard appears automatically while a Guardian is alive",
	)
	# Verify non-overlap across desktop and mobile landscape viewports.
	for vp in [Vector2(1280, 720), Vector2(844, 390), Vector2(667, 375)]:
		hud.apply_layout_for_size(vp, 1.0)
		var g_rect := guardian_card.get_rect()
		var wave_rect := (hud.get("_wave_card") as Control).get_rect()
		var ammo_rect := (hud.get("_touch_ammo_chip") as Control).get_rect()
		_expect(
			(
				g_rect.position.x >= 0.0
				and g_rect.end.x <= vp.x
				and not g_rect.intersects(wave_rect)
				and not g_rect.intersects(ammo_rect)
			),
			"GuardianCard fits cleanly without overlapping WaveCard or Ammo on %s" % vp,
		)

	# Verify EN/ID live localization on GuardianCard.
	if is_instance_valid(active_guardian):
		active_guardian.call("apply_emp_disrupt")
	await process_frame
	AegisText.set_locale("id", false)
	_expect(
		guardian_phase.text == AegisText.t("hud.guardian_exposed"),
		"GuardianCard phase label localizes live in Bahasa Indonesia",
	)
	AegisText.set_locale("en", false)

	# Clear Wave 3 and verify single-bank Guardian + milestone rewards.
	var run_stats: Node = main_scene.get_node("RunStats")
	var reward_service: Node = main_scene.get_node("RewardService")
	for _step in 120:
		if int(wave.get("current_wave")) == 3 and int(wave.get("enemies_remaining")) == 0:
			break
		for enemy in wave.call("get_active_enemies"):
			var e := enemy as Node3D
			e.call("apply_damage", 1000.0)
			reward_service.call("award_enemy_defeat", e)
		await physics_frame

	var bp_after_w3 := int(run_stats.get("bp_earned"))
	reward_service.call("award_wave_completion", 3, true)
	_expect(
		(
			int(run_stats.get("guardians_defeated")) == 1
			and int(run_stats.get("bp_earned")) == bp_after_w3
			and not guardian_card.visible
		),
		"Guardian defeat + Wave 3 milestone bank once and hide GuardianCard on clear",
	)

	# Cash out via Finish Run and verify Results summary reflects Endless + Guardian.
	main_scene.call("_finish_run")
	await process_frame
	var summary := (hud.get("_results_summary") as Label).text
	_expect(
		summary.contains("IRON WARDEN") and summary.contains("ENDLESS SURVIVAL"),
		"Results summary reports real Guardian eliminations and Endless wave reached",
	)

	paused = false
	main_scene.queue_free()
	await process_frame


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures += 1
		push_error("Endless & Guardian smoke test failed: " + message)
