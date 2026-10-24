class_name ModelFitter
extends RefCounted

## Shared GLB fitting for the player avatar and the enemies.
##
## The kit models are authored at wildly different sizes and all of them face +Z,
## while the game's forward direction is -Z. Fitting therefore does two things:
##
##   * measure every mesh under the instance and scale the model so its height
##     matches the requested target (no hand-tuned scale numbers in scenes),
##   * put the model under a pivot that carries the yaw offset, and centre it
##     *inside* that pivot. Compensating the offset on the rotated node itself
##     doubles the displacement — that mistake once pushed the player avatar
##     several metres away from its collider.

const DEFAULT_PIVOT_NAME := "ModelPivot"
const DEFAULT_MODEL_NAME := "CharacterModel"


## Returns { pivot, model, height, bounds } or an empty dictionary when the scene
## could not be used (the caller then keeps its fallback mesh visible).
##
## [param fit_axis] selects which measured axis is scaled to [param target_size]:
## 0 is width, 1 is height (the default), 2 is depth. A hovering craft is sized by
## its width so it stays inside its collider instead of exploding outwards.
static func attach(
	parent: Node3D,
	model_scene: PackedScene,
	target_size: float,
	yaw_offset_degrees: float = 180.0,
	pivot_name: String = DEFAULT_PIVOT_NAME,
	model_name: String = DEFAULT_MODEL_NAME,
	fit_axis: int = 1
) -> Dictionary:
	if parent == null or model_scene == null:
		return {}
	var instance := model_scene.instantiate()
	if not instance is Node3D:
		return {}
	var model := instance as Node3D
	model.name = model_name

	var pivot := Node3D.new()
	pivot.name = pivot_name
	pivot.rotation.y = deg_to_rad(yaw_offset_degrees)
	parent.add_child(pivot)
	pivot.add_child(model)

	var bounds := combined_bounds(model)
	var axis := clampi(fit_axis, 0, 2)
	if bounds.size[axis] <= 0.0001:
		pivot.queue_free()
		return {}
	var scale_factor := target_size / bounds.size[axis]
	var center := bounds.position + bounds.size * 0.5
	model.scale = Vector3.ONE * scale_factor
	model.position = Vector3(
		-center.x * scale_factor, -bounds.position.y * scale_factor, -center.z * scale_factor
	)
	return {
		"pivot": pivot,
		"model": model,
		"height": bounds.size.y * scale_factor,
		"bounds": bounds,
	}


## Dark (or glowing) rim around every mesh, drawn as an overlay grown past the
## surface. The kit models are light and the world is bright, so without this the
## actors stop reading against the floor.
static func apply_overlay_material(root: Node3D, material: Material) -> void:
	for mesh_instance in meshes_of(root):
		mesh_instance.material_overlay = material


static func outline_material(color: Color, grow_amount: float = 0.022) -> StandardMaterial3D:
	var outline := StandardMaterial3D.new()
	outline.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	outline.albedo_color = color
	outline.cull_mode = BaseMaterial3D.CULL_FRONT
	outline.grow = true
	outline.grow_amount = grow_amount
	return outline


static func flash_material(color: Color) -> StandardMaterial3D:
	var flash := StandardMaterial3D.new()
	flash.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	flash.albedo_color = color
	flash.grow = true
	flash.grow_amount = 0.03
	return flash


## Every MeshInstance3D under [param root], in tree order.
static func meshes_of(root: Node3D) -> Array[MeshInstance3D]:
	var found: Array[MeshInstance3D] = []
	if root == null:
		return found
	for child in root.find_children("*", "MeshInstance3D", true, false):
		var mesh_instance := child as MeshInstance3D
		if is_instance_valid(mesh_instance):
			found.append(mesh_instance)
	return found


## Bounds of every mesh under [param root], expressed in root-local space.
static func combined_bounds(root: Node3D) -> AABB:
	var has_bounds := false
	var combined := AABB()
	for mesh_instance in meshes_of(root):
		if mesh_instance.mesh == null:
			continue
		var relative := local_transform_within(root, mesh_instance)
		var converted := transform_aabb(mesh_instance.get_aabb(), relative)
		combined = converted if not has_bounds else combined.merge(converted)
		has_bounds = true
	return combined


## Transform of [param node] relative to [param root], built by walking parents so
## nested GLTF nodes are measured correctly without relying on global transforms
## (the node may not be inside the tree yet).
static func local_transform_within(root: Node3D, node: Node3D) -> Transform3D:
	var chain: Array[Node3D] = []
	var current: Node = node
	while current != null and current != root:
		if current is Node3D:
			chain.append(current as Node3D)
		current = current.get_parent()
	var result := Transform3D.IDENTITY
	for index in range(chain.size() - 1, -1, -1):
		result = result * chain[index].transform
	return result


static func transform_aabb(bounds: AABB, transform: Transform3D) -> AABB:
	var min_corner := Vector3.INF
	var max_corner := -Vector3.INF
	for corner_index in range(8):
		var local_corner := bounds.position
		if (corner_index & 1) != 0:
			local_corner.x += bounds.size.x
		if (corner_index & 2) != 0:
			local_corner.y += bounds.size.y
		if (corner_index & 4) != 0:
			local_corner.z += bounds.size.z
		var transformed := transform * local_corner
		min_corner = min_corner.min(transformed)
		max_corner = max_corner.max(transformed)
	return AABB(min_corner, max_corner - min_corner)
