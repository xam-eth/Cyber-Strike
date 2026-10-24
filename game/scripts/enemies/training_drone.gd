class_name TrainingDrone
extends StaticBody3D

signal health_changed(current: float, maximum: float)
signal damage_received(amount: float, current: float, maximum: float)
signal eliminated

@export_range(1.0, 500.0, 1.0) var max_health: float = 54.0
@export_range(0.5, 10.0, 0.5) var respawn_delay: float = 2.0

var current_health: float = 0.0
var _is_downed: bool = false
var _active: bool = true

@onready var collision_shape: CollisionShape3D = $CollisionShape3D
@onready var visuals: EnemyVisual = $Visuals


func _ready() -> void:
	add_to_group("enemies")
	current_health = max_health
	health_changed.emit(current_health, max_health)


## The drone never moves; its hover is driven here so the idle craft keeps
## breathing instead of hanging frozen in the air.
func _process(delta: float) -> void:
	visuals.update_motion(Vector3.ZERO, delta)


func apply_damage(amount: float, _source: Node = null) -> void:
	if _is_downed or amount <= 0.0:
		return

	var applied_damage := minf(amount, current_health)
	current_health = maxf(current_health - applied_damage, 0.0)
	damage_received.emit(applied_damage, current_health, max_health)
	health_changed.emit(current_health, max_health)
	if current_health <= 0.0:
		_is_downed = true
		eliminated.emit()
		Sfx.play_3d(&"enemy_down", global_position)
		visuals.play_death()
		collision_shape.set_deferred("disabled", true)
		set_deferred("collision_layer", 0)
		_respawn_after_delay()
	else:
		visuals.play_hit_flash()


## Practice dummy is an Explore affordance, never a Defense objective. Remove
## both its collision and enemies-group membership when a real wave starts so
## it cannot absorb shots or count as a misleading EMP target.
func set_active(value: bool) -> void:
	_active = value
	visible = value
	collision_layer = 2 if value else 0
	collision_shape.set_deferred("disabled", not value)
	if value and not is_in_group("enemies"):
		add_to_group("enemies")
	elif not value and is_in_group("enemies"):
		remove_from_group("enemies")


func reset() -> void:
	_is_downed = false
	current_health = max_health
	visuals.reset_visual()
	collision_shape.set_deferred("disabled", not _active)
	set_deferred("collision_layer", 2 if _active else 0)
	health_changed.emit(current_health, max_health)


func _respawn_after_delay() -> void:
	await get_tree().create_timer(respawn_delay).timeout
	if is_inside_tree() and _is_downed and _active:
		reset()
