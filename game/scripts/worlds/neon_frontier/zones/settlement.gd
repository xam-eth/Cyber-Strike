## The outpost and the extraction zone: the two built districts the player
## fights through rather than around.

## Split out of neon_frontier_world.gd, the composition root, which had grown one
## district at a time into 1,555 lines. Same contract as the other zone files:
## each builder takes the world node and reaches through it for the palette, the
## shape helpers and `_place_component`.
class_name NeonFrontierSettlement
extends RefCounted


static func build_outpost(world) -> void:
	world._place_component(
		NeonFrontierScenes.COMMAND_SCENE,
		"OutpostCommandCenter",
		Vector3(-52.0, 0.0, -4.0),
		Vector3(0.0, 90.0, 0.0)
	)
	world._place_component(
		NeonFrontierScenes.LAB_SCENE,
		"WeaponResearchLaboratory",
		Vector3(-47.0, 0.0, -28.0),
		Vector3(0.0, 90.0, 0.0)
	)
	world._place_component(
		NeonFrontierScenes.DEPOT_SCENE,
		"FieldEquipmentDepot",
		Vector3(-49.0, 0.0, 19.0),
		Vector3(0.0, -90.0, 0.0)
	)
	world._place_component(
		NeonFrontierScenes.SENSOR_SCENE,
		"WestObservationTower",
		Vector3(-72.0, 0.0, -22.0),
		Vector3(0.0, 18.0, 0.0),
		Vector3(0.9, 1.0, 0.9)
	)
	world._place_component(
		NeonFrontierScenes.SENSOR_SCENE,
		"SouthwestSignalTower",
		Vector3(-69.0, 0.0, 31.0),
		Vector3(0.0, -14.0, 0.0),
		Vector3(0.82, 0.88, 0.82)
	)
	world._place_component(
		NeonFrontierScenes.LANDING_PAD_SCENE,
		"EastVehicleLandingPlatform",
		Vector3(52.0, 0.0, 5.0),
		Vector3(0.0, -12.0, 0.0),
		Vector3(1.0, 0.28, 1.0)
	)
	world._add_box(
		"LandingPadAccessRamp",
		Vector3(31.75, 0.0685, 5.0),
		Vector3(9.5, 0.06, 4.0),
		world._materials["silver"],
		Vector3(0.0, 0.0, 1.19),
		true
	)
	world._add_box(
		"LandingPadRampGuide",
		Vector3(31.75, 0.13, 3.1),
		Vector3(8.5, 0.035, 0.08),
		world._materials["yellow"],
		Vector3(0.0, 0.0, 1.19)
	)

	world._add_box(
		"CommandToLabAccess",
		Vector3(-48.5, 0.06, -17.0),
		Vector3(7.0, 0.12, 9.0),
		world._materials["ceramic"]
	)
	world._add_box(
		"CommandToDepotAccess",
		Vector3(-48.5, 0.06, 9.0),
		Vector3(7.0, 0.12, 10.0),
		world._materials["ceramic"]
	)
	world._add_box(
		"OutpostVehicleApron",
		Vector3(-67.0, 0.07, 2.0),
		Vector3(14.0, 0.14, 42.0),
		world._materials["silver"]
	)
	world._add_box(
		"OutpostApronStripe",
		Vector3(-67.0, 0.16, 2.0),
		Vector3(0.18, 0.04, 40.0),
		world._materials["yellow"]
	)
	NeonFrontierScenes.ScifiBayBuilder.place(
		world,
		"console_large",
		"SciFiOutpostServiceBay",
		Vector3(-67.0, 0.0, -8.0),
		90.0,
		1.4,
		true,
		true
	)
	for crate_index in range(6):
		var x := -37.0 + float(crate_index % 3) * 2.2
		var z := 14.0 + float(crate_index / 3) * 2.0
		NeonFrontierScenes.ScifiBayBuilder.place(
			world,
			"crate",
			"SciFiOutpostSupply_%02d" % crate_index,
			Vector3(x, 0.0, z),
			float(crate_index % 4) * 90.0,
			1.2,
			false,
			true
		)

	for side in [-1.0, 1.0]:
		world._add_box(
			"OutpostPerimeterWall_%s" % str(side),
			Vector3(-60.0 + side * 17.0, 1.1, -3.0),
			Vector3(1.0, 2.2, 30.0),
			world._materials["blue"]
		)
		world._add_box(
			"OutpostWallLight_%s" % str(side),
			Vector3(-60.0 + side * 17.0, 2.3, -3.0),
			Vector3(0.1, 0.08, 28.0),
			world._materials["cyan"]
		)
	world._add_box(
		"OutpostDamagedWall",
		Vector3(-60.0, 0.95, 23.0),
		Vector3(25.0, 1.9, 0.9),
		world._materials["ceramic"],
		Vector3(0.0, 0.0, -4.0),
		true
	)
	world._add_box(
		"OutpostWallImpactScar",
		Vector3(-53.0, 1.65, 23.5),
		Vector3(4.8, 0.16, 0.15),
		world._materials["orange"],
		Vector3(0.0, 0.0, 22.0)
	)


static func build_extraction_zone(world) -> void:
	world._place_component(
		NeonFrontierScenes.GENERATOR_SCENE,
		"FrontierEnergyExtractionBank",
		Vector3(43.0, 0.0, -35.0),
		Vector3(0.0, 180.0, 0.0)
	)
	NeonFrontierScenes.ScifiBayBuilder.place(
		world,
		"wall_pipes",
		"SciFiExtractionPipeArray",
		Vector3(61.0, 0.0, -31.5),
		18.0,
		2.0,
		true,
		true
	)
	NeonFrontierScenes.ScifiBayBuilder.place(
		world,
		"console_large",
		"SciFiExtractionController",
		Vector3(64.0, 0.0, -35.5),
		108.0,
		1.35,
		true,
		true
	)
	world._place_component(
		NeonFrontierScenes.SENSOR_SCENE,
		"ExtractionSensorMast",
		Vector3(66.0, 0.0, -43.0),
		Vector3(0.0, 42.0, 0.0),
		Vector3(0.72, 0.8, 0.72)
	)
	for pipe_index in range(5):
		var z := -48.0 + float(pipe_index) * 6.0
		world._add_box(
			"ExtractionGroundPipe_%02d" % pipe_index,
			Vector3(34.0, 0.62, z),
			Vector3(25.0, 0.45, 0.42),
			world._materials["copper"]
		)
		world._add_box(
			"ExtractionPipeGlow_%02d" % pipe_index,
			Vector3(34.0, 0.87, z),
			Vector3(24.0, 0.07, 0.11),
			world._materials["turquoise"] if pipe_index % 2 == 0 else world._materials["green"]
		)
	for support_index in range(4):
		var x := 26.0 + float(support_index) * 5.5
		world._add_box(
			"ExtractionPipeSupport_%02d" % support_index,
			Vector3(x, 0.55, -35.0),
			Vector3(0.4, 1.1, 14.0),
			world._materials["blue"]
		)
	world._add_box(
		"ExtractionMaintenanceWalk",
		Vector3(51.0, 1.25, -27.0),
		Vector3(14.0, 0.32, 1.4),
		world._materials["yellow"]
	)
	for side in [-1.0, 1.0]:
		world._add_box(
			"ExtractionWalkRail",
			Vector3(51.0, 2.0, -27.0 + side * 0.65),
			Vector3(14.0, 1.2, 0.12),
			world._materials["silver"]
		)
	world._add_box(
		"ExtractionContainmentApron",
		Vector3(56.0, 0.08, -38.0),
		Vector3(22.0, 0.16, 26.0),
		world._materials["ceramic"]
	)
	world._add_box(
		"ExtractionHazardLine",
		Vector3(56.0, 0.18, -25.3),
		Vector3(21.0, 0.05, 0.22),
		world._materials["orange"]
	)
