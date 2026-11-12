class_name HudIcons
extends RefCounted

## Custom vector icon language for the gameplay HUD.
##
## Every glyph is painted from primitives — no icon fonts, no bitmaps — so the
## set scales crisply at any HUD stretch and matches the chamfered dark sci-fi
## language of the Aegis panels. One entry point (`draw_icon`) dispatches by
## name so buttons, cards and the minimap share a single visual vocabulary.
##
## The glyphs follow the shooter HUD conventions the layout is built on
## (Free Fire / PUBG Mobile / Valorant): a bullet for fire, a sight for ADS,
## a rotating arrow for reload, a rising figure for jump, an EMP bolt for the
## operative skill. Small captions under the icons stay as accessibility text.

const STROKE := 2.1


static func draw_icon(
	canvas: CanvasItem,
	icon: StringName,
	rect: Rect2,
	color: Color,
	accent: Color = Color(0, 0, 0, 0)
) -> void:
	if canvas == null or rect.size.x <= 1.0 or rect.size.y <= 1.0:
		return
	var accent_c := accent if accent.a > 0.01 else color
	match icon:
		&"fire":
			_draw_fire(canvas, rect, color, accent_c)
		&"scope":
			_draw_scope(canvas, rect, color, accent_c)
		&"reload":
			_draw_reload(canvas, rect, color, accent_c)
		&"jump":
			_draw_jump(canvas, rect, color, accent_c)
		&"skill":
			_draw_skill(canvas, rect, color, accent_c)
		&"swap":
			_draw_swap(canvas, rect, color, accent_c)
		&"armory":
			_draw_armory(canvas, rect, color, accent_c)
		&"vitals":
			_draw_vitals(canvas, rect, color, accent_c)
		&"shield":
			_draw_shield(canvas, rect, color, accent_c)
		&"skull":
			_draw_skull(canvas, rect, color, accent_c)
		&"coin":
			_draw_coin(canvas, rect, color, accent_c)
		&"clock":
			_draw_clock(canvas, rect, color, accent_c)
		&"target":
			_draw_target(canvas, rect, color, accent_c)
		&"rifle":
			_draw_rifle(canvas, rect, color, accent_c)
		&"marker":
			_draw_marker(canvas, rect, color, accent_c)
		&"player":
			_draw_player(canvas, rect, color, accent_c)
		&"bolt":
			_draw_bolt(canvas, rect, color, accent_c)
		&"defense":
			_draw_defense(canvas, rect, color, accent_c)
		&"interact":
			_draw_interact(canvas, rect, color, accent_c)
		&"north":
			_draw_north(canvas, rect, color, accent_c)
		_:
			_draw_target(canvas, rect, color, accent_c)


## Glyph helpers -------------------------------------------------------------
## All glyphs paint inside `rect`; strokes scale with the rect's short side so
## the language stays consistent from a 40 px caption chip to a 96 px fire
## plate. `accent_c` fills the primary mass; `color` draws the detail strokes.


static func _u(rect: Rect2) -> float:
	return minf(rect.size.x, rect.size.y) / 16.0


static func _stroke_w(rect: Rect2) -> float:
	return maxf(1.6, _u(rect) * STROKE)


static func _draw_fire(canvas: CanvasItem, rect: Rect2, color: Color, accent: Color) -> void:
	# Cartridge silhouette with a pointed tip: the fire/action primary.
	var u := _u(rect)
	var c := rect.get_center()
	var body := rect.size.y * 0.44
	canvas.draw_rect(
		Rect2(c.x - body * 0.32, c.y - body * 0.28, body * 0.64, body * 0.95), accent, true
	)
	var tip := PackedVector2Array(
		[
			Vector2(c.x - body * 0.32, c.y - body * 0.28),
			Vector2(c.x + body * 0.32, c.y - body * 0.28),
			Vector2(c.x, c.y - body * 0.78)
		]
	)
	canvas.draw_colored_polygon(tip, accent)
	canvas.draw_line(
		Vector2(c.x - body * 0.32, c.y + body * 0.22),
		Vector2(c.x + body * 0.32, c.y + body * 0.22),
		color,
		_stroke_w(rect) * 0.8
	)
	canvas.draw_line(
		Vector2(c.x - body * 0.32, c.y + body * 0.5),
		Vector2(c.x + body * 0.32, c.y + body * 0.5),
		color,
		_stroke_w(rect) * 0.8
	)
	canvas.draw_circle(Vector2(c.x, c.y + body * 0.72), u * 0.9, accent)


static func _draw_scope(canvas: CanvasItem, rect: Rect2, color: Color, accent: Color) -> void:
	# Crosshair sight: reticle circle with four ticks and a centre dot.
	var u := _u(rect)
	var c := rect.get_center()
	var r := rect.size.x * 0.3
	canvas.draw_arc(c, r, 0.0, TAU, 40, accent, _stroke_w(rect))
	canvas.draw_line(c + Vector2(-r * 1.45, 0), c + Vector2(-r * 0.55, 0), color, _stroke_w(rect))
	canvas.draw_line(c + Vector2(r * 0.55, 0), c + Vector2(r * 1.45, 0), color, _stroke_w(rect))
	canvas.draw_line(c + Vector2(0, -r * 1.45), c + Vector2(0, -r * 0.55), color, _stroke_w(rect))
	canvas.draw_line(c + Vector2(0, r * 0.55), c + Vector2(0, r * 1.45), color, _stroke_w(rect))
	canvas.draw_circle(c, u * 0.85, accent)


static func _draw_reload(canvas: CanvasItem, rect: Rect2, color: Color, accent: Color) -> void:
	# Open circular arrow around a magazine block.
	var u := _u(rect)
	var c := rect.get_center()
	var r := rect.size.x * 0.3
	canvas.draw_arc(c, r, -TAU * 0.42, TAU * 0.32, 36, accent, _stroke_w(rect))
	var arrow := PackedVector2Array(
		[
			c + Vector2(-r * 0.55, -r * 0.95),
			c + Vector2(-r * 0.05, -r * 1.12),
			c + Vector2(-r * 0.18, -r * 0.55)
		]
	)
	canvas.draw_colored_polygon(arrow, accent)
	canvas.draw_rect(
		Rect2(c.x - u * 2.1, c.y - u * 0.4, u * 4.2, u * 3.0), color, false, _stroke_w(rect) * 0.8
	)
	canvas.draw_line(
		Vector2(c.x - u * 2.1, c.y + u * 1.1),
		Vector2(c.x + u * 2.1, c.y + u * 1.1),
		color,
		_stroke_w(rect) * 0.8
	)


static func _draw_jump(canvas: CanvasItem, rect: Rect2, color: Color, accent: Color) -> void:
	# Rising chevron over a ground line.
	var u := _u(rect)
	var c := rect.get_center()
	var body := rect.size.x * 0.26
	var chev := PackedVector2Array(
		[
			Vector2(c.x - body, c.y + body * 0.35),
			Vector2(c.x, c.y - body * 0.75),
			Vector2(c.x + body, c.y + body * 0.35),
			Vector2(c.x + body * 0.55, c.y + body * 0.35),
			Vector2(c.x, c.y - body * 0.18),
			Vector2(c.x - body * 0.55, c.y + body * 0.35)
		]
	)
	canvas.draw_colored_polygon(chev, accent)
	canvas.draw_line(
		Vector2(c.x - body * 1.2, c.y + body * 1.1),
		Vector2(c.x + body * 1.2, c.y + body * 1.1),
		color,
		_stroke_w(rect)
	)
	canvas.draw_line(
		Vector2(c.x - body * 1.2, c.y + body * 1.55),
		Vector2(c.x + body * 0.3, c.y + body * 1.55),
		color,
		_stroke_w(rect) * 0.7
	)


static func _draw_skill(canvas: CanvasItem, rect: Rect2, color: Color, accent: Color) -> void:
	_draw_bolt(canvas, rect, color, accent)


static func _draw_bolt(canvas: CanvasItem, rect: Rect2, color: Color, accent: Color) -> void:
	# Lightning bolt: the operative skill / energy primary.
	var c := rect.get_center()
	var s := rect.size.x * 0.32
	var bolt := PackedVector2Array(
		[
			c + Vector2(s * 0.25, -s * 1.15),
			c + Vector2(-s * 0.72, s * 0.18),
			c + Vector2(-s * 0.1, s * 0.18),
			c + Vector2(-s * 0.28, s * 1.15),
			c + Vector2(s * 0.72, -s * 0.12),
			c + Vector2(s * 0.1, -s * 0.12)
		]
	)
	canvas.draw_colored_polygon(bolt, accent)
	canvas.draw_polyline(
		PackedVector2Array([bolt[0], bolt[1], bolt[2], bolt[3], bolt[4], bolt[5], bolt[0]]),
		color,
		_stroke_w(rect) * 0.55
	)


static func _draw_swap(canvas: CanvasItem, rect: Rect2, _color: Color, accent: Color) -> void:
	# Two opposed arrows: weapon swap.
	var u := _u(rect)
	var c := rect.get_center()
	var w := rect.size.x * 0.3
	canvas.draw_line(c + Vector2(-w, -u * 2.2), c + Vector2(w, -u * 2.2), accent, _stroke_w(rect))
	canvas.draw_line(c + Vector2(w, u * 2.2), c + Vector2(-w, u * 2.2), accent, _stroke_w(rect))
	var head_r := PackedVector2Array(
		[
			c + Vector2(w + u * 2.0, -u * 2.2),
			c + Vector2(w + u * 0.1, -u * 3.6),
			c + Vector2(w + u * 0.1, -u * 0.8)
		]
	)
	canvas.draw_colored_polygon(head_r, accent)
	var head_l := PackedVector2Array(
		[
			c + Vector2(-w - u * 2.0, u * 2.2),
			c + Vector2(-w - u * 0.1, u * 3.6),
			c + Vector2(-w - u * 0.1, u * 0.8)
		]
	)
	canvas.draw_colored_polygon(head_l, accent)


static func _draw_armory(canvas: CanvasItem, rect: Rect2, color: Color, accent: Color) -> void:
	# Chamfered crate with a lock bar.
	var u := _u(rect)
	var c := rect.get_center()
	var w := rect.size.x * 0.32
	canvas.draw_rect(
		Rect2(c.x - w, c.y - w * 0.72, w * 2, w * 1.44), accent, false, _stroke_w(rect)
	)
	canvas.draw_line(
		Vector2(c.x - w, c.y - w * 0.18),
		Vector2(c.x + w, c.y - w * 0.18),
		color,
		_stroke_w(rect) * 0.8
	)
	canvas.draw_rect(
		Rect2(c.x - u * 1.5, c.y + u * 0.3, u * 3.0, u * 2.4), color, false, _stroke_w(rect) * 0.7
	)


static func _draw_vitals(canvas: CanvasItem, rect: Rect2, color: Color, accent: Color) -> void:
	# Heart mass with an ECG pulse slash: player vitals.
	var u := _u(rect)
	var c := rect.get_center()
	var s := rect.size.x * 0.3
	canvas.draw_circle(c + Vector2(-s * 0.52, -s * 0.32), s * 0.58, accent)
	canvas.draw_circle(c + Vector2(s * 0.52, -s * 0.32), s * 0.58, accent)
	var body := PackedVector2Array(
		[
			c + Vector2(-s * 1.08, -s * 0.12),
			c + Vector2(s * 1.08, -s * 0.12),
			c + Vector2(0.0, s * 1.12)
		]
	)
	canvas.draw_colored_polygon(body, accent)
	canvas.draw_polyline(
		PackedVector2Array(
			[
				c + Vector2(-s * 1.15, s * 0.05),
				c + Vector2(-s * 0.45, s * 0.62),
				c + Vector2(0.0, s * 1.18)
			]
		),
		color,
		_stroke_w(rect) * 0.7
	)
	canvas.draw_polyline(
		PackedVector2Array(
			[
				c + Vector2(s * 1.15, s * 0.05),
				c + Vector2(s * 0.45, s * 0.62),
				c + Vector2(0.0, s * 1.18)
			]
		),
		color,
		_stroke_w(rect) * 0.7
	)
	var ecg := PackedVector2Array(
		[
			c + Vector2(-s * 1.25, -s * 0.22),
			c + Vector2(-s * 0.5, -s * 0.22),
			c + Vector2(-s * 0.25, -s * 0.62),
			c + Vector2(s * 0.05, s * 0.18),
			c + Vector2(s * 0.35, -s * 0.22),
			c + Vector2(s * 1.25, -s * 0.22)
		]
	)
	canvas.draw_polyline(ecg, Color(color.r, color.g, color.b, 0.95), _stroke_w(rect) * 0.62)


static func _draw_shield(canvas: CanvasItem, rect: Rect2, color: Color, accent: Color) -> void:
	var u := _u(rect)
	var c := rect.get_center()
	var s := rect.size.x * 0.3
	var body := PackedVector2Array(
		[
			c + Vector2(0.0, -s * 1.15),
			c + Vector2(s * 0.95, -s * 0.72),
			c + Vector2(s * 0.95, s * 0.12),
			c + Vector2(0.0, s * 1.18),
			c + Vector2(-s * 0.95, s * 0.12),
			c + Vector2(-s * 0.95, -s * 0.72)
		]
	)
	canvas.draw_colored_polygon(body, accent)
	canvas.draw_polyline(
		PackedVector2Array([body[0], body[1], body[2], body[3]]), color, _stroke_w(rect) * 0.6
	)
	canvas.draw_polyline(
		PackedVector2Array([body[3], body[4], body[5], body[0]]), color, _stroke_w(rect) * 0.6
	)
	canvas.draw_line(
		c + Vector2(-s * 0.42, -s * 0.05),
		c + Vector2(-s * 0.08, s * 0.32),
		color,
		_stroke_w(rect) * 0.7
	)
	canvas.draw_line(
		c + Vector2(-s * 0.08, s * 0.32),
		c + Vector2(s * 0.5, -s * 0.5),
		color,
		_stroke_w(rect) * 0.7
	)


static func _draw_skull(canvas: CanvasItem, rect: Rect2, color: Color, accent: Color) -> void:
	var u := _u(rect)
	var c := rect.get_center()
	var s := rect.size.x * 0.28
	canvas.draw_circle(c + Vector2(0, -s * 0.25), s * 0.95, accent)
	canvas.draw_rect(Rect2(c.x - s * 0.55, c.y + s * 0.35, s * 1.1, s * 0.62), accent, true)
	canvas.draw_circle(c + Vector2(-s * 0.42, -s * 0.3), s * 0.27, color)
	canvas.draw_circle(c + Vector2(s * 0.42, -s * 0.3), s * 0.27, color)
	canvas.draw_line(
		Vector2(c.x - s * 0.55, c.y + s * 0.66),
		Vector2(c.x + s * 0.55, c.y + s * 0.66),
		color,
		_stroke_w(rect) * 0.6
	)


static func _draw_coin(canvas: CanvasItem, rect: Rect2, color: Color, accent: Color) -> void:
	var c := rect.get_center()
	var s := rect.size.x * 0.3
	canvas.draw_circle(c, s * 1.05, accent)
	canvas.draw_arc(c, s * 1.05, 0.0, TAU, 32, color, _stroke_w(rect) * 0.7)
	canvas.draw_arc(c, s * 0.58, 0.0, TAU, 24, color, _stroke_w(rect) * 0.7)


static func _draw_clock(canvas: CanvasItem, rect: Rect2, color: Color, accent: Color) -> void:
	var c := rect.get_center()
	var s := rect.size.x * 0.3
	canvas.draw_circle(c, s * 1.02, Color(accent.r, accent.g, accent.b, 0.22))
	canvas.draw_arc(c, s * 1.02, 0.0, TAU, 32, accent, _stroke_w(rect) * 0.85)
	canvas.draw_line(c, c + Vector2(0, -s * 0.62), color, _stroke_w(rect) * 0.8)
	canvas.draw_line(c, c + Vector2(s * 0.48, 0), color, _stroke_w(rect) * 0.8)


static func _draw_target(canvas: CanvasItem, rect: Rect2, color: Color, accent: Color) -> void:
	var c := rect.get_center()
	var s := rect.size.x * 0.3
	canvas.draw_arc(c, s * 1.0, 0.0, TAU, 32, accent, _stroke_w(rect) * 0.85)
	canvas.draw_arc(c, s * 0.52, 0.0, TAU, 24, color, _stroke_w(rect) * 0.7)
	canvas.draw_circle(c, s * 0.14, accent)


static func _draw_rifle(canvas: CanvasItem, rect: Rect2, color: Color, accent: Color) -> void:
	# Side-profile rifle silhouette for the weapon card.
	var u := _u(rect)
	var c := rect.get_center()
	var w := rect.size.x * 0.42
	var h := rect.size.y * 0.1
	# Barrel + handguard.
	canvas.draw_rect(Rect2(c.x - w * 0.25, c.y - h * 1.15, w * 1.25, h * 0.95), accent, true)
	# Receiver.
	canvas.draw_rect(Rect2(c.x - w * 0.72, c.y - h * 1.35, w * 0.75, h * 1.35), accent, true)
	# Stock.
	var stock := PackedVector2Array(
		[
			c + Vector2(-w * 1.12, h * 0.1),
			c + Vector2(-w * 0.68, -h * 0.28),
			c + Vector2(-w * 0.68, h * 0.28),
			c + Vector2(-w * 1.12, h * 0.62)
		]
	)
	canvas.draw_colored_polygon(stock, accent)
	# Magazine (curved suggestion).
	canvas.draw_rect(Rect2(c.x - w * 0.28, c.y + h * 0.05, w * 0.28, h * 1.5), accent, true)
	# Grip.
	var grip := PackedVector2Array(
		[
			c + Vector2(-w * 0.62, h * 0.02),
			c + Vector2(-w * 0.38, h * 0.02),
			c + Vector2(-w * 0.3, h * 1.35),
			c + Vector2(-w * 0.58, h * 1.35)
		]
	)
	canvas.draw_colored_polygon(grip, accent)
	# Detail strokes.
	canvas.draw_line(
		c + Vector2(-w * 0.25, -h * 0.75),
		c + Vector2(w * 0.95, -h * 0.75),
		color,
		_stroke_w(rect) * 0.5
	)
	canvas.draw_line(
		c + Vector2(-w * 0.95, h * 0.16),
		c + Vector2(-w * 0.72, h * 0.16),
		color,
		_stroke_w(rect) * 0.5
	)


static func _draw_marker(canvas: CanvasItem, rect: Rect2, color: Color, accent: Color) -> void:
	# Map pin / objective waypoint: teardrop with a ring core.
	var c := rect.get_center()
	var s := rect.size.x * 0.3
	canvas.draw_circle(c + Vector2(0, -s * 0.38), s * 0.82, accent)
	var tail := PackedVector2Array(
		[
			c + Vector2(-s * 0.58, -s * 0.02),
			c + Vector2(s * 0.58, -s * 0.02),
			c + Vector2(0.0, s * 1.12)
		]
	)
	canvas.draw_colored_polygon(tail, accent)
	canvas.draw_circle(c + Vector2(0, -s * 0.38), s * 0.34, color)


static func _draw_player(canvas: CanvasItem, rect: Rect2, color: Color, accent: Color) -> void:
	# Forward-facing arrow: the player blip on the minimap.
	var c := rect.get_center()
	var s := rect.size.x * 0.36
	var arrow := PackedVector2Array(
		[
			c + Vector2(0.0, -s * 1.15),
			c + Vector2(s * 0.92, s * 0.95),
			c + Vector2(0.0, s * 0.42),
			c + Vector2(-s * 0.92, s * 0.95)
		]
	)
	canvas.draw_colored_polygon(arrow, accent)
	canvas.draw_polyline(
		PackedVector2Array([arrow[0], arrow[1], arrow[2], arrow[3], arrow[0]]),
		color,
		_stroke_w(rect) * 0.55
	)


static func _draw_defense(canvas: CanvasItem, rect: Rect2, color: Color, accent: Color) -> void:
	# Shield over a base line: defend / hold.
	_draw_shield(canvas, rect, color, accent)
	var c := rect.get_center()
	var s := rect.size.x * 0.3
	canvas.draw_line(
		c + Vector2(-s * 1.15, s * 1.32),
		c + Vector2(s * 1.15, s * 1.32),
		color,
		_stroke_w(rect) * 0.8
	)


static func _draw_interact(canvas: CanvasItem, rect: Rect2, color: Color, accent: Color) -> void:
	# Hand-reach chevron into a panel slot.
	var u := _u(rect)
	var c := rect.get_center()
	var s := rect.size.x * 0.3
	canvas.draw_rect(
		Rect2(c.x + s * 0.1, c.y - s * 0.75, s * 0.95, s * 1.5),
		accent,
		false,
		_stroke_w(rect) * 0.85
	)
	var chev := PackedVector2Array(
		[
			c + Vector2(-s * 1.15, -s * 0.55),
			c + Vector2(-s * 0.25, 0.0),
			c + Vector2(-s * 1.15, s * 0.55),
			c + Vector2(-s * 0.72, 0.0)
		]
	)
	canvas.draw_colored_polygon(chev, accent)
	canvas.draw_line(
		c + Vector2(-s * 0.95, 0.0), c + Vector2(s * 0.05, 0.0), color, _stroke_w(rect) * 0.7
	)


static func _draw_north(canvas: CanvasItem, rect: Rect2, color: Color, accent: Color) -> void:
	# North marker for the minimap: filled up-triangle with a stem.
	var c := rect.get_center()
	var s := rect.size.x * 0.34
	var tri := PackedVector2Array(
		[
			c + Vector2(0.0, -s * 1.1),
			c + Vector2(s * 0.8, s * 0.55),
			c + Vector2(-s * 0.8, s * 0.55)
		]
	)
	canvas.draw_colored_polygon(tri, accent)
	canvas.draw_line(
		c + Vector2(0, -s * 1.1), c + Vector2(0, s * 0.55), color, _stroke_w(rect) * 0.5
	)
