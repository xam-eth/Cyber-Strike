extends SceneTree
## Contract for focused structural density, kept separate from the 251-kit layout.

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
	var group := world.get_node_or_null("StructuralLandmarks") as Node3D
	if group == null or world.landmark_count != 6:
		fail("enam placement landmark terarah tidak termuat")
		return
	if world.landmark_collider_count != 9:
		fail("collision landmark tidak sesuai konfigurasi")
		return
	for landmark_name in ["primary_arrival_outpost", "horizon_relay_annex", "east_service_hangar"]:
		var landmark := group.get_node_or_null(landmark_name) as Node3D
		if landmark == null or landmark.get_node_or_null("Visual") == null or landmark.get_node_or_null("Collision") == null:
			fail("landmark bangunan tidak lengkap: " + landmark_name)
			return
	var lights := group.find_children("StructuralLight", "OmniLight3D", true, false)
	if lights.size() != 3:
		fail("pencahayaan landmark terarah tidak lengkap")
		return
	print("PASS Structural landmarks: 6 placement, 9 collision, 3 building, 3 light")
	world.queue_free()
	quit(0)

func fail(message: String) -> void:
	push_error("FAIL Structural landmarks: " + message)
	quit(1)
