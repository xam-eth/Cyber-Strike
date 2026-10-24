class_name EnemyVisual
extends Node3D

## Presentation layer shared by every enemy: a fitted GLB (Kenney space kit),
## a dark rim so the silhouette reads on a bright floor, procedural locomotion
## motion, a hit flash and a death collapse.
##
## Gameplay code stays untouched: enemies keep their capsules, colliders and
## damage maths; this node only decides what the player sees. If a model is
## missing or unmeasurable, the fallback mesh in the scene stays visible.

const ModelFitterScript = preload("res://scripts/visual/model_fitter.gd")

@export var model_scene: PackedScene
@export_range(0.3, 3.0, 0.01) var target_size: float = 1.7
@export_enum("Width", "Height", "Depth") var fit_axis: int = 1
@export_range(-180.0, 180.0, 1.0) var model_yaw_offset_degrees: float = 180.0
@export var outline_color: Color = Color(0.04, 0.03, 0.06, 1.0)
@export_range(0.0, 0.12, 0.002) var outline_grow: float = 0.022
@export_group("Motion")
@export var hover: bool = false
@export_range(0.0, 2.0, 0.01) var bob_amplitude: float = 0.05
@export_range(0.0, 20.0, 0.1) var bob_frequency: float = 6.5
@export_range(0.0, 1.0, 0.01) var hover_lift: float = 0.0
@export_range(0.0, 30.0, 0.5) var run_pitch_degrees: float = 7.0
@export_range(1.0, 30.0, 0.5) var speed_reference: float = 3.8
@export_group("Feedback")
@export var hit_flash_color: Color = Color(1.0, 0.94, 0.86, 1.0)
@export_range(0.02, 1.0, 0.01) var hit_flash_seconds: float = 0.12
@export_range(0.1, 2.0, 0.01) var death_seconds: float = 0.5
@export_range(0.0, 1.0, 0.01) var death_sink: float = 0.35

var _model: Node3D
var _mesh_height: float = 0.0
var _fitted_scale: float = 1.0
var _base_position: Vector3 = Vector3.ZERO

var _outline: StandardMaterial3D
var _flash: StandardMaterial3D
var _flash_remaining: float = 0.0
var _bob_phase: float = 0.0
var _bob_offset: float = 0.0
var _drifting: bool = false
var _dying: bool = false
var _death_tween: Tween

@onready var _fallback_body: MeshInstance3D = get_node_or_null("BodyMesh")


func _ready() -> void:
	_outline = ModelFitterScript.outline_material(outline_color, outline_grow)
	_flash = ModelFitterScript.flash_material(hit_flash_color)
	var fitted := ModelFitterScript.attach(
		self,
		model_scene,
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
	_apply_overlays(_outline)
	print(
		(
			"EnemyVisual[%s]: model=%s fitted_height=%.3fm fallback=no"
			% [get_parent().name, _model.name, _mesh_height]
		)
	)


func _process(delta: float) -> void:
	if _flash_remaining > 0.0:
		_flash_remaining = maxf(_flash_remaining - delta, 0.0)
		if _flash_remaining <= 0.0 and not _dying:
			_apply_overlays(_outline)


func has_model() -> bool:
	return _model != null and is_instance_valid(_model)


## Height of the rendered enemy; the camera and tests use it to reason about
## framing. Returns the gameplay capsule height when the model is missing.
func visual_height() -> float:
	return _mesh_height if has_model() else 1.7


func is_dying() -> bool:
	return _dying


## Limb-less kit models get their motion from here: a ground enemy bobs and leans
## into its run, a hovering one floats and banks.
func update_motion(velocity: Vector3, delta: float) -> void:
	if _dying or not has_model():
		return
	var speed := Vector2(velocity.x, velocity.z).length()
	var speed_ratio := clampf(speed / maxf(speed_reference, 0.001), 0.0, 1.4)
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
	_apply_overlays(_flash)


## Collapse animation. The enemy node stays in the tree (the wave director owns
## its lifetime) but its visuals shrink and sink, then hide.
func play_death() -> void:
	if _dying:
		return
	_dying = true
	_flash_remaining = 0.0
	_apply_overlays(_outline)
	if not has_model():
		visible = false
		return
	if _death_tween != null and _death_tween.is_valid():
		_death_tween.kill()
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
	_flash_remaining = 0.0
	visible = true
	if has_model():
		_model.scale = Vector3.ONE * _fitted_scale
		_model.position = _base_position
		_model.rotation = Vector3.ZERO
		_bob_phase = 0.0
		_bob_offset = 0.0
	_apply_overlays(_outline)
	if is_instance_valid(_fallback_body):
		_fallback_body.visible = not has_model()


func _apply_overlays(material: Material) -> void:
	ModelFitterScript.apply_overlay_material(self, material)
	if is_instance_valid(_fallback_body):
		_fallback_body.material_overlay = material


func _keep_fallback(reason: String) -> void:
	push_warning("EnemyVisual: using the fallback mesh (%s)." % reason)
	if is_instance_valid(_fallback_body):
		_fallback_body.visible = true
	else:
		visible = true
