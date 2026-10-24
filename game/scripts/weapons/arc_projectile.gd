class_name ArcProjectile
extends Node3D

const ImpactBurstScript = preload("res://scripts/weapons/impact_burst.gd")
const EFFECT_DURATION: float = 0.14

var _start_position: Vector3 = Vector3.ZERO
var _aim_point: Vector3 = Vector3.ZERO
var _max_range: float = 30.0
var _collision_mask: int = 3
var _damage: float = 20.0
var _chain_count: int = 2
var _chain_radius: float = 5.0
var _chain_damage_multiplier: float = 0.7
var _shooter: CollisionObject3D
var _pending_shot: bool = false
var _has_launched: bool = false
var _visual_points: Array[Vector3] = []


func _ready() -> void:
	set_physics_process(false)


func launch(
	start_position: Vector3,
	aim_point: Vector3,
	shooter: CollisionObject3D,
	definition: WeaponDefinition
) -> void:
	if _has_launched:
		return
	_has_launched = true
	global_transform = Transform3D.IDENTITY
	_start_position = start_position
	_aim_point = aim_point
	_max_range = maxf(definition.max_range, 0.0)
	_collision_mask = definition.collision_mask
	_damage = maxf(definition.damage, 0.0)
	_chain_count = maxi(definition.chain_count, 0)
	_chain_radius = maxf(definition.chain_radius, 0.0)
	_chain_damage_multiplier = clampf(definition.chain_damage_multiplier, 0.0, 1.0)
	_shooter = shooter
	_pending_shot = true
	set_physics_process(true)


func _physics_process(_delta: float) -> void:
	if not _pending_shot:
		return
	_pending_shot = false
	_resolve_shot()
	set_physics_process(false)


func _resolve_shot() -> void:
	var direction := _aim_point - _start_position
	var aim_distance := direction.length()
	if aim_distance < 0.0001:
		direction = -global_basis.z
		aim_distance = _max_range
	else:
		direction /= aim_distance
	var ray_end := _start_position + direction * minf(aim_distance, _max_range)
	_visual_points.append(_start_position)

	var excluded_rids: Array[RID] = []
	if is_instance_valid(_shooter):
		excluded_rids.append(_shooter.get_rid())
	var query := PhysicsRayQueryParameters3D.create(
		_start_position, ray_end, _collision_mask, excluded_rids
	)
	query.collide_with_areas = true
	var hit := get_world_3d().direct_space_state.intersect_ray(query)
	if hit.is_empty():
		_visual_points.append(ray_end)
		_build_beam_visual()
		_expire_after_delay()
		return

	var hit_position: Vector3 = hit.get("position", ray_end)
	ImpactBurstScript.spawn(
		get_parent(), hit_position, Color(0.64, 0.7, 1.0), hit.get("normal", Vector3.UP)
	)
	Sfx.play_3d(&"chain_zap", hit_position)
	_visual_points.append(hit_position)
	var first_target := hit.get("collider") as CollisionObject3D
	var damaged_targets: Dictionary = {}
	if first_target != null and first_target.has_method("apply_damage"):
		_apply_damage_once(first_target, _damage, damaged_targets)
		var previous_target := first_target
		for chain_index in range(_chain_count):
			var next_target := _find_next_chain_target(previous_target, damaged_targets)
			if next_target == null:
				break
			var chain_damage := _damage * pow(_chain_damage_multiplier, chain_index + 1)
			if not _apply_damage_once(next_target, chain_damage, damaged_targets):
				break
			_visual_points.append(next_target.global_position)
			previous_target = next_target

	_build_beam_visual()
	_expire_after_delay()


func _find_next_chain_target(
	source: CollisionObject3D, damaged_targets: Dictionary
) -> CollisionObject3D:
	if _chain_radius <= 0.0 or not is_instance_valid(source):
		return null
	var shape := SphereShape3D.new()
	shape.radius = _chain_radius
	var query := PhysicsShapeQueryParameters3D.new()
	query.shape = shape
	query.transform = Transform3D(Basis.IDENTITY, source.global_position)
	query.collision_mask = _collision_mask
	query.collide_with_bodies = true
	query.collide_with_areas = true
	if is_instance_valid(_shooter):
		query.exclude.append(_shooter.get_rid())

	var hits := get_world_3d().direct_space_state.intersect_shape(query, 64)
	var best_target: CollisionObject3D
	var best_distance_squared := INF
	var best_instance_id: int = 0
	var radius_squared := _chain_radius * _chain_radius
	for hit in hits:
		var candidate := hit.get("collider") as CollisionObject3D
		if candidate == null or not candidate.has_method("apply_damage"):
			continue
		var candidate_id := candidate.get_instance_id()
		if candidate_id == source.get_instance_id() or damaged_targets.has(candidate_id):
			continue
		var distance_squared := source.global_position.distance_squared_to(
			candidate.global_position
		)
		if distance_squared > radius_squared:
			continue
		if not _has_chain_line_of_sight(source, candidate):
			continue
		if (
			best_target == null
			or distance_squared < best_distance_squared
			or (
				is_equal_approx(distance_squared, best_distance_squared)
				and candidate_id < best_instance_id
			)
		):
			best_target = candidate
			best_distance_squared = distance_squared
			best_instance_id = candidate_id
	return best_target


func _has_chain_line_of_sight(source: CollisionObject3D, target: CollisionObject3D) -> bool:
	var source_position := source.global_position
	var target_position := target.global_position
	if source_position.is_equal_approx(target_position):
		return false
	var excluded_rids: Array[RID] = [source.get_rid()]
	if is_instance_valid(_shooter):
		excluded_rids.append(_shooter.get_rid())
	var query := PhysicsRayQueryParameters3D.create(
		source_position, target_position, _collision_mask, excluded_rids
	)
	query.collide_with_areas = true
	var hit := get_world_3d().direct_space_state.intersect_ray(query)
	return not hit.is_empty() and hit.get("collider") == target


func _apply_damage_once(
	target: CollisionObject3D, amount: float, damaged_targets: Dictionary
) -> bool:
	if (
		target == null
		or amount <= 0.0
		or not is_instance_valid(target)
		or not target.has_method("apply_damage")
	):
		return false
	var target_id := target.get_instance_id()
	if damaged_targets.has(target_id):
		return false
	damaged_targets[target_id] = true
	target.call("apply_damage", amount, _shooter)
	return true


func _build_beam_visual() -> void:
	if _visual_points.size() < 2:
		return
	var beam_mesh := ImmediateMesh.new()
	var beam_material := StandardMaterial3D.new()
	beam_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	beam_material.albedo_color = Color(0.3, 0.88, 1.0, 1.0)
	beam_material.emission_enabled = true
	beam_material.emission = Color(0.12, 0.55, 1.0, 1.0)
	beam_material.emission_energy_multiplier = 2.0
	beam_mesh.surface_begin(Mesh.PRIMITIVE_LINES, beam_material)
	for point_index in range(1, _visual_points.size()):
		beam_mesh.surface_add_vertex(to_local(_visual_points[point_index - 1]))
		beam_mesh.surface_add_vertex(to_local(_visual_points[point_index]))
	beam_mesh.surface_end()
	var beam_instance := MeshInstance3D.new()
	beam_instance.mesh = beam_mesh
	add_child(beam_instance)


func _expire_after_delay() -> void:
	await get_tree().create_timer(EFFECT_DURATION).timeout
	if is_inside_tree():
		queue_free()
