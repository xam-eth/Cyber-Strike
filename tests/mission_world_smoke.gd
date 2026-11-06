extends SceneTree
##
## mission_world_smoke.gd — verifies SH-01 Aetherfall loads cleanly through
## `MissionWorld`, carries real imported GLB geometry + colliders + lighting,
## spawns the operative at the Arrival Outpost, and leaves all 5 legacy worlds
## completely absent.
##
const MainScene = preload("res://scenes/main.tscn")
const WorldScene = preload("res://scenes/worlds/mission_world.tscn")
const WorldScript = preload("res://scripts/worlds/mission_world.gd")

var _passed := true


func _initialize() -> void:
	call_deferred("_run_smoke_test")


func _run_smoke_test() -> void:
	_passed = (
		_expect(
			(
				WorldDefinition.DEFINITION_IDS.size() == 1
				and WorldDefinition.DEFINITION_IDS[0] == &"aetherfall"
			),
			"WorldDefinition registry contains only SH-01 Aetherfall",
		)
		and _passed
	)
	_passed = (
		_expect(
			(
				WorldScript.world_for_selection("aetherfall") == "aetherfall"
				and WorldScript.world_for_selection("sh01") == "aetherfall"
			),
			"launcher ids resolve cleanly to SH-01 Aetherfall",
		)
		and _passed
	)

	await _check_aetherfall_world()
	await _check_gameplay_deployment()

	if _passed:
		print("MISSION WORLD smoke test passed.")
		quit()
	else:
		quit(1)


func _check_aetherfall_world() -> void:
	var world := WorldScene.instantiate() as Node3D
	world.set("world_override", "aetherfall")
	root.add_child(world)
	for _warm in 4:
		await process_frame
	await physics_frame

	var real_world := world.get_node_or_null("RealFrontierWorld") as Node3D
	if not _expect(real_world != null, "Aetherfall instances RealFrontierWorld"):
		world.queue_free()
		await process_frame
		return

	_passed = (
		_expect(
			String(real_world.get_meta("world_id", "")) == "aetherfall",
			"RealFrontierWorld carries world_id = aetherfall",
		)
		and _passed
	)

	var meshes := real_world.find_children("*", "MeshInstance3D", true, false)
	var colliders := real_world.find_children("*", "CollisionShape3D", true, false)
	var textured := 0
	for candidate in meshes:
		var mi := candidate as MeshInstance3D
		if mi.mesh == null or mi.mesh.get_surface_count() == 0:
			continue
		var mat := mi.get_active_material(0) as StandardMaterial3D
		if mat != null and mat.albedo_texture != null:
			textured += 1

	_passed = (
		_expect(
			meshes.size() >= 120 and textured >= 60 and colliders.size() >= 25,
			(
				"Aetherfall carries rich 3D geometry (%d meshes, %d textured, %d colliders)"
				% [meshes.size(), textured, colliders.size()]
			),
		)
		and _passed
	)

	var spawns := real_world.get_node_or_null("Spawns") as Node3D
	_passed = (
		_expect(
			spawns != null and spawns.get_child_count() >= 1,
			"Aetherfall world builds authored Spawns markers",
		)
		and _passed
	)

	var sun := real_world.get_node_or_null("Sun") as DirectionalLight3D
	_passed = (
		_expect(
			sun != null and sun.light_color.is_equal_approx(WorldMood.sun_color("aetherfall")),
			"Aetherfall applies crisp alpine Sun DirectionalLight3D colour",
		)
		and _passed
	)

	world.queue_free()
	await process_frame


func _check_gameplay_deployment() -> void:
	var prev := WorldSelection.override_selection(&"aetherfall")
	var main := MainScene.instantiate() as Node3D
	main.set("start_wave_session_on_ready", false)
	main.get_node("ProgressionService").set("profile_path", "")
	root.add_child(main)
	for _warm in 4:
		await process_frame
		await physics_frame
	WorldSelection.override_selection(prev)

	var main_spawns := main.get_node_or_null("SpawnPoints") as Node3D
	_passed = (
		_expect(
			main_spawns != null and main_spawns.get_child_count() >= 10,
			"Main builds >= 10 OBB-clean tactical SpawnPoints for WaveDirector",
		)
		and _passed
	)

	var player := main.get_node("Player") as CharacterBody3D
	_passed = (
		_expect(
			player.global_position.distance_to(Vector3(-18.0, 1.2, 3.0)) < 2.0,
			"Player deploys at Aetherfall Arrival Outpost (%s)" % [player.global_position],
		)
		and _passed
	)
	_passed = (
		_expect(
			main.get_node("RecoveryCaches").get_child_count() == 4,
			"Main mounts all 4 Aetherfall RecoveryCacheVisual landmarks",
		)
		and _passed
	)

	main.queue_free()
	await process_frame


func _expect(condition: bool, message: String) -> bool:
	if not condition:
		push_error("MISSION WORLD smoke test failed: " + message)
	return condition
