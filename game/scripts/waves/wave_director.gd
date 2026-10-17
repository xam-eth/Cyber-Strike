extends Node

signal wave_started(wave_index: int, enemy_count: int)
signal wave_completed(wave_index: int)
signal progress_changed
signal enemy_spawned(enemy: Node3D)
signal enemy_defeated(enemy: Node3D)
signal session_ended(wave_index: int, total_defeated: int)
signal spawn_blocked(reason: String)

enum WaveState { IDLE, SPAWNING, INTERMISSION, GAME_OVER, BLOCKED }

const RUNNER_SCENE: PackedScene = preload("res://scenes/enemies/runner.tscn")
const SHOOTER_SCENE: PackedScene = preload("res://scenes/enemies/shooter.tscn")

@export var player_path: NodePath = ^"../Player"
@export var enemy_container_path: NodePath = ^"../WaveEnemies"
@export var spawn_points_path: NodePath = ^"../SpawnPoints"
@export var enemy_target_path: NodePath = ^"../../Player"
@export_range(1, 8, 1) var base_enemies_per_wave: int = 3
@export_range(0, 4, 1) var enemies_added_per_wave: int = 1
@export_range(1, 12, 1) var max_enemies_per_wave: int = 8
@export_range(2, 12, 1) var shooter_first_wave: int = 2
@export_range(1, 6, 1) var shooter_every_n_waves: int = 2
@export_range(1, 6, 1) var max_shooters_per_wave: int = 3
@export_range(1, 6, 1) var max_active_enemies: int = 3
@export_range(0.0, 4.0, 0.05) var initial_spawn_delay: float = 0.75
@export_range(0.0, 4.0, 0.05) var spawn_interval: float = 0.8
@export_range(0.05, 2.0, 0.05) var spawn_retry_delay: float = 0.35
@export_range(1, 12, 1) var max_spawn_retries: int = 6
@export_range(0.25, 10.0, 0.25) var intermission_duration: float = 3.0
@export_range(1.0, 15.0, 0.5) var minimum_spawn_distance: float = 7.5
@export var arena_half_extents: Vector2 = Vector2(15.0, 15.0)
@export_range(0.5, 3.0, 0.1) var spawn_edge_margin: float = 1.25
@export_range(0.1, 1.0, 0.05) var spawn_clearance_radius: float = 0.36
@export_range(0.4, 1.5, 0.05) var spawn_clearance_height: float = 0.9
@export_flags_3d_physics var spawn_collision_mask: int = 3
@export_range(0.5, 1.0, 0.01) var camera_front_dot_threshold: float = 0.92

var state: WaveState = WaveState.IDLE
var current_wave: int = 0
var current_wave_enemy_count: int = 0
var current_wave_shooter_count: int = 0
var session_defeated_count: int = 0
var enemies_defeated_this_wave: int = 0
var enemies_spawned_this_wave: int = 0

var active_enemy_count: int:
	get:
		return _active_enemies.size()

var enemies_remaining: int:
	get:
		return maxi(current_wave_enemy_count - enemies_defeated_this_wave, 0)

var _player: Node3D
var _player_camera: Camera3D
var _enemy_container: Node3D
var _spawn_points_root: Node3D
var _active_enemies: Array[Node3D] = []
var _spawn_clearance_shape: SphereShape3D
var _rng := RandomNumberGenerator.new()
var _session_running: bool = false
var _spawn_timer: float = 0.0
var _intermission_timer: float = 0.0
var _failed_spawn_attempts: int = 0


func _ready() -> void:
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
	_emit_progress()


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
	if active_enemy_count >= max_active_enemies or _spawn_timer > 0.0:
		return
	_attempt_spawn_enemy()


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
	session_defeated_count = 0
	enemies_defeated_this_wave = 0
	enemies_spawned_this_wave = 0
	_start_next_wave()


func reset_session() -> void:
	_session_running = false
	_spawn_timer = 0.0
	_intermission_timer = 0.0
	_failed_spawn_attempts = 0
	_clear_active_enemies()
	state = WaveState.IDLE
	current_wave = 0
	current_wave_enemy_count = 0
	current_wave_shooter_count = 0
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
	state = WaveState.GAME_OVER
	session_ended.emit(current_wave, session_defeated_count)
	_emit_progress()


func get_active_enemies() -> Array[Node3D]:
	return _active_enemies.duplicate()


func get_shooter_count_for_wave(wave_index: int, enemy_count: int) -> int:
	if wave_index < shooter_first_wave or enemy_count <= 1:
		return 0
	var waves_since_first := wave_index - shooter_first_wave
	var scheduled_count := 1 + floori(float(waves_since_first) / float(shooter_every_n_waves))
	return mini(mini(scheduled_count, max_shooters_per_wave), enemy_count - 1)


func get_state_label() -> String:
	match state:
		WaveState.IDLE:
			return "READY"
		WaveState.SPAWNING:
			return "ACTIVE %d/%d" % [active_enemy_count, max_active_enemies]
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
	current_wave_enemy_count = mini(
		base_enemies_per_wave + (current_wave - 1) * enemies_added_per_wave, max_enemies_per_wave
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


func _attempt_spawn_enemy() -> void:
	var spawn_marker := _choose_valid_spawn_marker()
	if spawn_marker == null:
		_failed_spawn_attempts += 1
		if _failed_spawn_attempts >= max_spawn_retries:
			_block_session("No valid spawn point was found after %d attempts." % max_spawn_retries)
		else:
			_spawn_timer = spawn_retry_delay
		return

	var shooter_slot_start := current_wave_enemy_count - current_wave_shooter_count
	var is_shooter := enemies_spawned_this_wave >= shooter_slot_start
	var enemy_type_label := "Shooter" if is_shooter else "Runner"
	var enemy_scene := SHOOTER_SCENE if is_shooter else RUNNER_SCENE
	var enemy := enemy_scene.instantiate() as Node3D
	if enemy == null:
		_block_session("The configured %s scene could not be instantiated." % enemy_type_label)
		return

	enemy.name = "%s_Wave%d_%02d" % [enemy_type_label, current_wave, enemies_spawned_this_wave + 1]
	enemy.set("target_path", enemy_target_path)
	enemy.position = _enemy_container.to_local(spawn_marker.global_position)
	_enemy_container.add_child(enemy)
	if not enemy.has_signal("eliminated"):
		push_error("Wave enemy must expose an 'eliminated' signal.")
		enemy.queue_free()
		_block_session("The spawned enemy has no eliminated signal.")
		return

	_active_enemies.append(enemy)
	enemy.connect("eliminated", _on_enemy_eliminated.bind(enemy), CONNECT_ONE_SHOT)
	enemies_spawned_this_wave += 1
	_failed_spawn_attempts = 0
	_spawn_timer = spawn_interval
	enemy_spawned.emit(enemy)
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
	var candidates := preferred_markers if not preferred_markers.is_empty() else valid_markers
	return candidates[_rng.randi_range(0, candidates.size() - 1)]


func is_spawn_position_valid(position: Vector3) -> bool:
	if (
		absf(position.x) > arena_half_extents.x - spawn_edge_margin
		or absf(position.z) > arena_half_extents.y - spawn_edge_margin
	):
		return false

	var horizontal_offset := position - _player.global_position
	horizontal_offset.y = 0.0
	if horizontal_offset.length() < minimum_spawn_distance:
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


func _emit_progress() -> void:
	progress_changed.emit()
