extends Node3D

enum SessionMode { EXPLORE, PREPARING, DEFENSE, RESULTS, MISSION_COMPLETE }
enum RecoveryState { UNDISCOVERED, GUARDED, READY, SECURED }

const PlayerControllerScript = preload("res://scripts/player/player_controller.gd")
const TrainingDroneScript = preload("res://scripts/enemies/training_drone.gd")
const WaveDirectorScript = preload("res://scripts/waves/wave_director.gd")
const TouchControlsScript = preload("res://scripts/ui/hud/touch_controls.gd")
const RunStatsScript = preload("res://scripts/progression/run_stats.gd")
const RewardServiceScript = preload("res://scripts/progression/reward_service.gd")
const ProgressionServiceScript = preload("res://scripts/progression/progression_service.gd")
const RecoveryCacheVisualScript = preload("res://scripts/worlds/recovery_cache_visual.gd")
const DEFEAT_REVEAL_SECONDS := 1.55
const DEFEAT_HOLD_DRAWN_FRAMES := 6

## Test/authoring override only. The shipped scene starts in safe Explore; the
## player must explicitly choose Defense before the WaveDirector can run.
@export var start_wave_session_on_ready: bool = false
@export_range(2.0, 10.0, 0.5) var defense_preparation_seconds: float = 5.0

var session_mode: SessionMode = SessionMode.EXPLORE
var _preparation_remaining: float = 0.0
var _retry_defense: bool = false
var _shots_fired: int = 0
var _is_paused: bool = false
var _base_look_sensitivity: float = 0.0
var _defeat_reveal_remaining: float = 0.0
var _pending_defeat_wave: int = -1
var _defeat_hold_drawn_at: int = -1
var _defeat_hold_process_at: int = -1

## TECH HUNT 0 is orchestrated here, at the existing composition root. World
## resources provide cache content; WaveDirector and ProgressionService remain
## the only encounter and persistent-reward owners.
var _recovery_caches: Array[RecoveryCacheDefinition] = []
var _recovery_states: Dictionary = {}
var _recovery_visuals: Dictionary = {}
var _recovery_root: Node3D
var _recovery_action_cache: StringName = &""
var _recovery_notices: Array[Dictionary] = []
var _recovery_choice_presented: bool = false
var _recovery_return_mode: SessionMode = SessionMode.EXPLORE
var _extracting: bool = false
var _run_banked: bool = false
var _device_profiler: Node
var _profiler_context := ""
var _profiler_context_seconds := 0.0

@onready var player: PlayerControllerScript = $Player
@onready var training_drone: TrainingDroneScript = $TrainingDrone
@onready var wave_director: WaveDirectorScript = $WaveDirector
@onready var run_stats: RunStatsScript = $RunStats
@onready var reward_service: RewardServiceScript = $RewardService
@onready var progression_service: ProgressionServiceScript = $ProgressionService
@onready var touch_controls: TouchControlsScript = $HUD/TouchControls


## The F10 review camera used to be a node inside main.tscn, so every player
## downloaded it and it sat in the shipped scene graph. It is built here
## instead, and only where QA actually runs: the browser preview (the
## automated screenshot pass drives it over a keyboard) and desktop editor/debug
## runs. Android profiling and release APKs do not build the review rig.
func _add_qa_rig() -> void:
	# Android profiling must not pay for the desktop/browser review camera.
	if not ((OS.is_debug_build() and not OS.has_feature("android")) or OS.has_feature("web")):
		return
	# load(), not preload(): the script must not be resident in a build that
	# never uses it.
	var rig_script: GDScript = load("res://scripts/qa/world_tour.gd")
	if rig_script == null:
		return
	var rig: Node = rig_script.new()
	rig.name = "WorldTour"
	add_child(rig)


func _add_device_profiler() -> void:
	if not OS.has_feature("android"):
		return
	var profiling_enabled := (
		OS.is_debug_build()
		or OS.has_feature("device_profile")
		or OS.get_cmdline_user_args().has("--device-profile")
	)
	if not profiling_enabled:
		return
	# Load on the profiling path only. A normal release never creates the node.
	var profiler_script: GDScript = load("res://scripts/integration/device_profiler.gd")
	if profiler_script == null:
		return
	_device_profiler = profiler_script.new()
	_device_profiler.name = "DeviceProfiler"
	add_child(_device_profiler)
	_update_device_profiler_context()


func _update_device_profiler_context() -> void:
	if not is_instance_valid(_device_profiler):
		return
	var phase := "explore"
	match session_mode:
		SessionMode.PREPARING:
			phase = "preparing"
		SessionMode.DEFENSE:
			phase = "defense"
		SessionMode.RESULTS:
			phase = "results"
		SessionMode.MISSION_COMPLETE:
			phase = "mission_complete"
	var wave := wave_director.current_wave
	var enemies := wave_director.active_enemy_count + wave_director.active_guard_count
	var context := "%s/%d/%d" % [phase, wave, enemies]
	if context == _profiler_context:
		return
	_profiler_context = context
	_device_profiler.call("set_context", phase, wave, enemies)


func _ready() -> void:
	_add_qa_rig()
	_add_device_profiler()
	touch_controls.movement_changed.connect(player.set_touch_movement)
	touch_controls.look_delta.connect(player.apply_touch_look)
	touch_controls.fire_changed.connect(player.set_touch_fire_pressed)
	touch_controls.aim_changed.connect(player.set_touch_aim_held)
	touch_controls.weapon_switch_requested.connect(_on_weapon_switch_requested)
	touch_controls.armory_requested.connect(_open_armory)
	touch_controls.armory_weapon_action_requested.connect(_on_armory_weapon_action)
	touch_controls.armory_close_requested.connect(_close_armory)
	touch_controls.skill_requested.connect(player.activate_skill)
	touch_controls.pause_requested.connect(_toggle_pause)
	touch_controls.sound_mute_requested.connect(_on_sound_mute_requested)
	touch_controls._set_hostile_source(player.aim_camera, wave_director)
	_base_look_sensitivity = player.camera_rig.look_sensitivity
	if not FileAccess.file_exists(AegisPreferences.PATH):
		touch_controls._settings_menu.set_mute_from_game(Sfx.is_muted())
	touch_controls.settings_changed.connect(_on_settings_changed)
	touch_controls._apply_preferences(touch_controls._settings_menu.values)
	player.weapon_changed.connect(touch_controls.set_weapon_label)
	player.weapon_changed.connect(_on_weapon_equipped)
	player.weapon_controller.ammo_changed.connect(touch_controls._update_weapon_ammo)
	player.skill_cooldown_changed.connect(touch_controls.set_skill_cooldown)
	player.skill_used.connect(_on_skill_used)
	progression_service.profile_changed.connect(_on_profile_changed)
	_on_profile_changed()
	_apply_saved_weapon()
	_apply_selected_world_spawn()
	_setup_recovery()
	touch_controls._update_weapon_ammo(
		player.weapon_controller.get_current_ammo(),
		player.weapon_controller.get_current_magazine_size(),
		player.weapon_controller.is_reloading()
	)
	touch_controls.set_skill_cooldown(0.0, player.emp_pulse_cooldown)
	touch_controls.retry_requested.connect(_reset_session)
	touch_controls.defense_start_requested.connect(_request_defense)
	touch_controls.recovery_action_requested.connect(_on_recovery_action)
	touch_controls.extract_requested.connect(_extract_from_recovery)
	touch_controls.continue_endless_requested.connect(_continue_to_endless)
	touch_controls.return_to_explore_requested.connect(_return_to_explore)
	touch_controls.finish_run_requested.connect(_finish_run)
	touch_controls.home_requested.connect(_exit_to_dashboard)
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
	reward_service.wave_rewarded.connect(_on_wave_rewarded)
	wave_director.enemy_spawned.connect(_on_wave_enemy_spawned)
	wave_director.enemy_defeated.connect(reward_service.award_enemy_defeat)
	reward_service.enemy_rewarded.connect(_on_enemy_rewarded)
	wave_director.session_ended.connect(_on_wave_session_ended)
	wave_director.spawn_blocked.connect(_on_wave_spawn_blocked)
	wave_director.guard_group_cleared.connect(_on_guard_group_cleared)
	wave_director.guard_group_spawn_failed.connect(_on_guard_group_spawn_failed)
	touch_controls._set_play_phase("explore")
	Sfx.set_music_mode(&"explore")
	_update_status()
	_update_recovery()
	print("Encounter: Explore safe; activate Start Defense when ready")
	print(
		(
			"Progression: wallet %d BP · %d weapon(s) owned"
			% [progression_service.balance, progression_service.unlocked_ids.size()]
		)
	)
	# One line per session so the browser console proves audio came up in the
	# exported build, not only in the editor.
	print(Sfx.describe())
	if start_wave_session_on_ready:
		# Explicit opt-in for automated fixtures; never enabled in main.tscn.
		_request_defense()


func _process(delta: float) -> void:
	touch_controls.set_aim_state(player.is_aiming())
	_update_recovery()
	if _pending_defeat_wave >= 0:
		_defeat_reveal_remaining = maxf(_defeat_reveal_remaining - delta, 0.0)
		if _defeat_reveal_remaining <= 0.0:
			if _defeat_hold_drawn_at < 0:
				_defeat_hold_drawn_at = Engine.get_frames_drawn()
				_defeat_hold_process_at = Engine.get_process_frames()
			# Time alone is not enough on a slow WebGL canvas: the entire 1.2 s
			# Blender fall can be simulated between two visible frames. Hold its
			# final pose for a few actual rendered frames before covering it.
			var drawn := Engine.get_frames_drawn() - _defeat_hold_drawn_at
			var simulated := Engine.get_process_frames() - _defeat_hold_process_at
			if (
				drawn >= DEFEAT_HOLD_DRAWN_FRAMES
				or (Engine.get_frames_drawn() == 0 and simulated >= DEFEAT_HOLD_DRAWN_FRAMES)
			):
				var completed_wave := _pending_defeat_wave
				_pending_defeat_wave = -1
				_present_results(completed_wave)
	if session_mode == SessionMode.PREPARING:
		var before := ceili(_preparation_remaining)
		_preparation_remaining = maxf(_preparation_remaining - delta, 0.0)
		if _preparation_remaining <= 0.0:
			session_mode = SessionMode.DEFENSE
			touch_controls._set_play_phase("defense")
			print("Encounter: Defense started")
			wave_director.start_session()
		elif ceili(_preparation_remaining) != before:
			touch_controls._set_play_phase("preparing", ceili(_preparation_remaining))
	if Input.is_action_just_pressed("start_defense"):
		if (
			not _recovery_action_cache.is_empty()
			and session_mode in [SessionMode.EXPLORE, SessionMode.DEFENSE]
		):
			_on_recovery_action()
		else:
			_request_defense()
	if Input.is_action_just_pressed("open_armory"):
		_open_armory()
	if Input.is_action_just_pressed("reset_session"):
		_reset_session()
	if Input.is_action_just_pressed("toggle_sound"):
		_on_sound_mute_requested()
	if Input.is_action_just_pressed("emp_pulse"):
		player.activate_skill()
	if is_instance_valid(_device_profiler):
		_profiler_context_seconds += delta
		if _profiler_context_seconds >= 0.25:
			_profiler_context_seconds = 0.0
			_update_device_profiler_context()


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
	touch_controls._settings_menu.set_mute_from_game(muted)
	Sfx.play_ui(&"ui_click")


func _on_settings_changed(values: Dictionary) -> void:
	player.camera_rig.look_sensitivity = _base_look_sensitivity * float(values["sensitivity"])
	player.camera_rig.set_reduced_motion(bool(values.get("reduce_motion", false)))
	if is_instance_valid(player.muzzle_flash):
		player.muzzle_flash.set_reduced_flash(bool(values.get("reduce_flash", false)))
	var muted := bool(values["muted"])
	if Sfx.is_muted() != muted:
		Sfx.set_muted(muted)
	touch_controls.set_sound_muted(muted)


func _on_profile_changed() -> void:
	player.weapon_controller.set_available_weapon_ids(progression_service.unlocked_ids)
	HudArmoryBridge.refresh(
		touch_controls,
		progression_service.balance,
		progression_service.best_score,
		progression_service.unlocked_ids,
		player.weapon_controller.get_current_definition().weapon_id
	)
	touch_controls.set_weapon_label(player.get_current_weapon_name())
	touch_controls._update_weapon_ammo(
		player.weapon_controller.get_current_ammo(),
		player.weapon_controller.get_current_magazine_size(),
		player.weapon_controller.is_reloading()
	)


## The front end stores the weapon the player launched with; this is where it
## takes effect. It runs once on boot rather than on every profile change, so a
## mid-run swap in the armory is not overwritten by the saved choice.
func _apply_saved_weapon() -> void:
	var wanted := progression_service.selected_weapon_id
	if wanted == &"" or not progression_service.is_unlocked(wanted):
		return
	for index in range(player.weapon_controller.weapon_definitions.size()):
		var definition: WeaponDefinition = player.weapon_controller.weapon_definitions[index]
		if definition != null and definition.weapon_id == wanted:
			player.select_weapon(index)
			return


## World owns the authored spawn; Main only applies it after the same selection
## resolver used by MissionWorld has run. Existing definitions inherit the
## original main.tscn position, while Titans starts at its Hangar socket.
func _apply_selected_world_spawn() -> void:
	var selected := WorldSelection.selected(self)
	if selected == &"":
		selected = WorldDefinition.DEFAULT_WORLD_ID
	var definition := WorldDefinition.load_definition(selected)
	if definition != null:
		player.position = definition.player_spawn
		wave_director.arena_half_extents = definition.field_size * 0.5
		wave_director.arena_center = definition.field_center


func _on_weapon_equipped(_display_name: String) -> void:
	_on_profile_changed()


func _on_weapon_switch_requested() -> void:
	if player.weapon_controller.available_weapon_count() > 1:
		player.select_next_weapon()
	else:
		_open_armory()


func _open_armory() -> void:
	if session_mode == SessionMode.RESULTS or player.is_defeated() or _is_paused:
		return
	_toggle_pause()
	HudArmoryBridge.show_panel(touch_controls)


func _close_armory() -> void:
	HudArmoryBridge.hide_panel(touch_controls)
	if _is_paused:
		_toggle_pause()


func _on_armory_weapon_action(weapon_id: StringName) -> void:
	var weapon_index := -1
	for index in range(player.weapon_controller.weapon_definitions.size()):
		if player.weapon_controller.weapon_definitions[index].weapon_id == weapon_id:
			weapon_index = index
			break
	if weapon_index < 0 or not touch_controls._armory_panel.visible:
		return
	var weapon_name := player.weapon_controller.weapon_definitions[weapon_index].display_name
	if progression_service.is_unlocked(weapon_id):
		player.select_weapon(weapon_index)
		print("Armory: equipped " + String(weapon_id))
		touch_controls._armory_panel.show_hint(
			"%s EQUIPPED · READY TO PLAY" % weapon_name.to_upper()
		)
		return
	if (
		ProgressionService.BLUEPRINT_REQUIRED.has(weapon_id)
		and not progression_service.has_blueprint(weapon_id)
	):
		touch_controls._armory_panel.show_hint(AegisText.t("recovery.blueprint_required"))
		return
	var missing := progression_service.unlock_cost(weapon_id) - progression_service.balance
	if missing > 0:
		touch_controls._armory_panel.show_hint("NEED %d MORE BP · FIGHT WAVES" % missing)
		return
	if progression_service.unlock_weapon(weapon_id):
		player.select_weapon(weapon_index)
		print("Armory: unlocked " + String(weapon_id))
		Sfx.play_ui(&"session_clear")
		touch_controls._armory_panel.show_hint("%s UNLOCKED & EQUIPPED" % weapon_name.to_upper())


func _toggle_pause() -> void:
	if session_mode == SessionMode.MISSION_COMPLETE:
		return
	if player.is_defeated():
		_reset_session()
		return
	_is_paused = not _is_paused
	get_tree().paused = _is_paused
	touch_controls.set_paused(_is_paused)
	print("HUD: paused" if _is_paused else "HUD: resumed")


## Separate exploration from a survival encounter. Starting a run only enters
## preparation; no enemies may spawn before the player sees the countdown.
func _request_defense() -> void:
	if session_mode != SessionMode.EXPLORE or player.is_defeated() or _is_paused:
		return
	session_mode = SessionMode.PREPARING
	Sfx.set_music_mode(&"preparing")
	_preparation_remaining = defense_preparation_seconds
	touch_controls.hide_help()
	touch_controls._set_play_phase("preparing", ceili(_preparation_remaining))
	print("Encounter: Preparing Defense (%d s)" % ceili(_preparation_remaining))
	_update_status()


## Retry preserves the encounter intent; returning to Explore does not. Both
## routes clear remaining enemies and reset health/ammo before the HUD unlocks.
func _reset_session() -> void:
	var restart_defense := (
		session_mode == SessionMode.PREPARING
		or session_mode == SessionMode.DEFENSE
		or (session_mode == SessionMode.RESULTS and _retry_defense)
	)
	_return_to_explore()
	if restart_defense:
		_request_defense()


func _return_to_explore() -> void:
	_is_paused = false
	get_tree().paused = false
	_preparation_remaining = 0.0
	_pending_defeat_wave = -1
	_defeat_reveal_remaining = 0.0
	_defeat_hold_drawn_at = -1
	_defeat_hold_process_at = -1
	_retry_defense = false
	_extracting = false
	_run_banked = false
	_recovery_return_mode = SessionMode.EXPLORE
	wave_director.reset_session()
	player.reset_player()
	player.camera_rig.recenter_for_new_run()
	training_drone.set_active(true)
	training_drone.reset()
	_shots_fired = 0
	run_stats.reset_run()
	reward_service.reset_run()
	session_mode = SessionMode.EXPLORE
	_reset_recovery()
	Sfx.set_music_mode(&"explore")
	touch_controls.hide_results()
	touch_controls.set_player_down(false)
	touch_controls.set_paused(false)
	touch_controls._set_play_phase("explore")
	_update_status()
	print("Encounter: Returned to Explore")


## Every in-game HOME lands here. DashboardReturn owns where "home" is -- the web
## shell's lobby when the engine is embedded, the front end's DASHBOARD stage when
## it is not -- so the scene never has to know which build it is running in.
func _exit_to_dashboard() -> void:
	_is_paused = false
	_pending_defeat_wave = -1
	_retry_defense = false
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	touch_controls.set_paused(false)
	DashboardReturn.request(get_tree())


## Pause offers a deliberate cash-out path; a player need not die or leave
## their BP behind to see the outcome and choose another run.
func _finish_run() -> void:
	if session_mode != SessionMode.DEFENSE:
		return
	_is_paused = false
	get_tree().paused = false
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	touch_controls.set_paused(false)
	wave_director.end_session()


# --- TECH HUNT 0: explicit Recovery inside this session ---------------------


func _setup_recovery() -> void:
	var selected := WorldSelection.selected(self)
	var definition := WorldDefinition.load_definition(selected)
	if definition == null or definition.recovery_caches.is_empty():
		return
	_recovery_root = Node3D.new()
	_recovery_root.name = "RecoveryCaches"
	add_child(_recovery_root)
	for cache in definition.recovery_caches:
		if cache == null or not cache.is_valid_definition():
			push_warning("Recovery: invalid cache definition in %s" % selected)
			continue
		_recovery_caches.append(cache)
		_recovery_states[cache.cache_id] = (
			RecoveryState.SECURED
			if progression_service.is_cache_secured(cache.cache_id)
			else RecoveryState.UNDISCOVERED
		)
		var visual := RecoveryCacheVisualScript.new() as Node3D
		visual.name = "Cache_%s" % cache.cache_id
		visual.position = cache.position
		visual.set("model_scene_path", cache.model_scene_path)
		visual.set("cache_title", cache.display_name)
		_recovery_root.add_child(visual)
		_recovery_visuals[cache.cache_id] = visual
		_refresh_recovery_visual(cache)


func _reset_recovery() -> void:
	_recovery_action_cache = &""
	_recovery_choice_presented = false
	_recovery_notices.clear()
	for cache in _recovery_caches:
		_recovery_states[cache.cache_id] = (
			RecoveryState.SECURED
			if progression_service.is_cache_secured(cache.cache_id)
			else RecoveryState.UNDISCOVERED
		)
		_refresh_recovery_visual(cache)
	_update_recovery()


func _cache_by_id(cache_id: StringName) -> RecoveryCacheDefinition:
	for cache in _recovery_caches:
		if cache.cache_id == cache_id:
			return cache
	return null


func _primary_cache() -> RecoveryCacheDefinition:
	for cache in _recovery_caches:
		if not cache.optional:
			return cache
	return null


func _optional_cache() -> RecoveryCacheDefinition:
	for cache in _recovery_caches:
		if cache.optional:
			return cache
	return null


func _cache_state(cache_id: StringName) -> int:
	return int(_recovery_states.get(cache_id, RecoveryState.UNDISCOVERED))


## String form for smoke tests and diagnostics; reward decisions use the enum.
func recovery_cache_state(cache_id: StringName) -> String:
	match _cache_state(cache_id):
		RecoveryState.GUARDED:
			return "guarded"
		RecoveryState.READY:
			return "ready"
		RecoveryState.SECURED:
			return "secured"
	return "undiscovered"


func _cache_distance(cache: RecoveryCacheDefinition) -> float:
	return (
		Vector2(
			player.global_position.x - cache.position.x, player.global_position.z - cache.position.z
		)
		. length()
	)


func _update_recovery() -> void:
	if (
		_recovery_caches.is_empty()
		or session_mode in [SessionMode.MISSION_COMPLETE, SessionMode.RESULTS]
		or player.is_defeated()
	):
		return
	var nearest: RecoveryCacheDefinition = null
	var nearest_distance := INF
	for cache in _recovery_caches:
		if progression_service.is_cache_secured(cache.cache_id):
			_recovery_states[cache.cache_id] = RecoveryState.SECURED
		var distance := _cache_distance(cache)
		if (
			_cache_state(cache.cache_id) == RecoveryState.UNDISCOVERED
			and distance <= cache.discovery_radius
		):
			_recovery_states[cache.cache_id] = RecoveryState.GUARDED
			_refresh_recovery_visual(cache)
		if (
			_cache_state(cache.cache_id) != RecoveryState.SECURED
			and distance <= cache.interaction_radius
			and distance < nearest_distance
		):
			nearest = cache
			nearest_distance = distance

	_recovery_action_cache = &""
	var action := ""
	if nearest != null:
		match _cache_state(nearest.cache_id):
			RecoveryState.GUARDED:
				if wave_director.guard_group_size(nearest.cache_id) == 0:
					action = "engage"
			RecoveryState.READY:
				action = "secure"
		if not action.is_empty():
			_recovery_action_cache = nearest.cache_id
	_update_recovery_hud(nearest, nearest_distance, action)


func _update_recovery_hud(
	nearest: RecoveryCacheDefinition, nearest_distance: float, action: String
) -> void:
	var title := ""
	var detail := ""
	var state_text := ""
	if nearest != null:
		title = nearest.display_name
		var guards := wave_director.guard_group_size(nearest.cache_id)
		state_text = (
			AegisText.t("recovery.guards_remaining", [guards])
			if guards > 0
			else _recovery_state_text(nearest)
		)
		detail = "%s · %d m" % [_recovery_reward_text(nearest), roundi(nearest_distance)]
	else:
		var primary := _primary_cache()
		var optional := _optional_cache()
		var target: RecoveryCacheDefinition = null
		if primary != null and _cache_state(primary.cache_id) != RecoveryState.SECURED:
			target = primary
			title = AegisText.t("recovery.primary_task", [primary.display_name])
		elif optional != null and _cache_state(optional.cache_id) != RecoveryState.SECURED:
			target = optional
			title = AegisText.t("recovery.optional_task", [optional.display_name])
		elif primary != null:
			title = AegisText.t("recovery.complete_title")
			detail = AegisText.t("recovery.all_secured")
			state_text = AegisText.t("recovery.secured")
		if target != null:
			detail = "%s · %d m" % [_recovery_reward_text(target), roundi(_cache_distance(target))]
			state_text = target.landmark_name
	touch_controls.set_recovery_status(title, detail, state_text, action)


func _recovery_state_text(cache: RecoveryCacheDefinition) -> String:
	match _cache_state(cache.cache_id):
		RecoveryState.READY:
			return AegisText.t("recovery.ready")
		RecoveryState.SECURED:
			return AegisText.t("recovery.secured")
		RecoveryState.GUARDED:
			return AegisText.t("recovery.guarded")
	return AegisText.t("recovery.signal")


func _recovery_reward_text(cache: RecoveryCacheDefinition) -> String:
	if cache.blueprint_id != &"":
		var weapon := WeaponDefinition.load_definition(cache.blueprint_id)
		var weapon_name := String(cache.blueprint_id) if weapon == null else weapon.display_name
		return AegisText.t("recovery.blueprint_reward", [weapon_name])
	return AegisText.t("recovery.bp_reward", [cache.bp_reward])


func _refresh_recovery_visual(cache: RecoveryCacheDefinition) -> void:
	var visual := _recovery_visuals.get(cache.cache_id) as Node3D
	if visual == null:
		return
	var color: Color = AegisTokens.INK_2
	match _cache_state(cache.cache_id):
		RecoveryState.GUARDED:
			color = AegisTokens.ACCENT
		RecoveryState.READY:
			color = AegisTokens.INFO
		RecoveryState.SECURED:
			color = AegisTokens.OK
	visual.call("set_visual_state", _recovery_state_text(cache), color)


func _on_recovery_action() -> void:
	var cache := _cache_by_id(_recovery_action_cache)
	if (
		cache == null
		or _cache_distance(cache) > cache.interaction_radius
		or session_mode not in [SessionMode.EXPLORE, SessionMode.PREPARING, SessionMode.DEFENSE]
		or player.is_defeated()
		or _is_paused
	):
		return
	match _cache_state(cache.cache_id):
		RecoveryState.GUARDED:
			if wave_director.guard_group_size(cache.cache_id) > 0:
				return
			wave_director.spawn_guard_group(cache.cache_id, cache.guard_spawns)
		RecoveryState.READY:
			_secure_cache(cache)
	_update_recovery()
	_update_status()


func _secure_cache(cache: RecoveryCacheDefinition) -> bool:
	if (
		cache == null
		or _cache_state(cache.cache_id) != RecoveryState.READY
		or wave_director.guard_group_size(cache.cache_id) > 0
		or _cache_distance(cache) > cache.interaction_radius
		or session_mode not in [SessionMode.EXPLORE, SessionMode.PREPARING, SessionMode.DEFENSE]
		or player.is_defeated()
		or _is_paused
	):
		return false
	if not progression_service.secure_cache(
		cache.cache_id, cache.reward_id, cache.blueprint_id, cache.bp_reward
	):
		return false
	_recovery_states[cache.cache_id] = RecoveryState.SECURED
	if cache.blueprint_id != &"":
		_recovery_notices.append({"kind": "blueprint", "weapon": cache.blueprint_id})
	elif cache.bp_reward > 0:
		_recovery_notices.append({"kind": "bp", "amount": cache.bp_reward})
	_refresh_recovery_visual(cache)
	Sfx.play_ui(&"session_clear")
	touch_controls._feedback_panel.show_message(
		AegisText.t("recovery.secured_feedback", [cache.display_name])
	)
	print("Recovery: secured %s · reward %s" % [cache.cache_id, cache.reward_id])
	_update_recovery()
	_update_status()
	_present_recovery_choice()
	return true


func _on_guard_group_cleared(group_id: StringName) -> void:
	var cache := _cache_by_id(group_id)
	if cache == null or progression_service.is_cache_secured(group_id):
		return
	_recovery_states[group_id] = RecoveryState.READY
	_refresh_recovery_visual(cache)
	touch_controls._feedback_panel.show_message(
		AegisText.t("recovery.ready_feedback", [cache.display_name])
	)
	_update_recovery()
	_update_status()


func _on_guard_group_spawn_failed(group_id: StringName, reason: String) -> void:
	if _cache_by_id(group_id) == null:
		return
	push_warning("Recovery guards: " + reason)
	touch_controls._feedback_panel.show_message(AegisText.t("recovery.spawn_blocked"))


func _present_recovery_choice() -> void:
	var primary := _primary_cache()
	if (
		primary == null
		or _recovery_choice_presented
		or not progression_service.is_cache_secured(primary.cache_id)
	):
		return
	_recovery_choice_presented = true
	_recovery_return_mode = session_mode
	session_mode = SessionMode.MISSION_COMPLETE
	_is_paused = true
	get_tree().paused = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	Sfx.set_music_mode(&"results")
	touch_controls._set_play_phase("results")
	touch_controls.show_extraction_choice(
		progression_service.balance, progression_service.is_unlocked(&"arc_shooter")
	)


func _continue_to_endless() -> void:
	if session_mode != SessionMode.MISSION_COMPLETE:
		return
	var return_mode := _recovery_return_mode
	touch_controls.hide_results()
	_is_paused = false
	get_tree().paused = false
	touch_controls.set_paused(false)
	if return_mode == SessionMode.DEFENSE and wave_director.session_running:
		session_mode = SessionMode.DEFENSE
		Sfx.set_music_mode(&"defense")
		touch_controls._set_play_phase("defense")
	elif return_mode == SessionMode.PREPARING:
		session_mode = SessionMode.PREPARING
		Sfx.set_music_mode(&"preparing")
		touch_controls._set_play_phase("preparing", ceili(_preparation_remaining))
	else:
		session_mode = SessionMode.EXPLORE
		Sfx.set_music_mode(&"explore")
		touch_controls._set_play_phase("explore")
		_request_defense()
	_update_status()
	_update_recovery()


func _extract_from_recovery() -> void:
	if session_mode != SessionMode.MISSION_COMPLETE:
		return
	_extracting = true
	_is_paused = false
	get_tree().paused = false
	touch_controls.hide_results()
	touch_controls.set_paused(false)
	if wave_director.state == WaveDirectorScript.WaveState.GAME_OVER:
		_on_wave_session_ended(wave_director.current_wave, wave_director.session_defeated_count)
	else:
		wave_director.end_session()


func _recovery_result_summary() -> String:
	var lines := PackedStringArray()
	for notice in _recovery_notices:
		if notice.get("kind", "") == "blueprint":
			var weapon := WeaponDefinition.load_definition(StringName(notice["weapon"]))
			if weapon != null:
				lines.append(AegisText.t("results.recovery_blueprint", [weapon.display_name]))
		elif notice.get("kind", "") == "bp":
			lines.append(AegisText.t("results.recovery_bp", [int(notice["amount"])]))
	return "\n".join(lines)


func _on_shot_fired() -> void:
	_shots_fired += 1
	touch_controls._show_shot_feedback()
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
	# Also covers smoke fixtures that call WaveDirector.start_session() directly.
	# The fixed practice drone is for safe Explore only; in Defense it blocked
	# real targets and stole EMP damage without ever awarding wave BP.
	training_drone.set_active(false)
	session_mode = SessionMode.DEFENSE
	Sfx.set_music_mode(&"defense")
	touch_controls._set_play_phase("defense")
	Sfx.play_ui(&"wave_start")
	run_stats.start_run()
	_update_status()


func _on_wave_completed(_wave_index: int) -> void:
	_update_status()


func _on_enemy_rewarded(enemy: Node3D, _score_reward: int, bp_reward: int) -> void:
	# A real KO deserves an immediate outcome even if the player cannot finish
	# the wave. The same earned reward appears in Results and the browser log.
	touch_controls._feedback_panel.show_message("TARGET DOWN · +%d BP" % bp_reward)
	var archetype := "SHOOTER" if enemy.is_in_group("shooter_enemies") else "RUNNER"
	print("Encounter: %s KO · +%d BP" % [archetype, bp_reward])


func _on_wave_rewarded(wave_index: int, bp_reward: int) -> void:
	# Only show the award once it was actually applied, not before the reward
	# service has checked its per-wave duplicate guard.
	touch_controls._feedback_panel.show_message(
		"WAVE %02d CLEAR · +%d BP" % [wave_index, bp_reward]
	)


func _on_wave_enemy_spawned(enemy: Node3D) -> void:
	if enemy.has_signal("damage_received"):
		enemy.connect("damage_received", _on_target_damage_received)


func _on_wave_session_ended(wave_index: int, _total_defeated: int) -> void:
	var was_defense := (
		session_mode == SessionMode.DEFENSE
		or (_extracting and _recovery_return_mode == SessionMode.DEFENSE)
	)
	var should_bank := was_defense or _extracting
	# Explore never spawns an automatic wave, but a test/manual damage event
	# can still defeat the hero. Show recoverable Results instead of stranding
	# a dead character with no session to finish or rewards to claim.
	if not should_bank and not player.is_defeated():
		return
	_retry_defense = was_defense and not _extracting
	session_mode = SessionMode.RESULTS
	Sfx.set_music_mode(&"results")
	if not player.is_defeated():
		Sfx.play_ui(&"session_clear")
	run_stats.end_run()
	if should_bank and not _run_banked:
		# Bank immediately, including Extract from a non-Defense Recovery. The
		# guard covers duplicate end signals and all subsequent retry/reset paths.
		_run_banked = true
		progression_service.bank_run(run_stats.run_score, run_stats.bp_earned)
		print(
			(
				"Progression: banked +%d BP · wallet %d · best %d"
				% [run_stats.bp_earned, progression_service.balance, progression_service.best_score]
			)
		)
	if was_defense and player.is_defeated():
		# Results used to cover the authored 1.2 s Blender collapse on the very
		# same frame as fatal damage. Stop the AI and bank first, then let the
		# in-world motion actually render before opening the results panel.
		_pending_defeat_wave = wave_index
		_defeat_reveal_remaining = DEFEAT_REVEAL_SECONDS
		_update_status()
		print("Encounter: Defeat reveal before Results")
		return
	_present_results(wave_index)


func _present_results(wave_index: int) -> void:
	touch_controls._set_play_phase("results")
	(
		touch_controls
		. show_results(
			wave_index,
			run_stats.get_survival_time_text(),
			run_stats.eliminations,
			run_stats.run_score,
			run_stats.bp_earned,
			progression_service.balance,
			progression_service.best_score,
			progression_service.unlocked_ids,
			player.is_defeated(),
			_recovery_result_summary(),
		)
	)
	_update_status()
	print("Encounter: Results after wave %d" % wave_index)


func _on_wave_spawn_blocked(reason: String) -> void:
	push_warning("Defense could not spawn: " + reason)
	_return_to_explore()


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
	touch_controls.set_wave_status(wave_number, active_enemies, remaining_enemies, wave_state)
	touch_controls.set_status(status)
