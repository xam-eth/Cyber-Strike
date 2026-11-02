extends SceneTree

## Second playable operative Kestrel (Dian Prameswari, Scout) shares the single
## tier-free `roster.json` + `HeroDefinition` registry, applies real scout stats
## (96 HP, 4% armor DR, +14% stride speed, -10% reload), fires an aimed 18m
## Recon Overdrive lance that disrupts Iron Warden shields at range and grants
## 3.5s Overdrive (+20% speed, +22% fire rate), applies per-instance livery
## without mutating global materials, and updates HUD/FrontEnd/Results cleanly.
const MainScene = preload("res://scenes/main.tscn")
const FrontEndScene = preload("res://scenes/ui/front_end.tscn")
const GuardianScene = preload("res://scenes/enemies/guardian.tscn")

var _failures := 0


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	_test_kestrel_registry_and_profile()
	await _test_recon_overdrive_combat_and_livery_isolation()
	await _test_hud_results_and_front_end_selection()
	if _failures == 0:
		print("Kestrel operative smoke test passed.")
		quit()
	else:
		quit(1)


func _test_kestrel_registry_and_profile() -> void:
	var def := HeroDefinition.load_definition(&"kestrel")
	if not _expect(def != null and def.is_valid_definition(), "kestrel.tres loads and validates"):
		return
	_expect(def.display_name == "Dian Prameswari", "Kestrel canonical name is Dian Prameswari")
	_expect(
		HeroTier.is_field_ready(&"kestrel") and HeroTier.is_field_ready(&"sable"),
		"both Sable and Kestrel are field_ready in roster.json",
	)
	_expect(
		roundi(HeroTier.vitals(&"kestrel")) == 96 and roundi(HeroTier.reduction(&"kestrel")) == 4,
		"Kestrel scout vitals (96 HP) and armor reduction (4%) read from roster.json",
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
	_expect(service.select_hero(&"kestrel"), "ProgressionService selects kestrel")
	_expect(
		roundi(service.hero_vitals()) == 96 and roundi(service.hero_damage_reduction()) == 4,
		"ProgressionService.hero_vitals() reflects Kestrel (96 HP, 4% DR)",
	)
	service.free()

	var reloaded := ProgressionService.new()
	reloaded.profile_path = save_path
	root.add_child(reloaded)
	_expect(
		reloaded.selected_hero_id == &"kestrel" and roundi(reloaded.hero_vitals()) == 96,
		"Kestrel selection and vitals persist across profile reload",
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

	prog.select_hero(&"kestrel")
	player.apply_operative_profile(&"kestrel")

	_expect(
		(
			is_equal_approx(player.max_health, 96.0)
			and is_equal_approx(player.move_speed, 6.0 * 1.14)
			and player.active_skill_id() == &"recon_pulse"
			and is_equal_approx(player.emp_pulse_cooldown, 10.5)
			and is_equal_approx(player.emp_pulse_radius, 18.0)
		),
		"PlayerController applies Kestrel stats (96 HP) and 18m Recon Overdrive spec",
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

	await process_frame
	var visual := player.visual_root
	_expect(
		visual.has_model() and visual._livery_override_count > 0,
		"CharacterVisual applies per-instance surface overrides for Kestrel livery",
	)
	var meshes := visual._model.find_children("*", "MeshInstance3D", true, false)
	if not meshes.is_empty():
		var mi := meshes[0] as MeshInstance3D
		var override_mat := mi.get_surface_override_material(0) as BaseMaterial3D
		var shared_mat := mi.mesh.surface_get_material(0) as BaseMaterial3D
		_expect(
			override_mat != null and override_mat != shared_mat,
			"Operative livery duplicates material per instance and leaves shared GLB untouched",
		)

	guardian.free()
	main.free()
	DirAccess.remove_absolute(ProjectSettings.globalize_path(save_path))


func _test_hud_results_and_front_end_selection() -> void:
	AegisText.set_locale("en", false)
	var sable_summary := (
		HudMenuUi
		. format_recovery_summary(
			{
				"notices": [],
				"run_banked": true,
				"hero_id": "sable",
				"has_caches": true,
				"completed_runs": 1,
			}
		)
	)
	var kestrel_summary := (
		HudMenuUi
		. format_recovery_summary(
			{
				"notices": [],
				"run_banked": true,
				"hero_id": "kestrel",
				"has_caches": true,
				"completed_runs": 2,
			}
		)
	)
	_expect(
		sable_summary.contains("SABLE") and not sable_summary.contains("TIER"),
		"Sable summary logs expedition count with zero hero tier wording",
	)
	_expect(
		kestrel_summary.contains("KESTREL") and not kestrel_summary.contains("TIER"),
		"Kestrel summary logs expedition count with zero hero tier wording",
	)

	var save_path := "user://kestrel_fe_smoke.cfg"
	DirAccess.remove_absolute(ProjectSettings.globalize_path(save_path))
	var fe := FrontEndScene.instantiate()
	var fe_prog := fe.get_node("ProgressionService") as ProgressionService
	fe_prog.profile_path = save_path
	root.add_child(fe)
	await process_frame
	await process_frame
	fe.call("go_to", &"HERO", {})
	await process_frame
	await process_frame

	var hero_stage := fe.get("_current") as Control
	_expect(
		hero_stage.find_child("TierCycleButton", true, false) == null,
		"HERO stage carries no TierCycleButton after Hero Tier removal",
	)
	hero_stage.call("_on_card_pressed", &"kestrel")
	await process_frame
	var select_btn := hero_stage.get("_select_button") as BaseButton
	select_btn.pressed.emit()
	await process_frame
	var vitals_lbl := hero_stage.get("_tier_label") as Label
	_expect(
		(
			fe_prog.selected_hero_id == &"kestrel"
			and vitals_lbl != null
			and vitals_lbl.text.contains("HP 96")
			and vitals_lbl.text.contains("RECON 18M")
			and not vitals_lbl.text.contains("TIER")
		),
		"HERO stage selects Kestrel and displays tier-free HP 96 · RECON 18M stats",
	)

	fe.free()
	DirAccess.remove_absolute(ProjectSettings.globalize_path(save_path))


func _expect(condition: bool, message: String) -> bool:
	if not condition:
		_failures += 1
		push_error("Kestrel smoke test failed: " + message)
	return condition
