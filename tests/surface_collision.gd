extends SceneTree

# Test selected imported walking surfaces against the physical box used in-world.
func _initialize() -> void:
	call_deferred("run_test")

func run_test() -> void:
	var world := (load("res://scenes/aetherfall.tscn") as PackedScene).instantiate()
	root.add_child(world)
	await process_frame
	var layout: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://assets/world/aetherfall/layout.json"))
	var choices := {"deck_6x6": "DeckPlate", "bridge_deck": "BridgeDeck", "walkway_deck": "WalkwayDeck"}
	var expected := {"deck_6x6": Vector3(6, 0.5, 6), "bridge_deck": Vector3(6, 0.7, 8), "walkway_deck": Vector3(1.6, 0.35, 6)}
	for body in world.get_node("Collision").get_children():
		body.collision_layer = 0
	for connector in world.get_node("Connectors").get_children():
		connector.get_node("DeckCollision").collision_layer = 0
	for key in choices:
		var entry: Dictionary = {}
		for placement in layout.placements:
			if placement.asset == key:
				entry = placement
				break
		if entry.is_empty():
			fail("missing placement " + key)
			return
		var instance: Node3D = world.get_node("Modules").get_node(entry.name)
		var mesh := instance.find_child(choices[key], true, false) as MeshInstance3D
		var body: StaticBody3D = world.get_node("Collision").get_node("Collision_" + entry.name)
		var shape: CollisionShape3D = body.get_node("Shape")
		var local_bounds: AABB = (instance.global_transform.affine_inverse() * mesh.global_transform) * mesh.get_aabb()
		if not local_bounds.size.is_equal_approx(expected[key]):
			fail("orientation or mesh bounds incorrect for %s: %s" % [key, local_bounds.size])
			return
		if not (shape.shape as BoxShape3D).size.is_equal_approx(local_bounds.size * float(entry.scale)):
			fail("collider dimensions incorrect for " + key)
			return
		var mesh_center: Vector3 = mesh.to_global(mesh.get_aabb().get_center())
		if shape.global_position.distance_to(mesh_center) > 0.01:
			fail("collider center incorrect for " + key)
			return
		# Isolate this body and raycast onto the middle of its top surface.
		body.collision_layer = 1
		await physics_frame
		await physics_frame
		var top := mesh_center.y + local_bounds.size.y * float(entry.scale) * 0.5
		var from := Vector3(mesh_center.x, top + 2.0, mesh_center.z)
		var query := PhysicsRayQueryParameters3D.create(from, from - Vector3(0, 4, 0))
		var hit: Dictionary = world.get_world_3d().direct_space_state.intersect_ray(query)
		if hit.is_empty() or hit.collider != body or absf(hit.position.y - top) > 0.01:
			fail("raycast did not hit expected surface for %s: %s" % [key, hit])
			return
		body.collision_layer = 0
		print("PASS %s: size %s top %.3f" % [key, local_bounds.size, top])
	var connectors: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://assets/world/aetherfall/connectors.json"))
	for spec in connectors.connectors:
		var connector: Node3D = world.get_node("Connectors").get_node(spec.name)
		var body: StaticBody3D = connector.get_node("DeckCollision")
		body.collision_layer = 1
		await physics_frame
		await physics_frame
		var a := Vector3(spec.from[0], spec.from[1], spec.from[2])
		var b := Vector3(spec.to[0], spec.to[1], spec.to[2])
		for t in [0.1, 0.5, 0.9]:
			var point := a.lerp(b, t)
			var query := PhysicsRayQueryParameters3D.create(point + Vector3.UP * 2.0, point - Vector3.UP * 2.0)
			var hit: Dictionary = world.get_world_3d().direct_space_state.intersect_ray(query)
			if hit.is_empty() or hit.collider != body or absf(hit.position.y - point.y) > 0.02:
				fail("connector %s sample %.1f: %s" % [spec.name, t, hit])
				return
		body.collision_layer = 0
		print("PASS connector %s: three surface samples" % spec.name)
	world.queue_free()
	quit(0)

func fail(message: String) -> void:
	push_error("FAIL surface collision: " + message)
	quit(1)
