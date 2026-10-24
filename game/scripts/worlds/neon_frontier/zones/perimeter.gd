## The boss encounter platform and the defense perimeter: the two zones that
## exist to be fought in.

## Split out of neon_frontier_world.gd, the composition root. The boss zone is
## the one builder that also reads `world._active_geometry_parent`, which is how
## it attaches to whatever geometry the world chose.
class_name NeonFrontierPerimeter
extends RefCounted


static func build_boss_encounter_zone(world) -> void:
	var platform_body := StaticBody3D.new()
	platform_body.name = "BossEncounterPlatform"
	platform_body.position = Vector3(0.0, -0.05, -63.0)
	platform_body.collision_layer = 1
	platform_body.collision_mask = 0
	var platform_shape := CollisionShape3D.new()
	var cylinder_shape := CylinderShape3D.new()
	cylinder_shape.radius = 19.0
	cylinder_shape.height = 0.68
	platform_shape.shape = cylinder_shape
	platform_body.add_child(platform_shape)
	world.add_child(platform_body)
	var platform_artwork := Node3D.new()
	platform_artwork.name = "BossPlatformArtwork"
	platform_artwork.scale.y = 0.3
	world.add_child(platform_artwork)
	world._active_geometry_parent = platform_artwork
	world._add_cylinder(
		"BossPlatformSilverRim",
		Vector3(0.0, 0.02, -63.0),
		19.0,
		19.0,
		0.5,
		world._materials["silver"],
		Vector3.ZERO,
		32
	)
	world._add_cylinder(
		"BossPlatformDeck",
		Vector3(0.0, 0.3, -63.0),
		17.7,
		17.7,
		0.12,
		world._materials["blue"],
		Vector3.ZERO,
		32
	)
	world._add_cylinder(
		"BossPlatformInnerDeck",
		Vector3(0.0, 0.39, -63.0),
		13.6,
		13.6,
		0.08,
		world._materials["pearl"],
		Vector3.ZERO,
		32
	)
	world._add_cylinder(
		"BossPlatformCenterPlate",
		Vector3(0.0, 0.45, -63.0),
		8.5,
		8.5,
		0.06,
		world._materials["ceramic"],
		Vector3.ZERO,
		32
	)
	world._add_cylinder(
		"BossPlatformEnergyRing",
		Vector3(0.0, 0.53, -63.0),
		15.1,
		15.1,
		0.09,
		world._materials["cyan"],
		Vector3.ZERO,
		32
	)
	world._add_cylinder(
		"BossPlatformWarningRing",
		Vector3(0.0, 0.59, -63.0),
		18.2,
		18.2,
		0.08,
		world._materials["yellow"],
		Vector3.ZERO,
		32
	)
	for spoke in range(12):
		var angle := TAU * float(spoke) / 12.0
		var x := cos(angle) * 11.4
		var z := -63.0 + sin(angle) * 11.4
		world._add_box(
			"BossPlatformSpoke_%02d" % spoke,
			Vector3(x, 0.52, z),
			Vector3(5.0, 0.07, 0.24),
			world._materials["turquoise"],
			Vector3(0.0, -rad_to_deg(angle), 0.0)
		)
		var beacon_x := cos(angle) * 17.0
		var beacon_z := -63.0 + sin(angle) * 17.0
		world._add_sphere(
			"BossPlatformRingLight_%02d" % spoke,
			Vector3(beacon_x, 0.75, beacon_z),
			Vector3(0.35, 0.2, 0.35),
			world._materials["orange"] if spoke % 3 == 0 else world._materials["cyan"]
		)
	world._active_geometry_parent = null
	world._add_box(
		"BossRouteRamp",
		Vector3(0.0, 0.13, -41.0),
		Vector3(8.0, 0.06, 6.0),
		world._materials["silver"],
		Vector3(2.5, 0.0, 0.0),
		true
	)
	world._place_component(
		NeonFrontierScenes.BOSS_GATE_SCENE, "ColossalDockingGate", Vector3(0.0, 0.0, -83.0)
	)
	for side in [-1.0, 1.0]:
		world._add_box(
			"BossArenaSupportPillar",
			Vector3(side * 24.0, 8.0, -81.0),
			Vector3(3.0, 16.0, 5.0),
			world._materials["pearl"]
		)
		world._add_box(
			"BossArenaSupportConduit",
			Vector3(side * 21.8, 9.0, -64.0),
			Vector3(0.42, 0.42, 30.0),
			world._materials["copper"]
		)
		world._add_box(
			"BossArenaSupportConduitGlow",
			Vector3(side * 21.8, 9.27, -64.0),
			Vector3(0.12, 0.07, 28.0),
			world._materials["orange"]
		)


static func build_defense_perimeter(world) -> void:
	var turret_positions: Array[Vector3] = [
		Vector3(-78.0, 0.0, -47.0),
		Vector3(78.0, 0.0, -48.0),
		Vector3(-80.0, 0.0, 30.0),
		Vector3(80.0, 0.0, 31.0),
		Vector3(-42.0, 0.0, 62.0),
		Vector3(43.0, 0.0, 62.0),
	]
	for turret_index in range(turret_positions.size()):
		world._place_component(
			NeonFrontierScenes.TURRET_SCENE,
			"PerimeterDefenseTurret_%02d" % turret_index,
			turret_positions[turret_index],
			Vector3(0.0, float(turret_index) * 53.0, 0.0),
			Vector3(1.2, 1.2, 1.2)
		)

	var perimeter_gate_data := [
		{
			"name": "WestPerimeter",
			"position": Vector3(-83.0, 0.0, 1.0),
			"rotation": Vector3(0.0, 90.0, 0.0)
		},
		{
			"name": "EastPerimeter",
			"position": Vector3(83.0, 0.0, 1.0),
			"rotation": Vector3(0.0, -90.0, 0.0)
		},
		{
			"name": "SouthPerimeter",
			"position": Vector3(0.0, 0.0, 39.0),
			"rotation": Vector3(0.0, 180.0, 0.0)
		},
		{"name": "NorthPerimeter", "position": Vector3(0.0, 0.0, -59.0), "rotation": Vector3.ZERO},
	]
	for gate_data in perimeter_gate_data:
		world._place_component(
			NeonFrontierScenes.SPAWN_GATE_SCENE,
			str(gate_data.name),
			gate_data.position,
			gate_data.rotation,
			Vector3(1.45, 1.35, 1.2)
		)

	world._place_component(
		NeonFrontierScenes.SENSOR_SCENE,
		"EastPerimeterSensor",
		Vector3(79.0, 0.0, 6.0),
		Vector3(0.0, -15.0, 0.0),
		Vector3(0.9, 1.1, 0.9)
	)
	world._place_component(
		NeonFrontierScenes.SENSOR_SCENE,
		"NorthPerimeterSensor",
		Vector3(41.0, 0.0, -73.0),
		Vector3(0.0, 26.0, 0.0),
		Vector3(0.78, 0.9, 0.78)
	)

	# Perimeter walls are segmented around real vehicle/personnel gates so every district connects.
	for side in [-1.0, 1.0]:
		var wall_x: float = side * 83.0
		for segment_index in range(2):
			var z_start := -59.0 if segment_index == 0 else 7.0
			var z_end := -8.0 if segment_index == 0 else 39.0
			var segment_center := (z_start + z_end) * 0.5
			var segment_length := z_end - z_start
			world._add_box(
				"PerimeterDefenseWallSide_%s_%d" % [str(side), segment_index],
				Vector3(wall_x, 1.15, segment_center),
				Vector3(0.8, 2.3, segment_length),
				world._materials["pearl"],
				Vector3.ZERO,
				true
			)
			world._add_box(
				"PerimeterDefenseWallSideLight_%s_%d" % [str(side), segment_index],
				Vector3(wall_x - side * 0.48, 2.35, segment_center),
				Vector3(0.08, 0.08, segment_length - 2.0),
				world._materials["cyan"]
			)

	for side in [-1.0, 1.0]:
		var segment_center: float = side * 44.0
		world._add_box(
			"NorthPerimeterDefenseWall_%s" % str(side),
			Vector3(segment_center, 1.15, -59.0),
			Vector3(78.0, 2.3, 0.8),
			world._materials["pearl"],
			Vector3.ZERO,
			true
		)
		world._add_box(
			"NorthPerimeterWallLight_%s" % str(side),
			Vector3(segment_center, 2.35, -59.0),
			Vector3(76.0, 0.08, 0.08),
			world._materials["cyan"]
		)
		world._add_box(
			"SouthPerimeterDefenseWall_%s" % str(side),
			Vector3(segment_center, 1.15, 39.0),
			Vector3(78.0, 2.3, 0.8),
			world._materials["pearl"],
			Vector3.ZERO,
			true
		)
		world._add_box(
			"SouthPerimeterWallLight_%s" % str(side),
			Vector3(segment_center, 2.35, 39.0),
			Vector3(76.0, 0.08, 0.08),
			world._materials["cyan"]
		)

	world._place_component(
		NeonFrontierScenes.SENSOR_SCENE,
		"NorthwestRadarTower",
		Vector3(-73.0, 0.0, -66.0),
		Vector3.ZERO,
		Vector3(0.72, 0.75, 0.72)
	)
	world._place_component(
		NeonFrontierScenes.SENSOR_SCENE,
		"SoutheastRadarTower",
		Vector3(70.0, 0.0, 57.0),
		Vector3(0.0, 70.0, 0.0),
		Vector3(0.82, 0.85, 0.82)
	)
	world._add_box(
		"PerimeterRelayArray",
		Vector3(0.0, 5.4, 40.0),
		Vector3(20.0, 0.6, 1.2),
		world._materials["silver"]
	)
	for mast_index in range(7):
		var x := -9.0 + float(mast_index) * 3.0
		world._add_box(
			"RelayArrayMast_%02d" % mast_index,
			Vector3(x, 7.8, 40.0),
			Vector3(0.16, 5.2, 0.16),
			world._materials["blue"]
		)
		world._add_sphere(
			"RelayArrayTip_%02d" % mast_index,
			Vector3(x, 10.5, 40.0),
			Vector3(0.28, 0.38, 0.28),
			world._materials["turquoise"]
		)
