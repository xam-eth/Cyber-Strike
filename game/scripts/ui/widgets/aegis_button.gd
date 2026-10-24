## Button that draws the AEGIS cut corner and the status edge.
##
## The fill comes from AegisTheme.set_button_variant(), because a StyleBox is the
## only thing a Button will paint for its own states and several smoke tests read
## it. What a StyleBox cannot express is the cut, so that is what this subclass
## draws: one diagonal hairline across the trailing corner, the same angle and
## the same 8 px as the plate behind it. Keeping it a Button means focus,
## keyboard activation and the existing `pressed` wiring keep working.
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
## The trailing corner, in layout units. 0 = a square button.
@export var cut: float = 8.0:
	set(value):
		cut = value
		queue_redraw()
@export var cut_bottom_left: float = 0.0:
	set(value):
		cut_bottom_left = value
		queue_redraw()


func _ready() -> void:
	resized.connect(queue_redraw)
	if show_brackets:
		queue_redraw()


func _draw() -> void:
	if edge_active:
		draw_rect(Rect2(0.0, 0.0, edge_width, size.y), edge_color, true)
	if cut > 0.0 or cut_bottom_left > 0.0:
		AegisBezel.draw_cut_marks(
			self,
			Rect2(Vector2.ZERO, size),
			Vector4(0.0, cut, 0.0, cut_bottom_left),
			Color(bracket_color, 0.75 if not edge_active else 0.95)
		)
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
