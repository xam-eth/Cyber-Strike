## PanelContainer with the AEGIS corner-bracket signature.
##
## Square panels everywhere would read as generic engine UI; a 10 px bracket at
## the four corners plus an optional 2 px status edge is what makes a card look
## like an instrument cluster instead of a web dialog. The panel background is
## still a StyleBoxFlat so it keeps the spec's 92 % translucency and 2 px radius.
class_name AegisPanel
extends PanelContainer

## Modal panels (results) must accept clicks; every other card lets touches fall
## through to the world so the play area is not blocked by the HUD.
@export var interactive: bool = false
@export var show_brackets: bool = true:
	set(value):
		show_brackets = value
		queue_redraw()
@export var bracket_color: Color = AegisTokens.LINE_HI:
	set(value):
		bracket_color = value
		queue_redraw()
@export var bracket_length: float = AegisTokens.BRACKET_LENGTH:
	set(value):
		bracket_length = value
		queue_redraw()
@export var bracket_inset: float = AegisTokens.BRACKET_INSET:
	set(value):
		bracket_inset = value
		queue_redraw()
@export var bracket_width: float = AegisTokens.BRACKET_WIDTH
## "none", "left" or "top". The status edge carries health / ready state.
@export_enum("none", "left", "top") var accent_side: String = "none":
	set(value):
		accent_side = value
		queue_redraw()
@export var accent_color: Color = AegisTokens.ACCENT:
	set(value):
		accent_color = value
		queue_redraw()
@export var accent_width: float = AegisTokens.ACCENT_EDGE:
	set(value):
		accent_width = value
		queue_redraw()

## 0.0 keeps whatever the caller set; anything else is drawn behind the content.
@export_range(0.0, 1.0, 0.01) var surface_alpha: float = AegisTokens.PANEL_ALPHA_SOFT
## Inset from the card's edge to its content, in canvas units. A 360 px phone
## cannot pay 24 px of width for two padded cards, so a stage that measures its
## own budget calls `set_surface_pad()` instead of accepting the default.
@export var surface_pad: float = 12.0


## Rebuilds the card's surface at a different inset. Called from a layout pass,
## which runs after `_ready()`, so it also re-checks the override.
func set_surface_pad(value: float) -> void:
	surface_pad = value
	apply_surface()


func apply_surface() -> void:
	if surface_alpha <= 0.0:
		return
	add_theme_stylebox_override(
		"panel",
		AegisTheme.panel_style(
			Color(AegisTokens.PANEL, surface_alpha),
			Color(AegisTokens.LINE, 0.95),
			1,
			AegisTokens.RADIUS,
			surface_pad
		)
	)


func _ready() -> void:
	resized.connect(queue_redraw)
	# Every menu card was a bare PanelContainer with no "panel" stylebox: Godot's
	# default draws almost nothing, so HERO's information card, the dashboard
	# blocks and the theatre cards were text floating over a 3D scene. The HUD
	# builds its own styles and sets an override before or after this runs, so an
	# existing override always wins.
	if not has_theme_stylebox_override("panel"):
		apply_surface()
	if not interactive:
		mouse_filter = Control.MOUSE_FILTER_IGNORE


func _draw() -> void:
	var inset := bracket_inset
	var length := bracket_length
	var width := bracket_width
	var right := size.x - inset
	var bottom := size.y - inset
	if show_brackets:
		# Top-left
		draw_line(Vector2(inset, inset), Vector2(inset + length, inset), bracket_color, width)
		draw_line(Vector2(inset, inset), Vector2(inset, inset + length), bracket_color, width)
		# Top-right
		draw_line(Vector2(right - length, inset), Vector2(right, inset), bracket_color, width)
		draw_line(Vector2(right, inset), Vector2(right, inset + length), bracket_color, width)
		# Bottom-left
		draw_line(Vector2(inset, bottom), Vector2(inset + length, bottom), bracket_color, width)
		draw_line(Vector2(inset, bottom - length), Vector2(inset, bottom), bracket_color, width)
		# Bottom-right
		draw_line(Vector2(right - length, bottom), Vector2(right, bottom), bracket_color, width)
		draw_line(Vector2(right, bottom - length), Vector2(right, bottom), bracket_color, width)
	if accent_side == "left":
		draw_rect(Rect2(0.0, 0.0, accent_width, size.y), accent_color, true)
	elif accent_side == "top":
		draw_rect(Rect2(0.0, 0.0, size.x, accent_width), accent_color, true)
