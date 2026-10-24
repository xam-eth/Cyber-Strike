## MAIN DASHBOARD: the hub the player returns to between runs.
##
## Every number here comes from ProgressionService, which is the only owner of
## the persistent profile. There is no "profile level", no streak counter and no
## daily reward: the save file holds Battle Points, best score, completed runs,
## unlocks and the last loadout, so those five things are what the dashboard
## shows. Adding a sixth row would mean inventing data the game does not track.
##
## Every button does something:
##   DEPLOY       starts the loadout chain HERO -> WEAPON -> WORLD -> PRELOAD
##   ARMORY       the in-game shop widget, spending real BP for real unlocks
##   SETTINGS     the shared AegisSettingsMenu, which writes user://aegis.cfg
##   REPLAY INTRO clears intro_seen, which is how the cinematic can be seen
##                again without wiping a profile
extends MenuStage

var _balance: Label
var _best: Label
var _runs: Label
var _loadout: Label
var _armory: ArmoryUi
var _settings: AegisSettingsMenu
var _armory_hint_owner: bool = false
## The four blocks the layout is built from. Portrait stacks them in `_stack`;
## landscape moves them into `_split` so the stats sit beside the actions
## instead of above them -- the stack is ~500 px tall and a landscape phone is
## 390 px, which is what pushed DEPLOY past the bottom edge.
var _stack: VBoxContainer
var _split: HBoxContainer
var _left: VBoxContainer
var _right: VBoxContainer
var _mark: TextureRect
var _stats: AegisPanel
var _actions: VBoxContainer
var _spacer: Control
var _landscape_built := false


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(make_backdrop("res://assets/ui/dashboard_bg.jpg"))

	var scrim := ColorRect.new()
	scrim.color = Color(AegisTokens.VOID, 0.55)
	scrim.set_anchors_preset(Control.PRESET_FULL_RECT)
	scrim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(scrim)

	_margin = MarginContainer.new()
	_margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	_margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_margin)

	_stack = VBoxContainer.new()
	physical_separation(_stack, 18)
	_margin.add_child(_stack)

	_split = HBoxContainer.new()
	_split.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_split.size_flags_vertical = Control.SIZE_EXPAND_FILL
	physical_separation(_split, 18)
	_left = VBoxContainer.new()
	physical_separation(_left, 18)
	_left.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_right = VBoxContainer.new()
	physical_separation(_right, 12)
	_right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_split.add_child(_left)
	_split.add_child(_right)

	_mark = TextureRect.new()
	_mark.texture = try_texture("res://assets/ui/logo_wordmark.png")
	_mark.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_mark.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_size_both(_mark, Vector2(320.0, 80.0), Vector2(220.0, 56.0))
	_stack.add_child(_mark)

	var stats := AegisPanel.new()
	stats.interactive = false
	stats.accent_side = "top"
	stats.accent_color = AegisTokens.INFO
	stats.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_stack.add_child(stats)
	_stats = stats

	var stat_column := VBoxContainer.new()
	physical_separation(stat_column, 10)
	stats.add_child(stat_column)
	stat_column.add_child(make_label("PROFILE", "label", AegisTokens.INK_2))
	_balance = make_label("BATTLE POINTS  0", "mono_l", AegisTokens.ACCENT)
	stat_column.add_child(_balance)
	_best = make_label("BEST SCORE  0", "body", AegisTokens.INK)
	stat_column.add_child(_best)
	_runs = make_label("RUNS COMPLETED  0", "body", AegisTokens.INK)
	stat_column.add_child(_runs)
	_loadout = make_label("LOADOUT", "label_s", AegisTokens.INK_2)
	_loadout.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	stat_column.add_child(_loadout)

	# On a phone the canvas is ~3x taller than it is wide (1280x2770 at 390x844),
	# so a top-aligned column would leave two thirds of the screen empty and put
	# DEPLOY out of thumb reach. A spacer pushes the actions to the bottom and
	# DEPLOY sits last, closest to the edge the hand is already holding.
	_spacer = Control.new()
	_spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_stack.add_child(_spacer)

	var actions := VBoxContainer.new()
	physical_separation(actions, 12)
	_stack.add_child(actions)
	_actions = actions

	var row := HBoxContainer.new()
	physical_separation(row, 12)
	actions.add_child(row)

	var armory := make_button("ARMORY", "round", "Unlock and equip weapons with Battle Points")
	armory.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	physical_min_size(armory, 0.0, 56.0)
	armory.pressed.connect(_on_armory_pressed)
	row.add_child(armory)

	var settings := make_button("SETTINGS", "round", "Audio, HUD and control preferences")
	settings.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	physical_min_size(settings, 0.0, 56.0)
	settings.pressed.connect(_on_settings_pressed)
	row.add_child(settings)

	var replay := make_button("REPLAY INTRO", "ghost", "Watch the opening cinematic again")
	physical_min_size(replay, 0.0, 56.0)
	replay.pressed.connect(_on_replay_pressed)
	actions.add_child(replay)

	var deploy := make_button("DEPLOY", "primary", "Choose your loadout and start a run")
	physical_min_size(deploy, 0.0, 60.0)
	deploy.pressed.connect(_on_deploy_pressed)
	actions.add_child(deploy)

	_armory = ArmoryUi.new()
	_armory.name = "ArmoryPanel"
	_armory.visible = false
	_armory.weapon_action_requested.connect(_on_weapon_action)
	_armory.close_requested.connect(_on_armory_close)
	add_child(_armory)

	_settings = AegisSettingsMenu.new()
	_settings.name = "SettingsPanel"
	_settings.visible = false
	_settings.close_requested.connect(_on_settings_close)
	add_child(_settings)

	_connect_resized(_on_resized)
	relayout()


func enter(_stage_payload: Dictionary) -> void:
	_armory.visible = false
	_settings.visible = false
	apply_safe_margins(_margin)
	_on_resized()
	refresh_profile()


## FrontEnd calls this on `profile_changed`, so an unlock made inside the armory
## updates the dashboard underneath it without reopening the screen.
func refresh_profile() -> void:
	var progression := progression_service()
	if progression == null:
		return
	_balance.text = "BATTLE POINTS  %d" % progression.balance
	_best.text = "BEST SCORE  %d" % progression.best_score
	_runs.text = "RUNS COMPLETED  %d" % progression.completed_runs
	_loadout.text = (
		"LOADOUT  %s  /  %s  /  %s"
		% [
			_hero_name(progression.selected_hero_id),
			_weapon_name(progression.selected_weapon_id),
			_world_name(progression.selected_world_id),
		]
	)
	if _armory.visible:
		_armory.refresh_profile(
			progression.balance,
			progression.best_score,
			progression.unlocked_ids,
			progression.selected_weapon_id
		)


## Picks the arrangement that fits the screen: one column in portrait, stats
## beside actions in landscape. Only runs when the orientation actually
## changes, so a resize inside the same orientation is a re-scale, not a
## rebuild, and every block is detached before being re-added in reading order
## so the arrangement never depends on the order it was first built in.
func _apply_orientation() -> void:
	var landscape := is_landscape()
	if landscape == _landscape_built:
		return
	_landscape_built = landscape
	for block in [_mark, _stats, _spacer, _actions]:
		if block.get_parent() != null:
			block.get_parent().remove_child(block)
	if landscape:
		_stack.add_child(_split)
		_left.add_child(_mark)
		_left.add_child(_stats)
		_right.add_child(_spacer)
		_right.add_child(_actions)
	else:
		_stack.remove_child(_split)
		_stack.add_child(_mark)
		_stack.add_child(_stats)
		_stack.add_child(_spacer)
		_stack.add_child(_actions)


func _on_resized() -> void:
	relayout()
	_orient_nodes([_mark])
	_apply_orientation()
	# The armory and settings panels are sized in physical pixels too: they are
	# lists of 56 px rows, and a panel authored in canvas units would be a third
	# of that on a phone.
	_armory.custom_minimum_size = Vector2(px(minf(physical_size().x * 0.92, 420.0)), px(420.0))
	_settings.custom_minimum_size = Vector2(px(minf(physical_size().x * 0.94, 520.0)), px(520.0))
	enforce_font_floor(_armory, _stretch)
	enforce_font_floor(_settings, _stretch)
	_centre(_armory)
	_centre(_settings)


func _centre(panel: Control) -> void:
	panel.set_anchors_preset(Control.PRESET_CENTER)
	panel.position = (size - panel.size) * 0.5


func _on_deploy_pressed() -> void:
	Sfx.play_ui(&"session_clear")
	completed.emit(&"HERO", {})


func _on_armory_pressed() -> void:
	refresh_profile()
	_armory.visible = true
	_settings.visible = false
	_armory.focus_first()


func _on_armory_close() -> void:
	_armory.visible = false


func _on_settings_pressed() -> void:
	_settings.visible = true
	_armory.visible = false
	_settings.open()


func _on_settings_close() -> void:
	_settings.visible = false


func _on_replay_pressed() -> void:
	# Clearing the flag is what makes the cinematic reachable again; FrontEnd
	# re-marks it the moment the cinematic completes or is skipped.
	var progression := progression_service()
	if progression == null:
		return
	progression.reset_intro()
	completed.emit(&"CINEMATIC", {})


## Same rules as Main._on_armory_weapon_action: buying spends real BP and
## equipping only ever selects within what the profile already owns.
func _on_weapon_action(weapon_id: StringName) -> void:
	var progression := progression_service()
	if progression == null or not ProgressionService.WEAPON_IDS.has(weapon_id):
		return
	if progression.is_unlocked(weapon_id):
		progression.select_weapon(weapon_id)
		_armory.show_hint("%s EQUIPPED" % String(weapon_id).to_upper())
		return
	var missing := progression.unlock_cost(weapon_id) - progression.balance
	if missing > 0:
		_armory.show_hint("NEED %d MORE BP · FIGHT WAVES" % missing)
		return
	if progression.unlock_weapon(weapon_id):
		progression.select_weapon(weapon_id)
		Sfx.play_ui(&"session_clear")
		_armory.show_hint("%s UNLOCKED & EQUIPPED" % String(weapon_id).to_upper())
	refresh_profile()


## Heroes and worlds have no *numeric* model -- there is no per-hero health or
## speed -- but they do have a name, and it lives in the `HeroDefinition` /
## `WorldDefinition` registries exactly as a weapon's does. Reading it from
## there instead of typing it out here is what stops the dashboard calling the
## loadout something the HERO and WORLD cards do not.
func _hero_name(hero_id: StringName) -> String:
	var definition := HeroDefinition.load_definition(hero_id)
	if definition != null:
		return definition.display_name.to_upper()
	return String(hero_id).replace("_", " ").to_upper()


func _world_name(world_id: StringName) -> String:
	var definition := WorldDefinition.load_definition(world_id)
	if definition != null:
		return definition.display_name.to_upper()
	return String(world_id).replace("_", " ").to_upper()


## The weapon names itself: `WeaponDefinition.display_name` is the same string
## the selection card prints, so the dashboard cannot call it something else.
func _weapon_name(weapon_id: StringName) -> String:
	var definition := WeaponDefinition.load_definition(weapon_id)
	if definition != null and not definition.display_name.strip_edges().is_empty():
		return definition.display_name.to_upper()
	return String(weapon_id).to_upper()
