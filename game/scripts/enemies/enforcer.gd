class_name EnforcerEnemy
extends CharacterBody3D

## Tier-3 Epic Armored Robot Enforcer (`enemy_robot_tier_3_epic.glb`).
##
## Bridges ranged Marksmen and the heavy Iron Warden boss: advances with
## tactical lateral strafing, carries hardened armor (`0.82x` incoming weapon
## damage unless disrupted by EMP into `1.25x` vulnerability), and fires a
## telegraphed 3-round suppressive burst that rewards cover usage in Aetherfall.

signal health_changed(current: float, maximum: float)
signal damage_received(amount: float, current: float, maximum: float)
signal eliminated
signal attack_resolved(hit_target: bool)

@export var target_path: NodePath = ^"../Player"
@export_range(10.0, 400.0, 1.0) var max_health: float = 84.0
@export_range(1.0, 8.0, 0.1) var move_speed: float = 3.25
@export_range(1.0, 40.0, 0.5) var move_acceleration: float = 15.0
@export_range(2.0, 12.0, 0.5) var minimum_standoff: float = 5.0
@export_range(5.0, 28.0, 0.5) var preferred_range: float = 10.5
@export_range(8.0, 45.0, 1.0) var detection_range: float = 32.0
@export_range(6.0, 40.0, 1.0) var max_attack_range: float = 22.0
@export_range(1.0, 30.0, 0.5) var shot_damage: float = 6.0
@export_range(1, 5, 1) var burst_shots: int = 3
@export_range(0.08, 0.6, 0.02) var burst_interval: float = 0.18
@export_range(0.15, 2.5, 0.05) var attack_windup: float = 0.55
@export_range(0.8, 6.0, 0.1) var attack_cooldown_seconds: float = 2.1
@export_range(0.4, 1.0, 0.02) var armored_damage_multiplier: float = 0.82
@export_range(1.0, 2.0, 0.05) var disrupted_damage_multiplier: float = 1.25
@export_range(0.5, 6.0, 0.1) var emp_disrupt_seconds: float = 3.0
@export_flags_3d_physics var sight_collision_mask: int = 1
@export_flags_3d_physics var attack_collision_mask: int = 5

var current_health: float = 0.0
var _base_max_health: float = 84.0
var _target: Node3D
var _is_downed: bool = false
var _cooldown: float = 0.6
var _windup: float = 0.0
var _burst_remaining: int = 0
var _burst_timer: float = 0.0
var _disrupted_remaining: float = 0.0
var _locked_point: Vector3 = Vector3.ZERO
var _strafe_sign: float = 1.0
var _strafe_clock: float = 0.0
var _spawn_transform: Transform3D

@onready var collision_shape: CollisionShape3D = $CollisionShape3D
@onready var visuals: EnemyVisual = $Visuals
@onready var muzzle: Marker3D = $Visuals/Muzzle
@onready var aim_marker: MeshInstance3D = $AimMarker


func _ready() -> void:
	add_to_group("enemies")
	add_to_group("enforcer_enemies")
	_spawn_transform = global_transform
	_base_max_health = max_health
	_strafe_sign = 1.0 if get_instance_id() % 2 == 0 else -1.0
	_target = get_node_or_null(target_path) as Node3D
	current_health = max_health
	health_changed.emit(current_health, max_health)


func _physics_process(delta: float) -> void:
	if _is_downed:
		return
	_cooldown = maxf(_cooldown - delta, 0.0)
	_disrupted_remaining = maxf(_disrupted_remaining - delta, 0.0)
	_strafe_clock += delta
	if _strafe_clock >= 2.8:
		_strafe_clock = 0.0
		_strafe_sign *= -1.0

	var desired_velocity := Vector3.ZERO
	if is_instance_valid(_target) and not _target_is_defeated():
		var offset := _target.global_position - global_position
		offset.y = 0.0
		var distance := offset.length()
		if distance > 0.001:
			var direction := offset / distance
			rotation.y = atan2(-direction.x, -direction.z)
			var sideways := Vector3(-direction.z, 0.0, direction.x) * _strafe_sign
			if distance <= detection_range:
				var has_los := _has_line_of_sight()
				visuals.set_aiming(has_los and distance <= max_attack_range)
				if _burst_remaining > 0:
					desired_velocity = sideways * (move_speed * 0.45)
					_tick_burst(delta)
				elif _windup > 0.0:
					desired_velocity = sideways * (move_speed * 0.35)
					_windup = maxf(_windup - delta, 0.0)
					if _windup <= 0.0:
						_start_burst()
				elif not has_los:
					desired_velocity = (
						(direction * 0.55 + sideways * 0.85).normalized() * move_speed
					)
				elif distance > preferred_range + 1.5:
					desired_velocity = (
						(direction * 0.85 + sideways * 0.35).normalized() * move_speed
					)
				elif distance < minimum_standoff:
					desired_velocity = (
						(-direction * 0.75 + sideways * 0.45).normalized() * move_speed
					)
				else:
					desired_velocity = sideways * (move_speed * 0.62)
					if _cooldown <= 0.0 and distance <= max_attack_range:
						_begin_windup()
			else:
				_cancel_burst()
	else:
		_cancel_burst()

	var horizontal := Vector3(velocity.x, 0.0, velocity.z).move_toward(
		desired_velocity, move_acceleration * delta
	)
	velocity.x = horizontal.x
	velocity.z = horizontal.z
	if not is_on_floor():
		velocity.y -= float(ProjectSettings.get_setting("physics/3d/default_gravity")) * delta
	else:
		velocity.y = 0.0
	move_and_slide()
	visuals.update_motion(velocity, delta)


func apply_emp_disrupt(_source: Node = null) -> bool:
	if _is_downed:
		return false
	_disrupted_remaining = emp_disrupt_seconds
	_cancel_burst()
	_cooldown = maxf(_cooldown, 1.0)
	return true


func apply_damage(amount: float, _source: Node = null) -> void:
	if _is_downed or amount <= 0.0:
		return
	var mult := (
		disrupted_damage_multiplier if _disrupted_remaining > 0.0 else armored_damage_multiplier
	)
	var applied := minf(amount * mult, current_health)
	current_health = maxf(current_health - applied, 0.0)
	damage_received.emit(applied, current_health, max_health)
	health_changed.emit(current_health, max_health)
	if current_health <= 0.0:
		_is_downed = true
		velocity = Vector3.ZERO
		_cancel_burst()
		eliminated.emit()
		Sfx.play_3d(&"enemy_down", global_position)
		visuals.play_death()
		collision_shape.set_deferred("disabled", true)
		set_deferred("collision_layer", 0)
	else:
		visuals.play_hit_flash()


func scale_max_health(multiplier: float) -> void:
	var clamped := clampf(multiplier, 0.5, 3.0)
	max_health = roundf(_base_max_health * clamped)
	if not _is_downed:
		current_health = max_health
		health_changed.emit(current_health, max_health)


func is_defeated() -> bool:
	return _is_downed


func reset_enforcer() -> void:
	_is_downed = false
	_cooldown = 0.6
	_disrupted_remaining = 0.0
	_cancel_burst()
	max_health = _base_max_health
	current_health = max_health
	velocity = Vector3.ZERO
	global_transform = _spawn_transform
	visuals.reset_visual()
	collision_shape.set_deferred("disabled", false)
	set_deferred("collision_layer", 2)
	health_changed.emit(current_health, max_health)


func _begin_windup() -> void:
	_windup = attack_windup
	_locked_point = _target.global_position + Vector3.UP * 1.0
	if is_instance_valid(aim_marker):
		aim_marker.global_position = _locked_point
		aim_marker.visible = true


func _start_burst() -> void:
	_burst_remaining = burst_shots
	_burst_timer = 0.0
	_fire_burst_round()


func _tick_burst(delta: float) -> void:
	_burst_timer = maxf(_burst_timer - delta, 0.0)
	if _burst_timer <= 0.0 and _burst_remaining > 0:
		if is_instance_valid(_target) and not _target_is_defeated():
			_locked_point = _locked_point.lerp(_target.global_position + Vector3.UP * 1.0, 0.55)
			if is_instance_valid(aim_marker):
				aim_marker.global_position = _locked_point
		_fire_burst_round()


func _fire_burst_round() -> void:
	_burst_remaining -= 1
	_burst_timer = burst_interval
	visuals.play_attack()
	Sfx.play_3d_variants(&"enemy_shot", muzzle.global_position)
	var origin := muzzle.global_position
	var shot_dir := (_locked_point - origin).normalized()
	if shot_dir.length_squared() < 0.001:
		shot_dir = -global_basis.z
	var destination := origin + shot_dir * max_attack_range
	var excluded: Array[RID] = [get_rid()]
	var query := PhysicsRayQueryParameters3D.create(
		origin, destination, attack_collision_mask, excluded
	)
	var hit := get_world_3d().direct_space_state.intersect_ray(query)
	var hit_player := false
	var end_point := destination
	if not hit.is_empty():
		end_point = hit["position"]
		var collider := hit.get("collider") as Node
		if collider == _target and _target.has_method("apply_damage"):
			_target.call("apply_damage", shot_damage, self)
			hit_player = true
	_spawn_tracer(origin, end_point)
	attack_resolved.emit(hit_player)
	if _burst_remaining <= 0:
		_cooldown = attack_cooldown_seconds
		if is_instance_valid(aim_marker):
			aim_marker.visible = false


func _cancel_burst() -> void:
	_windup = 0.0
	_burst_remaining = 0
	_burst_timer = 0.0
	visuals.set_aiming(false)
	if is_instance_valid(aim_marker):
		aim_marker.visible = false


func _spawn_tracer(origin: Vector3, destination: Vector3) -> void:
	var span := destination - origin
	var dist := span.length()
	if dist <= 0.05 or get_parent() == null:
		return
	var beam := MeshInstance3D.new()
	var cyl := CylinderMesh.new()
	cyl.top_radius = 0.032
	cyl.bottom_radius = 0.032
	cyl.height = dist
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.albedo_color = Color(1.0, 0.34, 0.14, 0.92)
	cyl.material = mat
	beam.mesh = cyl
	get_parent().add_child(beam)
	beam.global_position = origin + span * 0.5
	var up := span / dist
	var ref := Vector3.FORWARD if absf(up.dot(Vector3.UP)) > 0.98 else Vector3.UP
	var x_axis := ref.cross(up).normalized()
	var z_axis := x_axis.cross(up).normalized()
	beam.global_basis = Basis(x_axis, up, z_axis)
	var tw := beam.create_tween()
	tw.tween_interval(0.09)
	tw.tween_callback(beam.queue_free)


func _target_is_defeated() -> bool:
	return _target.has_method("can_take_damage") and not bool(_target.call("can_take_damage"))


func _has_line_of_sight() -> bool:
	if not is_instance_valid(_target):
		return false
	var origin := global_position + Vector3.UP * 1.25
	var destination := _target.global_position + Vector3.UP * 1.1
	var excluded: Array[RID] = [get_rid()]
	var query := PhysicsRayQueryParameters3D.create(
		origin, destination, sight_collision_mask, excluded
	)
	return get_world_3d().direct_space_state.intersect_ray(query).is_empty()
