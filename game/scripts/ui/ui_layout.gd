## Geometry for the one landscape HUD, with touch and desktop densities.
##
## There is no portrait layout. The touch reference device is 844x390 and every
## number is authored in physical pixels, then converted by `hud._to_layout()`.
## A keyboard/mouse viewport keeps the same composition but uses a compact
## action rail instead of magnifying thumb controls. A portrait window is
## handled by the rotation notice. Kept out of touch_controls.gd so the runtime
## facade stays readable and the layout can be reviewed against screenshots.
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
		# Not the help plate: it is a hint with no action in it, so a drag that
		# starts on the hint must still move the player.
		hud._fire_button,
		hud._weapon_button,
		hud._skill_button,
		hud._aim_button,
		hud._touch_ammo_chip,
		hud._pause_panel,
		hud._results_panel,
		hud._settings_menu,
		hud._upgrade_entry_button,
		hud._upgrade_panel,
		hud._confirm_dialog,
		hud._run_card,
		hud._score_chip,
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


static func landscape(hud) -> void:
	var edge: float = hud._to_layout(44.0)
	var bar_height: float = hud._to_layout(56.0)
	_place_top_bar(hud, edge, hud._top_inset, bar_height)
	_place_in_top_bar(hud._health_card, 0, 0, 0, 0, Rect2(0, 0, hud._to_layout(208.0), bar_height))
	if is_instance_valid(hud._upgrade_status_card):
		_place_in_top_bar(
			hud._upgrade_status_card,
			1,
			0,
			1,
			0,
			Rect2(-hud._to_layout(196.0), 0, hud._to_layout(196.0), bar_height)
		)
	if is_instance_valid(hud._upgrade_entry_button):
		_place(
			hud._upgrade_entry_button,
			1,
			0,
			1,
			0,
			Rect2(
				-edge - hud._to_layout(196.0),
				hud._top_inset,
				hud._to_layout(196.0),
				hud._to_layout(52.0)
			)
		)
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

	# One compact two-by-two action cluster. FIRE is primary; ammo is the same
	# width as the cluster and sits directly above SWAP/ARMORY, so equipped
	# weapon, magazine and weapon action read as one column. The old 208x284 px
	# thumb rail was oversized on a 1280x720 mouse view. Desktop now uses
	# 80/72 px plates: still below touch density, but wide enough for the real
	# 16 px accessibility font and untracked ARMORY/ARSENAL captions.
	var fire_px := 96.0 if hud._touch_mode else 80.0
	var action_px := 80.0 if hud._touch_mode else 72.0
	var gap_px := 8.0 if hud._touch_mode else 6.0
	var ammo_height_px := 48.0 if hud._touch_mode else 42.0
	var fire_right := 16.0
	var fire_bottom := 16.0
	var aim_bottom := fire_bottom + fire_px + gap_px
	var weapon_right := fire_right + fire_px + gap_px
	var skill_right := weapon_right
	_place_button(hud, hud._fire_button, fire_right, fire_bottom, fire_px, fire_px)
	_place_button(hud, hud._aim_button, fire_right, aim_bottom, action_px, action_px)
	_place_button(hud, hud._skill_button, skill_right, fire_bottom, action_px, action_px)
	_place_button(hud, hud._weapon_button, weapon_right, aim_bottom, action_px, action_px)
	var ammo_bottom := aim_bottom + action_px + gap_px
	_place_button(
		hud,
		hud._touch_ammo_chip,
		fire_right,
		ammo_bottom,
		fire_px + action_px + gap_px,
		ammo_height_px
	)
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


## Pause and results are centred cards, sized from the shorter dimension so a
## 390 px-tall phone keeps both its actions on screen without scrolling.
static func overlays(hud) -> void:
	var results_width: float = minf(hud._to_layout(668.0), hud.size.x * 0.92)
	var results_height: float = minf(hud._to_layout(624.0), hud.size.y * 0.92)
	hud._results_panel.custom_minimum_size = Vector2(results_width, results_height)
	_place(
		hud._results_panel,
		0.5,
		0.5,
		0.5,
		0.5,
		Rect2(-results_width * 0.5, -results_height * 0.5, results_width, results_height)
	)
	var wide_results: bool = results_width >= float(hud._to_layout(600.0))
	var actions: BoxContainer = (
		hud._results_panel.find_child("ResultsActions", true, false) as BoxContainer
	)
	if is_instance_valid(actions):
		actions.vertical = not wide_results
	var button_width: float = (
		float(hud._to_layout(188.0))
		if wide_results
		else minf(float(hud._to_layout(240.0)), results_width - float(hud._to_layout(48.0)))
	)
	var button_size := Vector2(button_width, float(hud._to_layout(48.0)))
	hud._results_retry_button.custom_minimum_size = button_size
	hud._results_retry_button.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	hud._results_explore_button.custom_minimum_size = button_size
	hud._results_explore_button.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	if is_instance_valid(hud._results_home_button):
		hud._results_home_button.custom_minimum_size = button_size
		hud._results_home_button.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	hud._results_goal_bar.custom_minimum_size.y = hud._to_layout(8.0)

	var pause_width: float = minf(hud._to_layout(400.0), hud.size.x * 0.88)
	var pause_height: float = minf(hud._to_layout(390.0), hud.size.y * 0.9)
	hud._pause_panel.custom_minimum_size = Vector2(pause_width, pause_height)
	_place(
		hud._pause_panel,
		0.5,
		0.5,
		0.5,
		0.5,
		Rect2(-pause_width * 0.5, -pause_height * 0.5, pause_width, pause_height)
	)
	for button in [
		hud._pause_resume_button,
		hud._pause_restart_button,
		hud._pause_settings_button,
		hud._pause_home_button,
	]:
		if is_instance_valid(button):
			button.custom_minimum_size = Vector2(0.0, hud._to_layout(52.0))


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
