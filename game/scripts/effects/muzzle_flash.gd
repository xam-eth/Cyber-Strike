class_name MuzzleFlash
extends Node3D

## Short-lived muzzle flash: an emissive blob plus a point light, both switched on
## for a few frames when a shot leaves the weapon.
##
## Why it matters: the projectiles are small spheres, so without a flash at the
## weapon the shot reads as coming from nowhere. The light is the part that sells
## it — the world is bright, and a hot flash on the astronaut's rifle is the only
## local contrast in the frame.
##
## Nodes: this scene is placed at the weapon muzzle as a child so it inherits the
## aim direction; the flash itself is turned to face the camera nowhere — a small
## sphere is direction-independent and costs one draw.

@export_range(0.02, 0.4, 0.005) var duration: float = 0.09
@export_range(0.0, 12.0, 0.1) var flash_energy: float = 4.5
@export_range(0.02, 2.0, 0.01) var flash_scale: float = 0.34
@export var flash_color: Color = Color(1.0, 0.82, 0.45, 1.0)

var _mesh: MeshInstance3D
var _light: OmniLight3D
var _material: StandardMaterial3D
var _remaining: float = 0.0
# Frame the flash was triggered on. A slow device can have a frame delta longer
# than the flash itself, and then the very frame that lit it would also clear it,
# so the flash would never be drawn at all. Skipping the first decay guarantees
# at least one rendered frame.
var _trigger_frame: int = -1


func _ready() -> void:
	_material = StandardMaterial3D.new()
	_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_material.albedo_color = flash_color
	_material.emission_enabled = true
	_material.emission = flash_color
	_material.emission_energy_multiplier = flash_energy
	# Additive blending keeps the flash from turning the rifle into a grey blob
	# behind it: it adds light instead of painting over the model.
	_material.blend_mode = BaseMaterial3D.BLEND_MODE_ADD

	var sphere := SphereMesh.new()
	sphere.radius = 0.5
	sphere.height = 1.0
	sphere.radial_segments = 12
	sphere.rings = 6
	_mesh = MeshInstance3D.new()
	_mesh.name = "FlashMesh"
	_mesh.mesh = sphere
	_mesh.material_override = _material
	_mesh.scale = Vector3.ONE * flash_scale
	_mesh.visible = false
	_mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_mesh)

	_light = OmniLight3D.new()
	_light.name = "FlashLight"
	_light.light_color = flash_color
	_light.light_energy = 0.0
	_light.omni_range = 5.5
	_light.shadow_enabled = false
	add_child(_light)


func _process(delta: float) -> void:
	if _remaining <= 0.0:
		return
	if Engine.get_process_frames() == _trigger_frame:
		return
	_remaining = maxf(_remaining - delta, 0.0)
	var ratio := _remaining / maxf(duration, 0.0001)
	_light.light_energy = flash_energy * ratio
	_material.albedo_color.a = clampf(ratio * 1.6, 0.0, 1.0)
	if _remaining <= 0.0:
		_mesh.visible = false
		_light.light_energy = 0.0


## Fire the flash. Called once per shot, never per frame.
func flash(strength: float = 1.0) -> void:
	_remaining = duration * clampf(strength, 0.4, 2.0)
	_trigger_frame = Engine.get_process_frames()
	_mesh.visible = true
	_material.albedo_color.a = 1.0
	_light.light_energy = flash_energy
	_mesh.rotation.z = randf() * TAU
	_mesh.scale = Vector3.ONE * flash_scale * randf_range(0.85, 1.2)


func is_flashing() -> bool:
	return _remaining > 0.0
