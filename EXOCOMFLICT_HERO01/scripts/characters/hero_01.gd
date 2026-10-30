extends Node3D
## HERO_01 wrapper: locates the imported Skeleton3D / AnimationPlayer,
## attaches the separate weapon scene to Weapon_R, and optionally drives the
## Phase-1 weapon chain through a code-built AnimationTree state machine:
##   Idle -> Weapon_Raise -> Aim_Idle -> Fire -> Aim_Idle
##   Aim_Idle -> Weapon_Lower -> Idle
## The weapon GLB origin equals the character origin with identity transform
## at rest (VERIFIED in Blender), so the attachment offset is solved from the
## Weapon_R bone rest transform: offset = inverse(bone_global_rest).
## Status: direct AnimationPlayer path runtime-validated on Godot 4.7.2
## (headless) 2026-10-29; Phase-1 clips/AnimationTree are Blender+GLB
## validated and await the owner's Godot re-import pass (VALIDATION_REPORT 5.10).

const WEAPON_SCENE = preload("res://scenes/weapons/HERO_01_WEAPON.tscn")
const LEGACY_AIM_ANIMATION := "Weapon_Raise_To_Aim"
const ANIMATION_IDLE := "Idle"
const ANIMATION_WEAPON_RAISE := "Weapon_Raise"
const ANIMATION_AIM_IDLE := "Aim_Idle"
const ANIMATION_FIRE := "Fire"
const ANIMATION_WEAPON_LOWER := "Weapon_Lower"
const PHASE1_ANIMATIONS := [
	ANIMATION_IDLE,
	ANIMATION_WEAPON_RAISE,
	ANIMATION_AIM_IDLE,
	ANIMATION_FIRE,
	ANIMATION_WEAPON_LOWER,
]
const LOOP_ANIMATIONS := [ANIMATION_IDLE, ANIMATION_AIM_IDLE]

## Backwards-compatible alias used by older validation code.
const AIM_ANIMATION := LEGACY_AIM_ANIMATION

## Set true and fill manual_weapon_offset to override automatic calibration
## (printed solved offset can be pasted here after the first successful run).
@export var use_manual_weapon_offset: bool = false
@export var manual_weapon_offset: Transform3D = Transform3D.IDENTITY
## Hero meshes are dense open-shell geometry: force LOD0 and a generous
## cull margin so fine detail never pops out while animating or in
## close-up cameras. (Materials are double-sided in the GLBs themselves;
## see tools/patch_glb_double_sided.py and VALIDATION_REPORT 5.6.)
@export var force_full_detail: bool = true
## Build and activate the Phase-1 AnimationTree state machine. Disable this
## if the host game wants to drive the imported AnimationPlayer itself or
## supply its own AnimationTree/locomotion blend graph.
@export var use_animation_tree: bool = true
@export var start_animation_state: String = ANIMATION_IDLE

var skeleton: Skeleton3D
var animation_player: AnimationPlayer
var animation_tree: AnimationTree
var animation_playback: AnimationNodeStateMachinePlayback
var weapon_attachment: BoneAttachment3D
var weapon_instance: Node3D
var calibrated_weapon_offset: Transform3D = Transform3D.IDENTITY
var resolved_animations: Dictionary = {}
var current_animation_state: String = ""

func _ready() -> void:
	skeleton = _find_first(self, "Skeleton3D") as Skeleton3D
	animation_player = _find_first(self, "AnimationPlayer") as AnimationPlayer
	if skeleton == null:
		push_error("HERO_01: Skeleton3D not found in imported GLB scene.")
		return
	if animation_player == null:
		push_warning("HERO_01: AnimationPlayer not found in imported GLB scene.")
	_attach_weapon()
	if force_full_detail:
		_apply_full_detail(self)
	_resolve_animations()
	_configure_animation_loops()
	_build_animation_tree()
	if use_animation_tree:
		set_animation_tree_enabled(true)

func _find_first(node: Node, type_name: String) -> Node:
	for child in node.get_children():
		if child.is_class(type_name):
			return child
		var found := _find_first(child, type_name)
		if found != null:
			return found
	return null

func _apply_full_detail(node: Node) -> void:
	if node is GeometryInstance3D:
		var gi := node as GeometryInstance3D
		gi.lod_bias = 64.0
		gi.extra_cull_margin = 1.0
	for child in node.get_children():
		_apply_full_detail(child)

func _attach_weapon() -> void:
	var bone_idx := skeleton.find_bone("Weapon_R")
	if bone_idx < 0:
		push_error("HERO_01: bone 'Weapon_R' not found in Skeleton3D.")
		return
	weapon_attachment = BoneAttachment3D.new()
	weapon_attachment.name = "WeaponAttachment_R"
	skeleton.add_child(weapon_attachment)
	weapon_attachment.bone_name = "Weapon_R"
	weapon_instance = WEAPON_SCENE.instantiate() as Node3D
	weapon_attachment.add_child(weapon_instance)
	if use_manual_weapon_offset:
		weapon_instance.transform = manual_weapon_offset
	else:
		# The weapon GLB is authored at the skeleton's origin (identity at
		# rest), so the attachment-local offset is simply the inverse of the
		# bone's global rest transform in skeleton space. This is invariant
		# to character scale/placement. (Validated in Godot 4.7.2 headless:
		# tools/godot/ci_check.gd — do NOT anchor to the hero root global,
		# whose space differs by the ScaleRoot factor.)
		var bone_rest: Transform3D = skeleton.get_bone_global_rest(bone_idx)
		weapon_instance.transform = bone_rest.affine_inverse()
	calibrated_weapon_offset = weapon_instance.transform
	print("HERO_01: weapon local offset under Weapon_R = ", calibrated_weapon_offset)

# ---------------------------------------------------------------------------
# Animation resolution / loop configuration
# ---------------------------------------------------------------------------

func _animation_base_name(full_name: String) -> String:
	var parts := full_name.split("/")
	return String(parts[parts.size() - 1]) if parts.size() > 0 else full_name

func _resolve_animation(anim_name: String) -> String:
	if animation_player == null:
		return ""
	# Exact basename first: a suffix search for "Idle" must never resolve to
	# "Aim_Idle" when both clips exist.
	for candidate in animation_player.get_animation_list():
		var s := String(candidate)
		if s == anim_name or _animation_base_name(s) == anim_name:
			return s
	for candidate in animation_player.get_animation_list():
		var s := String(candidate)
		if s.ends_with("/" + anim_name):
			return s
	return ""

func _resolve_animations() -> void:
	resolved_animations.clear()
	if animation_player == null:
		return
	var wanted: Array = []
	wanted.append_array(PHASE1_ANIMATIONS)
	wanted.append(LEGACY_AIM_ANIMATION)
	for canonical in wanted:
		var canonical_name := String(canonical)
		var resolved := _resolve_animation(canonical_name)
		if resolved != "":
			resolved_animations[canonical_name] = resolved

func _configure_animation_loops() -> void:
	if animation_player == null:
		return
	for canonical in resolved_animations.keys():
		var canonical_name := String(canonical)
		var anim := animation_player.get_animation(String(resolved_animations[canonical_name]))
		if anim == null:
			continue
		if canonical_name in LOOP_ANIMATIONS:
			anim.loop_mode = Animation.LOOP_LINEAR
		else:
			anim.loop_mode = Animation.LOOP_NONE

func has_animation(canonical_name: String) -> bool:
	return resolved_animations.has(canonical_name)

func get_resolved_animation(canonical_name: String) -> String:
	return String(resolved_animations.get(canonical_name, ""))

# ---------------------------------------------------------------------------
# Code-built Phase-1 AnimationTree state machine
# ---------------------------------------------------------------------------

func _add_state_transition(sm: AnimationNodeStateMachine, from_state: String, to_state: String,
		xfade_time: float, auto_advance: bool, at_end: bool = true) -> void:
	var tr := AnimationNodeStateMachineTransition.new()
	tr.xfade_time = xfade_time
	if auto_advance:
		tr.advance_mode = AnimationNodeStateMachineTransition.ADVANCE_MODE_AUTO
	else:
		tr.advance_mode = AnimationNodeStateMachineTransition.ADVANCE_MODE_ENABLED
	if at_end:
		tr.switch_mode = AnimationNodeStateMachineTransition.SWITCH_MODE_AT_END
	else:
		tr.switch_mode = AnimationNodeStateMachineTransition.SWITCH_MODE_IMMEDIATE
	sm.add_transition(StringName(from_state), StringName(to_state), tr)

func _build_animation_tree() -> bool:
	if animation_tree != null:
		return true
	if animation_player == null:
		return false
	for required in PHASE1_ANIMATIONS:
		if not resolved_animations.has(String(required)):
			push_warning("HERO_01: Phase-1 animation '%s' missing; AnimationTree not built." % String(required))
			return false

	var sm := AnimationNodeStateMachine.new()
	var positions := {
		ANIMATION_IDLE: Vector2(0, 0),
		ANIMATION_WEAPON_RAISE: Vector2(260, 0),
		ANIMATION_AIM_IDLE: Vector2(520, 0),
		ANIMATION_FIRE: Vector2(780, -140),
		ANIMATION_WEAPON_LOWER: Vector2(520, 180),
	}
	for state in PHASE1_ANIMATIONS:
		var state_name := String(state)
		var node := AnimationNodeAnimation.new()
		node.animation = StringName(String(resolved_animations[state_name]))
		if state_name in LOOP_ANIMATIONS:
			node.loop_mode = Animation.LOOP_LINEAR
		else:
			node.loop_mode = Animation.LOOP_NONE
		var node_position: Vector2 = positions.get(state_name, Vector2.ZERO)
		sm.add_node(StringName(state_name), node, node_position)

	_add_state_transition(sm, "Start", ANIMATION_IDLE, 0.0, true, false)
	_add_state_transition(sm, ANIMATION_IDLE, ANIMATION_WEAPON_RAISE, 0.12, false, false)
	_add_state_transition(sm, ANIMATION_WEAPON_RAISE, ANIMATION_AIM_IDLE, 0.12, true, true)
	_add_state_transition(sm, ANIMATION_AIM_IDLE, ANIMATION_FIRE, 0.03, false, false)
	_add_state_transition(sm, ANIMATION_FIRE, ANIMATION_AIM_IDLE, 0.05, true, true)
	_add_state_transition(sm, ANIMATION_AIM_IDLE, ANIMATION_WEAPON_LOWER, 0.12, false, false)
	_add_state_transition(sm, ANIMATION_WEAPON_RAISE, ANIMATION_WEAPON_LOWER, 0.15, false, false)
	_add_state_transition(sm, ANIMATION_WEAPON_LOWER, ANIMATION_IDLE, 0.12, true, true)

	animation_tree = AnimationTree.new()
	animation_tree.name = "HERO01AnimationTree"
	add_child(animation_tree)
	animation_tree.anim_player = animation_tree.get_path_to(animation_player)
	# Match the AnimationPlayer's track root (the imported GLB scene root),
	# otherwise the tree would resolve bone tracks from this wrapper root.
	var player_root: Node = animation_player.get_node_or_null(animation_player.root_node)
	if player_root == null:
		player_root = animation_player.get_parent()
	if player_root != null:
		animation_tree.root_node = animation_tree.get_path_to(player_root)
	animation_tree.tree_root = sm
	animation_tree.active = false
	_refresh_animation_playback()
	return true

func _refresh_animation_playback() -> bool:
	if animation_tree == null:
		return false
	var pb: Variant = animation_tree.get("parameters/playback")
	if pb is AnimationNodeStateMachinePlayback:
		animation_playback = pb as AnimationNodeStateMachinePlayback
	return animation_playback != null

func _refresh_and_start_tree() -> void:
	if not is_animation_tree_enabled():
		return
	if not _refresh_animation_playback():
		return
	var current := String(animation_playback.get_current_node())
	if current == "" or current == "Start":
		var start_state := start_animation_state
		if not resolved_animations.has(start_state):
			start_state = ANIMATION_IDLE
		animation_playback.start(StringName(start_state))
		current_animation_state = start_state

func set_animation_tree_enabled(enabled: bool) -> bool:
	if enabled:
		if not _build_animation_tree():
			return false
		if animation_player != null and animation_player.is_playing():
			animation_player.stop()
		animation_tree.active = true
		if _refresh_animation_playback():
			var start_state := start_animation_state
			if not resolved_animations.has(start_state):
				start_state = ANIMATION_IDLE
			animation_playback.start(StringName(start_state))
			current_animation_state = start_state
		else:
			call_deferred("_refresh_and_start_tree")
		return true
	if animation_tree != null:
		animation_tree.active = false
	return true

func is_animation_tree_enabled() -> bool:
	return animation_tree != null and animation_tree.active

func travel_animation_state(state_name: String) -> bool:
	if not resolved_animations.has(state_name):
		push_error("HERO_01: animation state '%s' not found. Resolved: %s" % [state_name, str(resolved_animations.keys())])
		return false
	if is_animation_tree_enabled():
		if not _refresh_animation_playback():
			push_warning("HERO_01: AnimationTree playback not ready yet.")
			return false
		animation_playback.travel(StringName(state_name))
		current_animation_state = state_name
		return true
	return play_animation(state_name)

func play_animation(canonical_name: String, custom_blend: float = 0.12, custom_speed: float = 1.0, from_end: bool = false) -> bool:
	if animation_player == null:
		return false
	if not resolved_animations.has(canonical_name):
		push_error("HERO_01: animation '%s' not found. Available: %s" % [canonical_name, str(animation_player.get_animation_list())])
		return false
	if is_animation_tree_enabled():
		if canonical_name in PHASE1_ANIMATIONS:
			return travel_animation_state(canonical_name)
		push_warning("HERO_01: disable the AnimationTree before directly playing '%s'." % canonical_name)
		return false
	animation_player.play(String(resolved_animations[canonical_name]), custom_blend, custom_speed, from_end)
	current_animation_state = canonical_name
	return true

func play_idle() -> bool:
	return travel_animation_state(ANIMATION_IDLE)

func raise_weapon() -> bool:
	return travel_animation_state(ANIMATION_WEAPON_RAISE)

func play_aim_idle() -> bool:
	return travel_animation_state(ANIMATION_AIM_IDLE)

func fire_weapon() -> bool:
	if is_animation_tree_enabled() and _refresh_animation_playback():
		if String(animation_playback.get_current_node()) == ANIMATION_FIRE:
			animation_playback.start(StringName(ANIMATION_FIRE))
			current_animation_state = ANIMATION_FIRE
			return true
	return travel_animation_state(ANIMATION_FIRE)

func lower_weapon() -> bool:
	return travel_animation_state(ANIMATION_WEAPON_LOWER)

func get_current_animation_state() -> String:
	if is_animation_tree_enabled() and _refresh_animation_playback():
		var current := String(animation_playback.get_current_node())
		if current != "":
			current_animation_state = current
			return current
	if animation_player != null and String(animation_player.current_animation) != "":
		return _animation_base_name(String(animation_player.current_animation))
	return current_animation_state

func get_current_animation_position() -> float:
	if is_animation_tree_enabled() and _refresh_animation_playback():
		return animation_playback.get_current_play_position()
	if animation_player != null:
		return animation_player.current_animation_position
	return 0.0

func get_current_animation_length() -> float:
	if is_animation_tree_enabled() and _refresh_animation_playback():
		return animation_playback.get_current_length()
	if animation_player != null and String(animation_player.current_animation) != "":
		var anim := animation_player.get_animation(String(animation_player.current_animation))
		if anim != null:
			return anim.length
	return 0.0

# ---------------------------------------------------------------------------
# Legacy direct-play API (kept for the original validation scene / CI)
# ---------------------------------------------------------------------------

func play_aim(from_start: bool = true) -> void:
	if is_animation_tree_enabled():
		if from_start:
			raise_weapon()
		else:
			play_aim_idle()
		return
	if animation_player == null:
		return
	var anim := get_resolved_animation(LEGACY_AIM_ANIMATION)
	if anim == "":
		push_error("HERO_01: animation '%s' not found. Available: %s" % [LEGACY_AIM_ANIMATION, str(animation_player.get_animation_list())])
		return
	animation_player.play(anim)
	current_animation_state = LEGACY_AIM_ANIMATION
	if from_start:
		animation_player.seek(0.0, true)

func set_weapon_visible(v: bool) -> void:
	if weapon_instance != null:
		weapon_instance.visible = v
