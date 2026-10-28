extends SceneTree

# Automated review actor, not a game character controller. It traverses the
# ramps with actual CharacterBody3D collision and all world obstacles enabled.
func _initialize() -> void:
	call_deferred("run_test")

func run_test() -> void:
	var world := (load("res://scenes/aetherfall.tscn") as PackedScene).instantiate() as Node3D
	root.add_child(world)
	await process_frame
	var data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://assets/world/aetherfall/connectors.json"))
	var actor := CharacterBody3D.new()
	actor.name = "TraversalTestActor"
	actor.floor_max_angle = deg_to_rad(40.0)
	actor.floor_snap_length = 0.35
	var capsule := CapsuleShape3D.new()
	capsule.height = 1.8
	capsule.radius = 0.28
	var shape := CollisionShape3D.new()
	shape.shape = capsule
	actor.add_child(shape)
	world.add_child(actor)
	for route: Dictionary in data.connectors:
		var a: Vector3 = world.v3(route.from)
		var b: Vector3 = world.v3(route.to)
		for reverse in [false, true]:
			var start := a.lerp(b, 0.95 if reverse else 0.05)
			var target := a.lerp(b, 0.05 if reverse else 0.95)
			var direction := Vector3(target.x - start.x, 0.0, target.z - start.z).normalized()
			actor.global_position = start + Vector3.UP * 0.95
			actor.velocity = Vector3.ZERO
			var reached := false
			for frame in range(480):
				await physics_frame
				actor.velocity = direction * 5.0 + Vector3.DOWN * 2.0
				actor.move_and_slide()
				var remaining := Vector2(target.x - actor.global_position.x, target.z - actor.global_position.z).length()
				if remaining < 0.32:
					reached = true
					break
				if actor.global_position.y < minf(start.y, target.y) - 4.0:
					break
			if not reached:
				fail("%s reverse=%s berhenti di %s, target %s" % [route.name, reverse, actor.global_position, target])
				return
			print("PASS gerak kapsul %s reverse=%s hingga %s" % [route.name, reverse, actor.global_position])
	world.queue_free()
	quit(0)

func fail(message: String) -> void:
	push_error("FAIL traversal motion: " + message)
	quit(1)
