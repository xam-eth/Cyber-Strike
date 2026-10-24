class_name ThirdPersonCameraRig
extends Node3D

## Over-the-shoulder camera with an aim-down-sights (ADS) state, smooth
## transitions and short recoil kicks.
##
## Node layout is fixed and referenced by the player controller, the HUD tests and
## the wave director: CameraRig/YawPivot/PitchPivot/SpringArm3D/Camera3D.
## Hold-to-aim (desktop right mouse) or the HUD AIM toggle calls set_aiming(true);
## the rig then eases the arm in, raises the shoulder offset and narrows the FOV
## instead of snapping, which is what makes aiming readable on a phone screen.
## Recoil must NEVER write Camera3D.position: SpringArm3D owns its child
## displacement, and resetting it to zero puts the lens inside the avatar.

@export var look_sensitivity: float = 0.0035
@export_range(-80.0, 0.0, 1.0) var min_pitch_degrees: float = -55.0
@export_range(0.0, 80.0, 1.0) var max_pitch_degrees: float = 38.0
@export_group("Framing")
@export_range(1.5, 9.0, 0.05) var rest_spring_length: float = 4.2
@export_range(0.8, 6.0, 0.05) var aim_spring_length: float = 3.0
@export var rest_shoulder_offset: Vector3 = Vector3(0.55, 0.14, 0.0)
@export var aim_shoulder_offset: Vector3 = Vector3(0.50, 0.22, 0.0)
@export var rest_pivot_height: float = 1.58
@export var aim_pivot_height: float = 1.58
@export_range(30.0, 110.0, 0.5) var rest_fov: float = 66.0
@export_range(20.0, 90.0, 0.5) var aim_fov: float = 50.0
@export_range(1.0, 30.0, 0.5) var transition_speed: float = 9.0
@export_group("Kick")
@export_range(0.0, 1.0, 0.005) var kick_rotation_degrees: float = 0.16
@export_range(0.0, 1.0, 0.005) var kick_push: float = 0.05
@export_range(1.0, 30.0, 0.5) var kick_recovery: float = 11.0
@export_range(0.0, 1.0, 0.01) var walk_bob_scale: float = 0.35
@export_group("Aspect")
@export_range(1.0, 2.5, 0.05) var portrait_distance_factor: float = 1.45
@export_range(0.0, 30.0, 0.5) var portrait_fov_boost: float = 7.0
@export_range(0.0, 0.4, 0.01) var portrait_height_boost: float = 0.12

var _aiming: bool = false
var _aim_blend: float = 0.0
var _kick: float = 0.0
var _kick_offset: Vector3 = Vector3.ZERO
var _default_walk_bob: float = 0.0
var _default_kick_rotation: float = 0.0
var _default_kick_push: float = 0.0
var _default_pitch: float = 0.0
var _qa_camera_trace: bool = false
var _qa_trace_elapsed: float = 0.0

@onready var yaw_pivot: Node3D = $YawPivot
@onready var pitch_pivot: Node3D = $YawPivot/PitchPivot
@onready var spring_arm: SpringArm3D = $YawPivot/PitchPivot/SpringArm3D
@onready var spring_camera: Camera3D = $YawPivot/PitchPivot/SpringArm3D/Camera3D


func _ready() -> void:
	_default_walk_bob = walk_bob_scale
	_default_kick_rotation = kick_rotation_degrees
	_default_kick_push = kick_push
	# Opt-in browser telemetry lets a real WebGL touch probe distinguish ADS,
	# spring-arm obstruction and weapon motion without turning QA into a cheat.
	# Normal players pay no per-frame diagnostic cost.
	if OS.has_feature("web"):
		_qa_camera_trace = bool(
			JavaScriptBridge.eval("new URLSearchParams(location.search).has('qa_camera')")
		)
	_apply_blend(0.0)
	pitch_pivot.rotation.x = clampf(
		pitch_pivot.rotation.x, deg_to_rad(min_pitch_degrees), deg_to_rad(max_pitch_degrees)
	)
	_default_pitch = pitch_pivot.rotation.x


func _process(delta: float) -> void:
	var target_blend := 1.0 if _aiming else 0.0
	_aim_blend = move_toward(_aim_blend, target_blend, clampf(transition_speed, 1.0, 30.0) * delta)
	_apply_blend(_aim_blend)
	if _kick > 0.0:
		_kick = maxf(_kick - kick_recovery * delta * _kick, 0.0)
		if _kick < 0.001:
			_kick = 0.0
		_apply_kick()
	if _qa_camera_trace:
		_qa_trace_elapsed += delta
		if _qa_trace_elapsed >= 0.5:
			_qa_trace_elapsed = 0.0
			var avatar := get_parent().get_node_or_null("VisualRoot")
			print(
				(
					"Camera QA: aim=%s blend=%.2f fov=%.1f arm=%.2f hit=%.2f cam=%s player=%s fire=%s clip=%s"
					% [
						_aiming,
						_aim_blend,
						spring_camera.fov,
						spring_arm.spring_length,
						spring_arm.get_hit_length(),
						spring_camera.global_position,
						get_parent().global_position,
						get_parent().get("_touch_fire_pressed"),
						avatar.call("current_clip") if is_instance_valid(avatar) else "none",
					]
				)
			)
			# A clip name alone does not prove the imported Blender bones moved.
			# This opt-in trace distinguishes a frozen AnimationPlayer from a
			# compositor frame that missed the short collapse on slow WebGL.
			if is_instance_valid(avatar) and avatar.call("current_clip") == "death":
				var animation := avatar.get("_anim_player") as AnimationPlayer
				var skeleton := avatar.get("_skeleton") as Skeleton3D
				if animation != null and skeleton != null:
					var head_index := skeleton.find_bone("Head")
					var head_y := -1.0
					if head_index >= 0:
						head_y = (
							(
								skeleton.global_transform
								* skeleton.get_bone_global_pose(head_index).origin
							)
							. y
						)
					print(
						(
							"Rig QA: death playing=%s active=%s t=%.2f/%.2f head_y=%.2f"
							% [
								animation.is_playing(),
								animation.active,
								animation.current_animation_position,
								animation.current_animation_length,
								head_y,
							]
						)
					)


## Accessibility: preserve authored kick/bob values so toggling the option in
## a paused run restores the exact camera feel rather than a hard-coded guess.
func set_reduced_motion(enabled: bool) -> void:
	walk_bob_scale = 0.0 if enabled else _default_walk_bob
	kick_rotation_degrees = 0.0 if enabled else _default_kick_rotation
	kick_push = 0.0 if enabled else _default_kick_push
	if enabled:
		_kick = 0.0
		spring_camera.rotation = Vector3.ZERO
		# Never reset Camera3D.position here: that is the SpringArm3D's output.
		spring_arm.position.z = rest_shoulder_offset.lerp(aim_shoulder_offset, _aim_blend).z
		spring_camera.h_offset = 0.0
		spring_camera.v_offset = 0.0


## Returning from Results begins a new run, not a continuation of the last
## floor-level combat view. Keep yaw/location to respect the player's chosen
## direction, but restore the scene-authored horizon and clear weapon kick.
## Pause/resume deliberately does NOT call this method.
func recenter_for_new_run() -> void:
	_aiming = false
	_aim_blend = 0.0
	_kick = 0.0
	_kick_offset = Vector3.ZERO
	pitch_pivot.rotation.x = _default_pitch
	spring_camera.rotation = Vector3.ZERO
	spring_camera.h_offset = 0.0
	spring_camera.v_offset = 0.0
	_apply_blend(0.0)


func apply_look_delta(delta: Vector2) -> void:
	# Aiming slows the look down so fine adjustments are possible on touch.
	var sensitivity := look_sensitivity * (0.55 if _aim_blend > 0.5 else 1.0)
	yaw_pivot.rotation.y -= delta.x * sensitivity
	var min_pitch := deg_to_rad(min_pitch_degrees)
	var max_pitch := deg_to_rad(max_pitch_degrees)
	pitch_pivot.rotation.x = clampf(
		pitch_pivot.rotation.x - delta.y * sensitivity, min_pitch, max_pitch
	)


func get_yaw_basis() -> Basis:
	return yaw_pivot.global_transform.basis


func set_aiming(value: bool) -> void:
	_aiming = value


func is_aiming() -> bool:
	return _aiming


## 0 at rest, 1 fully aimed; the HUD uses it to tighten the crosshair.
func aim_blend() -> float:
	return _aim_blend


func add_recoil_kick(strength: float = 1.0) -> void:
	_kick = minf(_kick + 0.6 * clampf(strength, 0.2, 2.0), 1.4)
	_apply_kick()


## Short side-to-side sway driven by walking, so movement reads without the
## motion-sickness of a full first-person head bob.
func apply_walk_bob(intensity: float, time_seconds: float) -> void:
	if _kick_offset.length_squared() > 0.0:
		return
	var sway := sin(time_seconds * 6.0) * walk_bob_scale * intensity * 0.05
	spring_camera.h_offset = sway
	spring_camera.v_offset = absf(sin(time_seconds * 3.0)) * walk_bob_scale * intensity * 0.05


## How much extra room a narrow screen needs. A phone in portrait has a small
## horizontal field of view at a fixed vertical one, so the avatar eats the frame
## and the player cannot see what is beside them. Pulling the camera back and
## widening the lens a little fixes both without touching the game rules.
func _aspect_factor() -> float:
	var viewport := get_viewport()
	if viewport == null:
		return 1.0
	var size := viewport.get_visible_rect().size
	if size.y <= 0.0:
		return 1.0
	return clampf(1.5 / maxf(size.x / size.y, 0.3), 1.0, maxf(portrait_distance_factor, 1.0))


func _apply_blend(blend: float) -> void:
	if not is_instance_valid(spring_arm):
		return
	var aspect_room := _aspect_factor()
	spring_arm.spring_length = lerpf(rest_spring_length, aim_spring_length, blend) * aspect_room
	spring_arm.position = rest_shoulder_offset.lerp(aim_shoulder_offset, blend)
	position.y = (
		lerpf(rest_pivot_height, aim_pivot_height, blend)
		* (1.0 + (aspect_room - 1.0) * portrait_height_boost)
	)
	if is_instance_valid(spring_camera):
		var boost_ratio := (
			(aspect_room - 1.0) / maxf(maxf(portrait_distance_factor, 1.0) - 1.0, 0.001)
		)
		spring_camera.fov = lerpf(rest_fov, aim_fov, blend) + boost_ratio * portrait_fov_boost


func _apply_kick() -> void:
	if not is_instance_valid(spring_camera):
		return
	var decayed := _kick * _kick
	_kick_offset = (
		Vector3(randf_range(-1.0, 1.0), randf_range(-1.0, 1.0), randf_range(-1.0, 1.0))
		* decayed
		* kick_rotation_degrees
	)
	spring_camera.rotation = Vector3(
		deg_to_rad(-_kick_offset.x * 6.0), deg_to_rad(_kick_offset.y * 6.0), 0.0
	)
	# The SpringArm3D writes Camera3D.position to place it behind the player.
	# Overwriting that local transform with a tiny recoil value teleports the
	# camera to the shoulder during continuous fire (observed: z 14.01→7.98 m
	# while spring_length stayed 6.09 m). Shift the arm's *origin* instead.
	spring_arm.position.z = (
		rest_shoulder_offset.lerp(aim_shoulder_offset, _aim_blend).z + decayed * kick_push
	)
