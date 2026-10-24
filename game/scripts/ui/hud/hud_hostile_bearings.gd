class_name HudHostileBearings
extends RefCounted

## Compact directional cues only while Defense is active. The marker belongs
## to a live WaveDirector enemy, not the Explore training dummy. Nothing is
## drawn in the line of sight when that enemy is already in the playable area.
## This geometry deliberately reserves the upper objective and lower thumb
## cluster in both phone orientations; unlike a full radar it needs no text.


static func collect(
	camera: Camera3D,
	enemies: Array[Node3D],
	viewport_size: Vector2,
	portrait: bool,
	unit: float = 1.0
) -> Array[Dictionary]:
	var bearings: Array[Dictionary] = []
	if not is_instance_valid(camera) or viewport_size.x < 1.0 or viewport_size.y < 1.0:
		return bearings
	var safe_area := _safe_aperture(viewport_size, portrait, unit)
	if safe_area.size.x < 2.0 or safe_area.size.y < 2.0:
		return bearings
	var forward := -camera.global_basis.z
	var right := camera.global_basis.x
	forward.y = 0.0
	right.y = 0.0
	forward = forward.normalized()
	right = right.normalized()
	for enemy in enemies:
		if not is_instance_valid(enemy) or not enemy.is_inside_tree():
			continue
		if enemy.has_method("is_defeated") and bool(enemy.call("is_defeated")):
			continue
		var target := enemy.global_position + Vector3.UP
		var screen := camera.unproject_position(target)
		var behind := camera.is_position_behind(target)
		if not behind and safe_area.grow(-15.0 * unit).has_point(screen):
			continue
		var to_enemy := enemy.global_position - camera.global_position
		to_enemy.y = 0.0
		var horizontal := Vector2(to_enemy.dot(right), -to_enemy.dot(forward))
		var direction := _projected_direction(screen, safe_area, horizontal, behind)
		if direction.length_squared() < 0.0001:
			continue
		var half := safe_area.size * 0.5
		var extent := minf(
			half.x / maxf(absf(direction.x), 0.001), half.y / maxf(absf(direction.y), 0.001)
		)
		var marker: Dictionary = {
			"position": safe_area.get_center() + direction * extent,
			"direction": direction,
			"near": to_enemy.length() < 9.0,
		}
		bearings.append(marker)
	return bearings


static func _projected_direction(
	screen: Vector2, safe_area: Rect2, horizontal: Vector2, behind_camera: bool
) -> Vector2:
	# A Runner beside the player's feet can be *in front of the camera* but
	# project below the phone's thumb cluster. World-facing forward used to put
	# its arrow at the TOP of the screen, exactly opposite the visible threat.
	# Use the actual screen position when it is in the front hemisphere; only
	# an enemy behind the lens needs a world-space fallback.
	var projected := screen - safe_area.get_center()
	if not behind_camera and projected.length_squared() > 0.0001:
		return projected.normalized()
	return horizontal.normalized() if horizontal.length_squared() > 0.0001 else Vector2.ZERO


static func draw_marker(host: CanvasItem, bearing: Dictionary, unit: float) -> void:
	var position: Vector2 = bearing["position"]
	var direction: Vector2 = bearing["direction"]
	var near: bool = bearing["near"]
	var color := Color(AegisTokens.DANGER, 0.9 if near else 0.7)
	var radius := 13.0 * unit
	var wing := direction.orthogonal() * (5.0 * unit)
	var point := position + direction * (10.0 * unit)
	var base := position - direction * (5.0 * unit)
	host.draw_arc(position, radius, 0.0, TAU, 24, Color(color, 0.42), maxf(unit, 1.0))
	host.draw_colored_polygon(PackedVector2Array([point, base + wing, base - wing]), color)
	if near:
		host.draw_arc(position, radius + 3.0 * unit, 0.0, TAU, 24, Color(color, 0.36), unit)


static func _safe_aperture(viewport_size: Vector2, portrait: bool, unit: float) -> Rect2:
	var top := (
		maxf(224.0 * unit, viewport_size.y * 0.265)
		if portrait
		else maxf(150.0 * unit, viewport_size.y * 0.45)
	)
	var bottom := (
		minf(viewport_size.y - 314.0 * unit, viewport_size.y * 0.62)
		if portrait
		else minf(viewport_size.y - 92.0 * unit, viewport_size.y * 0.72)
	)
	var left := 40.0 * unit if portrait else viewport_size.x * 0.34
	var right := viewport_size.x - 40.0 * unit if portrait else viewport_size.x * 0.70
	return Rect2(Vector2(left, top), Vector2(maxf(right - left, 0.0), maxf(bottom - top, 0.0)))
