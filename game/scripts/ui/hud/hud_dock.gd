## The two docks that frame a run: a status strip along the top edge and an
## action rail in the bottom corner.
##
## Before this, every HUD element floated on its own: a vitals card here, a wave
## card under it, a sound and a pause plate in the middle of the top edge, and
## then a cluster of six action tiles loose in the bottom right. Nothing said
## which of them belonged together, or where the player's eye should return, so
## the screen read as widgets sprinkled over a game.
##
## A dock is the answer every shooter uses and none of them explain: group the
## readouts on one edge, the verbs on the other, and give both a frame. The frame
## is drawn behind the live widgets -- it is a plate, not a container -- so the
## cards keep their own sizes, keep responding to the HUD editor's offsets, and
## the dock simply follows them (the union of their rects, plus padding).
##
## Touch-safety: this only draws. It adds no Control to the hit-test path, so a
## tap in the world is still a tap in the world.
class_name HudDock
extends RefCounted

const CUT := 14.0


## Frame the top strip around whatever status widgets are visible.
static func top(hud, controls: Array) -> void:
	var rects: Array[Rect2] = []
	for control in controls:
		if is_instance_valid(control) and control is Control and control.visible:
			var rect: Rect2 = control.get_global_rect()
			if rect.size.x > 1.0 and rect.size.y > 1.0:
				rects.append(rect)
	if rects.is_empty():
		return
	var pad_x: float = hud._to_layout(10.0)
	var pad_y: float = hud._to_layout(6.0)
	var union := rects[0]
	for rect in rects:
		union = union.merge(rect)
	union = union.grow_individual(pad_x, pad_y, pad_x + hud._safe_left, pad_y)
	# The strip runs to the trailing edge of the screen: a dock that stops in
	# mid-air is a card, and this is not a card.
	union.size.x = maxf(union.size.x, hud.size.x - union.position.x)
	_plate(hud, union, true)


## Frame the action rail around the touch verbs.
static func bottom(hud, controls: Array) -> void:
	var rects: Array[Rect2] = []
	for control in controls:
		if is_instance_valid(control) and control is Control and control.visible:
			var rect: Rect2 = control.get_global_rect()
			if rect.size.x > 1.0 and rect.size.y > 1.0:
				rects.append(rect)
	if rects.is_empty():
		return
	var pad: float = hud._to_layout(8.0)
	var union := rects[0]
	for rect in rects:
		union = union.merge(rect)
	union = union.grow_individual(pad, pad, pad + hud._safe_right, pad + hud._safe_bottom)
	union.size.y = minf(union.size.y, hud.size.y * 0.62)
	union.position.y = maxf(union.position.y, hud.size.y - union.size.y - hud._safe_bottom)
	_plate(hud, union, false)


## One machined plate: a filled body with the outer corners cut, a hairline all
## the way round, and a short lit edge on the side the dock faces.
static func _plate(hud, rect: Rect2, facing_down: bool) -> void:
	var cut: float = hud._to_layout(CUT)
	var body := PackedVector2Array()
	if facing_down:
		# Top edge is cut at both ends; the bottom edge is the open one.
		body = PackedVector2Array(
			[
				Vector2(rect.position.x + cut, rect.position.y),
				Vector2(rect.end.x - cut, rect.position.y),
				Vector2(rect.end.x, rect.position.y + cut),
				Vector2(rect.end.x, rect.end.y),
				Vector2(rect.position.x, rect.end.y),
				Vector2(rect.position.x, rect.position.y + cut),
			]
		)
	else:
		# Bottom rail: cut the outer bottom corners, flush to the top.
		body = PackedVector2Array(
			[
				Vector2(rect.position.x, rect.position.y),
				Vector2(rect.end.x, rect.position.y),
				Vector2(rect.end.x, rect.end.y - cut),
				Vector2(rect.end.x - cut, rect.end.y),
				Vector2(rect.position.x + cut, rect.end.y),
				Vector2(rect.position.x, rect.end.y - cut),
			]
		)

	var fill := Color(AegisTokens.VOID, 0.34)
	var hair := Color(AegisTokens.LINE, 0.9)
	hud.draw_colored_polygon(body, fill)

	var outline := body.duplicate()
	outline.append(body[0])
	hud.draw_polyline(outline, hair, maxf(hud._to_layout(1.0), 1.0), true)

	# The lit edge: a two-pixel accent along the dock's inner edge, fading out
	# toward the screen. It is what makes the plate read as a rail the widgets
	# sit on rather than as a rectangle drawn behind them.
	var accent := Color(AegisTokens.LINE_HI, 0.85)
	var thickness: float = maxf(hud._to_layout(2.0), 1.0)
	if facing_down:
		var y: float = rect.end.y - thickness
		hud.draw_rect(Rect2(rect.position.x + cut, y, rect.size.x - cut * 2.0, thickness), accent)
	else:
		hud.draw_rect(
			Rect2(rect.position.x + cut, rect.position.y, rect.size.x - cut * 2.0, thickness),
			accent
		)

	# Corner ticks: four short marks at the cut corners, the same vocabulary the
	# machined touch tiles use, so the dock belongs to the same machined set.
	var tick: float = hud._to_layout(7.0)
	var tick_color := Color(AegisTokens.LINE_HI, 0.7)
	if facing_down:
		hud.draw_line(
			Vector2(rect.position.x + cut, rect.position.y),
			Vector2(rect.position.x + cut + tick, rect.position.y),
			tick_color,
			thickness
		)
		hud.draw_line(
			Vector2(rect.end.x - cut - tick, rect.position.y),
			Vector2(rect.end.x - cut, rect.position.y),
			tick_color,
			thickness
		)
	else:
		hud.draw_line(
			Vector2(rect.position.x + cut, rect.end.y),
			Vector2(rect.position.x + cut + tick, rect.end.y),
			tick_color,
			thickness
		)
		hud.draw_line(
			Vector2(rect.end.x - cut - tick, rect.end.y),
			Vector2(rect.end.x - cut, rect.end.y),
			tick_color,
			thickness
		)
