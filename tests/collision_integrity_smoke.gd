extends SceneTree

## collision_integrity_smoke.gd -- the "objects must not be pass-through" proof.
##
## The gameplay bug report: ice rocks and some buildings could be walked
## through. Root cause: `aetherfall_world` gave terrain_chunk/cliff_face/
## rock_boulder/energy_core/railing/debris_cluster no collider at all, and 8 of
## 9 ice_planet placements (glacier walls, frozen spires, cryo pylons) shipped
## without collision_boxes. This test boots the real world and proves the fix:
##
##   * every solid placement now owns a Collision_<name> body,
##   * solid irregular scenery carries a concave (trimesh) shape with real
##     faces, not an empty or missing shape,
##   * grid rays across each placement's own volume hit its own collider,
##   * purely decorative scenery (sky silhouettes, clouds, cables) stayed
##     pass-through on purpose.

const WorldScene = preload("res://scenes/worlds/mission_world.tscn")

## Placement names as authored in layout.json / ice_planet_phase1.json.
const SOLID_SETPIECES := [
	"west_glacier_wall",
	"east_glacier_wall",
	"west_outer_glacier",
	"east_outer_glacier",
	"tower_glacier_spire_west",
	"tower_glacier_spire_east",
	"archive_cryo_pylon_west",
	"archive_cryo_pylon_east",
]
const SOLID_KIT := [
	"terrain_chunk_191",
	"cliff_face_201",
	"rock_boulder_204",
	"energy_core_005",
	"debris_cluster_213",
]
## Ring-shaped rail modules: their trimesh hugs a 6 m perimeter, so a vertical
## ray grid through the AABB center would legitimately miss -- body + shape
## assertions carry these.
const SOLID_KIT_BODY_ONLY := [
	"railing_168",
]
const DECORATIVE := [
	"background_silhouette",
	"cloud_puff",
	"cable_bundle",
]

var _passed := true


func _initialize() -> void:
	call_deferred("_run_smoke_test")


func _run_smoke_test() -> void:
	var world := WorldScene.instantiate() as Node3D
	world.set("world_override", "aetherfall")
	root.add_child(world)
	for _warm in 6:
		await process_frame
	await physics_frame
	await physics_frame

	for setpiece_id in SOLID_SETPIECES:
		var setpiece := _find_named(world, setpiece_id, "IcePlanetPhase1")
		_passed = (
			_expect(
				setpiece != null,
				"ice_planet placement %s exists in the world" % setpiece_id,
			)
			and _passed
		)
		if setpiece == null:
			continue
		_check_solid(world, setpiece, setpiece_id, "Visual", true)

	for kit_name in SOLID_KIT:
		var module := _find_named(world, kit_name, "Modules")
		_passed = (
			_expect(module != null, "kit placement %s exists in the world" % kit_name) and _passed
		)
		if module == null:
			continue
		_check_solid(world, module, kit_name, "", true)

	for kit_name in SOLID_KIT_BODY_ONLY:
		var module := _find_named(world, kit_name, "Modules")
		_passed = (
			_expect(module != null, "kit placement %s exists in the world" % kit_name) and _passed
		)
		if module == null:
			continue
		_check_solid(world, module, kit_name, "", false)

	for decor in DECORATIVE:
		_passed = (
			_expect(
				not _has_collision_named(world, decor),
				"decorative %s stays pass-through" % decor,
			)
			and _passed
		)

	world.queue_free()
	await process_frame

	if _passed:
		print("COLLISION INTEGRITY smoke test passed.")
		quit()
	else:
		quit(1)


## A solid placement must own its Collision_<name> body (kit bodies live under
## the world's Collision scope, setpiece bodies under the placement), and its
## own concave/box shape must catch rays crossing the visible volume.
func _check_solid(
	world: Node3D, placement: Node3D, label: String, visual_path: String, ray_check: bool
) -> void:
	var found := _find_body_for(world, placement, label)
	_passed = _expect(found != null, "%s owns a collision body" % label) and _passed
	if found == null:
		return
	var shapes := found.find_children("*", "CollisionShape3D", true, false)
	_passed = _expect(not shapes.is_empty(), "%s has a CollisionShape3D" % label) and _passed
	if shapes.is_empty():
		return
	var total_faces := 0
	for candidate in shapes:
		var shape_node := candidate as CollisionShape3D
		var concave := shape_node.shape as ConcavePolygonShape3D
		if concave != null:
			total_faces += concave.get_faces().size()
		var box := shape_node.shape as BoxShape3D
		if box != null and box.size.length() <= 0.001:
			_passed = _expect(false, "%s box shape has real size" % label) and _passed
	if total_faces > 0:
		_passed = _expect(total_faces >= 12, "%s concave shape has real faces" % label) and _passed
	var own_tris := _own_shape_tris(found)
	_passed = _expect(own_tris.size() >= 3, "%s own shape carries triangles" % label) and _passed
	# Ray grid across the visible volume must hit this placement's OWN collider
	# geometry. Neighbouring colliders legitimately overlap this volume (the
	# tower energy core mounts inside its tier ring's box), so space-state
	# "first hit" tests shadow the target behind the neighbour and say nothing
	# about this body. Intersect the same 27-ray grid directly against the
	# body's own shape faces instead: strict, neighbour-immune, deterministic.
	var visual := placement if visual_path.is_empty() else placement.get_node_or_null(visual_path)
	var bounds := _combined_aabb(visual if visual != null else placement)
	_passed = _expect(bounds.size.length() > 0.1, "%s has visible geometry" % label) and _passed
	if not ray_check or bounds.size.length() <= 0.1:
		print(
			(
				"    %s: %s collider, %d faces (body/shape asserted)"
				% [label, "concave" if total_faces > 0 else "box", total_faces]
			)
		)
		return
	var hits := 0
	var center := bounds.get_center()
	# Multi-axis grid: sparse lattice geometry (energy cores, debris fields)
	# lets isolated vertical rays thread the gaps, so X, Z and vertical sweeps
	# all count toward the "this volume is solid" proof.
	for axis in range(3):
		for i1 in range(-1, 2):
			for i2 in range(-1, 2):
				var offset := Vector3.ZERO
				var from := center
				var to := center
				if axis == 0:
					offset = Vector3(
						bounds.size.x * 0.32 * float(i1), 0.0, bounds.size.z * 0.32 * float(i2)
					)
					from = center + offset + Vector3(0.0, bounds.size.y * 0.5 + 2.0, 0.0)
					to = center + offset - Vector3(0.0, bounds.size.y * 0.5 + 2.0, 0.0)
				elif axis == 1:
					offset = Vector3(
						0.0, bounds.size.y * 0.32 * float(i1), bounds.size.z * 0.32 * float(i2)
					)
					from = center + offset + Vector3(bounds.size.x * 0.5 + 2.0, 0.0, 0.0)
					to = center + offset - Vector3(bounds.size.x * 0.5 + 2.0, 0.0, 0.0)
				else:
					offset = Vector3(
						bounds.size.x * 0.32 * float(i1), bounds.size.y * 0.32 * float(i2), 0.0
					)
					from = center + offset + Vector3(0.0, 0.0, bounds.size.z * 0.5 + 2.0)
					to = center + offset - Vector3(0.0, 0.0, bounds.size.z * 0.5 + 2.0)
				if _segment_hits_tris(from, to, own_tris):
					hits += 1
	_passed = (
		_expect(hits >= 1, "%s blocks rays through its volume (%d grid hits)" % [label, hits])
		and _passed
	)
	print(
		(
			"    %s: %s collider, %d faces, %d/27 rays blocked by own geometry"
			% [label, "concave" if total_faces > 0 else "box", total_faces, hits]
		)
	)


## World-space triangle soup of the body's own shapes (concave faces and box
## shapes alike), so the ray grid can be tested against this collider only.
func _own_shape_tris(body: StaticBody3D) -> PackedVector3Array:
	var tris := PackedVector3Array()
	for candidate in body.find_children("*", "CollisionShape3D", true, false):
		var shape_node := candidate as CollisionShape3D
		if shape_node == null or shape_node.shape == null:
			continue
		var xform: Transform3D = shape_node.global_transform
		var concave := shape_node.shape as ConcavePolygonShape3D
		if concave != null:
			var faces := concave.get_faces()
			for i in range(faces.size()):
				tris.append(xform * faces[i])
			continue
		var box := shape_node.shape as BoxShape3D
		if box != null:
			var h := box.size * 0.5
			var corners := [
				Vector3(-h.x, -h.y, -h.z),
				Vector3(h.x, -h.y, -h.z),
				Vector3(h.x, h.y, -h.z),
				Vector3(-h.x, h.y, -h.z),
				Vector3(-h.x, -h.y, h.z),
				Vector3(h.x, -h.y, h.z),
				Vector3(h.x, h.y, h.z),
				Vector3(-h.x, h.y, h.z),
			]
			var quads := [
				[0, 2, 1],
				[0, 3, 2],
				[4, 5, 6],
				[4, 6, 7],
				[0, 1, 5],
				[0, 5, 4],
				[3, 7, 6],
				[3, 6, 2],
				[0, 4, 7],
				[0, 7, 3],
				[1, 2, 6],
				[1, 6, 5],
			]
			for q in quads:
				tris.append(xform * corners[q[0]])
				tris.append(xform * corners[q[1]])
				tris.append(xform * corners[q[2]])
	return tris


## Möller-Trumbore segment/triangle-soup test (double-sided, inclusive ends).
func _segment_hits_tris(from: Vector3, to: Vector3, tris: PackedVector3Array) -> bool:
	var d := to - from
	var i := 0
	while i + 2 < tris.size():
		var v0: Vector3 = tris[i]
		var v1: Vector3 = tris[i + 1]
		var v2: Vector3 = tris[i + 2]
		i += 3
		var e1 := v1 - v0
		var e2 := v2 - v0
		var pv := d.cross(e2)
		var det := e1.dot(pv)
		if det > -0.000001 and det < 0.000001:
			continue
		var inv := 1.0 / det
		var tv := from - v0
		var u := tv.dot(pv) * inv
		if u < -0.000001 or u > 1.000001:
			continue
		var qv := tv.cross(e1)
		var v := d.dot(qv) * inv
		if v < -0.000001 or u + v > 1.000001:
			continue
		var t := e2.dot(qv) * inv
		if t >= -0.000001 and t <= 1.000001:
			return true
	return false


func _find_body_for(world: Node3D, placement: Node3D, label: String) -> StaticBody3D:
	for candidate in placement.find_children("*", "StaticBody3D", true, false):
		var body := candidate as StaticBody3D
		if body.name == "Collision_%s" % label or body.name == "Collision":
			return body
	for candidate in world.find_children("Collision_%s" % label, "StaticBody3D", true, false):
		return candidate as StaticBody3D
	return null


func _has_collision_named(scope: Node, key: String) -> bool:
	for candidate in scope.find_children("*", "StaticBody3D", true, false):
		if String(candidate.name).contains(key):
			return true
	return false


func _find_named(scope: Node, node_name: String, parent_hint: String) -> Node3D:
	var matches := scope.find_children(node_name, "Node3D", true, false)
	if matches.is_empty():
		matches = scope.find_children(node_name, "", true, false)
	for candidate in matches:
		var node := candidate as Node3D
		if node == null:
			continue
		if parent_hint.is_empty() or String(node.get_parent().name) == parent_hint:
			return node
	if not matches.is_empty():
		return matches[0] as Node3D
	return null


func _combined_aabb(root_node: Node3D) -> AABB:
	var box := AABB()
	var has := false
	for candidate in root_node.find_children("*", "MeshInstance3D", true, false):
		var mesh_instance := candidate as MeshInstance3D
		if mesh_instance == null or mesh_instance.mesh == null:
			continue
		var part := mesh_instance.global_transform * mesh_instance.get_aabb()
		box = part if not has else box.merge(part)
		has = true
	if not has and root_node is MeshInstance3D:
		var solo := root_node as MeshInstance3D
		if solo.mesh != null:
			box = solo.global_transform * solo.get_aabb()
			has = true
	return box


func _expect(condition: bool, message: String) -> bool:
	if not condition:
		push_error("COLLISION INTEGRITY smoke test failed: " + message)
	return condition
