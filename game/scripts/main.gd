extends Node3D

const PlayerControllerScript = preload("res://scripts/player/player_controller.gd")
const TrainingDroneScript = preload("res://scripts/enemies/training_drone.gd")
const WaveDirectorScript = preload("res://scripts/waves/wave_director.gd")
const TouchControlsScript = preload("res://scripts/ui/touch_controls.gd")
const RunStatsScript = preload("res://scripts/progression/run_stats.gd")
const RewardServiceScript = preload("res://scripts/progression/reward_service.gd")

@export var start_wave_session_on_ready: bool = true

var _shots_fired: int = 0
var _is_paused: bool = false

@onready var player: PlayerControllerScript = $Player
@onready var training_drone: TrainingDroneScript = $TrainingDrone
@onready var wave_director: WaveDirectorScript = $WaveDirector
@onready var run_stats: RunStatsScript = $RunStats
@onready var reward_service: RewardServiceScript = $RewardService
@onready var touch_controls: TouchControlsScript = $HUD/TouchControls


func _ready() -> void:
	touch_controls.movement_changed.connect(player.set_touch_movement)
	touch_controls.look_delta.connect(player.apply_touch_look)
	touch_controls.fire_changed.connect(player.set_touch_fire_pressed)
	touch_controls.aim_changed.connect(player.set_touch_aim_held)
	touch_controls.weapon_switch_requested.connect(player.select_next_weapon)
	touch_controls.skill_requested.connect(player.activate_skill)
	touch_controls.pause_requested.connect(_toggle_pause)
	touch_controls.sound_mute_requested.connect(_on_sound_mute_requested)
	touch_controls.set_sound_muted(Sfx.is_muted())
	player.weapon_changed.connect(touch_controls.set_weapon_label)
	player.skill_cooldown_changed.connect(touch_controls.set_skill_cooldown)
	player.skill_used.connect(_on_skill_used)
	touch_controls.set_weapon_label(player.get_current_weapon_name())
	touch_controls.set_skill_cooldown(0.0, player.emp_pulse_cooldown)
	touch_controls.retry_requested.connect(_reset_session)
	player.aim_changed.connect(touch_controls.set_aim_state)
	player.shot_fired.connect(_on_shot_fired)
	player.health_changed.connect(_on_combatant_health_changed)
	player.damage_received.connect(_on_player_damage_received)
	player.defeated.connect(_on_player_defeated)
	training_drone.health_changed.connect(_on_combatant_health_changed)
	training_drone.damage_received.connect(_on_target_damage_received)
	wave_director.progress_changed.connect(_update_status)
	run_stats.stats_changed.connect(_update_status)
	wave_director.wave_started.connect(_on_wave_started)
	wave_director.wave_completed.connect(_on_wave_completed)
	wave_director.wave_completed.connect(reward_service.award_wave_completion)
	wave_director.enemy_spawned.connect(_on_wave_enemy_spawned)
	wave_director.enemy_defeated.connect(reward_service.award_enemy_defeat)
	wave_director.session_ended.connect(_on_wave_session_ended)
	wave_director.spawn_blocked.connect(_on_wave_spawn_blocked)
	_update_status()
	# One line per session so the browser console proves audio came up in the
	# exported build, not only in the editor.
	print(Sfx.describe())
	if start_wave_session_on_ready:
		wave_director.start_session()


func _process(_delta: float) -> void:
	touch_controls.set_aim_state(player.is_aiming())
	if Input.is_action_just_pressed("reset_session"):
		_reset_session()
	if Input.is_action_just_pressed("toggle_sound"):
		_on_sound_mute_requested()
	if Input.is_action_just_pressed("emp_pulse"):
		player.activate_skill()


func _unhandled_input(event: InputEvent) -> void:
	if not event.is_action_pressed("ui_cancel"):
		return
	if event is InputEventKey and event.echo:
		return
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	_toggle_pause()
	get_viewport().set_input_as_handled()


## Audio mute is owned here rather than in the HUD: the button and the M key go
## through the same path, and the label is updated from the real audio state
## instead of being flipped blindly.
func _on_sound_mute_requested() -> void:
	var muted := Sfx.toggle_muted()
	touch_controls.set_sound_muted(muted)
	Sfx.play_ui(&"ui_click")


func _toggle_pause() -> void:
	if player.is_defeated():
		_reset_session()
		return
	_is_paused = not _is_paused
	get_tree().paused = _is_paused
	touch_controls.set_paused(_is_paused)


func _reset_session() -> void:
	_is_paused = false
	get_tree().paused = false
	touch_controls.hide_results()
	touch_controls.set_paused(false)
	touch_controls.set_player_down(false)
	player.reset_player()
	training_drone.reset()
	_shots_fired = 0
	run_stats.reset_run()
	reward_service.reset_run()
	wave_director.reset_session()
	touch_controls.show_help()
	if start_wave_session_on_ready:
		wave_director.start_session()
	_update_status()


func _on_shot_fired() -> void:
	_shots_fired += 1
	_update_status()


func _on_player_damage_received(_amount: float, _current: float, _maximum: float) -> void:
	touch_controls.show_damage_received()
	_update_status()


func _on_player_defeated() -> void:
	Sfx.play_ui(&"defeat")
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	touch_controls.set_player_down(true)
	wave_director.end_session()
	_update_status()


func _on_target_damage_received(_amount: float, _current: float, _maximum: float) -> void:
	Sfx.play_ui(&"hit_confirm")
	touch_controls.show_hit_confirmed()


func _on_skill_used(targets_hit: int, _cooldown_seconds: float) -> void:
	Sfx.play_3d(&"skill_pulse", player.global_position)
	touch_controls.show_skill_feedback(targets_hit)


func _on_combatant_health_changed(_current: float, _maximum: float) -> void:
	_update_status()


func _on_wave_started(_wave_index: int, _enemy_count: int) -> void:
	Sfx.play_ui(&"wave_start")
	run_stats.start_run()
	_update_status()


func _on_wave_completed(_wave_index: int) -> void:
	_update_status()


func _on_wave_enemy_spawned(enemy: Node3D) -> void:
	if enemy.has_signal("damage_received"):
		enemy.connect("damage_received", _on_target_damage_received)


func _on_wave_session_ended(wave_index: int, _total_defeated: int) -> void:
	Sfx.play_ui(&"session_clear")
	run_stats.end_run()
	var run_time := run_stats.get_survival_time_text()
	var run_kos := run_stats.eliminations
	var run_score := run_stats.run_score
	var run_bp := run_stats.bp_earned
	touch_controls.show_results(wave_index, run_time, run_kos, run_score, run_bp)
	_update_status()


func _on_wave_spawn_blocked(_reason: String) -> void:
	run_stats.end_run()
	_update_status()


func _update_status() -> void:
	var player_health := roundi(player.current_health)
	var player_maximum := roundi(player.max_health)
	var target_health := roundi(training_drone.current_health)
	var target_maximum := roundi(training_drone.max_health)
	var status := (
		"Score: %d · BP earned: %d\nKOs: %d · Time: %s\nTarget %d / %d · Shots %d"
		% [
			run_stats.run_score,
			run_stats.bp_earned,
			run_stats.eliminations,
			run_stats.get_survival_time_text(),
			target_health,
			target_maximum,
			_shots_fired,
		]
	)
	touch_controls.set_hud_health(player_health, player_maximum)
	var wave_number := wave_director.current_wave
	var active_enemies := wave_director.active_enemy_count
	var remaining_enemies := wave_director.enemies_remaining
	var wave_state := wave_director.get_state_label()
	touch_controls.set_wave_status(wave_number, active_enemies, remaining_enemies, wave_state)
	touch_controls.set_status(status)
	(
		touch_controls
		. set_run_summary(
			run_stats.run_score,
			run_stats.bp_earned,
			run_stats.eliminations,
			run_stats.get_survival_time_text(),
			_shots_fired,
		)
	)
