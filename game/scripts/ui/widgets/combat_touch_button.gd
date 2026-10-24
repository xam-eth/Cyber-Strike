## Combat actions use full-sized, legible finger targets; the image must do the
## explaining. No ornamental ring around a tiny pictogram: inspect the rendered
## 390x844 canvas before accepting the sizes or claiming it is comfortable.
class_name CombatTouchButton
extends AegisButton

@export var accent: Color = AegisTokens.INFO:
	set(value):
		accent = value
		queue_redraw()
@export var is_primary: bool = false:
	set(value):
		is_primary = value
		queue_redraw()

var _held: bool = false


func _ready() -> void:
	super._ready()
	button_down.connect(_set_held.bind(true))
	button_up.connect(_set_held.bind(false))


func _set_held(value: bool) -> void:
	_held = value
	queue_redraw()


func _draw() -> void:
	super._draw()
	if not is_primary or size.x < 24.0 or size.y < 24.0:
		return
	# Short amber tab, not a circular gauge: FIRE is the primary action even
	# when the player has not touched it. Pressing expands the tab in-place.
	var inset := size.x * (0.16 if _held else 0.31)
	var y := size.y - maxf(size.y * 0.045, 3.0)
	var thickness := maxf(size.y * 0.035, 2.0)
	draw_line(
		Vector2(inset, y),
		Vector2(size.x - inset, y),
		Color(accent, 1.0 if _held else 0.82),
		thickness,
		true
	)
