@tool
extends RefCounted

# Preloading imported scenes makes the GLTFs and their BIN/texture dependencies visible to
# Godot's export dependency scanner. Keep these paths static so Android PCK exports include them.
#
# The whole CC0 KayKit "Space Base Bits" pack is registered here (57 models), not just the
# handful the first world pass used: the level is built from these modules, so a missing
# preload would silently drop geometry from an export-only build.
const MODEL_SCENES: Dictionary = {
	"basemodule_A": preload("res://assets/world/kaykit_space_base_bits/gltf/basemodule_A.gltf"),
	"basemodule_B": preload("res://assets/world/kaykit_space_base_bits/gltf/basemodule_B.gltf"),
	"basemodule_C": preload("res://assets/world/kaykit_space_base_bits/gltf/basemodule_C.gltf"),
	"basemodule_D": preload("res://assets/world/kaykit_space_base_bits/gltf/basemodule_D.gltf"),
	"basemodule_E": preload("res://assets/world/kaykit_space_base_bits/gltf/basemodule_E.gltf"),
	"basemodule_garage":
	preload("res://assets/world/kaykit_space_base_bits/gltf/basemodule_garage.gltf"),
	"cargo_A": preload("res://assets/world/kaykit_space_base_bits/gltf/cargo_A.gltf"),
	"cargo_A_packed": preload("res://assets/world/kaykit_space_base_bits/gltf/cargo_A_packed.gltf"),
	"cargo_A_stacked":
	preload("res://assets/world/kaykit_space_base_bits/gltf/cargo_A_stacked.gltf"),
	"cargo_B": preload("res://assets/world/kaykit_space_base_bits/gltf/cargo_B.gltf"),
	"cargo_B_packed": preload("res://assets/world/kaykit_space_base_bits/gltf/cargo_B_packed.gltf"),
	"cargo_B_stacked":
	preload("res://assets/world/kaykit_space_base_bits/gltf/cargo_B_stacked.gltf"),
	"cargodepot_A": preload("res://assets/world/kaykit_space_base_bits/gltf/cargodepot_A.gltf"),
	"cargodepot_B": preload("res://assets/world/kaykit_space_base_bits/gltf/cargodepot_B.gltf"),
	"cargodepot_C": preload("res://assets/world/kaykit_space_base_bits/gltf/cargodepot_C.gltf"),
	"containers_A": preload("res://assets/world/kaykit_space_base_bits/gltf/containers_A.gltf"),
	"containers_B": preload("res://assets/world/kaykit_space_base_bits/gltf/containers_B.gltf"),
	"containers_C": preload("res://assets/world/kaykit_space_base_bits/gltf/containers_C.gltf"),
	"containers_D": preload("res://assets/world/kaykit_space_base_bits/gltf/containers_D.gltf"),
	"drill_structure":
	preload("res://assets/world/kaykit_space_base_bits/gltf/drill_structure.gltf"),
	"lander_A": preload("res://assets/world/kaykit_space_base_bits/gltf/lander_A.gltf"),
	"lander_B": preload("res://assets/world/kaykit_space_base_bits/gltf/lander_B.gltf"),
	"lander_base": preload("res://assets/world/kaykit_space_base_bits/gltf/lander_base.gltf"),
	"landingpad_large":
	preload("res://assets/world/kaykit_space_base_bits/gltf/landingpad_large.gltf"),
	"landingpad_small":
	preload("res://assets/world/kaykit_space_base_bits/gltf/landingpad_small.gltf"),
	"lights": preload("res://assets/world/kaykit_space_base_bits/gltf/lights.gltf"),
	"rock_A": preload("res://assets/world/kaykit_space_base_bits/gltf/rock_A.gltf"),
	"rock_B": preload("res://assets/world/kaykit_space_base_bits/gltf/rock_B.gltf"),
	"rocks_A": preload("res://assets/world/kaykit_space_base_bits/gltf/rocks_A.gltf"),
	"rocks_B": preload("res://assets/world/kaykit_space_base_bits/gltf/rocks_B.gltf"),
	"roofmodule_base":
	preload("res://assets/world/kaykit_space_base_bits/gltf/roofmodule_base.gltf"),
	"roofmodule_cargo_A":
	preload("res://assets/world/kaykit_space_base_bits/gltf/roofmodule_cargo_A.gltf"),
	"roofmodule_cargo_B":
	preload("res://assets/world/kaykit_space_base_bits/gltf/roofmodule_cargo_B.gltf"),
	"roofmodule_cargo_C":
	preload("res://assets/world/kaykit_space_base_bits/gltf/roofmodule_cargo_C.gltf"),
	"roofmodule_solarpanels":
	preload("res://assets/world/kaykit_space_base_bits/gltf/roofmodule_solarpanels.gltf"),
	"solarpanel": preload("res://assets/world/kaykit_space_base_bits/gltf/solarpanel.gltf"),
	"spacetruck": preload("res://assets/world/kaykit_space_base_bits/gltf/spacetruck.gltf"),
	"spacetruck_large":
	preload("res://assets/world/kaykit_space_base_bits/gltf/spacetruck_large.gltf"),
	"spacetruck_trailer":
	preload("res://assets/world/kaykit_space_base_bits/gltf/spacetruck_trailer.gltf"),
	"structure_low": preload("res://assets/world/kaykit_space_base_bits/gltf/structure_low.gltf"),
	"structure_tall": preload("res://assets/world/kaykit_space_base_bits/gltf/structure_tall.gltf"),
	"terrain_low": preload("res://assets/world/kaykit_space_base_bits/gltf/terrain_low.gltf"),
	"terrain_low_curved":
	preload("res://assets/world/kaykit_space_base_bits/gltf/terrain_low_curved.gltf"),
	"terrain_mining": preload("res://assets/world/kaykit_space_base_bits/gltf/terrain_mining.gltf"),
	"terrain_slope": preload("res://assets/world/kaykit_space_base_bits/gltf/terrain_slope.gltf"),
	"terrain_slope_inner_corner":
	preload("res://assets/world/kaykit_space_base_bits/gltf/terrain_slope_inner_corner.gltf"),
	"terrain_slope_outer_corner":
	preload("res://assets/world/kaykit_space_base_bits/gltf/terrain_slope_outer_corner.gltf"),
	"terrain_tall": preload("res://assets/world/kaykit_space_base_bits/gltf/terrain_tall.gltf"),
	"terrain_tall_curved":
	preload("res://assets/world/kaykit_space_base_bits/gltf/terrain_tall_curved.gltf"),
	"tunnel_diagonal_long_A":
	preload("res://assets/world/kaykit_space_base_bits/gltf/tunnel_diagonal_long_A.gltf"),
	"tunnel_diagonal_long_B":
	preload("res://assets/world/kaykit_space_base_bits/gltf/tunnel_diagonal_long_B.gltf"),
	"tunnel_diagonal_short_A":
	preload("res://assets/world/kaykit_space_base_bits/gltf/tunnel_diagonal_short_A.gltf"),
	"tunnel_diagonal_short_B":
	preload("res://assets/world/kaykit_space_base_bits/gltf/tunnel_diagonal_short_B.gltf"),
	"tunnel_straight_A":
	preload("res://assets/world/kaykit_space_base_bits/gltf/tunnel_straight_A.gltf"),
	"tunnel_straight_B":
	preload("res://assets/world/kaykit_space_base_bits/gltf/tunnel_straight_B.gltf"),
	"windturbine_low":
	preload("res://assets/world/kaykit_space_base_bits/gltf/windturbine_low.gltf"),
	"windturbine_tall":
	preload("res://assets/world/kaykit_space_base_bits/gltf/windturbine_tall.gltf"),
}


static func instantiate_model(model_name: String) -> Node3D:
	if not MODEL_SCENES.has(model_name):
		push_warning("Unknown external world asset: " + model_name)
		return null

	var packed_scene := MODEL_SCENES[model_name] as PackedScene
	if packed_scene == null:
		push_warning("External world asset was not imported as a PackedScene: " + model_name)
		return null

	var instance := packed_scene.instantiate() as Node3D
	if instance == null:
		push_warning("External world asset did not instantiate as Node3D: " + model_name)
	return instance


static func add_bounds_collider(
	model_root: Node3D, collider_name: String, fill_ratio: float = 0.88
) -> StaticBody3D:
	if not is_instance_valid(model_root):
		return null
	var mesh_nodes := model_root.find_children("*", "MeshInstance3D", true, false)
	if mesh_nodes.is_empty():
		return null

	var inverse_root := model_root.global_transform.affine_inverse()
	var has_bounds := false
	var model_bounds := AABB()
	for child in mesh_nodes:
		var mesh_instance := child as MeshInstance3D
		if not is_instance_valid(mesh_instance) or mesh_instance.mesh == null:
			continue
		var relative_transform := inverse_root * mesh_instance.global_transform
		var mesh_bounds := _transform_aabb(mesh_instance.get_aabb(), relative_transform)
		model_bounds = mesh_bounds if not has_bounds else model_bounds.merge(mesh_bounds)
		has_bounds = true
	if not has_bounds or model_bounds.size.is_zero_approx():
		return null

	var body := StaticBody3D.new()
	body.name = collider_name
	body.position = model_bounds.position + model_bounds.size * 0.5
	body.collision_layer = 1
	body.collision_mask = 0
	var collision := CollisionShape3D.new()
	collision.name = collider_name + "Shape"
	var shape := BoxShape3D.new()
	shape.size = model_bounds.size * clampf(fill_ratio, 0.1, 1.0)
	collision.shape = shape
	body.add_child(collision)
	model_root.add_child(body)
	return body


static func _transform_aabb(bounds: AABB, transform: Transform3D) -> AABB:
	var min_corner := Vector3.ZERO
	var max_corner := Vector3.ZERO
	var has_corner := false
	for corner_index in range(8):
		var local_corner := bounds.position
		if (corner_index & 1) != 0:
			local_corner.x += bounds.size.x
		if (corner_index & 2) != 0:
			local_corner.y += bounds.size.y
		if (corner_index & 4) != 0:
			local_corner.z += bounds.size.z

		var transformed_corner := transform * local_corner
		if not has_corner:
			min_corner = transformed_corner
			max_corner = transformed_corner
			has_corner = true
		else:
			min_corner.x = minf(min_corner.x, transformed_corner.x)
			min_corner.y = minf(min_corner.y, transformed_corner.y)
			min_corner.z = minf(min_corner.z, transformed_corner.z)
			max_corner.x = maxf(max_corner.x, transformed_corner.x)
			max_corner.y = maxf(max_corner.y, transformed_corner.y)
			max_corner.z = maxf(max_corner.z, transformed_corner.z)

	return AABB(min_corner, max_corner - min_corner)
