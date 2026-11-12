## Immediate-mode drawing for the parts of the HUD that a Control node cannot
## express: the dynamic tactical reticle, the Exo-Visor frame, the azimuth
## compass with hostile/pickup telemetry, the virtual joystick, and the damage
## vignette.
class_name HudRenderer
extends RefCounted


static func damage_vignette(
	host: CanvasItem, viewport_size: Vector2, strength: float, thickness: float, color: Color
) -> void:
	for index in 3:
		var inset := float(index) * thickness * 0.8
		var alpha := (0.14 - float(index) * 0.035) * strength
		host.draw_rect(
			Rect2(inset, inset, viewport_size.x - inset * 2.0, viewport_size.y - inset * 2.0),
			Color(color, alpha),
			false,
			thickness
		)


## Subtle AAA futuristic helmet visor framing ticks at the upper corners.
static func visor_frame(hud: Control) -> void:
	if hud.size.x < 480.0 or hud.size.y < 300.0:
		return
	var s := maxf(float(hud.call("_to_layout", 1.0)), 0.75)
	var pad_x := float(hud.get("_safe_left")) + 14.0 * s
	var pad_r := float(hud.get("_safe_right")) + 14.0 * s
	var top_y := maxf(float(hud.get("_top_inset")) - 8.0 * s, 6.0 * s)
	var arm := 26.0 * s
	var col := Color(AegisTokens.INFO, 0.30)
	hud.draw_line(Vector2(pad_x, top_y + arm * 0.55), Vector2(pad_x, top_y), col, 1.2, true)
	hud.draw_line(Vector2(pad_x, top_y), Vector2(pad_x + arm, top_y), col, 1.2, true)
	var rx := hud.size.x - pad_r
	hud.draw_line(Vector2(rx, top_y + arm * 0.55), Vector2(rx, top_y), col, 1.2, true)
	hud.draw_line(Vector2(rx, top_y), Vector2(rx - arm, top_y), col, 1.2, true)


## AAA tactical crosshair: movable [+] center ticks, diagonal hit-confirm
## chevrons, outer corner brackets, ADS rangefinder arc, and Overcharge aura.
static func crosshair(
	host: CanvasItem,
	center: Vector2,
	gap: float,
	tick: float,
	thickness: float,
	color: Color,
	outline: Color,
	hit: bool,
	outline_offset: float,
	soft_lock: bool = false,
	aiming: bool = false,
	overcharged: bool = false
) -> void:
	var resolved_gap := maxf(gap, tick + 2.0)
	var resolved_color := color
	if hit:
		resolved_color = AegisTokens.ACCENT
		resolved_gap *= 1.18
	elif soft_lock:
		resolved_color = AegisTokens.INFO
		resolved_gap *= 0.85
	elif overcharged:
		resolved_color = Color(0.80, 0.56, 1.0)

	for offset: Vector2 in [
		Vector2(1.0, 0.0), Vector2(-1.0, 0.0), Vector2(0.0, 1.0), Vector2(0.0, -1.0)
	]:
		_draw_ticks(
			host, center + offset * outline_offset, resolved_gap, tick, thickness + 1.1, outline
		)
	_draw_ticks(host, center, resolved_gap, tick, thickness, resolved_color)
	host.draw_circle(center, maxf(thickness * 1.25, 1.4), resolved_color)
	host.draw_arc(center, maxf(tick * 0.42, 2.0), 0.0, TAU, 18, Color(outline, 0.85), 1.0, true)

	# Precision outer corner micro-brackets on the [+] sight.
	var outer_r := resolved_gap + tick + (3.2 if aiming else 5.0) * outline_offset
	var leg := maxf((4.8 if aiming else 3.2) * outline_offset, 2.8)
	var bracket_col := Color(
		AegisTokens.INFO if aiming else resolved_color, 0.84 if aiming else 0.44
	)
	for sx: float in [-1.0, 1.0]:
		for sy: float in [-1.0, 1.0]:
			var corner := center + Vector2(sx * outer_r, sy * outer_r)
			host.draw_line(corner, corner - Vector2(sx * leg, 0.0), bracket_col, 1.25, true)
			host.draw_line(corner, corner - Vector2(0.0, sy * leg), bracket_col, 1.25, true)

	if aiming:
		host.draw_arc(
			center,
			resolved_gap * 0.72,
			-PI * 0.22,
			PI * 0.22,
			12,
			Color(AegisTokens.INFO, 0.55),
			1.15,
			true
		)
		host.draw_arc(
			center,
			resolved_gap * 0.72,
			PI - PI * 0.22,
			PI + PI * 0.22,
			12,
			Color(AegisTokens.INFO, 0.55),
			1.15,
			true
		)

	if hit:
		# Classic AAA diagonal X-hitmarker confirmation ticks.
		var hm_in := maxf(resolved_gap * 0.52, 4.0)
		var hm_out := hm_in + maxf(tick * 0.88, 4.5)
		for diag: Vector2 in [
			Vector2(1.0, 1.0),
			Vector2(-1.0, 1.0),
			Vector2(1.0, -1.0),
			Vector2(-1.0, -1.0),
		]:
			var dir: Vector2 = diag.normalized()
			host.draw_line(
				center + dir * hm_in,
				center + dir * hm_out,
				Color(outline, 0.9),
				thickness + 1.6,
				true
			)
			host.draw_line(
				center + dir * hm_in,
				center + dir * hm_out,
				AegisTokens.ACCENT,
				thickness + 0.3,
				true
			)

	if soft_lock:
		host.draw_arc(
			center, resolved_gap + tick + 2.5, 0.0, TAU, 24, Color(AegisTokens.INFO, 0.58), 1.3
		)
	elif overcharged:
		host.draw_arc(
			center, resolved_gap + tick + 3.0, 0.0, TAU, 24, Color(0.76, 0.46, 1.0, 0.45), 1.2
		)


static func _draw_ticks(
	host: CanvasItem, center: Vector2, gap: float, tick: float, thickness: float, color: Color
) -> void:
	host.draw_line(center + Vector2(gap, 0.0), center + Vector2(gap + tick, 0.0), color, thickness)
	host.draw_line(center - Vector2(gap, 0.0), center - Vector2(gap + tick, 0.0), color, thickness)
	host.draw_line(center + Vector2(0.0, gap), center + Vector2(0.0, gap + tick), color, thickness)
	host.draw_line(center - Vector2(0.0, gap), center - Vector2(0.0, gap + tick), color, thickness)


static func joystick(
	host: CanvasItem, center: Vector2, radius: float, knob: Vector2, stroke: float
) -> void:
	var active := center.distance_to(knob) > 2.0
	host.draw_circle(center, radius, Color(AegisTokens.PANEL, 0.34))
	host.draw_arc(
		center,
		radius,
		0.0,
		TAU,
		48,
		Color(AegisTokens.INFO if active else AegisTokens.INK_2, 0.84),
		stroke,
		true
	)
	host.draw_arc(
		center, radius * 0.59, 0.0, TAU, 36, Color(AegisTokens.LINE_HI, 0.38), stroke, true
	)
	var tick_len := maxf(4.5 * stroke, 3.5)
	for dir in [Vector2.UP, Vector2.DOWN, Vector2.LEFT, Vector2.RIGHT]:
		host.draw_line(
			center + dir * (radius - tick_len),
			center + dir * radius,
			Color(AegisTokens.INFO, 0.58),
			maxf(stroke, 1.0),
			true
		)
	var visual_knob := center + (knob - center).limit_length(radius * 0.60)
	if active:
		host.draw_line(
			center, visual_knob, Color(AegisTokens.INFO, 0.58), maxf(stroke * 1.2, 1.2), true
		)
	host.draw_circle(visual_knob, radius * 0.40, Color(AegisTokens.PANEL_3, 0.90))
	host.draw_arc(
		visual_knob,
		radius * 0.40,
		0.0,
		TAU,
		32,
		AegisTokens.INFO if active else Color(AegisTokens.ACCENT, 0.85),
		maxf(stroke * 1.5, 1.0),
		true
	)


static func draw_tactical_compass(hud: Control, layer: Control = null) -> void:
	var surface: Control = layer if is_instance_valid(layer) else hud
	if (
		hud.get("_player_down") == true
		or hud.get_tree() == null
		or hud.get_tree().paused
		or bool(hud.call("_results_visible"))
	):
		return
	var cam := hud.get("_hostile_camera") as Camera3D
	if not is_instance_valid(cam):
		return
	var scale := maxf(float(hud.call("_to_layout", 1.0)), 0.75)
	var safe_l := float(hud.get("_safe_left"))
	var wave_c := hud.get("_wave_card") as Control
	var guardian_c := hud.get("_guardian_card") as Control
	var sys_row := hud.get("_system_row") as Control
	var top_in := float(hud.get("_top_inset"))
	var h := 25.0 * scale
	var rect := Rect2()

	var center_below_sys := (
		hud.size.y >= 460.0
		and (not is_instance_valid(guardian_c) or not guardian_c.visible)
		and is_instance_valid(sys_row)
		and sys_row.visible
	)
	# The minimap owns the top-left band and the mission card the top-right;
	# the compass strip lives in the free centre band between them, whatever
	# the row does with the system buttons.
	var minimap_c := hud.get("_minimap") as Control
	var band_left := safe_l
	if is_instance_valid(minimap_c) and minimap_c.visible:
		band_left = maxf(band_left, minimap_c.get_global_rect().end.x)
	band_left += 12.0 * scale
	var band_right := hud.size.x - float(hud.get("_safe_right"))
	if is_instance_valid(wave_c) and wave_c.visible:
		band_right = minf(band_right, wave_c.get_global_rect().position.x - 12.0 * scale)
	if not center_below_sys:
		for key in [
			"_system_row",
			"_upgrade_status_card",
			"_upgrade_entry_button",
			"_armory_entry_button",
		]:
			var right_ctrl := hud.get(key) as Control
			if (
				is_instance_valid(right_ctrl)
				and right_ctrl.visible
				and right_ctrl.get_global_rect().position.y < top_in + 54.0 * scale
			):
				var pad_r := 28.0 * scale if key == "_system_row" else 14.0 * scale
				band_right = minf(band_right, right_ctrl.get_global_rect().position.x - pad_r)
	var band_top := top_in + 2.0 * scale
	if center_below_sys:
		band_top = sys_row.get_global_rect().end.y + 10.0 * scale
	var avail_w := band_right - band_left
	var min_w := 120.0 * scale
	if avail_w < min_w:
		return
	var target_w := minf(avail_w, 272.0 * scale if center_below_sys else 232.0 * scale)
	if center_below_sys:
		target_w = minf(target_w, hud.size.x * 0.30)
	var cx := clampf(hud.size.x * 0.5, band_left + target_w * 0.5, band_right - target_w * 0.5)
	rect = Rect2(cx - target_w * 0.5, band_top, target_w, h)

	var enemies: Array = []
	for node in hud.get_tree().get_nodes_in_group("enemies"):
		if (
			is_instance_valid(node)
			and (not node.has_method("is_defeated") or not bool(node.call("is_defeated")))
		):
			enemies.append(node)

	var pickups: Array = hud.get_tree().get_nodes_in_group("field_pickups")
	for crate in hud.get_tree().get_nodes_in_group("supply_crates"):
		if is_instance_valid(crate):
			pickups.append(crate)

	var state_obj: Variant = hud.get("_state")
	var has_obj := false
	var obj_pos := Vector3.ZERO
	if state_obj != null:
		has_obj = state_obj.get("objective_has_target") == true
		var raw_pos: Variant = state_obj.get("objective_world_pos")
		if raw_pos is Vector3:
			obj_pos = raw_pos

	compass_strip(surface, cam, enemies, has_obj, obj_pos, rect, scale, pickups)


static func compass_strip(
	canvas: Control,
	camera: Camera3D,
	enemies: Array,
	has_objective: bool,
	objective_pos: Vector3,
	rect: Rect2,
	scale: float,
	pickups: Array = []
) -> void:
	var cut := minf(7.0 * scale, rect.size.y * 0.42)
	var poly := PackedVector2Array(
		[
			Vector2(rect.position.x + cut, rect.position.y),
			Vector2(rect.end.x - cut, rect.position.y),
			Vector2(rect.end.x, rect.position.y + cut),
			Vector2(rect.end.x, rect.end.y - cut * 0.5),
			Vector2(rect.end.x - cut * 0.5, rect.end.y),
			Vector2(rect.position.x + cut * 0.5, rect.end.y),
			Vector2(rect.position.x, rect.end.y - cut * 0.5),
			Vector2(rect.position.x, rect.position.y + cut),
		]
	)
	canvas.draw_colored_polygon(poly, Color(AegisTokens.VOID, 0.80))
	var closed := poly.duplicate()
	closed.append(poly[0])
	canvas.draw_polyline(closed, Color(AegisTokens.LINE_HI, 0.72), 1.1, true)
	canvas.draw_line(
		Vector2(rect.position.x + cut, rect.position.y),
		Vector2(rect.end.x - cut, rect.position.y),
		Color(AegisTokens.INFO, 0.90),
		1.6,
		true
	)

	var fwd := -camera.global_transform.basis.z
	var flat_fwd := Vector2(fwd.x, fwd.z)
	flat_fwd = Vector2(0.0, -1.0) if flat_fwd.length_squared() < 0.0001 else flat_fwd.normalized()
	var heading_deg := fposmod(rad_to_deg(atan2(flat_fwd.x, -flat_fwd.y)), 360.0)
	var half_fov := 65.0
	var usable_half := maxf(rect.size.x * 0.5 - 12.0 * scale, 24.0)
	var cx := rect.position.x + rect.size.x * 0.5
	var mono: Font = AegisTheme.font("mono")
	var font_sz := maxi(roundi(9.5 * scale), 8)

	var first_tick := int(floor((heading_deg - half_fov) / 15.0)) * 15
	var last_tick := int(ceil((heading_deg + half_fov) / 15.0)) * 15
	for raw_deg in range(first_tick, last_tick + 1, 15):
		var delta_deg := float(raw_deg) - heading_deg
		if absf(delta_deg) > half_fov:
			continue
		var tx := cx + (delta_deg / half_fov) * usable_half
		var norm_deg := posmod(raw_deg, 360)
		var is_cardinal := (norm_deg % 90) == 0
		var is_inter := (norm_deg % 45) == 0 and not is_cardinal
		var tick_h := (5.5 if is_cardinal else (4.0 if is_inter else 2.5)) * scale
		canvas.draw_line(
			Vector2(tx, rect.end.y - tick_h),
			Vector2(tx, rect.end.y - 1.0),
			Color(AegisTokens.INFO if is_cardinal else AegisTokens.LINE_HI, 0.78),
			1.25 if is_cardinal else 1.0
		)
		if (is_cardinal or is_inter) and mono != null and absf(tx - cx) > 18.0 * scale:
			var card_txt := _bearing_label(norm_deg)
			canvas.draw_string(
				mono,
				Vector2(
					tx - 4.0 * scale * float(card_txt.length()) * 0.5,
					rect.position.y + rect.size.y * 0.64
				),
				card_txt,
				HORIZONTAL_ALIGNMENT_LEFT,
				-1,
				font_sz - (1 if is_inter else 0),
				AegisTokens.INK if norm_deg == 0 else AegisTokens.INK_2
			)

	# Digital heading callout pill at center of compass strip.
	if mono != null:
		var deg_int := posmod(roundi(heading_deg), 360)
		var pill_w := 34.0 * scale
		var pill_rect := Rect2(
			cx - pill_w * 0.5, rect.position.y + 2.0 * scale, pill_w, 13.0 * scale
		)
		canvas.draw_rect(pill_rect, Color(AegisTokens.PANEL_3, 0.92))
		canvas.draw_rect(pill_rect, Color(AegisTokens.INFO, 0.65), false, 1.0)
		canvas.draw_string(
			mono,
			Vector2(pill_rect.position.x, pill_rect.position.y + 10.2 * scale),
			"%03d°" % deg_int,
			HORIZONTAL_ALIGNMENT_CENTER,
			pill_w,
			maxi(roundi(8.8 * scale), 8),
			AegisTokens.ACCENT
		)

	var cam_pos := camera.global_position
	for node in pickups:
		var p := node as Node3D
		if p == null or not is_instance_valid(p):
			continue
		if cam_pos.distance_squared_to(p.global_position) > 784.0:
			continue
		_draw_compass_pip(
			canvas,
			cam_pos,
			p.global_position,
			heading_deg,
			half_fov,
			cx,
			usable_half,
			rect.end.y - 4.0 * scale,
			maxf(2.2 * scale, 1.8),
			Color(AegisTokens.INFO, 0.85)
		)

	if has_objective:
		_draw_compass_pip(
			canvas,
			cam_pos,
			objective_pos,
			heading_deg,
			half_fov,
			cx,
			usable_half,
			rect.position.y + rect.size.y * 0.52,
			maxf(4.2 * scale, 3.2),
			AegisTokens.OK
		)

	for item in enemies:
		var enemy := item as Node3D
		if enemy == null or not is_instance_valid(enemy):
			continue
		var is_boss: bool = enemy.get("is_guardian_boss") == true
		_draw_compass_pip(
			canvas,
			cam_pos,
			enemy.global_position,
			heading_deg,
			half_fov,
			cx,
			usable_half,
			rect.position.y + rect.size.y * 0.52,
			maxf((4.6 if is_boss else 3.2) * scale, 2.5),
			AegisTokens.ACCENT if is_boss else AegisTokens.DANGER
		)


static func _bearing_label(norm_deg: int) -> String:
	match norm_deg:
		0:
			return "N"
		45:
			return "NE"
		90:
			return "E"
		135:
			return "SE"
		180:
			return "S"
		225:
			return "SW"
		270:
			return "W"
		315:
			return "NW"
		_:
			return ""


static func _draw_compass_pip(
	canvas: Control,
	origin: Vector3,
	target: Vector3,
	heading_deg: float,
	half_fov: float,
	cx: float,
	usable_half: float,
	cy: float,
	r: float,
	color: Color
) -> void:
	var to_t := Vector2(target.x - origin.x, target.z - origin.z)
	if to_t.length_squared() < 0.04:
		return
	var target_deg := fposmod(rad_to_deg(atan2(to_t.x, -to_t.y)), 360.0)
	var diff := wrapf(target_deg - heading_deg, -180.0, 180.0)
	var clamped := clampf(diff, -half_fov, half_fov)
	var px := cx + (clamped / half_fov) * usable_half
	var alpha := 0.96 if absf(diff) <= half_fov else 0.52
	(
		canvas
		. draw_colored_polygon(
			PackedVector2Array(
				[
					Vector2(px, cy - r),
					Vector2(px + r, cy),
					Vector2(px, cy + r),
					Vector2(px - r, cy),
				]
			),
			Color(color, alpha)
		)
	)


static func draw_reticle(hud: Control, layer: Control = null) -> void:
	var surface: Control = layer if is_instance_valid(layer) else hud
	if (
		hud.get("_player_down") == true
		or hud.get_tree() == null
		or hud.get_tree().paused
		or bool(hud.call("_results_visible"))
	):
		return
	var scrim := hud.get("_scrim") as Control
	var editor := hud.get("_hud_editor") as Control
	if (
		(is_instance_valid(scrim) and scrim.visible)
		or (is_instance_valid(editor) and editor.visible)
	):
		return
	var state = hud.get("_state")
	var touch_mode := bool(hud.call("is_touch_mode"))
	var center := hud.size * 0.5
	if (
		not touch_mode
		and state != null
		and bool(state.cursor_aim_active)
		and state.reticle_pos.x >= 0.0
	):
		center = state.reticle_pos.clamp(Vector2.ZERO, hud.size)
	var fire_rem := float(hud.get("_fire_flash_remaining"))
	var aiming: bool = hud.get("_aiming") == true
	var overcharged: bool = state != null and float(state.overcharge_seconds) > 0.0
	var spread := 5.0 + (fire_rem / 0.15) * 6.5
	if int(hud.get("_move_touch_id")) != -1:
		spread += 4.0
	if aiming:
		spread *= 0.42
	crosshair(
		surface,
		center,
		float(hud.call("_to_layout", 11.5 + spread)),
		maxf(float(hud.call("_to_layout", 6.8)), 2.5),
		maxf(float(hud.call("_to_layout", 1.7)), 1.1),
		AegisTokens.INK,
		Color(AegisTokens.VOID, 0.82),
		float(hud.get("_hit_confirm_remaining")) > 0.0,
		maxf(float(hud.call("_to_layout", 1.0)), 0.75),
		hud.get("_soft_lock") == true,
		aiming,
		overcharged
	)
