## PanelContainer with the AEGIS cut-plate signature.
##
## A rounded box is what every app on a phone looks like, so a card here is a
## machined plate instead: 45 degree corners, one hairline along every cut, and
## an optional 2 px status edge. Two modes, because a card carries its fill in
## one of two ways:
##
##   * `bezel = true` -- the card owns its surface. The StyleBox is reduced to
##     content margins and `_draw` paints the cut plate, so the corners are
##     genuinely absent and whatever is behind the card shows through them.
##     This is the mode for menu cards, the armory sheet and the overlays.
##   * `bezel = false` -- a StyleBox still owns the fill (the HUD chips, whose
##     translucent fill a smoke test reads from the stylebox), so the card stays
##     square and gets a diagonal cut mark on the corners it names instead.
class_name AegisPanel
extends PanelContainer

## Modal panels (results) must accept clicks; every other card lets touches fall
## through to the world so the play area is not blocked by the HUD.
@export var interactive: bool = false
## Off by default: the corner bracket was the old signature and the cut plate
## replaced it. Kept as a property because a caller may still ask for the L.
@export var show_brackets: bool = false:
	set(value):
		show_brackets = value
		queue_redraw()
@export var bracket_color: Color = AegisTokens.LINE_HI:
	set(value):
		bracket_color = value
		queue_redraw()
## Where the plate is cut, in layout units. Positive cut = that corner is
## removed. `bezel` decides whether the cut is real or only marked.
@export var cut_top_left: float = 0.0:
	set(value):
		cut_top_left = value
		queue_redraw()
## Every card points, unless it says otherwise: one machined corner on the
## trailing edge is what a plate cut by a single pass looks like.
@export var cut_top_right: float = 8.0:
	set(value):
		cut_top_right = value
		queue_redraw()
@export var cut_bottom_right: float = 0.0:
	set(value):
		cut_bottom_right = value
		queue_redraw()
@export var cut_bottom_left: float = 0.0:
	set(value):
		cut_bottom_left = value
		queue_redraw()
## True = this card paints its own cut plate (see the class comment).
@export var bezel: bool = false:
	set(value):
		bezel = value
		if is_inside_tree():
			apply_surface()
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
@export var accent_width: float = 3.0:
	set(value):
		accent_width = value
		queue_redraw()
## Paints a subtle instrument header wash and optical chamfer wedges on
## non-bezel HUD cards while leaving the StyleBoxFlat opacity intact.
@export var tactical_header: bool = false:
	set(value):
		tactical_header = value
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
	# A bezel card draws its own fill, so the stylebox keeps only the inset that
	# positions the content inside the cut plate.
	var fill := Color(AegisTokens.PANEL, 0.0 if bezel else surface_alpha)
	add_theme_stylebox_override(
		"panel",
		AegisTheme.panel_style(
			fill,
			Color(AegisTokens.LINE, 0.0 if bezel else 0.95),
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


## The four cuts as one value, which is what `AegisBezel` takes.
func cuts() -> Vector4:
	return Vector4(cut_top_left, cut_top_right, cut_bottom_right, cut_bottom_left)


func _draw() -> void:
	if bezel:
		AegisBezel.draw_plate(
			self,
			Rect2(Vector2.ZERO, size),
			cuts(),
			Color(AegisTokens.PANEL, surface_alpha),
			Color(AegisTokens.LINE, 0.95)
		)
		_draw_accent()
		return
	var inset := bracket_inset
	var length := bracket_length
	var width := bracket_width
	var right := size.x - inset
	var bottom := size.y - inset
	if tactical_header and size.x > 8.0 and size.y > 12.0:
		var tint: Color = accent_color if accent_side != "none" else AegisTokens.INFO
		var band_h := minf(18.0, size.y * 0.42)
		draw_rect(Rect2(1.0, 1.0, size.x - 2.0, band_h), Color(tint, 0.10), true)
		draw_line(
			Vector2(maxf(cut_top_left, 1.0), 1.0),
			Vector2(size.x - maxf(cut_top_right, 1.0), 1.0),
			Color(AegisTokens.LINE_HI, 0.65),
			1.0
		)
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
	_draw_optical_chamfers()
	_draw_accent()


func _draw_optical_chamfers() -> void:
	var c := cuts()
	var edge_col: Color = (
		Color(accent_color, 0.88) if accent_side != "none" else Color(bracket_color, 0.9)
	)
	var mask_col := Color(AegisTokens.VOID, 0.94)
	if c.x > 0.5:
		var tl := minf(c.x, minf(size.x, size.y) * 0.45)
		draw_colored_polygon(
			PackedVector2Array([Vector2.ZERO, Vector2(tl, 0.0), Vector2(0.0, tl)]), mask_col
		)
		draw_line(Vector2(0.0, tl), Vector2(tl, 0.0), edge_col, 1.5, true)
	if c.y > 0.5:
		var tr := minf(c.y, minf(size.x, size.y) * 0.45)
		draw_colored_polygon(
			PackedVector2Array(
				[Vector2(size.x - tr, 0.0), Vector2(size.x, 0.0), Vector2(size.x, tr)]
			),
			mask_col
		)
		draw_line(Vector2(size.x - tr, 0.0), Vector2(size.x, tr), edge_col, 1.5, true)
	if c.z > 0.5:
		var br := minf(c.z, minf(size.x, size.y) * 0.45)
		draw_colored_polygon(
			PackedVector2Array(
				[
					Vector2(size.x, size.y - br),
					Vector2(size.x, size.y),
					Vector2(size.x - br, size.y)
				]
			),
			mask_col
		)
		draw_line(Vector2(size.x, size.y - br), Vector2(size.x - br, size.y), edge_col, 1.5, true)
	if c.w > 0.5:
		var bl := minf(c.w, minf(size.x, size.y) * 0.45)
		draw_colored_polygon(
			PackedVector2Array(
				[Vector2(0.0, size.y - bl), Vector2(bl, size.y), Vector2(0.0, size.y)]
			),
			mask_col
		)
		draw_line(Vector2(bl, size.y), Vector2(0.0, size.y - bl), edge_col, 1.5, true)


## The status edge: the lit spine that carries health, readiness or selection.
func _draw_accent() -> void:
	if accent_side == "left":
		var y0 := cut_top_left
		var h := maxf(size.y - cut_top_left - cut_bottom_left, 0.0)
		draw_rect(Rect2(0.0, y0, accent_width * 2.8, h), Color(accent_color, 0.16), true)
		draw_rect(Rect2(0.0, y0, accent_width, h), accent_color, true)
	elif accent_side == "top":
		var x0 := cut_top_left
		var w := maxf(size.x - cut_top_left - cut_top_right, 0.0)
		draw_rect(Rect2(x0, 0.0, w, accent_width * 2.6), Color(accent_color, 0.16), true)
		draw_rect(Rect2(x0, 0.0, w, accent_width), accent_color, true)
