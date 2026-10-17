extends SceneTree

const MainScene = preload("res://scenes/main.tscn")
const RunnerScene = preload("res://scenes/enemies/runner.tscn")

var _failures: int = 0


func _initialize() -> void:
	call_deferred("_run_smoke_test")


func _run_smoke_test() -> void:
	# The mute preference is persisted in user://, so a previous run could hand
	# this one a muted game: start from a known state.
	Sfx.set_muted(false)
	var main_scene := MainScene.instantiate()
	main_scene.set("start_wave_session_on_ready", false)
	root.add_child(main_scene)
	await process_frame

	var player: Node3D = main_scene.get_node("Player")
	var wave_director: Node = main_scene.get_node("WaveDirector")
	var controls: Control = main_scene.get_node("HUD/TouchControls")
	var health_bar := controls.get("_health_bar") as ProgressBar
	var health_value := controls.get("_health_value_label") as Label
	var wave_title := controls.get("_wave_title_label") as Label
	var wave_enemy_label := controls.get("_wave_enemy_label") as Label
	var status_label := controls.get("_status_label") as Label
	var help_label := controls.get("_help_label") as Label
	var fire_button := controls.get("_fire_button") as Button
	var weapon_button := controls.get("_weapon_button") as Button
	var skill_button := controls.get("_skill_button") as Button
	var pause_button := controls.get("_pause_button") as Button
	var sound_button := controls.get("_sound_button") as Button
	var compact_card := controls.get("_compact_card") as PanelContainer
	var compact_label := controls.get("_compact_label") as Label
	var aim_button := controls.get("_aim_button") as Button
	# The test drives a touchscreen that a headless display server never reports,
	# so it opts into the thumb layout explicitly. Desktop mode is asserted below.
	controls.call("set_touch_mode", true)
	var character_visual := player.get_node("VisualRoot")
	var player_camera := (
		player.get_node("CameraRig/YawPivot/PitchPivot/SpringArm3D/Camera3D") as Camera3D
	)
	var spring_arm := player.get_node("CameraRig/YawPivot/PitchPivot/SpringArm3D") as SpringArm3D
	var pitch_pivot := player.get_node("CameraRig/YawPivot/PitchPivot") as Node3D

	_expect(
		(
			is_instance_valid(health_bar)
			and is_instance_valid(wave_title)
			and is_instance_valid(status_label)
		),
		"playtest HUD builds health, wave, and run-data cards",
	)
	_expect(
		is_equal_approx(health_bar.value, 100.0) and health_value.text == "100 / 100",
		"health bar reflects the live player health",
	)
	_expect(
		wave_title.text == "FRONTIER DEFENSE" and wave_enemy_label.text.contains("0 ACTIVE"),
		"wave HUD starts in a clear ready state",
	)
	# On a phone the compact data card and the help plate must not overlap; this
	# was the first thing a 390x844 screenshot showed.
	controls.call("apply_layout_for_size", Vector2(390.0, 844.0), 1.0)
	# Containers recompute their rects on the next frame; reading the rects
	# immediately measures the previous layout and reports a false overlap.
	await process_frame
	var compact_bottom := compact_card.get_global_rect().end.y
	var help_top := help_label.get_global_rect().position.y
	_expect(
		help_top >= compact_bottom - 0.5,
		"narrow layout keeps the help plate below the compact data card",
	)
	controls.call("apply_layout_for_size", Vector2(1280.0, 720.0), 1.0)
	_expect(
		(
			help_label.autowrap_mode != TextServer.AUTOWRAP_OFF
			and help_label.text.contains("TOUCH")
			and help_label.text.contains("360°")
			and help_label.text.contains("EMP")
			and help_label.text.contains("WASD")
		),
		"wrapped help explains mobile and desktop controls",
	)
	# Desktop sessions must not keep the thumb cluster on screen: it covered the
	# play area and swallowed clicks.
	controls.call("set_touch_mode", false)
	_expect(
		not fire_button.visible and not aim_button.visible and not skill_button.visible,
		"desktop mode hides the thumb controls",
	)
	var desktop_hint := controls.get("_desktop_hint") as Label
	_expect(
		is_instance_valid(desktop_hint) and desktop_hint.visible,
		(
			(
				"desktop mode shows the keyboard legend (valid=%s visible=%s touch=%s narrow=%s "
				+ "size=%s physical=%s)"
			)
			% [
				is_instance_valid(desktop_hint),
				is_instance_valid(desktop_hint) and desktop_hint.visible,
				controls.call("is_touch_mode"),
				controls.get("_narrow"),
				controls.size,
				controls.get("_physical_size"),
			]
		),
	)
	controls.call("set_touch_mode", true)
	_expect(
		fire_button.visible and aim_button.visible and skill_button.visible,
		"touch mode restores the thumb controls",
	)
	_expect(
		(
			fire_button.text == "FIRE"
			and weapon_button.text == "PULSE RIFLE"
			and skill_button.text.contains("READY")
			and not skill_button.disabled
			and String(pause_button.get_meta("aegis_state", "")) == "pause"
		),
		"fire, weapon-cycle, EMP skill, and pause buttons are visible and labeled",
	)
	# Audio has no settings screen yet, so the mute control living on the HUD is
	# the only way a player can silence the game.
	_expect(
		(
			is_instance_valid(sound_button)
			and String(sound_button.get_meta("aegis_state", "")) == "on"
			and not Sfx.is_muted()
		),
		"the HUD starts with sound on and a mute control",
	)
	_tap_screen_button(controls, sound_button, 78)
	_expect(
		Sfx.is_muted() and String(sound_button.get_meta("aegis_state", "")) == "muted",
		(
			("touching SOUND mutes the audio and says so (muted=%s state=%s disabled=%s rect=%s)")
			% [
				Sfx.is_muted(),
				sound_button.get_meta("aegis_state", ""),
				sound_button.disabled,
				sound_button.get_global_rect(),
			]
		),
	)
	_tap_screen_button(controls, sound_button, 79)
	_expect(
		not Sfx.is_muted() and String(sound_button.get_meta("aegis_state", "")) == "on",
		"touching MUTED restores the audio",
	)
	# The HUD label must follow the real audio state, not flip blindly: mute from
	# outside (as the M key or a restored preference does) and let the label catch up.
	Sfx.set_muted(true)
	controls.call("set_sound_muted", Sfx.is_muted())
	_expect(
		String(sound_button.get_meta("aegis_state", "")) == "muted",
		"the HUD label follows the audio state it is told about",
	)
	Sfx.set_muted(false)
	controls.call("set_sound_muted", Sfx.is_muted())
	# Narrow screens lose the three-column bar; the numbers must move, not vanish.
	controls.call("apply_layout_for_size", Vector2(390.0, 844.0), 1.0)
	var status_snapshot := status_label.text
	controls.call("set_status", status_snapshot)
	_expect(
		(
			compact_card.visible
			and not controls.get("_run_card").visible
			and not wave_enemy_label.visible
			and compact_label.text.contains("ENEMIES")
			and compact_label.text.contains("Score:")
			and compact_label.text.count("\n") == 1
		),
		"a narrow screen shows one compact card with enemy counts and run stats",
	)
	# The web build keeps a 1280-unit logical canvas in portrait, so on a phone
	# the whole HUD used to render at ~30% of its designed size. The layout must
	# size itself from the physical window instead: a 390 px wide phone therefore
	# gets portrait body text (~11 px on glass), not 3 px.
	controls.call("apply_layout_for_size", Vector2(390.0, 844.0), 0.3047)
	# One frame so the containers settle at the new font sizes before measuring.
	await process_frame
	await process_frame
	var portrait_font := float(pause_button.get_theme_font_size("font_size")) * 0.3047
	var portrait_body_font := float(compact_label.get_theme_font_size("font_size")) * 0.3047
	_expect(
		(
			is_equal_approx(float(controls.get("_ui_scale")), 0.64)
			and is_equal_approx(float(controls.get("_stretch")), 0.3047)
			# The promise is about pixels on the glass, not about the canvas: the
			# web build keeps a 1280-unit logical canvas in portrait, so a 390 px
			# phone renders every logical pixel at ~0.3x.
			and portrait_font >= 10.5
			and portrait_body_font >= 10.5
			and compact_card.visible
			and compact_card.size.y >= compact_label.get_combined_minimum_size().y
		),
		(
			(
				"a portrait phone renders HUD text at >=11 physical px (%.1f px / %.1f px) "
				+ "and fits its data card (%.0f >= %.0f)"
			)
			% [
				portrait_body_font,
				portrait_font,
				compact_card.size.y,
				compact_label.get_combined_minimum_size().y,
			]
		),
	)
	controls.call("apply_layout_for_size", Vector2(1280.0, 720.0), 1.0)
	_expect(
		not compact_card.visible and controls.get("_run_card").visible and wave_enemy_label.visible,
		"a wide screen returns to the three-column top bar",
	)
	_expect(
		help_label.is_visible_in_tree(),
		"the control hint is shown at the start of a run",
	)
	controls.call("hide_help")
	_expect(
		not help_label.is_visible_in_tree(),
		"firing or moving retires the control hint so it stops covering the action",
	)
	controls.call("show_help")
	var camera_rig := player.get_node("CameraRig")
	# The rig pulls back on a narrow viewport, so the rest distance is a floor and
	# the exported portrait factor is the ceiling.
	var rest_distance := float(camera_rig.get("rest_spring_length"))
	var max_distance := rest_distance * float(camera_rig.get("portrait_distance_factor"))
	_expect(
		(
			spring_arm.spring_length >= rest_distance - 0.05
			and spring_arm.spring_length <= max_distance + 0.05
			and spring_arm.position.x > 0.25
			and pitch_pivot.rotation.x < -0.1
		),
		"camera rig uses a close rear follow, right-shoulder offset, and downward pitch",
	)
	_expect(
		(
			bool(character_visual.call("has_model"))
			and absf(float(character_visual.call("model_height")) - 1.78) < 0.2
		),
		"player avatar is a fitted GLB model, not the fallback capsule",
	)
	_expect(
		is_instance_valid(aim_button) and aim_button.text == "AIM",
		"aim-down-sights button is present for touch aiming",
	)

	var rest_fov := player_camera.fov
	_send_screen_touch(controls, 90, aim_button.get_global_rect().get_center(), true)
	for _frame in 14:
		await process_frame
	_expect(
		bool(player.call("is_aiming")) and player_camera.fov < rest_fov - 5.0,
		(
			(
				"holding AIM zooms the camera in for aim-down-sights (aiming=%s hold=%s hud_aim=%s "
				+ "held=%s paused=%s down=%s ids=%s fov=%.1f rest=%.1f disabled=%s rect=%s "
				+ "buttons=%s last=%s)"
			)
			% [
				player.call("is_aiming"),
				player.get("_touch_aim_hold"),
				controls.get("_aiming"),
				controls.get("_pressed_touch_buttons").keys(),
				int(paused),
				controls.get("_player_down"),
				(
					"%s/%s/%s"
					% [
						controls.get("_move_touch_id"),
						controls.get("_look_touch_id"),
						controls.get("_fire_touch_id"),
					]
				),
				player_camera.fov,
				rest_fov,
				aim_button.disabled,
				aim_button.get_global_rect(),
				_touch_button_debug(controls),
				controls.get("_last_touch_debug"),
			]
		),
	)
	_send_screen_touch(controls, 90, aim_button.get_global_rect().get_center(), false)
	for _frame in 20:
		await process_frame
	_expect(
		not bool(player.call("is_aiming")) and player_camera.fov > rest_fov - 2.0,
		"releasing AIM returns the camera to its follow framing",
	)

	var shots_before_touch_fire := int(main_scene.get("_shots_fired"))
	_send_screen_touch(controls, 70, fire_button.get_global_rect().get_center(), true)
	for _frame in 2:
		await physics_frame
	_expect(
		(
			bool(player.get("_touch_fire_pressed"))
			and int(main_scene.get("_shots_fired")) > shots_before_touch_fire
		),
		"screen touch on FIRE reaches the player and spawns a combat shot",
	)
	_send_screen_touch(controls, 70, fire_button.get_global_rect().get_center(), false)
	_expect(
		not bool(player.get("_touch_fire_pressed")),
		"screen touch release on FIRE clears the player input state",
	)

	player.call("apply_damage", 27.0)
	_expect(
		is_equal_approx(health_bar.value, 73.0) and health_value.text == "73 / 100",
		"taking damage updates the health bar immediately",
	)

	wave_director.call("start_session")
	_expect(
		wave_title.text == "WAVE 01" and wave_enemy_label.text.ends_with("3 LEFT"),
		"starting a wave updates wave number and remaining-enemy count",
	)

	_tap_screen_button(controls, weapon_button, 73)
	_expect(
		(
			player.call("get_current_weapon_name") == "Nova Launcher"
			and weapon_button.text == "NOVA LAUNCHER"
		),
		"touching the weapon button cycles the active weapon and HUD label",
	)

	var skill_enemy := RunnerScene.instantiate() as Node3D
	skill_enemy.set("target_path", NodePath("../../Player"))
	skill_enemy.position = player.global_position + Vector3(0.0, 0.0, -2.0)
	main_scene.get_node("WaveEnemies").add_child(skill_enemy)
	await process_frame
	var health_before_skill := float(skill_enemy.get("current_health"))
	_tap_screen_button(controls, skill_button, 78)
	_expect(
		is_equal_approx(
			float(skill_enemy.get("current_health")),
			health_before_skill - float(player.get("emp_pulse_damage"))
		),
		"EMP skill damages nearby wave enemies",
	)
	_expect(
		(
			float(player.get("_skill_cooldown_remaining")) > 0.0
			and skill_button.disabled
			and skill_button.text.contains("HIT")
		),
		"skill activation starts its cooldown and shows target-hit feedback",
	)
	_expect(
		not bool(player.call("activate_skill")),
		"skill cooldown rejects a duplicate activation",
	)
	skill_enemy.queue_free()
	await process_frame

	var initial_position: Vector3 = player.global_position
	var joystick_touch := InputEventScreenTouch.new()
	joystick_touch.index = 71
	joystick_touch.position = Vector2(controls.size.x * 0.12, controls.size.y * 0.62)
	joystick_touch.pressed = true
	controls.call("_input", joystick_touch)
	var joystick_drag := InputEventScreenDrag.new()
	joystick_drag.index = 71
	joystick_drag.position = joystick_touch.position + Vector2(0.0, -90.0)
	joystick_drag.relative = Vector2(0.0, -90.0)
	controls.call("_input", joystick_drag)
	_expect(
		(Vector2(player.get("_touch_movement")) - Vector2(0.0, -1.0)).length() < 0.02,
		"left-side touch drag maps to forward movement input",
	)
	for _frame in 18:
		await physics_frame
	_expect(
		player.global_position.z < initial_position.z - 0.35,
		"touch movement moves the player through the 3D world",
	)
	var joystick_release := InputEventScreenTouch.new()
	joystick_release.index = 71
	joystick_release.position = joystick_drag.position
	joystick_release.pressed = false
	controls.call("_input", joystick_release)
	_expect(
		Vector2(player.get("_touch_movement")).is_zero_approx(),
		"releasing the movement touch clears the virtual joystick",
	)
	var joystick_origin := Vector2(controls.size.x * 0.12, controls.size.y * 0.62)
	await _test_joystick_vector(
		controls, player, 80, joystick_origin, Vector2(0.0, -90.0), Vector2(0.0, -1.0), "up"
	)
	await _test_joystick_vector(
		controls, player, 81, joystick_origin, Vector2(0.0, 90.0), Vector2(0.0, 1.0), "down"
	)
	await _test_joystick_vector(
		controls, player, 82, joystick_origin, Vector2(-90.0, 0.0), Vector2(-1.0, 0.0), "left"
	)
	await _test_joystick_vector(
		controls, player, 83, joystick_origin, Vector2(90.0, 0.0), Vector2(1.0, 0.0), "right"
	)
	await _test_joystick_vector(
		controls,
		player,
		84,
		joystick_origin,
		Vector2(-90.0, -90.0),
		Vector2(-1.0, -1.0).normalized(),
		"up-left diagonal"
	)
	await _test_joystick_vector(
		controls,
		player,
		85,
		joystick_origin,
		Vector2(90.0, -90.0),
		Vector2(1.0, -1.0).normalized(),
		"up-right diagonal"
	)
	await _test_joystick_vector(
		controls,
		player,
		86,
		joystick_origin,
		Vector2(-90.0, 90.0),
		Vector2(-1.0, 1.0).normalized(),
		"down-left diagonal"
	)
	await _test_joystick_vector(
		controls,
		player,
		87,
		joystick_origin,
		Vector2(90.0, 90.0),
		Vector2(1.0, 1.0).normalized(),
		"down-right diagonal"
	)

	var yaw_pivot: Node3D = player.get_node("CameraRig/YawPivot")
	var yaw_before := yaw_pivot.rotation.y
	var look_touch := InputEventScreenTouch.new()
	look_touch.index = 72
	look_touch.position = Vector2(controls.size.x * 0.82, controls.size.y * 0.58)
	look_touch.pressed = true
	controls.call("_input", look_touch)
	var look_drag := InputEventScreenDrag.new()
	look_drag.index = 72
	look_drag.position = look_touch.position + Vector2(60.0, 0.0)
	look_drag.relative = Vector2(60.0, 0.0)
	controls.call("_input", look_drag)
	_expect(
		not is_equal_approx(yaw_pivot.rotation.y, yaw_before),
		"right-side touch drag rotates the over-the-shoulder camera",
	)
	var look_release := InputEventScreenTouch.new()
	look_release.index = 72
	look_release.position = look_drag.position
	look_release.pressed = false
	controls.call("_input", look_release)

	_send_screen_touch(controls, 74, fire_button.get_global_rect().get_center(), true)
	_expect(bool(player.get("_touch_fire_pressed")), "holding FIRE sets the player fire state")
	_tap_screen_button(controls, pause_button, 75)
	_expect(
		(
			paused
			and not bool(player.get("_touch_fire_pressed"))
			and Vector2(player.get("_touch_movement")).is_zero_approx()
		),
		(
			("pausing clears held touch fire and movement input (paused=%s fire=%s move=%s rect=%s)")
			% [
				paused,
				player.get("_touch_fire_pressed"),
				player.get("_touch_movement"),
				pause_button.get_global_rect(),
			]
		),
	)
	_expect(
		fire_button.disabled and skill_button.disabled,
		"fire and skill are disabled while the run is paused",
	)
	_tap_screen_button(controls, pause_button, 76)
	_expect(
		not paused and String(pause_button.get_meta("aegis_state", "")) == "pause",
		"RESUME restores play input",
	)

	var run_stats: Node = main_scene.get_node("RunStats")
	run_stats.call("start_run")
	run_stats.call("record_elimination", 100, 110)
	_expect(
		status_label.text.contains("Score: 100") and status_label.text.contains("BP earned: 110"),
		"run score and earned Battle Points update on the HUD",
	)
	player.call("apply_damage", 1000.0)
	var results_panel := controls.get("_results_panel") as PanelContainer
	var results_retry_button := controls.get("_results_retry_button") as Button
	_expect(
		(
			results_panel.visible
			and results_retry_button.is_visible_in_tree()
			and not skill_button.visible
		),
		"defeat presents retry and hides combat controls behind results",
	)
	_tap_screen_button(controls, results_retry_button, 77)
	_expect(
		(
			not bool(player.call("is_defeated"))
			and is_equal_approx(health_bar.value, 100.0)
			and not results_panel.visible
			and skill_button.text.contains("READY")
			and not skill_button.disabled
		),
		"touching results RETRY restores the player and returns to the HUD",
	)
	print("Playability/HUD smoke test: %d failure(s)" % _failures)
	main_scene.queue_free()
	await process_frame
	quit(1 if _failures > 0 else 0)


func _test_joystick_vector(
	controls: Control,
	player: Node3D,
	touch_id: int,
	origin: Vector2,
	drag_delta: Vector2,
	expected: Vector2,
	direction_label: String
) -> void:
	player.set("velocity", Vector3.ZERO)
	var start_position := player.global_position
	_send_screen_touch(controls, touch_id, origin, true)
	var drag := InputEventScreenDrag.new()
	drag.index = touch_id
	drag.position = origin + drag_delta
	drag.relative = drag_delta
	controls.call("_input", drag)
	var actual: Vector2 = player.get("_touch_movement")
	_expect(
		actual.distance_to(expected) < 0.02,
		"360° joystick maps %s input correctly" % direction_label,
	)
	for _frame in 8:
		await physics_frame
	var world_delta := Vector2(
		player.global_position.x - start_position.x, player.global_position.z - start_position.z
	)
	_expect(
		world_delta.dot(expected.normalized()) > 0.1,
		"360° joystick moves the player toward %s" % direction_label,
	)
	_send_screen_touch(controls, touch_id, origin + drag_delta, false)
	player.set("velocity", Vector3.ZERO)


func _touch_button_debug(controls: Control) -> String:
	var parts: PackedStringArray = []
	for button in controls.get("_touch_buttons"):
		if not is_instance_valid(button):
			continue
		var rect: Rect2 = button.get_global_rect()
		(
			parts
			. append(
				(
					"%s:%s:(%.0f,%.0f,%.0f,%.0f)"
					% [
						button.name,
						button.is_visible_in_tree(),
						rect.position.x,
						rect.position.y,
						rect.size.x,
						rect.size.y,
					]
				)
			)
		)
	return " ".join(parts)


func _send_screen_touch(controls: Control, touch_id: int, position: Vector2, pressed: bool) -> void:
	var event := InputEventScreenTouch.new()
	event.index = touch_id
	event.position = position
	event.pressed = pressed
	controls.call("_input", event)


func _tap_screen_button(controls: Control, button: Button, touch_id: int) -> void:
	var position := button.get_global_rect().get_center()
	_send_screen_touch(controls, touch_id, position, true)
	_send_screen_touch(controls, touch_id, position, false)


func _expect(condition: bool, message: String) -> void:
	if condition:
		print("PASS: ", message)
	else:
		_failures += 1
		push_error("FAIL: " + message)
