class_name NovaProjectile
extends Node3D

var _direction: Vector3 = Vector3.FORWARD
var _damage: float = 34.0
var _speed: float = 18.0
var _remaining_range: float = 32.0
var _collision_mask: int = 3
var _splash_damage: float = 24.0
var _splash_radius: float = 4.0
var _shooter: CollisionObject3D


func launch(
	start_position: Vector3,
	aim_point: Vector3,
	shooter: CollisionObject3D,
	definition: WeaponDefinition
) -> void:
	global_position = start_position
	_direction = aim_point - start_position
	if _direction.length_squared() < 0.0001:
		_direction = -global_basis.z
	_direction = _direction.normalized()
	_shooter = shooter
	_damage = definition.damage
	_speed = definition.projectile_speed
	_remaining_range = definition.max_range
	_collision_mask = definition.collision_mask
	_splash_damage = definition.splash_damage
	_splash_radius = definition.splash_radius
	look_at(global_position + _direction, Vector3.UP)


func _physics_process(delta: float) -> void:
	if _remaining_range <= 0.0:
		queue_free()
		return

	var step_distance := minf(_speed * delta, _remaining_range)
	var next_position := global_position + _direction * step_distance
	var excluded_rids: Array[RID] = []
	if is_instance_valid(_shooter):
		excluded_rids.append(_shooter.get_rid())
	var query := PhysicsRayQueryParameters3D.create(
		global_position, next_position, _collision_mask, excluded_rids
	)
	var hit := get_world_3d().direct_space_state.intersect_ray(query)
	if not hit.is_empty():
		var collider: Object = hit.get("collider")
		var hit_position: Vector3 = hit.get("position", next_position)
		_detonate(hit_position, collider)
		return

	global_position = next_position
	_remaining_range -= step_distance


func _detonate(impact_position: Vector3, direct_target: Object) -> void:
	global_position = impact_position
	var damaged_targets: Dictionary = {}
	_apply_damage_once(direct_target, _damage, damaged_targets)
	if _splash_damage > 0.0 and _splash_radius > 0.0:
		_apply_splash_damage(impact_position, damaged_targets)
	Sfx.play_3d(&"explosion", impact_position)
	queue_free()


func _apply_splash_damage(impact_position: Vector3, damaged_targets: Dictionary) -> void:
	var shape := SphereShape3D.new()
	shape.radius = _splash_radius
	var query := PhysicsShapeQueryParameters3D.new()
	query.shape = shape
	query.transform = Transform3D(Basis.IDENTITY, impact_position)
	query.collision_mask = _collision_mask
	query.collide_with_bodies = true
	query.collide_with_areas = true
	if is_instance_valid(_shooter):
		query.exclude.append(_shooter.get_rid())
	var hits := get_world_3d().direct_space_state.intersect_shape(query, 64)
	for hit in hits:
		var collider: Object = hit.get("collider")
		_apply_damage_once(collider, _splash_damage, damaged_targets)


func _apply_damage_once(target: Object, amount: float, damaged_targets: Dictionary) -> void:
	if target == null or not target.has_method("apply_damage"):
		return
	var target_id := target.get_instance_id()
	if damaged_targets.has(target_id):
		return
	damaged_targets[target_id] = true
	target.call("apply_damage", amount, _shooter)
