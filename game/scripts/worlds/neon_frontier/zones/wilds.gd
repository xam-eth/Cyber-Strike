## The destroyed sector and the alien landscape.
##
## Split out of neon_frontier_world.gd, which is the composition root for the
## whole world and had grown one district at a time into 1,555 lines. These two
## are the wilds: the wrecked frontier sector and the alien cliffs, crystals and
## flora. They share no structure with the built districts, so they are the
## first group to get a file of their own.
##
## Each builder takes the world node and reaches through it for the palette
## (`world._materials`), the shape helpers (`world._add_box` and friends), and
## `_place_component`, which instantiates a component scene.
class_name NeonFrontierWilds
extends RefCounted


static func build_destroyed_frontier_sector(world) -> void:
	world._place_component(
		NeonFrontierScenes.TRANSPORT_SCENE,
		"CrashedFrontierTransport",
		Vector3(-48.0, 0.0, 46.0),
		Vector3(0.0, 33.0, 0.0),
		Vector3(1.2, 1.0, 1.1)
	)
	world._place_component(
		NeonFrontierScenes.DRONE_WRECK_SCENE,
		"AlienDroneWreck",
		Vector3(-28.0, 0.0, 47.0),
		Vector3(0.0, -18.0, 0.0),
		Vector3(1.2, 1.0, 1.1)
	)
	world._place_component(
		NeonFrontierScenes.TURRET_SCENE,
		"DisabledCheckpointTurret",
		Vector3(-64.0, 0.0, 47.0),
		Vector3(0.0, 42.0, 72.0),
		Vector3(0.9, 0.72, 0.9)
	)
	world._place_component(
		NeonFrontierScenes.DEPOT_SCENE,
		"AbandonedLoadingModule",
		Vector3(-34.0, 0.0, 64.0),
		Vector3(0.0, -14.0, 0.0),
		Vector3(0.82, 0.8, 0.82)
	)
	world._add_box(
		"CrackedSectorPavement",
		Vector3(-47.0, 0.11, 47.0),
		Vector3(37.0, 0.2, 26.0),
		world._materials["ground_rose"],
		Vector3(0.0, 12.0, 0.0)
	)
	for crack_index in range(8):
		var x := -64.0 + float(crack_index) * 4.6
		var z := 36.0 + float(crack_index % 3) * 7.0
		world._add_box(
			"FracturedMetalPlate_%02d" % crack_index,
			Vector3(x, 0.27, z),
			Vector3(3.2, 0.12, 2.8),
			world._materials["silver"],
			Vector3(0.0, float(crack_index) * 17.0, float(crack_index % 2) * 11.0)
		)
		world._add_box(
			"FractureWarningEdge_%02d" % crack_index,
			Vector3(x, 0.35, z + 1.4),
			Vector3(2.2, 0.035, 0.09),
			world._materials["orange"],
			Vector3(0.0, float(crack_index) * 17.0, 0.0)
		)
	for debris_index in range(12):
		var x := -67.0 + float((debris_index * 7) % 34)
		var z := 34.0 + float((debris_index * 11) % 35)
		world._add_box(
			"SectorMachineDebris_%02d" % debris_index,
			Vector3(x, 0.28, z),
			Vector3(1.8 + float(debris_index % 3) * 0.4, 0.5, 1.2),
			world._materials["dark_trim"],
			Vector3(0.0, float(debris_index) * 29.0, float(debris_index % 4) * 8.0)
		)
	world._add_box(
		"DisabledSecurityCheckpoint",
		Vector3(-72.0, 1.0, 46.0),
		Vector3(4.0, 2.0, 12.0),
		world._materials["blue"],
		Vector3(0.0, 6.0, 0.0),
		true
	)
	world._add_box(
		"CheckpointBrokenWindow",
		Vector3(-69.8, 1.55, 44.0),
		Vector3(0.08, 0.75, 5.0),
		world._materials["orange"],
		Vector3(16.0, 0.0, 10.0)
	)
	world._add_box(
		"DisabledTurretWarning",
		Vector3(-64.0, 2.9, 47.0),
		Vector3(0.12, 0.12, 1.1),
		world._materials["red"]
	)
	world._add_box(
		"BrokenCableRun",
		Vector3(-42.0, 0.68, 60.0),
		Vector3(12.0, 0.16, 0.15),
		world._materials["dark_trim"],
		Vector3(0.0, 18.0, 12.0)
	)
	for spark_index in range(6):
		var x := -47.0 + float(spark_index) * 1.4
		world._add_sphere(
			"ControlledCableSpark_%02d" % spark_index,
			Vector3(x, 0.95 + float(spark_index % 2) * 0.6, 59.0),
			Vector3(0.15, 0.18, 0.15),
			world._materials["orange"]
		)
	world._add_box(
		"SealedDeepFacilityGate",
		Vector3(-22.0, 5.6, 72.0),
		Vector3(18.0, 11.2, 1.5),
		world._materials["blue"],
		Vector3.ZERO,
		true
	)
	for slat_index in range(6):
		world._add_box(
			"DeepGateLockingSlat_%02d" % slat_index,
			Vector3(-29.0 + float(slat_index) * 2.8, 5.7, 72.9),
			Vector3(0.2, 9.2, 0.24),
			world._materials["pearl"]
		)
	world._add_box(
		"DeepGateSealedStatus",
		Vector3(-22.0, 10.3, 73.1),
		Vector3(5.0, 0.18, 0.12),
		world._materials["red"]
	)


static func build_alien_landscape(world) -> void:
	var rock_positions: Array[Vector3] = [
		Vector3(-88.0, 0.0, -88.0),
		Vector3(-68.0, 0.0, -91.0),
		Vector3(-43.0, 0.0, -90.0),
		Vector3(-17.0, 0.0, -92.0),
		Vector3(18.0, 0.0, -92.0),
		Vector3(46.0, 0.0, -90.0),
		Vector3(72.0, 0.0, -87.0),
		Vector3(89.0, 0.0, -68.0),
		Vector3(91.0, 0.0, -39.0),
		Vector3(90.0, 0.0, -5.0),
		Vector3(90.0, 0.0, 28.0),
		Vector3(88.0, 0.0, 60.0),
		Vector3(62.0, 0.0, 72.0),
		Vector3(34.0, 0.0, 73.0),
		Vector3(5.0, 0.0, 74.0),
		Vector3(-26.0, 0.0, 73.0),
		Vector3(-55.0, 0.0, 71.0),
		Vector3(-83.0, 0.0, 66.0),
		Vector3(-91.0, 0.0, 43.0),
		Vector3(-91.0, 0.0, 11.0),
		Vector3(-91.0, 0.0, -22.0),
	]
	for rock_index in range(rock_positions.size()):
		var rock_position: Vector3 = rock_positions[rock_index]
		var key := "wall_cube" if rock_index % 3 == 0 else "column"
		NeonFrontierScenes.ScifiBayBuilder.place(
			world,
			key,
			"SciFiFrontierRuin_%02d" % rock_index,
			rock_position,
			float(rock_index * 29),
			1.65,
			true,
			true
		)

	var crystal_positions: Array[Vector3] = [
		Vector3(-80.0, 0.0, -58.0),
		Vector3(-78.0, 0.0, -8.0),
		Vector3(-75.0, 0.0, 48.0),
		Vector3(-57.0, 0.0, -70.0),
		Vector3(-58.0, 0.0, 65.0),
		Vector3(78.0, 0.0, -68.0),
		Vector3(77.0, 0.0, -20.0),
		Vector3(79.0, 0.0, 43.0),
		Vector3(57.0, 0.0, 70.0),
		Vector3(18.0, 0.0, 61.0),
		Vector3(-4.0, 0.0, 67.0),
		Vector3(57.0, 0.0, 16.0),
	]
	for crystal_index in range(crystal_positions.size()):
		world._place_component(
			NeonFrontierScenes.CRYSTAL_SCENE,
			"FrontierCrystalCluster_%02d" % crystal_index,
			crystal_positions[crystal_index],
			Vector3(0.0, crystal_index * 41.0, 0.0),
			Vector3.ONE,
			crystal_index
		)

	var flora_positions: Array[Vector3] = [
		Vector3(-70.0, 0.0, -47.0),
		Vector3(-62.0, 0.0, -12.0),
		Vector3(-73.0, 0.0, 12.0),
		Vector3(-65.0, 0.0, 58.0),
		Vector3(-36.0, 0.0, 68.0),
		Vector3(-8.0, 0.0, 59.0),
		Vector3(15.0, 0.0, 66.0),
		Vector3(38.0, 0.0, 60.0),
		Vector3(66.0, 0.0, 58.0),
		Vector3(69.0, 0.0, 29.0),
		Vector3(72.0, 0.0, 5.0),
		Vector3(72.0, 0.0, -60.0),
		Vector3(57.0, 0.0, -66.0),
		Vector3(6.0, 0.0, -77.0),
		Vector3(-38.0, 0.0, -68.0),
		Vector3(31.0, 0.0, 19.0),
		Vector3(-28.0, 0.0, 35.0),
		Vector3(17.0, 0.0, 43.0),
	]
	for flora_index in range(flora_positions.size()):
		world._place_component(
			NeonFrontierScenes.FLORA_SCENE,
			"LuminousAlienFlora_%02d" % flora_index,
			flora_positions[flora_index],
			Vector3(0.0, flora_index * 23.0, 0.0),
			Vector3.ONE,
			flora_index + 9
		)

	# Resource alcoves sit just off the main routes, leaving combat and movement lanes open.
	for pickup_index in range(6):
		var x := -67.0 + float(pickup_index % 3) * 4.2
		var z := -49.0 + float(pickup_index / 3) * 5.0
		world._add_cylinder(
			"FrontierResourceCanister_%02d" % pickup_index,
			Vector3(x, 0.72, z),
			0.48,
			0.38,
			1.4,
			world._materials["blue"],
			Vector3(0.0, float(pickup_index) * 27.0, 0.0),
			16
		)
		world._add_cylinder(
			"ResourceCanisterCore_%02d" % pickup_index,
			Vector3(x, 0.74, z),
			0.23,
			0.23,
			1.1,
			world._materials["green"],
			Vector3.ZERO,
			12
		)
		world._add_box(
			"ResourceCanisterBand_%02d" % pickup_index,
			Vector3(x, 1.1, z + 0.4),
			Vector3(0.62, 0.12, 0.08),
			world._materials["yellow"]
		)
