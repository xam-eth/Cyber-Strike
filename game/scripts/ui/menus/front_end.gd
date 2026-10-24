## Owns the front-end journey: BOOT -> LOADING -> CHAPTER -> DASHBOARD ->
## HERO -> WORLD -> PRELOAD -> gameplay.
##
## This is the only place that knows the order. A stage asks for the next one by
## name and FrontEnd decides whether that is legal, which is what keeps the
## onboarding honest: the CHAPTER 01 card is skipped on a second launch because
## *this* object reads `intro_seen` off the profile, not because each screen
## remembers whether it played.
##
## There is no WEAPON stage any more. Its screen was three weapon chips around a
## 3D rifle -- a section of a loadout, not a page in a journey -- so the rail
## moved into HERO, next to the operative who carries it. The journey is shorter
## and the loadout is still two choices: who, and with what.
##
## There is no studio ident and no opening film. The delivered clip was pulled
## on 2026-10-24 because it was not good enough to be the first thing a player
## saw, and a placeholder standing in for the mark would be worse than nothing
## (docs/DECISIONS.md 17). BOOT is therefore first and unguarded: it is the
## engine's own load, and the boot overlay in the web shell is deliberately a
## dark frame with no words on it.
##
## Nothing here fakes progress. BOOT shows an indeterminate bar because a
## ConfigFile read reports no progress; LOADING and PRELOAD show a percentage
## because `ResourceLoader` reports one.
class_name FrontEnd
extends Control

const GAMEPLAY_SCENE := "res://scenes/main.tscn"

const STAGE_SCENES := {
	&"BOOT": preload("res://scenes/ui/menus/stage_boot.tscn"),
	&"LOADING": preload("res://scenes/ui/menus/stage_loading.tscn"),
	&"CHAPTER": preload("res://scenes/ui/menus/stage_chapter.tscn"),
	&"DASHBOARD": preload("res://scenes/ui/menus/stage_dashboard.tscn"),
	&"HERO": preload("res://scenes/ui/menus/stage_hero_select.tscn"),
	&"WORLD": preload("res://scenes/ui/menus/stage_world_select.tscn"),
	&"PRELOAD": preload("res://scenes/ui/menus/stage_preload.tscn"),
}

## Where BACK / Escape goes. Stages not listed are terminal within the journey
## and ignore the key.
const BACK_TARGET := {
	&"HERO": &"DASHBOARD",
	&"WORLD": &"HERO",
	&"PRELOAD": &"WORLD",
}

## Read-only view of the active stage, for tests and for QA logging.
var current_stage_name := StringName()

var _stages: Dictionary = {}
var _current: MenuStage = null
var _current_name := StringName()

@onready var progression_service: ProgressionService = $ProgressionService
@onready var stage_host: Control = $StageHost


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	for key in STAGE_SCENES:
		var stage: MenuStage = (STAGE_SCENES[key] as PackedScene).instantiate()
		stage.name = str(key)
		stage.front_end = self
		stage.set_anchors_preset(Control.PRESET_FULL_RECT)
		stage.visible = false
		stage.completed.connect(_on_stage_completed.bind(key))
		stage_host.add_child(stage)
		# Entering the tree turns processing ON for a node whose script declares
		# `_process`, even though nothing called set_process(true) -- measured in
		# this build: a bare Control reports is_processing() false after new(),
		# true immediately after add_child(). Left alone every stage ticks from
		# the moment the front end boots, and a loading stage drains its queue
		# before it is ever shown. So the opt-out has to come *after* add_child,
		# and stages opt back in from enter().
		stage.set_process(false)
		stage.set_physics_process(false)
		_stages[key] = stage
	progression_service.profile_changed.connect(_on_profile_changed)
	_enter(&"BOOT", {})
	_enter_qa_stage()


## QA hook, web only: `?qa_stage=DASHBOARD` lands straight on a stage so a
## build can be photographed without playing through to it. Same mechanism as
## the existing `?qa_camera` / `?qa_touch` flags in camera_rig.gd and
## hud_encounter_ui.gd, and equally inert outside a browser.
func _enter_qa_stage() -> void:
	if not OS.has_feature("web"):
		return
	_enter_qa_world()
	var requested: Variant = JavaScriptBridge.eval(
		"new URLSearchParams(location.search).get('qa_stage') || ''"
	)
	var stage_name := StringName(str(requested))
	if stage_name == &"" or not STAGE_SCENES.has(stage_name):
		return
	call_deferred("_enter", stage_name, _qa_payload(stage_name))


## QA hook, web only: `?qa_world=vanguard_station` selects a theatre before the
## launch, the same way pressing its card on the WORLD screen would. Without it a
## second world can only be photographed by clicking through the front end, which
## is exactly the kind of "it works, trust me" claim this project keeps paying for.
func _enter_qa_world() -> void:
	var requested: Variant = JavaScriptBridge.eval(
		"new URLSearchParams(location.search).get('qa_world') || ''"
	)
	var world_id := StringName(str(requested))
	if world_id == &"" or not ProgressionService.WORLD_IDS.has(world_id):
		return
	progression_service.select_world(world_id)
	print("FrontEnd: qa_world selected %s" % world_id)


## What the real journey would have passed to this stage. It matters for the
## two loading stages: with no targets they leave on the next frame, so a deep
## link landed on a screen that existed for one frame and could not be
## photographed (or QA'd) at all.
func _qa_payload(stage_name: StringName) -> Dictionary:
	# `?qa_hold=1` keeps a stage that would otherwise finish in one frame on
	# screen -- the loading screens have no duration in a web build, so without
	# this they cannot be photographed. Nothing outside the QA deep link sets it.
	if OS.has_feature("web"):
		var hold: Variant = JavaScriptBridge.eval(
			"new URLSearchParams(location.search).has('qa_hold')"
		)
		if bool(hold):
			var held := _qa_stage_payload(stage_name)
			held["hold"] = true
			return held
	return _qa_stage_payload(stage_name)


func _qa_stage_payload(stage_name: StringName) -> Dictionary:
	match stage_name:
		&"LOADING":
			return {"targets": _stages[&"BOOT"].FRONT_END_ART}
		&"PRELOAD":
			return {"targets": [GAMEPLAY_SCENE], "title": &"PRE-GAME LOADING"}
	return {}


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel") and BACK_TARGET.has(_current_name):
		get_viewport().set_input_as_handled()
		_enter(BACK_TARGET[_current_name], {})


## The only legal way to change stage. Test hooks call this directly.
func go_to(stage_name: StringName, stage_payload: Dictionary = {}) -> void:
	if not STAGE_SCENES.has(stage_name):
		push_error("FrontEnd: unknown stage '%s'." % stage_name)
		return
	_enter(stage_name, stage_payload)


## Where the front-end art load leads: the CHAPTER 01 card on a first launch,
## the dashboard once it has been seen. Resolved here rather than in BOOT so the
## "play the chapter card once" rule lives in exactly one place.
##
## The studio ident is deliberately not part of this: it played before BOOT and
## it plays again on the next launch, whatever the profile says.
func stage_after_loading() -> StringName:
	return &"DASHBOARD" if progression_service.intro_seen else &"CHAPTER"


func start_gameplay() -> void:
	var scene := load(GAMEPLAY_SCENE) as PackedScene
	if scene == null:
		push_error("FrontEnd: the gameplay scene is missing: " + GAMEPLAY_SCENE)
		return
	var error := get_tree().change_scene_to_packed(scene)
	if error != OK:
		push_error("FrontEnd: could not change scene (%d)." % error)


func _enter(stage_name: StringName, stage_payload: Dictionary) -> void:
	if is_instance_valid(_current):
		_current.exit()
		_current.visible = false
	var stage: MenuStage = _stages.get(stage_name)
	if stage == null:
		push_error("FrontEnd: stage '%s' was never instantiated." % stage_name)
		return
	_current = stage
	_current_name = stage_name
	current_stage_name = stage_name
	stage.payload = stage_payload
	stage.visible = true
	stage.enter(stage_payload)
	print("FrontEnd: stage %s" % stage_name)
	_report_menu_rects()


## Opt-in browser report of the rendered menu rectangles, in physical pixels.
## Only present with `?qa_menu=1`.
##
## Screenshots cannot be looked at in this environment, so every layout claim
## has to come from numbers the engine reports. This prints the canvas and
## physical sizes, the resolved safe-area reserve, and each visible control's
## rect -- so "is this button inside the safe area" and "is it big enough to
## hit" can be answered from the browser log alone, at any viewport, without
## trusting a picture.
func report_menu_rects() -> void:
	if not OS.has_feature("web"):
		return
	if not bool(JavaScriptBridge.eval("new URLSearchParams(location.search).has('qa_menu')")):
		return
	var physical := Vector2(get_window().size)
	var stretch := UiLayout.compute_stretch(self, physical)
	var insets := UiLayout.measure_safe_insets(physical, DisplayServer.is_touchscreen_available())
	var lines := PackedStringArray()
	lines.append("STAGE=%s" % _current_name)
	(
		lines
		. append(
			(
				"CANVAS=%dx%d PHYSICAL=%dx%d STRETCH=%.3f"
				% [
					roundi(size.x),
					roundi(size.y),
					roundi(physical.x),
					roundi(physical.y),
					stretch,
				]
			)
		)
	)
	lines.append("SAFE=%.0f,%.0f,%.0f" % [insets.x, insets.y, insets.z])
	for child in _current.find_children("*", "Control", true, false):
		var control := child as Control
		if control == null or not control.is_visible_in_tree():
			continue
		if not (
			control is Button
			or control is Label
			or control is ProgressBar
			or control is VideoStreamPlayer
			or control is ScrollContainer
		):
			continue
		var label := str(control.name)
		if control is Button and not (control as Button).text.is_empty():
			label = (control as Button).text
		elif control is Label and not (control as Label).text.is_empty():
			label = (control as Label).text.substr(0, mini((control as Label).text.length(), 18))
		var rect := control.get_global_rect()
		(
			lines
			. append(
				(
					"%s=%d,%d,%dx%d"
					% [
						label,
						roundi(rect.position.x * stretch),
						roundi(rect.position.y * stretch),
						roundi(rect.size.x * stretch),
						roundi(rect.size.y * stretch),
					]
				)
			)
		)
	print("Menu QA: " + " | ".join(lines))


## Rectangles are only meaningful once the containers have run, so the report
## waits two frames after the stage is entered.
func _report_menu_rects() -> void:
	if not OS.has_feature("web"):
		return
	await get_tree().process_frame
	await get_tree().process_frame
	report_menu_rects()


func _on_stage_completed(
	next_stage: StringName, stage_payload: Dictionary, from_stage: StringName
) -> void:
	# The CHAPTER 01 card plays once. Clearing it counts as seeing it: being
	# dropped straight into the dashboard is the reward for clearing it.
	if from_stage == &"CHAPTER":
		progression_service.mark_intro_seen()
	if not STAGE_SCENES.has(next_stage):
		push_error("FrontEnd: stage '%s' asked for unknown stage '%s'." % [from_stage, next_stage])
		return
	_enter(next_stage, stage_payload)


func _on_profile_changed() -> void:
	# The dashboard and the selection screens read the profile when they are
	# entered, so this only has to cover the case where a purchase or an unlock
	# lands while a screen is already open (the in-dashboard armory).
	if is_instance_valid(_current) and _current.has_method("refresh_profile"):
		_current.refresh_profile()
