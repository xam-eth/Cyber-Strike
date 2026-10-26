extends SceneTree

## Proof that every gameplay menu can leave the world.
##
## A HOME button that exists but is wired to nothing is worse than no button: the
## player presses the way out and the screen does not move. So this test presses
## each of the four HOME affordances the shipped HUD builds -- pause, results,
## armory, settings -- and asserts that the HUD raises `home_requested` for it,
## and that `Main` answered that signal before the test disconnected it.
##
## The second half covers the return from the front end's side: `FrontEnd`
## honours `resume_stage`, which is what `DashboardReturn` sets when the engine is
## not embedded in the web shell. Coming back has to land on DASHBOARD and has to
## clear the request, or the next launch would skip the boot as well.

const MainScene = preload("res://scenes/main.tscn")
const FrontEndScene = preload("res://scenes/ui/front_end.tscn")

## Distinct from the real save: the suite must not spend anyone's BP.
const PROFILE_PATH := "user://menu_home_smoke_profile.cfg"
const FRONT_END_PROFILE := "user://menu_home_smoke_front_end.cfg"

var _failures: Array[String] = []
var _home_requests := 0


func _initialize() -> void:
	call_deferred("_run_smoke_test")


func _run_smoke_test() -> void:
	AegisPreferences.write(AegisPreferences.defaults())
	if FileAccess.file_exists(FRONT_END_PROFILE):
		DirAccess.remove_absolute(FRONT_END_PROFILE)

	var main := MainScene.instantiate()
	main.set("start_wave_session_on_ready", false)
	main.get_node("ProgressionService").set("profile_path", PROFILE_PATH)
	root.add_child(main)
	await process_frame
	await process_frame

	var hud: Control = main.get_node("HUD/TouchControls")
	_expect(_exit_is_answered(hud), "Main answers the HUD's HOME request")
	_disconnect_home(hud)
	hud.home_requested.connect(_on_home_requested)

	# The armory is the one panel whose HOME only exists in the field: the
	# dashboard shows the same panel as its own armory, where HOME would mean
	# "stay here".
	var armory: Node = hud.get("_armory_panel")
	_expect(
		_is_hidden_button(armory, "ArmoryHomeButton"),
		"the armory's HOME stays hidden until the field opens the panel",
	)
	armory.call("show_home", true)
	_expect(
		_is_free_button(armory, "ArmoryHomeButton"),
		"the field armory offers HOME",
	)

	var cases := [
		[hud.get("_pause_panel"), "PauseHomeButton", "pause"],
		[hud.get("_results_panel"), "ResultsHomeButton", "results"],
		[armory, "ArmoryHomeButton", "armory"],
		[hud.get("_settings_menu"), "HomeSettingsButton", "settings"],
	]
	for entry in cases:
		var panel: Node = entry[0]
		var button_name: String = entry[1]
		var label: String = entry[2]
		var button := panel.find_child(button_name, true, false) as Button
		if not is_instance_valid(button):
			_expect(false, "the %s menu builds %s" % [label, button_name])
			continue
		var before := _home_requests
		button.pressed.emit()
		_expect(
			_home_requests == before + 1,
			"%s HOME raises home_requested" % label,
		)

	await _check_touch_dispatch(hud)
	await _check_overlay_stack(hud)

	main.queue_free()
	await process_frame

	await _check_resume_stage()
	_finish()


## The touch build does not let Godot's Button GUI do the work: `HudTouchInput`
## resolves a finger to a button and then walks a hand-written `activate()` chain.
## A plate that is missing from that chain is drawn, pressed by `pressed.emit()`
## and completely dead under a real finger -- which is how the first cut of these
## HOME buttons shipped. So the last check uses a finger, not a signal emit.
func _check_touch_dispatch(hud: Control) -> void:
	hud.call("set_paused", true)
	await process_frame
	await process_frame
	var panel: Node = hud.get("_pause_panel")
	var home := panel.find_child("PauseHomeButton", true, false) as Button
	if not is_instance_valid(home):
		_expect(false, "the pause card builds its HOME plate")
		return
	var center: Vector2 = home.get_global_rect().get_center()
	var touch: Object = hud.get("_touch")
	var before := _home_requests
	touch.call("begin", 0, center)
	touch.call("end", 0, center)
	_expect(_home_requests == before + 1, "a finger on pause HOME reaches Main")
	hud.call("set_paused", false)
	await process_frame


## What the round-11 bug taught: the HUD's overlays used to be five booleans and
## an if/elif ladder, so a new plate could be added in one place and forgotten in
## another. `HudOverlayStack` is the single owner now, and this checks the three
## things it promises -- one layer per overlay, ESC closes exactly one, and focus
## cannot walk out of a modal into the buttons behind it.
func _check_overlay_stack(hud: Control) -> void:
	var stack: Object = hud.get("_overlays")
	if stack == null:
		_expect(false, "the HUD owns an overlay stack")
		return
	_expect(stack.call("is_empty"), "nothing owns the screen before a menu opens")

	paused = true
	hud.call("set_paused", true)
	await process_frame
	var pause_panel := hud.get("_pause_panel") as Control
	_expect(
		stack.call("size") == 1 and stack.call("top") == pause_panel,
		"the pause card is the only layer while it is open",
	)

	var fire := hud.get("_fire_button") as Control
	if "focus_behavior_recursive" in fire:
		_expect(
			(
				fire.focus_behavior_recursive == Control.FOCUS_BEHAVIOR_DISABLED
				and pause_panel.focus_behavior_recursive != Control.FOCUS_BEHAVIOR_DISABLED
			),
			"a modal traps focus: the fire tile is unreachable, the card is not",
		)

	hud.call("_open_settings")
	await process_frame
	var settings := hud.get("_settings_menu") as Control
	_expect(
		stack.call("size") == 2 and stack.call("top") == settings,
		"settings stacks on top of pause instead of replacing it",
	)

	# ESC through the real handler, not by calling pop().
	var escape := InputEventKey.new()
	escape.keycode = KEY_ESCAPE
	escape.physical_keycode = KEY_ESCAPE
	escape.pressed = true
	hud.call("_input", escape)
	await process_frame
	_expect(
		stack.call("size") == 1 and not settings.visible and pause_panel.visible,
		"ESC closes one layer and leaves the one under it up",
	)

	hud.call("set_paused", false)
	paused = false
	await process_frame
	_expect(stack.call("is_empty"), "resuming empties the stack, trap and all")
	if "focus_behavior_recursive" in fire:
		_expect(
			fire.focus_behavior_recursive == Control.FOCUS_BEHAVIOR_INHERITED,
			"resuming hands focus back to the world",
		)


func _check_resume_stage() -> void:
	FrontEnd.resume_stage = &"DASHBOARD"
	var front_end := FrontEndScene.instantiate()
	front_end.get_node("ProgressionService").set("profile_path", FRONT_END_PROFILE)
	root.add_child(front_end)
	await process_frame
	await process_frame
	_expect(
		front_end.get("current_stage_name") == &"DASHBOARD",
		"a return from the world opens on DASHBOARD, not on the boot",
	)
	_expect(
		FrontEnd.resume_stage == &"",
		"the resume request is spent once, so the next launch still boots",
	)
	front_end.queue_free()
	await process_frame


func _exit_is_answered(hud: Control) -> bool:
	for connection in hud.home_requested.get_connections():
		var callable: Callable = connection["callable"]
		if callable.get_method() == "_exit_to_dashboard":
			return true
	return false


## The real handler changes the scene; this test wants to count the signal and
## stay in the field, so it owns the connection for the rest of the run.
func _disconnect_home(hud: Control) -> void:
	for connection in hud.home_requested.get_connections():
		var callable: Callable = connection["callable"]
		hud.home_requested.disconnect(callable)


func _on_home_requested() -> void:
	_home_requests += 1


func _is_hidden_button(panel: Node, button_name: String) -> bool:
	if not is_instance_valid(panel):
		return false
	var button := panel.find_child(button_name, true, false) as Button
	return is_instance_valid(button) and not button.visible


func _is_free_button(panel: Node, button_name: String) -> bool:
	var button := panel.find_child(button_name, true, false) as Button
	if not is_instance_valid(button):
		return false
	return button.visible and not button.disabled and button.pressed.get_connections().size() > 0


func _finish() -> void:
	if FileAccess.file_exists(PROFILE_PATH):
		DirAccess.remove_absolute(PROFILE_PATH)
	if FileAccess.file_exists(FRONT_END_PROFILE):
		DirAccess.remove_absolute(FRONT_END_PROFILE)
	if _failures.is_empty():
		print("Menu HOME smoke: PASS")
		quit(0)
		return
	print("Menu HOME smoke: %d failure(s)" % _failures.size())
	for failure in _failures:
		print("  fail: " + failure)
	quit(1)


func _expect(condition: bool, label: String) -> void:
	if condition:
		print("  PASS: " + label)
	else:
		print("  FAIL: " + label)
		_failures.append(label)
