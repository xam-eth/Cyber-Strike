## Geometry for the three HUD layouts. Kept out of touch_controls.gd so the
## runtime facade stays readable and each platform layout can be reviewed (and
## tuned on a device) on its own.
##
## Every function takes the live HUD as an untyped host: typing it as
## TouchControls would create a cyclic script reference, and the HUD is the only
## caller. Positions are expressed in physical design pixels and converted with
## the host's `_to_layout()` so the same numbers work at 390 px and at 1280 px.
class_name HudLayout
extends RefCounted


static func desktop(hud) -> void:
	var unit: float = hud._control_unit()
	var inset := 20.0 * unit
	_place_top_bar(hud, inset, hud._top_inset, 64.0 * unit)
	_place_in_top_bar(hud._health_card, 0, 0, 0, 0, Rect2(0, 0, 268.0 * unit, 64.0 * unit))
	_place_wave(hud, inset, 44.0 * unit, 268.0 * unit, 300.0 * unit, 96.0 * unit)
	_place_in_top_bar(hud._system_row, 1, 0, 1, 0, Rect2(-96.0 * unit, 0, 96.0 * unit, 44.0 * unit))
	_place(
		hud._score_chip,
		1,
		0,
		1,
		0,
		Rect2(-inset - 184.0 * unit, hud._top_inset + 72.0 * unit, 184.0 * unit, 30.0 * unit)
	)
	_place(
		hud._run_card,
		0,
		1,
		0,
		1,
		Rect2(inset, -(inset + 28.0 * unit + 76.0 * unit), 320.0 * unit, 76.0 * unit)
	)
	_place(
		hud._desktop_weapon_card,
		1,
		1,
		1,
		1,
		Rect2(-inset - 268.0 * unit, -inset - 76.0 * unit, 268.0 * unit, 76.0 * unit)
	)
	var chip_bottom := -inset - 76.0 * unit - 8.0 * unit - 36.0 * unit
	_place(
		hud._emp_chip,
		1,
		1,
		1,
		1,
		Rect2(-inset - 172.0 * unit, chip_bottom, 172.0 * unit, 36.0 * unit)
	)
	_place(
		hud._ads_chip,
		1,
		1,
		1,
		1,
		Rect2(
			-inset - 172.0 * unit - 8.0 * unit - 76.0 * unit, chip_bottom, 76.0 * unit, 36.0 * unit
		)
	)
	_place(
		hud._desktop_hint, 0, 1, 0, 1, Rect2(inset, -inset - 20.0 * unit, 640.0 * unit, 18.0 * unit)
	)

	hud._show_top_wave_details(true)
	hud._compact_card.visible = false
	hud._run_card.visible = true
	hud._score_chip.visible = true
	hud._sound_button.visible = true
	hud._wave_icon.visible = true
	_place_help(hud, inset, hud._top_inset + 64.0 * unit + 8.0 * unit, 560.0 * unit, 64.0 * unit)
	_place_compact(hud, inset, 0.0, false)


static func touch_portrait(hud) -> void:
	var edge: float = hud._to_layout(12.0)
	var bar_height: float = hud._to_layout(48.0)
	_place_top_bar(hud, edge, hud._top_inset, bar_height)
	_place_in_top_bar(hud._health_card, 0, 0, 0, 0, Rect2(0, 0, hud._to_layout(168.0), bar_height))
	_place_wave(
		hud,
		edge,
		bar_height,
		hud._to_layout(168.0),
		hud._to_layout(88.0),
		hud._to_layout(44.0 if hud._narrow else 96.0)
	)
	# The sound control is hidden on phones, so the row only needs one target
	# there; on a wide touch screen both buttons must fit side by side.
	var system_width: float = hud._to_layout(44.0 if hud._narrow else 96.0)
	_place_in_top_bar(
		hud._system_row, 1, 0, 1, 0, Rect2(-system_width, 0, system_width, bar_height)
	)

	_place_button(hud, hud._fire_button, 18.0, 50.0, 92.0, 92.0)
	_place_button(hud, hud._aim_button, 36.0, 176.0, 56.0, 56.0)
	_place_button(hud, hud._skill_button, 130.0, 116.0, 56.0, 56.0)
	_place_button(hud, hud._weapon_button, 92.0, 208.0, 132.0, 40.0)
	_place(
		hud._skill_ring,
		1,
		1,
		1,
		1,
		Rect2(
			-hud._to_layout(125.0),
			-hud._to_layout(111.0),
			hud._to_layout(66.0),
			hud._to_layout(66.0)
		)
	)
	_place(
		hud._score_chip,
		1,
		0,
		1,
		0,
		Rect2(
			-edge - hud._to_layout(184.0),
			hud._top_inset + bar_height + hud._to_layout(8.0),
			hud._to_layout(184.0),
			hud._to_layout(30.0)
		)
	)

	hud._joystick_center = Vector2(hud._to_layout(84.0), hud.size.y - hud._to_layout(106.0))
	hud._joystick_radius = hud._to_layout(64.0)

	hud._show_top_wave_details(false)
	hud._run_card.visible = false
	hud._score_chip.visible = false
	hud._sound_button.visible = false
	hud._wave_icon.visible = false
	var compact_top: float = hud._top_inset + bar_height + hud._to_layout(8.0)
	var compact_height: float = _place_compact(hud, edge, compact_top, true)
	_place_help(
		hud,
		edge,
		compact_top + compact_height + hud._to_layout(8.0),
		minf(hud._to_layout(342.0), hud.size.x - edge * 2.0),
		hud._help_block_height(5)
	)
	if not hud._touch_mode:
		_place(
			hud._desktop_hint,
			0,
			1,
			0,
			1,
			Rect2(edge, -edge - hud._to_layout(18.0), hud.size.x - edge * 2.0, hud._to_layout(18.0))
		)


static func touch_landscape(hud) -> void:
	var edge: float = hud._to_layout(44.0)
	var bar_height: float = hud._to_layout(44.0)
	_place_top_bar(hud, edge, hud._top_inset, bar_height)
	_place_in_top_bar(hud._health_card, 0, 0, 0, 0, Rect2(0, 0, hud._to_layout(196.0), bar_height))
	_place_wave(
		hud, edge, bar_height, hud._to_layout(196.0), hud._to_layout(100.0), hud._to_layout(96.0)
	)
	_place_in_top_bar(
		hud._system_row,
		1,
		0,
		1,
		0,
		Rect2(-hud._to_layout(96.0), 0, hud._to_layout(96.0), bar_height)
	)

	_place_button(hud, hud._fire_button, 44.0, 50.0, 80.0, 80.0)
	_place_button(hud, hud._aim_button, 60.0, 154.0, 48.0, 48.0)
	_place_button(hud, hud._skill_button, 148.0, 104.0, 48.0, 48.0)
	_place_button(hud, hud._weapon_button, 108.0, 190.0, 132.0, 36.0)
	_place(
		hud._skill_ring,
		1,
		1,
		1,
		1,
		Rect2(
			-hud._to_layout(143.0),
			-hud._to_layout(99.0),
			hud._to_layout(58.0),
			hud._to_layout(58.0)
		)
	)

	hud._joystick_center = Vector2(hud._to_layout(120.0), hud.size.y - hud._to_layout(90.0))
	hud._joystick_radius = hud._to_layout(56.0)

	hud._show_top_wave_details(true)
	hud._sound_button.visible = true
	hud._wave_icon.visible = true
	hud._compact_card.visible = false
	hud._run_card.visible = true
	hud._score_chip.visible = false
	_place(
		hud._run_card,
		1,
		0,
		1,
		0,
		Rect2(
			-edge - hud._to_layout(236.0),
			hud._top_inset + bar_height + hud._to_layout(8.0),
			hud._to_layout(236.0),
			hud._to_layout(64.0)
		)
	)
	_place_help(
		hud,
		edge,
		hud._top_inset + bar_height + hud._to_layout(8.0),
		hud._to_layout(560.0),
		hud._to_layout(60.0)
	)


## Centres the wave card on screen but clamps it into the gap between the
## vitals card and the system row, so a 390 px phone never overlaps either.
static func _place_wave(
	hud, edge: float, bar_height: float, health_w: float, wave_w: float, system_w: float
) -> void:
	var gap: float = hud._to_layout(8.0)
	var left: float = (hud.size.x - wave_w) * 0.5
	left = clampf(left, edge + health_w + gap, hud.size.x - edge - system_w - gap - wave_w)
	_place_in_top_bar(hud._wave_card, 0, 0, 0, 0, Rect2(left - edge, 0, wave_w, bar_height))


static func place(
	_hud, control: Control, al: float, at: float, ar: float, ab: float, rect: Rect2
) -> void:
	_place(control, al, at, ar, ab, rect)


static func _place_top_bar(hud, left: float, top: float, height: float) -> void:
	hud._top_bar.offset_left = left
	hud._top_bar.offset_top = top
	hud._top_bar.offset_right = -left
	hud._top_bar.offset_bottom = top + height


static func _place_in_top_bar(
	control: Control, al: float, at: float, ar: float, ab: float, rect: Rect2
) -> void:
	_place(control, al, at, ar, ab, rect)


static func _place(
	control: Control, al: float, at: float, ar: float, ab: float, rect: Rect2
) -> void:
	control.anchor_left = al
	control.anchor_top = at
	control.anchor_right = ar
	control.anchor_bottom = ab
	control.offset_left = rect.position.x
	control.offset_top = rect.position.y
	control.offset_right = rect.position.x + rect.size.x
	control.offset_bottom = rect.position.y + rect.size.y


static func _place_button(
	hud, button: Control, right_px: float, bottom_px: float, w_px: float, h_px: float
) -> void:
	var right: float = hud._to_layout(right_px)
	var bottom: float = hud._to_layout(bottom_px)
	var width: float = hud._to_layout(w_px)
	var height: float = hud._to_layout(h_px)
	_place(button, 1, 1, 1, 1, Rect2(-right - width, -bottom - height, width, height))
	button.custom_minimum_size = Vector2(width, height)


static func _place_compact(hud, left: float, top: float, visible: bool) -> float:
	if not is_instance_valid(hud._compact_card):
		return 0.0
	hud._compact_card.visible = visible
	if not visible:
		return 0.0
	var font := float(hud._compact_label.get_theme_font_size("font_size"))
	var height: float = font * 1.45 * float(hud.COMPACT_LINES) + hud._to_layout(16.0)
	_place(hud._compact_card, 0, 0, 1, 0, Rect2(left, top, -left * 2.0, height))
	hud._compact_label.custom_minimum_size = Vector2.ZERO
	return height


static func _place_help(hud, left: float, top: float, width: float, height: float) -> void:
	_place(hud._help_panel, 0.5, 0, 0.5, 0, Rect2(-width * 0.5, top, width, height))
	hud._help_panel.offset_left = -width * 0.5
	hud._help_panel.offset_right = width * 0.5
	hud._help_panel.offset_left = maxf(hud._help_panel.offset_left, -hud.size.x * 0.5 + left)
	hud._help_panel.offset_right = minf(hud._help_panel.offset_right, hud.size.x * 0.5 - left)
