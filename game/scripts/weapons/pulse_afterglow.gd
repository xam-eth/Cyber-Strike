class_name PulseAfterglow
extends Node3D

## A short-lived wake left by a *real* Pulse bolt on collision. On WebGL a
## 42 m/s bolt can cross the view and vanish in a single rendered frame; this
## narrow cyan segment stays at *up to* the last 2 m of its travelled path for
## one extra beat so the action is legible. Close to the camera, this is further
## capped by its projected width: a near-floor shot must not paint a white spear
## across the hero. No trail extends past the real collision point.
const GROUP := "pulse_afterglows"
const DURATION := 0.22
const MAX_LENGTH := 2.0

var _core_material: StandardMaterial3D
var _halo_material: StandardMaterial3D
var _age: float = 0.0
var _trigger_frame: int = -1


static func spawn(parent: Node, start: Vector3, hit: Vector3) -> PulseAfterglow:
	var travelled := hit - start
	if parent == null or not parent.is_inside_tree() or travelled.length_squared() < 0.05:
		return null
	var glow := PulseAfterglow.new()
	glow.name = "PulseAfterglow"
	parent.add_child(glow)
	var direction := travelled.normalized()
	var length := screen_limited_length(
		parent, hit, direction, minf(travelled.length(), MAX_LENGTH)
	)
	glow.global_position = hit - direction * length * 0.5
	var up := Vector3.FORWARD if absf(direction.dot(Vector3.UP)) > 0.96 else Vector3.UP
	glow.look_at(hit, up)
	glow._build(length)
	glow._trigger_frame = Engine.get_process_frames()
	return glow


## Cap both the in-flight tracer and its collision wake by their actual screen
## projection. Foreshortened distant shots retain their world-space length;
## side-on close shots are cut short without changing collision or damage.
static func screen_limited_length(
	context: Node, end: Vector3, direction: Vector3, length: float
) -> float:
	if context == null or not context.is_inside_tree() or length <= 0.0:
		return length
	var viewport := context.get_viewport()
	var camera := viewport.get_camera_3d()
	var start := end - direction * length
	if camera == null or camera.is_position_behind(start) or camera.is_position_behind(end):
		return length
	var projected_span := camera.unproject_position(start).distance_to(
		camera.unproject_position(end)
	)
	if projected_span < 0.01:
		return length
	return length * minf(1.0, viewport.get_visible_rect().size.x * 0.075 / projected_span)


func _ready() -> void:
	add_to_group(GROUP)


func _build(length: float) -> void:
	# The bright core is not a full-distance laser. Both meshes have their own
	# materials so several simultaneous shots can fade independently.
	_core_material = _material(Color(0.42, 0.93, 1.0, 0.76), 1.35)
	_halo_material = _material(Color(0.06, 0.65, 1.0, 0.19), 0.8)
	_add_capsule("Core", length, 0.038, _core_material)
	_add_capsule("Halo", length, 0.105, _halo_material)


func _add_capsule(
	part_name: String, length: float, radius: float, material: StandardMaterial3D
) -> void:
	var part := MeshInstance3D.new()
	part.name = part_name
	part.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var capsule := CapsuleMesh.new()
	capsule.radius = radius
	capsule.height = maxf(length, radius * 2.0 + 0.01)
	part.mesh = capsule
	part.material_override = material
	part.rotation.x = deg_to_rad(90.0)
	add_child(part)


func _material(color: Color, energy: float) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	material.albedo_color = color
	material.emission_enabled = true
	material.emission = Color(color.r, color.g, color.b)
	material.emission_energy_multiplier = energy
	material.depth_draw_mode = BaseMaterial3D.DEPTH_DRAW_DISABLED
	return material


func _process(delta: float) -> void:
	# Preserve the first rendered frame even if a slow WebGL frame exceeds the
	# entire lifetime. Physics resolves before rendering on that frame.
	if Engine.get_process_frames() == _trigger_frame:
		return
	_age += delta
	if _age >= DURATION:
		queue_free()
		return
	var fade := pow(1.0 - _age / DURATION, 1.5)
	if _core_material != null:
		var core_color := _core_material.albedo_color
		core_color.a = 0.76 * fade
		_core_material.albedo_color = core_color
	if _halo_material != null:
		var halo_color := _halo_material.albedo_color
		halo_color.a = 0.19 * fade
		_halo_material.albedo_color = halo_color
