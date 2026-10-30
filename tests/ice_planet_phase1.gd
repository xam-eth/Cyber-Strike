extends SceneTree
## Phase 1 contract: visible outdoor ice-planet composition and archive goal.

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
	var group := world.get_node_or_null("IcePlanetPhase1") as Node3D
	if group == null or world.ice_planet_count != 9:
		fail("sembilan placement ice-planet Phase 1 tidak termuat")
		return
	if world.ice_planet_collider_count != 6:
		fail("collider shell Sentinel Archive tidak sesuai threshold interior")
		return
	var archive := group.get_node_or_null("sentinel_archive_exterior") as Node3D
	if archive == null or archive.get_node_or_null("Visual") == null or archive.get_node_or_null("Collision") == null:
		fail("Sentinel Archive exterior tidak lengkap")
		return
	var glacial_walls := ["west_glacier_wall", "east_glacier_wall", "west_outer_glacier", "east_outer_glacier"]
	for wall_name in glacial_walls:
		if group.get_node_or_null(wall_name) == null:
			fail("perimeter glacier hilang: " + wall_name)
			return
	var archive_lights := group.find_children("IcePlanetLight", "OmniLight3D", true, false)
	if archive_lights.size() != 1:
		fail("pencahayaan tujuan archive tidak termuat")
		return
	print("PASS Ice Planet Phase 1: 9 placement, archive, glacier perimeter, pylon, light")
	world.queue_free()
	quit(0)

func fail(message: String) -> void:
	push_error("FAIL Ice Planet Phase 1: " + message)
	quit(1)
