extends SceneTree

## Phase 3 contract: Multi-theatre expeditions across 4 frontier worlds (8 caches
## total while Frostline Relay stays Defense-only), permanent Field Kit Tech
## Modules (`MAX_SLOTS = 2`), real combat hooks (ADS Warden shield pierce, EMP
## magazine refill, Arc chain EMP cooldown refund), strict separation from
## temporary run evolutions on retry/reset, and Armory UI layout on 667x375.
const MainScene = preload("res://scenes/main.tscn")
const GuardianScene = preload("res://scenes/enemies/guardian.tscn")

var _failures := 0


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	_test_multi_theatre_world_definitions()
	_test_progression_module_rules_and_persistence()
	await _test_combat_hooks_and_run_reset_isolation()
	await _test_live_expedition_and_armory_field_kit_ui()
	if _failures == 0:
		print("Multi-theatre & Tech Modules smoke test passed.")
		quit()
	else:
		quit(1)


func _test_multi_theatre_world_definitions() -> void:
	var frostline := WorldDefinition.load_definition(&"frostline_relay")
	_expect(
		frostline != null and not frostline.has_recovery_caches(),
		"Frostline Relay remains a pure Wave Defense baseline theatre",
	)
	var expected := {
		"verdant_bloom": {"primary_wpn": &"arc_shooter", "primary_mod": &"", "bp": 80},
		"emberfall_foundry": {"primary_wpn": &"", "primary_mod": &"breach_capacitor", "bp": 90},
		"vanguard_station": {"primary_wpn": &"", "primary_mod": &"phase_thrusters", "bp": 95},
		"titans": {"primary_wpn": &"", "primary_mod": &"storm_conductor", "bp": 100},
	}
	var seen_cache_ids: Dictionary = {}
	for world_key in expected.keys():
		var wdef := WorldDefinition.load_definition(StringName(world_key))
		var spec: Dictionary = expected[world_key]
		if not _expect(
			wdef != null and wdef.recovery_caches.size() == 2,
			"%s defines exactly 2 authored expedition caches" % world_key,
		):
			continue
		var primary := wdef.recovery_caches[0] as RecoveryCacheDefinition
		var optional := wdef.recovery_caches[1] as RecoveryCacheDefinition
		_expect(
			(
				primary != null
				and not primary.optional
				and primary.blueprint_id == spec["primary_wpn"]
				and primary.module_id == spec["primary_mod"]
			),
			"%s primary cache maps to canonical schematic reward" % world_key,
		)
		_expect(
			optional != null and optional.optional and optional.bp_reward == int(spec["bp"]),
			"%s optional cache grants %d permanent BP" % [world_key, int(spec["bp"])],
		)
		for item in wdef.recovery_caches:
			var c := item as RecoveryCacheDefinition
			_expect(
				c != null and not seen_cache_ids.has(c.cache_id),
				"cache_id %s is globally unique across theatres" % c.cache_id,
			)
			if c != null:
				seen_cache_ids[c.cache_id] = true
	_expect(seen_cache_ids.size() == 8, "frontier defines 8 distinct expedition caches in total")


func _test_progression_module_rules_and_persistence() -> void:
	var tmp_path := "user://test_phase3_modules_%d.cfg" % Time.get_ticks_usec()
	var svc := ProgressionService.new()
	svc.profile_path = tmp_path
	svc.reset_state()
	svc.balance = 600

	_expect(
		not svc.unlock_module(&"breach_capacitor"),
		"cannot buy Breach Capacitor before securing its schematic",
	)
	_expect(
		svc.secure_cache(
			&"emberfall_seam_core", &"breach_capacitor_schematic", &"", 0, &"breach_capacitor"
		),
		"securing Emberfall primary cache records Breach Capacitor schematic",
	)
	_expect(
		not svc.secure_cache(
			&"emberfall_seam_core", &"breach_capacitor_schematic", &"", 0, &"breach_capacitor"
		),
		"re-securing an already secured module cache is strictly idempotent",
	)
	_expect(
		svc.has_blueprint(&"breach_capacitor") and svc.unlock_module(&"breach_capacitor"),
		"Breach Capacitor unlocks for 140 BP once schematic is recovered",
	)
	_expect(svc.balance == 460, "unlocking Breach Capacitor deducts exact 140 BP")

	svc.secure_cache(
		&"vanguard_reactor_core", &"phase_thrusters_schematic", &"", 0, &"phase_thrusters"
	)
	svc.secure_cache(
		&"titans_storm_spire", &"storm_conductor_schematic", &"", 0, &"storm_conductor"
	)
	_expect(
		svc.unlock_module(&"phase_thrusters") and svc.unlock_module(&"storm_conductor"),
		"Phase Thrusters (120 BP) and Storm Conductor (160 BP) unlock cleanly",
	)
	_expect(svc.balance == 180, "wallet reflects 600 - 140 - 120 - 160 = 180 BP")

	_expect(
		svc.toggle_module(&"breach_capacitor") and svc.toggle_module(&"phase_thrusters"),
		"can equip two owned Tech Modules into Field Kit",
	)
	_expect(
		not svc.toggle_module(&"storm_conductor") and svc.equipped_modules.size() == 2,
		"third Tech Module is refused while 2/2 Field Kit slots are occupied",
	)
	_expect(
		svc.toggle_module(&"phase_thrusters") and svc.toggle_module(&"storm_conductor"),
		"unequipping slot 2 frees room to equip Storm Conductor",
	)

	var reloaded := ProgressionService.new()
	reloaded.profile_path = tmp_path
	reloaded.load_profile()
	_expect(
		(
			reloaded.balance == 180
			and reloaded.unlocked_modules.size() == 3
			and reloaded.equipped_modules.size() == 2
			and reloaded.equipped_modules[0] == &"breach_capacitor"
			and reloaded.equipped_modules[1] == &"storm_conductor"
		),
		"ConfigFile reload preserves wallet, unlocked modules, and equipped Field Kit order",
	)
	DirAccess.remove_absolute(ProjectSettings.globalize_path(tmp_path))
	svc.free()
	reloaded.free()


func _test_combat_hooks_and_run_reset_isolation() -> void:
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
	var prog: ProgressionService = main_scene.get_node("ProgressionService")
	prog.profile_path = ""
	arena.add_child(main_scene)
	await process_frame
	await physics_frame

	var player := main_scene.get_node("Player") as CharacterBody3D
	var wc := player.get("weapon_controller") as Node
	player.set_physics_process(false)
	player.global_position = Vector3(0.0, 0.1, 8.0)

	var guardian := GuardianScene.instantiate() as CharacterBody3D
	guardian.set("target_path", player.get_path())
	main_scene.get_node("WaveEnemies").add_child(guardian)
	guardian.global_position = Vector3(0.0, 0.1, 0.0)
	await process_frame
	await physics_frame

	# Equip Breach Capacitor + Phase Thrusters on Player.
	var mods := TechModuleDefinition.aggregate_modifiers([&"breach_capacitor", &"phase_thrusters"])
	player.call("set_tech_modifiers", mods)

	player.call("set_touch_aim_held", false)
	var hp0 := float(guardian.get("current_health"))
	guardian.call("apply_damage", 20.0, player)
	var hip_delta := hp0 - float(guardian.get("current_health"))
	_expect(
		is_equal_approx(hip_delta, 9.0),
		"hip-fire with Breach Capacitor still takes 0.45x on FORTIFIED Warden",
	)

	player.call("set_touch_aim_held", true)
	var hp1 := float(guardian.get("current_health"))
	guardian.call("apply_damage", 20.0, player)
	var ads_delta := hp1 - float(guardian.get("current_health"))
	_expect(
		is_equal_approx(ads_delta, 20.0),
		"ADS fire with Breach Capacitor pierces FORTIFIED Warden barrier for full 1.0x damage",
	)
	player.call("set_touch_aim_held", false)

	# Verify Phase Thrusters EMP magazine refill (35% of 24 = ceil(8.4) = 9 rounds).
	var mags := wc.get("_magazines") as Array
	mags[0] = 10
	var used_emp := bool(player.call("activate_skill"))
	_expect(
		used_emp and int(wc.call("get_current_ammo")) == 19,
		"Phase Thrusters refills 35% of active magazine on EMP activation",
	)

	# Equip Storm Conductor and verify Arc chain EMP cooldown refund + chain count bonus.
	prog.unlocked_ids["arc_shooter"] = true
	wc.call("set_available_weapon_ids", prog.unlocked_ids)
	player.call("select_weapon", 2)
	var storm_mods := TechModuleDefinition.aggregate_modifiers([&"storm_conductor"])
	player.call("set_tech_modifiers", storm_mods)
	var eff_arc := wc.call("get_effective_definition") as WeaponDefinition
	_expect(
		eff_arc != null and eff_arc.chain_count == 3,
		"Storm Conductor increases Arc Shooter chain bounces from 2 to 3",
	)
	var cd_before := float(player.get("_skill_cooldown_remaining"))
	player.call("notify_arc_chain_hit")
	var cd_after := float(player.get("_skill_cooldown_remaining"))
	_expect(
		cd_before > 1.0 and is_equal_approx(cd_before - cd_after, 0.75),
		"Storm Conductor refunds 0.75s of active EMP cooldown on each Arc chain bounce",
	)

	# Temporary run upgrade reset must NOT wipe permanent Tech Module modifiers.
	player.call("apply_run_modifiers", {"damage_multiplier": 1.3}, 0.0, false)
	player.call("clear_run_modifiers")
	eff_arc = wc.call("get_effective_definition") as WeaponDefinition
	_expect(
		eff_arc != null and eff_arc.chain_count == 3 and is_equal_approx(eff_arc.damage, 20.0),
		"clearing temporary run evolutions resets run damage buff while keeping Tech Module chain bonus",
	)

	arena.queue_free()
	await process_frame


func _test_live_expedition_and_armory_field_kit_ui() -> void:
	root.size = Vector2i(667, 375)
	var prev_world := WorldSelection.override_selection(&"emberfall_foundry")
	var main_scene := MainScene.instantiate()
	main_scene.set("start_wave_session_on_ready", false)
	var prog: ProgressionService = main_scene.get_node("ProgressionService")
	prog.profile_path = ""
	root.add_child(main_scene)
	await process_frame
	await physics_frame
	WorldSelection.override_selection(prev_world)

	var caches_root := main_scene.get_node_or_null("RecoveryCaches")
	_expect(
		caches_root != null and caches_root.get_child_count() == 2,
		"Emberfall Foundry spawns 2 live RecoveryCacheVisual landmarks outside MissionWorld",
	)

	# Simulate clearing guards and securing Emberfall primary schematic cache.
	var primary := (main_scene.get("_recovery_caches") as Array)[0] as RecoveryCacheDefinition
	var player := main_scene.get_node("Player") as Node3D
	player.global_position = primary.position + Vector3(0.0, 0.2, 1.5)
	(main_scene.get("_recovery_states") as Dictionary)[primary.cache_id] = 2
	var secured := bool(main_scene.call("_secure_cache", primary))
	_expect(
		secured and prog.has_blueprint(&"breach_capacitor"),
		"securing Emberfall Seam Core grants Breach Capacitor schematic and opens extraction choice",
	)
	var hud := main_scene.get_node("UI/TouchControls") as Control
	var reward_lbl := hud.get("_results_reward_label") as Label
	_expect(
		bool(hud.call("_results_visible")) and reward_lbl.text.contains("BREACH CAPACITOR"),
		"extraction choice displays Breach Capacitor schematic reward",
	)

	# Continue to field, grant BP, open Armory on 667x375, switch to FIELD KIT tab, unlock + equip.
	main_scene.call("_continue_to_endless")
	prog.balance = 200
	main_scene.call("_on_profile_changed")
	main_scene.call("_open_armory")
	await process_frame
	var armory := hud.get("_armory_panel") as Control
	armory.call("show_tab", "modules")
	await process_frame

	var mod_btns: Array = armory.get("_module_buttons")
	_expect(
		armory.visible and mod_btns.size() == 3,
		"Armory FIELD KIT tab exposes 3 real Tech Module action buttons",
	)
	var panel_rect := armory.get_global_rect()
	_expect(
		panel_rect.position.y >= 0.0 and panel_rect.end.y <= float(hud.size.y) + 1.0,
		"Armory FIELD KIT tab fits cleanly inside compact 667x375 viewport",
	)
	(mod_btns[0] as BaseButton).pressed.emit()
	await process_frame
	_expect(
		(
			prog.unlocked_modules.has("breach_capacitor")
			and prog.equipped_modules.has(&"breach_capacitor")
			and prog.balance == 60
		),
		"pressing Breach Capacitor action in Armory unlocks (140 BP) and equips Slot 1/2 live",
	)
	var badge := hud.get("_health_tier_badge") as Label
	_expect(
		badge != null and badge.text.contains("BREACH"),
		"HUD OperativeTierBadge reflects active permanent Field Kit module in cyan",
	)

	main_scene.call("_close_armory")
	main_scene.queue_free()
	await process_frame


func _expect(condition: bool, label: String) -> bool:
	if not condition:
		_failures += 1
		push_error("FAIL: %s" % label)
	return condition
