extends SceneTree

# Uses the entire world, unlike the isolated surface test. A capsule approximates
# a 1.8 m review character; it does not replace a controller-driven playthrough.
func _initialize() -> void:
	call_deferred("run_test")

func run_test() -> void:
	var world := (load("res://scenes/aetherfall.tscn") as PackedScene).instantiate() as Node3D
	root.add_child(world)
	await process_frame
	await physics_frame
	await physics_frame
	var data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://assets/world/aetherfall/connectors.json"))
	var space := world.get_world_3d().direct_space_state
	var capsule := CapsuleShape3D.new()
	capsule.radius = 0.28
	capsule.height = 1.5
	for route: Dictionary in data.connectors:
		var a: Vector3 = world.v3(route.from)
		var b: Vector3 = world.v3(route.to)
		for n in range(1, 20):
			var t := float(n) / 20.0
			var p := a.lerp(b, t)
			var ray := PhysicsRayQueryParameters3D.create(p + Vector3.UP * 0.45, p - Vector3.UP * 0.45)
			var floor_hit := space.intersect_ray(ray)
			if floor_hit.is_empty() or absf(floor_hit.position.y - p.y) > 0.2:
				fail("%s t=%.2f tidak ada permukaan sesuai: %s" % [route.name, t, floor_hit])
				return
			var probe := PhysicsShapeQueryParameters3D.new()
			probe.shape = capsule
			probe.transform = Transform3D(Basis.IDENTITY, p + Vector3.UP * 1.1)
			var hits := space.intersect_shape(probe, 16)
			if not hits.is_empty():
				fail("%s t=%.2f terhalang: %s" % [route.name, t, hits])
				return
		print("PASS clearance %s: 19 titik, seluruh collider aktif" % route.name)
	world.queue_free()
	quit(0)

func fail(message: String) -> void:
	push_error("FAIL traversal: " + message)
	quit(1)
