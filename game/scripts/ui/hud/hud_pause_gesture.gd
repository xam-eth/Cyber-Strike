## Optional portrait bottom-sheet gesture. A swipe beginning at the drag grip
## resumes the run; taps elsewhere continue to reach the regular menu buttons.
## This runs in the HUD's _input because gameplay nodes stop processing when
## SceneTree is paused and touch events never reach their _unhandled_input.
class_name HudPauseGesture
extends RefCounted


static func layout(hud) -> void:
	if not is_instance_valid(hud._pause_swipe_handle):
		return
	hud._pause_swipe_handle.visible = hud._portrait and hud._narrow
	hud._pause_swipe_handle.custom_minimum_size = Vector2(hud._to_layout(48.0), hud._to_layout(4.0))


static func handle(hud, event: InputEvent) -> bool:
	if (
		not hud.get_tree().paused
		or not hud._portrait
		or not hud._narrow
		or not hud._pause_panel.visible
	):
		hud._pause_swipe_id = -1
		return false
	if event is InputEventScreenTouch:
		if (
			event.pressed
			and hud._pause_swipe_handle.get_global_rect().grow(hud._to_layout(32.0)).has_point(
				event.position
			)
		):
			hud._pause_swipe_id = event.index
			hud._pause_swipe_origin = event.position
			hud.get_viewport().set_input_as_handled()
			return true
		if event.index == hud._pause_swipe_id and not event.pressed:
			hud._pause_swipe_id = -1
			hud.get_viewport().set_input_as_handled()
			return true
	if event is InputEventScreenDrag and event.index == hud._pause_swipe_id:
		if event.position.y - hud._pause_swipe_origin.y >= hud._to_layout(80.0):
			hud._pause_swipe_id = -1
			hud._on_pause_pressed()
		hud.get_viewport().set_input_as_handled()
		return true
	return false
