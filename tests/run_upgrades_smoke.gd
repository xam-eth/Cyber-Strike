extends SceneTree

## Run-adaptation contract: content registry, exactly-once choice, runtime-only
## modifier composition with permanent tiers, real projectile data, and reset.
const MainScene = preload("res://scenes/main.tscn")
const PROFILE_PATH := "user://run-upgrades-smoke.cfg"

var _failures := 0


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	await _check_service()
	await _check_card_layout()
	await _check_weapon_effects()
	paused = false
	if _failures == 0:
		print("RUN UPGRADES smoke test passed.")
		quit()
	else:
		printerr("RUN UPGRADES smoke test: %d failure(s)" % _failures)
		quit(1)


func _check_service() -> void:
	var definitions := RunUpgradeDefinition.load_all_definitions()
	_expect(definitions.size() == 2, "exactly two bounded adaptations are registered")
	for definition in definitions:
		_expect(
			definition.is_valid_definition(), "%s is a valid definition" % definition.upgrade_id
		)
		for weapon_id in WeaponDefinition.DEFINITION_IDS:
			_expect(
				definition.supports_weapon(weapon_id),
				"%s declares compatibility with %s" % [definition.upgrade_id, weapon_id],
			)

	var service := RunUpgradeService.new()
	root.add_child(service)
	await process_frame
	_expect(
		not service.choose(&"overcharge", &"pulse_rifle"),
		"combat cannot choose before earning an offer"
	)
	_expect(service.offer(), "a real encounter owner can grant the first offer")
	_expect(
		service.offer_available and service.offer_consumed,
		"the pending offer is consumed exactly once"
	)
	_expect(not service.offer(), "a duplicate guard-clear cannot grant a second offer")
	_expect(not service.choose(&"unknown", &"pulse_rifle"), "an unknown card id is refused")
	_expect(not service.choose(&"overcharge", &"unknown"), "an incompatible weapon id is refused")
	_expect(service.offer_available, "refused choices leave the earned offer available")
	_expect(
		service.choose(&"overcharge", &"pulse_rifle"),
		"a supported card and weapon select successfully"
	)
	_expect(
		service.selected_id == &"overcharge", "the selected id is the only run adaptation state"
	)
	_expect(not service.choose(&"quick_cycle", &"pulse_rifle"), "a second selection is refused")
	_expect(
		is_equal_approx(float(service.modifiers()["damage"]), 1.25),
		"Overcharge exposes its real damage multiplier"
	)
	_expect(
		is_equal_approx(float(service.modifiers()["reload"]), 1.0),
		"Overcharge leaves reload unchanged"
	)
	service.reset_run()
	_expect(
		service.selected_id == &"" and not service.offer_consumed,
		"reset clears the selection and offer record"
	)
	_expect(
		service.modifiers() == {"damage": 1.0, "reload": 1.0}, "reset restores neutral modifiers"
	)
	_expect(service.offer(), "a new deployment can earn one new offer")
	service.queue_free()
	await process_frame


func _check_card_layout() -> void:
	var definition := RunUpgradeDefinition.load_all_definitions()[0]
	var card := RunUpgradeCard.new()
	root.add_child(card)
	card.configure(definition, &"pulse_rifle")
	card.size = Vector2(320.0, 150.0)
	await process_frame
	await process_frame
	var content := card.get_node("Content") as VBoxContainer
	var card_rect := card.get_global_rect()
	var content_rect := content.get_global_rect()
	_expect(
		is_equal_approx(content_rect.size.x, 296.0),
		"card content follows the real button width instead of its longest word",
	)
	_expect(
		(
			content_rect.position.x >= card_rect.position.x
			and content_rect.position.y >= card_rect.position.y
			and content_rect.end.x <= card_rect.end.x + 1.0
			and content_rect.end.y <= card_rect.end.y + 1.0
		),
		"card labels stay inside the measured touch target",
	)
	card.queue_free()
	await process_frame


func _check_weapon_effects() -> void:
	_remove_profile()
	# Main deliberately restores permanent ownership/tiers whenever weapon
	# selection changes the profile. Build that permanent fixture through the
	# real service first; injecting WeaponController directly would be erased.
	var profile := ProgressionService.new()
	profile.profile_path = PROFILE_PATH
	root.add_child(profile)
	await process_frame
	profile.balance = 10000
	profile.secure_cache(&"run_upgrade_fixture", &"arc_blueprint", &"arc_shooter")
	profile.unlock_weapon(&"nova_launcher")
	profile.unlock_weapon(&"arc_shooter")
	for weapon_id in WeaponDefinition.DEFINITION_IDS:
		profile.upgrade_weapon(weapon_id)
		profile.upgrade_weapon(weapon_id)
	profile.queue_free()
	await process_frame

	var main := MainScene.instantiate()
	main.set("start_wave_session_on_ready", false)
	main.get_node("ProgressionService").set("profile_path", PROFILE_PATH)
	root.add_child(main)
	await process_frame
	var player := main.get_node("Player") as PlayerController
	player.set_physics_process(false)
	var controller := player.weapon_controller
	for index in range(WeaponDefinition.DEFINITION_IDS.size()):
		var expected_id: StringName = WeaponDefinition.DEFINITION_IDS[index]
		_expect(player.select_weapon(index), "%s is available in the combat fixture" % expected_id)
		var base := controller.get_current_definition()
		_expect(base.weapon_id == expected_id, "%s is genuinely equipped" % expected_id)
		controller.set_run_modifiers(1.25, 1.0)
		var effective := controller.get_effective_definition()
		var permanent_damage := WeaponTier.damage_multiplier(3)
		_expect(
			is_equal_approx(effective.damage, base.damage * permanent_damage * 1.25),
			"%s composes permanent tier and temporary damage" % base.weapon_id,
		)
		_expect(
			is_equal_approx(effective.splash_damage, base.splash_damage * permanent_damage * 1.25),
			"%s applies the same temporary multiplier to splash" % base.weapon_id,
		)
		_expect(
			is_equal_approx(
				effective.reload_seconds, base.reload_seconds * WeaponTier.reload_multiplier(3)
			),
			"%s Overcharge leaves tiered reload unchanged" % base.weapon_id,
		)
		controller.set_run_modifiers(1.0, 0.8)
		effective = controller.get_effective_definition()
		_expect(
			is_equal_approx(
				effective.reload_seconds,
				base.reload_seconds * WeaponTier.reload_multiplier(3) * 0.8,
			),
			"%s Quick Cycle composes with permanent reload" % base.weapon_id,
		)
		_expect(
			base.damage == WeaponDefinition.load_definition(base.weapon_id).damage,
			"%s base damage remains immutable" % base.weapon_id,
		)
		controller.reset_run_modifiers()
		effective = controller.get_effective_definition()
		_expect(
			is_equal_approx(effective.damage, base.damage * permanent_damage),
			"%s reset removes only the temporary modifier" % base.weapon_id,
		)

	# Prove a fired projectile receives the composed runtime definition rather
	# than merely changing an inspector/accessor value.
	player.select_weapon(0)
	controller.reset_ammo()
	controller.set_run_modifiers(1.25, 1.0)
	var muzzle := player.get_node("VisualRoot/WeaponSocket/Muzzle") as Marker3D
	var fired := controller.try_fire(player, muzzle, Vector3(0.34, 1.18, 3.8))
	var round := main.find_child("PulseProjectile", true, false)
	_expect(fired and round != null, "an adapted Pulse fires a real projectile")
	if round != null:
		_expect(
			is_equal_approx(
				float(round.get("_damage")), controller.get_effective_definition().damage
			),
			"the real Pulse projectile carries permanent + temporary damage",
		)
	player.reset_player()
	_expect(
		controller.get_run_modifiers() == {"damage": 1.0, "reload": 1.0},
		"player run reset explicitly clears temporary modifiers",
	)
	_expect(
		is_equal_approx(
			controller.get_effective_definition().damage,
			controller.get_current_definition().damage * WeaponTier.damage_multiplier(3),
		),
		"player run reset preserves the permanent weapon tier",
	)
	main.queue_free()
	await process_frame
	_remove_profile()


func _remove_profile() -> void:
	if FileAccess.file_exists(PROFILE_PATH):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(PROFILE_PATH))


func _expect(condition: bool, message: String) -> void:
	if condition:
		print("  PASS: " + message)
	else:
		_failures += 1
		push_error("RUN UPGRADES smoke test failed: " + message)
