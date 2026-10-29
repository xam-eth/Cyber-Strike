extends SceneTree

const MainScene = preload("res://scenes/main.tscn")
const DashboardScript = preload("res://scripts/ui/menus/stage_dashboard.gd")
const PROFILE_PATH := "user://run_upgrade_smoke_profile.cfg"

var _failures: Array[String] = []


func _initialize() -> void:
	DisplayServer.window_set_size(Vector2i(1280, 720))
	await process_frame
	_remove_profile()
	_test_catalog_and_manager()
	await _test_dashboard_armory_upgrade_wiring()
	await _test_main_vertical_slice_and_layouts()
	_remove_profile()

	if _failures.is_empty():
		print("PASS: run_upgrade_smoke")
		quit(0)
		return

	for failure in _failures:
		push_error(failure)
	print("FAIL: run_upgrade_smoke (%d failure(s))" % _failures.size())
	quit(1)


func _test_catalog_and_manager() -> void:
	var defs := RunUpgradeDefinition.load_all_definitions()
	_check(defs.size() == 6, "expected 6 temporary run upgrades, got %d" % defs.size())
	for locale in AegisTextCatalog.LOCALES:
		AegisText.set_locale(locale)
		for def in defs:
			_check(def.is_valid_definition(), "invalid RunUpgradeDefinition: %s" % def.upgrade_id)
			_check(not def.display_title().is_empty(), "empty title in %s" % locale)
			_check(not def.display_summary().is_empty(), "empty summary in %s" % locale)
			_check(not def.display_category().is_empty(), "empty category in %s" % locale)
	AegisText.set_locale("en")

	var mgr := RunUpgradeManager.new()
	mgr.set_seed(42)
	root.add_child(mgr)
	_check(not mgr.has_pending_choice(), "fresh manager must not have pending choice")
	_check(mgr.charge_required() == 2, "first evolution must require 2 KOs")

	var dummy_a := Node3D.new()
	var dummy_b := Node3D.new()
	root.add_child(dummy_a)
	root.add_child(dummy_b)

	_check(not mgr.record_elimination(dummy_a), "1st KO should charge 1/2, not trigger")
	_check(not mgr.record_elimination(dummy_a), "duplicate KO on same instance must be ignored")
	_check(mgr.current_charge() == 1, "charge must remain 1 after duplicate KO")
	_check(mgr.record_elimination(dummy_b), "2nd distinct KO must trigger evolution")
	_check(mgr.has_pending_choice(), "pending choice must be active after 2nd KO")

	var offered := mgr.get_pending_choices()
	_check(offered.size() == 3, "expected 3 distinct upgrade choices, got %d" % offered.size())
	_check(
		(
			offered[0].upgrade_id != offered[1].upgrade_id
			and offered[1].upgrade_id != offered[2].upgrade_id
			and offered[0].upgrade_id != offered[2].upgrade_id
		),
		"offered run upgrade cards must not duplicate within one draft"
	)

	var picked := mgr.select_choice(0)
	_check(picked != null, "selecting card 0 must return chosen RunUpgradeDefinition")
	_check(not mgr.has_pending_choice(), "pending choice must clear after selection")
	_check(mgr.stack_count(picked.upgrade_id) == 1, "selected upgrade stack must become 1")
	_check(not mgr.active_tags_summary().is_empty(), "active_tags_summary must list chosen mod")
	_check(mgr.charge_required() == 3, "next evolution threshold must step to 3 KOs")

	mgr.reset_run()
	_check(mgr.total_stacks() == 0, "reset_run must wipe all temporary stacks")
	_check(mgr.active_tags_summary().is_empty(), "reset_run must clear active tags")
	_check(mgr.charge_required() == 2, "reset_run must restore initial threshold")

	dummy_a.queue_free()
	dummy_b.queue_free()
	mgr.queue_free()


func _test_dashboard_armory_upgrade_wiring() -> void:
	var svc := ProgressionService.new()
	svc.profile_path = PROFILE_PATH
	root.add_child(svc)
	await process_frame
	svc.bank(300, 300)
	_check(svc.weapon_tier(&"pulse_rifle") == 1, "fresh profile must start pulse_rifle at tier 1")

	var stage := DashboardScript.new()
	stage._services = {"progression": svc}
	stage.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.add_child(stage)
	await process_frame
	stage.enter({})
	await process_frame

	stage._on_armory_pressed()
	var armory := stage.get_node_or_null("ArmoryPanel") as ArmoryUi
	_check(armory != null and armory.visible, "Dashboard armory must open")
	armory.weapon_upgrade_requested.emit(&"pulse_rifle")
	_check(
		svc.weapon_tier(&"pulse_rifle") == 2,
		"Dashboard armory upgrade button must upgrade pulse_rifle to tier 2"
	)

	var arc_action := armory.find_child("ArcWeaponButton", true, false) as Button
	_check(
		arc_action != null and arc_action.text == AegisText.t("armory.blueprint_locked"),
		"Arc Shooter button must report BLUEPRINT LOCKED when Seed Vault blueprint is missing"
	)

	stage.queue_free()
	svc.queue_free()
	await process_frame


func _test_main_vertical_slice_and_layouts() -> void:
	_remove_profile()
	var main := MainScene.instantiate()
	var progression: ProgressionService = main.get_node("ProgressionService")
	progression.profile_path = PROFILE_PATH
	root.add_child(main)
	await process_frame
	await process_frame

	var hud := main.get_node("HUD/TouchControls")
	var player := main.get_node("Player")
	var wc: WeaponController = player.weapon_controller
	var upg_mgr: RunUpgradeManager = main.get_node("RunUpgradeManager")

	var base_def: WeaponDefinition = wc.get_current_definition()
	var base_damage: float = base_def.damage
	var base_mag: int = base_def.magazine_size

	# Verify PauseHomeButton in Explore emits home_requested immediately (no modal block).
	var home_signals: Array[int] = [0]
	hud.home_requested.connect(func() -> void: home_signals[0] += 1)
	var pause_home := hud.find_child("PauseHomeButton", true, false) as Button
	_check(pause_home != null, "PauseHomeButton must exist")
	pause_home.pressed.emit()
	_check(
		home_signals[0] == 1, "PauseHomeButton in safe Explore must emit home_requested immediately"
	)

	# Start Defense and skip preparation countdown.
	main._request_defense()
	main._preparation_remaining = 0.01
	await _advance(0.12)
	var wave_director := main.get_node("WaveDirector")
	_check(wave_director.current_wave == 1, "Wave 1 must start")

	# Defeat 2 enemies to earn real BP and trigger Evolution Lv 1.
	var wave_enemies := main.get_node("WaveEnemies")
	await _advance_until(func() -> bool: return wave_enemies.get_child_count() >= 2, 3.0)
	var killed := 0
	for child in wave_enemies.get_children():
		if killed >= 2:
			break
		if child.has_method("apply_damage"):
			child.apply_damage(999.0)
			killed += 1
	await _advance(0.15)

	_check(upg_mgr.has_pending_choice(), "2 real enemy KOs must ready a Run Evolution")
	var ready_btn := hud.find_child("UpgradeReadyButton", true, false) as Button
	_check(
		ready_btn != null and ready_btn.visible,
		"UpgradeReadyButton must appear in top-right HUD when evolution is ready"
	)

	# Verify HUD & modal geometry across 1280x720, 844x390, and 667x375.
	for vp in [Vector2i(1280, 720), Vector2i(844, 390), Vector2i(667, 375)]:
		DisplayServer.window_set_size(vp)
		await process_frame
		await process_frame
		var btn_rect := ready_btn.get_global_rect()
		_check(
			btn_rect.size.x >= 120.0 and btn_rect.size.y >= 44.0,
			"UpgradeReadyButton touch size too small at %s: %s" % [vp, btn_rect]
		)
		_check(
			btn_rect.position.x >= 0.0 and btn_rect.end.x <= float(vp.x) + 1.0,
			"UpgradeReadyButton out of horizontal bounds at %s: %s" % [vp, btn_rect]
		)

	# Open Run Upgrade modal and verify 3 cards fit inside 667x375 viewport.
	ready_btn.pressed.emit()
	await process_frame
	var upg_panel := hud.find_child("RunUpgradePanel", true, false) as Control
	_check(
		upg_panel != null and upg_panel.visible and paused,
		"tapping UpgradeReadyButton must pause combat and show RunUpgradePanel"
	)
	var panel_rect := upg_panel.get_global_rect()
	_check(
		(
			panel_rect.position.x >= 0.0
			and panel_rect.position.y >= 0.0
			and panel_rect.end.x <= 668.0
			and panel_rect.end.y <= 376.0
		),
		"RunUpgradePanel must fit inside 667x375 viewport, got %s" % panel_rect
	)

	# Force deterministic Overcharge + Plating test via manager + apply_run_modifiers.
	main._on_run_upgrade_chosen(0)
	await process_frame
	_check(
		not upg_panel.visible and not paused,
		"choosing a Run Upgrade card must resume gameplay and close modal"
	)
	_check(upg_mgr.total_stacks() == 1, "one temporary run upgrade stack must be active")

	# Verify PauseHomeButton during active Defense with earned BP opens AegisConfirmDialog!
	main._toggle_pause()
	await process_frame
	var before_home := home_signals[0]
	pause_home.pressed.emit()
	await process_frame
	var confirm_dialog := hud.find_child("ConfirmLeaveDialog", true, false) as Control
	_check(
		confirm_dialog != null and confirm_dialog.visible and home_signals[0] == before_home,
		"PauseHomeButton during active Defense with unbanked BP must show ConfirmLeaveDialog"
	)
	var stay_btn := confirm_dialog.find_child("ConfirmCancelButton", true, false) as Button
	stay_btn.pressed.emit()
	await process_frame
	_check(not confirm_dialog.visible, "ConfirmCancelButton must dismiss ConfirmLeaveDialog")
	main._toggle_pause()
	await process_frame

	# Verify base WeaponDefinition resource was NEVER mutated.
	_check(
		is_equal_approx(base_def.damage, base_damage) and base_def.magazine_size == base_mag,
		"temporary run modifiers must never mutate shared WeaponDefinition .tres resources"
	)

	# Finish run -> bank permanent BP -> return to explore -> verify temporary mods reset!
	var earned_bp: int = main.get_node("RewardService").run_battle_points
	_check(earned_bp >= 20, "expected >= 20 BP earned from 2 KOs, got %d" % earned_bp)
	main._finish_run()
	await process_frame
	_check(
		progression.balance == earned_bp,
		"finishing run must bank permanent BP once (%d != %d)" % [progression.balance, earned_bp]
	)
	main._return_to_explore()
	await process_frame
	_check(
		upg_mgr.total_stacks() == 0, "returning to Explore must reset all temporary run upgrades"
	)
	_check(
		progression.balance == earned_bp,
		"permanent wallet BP must remain intact after temporary run upgrades reset"
	)
	_check(
		is_equal_approx(wc.get_effective_definition().damage, base_damage),
		"effective weapon damage must return to base/permanent tier after run reset"
	)

	DisplayServer.window_set_size(Vector2i(1280, 720))
	main.queue_free()
	await process_frame


func _advance(seconds: float) -> void:
	var steps := maxi(int(ceil(seconds / (1.0 / 60.0))), 1)
	for _i in range(steps):
		await physics_frame
		await process_frame


func _advance_until(predicate: Callable, timeout_seconds: float) -> void:
	var steps := maxi(int(ceil(timeout_seconds / (1.0 / 60.0))), 1)
	for _i in range(steps):
		if predicate.call():
			return
		await physics_frame
		await process_frame


func _remove_profile() -> void:
	var absolute := ProjectSettings.globalize_path(PROFILE_PATH)
	if FileAccess.file_exists(absolute):
		DirAccess.remove_absolute(absolute)


func _check(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
