## The ground-level routes that connect the districts, so a player can walk from
## the arena to any zone without loading anything.

## Split out of neon_frontier_world.gd, the composition root.
class_name NeonFrontierRoutes
extends RefCounted


static func build_access_routes(world) -> void:
	# Bright modular road plates physically join every playable district to the arena.
	world._add_box(
		"WestRouteLeg",
		Vector3(-29.0, 0.015, 0.0),
		Vector3(22.0, 0.03, 8.0),
		world._materials["silver"]
	)
	world._add_box(
		"WestRouteNorthLeg",
		Vector3(-38.0, 0.015, -14.0),
		Vector3(8.0, 0.03, 28.0),
		world._materials["silver"]
	)
	world._add_box(
		"WestRouteSignal",
		Vector3(-29.0, 0.05, 0.0),
		Vector3(19.0, 0.045, 0.24),
		world._materials["cyan"]
	)
	world._add_box(
		"WestRouteSignalNorth",
		Vector3(-38.0, 0.05, -14.0),
		Vector3(0.24, 0.045, 25.0),
		world._materials["turquoise"]
	)
	world._add_box(
		"WestRouteEdgeYellow",
		Vector3(-29.0, 0.05, -3.75),
		Vector3(20.0, 0.035, 0.12),
		world._materials["yellow"]
	)
	world._add_box(
		"WestRouteEdgeYellowSouth",
		Vector3(-29.0, 0.05, 3.75),
		Vector3(20.0, 0.035, 0.12),
		world._materials["yellow"]
	)

	world._add_box(
		"EastRouteLeg",
		Vector3(30.0, 0.015, 1.0),
		Vector3(22.0, 0.03, 8.0),
		world._materials["silver"]
	)
	world._add_box(
		"EastRouteSignal",
		Vector3(30.0, 0.05, 1.0),
		Vector3(20.0, 0.02, 0.22),
		world._materials["cyan"]
	)
	world._add_box(
		"EastRouteEdgeNorth",
		Vector3(30.0, 0.05, -2.75),
		Vector3(21.0, 0.02, 0.12),
		world._materials["yellow"]
	)
	world._add_box(
		"EastRouteEdgeSouth",
		Vector3(30.0, 0.05, 4.75),
		Vector3(21.0, 0.02, 0.12),
		world._materials["yellow"]
	)

	world._add_box(
		"NorthRouteLeg",
		Vector3(0.0, 0.015, -31.0),
		Vector3(8.0, 0.03, 24.0),
		world._materials["silver"]
	)
	world._add_box(
		"NorthRouteCauseway",
		Vector3(0.0, 0.025, -51.0),
		Vector3(10.0, 0.05, 18.0),
		world._materials["blue"]
	)
	world._add_box(
		"NorthRouteSignal",
		Vector3(0.0, 0.06, -42.0),
		Vector3(0.22, 0.04, 36.0),
		world._materials["cyan"]
	)
	for side in [-1.0, 1.0]:
		world._add_box(
			"NorthRouteSafetyRail",
			Vector3(side * 4.65, 0.77, -50.5),
			Vector3(0.18, 1.3, 18.0),
			world._materials["pearl"]
		)
		world._add_box(
			"NorthRouteRailLight",
			Vector3(side * 4.52, 0.89, -50.5),
			Vector3(0.06, 0.08, 17.0),
			world._materials["turquoise"]
		)
	world._add_box(
		"BossRouteLanding",
		Vector3(0.0, 0.025, -62.0),
		Vector3(19.0, 0.05, 12.0),
		world._materials["silver"]
	)

	world._add_box(
		"SouthRouteLeg",
		Vector3(0.0, 0.015, 28.0),
		Vector3(8.0, 0.03, 16.0),
		world._materials["ceramic"]
	)
	world._add_box(
		"SouthRouteSignal",
		Vector3(0.0, 0.05, 28.0),
		Vector3(0.22, 0.04, 14.0),
		world._materials["cyan"]
	)
	world._add_box(
		"SouthPerimeterGateApproach",
		Vector3(0.0, 0.015, 38.0),
		Vector3(8.0, 0.03, 10.0),
		world._materials["silver"]
	)
	world._add_box(
		"SouthResourceRouteTurn",
		Vector3(-14.0, 0.015, 43.0),
		Vector3(28.0, 0.03, 8.0),
		world._materials["silver"]
	)
	world._add_box(
		"SouthResourceRouteLeg",
		Vector3(-28.0, 0.015, 55.0),
		Vector3(8.0, 0.03, 24.0),
		world._materials["ceramic"]
	)
	world._add_box(
		"SouthWreckApproach",
		Vector3(-39.0, 0.015, 46.0),
		Vector3(22.0, 0.03, 8.0),
		world._materials["silver"]
	)
	world._add_box(
		"SouthResourceRouteSignal",
		Vector3(-14.0, 0.05, 43.0),
		Vector3(25.0, 0.035, 0.16),
		world._materials["turquoise"]
	)
	world._add_box(
		"SouthResourceRouteSignalLeg",
		Vector3(-28.0, 0.05, 55.0),
		Vector3(0.16, 0.035, 21.0),
		world._materials["cyan"]
	)

	# Conduits visibly carry energy between the reactor and the extraction complex.
	world._add_box(
		"MainEnergyConduitWest",
		Vector3(-25.0, 0.72, -2.0),
		Vector3(24.0, 0.38, 0.42),
		world._materials["copper"]
	)
	world._add_box(
		"MainEnergyConduitWestGlow",
		Vector3(-25.0, 0.94, -2.0),
		Vector3(23.0, 0.08, 0.14),
		world._materials["orange"]
	)
	world._add_box(
		"MainEnergyConduitNorth",
		Vector3(20.0, 0.72, -26.0),
		Vector3(0.42, 0.38, 50.0),
		world._materials["copper"]
	)
	world._add_box(
		"MainEnergyConduitNorthGlow",
		Vector3(20.0, 0.94, -26.0),
		Vector3(0.14, 0.08, 49.0),
		world._materials["turquoise"]
	)
	world._add_box(
		"MainEnergyConduitEast",
		Vector3(31.0, 0.72, -33.0),
		Vector3(22.0, 0.38, 0.42),
		world._materials["copper"]
	)
	world._add_box(
		"MainEnergyConduitEastGlow",
		Vector3(31.0, 0.94, -33.0),
		Vector3(21.0, 0.08, 0.14),
		world._materials["green"]
	)
	for x in [-35.0, -15.0, 20.0, 41.0]:
		var z := -2.0 if x < 0.0 else -33.0
		world._add_box(
			"EnergyPipeSupport",
			Vector3(x, 0.53, z),
			Vector3(0.34, 1.0, 0.34),
			world._materials["blue"]
		)
