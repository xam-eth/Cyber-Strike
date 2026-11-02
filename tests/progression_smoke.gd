extends SceneTree

const MainScene = preload("res://scenes/main.tscn")
const TEST_PATH := "user://progression-smoke.cfg"

var _failures: int = 0


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var disk_path := ProjectSettings.globalize_path(TEST_PATH)
	if FileAccess.file_exists(TEST_PATH):
		DirAccess.remove_absolute(disk_path)
	var profile := ProgressionService.new()
	profile.profile_path = TEST_PATH
	root.add_child(profile)
	_expect(profile.balance == 0 and profile.is_unlocked(&"pulse_rifle"), "new wallet owns Pulse")
	_expect(not profile.is_unlocked(&"nova_launcher"), "Nova starts locked")
	profile.bank_run(120, 130)
	_expect(profile.balance == 130 and profile.best_score == 120, "a finished wave banks BP")
	_expect(profile.unlock_weapon(&"nova_launcher"), "Nova costs 120 earned BP")
	_expect(profile.balance == 10, "valid purchase deducts points exactly once")
	_expect(not profile.unlock_weapon(&"nova_launcher"), "duplicate purchase cannot spend twice")
	_expect(not profile.unlock_weapon(&"arc_shooter"), "unaffordable purchase cannot overdraft")
	profile.bank_run(80, 300)
	_expect(
		profile.best_score == 120 and profile.balance == 310, "best score stays separate from BP"
	)
	_expect(not profile.unlock_weapon(&"arc_shooter"), "Arc also requires its recovered blueprint")
	_expect(
		profile.secure_cache(&"verdant_seed_vault", &"arc_shooter_blueprint", &"arc_shooter"),
		"Seed Vault persists Arc blueprint eligibility",
	)
	_expect(
		not profile.secure_cache(&"verdant_seed_vault", &"arc_shooter_blueprint", &"arc_shooter"),
		"duplicate cache secure is a no-op",
	)
	_expect(profile.unlock_weapon(&"arc_shooter") and profile.balance == 60, "Arc costs 250 BP")
	profile.queue_free()
	await process_frame

	var main := MainScene.instantiate()
	main.get_node("ProgressionService").set("profile_path", TEST_PATH)
	root.add_child(main)
	await process_frame
	var wallet := main.get_node("ProgressionService") as ProgressionService
	var player := main.get_node("Player") as PlayerController
	var hud := main.get_node("HUD/TouchControls") as TouchControls
	var armory := hud.get("_armory_panel") as ArmoryUi
	var open_button := hud.get("_armory_button") as Button
	_expect(
		(
			wallet.balance == 60
			and wallet.is_unlocked(&"arc_shooter")
			and wallet.is_cache_secured(&"verdant_seed_vault")
			and wallet.has_blueprint(&"arc_shooter")
			and open_button.text.contains("60 BP")
		),
		"restarting the game reloads BP and purchased weapons into the live HUD",
	)
	open_button.pressed.emit()
	_expect(paused and armory.visible, "ARMORY suspends live gameplay and opens")
	var arc_button := armory.find_child("ArcWeaponButton", true, false) as Button
	_expect(is_instance_valid(arc_button) and arc_button.text.contains("EQUIP"), "Arc offers EQUIP")
	arc_button.pressed.emit()
	_expect(
		(
			player.get_current_weapon_name() == "Arc Shooter"
			and (hud.get("_weapon_button") as Button).text.is_empty()
			and (hud.get("_touch_ammo_chip").get("weapon_label") as Label).text == "ARC"
		),
		"armory equips Arc; the shooter and SWAP HUD use the same selection",
	)
	var close_button := armory.find_child("CloseArmoryButton", true, false) as Button
	close_button.pressed.emit()
	_expect(not paused and not armory.visible, "close returns to playable safe Explore")
	_expect(not wallet.unlock_weapon(&"unknown"), "unknown weapon ID cannot be purchased")

	# --- operative roster (hero tiers removed, weapon tiers preserved) -------
	_expect(HeroTier.has_roster(), "resources/heroes/roster.json parses")
	_expect(
		(
			HeroTier.is_field_ready(&"sable")
			and HeroTier.is_field_ready(&"kestrel")
			and not HeroTier.is_field_ready(&"vanguard")
		),
		"field-ready operatives require a real rig; in-development slots remain blocked",
	)
	_expect(
		roundi(HeroTier.vitals(&"sable")) == 110 and roundi(HeroTier.reduction(&"sable")) == 6,
		"Sable vitals (110 HP) and armor reduction (6%) come directly from roster.json",
	)
	_expect(
		roundi(HeroTier.vitals(&"kestrel")) == 96 and roundi(HeroTier.reduction(&"kestrel")) == 4,
		"Kestrel scout vitals (96 HP) and armor reduction (4%) come directly from roster.json",
	)
	_expect(
		HeroTier.model_path(&"sable").ends_with("hero_human_tier_1.glb"),
		"each field-ready operative resolves its canonical GLB rig",
	)
	wallet.select_hero(&"sable")
	_expect(player.call("_progression_service") != null, "the player can find the profile")
	player.call("_apply_progression_tier")
	_expect(
		is_equal_approx(player.max_health, HeroTier.vitals(&"sable")),
		"the arena's health pool matches the selected operative's vitals",
	)
	_expect(
		is_equal_approx(player.tier_damage_reduction(), HeroTier.reduction(&"sable") / 100.0),
		"the selected operative's armor plate is applied to incoming damage",
	)
	player.current_health = 110.0
	player.apply_damage(100.0)
	_expect(
		is_equal_approx(
			player.current_health, 110.0 - 100.0 * (1.0 - player.tier_damage_reduction())
		),
		"a hit is reduced by the operative's plate, not by nothing",
	)
	wallet.selected_hero_id = &"sable"
	_expect(HeroTier.model_path(wallet.selected_hero_id) != "", "the fielded hero has a rig")

	main.queue_free()
	await process_frame
	DirAccess.remove_absolute(disk_path)
	if _failures > 0:
		printerr("Progression smoke: %d failure(s)" % _failures)
		quit(1)
	else:
		print("Progression smoke: PASS")
		quit()


func _expect(condition: bool, label: String) -> void:
	if condition:
		print("  PASS: ", label)
	else:
		printerr("  FAIL: ", label)
		_failures += 1
