class_name CharacterVisual
extends Node3D

## Presentation layer for the player avatar.
##
## The gameplay body is a CharacterBody3D with a capsule collider; everything the
## camera sees lives under this node. Two kinds of model can be attached here:
##
## * a **rigged** GLB with a Skeleton3D and AnimationPlayer in the selected
##   HeroDefinition. Its locomotion, aim locomotion, combat, hit and death clips
##   drive the limbs. Each model has its own generated rig profile; the rifle
##   follows its `R_Hand` bone through a BoneAttachment3D, and the shot origin
##   is read from the rifle's measured `MuzzlePoint`, not a guessed offset.
## * a **static** kit model (the Kenney astronaut fallback). No skeleton, so
##   motion stays procedural: walking bob, strafe lean, run pitch and recoil are
##   driven here from the controller's velocity.
##
## The weapon socket and muzzle node paths (`VisualRoot/WeaponSocket/Muzzle`,
## `.../MuzzleFlash`) are the same in both modes: the combat code and the smoke
## tests address them directly, so a rig swap must not move them in the tree.
##
## Each `HeroDefinition.rig_path` points at a generated profile. Common's profile
## comes from `tools/gltf/build_clips.py`; the Rare/Epic profiles are generated
## by `tools/gltf/retarget_hero_variants.py` and carry their own hand/socket data.

const ModelFitterScript = preload("res://scripts/visual/model_fitter.gd")
const DEFAULT_RIG_PATH := "res://assets/characters/hero/hero_rig.json"
const FIRE_CLIP_SECONDS := 0.45
# The shipped walk/run tracks contain roughly two gait repeats across their
# full clip duration. Map playback rate to the controller's in-place travel speed.
const RUN_ENTER_THRESHOLD := 0.60
const RUN_EXIT_THRESHOLD := 0.48
const WALK_ENTER_THRESHOLD := 0.06
const WALK_EXIT_THRESHOLD := 0.04
const MAX_EXPECTED_SPEED_RATIO := 1.45
const WALK_RATE_AT_MIN_SPEED := 0.78
const WALK_RATE_AT_RUN_ENTRY := 2.15
const RUN_RATE_AT_ENTRY := 1.0
const RUN_RATE_AT_SPRINT := 1.9
const CHARACTER_TEXTURE_FILTER := BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC

@export var model_scene: PackedScene
@export var weapon_scene: PackedScene
@export_range(1.0, 2.4, 0.01) var target_height: float = 1.78
@export_range(0.2, 2.0, 0.01) var weapon_length: float = 0.86
@export_range(-180.0, 180.0, 1.0) var weapon_yaw_offset_degrees: float = 0.0
@export_range(-45.0, 45.0, 0.5) var weapon_pitch_degrees: float = -4.0
@export_range(-180.0, 180.0, 1.0) var model_yaw_offset_degrees: float = 180.0
@export_range(0.0, 2.0, 0.01) var bob_amplitude: float = 0.04
@export_range(0.0, 12.0, 0.1) var bob_frequency: float = 7.0
@export_range(0.0, 30.0, 0.5) var strafe_roll_degrees: float = 6.0
@export_range(0.0, 30.0, 0.5) var run_pitch_degrees: float = 5.0
@export_range(1.0, 30.0, 0.5) var move_speed_reference: float = 6.0
@export_range(60.0, 2000.0, 10.0) var aiming_turn_speed_degrees: float = 900.0
@export_range(30.0, 900.0, 10.0) var free_turn_speed_degrees: float = 320.0
@export_range(0.0, 0.5, 0.005) var recoil_kick: float = 0.05
@export var rig_path: String = DEFAULT_RIG_PATH
@export var use_rig_animation: bool = true
@export_range(0.05, 1.0, 0.01) var weapon_socket_blend_seconds: float = 0.16
@export_range(-60.0, 60.0, 0.5) var reload_weapon_yaw_degrees: float = -38.0

var _model: Node3D
var _model_bounds: AABB
var _model_height: float = 0.0
var _current_hero_id: StringName = &""
var _fallback_muzzle_transform: Transform3D = Transform3D.IDENTITY
var _fallback_flash_transform: Transform3D = Transform3D.IDENTITY
var _facing_yaw: float = 0.0
var _bob_phase: float = 0.0
var _bob_offset: float = 0.0
var _roll_degrees: float = 0.0
var _pitch_degrees: float = 0.0
var _recoil_remaining: float = 0.0
var _recoil_duration: float = 0.16
var _aiming: bool = false
var _weapon_socket_base_position: Vector3 = Vector3.ZERO
var _weapon_socket_base_rotation: Vector3 = Vector3.ZERO

# --- rig state -------------------------------------------------------------
var _rig: Dictionary = {}
var _skeleton: Skeleton3D = null
var _anim_player: AnimationPlayer = null
var _attachment: BoneAttachment3D = null
var _current_clip: String = ""
var _fire_remaining: float = 0.0
var _reload_remaining: float = 0.0
var _reload_total: float = 0.0
var _hit_remaining: float = 0.0
var _defeated: bool = false
var _socket_aiming: bool = false
var _socket_weight: float = 0.0
var _socket_aim_basis: Basis = Basis()
var _socket_carry_basis: Basis = Basis()
var _socket_offset: Vector3 = Vector3.ZERO
var _last_speed_ratio: float = 0.0
var _locomotion_active: bool = false
var _run_locomotion_active: bool = false

@onready var _fallback_body: MeshInstance3D = get_node_or_null("BodyMesh")
@onready var _weapon_socket: Node3D = get_node_or_null("WeaponSocket")
@onready var _muzzle_marker: Marker3D = get_node_or_null("WeaponSocket/Muzzle")
@onready var _muzzle_flash: Node3D = get_node_or_null("WeaponSocket/MuzzleFlash")


func _ready() -> void:
	if is_instance_valid(_muzzle_marker):
		_fallback_muzzle_transform = _muzzle_marker.transform
	if is_instance_valid(_muzzle_flash):
		_fallback_flash_transform = _muzzle_flash.transform
	_spawn_model()
	_spawn_weapon()


func _process(delta: float) -> void:
	if _fire_remaining > 0.0:
		_fire_remaining = maxf(_fire_remaining - delta, 0.0)
	if _reload_remaining > 0.0:
		_reload_remaining = maxf(_reload_remaining - delta, 0.0)
	if _hit_remaining > 0.0:
		_hit_remaining = maxf(_hit_remaining - delta, 0.0)
	if is_rigged():
		_update_locomotion(_last_speed_ratio)
		_blend_socket(delta)


func has_model() -> bool:
	return _model != null and is_instance_valid(_model)


func current_hero_id() -> StringName:
	return _current_hero_id


## Apply the selected roster definition without replacing the player, collider,
## camera, combat controller, weapon socket, or muzzle marker paths.
func set_hero_definition(definition: HeroDefinition) -> bool:
	if definition == null or not definition.field_ready or not definition.is_valid_definition():
		return false
	var model_changed := (
		model_scene != definition.model_scene
		or rig_path != definition.rig_path
		or not is_equal_approx(target_height, definition.target_height)
		or not is_equal_approx(model_yaw_offset_degrees, definition.model_yaw_offset_degrees)
	)
	_current_hero_id = definition.hero_id
	if not model_changed:
		return true

	model_scene = definition.model_scene
	rig_path = definition.rig_path
	target_height = definition.target_height
	model_yaw_offset_degrees = definition.model_yaw_offset_degrees
	_remove_model()
	_remove_weapon()
	_restore_muzzle_markers()
	_current_clip = ""
	_fire_remaining = 0.0
	_reload_remaining = 0.0
	_reload_total = 0.0
	_hit_remaining = 0.0
	_locomotion_active = false
	_run_locomotion_active = false
	_socket_weight = 0.0
	_spawn_model()
	_spawn_weapon()
	if is_rigged():
		_update_locomotion(_last_speed_ratio)
	return has_model()


## True when the attached model brought a skeleton and an AnimationPlayer.
func is_rigged() -> bool:
	return _skeleton != null and _anim_player != null


func model_height() -> float:
	return _model_height


func is_aiming() -> bool:
	return _aiming


## Name of the clip the AnimationPlayer is showing ("" for static models).
func current_clip() -> String:
	return _current_clip


## Height of the avatar as rendered (after the model was fitted), in metres.
## The camera uses it to frame the player; 1.8 is the capsule fallback.
func visual_height() -> float:
	return _model_height if has_model() else 1.8


func walk_intensity() -> float:
	return absf(_bob_offset) / maxf(bob_amplitude, 0.0001)


func set_aiming(value: bool) -> void:
	_aiming = value
	if is_rigged():
		_update_locomotion(_last_speed_ratio)


## WeaponController owns the ammo timer. This presentation layer stretches its
## imported reload action to the *current weapon's* measured reload duration.
func play_reload(seconds: float) -> void:
	if _defeated or seconds <= 0.0:
		return
	_reload_remaining = seconds
	_reload_total = seconds
	_fire_remaining = 0.0
	if is_rigged():
		_update_locomotion(_last_speed_ratio)


func finish_reload() -> void:
	_reload_remaining = 0.0
	_reload_total = 0.0
	if is_rigged():
		_update_locomotion(_last_speed_ratio)


func play_hit() -> void:
	if _defeated:
		return
	_hit_remaining = _anim_player.get_animation("hit").length if _has_clip("hit") else 0.28
	if is_rigged():
		_update_locomotion(_last_speed_ratio)


func play_death() -> void:
	_defeated = true
	_fire_remaining = 0.0
	_reload_remaining = 0.0
	_reload_total = 0.0
	_hit_remaining = 0.0
	if is_rigged():
		_update_locomotion(0.0)


func reset_action_state() -> void:
	_defeated = false
	_fire_remaining = 0.0
	_reload_remaining = 0.0
	_reload_total = 0.0
	_hit_remaining = 0.0
	_aiming = false
	_last_speed_ratio = 0.0
	_locomotion_active = false
	_run_locomotion_active = false
	if is_rigged():
		_update_locomotion(0.0)


## Hip fire cannot spawn at the lowered carry barrel and THEN begin raising the
## authored arms: that put the first discharge beside the boot in actual WebGL.
## Sample the already-authored Blender aim/aim-run frame before resolving the
## projectile. Keep a moving clip's phase so its legs do not restart on trigger.
## This moves the real rifle, MuzzlePoint, projectile and light as one assembly;
## it never adds a fake higher shot origin or changes damage/aim assist.
func prime_shot_pose() -> void:
	if not is_rigged() or _defeated or _reload_remaining > 0.0:
		return
	if _socket_weight >= 0.98 and _current_clip in ["aim", "aim_walk", "aim_run", "fire"]:
		return
	_update_locomotion_flags(_last_speed_ratio)
	var clip := "aim"
	if _run_locomotion_active and _has_clip("aim_run"):
		clip = "aim_run"
	elif _locomotion_active and _has_clip("aim_walk"):
		clip = "aim_walk"
	if not _has_clip(clip):
		return
	# _play carries normalized gait phase into the composite aim clip, rather
	# than restarting the stride on the exact frame a shot is requested.
	_play(clip, 0.0)
	_socket_weight = 1.0
	# BoneAttachment3D syncs during the normal update, but the shot is fired
	# *inside this physics tick*. Read the measured hand bone pose directly so
	# the marker and the rifle are in the same pose on the first trigger frame.
	var hand_index := _skeleton.find_bone(str(_rig.get("hand_bone", "R_Hand")))
	if hand_index >= 0:
		var hand := _skeleton.global_transform * _skeleton.get_bone_global_pose(hand_index)
		_weapon_socket.global_transform = hand * Transform3D(_socket_aim_basis, _socket_offset)


func play_recoil(strength: float = 1.0, duration: float = 0.16) -> void:
	_recoil_duration = maxf(duration, 0.01)
	_recoil_remaining = maxf(_recoil_remaining, _recoil_duration * clampf(strength, 0.2, 2.0))
	# Hip-fire is a real shot too: without this, the rifle fires from its
	# lowered carry pose while the hero's arms remain idle. Shoulder the
	# Blender-authored fire pose while standing; during movement keep the
	# authored aim-walk/run legs moving instead of freezing in a standing pose.
	if is_rigged() and _has_clip("fire"):
		_update_locomotion_flags(_last_speed_ratio)
		_fire_remaining = FIRE_CLIP_SECONDS
		if not _locomotion_active:
			if _current_clip == "fire":
				# A second shot restarts the recoil instead of being swallowed.
				_anim_player.seek(0.0, true)
			else:
				_play("fire", 0.05)
		else:
			_update_locomotion(_last_speed_ratio)


func recoil_ratio() -> float:
	if _recoil_duration <= 0.0:
		return 0.0
	return clampf(_recoil_remaining / _recoil_duration, 0.0, 1.0)


## Decide which way the avatar looks. Aiming wins, then movement, then a slow
## turn towards the aim point so an idle player still faces the crosshair.
func update_facing(aim_point: Vector3, velocity: Vector3, aim_active: bool, delta: float) -> void:
	var desired_yaw := _facing_yaw
	var turn_speed := free_turn_speed_degrees
	var horizontal := Vector3(velocity.x, 0.0, velocity.z)
	if aim_active:
		var to_aim := aim_point - global_position
		to_aim.y = 0.0
		if to_aim.length_squared() > 0.0004:
			desired_yaw = atan2(-to_aim.x, -to_aim.z)
			turn_speed = aiming_turn_speed_degrees
	elif horizontal.length_squared() > 0.04:
		desired_yaw = atan2(-horizontal.x, -horizontal.z)
	else:
		var to_idle_aim := aim_point - global_position
		to_idle_aim.y = 0.0
		if to_idle_aim.length_squared() > 0.0004:
			desired_yaw = atan2(-to_idle_aim.x, -to_idle_aim.z)
	_facing_yaw = rotate_toward(_facing_yaw, desired_yaw, deg_to_rad(turn_speed) * delta)


func update_pose(velocity: Vector3, grounded: bool, delta: float) -> void:
	var horizontal := Vector2(velocity.x, velocity.z)
	var speed_ratio := clampf(
		horizontal.length() / maxf(move_speed_reference, 0.001), 0.0, MAX_EXPECTED_SPEED_RATIO
	)
	_last_speed_ratio = speed_ratio
	if is_rigged():
		# The clips carry their own weight shift and gear motion; adding the
		# procedural bob on top would double it. Only the strafe lean is kept.
		_bob_offset = 0.0
		_roll_degrees = lerpf(_roll_degrees, _strafe_roll(velocity) * 0.35, 9.0 * delta)
		_apply_pose()
		return

	var target_bob := 0.0
	var target_roll := 0.0
	var target_pitch := 0.0

	if grounded and speed_ratio > 0.02:
		_bob_phase = fmod(_bob_phase + bob_frequency * speed_ratio * delta, TAU)
		target_bob = sin(_bob_phase) * bob_amplitude * minf(speed_ratio, 1.0)
		target_roll = _strafe_roll(velocity)
		target_pitch = speed_ratio * run_pitch_degrees
	else:
		_bob_phase = 0.0

	if _aiming:
		# Aiming stills the body: no bob, minimal lean.
		target_bob = 0.0
		target_roll *= 0.3
		target_pitch *= 0.4

	var blend := 9.0 * delta
	_bob_offset = lerpf(_bob_offset, target_bob, blend)
	_roll_degrees = lerpf(_roll_degrees, target_roll, blend)
	_pitch_degrees = lerpf(_pitch_degrees, target_pitch, blend)

	if _recoil_remaining > 0.0:
		_recoil_remaining = maxf(_recoil_remaining - delta, 0.0)
	_apply_pose()


func _strafe_roll(velocity: Vector3) -> float:
	var local_side := (global_transform.basis.inverse() * velocity).x
	return -local_side / maxf(move_speed_reference, 0.001) * strafe_roll_degrees


func _apply_pose() -> void:
	var kick := recoil_ratio()
	if is_rigged():
		kick = 0.0
	rotation.y = _facing_yaw
	rotation.x = deg_to_rad(_pitch_degrees + kick * 4.5)
	rotation.z = deg_to_rad(_roll_degrees)
	position.y = _bob_offset
	if is_instance_valid(_weapon_socket) and not is_rigged():
		_weapon_socket.position.z = _weapon_socket_base_position.z + kick * recoil_kick
		_weapon_socket.rotation.x = _weapon_socket_base_rotation.x - kick * 0.36


# --- rig -------------------------------------------------------------------


func _remove_model() -> void:
	if is_instance_valid(_model):
		var pivot := _model.get_parent() as Node3D
		if is_instance_valid(pivot) and pivot.name == "ModelPivot":
			pivot.free()
		else:
			_model.free()
	_model = null
	_model_bounds = AABB()
	_model_height = 0.0
	_skeleton = null
	_anim_player = null
	_attachment = null
	_rig = {}


func _remove_weapon() -> void:
	if not is_instance_valid(_weapon_socket):
		return
	var weapon := _weapon_socket.get_node_or_null("WeaponModel")
	if is_instance_valid(weapon):
		weapon.free()


func _restore_muzzle_markers() -> void:
	if is_instance_valid(_muzzle_marker):
		_muzzle_marker.transform = _fallback_muzzle_transform
	if is_instance_valid(_muzzle_flash):
		_muzzle_flash.transform = _fallback_flash_transform


func _spawn_model() -> void:
	if is_instance_valid(_weapon_socket):
		_weapon_socket_base_position = _weapon_socket.position
		_weapon_socket_base_rotation = _weapon_socket.rotation
	# The kit models are authored facing +Z while the game's forward is -Z, and the
	# ModelFitter pivot carries that yaw and centres the model inside itself: doing
	# the compensation on the rotated node would push the avatar ~9 m off-centre.
	var fitted := ModelFitterScript.attach(
		self, model_scene, target_height, model_yaw_offset_degrees, "ModelPivot", "CharacterModel"
	)
	if fitted.is_empty():
		_keep_fallback("no measurable model")
		return
	_model = fitted["model"] as Node3D
	_model_bounds = fitted["bounds"]
	_model_height = float(fitted["height"])
	# The imported GLB carries the hero's detailed PBR textures. Its old
	# near-black grown material_overlay was drawn over every skinned mesh and
	# risked obscuring that detail at gameplay scale. Keep the original material
	# stack and use anisotropic filtering instead of a full-body outline pass.
	_prepare_character_materials(_model)
	if is_instance_valid(_fallback_body):
		_fallback_body.visible = false
	_setup_rig()
	# One line in the console/log: which model the avatar actually got, how tall it
	# renders and whether the fallback is in use. Read from the browser console
	# during web QA and from the editor log on device.
	print(
		(
			"CharacterVisual: model=%s fitted_height=%.3fm scale=%.3f rig=%s fallback=no"
			% [
				_model.name,
				_model_height,
				_model.scale.y,
				(
					(
						"%s clips=%d"
						% [_rig.get("skeleton", "yes"), _anim_player.get_animation_list().size()]
					)
					if is_rigged()
					else "no"
				)
			]
		)
	)


func _prepare_character_materials(root_node: Node3D) -> void:
	for mesh_instance in ModelFitterScript.meshes_of(root_node):
		# Avoid a dark full-mesh overlay pass that can obscure the imported
		# albedo/normal/metallic-roughness detail at the gameplay camera distance.
		mesh_instance.material_overlay = null
		if mesh_instance.material_override != null:
			var override := mesh_instance.material_override as BaseMaterial3D
			if override != null:
				var local_override := override.duplicate() as BaseMaterial3D
				local_override.texture_filter = CHARACTER_TEXTURE_FILTER
				mesh_instance.material_override = local_override
			continue
		if mesh_instance.mesh == null:
			continue
		for surface_index in range(mesh_instance.mesh.get_surface_count()):
			var imported := mesh_instance.get_active_material(surface_index) as BaseMaterial3D
			if imported == null:
				continue
			var local_material := imported.duplicate() as BaseMaterial3D
			local_material.texture_filter = CHARACTER_TEXTURE_FILTER
			mesh_instance.set_surface_override_material(surface_index, local_material)


func _setup_rig() -> void:
	if not use_rig_animation:
		return
	var skeletons := _model.find_children("*", "Skeleton3D", true, false)
	var players := _model.find_children("*", "AnimationPlayer", true, false)
	if skeletons.is_empty() or players.is_empty():
		return
	_skeleton = skeletons[0] as Skeleton3D
	_anim_player = players[0] as AnimationPlayer
	if _skeleton == null or _anim_player == null:
		return
	_rig = _load_rig()
	if _rig.is_empty():
		push_warning("CharacterVisual: %s is missing; the hero stays unrigged." % rig_path)
		_skeleton = null
		_anim_player = null
		return
	var hand_bone := str(_rig.get("hand_bone", "R_Hand"))
	if _skeleton.find_bone(hand_bone) < 0:
		push_warning("CharacterVisual: bone '%s' not found; the hero stays unrigged." % hand_bone)
		_skeleton = null
		_anim_player = null
		return
	_attachment = BoneAttachment3D.new()
	_attachment.name = "HandAttachment"
	_skeleton.add_child(_attachment)
	_attachment.bone_name = hand_bone

	var socket := _rig.get("weapon_socket", {}) as Dictionary
	_socket_aim_basis = Basis(_quat(socket.get("aim_rotation_xyzw", [0, 0, 0, 1])))
	_socket_carry_basis = Basis(_quat(socket.get("carry_rotation_xyzw", [0, 0, 0, 1])))
	_socket_offset = _vec3(socket.get("offset", [0, 0, 0]))

	# GLB export does not guarantee Godot's loop import flags. Without an
	# explicit loop, a long walk freezes on its last frame; reactions should
	# never loop, and death must remain in its final pose until reset.
	for clip in [
		"idle", "run", "walk", "aim", "aim_walk", "aim_run", "fire", "reload", "hit", "death"
	]:
		if _anim_player.has_animation(clip):
			var animation := _anim_player.get_animation(clip)
			animation.loop_mode = (
				Animation.LOOP_LINEAR
				if clip in ["idle", "run", "walk", "aim", "aim_walk", "aim_run"]
				else Animation.LOOP_NONE
			)
			_anim_player.set_blend_time(clip, "aim", 0.12)
			_anim_player.set_blend_time("aim", clip, 0.12)
	_play("idle", 0.0)


func _load_rig() -> Dictionary:
	if not FileAccess.file_exists(rig_path):
		return {}
	var text := FileAccess.get_file_as_string(rig_path)
	var parsed: Variant = JSON.parse_string(text)
	if parsed is Dictionary:
		return parsed
	return {}


func _has_clip(clip: String) -> bool:
	return _anim_player != null and _anim_player.has_animation(clip)


func _is_locomotion_clip(clip: String) -> bool:
	return clip in ["walk", "run", "aim_walk", "aim_run"]


func _animation_rate_for_clip(clip: String, speed_ratio: float) -> float:
	if clip in ["walk", "aim_walk"]:
		var walk_span := maxf(RUN_ENTER_THRESHOLD - WALK_ENTER_THRESHOLD, 0.001)
		var walk_progress := clampf((speed_ratio - WALK_ENTER_THRESHOLD) / walk_span, 0.0, 1.0)
		return lerpf(WALK_RATE_AT_MIN_SPEED, WALK_RATE_AT_RUN_ENTRY, walk_progress)
	if clip in ["run", "aim_run"]:
		var run_span := maxf(MAX_EXPECTED_SPEED_RATIO - RUN_ENTER_THRESHOLD, 0.001)
		var run_progress := clampf((speed_ratio - RUN_ENTER_THRESHOLD) / run_span, 0.0, 1.0)
		return lerpf(RUN_RATE_AT_ENTRY, RUN_RATE_AT_SPRINT, run_progress)
	return 1.0


func _update_locomotion_flags(speed_ratio: float) -> void:
	# Separate enter/exit speeds prevent the run/walk choice from flickering
	# while acceleration settles just around a threshold.
	if _locomotion_active:
		if speed_ratio <= WALK_EXIT_THRESHOLD:
			_locomotion_active = false
	elif speed_ratio >= WALK_ENTER_THRESHOLD:
		_locomotion_active = true

	if _run_locomotion_active:
		if speed_ratio <= RUN_EXIT_THRESHOLD:
			_run_locomotion_active = false
	elif speed_ratio >= RUN_ENTER_THRESHOLD:
		_run_locomotion_active = true
	if not _locomotion_active:
		_run_locomotion_active = false


func _play(clip: String, blend: float = 0.18, speed: float = -1.0) -> void:
	if not _has_clip(clip):
		return
	var playback_speed := (
		_animation_rate_for_clip(clip, _last_speed_ratio) if speed < 0.0 else speed
	)
	_anim_player.speed_scale = playback_speed
	if clip == _current_clip:
		return

	var normalized_phase := -1.0
	if _is_locomotion_clip(_current_clip) and _is_locomotion_clip(clip):
		if _has_clip(_current_clip):
			var previous_length := _anim_player.get_animation(_current_clip).length
			if previous_length > 0.0:
				normalized_phase = fposmod(
					_anim_player.current_animation_position / previous_length, 1.0
				)
	_current_clip = clip
	_anim_player.play(clip, blend)
	if normalized_phase >= 0.0:
		var next_length := _anim_player.get_animation(clip).length
		if next_length > 0.0:
			_anim_player.seek(normalized_phase * next_length, true)


func _update_locomotion(speed_ratio: float) -> void:
	if not is_rigged():
		return
	_update_locomotion_flags(speed_ratio)
	# Blender-authored composite clips keep the moving lower body instead of
	# pinning the legs to a standing aim pose. A real hip-fire briefly shoulders
	# the weapon as well; ADS still controls the camera, not whether the hero
	# animates a shot. The socket follows the chosen clip in either case.
	var desired := "idle"
	var combat_aim := _aiming or _fire_remaining > 0.0
	if _defeated and _has_clip("death"):
		desired = "death"
	elif _hit_remaining > 0.0 and _has_clip("hit"):
		desired = "hit"
	elif _reload_remaining > 0.0 and _has_clip("reload"):
		desired = "reload"
	elif combat_aim and _run_locomotion_active and _has_clip("aim_run"):
		desired = "aim_run"
	elif combat_aim and _locomotion_active and _has_clip("aim_walk"):
		desired = "aim_walk"
	elif _fire_remaining > 0.0 and _has_clip("fire"):
		desired = "fire"
	elif _aiming:
		desired = "aim"
	elif _run_locomotion_active:
		desired = "run"
	elif _locomotion_active:
		desired = "walk"

	var clip_speed := _animation_rate_for_clip(desired, speed_ratio)
	if desired == "reload":
		var clip_length := _anim_player.get_animation("reload").length
		clip_speed = clip_length / maxf(_reload_remaining, 0.01)
	_play(desired, 0.18, clip_speed)


## Blend the weapon socket between the aim and carry rotations and follow the
## hand bone. The socket stays a child of VisualRoot (combat code and the smoke
## tests address `VisualRoot/WeaponSocket/Muzzle` directly), so its global
## transform is copied from the BoneAttachment3D instead of being re-parented.
func _blend_socket(delta: float) -> void:
	if not is_instance_valid(_weapon_socket) or not is_instance_valid(_attachment):
		return
	var target := (
		1.0 if _current_clip in ["aim", "aim_walk", "aim_run", "fire", "reload", "hit"] else 0.0
	)
	var step := delta / maxf(weapon_socket_blend_seconds, 0.01)
	_socket_weight = move_toward(_socket_weight, target, step)
	var basis := _socket_carry_basis.slerp(_socket_aim_basis, _socket_weight)
	# In the actual WebGL player camera, three Blender reload attempts kept the
	# receiver hidden behind the hero even though the hands visibly moved. Turn
	# the *actual rifle about its grip* during the authored receiver-check hold;
	# its MuzzlePoint, flash and mesh remain the same transform. This is a
	# weapon-specific presentation offset, not a cosmetic floating gun or a new
	# projectile origin. Ease back to true aim BEFORE the ammo timer completes so
	# the first legal post-reload shot always leaves an aligned barrel.
	if _reload_remaining > 0.0 and _reload_total > 0.0 and _current_clip == "reload":
		var reload_phase := clampf(1.0 - _reload_remaining / _reload_total, 0.0, 1.0)
		var reveal := smoothstep(0.04, 0.28, reload_phase)
		var recover := 1.0 - smoothstep(0.70, 0.96, reload_phase)
		var grip_yaw := deg_to_rad(reload_weapon_yaw_degrees * reveal * recover)
		basis = basis * Basis(Vector3.UP, grip_yaw)
	_weapon_socket.global_transform = (
		_attachment.global_transform * Transform3D(basis, _socket_offset)
	)


# --- weapon ----------------------------------------------------------------


func _spawn_weapon() -> void:
	if weapon_scene == null or not is_instance_valid(_weapon_socket):
		return
	if is_rigged():
		_spawn_rigged_weapon()
		return
	var instance := weapon_scene.instantiate()
	if not instance is Node3D:
		push_warning("CharacterVisual: weapon scene did not instantiate as Node3D.")
		return
	var weapon := instance as Node3D
	weapon.name = "WeaponModel"
	_weapon_socket.add_child(weapon)

	var bounds := ModelFitterScript.combined_bounds(weapon)
	if bounds.size.length() <= 0.0001:
		weapon.queue_free()
		return
	# Kit models are authored along different axes; put the longest side on -Z so
	# the barrel always points where the aim ray goes.
	var longest := _longest_axis(bounds.size)
	var axis_rotation := Vector3.ZERO
	if longest == 0:
		axis_rotation.y = deg_to_rad(90.0)
	elif longest == 1:
		axis_rotation.x = deg_to_rad(-90.0)
	weapon.rotation = Vector3(
		axis_rotation.x + deg_to_rad(weapon_pitch_degrees),
		axis_rotation.y + deg_to_rad(weapon_yaw_offset_degrees),
		axis_rotation.z
	)
	# Re-measure after the rotation: the long side now runs along Z.
	var rotated_bounds := ModelFitterScript.combined_bounds(weapon)
	var length := maxf(rotated_bounds.size.z, 0.0001)
	var fit := weapon_length / length
	weapon.scale = Vector3.ONE * fit
	var center := rotated_bounds.position + rotated_bounds.size * 0.5
	weapon.position = Vector3(-center.x * fit, -center.y * fit, -center.z * fit)


## Rigged path: the socket lives under the hand bone, the rifle is pre-authored
## with the barrel on -Z and the grip at the origin, and the muzzle marker is
## copied from the rifle's own MuzzlePoint so the flash starts at the barrel.
func _spawn_rigged_weapon() -> void:
	_weapon_socket.transform = Transform3D(_socket_carry_basis, _socket_offset)
	_weapon_socket_base_position = _weapon_socket.position
	_weapon_socket_base_rotation = _weapon_socket.rotation

	var instance := weapon_scene.instantiate()
	if not instance is Node3D:
		push_warning("CharacterVisual: rigged weapon scene did not instantiate as Node3D.")
		return
	var weapon := instance as Node3D
	weapon.name = "WeaponModel"
	weapon.scale = (
		Vector3.ONE
		* float((_rig.get("weapon_socket", {}) as Dictionary).get("scale_model_units", 0.4))
	)
	_weapon_socket.add_child(weapon)

	var muzzle_point := weapon.get_node_or_null("MuzzlePoint") as Node3D
	if muzzle_point == null:
		push_warning(
			"CharacterVisual: rigged weapon has no MuzzlePoint; keeping the fallback muzzle."
		)
		return
	var local := _weapon_socket.global_transform.affine_inverse() * muzzle_point.global_transform
	if is_instance_valid(_muzzle_marker):
		_muzzle_marker.transform = local
	if is_instance_valid(_muzzle_flash):
		# Same place, but unscaled: the flash is sized for metres, not for the
		# rifle's 0.4x model scale.
		_muzzle_flash.transform = Transform3D(
			Basis(local.basis.get_rotation_quaternion()), local.origin
		)


static func _longest_axis(size_vector: Vector3) -> int:
	if size_vector.x >= size_vector.y and size_vector.x >= size_vector.z:
		return 0
	if size_vector.y >= size_vector.z:
		return 1
	return 2


static func _quat(values: Variant) -> Quaternion:
	var list := values as Array
	if list == null or list.size() < 4:
		return Quaternion.IDENTITY
	return Quaternion(float(list[0]), float(list[1]), float(list[2]), float(list[3]))


static func _vec3(values: Variant) -> Vector3:
	var list := values as Array
	if list == null or list.size() < 3:
		return Vector3.ZERO
	return Vector3(float(list[0]), float(list[1]), float(list[2]))


func _keep_fallback(reason: String) -> void:
	push_warning("CharacterVisual: using the fallback capsule (%s)." % reason)
	if is_instance_valid(_fallback_body):
		_fallback_body.visible = true
