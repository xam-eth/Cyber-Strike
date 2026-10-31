extends SceneTree
## Runtime assembly contract for the connected outdoor Expanse. It checks only
## environment topology/physical surface nodes; it does not claim a controller,
## falling damage, respawn, AI, combat, or streaming result.

func _initialize() -> void:
	call_deferred("run_test")

func run_test() -> void:
	var scene := load("res://scenes/aetherfall.tscn") as PackedScene
	if scene == null:
		fail("scene Aetherfall tidak dapat dimuat")
		return
	var world := scene.instantiate()
	root.add_child(world)
	await process_frame
	await physics_frame
	var expanse := world.get_node_or_null("ConnectedExpanse") as Node3D
	if expanse == null:
		fail("ConnectedExpanse tidak termuat")
		return
	if world.expanse_lowland_count != 9 or world.expanse_shelf_count != 14 or world.expanse_route_count != 18:
		fail("jumlah lowland/shelf/route expanse tidak sesuai konfigurasi")
		return
	if world.expanse_collider_count != 41:
		fail("collision surface expanse tidak sesuai konfigurasi")
		return
	var lowlands := expanse.get_node_or_null("LowlandFields") as Node3D
	var shelves := expanse.get_node_or_null("RimShelves") as Node3D
	var loop := expanse.get_node_or_null("PerimeterLoop") as Node3D
	if lowlands == null or shelves == null or loop == null or lowlands.get_child_count() != 9 or shelves.get_child_count() != 14 or loop.get_child_count() != 18:
		fail("hierarki expanse tidak lengkap")
		return
	for route_name in [
		"west_catwalk_to_release", "east_glacis_to_bridge",
		"southeast_cut_to_lower_canyon", "west_exposure_to_catwalk",
		"lower_canyon_to_icefield",
	]:
		var route := loop.get_node_or_null(route_name) as Node3D
		if route == null or route.get_node_or_null("Visual") == null or route.get_node_or_null("Collision/Surface") == null:
			fail("route expanse tidak lengkap: " + route_name)
			return
	for field_name in ["lowland_northwest", "lowland_core", "lowland_southeast"]:
		var field := lowlands.get_node_or_null(field_name) as Node3D
		if field == null or field.get_node_or_null("Collision/Surface") == null:
			fail("catch terrain lowland hilang: " + field_name)
			return
	print("PASS World Expansion: 9 lowland, 14 shelf, 18 route, 41 collision; loop endpoint terhubung")
	world.queue_free()
	quit(0)

func fail(message: String) -> void:
	push_error("FAIL World Expansion: " + message)
	quit(1)
