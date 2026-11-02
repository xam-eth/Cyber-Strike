class_name EnemyVisual
extends Node3D

## Presentation layer shared by all robot enemy archetypes.
##
## Binds rigged 3D robot `.glb` models (`Skeleton3D` + `AnimationPlayer` +
## `BoneAttachment3D` `R_Hand` socket from `*_rig.json`), attaches a 3D weapon
## mesh (`rifle.glb` / `nova_launcher.glb`) aligned to `MuzzlePoint`, drives
## skeletal locomotion/aim/fire/hit/death clips, and falls back gracefully if an
## isolated test fixture supplies a static or missing model.

const ModelFitterScript = preload("res://scripts/visual/model_fitter.gd")
const RUN_THRESHOLD := 0.52
const WALK_THRESHOLD := 0.06
const FIRE_CLIP_SECONDS := 0.42
const HIT_CLIP_SECONDS := 0.24

@export var model_scene: PackedScene
@export var model_scene_path: String = ""
@export var weapon_scene: PackedScene
@export var weapon_scene_path: String = ""
@export var rig_path: String = ""
@export_range(0.3, 3.2, 0.01) var target_size: float = 1.9
@export_enum("Width", "Height", "Depth") var fit_axis: int = 1
@export_range(-180.0, 180.0, 1.0) var model_yaw_offset_degrees: float = 180.0
@export var outline_color: Color = Color(0.04, 0.03, 0.06, 1.0)
@export_range(0.0, 0.12, 0.002) var outline_grow: float = 0.018
@export_group("Motion")
@export var hover: bool = false
@export_range(0.0, 2.0, 0.01) var bob_amplitude: float = 0.04
@export_range(0.0, 20.0, 0.1) var bob_frequency: float = 6.5
@export_range(0.0, 1.0, 0.01) var hover_lift: float = 0.0
@export_range(0.0, 30.0, 0.5) var run_pitch_degrees: float = 6.0
@export_range(1.0, 30.0, 0.5) var speed_reference: float = 3.8
@export_group("Feedback")
@export var hit_flash_color: Color = Color(1.0, 0.94, 0.86, 1.0)
@export_range(0.02, 1.0, 0.01) var hit_flash_seconds: float = 0.12
@export_range(0.1, 2.5, 0.01) var death_seconds: float = 0.85
@export_range(0.0, 1.0, 0.01) var death_sink: float = 0.35

var _model: Node3D
var _mesh_height: float = 0.0
var _fitted_scale: float = 1.0
var _base_position: Vector3 = Vector3.ZERO

var _rig: Dictionary = {}
var _skeleton: Skeleton3D = null
var _anim_player: AnimationPlayer = null
var _attachment: BoneAttachment3D = null
var _weapon_socket: Node3D = null
var _weapon_model: Node3D = null
var _weapon_muzzle_point: Node3D = null
var _socket_aim_basis: Basis = Basis.IDENTITY
var _socket_carry_basis: Basis = Basis.IDENTITY
var _socket_offset: Vector3 = Vector3.ZERO
var _socket_weight: float = 0.0
var _current_clip: String = ""
var _aiming: bool = false
var _fire_remaining: float = 0.0
var _hit_remaining: float = 0.0
var _last_speed_ratio: float = 0.0

var _outline: StandardMaterial3D
var _flash: StandardMaterial3D
var _flash_remaining: float = 0.0
var _bob_phase: float = 0.0
var _bob_offset: float = 0.0
var _dying: bool = false
var _death_remaining: float = 0.0
var _death_tween: Tween

@onready var _fallback_body: MeshInstance3D = get_node_or_null("BodyMesh")
@onready var _muzzle_marker: Marker3D = get_node_or_null("Muzzle")


func _ready() -> void:
	_outline = ModelFitterScript.outline_material(outline_color, outline_grow)
	_flash = ModelFitterScript.flash_material(hit_flash_color)
	var selected_scene := model_scene
	if selected_scene == null and not model_scene_path.is_empty():
		var result := ContentModuleLoader.load_scene(
			model_scene_path, ContentModuleLoader.CHARACTER_ROOTS
		)
		if not bool(result["ok"]):
			_keep_fallback("%s: %s" % [result["code"], result["message"]])
			return
		selected_scene = result["scene"] as PackedScene
	var fitted := ModelFitterScript.attach(
		self,
		selected_scene,
		target_size,
		model_yaw_offset_degrees,
		"ModelPivot",
		"EnemyModel",
		fit_axis
	)
	if fitted.is_empty():
		_keep_fallback("no measurable model")
		return
	_model = fitted["model"] as Node3D
	_mesh_height = float(fitted["height"])
	_fitted_scale = _model.scale.y
	_base_position = _model.position
	if is_instance_valid(_fallback_body):
		_fallback_body.visible = false
	_bind_rig()
	_spawn_weapon()
	_apply_overlays(_outline)
	print(
		(
			"EnemyVisual[%s]: model=%s fitted_height=%.3fm rigged=%s fallback=no"
			% [
				get_parent().name if get_parent() != null else name,
				_model.name,
				_mesh_height,
				"yes" if is_rigged() else "no",
			]
		)
	)


func _process(delta: float) -> void:
	if _flash_remaining > 0.0:
		_flash_remaining = maxf(_flash_remaining - delta, 0.0)
		if _flash_remaining <= 0.0 and not _dying:
			_apply_overlays(_outline)
	if _fire_remaining > 0.0:
		_fire_remaining = maxf(_fire_remaining - delta, 0.0)
	if _hit_remaining > 0.0:
		_hit_remaining = maxf(_hit_remaining - delta, 0.0)
	if _dying and _death_remaining > 0.0:
		_death_remaining = maxf(_death_remaining - delta, 0.0)
		if _death_remaining <= 0.0:
			visible = false
	if is_rigged():
		_update_rig_locomotion(_last_speed_ratio)
		_blend_weapon_socket(delta)


func has_model() -> bool:
	return _model != null and is_instance_valid(_model)


func is_rigged() -> bool:
	return _skeleton != null and _anim_player != null


func has_weapon_model() -> bool:
	return _weapon_model != null and is_instance_valid(_weapon_model)


func visual_height() -> float:
	return _mesh_height if has_model() else 1.7


func is_dying() -> bool:
	return _dying


func set_aiming(value: bool) -> void:
	_aiming = value


func play_attack() -> void:
	if _dying:
		return
	_fire_remaining = FIRE_CLIP_SECONDS
	if is_rigged() and _anim_player.has_animation("fire"):
		_current_clip = "fire"
		_anim_player.stop()
		_anim_player.play("fire", 0.08, 1.0)


func update_motion(velocity: Vector3, delta: float) -> void:
	if _dying or not has_model():
		return
	var speed := Vector2(velocity.x, velocity.z).length()
	var speed_ratio := clampf(speed / maxf(speed_reference, 0.001), 0.0, 1.4)
	_last_speed_ratio = speed_ratio
	if is_rigged():
		_model.position = _base_position
		_model.rotation.x = lerpf(
			_model.rotation.x, speed_ratio * deg_to_rad(run_pitch_degrees * 0.45), 7.0 * delta
		)
		return
	if hover:
		_bob_phase = fmod(_bob_phase + bob_frequency * delta * (0.35 + speed_ratio), TAU)
		_bob_offset = hover_lift + sin(_bob_phase) * bob_amplitude
		_model.rotation.z = lerpf(_model.rotation.z, sin(_bob_phase * 0.5) * 0.08, 6.0 * delta)
		_model.rotation.x = lerpf(
			_model.rotation.x, -velocity.dot(Vector3.FORWARD) / speed_reference * 0.12, 6.0 * delta
		)
		_model.position.y = _bob_offset
		return
	if speed_ratio > 0.05:
		_bob_phase = fmod(_bob_phase + bob_frequency * speed_ratio * delta, TAU)
		_bob_offset = absf(sin(_bob_phase)) * bob_amplitude
	else:
		_bob_phase = 0.0
		_bob_offset = lerpf(_bob_offset, 0.0, 6.0 * delta)
	_model.position.y = _bob_offset
	_model.rotation.x = lerpf(
		_model.rotation.x, speed_ratio * deg_to_rad(run_pitch_degrees), 7.0 * delta
	)


func play_hit_flash() -> void:
	if _dying:
		return
	_flash_remaining = hit_flash_seconds
	_hit_remaining = HIT_CLIP_SECONDS
	_apply_overlays(_flash)


func play_death() -> void:
	if _dying:
		return
	_dying = true
	_flash_remaining = 0.0
	_fire_remaining = 0.0
	_hit_remaining = 0.0
	_apply_overlays(_outline)
	if not has_model():
		visible = false
		return
	if _death_tween != null and _death_tween.is_valid():
		_death_tween.kill()
	if is_rigged() and _anim_player.has_animation("death"):
		_current_clip = "death"
		_anim_player.play("death", 0.12, 1.0)
		var clip_len := maxf(_anim_player.get_animation("death").length, death_seconds)
		_death_remaining = clip_len
		_death_tween = create_tween()
		_death_tween.tween_interval(clip_len)
		_death_tween.tween_callback(func() -> void: visible = false)
		return
	_death_remaining = death_seconds
	_death_tween = create_tween()
	_death_tween.set_parallel(true)
	(
		_death_tween
		. tween_property(_model, "scale", _model.scale * Vector3(1.1, 0.12, 1.1), death_seconds)
		. set_trans(Tween.TRANS_QUAD)
		. set_ease(Tween.EASE_IN)
	)
	_death_tween.tween_property(
		_model, "position:y", _model.position.y - death_sink, death_seconds * 0.8
	)
	_death_tween.chain().tween_callback(func() -> void: visible = false)


func reset_visual() -> void:
	if _death_tween != null and _death_tween.is_valid():
		_death_tween.kill()
	_dying = false
	_death_remaining = 0.0
	_flash_remaining = 0.0
	_fire_remaining = 0.0
	_hit_remaining = 0.0
	_aiming = false
	_last_speed_ratio = 0.0
	_current_clip = ""
	visible = true
	if has_model():
		_model.scale = Vector3.ONE * _fitted_scale
		_model.position = _base_position
		_model.rotation = Vector3.ZERO
		_bob_phase = 0.0
		_bob_offset = 0.0
	if is_rigged():
		_play_clip("idle", 0.0)
	_apply_overlays(_outline)
	if is_instance_valid(_fallback_body):
		_fallback_body.visible = not has_model()


func _bind_rig() -> void:
	if not has_model():
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
	var hand_bone := str(_rig.get("hand_bone", "R_Hand"))
	if _skeleton.find_bone(hand_bone) >= 0:
		_attachment = BoneAttachment3D.new()
		_attachment.name = "HandAttachment"
		_skeleton.add_child(_attachment)
		_attachment.bone_name = hand_bone
	var socket := _rig.get("weapon_socket", {}) as Dictionary
	_socket_aim_basis = Basis(_quat(socket.get("aim_rotation_xyzw", [0, 0, 0, 1])))
	_socket_carry_basis = Basis(_quat(socket.get("carry_rotation_xyzw", [0, 0, 0, 1])))
	_socket_offset = _vec3(socket.get("offset", [0, 0, 0]))
	for clip in [
		"idle", "run", "walk", "aim", "aim_walk", "aim_run", "fire", "reload", "hit", "death"
	]:
		if _anim_player.has_animation(clip):
			var anim := _anim_player.get_animation(clip)
			anim.loop_mode = (
				Animation.LOOP_LINEAR
				if clip in ["idle", "run", "walk", "aim", "aim_walk", "aim_run"]
				else Animation.LOOP_NONE
			)
	_play_clip("idle", 0.0)


func _spawn_weapon() -> void:
	var selected_weapon := weapon_scene
	if selected_weapon == null and not weapon_scene_path.is_empty():
		var result := ContentModuleLoader.load_scene(
			weapon_scene_path, ContentModuleLoader.CHARACTER_ROOTS
		)
		if bool(result["ok"]):
			selected_weapon = result["scene"] as PackedScene
	if selected_weapon == null or not is_instance_valid(_attachment):
		return
	_weapon_socket = Node3D.new()
	_weapon_socket.name = "EnemyWeaponSocket"
	add_child(_weapon_socket)
	_weapon_socket.transform = Transform3D(_socket_carry_basis, _socket_offset)
	var instance := selected_weapon.instantiate()
	if not instance is Node3D:
		if instance != null:
			instance.free()
		return
	_weapon_model = instance as Node3D
	_weapon_model.name = "EnemyWeapon"
	var scale_units := float(
		(_rig.get("weapon_socket", {}) as Dictionary).get("scale_model_units", 0.4)
	)
	_weapon_model.scale = Vector3.ONE * scale_units
	_weapon_socket.add_child(_weapon_model)
	_weapon_muzzle_point = _weapon_model.get_node_or_null("MuzzlePoint") as Node3D


func _update_rig_locomotion(speed_ratio: float) -> void:
	if _dying:
		return
	var desired := "idle"
	var combat_aim := _aiming or _fire_remaining > 0.0
	if _hit_remaining > 0.0 and _anim_player.has_animation("hit"):
		desired = "hit"
	elif combat_aim and speed_ratio > RUN_THRESHOLD and _anim_player.has_animation("aim_run"):
		desired = "aim_run"
	elif combat_aim and speed_ratio > WALK_THRESHOLD and _anim_player.has_animation("aim_walk"):
		desired = "aim_walk"
	elif _fire_remaining > 0.0 and _anim_player.has_animation("fire"):
		desired = "fire"
	elif _aiming and _anim_player.has_animation("aim"):
		desired = "aim"
	elif speed_ratio > RUN_THRESHOLD and _anim_player.has_animation("run"):
		desired = "run"
	elif speed_ratio > WALK_THRESHOLD and _anim_player.has_animation("walk"):
		desired = "walk"
	_play_clip(desired, 0.16)


func _blend_weapon_socket(delta: float) -> void:
	if not is_instance_valid(_weapon_socket) or not is_instance_valid(_attachment):
		return
	var target := 1.0 if _current_clip in ["aim", "aim_walk", "aim_run", "fire", "hit"] else 0.35
	_socket_weight = move_toward(_socket_weight, target, delta / 0.14)
	var basis := _socket_carry_basis.slerp(_socket_aim_basis, _socket_weight)
	_weapon_socket.global_transform = (
		_attachment.global_transform * Transform3D(basis, _socket_offset)
	)
	if is_instance_valid(_muzzle_marker) and is_instance_valid(_weapon_muzzle_point):
		_muzzle_marker.global_position = _weapon_muzzle_point.global_position


func _play_clip(clip: String, blend: float = 0.16) -> void:
	if _anim_player == null or not _anim_player.has_animation(clip) or clip == _current_clip:
		return
	_current_clip = clip
	_anim_player.play(clip, blend, 1.0)


func _load_rig() -> Dictionary:
	var candidate := rig_path
	if candidate.is_empty() and model_scene_path.ends_with(".glb"):
		candidate = model_scene_path.trim_suffix(".glb") + "_rig.json"
	if candidate.is_empty() or not FileAccess.file_exists(candidate):
		return {}
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(candidate))
	return parsed as Dictionary if parsed is Dictionary else {}


static func _quat(values: Variant) -> Quaternion:
	if values is Array and (values as Array).size() >= 4:
		var a := values as Array
		return Quaternion(float(a[0]), float(a[1]), float(a[2]), float(a[3])).normalized()
	return Quaternion.IDENTITY


static func _vec3(values: Variant) -> Vector3:
	if values is Array and (values as Array).size() >= 3:
		var a := values as Array
		return Vector3(float(a[0]), float(a[1]), float(a[2]))
	return Vector3.ZERO


func _apply_overlays(material: Material) -> void:
	ModelFitterScript.apply_overlay_material(self, material)
	if is_instance_valid(_fallback_body):
		_fallback_body.material_overlay = material


func _keep_fallback(reason: String) -> void:
	push_warning("EnemyVisual: using the fallback mesh (%s)." % reason)
	if not is_instance_valid(_fallback_body):
		var emergency := MeshInstance3D.new()
		emergency.name = "BodyMesh"
		var cap := CapsuleMesh.new()
		cap.radius = 0.38
		cap.height = maxf(target_size, 1.6)
		emergency.mesh = cap
		emergency.position = Vector3(0.0, cap.height * 0.5, 0.0)
		add_child(emergency)
		_fallback_body = emergency
	_fallback_body.visible = true
	visible = true
