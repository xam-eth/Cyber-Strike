extends SceneTree

## Real input-path ADS regression for every shipped weapon. In particular, a
## browser may deny pointer lock; right-button aim and look must still work.
const MainScene = preload("res://scenes/main.tscn")
const STRETCH := 390.0 / 720.0

var _failures := 0


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	AegisPreferences.write(AegisPreferences.defaults())
	var main := MainScene.instantiate()
	main.set("start_wave_session_on_ready", false)
	main.get_node("ProgressionService").set("profile_path", "")
	root.add_child(main)
	await process_frame
	var profile := main.get_node("ProgressionService") as ProgressionService
	profile.balance = 1000
	profile.secure_cache(&"ads_fixture", &"arc_blueprint", &"arc_shooter")
	profile.unlock_weapon(&"nova_launcher")
	profile.unlock_weapon(&"arc_shooter")

	var player := main.get_node("Player") as PlayerController
	var controls := main.get_node("HUD/TouchControls") as TouchControls
	var camera := player.aim_camera
	var rig := player.camera_rig
	controls.size = Vector2(844.0 / STRETCH, 390.0 / STRETCH)
	controls.apply_layout_for_size(Vector2(844.0, 390.0), STRETCH)
	await process_frame

	for index in range(WeaponDefinition.DEFINITION_IDS.size()):
		player.select_weapon(index)
		await process_frame
		var id := player.weapon_controller.get_current_definition().weapon_id
		_expect(id == WeaponDefinition.DEFINITION_IDS[index], "%s is the fixture weapon" % id)

		# Mouse: force VISIBLE after the press to reproduce denied pointer lock.
		var rest_fov := camera.fov
		_mouse_button(true)
		await physics_frame
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
		for frame in 18:
			await physics_frame
		_expect(
			player.is_aiming() and camera.fov < rest_fov - 5.0,
			"%s right-mouse ADS survives without pointer lock" % id
		)
		_expect(
			String((controls.get("_aim_button") as Button).get_meta("aegis_state")) == "active",
			"%s right-mouse ADS updates the HUD state" % id
		)
		var yaw_before: float = rig.yaw_pivot.rotation.y
		var pitch_before: float = rig.pitch_pivot.rotation.x
		var motion := InputEventMouseMotion.new()
		motion.position = Vector2(420, 190)
		motion.relative = Vector2(28, -12)
		Input.parse_input_event(motion)
		await physics_frame
		_expect(
			(
				not is_equal_approx(yaw_before, rig.yaw_pivot.rotation.y)
				and not is_equal_approx(pitch_before, rig.pitch_pivot.rotation.x)
			),
			"%s right-mouse motion changes yaw and pitch while aiming" % id
		)
		_mouse_button(false)
		for frame in 20:
			await physics_frame
		_expect(
			not player.is_aiming() and camera.fov > rest_fov - 2.0,
			"%s right-mouse release restores follow framing" % id
		)

		# Touch: one finger holds AIM while a second drags the open look lane.
		controls.set_touch_mode(true)
		rest_fov = camera.fov
		var aim := controls.get("_aim_button") as Button
		_touch(90, aim.get_global_rect().get_center(), true)
		for frame in 18:
			await physics_frame
		_expect(
			player.is_aiming() and camera.fov < rest_fov - 5.0, "%s touch AIM hold enters ADS" % id
		)
		yaw_before = rig.yaw_pivot.rotation.y
		pitch_before = rig.pitch_pivot.rotation.x
		var look := Vector2(controls.size.x * 0.52, controls.size.y * 0.62)
		_touch(91, look, true)
		_drag(91, look + Vector2(30, -12), Vector2(30, -12))
		await physics_frame
		_expect(
			(
				not is_equal_approx(yaw_before, rig.yaw_pivot.rotation.y)
				and not is_equal_approx(pitch_before, rig.pitch_pivot.rotation.x)
			),
			"%s second-finger touch drag changes ADS yaw and pitch" % id
		)
		_touch(91, look + Vector2(30, -12), false)
		_touch(90, aim.get_global_rect().get_center(), false)
		for frame in 20:
			await physics_frame
		_expect(
			not player.is_aiming() and camera.fov > rest_fov - 2.0,
			"%s touch AIM release restores follow framing" % id
		)

	main.queue_free()
	await process_frame
	if _failures > 0:
		printerr("ADS input smoke: %d failure(s)" % _failures)
		quit(1)
	else:
		print("ADS input smoke: PASS")
		quit()


func _mouse_button(pressed: bool) -> void:
	var event := InputEventMouseButton.new()
	event.button_index = MOUSE_BUTTON_RIGHT
	event.button_mask = MOUSE_BUTTON_MASK_RIGHT if pressed else 0
	event.position = Vector2(420, 190)
	event.global_position = event.position
	event.pressed = pressed
	Input.parse_input_event(event)


func _touch(id: int, position: Vector2, pressed: bool) -> void:
	var event := InputEventScreenTouch.new()
	event.index = id
	event.position = position
	event.pressed = pressed
	# Same dispatcher entry point as the established playability HUD suite.
	var controls := root.get_node_or_null("Main/HUD/TouchControls")
	if controls == null:
		controls = _find_controls(root)
	if controls != null:
		controls.call("_input", event)


func _drag(id: int, position: Vector2, relative: Vector2) -> void:
	var event := InputEventScreenDrag.new()
	event.index = id
	event.position = position
	event.relative = relative
	var controls := _find_controls(root)
	if controls != null:
		controls.call("_input", event)


func _find_controls(node: Node) -> TouchControls:
	if node is TouchControls:
		return node
	for child in node.get_children():
		var found := _find_controls(child)
		if found != null:
			return found
	return null


func _expect(condition: bool, label: String) -> void:
	if condition:
		print("  PASS: ", label)
	else:
		_failures += 1
		printerr("  FAIL: ", label)
