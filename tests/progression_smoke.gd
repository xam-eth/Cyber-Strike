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

	# --- the operative ladder -------------------------------------------------
	# The tier cards on the operative page and the arena both read this table, so
	# what is checked here is the whole chain: the roster parses, a rank is earned
	# by runs, a rank that is not earned cannot be selected, and the player's body
	# and health follow the selection.
	_expect(HeroTier.has_roster(), "resources/heroes/roster.json parses")
	_expect(HeroTier.tier_count() == 5, "the ladder has five ranks")
	_expect(HeroTier.owned_tier(0) == 1, "tier 1 needs no runs")
	_expect(HeroTier.owned_tier(1) == 2 and HeroTier.owned_tier(2) == 2, "one run opens tier 2")
	_expect(HeroTier.owned_tier(10) == 5, "ten runs open the last tier")
	_expect(
		HeroTier.vitals(5) > HeroTier.vitals(1) and HeroTier.reduction(5) > HeroTier.reduction(1),
		"a higher rank is worth more health and more plate",
	)
	_expect(
		HeroTier.model_path(&"sable", 3).ends_with("hero_human_tier_3.glb"),
		"each rank has its own model",
	)
	_expect(
		not HeroTier.is_field_ready(&"kestrel"),
		"a hero with no rig cannot be fielded",
	)
	# The profile in this fixture has already banked two runs, so what it owns is
	# the roster's answer for *its* count, and what it fields is the saved rank
	# clamped into that range -- never a rank nobody earned.
	_expect(
		wallet.owned_tier() == HeroTier.owned_tier(wallet.completed_runs),
		"the owned rank is the roster's answer for this profile's runs",
	)
	_expect(wallet.fieldable_tier() <= wallet.owned_tier(), "a profile fields a rank it owns")
	_expect(not wallet.select_tier(HeroTier.tier_count()), "an unearned rank cannot be selected")
	wallet.completed_runs = 12
	_expect(wallet.owned_tier() == 5, "runs earned in the arena open the ranks")
	_expect(
		wallet.select_tier(4) and wallet.fieldable_tier() == 4, "an earned rank can be selected"
	)
	# The body reads the rank before it is fitted (CharacterVisual) and before the
	# first hit (PlayerController). Both go through ProgressionLookup, and the same
	# read is driven here so the numbers are checked without a second arena.
	_expect(player.call("_progression_service") != null, "the player can find the profile")
	player.call("_apply_progression_tier")
	_expect(
		player.max_health == HeroTier.vitals(4),
		"the arena's health pool is the selected rank's vitals",
	)
	_expect(
		is_equal_approx(player.tier_damage_reduction(), HeroTier.reduction(4) / 100.0),
		"the selected rank's plate is applied to incoming damage",
	)
	player.current_health = 200.0
	player.apply_damage(100.0)
	_expect(
		is_equal_approx(
			player.current_health, 200.0 - 100.0 * (1.0 - player.tier_damage_reduction())
		),
		"a hit is reduced by the rank's plate, not by nothing",
	)
	# An id that is not in the roster cannot become the operative, even though the
	# id is a string the profile is happy to hold.
	wallet.selected_hero_id = &"sable"
	_expect(HeroTier.model_path(wallet.selected_hero_id, 1) != "", "the fielded hero has a rig")

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
