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

	var env_node := world.get_node_or_null("ArenaEnvironment") as WorldEnvironment
	var sun := world.get_node_or_null("FrontierDaylightSun") as DirectionalLight3D
	var reactor_fill := world.get_node_or_null("ReactorCyanBounce") as OmniLight3D
	var graded := env_node != null and env_node.environment != null
	if graded:
		graded = (
			env_node.environment.tonemap_mode == Environment.TONE_MAPPER_ACES
			and env_node.environment.ambient_light_source == Environment.AMBIENT_SOURCE_COLOR
			and (
				env_node.environment.ambient_light_color.b
				>= env_node.environment.ambient_light_color.r
			)
			and env_node.environment.adjustment_saturation < 1.0
			and sun != null
			and sun.light_color.r > sun.light_color.b
			and sun.light_energy < 1.1
			and sun.shadow_enabled
			and sun.shadow_opacity >= 0.5
			and sun.shadow_opacity <= 0.65
			and reactor_fill != null
			and reactor_fill.omni_range <= 13.0
			and reactor_fill.light_energy < 0.8
		)
	test_passed = (
		_expect(
			(
				graded
				and world.get_node_or_null("NorthRouteWayfinder") != null
				and world.get_node_or_null("SouthRouteWayfinder") != null
			),
			"relight controls sky/fill energy and gives the player path wayfinders",
		)
		and test_passed
	)

	# Architectural cladding comes from the uploaded converted FBX pack. The
	# terrain/foundations are still procedural; never mistake this model check
	# for proof that every visible surface is an imported FBX. KayKit is gone.
	var kit_models: Array[String] = [
		"SciFiEquipmentDepotFacade",
		"SciFiEquipmentSupply_00",
		"SciFiLandingDeck_0_0",
		"SciFiOutpostServiceBay",
		"SciFiOutpostSupply_00",
		"SciFiExtractionPipeArray",
		"SciFiFrontierRuin_00",
	]
	for model_name in kit_models:
		var model := world.find_child(model_name, true, false) as Node3D
		test_passed = (
			_expect(
				(
					model != null
					and not model.find_children("*", "MeshInstance3D", true, false).is_empty()
				),
				"world instantiates the user's FBX-based SciFi kit model " + model_name,
			)
			and test_passed
		)
	test_passed = (
		_expect(
			world.find_children("KayKit*", "Node3D", true, false).is_empty(),
			"the playable world no longer instantiates KayKit assets",
		)
		and test_passed
	)
	var kit_pylons := 0
	for candidate in world.find_children("SciFiReactorPylon_*", "Node3D", true, false):
		if not candidate.find_children("*", "MeshInstance3D", true, false).is_empty():
			kit_pylons += 1
	test_passed = (
		_expect(kit_pylons == 4, "the central reactor's pylons use uploaded FBX geometry")
		and test_passed
	)
	var reactor := world.get_node_or_null("CentralReactor") as Node3D
	var spine: MeshInstance3D = null
	var coils: MeshInstance3D = null
	var glass: MeshInstance3D = null
	if reactor != null:
		spine = reactor.get_node_or_null("EmeraldEnergyColumn") as MeshInstance3D
		coils = reactor.get_node_or_null("ReactorCoils") as MeshInstance3D
		glass = reactor.get_node_or_null("ContainmentGlass") as MeshInstance3D
	var spine_mesh := spine.mesh as CylinderMesh if spine != null else null
	var coil_material := coils.material_override as StandardMaterial3D if coils != null else null
	var glass_material := glass.material_override as StandardMaterial3D if glass != null else null
	test_passed = (
		_expect(
			(
				spine_mesh != null
				and spine_mesh.bottom_radius < 1.0
				and coils != null
				and coils.mesh != null
				and coils.mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX].size() >= 1400
				and coil_material != null
				and coil_material.cull_mode == BaseMaterial3D.CULL_DISABLED
				and glass_material != null
				and glass_material.albedo_color.a < 0.12
			),
			"reactor energy reads as slim powered coils in FBX framing, not an opaque green slab",
		)
		and test_passed
	)
	for district in ["Outpost", "Landing", "Extraction", "Boss", "Wreck"]:
		var group := world.get_node_or_null("SciFi%sDistrict" % district) as Node3D
		test_passed = (
			_expect(
				(
					group != null
					and group.find_children("*", "MeshInstance3D", true, false).size() >= 7
				),
				"%s district has uploaded FBX cladding, supplies and a route light" % district,
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
	# Check the authored map actually reaches the imported UV-mapped floor;
	# this verifies integration only, not whether the deck looks polished.
	var floor_instance: Node3D
	if bay != null:
		floor_instance = bay.get_node_or_null("SciFiBayFloor_3_3") as Node3D
	var floor_visuals: Array[Node] = []
	if floor_instance != null:
		floor_visuals = floor_instance.find_children("*", "MeshInstance3D", true, false)
	var deck_material: StandardMaterial3D = (
		(floor_visuals[0] as MeshInstance3D).get_active_material(0) as StandardMaterial3D
		if not floor_visuals.is_empty()
		else null
	)
	test_passed = (
		_expect(
			(
				deck_material != null
				and deck_material.albedo_texture != null
				and deck_material.albedo_texture.get_width() == 512
			),
			"authored deck map is bound to the uploaded FBX floor UVs",
		)
		and test_passed
	)
	# Physics bounds are hidden behind imported modular fencing and pylons.
	var perimeter := world.get_node_or_null("SciFiFrontierBoundary") as Node3D
	for side in ["North", "South", "West", "East"]:
		var core: Node3D = null
		var fence: Node3D = null
		if perimeter != null:
			core = perimeter.get_node_or_null("%sBoundaryCore" % side) as Node3D
			fence = perimeter.get_node_or_null("SciFi%sFence_00" % side) as Node3D
		test_passed = (
			_expect(
				core != null and not core.visible and core.get_child_count() > 0,
				"the %s physical boundary is invisible behind imported art" % side,
			)
			and test_passed
		)
		test_passed = (
			_expect(
				(
					fence != null
					and not fence.find_children("*", "MeshInstance3D", true, false).is_empty()
				),
				"the %s horizon has FBX fence geometry rather than a flat box" % side,
			)
			and test_passed
		)
	var depot := world.get_node_or_null("FieldEquipmentDepot") as Node3D
	test_passed = (
		_expect(
			depot != null and depot.get_node_or_null("SciFiEquipmentDepotFacadeBody") != null,
			"imported depot facade has a physical bounds collider",
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
