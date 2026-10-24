## Geometry for the three HUD layouts. Kept out of touch_controls.gd so the
## runtime facade stays readable and each platform layout can be reviewed (and
## tuned on a device) on its own.
##
## Every function takes the live HUD as an untyped host: typing it as
## TouchControls would create a cyclic script reference, and the HUD is the only
## caller. Positions are expressed in physical design pixels and converted with
## the host's `_to_layout()` so the same numbers work at 390 px and at 1280 px.
class_name UiLayout
extends RefCounted


static func over_hud(hud, position: Vector2) -> bool:
	var hud_controls: Array[Control] = [
		hud._top_bar,
		hud._wave_card,
		hud._defense_button,
		hud._armory_button,
		hud._armory_panel,
		hud._help_panel,
		hud._fire_button,
		hud._weapon_button,
		hud._skill_button,
		hud._aim_button,
		hud._touch_ammo_chip,
		hud._pause_panel,
		hud._results_panel,
		hud._settings_menu,
		hud._run_card,
		hud._score_chip,
		hud._desktop_weapon_card,
		hud._emp_chip,
		hud._ads_chip,
		hud._compact_card,
	]
	for control in hud_controls:
		if (
			is_instance_valid(control)
			and control.visible
			and control.get_global_rect().has_point(position)
		):
			return true
	return false


## How many physical pixels one logical canvas unit occupies. With stretch mode
## canvas_items this is the uniform scale the engine applies to the canvas.
static func compute_stretch(hud, physical: Vector2) -> float:
	if hud.size.x <= 0.0 or hud.size.y <= 0.0 or physical.x <= 0.0 or physical.y <= 0.0:
		return 1.0
	return maxf(minf(physical.x / hud.size.x, physical.y / hud.size.y), 0.0001)


## Reserve the system-controlled edges of the display for the bottom-docked
## combat controls. `get_display_safe_area()` and `get_display_cutouts()` come
## back in *window* pixels and are converted to layout units here, so every
## call inside this module adds the same margin. A device that reports nothing
## (a desktop browser, or an OEM that leaves the insets empty) still gets the
## touch gesture reserve, so the buttons never reach the glass edge.
static func resolve_safe_insets(hud, physical: Vector2) -> void:
	var measured := measure_safe_insets(physical, hud._touch_mode)
	hud._safe_left = hud._to_layout(measured.x)
	hud._safe_right = hud._to_layout(measured.y)
	hud._safe_bottom = hud._to_layout(measured.z)


## Pure form of resolve_safe_insets, in window pixels: x = left, y = right,
## z = bottom. The menus need the same three numbers and duplicating this maths
## is how the front end and the combat HUD end up disagreeing about where the
## glass edge is -- which is the failure BUG 2 was about. Both call this.
static func measure_safe_insets(physical: Vector2, touch_mode: bool) -> Vector3:
	var left := 0.0
	var right := 0.0
	var bottom := 0.0
	var safe := DisplayServer.get_display_safe_area()
	if safe.size.x > 0 and safe.size.y > 0:
		left = maxf(left, float(safe.position.x))
		right = maxf(right, float(physical.x - (safe.position.x + safe.size.x)))
		bottom = maxf(bottom, float(physical.y - (safe.position.y + safe.size.y)))
	var cutouts := DisplayServer.get_display_cutouts()
	for index in range(cutouts.size()):
		var cutout: Rect2 = cutouts[index]
		if cutout.size.x <= 0.0 or cutout.size.y <= 0.0:
			continue
		if cutout.position.x <= AegisTokens.SAFE_INSET_NOISE_PX:
			left = maxf(left, cutout.position.x + cutout.size.x)
		if cutout.position.x + cutout.size.x >= physical.x - AegisTokens.SAFE_INSET_NOISE_PX:
			right = maxf(right, physical.x - cutout.position.x)
		if cutout.position.y + cutout.size.y >= physical.y - AegisTokens.SAFE_INSET_NOISE_PX:
			bottom = maxf(bottom, cutout.size.y)
	if touch_mode:
		bottom = maxf(bottom, AegisTokens.SAFE_BOTTOM_PX)
		left = maxf(left, AegisTokens.SAFE_SIDE_PX)
		right = maxf(right, AegisTokens.SAFE_SIDE_PX)
	return Vector3(maxf(left, 0.0), maxf(right, 0.0), maxf(bottom, 0.0))


static func desktop(hud) -> void:
	var unit: float = hud._control_unit()
	var inset := 20.0 * unit
	_place_top_bar(hud, inset, hud._top_inset, 64.0 * unit)
	_place_in_top_bar(hud._health_card, 0, 0, 0, 0, Rect2(0, 0, 268.0 * unit, 56.0 * unit))
	# Destiny-style objective hierarchy: the task sits below health on the
	# left, never across the sightline in the centre of the screen.
	_place_in_top_bar(hud._wave_card, 0, 0, 0, 0, Rect2(0, 64.0 * unit, 306.0 * unit, 56.0 * unit))
	_place(
		hud._defense_button,
		0,
		0,
		0,
		0,
		Rect2(inset, hud._top_inset + 128.0 * unit, 230.0 * unit, 52.0 * unit)
	)
	_place_in_top_bar(
		hud._system_row, 1, 0, 1, 0, Rect2(-152.0 * unit, 0, 152.0 * unit, 56.0 * unit)
	)
	_place(
		hud._armory_button,
		0,
		0,
		0,
		0,
		Rect2(inset + 320.0 * unit, hud._top_inset + 64.0 * unit, 186.0 * unit, 52.0 * unit)
	)
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
	_place_help(
		hud,
		inset,
		hud._top_inset + 64.0 * unit + 8.0 * unit,
		560.0 * unit,
		hud._help_block_height(3)
	)
	_place_compact(hud, inset, 0.0, false)


static func touch_portrait(hud) -> void:
	var edge: float = hud._to_layout(12.0)
	var bar_height: float = hud._to_layout(56.0)
	_place_top_bar(hud, edge, hud._top_inset, bar_height)
	_place_in_top_bar(hud._health_card, 0, 0, 0, 0, Rect2(0, 0, hud._to_layout(184.0), bar_height))
	var objective_top: float = bar_height + hud._to_layout(8.0)
	# The old 354 px objective plus two vertically stacked 234 px actions hid
	# the first third of the bay. Keep the readout legible, then share one row
	# between the deliberate Defense start and the Explore-only Armory choice.
	var objective_width: float = minf(hud._to_layout(270.0), hud.size.x - edge * 2.0)
	_place_in_top_bar(
		hud._wave_card, 0, 0, 0, 0, Rect2(0, objective_top, objective_width, hud._to_layout(56.0))
	)
	var action_top: float = hud._top_inset + objective_top + hud._to_layout(64.0)
	var available_px: float = hud._physical_size.x - 24.0
	var start_px: float = minf(208.0, available_px * 0.615)
	var armory_px: float = minf(148.0, available_px - start_px - 8.0)
	_place(
		hud._defense_button,
		0,
		0,
		0,
		0,
		Rect2(edge, action_top, hud._to_layout(start_px), hud._to_layout(56.0))
	)
	_place(
		hud._armory_button,
		1,
		0,
		1,
		0,
		Rect2(
			-edge - hud._to_layout(armory_px),
			action_top,
			hud._to_layout(armory_px),
			hud._to_layout(56.0)
		)
	)
	# The actual Pause plate also grows, not just its icon. Extend four pixels
	# beyond the 56px rail on each vertical side without covering the objective.
	var system_width: float = hud._to_layout(64.0 if hud._narrow else 136.0)
	_place_in_top_bar(
		hud._system_row,
		1,
		0,
		1,
		0,
		Rect2(-system_width, -hud._to_layout(4.0), system_width, hud._to_layout(64.0))
	)

	# These are sizes of the painted AND interactive button plates, not icon
	# ceilings. Keep 7–12px gaps and dock SWAP opposite the firing thumb.
	# A short phone needs a separate reflow so EMP stays below START/ARMORY.
	var short_portrait: bool = hud._physical_size.y < 750.0
	var fire_px: float = 186.0 if short_portrait else 202.0
	var action_px: float = 108.0 if short_portrait else 124.0
	var weapon_px: float = 112.0 if short_portrait else 124.0
	var gap_px: float = 7.0 if short_portrait else 12.0
	# The stack used to start 8 px from the right and 14 px from the bottom on
	# a short phone, which put FIRE inside the Android gesture strip. The
	# authored margin is now a real edge margin; _place_button still adds the
	# device safe area on top of it. A short phone spends 18 px instead of
	# 40 px because its vertical budget has to hold the whole stack *and* the
	# Explore action row above it.
	var fire_right: float = 18.0
	var fire_bottom: float = 18.0 if short_portrait else 40.0
	var aim_bottom: float = fire_bottom + fire_px + gap_px
	var emp_bottom: float = aim_bottom + action_px + gap_px
	_place_button(hud, hud._fire_button, fire_right, fire_bottom, fire_px, fire_px)
	_place_button(hud, hud._aim_button, fire_right, aim_bottom, action_px, action_px)
	_place_button(hud, hud._skill_button, fire_right, emp_bottom, action_px, action_px)
	# Weapon and magazine stack vertically under the thumb's left pocket.
	# Side by side they need 224 px of width, which is more than a 375 px
	# phone can give them once the movement ring and the safe margins are
	# taken out — the two plates then collided with EMP on the right rail.
	# The authored 4 px is *added to* the safe-area reserve rather than
	# replacing it, so the dock keeps the 12 px corner it always had on a
	# display that reports no safe area, while gaining real clearance on one
	# that reports a notch or a rounded corner.
	var dock_top: float = action_top + hud._to_layout(61.0 if short_portrait else 64.0)
	var dock_side: float = 4.0
	_place_weapon_dock(hud, hud._weapon_button, dock_side, dock_top, weapon_px, weapon_px)
	_place_weapon_dock(
		hud,
		hud._touch_ammo_chip,
		dock_side,
		dock_top + hud._to_layout(weapon_px + 8.0),
		112.0,
		54.0
	)
	# Same centre as the expanded EMP hit rectangle, including left-hand mode.
	_place_button(
		hud, hud._skill_ring, fire_right - 4.0, emp_bottom - 4.0, action_px + 8.0, action_px + 8.0
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

	# At 375x667 the ADS hero fills x≈65..165/y≈345..577, while the old
	# (86, height-106) move ring crossed the leg and boot. Keep the same
	# 72px finger radius, but tuck its *centre* into the bottom-left pocket on
	# short phones instead of shrinking its hit target or hiding it entirely.
	# Review of the retake found the outer ring clipped 10 px off-screen. Paint
	# a 64px-radius ring at x73 while retaining the 72px movement hit radius.
	# Match the reflow used by the larger action stack.
	# `short_portrait` was determined from the physical window above.
	# The pocket is measured from the usable corner so the drawn ring keeps a
	# real gap from the glass on every display, not just the ones that report
	# a safe area. The centre also has to leave the whole 72 px capture circle
	# clear of FIRE's left rim: at 390 px wide there is not enough room for
	# both a 202 px plate and a pocket centred any further right than this.
	var stick_x: float = hud._to_layout(73.0 if short_portrait else 78.0) + hud._safe_left
	var stick_bottom: float = _stick_pocket_bottom(hud, 82.0 if short_portrait else 106.0, 72.0)
	hud._joystick_center = Vector2(
		hud.size.x - stick_x if hud._left_handed else stick_x, hud.size.y - stick_bottom
	)
	hud._joystick_radius = hud._to_layout(72.0)
	hud._joystick_visual_radius = hud._to_layout(64.0 if short_portrait else 72.0)

	hud._show_top_wave_details(true)
	# The objective now has its own row: display a readable description instead
	# of cramming a two-word badge between health and pause.
	hud._wave_state_label.visible = false
	hud._run_card.visible = false
	hud._score_chip.visible = false
	hud._sound_button.visible = false
	hud._wave_icon.visible = false
	_place_compact(hud, edge, 0.0, false)
	_place_help(
		hud,
		edge,
		hud._top_inset + objective_top + hud._to_layout(128.0),
		minf(hud._to_layout(342.0), hud.size.x - edge * 2.0),
		hud._help_block_height(2)
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
	var bar_height: float = hud._to_layout(56.0)
	_place_top_bar(hud, edge, hud._top_inset, bar_height)
	_place_in_top_bar(hud._health_card, 0, 0, 0, 0, Rect2(0, 0, hud._to_layout(208.0), bar_height))
	var objective_top: float = bar_height + hud._to_layout(8.0)
	_place_in_top_bar(
		hud._wave_card,
		0,
		0,
		0,
		0,
		Rect2(0, objective_top, hud._to_layout(294.0), hud._to_layout(60.0))
	)
	_place(
		hud._defense_button,
		0,
		0,
		0,
		0,
		Rect2(
			edge,
			hud._top_inset + objective_top + hud._to_layout(68.0),
			hud._to_layout(230.0),
			hud._to_layout(56.0)
		)
	)
	# The enlarged upper-right ADS/weapon plates occupy the old Pause slot.
	# Keep system actions on a separate, safe top-centre rail.
	var system_width: float = hud._to_layout(64.0 if hud._narrow else 136.0)
	_place_in_top_bar(
		hud._system_row,
		0.5,
		0,
		0.5,
		0,
		Rect2(-system_width * 0.5, -hud._to_layout(4.0), system_width, hud._to_layout(64.0))
	)
	_place(
		hud._armory_button,
		0,
		0,
		0,
		0,
		Rect2(
			edge + hud._to_layout(306.0),
			hud._top_inset + objective_top,
			hud._to_layout(186.0),
			hud._to_layout(56.0)
		)
	)

	# 844x390: enlarge the actual FIRE/ADS/EMP/SWAP touch faces as a two-row
	# right-thumb cluster. Keep an 8px gap and move ammo into the open seam.
	# Landscape used to dock the whole right-thumb cluster 8 px from the right
	# and the bottom of an 844x390 screen. Raise the authored edge margin; the
	# device safe area is added on top by _place_button.
	var fire_px := 180.0
	var action_px := 112.0
	var gap_px := 8.0
	var fire_right := 20.0
	var fire_bottom := 20.0
	var aim_bottom := fire_bottom + fire_px + gap_px
	var weapon_right := fire_right + action_px + gap_px
	var skill_right := fire_right + fire_px + gap_px
	_place_button(hud, hud._fire_button, fire_right, fire_bottom, fire_px, fire_px)
	_place_button(hud, hud._aim_button, fire_right, aim_bottom, action_px, action_px)
	_place_button(hud, hud._skill_button, skill_right, fire_bottom, action_px, action_px)
	_place_button(hud, hud._weapon_button, weapon_right, aim_bottom, action_px, action_px)
	# The magazine sits in the seam between the top-left rail and the raised
	# EMP plate: the old (224, 136) corner ended up under the Armory row once
	# the gesture reserve lifted it off the bottom edge.
	_place_button(hud, hud._touch_ammo_chip, 340.0, 80.0, 112.0, 54.0)
	_place_button(
		hud, hud._skill_ring, skill_right - 4.0, fire_bottom - 4.0, action_px + 8.0, action_px + 8.0
	)
	var stick_x: float = hud._to_layout(120.0) + hud._safe_left
	hud._joystick_center = Vector2(
		hud.size.x - stick_x if hud._left_handed else stick_x,
		hud.size.y - _stick_pocket_bottom(hud, 90.0, 64.0)
	)
	hud._joystick_radius = hud._to_layout(64.0)
	hud._joystick_visual_radius = hud._joystick_radius

	hud._show_top_wave_details(true)
	# On a 390 px-high display the optional state badge steals the objective's
	# width and squeezes its description into the corner. The title/remaining
	# count already communicate the state; leave the description its own row.
	hud._wave_state_label.visible = false
	hud._sound_button.visible = true
	hud._wave_icon.visible = false
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
	# Retain an anchor for the help panel across rotations, but never show it
	# over the enlarged action row on a 390px-high landscape playfield.
	_place(
		hud._help_panel,
		1,
		0,
		1,
		0,
		Rect2(
			-edge - hud._to_layout(220.0),
			hud._top_inset + bar_height + hud._to_layout(2.0),
			hud._to_layout(220.0),
			hud._help_block_height(2)
		)
	)
	hud._help_panel.visible = false


## Portrait menus are bottom sheets above the gesture area; wide layouts use
## centered cards. The same pause/results widgets work in both orientations.
static func overlays(hud) -> void:
	var sheet: bool = hud._portrait and hud._narrow
	var anchor_y := 1.0 if sheet else 0.5
	# Portrait sheets clear the gesture strip too: the drag-to-dismiss grip
	# lives at the bottom of the sheet, so it must never sit under it.
	var sheet_bottom: float = (hud._to_layout(34.0) + hud._safe_bottom) if sheet else 0.0

	var results_width: float = minf(
		hud._to_layout(390.0 if sheet else 600.0), hud.size.x * (0.94 if sheet else 0.92)
	)
	# A real 390x844 Results screenshot had ~160 px of empty report space
	# between the reward and its actions. Keep the buttons full-size, but bring
	# this portrait sheet up from 528 to 448 px so earned BP and the choice to
	# continue occupy one readable glance rather than a tall vacant card.
	var results_height: float = minf(
		hud._to_layout(448.0 if sheet else 528.0), hud.size.y * (0.86 if sheet else 0.9)
	)
	hud._results_panel.custom_minimum_size = Vector2(results_width, results_height)
	_place(
		hud._results_panel,
		0.5,
		anchor_y,
		0.5,
		anchor_y,
		Rect2(
			-results_width * 0.5,
			-results_height - sheet_bottom if sheet else -results_height * 0.5,
			results_width,
			results_height
		)
	)
	hud._results_retry_button.custom_minimum_size = Vector2(
		minf(hud._to_layout(302.0 if sheet else 240.0), results_width - hud._to_layout(48.0)),
		hud._to_layout(56.0 if sheet else 52.0)
	)
	hud._results_retry_button.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	hud._results_explore_button.custom_minimum_size = hud._results_retry_button.custom_minimum_size
	hud._results_explore_button.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	hud._results_goal_bar.custom_minimum_size.y = hud._to_layout(8.0)

	var pause_width: float = minf(
		hud._to_layout(390.0 if sheet else 400.0), hud.size.x * (0.94 if sheet else 0.88)
	)
	var pause_height: float = minf(
		hud._to_layout(340.0 if sheet else 390.0), hud.size.y * (0.86 if sheet else 0.9)
	)
	hud._pause_panel.custom_minimum_size = Vector2(pause_width, pause_height)
	_place(
		hud._pause_panel,
		0.5,
		anchor_y,
		0.5,
		anchor_y,
		Rect2(
			-pause_width * 0.5,
			-pause_height - sheet_bottom if sheet else -pause_height * 0.5,
			pause_width,
			pause_height
		)
	)
	for button in [hud._pause_resume_button, hud._pause_restart_button, hud._pause_settings_button]:
		if is_instance_valid(button):
			button.custom_minimum_size = Vector2(0.0, hud._to_layout(56.0 if sheet else 52.0))


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


## Distance from the bottom glass to the joystick's centre, in layout units.
## The pocket only moves up as far as the reserve demands: a 106 px offset
## already keeps a 72 px ring 34 px clear of the edge, and lifting it by the
## full reserve on top of that would push the ring into the control stack
## above it on a 390 px-tall landscape screen.
static func _stick_pocket_bottom(hud, authored_px: float, radius_px: float) -> float:
	var needed_px: float = radius_px + hud._safe_bottom * hud._stretch
	return hud._to_layout(maxf(authored_px, needed_px))


static func _place_button(
	hud, button: Control, right_px: float, bottom_px: float, w_px: float, h_px: float
) -> void:
	# The authored margin is measured from the *usable* edge, never from the
	# glass: the safe-area reserve (Android gesture bar, notch, rounded corner)
	# is added here so every bottom-docked control inherits it, including the
	# mirrored left-hand layout.
	var right: float = hud._to_layout(right_px) + hud._safe_right
	var bottom: float = hud._to_layout(bottom_px) + hud._safe_bottom
	var width: float = hud._to_layout(w_px)
	var height: float = hud._to_layout(h_px)
	if hud._left_handed:
		_place(button, 0, 1, 0, 1, Rect2(right, -bottom - height, width, height))
	else:
		_place(button, 1, 1, 1, 1, Rect2(-right - width, -bottom - height, width, height))
	button.custom_minimum_size = Vector2(width, height)


## Weapon + ammo live opposite the firing thumb in portrait. Mirroring both
## docks together preserves the handedness option without mirroring the art.
static func _place_weapon_dock(
	hud, control: Control, side_px: float, top: float, w_px: float, h_px: float
) -> void:
	var side: float = (
		hud._to_layout(side_px) + (hud._safe_right if hud._left_handed else hud._safe_left)
	)
	var width: float = hud._to_layout(w_px)
	var height: float = hud._to_layout(h_px)
	if hud._left_handed:
		_place(control, 1, 0, 1, 0, Rect2(-side - width, top, width, height))
	else:
		_place(control, 0, 0, 0, 0, Rect2(side, top, width, height))
	control.custom_minimum_size = Vector2(width, height)


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
