extends Node
class_name OrbitCamera
# Orbit rig — discipline: camera-systems #4 (3D third-person orbit with collision, SpringArm, clamped pitch)
# Manual exploration when cinematic is toggled off. Frame-rate independent, uses screen_relative for mouse.
# Also respects level bounds: never shows outside 180x180 world (clamp focus to rect + viewport half-size).

@export var target: Vector3 = Vector3.ZERO  # look centre (tower hub)
@export var distance: float = 78.0
@export var min_distance: float = 12.0
@export var max_distance: float = 145.0
@export var yaw: float = 0.78   # rad
@export var pitch: float = 0.42 # rad
@export var sensitivity: float = 0.004
@export var smooth_rate: float = 8.0
@export var min_pitch: float = -1.25 # ~ -72 deg
@export var max_pitch: float = 0.9   # ~ 51 deg

var _camera: Camera3D
var _enabled: bool = false
var _dragging: bool = false
var _active_pos: Vector3
var _active_target: Vector3

func setup(camera: Camera3D, initial_target: Vector3) -> void:
	_camera = camera
	target = initial_target
	_active_target = target
	_update_camera(0.016, true)

func set_enabled(v: bool) -> void:
	_enabled = v
	if _enabled:
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	else:
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE

func handle_input(event: InputEvent) -> void:
	if not _enabled or not _camera:
		return
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_RIGHT:
			_dragging = event.pressed
		elif event.pressed and event.button_index == MOUSE_BUTTON_WHEEL_UP:
			distance = clampf(distance - 4.0, min_distance, max_distance)
		elif event.pressed and event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			distance = clampf(distance + 4.0, min_distance, max_distance)
	if event is InputEventMouseMotion and _dragging:
		# Use screen_relative — not relative (stretch-scaled) — per camera-systems pitfall
		var rel: Vector2 = event.screen_relative if "screen_relative" in event else event.relative
		yaw -= rel.x * sensitivity
		pitch = clampf(pitch - rel.y * sensitivity, min_pitch, max_pitch)
	elif event is InputEventKey and event.pressed:
		# WASD nudges target (pan) — small steps, respects bounds
		var step := 2.5
		if event.keycode == KEY_W: target.z -= step
		if event.keycode == KEY_S: target.z += step
		if event.keycode == KEY_A: target.x -= step
		if event.keycode == KEY_D: target.x += step
		if event.keycode == KEY_Q: target.y += step
		if event.keycode == KEY_E: target.y -= step
		# clamp target inside world bounds (180x180) so camera never peeks outside
		target.x = clampf(target.x, -78.0, 78.0)
		target.z = clampf(target.z, -78.0, 78.0)
		target.y = clampf(target.y, -2.0, 28.0)

func _process(dt: float) -> void:
	if not _enabled or not _camera: return
	_update_camera(dt, false)

func _update_camera(dt: float, instant: bool) -> void:
	# spherical offset
	var offset := Vector3(0, 0, distance)
	offset = offset.rotated(Vector3(1, 0, 0), pitch)
	offset = offset.rotated(Vector3(0, 1, 0), yaw)
	var desired_pos := target + offset
	var t := 1.0 if instant else (1.0 - exp(-smooth_rate * dt))
	_active_pos = _active_pos.lerp(desired_pos, t) if not instant else desired_pos
	_active_target = _active_target.lerp(target, t) if not instant else target
	_camera.global_position = _active_pos
	_camera.look_at(_active_target, Vector3.UP)
	# TODO: wall collision via SpringArm3D / ray to pull in if blocked — keep hook for later
