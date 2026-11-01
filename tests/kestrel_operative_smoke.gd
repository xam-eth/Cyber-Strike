extends SceneTree

## Phase 4 contract: Second playable operative Kestrel (Dian Prameswari, Scout)
## shares the single `roster.json` + `HeroDefinition` registry, applies real
## scout stats (-10 vitals -> 90..116 HP, +14% stride speed, -10% reload), fires
## an aimed 18m Recon Overdrive lance that disrupts Iron Warden shields at range
## and grants 3.5s Overdrive (+20% speed, +22% fire rate), applies per-instance
## tier livery without mutating global materials, and updates HUD/FrontEnd/Results.
const MainScene = preload("res://scenes/main.tscn")
const FrontEndScene = preload("res://scenes/ui/front_end.tscn")
const GuardianScene = preload("res://scenes/enemies/guardian.tscn")

var _failures := 0


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	_test_kestrel_registry_and_tier_ladder()
	await _test_recon_overdrive_combat_and_livery_isolation()
	await _test_hud_results_and_front_end_selection()
	if _failures == 0:
		print("Kestrel operative smoke test passed.")
		quit()
	else:
		quit(1)


func _test_kestrel_registry_and_tier_ladder() -> void:
	var def := HeroDefinition.load_definition(&"kestrel")
	if not _expect(def != null and def.is_valid_definition(), "kestrel.tres loads and validates"):
		return
	_expect(def.display_name == "Dian Prameswari", "Kestrel canonical name is Dian Prameswari")
	_expect(
		HeroTier.is_field_ready(&"kestrel") and HeroTier.is_field_ready(&"sable"),
		"both Sable and Kestrel are field_ready in roster.json",
	)
	_expect(
		(
			roundi(HeroTier.vitals(1, &"kestrel")) == 90
			and roundi(HeroTier.vitals(2, &"kestrel")) == 96
			and roundi(HeroTier.vitals(5, &"kestrel")) == 116
		),
		"Kestrel scout vitals scale 90..116 across T1..T5",
	)
	_expect(
		(
			is_equal_approx(HeroTier.move_speed_multiplier(&"kestrel"), 1.14)
			and is_equal_approx(HeroTier.reload_multiplier(&"kestrel"), 0.90)
			and HeroTier.skill_id(&"kestrel") == &"recon_pulse"
		),
		"Kestrel mobility (+14%), reload (-10%), and recon_pulse skill read from roster.json",
	)

	var save_path := "user://kestrel_smoke_profile.cfg"
	DirAccess.remove_absolute(ProjectSettings.globalize_path(save_path))
	var service := ProgressionService.new()
	service.profile_path = save_path
	root.add_child(service)
	service.completed_runs = 2
	_expect(service.select_hero(&"kestrel"), "ProgressionService selects kestrel")
	_expect(service.select_tier(2), "ProgressionService selects unlocked tier 2 for kestrel")
	_expect(
		roundi(service.tier_vitals()) == 96 and roundi(service.tier_damage_reduction()) == 3,
		"ProgressionService.tier_vitals() reflects Kestrel T2 (96 HP, 3% DR)",
	)
	service.free()

	var reloaded := ProgressionService.new()
	reloaded.profile_path = save_path
	root.add_child(reloaded)
	_expect(
		reloaded.selected_hero_id == &"kestrel" and roundi(reloaded.tier_vitals()) == 96,
		"Kestrel selection and tier vitals persist across profile reload",
	)
	reloaded.free()
	DirAccess.remove_absolute(ProjectSettings.globalize_path(save_path))


func _test_recon_overdrive_combat_and_livery_isolation() -> void:
	var main := MainScene.instantiate()
	var save_path := "user://kestrel_combat_smoke.cfg"
	DirAccess.remove_absolute(ProjectSettings.globalize_path(save_path))
	var prog := main.get_node("ProgressionService") as ProgressionService
	prog.profile_path = save_path
	root.add_child(main)
	await process_frame
	await process_frame

	var player: PlayerController = main.player
	var base_pulse := player.weapon_controller.get_current_definition()
	var authored_reload := base_pulse.reload_seconds

	prog.completed_runs = 10
	prog.select_hero(&"kestrel")
	prog.select_tier(1)
	player.apply_operative_profile(&"kestrel", 1)

	_expect(
		(
			is_equal_approx(player.max_health, 90.0)
			and is_equal_approx(player.move_speed, 6.0 * 1.14)
			and player.active_skill_id() == &"recon_pulse"
			and is_equal_approx(player.emp_pulse_cooldown, 10.5)
			and is_equal_approx(player.emp_pulse_radius, 18.0)
		),
		"PlayerController applies Kestrel T1 stats and 18m Recon Overdrive spec",
	)
	var eff_pulse := player.weapon_controller.get_effective_definition()
	_expect(
		(
			is_equal_approx(eff_pulse.reload_seconds, authored_reload * 0.90)
			and is_equal_approx(base_pulse.reload_seconds, authored_reload)
		),
		"Kestrel -10% reload applies to effective weapon copy without mutating .tres",
	)

	var forward := -player.camera_rig.get_yaw_basis().z
	forward.y = 0.0
	forward = forward.normalized()
	var guardian := GuardianScene.instantiate() as Node3D
	main.add_child(guardian)
	guardian.global_position = player.global_position + forward * 16.0
	await process_frame

	var hp_before := float(guardian.get("current_health"))
	var fired := player.activate_skill()
	_expect(fired, "Kestrel activates Recon Overdrive")
	var disrupted: bool = bool(guardian.call("is_exposed"))
	var hp_after := float(guardian.get("current_health"))
	_expect(
		disrupted and hp_after < hp_before,
		"Recon Overdrive lance disrupts Iron Warden shield and deals damage at 16m range",
	)
	_expect(
		(
			player.is_overdrive_active()
			and is_equal_approx(player.weapon_controller._overdrive_fire_rate_multiplier, 1.22)
		),
		"Recon Overdrive activates +22% fire-rate boost",
	)

	player._physics_process(3.6)
	_expect(
		(
			not player.is_overdrive_active()
			and is_equal_approx(player.weapon_controller._overdrive_fire_rate_multiplier, 1.0)
		),
		"Overdrive expires cleanly after 3.5s duration",
	)

	player.apply_operative_profile(&"kestrel", 5)
	await process_frame
	var visual := player.visual_root
	_expect(
		visual.has_model() and visual._livery_override_count > 0,
		"CharacterVisual applies per-instance surface overrides for Kestrel T5 livery",
	)
	var meshes := visual._model.find_children("*", "MeshInstance3D", true, false)
	if not meshes.is_empty():
		var mi := meshes[0] as MeshInstance3D
		var override_mat := mi.get_surface_override_material(0) as BaseMaterial3D
		var shared_mat := mi.mesh.surface_get_material(0) as BaseMaterial3D
		_expect(
			override_mat != null and override_mat != shared_mat,
			"Tier livery duplicates material per instance and leaves shared GLB material untouched",
		)

	guardian.free()
	main.free()
	DirAccess.remove_absolute(ProjectSettings.globalize_path(save_path))


func _test_hud_results_and_front_end_selection() -> void:
	AegisText.set_locale("en", false)
	var sable_promo := (
		HudMenuUi
		. format_recovery_summary(
			{
				"notices": [],
				"run_banked": true,
				"promoted_tier": 2,
				"hero_id": "sable",
				"has_caches": true,
				"completed_runs": 1,
				"owned_tier": 2,
			}
		)
	)
	var kestrel_promo := (
		HudMenuUi
		. format_recovery_summary(
			{
				"notices": [],
				"run_banked": true,
				"promoted_tier": 2,
				"hero_id": "kestrel",
				"has_caches": true,
				"completed_runs": 1,
				"owned_tier": 2,
			}
		)
	)
	_expect(
		sable_promo.contains("PROMOTED · SABLE TIER 2 READY (106 HP · 3% ARMOR)"),
		"Sable promotion line preserves exact 106 HP · 3% ARMOR copy",
	)
	_expect(
		kestrel_promo.contains("PROMOTED · KESTREL TIER 2 READY (96 HP · 3% ARMOR)"),
		"Kestrel promotion line prints honest 96 HP · 3% ARMOR copy",
	)

	var save_path := "user://kestrel_fe_smoke.cfg"
	DirAccess.remove_absolute(ProjectSettings.globalize_path(save_path))
	var fe := FrontEndScene.instantiate()
	var fe_prog := fe.get_node("ProgressionService") as ProgressionService
	fe_prog.profile_path = save_path
	root.add_child(fe)
	await process_frame
	await process_frame

	fe.go_to(&"HERO", {})
	await process_frame
	var hero_stage := fe.get_node_or_null("StageHost/HERO")
	if _expect(hero_stage != null, "HERO stage mounts in FrontEnd"):
		hero_stage.call("_on_chip_pressed", &"kestrel")
		await process_frame
		hero_stage.call("_on_select_pressed")
		await process_frame
		_expect(
			fe_prog.selected_hero_id == &"kestrel",
			"StageHeroSelect commits kestrel to ProgressionService",
		)
	fe.go_to(&"DASHBOARD", {})
	await process_frame
	var dash := fe.get_node_or_null("StageHost/DASHBOARD")
	if _expect(dash != null, "DASHBOARD stage mounts after selecting Kestrel"):
		var hero_name_lbl := dash.get("_hero_name_label") as Label
		var hero_status_lbl := dash.get("_hero_status") as Label
		_expect(
			(
				hero_name_lbl != null
				and hero_name_lbl.text.to_upper().contains("DIAN PRAMESWARI")
				and hero_status_lbl != null
				and hero_status_lbl.text.contains("90")
			),
			"StageDashboard displays Dian Prameswari and honest 90 HP vitals",
		)

	fe.free()
	DirAccess.remove_absolute(ProjectSettings.globalize_path(save_path))


func _expect(condition: bool, message: String) -> bool:
	if condition:
		return true
	_failures += 1
	printerr("FAIL: %s" % message)
	return false
