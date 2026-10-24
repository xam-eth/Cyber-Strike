## 270° countdown outside the EMP touch button; no ring when ready.
## `remaining` is the fraction of the cooldown left: a full arc right after
## use, shrinking clockwise until the skill is ready. The actual hit target is
## the 80 px button, not the decorative ring.
class_name CooldownRing
extends Control

const START_ANGLE := deg_to_rad(135.0)
const SWEEP := deg_to_rad(270.0)

var remaining: float = 0.0:
	set(value):
		remaining = clampf(value, 0.0, 1.0)
		queue_redraw()
## Named `available`, not `ready`: Node already has a `ready` signal and
## GDScript rejects a property that collides with it.
var available: bool = true:
	set(value):
		available = value
		queue_redraw()
var ring_color: Color = AegisTokens.ABILITY
var track_color: Color = Color(AegisTokens.LINE, 0.85)
var stroke: float = 2.0


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	resized.connect(queue_redraw)


func _draw() -> void:
	# The bold ability icon/keyline already says READY. Only show the ring when
	# a cooldown is actually counting down, not a third concentric bezel.
	if available or remaining <= 0.001:
		return
	var center := size * 0.5
	var radius := maxf(minf(size.x, size.y) * 0.5 - stroke, 1.0)
	draw_arc(center, radius, START_ANGLE, START_ANGLE + SWEEP, 40, track_color, stroke, true)
	if remaining > 0.001:
		draw_arc(
			center,
			radius,
			START_ANGLE,
			START_ANGLE + SWEEP * remaining,
			40,
			Color(ring_color, 0.9),
			stroke + 0.5,
			true
		)
