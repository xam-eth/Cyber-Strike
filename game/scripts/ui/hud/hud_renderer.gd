## Immediate-mode drawing for the parts of the HUD that a Control node cannot
## express: the reticle, the virtual joystick and the damage vignette.
##
## Kept out of touch_controls.gd so the layout/state facade stays reviewable and
## the drawing can be reused by the touch HUD preview in tools.
class_name HudRenderer
extends RefCounted


## Edge-only damage feedback: the world stays readable, unlike a full-screen
## flash. Three nested outlines fall off toward the centre.
static func damage_vignette(
	host: CanvasItem, viewport_size: Vector2, strength: float, thickness: float, color: Color
) -> void:
	for index in 3:
		var inset := float(index) * thickness * 0.8
		var alpha := (0.13 - float(index) * 0.035) * strength
		host.draw_rect(
			Rect2(inset, inset, viewport_size.x - inset * 2.0, viewport_size.y - inset * 2.0),
			Color(color, alpha),
			false,
			thickness
		)


## Four ticks and a dot. `hit` swaps the colour to amber and opens the gap by a
## quarter, which reads as a hit confirm without an extra sprite.
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
	aiming: bool = false
) -> void:
	var resolved_gap := maxf(gap, tick + 2.0)
	var resolved_color := color
	if hit:
		resolved_color = AegisTokens.ACCENT
		resolved_gap *= 1.25
	elif soft_lock:
		resolved_color = AegisTokens.INFO
		resolved_gap *= 0.85
	for offset in [Vector2(1.0, 0.0), Vector2(-1.0, 0.0), Vector2(0.0, 1.0), Vector2(0.0, -1.0)]:
		_draw_ticks(
			host, center + offset * outline_offset, resolved_gap, tick, thickness + 1.0, outline
		)
	_draw_ticks(host, center, resolved_gap, tick, thickness, resolved_color)
	host.draw_circle(center, maxf(thickness * 1.2, 1.2), resolved_color)
	host.draw_arc(center, maxf(tick * 0.4, 1.8), 0.0, TAU, 16, outline, 1.0)
	if aiming:
		var br := resolved_gap + tick + 4.0 * outline_offset
		var leg := maxf(4.5 * outline_offset, 3.5)
		var bc := Color(AegisTokens.INFO, 0.78)
		for sx in [-1.0, 1.0]:
			for sy in [-1.0, 1.0]:
				var corner := center + Vector2(sx * br, sy * br)
				host.draw_line(corner, corner - Vector2(sx * leg, 0.0), bc, 1.3, true)
				host.draw_line(corner, corner - Vector2(0.0, sy * leg), bc, 1.3, true)
	if soft_lock:
		host.draw_arc(
			center, resolved_gap + tick + 2.5, 0.0, TAU, 24, Color(AegisTokens.INFO, 0.52), 1.2
		)


static func _draw_ticks(
	host: CanvasItem, center: Vector2, gap: float, tick: float, thickness: float, color: Color
) -> void:
	host.draw_line(center + Vector2(gap, 0.0), center + Vector2(gap + tick, 0.0), color, thickness)
	host.draw_line(center - Vector2(gap, 0.0), center - Vector2(gap + tick, 0.0), color, thickness)
	host.draw_line(center + Vector2(0.0, gap), center + Vector2(0.0, gap + tick), color, thickness)
	host.draw_line(center - Vector2(0.0, gap), center - Vector2(0.0, gap + tick), color, thickness)


## Virtual joystick: a 128 px outer ring, a 76 px inner ring and a 52 px knob.
## The knob follows the thumb; the rings stay at home so muscle memory survives.
static func joystick(
	host: CanvasItem, center: Vector2, radius: float, knob: Vector2, stroke: float
) -> void:
	var active := center.distance_to(knob) > 2.0
	host.draw_circle(center, radius, Color(AegisTokens.PANEL, 0.32))
	host.draw_arc(
		center,
		radius,
		0.0,
		TAU,
		48,
		Color(AegisTokens.INFO if active else AegisTokens.INK_2, 0.82),
		stroke,
		true
	)
	host.draw_arc(
		center, radius * 0.59, 0.0, TAU, 36, Color(AegisTokens.LINE_HI, 0.36), stroke, true
	)
	var tick_len := maxf(4.5 * stroke, 3.5)
	for dir in [Vector2.UP, Vector2.DOWN, Vector2.LEFT, Vector2.RIGHT]:
		host.draw_line(
			center + dir * (radius - tick_len),
			center + dir * radius,
			Color(AegisTokens.INFO, 0.55),
			maxf(stroke, 1.0),
			true
		)
	# The thumb may drag arbitrarily far; the visual knob must remain inside the
	# fixed ring instead of following it over the rest of the HUD.
	var visual_knob := center + (knob - center).limit_length(radius * 0.60)
	if active:
		host.draw_line(
			center, visual_knob, Color(AegisTokens.INFO, 0.55), maxf(stroke * 1.2, 1.2), true
		)
	host.draw_circle(visual_knob, radius * 0.40, Color(AegisTokens.PANEL_3, 0.88))
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


## Draws the top-center tactical azimuth compass driven by live Camera3D yaw,
## active hostiles, and any tracked Recovery objective waypoint onto its own
## lightweight Control layer so camera turns never rebuild TouchControls docks.
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
	var health_c := hud.get("_health_card") as Control
	var wave_c := hud.get("_wave_card") as Control
	var left_bound := safe_l
	for card in [health_c, wave_c]:
		if is_instance_valid(card) and card.visible:
			left_bound = maxf(left_bound, card.position.x + card.size.x)
	left_bound += 12.0 * scale

	var right_bound := hud.size.x - float(hud.get("_safe_right"))
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
			and right_ctrl.position.y < float(hud.get("_top_inset")) + 54.0 * scale
		):
			right_bound = minf(right_bound, right_ctrl.position.x)
	right_bound -= 12.0 * scale

	var avail_w := right_bound - left_bound
	var min_w := 124.0 * scale
	if avail_w < min_w:
		return
	var target_w := minf(avail_w, 236.0 * scale)
	var cx := clampf(hud.size.x * 0.5, left_bound + target_w * 0.5, right_bound - target_w * 0.5)
	var top_y := float(hud.get("_top_inset"))
	var h := 20.0 * scale
	var rect := Rect2(cx - target_w * 0.5, top_y, target_w, h)

	var enemies: Array = []
	var src := hud.get("_hostile_source") as Node
	if is_instance_valid(src) and src.has_method("get_active_enemies"):
		var raw: Variant = src.call("get_active_enemies")
		if raw is Array:
			enemies = raw

	var state_obj: Variant = hud.get("_state")
	var has_obj := false
	var obj_pos := Vector3.ZERO
	if state_obj != null:
		has_obj = state_obj.get("objective_has_target") == true
		var raw_pos: Variant = state_obj.get("objective_world_pos")
		if raw_pos is Vector3:
			obj_pos = raw_pos

	compass_strip(surface, cam, enemies, has_obj, obj_pos, rect, scale)


static func compass_strip(
	canvas: Control,
	camera: Camera3D,
	enemies: Array,
	has_objective: bool,
	objective_pos: Vector3,
	rect: Rect2,
	scale: float
) -> void:
	var cut := minf(6.0 * scale, rect.size.y * 0.42)
	var poly := PackedVector2Array(
		[
			Vector2(rect.position.x + cut, rect.position.y),
			Vector2(rect.end.x - cut, rect.position.y),
			Vector2(rect.end.x, rect.position.y + cut),
			Vector2(rect.end.x, rect.end.y),
			Vector2(rect.position.x, rect.end.y),
			Vector2(rect.position.x, rect.position.y + cut),
		]
	)
	canvas.draw_colored_polygon(poly, Color(AegisTokens.VOID, 0.74))
	var closed := poly.duplicate()
	closed.append(poly[0])
	canvas.draw_polyline(closed, Color(AegisTokens.LINE_HI, 0.65), 1.0, true)
	canvas.draw_line(
		Vector2(rect.position.x + cut, rect.position.y),
		Vector2(rect.end.x - cut, rect.position.y),
		Color(AegisTokens.INFO, 0.85),
		1.5,
		true
	)

	var fwd := -camera.global_transform.basis.z
	var flat_fwd := Vector2(fwd.x, fwd.z)
	flat_fwd = Vector2(0.0, -1.0) if flat_fwd.length_squared() < 0.0001 else flat_fwd.normalized()
	var heading_deg := fposmod(rad_to_deg(atan2(flat_fwd.x, -flat_fwd.y)), 360.0)
	var half_fov := 65.0
	var usable_half := maxf(rect.size.x * 0.5 - 10.0 * scale, 24.0)
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
		var tick_h := (5.0 if is_cardinal else 2.8) * scale
		canvas.draw_line(
			Vector2(tx, rect.end.y - tick_h),
			Vector2(tx, rect.end.y - 1.0),
			Color(AegisTokens.INFO if is_cardinal else AegisTokens.LINE_HI, 0.78),
			1.2 if is_cardinal else 1.0
		)
		if is_cardinal and mono != null:
			var card_txt := "N"
			if norm_deg == 90:
				card_txt = "E"
			elif norm_deg == 180:
				card_txt = "S"
			elif norm_deg == 270:
				card_txt = "W"
			canvas.draw_string(
				mono,
				Vector2(tx - 3.2 * scale, rect.position.y + rect.size.y * 0.66),
				card_txt,
				HORIZONTAL_ALIGNMENT_LEFT,
				-1,
				font_sz,
				AegisTokens.INK if norm_deg == 0 else AegisTokens.INK_2
			)

	var tri := maxf(3.2 * scale, 2.5)
	(
		canvas
		. draw_colored_polygon(
			PackedVector2Array(
				[
					Vector2(cx - tri, rect.position.y),
					Vector2(cx + tri, rect.position.y),
					Vector2(cx, rect.position.y + tri * 1.4),
				]
			),
			AegisTokens.ACCENT
		)
	)

	var cam_pos := camera.global_position
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
			maxf(3.8 * scale, 3.0),
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
			maxf((4.4 if is_boss else 3.0) * scale, 2.5),
			AegisTokens.ACCENT if is_boss else AegisTokens.DANGER
		)


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
