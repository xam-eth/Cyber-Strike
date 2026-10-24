## The shapes every Neon Frontier component is built from.
##
## These were methods on neon_frontier_asset.gd, which meant a box existed only
## inside one 1,500-line file and the world builder and the arena graybox each
## kept their own copy. They are pure construction — take a parent, add a mesh
## with a material, hand it back — so they are now static and shared.
##
## Nothing here reads asset state: the caller passes the parent and, for the
## reactor coils, the material to wind them from.
class_name NeonFrontierGeometry
extends RefCounted


static func box(
	parent: Node3D,
	node_name: String,
	at: Vector3,
	size: Vector3,
	material: Material,
	rotation: Vector3 = Vector3.ZERO,
	collidable: bool = false
) -> MeshInstance3D:
	var mesh := BoxMesh.new()
	mesh.size = size
	var instance := MeshInstance3D.new()
	instance.name = node_name
	instance.mesh = mesh
	instance.material_override = material
	instance.position = at
	instance.rotation_degrees = rotation
	parent.add_child(instance)
	if collidable:
		box_collider(parent, node_name + "Collision", at, size, rotation)
	return instance


static func box_collider(
	parent: Node3D, node_name: String, at: Vector3, size: Vector3, rotation: Vector3 = Vector3.ZERO
) -> StaticBody3D:
	var body := StaticBody3D.new()
	body.name = node_name
	body.position = at
	body.rotation_degrees = rotation
	body.collision_layer = 1
	body.collision_mask = 0
	var collision_shape := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = size
	collision_shape.shape = shape
	body.add_child(collision_shape)
	parent.add_child(body)
	return body


static func cylinder(
	parent: Node3D,
	node_name: String,
	at: Vector3,
	bottom_radius: float,
	top_radius: float,
	height: float,
	material: Material,
	rotation: Vector3 = Vector3.ZERO,
	radial_segments: int = 24
) -> MeshInstance3D:
	var mesh := CylinderMesh.new()
	mesh.bottom_radius = bottom_radius
	mesh.top_radius = top_radius
	mesh.height = height
	mesh.radial_segments = radial_segments
	mesh.rings = 1
	var instance := MeshInstance3D.new()
	instance.name = node_name
	instance.mesh = mesh
	instance.material_override = material
	instance.position = at
	instance.rotation_degrees = rotation
	parent.add_child(instance)
	return instance


static func sphere(
	parent: Node3D,
	node_name: String,
	at: Vector3,
	size: Vector3,
	material: Material,
	rotation: Vector3 = Vector3.ZERO
) -> MeshInstance3D:
	var mesh := SphereMesh.new()
	mesh.radius = 1.0
	mesh.height = 2.0
	mesh.radial_segments = 16
	mesh.rings = 10
	var instance := MeshInstance3D.new()
	instance.name = node_name
	instance.mesh = mesh
	instance.material_override = material
	instance.position = at
	instance.scale = size
	instance.rotation_degrees = rotation
	parent.add_child(instance)
	return instance


static func link_cylinder(
	parent: Node3D,
	node_name: String,
	start: Vector3,
	finish: Vector3,
	radius: float,
	material: Material
) -> MeshInstance3D:
	var direction := finish - start
	var length := direction.length()
	var instance := cylinder(
		parent,
		node_name,
		(start + finish) * 0.5,
		radius,
		radius,
		length,
		material,
		Vector3.ZERO,
		16
	)
	if length > 0.001:
		instance.basis = Basis(Quaternion(Vector3.UP, direction / length))
	return instance


static func ring(
	parent: Node3D,
	node_name: String,
	center: Vector3,
	radius: float,
	y: float,
	thickness: float,
	material: Material,
	segments: int = 20
) -> void:
	var segment_length := 2.0 * radius * sin(PI / float(segments))
	for segment in range(segments):
		var angle := TAU * float(segment) / float(segments)
		var midpoint_angle := angle + PI / float(segments)
		var at := center + Vector3(cos(midpoint_angle) * radius, y, sin(midpoint_angle) * radius)
		var yaw_degrees := rad_to_deg(midpoint_angle - PI * 0.5)
		box(
			parent,
			"%s_%02d" % [node_name, segment],
			at,
			Vector3(segment_length * 1.06, thickness, thickness),
			material,
			Vector3(0.0, yaw_degrees, 0.0)
		)


static func reactor_coils(parent: Node3D, coil_material: Material) -> MeshInstance3D:
	# One small mesh, not ten extra glowing cylinders/draw calls. Keeping dark
	# gaps between these powered bands breaks the old six-metre green billboard
	# without removing the uploaded-FBX columns and cladding around the reactor.
	var vertices := PackedVector3Array()
	var normals := PackedVector3Array()
	for tier in range(10):
		var height := 4.38 + float(tier) * 0.59
		var radius := lerpf(0.98, 0.78, float(tier) / 9.0)
		for segment in range(24):
			var angle := TAU * float(segment) / 24.0
			var next_angle := TAU * float(segment + 1) / 24.0
			var lower := Vector3(cos(angle) * radius, height, sin(angle) * radius)
			var upper := lower + Vector3.UP * 0.075
			var next_lower := Vector3(cos(next_angle) * radius, height, sin(next_angle) * radius)
			var next_upper := next_lower + Vector3.UP * 0.075
			vertices.append_array(
				PackedVector3Array([lower, upper, next_lower, upper, next_upper, next_lower])
			)
			var normal := Vector3(cos(angle), 0.0, sin(angle))
			var next_normal := Vector3(cos(next_angle), 0.0, sin(next_angle))
			normals.append_array(
				PackedVector3Array([normal, normal, next_normal, normal, next_normal, next_normal])
			)
	var arrays: Array = []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_NORMAL] = normals
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	var coils := MeshInstance3D.new()
	coils.name = "ReactorCoils"
	coils.mesh = mesh
	var coil_surface := coil_material as StandardMaterial3D
	# Godot's front-face winding differs from the raw band triangles; without
	# two-sided rendering the near side vanishes behind the dark spine in WebGL.
	coil_surface.cull_mode = BaseMaterial3D.CULL_DISABLED
	coils.material_override = coil_surface
	coils.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(coils)
	return coils


static func bolts(
	parent: Node3D,
	prefix: String,
	center: Vector3,
	half_size: Vector2,
	y: float,
	material: Material
) -> void:
	for x_sign in [-1.0, 1.0]:
		for z_sign in [-1.0, 1.0]:
			cylinder(
				parent,
				"%s_Bolt_%s_%s" % [prefix, str(x_sign), str(z_sign)],
				center + Vector3(half_size.x * x_sign, y, half_size.y * z_sign),
				0.055,
				0.055,
				0.035,
				material,
				Vector3.ZERO,
				10
			)
