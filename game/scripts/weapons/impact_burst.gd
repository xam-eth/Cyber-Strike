class_name ImpactBurst
extends CPUParticles3D

## One-shot spark burst spawned where a shot lands, then freed by itself.
##
## Spawning is a static helper so projectile code stays a one-liner and the parent
## (the current scene, or the root in a test) does not need to know how a burst is
## built. The node frees itself after the particles die: a wave can produce
## dozens of impacts a second, and leaked burst nodes would slowly poison the
## frame time.

const LIFETIME := 0.4
const CLEANUP_DELAY := 0.7
const BURST_GROUP := "impact_bursts"
const DEFAULT_TINT := Color(1.0, 0.72, 0.32, 1.0)

@export var tint: Color = DEFAULT_TINT

# Pulse rounds get a restrained, surface-aligned contact ring around the
# collision point. Leave Nova's separate shockwave and Arc's sparks alone.
var pulse_contact: bool = false
var surface_normal: Vector3 = Vector3.UP
var _light: OmniLight3D
var _contact_ring: MeshInstance3D
var _ring_material: StandardMaterial3D
var _light_age: float = 0.0
var _trigger_frame: int = -1


## Spawns a burst at [param position] under [param parent]. Returns the node so a
## test can inspect it; gameplay ignores the return value.
static func spawn(
	parent: Node,
	position: Vector3,
	color: Color = DEFAULT_TINT,
	normal: Vector3 = Vector3.UP,
	show_pulse_contact: bool = false
) -> ImpactBurst:
	if parent == null or not parent.is_inside_tree():
		return null
	var burst := ImpactBurst.new()
	burst.name = "ImpactBurst"
	burst.tint = color
	burst.pulse_contact = show_pulse_contact
	burst.surface_normal = normal.normalized() if normal.length_squared() > 0.01 else Vector3.UP
	parent.add_child(burst)
	burst.global_position = position
	burst.emitting = true
	var tree := burst.get_tree()
	if tree != null:
		tree.create_timer(CLEANUP_DELAY).timeout.connect(burst.queue_free)
	return burst


func _ready() -> void:
	one_shot = true
	emitting = false
	amount = 22
	lifetime = LIFETIME
	explosiveness = 1.0
	randomness = 0.38
	local_coords = false
	add_to_group(BURST_GROUP)
	cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF

	# Thin tapering metal/energy splinters read as sparks, not voxel confetti.
	# Their one-shot CPU simulation remains available to the Web renderer.
	var spark := CylinderMesh.new()
	spark.top_radius = 0.004
	spark.bottom_radius = 0.022
	spark.height = 0.22
	spark.radial_segments = 5
	mesh = spark
	material_override = _spark_material(tint)

	# Impact direction comes from the actual collision normal (floor, wall or
	# enemy), not a cosmetic always-up burst unrelated to the projectile hit.
	direction = surface_normal
	spread = 58.0
	initial_velocity_min = 2.0
	initial_velocity_max = 5.2
	gravity = Vector3(0.0, -7.5, 0.0)
	scale_amount_min = 0.65
	scale_amount_max = 1.5
	damping_min = 0.5
	damping_max = 1.5
	_light = OmniLight3D.new()
	_light.name = "ImpactBounce"
	_light.light_color = tint
	_light.light_energy = 1.5
	_light.omni_range = 3.0
	_light.shadow_enabled = false
	add_child(_light)
	if pulse_contact:
		_build_contact_ring()
	_trigger_frame = Engine.get_process_frames()


func _process(delta: float) -> void:
	if _light == null or Engine.get_process_frames() == _trigger_frame:
		return
	_light_age += delta
	_light.light_energy = 1.5 * clampf(1.0 - _light_age / 0.22, 0.0, 1.0)
	if _contact_ring != null:
		var progress := clampf(_light_age / 0.3, 0.0, 1.0)
		_contact_ring.scale = Vector3.ONE * (0.9 + progress * 0.55)
		_ring_material.albedo_color.a = 0.58 * (1.0 - progress)
		_ring_material.emission_energy_multiplier = 0.85 * (1.0 - progress)
		_contact_ring.visible = progress < 1.0


func _build_contact_ring() -> void:
	var torus := TorusMesh.new()
	torus.inner_radius = 0.34
	torus.outer_radius = 0.42
	torus.rings = 8
	torus.ring_segments = 32
	_ring_material = StandardMaterial3D.new()
	_ring_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_ring_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_ring_material.cull_mode = BaseMaterial3D.CULL_DISABLED
	_ring_material.albedo_color = Color(tint.r, tint.g, tint.b, 0.58)
	_ring_material.emission_enabled = true
	_ring_material.emission = tint
	_ring_material.emission_energy_multiplier = 0.85
	_contact_ring = MeshInstance3D.new()
	_contact_ring.name = "PulseContactRing"
	_contact_ring.mesh = torus
	_contact_ring.material_override = _ring_material
	_contact_ring.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	# A torus faces +Y. Match the actual collision normal instead of aiming
	# every impact at the camera; the hollow center preserves target visibility.
	_contact_ring.basis = Basis(Quaternion(Vector3.UP, surface_normal))
	_contact_ring.position = surface_normal * 0.065
	add_child(_contact_ring)


func _spark_material(color: Color) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.albedo_color = color
	material.emission_enabled = true
	material.emission = color
	material.emission_energy_multiplier = 2.4
	return material
