extends SceneTree

const MainScene = preload("res://scenes/main.tscn")


func _initialize() -> void:
	call_deferred("_run_smoke_test")


func _run_smoke_test() -> void:
	var main_scene := MainScene.instantiate()
	main_scene.set("start_wave_session_on_ready", false)
	root.add_child(main_scene)
	await process_frame
	await physics_frame

	var world: Node3D = main_scene.get_node("NeonFrontier")
	var player: Node3D = main_scene.get_node("Player")
	var test_passed := true
	var required_components: Array[String] = [
		"ArenaFloor",
		"ContinuousFrontierSurface",
		"CentralArenaDeck",
		"CentralReactor",
		"OutpostCommandCenter",
		"WeaponResearchLaboratory",
		"FieldEquipmentDepot",
		"FrontierEnergyExtractionBank",
		"EastVehicleLandingPlatform",
		"BossEncounterPlatform",
		"ColossalDockingGate",
		"CrashedFrontierTransport",
		"AlienDroneWreck",
		"WestPerimeter",
		"NorthPerimeter",
		"ArenaEnvironment",
		"FrontierDaylightSun",
	]
	for component_name in required_components:
		test_passed = (
			_expect(
				world.get_node_or_null(component_name) != null,
				"world contains the 3D component " + component_name,
			)
			and test_passed
		)

	var kaykit_model_names: Array[String] = [
		"KayKitCargoDepot",
		"KayKitDepotCargo_00",
		"KayKitLandingPadSurface",
		"KayKitOutpostServiceTruck",
		"KayKitOutpostSupply_00",
		"KayKitFrontierDrillStructure",
		"KayKitFrontierCliffRock_00",
	]
	for model_name in kaykit_model_names:
		var model := world.find_child(model_name, true, false) as Node3D
		test_passed = (
			_expect(
				(
					model != null
					and not model.find_children("*", "MeshInstance3D", true, false).is_empty()
				),
				"world instantiates the licensed KayKit 3D model " + model_name,
			)
			and test_passed
		)
	# The world is now dressed from the whole 57-model pack, not the 7 models of
	# the first pass. Each district has its own group, and the name of the group
	# is what tells a reviewer which part of the level to look at.
	var kit_groups: Dictionary = {
		"KayKitArenaRim": 16,
		"KayKitOutpost": 20,
		"KayKitLandingZone": 10,
		"KayKitExtraction": 15,
		"KayKitBossZone": 10,
		"KayKitRuins": 12,
		"KayKitPower": 8,
		"KayKitRoutes": 10,
		"KayKitTerrainShoulders": 120,
	}
	for group_name in kit_groups:
		var group := world.get_node_or_null(group_name) as Node3D
		var meshes := 0
		if group != null:
			meshes = group.find_children("*", "MeshInstance3D", true, false).size()
		test_passed = (
			_expect(
				meshes >= int(kit_groups[group_name]),
				"%s is dressed from the KayKit pack (%d meshes)" % [group_name, meshes],
			)
			and test_passed
		)
	# The uploaded SciFi Starter Kit is the playable interior: a 7x7 floor grid,
	# wall runs with a lane opening per side, and a door frame on each lane.
	var bay := world.get_node_or_null("SciFiBay") as Node3D
	var bay_floor := 0
	var bay_walls := 0
	var bay_gates := 0
	if bay != null:
		for child in bay.get_children():
			var child_name := str(child.name)
			if child_name.begins_with("SciFiBayFloor"):
				bay_floor += 1
			elif child_name.begins_with("SciFiBayWall") or child_name.begins_with("SciFiBayCover"):
				bay_walls += 1
			elif child_name.begins_with("SciFiBayGate"):
				bay_gates += 1
	test_passed = (
		_expect(
			bay_floor >= 49 and bay_walls >= 28 and bay_gates == 4,
			(
				"the arena interior is built from the uploaded SciFi kit (floor %d, walls %d, gates %d)"
				% [bay_floor, bay_walls, bay_gates]
			),
		)
		and test_passed
	)
	# The boundary is no longer four flat boxes: a collider keeps the player in,
	# and rock tiles close the horizon. Both have to exist at the same time.
	for wall_name in [
		"NorthBoundaryCliffCore",
		"SouthBoundaryCliffCore",
		"WestBoundaryCliffCore",
		"EastBoundaryCliffCore",
	]:
		var wall := world.get_node_or_null(wall_name) as Node3D
		test_passed = (
			_expect(
				wall != null and not wall.visible and wall.get_child_count() > 0,
				"invisible boundary collider still stops the player: " + wall_name,
			)
			and test_passed
		)
	# Cliff tiles are direct children of the world node, not nested under a
	# group, so they are counted by name prefix.
	var cliff_meshes := 0
	for child in world.get_children():
		if (
			String(child.name).begins_with("NorthCliff_")
			or String(child.name).begins_with("EastCliff_")
		):
			cliff_meshes += 1
	test_passed = (
		_expect(
			cliff_meshes >= 16,
			"the horizon is tiled with rock, not one flat box (%d tiles)" % cliff_meshes
		)
		and test_passed
	)

	var depot_model := world.find_child("KayKitCargoDepot", true, false) as Node3D
	if depot_model != null:
		test_passed = (
			_expect(
				depot_model.find_child("KayKitCargoDepotCollision", true, false) != null,
				"imported depot model receives a physical bounds collider",
			)
			and test_passed
		)

	var mesh_instances := world.find_children("*", "MeshInstance3D", true, false)
	var static_bodies := world.find_children("*", "StaticBody3D", true, false)
	print(
		(
			"NEON FRONTIER assembled: %d meshes and %d static bodies."
			% [mesh_instances.size(), static_bodies.size()]
		)
	)
	test_passed = (
		_expect(
			mesh_instances.size() >= 1000,
			"world is assembled from many individual 3D mesh assets, not a flat image",
		)
		and test_passed
	)
	test_passed = (
		_expect(
			static_bodies.size() >= 45,
			"buildings, cover, gates, platforms, and cliffs have physical 3D collision",
		)
		and test_passed
	)

	var floor_collision := (
		world.get_node_or_null("ArenaFloor/ArenaFloorCollisionShape") as CollisionShape3D
	)
	var floor_shape: BoxShape3D = null
	if floor_collision != null:
		floor_shape = floor_collision.shape as BoxShape3D
	test_passed = (
		_expect(
			floor_shape != null and floor_shape.size.x >= 180.0 and floor_shape.size.z >= 170.0,
			"continuous terrain collider covers the complete explorable world",
		)
		and test_passed
	)
	for route_name in [
		"WestRouteLeg",
		"EastRouteLeg",
		"NorthRouteCauseway",
		"BossRouteRamp",
		"BossRouteLanding",
		"SouthPerimeterGateApproach",
		"SouthWreckApproach",
	]:
		test_passed = (
			_expect(
				world.get_node_or_null(route_name) != null, "district route exists: " + route_name
			)
			and test_passed
		)

	player.global_position = Vector3(0.0, 0.0, 8.0)
	player.set("velocity", Vector3.ZERO)
	player.call("set_touch_movement", Vector2.UP)
	for _frame in 800:
		await physics_frame
		if player.global_position.z <= -49.0:
			break
	player.call("set_touch_movement", Vector2.ZERO)
	test_passed = (
		_expect(
			player.global_position.z <= -49.0,
			"player can walk from the central arena through the defense gate to the boss causeway",
		)
		and test_passed
	)
	print("Central-to-boss causeway traversal ended at %s." % player.global_position)
	player.call("set_touch_movement", Vector2.UP)
	for _frame in 300:
		await physics_frame
		if player.global_position.z <= -64.0 and player.global_position.y >= 0.25:
			break
	player.call("set_touch_movement", Vector2.ZERO)
	test_passed = (
		_expect(
			player.global_position.z <= -64.0 and player.global_position.y >= 0.25,
			"shallow boss-platform ramp lets the player reach the elevated encounter floor",
		)
		and test_passed
	)
	print("Boss-platform ramp traversal ended at %s." % player.global_position)

	player.global_position = Vector3(28.0, 0.0, 5.0)
	player.set("velocity", Vector3.ZERO)
	player.call("set_touch_movement", Vector2.RIGHT)
	for _frame in 300:
		await physics_frame
		if player.global_position.x >= 39.0 and player.global_position.y >= 0.1:
			break
	player.call("set_touch_movement", Vector2.ZERO)
	test_passed = (
		_expect(
			player.global_position.x >= 39.0 and player.global_position.y >= 0.1,
			"player can use the shallow access ramp to reach the raised vehicle landing pad",
		)
		and test_passed
	)
	print("Landing-pad ramp traversal ended at %s." % player.global_position)

	main_scene.queue_free()
	await process_frame
	if test_passed:
		print(
			(
				"NEON FRONTIER 3D world smoke test passed (%d meshes, %d static bodies)."
				% [mesh_instances.size(), static_bodies.size()]
			)
		)
		quit()
	else:
		quit(1)


func _expect(condition: bool, message: String) -> bool:
	if not condition:
		push_error("NEON FRONTIER world smoke test failed: " + message)
	return condition
