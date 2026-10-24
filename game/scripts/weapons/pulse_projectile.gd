class_name PulseProjectile
extends Node3D

const ImpactBurstScript = preload("res://scripts/weapons/impact_burst.gd")
const PulseAfterglowScript = preload("res://scripts/weapons/pulse_afterglow.gd")
# Thicker, shorter-than-target travel streak: the old 0.022 m core occupied
# only a few pixels in the real 390 px WebGL firing sequence. Never invent a
# beam past a hit or draw backwards through the hero at launch.
const MAX_TRAIL_LENGTH: float = 2.6

@export var collision_mask: int = 3

var _start_position: Vector3 = Vector3.ZERO
var _direction: Vector3 = Vector3.FORWARD
var _damage: float = 18.0
var _speed: float = 42.0
var _remaining_range: float = 45.0
var _shooter: CollisionObject3D


func launch(
	start_position: Vector3,
	aim_point: Vector3,
	shooter: CollisionObject3D,
	definition: WeaponDefinition
) -> void:
	collision_mask = definition.collision_mask
	global_position = start_position
	_start_position = start_position
	_direction = aim_point - start_position
	if _direction.length_squared() < 0.0001:
		_direction = -global_basis.z
	_direction = _direction.normalized()
	_shooter = shooter
	_damage = definition.damage
	_speed = definition.projectile_speed
	_remaining_range = definition.max_range
	look_at(global_position + _direction, Vector3.UP)
	# At the muzzle there is no travelled path. The previous 1.2 m starter
	# capsule drew backwards through the hero and read as a white tube.
	_stretch_tracer(0.0)


## The moving capsule covers only the path *already travelled* by the bolt,
## capped at 2.6 m to stay legible without drawing a beam through cover.
## Duplicate the mesh: a shared CapsuleMesh must not stretch other rounds.
func _stretch_tracer(length: float = 1.2) -> void:
	# The smoke fixture exercises the detached projectile before add_child().
	# Do not evaluate global_position on a Node3D outside the scene tree.
	var end_position: Vector3 = position
	if is_inside_tree():
		end_position = global_position
	length = PulseAfterglowScript.screen_limited_length(self, end_position, _direction, length)
	for part_name in ["Tracer", "TracerGlow"]:
		var part := get_node_or_null(part_name) as MeshInstance3D
		if part == null:
			continue
		part.visible = length >= 0.09
		if not part.has_meta("unique_trail_mesh"):
			part.mesh = part.mesh.duplicate(true) as Mesh
			part.set_meta("unique_trail_mesh", true)
		var capsule := part.mesh as CapsuleMesh
		if capsule == null:
			continue
		capsule.height = maxf(length, capsule.radius * 2.0 + 0.01)
		part.rotation.x = deg_to_rad(90.0)
		part.position = Vector3(0.0, 0.0, capsule.height * 0.5)


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
		global_position, next_position, collision_mask, excluded_rids
	)
	var hit := get_world_3d().direct_space_state.intersect_ray(query)
	if not hit.is_empty():
		var collider: Object = hit.get("collider")
		if collider != null and collider.has_method("apply_damage"):
			collider.call("apply_damage", _damage, _shooter)
		var hit_position: Vector3 = hit.get("position", next_position)
		global_position = hit_position
		# Spawn at the collision point, not the projectile origin. The muzzle
		# effect and impact must be driven by the *actual* fired round, never by
		# a cosmetic keyframe or a standalone smoke-test helper.
		ImpactBurstScript.spawn(
			get_parent(), hit_position, Color(0.28, 0.86, 1.0), hit.get("normal", Vector3.UP), true
		)
		PulseAfterglowScript.spawn(get_parent(), _start_position, hit_position)
		Sfx.play_3d(&"impact", hit_position)
		queue_free()
		return

	global_position = next_position
	_stretch_tracer(minf(_start_position.distance_to(next_position), MAX_TRAIL_LENGTH))
	_remaining_range -= step_distance
