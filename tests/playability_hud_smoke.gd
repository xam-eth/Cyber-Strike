extends SceneTree

const MainScene = preload("res://scenes/main.tscn")
const RunnerScene = preload("res://scenes/enemies/runner.tscn")

var _failures: int = 0


func _initialize() -> void:
	call_deferred("_run_smoke_test")


func _run_smoke_test() -> void:
	# Audio and HUD settings persist in user://; other runs must not alter
	# this geometry/interaction smoke's default layout or initial mute state.
	AegisPreferences.write(AegisPreferences.defaults())
	Sfx.set_muted(false)
	var main_scene := MainScene.instantiate()
	main_scene.set("start_wave_session_on_ready", false)
	main_scene.get_node("ProgressionService").set("profile_path", "")
	root.add_child(main_scene)
	await process_frame

	var player: Node3D = main_scene.get_node("Player")
	var wave_director: Node = main_scene.get_node("WaveDirector")
	var controls: Control = main_scene.get_node("HUD/TouchControls")
	var health_bar := controls.get("_health_bar") as ProgressBar
	var health_value := controls.get("_health_value_label") as Label
	var wave_title := controls.get("_wave_title_label") as Label
	var wave_enemy_label := controls.get("_wave_enemy_label") as Label
	var defense_button := controls.get("_defense_button") as Button
	var status_label := controls.get("_status_label") as Label
	var help_label := controls.get("_help_label") as Label
	var fire_button := controls.get("_fire_button") as Button
	var weapon_button := controls.get("_weapon_button") as Button
	var skill_button := controls.get("_skill_button") as Button
	var pause_button := controls.get("_pause_button") as Button
	var sound_button := controls.get("_sound_button") as Button
	var compact_card := controls.get("_compact_card") as PanelContainer
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
		(
			wave_title.text == "EXPLORE THE FRONTIER"
			and wave_enemy_label.text.contains("SAFE ZONE")
			and defense_button.visible
			and not controls.get("_run_card").visible
			and int(wave_director.get("current_wave")) == 0
		),
		"Explore starts safe, with a visible start action and no scoreboard",
	)
	var launch_style := defense_button.get_theme_stylebox("normal") as StyleBoxFlat
	_expect(
		(
			launch_style != null
			and launch_style.bg_color.r < 0.15
			and launch_style.border_width_left >= 4
			and launch_style.border_width_right == 0
			and defense_button.icon != null
		),
		"START stays legible and tappable without a solid amber rectangle covering the world",
	)
	# In portrait the optional help plate must sit below the objective and
	# Defense button, leaving the centre of the screen unobstructed.
	controls.call("apply_layout_for_size", Vector2(390.0, 844.0), 1.0)
	# Containers recompute their rects on the next frame; reading the rects
	# immediately measures the previous layout and reports a false overlap.
	await process_frame
	var defense_bottom := defense_button.get_global_rect().end.y
	var help_top := help_label.get_global_rect().position.y
	_expect(
		help_top >= defense_bottom + 7.0 and not compact_card.visible,
		"portrait help sits below the start action; the run-data strip stays hidden",
	)
	_expect(
		(
			help_label.text.contains("LEFT STICK")
			and help_label.text.contains("HOLD AIM")
			and help_label.text.contains("EMP")
			and help_label.text.contains("SWAP")
		),
		"portrait help explains the mobile controls",
	)
	controls.call("apply_layout_for_size", Vector2(1280.0, 720.0), 1.0)
	_expect(
		(
			help_label.autowrap_mode == TextServer.AUTOWRAP_OFF
			and help_label.clip_text
			and help_label.text.contains("B DEFENSE")
			and help_label.text.contains("U ARMORY")
			and help_label.text.contains("WASD")
		),
		"wide help explains desktop bindings without growing over controls",
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
	var weapon_readout := controls.get("_touch_ammo_chip").get("weapon_label") as Label
	_expect(
		(
			fire_button.text.is_empty()
			and fire_button.icon != null
			and weapon_button.text.is_empty()
			and weapon_button.icon != null
			and String(weapon_button.get_meta("aegis_state", "")) == "armory"
			and weapon_readout.text == "PULSE"
			and skill_button.text.is_empty()
			and skill_button.icon != null
			and not skill_button.disabled
			and pause_button.text.is_empty()
			and pause_button.icon != null
			and String(pause_button.get_meta("aegis_state", "")) == "pause"
		),
		"combat actions use distinct icons; weapon/ammo data are outside their hit targets",
	)
	# Quick mute and the settings screen must share the same live audio state.
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
	# The objective is below the vitals on a phone; run score is reserved for
	# pause/results instead of spilling over the play area.
	controls.call("apply_layout_for_size", Vector2(390.0, 844.0), 1.0)
	_expect(
		(
			not compact_card.visible
			and not controls.get("_run_card").visible
			and wave_enemy_label.visible
			and wave_enemy_label.text.contains("SAFE ZONE")
			and defense_button.visible
		),
		"portrait shows a safe Explore objective, not a persistent data table",
	)
	# The web build keeps a 1280-unit logical canvas in portrait, so on a phone
	# the whole HUD used to render at ~30% of its designed size. The layout must
	# size itself from the physical window instead: a 390 px wide phone therefore
	# gets portrait body text (~11 px on glass), not 3 px.
	# As in the real exported portrait canvas, the HUD must span *both* axes
	# after the physical->logical stretch. Otherwise bottom-anchored actions
	# sit above the simulated screen and overlap checks judge a fictitious HUD.
	controls.size = Vector2(390.0 / 0.3047, 844.0 / 0.3047)
	controls.call("apply_layout_for_size", Vector2(390.0, 844.0), 0.3047)
	# One frame so the containers settle at the new font sizes before measuring.
	await process_frame
	await process_frame
	var portrait_font := float(pause_button.get_theme_font_size("font_size")) * 0.3047
	var portrait_body_font := float(wave_enemy_label.get_theme_font_size("font_size")) * 0.3047
	# Opening/refreshing the armory must not reset its action text to Godot's
	# unscaled 13-unit default (~4 physical px on a portrait WASM canvas).
	var armory := controls.get("_armory_panel") as Control
	armory.call("refresh_profile", 0, 0, {"pulse_rifle": true}, &"pulse_rifle")
	var buy_button := armory.get("_weapon_buttons")[1] as Button
	var buy_font := float(buy_button.get_theme_font_size("font_size")) * 0.3047
	_expect(buy_font >= 14.5, "portrait armory UNLOCK/EQUIP text stays >=15 physical px")
	var vitals_card := controls.get("_health_card") as Control
	var wave_card := controls.get("_wave_card") as Control
	var system_row := controls.get("_system_row") as Control
	var rail_gap := float(controls.call("_to_layout", 8.0))
	_expect(
		(
			(
				(
					wave_card.get_global_rect().position.y
					>= vitals_card.get_global_rect().end.y + rail_gap - 1.0
				)
				and (
					wave_card.get_global_rect().position.y
					>= (
						system_row.get_global_rect().end.y
						+ float(controls.call("_to_layout", 3.0))
						- 1.0
					)
				)
			)
			and (
				defense_button.get_global_rect().position.y
				>= wave_card.get_global_rect().end.y + rail_gap - 1.0
			)
		),
		"portrait objective and start action stack below vitals without overlap",
	)
	var portrait_gap := float(controls.call("_to_layout", 5.9))
	var feedback_panel := controls.get("_feedback_panel") as Control
	var ammo_panel := controls.get("_touch_ammo_chip") as Control
	_expect(
		(
			not feedback_panel.get_global_rect().intersects(weapon_button.get_global_rect())
			and not feedback_panel.get_global_rect().intersects(ammo_panel.get_global_rect())
			and not feedback_panel.get_global_rect().intersects(skill_button.get_global_rect())
			and not feedback_panel.get_global_rect().intersects(aim_button.get_global_rect())
		),
		"portrait Explore feedback does not hide the SWAP/ammo dock or EMP",
	)
	feedback_panel.call("show_message", "EMP PULSE · NO TARGETS")
	_expect(
		(controls.get("_feedback_panel").get("_message_label") as Label).text == "NO\nTARGETS",
		"portrait Explore feedback remains legible in the slim lane between real buttons",
	)
	feedback_panel.call("clear_message")
	var portrait_skill_ring := controls.get("_skill_ring") as Control
	_expect(
		(
			portrait_skill_ring.visible
			and (
				(
					portrait_skill_ring.get_global_rect().get_center().distance_to(
						skill_button.get_global_rect().get_center()
					)
					* 0.3047
				)
				< 2.0
			)
		),
		"portrait EMP cooldown ring stays visibly centred around its icon",
	)
	_expect(
		(
			weapon_button.get_global_rect().size.y * 0.3047 >= 122.0
			and weapon_button.get_global_rect().size.x * 0.3047 >= 122.0
			and weapon_button.get_global_rect().get_center().x * 0.3047 < 80.0
			and (
				weapon_button.get_global_rect().position.y
				>= defense_button.get_global_rect().end.y + portrait_gap
			)
			and fire_button.get_global_rect().size.x * 0.3047 >= 200.0
			and fire_button.get_global_rect().size.y * 0.3047 >= 200.0
			and fire_button.get_theme_constant("icon_max_width") * 0.3047 >= 190.0
			and fire_button.expand_icon
			and aim_button.get_global_rect().size.x * 0.3047 >= 122.0
			and aim_button.get_theme_constant("icon_max_width") * 0.3047 >= 113.0
			and skill_button.get_global_rect().size.x * 0.3047 >= 122.0
			and skill_button.get_theme_constant("icon_max_width") * 0.3047 >= 110.0
			and pause_button.get_global_rect().size.x * 0.3047 >= 62.0
			and pause_button.get_global_rect().size.y * 0.3047 >= 62.0
			and not weapon_button.get_global_rect().grow(portrait_gap).intersects(
				aim_button.get_global_rect()
			)
			and not fire_button.get_global_rect().grow(portrait_gap).intersects(
				aim_button.get_global_rect()
			)
			and not fire_button.get_global_rect().grow(portrait_gap).intersects(
				skill_button.get_global_rect()
			)
		),
		"portrait FIRE/ADS/EMP finger targets clear the upper-left SWAP dock and each other",
	)
	_expect(
		(
			is_equal_approx(float(controls.get("_ui_scale")), 0.64)
			and is_equal_approx(float(controls.get("_stretch")), 0.3047)
			# The promise is about pixels on the glass, not about the canvas: the
			# web build keeps a 1280-unit logical canvas in portrait, so a 390 px
			# phone renders every logical pixel at ~0.3x.
			and portrait_font >= 12.5
			and portrait_body_font >= 12.5
			and weapon_button.get_theme_constant("icon_max_width") * 0.3047 >= 113.0
			and pause_button.get_theme_constant("icon_max_width") * 0.3047 >= 46.0
			and wave_card.size.y >= wave_enemy_label.get_combined_minimum_size().y
			and defense_button.get_global_rect().size.y * 0.3047 >= 55.0
		),
		(
			(
				"portrait HUD text stays >=13 physical px (%.1f / %.1f), "
				+ "objective and start control fit (%.0f >= %.0f)"
			)
			% [
				portrait_body_font,
				portrait_font,
				wave_card.size.y,
				wave_enemy_label.get_combined_minimum_size().y,
			]
		),
	)
	# Press the NEW strip left of the old 160px FIRE rect, not its centre.
	# Rect-size assertions alone would miss a stale dispatcher/hitbox.
	var fire_edge: Vector2 = fire_button.get_global_rect().get_center()
	fire_edge.x = fire_button.get_global_rect().position.x + float(controls.call("_to_layout", 5.0))
	_expect(
		controls.call("_find_touch_button", fire_edge) == fire_button,
		"the physically expanded FIRE rim belongs to the input dispatcher",
	)
	_send_screen_touch(controls, 96, fire_edge, true)
	_expect(bool(player.get("_touch_fire_pressed")), "the newly expanded FIRE rim actually fires")
	_send_screen_touch(controls, 96, fire_edge, false)
	_expect(
		not bool(player.get("_touch_fire_pressed")), "releasing the expanded FIRE rim stops fire"
	)
	var pause_edge: Vector2 = pause_button.get_global_rect().get_center()
	pause_edge.x = (
		pause_button.get_global_rect().position.x + float(controls.call("_to_layout", 2.0))
	)
	_expect(
		controls.call("_find_touch_button", pause_edge) == pause_button,
		"the 64px Pause face extends beyond the old 56px hitbox",
	)
	controls.call("_set_play_phase", "defense")
	_expect(
		(
			not feedback_panel.get_global_rect().intersects(wave_card.get_global_rect())
			and not feedback_panel.get_global_rect().intersects(weapon_button.get_global_rect())
			and feedback_panel.get_global_rect().end.y < weapon_button.get_global_rect().position.y
		),
		"portrait Defense feedback moves into the vacated START row, clear of SWAP",
	)
	controls.call("_set_play_phase", "explore")
	# A 375x667 phone must gain REAL hit area without pushing EMP into the
	# Explore action row. Do not accept a larger painted icon in the old rect.
	const SHORT_STRETCH := 375.0 / 1280.0
	controls.size = Vector2(375.0 / SHORT_STRETCH, 667.0 / SHORT_STRETCH)
	controls.call("apply_layout_for_size", Vector2(375.0, 667.0), SHORT_STRETCH)
	await process_frame
	var short_gap := float(controls.call("_to_layout", 5.0))
	_expect(
		(
			fire_button.get_global_rect().size.x * SHORT_STRETCH >= 184.0
			and fire_button.get_global_rect().size.y * SHORT_STRETCH >= 184.0
			and aim_button.get_global_rect().size.x * SHORT_STRETCH >= 106.0
			and skill_button.get_global_rect().size.x * SHORT_STRETCH >= 106.0
			and weapon_button.get_global_rect().size.x * SHORT_STRETCH >= 110.0
			and pause_button.get_global_rect().size.x * SHORT_STRETCH >= 62.0
			and not feedback_panel.get_global_rect().intersects(skill_button.get_global_rect())
			and not feedback_panel.get_global_rect().intersects(ammo_panel.get_global_rect())
			and (
				(
					(
						skill_button.get_global_rect().position.y
						- (controls.get("_armory_button") as Control).get_global_rect().end.y
					)
					* SHORT_STRETCH
				)
				>= 6.0
			)
			and not fire_button.get_global_rect().grow(short_gap).intersects(
				aim_button.get_global_rect()
			)
			and not aim_button.get_global_rect().grow(short_gap).intersects(
				skill_button.get_global_rect()
			)
			and (
				(
					portrait_skill_ring.get_global_rect().get_center().distance_to(
						skill_button.get_global_rect().get_center()
					)
					* SHORT_STRETCH
				)
				< 2.0
			)
		),
		"short portrait enlarges button hit rects and keeps EMP below Explore actions",
	)
	# The browser's canvas_items layout spans 844 / .541667 logical units,
	# not the headless runner's default 1280. Resize the HUD rect as well as
	# overriding physical pixels so the right rail can actually fit on-screen.
	controls.size = Vector2(844.0 / 0.541667, 390.0 / 0.541667)
	controls.call("apply_layout_for_size", Vector2(844.0, 390.0), 0.541667)
	await process_frame
	var landscape_gap := float(controls.call("_to_layout", 5.9))
	var emp_center: Vector2 = skill_button.get_global_rect().get_center()
	var ring := controls.get("_skill_ring") as Control
	_expect(
		(
			weapon_button.get_global_rect().size.y * 0.541667 >= 110.0
			and weapon_button.get_global_rect().size.x * 0.541667 >= 110.0
			and fire_button.get_global_rect().size.x * 0.541667 >= 178.0
			and fire_button.get_global_rect().size.y * 0.541667 >= 178.0
			and aim_button.get_global_rect().size.x * 0.541667 >= 110.0
			and skill_button.get_global_rect().size.x * 0.541667 >= 110.0
			and emp_center.distance_to(ring.get_global_rect().get_center()) * 0.541667 < 2.0
			and not system_row.get_global_rect().intersects(aim_button.get_global_rect())
			and not system_row.get_global_rect().intersects(weapon_button.get_global_rect())
			and not weapon_button.get_global_rect().grow(landscape_gap).intersects(
				aim_button.get_global_rect()
			)
			and not fire_button.get_global_rect().grow(landscape_gap).intersects(
				skill_button.get_global_rect()
			)
			and not fire_button.get_global_rect().grow(landscape_gap).intersects(
				aim_button.get_global_rect()
			)
		),
		"landscape FIRE 180, AIM/EMP/SWAP 112px hit rects; ring frames EMP",
	)
	var landscape_fire_edge := (
		fire_button.get_global_rect().position
		+ Vector2(float(controls.call("_to_layout", 5.0)), float(controls.call("_to_layout", 8.0)))
	)
	var landscape_aim_edge := (
		aim_button.get_global_rect().position
		+ Vector2(float(controls.call("_to_layout", 4.0)), float(controls.call("_to_layout", 7.0)))
	)
	_expect(
		(
			controls.call("_find_touch_button", landscape_fire_edge) == fire_button
			and controls.call("_find_touch_button", landscape_aim_edge) == aim_button
		),
		"landscape FIRE and ADS new border pixels are actual touch targets",
	)
	var help_plate := controls.get("_help_panel") as Control
	var armory_entry := controls.get("_armory_button") as Control
	var ammo_chip := controls.get("_touch_ammo_chip") as Control
	_expect(
		(
			help_plate.get_global_rect().size.y * 0.541667 < 65.0
			and help_label.text.contains("STICK MOVE")
			and help_label.text.contains("AIM")
			and help_label.text.contains("EMP")
			and help_label.text.contains("SWAP")
			and not help_plate.visible
			and not feedback_panel.get_global_rect().intersects(
				(controls.get("_health_card") as Control).get_global_rect()
			)
			and not feedback_panel.get_global_rect().intersects(
				(controls.get("_system_row") as Control).get_global_rect()
			)
			and not feedback_panel.get_global_rect().intersects(weapon_button.get_global_rect())
			and not ammo_chip.get_global_rect().grow(landscape_gap).intersects(
				skill_button.get_global_rect()
			)
			and (
				(
					(ammo_chip.get_global_rect().position.y - armory_entry.get_global_rect().end.y)
					* 0.541667
				)
				>= 10.0
			)
			and not (controls.get("_wave_state_label") as Label).visible
			and not controls.get("_run_card").visible
		),
		(
			(
				"landscape ammo clears Armory, short-screen hint stays hidden: canvas=%s objective=%s "
				+ "help=%s armory=%s swap=%s font=%d text=%s state=%s"
			)
			% [
				controls.size,
				wave_card.get_global_rect(),
				help_plate.get_global_rect(),
				armory_entry.get_global_rect(),
				weapon_button.get_global_rect(),
				help_label.get_theme_font_size("font_size"),
				help_label.text,
				(controls.get("_wave_state_label") as Label).visible,
			]
		),
	)
	# 667x375 would put the old top Armory entry under the enlarged SWAP
	# face. On compact landscape SWAP opens Armory in safe Explore instead.
	const COMPACT_STRETCH := 667.0 / 1280.0
	controls.size = Vector2(667.0 / COMPACT_STRETCH, 375.0 / COMPACT_STRETCH)
	controls.call("apply_layout_for_size", Vector2(667.0, 375.0), COMPACT_STRETCH)
	await process_frame
	_expect(
		(
			not armory_entry.visible
			and weapon_button.visible
			and String(weapon_button.get_meta("aegis_state", "")) == "armory"
			and weapon_button.tooltip_text.contains("Open Armory")
			and fire_button.get_global_rect().size.x * COMPACT_STRETCH >= 178.0
			and not feedback_panel.get_global_rect().intersects(skill_button.get_global_rect())
			and not feedback_panel.get_global_rect().intersects(weapon_button.get_global_rect())
			and (
				(controls.get("_feedback_panel").get("_message_label") as Label).text
				== "NO TARGETS"
			)
		),
		(
			(
				"compact landscape preserves Armory and a free status lane: entry=%s weapon=%s "
				+ "state=%s tooltip=%s fire=%s feedback=%s EMP=%s SWAP=%s text=%s"
			)
			% [
				armory_entry.visible,
				weapon_button.visible,
				weapon_button.get_meta("aegis_state", ""),
				weapon_button.tooltip_text,
				fire_button.get_global_rect(),
				feedback_panel.get_global_rect(),
				skill_button.get_global_rect(),
				weapon_button.get_global_rect(),
				(controls.get("_feedback_panel").get("_message_label") as Label).text,
			]
		),
	)
	_tap_screen_button(controls, weapon_button, 94)
	_expect(armory.visible and paused, "compact SWAP face opens Armory in Explore")
	main_scene.call("_close_armory")
	_expect(not paused, "closing compact Armory resumes safe Explore")
	controls.size = Vector2(1280.0, 720.0)
	controls.call("apply_layout_for_size", Vector2(1280.0, 720.0), 1.0)
	_expect(
		(
			not compact_card.visible
			and not controls.get("_run_card").visible
			and wave_enemy_label.visible
		),
		"desktop retains the left-side objective without the run-data table",
	)
	_expect(
		not help_label.is_visible_in_tree(),
		"play opens without a large control overlay obscuring the world",
	)
	controls.call("show_help")
	_expect(help_label.is_visible_in_tree(), "controls can be displayed explicitly")
	controls.call("hide_help")
	_expect(not help_label.is_visible_in_tree(), "controls can be dismissed")
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
		(
			is_instance_valid(aim_button)
			and aim_button.text.is_empty()
			and aim_button.icon != null
			and aim_button.tooltip_text.contains("aim down sights")
		),
		"ADS uses an optic glyph and retains a discoverable help description",
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

	# The first wave's slim Runner can sit ~18 physical pixels off the reticle;
	# a real thumb covers that offset. Touch assist must use a visible collider,
	# must never select the training dummy, and must stop on release.
	var screen_center := player_camera.get_viewport().get_visible_rect().size * 0.5
	var visible_target := player_camera.project_position(screen_center + Vector2(18.0, 0.0), 5.5)
	var soft_lock_runner := RunnerScene.instantiate() as Node3D
	soft_lock_runner.set("target_path", NodePath("../../Player"))
	soft_lock_runner.position = visible_target - Vector3.UP
	main_scene.get_node("WaveEnemies").add_child(soft_lock_runner)
	# The fixture checks targeting geometry, not melee. Keep its collider alive
	# but freeze AI so it cannot change the baseline health assertion below.
	soft_lock_runner.set_physics_process(false)
	await physics_frame
	player.call("set_touch_fire_pressed", true)
	var soft_lock_point: Vector3 = player.call("_touch_assisted_aim_point", screen_center)
	_expect(
		(
			soft_lock_point.distance_to(soft_lock_runner.global_position + Vector3.UP) < 0.3
			and bool(controls.get("_soft_lock"))
		),
		"nearby visible Runner gets a small touch-only shot correction and cyan reticle",
	)
	player.call("set_touch_fire_pressed", false)
	controls.set("_soft_lock", false)
	_expect(
		player.call("_touch_assisted_aim_point", screen_center) == Vector3.ZERO,
		"releasing FIRE removes soft lock; idle exploration never magnetizes shots",
	)
	soft_lock_runner.queue_free()
	await physics_frame

	var shots_before_touch_fire := int(main_scene.get("_shots_fired"))
	var camera_before_fire := player_camera.global_position
	_send_screen_touch(controls, 70, fire_button.get_global_rect().get_center(), true)
	for _frame in 2:
		await physics_frame
	_expect(
		(
			bool(player.get("_touch_fire_pressed"))
			and bool(fire_button.get("_held"))
			and int(main_scene.get("_shots_fired")) > shots_before_touch_fire
			and float(controls.get("_fire_flash_remaining")) > 0.0
		),
		"screen touch on FIRE reaches the player and spawns a combat shot",
	)
	_expect(
		(
			not bool(player.call("is_aiming"))
			and player_camera.global_position.distance_to(camera_before_fire) < 0.4
		),
		"hip-fire recoil never teleports the SpringArm camera into the hero",
	)
	_send_screen_touch(controls, 70, fire_button.get_global_rect().get_center(), false)
	_expect(
		not bool(player.get("_touch_fire_pressed")) and not bool(fire_button.get("_held")),
		"screen touch release on FIRE clears input and the pressed glyph rim",
	)

	player.call("apply_damage", 27.0)
	_expect(
		is_equal_approx(health_bar.value, 73.0) and health_value.text == "73 / 100",
		"taking damage updates the health bar immediately",
	)

	wave_director.call("start_session")
	_expect(
		wave_title.text == "WAVE 01" and wave_enemy_label.text.contains("2 LEFT · 0 KO · +0 BP"),
		"starting a wave shows the objective and earned BP while fighting",
	)

	var progression := main_scene.get_node("ProgressionService") as ProgressionService
	progression.balance = 120
	_expect(progression.unlock_weapon(&"nova_launcher"), "earning BP enables a Nova unlock")
	_expect(
		(
			String(weapon_button.get_meta("aegis_state", "")) == "swap"
			and weapon_button.tooltip_text.contains("Tap to swap")
		),
		"unlock changes the weapon glyph from Armory to SWAP",
	)
	_tap_screen_button(controls, weapon_button, 73)
	_expect(
		player.call("get_current_weapon_name") == "Nova Launcher" and weapon_readout.text == "NOVA",
		"touching SWAP changes the actual weapon and adjacent readout",
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
			and skill_button.text.is_empty()
			and (controls.get("_skill_cooldown_label") as Label).text.ends_with("s")
			and (controls.get("_feedback_panel").get("_message_label") as Label).text.contains(
				"1 TARGET"
			)
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
	var joystick_origin: Vector2 = controls.get("_joystick_center")
	var outside_ring := joystick_origin - Vector2(0.0, 180.0)
	_send_screen_touch(controls, 93, outside_ring, true)
	_expect(
		int(controls.get("_move_touch_id")) == -1,
		"left-side taps outside the fixed joystick do not move the player",
	)
	_send_screen_touch(controls, 93, outside_ring, false)
	var joystick_touch := InputEventScreenTouch.new()
	joystick_touch.index = 71
	joystick_touch.position = joystick_origin
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
	# A right-edge swipe now correctly hits the larger FIRE plate. Exercise
	# camera look in the open aiming lane just to its left instead.
	look_touch.position = Vector2(controls.size.x * 0.58, controls.size.y * 0.66)
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
	var pause_panel := controls.get("_pause_panel") as PanelContainer
	var resume_button := controls.get("_pause_resume_button") as Button
	var restart_button := controls.get("_pause_restart_button") as Button
	var settings_button := controls.get("_pause_settings_button") as Button
	await process_frame
	_expect(
		(
			(
				settings_button.get_theme_constant("icon_max_width")
				<= float(controls.call("_to_layout", 24.0))
			)
			and settings_button.get_global_rect().end.y <= pause_panel.get_global_rect().end.y + 1.0
		),
		"settings icon stays small and every pause action fits inside its card",
	)
	_expect(
		(
			pause_panel.is_visible_in_tree()
			and resume_button.is_visible_in_tree()
			and restart_button.is_visible_in_tree()
			and restart_button.text == "FINISH RUN · RESULTS"
			and (controls.get("_pause_stats_label") as Label).text.contains("SCORE")
		),
		"Defense pause shows score, RESUME, and an explicit Finish Run to Results",
	)
	_expect(resume_button.has_focus(), "pause focuses RESUME by default")
	_tap_screen_button(controls, resume_button, 76)
	_expect(
		(
			not paused
			and not pause_panel.visible
			and String(pause_button.get_meta("aegis_state", "")) == "pause"
			and pause_button.icon == AegisTheme.icon("pause", true)
		),
		"RESUME restores the filled Pause glyph rather than an outline 00",
	)
	_tap_screen_button(controls, pause_button, 95)
	var escape_key := InputEventKey.new()
	escape_key.keycode = KEY_ESCAPE
	escape_key.physical_keycode = KEY_ESCAPE
	escape_key.pressed = true
	controls.call("_input", escape_key)
	_expect(
		not paused and not pause_panel.visible,
		"ESC resumes from a paused tree even when the gameplay node is inactive",
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
			not results_panel.visible
			and str(player.get_node("VisualRoot").call("current_clip")) == "death"
			and wave_director.call("get_active_enemies").is_empty()
		),
		"fatal Defense damage shows the Blender collapse without a Results scrim or live AI",
	)
	main_scene.call("_process", 0.75)
	_expect(not results_panel.visible, "Results do not cut off the middle of the death clip")
	main_scene.call("_process", 0.9)
	_expect(not results_panel.visible, "the final death pose survives its first render frame")
	for _frame in 10:
		await process_frame
	_expect(
		(
			results_panel.visible
			and results_retry_button.is_visible_in_tree()
			and not skill_button.visible
		),
		"after the collapse, defeat presents retry and hides combat controls behind results",
	)
	_tap_screen_button(controls, results_retry_button, 77)
	_expect(
		(
			not bool(player.call("is_defeated"))
			and is_equal_approx(health_bar.value, 100.0)
			and not results_panel.visible
			and skill_button.text.is_empty()
			and not (controls.get("_skill_cooldown_label") as Label).visible
			and not skill_button.disabled
		),
		"touching results RETRY restores the player and returns to the HUD",
	)
	# The escape hatch must clear every wave enemy and return to safe Explore,
	# never quietly start another Defense run after the pause closes.
	_tap_screen_button(controls, pause_button, 91)
	_tap_screen_button(controls, restart_button, 92)
	_expect(
		(
			not paused
			and not pause_panel.visible
			and not player.call("is_defeated")
			and is_equal_approx(health_bar.value, 100.0)
			and wave_title.text == "EXPLORE THE FRONTIER"
			and int(wave_director.get("current_wave")) == 0
		),
		"CANCEL DEFENSE during preparation unpauses and restores safe Explore",
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
