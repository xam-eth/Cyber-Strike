## The central arena: the combat floor, its hazard markings and its spawn gates.
## The one place every route leads to and every wave is fought in.

## Split out of neon_frontier_world.gd, the composition root. Same contract as the
## other zone files: static builders that take the world node.
class_name NeonFrontierArena
extends RefCounted


static func build_central_arena(world) -> void:
	world._add_box(
		"CentralArenaSubstructure",
		Vector3(0.0, -0.25, 0.0),
		Vector3(42.0, 0.5, 42.0),
		world._materials["silver"]
	)
	world._add_box(
		"CentralArenaOuterBand",
		Vector3(0.0, 0.025, 0.0),
		Vector3(40.0, 0.05, 40.0),
		world._materials["blue"]
	)
	world._add_box(
		"CentralArenaDeck",
		Vector3(0.0, 0.03, 0.0),
		Vector3(38.0, 0.02, 38.0),
		world._materials["pearl"]
	)
	world._add_box(
		"CentralArenaInnerDeck",
		Vector3(0.0, 0.047, 0.0),
		Vector3(33.6, 0.014, 33.6),
		world._materials["ceramic"]
	)

	for tile_x in range(7):
		for tile_z in range(7):
			var x := -18.0 + float(tile_x) * 6.0
			var z := -18.0 + float(tile_z) * 6.0
			var material: Material = (
				world._materials["silver"]
				if (tile_x + tile_z) % 2 == 0
				else world._materials["ceramic"]
			)
			world._add_box(
				"ArenaPanel_%02d_%02d" % [tile_x, tile_z],
				Vector3(x, 0.061, z),
				Vector3(5.7, 0.02, 5.7),
				material
			)
			world._add_box(
				"ArenaPanelSeamX_%02d_%02d" % [tile_x, tile_z],
				Vector3(x, 0.075, z - 2.78),
				Vector3(5.42, 0.008, 0.035),
				world._materials["dark_trim"]
			)
			if (tile_x + tile_z) % 3 == 0:
				for bolt_x in [-2.48, 2.48]:
					for bolt_z in [-2.48, 2.48]:
						world._add_cylinder(
							"ArenaPanelFastener",
							Vector3(x + bolt_x, 0.086, z + bolt_z),
							0.045,
							0.045,
							0.028,
							world._materials["dark_trim"],
							Vector3.ZERO,
							8
						)

	world._add_box(
		"ArenaEnergyChannelNorth",
		Vector3(0.0, 0.09, -14.2),
		Vector3(0.46, 0.05, 7.3),
		world._materials["cyan"]
	)
	world._add_box(
		"ArenaEnergyChannelSouth",
		Vector3(0.0, 0.09, 14.2),
		Vector3(0.46, 0.05, 7.3),
		world._materials["cyan"]
	)
	world._add_box(
		"ArenaEnergyChannelEast",
		Vector3(14.2, 0.09, 0.0),
		Vector3(7.3, 0.05, 0.46),
		world._materials["cyan"]
	)
	world._add_box(
		"ArenaEnergyChannelWest",
		Vector3(-14.2, 0.09, 0.0),
		Vector3(7.3, 0.05, 0.46),
		world._materials["cyan"]
	)
	world._add_box(
		"ArenaCrossChannelX",
		Vector3(0.0, 0.08, 0.0),
		Vector3(31.0, 0.035, 0.18),
		world._materials["turquoise"]
	)
	world._add_box(
		"ArenaCrossChannelZ",
		Vector3(0.0, 0.08, 0.0),
		Vector3(0.18, 0.035, 31.0),
		world._materials["turquoise"]
	)

	for side in [-1.0, 1.0]:
		world._add_box(
			"ArenaOrangeConduitX_%s" % str(side),
			Vector3(side * 8.0, 0.08, 0.0),
			Vector3(0.48, 0.16, 18.0),
			world._materials["copper"]
		)
		world._add_box(
			"ArenaOrangeConduitGlowX_%s" % str(side),
			Vector3(side * 8.0, 0.13, 0.0),
			Vector3(0.12, 0.04, 17.0),
			world._materials["orange"]
		)
		world._add_box(
			"ArenaOrangeConduitZ_%s" % str(side),
			Vector3(0.0, 0.08, side * 8.0),
			Vector3(18.0, 0.16, 0.48),
			world._materials["copper"]
		)
		world._add_box(
			"ArenaOrangeConduitGlowZ_%s" % str(side),
			Vector3(0.0, 0.13, side * 8.0),
			Vector3(17.0, 0.04, 0.12),
			world._materials["orange"]
		)

	add_arena_hazard_markings(world)
	world._place_component(
		NeonFrontierScenes.REACTOR_SCENE, "CentralReactor", Vector3(0.0, 0.0, 0.0)
	)
	add_arena_spawn_gates(world)
	world._place_component(
		NeonFrontierScenes.COVER_SCENE,
		"CoverWest",
		Vector3(-10.0, 0.0, 1.5),
		Vector3(0.0, 0.0, -8.0)
	)
	world._place_component(
		NeonFrontierScenes.COVER_SCENE,
		"CoverEast",
		Vector3(4.0, 0.0, -3.0),
		Vector3(0.0, 90.0, 0.0)
	)
	world._place_component(
		NeonFrontierScenes.COVER_SCENE,
		"CoverNorthWest",
		Vector3(-7.0, 0.0, -11.0),
		Vector3(0.0, 22.0, 0.0),
		Vector3(0.8, 0.8, 0.8)
	)
	world._place_component(
		NeonFrontierScenes.COVER_SCENE,
		"CoverSouthEast",
		Vector3(8.0, 0.0, 9.0),
		Vector3(0.0, -16.0, 0.0),
		Vector3(0.75, 0.75, 0.75)
	)

	# Retained service deck and low ramp remain traversable for the existing combat blockout.
	world._add_box(
		"ServiceDeck",
		Vector3(11.3, 0.25, 5.5),
		Vector3(3.0, 0.5, 3.0),
		world._materials["blue"],
		Vector3.ZERO,
		true
	)
	world._add_box(
		"ServiceDeckTop",
		Vector3(11.3, 0.53, 5.5),
		Vector3(2.7, 0.08, 2.7),
		world._materials["pearl"]
	)
	world._add_box(
		"ServiceRamp",
		Vector3(8.1, 0.25, 5.5),
		Vector3(3.4, 0.16, 2.4),
		world._materials["silver"],
		Vector3(0.0, 0.0, 8.5),
		true
	)
	world._add_box(
		"ServiceRampStripe",
		Vector3(8.1, 0.36, 5.5),
		Vector3(2.5, 0.035, 0.07),
		world._materials["yellow"],
		Vector3(0.0, 0.0, 8.5)
	)
	world._add_box(
		"ServiceDeckStripe",
		Vector3(11.3, 0.59, 5.5),
		Vector3(2.0, 0.035, 0.08),
		world._materials["orange"]
	)

	world._add_box(
		"SouthLaneMarking",
		Vector3(0.0, 0.09, 17.5),
		Vector3(0.14, 0.04, 4.0),
		world._materials["cyan"]
	)
	world._add_box(
		"NorthLaneMarking",
		Vector3(0.0, 0.09, -17.5),
		Vector3(0.14, 0.04, 4.0),
		world._materials["cyan"]
	)
	world._add_box(
		"WestLaneMarking",
		Vector3(-17.5, 0.09, 0.0),
		Vector3(4.0, 0.04, 0.14),
		world._materials["cyan"]
	)
	world._add_box(
		"EastLaneMarking",
		Vector3(17.5, 0.09, 0.0),
		Vector3(4.0, 0.04, 0.14),
		world._materials["cyan"]
	)


static func add_arena_hazard_markings(world) -> void:
	for stripe in range(18):
		var x := -18.0 + float(stripe) * 2.12
		var material: Material = (
			world._materials["yellow"] if stripe % 2 == 0 else world._materials["dark_trim"]
		)
		world._add_box(
			"ArenaEdgeStripeNorth_%02d" % stripe,
			Vector3(x, 0.09, -19.1),
			Vector3(1.0, 0.06, 0.42),
			material
		)
		world._add_box(
			"ArenaEdgeStripeSouth_%02d" % stripe,
			Vector3(x, 0.09, 19.1),
			Vector3(1.0, 0.06, 0.42),
			material
		)
		var z := -18.0 + float(stripe) * 2.12
		world._add_box(
			"ArenaEdgeStripeEast_%02d" % stripe,
			Vector3(19.1, 0.09, z),
			Vector3(0.42, 0.06, 1.0),
			material
		)
		world._add_box(
			"ArenaEdgeStripeWest_%02d" % stripe,
			Vector3(-19.1, 0.09, z),
			Vector3(0.42, 0.06, 1.0),
			material
		)
	for corner_x in [-17.0, 17.0]:
		for corner_z in [-17.0, 17.0]:
			world._add_box(
				"ArenaCornerWarningPanel",
				Vector3(corner_x, 0.11, corner_z),
				Vector3(1.1, 0.07, 1.1),
				world._materials["orange"]
			)


static func add_arena_spawn_gates(world) -> void:
	var gates := [
		{"name": "North", "position": Vector3(0.0, 0.0, -18.2), "rotation": Vector3.ZERO},
		{
			"name": "South",
			"position": Vector3(0.0, 0.0, 18.2),
			"rotation": Vector3(0.0, 180.0, 0.0)
		},
		{"name": "West", "position": Vector3(-18.2, 0.0, 0.0), "rotation": Vector3(0.0, 90.0, 0.0)},
		{"name": "East", "position": Vector3(18.2, 0.0, 0.0), "rotation": Vector3(0.0, -90.0, 0.0)},
	]
	for gate_data in gates:
		world._place_component(
			NeonFrontierScenes.SPAWN_GATE_SCENE,
			"WaveEntry_%s" % gate_data.name,
			gate_data.position,
			gate_data.rotation
		)
