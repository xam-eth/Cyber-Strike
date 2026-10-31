class_name GuardianEnemy
extends CharacterBody3D

## Armored frontline Guardian (`Iron Warden`).
##
## Tests existing player combat verbs rather than acting as a passive bullet
## sponge (docs/GAMEPLAY_DESIGN.md §12):
##   * FORTIFIED: advances behind a directional energy barrier that dampens
##     ordinary weapon fire (`fortified_damage_multiplier`) until broken by an
##     EMP Pulse (`apply_emp_disrupt`) or drained by firing its salvo.
##   * WINDUP: locks the player's current floor position with an explicit aim
##     sphere + blast ring for `salvo_windup` seconds so movement or cover
##     cleanly avoids the detonation.
##   * EXPOSED: enters a stationary core-overheat recovery window where the
##     barrier drops and incoming shots deal `exposed_damage_multiplier` (1.5x).

signal health_changed(current: float, maximum: float)
signal damage_received(amount: float, current: float, maximum: float)
signal phase_changed(phase: StringName)
signal shield_broken(by_emp: bool)
signal attack_resolved(hit_target: bool)
signal eliminated

enum Phase { FORTIFIED, WINDUP, EXPOSED }

@export var target_path: NodePath = ^"../Player"
@export_range(20.0, 600.0, 5.0) var max_health: float = 135.0
@export_range(0.8, 6.0, 0.05) var move_speed: float = 2.35
@export_range(1.0, 40.0, 0.5) var move_acceleration: float = 12.0
@export_range(2.0, 12.0, 0.5) var minimum_standoff: float = 4.0
@export_range(5.0, 24.0, 0.5) var preferred_range: float = 8.5
@export_range(8.0, 45.0, 1.0) var detection_range: float = 32.0
@export_range(6.0, 35.0, 1.0) var max_attack_range: float = 22.0
@export_range(1.2, 4.0, 0.1) var shock_push_range: float = 2.3
@export_range(2.0, 40.0, 0.5) var shock_damage: float = 11.0
@export_range(0.5, 4.0, 0.1) var shock_interval: float = 1.6
@export_range(4.0, 50.0, 0.5) var salvo_damage: float = 16.0
@export_range(0.3, 3.0, 0.05) var salvo_windup: float = 1.05
@export_range(1.0, 6.0, 0.1) var salvo_blast_radius: float = 2.4
@export_range(1.0, 8.0, 0.1) var salvo_cooldown: float = 3.2
@export_range(0.5, 6.0, 0.1) var recovery_duration: float = 2.6
@export_range(0.5, 8.0, 0.1) var emp_expose_duration: float = 3.2
@export_range(0.1, 1.0, 0.05) var fortified_damage_multiplier: float = 0.45
@export_range(1.0, 3.0, 0.05) var exposed_damage_multiplier: float = 1.5
@export_range(0.2, 2.0, 0.1) var cover_search_delay: float = 0.7
@export_range(1.0, 8.0, 0.1) var flank_turn_interval: float = 3.6
@export_flags_3d_physics var sight_collision_mask: int = 1
@export_flags_3d_physics var attack_collision_mask: int = 5

var current_health: float = 0.0
var _base_max_health: float = 135.0
var _target: Node3D
var _is_downed: bool = false
var _phase: Phase = Phase.FORTIFIED
var _salvo_cooldown_remaining: float = 1.0
var _shock_cooldown_remaining: float = 0.0
var _windup_remaining: float = 0.0
var _exposed_remaining: float = 0.0
var _locked_attack_point: Vector3 = Vector3.ZERO
var _locked_ground_y: float = 0.0
var _spawn_transform: Transform3D
var _cover_blocked_seconds: float = 0.0
var _flank_elapsed: float = 0.0
var _flank_sign: float = 1.0
var _pulse_clock: float = 0.0

@onready var collision_shape: CollisionShape3D = $CollisionShape3D
@onready var visuals: EnemyVisual = $Visuals
@onready var muzzle: Marker3D = $Visuals/Muzzle
@onready var core: MeshInstance3D = get_node_or_null("Visuals/CoreMesh") as MeshInstance3D
@onready var shield_mesh: MeshInstance3D = get_node_or_null("ShieldMesh") as MeshInstance3D
@onready var aim_marker: MeshInstance3D = $AimMarker
@onready var salvo_ring: MeshInstance3D = get_node_or_null("SalvoRing") as MeshInstance3D


func _ready() -> void:
	add_to_group("enemies")
	add_to_group("guardian_enemies")
	_spawn_transform = global_transform
	_base_max_health = max_health
	_flank_sign = 1.0 if get_instance_id() % 2 == 0 else -1.0
	_target = get_node_or_null(target_path) as Node3D
	current_health = max_health
	_salvo_cooldown_remaining = 0.9
	_sync_salvo_ring_scale()
	_set_phase(Phase.FORTIFIED, true)
	health_changed.emit(current_health, max_health)
	if _target == null:
		push_warning("GuardianEnemy could not find its target at '%s'." % target_path)


func _physics_process(delta: float) -> void:
	if _is_downed:
		return

	_pulse_clock = fmod(_pulse_clock + delta * 5.0, TAU)
	_salvo_cooldown_remaining = maxf(_salvo_cooldown_remaining - delta, 0.0)
	_shock_cooldown_remaining = maxf(_shock_cooldown_remaining - delta, 0.0)
	var desired_velocity := Vector3.ZERO

	if _phase == Phase.EXPOSED:
		_exposed_remaining = maxf(_exposed_remaining - delta, 0.0)
		if is_instance_valid(_target) and not _target_is_defeated():
			_face_target(_target.global_position)
		if _exposed_remaining <= 0.0:
			_salvo_cooldown_remaining = maxf(_salvo_cooldown_remaining, salvo_cooldown * 0.65)
			_set_phase(Phase.FORTIFIED)
	elif is_instance_valid(_target) and not _target_is_defeated():
		desired_velocity = _step_active_combat(delta)
	else:
		_cancel_salvo()
		_reset_cover_search()

	if _phase != Phase.FORTIFIED:
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
	_update_phase_visuals(delta)


func _step_active_combat(delta: float) -> Vector3:
	var offset := _target.global_position - global_position
	offset.y = 0.0
	var distance := offset.length()
	if distance <= 0.001:
		return Vector3.ZERO
	var direction := offset / distance
	_face_target(_target.global_position)

	if _phase == Phase.WINDUP:
		return _step_windup_combat(distance, delta)
	if distance > detection_range:
		_reset_cover_search()
		return Vector3.ZERO
	if not _has_line_of_sight():
		return _search_around_cover(direction, distance, delta)

	_reset_cover_search()
	if distance <= shock_push_range and _shock_cooldown_remaining <= 0.0:
		_resolve_close_shock()
	var desired := Vector3.ZERO
	if (
		distance <= max_attack_range
		and distance >= minimum_standoff * 0.75
		and _salvo_cooldown_remaining <= 0.0
	):
		_begin_salvo_windup()
	elif distance > preferred_range + 1.2:
		desired = direction * move_speed
	elif distance < minimum_standoff:
		desired = -direction * (move_speed * 0.65)
	return desired


func _step_windup_combat(distance: float, delta: float) -> Vector3:
	if distance > max_attack_range * 1.25:
		_cancel_salvo()
		_set_phase(Phase.FORTIFIED)
		return Vector3.ZERO
	_windup_remaining = maxf(_windup_remaining - delta, 0.0)
	_refresh_locked_markers()
	if _windup_remaining <= 0.0:
		_resolve_salvo()
	return Vector3.ZERO


func _face_target(world_target: Vector3) -> void:
	var offset := world_target - global_position
	offset.y = 0.0
	if offset.length_squared() > 0.0001:
		var dir := offset.normalized()
		rotation.y = atan2(-dir.x, -dir.z)


func _search_around_cover(direction: Vector3, distance: float, delta: float) -> Vector3:
	_cover_blocked_seconds += delta
	if _cover_blocked_seconds < cover_search_delay:
		if distance > preferred_range + 1.2:
			return direction * move_speed
		return Vector3.ZERO
	_flank_elapsed += delta
	if _flank_elapsed >= flank_turn_interval:
		_flank_elapsed = 0.0
		_flank_sign *= -1.0
	var sideways := Vector3(-direction.z, 0.0, direction.x) * _flank_sign
	var approach := 0.45 if distance > preferred_range else 0.0
	return (sideways + direction * approach).normalized() * move_speed


func _reset_cover_search() -> void:
	_cover_blocked_seconds = 0.0
	_flank_elapsed = 0.0


func _begin_salvo_windup() -> void:
	_windup_remaining = salvo_windup
	_salvo_cooldown_remaining = salvo_cooldown
	_locked_ground_y = _target.global_position.y
	_locked_attack_point = _target.global_position + Vector3.UP * 0.9
	_set_phase(Phase.WINDUP)
	_refresh_locked_markers()
	aim_marker.visible = true
	if is_instance_valid(salvo_ring):
		salvo_ring.visible = true


func _refresh_locked_markers() -> void:
	if is_instance_valid(aim_marker):
		aim_marker.global_position = _locked_attack_point + Vector3.UP * 0.75
	if is_instance_valid(salvo_ring):
		salvo_ring.global_position = Vector3(
			_locked_attack_point.x, _locked_ground_y + 0.04, _locked_attack_point.z
		)
		salvo_ring.global_rotation = Vector3.ZERO


func _resolve_salvo() -> void:
	var hit_target := false
	if is_instance_valid(_target) and not _target_is_defeated():
		var flat_offset := Vector2(
			_target.global_position.x - _locked_attack_point.x,
			_target.global_position.z - _locked_attack_point.z
		)
		if flat_offset.length() <= salvo_blast_radius and _has_attack_clearance_to_target():
			if _target.has_method("apply_damage"):
				if (
					not _target.has_method("can_take_damage")
					or bool(_target.call("can_take_damage"))
				):
					_target.call("apply_damage", salvo_damage, self)
					hit_target = true
	attack_resolved.emit(hit_target)
	_cancel_salvo()
	_exposed_remaining = recovery_duration
	_set_phase(Phase.EXPOSED)


func _resolve_close_shock() -> void:
	_shock_cooldown_remaining = shock_interval
	if not is_instance_valid(_target) or _target_is_defeated():
		return
	if _target.has_method("apply_damage"):
		if not _target.has_method("can_take_damage") or bool(_target.call("can_take_damage")):
			_target.call("apply_damage", shock_damage, self)
			attack_resolved.emit(true)


func _has_attack_clearance_to_target() -> bool:
	var excluded_rids: Array[RID] = [get_rid()]
	var target_chest := _target.global_position + Vector3.UP * 0.9
	var query := PhysicsRayQueryParameters3D.create(
		muzzle.global_position, target_chest, attack_collision_mask, excluded_rids
	)
	var hit := get_world_3d().direct_space_state.intersect_ray(query)
	if hit.is_empty():
		return true
	return hit.get("collider") == _target


func _has_line_of_sight() -> bool:
	if not is_instance_valid(_target):
		return false
	var destination := _target.global_position + Vector3.UP * 0.9
	var excluded_rids: Array[RID] = [get_rid()]
	var query := PhysicsRayQueryParameters3D.create(
		muzzle.global_position, destination, sight_collision_mask, excluded_rids
	)
	return get_world_3d().direct_space_state.intersect_ray(query).is_empty()


func _cancel_salvo() -> void:
	_windup_remaining = 0.0
	if is_instance_valid(aim_marker):
		aim_marker.visible = false
	if is_instance_valid(salvo_ring):
		salvo_ring.visible = false


## EMP Pulse counterplay: shatters the frontal barrier, aborts any active salvo
## lock, and opens the full core punish window immediately.
func apply_emp_disrupt(_source: Node = null) -> void:
	if _is_downed:
		return
	var was_shielded := _phase != Phase.EXPOSED
	_cancel_salvo()
	_exposed_remaining = maxf(_exposed_remaining, emp_expose_duration)
	_salvo_cooldown_remaining = maxf(_salvo_cooldown_remaining, salvo_cooldown * 0.5)
	_set_phase(Phase.EXPOSED)
	if was_shielded:
		shield_broken.emit(true)


func apply_damage(amount: float, _source: Node = null) -> void:
	if _is_downed or amount <= 0.0:
		return

	var multiplier := 1.0
	if _phase == Phase.FORTIFIED:
		multiplier = fortified_damage_multiplier
	elif _phase == Phase.EXPOSED:
		multiplier = exposed_damage_multiplier
	var scaled_amount := amount * multiplier
	var applied_damage := minf(scaled_amount, current_health)
	current_health = maxf(current_health - applied_damage, 0.0)
	damage_received.emit(applied_damage, current_health, max_health)
	health_changed.emit(current_health, max_health)
	if current_health <= 0.0:
		_is_downed = true
		velocity = Vector3.ZERO
		_cancel_salvo()
		if is_instance_valid(shield_mesh):
			shield_mesh.visible = false
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


func is_winding_up() -> bool:
	return _phase == Phase.WINDUP and _windup_remaining > 0.0


func is_shielded() -> bool:
	return not _is_downed and _phase == Phase.FORTIFIED


func is_exposed() -> bool:
	return not _is_downed and _phase == Phase.EXPOSED


func get_phase_id() -> StringName:
	match _phase:
		Phase.WINDUP:
			return &"windup"
		Phase.EXPOSED:
			return &"exposed"
	return &"fortified"


func reset_guardian() -> void:
	_is_downed = false
	_salvo_cooldown_remaining = 0.9
	_shock_cooldown_remaining = 0.0
	_windup_remaining = 0.0
	_exposed_remaining = 0.0
	_reset_cover_search()
	max_health = _base_max_health
	current_health = max_health
	velocity = Vector3.ZERO
	global_transform = _spawn_transform
	visuals.reset_visual()
	_cancel_salvo()
	_set_phase(Phase.FORTIFIED, true)
	collision_shape.set_deferred("disabled", false)
	set_deferred("collision_layer", 2)
	health_changed.emit(current_health, max_health)


func _set_phase(next_phase: Phase, force_emit: bool = false) -> void:
	if _phase == next_phase and not force_emit:
		return
	_phase = next_phase
	if is_instance_valid(shield_mesh):
		shield_mesh.visible = not _is_downed and _phase == Phase.FORTIFIED
	_update_core_color()
	phase_changed.emit(get_phase_id())


func _update_core_color() -> void:
	if not is_instance_valid(core):
		return
	var mat := core.material_override as StandardMaterial3D
	if mat == null:
		return
	match _phase:
		Phase.FORTIFIED:
			mat.albedo_color = Color(0.14, 0.86, 1.0, 1.0)
			mat.emission = Color(0.06, 0.68, 0.96, 1.0)
		Phase.WINDUP:
			mat.albedo_color = Color(1.0, 0.72, 0.14, 1.0)
			mat.emission = Color(1.0, 0.52, 0.06, 1.0)
		Phase.EXPOSED:
			mat.albedo_color = Color(1.0, 0.24, 0.12, 1.0)
			mat.emission = Color(1.0, 0.18, 0.05, 1.0)


func _update_phase_visuals(delta: float) -> void:
	if is_instance_valid(core):
		var target_scale := Vector3.ONE
		if _phase == Phase.WINDUP:
			var charge := 1.0 - clampf(_windup_remaining / maxf(salvo_windup, 0.001), 0.0, 1.0)
			target_scale = Vector3.ONE * (1.1 + 0.65 * charge)
		elif _phase == Phase.EXPOSED:
			target_scale = Vector3.ONE * (1.35 + 0.18 * sin(_pulse_clock * 2.0))
		core.scale = core.scale.lerp(target_scale, minf(delta * 14.0, 1.0))
	if is_instance_valid(shield_mesh) and shield_mesh.visible:
		var pulse := 1.0 + 0.03 * sin(_pulse_clock)
		shield_mesh.scale = Vector3(pulse, pulse, 1.0)


func _sync_salvo_ring_scale() -> void:
	if not is_instance_valid(salvo_ring):
		return
	var cyl := salvo_ring.mesh as CylinderMesh
	if cyl != null:
		cyl.top_radius = salvo_blast_radius
		cyl.bottom_radius = salvo_blast_radius


func _target_is_defeated() -> bool:
	return _target.has_method("can_take_damage") and not bool(_target.call("can_take_damage"))
