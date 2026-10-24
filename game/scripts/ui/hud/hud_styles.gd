## Layout-dependent panel styles. Kept separate from the HUD facade so menus
## and accessibility settings can change surface opacity without duplicating
## every StyleBox in touch_controls.gd.
class_name HudStyles
extends RefCounted


static func apply(hud) -> void:
	var pad: float = hud._to_layout(10.0)
	var tight: float = hud._to_layout(8.0)
	var fill := Color(AegisTokens.PANEL, AegisTokens.PANEL_ALPHA * hud._hud_opacity)
	hud._health_card.add_theme_stylebox_override(
		"panel", AegisTheme.panel_style(fill, AegisTokens.LINE, 1, AegisTokens.RADIUS, pad)
	)
	hud._wave_card.add_theme_stylebox_override(
		"panel", AegisTheme.panel_style(fill, AegisTokens.LINE, 1, AegisTokens.RADIUS, tight)
	)
	hud._run_card.add_theme_stylebox_override(
		"panel", AegisTheme.panel_style(fill, AegisTokens.LINE, 1, AegisTokens.RADIUS, pad)
	)
	hud._score_chip.add_theme_stylebox_override(
		"panel", AegisTheme.panel_style(fill, AegisTokens.LINE, 1, AegisTokens.RADIUS, tight)
	)
	hud._compact_card.add_theme_stylebox_override(
		"panel", AegisTheme.panel_style(fill, AegisTokens.LINE, 1, AegisTokens.RADIUS, pad)
	)
	hud._help_panel.add_theme_stylebox_override(
		"panel",
		AegisTheme.panel_style(
			Color(AegisTokens.VOID, 0.86), Color(AegisTokens.LINE, 0.9), 1, AegisTokens.RADIUS, pad
		)
	)
	hud._desktop_weapon_card.add_theme_stylebox_override(
		"panel", AegisTheme.panel_style(fill, AegisTokens.LINE, 1, AegisTokens.RADIUS, pad)
	)
	hud._ads_chip.add_theme_stylebox_override(
		"panel", AegisTheme.panel_style(fill, AegisTokens.LINE, 1, AegisTokens.RADIUS, tight)
	)
	hud._pause_panel.add_theme_stylebox_override(
		"panel",
		AegisTheme.panel_style(
			Color(AegisTokens.PANEL, 0.97),
			Color(AegisTokens.LINE_HI, 0.9),
			1,
			AegisTokens.RADIUS,
			hud._to_layout(24.0)
		)
	)
	hud._results_panel.add_theme_stylebox_override(
		"panel",
		AegisTheme.panel_style(
			Color(AegisTokens.PANEL, 0.97),
			Color(AegisTokens.LINE_HI, 0.9),
			1,
			AegisTokens.RADIUS,
			hud._to_layout(24.0)
		)
	)
	if is_instance_valid(hud._health_bar):
		hud._health_bar.custom_minimum_size = Vector2(0.0, hud._to_layout(6.0))
		hud._health_bar.gap_width = maxf(hud._to_layout(2.0), 1.0)
	if is_instance_valid(hud._wave_icon):
		var icon_size: float = hud._to_layout(16.0)
		hud._wave_icon.custom_minimum_size = Vector2(icon_size, icon_size)
	for button in [
		hud._results_retry_button,
		hud._results_explore_button,
		hud._pause_resume_button,
		hud._pause_restart_button,
		hud._pause_settings_button,
	]:
		if is_instance_valid(button):
			button.add_theme_constant_override("icon_max_width", roundi(hud._to_layout(18.0)))


static func apply_fonts(hud) -> void:
	var floor_size: int = hud._minimum_font_size()
	var unit: float = hud._control_unit() * hud._text_scale
	for node in hud.find_children("*", "Label", true, false):
		var label := node as Label
		if label == null or not label.has_meta("aegis_role"):
			continue
		var role := String(label.get_meta("aegis_role"))
		var multiplier := float(label.get_meta("aegis_scale", 1.0))
		var text_size := maxi(
			roundi(float(AegisTheme.type_size(role)) * unit * multiplier), floor_size
		)
		AegisTheme.resize_label(label, role, text_size)
	for node in hud.find_children("*", "Button", true, false):
		var button := node as Button
		if (
			button == null
			or (is_instance_valid(hud._settings_menu) and hud._settings_menu.is_ancestor_of(button))
		):
			continue
		button.add_theme_font_size_override("font_size", floor_size)
		if button == hud._fire_button:
			AegisTheme.resize_button_font(
				button, "title", maxi(roundi(hud._to_layout(18.0)), floor_size)
			)
		elif button == hud._aim_button or button == hud._skill_button:
			AegisTheme.resize_button_font(
				button, "title", maxi(roundi(hud._to_layout(15.0)), floor_size)
			)
		elif button == hud._weapon_button:
			AegisTheme.resize_button_font(
				button, "title", maxi(roundi(hud._to_layout(14.0)), floor_size)
			)
		elif is_instance_valid(hud._armory_panel) and hud._armory_panel.is_ancestor_of(button):
			AegisTheme.resize_button_font(
				button, "title", maxi(roundi(hud._to_layout(15.0)), floor_size)
			)
		elif (
			button == hud._armory_button
			or button == hud._defense_button
			or button == hud._results_retry_button
			or button == hud._results_explore_button
			or button == hud._pause_resume_button
			or button == hud._pause_restart_button
			or button == hud._pause_settings_button
		):
			AegisTheme.resize_button_font(button, "title", maxi(roundi(15.0 * unit), floor_size))
	if is_instance_valid(hud._health_bar):
		hud._health_bar.custom_minimum_size.y = maxf(hud._to_layout(6.0), 3.0)
	# Texture ceilings, not coloured glyph dimensions. The stage-21 WebGL
	# screenshot measured FIRE only 78x59 inside a 120x120 target. The icon's
	# new diagonal drawing and this ceiling must BOTH be checked in pixels.
	var icon_px := maxi(roundi(hud._to_layout(20.0)), 12)
	var icon_button_px := maxf(hud._to_layout(64.0 if hud._touch_mode else 56.0), 32.0)
	var short_touch: bool = hud._portrait and hud._physical_size.y < 750.0
	for icon_button in [hud._pause_button, hud._sound_button]:
		if is_instance_valid(icon_button):
			icon_button.custom_minimum_size = Vector2(icon_button_px, icon_button_px)
	for button in [
		hud._defense_button,
		hud._results_explore_button,
		hud._fire_button,
		hud._weapon_button,
		hud._skill_button,
		hud._aim_button,
		hud._pause_button,
		hud._sound_button,
		hud._emp_chip
	]:
		if is_instance_valid(button):
			var button_icon_px := icon_px
			if button == hud._fire_button:
				button_icon_px = roundi(
					hud._to_layout(180.0 if short_touch else (194.0 if hud._portrait else 170.0))
				)
			elif button == hud._aim_button:
				button_icon_px = roundi(
					hud._to_layout(102.0 if short_touch else (116.0 if hud._portrait else 104.0))
				)
			elif button == hud._skill_button:
				button_icon_px = roundi(
					hud._to_layout(100.0 if short_touch else (112.0 if hud._portrait else 104.0))
				)
			elif button == hud._weapon_button:
				button_icon_px = roundi(
					hud._to_layout(106.0 if short_touch else (116.0 if hud._portrait else 104.0))
				)
			elif button == hud._pause_button:
				button_icon_px = roundi(hud._to_layout(48.0 if hud._touch_mode else 40.0))
			elif button == hud._sound_button:
				button_icon_px = roundi(hud._to_layout(32.0 if hud._touch_mode else 24.0))
			button.add_theme_constant_override("icon_max_width", button_icon_px)
	if is_instance_valid(hud._skill_ring):
		hud._skill_ring.stroke = hud._to_layout(2.2)
	if is_instance_valid(hud._skill_cooldown_label):
		hud._skill_cooldown_label.offset_left = hud._to_layout(2.0)
		hud._skill_cooldown_label.offset_right = -hud._to_layout(2.0)
		hud._skill_cooldown_label.offset_top = -hud._to_layout(21.0)
		hud._skill_cooldown_label.offset_bottom = -hud._to_layout(2.0)
