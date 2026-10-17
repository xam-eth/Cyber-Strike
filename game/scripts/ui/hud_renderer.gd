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
	outline_offset: float
) -> void:
	var resolved_gap := maxf(gap, tick + 2.0)
	var resolved_color := color
	if hit:
		resolved_color = AegisTokens.ACCENT
		resolved_gap *= 1.25
	for offset in [Vector2(1.0, 0.0), Vector2(-1.0, 0.0), Vector2(0.0, 1.0), Vector2(0.0, -1.0)]:
		_draw_ticks(
			host, center + offset * outline_offset, resolved_gap, tick, thickness + 1.0, outline
		)
	_draw_ticks(host, center, resolved_gap, tick, thickness, resolved_color)
	host.draw_circle(center, maxf(thickness * 1.2, 1.2), resolved_color)
	host.draw_arc(center, maxf(tick * 0.4, 1.8), 0.0, TAU, 16, outline, 1.0)


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
	host.draw_arc(center, radius, 0.0, TAU, 48, Color(AegisTokens.LINE_HI, 0.55), stroke, true)
	host.draw_arc(
		center, radius * 0.59, 0.0, TAU, 36, Color(AegisTokens.LINE_HI, 0.32), stroke, true
	)
	host.draw_circle(knob, radius * 0.40, Color(AegisTokens.PANEL_3, 0.82))
	host.draw_arc(
		knob,
		radius * 0.40,
		0.0,
		TAU,
		32,
		Color(AegisTokens.INK_2, 0.8),
		maxf(stroke * 1.5, 1.0),
		true
	)
