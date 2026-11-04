class_name FieldPickup
extends Node3D

## Physical 3D collectible resource & tactical power-up dropped by defeated
## robot units, shattered Supply Crates, and Aetherfall field nodes.
##
## Features a ballistic pop-out arc on spawn, sinusoidal hover bob + dual-axis
## spin, ground holo-beacon ring, and tractor-beam magnetization when an active
## player moves within pickup range.

signal collected(kind: StringName, amount: int, world_position: Vector3)

const KIND_BP_SHARD: StringName = &"bp_shard"
const KIND_CRYO_ALLOY: StringName = &"cryo_alloy"
const KIND_MED_INJECTOR: StringName = &"med_injector"
const KIND_PLASMA_CELL: StringName = &"plasma_cell"

const MAGNET_RADIUS := 4.4
const COLLECT_RADIUS := 1.42
const MAGNET_SPEED := 12.5
const GRAVITY := 19.0

var pickup_kind: StringName = KIND_BP_SHARD
var amount: int = 10
var target_player: Node3D = null

var _core_pivot: Node3D
var _outer_ring: MeshInstance3D
var _beacon_ring: MeshInstance3D
var _rest_y: float = 0.25
var _hover_phase: float = 0.0
var _launch_velocity: Vector3 = Vector3.ZERO
var _airborne: bool = false
var _collected: bool = false
var _age: float = 0.0


func configure(
	kind: StringName,
	value: int,
	spawn_pos: Vector3,
	ground_y: float = 0.25,
	launch_vel: Vector3 = Vector3.ZERO
) -> void:
	pickup_kind = kind
	amount = maxi(value, 1)
	_rest_y = ground_y
	position = spawn_pos
	_launch_velocity = launch_vel
	_airborne = launch_vel.length_squared() > 0.01
	_hover_phase = fposmod(spawn_pos.x * 1.37 + spawn_pos.z * 2.11, TAU)


func _ready() -> void:
	add_to_group("field_pickups")
	_build_visual()


func _process(delta: float) -> void:
	if _collected:
		return
	_age += delta
	if _airborne:
		_launch_velocity.y -= GRAVITY * delta
		position += _launch_velocity * delta
		if position.y <= _rest_y and _launch_velocity.y <= 0.0:
			position.y = _rest_y
			_launch_velocity = Vector3.ZERO
			_airborne = false

	var bob := sin(_age * 3.1 + _hover_phase) * 0.09
	if is_instance_valid(_core_pivot):
		_core_pivot.position.y = 0.56 + bob
		_core_pivot.rotation.y += delta * 2.15
	if is_instance_valid(_outer_ring):
		_outer_ring.rotation.x += delta * 1.65
		_outer_ring.rotation.z -= delta * 1.25
	if is_instance_valid(_beacon_ring):
		var pulse := 0.92 + 0.10 * sin(_age * 4.4 + _hover_phase)
		_beacon_ring.scale = Vector3(pulse, 1.0, pulse)

	if _age < 0.22 or not _can_magnetize_to_player():
		return

	var target_chest := target_player.global_position + Vector3(0.0, 0.95, 0.0)
	var planar := Vector2(
		target_player.global_position.x - global_position.x,
		target_player.global_position.z - global_position.z
	)
	var planar_dist := planar.length()
	if (
		planar_dist <= COLLECT_RADIUS
		and absf(target_player.global_position.y - global_position.y) <= 2.4
	):
		_trigger_collect()
		return
	if planar_dist <= MAGNET_RADIUS:
		_airborne = false
		var pull_factor := clampf(1.35 - planar_dist / MAGNET_RADIUS, 0.35, 1.25)
		global_position = global_position.move_toward(
			target_chest, MAGNET_SPEED * pull_factor * delta
		)
		if global_position.distance_to(target_chest) <= COLLECT_RADIUS * 0.85:
			_trigger_collect()


func _can_magnetize_to_player() -> bool:
	if not is_instance_valid(target_player):
		return false
	if not target_player.is_physics_processing():
		return false
	if target_player.has_method("is_defeated") and bool(target_player.call("is_defeated")):
		return false
	var dist_moved: Variant = target_player.get("_distance_travelled")
	if dist_moved != null and float(dist_moved) < 0.35:
		return false
	return true


func _trigger_collect() -> void:
	if _collected:
		return
	_collected = true
	var pos := global_position
	collected.emit(pickup_kind, amount, pos)
	set_process(false)
	var tween := create_tween()
	tween.set_parallel(true)
	if is_instance_valid(_core_pivot):
		tween.tween_property(_core_pivot, "scale", Vector3.ONE * 1.65, 0.14)
		tween.tween_property(_core_pivot, "position:y", 1.25, 0.14)
	tween.chain().tween_callback(queue_free)


func _palette() -> Dictionary:
	match pickup_kind:
		KIND_CRYO_ALLOY:
			return {
				"core": Color(0.18, 0.86, 1.0),
				"emission": Color(0.24, 0.90, 1.0),
				"trim": Color(0.10, 0.24, 0.34),
				"energy": 2.35,
			}
		KIND_MED_INJECTOR:
			return {
				"core": Color(0.20, 0.96, 0.56),
				"emission": Color(0.24, 1.0, 0.62),
				"trim": Color(0.09, 0.24, 0.17),
				"energy": 2.2,
			}
		KIND_PLASMA_CELL:
			return {
				"core": Color(0.68, 0.38, 1.0),
				"emission": Color(0.76, 0.44, 1.0),
				"trim": Color(0.18, 0.12, 0.30),
				"energy": 2.4,
			}
		_:
			return {
				"core": Color(1.0, 0.78, 0.18),
				"emission": Color(1.0, 0.74, 0.16),
				"trim": Color(0.26, 0.20, 0.08),
				"energy": 2.35,
			}


func _build_visual() -> void:
	var pal := _palette()
	var core_color: Color = pal["core"]
	var emission_color: Color = pal["emission"]
	var trim_color: Color = pal["trim"]
	var energy: float = float(pal["energy"])

	var glow_mat := StandardMaterial3D.new()
	glow_mat.albedo_color = core_color
	glow_mat.metallic = 0.22
	glow_mat.roughness = 0.18
	glow_mat.emission_enabled = true
	glow_mat.emission = emission_color
	glow_mat.emission_energy_multiplier = energy

	var casing_mat := StandardMaterial3D.new()
	casing_mat.albedo_color = trim_color
	casing_mat.metallic = 0.78
	casing_mat.roughness = 0.28

	var ring_mat := StandardMaterial3D.new()
	ring_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	ring_mat.albedo_color = Color(core_color.r, core_color.g, core_color.b, 0.52)
	ring_mat.emission_enabled = true
	ring_mat.emission = emission_color
	ring_mat.emission_energy_multiplier = 1.65
	ring_mat.cull_mode = BaseMaterial3D.CULL_DISABLED

	_beacon_ring = MeshInstance3D.new()
	var ground_torus := TorusMesh.new()
	ground_torus.inner_radius = 0.34
	ground_torus.outer_radius = 0.44
	ground_torus.rings = 18
	ground_torus.ring_segments = 8
	_beacon_ring.mesh = ground_torus
	_beacon_ring.position = Vector3(0.0, 0.04, 0.0)
	_beacon_ring.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_beacon_ring.material_override = ring_mat
	add_child(_beacon_ring)

	_core_pivot = Node3D.new()
	_core_pivot.position = Vector3(0.0, 0.56, 0.0)
	add_child(_core_pivot)

	var core_mesh := MeshInstance3D.new()
	core_mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	core_mesh.material_override = glow_mat
	if pickup_kind == KIND_MED_INJECTOR:
		var cyl := CylinderMesh.new()
		cyl.top_radius = 0.13
		cyl.bottom_radius = 0.13
		cyl.height = 0.36
		cyl.radial_segments = 12
		core_mesh.mesh = cyl
	elif pickup_kind == KIND_PLASMA_CELL:
		var cell := CapsuleMesh.new()
		cell.radius = 0.13
		cell.height = 0.38
		cell.radial_segments = 12
		core_mesh.mesh = cell
	else:
		var prism := BoxMesh.new()
		prism.size = Vector3(0.24, 0.28, 0.24)
		core_mesh.mesh = prism
		core_mesh.rotation_degrees = Vector3(35.26, 45.0, 0.0)
	_core_pivot.add_child(core_mesh)

	var cap_top := MeshInstance3D.new()
	var cap_mesh := CylinderMesh.new()
	cap_mesh.top_radius = 0.15
	cap_mesh.bottom_radius = 0.15
	cap_mesh.height = 0.055
	cap_mesh.radial_segments = 10
	cap_top.mesh = cap_mesh
	cap_top.position = Vector3(0.0, 0.20, 0.0)
	cap_top.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	cap_top.material_override = casing_mat
	_core_pivot.add_child(cap_top)

	var cap_bot := MeshInstance3D.new()
	cap_bot.mesh = cap_mesh
	cap_bot.position = Vector3(0.0, -0.20, 0.0)
	cap_bot.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	cap_bot.material_override = casing_mat
	_core_pivot.add_child(cap_bot)

	_outer_ring = MeshInstance3D.new()
	var orbit := TorusMesh.new()
	orbit.inner_radius = 0.25
	orbit.outer_radius = 0.285
	orbit.rings = 16
	orbit.ring_segments = 8
	_outer_ring.mesh = orbit
	_outer_ring.rotation_degrees = Vector3(58.0, 0.0, 22.0)
	_outer_ring.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_outer_ring.material_override = ring_mat
	_core_pivot.add_child(_outer_ring)
