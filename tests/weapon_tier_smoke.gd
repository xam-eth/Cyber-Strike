extends SceneTree

const MainScene = preload("res://scenes/main.tscn")
const PROFILE_PATH := "user://weapon_tier_smoke.cfg"

var _failures := 0


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var disk := ProjectSettings.globalize_path(PROFILE_PATH)
	if FileAccess.file_exists(PROFILE_PATH):
		DirAccess.remove_absolute(disk)
	_expect(WeaponTier.has_table() and WeaponTier.tier_count() == 3, "shared table has three tiers")
	for id in WeaponDefinition.DEFINITION_IDS:
		_expect(WeaponTier.cost(id, 1) == 0, "%s tier 1 is the free baseline" % id)
		_expect(
			WeaponTier.cost(id, 2) > 0 and WeaponTier.cost(id, 3) > 0, "%s has real BP costs" % id
		)
	_expect(WeaponTier.damage_multiplier(3) <= 1.16, "damage growth is capped at +16 percent")
	_expect(WeaponTier.reload_multiplier(3) >= 0.92, "reload reduction is capped at 8 percent")

	# A legacy ConfigFile has no weapon_tiers field at all.
	var legacy := ConfigFile.new()
	legacy.set_value("profile", "balance", 37)
	legacy.set_value("profile", "unlocked_ids", ["pulse_rifle"])
	legacy.set_value("profile", "selected_weapon", "pulse_rifle")
	legacy.save(PROFILE_PATH)
	var profile := ProgressionService.new()
	profile.profile_path = PROFILE_PATH
	root.add_child(profile)
	await process_frame
	_expect(profile.balance == 37, "legacy BP survives migration")
	for id in WeaponDefinition.DEFINITION_IDS:
		_expect(profile.weapon_tier(id) == 1, "%s legacy save falls back to tier 1" % id)
	_expect(not profile.upgrade_weapon(&"unknown"), "unknown weapon cannot be upgraded")
	_expect(not profile.upgrade_weapon(&"nova_launcher"), "locked weapon cannot be upgraded")

	var second_cost := profile.weapon_upgrade_cost(&"pulse_rifle")
	profile.balance = second_cost - 1
	_expect(not profile.upgrade_weapon(&"pulse_rifle"), "unaffordable tier cannot overdraft")
	profile.balance = second_cost
	_expect(profile.upgrade_weapon(&"pulse_rifle"), "tier 2 purchase succeeds at exact cost")
	_expect(profile.balance == 0 and profile.weapon_tier(&"pulse_rifle") == 2, "tier 2 spends once")
	var third_cost := profile.weapon_upgrade_cost(&"pulse_rifle")
	profile.balance = third_cost
	_expect(profile.upgrade_weapon(&"pulse_rifle"), "tier 3 purchase succeeds")
	var maxed_balance := profile.balance
	_expect(not profile.upgrade_weapon(&"pulse_rifle"), "max tier is a no-op")
	_expect(profile.balance == maxed_balance, "max tier does not spend BP")
	profile.queue_free()
	await process_frame

	var saved := ProgressionService.new()
	saved.profile_path = PROFILE_PATH
	root.add_child(saved)
	await process_frame
	_expect(saved.weapon_tier(&"pulse_rifle") == 3, "purchased tier reloads from disk")
	saved.balance = 5000
	saved.secure_cache(&"tier_fixture", &"arc_blueprint", &"arc_shooter")
	saved.unlock_weapon(&"nova_launcher")
	saved.unlock_weapon(&"arc_shooter")
	for id in [&"nova_launcher", &"arc_shooter"]:
		_expect(saved.upgrade_weapon(id), "%s reaches tier 2 through BP" % id)
		_expect(saved.upgrade_weapon(id), "%s reaches tier 3 through BP" % id)
	saved.queue_free()
	await process_frame

	var main := MainScene.instantiate()
	main.set("start_wave_session_on_ready", false)
	main.get_node("ProgressionService").set("profile_path", PROFILE_PATH)
	root.add_child(main)
	await process_frame
	var player := main.get_node("Player") as PlayerController
	var controller := player.weapon_controller
	for index in range(WeaponDefinition.DEFINITION_IDS.size()):
		player.select_weapon(index)
		var base := controller.get_current_definition()
		var effective := controller.get_effective_definition()
		var id: StringName = base.weapon_id
		_expect(effective != base, "%s tier 3 uses a runtime copy" % id)
		_expect(
			is_equal_approx(effective.damage, base.damage * WeaponTier.damage_multiplier(3)),
			"%s projectile data receives bounded direct damage" % id
		)
		_expect(
			is_equal_approx(
				effective.splash_damage, base.splash_damage * WeaponTier.damage_multiplier(3)
			),
			"%s splash uses the same bounded multiplier" % id
		)
		_expect(effective.chain_count == base.chain_count, "%s chain count is unchanged" % id)
		_expect(
			is_equal_approx(
				effective.reload_seconds, base.reload_seconds * WeaponTier.reload_multiplier(3)
			),
			"%s effective reload follows tier" % id
		)
		controller.get("_magazines")[index] = 0
		_expect(controller.request_reload(), "%s can start a tiered reload" % id)
		_expect(
			is_equal_approx(controller.current_reload_remaining(), effective.reload_seconds),
			"%s active reload timer uses effective seconds" % id
		)
		_expect(
			base.damage == WeaponDefinition.load_definition(id).damage,
			"%s base damage is immutable" % id
		)
		_expect(
			base.reload_seconds == WeaponDefinition.load_definition(id).reload_seconds,
			"%s base reload is immutable" % id
		)

	# Prove the shot receives the runtime copy, not merely that an accessor changed.
	player.select_weapon(0)
	controller.reset_ammo()
	var muzzle := player.get_node("VisualRoot/WeaponSocket/Muzzle") as Marker3D
	var fired := controller.try_fire(player, muzzle, Vector3(0.34, 1.18, 3.8))
	var round := main.find_child("PulseProjectile", true, false)
	_expect(fired and round != null, "tiered Pulse fires a real projectile")
	if round != null:
		_expect(
			is_equal_approx(
				float(round.get("_damage")), controller.get_effective_definition().damage
			),
			"real Pulse projectile carries tiered damage"
		)

	main.queue_free()
	await process_frame
	if FileAccess.file_exists(PROFILE_PATH):
		DirAccess.remove_absolute(disk)
	if _failures > 0:
		printerr("Weapon tier smoke: %d failure(s)" % _failures)
		quit(1)
	else:
		print("Weapon tier smoke: PASS")
		quit()


func _expect(condition: bool, label: String) -> void:
	if condition:
		print("  PASS: ", label)
	else:
		_failures += 1
		printerr("  FAIL: ", label)
