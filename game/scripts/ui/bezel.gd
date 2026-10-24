class_name AegisBezel
extends RefCounted

## The AEGIS plate shape.
##
## Every card in this product is a piece of machined plate, not a rounded box:
## one angle, 45 degrees, and the corner a plate cuts is the corner that carries
## its direction. A rounded rectangle is what every app on the phone already
## looks like, so nothing in this UI has one.
##
## A shape is four cut lengths -- top-left, top-right, bottom-right, bottom-left
## -- in layout units, and the same four numbers are what `tools/` author on the
## web side. Two drawing modes exist because the two kinds of surface carry
## their fill differently:
##
##   * `draw_plate()` paints the fill *and* the hairline. Used where the card
##     owns its own surface (menu cards, overlays), so the cut is real: the
##     pixels outside the polygon are simply not painted.
##   * `draw_cut_marks()` paints only the diagonal hairline. Used where a
##     StyleBox still owns the fill (the HUD chips, whose translucent fill is
##     asserted by a smoke test), so the corner reads as cut without the fill
##     being moved out from under the stylebox.

## Cut lengths, in layout units. Small enough to read at a 56 px HUD chip, large
## enough to read as a chamfer rather than a nick.
const CUT_XS := 5.0
const CUT_SM := 8.0
const CUT := 12.0
const CUT_LG := 22.0
const CUT_XL := 32.0


## The eight points of a cut rectangle, clockwise from the top-left edge.
## A zero cut leaves the two points on that corner at the corner itself, so a
## plate can cut one corner and stay square everywhere else.
static func points(rect: Rect2, cuts: Vector4) -> PackedVector2Array:
	var x0 := rect.position.x
	var y0 := rect.position.y
	var x1 := rect.end.x
	var y1 := rect.end.y
	var tl := maxf(cuts.x, 0.0)
	var tr := maxf(cuts.y, 0.0)
	var br := maxf(cuts.z, 0.0)
	var bl := maxf(cuts.w, 0.0)
	var limit := minf(rect.size.x, rect.size.y) * 0.5
	tl = minf(tl, limit)
	tr = minf(tr, limit)
	br = minf(br, limit)
	bl = minf(bl, limit)
	return PackedVector2Array(
		[
			Vector2(x0 + tl, y0),
			Vector2(x1 - tr, y0),
			Vector2(x1, y0 + tr),
			Vector2(x1, y1 - br),
			Vector2(x1 - br, y1),
			Vector2(x0 + bl, y1),
			Vector2(x0, y1 - bl),
			Vector2(x0, y0 + tl),
		]
	)


## Fills the plate and draws its hairline. `edge` is the machined edge; pass a
## second colour for the cut that points, if the card should point.
static func draw_plate(
	item: CanvasItem, rect: Rect2, cuts: Vector4, fill: Color, edge: Color, edge_width: float = 1.0
) -> void:
	if rect.size.x <= 0.0 or rect.size.y <= 0.0:
		return
	var shape := points(rect, cuts)
	if fill.a > 0.0:
		item.draw_colored_polygon(shape, fill)
	if edge.a > 0.0:
		# Inset by half a pixel so the hairline sits inside the plate rather than
		# straddling its edge, which is what makes it look drawn by hand.
		var half := edge_width * 0.5
		var outline := PackedVector2Array()
		for point in shape:
			var centre := rect.get_center()
			outline.append(point + (centre - point).normalized() * half)
		outline.append(outline[0])
		item.draw_polyline(outline, edge, edge_width, true)


## Draws one diagonal hairline across each cut corner, 1 px wide, inset so it
## reads as an edge and not as a border.
static func draw_cut_marks(item: CanvasItem, rect: Rect2, cuts: Vector4, color: Color) -> void:
	var shape := points(rect, cuts)
	if cuts.x > 0.0:
		item.draw_line(shape[7], shape[0], color, 1.0, true)
	if cuts.y > 0.0:
		item.draw_line(shape[1], shape[2], color, 1.0, true)
	if cuts.z > 0.0:
		item.draw_line(shape[3], shape[4], color, 1.0, true)
	if cuts.w > 0.0:
		item.draw_line(shape[5], shape[6], color, 1.0, true)
