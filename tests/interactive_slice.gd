extends SceneTree
## End-to-end contract for the smallest Stellar Horizon interaction slice.
## It verifies actual Area3D range, collision nodes, animation clips, one-time
## persisted reward commit, objective dependency and clean duplicate rejection.

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
	var player := world.get_node_or_null("AetherfallPlayer") as AetherfallPlayer
	var cache := world.get_node_or_null("StellarHorizon/aetherfall_primary_tech_cache") as AetherfallTechCache
	var device := world.get_node_or_null("StellarHorizon/aetherfall_horizon_relay") as AetherfallObjectiveDevice
	if state == null or player == null or cache == null or device == null:
		fail("komponen vertical slice tidak lengkap")
		return
	state.clear_persisted_profile_for_test()
	if cache.get_node_or_null("Collision/Shape") == null or cache.get_node_or_null("InteractionRange/Shape") == null:
		fail("cache tidak memiliki collision/range yang dipisahkan")
		return
	if device.get_node_or_null("Collision/Shape") == null or device.get_node_or_null("InteractionRange/Shape") == null:
		fail("device tidak memiliki collision/range yang dipisahkan")
		return
	if cache.find_children("*", "AnimationPlayer", true, false).is_empty() or device.find_children("*", "AnimationPlayer", true, false).is_empty():
		fail("animasi authored GLB tidak diimpor")
		return
	var cache_anim := cache.find_children("*", "AnimationPlayer", true, false)[0] as AnimationPlayer
	var device_anim := device.find_children("*", "AnimationPlayer", true, false)[0] as AnimationPlayer
	if not cache_anim.has_animation(&"TechCache_Open") or not device_anim.has_animation(&"ObjectiveDevice_Activate"):
		fail("nama klip animasi interaktif tidak sesuai")
		return
	player.global_position = cache.global_position + Vector3(0, 0.2, 1.4)
	await physics_frame
	await physics_frame
	if not cache.is_actor_in_range(player):
		fail("Area3D cache tidak mendeteksi operator dalam jangkauan")
		return
	var missing_before := device.attempt_interaction(player)
	if missing_before.get("code", "") != "out_of_range":
		fail("validasi jarak perangkat tidak menolak actor di lokasi cache")
		return
	var reward := cache.attempt_interaction(player)
	if not reward.get("ok", false) or state.tech_data != 1 or not state.has_claimed_cache(cache.interaction_id):
		fail("transaction reward cache tidak committed satu kali")
		return
	var duplicate := cache.attempt_interaction(player)
	if duplicate.get("code", "") != "already_claimed" or state.tech_data != 1:
		fail("anti-duplikasi cache gagal")
		return
	player.global_position = device.global_position + Vector3(0, 0.2, 1.3)
	await physics_frame
	await physics_frame
	if not device.is_actor_in_range(player):
		fail("Area3D device tidak mendeteksi operator dalam jangkauan")
		return
	var activation := device.attempt_interaction(player)
	if not activation.get("ok", false) or not state.is_objective_active(device.interaction_id):
		fail("objective device tidak mengaktifkan state yang valid")
		return
	var repeated_activation := device.attempt_interaction(player)
	if repeated_activation.get("code", "") != "already_active":
		fail("anti-duplikasi objective gagal")
		return
	var verifier := AetherfallProgressionState.new()
	root.add_child(verifier)
	await process_frame
	if verifier.tech_data != 1 or not verifier.has_claimed_cache(cache.interaction_id) or not verifier.is_objective_active(device.interaction_id):
		fail("persistensi state vertical slice tidak dapat dibaca ulang")
		return
	verifier.clear_persisted_profile_for_test()
	world.queue_free()
	print("PASS Stellar Horizon: range, collision, animasi, reward persist, objective, anti-duplikasi")
	quit(0)

func fail(message: String) -> void:
	push_error("FAIL Stellar Horizon: " + message)
	quit(1)
