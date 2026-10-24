## Front-end menu layout probe.
##
## Screenshots cannot be read in this environment, and a layout that fits one
## screen can pour off the next: the dashboard that measures 56 px buttons at
## 390x844 put DEPLOY at y=444 on a 390 px tall landscape screen, and a card
## list that scrolls nicely in portrait leaves a ~130 px window in landscape.
##
## So this test mounts the real `front_end.tscn` once, inside a SubViewport
## sized 390x844, then *rotates* the same live viewport to 844x390, 360x640 and
## 1280x720 -- the case a browser build cannot produce, because it is fixed at
## one viewport per launch. At each size it walks every visible control and
## asserts three things in *physical* pixels:
##
##   * nothing that is not inside a scroll container is drawn outside the
##     viewport -- the failure that hides a button below the bottom edge;
##   * every button is still at least MIN_TOUCH_PX tall and wide enough to hit;
##   * a card list that reports a scroll range can be scrolled to the end, and
##     scrolling it moves the cards -- a row whose range were zero would strand
##     the last weapon off screen with no way to reach it.
##
## It also prints a rect report in the same format as `?qa_menu=1`, so the
## numbers measured headlessly can be compared with the numbers measured in a
## real browser at the same viewport.
extends SceneTree

const FrontEndScene = preload("res://scenes/ui/front_end.tscn")
## Distinct from the real save so the suite never reads a developer profile.
const PROFILE_PATH := "user://menu_layout_smoke_profile.cfg"

const SIZES := {
	"portrait": Vector2i(390, 844),
	"landscape": Vector2i(844, 390),
	"small portrait": Vector2i(360, 640),
	"desktop": Vector2i(1280, 720),
}
## The four menu screens that carry the layout: the hub and the three
## selection lists. BOOT/LOADING/CINEMATIC/CHAPTER/PRELOAD are single-purpose
## panels with no edge-hugging actions.
const STAGES := [&"DASHBOARD", &"HERO", &"WEAPON", &"WORLD"]
## AegisTokens.MIN_TOUCH_PX, less a pixel of rounding.
const MIN_TOUCH := 55.0

var _failures: Array[String] = []
var _viewport: SubViewport = null
var _front_end: Control = null
var _current_stage := StringName()


func _initialize() -> void:
	call_deferred("_run_smoke_test")


func _run_smoke_test() -> void:
	var first := true
	for size_name in SIZES:
		var size: Vector2i = SIZES[size_name]
		# Only the first size is mounted. Everything after it is a *rotation* of
		# a screen that is already open and laid out, which is the case the
		# browser cannot produce (one viewport per launch) and the one that
		# decides whether `resized` really re-arranges a live stage.
		if first:
			await _mount(size)
			first = false
		else:
			await _rotate(size_name, size)
		for stage_name in STAGES:
			await _probe(stage_name, size_name, Vector2(size))
	_teardown()
	if _failures.is_empty():
		print("Menu layout smoke test passed.")
		quit(0)
		return
	print("Menu layout smoke test FAILED:")
	for failure in _failures:
		print("  fail: " + failure)
	quit(1)


## Puts the front end inside a SubViewport of exactly `size`. `MenuStage` reads
## its physical size from the window and falls back to the viewport when the
## window is not real -- which is the case headless -- so the SubViewport size
## is what every layout decision is made against.
func _mount(size: Vector2i) -> void:
	_teardown()
	_viewport = SubViewport.new()
	_viewport.size = size
	_viewport.disable_3d = true
	_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	_viewport.name = "LayoutProbe"
	root.add_child(_viewport)
	_front_end = FrontEndScene.instantiate()
	_front_end.set_anchors_preset(Control.PRESET_FULL_RECT)
	_front_end.get_node("ProgressionService").set("profile_path", PROFILE_PATH)
	_viewport.add_child(_front_end)
	await process_frame
	await process_frame


## Resizes the live SubViewport, which is what a device rotation does: the
## front end is anchored full-rect inside it, so every stage gets `resized` and
## has to re-arrange itself in place. Nothing is freed or rebuilt in between.
func _rotate(size_name: String, size: Vector2i) -> void:
	_viewport.size = size
	await process_frame
	await process_frame
	var live := Vector2(_viewport.size)
	_expect(
		live == Vector2(size),
		"rotated the live viewport to %s (%dx%d)" % [size_name, size.x, size.y]
	)


func _teardown() -> void:
	if is_instance_valid(_front_end):
		_front_end.free()
		_front_end = null
	if is_instance_valid(_viewport):
		_viewport.free()
		_viewport = null


func _probe(stage_name: StringName, size_name: String, physical: Vector2) -> void:
	_current_stage = stage_name
	_front_end.call("go_to", stage_name, {})
	await process_frame
	await process_frame
	var stage: Control = _front_end.get_node_or_null("StageHost/" + str(stage_name)) as Control
	if not _expect(is_instance_valid(stage), "%s %s: stage is mounted" % [stage_name, size_name]):
		return
	var stretch: float = UiLayout.compute_stretch(stage, physical)
	var viewport := Rect2(Vector2.ZERO, physical)
	var lines := PackedStringArray()
	lines.append("STAGE=%s %s" % [stage_name, size_name])
	lines.append(
		(
			"CANVAS=%dx%d PHYSICAL=%dx%d STRETCH=%.3f"
			% [
				roundi(stage.size.x),
				roundi(stage.size.y),
				roundi(physical.x),
				roundi(physical.y),
				stretch
			]
		)
	)
	for child in stage.find_children("*", "Control", true, false):
		var control := child as Control
		if control == null or not control.is_visible_in_tree():
			continue
		if not (control is Button or control is Label or control is ProgressBar):
			continue
		var name := str(control.name)
		if control is Button and not (control as Button).text.is_empty():
			name = (control as Button).text
		elif control is Label and not (control as Label).text.is_empty():
			name = (control as Label).text.substr(0, mini((control as Label).text.length(), 18))
		var global := control.get_global_rect()
		var rect := Rect2(global.position * stretch, global.size * stretch)
		lines.append(
			(
				"%s=%.0f,%.0f,%.0fx%.0f"
				% [name, rect.position.x, rect.position.y, rect.size.x, rect.size.y]
			)
		)
		_check(control, rect, viewport, "%s %s" % [stage_name, size_name])
	print("Menu layout: " + " | ".join(lines))
	await _check_row_scroll(stage, "%s %s" % [stage_name, size_name])
	await _check_thumb_drag(stage, "%s %s" % [stage_name, size_name])


## The two rules. A control inside a ScrollContainer is allowed to sit outside
## the viewport: that is what scrolling is for, and clipping it is the
## container's job. Everything else has to be on screen to be usable.
func _check(control: Control, rect: Rect2, viewport: Rect2, where: String) -> void:
	var name := str(control.name)
	if control is Button and not (control as Button).text.is_empty():
		name = (control as Button).text
	if _inside_scroll_container(control):
		return
	if (
		rect.position.x < -1.0
		or rect.position.y < -1.0
		or rect.end.x > viewport.size.x + 1.0
		or rect.end.y > viewport.size.y + 1.0
	):
		_fail(
			(
				"%s: %s is outside the viewport (%.0f,%.0f %.0fx%.0f in %.0fx%.0f)"
				% [
					where,
					name,
					rect.position.x,
					rect.position.y,
					rect.size.x,
					rect.size.y,
					viewport.size.x,
					viewport.size.y
				]
			)
		)
	if control is Button and not (control as Button).text.is_empty():
		if rect.size.y + 0.5 < MIN_TOUCH:
			_fail(
				(
					"%s: %s is only %.0f px tall, under the %.0f px touch floor"
					% [where, name, rect.size.y, MIN_TOUCH]
				)
			)
		if rect.size.x + 0.5 < MIN_TOUCH:
			_fail.call(
				(
					"%s: %s is only %.0f px wide, under the %.0f px floor"
					% [where, name, rect.size.x, MIN_TOUCH]
				)
			)


## A list that claims to scroll has to have somewhere to scroll to, and moving
## it has to move the cards. The landscape row is the interesting case: three
## 340 px cards in a 470 px window, where a scroll range of zero would strand
## the last weapon off screen with no way to reach it.
func _check_row_scroll(stage: Control, where: String) -> void:
	var sideways := is_landscape(stage)
	for child in stage.find_children("*", "ScrollContainer", true, false):
		var scroll := child as ScrollContainer
		if scroll == null or not scroll.is_visible_in_tree():
			continue
		var bar: ScrollBar = scroll.get_h_scroll_bar() if sideways else scroll.get_v_scroll_bar()
		if not bar.visible or bar.max_value <= 0.0:
			continue
		var card: Control = _first_card(scroll)
		var maximum := float(bar.max_value)
		var before := 0.0
		# Portrait scrolls the list down, landscape scrolls it sideways, so the
		# coordinate that has to move is the axis the scroll runs on.
		var point_before := card.get_global_rect().position if card != null else Vector2.ZERO
		if sideways:
			scroll.scroll_horizontal = int(maximum)
		else:
			scroll.scroll_vertical = int(maximum)
		await process_frame
		await process_frame
		var after := float(scroll.scroll_horizontal if sideways else scroll.scroll_vertical)
		var point_after := card.get_global_rect().position if card != null else Vector2.ZERO
		var axis := "sideways" if sideways else "down"
		_expect(
			after > before, "%s: the card list scrolls %s (0 -> %d)" % [where, axis, int(after)]
		)
		if card != null:
			_expect(
				(
					point_after.x < point_before.x - 1.0
					if sideways
					else point_after.y < point_before.y - 1.0
				),
				(
					"%s: scrolling %s moves the cards (first card %d -> %d)"
					% [
						where,
						axis,
						int(point_before.x if sideways else point_before.y),
						int(point_after.x if sideways else point_after.y)
					]
				)
			)
		# Back to the top before the drag: anything measured after it has to be
		# the drag's doing, not the programmatic scroll's.
		if sideways:
			scroll.scroll_horizontal = 0
		else:
			scroll.scroll_vertical = 0
		await process_frame
		await process_frame


## A thumb drag, now that the menus scroll the card list themselves.
##
## This used to be impossible to test, and the reason matters: `ScrollContainer`
## pans on mouse events and nothing else, so on a phone it only works while
## `emulate_mouse_from_touch` synthesises them -- which this project switches
## off on purpose for the combat HUD. The row therefore could not be dragged at
## all, and no headless test could say so, because a synthetic screen drag moved
## 0 px. `MenuStage._input` now pans the list from the screen events directly,
## which makes the gesture testable here: `push_input` delivers real screen
## events to the stage, and the row has to move -- without the drag also
## selecting the card it started on, which is the other half of the contract.
func _check_thumb_drag(stage: Control, where: String) -> void:
	var sideways := is_landscape(stage)
	for child in stage.find_children("*", "ScrollContainer", true, false):
		var scroll := child as ScrollContainer
		if scroll == null or not scroll.is_visible_in_tree():
			continue
		var bar: ScrollBar = scroll.get_h_scroll_bar() if sideways else scroll.get_v_scroll_bar()
		if not bar.visible or bar.max_value <= 0.0:
			continue
		if sideways:
			scroll.scroll_horizontal = 0
		else:
			scroll.scroll_vertical = 0
		# The bar's range is only final once the container has been laid out
		# after the programmatic scroll above; read it too early and the drag is
		# measured against a range the row did not have yet.
		for _frame in range(4):
			await process_frame
		# A bar's value can only reach max_value - page, so that is the most a
		# drag can cover no matter how far the thumb travels.
		var range_now := maxf(0.0, bar.max_value - bar.page)
		var service := _front_end.get_node_or_null("ProgressionService")
		var selected_before: Variant = service.get("selected_weapon_id") if service != null else ""
		var point := scroll.get_global_rect().get_center()
		var step := Vector2(-30.0, 0.0) if sideways else Vector2(0.0, -30.0)

		var press := InputEventScreenTouch.new()
		press.index = 0
		press.pressed = true
		press.position = point
		_viewport.push_input(press)
		await process_frame

		var travelled := 0.0
		for _index in range(6):
			var drag := InputEventScreenDrag.new()
			drag.index = 0
			drag.relative = step
			drag.position = point + step * float(_index + 1)
			_viewport.push_input(drag)
			travelled += absf(step.x if sideways else step.y)
			await process_frame

		var release := InputEventScreenTouch.new()
		release.index = 0
		release.pressed = false
		release.position = point + step * 6.0
		_viewport.push_input(release)
		await process_frame
		await process_frame

		var moved := float(scroll.scroll_horizontal if sideways else scroll.scroll_vertical)
		var axis := "sideways" if sideways else "down"
		# A short list reaches its end before the thumb does; landing on the end
		# is still a scroll, so compare against whichever ran out first.
		var reachable := minf(travelled, range_now)
		var message := "%s: a thumb drag scrolls the list %s (%.0f of %.0f px, range %.0f px)"
		_expect(moved >= reachable * 0.9, message % [where, axis, moved, reachable, range_now])
		if service != null:
			_expect(
				service.get("selected_weapon_id") == selected_before,
				"%s: dragging the list does not also select the card it started on" % where
			)


func _first_card(scroll: ScrollContainer) -> Control:
	for child in scroll.find_children("*", "Control", true, false):
		var control := child as Control
		if control != null and control.is_visible_in_tree() and control is Button:
			return control
	return null


## `MenuStage.is_landscape()` for the stage being measured, without assuming the
## probe's own viewport agrees with what the stage measured.
func is_landscape(stage: Control) -> bool:
	var size := Vector2(stage.size)
	return size.x > size.y * 1.2


func _inside_scroll_container(control: Control) -> bool:
	var node: Node = control.get_parent()
	while node != null:
		if node is ScrollContainer:
			return true
		node = node.get_parent()
	return false


func _expect(condition: bool, message: String) -> bool:
	if condition:
		print("  ok: " + message)
		return true
	_fail(message)
	return false


func _fail(message: String) -> void:
	print("  fail: " + message)
	_failures.append(message)
