extends Node

signal wave_started(wave_index: int, enemy_count: int)
signal wave_completed(wave_index: int)
signal progress_changed
signal enemy_spawned(enemy: Node3D)
signal guardian_spawned(guardian: Node3D, wave_index: int)
signal enemy_defeated(enemy: Node3D)
signal session_ended(wave_index: int, total_defeated: int)
signal spawn_blocked(reason: String)
signal guard_group_cleared(group_id: StringName)
signal guard_group_spawn_failed(group_id: StringName, reason: String)

enum WaveState { IDLE, SPAWNING, INTERMISSION, GAME_OVER, BLOCKED }

const EnemyDefinitionScript = preload("res://scripts/enemies/enemy_definition.gd")

@export var player_path: NodePath = ^"../Player"
@export var enemy_definitions: Array[EnemyDefinition] = []
@export var enemy_container_path: NodePath = ^"../WaveEnemies"
@export var spawn_points_path: NodePath = ^"../SpawnPoints"
@export var enemy_target_path: NodePath = ^"../../Player"
@export_range(1, 8, 1) var base_enemies_per_wave: int = 2
@export_range(0, 4, 1) var enemies_added_per_wave: int = 1
@export_range(1, 12, 1) var max_enemies_per_wave: int = 8
@export_range(2, 12, 1) var shooter_first_wave: int = 2
@export_range(1, 6, 1) var shooter_every_n_waves: int = 2
@export_range(1, 6, 1) var max_shooters_per_wave: int = 3
@export_range(2, 12, 1) var guardian_first_wave: int = 3
@export_range(1, 8, 1) var guardian_every_n_waves: int = 3
@export_range(0, 3, 1) var max_guardians_per_wave: int = 2
@export_range(3, 12, 1) var endless_escalation_wave: int = 4
@export_range(1.0, 2.0, 0.05) var endless_max_health_scale: float = 1.35
@export_range(0.0, 0.2, 0.01) var endless_health_step: float = 0.07
@export_range(1, 6, 1) var max_active_enemies: int = 3
@export_range(0.0, 4.0, 0.05) var initial_spawn_delay: float = 0.75
@export_range(0.0, 4.0, 0.05) var spawn_interval: float = 0.8
@export_range(0.05, 2.0, 0.05) var spawn_retry_delay: float = 0.35
@export_range(1, 12, 1) var max_spawn_retries: int = 6
@export_range(0.25, 10.0, 0.25) var intermission_duration: float = 3.0
@export_range(1.0, 15.0, 0.5) var minimum_spawn_distance: float = 7.5
@export var arena_half_extents: Vector2 = Vector2(15.0, 15.0)
@export var arena_center: Vector2 = Vector2.ZERO
@export_range(0.5, 3.0, 0.1) var spawn_edge_margin: float = 1.25
@export_range(0.1, 1.0, 0.05) var spawn_clearance_radius: float = 0.36
@export_range(0.4, 1.5, 0.05) var spawn_clearance_height: float = 0.9
@export_flags_3d_physics var spawn_collision_mask: int = 3
@export_range(0.5, 1.0, 0.01) var camera_front_dot_threshold: float = 0.92
@export var intro_front_spawn: bool = true

var state: WaveState = WaveState.IDLE
var current_wave: int = 0
var current_wave_enemy_count: int = 0
var current_wave_shooter_count: int = 0
var current_wave_guardian_count: int = 0
var endless_mode: bool = false
var session_defeated_count: int = 0
var enemies_defeated_this_wave: int = 0
var enemies_spawned_this_wave: int = 0

var active_enemy_count: int:
	get:
		return _active_enemies.size()

var active_guard_count: int:
	get:
		var count := 0
		for members in _guard_groups.values():
			count += (members as Array).size()
		return count

var session_running: bool:
	get:
		return _session_running

var enemies_remaining: int:
	get:
		return maxi(current_wave_enemy_count - enemies_defeated_this_wave, 0)

var _player: Node3D
var _player_camera: Camera3D
var _enemy_container: Node3D
var _spawn_points_root: Node3D
var _active_enemies: Array[Node3D] = []
## Explicit Recovery encounters live outside wave counts but share spawning,
## damage signals, hostile indicators, and cleanup with this director.
var _guard_groups: Dictionary = {}
var _guard_enemy_groups: Dictionary = {}
var _spawn_clearance_shape: SphereShape3D
var _rng := RandomNumberGenerator.new()
var _session_running: bool = false
var _spawn_timer: float = 0.0
var _intermission_timer: float = 0.0
var _failed_spawn_attempts: int = 0
var _last_spawn_marker: Marker3D
## Opt-in, read-only browser targeting evidence. It lets the real-input Recovery
## probe correct aim from rendered camera geometry instead of guessed mouse
## timings; it has no gameplay authority and is silent in ordinary play.
var _recovery_target_qa_enabled: bool = false
var _recovery_target_qa_remaining: float = 0.0


func _ready() -> void:
	if enemy_definitions.is_empty():
		enemy_definitions = EnemyDefinitionScript.load_all_definitions()
	_player = get_node_or_null(player_path) as Node3D
	_enemy_container = get_node_or_null(enemy_container_path) as Node3D
	_spawn_points_root = get_node_or_null(spawn_points_path) as Node3D
	if is_instance_valid(_player):
		_player_camera = (
			_player.get_node_or_null("CameraRig/YawPivot/PitchPivot/SpringArm3D/Camera3D")
			as Camera3D
		)
	_spawn_clearance_shape = SphereShape3D.new()
	_spawn_clearance_shape.radius = spawn_clearance_radius
	_rng.randomize()
	if OS.has_feature("web"):
		_recovery_target_qa_enabled = bool(
			JavaScriptBridge.eval("new URLSearchParams(location.search).has('qa_recovery')")
		)
	_emit_progress()


func _process(delta: float) -> void:
	if (
		not _recovery_target_qa_enabled
		or active_guard_count == 0
		or not is_instance_valid(_player_camera)
	):
		return
	_recovery_target_qa_remaining = maxf(_recovery_target_qa_remaining - delta, 0.0)
	if _recovery_target_qa_remaining > 0.0:
		return
	_recovery_target_qa_remaining = 0.2
	for members in _guard_groups.values():
		for enemy in members as Array:
			if not is_instance_valid(enemy):
				continue
			var target: Vector3 = enemy.global_position + Vector3.UP
			var screen := _player_camera.unproject_position(target)
			var vp_size := _player_camera.get_viewport().get_visible_rect().size
			var dist := _player.global_position.distance_to(enemy.global_position)
			print(
				(
					"Recovery Target QA: id=%s x=%.2f y=%.2f behind=%s dist=%.1f vp=%.0fx%.0f"
					% [
						enemy.name,
						screen.x,
						screen.y,
						"yes" if _player_camera.is_position_behind(target) else "no",
						dist,
						vp_size.x,
						vp_size.y,
					]
				)
			)


func _physics_process(delta: float) -> void:
	if not _session_running:
		return

	if state == WaveState.INTERMISSION:
		var previous_countdown := ceili(_intermission_timer)
		_intermission_timer = maxf(_intermission_timer - delta, 0.0)
		if _intermission_timer <= 0.0:
			_start_next_wave()
		elif ceili(_intermission_timer) != previous_countdown:
			_emit_progress()
		return

	if state != WaveState.SPAWNING or enemies_spawned_this_wave >= current_wave_enemy_count:
		return

	_spawn_timer = maxf(_spawn_timer - delta, 0.0)
	if active_enemy_count >= get_effective_max_active_enemies() or _spawn_timer > 0.0:
		return
	_attempt_spawn_enemy()


func set_endless_mode(enabled: bool) -> void:
	if endless_mode == enabled:
		return
	endless_mode = enabled
	_emit_progress()


func start_session() -> void:
	if _session_running:
		return
	if not _dependencies_are_valid():
		_block_session("Wave Director is missing the player, enemy container, or spawn points.")
		return

	_clear_active_enemies()
	_session_running = true
	current_wave = 0
	current_wave_enemy_count = 0
	current_wave_shooter_count = 0
	current_wave_guardian_count = 0
	session_defeated_count = 0
	enemies_defeated_this_wave = 0
	enemies_spawned_this_wave = 0
	_last_spawn_marker = null
	_start_next_wave()


func reset_session() -> void:
	_session_running = false
	endless_mode = false
	_spawn_timer = 0.0
	_intermission_timer = 0.0
	_failed_spawn_attempts = 0
	_last_spawn_marker = null
	_clear_active_enemies()
	_clear_guard_groups()
	state = WaveState.IDLE
	current_wave = 0
	current_wave_enemy_count = 0
	current_wave_shooter_count = 0
	current_wave_guardian_count = 0
	session_defeated_count = 0
	enemies_defeated_this_wave = 0
	enemies_spawned_this_wave = 0
	_emit_progress()


func end_session() -> void:
	if state == WaveState.GAME_OVER:
		return
	_session_running = false
	_spawn_timer = 0.0
	_intermission_timer = 0.0
	# Don't leave live AI attacking the player behind the Results panel when a
	# run is finished voluntarily (or after a defeat).
	_clear_active_enemies()
	_clear_guard_groups()
	state = WaveState.GAME_OVER
	session_ended.emit(current_wave, session_defeated_count)
	_emit_progress()


## Hostile indicators and tests receive every live combatant. Wave counters
## still read active_enemy_count, which deliberately excludes Recovery guards.
func get_active_enemies() -> Array[Node3D]:
	var enemies: Array[Node3D] = _active_enemies.duplicate()
	for members in _guard_groups.values():
		for enemy in members as Array:
			if is_instance_valid(enemy):
				enemies.append(enemy as Node3D)
	return enemies


func get_guard_group(group_id: StringName) -> Array[Node3D]:
	var members: Array[Node3D] = []
	for enemy in _guard_groups.get(group_id, []) as Array:
		if is_instance_valid(enemy):
			members.append(enemy as Node3D)
	return members


func guard_group_size(group_id: StringName) -> int:
	return get_guard_group(group_id).size()


func get_active_guardian() -> Node3D:
	for enemy in get_active_enemies():
		if not is_instance_valid(enemy) or not enemy.is_in_group("guardian_enemies"):
			continue
		if enemy.has_method("is_defeated") and bool(enemy.call("is_defeated")):
			continue
		return enemy
	return null


func get_effective_max_active_enemies() -> int:
	if endless_mode and current_wave >= endless_escalation_wave and max_active_enemies >= 3:
		return mini(max_active_enemies + 1, 5)
	return max_active_enemies


func get_enemy_count_for_wave(wave_index: int) -> int:
	if wave_index < 1:
		return 0
	var cap := max_enemies_per_wave
	if endless_mode and wave_index >= endless_escalation_wave:
		cap += 2
	return mini(base_enemies_per_wave + (wave_index - 1) * enemies_added_per_wave, cap)


func get_guardian_count_for_wave(wave_index: int, enemy_count: int) -> int:
	if max_guardians_per_wave <= 0 or wave_index < guardian_first_wave or enemy_count < 2:
		return 0
	if (wave_index - guardian_first_wave) % guardian_every_n_waves != 0:
		return 0
	if _get_enemy_definition(&"guardian") == null and not enemy_definitions.is_empty():
		return 0
	var milestone_step := floori(
		float(wave_index - guardian_first_wave) / float(guardian_every_n_waves)
	)
	var desired := 2 if (milestone_step >= 2 and enemy_count >= 6) else 1
	return mini(mini(desired, max_guardians_per_wave), maxi(enemy_count - 2, 1))


func is_guardian_wave(wave_index: int) -> bool:
	return get_guardian_count_for_wave(wave_index, get_enemy_count_for_wave(wave_index)) > 0


func get_health_scale_for_wave(wave_index: int) -> float:
	if wave_index < 6:
		return 1.0
	return minf(1.0 + float(wave_index - 5) * endless_health_step, endless_max_health_scale)


func get_shooter_count_for_wave(wave_index: int, enemy_count: int) -> int:
	if wave_index < shooter_first_wave or enemy_count <= 1:
		return 0
	var waves_since_first := wave_index - shooter_first_wave
	var scheduled_count := 1 + floori(float(waves_since_first) / float(shooter_every_n_waves))
	var shooter_cap := max_shooters_per_wave + (1 if endless_mode and wave_index >= 5 else 0)
	var reserved := 1 + get_guardian_count_for_wave(wave_index, enemy_count)
	return maxi(mini(mini(scheduled_count, shooter_cap), enemy_count - reserved), 0)


func get_state_label() -> String:
	match state:
		WaveState.IDLE:
			return "READY"
		WaveState.SPAWNING:
			return "ACTIVE %d/%d" % [active_enemy_count, get_effective_max_active_enemies()]
		WaveState.INTERMISSION:
			return "WAVE %d CLEAR · NEXT IN %d" % [current_wave, ceili(_intermission_timer)]
		WaveState.GAME_OVER:
			return "SESSION OVER · WAVE %d" % current_wave
		WaveState.BLOCKED:
			return "SPAWN BLOCKED · PRESS R TO RESET"
	return "UNKNOWN"


func _dependencies_are_valid() -> bool:
	return (
		is_instance_valid(_player)
		and is_instance_valid(_enemy_container)
		and is_instance_valid(_spawn_points_root)
		and _spawn_clearance_shape != null
	)


func _start_next_wave() -> void:
	if not _session_running:
		return
	if (
		not is_instance_valid(_player)
		or _player.has_method("is_defeated") and _player.call("is_defeated")
	):
		end_session()
		return

	current_wave += 1
	current_wave_enemy_count = get_enemy_count_for_wave(current_wave)
	current_wave_guardian_count = get_guardian_count_for_wave(
		current_wave, current_wave_enemy_count
	)
	current_wave_shooter_count = get_shooter_count_for_wave(current_wave, current_wave_enemy_count)
	enemies_defeated_this_wave = 0
	enemies_spawned_this_wave = 0
	_failed_spawn_attempts = 0
	_spawn_timer = initial_spawn_delay if current_wave == 1 else 0.0
	_intermission_timer = 0.0
	state = WaveState.SPAWNING
	wave_started.emit(current_wave, current_wave_enemy_count)
	_emit_progress()


func _get_enemy_definition(enemy_id: StringName) -> EnemyDefinition:
	for definition in enemy_definitions:
		if definition != null and definition.enemy_id == enemy_id:
			return definition
	return null


## Spawn one explicitly requested Recovery group. No wave counter, intermission,
## or session-running flag is changed, so the same API works before and during
## Endless. Validation is transactional: a bad entry spawns no partial patrol.
func spawn_guard_group(group_id: StringName, spawns: Array[Dictionary]) -> bool:
	if group_id == &"" or spawns.is_empty() or _guard_groups.has(group_id):
		return _fail_guard_spawn(group_id, "Guard group is empty or already active.")
	if not _dependencies_are_valid():
		return _fail_guard_spawn(group_id, "Guard dependencies are not ready.")
	var validated: Array[Dictionary] = []
	for spawn in spawns:
		var enemy_id := StringName(str(spawn.get("enemy_id", "")))
		var definition := _get_enemy_definition(enemy_id)
		var raw_position: Variant = spawn.get("position")
		if (
			definition == null
			or not definition.is_valid_definition()
			or not raw_position is Vector3
		):
			return _fail_guard_spawn(group_id, "Guard content is missing or invalid.")
		var position := raw_position as Vector3
		var player_offset := position - _player.global_position
		player_offset.y = 0.0
		if player_offset.length() < 2.0 or not is_spawn_position_valid(position, false):
			return _fail_guard_spawn(group_id, "A guard position is blocked; reposition and retry.")
		validated.append({"definition": definition, "position": position})

	var members: Array[Node3D] = []
	for entry in validated:
		var definition := entry["definition"] as EnemyDefinition
		var enemy := _spawn_enemy(
			definition, "Guard_%s_%02d" % [group_id, members.size() + 1], entry["position"]
		)
		if enemy == null:
			for member in members:
				_guard_enemy_groups.erase(member)
				member.queue_free()
			return _fail_guard_spawn(group_id, "A guard actor could not be instantiated.")
		members.append(enemy)
		_guard_enemy_groups[enemy] = group_id
		enemy.connect("eliminated", _on_guard_eliminated.bind(enemy), CONNECT_ONE_SHOT)
		enemy_spawned.emit(enemy)
		if enemy.is_in_group("guardian_enemies"):
			guardian_spawned.emit(enemy, current_wave)
	_guard_groups[group_id] = members
	_emit_progress()
	return true


func _fail_guard_spawn(group_id: StringName, reason: String) -> bool:
	guard_group_spawn_failed.emit(group_id, reason)
	return false


func _spawn_enemy(
	definition: EnemyDefinition, enemy_name: String, world_position: Vector3
) -> Node3D:
	var enemy := definition.enemy_scene.instantiate() as Node3D
	if enemy == null or not enemy.has_signal("eliminated"):
		if enemy != null:
			enemy.queue_free()
		return null
	enemy.name = enemy_name
	enemy.set("target_path", enemy_target_path)
	enemy.position = _enemy_container.to_local(world_position)
	_enemy_container.add_child(enemy)
	return enemy


func _enemy_id_for_spawn_slot(slot_index: int) -> StringName:
	if current_wave_guardian_count > 0:
		var guardian_start := 1 if current_wave_enemy_count > 1 else 0
		var guardian_end := guardian_start + current_wave_guardian_count
		if slot_index >= guardian_start and slot_index < guardian_end:
			return &"guardian"
	var shooter_slot_start := current_wave_enemy_count - current_wave_shooter_count
	if slot_index >= shooter_slot_start:
		return &"shooter"
	return &"runner"


func _attempt_spawn_enemy() -> void:
	var spawn_marker := _choose_valid_spawn_marker()
	if spawn_marker == null:
		_failed_spawn_attempts += 1
		if _failed_spawn_attempts >= max_spawn_retries:
			_block_session("No valid spawn point was found after %d attempts." % max_spawn_retries)
		else:
			_spawn_timer = spawn_retry_delay
		return

	var enemy_id := _enemy_id_for_spawn_slot(enemies_spawned_this_wave)
	var definition := _get_enemy_definition(enemy_id)
	if definition == null or not definition.is_valid_definition():
		_block_session("The configured %s enemy definition is missing or invalid." % enemy_id)
		return
	var enemy_name := (
		"%s_Wave%d_%02d"
		% [
			definition.display_name.replace(" ", ""),
			current_wave,
			enemies_spawned_this_wave + 1,
		]
	)
	var enemy := _spawn_enemy(definition, enemy_name, spawn_marker.global_position)
	if enemy == null:
		_block_session("The configured %s scene could not be instantiated safely." % enemy_id)
		return
	var health_scale := get_health_scale_for_wave(current_wave)
	if health_scale > 1.001 and enemy.has_method("scale_max_health"):
		enemy.call("scale_max_health", health_scale)

	_last_spawn_marker = spawn_marker
	_active_enemies.append(enemy)
	enemy.connect("eliminated", _on_enemy_eliminated.bind(enemy), CONNECT_ONE_SHOT)
	enemies_spawned_this_wave += 1
	_failed_spawn_attempts = 0
	_spawn_timer = spawn_interval
	enemy_spawned.emit(enemy)
	if enemy.is_in_group("guardian_enemies"):
		guardian_spawned.emit(enemy, current_wave)
	_emit_progress()


func _choose_valid_spawn_marker() -> Marker3D:
	var valid_markers: Array[Marker3D] = []
	var preferred_markers: Array[Marker3D] = []
	for child in _spawn_points_root.get_children():
		if not child is Marker3D:
			continue
		var marker := child as Marker3D
		if not is_spawn_position_valid(marker.global_position):
			continue
		valid_markers.append(marker)
		if not _is_in_camera_front_cone(marker.global_position):
			preferred_markers.append(marker)

	if valid_markers.is_empty():
		return null
	# First contact should teach the player to fight the wave they *chose* to
	# start, not backstab an idle camera. Use the clearest front-facing lane for
	# the first Runner if one exists; later enemies retain varied flank entries.
	if intro_front_spawn and current_wave == 1:
		if enemies_spawned_this_wave == 0:
			var intro_marker := _choose_intro_marker(valid_markers)
			if intro_marker != null:
				return intro_marker
		elif enemies_spawned_this_wave == 1:
			# The tutorial flank used to be chosen from *any* offscreen marker,
			# including blocked lanes where the only remaining Runner could stall
			# behind reactor cover. A visible, clear side lane is more teachable.
			var flank_marker := _choose_intro_flank_marker(valid_markers)
			if flank_marker != null:
				return flank_marker
	var candidates := preferred_markers if not preferred_markers.is_empty() else valid_markers
	if (
		(current_wave >= 3 or endless_mode)
		and candidates.size() > 1
		and is_instance_valid(_last_spawn_marker)
	):
		var rotated: Array[Marker3D] = []
		for candidate in candidates:
			if candidate != _last_spawn_marker:
				rotated.append(candidate)
		if not rotated.is_empty():
			candidates = rotated
	return candidates[_rng.randi_range(0, candidates.size() - 1)]


func _choose_intro_marker(markers: Array[Marker3D]) -> Marker3D:
	if not is_instance_valid(_player_camera):
		return null
	var camera_forward := -_player_camera.global_basis.z
	camera_forward.y = 0.0
	camera_forward = camera_forward.normalized()
	var best: Marker3D
	var best_alignment := 0.62
	for marker in markers:
		var to_spawn := marker.global_position - _player.global_position
		to_spawn.y = 0.0
		if to_spawn.length_squared() < 0.01:
			continue
		var alignment := camera_forward.dot(to_spawn.normalized())
		if alignment > best_alignment and _has_player_sight_line(marker.global_position):
			best = marker
			best_alignment = alignment
	return best


## The second tutorial Runner enters from an unobstructed forward flank.
## Later waves still use the varied offscreen spawn policy. Don't place it on
## the first Runner's exact front ray or on a blind back route behind the player.
func _choose_intro_flank_marker(markers: Array[Marker3D]) -> Marker3D:
	if not is_instance_valid(_player_camera):
		return null
	var forward := -_player_camera.global_basis.z
	forward.y = 0.0
	forward = forward.normalized()
	var best: Marker3D
	var best_alignment := 0.0
	for marker in markers:
		var toward := marker.global_position - _player.global_position
		toward.y = 0.0
		if toward.length_squared() < 0.01:
			continue
		var alignment := forward.dot(toward.normalized())
		if (
			alignment > best_alignment
			and alignment < camera_front_dot_threshold
			and _has_player_sight_line(marker.global_position)
		):
			best = marker
			best_alignment = alignment
	return best


func _has_player_sight_line(position: Vector3) -> bool:
	var origin := _player.global_position + Vector3.UP * 1.1
	var destination := position + Vector3.UP * 1.1
	var excluded: Array[RID] = []
	if _player is CollisionObject3D:
		excluded.append((_player as CollisionObject3D).get_rid())
	var query := PhysicsRayQueryParameters3D.create(origin, destination, 1, excluded)
	return _player.get_world_3d().direct_space_state.intersect_ray(query).is_empty()


func is_spawn_position_valid(position: Vector3, enforce_player_distance: bool = true) -> bool:
	if (
		absf(position.x - arena_center.x) > arena_half_extents.x - spawn_edge_margin
		or absf(position.z - arena_center.y) > arena_half_extents.y - spawn_edge_margin
	):
		return false

	var horizontal_offset := position - _player.global_position
	horizontal_offset.y = 0.0
	if enforce_player_distance and horizontal_offset.length() < minimum_spawn_distance:
		return false

	var query := PhysicsShapeQueryParameters3D.new()
	query.shape = _spawn_clearance_shape
	query.transform = Transform3D(Basis.IDENTITY, position + Vector3.UP * spawn_clearance_height)
	query.collision_mask = spawn_collision_mask
	query.collide_with_bodies = true
	query.collide_with_areas = false
	return _player.get_world_3d().direct_space_state.intersect_shape(query, 1).is_empty()


func _is_in_camera_front_cone(position: Vector3) -> bool:
	if not is_instance_valid(_player_camera):
		return false

	var camera_forward := -_player_camera.global_basis.z
	camera_forward.y = 0.0
	var to_spawn := position - _player.global_position
	to_spawn.y = 0.0
	if camera_forward.length_squared() < 0.001 or to_spawn.length_squared() < 0.001:
		return false
	return camera_forward.normalized().dot(to_spawn.normalized()) > camera_front_dot_threshold


func _on_guard_eliminated(enemy: Node3D) -> void:
	if not _guard_enemy_groups.has(enemy):
		return
	var group_id := StringName(_guard_enemy_groups[enemy])
	_guard_enemy_groups.erase(enemy)
	var members: Array = _guard_groups.get(group_id, [])
	members.erase(enemy)
	enemy_defeated.emit(enemy)
	enemy.queue_free()
	if members.is_empty():
		_guard_groups.erase(group_id)
		guard_group_cleared.emit(group_id)
	_emit_progress()


func _on_enemy_eliminated(enemy: Node3D) -> void:
	if not _active_enemies.has(enemy):
		return

	_active_enemies.erase(enemy)
	enemies_defeated_this_wave += 1
	session_defeated_count += 1
	enemy_defeated.emit(enemy)
	enemy.queue_free()
	_emit_progress()

	if enemies_defeated_this_wave >= current_wave_enemy_count:
		_complete_wave()


func _complete_wave() -> void:
	state = WaveState.INTERMISSION
	_intermission_timer = intermission_duration
	wave_completed.emit(current_wave)
	_emit_progress()


func _block_session(reason: String) -> void:
	_session_running = false
	_spawn_timer = 0.0
	_intermission_timer = 0.0
	state = WaveState.BLOCKED
	push_warning(reason)
	spawn_blocked.emit(reason)
	_emit_progress()


func _clear_active_enemies() -> void:
	for enemy in _active_enemies:
		if is_instance_valid(enemy):
			enemy.queue_free()
	_active_enemies.clear()


func _clear_guard_groups() -> void:
	for members in _guard_groups.values():
		for enemy in members:
			if is_instance_valid(enemy):
				enemy.queue_free()
	_guard_groups.clear()
	_guard_enemy_groups.clear()


func _emit_progress() -> void:
	progress_changed.emit()
