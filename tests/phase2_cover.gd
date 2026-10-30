extends SceneTree
## Runtime contract for the Phase 2 environment assembly. It does not claim AI,
## combat, damage, hazards, or a playable Archive interior.

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
	var group := world.get_node_or_null("Phase2Cover") as Node3D
	if group == null or world.phase2_cover_count != 8:
		fail("delapan placement cover Phase 2 tidak termuat")
		return
	if world.phase2_cover_collider_count != 12:
		fail("dua belas collision cover/terrace Phase 2 tidak termuat")
		return
	for name in [
		"landing_ridge_berm", "basin_west_berm", "basin_east_salvage_pod",
		"basin_east_cryo_bulkhead", "archive_west_berm",
		"west_basin_ice_terrace", "east_flank_ice_terrace",
		"lower_canyon_salvage_pod",
	]:
		var setpiece := group.get_node_or_null(name) as Node3D
		if setpiece == null or setpiece.get_node_or_null("Visual") == null or setpiece.get_node_or_null("Collision") == null:
			fail("setpiece Phase 2 tidak lengkap: " + name)
			return
	for name in ["west_basin_ice_terrace", "east_flank_ice_terrace"]:
		var terrace := group.get_node(name) as Node3D
		var collision := terrace.get_node_or_null("Collision") as StaticBody3D
		if collision == null or collision.get_child_count() != 3:
			fail("terrace tidak memiliki tiga level collision: " + name)
			return
	var lights := group.find_children("Phase2CoverLight", "OmniLight3D", true, false)
	if lights.size() != 3:
		fail("lampu diagnostik Phase 2 tidak sesuai konfigurasi")
		return
	print("PASS Phase 2 Cover: 8 placement, 12 collision, 2 terrace bertingkat, 3 lampu")
	world.queue_free()
	quit(0)

func fail(message: String) -> void:
	push_error("FAIL Phase 2 Cover: " + message)
	quit(1)
