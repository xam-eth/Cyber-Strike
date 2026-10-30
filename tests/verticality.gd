extends SceneTree
## Ensures the structural pass creates actual elevated/vertical setpieces,
## rather than only increasing flat deck prop count.

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
	var group := world.get_node_or_null("VerticalInfrastructure") as Node3D
	if group == null or world.verticality_count != 4:
		fail("empat placement infrastruktur vertikal tidak termuat")
		return
	if world.verticality_collider_count != 12:
		fail("collision infrastruktur vertikal tidak sesuai konfigurasi")
		return
	for name in ["west_refinery_stack", "east_refinery_stack", "central_overhead_gantry", "west_raised_ops_deck"]:
		var structure := group.get_node_or_null(name) as Node3D
		if structure == null or structure.get_node_or_null("Visual") == null or structure.get_node_or_null("Collision") == null:
			fail("setpiece vertikal tidak lengkap: " + name)
			return
	var lights := group.find_children("VerticalLight", "OmniLight3D", true, false)
	if lights.size() != 1:
		fail("lampu gantry terarah tidak termuat")
		return
	print("PASS Verticality: 4 placement, 12 collision, refinery, gantry, raised deck")
	world.queue_free()
	quit(0)

func fail(message: String) -> void:
	push_error("FAIL Verticality: " + message)
	quit(1)
