extends SceneTree

const MainScene = preload("res://scenes/main.tscn")

var _failures: int = 0


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	AegisPreferences.write(AegisPreferences.defaults())
	var temp_path := "user://aegis-settings-smoke.cfg"
	var malformed := AegisPreferences.defaults()
	malformed["sensitivity"] = -4.0
	malformed["hud_scale"] = 9.0
	malformed["hud_opacity"] = 0.1
	malformed["left_handed"] = true
	_expect(AegisPreferences.write(malformed, temp_path) == OK, "settings can be saved")
	var sanitized := AegisPreferences.read(temp_path)
	_expect(
		(
			is_equal_approx(float(sanitized["sensitivity"]), 0.5)
			and is_equal_approx(float(sanitized["hud_scale"]), 1.2)
			and is_equal_approx(float(sanitized["hud_opacity"]), 0.65)
			and bool(sanitized["left_handed"])
		),
		"stored settings round-trip with safe min/max bounds",
	)
	DirAccess.remove_absolute(ProjectSettings.globalize_path(temp_path))

	var main := MainScene.instantiate()
	main.set("start_wave_session_on_ready", false)
	root.add_child(main)
	await process_frame
	var controls := main.get_node("HUD/TouchControls")
	var menu := controls.get("_settings_menu") as AegisSettingsMenu
	var pause := controls.get("_pause_panel") as Control
	var top := controls.get("_top_bar") as Control
	var player := main.get_node("Player")
	var camera_rig := player.get_node("CameraRig") as ThirdPersonCameraRig
	var default_sensitivity := camera_rig.look_sensitivity
	controls.call("apply_layout_for_size", Vector2(1280, 720), 1.0)
	_expect(is_instance_valid(menu) and not menu.visible, "settings remain hidden during gameplay")
	main.call("_toggle_pause")
	controls.call("_open_settings")
	_expect(
		menu.visible and not pause.visible and not top.visible and paused,
		"settings opens over a paused run without unpausing gameplay",
	)
	menu.call("_show_tab", 1)
	var sensitivity := menu.find_child("sensitivitySlider", true, false) as HSlider
	var handed := menu.find_child("left_handedToggle", true, false) as Button
	_expect(
		is_instance_valid(sensitivity) and is_instance_valid(handed),
		"controls tab offers aim and handedness"
	)
	var slider_track := sensitivity.get_theme_stylebox("slider") as StyleBoxFlat
	var slider_fill := sensitivity.get_theme_stylebox("grabber_area") as StyleBoxFlat
	_expect(
		(
			slider_track.bg_color.is_equal_approx(AegisTokens.LINE_HI)
			and slider_fill.bg_color.is_equal_approx(AegisTokens.ACCENT)
			and slider_track.content_margin_top >= 3.0
		),
		"settings sliders retain high-contrast tracks like the HUD editor",
	)
	sensitivity.value = 1.25
	_expect(
		(
			is_equal_approx(camera_rig.look_sensitivity, default_sensitivity * 1.25)
			and is_equal_approx(float(AegisPreferences.read()["sensitivity"]), 1.25)
		),
		"sensitivity changes camera immediately and persists across reload",
	)
	handed.button_pressed = true
	controls.call("apply_layout_for_size", Vector2(390, 844), 0.3047)
	await process_frame
	var stick: Vector2 = controls.get("_joystick_center")
	var fire := controls.get("_fire_button") as Button
	_expect(
		(
			stick.x > controls.size.x * 0.5
			and fire.get_global_rect().get_center().x < controls.size.x * 0.5
		),
		"left-handed layout mirrors joystick and combat buttons",
	)

	menu.call("_show_tab", 2)
	var scale_slider := menu.find_child("hud_scaleSlider", true, false) as HSlider
	var opacity_slider := menu.find_child("hud_opacitySlider", true, false) as HSlider
	_expect(
		is_instance_valid(scale_slider) and is_instance_valid(opacity_slider),
		"HUD tab has scale and contrast-safe opacity controls",
	)
	scale_slider.value = 1.15
	opacity_slider.value = 0.70
	var card := controls.get("_health_card") as Control
	var panel_style := card.get_theme_stylebox("panel") as StyleBoxFlat
	_expect(
		(
			is_equal_approx(float(controls.get("_hud_scale")), 1.15)
			and is_equal_approx(float(controls.get("_hud_opacity")), 0.70)
			and is_equal_approx(panel_style.bg_color.a, AegisTokens.PANEL_ALPHA * 0.70)
		),
		"HUD scale and panel opacity apply live without dimming text",
	)

	menu.call("_show_tab", 3)
	var reduce_motion := menu.find_child("reduce_motionToggle", true, false) as Button
	var reduce_flash := menu.find_child("reduce_flashToggle", true, false) as Button
	var colorblind := menu.find_child("colorblindToggle", true, false) as Button
	var text_scale := menu.find_child("text_scaleSlider", true, false) as HSlider
	text_scale.value = 1.25
	colorblind.button_pressed = true
	reduce_motion.button_pressed = true
	reduce_flash.button_pressed = true
	controls.call("set_hud_health", 20.0, 100.0)
	var health_style := (
		(controls.get("_health_bar") as Control).get_theme_stylebox("fill") as StyleBoxFlat
	)
	_expect(
		(
			is_equal_approx(float(controls.get("_text_scale")), 1.25)
			and health_style.bg_color.is_equal_approx(Color("ff8c42"))
			and (controls.get("_health_heading") as Label).text.contains("!")
		),
		"large text and colorblind-safe low-health signal apply live",
	)
	controls.call("show_hit_confirmed")
	controls.call("show_damage_received")
	_expect(
		(
			float(controls.get("_hit_confirm_remaining")) <= 0.09
			and is_zero_approx(float(controls.get("_damage_flash_remaining")))
		),
		"accessibility settings shorten motion and disable damage flashes",
	)
	var rig := camera_rig as ThirdPersonCameraRig
	_expect(
		(
			is_zero_approx(rig.walk_bob_scale)
			and is_zero_approx(rig.kick_rotation_degrees)
			and is_zero_approx(rig.kick_push)
		),
		"reduce motion disables camera bob and weapon kick, not just HUD fades",
	)
	reduce_flash.button_pressed = false
	controls.call("show_damage_received")
	_expect(
		float(controls.get("_damage_flash_remaining")) <= 0.1,
		"reduce motion caps the vignette even when reduce flash is off",
	)
	reduce_motion.button_pressed = false
	_expect(
		(
			is_equal_approx(rig.walk_bob_scale, float(rig.get("_default_walk_bob")))
			and is_equal_approx(rig.kick_push, float(rig.get("_default_kick_push")))
		),
		"disabling reduce motion restores authored camera feel",
	)

	var escape := InputEventKey.new()
	escape.keycode = KEY_ESCAPE
	escape.pressed = true
	controls.call("_input", escape)
	_expect(
		not menu.visible and pause.visible and paused,
		"first ESC closes settings back to the pause card",
	)
	controls.call("_input", escape)
	_expect(not paused and not pause.visible, "second ESC resumes gameplay")

	main.queue_free()
	await process_frame
	AegisPreferences.write(AegisPreferences.defaults())
	if _failures > 0:
		printerr("UI settings smoke: %d failure(s)" % _failures)
		quit(1)
	else:
		print("UI settings smoke: PASS")
		quit(0)


func _expect(condition: bool, label: String) -> void:
	if condition:
		print("  PASS: ", label)
	else:
		printerr("  FAIL: ", label)
		_failures += 1
