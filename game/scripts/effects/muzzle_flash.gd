class_name MuzzleFlash
extends Node3D

## A directional flash anchored to the weapon's measured MuzzlePoint. The cone
## projects along local -Z (the barrel axis); short radial sparks break the
## round "glowing ball" silhouette without covering the sight line. Every mesh
## is transient and the accompanying light has a bounded range for mobile/Web.

const GLINT_MASK: Texture2D = preload("res://assets/vfx/muzzle_glint.png")
# A near-side view of the billboard filled ~100 CSS px on a 390 px phone when
# the player looked down at the floor. Keep the flare readable but bounded.
const MAX_GLINT_VIEW_WIDTH: float = 0.095

@export_range(0.02, 0.4, 0.005) var duration: float = 0.15
@export_range(0.0, 12.0, 0.1) var flash_energy: float = 2.8
@export_range(0.02, 2.0, 0.01) var flash_scale: float = 0.48
@export var flash_color: Color = Color(1.0, 0.74, 0.4, 1.0)

var _mesh: MeshInstance3D
var _core: MeshInstance3D
var _glint: MeshInstance3D
var _glint_material: StandardMaterial3D
var _streaks: Array[MeshInstance3D] = []
var _light: OmniLight3D
var _material: StandardMaterial3D
var _hot_core_material: StandardMaterial3D
var _remaining: float = 0.0
var _reduce_flash: bool = false
# Preserve at least one render even when device frame time exceeds duration.
var _trigger_frame: int = -1


func _ready() -> void:
	_material = StandardMaterial3D.new()
	_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_material.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	_material.albedo_color = flash_color
	_material.emission_enabled = true
	_material.emission = flash_color
	_material.emission_energy_multiplier = flash_energy * 0.8
	_hot_core_material = _material.duplicate() as StandardMaterial3D

	# The stage28 two-fin candidate became an opaque cyan kite over the
	# shoulder at 390px wide. A muzzle discharge is a *short axial glint*,
	# not a shield or a decorative symbol. Keep its core at the muzzle and
	# let a tapered, translucent plume and two hairline streaks lead forward.
	var cone := CylinderMesh.new()
	cone.top_radius = 0.002
	# The previous 0.38 m / 0.072 m cone became a broad white triangle
	# when a real touch-look aimed at nearby imported floor. Let the core
	# and bounded glint carry the beat; the cone only bridges the barrel.
	cone.bottom_radius = 0.036
	cone.height = 0.19
	cone.radial_segments = 9
	_mesh = _add_shape("FlashCone", cone)
	_mesh.rotation.x = -PI * 0.5
	_mesh.position.z = -0.16

	var core_mesh := SphereMesh.new()
	core_mesh.radius = 0.072
	core_mesh.height = 0.144
	core_mesh.radial_segments = 10
	core_mesh.rings = 5
	_core = _add_shape("FlashCore", core_mesh)
	_core.position.z = -0.11
	_core.material_override = _hot_core_material

	# The face-on alpha flare supplies the pixels a nearly head-on barrel cone
	# cannot provide at 390px, without a large opaque mesh crossing the helmet.
	# It sits ahead of the measured muzzle. Keep-scale and two-sided are
	# necessary for a visible small billboard; the brief glint is rendered on
	# top of the shoulder rather than being fully occluded on a phone screen.
	_glint_material = StandardMaterial3D.new()
	_glint_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_glint_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_glint_material.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	_glint_material.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	_glint_material.billboard_keep_scale = true
	_glint_material.cull_mode = BaseMaterial3D.CULL_DISABLED
	_glint_material.no_depth_test = true
	_glint_material.albedo_texture = GLINT_MASK
	_glint_material.albedo_color = Color(1.0, 1.0, 1.0, 0.95)
	_glint_material.emission_enabled = true
	_glint_material.emission = Color.WHITE
	_glint_material.emission_energy_multiplier = 1.4
	var glint_quad := QuadMesh.new()
	# The broad stage39 mask on a 0.62m quad made a white cloud over the hero.
	# A narrower alpha-painted streak sits in front of the barrel, not across
	# the rifle/helmet. Only a real shot screenshot can accept this treatment.
	glint_quad.size = Vector2(0.58, 0.58)
	_glint = _add_shape("FlashGlint", glint_quad)
	_glint.position.z = -0.31
	_glint.material_override = _glint_material

	var streak_mesh := BoxMesh.new()
	streak_mesh.size = Vector3(0.018, 0.052, 0.21)
	for index in range(2):
		var streak := _add_shape("FlashSpark_%d" % index, streak_mesh)
		streak.position = Vector3(0.095 + 0.018 * index, 0.05 - 0.1 * index, -0.24)
		streak.rotation.x = 0.18 if index == 0 else -0.15
		streak.rotation.y = -0.34 if index == 0 else -0.2
		_streaks.append(streak)

	_light = OmniLight3D.new()
	_light.name = "FlashLight"
	_light.light_color = flash_color
	_light.light_energy = 0.0
	# Tight transient bounce around the weapon; broad cyan ground wash hid
	# the FBX material contrast in the WebGL phone capture.
	_light.omni_range = 1.35
	_light.shadow_enabled = false
	add_child(_light)


func _add_shape(node_name: String, shape: Mesh) -> MeshInstance3D:
	var mesh := MeshInstance3D.new()
	mesh.name = node_name
	mesh.mesh = shape
	mesh.material_override = _material
	mesh.visible = false
	mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mesh)
	return mesh


func _set_active(active: bool) -> void:
	_mesh.visible = active
	_core.visible = active
	_glint.visible = active and not _reduce_flash
	for streak in _streaks:
		streak.visible = active and not _reduce_flash


func set_reduced_flash(value: bool) -> void:
	_reduce_flash = value
	if _mesh != null:
		_set_active(_remaining > 0.0)
	if _light != null and value:
		_light.light_energy = 0.0


func _process(delta: float) -> void:
	if _remaining <= 0.0 or Engine.get_process_frames() == _trigger_frame:
		return
	_remaining = maxf(_remaining - delta, 0.0)
	var ratio := _remaining / maxf(duration, 0.0001)
	_light.light_energy = 0.0 if _reduce_flash else flash_energy * 0.4 * ratio
	_material.albedo_color.a = clampf(ratio * 1.1, 0.0, 0.85)
	_hot_core_material.albedo_color.a = clampf(ratio * 1.9, 0.0, 1.0)
	_glint_material.albedo_color.a = clampf(ratio * 1.4, 0.0, 0.95)
	if _remaining <= 0.0:
		_set_active(false)
		_light.light_energy = 0.0


## Fire from the calibrated barrel point; color distinguishes the three weapon
## discharge types without pretending that they are three different 3D models.
func flash(strength: float = 1.0, tint: Color = Color(0.0, 0.0, 0.0, 0.0)) -> void:
	var color := tint if tint.a > 0.0 else flash_color
	_material.albedo_color = color
	_material.emission = color
	var white_centre := Color.WHITE.lerp(color, 0.32)
	_hot_core_material.albedo_color = white_centre
	_hot_core_material.emission = white_centre
	_hot_core_material.emission_energy_multiplier = 1.2 if _reduce_flash else flash_energy + 0.7
	# Keep a white hot core, but let the wider barrel streak read as PULSE
	# cyan against the now-lighter FBX deck instead of a white smoke smudge.
	_glint_material.albedo_color = Color.WHITE.lerp(color, 0.72)
	_glint_material.emission = Color.WHITE.lerp(color, 0.68)
	_light.light_color = color
	_remaining = duration * clampf(strength, 0.4, 2.0)
	_trigger_frame = Engine.get_process_frames()
	_set_active(true)
	_material.albedo_color.a = 0.85
	_hot_core_material.albedo_color.a = 1.0
	_glint_material.albedo_color.a = 0.95
	_light.light_energy = 0.0 if _reduce_flash else flash_energy * 0.4
	var size := flash_scale / 0.34 * randf_range(0.88, 1.12)
	_mesh.scale = Vector3.ONE * size
	_core.scale = Vector3.ONE * size
	# The face-on billboard can have a huge projected footprint when a close
	# floor shot turns its plane broadside to a steep third-person camera. Cap
	# its actual on-screen width rather than shrinking every normal shot.
	var glint_size := size
	var camera := get_viewport().get_camera_3d()
	if camera != null and not camera.is_position_behind(_glint.global_position):
		var viewport := get_viewport()
		var centre := camera.unproject_position(_glint.global_position)
		var quad := _glint.mesh as QuadMesh
		var edge := camera.unproject_position(
			_glint.global_position + camera.global_basis.x * quad.size.x * size
		)
		var projected_width := centre.distance_to(edge)
		if projected_width > 0.01:
			glint_size *= minf(
				1.0, viewport.get_visible_rect().size.x * MAX_GLINT_VIEW_WIDTH / projected_width
			)
	_glint.scale = Vector3.ONE * glint_size
	for index in range(_streaks.size()):
		var streak := _streaks[index]
		streak.scale = Vector3.ONE * size * (0.85 if index else 1.0)
		streak.rotation.y = (-0.34 if index == 0 else -0.20) + randf_range(-0.04, 0.04)


func is_flashing() -> bool:
	return _remaining > 0.0
