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


## Spawns a burst at [param position] under [param parent]. Returns the node so a
## test can inspect it; gameplay ignores the return value.
static func spawn(parent: Node, position: Vector3, color: Color = DEFAULT_TINT) -> ImpactBurst:
	if parent == null or not parent.is_inside_tree():
		return null
	var burst := ImpactBurst.new()
	burst.name = "ImpactBurst"
	burst.tint = color
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
	amount = 14
	lifetime = LIFETIME
	explosiveness = 1.0
	randomness = 0.45
	local_coords = false
	add_to_group(BURST_GROUP)
	cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF

	var spark := BoxMesh.new()
	spark.size = Vector3(0.045, 0.045, 0.045)
	mesh = spark
	material_override = _spark_material(tint)

	# A short cone along +Y: with no surface normal to orient to, the burst still
	# reads as a puff of sparks flying up and out.
	direction = Vector3(0.0, 1.0, 0.0)
	spread = 75.0
	initial_velocity_min = 1.6
	initial_velocity_max = 4.4
	gravity = Vector3(0.0, -7.5, 0.0)
	scale_amount_min = 0.6
	scale_amount_max = 1.5
	damping_min = 0.5
	damping_max = 1.5


func _spark_material(color: Color) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.albedo_color = color
	material.emission_enabled = true
	material.emission = color
	material.emission_energy_multiplier = 2.4
	return material
