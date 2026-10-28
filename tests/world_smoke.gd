extends SceneTree

func _initialize() -> void:
	call_deferred("run_test")

func run_test() -> void:
	var scene := load("res://scenes/aetherfall.tscn") as PackedScene
	if scene == null:
		fail("scene tidak dapat dimuat")
		return
	var world := scene.instantiate()
	root.add_child(world)
	await process_frame
	if world.placement_count != 251:
		fail("jumlah placement: %s" % world.placement_count)
		return
	if world.collider_count < 100:
		fail("collider: %s" % world.collider_count)
		return
	if world.get_node_or_null("Routes/east_bridge") == null or world.get_node_or_null("Spawns/primary") == null:
		fail("marker tidak tersedia")
		return
	var orbit := world.get_node_or_null("EnergyOrbit")
	if orbit == null or orbit.find_children("*", "AnimationPlayer", true, false).is_empty():
		fail("animasi orbit tidak dimuat")
		return
	var player := orbit.find_children("*", "AnimationPlayer", true, false)[0] as AnimationPlayer
	if not player.is_playing():
		fail("animasi orbit tidak sedang diputar")
		return
	print("PASS Aetherfall: %d placement, %d collider, routes, spawns, orbit" % [world.placement_count, world.collider_count])
	world.queue_free()
	quit(0)

func fail(message: String) -> void:
	push_error("FAIL Aetherfall: " + message)
	quit(1)
