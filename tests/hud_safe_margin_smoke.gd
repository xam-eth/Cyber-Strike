extends SceneTree

## Guards the *edge* geometry of the touch HUD: how far every thumb control
## stays from the glass, and whether any two of them overlap.
##
## `playability_hud_smoke.gd` asserts that the buttons are big enough and that
## they keep their relative order. It never measured the distance to the
## display edge, so a cluster docked 8 px from the bottom-right corner passed
## every check while sitting inside the Android gesture-navigation strip (the
## swipe zone that swallows the touch before the game ever sees it).
##
## This test measures exactly that, on the four viewports the project ships
## for. Every number is a real `Control.get_global_rect()` scaled to physical
## pixels, never a design constant:
##
##   * each bottom-docked control clears the bottom edge by the gesture
##     reserve (AegisTokens.SAFE_BOTTOM_PX) plus its authored margin,
##   * each one clears the side edge it is docked to,
##   * the joystick pocket is fully on screen,
##   * no two interactive controls overlap,
##   * nothing is pushed off screen by the reserve.
##
## The resolved reserve is printed per viewport so a device that reports a
## larger safe area can be seen in the log instead of being silently ignored.

const MainScene = preload("res://scenes/main.tscn")

## viewports the HUD ships for: portrait, short portrait, landscape, short
## landscape. The stretch is what the engine's `canvas_items` + `expand`
## project setting produces for a 1280x720 logical canvas.
const VIEWPORTS: Array[Vector2] = [
	Vector2(390.0, 844.0),
	Vector2(375.0, 667.0),
	Vector2(844.0, 390.0),
	Vector2(667.0, 375.0),
]
const CANVAS := Vector2(1280.0, 720.0)
## A thumb control may never be closer than this to the bottom glass.
const MIN_BOTTOM_CLEARANCE: float = AegisTokens.SAFE_BOTTOM_PX - 2.0
## ...nor to the side it is docked to.
const MIN_SIDE_CLEARANCE: float = AegisTokens.SAFE_SIDE_PX - 2.0

var _failures: Array[String] = []


func _initialize() -> void:
	call_deferred("_run_smoke_test")


func _run_smoke_test() -> void:
	AegisPreferences.write(AegisPreferences.defaults())
	var main_scene := MainScene.instantiate()
	main_scene.set("start_wave_session_on_ready", false)
	main_scene.get_node("ProgressionService").set("profile_path", "")
	root.add_child(main_scene)
	await process_frame

	var controls: Control = main_scene.get_node("HUD/TouchControls")
	# A headless display server never reports a touchscreen; opt in so the
	# thumb layout (and the gesture reserve it must respect) is the one under
	# test.
	controls.call("set_touch_mode", true)
	await process_frame

	for viewport in VIEWPORTS:
		var stretch: float = minf(viewport.x / CANVAS.x, viewport.y / CANVAS.y)
		controls.size = Vector2(viewport.x / stretch, viewport.y / stretch)
		controls.call("apply_layout_for_size", viewport, stretch)
		await process_frame
		# The status toast is not pressable, but it must never be painted over
		# a control that is: it is measured while a message is on screen.
		var feedback: Control = controls.get("_feedback_panel")
		feedback.call("show_message", "EMP PULSE \u00b7 NO TARGETS")
		await process_frame
		_check_viewport(controls, viewport, stretch)
		feedback.call("clear_message")

	_finish(main_scene)


func _check_viewport(controls: Control, viewport: Vector2, stretch: float) -> void:
	var label := "%dx%d" % [roundi(viewport.x), roundi(viewport.y)]
	var safe_bottom := float(controls.get("_safe_bottom")) * stretch
	var safe_left := float(controls.get("_safe_left")) * stretch
	var safe_right := float(controls.get("_safe_right")) * stretch
	print(
		(
			"Safe margins %s: reserve bottom=%.0f left=%.0f right=%.0f (physical px)"
			% [label, safe_bottom, safe_left, safe_right]
		)
	)
	_expect(
		safe_bottom >= AegisTokens.SAFE_BOTTOM_PX - 0.5,
		"%s reserves the gesture strip (%.0f px)" % [label, safe_bottom],
	)

	var named := _interactive_rects(controls, stretch)
	for entry in named:
		var name: String = entry[0]
		var rect: Rect2 = entry[1]
		var detail := "%s %s rect=%s" % [label, name, _rect_text(rect)]
		_expect(
			(
				rect.position.x >= -1.0
				and rect.position.y >= -1.0
				and rect.end.x <= viewport.x + 1.0
				and rect.end.y <= viewport.y + 1.0
			),
			"%s keeps %s fully on screen (%s)" % [label, name, detail],
		)
		if name in ["FIRE", "ADS", "EMP", "SWAP"]:
			_expect(
				(viewport.y - rect.end.y) >= MIN_BOTTOM_CLEARANCE,
				(
					"%s keeps %s clear of the bottom edge (%.0f px, %s)"
					% [label, name, viewport.y - rect.end.y, detail]
				),
			)
			_expect(
				(viewport.x - rect.end.x) >= MIN_SIDE_CLEARANCE,
				(
					"%s keeps %s clear of the right edge (%.0f px, %s)"
					% [label, name, viewport.x - rect.end.x, detail]
				),
			)
		if name == "JOY":
			_expect(
				rect.position.x >= 6.0 and (viewport.y - rect.end.y) >= 6.0,
				(
					"%s keeps the joystick pocket off both edges (left %.0f px, bottom %.0f px, %s)"
					% [label, rect.position.x, viewport.y - rect.end.y, detail]
				),
			)

	# The status toast carries no action, so it yields to every thumb target.
	var feedback: Control = controls.get("_feedback_panel") as Control
	if is_instance_valid(feedback) and feedback.visible:
		var toast: Rect2 = Rect2(
			feedback.get_global_rect().position * stretch, feedback.get_global_rect().size * stretch
		)
		for entry in named:
			_expect(
				not toast.intersects(entry[1]),
				(
					"%s keeps the status toast off %s (%s vs %s)"
					% [label, entry[0], _rect_text(toast), _rect_text(entry[1])]
				),
			)

	# Overlap check: two interactive controls may never share a pixel.
	for index_a in range(named.size()):
		for index_b in range(index_a + 1, named.size()):
			var name_a: String = named[index_a][0]
			var name_b: String = named[index_b][0]
			var rect_a: Rect2 = named[index_a][1]
			var rect_b: Rect2 = named[index_b][1]
			_expect(
				not rect_a.intersects(rect_b),
				(
					"%s keeps %s and %s apart (%s vs %s)"
					% [label, name_a, name_b, _rect_text(rect_a), _rect_text(rect_b)]
				),
			)


## Every control a thumb can press, in physical pixels. `JOY` is the drawn
## movement pocket: it is not a Control, so it is measured from the same
## centre and radius the input dispatcher uses.
func _interactive_rects(controls: Control, stretch: float) -> Array:
	var found: Array = []
	var names := ["FIRE", "ADS", "EMP", "SWAP", "PAUSE", "AMMO", "START", "ARMORY"]
	var keys := [
		"_fire_button",
		"_aim_button",
		"_skill_button",
		"_weapon_button",
		"_pause_button",
		"_touch_ammo_chip",
		"_defense_button",
		"_armory_button",
	]
	for index in range(names.size()):
		var control: Control = controls.get(keys[index]) as Control
		if not is_instance_valid(control) or not control.visible:
			continue
		var global: Rect2 = control.get_global_rect()
		(
			found
			. append(
				[
					names[index],
					Rect2(global.position * stretch, global.size * stretch),
				]
			)
		)
	var radius: float = float(controls.get("_joystick_radius")) * stretch
	var center: Vector2 = (controls.get("_joystick_center") as Vector2) * stretch
	found.append(["JOY", Rect2(center - Vector2(radius, radius), Vector2.ONE * radius * 2.0)])
	return found


func _rect_text(rect: Rect2) -> String:
	return (
		"%d,%d %dx%d"
		% [
			roundi(rect.position.x),
			roundi(rect.position.y),
			roundi(rect.size.x),
			roundi(rect.size.y),
		]
	)


func _expect(condition: bool, message: String) -> bool:
	if condition:
		print("  ok: " + message)
	else:
		_failures.append(message)
		push_error("Safe margin smoke test failed: " + message)
	return condition


func _finish(main_scene: Node) -> void:
	main_scene.queue_free()
	await process_frame
	if _failures.is_empty():
		print("HUD safe margin smoke test passed.")
		quit()
	else:
		print("HUD safe margin smoke test failed: %d problem(s)." % _failures.size())
		for failure in _failures:
			print("  - " + failure)
		quit(1)
