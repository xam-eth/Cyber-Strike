extends SceneTree

const MainScene = preload("res://scenes/main.tscn")

var _failures: int = 0


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	AegisPreferences.write(AegisPreferences.defaults())
	var main := MainScene.instantiate()
	main.set("start_wave_session_on_ready", false)
	root.add_child(main)
	await process_frame
	var hud := main.get_node("HUD/TouchControls")
	var menu := hud.get("_settings_menu") as AegisSettingsMenu
	var editor := hud.get("_hud_editor") as AegisHudEditor
	var vitals := hud.get("_health_card") as Control
	var run_card := hud.get("_run_card") as Control
	var scrim := hud.get("_scrim") as Control
	hud.call("set_touch_mode", false)
	hud.call("apply_layout_for_size", Vector2(1280, 720), 1.0)
	await process_frame
	var starting_rect := vitals.get_global_rect()
	main.call("_toggle_pause")
	hud.call("_open_settings")
	menu.editor_requested.emit()
	_expect(
		editor.visible and not menu.visible and not scrim.visible and paused,
		"HUD editor previews actual controls over the paused world",
	)
	_expect(
		editor.find_child("HudGroupSelect", true, false) is OptionButton,
		"inspector exposes a keyboard-focusable HUD group selector",
	)

	editor.call("_set_offset", Vector2(53, -22))
	await process_frame
	var stored := AegisPreferences.read()
	var offset: Vector2 = stored["hud_offsets"]["VITALS"]
	_expect(
		(
			offset == Vector2(56, -24)
			and vitals.get_global_rect().position.x > starting_rect.position.x + 50.0
			and vitals.get_global_rect().position.y >= 12.0
		),
		"drag offset snaps to 8 design units, persists, and stays within safe margins",
	)
	editor.call("_set_preset", "MINIMAL")
	_expect(
		(
			not run_card.visible
			and vitals.visible
			and String(AegisPreferences.read()["hud_preset"]) == "MINIMAL"
		),
		"minimal preset removes nonessential run chrome but retains critical status",
	)
	editor.call("_reset_group")
	_expect(
		(
			not AegisPreferences.read()["hud_offsets"].has("VITALS")
			and is_equal_approx(vitals.get_global_rect().position.x, starting_rect.position.x)
		),
		"reset group restores only its default position",
	)
	editor.call("_set_offset", Vector2(80, 32))
	editor.call("_reset_layout")
	_expect(
		(
			AegisPreferences.read()["hud_offsets"].is_empty()
			and String(AegisPreferences.read()["hud_preset"]) == "STANDARD"
			and not run_card.visible
			and (hud.get("_wave_card") as Control).visible
		),
		"reset layout clears offsets and keeps the contextual objective, not run clutter",
	)

	hud.call("set_touch_mode", true)
	hud.call("apply_layout_for_size", Vector2(844, 390), 0.541667)
	await process_frame
	var inspector := editor.find_child("HudInspector", true, false) as Control
	var finish := editor.find_child("DoneHudEditorButton", true, false) as Button
	_expect(
		(
			finish.is_visible_in_tree()
			and finish.get_global_rect().end.y <= inspector.get_global_rect().end.y + 1.0
			and finish.get_global_rect().size.y * 0.541667 >= 43.5
		),
		"landscape editor keeps an always-visible 44px DONE target",
	)

	var escape := InputEventKey.new()
	escape.keycode = KEY_ESCAPE
	escape.pressed = true
	hud.call("_input", escape)
	_expect(not editor.visible and menu.visible and paused, "ESC exits editor to settings")
	hud.call("_input", escape)
	_expect(not menu.visible and paused, "ESC exits settings to pause")
	hud.call("_input", escape)
	_expect(not paused, "ESC finally resumes the same session")
	main.queue_free()
	await process_frame
	AegisPreferences.write(AegisPreferences.defaults())
	if _failures > 0:
		printerr("HUD editor smoke: %d failure(s)" % _failures)
		quit(1)
	else:
		print("HUD editor smoke: PASS")
		quit(0)


func _expect(condition: bool, label: String) -> void:
	if condition:
		print("  PASS: ", label)
	else:
		printerr("  FAIL: ", label)
		_failures += 1
