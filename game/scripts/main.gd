extends Node3D

enum SessionMode { EXPLORE, PREPARING, DEFENSE, RESULTS, MISSION_COMPLETE }
enum RecoveryState { UNDISCOVERED, GUARDED, READY, SECURED }

const PlayerControllerScript = preload("res://scripts/player/player_controller.gd")
const TrainingDroneScript = preload("res://scripts/enemies/training_drone.gd")
const WaveDirectorScript = preload("res://scripts/waves/wave_director.gd")
const TouchControlsScript = preload("res://scripts/ui/hud/touch_controls.gd")
const RunStatsScript = preload("res://scripts/progression/run_stats.gd")
const RewardServiceScript = preload("res://scripts/progression/reward_service.gd")
const RunUpgradeManagerScript = preload("res://scripts/progression/run_upgrade_manager.gd")
const ProgressionServiceScript = preload("res://scripts/progression/progression_service.gd")
const RecoveryCacheVisualScript = preload("res://scripts/worlds/recovery_cache_visual.gd")
const FieldActivityDirectorScript = preload("res://scripts/worlds/field_activity_director.gd")
const DEFEAT_REVEAL_SECONDS := 1.55
const DEFEAT_HOLD_DRAWN_FRAMES := 6
const RECOVERY_LOCAL_RADIUS := 22.0
const RECOVERY_STUCK_SECONDS := 12.0

## Test/authoring override only: the shipped scene starts in safe Explore.
@export var start_wave_session_on_ready: bool = false
## Field activity mode: "auto" on real displays, headless skips, "force" opts tests in.
@export_enum("auto", "force", "off") var field_activity_mode: String = "auto"
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

## TECH HUNT 0 orchestrates here; WaveDirector and ProgressionService own encounters and rewards.
var _recovery_caches: Array[RecoveryCacheDefinition] = []
var _recovery_states: Dictionary = {}
var _recovery_visuals: Dictionary = {}
var _recovery_root: Node3D
var _recovery_action_cache: StringName = &""
var _recovery_notices: Array[Dictionary] = []
var _recovery_choice_presented: bool = false
var _recovery_return_mode: SessionMode = SessionMode.EXPLORE
var _recovery_guidance_stage: String = "area"
var _recovery_stuck_seconds: float = 0.0
var _recovery_anchor_dist: float = INF
var _recovery_tracked_target: StringName = &""
var _recovery_stuck_notified: bool = false
var _recovery_qa_enabled: bool = false
var _recovery_qa_timer: float = 0.0
var _extracting: bool = false
var _run_banked: bool = false
var _device_profiler: Node
var _field_activity: FieldActivityDirector
var _profiler_context := ""
var _profiler_context_seconds := 0.0

@onready var player: PlayerControllerScript = $Player
@onready var training_drone: TrainingDroneScript = $TrainingDrone
@onready var wave_director: WaveDirectorScript = $WaveDirector
@onready var run_stats: RunStatsScript = $RunStats
@onready var reward_service: RewardServiceScript = $RewardService
@onready var run_upgrade_manager: RunUpgradeManagerScript = $RunUpgradeManager
@onready var progression_service: ProgressionServiceScript = $ProgressionService
@onready var touch_controls: TouchControlsScript = $HUD/TouchControls


## Builds the F10 review rig only on desktop debug or embedded Web QA.
func _add_qa_rig() -> void:
	if not ((OS.is_debug_build() and not OS.has_feature("android")) or OS.has_feature("web")):
		return
	var rig_script: GDScript = load("res://scripts/qa/world_tour.gd")
	if rig_script == null:
		return
	var rig: Node = rig_script.new()
	rig.name = "WorldTour"
	add_child(rig)


func _add_device_profiler() -> void:
	if not OS.has_feature("android"):
		return
	if not (
		OS.is_debug_build()
		or OS.has_feature("device_profile")
		or OS.get_cmdline_user_args().has("--device-profile")
	):
		return
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
	const PHASES := ["explore", "preparing", "defense", "results", "mission_complete"]
	var phase: String = PHASES[clampi(int(session_mode), 0, PHASES.size() - 1)]
	var enemies := wave_director.active_enemy_count + wave_director.active_guard_count
	var context := "%s/%d/%d" % [phase, wave_director.current_wave, enemies]
	if context != _profiler_context:
		_profiler_context = context
		_device_profiler.call("set_context", phase, wave_director.current_wave, enemies)


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
	touch_controls.armory_weapon_upgrade_requested.connect(_on_armory_weapon_upgrade)
	touch_controls.armory_module_action_requested.connect(_on_armory_module_action)
	touch_controls.armory_close_requested.connect(_close_armory)
	touch_controls.upgrade_open_requested.connect(_open_run_upgrades)
	touch_controls.upgrade_choice_requested.connect(_on_run_upgrade_chosen)
	touch_controls.upgrade_close_requested.connect(_close_run_upgrades)
	run_upgrade_manager.state_changed.connect(_on_run_upgrades_changed)
	run_upgrade_manager.choices_ready.connect(_on_run_upgrade_choices_ready)
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
	_setup_field_activity()
	print(
		(
			"Operative: hero=%s vitals=%d reduction=%d%%"
			% [
				progression_service.selected_hero_id,
				roundi(player.max_health),
				roundi(player.tier_damage_reduction() * 100.0),
			]
		)
	)
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
	player.overshield_changed.connect(
		func(c: float, m: float) -> void: HudResourceBar.sync_overshield(touch_controls, c, m)
	)
	player.overcharge_changed.connect(
		func(sec: float) -> void: HudResourceBar.sync_overcharge(touch_controls, sec)
	)
	player.damage_received.connect(_on_player_damage_received)
	player.defeated.connect(_on_player_defeated)
	training_drone.health_changed.connect(_on_combatant_health_changed)
	training_drone.damage_received.connect(_on_target_damage_received)
	wave_director.progress_changed.connect(_update_status)
	run_stats.stats_changed.connect(_update_status)
	wave_director.wave_started.connect(_on_wave_started)
	wave_director.wave_completed.connect(_on_wave_completed)
	reward_service.wave_rewarded.connect(_on_wave_rewarded)
	wave_director.enemy_spawned.connect(_on_wave_enemy_spawned)
	wave_director.guardian_spawned.connect(_on_guardian_spawned)
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
	# One log line per session proves audio came up in the exported build.
	print(Sfx.describe())
	if start_wave_session_on_ready:
		# Explicit opt-in for automated fixtures; never enabled in main.tscn.
		_request_defense()
	_apply_qa_hooks()


func _apply_qa_hooks() -> void:
	if not OS.has_feature("web"):
		return
	var query := str(JavaScriptBridge.eval("location.search || ''"))
	_recovery_qa_enabled = query.contains("qa_recovery")
	if query.contains("qa_upgrade=1"):
		run_upgrade_manager.set_seed(7)
		run_upgrade_manager.record_milestone("qa_upgrade")
	if query.contains("qa_guardian=1"):
		wave_director.guardian_first_wave = 1
		wave_director.guardian_every_n_waves = 1
		wave_director.base_enemies_per_wave = 2
		wave_director.initial_spawn_delay = 0.1
		defense_preparation_seconds = 0.2
		_request_defense()


func _process(delta: float) -> void:
	touch_controls.set_aim_state(player.is_aiming())
	_tick_recovery_guidance(delta)
	_update_recovery()
	_emit_recovery_cache_qa(delta)
	if _pending_defeat_wave >= 0:
		_defeat_reveal_remaining = maxf(_defeat_reveal_remaining - delta, 0.0)
		if _defeat_reveal_remaining <= 0.0:
			if _defeat_hold_drawn_at < 0:
				_defeat_hold_drawn_at = Engine.get_frames_drawn()
				_defeat_hold_process_at = Engine.get_process_frames()
			# Slow WebGL can simulate the whole 1.2 s Blender fall between two frames; hold its final
			# pose for real rendered frames.
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
	if Input.is_action_just_pressed("open_upgrades"):
		_open_run_upgrades()
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


## Audio mute is owned here (not the HUD): button and M key share one path, and the label mirrors
## real audio state.
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
	player.weapon_controller.set_weapon_tiers(progression_service.weapon_tiers)
	player.set_tech_modifiers(
		TechModuleDefinition.aggregate_modifiers(progression_service.equipped_modules)
	)
	if is_instance_valid(run_upgrade_manager) and run_upgrade_manager.total_stacks() > 0:
		player.apply_run_modifiers(run_upgrade_manager.get_modifiers(), 0.0, false)
	var op_hero := progression_service.selected_hero_id
	HudEncounterUi.set_operative_telemetry(
		touch_controls, roundi(HeroTier.reduction(op_hero)), op_hero, HeroTier.skill_id(op_hero)
	)
	(
		HudArmoryBridge
		. refresh(
			touch_controls,
			progression_service.balance,
			progression_service.best_score,
			progression_service.unlocked_ids,
			player.weapon_controller.get_current_definition().weapon_id,
			progression_service.weapon_tiers,
			progression_service.blueprint_ids,
			progression_service.module_blueprints,
			progression_service.unlocked_modules,
			progression_service.equipped_modules,
		)
	)
	touch_controls.set_weapon_label(player.get_current_weapon_name())
	touch_controls.set_weapon_tier(
		progression_service.weapon_tier(player.weapon_controller.get_current_definition().weapon_id)
	)
	touch_controls._update_weapon_ammo(
		player.weapon_controller.get_current_ammo(),
		player.weapon_controller.get_current_magazine_size(),
		player.weapon_controller.is_reloading()
	)
	_sync_resource_hud()


## The front end's launch weapon takes effect here, once on boot, so a mid-run armory swap is
## never overwritten.
func _apply_saved_weapon() -> void:
	var wanted := progression_service.selected_weapon_id
	if wanted == &"" or not progression_service.is_unlocked(wanted):
		return
	for index in range(player.weapon_controller.weapon_definitions.size()):
		var definition: WeaponDefinition = player.weapon_controller.weapon_definitions[index]
		if definition != null and definition.weapon_id == wanted:
			player.select_weapon(index)
			return


## World owns the authored spawn; Main applies it after MissionWorld's selection resolver (legacy
## defs inherit main.tscn's position).
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


func _open_run_upgrades() -> void:
	if (
		session_mode in [SessionMode.RESULTS, SessionMode.MISSION_COMPLETE]
		or player.is_defeated()
		or _is_paused
		or not run_upgrade_manager.has_pending_choice()
	):
		return
	_toggle_pause()
	HudUpgradeBridge.show_panel(
		touch_controls, run_upgrade_manager.get_pending_choices(), run_upgrade_manager
	)
	print("HUD: run upgrades opened")


func _close_run_upgrades() -> void:
	HudUpgradeBridge.hide_panel(touch_controls)
	if _is_paused:
		_toggle_pause()


func _on_run_upgrade_chosen(index: int) -> void:
	var chosen := run_upgrade_manager.select_choice(index)
	if chosen == null:
		return
	(
		player
		. apply_run_modifiers(
			run_upgrade_manager.get_modifiers(),
			chosen.instant_heal_on_pick,
			chosen.refill_magazine_on_pick,
		)
	)
	var stacks := run_upgrade_manager.stack_count(chosen.upgrade_id)
	Sfx.play_ui(&"session_clear")
	_update_status()
	if run_upgrade_manager.has_pending_choice():
		HudUpgradeBridge.show_panel(
			touch_controls, run_upgrade_manager.get_pending_choices(), run_upgrade_manager
		)
	else:
		_close_run_upgrades()
	touch_controls._feedback_panel.show_message(
		AegisText.t("hud.upg_applied_toast", ["%s L%d" % [chosen.short_tag, stacks]])
	)


func _on_run_upgrades_changed() -> void:
	HudUpgradeBridge.refresh(touch_controls, run_upgrade_manager)


func _on_run_upgrade_choices_ready(
	_choices: Array[RunUpgradeDefinition], evolution_level: int
) -> void:
	HudUpgradeBridge.refresh(touch_controls, run_upgrade_manager)
	print("RunUpgrade: ready level=%d" % evolution_level)


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
		touch_controls._armory_panel.show_hint_key("armory.now_equipped", [weapon_name.to_upper()])
		return
	if (
		ProgressionService.BLUEPRINT_REQUIRED.has(weapon_id)
		and not progression_service.has_blueprint(weapon_id)
	):
		touch_controls._armory_panel.show_hint_key("recovery.blueprint_required")
		return
	var missing := progression_service.unlock_cost(weapon_id) - progression_service.balance
	if missing > 0:
		touch_controls._armory_panel.show_hint_key("armory.need_bp", [missing])
		return
	if progression_service.unlock_weapon(weapon_id):
		player.select_weapon(weapon_index)
		print("Armory: unlocked " + String(weapon_id))
		Sfx.play_ui(&"session_clear")
		touch_controls._armory_panel.show_hint_key("armory.now_unlocked", [weapon_name.to_upper()])


func _on_armory_weapon_upgrade(weapon_id: StringName) -> void:
	if not touch_controls._armory_panel.visible or not progression_service.is_unlocked(weapon_id):
		return
	var current := progression_service.weapon_tier(weapon_id)
	if current >= WeaponTier.tier_count():
		touch_controls._armory_panel.show_hint_key("armory.upgrade_max")
		return
	var cost := progression_service.weapon_upgrade_cost(weapon_id)
	var missing := cost - progression_service.balance
	if missing > 0:
		touch_controls._armory_panel.show_hint_key("armory.upgrade_need", [missing])
		return
	if progression_service.upgrade_weapon(weapon_id):
		var next := progression_service.weapon_tier(weapon_id)
		print("Armory: upgraded %s to tier %d" % [String(weapon_id), next])
		Sfx.play_ui(&"session_clear")
		touch_controls._armory_panel.show_hint_key("armory.upgraded", [next])


func _on_armory_module_action(module_id: StringName) -> void:
	var def := TechModuleDefinition.get_definition(module_id)
	if def == null or not touch_controls._armory_panel.visible:
		return
	var panel := touch_controls._armory_panel
	if progression_service.unlocked_modules.has(String(module_id)):
		var was_eq := progression_service.equipped_modules.has(module_id)
		if (
			not was_eq
			and (
				progression_service.equipped_modules.size()
				>= ProgressionService.MAX_EQUIPPED_MODULES
			)
		):
			panel.show_hint_key("armory.mod_slots_full", [ProgressionService.MAX_EQUIPPED_MODULES])
			return
		if progression_service.toggle_module(module_id):
			Sfx.play_ui(&"ui_click")
			panel.show_hint_key(
				"armory.mod_unequipped" if was_eq else "armory.now_equipped", [def.display_title()]
			)
		return
	if not progression_service.has_blueprint(module_id):
		panel.show_hint_key("armory.mod_bp_required", [def.display_source_world()])
		return
	var missing := def.unlock_cost - progression_service.balance
	if missing > 0:
		panel.show_hint_key("armory.need_bp", [missing])
		return
	if progression_service.unlock_module(module_id):
		if progression_service.equipped_modules.size() < ProgressionService.MAX_EQUIPPED_MODULES:
			progression_service.toggle_module(module_id)
		Sfx.play_ui(&"session_clear")
		panel.show_hint_key("armory.now_unlocked", [def.display_title()])


func _toggle_pause() -> void:
	if session_mode in [SessionMode.MISSION_COMPLETE, SessionMode.RESULTS]:
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
	var active_guards := _active_recovery_guard_count()
	if active_guards > 0:
		# Do not mix an unresolved TECH HUNT encounter with a generic wave. The
		# player can still fight, use a ready cache, or reset from Pause.
		touch_controls._feedback_panel.show_message(
			AegisText.t("recovery.guards_active", [active_guards])
		)
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
	run_upgrade_manager.reset_run()
	HudUpgradeBridge.refresh(touch_controls, run_upgrade_manager)
	session_mode = SessionMode.EXPLORE
	_reset_recovery()
	if is_instance_valid(_field_activity):
		_field_activity.reset_field_activity()
	HudResourceBar.clear_toast_feed(touch_controls)
	Sfx.set_music_mode(&"explore")
	touch_controls.hide_results()
	touch_controls.set_player_down(false)
	touch_controls.set_paused(false)
	touch_controls._set_play_phase("explore")
	_update_status()
	print("Encounter: Returned to Explore")


## Every in-game HOME lands here; DashboardReturn picks the web lobby or DASHBOARD stage so this
## scene never knows the build.
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
	_recovery_guidance_stage = "area"
	_recovery_stuck_seconds = 0.0
	_recovery_anchor_dist = INF
	_recovery_tracked_target = &""
	_recovery_stuck_notified = false
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
	var fallback: RecoveryCacheDefinition = null
	for cache in _recovery_caches:
		if not cache.optional:
			fallback = cache
			if _cache_state(cache.cache_id) != RecoveryState.SECURED:
				return cache
	return fallback


func _optional_cache() -> RecoveryCacheDefinition:
	var fallback: RecoveryCacheDefinition = null
	for cache in _recovery_caches:
		if cache.optional:
			fallback = cache
			if _cache_state(cache.cache_id) != RecoveryState.SECURED:
				return cache
	return fallback


func _all_primary_caches_secured() -> bool:
	var has_primary := false
	for cache in _recovery_caches:
		if not cache.optional:
			has_primary = true
			if not progression_service.is_cache_secured(cache.cache_id):
				return false
	return has_primary


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


func _active_recovery_guard_count() -> int:
	var count := 0
	for cache in _recovery_caches:
		count += wave_director.guard_group_size(cache.cache_id)
	return count


func recovery_guidance_stage() -> String:
	return _recovery_guidance_stage


func advance_recovery_guidance(seconds: float) -> void:
	_tick_recovery_guidance(maxf(seconds, 0.0))
	_update_recovery()


func _active_guidance_cache() -> RecoveryCacheDefinition:
	var ready_best: RecoveryCacheDefinition = null
	var ready_dist := INF
	for cache in _recovery_caches:
		if _cache_state(cache.cache_id) == RecoveryState.READY:
			var d := _cache_distance(cache)
			if d < ready_dist:
				ready_dist = d
				ready_best = cache
	if ready_best != null:
		return ready_best
	var primary := _primary_cache()
	if primary != null and _cache_state(primary.cache_id) != RecoveryState.SECURED:
		return primary
	var optional := _optional_cache()
	if optional != null and _cache_state(optional.cache_id) != RecoveryState.SECURED:
		return optional
	return null


func _nearest_active_guard() -> Node3D:
	var best: Node3D = null
	var best_sq := INF
	for cache in _recovery_caches:
		for candidate in wave_director.get_guard_group(cache.cache_id):
			var enemy := candidate as Node3D
			if not is_instance_valid(enemy):
				continue
			if enemy.has_method("is_defeated") and bool(enemy.call("is_defeated")):
				continue
			var sq := player.global_position.distance_squared_to(enemy.global_position)
			if sq < best_sq:
				best_sq = sq
				best = enemy
	return best


func _relative_bearing_label(world_pos: Vector3) -> String:
	var to_target := Vector3(
		world_pos.x - player.global_position.x,
		0.0,
		world_pos.z - player.global_position.z,
	)
	if to_target.length_squared() < 0.04:
		return AegisText.t("recovery.dir_ahead")
	to_target = to_target.normalized()
	var basis := player.camera_rig.get_yaw_basis()
	var forward := -basis.z
	forward.y = 0.0
	forward = forward.normalized() if forward.length_squared() > 0.0001 else Vector3.FORWARD
	var right := basis.x
	right.y = 0.0
	right = right.normalized() if right.length_squared() > 0.0001 else Vector3.RIGHT
	var deg := rad_to_deg(atan2(to_target.dot(right), to_target.dot(forward)))
	var key := "recovery.dir_behind"
	if absf(deg) <= 28.0:
		key = "recovery.dir_ahead"
	elif deg < -28.0 and deg >= -75.0:
		key = "recovery.dir_ahead_left"
	elif deg < -75.0 and deg >= -135.0:
		key = "recovery.dir_left"
	elif deg > 28.0 and deg <= 75.0:
		key = "recovery.dir_ahead_right"
	elif deg > 75.0 and deg <= 135.0:
		key = "recovery.dir_right"
	return AegisText.t(key)


func _reset_guidance_stuck() -> void:
	_recovery_stuck_seconds = 0.0
	_recovery_stuck_notified = false


func _tick_recovery_guidance(delta: float) -> void:
	if (
		_recovery_caches.is_empty()
		or _is_paused
		or player.is_defeated()
		or session_mode not in [SessionMode.EXPLORE, SessionMode.DEFENSE]
	):
		return
	var target := _active_guidance_cache()
	if target == null:
		_reset_guidance_stuck()
		_recovery_anchor_dist = INF
		return
	var guard := _nearest_active_guard()
	var focus_pos := guard.global_position if guard != null else target.position
	var dist := (
		Vector2(player.global_position.x - focus_pos.x, player.global_position.z - focus_pos.z)
		. length()
	)
	if _recovery_tracked_target != target.cache_id or not is_finite(_recovery_anchor_dist):
		_recovery_tracked_target = target.cache_id
		_recovery_anchor_dist = dist
		_reset_guidance_stuck()
		return
	if guard == null and dist <= target.interaction_radius:
		_recovery_anchor_dist = dist
		_reset_guidance_stuck()
		return
	if dist < _recovery_anchor_dist - 1.25:
		_recovery_anchor_dist = dist
		_reset_guidance_stuck()
		return
	if dist > _recovery_anchor_dist + 2.0:
		_recovery_anchor_dist = dist
	_recovery_stuck_seconds += delta
	if _recovery_stuck_seconds >= RECOVERY_STUCK_SECONDS and not _recovery_stuck_notified:
		_recovery_stuck_notified = true
		var dir_lbl := _relative_bearing_label(focus_pos)
		var msg := AegisText.t("recovery.stuck_toast", [dir_lbl, roundi(dist)])
		touch_controls._feedback_panel.show_message(msg)


func _emit_recovery_cache_qa(delta: float) -> void:
	if (
		not _recovery_qa_enabled
		or _recovery_caches.is_empty()
		or _is_paused
		or player.is_defeated()
		or not is_instance_valid(player.aim_camera)
		or session_mode not in [SessionMode.EXPLORE, SessionMode.DEFENSE]
	):
		return
	_recovery_qa_timer = maxf(_recovery_qa_timer - delta, 0.0)
	if _recovery_qa_timer > 0.0:
		return
	_recovery_qa_timer = 0.25
	var target := _active_guidance_cache()
	if target == null:
		return
	var focus := target.position + Vector3(0.0, 1.0, 0.0)
	var screen := player.aim_camera.unproject_position(focus)
	var vp_size := player.aim_camera.get_viewport().get_visible_rect().size
	print(
		(
			"Recovery Cache QA: id=%s x=%.2f y=%.2f behind=%s dist=%.1f vp=%.0fx%.0f"
			% [
				target.cache_id,
				screen.x,
				screen.y,
				"yes" if player.aim_camera.is_position_behind(focus) else "no",
				_cache_distance(target),
				vp_size.x,
				vp_size.y,
			]
		)
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
	var active_guards := _active_recovery_guard_count()
	var is_stuck := _recovery_stuck_seconds >= RECOVERY_STUCK_SECONDS
	var focus_cache := nearest if nearest != null else _active_guidance_cache()
	for cache in _recovery_caches:
		var visual := _recovery_visuals.get(cache.cache_id) as Node3D
		if visual != null:
			var is_target := (
				focus_cache != null
				and cache.cache_id == focus_cache.cache_id
				and _cache_state(cache.cache_id) != RecoveryState.SECURED
			)
			visual.call("set_guidance_focus", is_target, is_target and is_stuck)
	var compass_cache: RecoveryCacheDefinition = nearest
	if nearest != null:
		title = nearest.display_name
		var guards := wave_director.guard_group_size(nearest.cache_id)
		state_text = (
			AegisText.t("recovery.guards_remaining", [guards])
			if guards > 0
			else _recovery_state_text(nearest)
		)
		detail = "%s · %d m" % [_recovery_reward_text(nearest), roundi(nearest_distance)]
		_recovery_guidance_stage = "combat" if active_guards > 0 else "interact"
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
			_recovery_guidance_stage = "complete"
		compass_cache = target
		if target != null:
			var target_dist := _cache_distance(target)
			var dist_m := roundi(target_dist)
			var bearing := _relative_bearing_label(target.position)
			if is_stuck:
				_recovery_guidance_stage = "stuck"
				detail = "%s · %s %dM" % [_recovery_reward_text(target), bearing, dist_m]
				state_text = AegisText.t("recovery.stuck_waypoint", [bearing, dist_m])
			elif target_dist <= RECOVERY_LOCAL_RADIUS:
				_recovery_guidance_stage = "local"
				detail = (
					"%s · %s"
					% [
						_recovery_reward_text(target),
						AegisText.t("recovery.local_approach", [bearing, dist_m]),
					]
				)
				state_text = "%s · %s" % [target.landmark_name, bearing]
			else:
				_recovery_guidance_stage = "area"
				detail = "%s · %s %dM" % [_recovery_reward_text(target), bearing, dist_m]
				state_text = "%s · %s" % [target.landmark_name, bearing]
	if active_guards > 0 and action.is_empty():
		_recovery_guidance_stage = "stuck" if is_stuck else "combat"
		# Landscape hides the tertiary badge: put the active encounter in the always-visible detail
		# row instead.
		detail = AegisText.t("recovery.guards_active", [active_guards])
		var guard := _nearest_active_guard()
		if guard != null:
			var g_dist := roundi(
				(
					Vector2(
						player.global_position.x - guard.global_position.x,
						player.global_position.z - guard.global_position.z
					)
					. length()
				)
			)
			var g_dir := _relative_bearing_label(guard.global_position)
			state_text = (
				AegisText
				. t(
					"recovery.stuck_waypoint" if is_stuck else "recovery.guard_bearing",
					[g_dir, g_dist],
				)
			)
		else:
			state_text = AegisText.t("recovery.guards_remaining", [active_guards])
	touch_controls.set_recovery_status(
		title,
		detail,
		state_text,
		action,
		active_guards,
		_recovery_guidance_stage,
		compass_cache != null and _cache_state(compass_cache.cache_id) != RecoveryState.SECURED,
		compass_cache.position if compass_cache != null else Vector3.ZERO
	)


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
	if cache.module_id != &"":
		var mod_def := TechModuleDefinition.get_definition(cache.module_id)
		var mod_name := (
			mod_def.display_title() if mod_def != null else String(cache.module_id).to_upper()
		)
		return AegisText.t("recovery.module_reward", [mod_name])
	if cache.blueprint_id != &"":
		var weapon := WeaponDefinition.load_definition(cache.blueprint_id)
		var weapon_name := (
			String(cache.blueprint_id).to_upper()
			if weapon == null
			else weapon.display_name.to_upper()
		)
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
			_reset_guidance_stuck()
			wave_director.spawn_guard_group(cache.cache_id, cache.guard_spawns)
			if wave_director.guard_group_size(cache.cache_id) > 0:
				run_stats.start_run()
		RecoveryState.READY:
			_reset_guidance_stuck()
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
		cache.cache_id, cache.reward_id, cache.blueprint_id, cache.bp_reward, cache.module_id
	):
		return false
	_recovery_states[cache.cache_id] = RecoveryState.SECURED
	if cache.module_id != &"":
		_recovery_notices.append({"kind": "module", "module": cache.module_id})
	elif cache.blueprint_id != &"":
		_recovery_notices.append({"kind": "blueprint", "weapon": cache.blueprint_id})
	elif cache.bp_reward > 0:
		_recovery_notices.append({"kind": "bp", "amount": cache.bp_reward})
	_refresh_recovery_visual(cache)
	Sfx.play_ui(&"session_clear")
	touch_controls._feedback_panel.show_message(
		AegisText.t("recovery.secured_feedback", [cache.display_name])
	)
	HudResourceBar.push_toast(
		touch_controls, "◈ CACHE SECURED · %s" % cache.display_name.to_upper(), AegisTokens.OK
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
	if run_upgrade_manager.total_evolutions_claimed_or_queued() == 0:
		run_upgrade_manager.record_milestone("guard:" + String(group_id))
	_reset_guidance_stuck()
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
	if primary == null or _recovery_choice_presented or not _all_primary_caches_secured():
		return
	_recovery_choice_presented = true
	_recovery_return_mode = session_mode
	session_mode = SessionMode.MISSION_COMPLETE
	_is_paused = true
	get_tree().paused = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	Sfx.set_music_mode(&"results")
	touch_controls._set_play_phase("results")
	var opt_bp := 0
	for cache in _recovery_caches:
		if cache.optional and progression_service.is_cache_secured(cache.cache_id):
			opt_bp += cache.bp_reward
	var primary_unlocked := (
		progression_service.unlocked_modules.has(String(primary.module_id))
		if primary.module_id != &""
		else progression_service.is_unlocked(&"arc_shooter")
	)
	(
		touch_controls
		. show_extraction_choice(
			progression_service.balance,
			primary_unlocked,
			progression_service.completed_runs,
			opt_bp,
			primary.module_id,
		)
	)


func _continue_to_endless() -> void:
	if session_mode != SessionMode.MISSION_COMPLETE:
		return
	var return_mode := _recovery_return_mode
	wave_director.set_endless_mode(true)
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
	return (
		HudMenuUi
		. format_recovery_summary(
			{
				"notices": _recovery_notices,
				"run_banked": _run_banked,
				"hero_id": String(progression_service.selected_hero_id),
				"has_caches": not _recovery_caches.is_empty(),
				"completed_runs": progression_service.completed_runs,
				"run_mods": run_upgrade_manager.active_tags_summary(),
				"extracting": _extracting,
				"guardians_defeated": run_stats.guardians_defeated,
				"endless_wave": wave_director.current_wave if wave_director.endless_mode else 0,
			}
		)
	)


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
	if is_instance_valid(_field_activity):
		_field_activity.clear_patrols()
	wave_director.end_session()
	_update_status()


func _on_target_damage_received(_amount: float, _current: float, _maximum: float) -> void:
	_reset_guidance_stuck()
	Sfx.play_ui(&"hit_confirm")
	touch_controls.show_hit_confirmed()


func _on_skill_used(targets_hit: int, _cooldown_seconds: float) -> void:
	Sfx.play_3d(&"skill_pulse", player.global_position)
	touch_controls.show_skill_feedback(targets_hit, player.active_skill_id())


func _on_combatant_health_changed(_current: float, _maximum: float) -> void:
	_update_status()


func _on_wave_started(_wave_index: int, _enemy_count: int) -> void:
	# Also covers smoke fixtures that call start_session() directly; the practice drone is Explore-
	# only.
	training_drone.set_active(false)
	session_mode = SessionMode.DEFENSE
	Sfx.set_music_mode(&"defense")
	touch_controls._set_play_phase("defense")
	Sfx.play_ui(&"wave_start")
	run_stats.start_run()
	_update_status()


func _on_wave_completed(wave_index: int) -> void:
	reward_service.award_wave_completion(wave_index, wave_director.is_guardian_wave(wave_index))
	_update_status()


func _on_enemy_rewarded(enemy: Node3D, _score_reward: int, bp_reward: int) -> void:
	# A real KO deserves an immediate outcome even if the player cannot finish
	# the wave. The same earned reward appears in Results and the browser log.
	touch_controls._feedback_panel.show_message(AegisText.t("hud.target_down_bp", [bp_reward]))
	run_upgrade_manager.record_elimination(enemy)
	var is_guardian := enemy.is_in_group("guardian_enemies")
	var archetype := "RUNNER"
	if is_guardian:
		archetype = "GUARDIAN"
		run_upgrade_manager.record_milestone("guardian_%d" % enemy.get_instance_id())
	elif enemy.is_in_group("enforcer_enemies"):
		archetype = "ENFORCER"
	elif enemy.is_in_group("shooter_enemies"):
		archetype = "SHOOTER"
	if is_instance_valid(_field_activity):
		_field_activity.spawn_enemy_drops(enemy, is_guardian)
	HudResourceBar.push_toast(
		touch_controls, "◆ +%d BP · %s KO" % [bp_reward, archetype], AegisTokens.ACCENT
	)
	print("Encounter: %s KO · +%d BP" % [archetype, bp_reward])


func _on_wave_rewarded(wave_index: int, bp_reward: int) -> void:
	# Only show the award once it was actually applied, not before the reward
	# service has checked its per-wave duplicate guard.
	touch_controls._feedback_panel.show_message(
		AegisText.t("hud.wave_clear_bp", [wave_index, bp_reward])
	)


func _on_wave_enemy_spawned(enemy: Node3D) -> void:
	if enemy.has_signal("damage_received"):
		enemy.connect("damage_received", _on_target_damage_received)
	if enemy.is_in_group("guardian_enemies"):
		enemy.connect("health_changed", _on_combatant_health_changed)
		if enemy.has_signal("phase_changed"):
			enemy.connect("phase_changed", func(_p: StringName) -> void: _update_status())
		if enemy.has_signal("shield_broken"):
			enemy.connect("shield_broken", _on_guardian_shield_broken)
		_update_status()


func _on_guardian_spawned(_guardian: Node3D, wave_index: int) -> void:
	touch_controls._feedback_panel.show_message(AegisText.t("hud.guardian_alert"))
	print("Encounter: Guardian deployed (wave %d)" % wave_index)
	_update_status()


func _on_guardian_shield_broken(_by_emp: bool) -> void:
	touch_controls._feedback_panel.show_message(AegisText.t("hud.guardian_exposed_toast"))
	_update_status()


func _on_wave_session_ended(wave_index: int, _total_defeated: int) -> void:
	var was_defense := (
		session_mode == SessionMode.DEFENSE
		or (_extracting and _recovery_return_mode == SessionMode.DEFENSE)
	)
	var should_bank := (
		was_defense or _extracting or (player.is_defeated() and run_stats.bp_earned > 0)
	)
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
				"Progression: banked +%d BP · wallet %d · best %d · runs %d"
				% [
					run_stats.bp_earned,
					progression_service.balance,
					progression_service.best_score,
					progression_service.completed_runs,
				]
			)
		)
	if was_defense and player.is_defeated():
		# Let the authored 1.2 s collapse render before results: stop AI and bank first.
		_pending_defeat_wave = wave_index
		_defeat_reveal_remaining = DEFEAT_REVEAL_SECONDS
		_update_status()
		print("Encounter: Defeat reveal before Results")
		return
	_present_results(wave_index)


func _present_results(wave_index: int) -> void:
	touch_controls._set_play_phase("results")
	touch_controls.set_results_context(
		_extracting, progression_service.has_blueprint(&"arc_shooter")
	)
	touch_controls.show_results(
		wave_index,
		run_stats.get_survival_time_text(),
		run_stats.eliminations,
		run_stats.run_score,
		run_stats.bp_earned,
		progression_service.balance,
		progression_service.best_score,
		progression_service.unlocked_ids,
		player.is_defeated(),
		_recovery_result_summary()
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
	HudResourceBar.sync_overshield(touch_controls, player.current_overshield, player.max_overshield)
	_sync_resource_hud()
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
	var guardian := wave_director.get_active_guardian()
	if guardian != null:
		var g_hp := float(guardian.get("current_health"))
		var g_max := float(guardian.get("max_health"))
		var g_phase: String = (
			String(guardian.call("get_phase_id"))
			if guardian.has_method("get_phase_id")
			else "fortified"
		)
		HudEncounterUi.set_guardian_status(touch_controls, true, g_hp, g_max, g_phase)
	else:
		HudEncounterUi.set_guardian_status(touch_controls, false, 0.0, 0.0, "fortified")
	touch_controls.set_status(status)


func _setup_field_activity() -> void:
	var headless := DisplayServer.get_name() == "headless"
	if field_activity_mode == "off" or (field_activity_mode == "auto" and headless):
		return
	_field_activity = FieldActivityDirectorScript.new()
	add_child(_field_activity)
	_field_activity.pickup_collected.connect(_on_field_pickup_collected)
	_field_activity.supply_crate_broken.connect(_on_supply_crate_broken)
	_field_activity.patrol_robot_defeated.connect(_on_patrol_robot_defeated)
	_field_activity.field_target_hit.connect(_on_target_damage_received.bind(0.0, 0.0, 0.0))
	_field_activity.configure(player)


func _sync_resource_hud() -> void:
	if not is_instance_valid(touch_controls) or not is_instance_valid(progression_service):
		return
	var secured_count := 0
	for cache in _recovery_caches:
		if cache != null and progression_service.is_cache_secured(cache.cache_id):
			secured_count += 1
	HudResourceBar.sync_telemetry(
		touch_controls,
		progression_service.balance,
		run_stats.bp_earned if is_instance_valid(run_stats) else 0,
		run_stats.cryo_alloy if is_instance_valid(run_stats) else 0,
		secured_count,
		maxi(_recovery_caches.size(), 4)
	)


func _on_field_pickup_collected(kind: StringName, amount: int, _pos: Vector3) -> void:
	var note := FieldActivityDirectorScript.apply_pickup_effect(
		kind, amount, player, run_stats, run_upgrade_manager
	)
	HudResourceBar.push_toast(touch_controls, str(note["text"]), note["color"] as Color)
	_update_status()


func _on_supply_crate_broken(_pos: Vector3, tier: int) -> void:
	run_stats.record_crate_broken(60 if tier == 2 else 40)
	HudResourceBar.push_toast(touch_controls, "▣ SUPPLY CACHE BREACHED", AegisTokens.ACCENT)
	_update_status()


func _on_patrol_robot_defeated(
	score_reward: int, bp_reward: int, _pos: Vector3, kind_id: StringName
) -> void:
	if run_stats.is_run_active:
		run_stats.record_elimination(score_reward, bp_reward)
	else:
		run_stats.collect_field_bp(bp_reward, score_reward)
	var msg := "◆ +%d BP · %s PATROL KO" % [bp_reward, String(kind_id).to_upper()]
	HudResourceBar.push_toast(touch_controls, msg, AegisTokens.ACCENT)
	_update_status()
