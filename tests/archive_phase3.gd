extends SceneTree
## End-to-end contract for the compact Archive Interior and its only final-tech
## source. It deliberately checks persistence/state, not combat or mission end.

func _initialize() -> void:
	call_deferred("run_test")

func run_test() -> void:
	var scene := load("res://scenes/aetherfall.tscn") as PackedScene
	if scene == null:
		fail("scene Aetherfall tidak dapat dimuat")
		return
	var world := scene.instantiate()
	root.add_child(world)
	await physics_frame
	await physics_frame
	var state := world.get_node_or_null("ProgressionState") as AetherfallProgressionState
	var interior := world.get_node_or_null("ArchiveInterior") as Node3D
	var computer := world.get_node_or_null("ArchiveInterior/aetherfall_sentinel_computer") as AetherfallArchiveComputer
	if state == null or interior == null or computer == null:
		fail("Archive interior, computer, atau state lokal tidak termuat")
		return
	state.clear_persisted_profile_for_test()
	computer.sync_from_progression()
	if world.archive_interior_count != 1 or world.archive_interior_collider_count != 4 or world.archive_computer_count != 1:
		fail("jumlah assembly interior Archive tidak sesuai konfigurasi")
		return
	if interior.get_node_or_null("VestibuleVisual") == null or interior.get_node_or_null("Collision") == null:
		fail("vestibule Archive tidak memiliki visual/collision")
		return
	# This probe sits at the south/front threshold shared with the exterior shell.
	# It proves the doorway is not represented by a sealed archive AABB.
	var capsule := CapsuleShape3D.new()
	capsule.radius = 0.28
	capsule.height = 1.5
	var threshold_probe := PhysicsShapeQueryParameters3D.new()
	threshold_probe.shape = capsule
	threshold_probe.transform = Transform3D(interior.global_transform.basis, interior.to_global(Vector3(0, 1.45, -2.45)))
	threshold_probe.collision_mask = 1
	var threshold_hits := world.get_world_3d().direct_space_state.intersect_shape(threshold_probe, 8)
	if not threshold_hits.is_empty():
		fail("threshold Archive masih tertutup collider: %s" % threshold_hits)
		return
	if computer.get_node_or_null("Collision/Shape") == null or computer.get_node_or_null("InteractionRange/Shape") == null:
		fail("Archive Computer tidak memiliki collision/range terpisah")
		return
	var players := computer.find_children("*", "AnimationPlayer", true, false)
	if players.is_empty() or not (players[0] as AnimationPlayer).has_animation(&"ArchiveComputer_Download"):
		fail("animasi download authored Archive Computer tidak diimpor")
		return
	# Main world stays character-free. The test owns a temporary interaction actor.
	var player_scene := load("res://scenes/aetherfall_player.tscn") as PackedScene
	var actor := player_scene.instantiate() as AetherfallPlayer
	actor.name = "ArchiveInteractionTestActor"
	root.add_child(actor)
	actor.global_position = computer.global_position + computer.global_transform.basis.z * 1.5 + Vector3.UP * .2
	await physics_frame
	await physics_frame
	if not computer.is_actor_in_range(actor):
		fail("Area3D Archive Computer tidak mendeteksi operator")
		return
	var locked := computer.attempt_interaction(actor)
	if locked.get("code", "") != "requirement_missing" or computer.current_state() != computer.LOCKED:
		fail("Archive Computer tidak mempertahankan state locked tanpa credential")
		return
	var credential := state.claim_tech_cache("archive_phase3_test_credential", 1)
	if not credential.get("ok", false) or state.tech_data != 1:
		fail("credential akses Archive tidak dapat di-commit")
		return
	var authorized := computer.attempt_interaction(actor)
	if not authorized.get("ok", false) or authorized.get("code", "") != "authorized" or computer.current_state() != computer.AUTHORIZED:
		fail("transisi locked ke authorized gagal")
		return
	if not state.is_archive_computer_authorized(computer.interaction_id):
		fail("otorisasi Archive Computer tidak tersimpan")
		return
	var download := computer.attempt_interaction(actor)
	if not download.get("ok", false) or download.get("code", "") != "downloading" or computer.current_state() != computer.DOWNLOADING:
		fail("transisi authorized ke downloading gagal")
		return
	var busy := computer.attempt_interaction(actor)
	if busy.get("code", "") != "download_in_progress":
		fail("download paralel tidak ditolak")
		return
	await create_timer(1.5).timeout
	if computer.current_state() != computer.COLLECTED or not state.has_data_core(computer.data_core_id):
		fail("Archive Data Core tidak committed setelah download")
		return
	var duplicate := computer.attempt_interaction(actor)
	if duplicate.get("code", "") != "already_collected":
		fail("Archive Data Core duplikat tidak ditolak")
		return
	var verifier := AetherfallProgressionState.new()
	root.add_child(verifier)
	await process_frame
	if verifier.tech_data != 1 or not verifier.is_archive_computer_authorized(computer.interaction_id) or not verifier.has_data_core(computer.data_core_id):
		fail("persistensi credential/otorisasi/Data Core tidak dapat dibaca ulang")
		return
	verifier.clear_persisted_profile_for_test()
	world.queue_free()
	print("PASS Archive Phase 3: vestibule, computer state, Data Core persist, anti-duplikasi")
	quit(0)

func fail(message: String) -> void:
	push_error("FAIL Archive Phase 3: " + message)
	quit(1)
