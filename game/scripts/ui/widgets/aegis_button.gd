## Button that can draw the AEGIS corner brackets and short status ticks.
##
## The styleboxes come from AegisTheme.set_button_variant(); this subclass only
## adds the drawn decoration that a StyleBox cannot express (corner cuts, an
## active tick row). Keeping it a Button means focus, keyboard activation and the
## existing `pressed` wiring keep working without a custom input path.
class_name AegisButton
extends Button

@export var show_brackets: bool = false:
	set(value):
		show_brackets = value
		queue_redraw()
@export var bracket_color: Color = AegisTokens.LINE_HI:
	set(value):
		bracket_color = value
		queue_redraw()
@export var bracket_length: float = 8.0
@export var bracket_inset: float = 4.0
## A 2 px accent edge on the left, used for the focused menu row / active chip.
@export var edge_active: bool = false:
	set(value):
		edge_active = value
		queue_redraw()
@export var edge_color: Color = AegisTokens.ACCENT
@export var edge_width: float = AegisTokens.ACCENT_EDGE


func _ready() -> void:
	resized.connect(queue_redraw)
	if show_brackets:
		queue_redraw()


func _draw() -> void:
	if edge_active:
		draw_rect(Rect2(0.0, 0.0, edge_width, size.y), edge_color, true)
	if not show_brackets:
		return
	var inset := bracket_inset
	var right := size.x - inset
	var bottom := size.y - inset
	var length := minf(bracket_length, minf(size.x, size.y) * 0.35)
	draw_line(Vector2(inset, inset), Vector2(inset + length, inset), bracket_color, 1.0)
	draw_line(Vector2(inset, inset), Vector2(inset, inset + length), bracket_color, 1.0)
	draw_line(Vector2(right - length, inset), Vector2(right, inset), bracket_color, 1.0)
	draw_line(Vector2(right, inset), Vector2(right, inset + length), bracket_color, 1.0)
	draw_line(Vector2(inset, bottom), Vector2(inset + length, bottom), bracket_color, 1.0)
	draw_line(Vector2(inset, bottom - length), Vector2(inset, bottom), bracket_color, 1.0)
	draw_line(Vector2(right - length, bottom), Vector2(right, bottom), bracket_color, 1.0)
	draw_line(Vector2(right, bottom - length), Vector2(right, bottom), bracket_color, 1.0)
