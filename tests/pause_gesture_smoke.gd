extends SceneTree

var _failures: int = 0


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	AegisPreferences.write(AegisPreferences.defaults())
	var canvas := Control.new()
	canvas.size = Vector2(390, 844)
	root.add_child(canvas)
	var hud := TouchControls.new()
	canvas.add_child(hud)
	await process_frame
	hud.set_touch_mode(true)
	hud.apply_layout_for_size(Vector2(390, 844), 1.0)
	paused = true
	hud.set_paused(true)
	hud.pause_requested.connect(
		func():
			paused = false
			hud.set_paused(false)
	)
	await process_frame
	var grip := hud.get("_pause_swipe_handle") as Control
	_expect(
		grip.visible and grip.get_global_rect().size.x >= 44.0,
		"portrait sheet has a visible 48px drag handle"
	)
	var start := grip.get_global_rect().get_center()
	var touch := InputEventScreenTouch.new()
	touch.index = 7
	touch.position = start
	touch.pressed = true
	hud._input(touch)
	var drag := InputEventScreenDrag.new()
	drag.index = 7
	drag.position = start + Vector2(0, 90)
	drag.relative = Vector2(0, 90)
	hud._input(drag)
	_expect(
		not paused and not hud.get("_pause_panel").visible,
		"swiping the sheet handle down resumes the run"
	)

	paused = true
	hud.set_paused(true)
	var elsewhere := InputEventScreenTouch.new()
	elsewhere.index = 8
	elsewhere.position = start + Vector2(0, 130)
	elsewhere.pressed = true
	hud._input(elsewhere)
	var outside_drag := InputEventScreenDrag.new()
	outside_drag.index = 8
	outside_drag.position = elsewhere.position + Vector2(0, 110)
	outside_drag.relative = Vector2(0, 110)
	hud._input(outside_drag)
	_expect(paused, "swipes starting outside the grip cannot accidentally resume")
	paused = false
	hud.set_paused(false)
	canvas.queue_free()
	await process_frame
	AegisPreferences.write(AegisPreferences.defaults())
	if _failures > 0:
		printerr("Pause gesture smoke: %d failure(s)" % _failures)
		quit(1)
	else:
		print("Pause gesture smoke: PASS")
		quit(0)


func _expect(condition: bool, label: String) -> void:
	if condition:
		print("  PASS: ", label)
	else:
		printerr("  FAIL: ", label)
		_failures += 1
