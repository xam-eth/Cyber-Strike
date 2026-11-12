class_name HudMinimap
extends Control

## Tactical minimap: a live top-down view of the real mission world.
##
## Every dot is a real game object supplied through `HudState.map_points`
## (caches with their secured/optional/target states, the live objective) plus
## the player's true world position and yaw. The route polyline is the authored
## guidance path. Nothing here invents state — the map is a second view of the
## same facts the mission card and the compass already show, resolved into
## "where am I, which way is the next thing" at a glance.
##
## Painted entirely from primitives in the chamfered dark sci-fi language so it
## scales with the HUD stretch like every other plate.

const PAD := 8.0
const DOT_CACHE := 4.6
const GRID_STEP := 0.25

var _state: HudState = null
var _pulse: float = 0.0


func _init(state: HudState) -> void:
	_state = state
	custom_minimum_size = Vector2(150, 150)
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func _process(delta: float) -> void:
	_pulse = fmod(_pulse + delta, TAU)
	if visible:
		queue_redraw()


func set_state(state: HudState) -> void:
	_state = state


func _draw() -> void:
	if _state == null:
		return
	var rect := Rect2(Vector2.ZERO, size)
	_draw_panel(rect)
	var map_rect := rect.grow(-PAD)
	_draw_grid(map_rect)
	var xf := _world_to_map(map_rect)
	if _state.map_route.size() >= 2:
		_draw_route(map_rect, xf)
	_draw_points(map_rect, xf)
	_draw_player(map_rect, xf)
	_draw_north_glyph(map_rect)


## Panel with chamfered corners (the Aegis cut), dark glass + hairline border.
func _draw_panel(rect: Rect2) -> void:
	var cut := 10.0
	var pts := PackedVector2Array(
		[
			rect.position + Vector2(cut, 0),
			rect.position + Vector2(rect.size.x, 0),
			rect.position + Vector2(rect.size.x, rect.size.y - cut),
			rect.position + Vector2(rect.size.x - cut, rect.size.y),
			rect.position + Vector2(0, rect.size.y),
			rect.position + Vector2(0, cut)
		]
	)
	draw_colored_polygon(
		pts, Color(AegisTokens.PANEL.r, AegisTokens.PANEL.g, AegisTokens.PANEL.b, 0.86)
	)
	draw_polyline(
		PackedVector2Array([pts[0], pts[1], pts[2], pts[3], pts[4], pts[5], pts[0]]),
		Color(AegisTokens.LINE.r, AegisTokens.LINE.g, AegisTokens.LINE.b, 0.95),
		1.2
	)
	# Accent corner tick: top-left origin mark.
	draw_line(
		rect.position + Vector2(cut, 2),
		rect.position + Vector2(cut + 18, 2),
		AegisTokens.ACCENT,
		2.0
	)


func _draw_grid(map_rect: Rect2) -> void:
	var grid := Color(AegisTokens.LINE.r, AegisTokens.LINE.g, AegisTokens.LINE.b, 0.28)
	var step := map_rect.size.x * GRID_STEP
	var x := map_rect.position.x + step
	while x < map_rect.end.x - 1.0:
		draw_line(Vector2(x, map_rect.position.y), Vector2(x, map_rect.end.y), grid, 1.0)
		x += step
	var y := map_rect.position.y + step
	while y < map_rect.end.y - 1.0:
		draw_line(Vector2(map_rect.position.x, y), Vector2(map_rect.end.x, y), grid, 1.0)
		y += step


func _world_to_map(map_rect: Rect2) -> Callable:
	var center := _state.map_center
	var radius: float = maxf(_state.map_radius, 1.0)
	var half := map_rect.size * 0.5
	var mid := map_rect.position + half
	var scale := half.x / radius

	return func(world: Vector2) -> Vector2:
		return mid + Vector2((world.x - center.x) * scale, (world.y - center.y) * scale)


func _draw_route(_map_rect: Rect2, xf: Callable) -> void:
	var pts := PackedVector2Array()
	for i in _state.map_route.size():
		var p: Vector2 = xf.call(_state.map_route[i])
		pts.append(p)
	var route := Color(AegisTokens.ACCENT.r, AegisTokens.ACCENT.g, AegisTokens.ACCENT.b, 0.38)
	draw_polyline(pts, route, 2.2)


func _draw_points(map_rect: Rect2, xf: Callable) -> void:
	for point in _state.map_points:
		var world := Vector2(float(point.get("x", 0.0)), float(point.get("z", 0.0)))
		var pos: Vector2 = xf.call(world)
		if not map_rect.grow(6.0).has_point(pos):
			continue
		var kind := String(point.get("kind", "cache"))
		var secured := bool(point.get("secured", false))
		var target := bool(point.get("target", false))
		match kind:
			"objective":
				var color := AegisTokens.ACCENT
				HudIcons.draw_icon(
					self, &"marker", Rect2(pos - Vector2(11, 13), Vector2(22, 26)), color, color
				)
			"cache", "optional":
				var color := (
					Color(AegisTokens.INK.r, AegisTokens.INK.g, AegisTokens.INK.b, 0.4)
					if secured
					else (AegisTokens.ACCENT if target else AegisTokens.INFO)
				)
				var r := DOT_CACHE * (1.35 if target else 1.0)
				draw_circle(pos, r + 2.2, Color(0, 0, 0, 0.55))
				draw_circle(pos, r, color)
				if secured:
					draw_arc(
						pos, r + 2.4, 0.0, TAU, 16, Color(color.r, color.g, color.b, 0.55), 1.2
					)
				if target:
					var ring := 0.5 + 0.5 * sin(_pulse * 2.4)
					draw_arc(
						pos,
						r + 5.0 + ring * 2.5,
						0.0,
						TAU,
						24,
						Color(
							AegisTokens.ACCENT.r, AegisTokens.ACCENT.g, AegisTokens.ACCENT.b, 0.65
						),
						1.8
					)
				if not secured and kind == "optional":
					draw_arc(
						pos,
						r + 2.4,
						0.0,
						TAU,
						16,
						Color(AegisTokens.INFO.r, AegisTokens.INFO.g, AegisTokens.INFO.b, 0.7),
						1.2
					)


func _draw_player(map_rect: Rect2, xf: Callable) -> void:
	var pos: Vector2 = xf.call(_state.map_center + Vector2.ZERO)
	var player_world := Vector2(_state.player_world_pos.x, _state.player_world_pos.z)
	pos = xf.call(player_world)
	if not map_rect.grow(10.0).has_point(pos):
		return
	var yaw := _state.player_yaw
	# World yaw 0 faces -Z (map up); rotate the blip by yaw around its centre.
	var s := 9.0
	var pts := PackedVector2Array(
		[
			Vector2(0, -s),
			Vector2(s * 0.82, s * 0.95),
			Vector2(0, s * 0.38),
			Vector2(-s * 0.82, s * 0.95)
		]
	)
	var xform := Transform2D(yaw, pos)
	var world_pts := PackedVector2Array()
	for p in pts:
		world_pts.append(xform.xform(p))
	draw_colored_polygon(world_pts, AegisTokens.ACCENT)
	draw_polyline(
		PackedVector2Array([world_pts[0], world_pts[1], world_pts[2], world_pts[3], world_pts[0]]),
		AegisTokens.ACCENT_INK,
		1.2
	)
	draw_circle(pos, 2.4, AegisTokens.ACCENT_INK)


func _draw_north_glyph(map_rect: Rect2) -> void:
	var g := Rect2(map_rect.position + Vector2(2, 2), Vector2(16, 16))
	HudIcons.draw_icon(self, &"north", g, AegisTokens.INK_2, AegisTokens.INK)
