class_name SupplyCrate
extends StaticBody3D

## Destructible Aetherfall armored supply crate.
##
## Placed on collision layer 2 so player ballistic/energy/explosive rounds and
## EMP pulses damage it without placing it in the "enemies" group (preserving
## WaveDirector wave-clear counts and touch soft-lock contracts). Shatters into
## physical 3D FieldPickup collectibles when opened.

signal crate_damaged
signal crate_broken(world_position: Vector3, crate_tier: int)

@export var max_health: float = 38.0
@export var crate_tier: int = 1

var current_health: float = 38.0
var _broken: bool = false
var _body_mesh: MeshInstance3D
var _strap_mesh: MeshInstance3D
var _beacon_mesh: MeshInstance3D
var _body_mat: StandardMaterial3D
var _strap_mat: StandardMaterial3D
var _flash_remaining: float = 0.0
var _pulse_time: float = 0.0


func configure(pos: Vector3, yaw_deg: float = 0.0, tier: int = 1) -> void:
	position = pos
	rotation_degrees.y = yaw_deg
	crate_tier = clampi(tier, 1, 2)
	max_health = 52.0 if crate_tier == 2 else 36.0
	current_health = max_health


func _ready() -> void:
	collision_layer = 2
	collision_mask = 0
	add_to_group("supply_crates")
	current_health = max_health
	_build_crate()


func _process(delta: float) -> void:
	if _broken:
		return
	_pulse_time += delta
	if _flash_remaining > 0.0:
		_flash_remaining = maxf(_flash_remaining - delta, 0.0)
		if _flash_remaining <= 0.0 and is_instance_valid(_body_mat):
			_body_mat.emission_enabled = false
	if is_instance_valid(_strap_mat):
		var base_e := 1.85 if crate_tier == 2 else 1.45
		_strap_mat.emission_energy_multiplier = base_e + 0.35 * sin(_pulse_time * 3.4)


func apply_damage(amount: float, _source: Node = null) -> void:
	if _broken or amount <= 0.0:
		return
	current_health = maxf(current_health - amount, 0.0)
	crate_damaged.emit()
	_flash_remaining = 0.09
	if is_instance_valid(_body_mat):
		_body_mat.emission_enabled = true
		_body_mat.emission = Color(1.0, 0.86, 0.52)
		_body_mat.emission_energy_multiplier = 1.35
	if is_instance_valid(_body_mesh):
		var hit_tw := create_tween()
		hit_tw.tween_property(_body_mesh, "scale", Vector3(1.06, 0.93, 1.06), 0.04)
		hit_tw.tween_property(_body_mesh, "scale", Vector3.ONE, 0.07)
	if current_health <= 0.0:
		_shatter()


func is_defeated() -> bool:
	return _broken


func _shatter() -> void:
	if _broken:
		return
	_broken = true
	collision_layer = 0
	var burst_pos := global_position
	Sfx.play_3d(&"crate_break", burst_pos + Vector3(0.0, 0.5, 0.0))
	crate_broken.emit(burst_pos, crate_tier)
	set_process(false)
	var tw := create_tween()
	tw.set_parallel(true)
	if is_instance_valid(_body_mesh):
		tw.tween_property(_body_mesh, "scale", Vector3(1.28, 0.14, 1.28), 0.16)
	if is_instance_valid(_strap_mesh):
		tw.tween_property(_strap_mesh, "position:y", 1.35, 0.16)
		tw.tween_property(_strap_mesh, "scale", Vector3(1.35, 0.2, 1.35), 0.16)
	tw.chain().tween_callback(queue_free)


func _build_crate() -> void:
	var shape_node := CollisionShape3D.new()
	var box_col := BoxShape3D.new()
	box_col.size = Vector3(1.18, 0.92, 0.88)
	shape_node.shape = box_col
	shape_node.position = Vector3(0.0, 0.46, 0.0)
	add_child(shape_node)

	var accent := Color(0.22, 0.88, 1.0) if crate_tier == 2 else Color(1.0, 0.74, 0.16)
	_body_mat = StandardMaterial3D.new()
	_body_mat.albedo_color = Color(0.13, 0.17, 0.22) if crate_tier == 2 else Color(0.16, 0.19, 0.23)
	_body_mat.metallic = 0.76
	_body_mat.roughness = 0.34

	_strap_mat = StandardMaterial3D.new()
	_strap_mat.albedo_color = accent
	_strap_mat.metallic = 0.35
	_strap_mat.roughness = 0.22
	_strap_mat.emission_enabled = true
	_strap_mat.emission = accent
	_strap_mat.emission_energy_multiplier = 1.6

	_body_mesh = MeshInstance3D.new()
	var hull := BoxMesh.new()
	hull.size = Vector3(1.12, 0.78, 0.82)
	_body_mesh.mesh = hull
	_body_mesh.position = Vector3(0.0, 0.41, 0.0)
	_body_mesh.material_override = _body_mat
	add_child(_body_mesh)

	var lid := MeshInstance3D.new()
	var lid_mesh := BoxMesh.new()
	lid_mesh.size = Vector3(1.18, 0.14, 0.88)
	lid.mesh = lid_mesh
	lid.position = Vector3(0.0, 0.41, 0.0)
	lid.material_override = _body_mat
	_body_mesh.add_child(lid)

	_strap_mesh = MeshInstance3D.new()
	var strap_box := BoxMesh.new()
	strap_box.size = Vector3(1.20, 0.12, 0.90)
	_strap_mesh.mesh = strap_box
	_strap_mesh.position = Vector3(0.0, 0.56, 0.0)
	_strap_mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_strap_mesh.material_override = _strap_mat
	add_child(_strap_mesh)

	for side: float in [-0.34, 0.34]:
		var rib := MeshInstance3D.new()
		var rib_box := BoxMesh.new()
		rib_box.size = Vector3(0.09, 0.84, 0.86)
		rib.mesh = rib_box
		rib.position = Vector3(float(side), 0.43, 0.0)
		rib.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		rib.material_override = _strap_mat
		add_child(rib)

	_beacon_mesh = MeshInstance3D.new()
	var beacon_cyl := CylinderMesh.new()
	beacon_cyl.top_radius = 0.12
	beacon_cyl.bottom_radius = 0.16
	beacon_cyl.height = 0.08
	beacon_cyl.radial_segments = 12
	_beacon_mesh.mesh = beacon_cyl
	_beacon_mesh.position = Vector3(0.0, 0.86, 0.0)
	_beacon_mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_beacon_mesh.material_override = _strap_mat
	add_child(_beacon_mesh)
