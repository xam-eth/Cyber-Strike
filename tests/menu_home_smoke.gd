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

	main.queue_free()
	await process_frame

	await _check_resume_stage()
	_finish()


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
