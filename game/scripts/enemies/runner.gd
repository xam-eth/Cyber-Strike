class_name RunnerEnemy
extends CharacterBody3D

signal health_changed(current: float, maximum: float)
signal damage_received(amount: float, current: float, maximum: float)
signal eliminated

@export var target_path: NodePath = ^"../Player"
@export_range(1.0, 200.0, 1.0) var max_health: float = 36.0
@export_range(1.0, 10.0, 0.1) var move_speed: float = 3.8
@export_range(1.0, 40.0, 0.5) var move_acceleration: float = 16.0
@export_range(0.8, 3.0, 0.1) var attack_range: float = 1.5
@export_range(1.0, 50.0, 1.0) var attack_damage: float = 8.0
@export_range(0.3, 3.0, 0.1) var attack_interval: float = 1.25
@export_range(3.0, 40.0, 1.0) var detection_range: float = 28.0

var current_health: float = 0.0
var _target: Node3D
var _is_downed: bool = false
var _attack_cooldown: float = 0.0
var _spawn_transform: Transform3D

@onready var collision_shape: CollisionShape3D = $CollisionShape3D
@onready var visuals: EnemyVisual = $Visuals


func _ready() -> void:
	add_to_group("enemies")
	add_to_group("runner_enemies")
	_spawn_transform = global_transform
	_target = get_node_or_null(target_path) as Node3D
	current_health = max_health
	health_changed.emit(current_health, max_health)
	if _target == null:
		push_warning("RunnerEnemy could not find its target at '%s'." % target_path)


func _physics_process(delta: float) -> void:
	if _is_downed:
		return

	_attack_cooldown = maxf(_attack_cooldown - delta, 0.0)
	var desired_velocity := Vector3.ZERO
	if is_instance_valid(_target) and not _target_is_defeated():
		var offset := _target.global_position - global_position
		offset.y = 0.0
		var distance := offset.length()
		if distance > 0.001:
			var direction := offset / distance
			if distance <= detection_range:
				rotation.y = atan2(-direction.x, -direction.z)
				# Don't chase straight through the player's capsule when a nearby
				# prop blocks the sight ray. Stop at melee distance; physical
				# collision with layer 4 keeps the target outside the rifle barrel.
				if distance > attack_range:
					desired_velocity = direction * move_speed
				elif _has_line_of_sight() and _attack_cooldown <= 0.0:
					_attack_target()

	var horizontal_velocity := Vector3(velocity.x, 0.0, velocity.z)
	horizontal_velocity = horizontal_velocity.move_toward(
		desired_velocity, move_acceleration * delta
	)
	velocity.x = horizontal_velocity.x
	velocity.z = horizontal_velocity.z
	if not is_on_floor():
		velocity.y -= float(ProjectSettings.get_setting("physics/3d/default_gravity")) * delta
	else:
		velocity.y = 0.0
	move_and_slide()
	# The kit model has no rig, so the run bob and the forward lean come from here.
	visuals.update_motion(velocity, delta)


func apply_damage(amount: float, _source: Node = null) -> void:
	if _is_downed or amount <= 0.0:
		return

	var applied_damage := minf(amount, current_health)
	current_health = maxf(current_health - applied_damage, 0.0)
	damage_received.emit(applied_damage, current_health, max_health)
	health_changed.emit(current_health, max_health)
	if current_health <= 0.0:
		_is_downed = true
		velocity = Vector3.ZERO
		eliminated.emit()
		Sfx.play_3d(&"enemy_down", global_position)
		visuals.play_death()
	else:
		visuals.play_hit_flash()
		collision_shape.set_deferred("disabled", true)
		set_deferred("collision_layer", 0)


func is_defeated() -> bool:
	return _is_downed


func reset_runner() -> void:
	_is_downed = false
	_attack_cooldown = 0.0
	current_health = max_health
	velocity = Vector3.ZERO
	global_transform = _spawn_transform
	visuals.reset_visual()
	collision_shape.set_deferred("disabled", false)
	set_deferred("collision_layer", 2)
	health_changed.emit(current_health, max_health)


func _target_is_defeated() -> bool:
	return _target.has_method("can_take_damage") and not bool(_target.call("can_take_damage"))


func _has_line_of_sight() -> bool:
	var origin := global_position + Vector3.UP
	var destination := _target.global_position + Vector3.UP
	var excluded_rids: Array[RID] = [get_rid()]
	var query := PhysicsRayQueryParameters3D.create(origin, destination, 1, excluded_rids)
	return get_world_3d().direct_space_state.intersect_ray(query).is_empty()


func _attack_target() -> void:
	_attack_cooldown = attack_interval
	if _target.has_method("apply_damage"):
		_target.call("apply_damage", attack_damage, self)
