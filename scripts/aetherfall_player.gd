class_name AetherfallPlayer
extends CharacterBody3D
## Compact third-person validation controller for the standalone Aetherfall slice.
## It is not presented as the removed EXOCOMFLICT player-combat controller.

signal interaction_target_changed(target: AetherfallInteractionTarget)
signal interaction_feedback(message: String)

@export var move_speed := 5.5
@export var jump_velocity := 4.4
@export var mouse_sensitivity := 0.0025

var gravity := float(ProjectSettings.get_setting("physics/3d/default_gravity"))
var _interaction_target: AetherfallInteractionTarget
var _review_mode := false

@onready var pivot := $Pivot as Node3D
@onready var camera := $Pivot/SpringArm3D/Camera3D as Camera3D

func _ready() -> void:
	add_to_group("aetherfall_player")
	camera.make_current()

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_F1:
		set_review_mode(not _review_mode)
		return
	if _review_mode:
		return
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_RIGHT:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED if event.pressed else Input.MOUSE_MODE_VISIBLE
	elif event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		rotation.y -= event.relative.x * mouse_sensitivity
		pivot.rotation.x = clampf(pivot.rotation.x - event.relative.y * mouse_sensitivity, -1.15, 0.45)
	elif event.is_action_pressed("interact"):
		attempt_active_interaction()

func _physics_process(delta: float) -> void:
	if _review_mode:
		return
	if not is_on_floor():
		velocity.y -= gravity * delta
	if Input.is_action_just_pressed("jump") and is_on_floor():
		velocity.y = jump_velocity
	var movement := Input.get_vector("move_left", "move_right", "move_forward", "move_back")
	var direction := (transform.basis * Vector3(movement.x, 0.0, movement.y)).normalized()
	if direction.length_squared() > 0.001:
		velocity.x = direction.x * move_speed
		velocity.z = direction.z * move_speed
	else:
		velocity.x = move_toward(velocity.x, 0.0, move_speed * 7.0 * delta)
		velocity.z = move_toward(velocity.z, 0.0, move_speed * 7.0 * delta)
	move_and_slide()

func set_interaction_target(target: AetherfallInteractionTarget) -> void:
	if target == _interaction_target:
		return
	_interaction_target = target
	interaction_target_changed.emit(_interaction_target)

func clear_interaction_target(target: AetherfallInteractionTarget) -> void:
	if target != _interaction_target:
		return
	_interaction_target = null
	interaction_target_changed.emit(null)

func attempt_active_interaction() -> Dictionary:
	if _interaction_target == null:
		var none := {"ok": false, "code": "no_target", "message": "Tidak ada perangkat dalam jangkauan."}
		show_interaction_feedback(str(none.message))
		return none
	return _interaction_target.attempt_interaction(self)

func show_interaction_feedback(message: String) -> void:
	interaction_feedback.emit(message)

func set_review_mode(enabled: bool) -> void:
	_review_mode = enabled
	var review := get_tree().current_scene.get_node_or_null("ReviewCamera")
	if review != null and review.has_method("set_review_mode"):
		review.set_review_mode(enabled)
	if not enabled:
		camera.make_current()
	show_interaction_feedback("Mode review aktif (F1 untuk kembali ke operator)." if enabled else "Mode operator aktif.")
