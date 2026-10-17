class_name ShooterEnemy
extends CharacterBody3D

signal health_changed(current: float, maximum: float)
signal damage_received(amount: float, current: float, maximum: float)
signal eliminated
signal attack_resolved(hit_target: bool)

@export var target_path: NodePath = ^"../Player"
@export_range(1.0, 200.0, 1.0) var max_health: float = 30.0
@export_range(1.0, 8.0, 0.1) var move_speed: float = 2.8
@export_range(1.0, 40.0, 0.5) var move_acceleration: float = 14.0
@export_range(2.0, 12.0, 0.5) var minimum_standoff: float = 6.0
@export_range(6.0, 30.0, 0.5) var preferred_range: float = 12.0
@export_range(8.0, 40.0, 1.0) var detection_range: float = 28.0
@export_range(4.0, 40.0, 1.0) var max_attack_range: float = 20.0
@export_range(0.5, 40.0, 0.5) var attack_damage: float = 8.0
@export_range(0.1, 3.0, 0.05) var attack_windup: float = 0.7
@export_range(0.5, 6.0, 0.1) var attack_interval: float = 2.2
@export_flags_3d_physics var sight_collision_mask: int = 1
@export_flags_3d_physics var attack_collision_mask: int = 5

var current_health: float = 0.0
var _target: Node3D
var _is_downed: bool = false
var _attack_cooldown: float = 0.0
var _windup_remaining: float = 0.0
var _locked_attack_point: Vector3 = Vector3.ZERO
var _spawn_transform: Transform3D

@onready var collision_shape: CollisionShape3D = $CollisionShape3D
@onready var visuals: EnemyVisual = $Visuals
@onready var muzzle: Marker3D = $Visuals/Muzzle
@onready var aim_marker: MeshInstance3D = $AimMarker
@onready var core: MeshInstance3D = get_node_or_null("Visuals/CoreMesh") as MeshInstance3D


func _ready() -> void:
	add_to_group("enemies")
	add_to_group("shooter_enemies")
	_spawn_transform = global_transform
	_target = get_node_or_null(target_path) as Node3D
	current_health = max_health
	health_changed.emit(current_health, max_health)
	if _target == null:
		push_warning("ShooterEnemy could not find its target at '%s'." % target_path)


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
			rotation.y = atan2(-direction.x, -direction.z)
			if distance > detection_range:
				_cancel_attack()
			elif distance > preferred_range + 1.5:
				desired_velocity = direction * move_speed
				_cancel_attack()
			elif distance < minimum_standoff:
				desired_velocity = -direction * move_speed
				_cancel_attack()
			elif _windup_remaining > 0.0:
				if distance > max_attack_range or not _has_line_of_sight():
					_cancel_attack()
				else:
					_windup_remaining = maxf(_windup_remaining - delta, 0.0)
					if _windup_remaining <= 0.0:
						_resolve_attack()
			elif distance <= max_attack_range and _attack_cooldown <= 0.0:
				if _has_line_of_sight():
					_begin_attack_windup()
	else:
		_cancel_attack()

	if _windup_remaining > 0.0:
		desired_velocity = Vector3.ZERO
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
	visuals.update_motion(velocity, delta)
	_update_core_telegraph(delta)


## The core in the chest pulses while the ranged attack charges, so the telegraph
## reads from the model itself and not only from the floating aim marker.
func _update_core_telegraph(delta: float) -> void:
	if not is_instance_valid(core):
		return
	var target_scale := Vector3.ONE
	if _windup_remaining > 0.0:
		var charge := 1.0 - clampf(_windup_remaining / maxf(attack_windup, 0.001), 0.0, 1.0)
		target_scale = Vector3.ONE * (1.0 + 0.55 * charge)
	core.scale = core.scale.lerp(target_scale, minf(delta * 14.0, 1.0))


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
		_cancel_attack()
		eliminated.emit()
		Sfx.play_3d(&"enemy_down", global_position)
		visuals.play_death()
		collision_shape.set_deferred("disabled", true)
		set_deferred("collision_layer", 0)
	else:
		visuals.play_hit_flash()


func is_defeated() -> bool:
	return _is_downed


func is_winding_up() -> bool:
	return _windup_remaining > 0.0


func reset_shooter() -> void:
	_is_downed = false
	_attack_cooldown = 0.0
	_windup_remaining = 0.0
	current_health = max_health
	velocity = Vector3.ZERO
	global_transform = _spawn_transform
	visuals.reset_visual()
	aim_marker.visible = false
	collision_shape.set_deferred("disabled", false)
	set_deferred("collision_layer", 2)
	health_changed.emit(current_health, max_health)


func _begin_attack_windup() -> void:
	_windup_remaining = attack_windup
	_attack_cooldown = attack_interval
	_locked_attack_point = _target.global_position + Vector3.UP * 0.9
	aim_marker.global_position = _locked_attack_point + Vector3.UP * 0.85
	aim_marker.visible = true


func _resolve_attack() -> void:
	var hit_target := false
	var excluded_rids: Array[RID] = [get_rid()]
	var query := PhysicsRayQueryParameters3D.create(
		muzzle.global_position, _locked_attack_point, attack_collision_mask, excluded_rids
	)
	var hit := get_world_3d().direct_space_state.intersect_ray(query)
	if not hit.is_empty():
		var collider: Object = hit.get("collider")
		if collider == _target and collider.has_method("apply_damage"):
			if not collider.has_method("can_take_damage") or bool(collider.call("can_take_damage")):
				collider.call("apply_damage", attack_damage, self)
				hit_target = true
	attack_resolved.emit(hit_target)
	_cancel_attack()


func _cancel_attack() -> void:
	_windup_remaining = 0.0
	if is_instance_valid(aim_marker):
		aim_marker.visible = false


func _has_line_of_sight() -> bool:
	if not is_instance_valid(_target):
		return false
	var destination := _target.global_position + Vector3.UP * 0.9
	var excluded_rids: Array[RID] = [get_rid()]
	var query := PhysicsRayQueryParameters3D.create(
		muzzle.global_position, destination, sight_collision_mask, excluded_rids
	)
	return get_world_3d().direct_space_state.intersect_ray(query).is_empty()


func _target_is_defeated() -> bool:
	return _target.has_method("can_take_damage") and not bool(_target.call("can_take_damage"))
