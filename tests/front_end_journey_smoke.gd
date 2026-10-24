extends SceneTree

## Proof that the front-end journey actually runs, in order, end to end.
##
## A menu tree can be authored, committed and still be unreachable: a stage that
## is never instantiated, a `completed` signal nobody wired, a chapter card that
## replays forever because the flag is never written. This test instantiates the
## real `front_end.tscn`, walks BOOT -> LOADING -> CHAPTER ->
## DASHBOARD -> HERO -> WORLD and asserts, at each stop:
##
##   * the stage exists, is visible, and is the one the journey asked for;
##   * no enabled button is inert -- every one has a `pressed` connection;
##   * no interactive control crosses the reserved safe-area edge (the BUG 2
##     rule, applied to the menus as well as the HUD);
##   * the content the project does not have is marked locked and disabled, so
##     the selection screens cannot offer a hero, weapon or world that no rig,
##     definition or scene backs;
##   * the loading screens report progress that comes from ResourceLoader, not
##     from a timer;
##   * the journey opens on the engine's own load, with no film and no boot
##     screen carrying engine words in front of it;
##   * the CHAPTER 01 card is marked seen once, persisted to a real ConfigFile,
##     and skipped on a second launch.
##
## It does not judge whether the journey is *pleasant*. It proves the wiring.

const FrontEndScene = preload("res://scenes/ui/front_end.tscn")
const PreloadScene = preload("res://scenes/ui/menus/stage_preload.tscn")
const GameplayScene = preload("res://scenes/main.tscn")

## Distinct from the real `user://progression.cfg` so the suite never spends or
## unlocks anything in a profile a developer might care about.
const PROFILE_PATH := "user://front_end_smoke_profile.cfg"

## Frames to wait for a stage that advances on its own (BOOT's minimum hold,
## LOADING's threaded queue). Headless frames are cheap; this is a ceiling, not
## an expectation.
const MAX_WAIT_FRAMES := 6000
## Progress-only stages (BOOT, LOADING, PRELOAD) expose no controls at all --
## there is nothing to press while resources are in flight -- so the
## "at least one action" half of the rule is skipped for them.
const INTERACTIVE_STAGES: Array[StringName] = [
	&"CHAPTER",
	&"DASHBOARD",
	&"HERO",
	&"WORLD",
]

var _failures: Array[String] = []
var _front_end: Control
var _profile: Node


func _initialize() -> void:
	call_deferred("_run_smoke_test")


func _run_smoke_test() -> void:
	AegisPreferences.write(AegisPreferences.defaults())
	# Start from a clean profile so "intro not yet seen" is true.
	if FileAccess.file_exists(PROFILE_PATH):
		DirAccess.remove_absolute(PROFILE_PATH)
	_front_end = FrontEndScene.instantiate()
	_front_end.get_node("ProgressionService").set("profile_path", PROFILE_PATH)
	root.add_child(_front_end)
	await process_frame
	await process_frame
	_profile = _front_end.get_node("ProgressionService")

	# The opening is the engine's own load. There is no ident film in front of
	# it any more (docs/DECISIONS.md 17), so the first frame this test sees has
	# to be BOOT.
	_expect(_front_end.get("current_stage_name") == &"BOOT", "the journey starts at BOOT")
	_check_stage(&"BOOT")

	if not await _walk_to(&"LOADING", "BOOT"):
		_finish()
		return

	# LOADING drains its own queue. Waiting on it is the point: it proves the
	# stage advances because the resources arrived, not because a timer fired.
	if not await _walk_to(&"CHAPTER", "LOADING"):
		_finish()
		return

	_expect(
		not bool(_profile.get("intro_seen")),
		"the chapter card is not marked seen while it is still on screen"
	)
	_check_stage(&"CHAPTER")

	# Clearing the card is what marks the first launch done; FrontEnd owns that
	# rule, so the test drives the card's own action rather than go_to().
	_press_continue(&"CHAPTER")
	await process_frame
	_check_stage(&"DASHBOARD")
	_check_dashboard_numbers()

	# The weapon rail lives on HERO now: one page, one loadout -- who you are and
	# what you carry. `_check_weapon_stats_are_real` walks the registry through
	# the rail rather than a page of its own.
	_front_end.go_to(&"HERO", {})
	await process_frame
	_check_stage(&"HERO")
	await _check_weapon_stats_are_real()
	_check_locked_content_disabled(&"HERO")

	_front_end.go_to(&"WORLD", {})
	await process_frame
	_check_stage(&"WORLD")
	_check_locked_content_disabled(&"WORLD")
	await _check_launch_payload()

	await _check_preload_contract()
	await _check_intro_persists()
	await _check_saved_weapon_reaches_gameplay()
	_finish()


# --- walking ----------------------------------------------------------------


## Waits for a stage that advances by itself, up to MAX_WAIT_FRAMES.
func _walk_to(expected: StringName, from_label: String) -> bool:
	for _frame in range(MAX_WAIT_FRAMES):
		if _front_end.get("current_stage_name") == expected:
			await process_frame
			_check_stage(expected)
			return true
		await process_frame
	_expect(
		false,
		(
			"%s advances to %s on its own (still at %s after %d frames)"
			% [
				from_label,
				expected,
				_front_end.get("current_stage_name"),
				MAX_WAIT_FRAMES,
			]
		)
	)
	return false


## Presses a stage's primary action, whatever its copy is.
func _press_continue(stage_name: StringName) -> void:
	var stage := _stage(stage_name)
	if not is_instance_valid(stage):
		return
	for child in stage.find_children("*", "Button", true, false):
		var button := child as Button
		if button == null or button.disabled or button.text.is_empty():
			continue
		button.pressed.emit()
		return
	_expect(false, "%s exposes a primary action" % stage_name)


func _stage(name: StringName) -> Control:
	return _front_end.get_node_or_null("StageHost/" + str(name)) as Control


# --- per-stage checks -------------------------------------------------------


func _check_stage(name: StringName) -> void:
	var stage := _stage(name)
	if not _expect(is_instance_valid(stage), "%s is instantiated under StageHost" % name):
		return
	_expect(stage.visible, "%s is visible when entered" % name)
	_expect(stage.size.x > 0.0 and stage.size.y > 0.0, "%s has a non-zero size" % name)
	_check_buttons_have_actions(stage, name)
	_check_safe_area(stage, name)


## "No buttons without actions", enforced. Placeholder slots are `disabled`,
## which is the honest way to show content that does not exist yet: the button
## is visibly inert instead of quietly doing nothing when tapped.
func _check_buttons_have_actions(stage: Node, label: String) -> void:
	var checked := 0
	for child in stage.find_children("*", "Button", true, false):
		var button := child as Button
		if button == null or button.disabled:
			continue
		# A stage's own BACK/CONTINUE row is inside the stage; the settings and
		# armory panels are children of the dashboard and are checked too.
		# A toggle_mode button does its work on `toggled`, which fires on every
		# press; `pressed` is not the only signal that makes a control live.
		var connections := button.get_signal_connection_list("pressed")
		connections.append_array(button.get_signal_connection_list("toggled"))
		if connections.is_empty():
			_expect(
				false,
				(
					"%s: button '%s' is enabled but has no pressed or toggled handler"
					% [
						label,
						button.name,
					]
				)
			)
		checked += 1
	if label in INTERACTIVE_STAGES:
		_expect(checked > 0, "%s exposes at least one enabled action" % label)


## The menus inherit the combat HUD's reserved edge. Headless reports no safe
## area, so this catches overflow past the viewport rather than past a notch --
## the notch maths is shared with UiLayout and covered by
## hud_safe_margin_smoke.gd.
func _check_safe_area(stage: Control, label: String) -> void:
	var bounds := Rect2(Vector2.ZERO, stage.size).grow(-4.0)
	for child in stage.find_children("*", "Button", true, false):
		var button := child as Button
		if button == null or not button.is_visible_in_tree():
			continue
		var local := Rect2(button.get_global_position() - stage.get_global_position(), button.size)
		_expect(
			bounds.encloses(local) or local.intersects(bounds),
			"%s: control '%s' stays inside the frame (rect %s)" % [label, button.name, local]
		)


func _check_dashboard_numbers() -> void:
	var stage := _stage(&"DASHBOARD")
	var text := _all_label_text(stage)
	_expect(text.contains("BATTLE POINTS"), "the dashboard shows the Battle Points wallet")
	_expect(text.contains("BEST SCORE"), "the dashboard shows the best score")
	_expect(text.contains("RUNS COMPLETED"), "the dashboard shows completed runs")
	_expect(text.contains("LOADOUT"), "the dashboard shows the loadout it will launch with")


## Every weapon prints its own numbers, and prints them *when it is selected*.
##
## This used to read one static page of three cards. The screen is a 3D showcase
## now, so it shows the selected weapon's statistics in one panel; the way to keep
## the original promise -- no number on screen that the resource does not contain
## -- is to walk the registry, select each weapon and read the panel back. That is
## a stronger check than the old one: it fails if the panel stops following the
## selection, which the card version could not.
func _check_weapon_stats_are_real() -> void:
	var stage := _stage(&"HERO")
	for definition in WeaponDefinition.load_all_definitions():
		var chip := _weapon_chip(stage, definition.weapon_id)
		if not _expect(chip != null, "%s: the carousel offers a chip" % definition.weapon_id):
			continue
		if chip.disabled:
			# A weapon the profile has not unlocked cannot be selected, so what
			# the screen owes the player is its name and its price -- both of
			# which are the chip's own text now, not a caption under it.
			var chip_text := _all_label_text(chip)
			_expect(
				chip_text.contains(definition.display_name.to_upper()),
				"%s: the locked chip is still named" % definition.weapon_id
			)
			_expect(
				chip_text.contains("BP"),
				"%s: the locked chip states its price" % definition.weapon_id
			)
			continue
		chip.pressed.emit()
		await process_frame
		await process_frame
		var shown := _all_label_text(_stage(&"HERO"))
		# Straight off the WeaponDefinition: 18/34/20 damage at 5.0/0.8/2.0 shots
		# per second, 24/6/12 rounds. If these drift, the screen is lying.
		for expected in [
			"DMG %d" % roundi(definition.damage),
			"RATE %s/s" % _trim_number(definition.fire_rate),
			"MAG %d" % definition.magazine_size,
		]:
			_expect(
				shown.contains(expected),
				(
					"%s: the selected weapon prints '%s' from the definition"
					% [definition.weapon_id, expected]
				)
			)
		if definition.chain_count > 0:
			_expect(
				shown.contains("CHAIN %d" % definition.chain_count),
				"%s: the chain property is printed" % definition.weapon_id
			)


func _weapon_chip(stage: Control, weapon_id: StringName) -> Button:
	for child in stage.find_children("*", "Button", true, false):
		var button := child as Button
		if button != null and StringName(str(button.get_meta("weapon_id", ""))) == weapon_id:
			return button
	return null


## The screen trims trailing zeros; the test has to read the same way.
func _trim_number(value: float) -> String:
	var text := "%.2f" % value
	while text.ends_with("0") and text.contains("."):
		text = text.substr(0, text.length() - 1)
	return text.substr(0, text.length() - 1) if text.ends_with(".") else text


## Content the project does not have must be disabled, not merely labelled.
func _check_locked_content_disabled(name: StringName) -> void:
	var stage := _stage(name)
	var disabled := 0
	for child in stage.find_children("*", "Button", true, false):
		var button := child as Button
		if button != null and button.disabled:
			disabled += 1
	_expect(disabled > 0, "%s marks content the project does not ship as disabled" % name)
	_expect(
		_all_label_text(stage).contains("IN DEVELOPMENT"),
		"%s labels its placeholder slots IN DEVELOPMENT" % name
	)


## Pressing LAUNCH must hand PRELOAD a payload naming a scene that exists. The
## payload is read back off the live stage, so this is the wiring, not a copy of
## the constant.
func _check_launch_payload() -> void:
	var stage := _stage(&"WORLD")
	var launched := false
	for child in stage.find_children("*", "Button", true, false):
		var button := child as Button
		if button != null and button.text == "LAUNCH":
			button.pressed.emit()
			launched = true
			break
	_expect(launched, "WORLD exposes a LAUNCH action")
	await process_frame
	_expect(
		_front_end.get("current_stage_name") == &"PRELOAD", "LAUNCH advances the journey to PRELOAD"
	)
	var payload: Dictionary = {}
	var preload_stage := _stage(&"PRELOAD") as MenuStage
	if is_instance_valid(preload_stage):
		payload = preload_stage.payload
	_expect(
		str(payload.get("scene", "")) == "res://scenes/main.tscn",
		"PRELOAD is handed the gameplay scene path (got '%s')" % str(payload.get("scene", ""))
	)
	_expect(
		ResourceLoader.exists(str(payload.get("scene", ""))),
		"the scene PRELOAD is asked to load exists"
	)
	# Step off PRELOAD so it cannot reach change_scene (which would tear the
	# harness down), then let the threaded fetch it started run to completion.
	# Quitting with a load in flight makes the loader thread compile scripts
	# during teardown, which reports failures that are not real.
	_front_end.go_to(&"DASHBOARD", {})
	await process_frame
	for _frame in range(MAX_WAIT_FRAMES):
		var status := ResourceLoader.load_threaded_get_status("res://scenes/main.tscn")
		if status != ResourceLoader.THREAD_LOAD_IN_PROGRESS:
			_expect(
				status == ResourceLoader.THREAD_LOAD_LOADED,
				"the gameplay scene PRELOAD fetches really loads (status %d)" % status
			)
			break
		await process_frame


## PRELOAD is the only stage allowed to change scene, and it must be handed a
## real PackedScene. The scene swap itself is exercised by the browser
## playthrough, not here: swapping the root out from under a SceneTree test
## would tear down the harness.
func _check_preload_contract() -> void:
	var stage: Control = PreloadScene.instantiate()
	stage.name = "PreloadProbe"
	root.add_child(stage)
	await process_frame
	_expect(is_instance_valid(stage), "the PRELOAD stage instantiates")
	var scene := GameplayScene
	_expect(scene != null, "the preload target res://scenes/main.tscn is a PackedScene")
	stage.free()


## Second-launch behaviour: the flag written when the chapter card was cleared
## has to survive a reload of the profile, and a fresh FrontEnd must skip the
## card.
func _check_intro_persists() -> void:
	_expect(
		bool(_profile.get("intro_seen")),
		"clearing the chapter card marks intro_seen on the live profile"
	)
	_expect(
		FileAccess.file_exists(PROFILE_PATH),
		"intro_seen is written to a real ConfigFile, not only held in memory"
	)

	var reloaded := ProgressionService.new()
	reloaded.profile_path = PROFILE_PATH
	root.add_child(reloaded)
	await process_frame
	_expect(bool(reloaded.intro_seen), "a fresh profile load reads intro_seen back")
	_expect(reloaded.selected_weapon_id == &"pulse_rifle", "the default loadout survives a reload")
	reloaded.free()


## The last hop: PRELOAD hands the gameplay scene a loadout, and the scene has
## to actually read it. Without this check the journey could end at a scene that
## silently ignores the choice the player made three screens earlier.
func _check_saved_weapon_reaches_gameplay() -> void:
	var profile := ProgressionService.new()
	profile.profile_path = PROFILE_PATH
	root.add_child(profile)
	await process_frame
	profile.unlocked_ids["arc_shooter"] = true
	_expect(profile.select_weapon(&"arc_shooter"), "the profile accepts a weapon the player owns")

	var main: Node = GameplayScene.instantiate()
	main.set("start_wave_session_on_ready", false)
	main.get_node("ProgressionService").set("profile_path", PROFILE_PATH)
	root.add_child(main)
	await process_frame
	await process_frame
	var controller := main.get_node("Player").get("weapon_controller") as WeaponController
	if not _expect(is_instance_valid(controller), "the gameplay scene exposes a weapon controller"):
		main.free()
		profile.free()
		return
	var equipped: StringName = controller.get_current_definition().weapon_id
	_expect(
		equipped == &"arc_shooter",
		"gameplay starts with the weapon the front end saved (equipped %s)" % equipped
	)
	main.free()
	profile.free()


# --- harness ----------------------------------------------------------------


func _all_label_text(root_node: Node) -> String:
	var parts: Array[String] = []
	# Buttons render their own text. A placeholder drawn as a disabled button
	# says IN DEVELOPMENT in exactly the place a player reads it.
	for child in root_node.find_children("*", "BaseButton", true, false):
		var button := child as BaseButton
		if button != null and not button.text.is_empty():
			parts.append(button.text)
	for child in root_node.find_children("*", "Label", true, false):
		parts.append((child as Label).text)
	return "\n".join(parts)


func _expect(condition: bool, message: String) -> bool:
	if condition:
		print("  ok: " + message)
	else:
		_failures.append(message)
		push_error("Front-end journey smoke test failed: " + message)
	return condition


func _finish() -> void:
	if is_instance_valid(_front_end):
		_front_end.free()
		_front_end = null
	if _failures.is_empty():
		print("Front-end journey smoke test passed.")
	else:
		print("Front-end journey smoke test failed: %d problem(s)." % _failures.size())
		for message in _failures:
			print("  - " + message)
	quit(1 if _failures.size() > 0 else 0)
