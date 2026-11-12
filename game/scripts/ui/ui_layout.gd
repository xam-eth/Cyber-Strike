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
		hud._reload_button,
		hud._jump_button,
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
	var short_view: bool = (
		hud._narrow or (hud._physical_size.y > 0.0 and hud._physical_size.y < 480.0)
	)
	var edge: float = hud._to_layout(44.0)
	var bar_height: float = hud._to_layout(56.0 if short_view else 60.0)
	var health_width: float = hud._to_layout(160.0 if short_view else 242.0)
	_place_top_bar(hud, edge, hud._top_inset, bar_height)
	# Top-left: the tactical minimap — a live view of the real mission world
	# (caches, route, objective, player). The vitals card belongs bottom-left
	# per shooter convention and is placed after the movement pocket below.
	var map_px: float = hud._to_layout(80.0 if short_view else 152.0)
	_place_in_top_bar(hud._minimap, 0, 0, 0, 0, Rect2(0, 0, map_px, map_px))
	hud._minimap.custom_minimum_size = Vector2(map_px, map_px)
	if is_instance_valid(hud._upgrade_status_card):
		_place_in_top_bar(
			hud._upgrade_status_card,
			1,
			0,
			1,
			0,
			Rect2(-hud._to_layout(196.0), 0, hud._to_layout(196.0), bar_height)
		)
	if is_instance_valid(hud._resource_bar):
		var res_w: float = hud._to_layout(196.0 if short_view else 268.0)
		var res_h: float = hud._to_layout(28.0 if short_view else 112.0)
		hud._resource_bar.compact_mode = short_view
		hud._resource_bar.scale_unit = hud._to_layout(1.0)
		_place_in_top_bar(
			hud._resource_bar,
			1,
			0,
			1,
			0,
			Rect2(-res_w, bar_height + hud._to_layout(6.0), res_w, res_h)
		)
		hud._resource_bar.queue_redraw()
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
	# Mission card: top-right column under the resource telemetry (shooter
	# convention — the objective/quest reads on the right, the map on the left).
	var objective_top: float = bar_height + hud._to_layout(8.0)
	objective_top += hud._to_layout(28.0 if short_view else 112.0) + hud._to_layout(6.0)
	_place_in_top_bar(
		hud._wave_card,
		1,
		0,
		1,
		0,
		Rect2(-hud._to_layout(294.0), objective_top, hud._to_layout(294.0), hud._to_layout(70.0))
	)
	# The wrapped mission detail reserves its two lines here, not at build time
	# where the stretch factor is still stale. Godot forces an autowrap+clip
	# label's minimum height to 1 px, so without this stamp the container
	# grants ~one line and the engine's visible-line counter truncates the
	# copy to "BREACH CAPACITOR MODULE ·...". 46 physical px clears the two
	# shaped lines (their em boxes run ~20 px each) inside the 70 px card.
	if is_instance_valid(hud._wave_enemy_label):
		hud._wave_enemy_label.custom_minimum_size.y = hud._to_layout(46.0)
	# (START DEFENSE is placed after the action cluster, which owns the lane
	# geometry its slot clamps against.)
	# System actions (pause/sound) share the top-right corner row with the
	# upgrade entry, leaving the top-centre band to the guardian bar and the
	# compass strip — the classic shooter top edge.
	var system_width: float = hud._to_layout(64.0 if hud._narrow else 136.0)
	_place_in_top_bar(
		hud._system_row,
		1,
		0,
		1,
		0,
		Rect2(
			-hud._to_layout(204.0) - system_width,
			-hud._to_layout(4.0),
			system_width,
			hud._to_layout(64.0)
		)
	)
	_place(
		hud._armory_button,
		0,
		0,
		0,
		0,
		Rect2(
			edge,
			hud._top_inset + map_px + hud._to_layout(8.0),
			hud._to_layout(186.0),
			hud._to_layout(56.0)
		)
	)
	# Guardian telemetry: the top-centre boss bar, in the free band between
	# the minimap and the mission card — the classic shooter placement. The
	# endless smoke compares raw rects (the wave card's being top-bar-local),
	# so the band's right edge is held in that same comparison space.
	if is_instance_valid(hud._guardian_card):
		var g_left_min: float = edge + map_px + hud._to_layout(8.0)
		var g_left_max: float = (
			hud.size.x - 2.0 * edge - hud._to_layout(294.0) - hud._to_layout(8.0)
		)
		var g_width: float = clampf(
			g_left_max - g_left_min, hud._to_layout(110.0), hud._to_layout(268.0)
		)
		g_width = minf(g_width, maxf(g_left_max - g_left_min, hud._to_layout(110.0)))
		var g_left: float = clampf(
			(g_left_min + g_left_max - g_width) * 0.5, g_left_min, g_left_max - g_width
		)
		_place(
			hud._guardian_card,
			0,
			0,
			0,
			0,
			Rect2(g_left, hud._top_inset, g_width, hud._to_layout(52.0))
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
	# Reload + jump extend the cluster one column outward: the PUBG/Free Fire
	# thumb grid keeps reload/stance controls beside the fire column.
	var outer_right := weapon_right + action_px + gap_px
	_place_button(hud, hud._reload_button, outer_right, fire_bottom, action_px, action_px)
	_place_button(hud, hud._jump_button, outer_right, aim_bottom, action_px, action_px)
	var ammo_bottom := aim_bottom + action_px + gap_px
	# AegisAmmoChip is a PanelContainer: its minimum height follows its content
	# (header + ammo value + magazine bar + margins ~66 px), taller than the
	# 48 px slot above the action cluster, and the expanded panel collided with
	# the resource strip on short landscape. The chip keeps the SWAP column
	# (the dock and the layout smoke both pin that pairing) and compacts to a
	# single tier-and-ammo row whose real minimum fits the 34 px short slot.
	if short_view:
		hud._touch_ammo_chip.set_compact_row(true)
		_place_button(
			hud, hud._touch_ammo_chip, fire_right, ammo_bottom, fire_px + action_px + gap_px, 34.0
		)
	else:
		hud._touch_ammo_chip.set_compact_row(false)
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

	# START DEFENSE: the contextual mission action lives in the bottom lane
	# between the movement pocket and the action cluster, riding above the
	# feedback strip. Two hard floors shape it: no thumb target may share a
	# pixel, and the centre of the screen stays free of interactive controls
	# so a look-drag through the reticle zone always moves the camera (the
	# ADS touch contract pins that centre point).
	var stick_x_now: float = hud._to_layout(120.0) + hud._safe_left
	var def_lane_left: float = (
		(hud.size.x - stick_x_now if hud._left_handed else stick_x_now) + hud._to_layout(72.0)
	)
	var def_lane_right: float = minf(
		hud._jump_button.get_rect().position.x - hud._to_layout(8.0),
		hud.size.x * 0.5 - hud._to_layout(24.0)
	)
	var def_w: float = clampf(
		def_lane_right - def_lane_left, hud._to_layout(80.0), hud._to_layout(230.0)
	)
	_fit_width(hud._defense_button, def_w)
	_place(
		hud._defense_button,
		0,
		0,
		0,
		0,
		Rect2(
			def_lane_left,
			(
				hud.size.y
				- float(hud._safe_bottom)
				- hud._to_layout(58.0)
				- hud._to_layout(16.0)
				- hud._to_layout(56.0)
			),
			def_w,
			hud._to_layout(56.0)
		)
	)
	var stick_x: float = hud._to_layout(120.0) + hud._safe_left
	hud._joystick_center = Vector2(
		hud.size.x - stick_x if hud._left_handed else stick_x,
		hud.size.y - _stick_pocket_bottom(hud, 90.0, 64.0)
	)
	hud._joystick_radius = hud._to_layout(64.0)
	hud._joystick_visual_radius = hud._joystick_radius

	# Vitals card: bottom-left above the movement pocket (shooter convention —
	# health/armor beside the stick, never a top corner). The same slot reads
	# as the classic bottom-left vitals block on desktop.
	var vitals_h: float = bar_height
	var vitals_y: float = (
		hud.size.y
		- _stick_pocket_bottom(hud, 90.0, 64.0)
		- hud._to_layout(64.0)
		- hud._to_layout(10.0)
		- vitals_h
		- hud._top_inset
	)
	if hud._left_handed:
		_place(hud._health_card, 1, 0, 1, 0, Rect2(-health_width, vitals_y, health_width, vitals_h))
	else:
		_place(hud._health_card, 0, 0, 0, 0, Rect2(0, vitals_y, health_width, vitals_h))

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


## Shrink a plate's label font until its content minimum fits `max_w`, so a
## text-bearing contextual button can occupy a squeezed lane without its
## minimum size crossing a thumb target. Restores the authored size first so
## a rotation back to a wide canvas brings the type scale with it.
static func _fit_width(button: Control, max_w: float) -> void:
	if not is_instance_valid(button):
		return
	if not button.has_meta("aegis_font_px"):
		button.set_meta("aegis_font_px", button.get_theme_font_size("font_size"))
	var font_size := int(button.get_meta("aegis_font_px"))
	button.add_theme_font_size_override("font_size", font_size)
	var tries := 0
	while button.get_minimum_size().x > max_w and tries < 5 and font_size > 8:
		font_size = maxi(8, int(font_size * 0.85))
		button.add_theme_font_size_override("font_size", font_size)
		tries += 1


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
