class_name NovaProjectile
extends Node3D

const ImpactBurstScript = preload("res://scripts/weapons/impact_burst.gd")
const NovaShockwaveScript = preload("res://scripts/weapons/nova_shockwave.gd")

## The round collides at the muzzle, but its mesh waits until clear of camera.
const VISUAL_CLEARANCE: float = 1.4

var _direction: Vector3 = Vector3.FORWARD
var _damage: float = 34.0
var _speed: float = 18.0
var _remaining_range: float = 32.0
var _collision_mask: int = 3
var _splash_damage: float = 24.0
var _splash_radius: float = 4.0
var _shooter: CollisionObject3D
var _distance_flown: float = 0.0


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
	_distance_flown = 0.0
	look_at(global_position + _direction, Vector3.UP)
	var trail := get_node_or_null("NovaTrail") as MeshInstance3D
	if trail != null:
		trail.rotation.x = PI * 0.5
		trail.position.z = 0.36
	_set_visuals_visible(false)


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
		_detonate(hit_position, collider, hit.get("normal", Vector3.UP))
		return

	global_position = next_position
	_remaining_range -= step_distance
	_distance_flown += step_distance
	if _distance_flown - step_distance < VISUAL_CLEARANCE and _distance_flown >= VISUAL_CLEARANCE:
		_set_visuals_visible(true)


func _set_visuals_visible(value: bool) -> void:
	for mesh_name in ["NovaCore", "NovaTrail"]:
		var mesh := get_node_or_null(mesh_name) as MeshInstance3D
		if mesh != null:
			mesh.visible = value


func _detonate(
	impact_position: Vector3, direct_target: Object, normal: Vector3 = Vector3.UP
) -> void:
	global_position = impact_position
	var damaged_targets: Dictionary = {}
	_apply_damage_once(direct_target, _damage, damaged_targets)
	if _splash_damage > 0.0 and _splash_radius > 0.0:
		_apply_splash_damage(impact_position, damaged_targets)
	var burst := ImpactBurstScript.spawn(
		get_parent(), impact_position, Color(1.0, 0.46, 0.16), normal
	)
	if burst != null:
		# More debris velocity distinguishes an area blast from Pulse's pinprick.
		burst.amount = 28
		burst.initial_velocity_min = 2.4
		burst.initial_velocity_max = 5.6
	# A thin shockfront marks the *real* explosion's radius, grounded below an
	# enemy impact instead of a billboard that obscures the target. It owns no
	# damage: the direct hit and splash above are the only gameplay authority.
	var surface := _find_blast_surface(impact_position, normal)
	var contact: Vector3 = surface["position"]
	var surface_normal: Vector3 = surface["normal"]
	var preferences := AegisPreferences.read()
	NovaShockwaveScript.spawn(
		get_parent(),
		impact_position,
		contact,
		surface_normal,
		_splash_radius,
		bool(preferences.get("reduce_motion", false)),
		bool(preferences.get("reduce_flash", false))
	)
	if (
		OS.has_feature("web")
		and bool(JavaScriptBridge.eval("new URLSearchParams(location.search).has('qa_effects')"))
	):
		var target_name := (direct_target as Node).name if direct_target is Node else &"World"
		print(
			(
				"Effects QA: Nova impact=%s damaged=%d radius=%.1f shockwave=spawned"
				% [target_name, damaged_targets.size(), _splash_radius]
			)
		)
	Sfx.play_3d(&"explosion", impact_position)
	queue_free()


func _find_blast_surface(impact: Vector3, normal: Vector3) -> Dictionary:
	# The FBX bay has a decorative floor at y≈0.075 above the physics deck at
	# y=0. Lift the cue by 0.14 m so it cannot z-fight or disappear below the
	# imported panels. On a wall with no ground below, follow the hit normal.
	var down := PhysicsRayQueryParameters3D.create(
		impact + Vector3.UP * 0.3, impact - Vector3.UP * 4.5, 1
	)
	var floor_hit := get_world_3d().direct_space_state.intersect_ray(down)
	if not floor_hit.is_empty():
		var floor_normal: Vector3 = floor_hit.get("normal", Vector3.UP)
		if floor_normal.dot(Vector3.UP) > 0.7:
			var floor_position: Vector3 = floor_hit.get("position", impact)
			return {"position": floor_position + floor_normal * 0.14, "normal": floor_normal}
	var facing := normal.normalized() if normal.length_squared() > 0.01 else Vector3.UP
	return {"position": impact + facing * 0.14, "normal": facing}


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
