@tool
extends Node3D

const GltfAssetLibrary = preload("res://scripts/worlds/gltf_asset_library.gd")
const KayKitBaseBuilder = preload("res://scripts/worlds/kaykit_base_builder.gd")
const ScifiBayBuilder = preload("res://scripts/worlds/scifi_bay_builder.gd")
const REACTOR_SCENE: PackedScene = preload("res://scenes/worlds/components/reactor_core.tscn")
const COMMAND_SCENE: PackedScene = preload("res://scenes/worlds/components/command_center.tscn")
const LAB_SCENE: PackedScene = preload("res://scenes/worlds/components/research_lab.tscn")
const DEPOT_SCENE: PackedScene = preload("res://scenes/worlds/components/equipment_depot.tscn")
const GENERATOR_SCENE: PackedScene = preload("res://scenes/worlds/components/generator_bank.tscn")
const BOSS_GATE_SCENE: PackedScene = preload("res://scenes/worlds/components/boss_gate.tscn")
const TURRET_SCENE: PackedScene = preload("res://scenes/worlds/components/defense_turret.tscn")
const SENSOR_SCENE: PackedScene = preload("res://scenes/worlds/components/sensor_tower.tscn")
const LANDING_PAD_SCENE: PackedScene = preload("res://scenes/worlds/components/landing_pad.tscn")
const TRANSPORT_SCENE: PackedScene = preload(
	"res://scenes/worlds/components/wrecked_transport.tscn"
)
const DRONE_WRECK_SCENE: PackedScene = preload(
	"res://scenes/worlds/components/alien_drone_wreck.tscn"
)
const CRYSTAL_SCENE: PackedScene = preload("res://scenes/worlds/components/crystal_cluster.tscn")
const FLORA_SCENE: PackedScene = preload("res://scenes/worlds/components/alien_flora.tscn")
const ROCK_SCENE: PackedScene = preload("res://scenes/worlds/components/rock_cluster.tscn")
const SPAWN_GATE_SCENE: PackedScene = preload(
	"res://scenes/worlds/components/enemy_spawn_gate.tscn"
)
const COVER_SCENE: PackedScene = preload("res://scenes/worlds/components/cover_module.tscn")

const WORLD_WIDTH: float = 192.0
const WORLD_DEPTH: float = 180.0
const WORLD_CENTER_Z: float = -10.0

var _materials: Dictionary = {}
var _active_geometry_parent: Node3D
var _built: bool = false


func _ready() -> void:
	if _built or get_node_or_null("ArenaFloor") != null:
		return
	_built = true
	_create_materials()
	_build_terrain_and_floor()
	_build_central_arena()
	_build_access_routes()
	_build_outpost()
	_build_extraction_zone()
	_build_boss_encounter_zone()
	_build_defense_perimeter()
	_build_destroyed_frontier_sector()
	_build_alien_landscape()
	_build_lighting_and_atmosphere()
	_build_spawn_beacons()
	KayKitBaseBuilder.dress_districts(self)
	ScifiBayBuilder.build(self)


func _create_materials() -> void:
	_materials = {
		"ground": _make_material(Color(0.72, 0.56, 0.39), 0.0, 0.92),
		"ground_light": _make_material(Color(0.83, 0.68, 0.47), 0.0, 0.89),
		"ground_rose": _make_material(Color(0.66, 0.42, 0.38), 0.0, 0.91),
		"silver": _make_material(Color(0.68, 0.77, 0.81), 0.74, 0.28),
		"pearl": _make_material(Color(0.9, 0.93, 0.9), 0.2, 0.35),
		"ceramic": _make_material(Color(0.72, 0.83, 0.84), 0.28, 0.42),
		"blue": _make_material(Color(0.08, 0.25, 0.55), 0.52, 0.3),
		"deep_blue": _make_material(Color(0.035, 0.13, 0.33), 0.58, 0.28),
		"cyan": _make_emissive(Color(0.02, 0.78, 0.98), 1.5),
		"turquoise": _make_emissive(Color(0.015, 0.94, 0.8), 1.25),
		"green": _make_emissive(Color(0.12, 0.84, 0.38), 1.2),
		"yellow": _make_emissive(Color(1.0, 0.66, 0.035), 0.55),
		"orange": _make_emissive(Color(1.0, 0.27, 0.04), 0.9),
		"red": _make_emissive(Color(0.98, 0.05, 0.06), 1.0),
		"dark_trim": _make_material(Color(0.11, 0.18, 0.2), 0.66, 0.38),
		"copper": _make_material(Color(0.76, 0.32, 0.13), 0.65, 0.34),
		"rock": _make_material(Color(0.59, 0.43, 0.34), 0.02, 0.93),
	}


func _make_material(color: Color, metallic: float, roughness: float) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.metallic = metallic
	material.roughness = roughness
	return material


func _make_emissive(color: Color, strength: float) -> StandardMaterial3D:
	var material := _make_material(color, 0.25, 0.3)
	material.emission_enabled = true
	material.emission = color
	material.emission_energy_multiplier = strength
	return material


func _build_terrain_and_floor() -> void:
	var floor_body := StaticBody3D.new()
	floor_body.name = "ArenaFloor"
	floor_body.position = Vector3(0.0, -0.4, WORLD_CENTER_Z)
	floor_body.collision_layer = 1
	floor_body.collision_mask = 0
	var floor_shape := CollisionShape3D.new()
	floor_shape.name = "ArenaFloorCollisionShape"
	var shape := BoxShape3D.new()
	shape.size = Vector3(WORLD_WIDTH, 0.8, WORLD_DEPTH)
	floor_shape.shape = shape
	floor_body.add_child(floor_shape)
	add_child(floor_body)

	var ground_mesh := PlaneMesh.new()
	ground_mesh.size = Vector2(WORLD_WIDTH, WORLD_DEPTH)
	ground_mesh.subdivide_width = 48
	ground_mesh.subdivide_depth = 44
	var ground := MeshInstance3D.new()
	ground.name = "ContinuousFrontierSurface"
	ground.mesh = ground_mesh
	ground.material_override = _materials["ground"]
	ground.position = Vector3(0.0, 0.012, WORLD_CENTER_Z)
	add_child(ground)

	# A broad foundation is visually softened by terrain shelves and rock formations.
	_add_box(
		"SouthApproachPlate",
		Vector3(0.0, 0.025, 36.0),
		Vector3(50.0, 0.12, 24.0),
		_materials["ground_light"]
	)
	_add_box(
		"WestOutpostApron",
		Vector3(-42.0, 0.028, 1.0),
		Vector3(44.0, 0.14, 58.0),
		_materials["ground_light"]
	)
	_add_box(
		"EastLandingApron",
		Vector3(47.0, 0.03, 1.0),
		Vector3(46.0, 0.16, 48.0),
		_materials["ground_rose"]
	)
	_add_box(
		"NorthExtractionApron",
		Vector3(32.0, 0.032, -39.0),
		Vector3(54.0, 0.18, 40.0),
		_materials["ground_light"]
	)
	_add_box(
		"BossApproachApron",
		Vector3(0.0, 0.035, -61.0),
		Vector3(45.0, 0.2, 45.0),
		_materials["ground_rose"]
	)

	for shelf_index in range(8):
		var offset := float(shelf_index) * 2.1
		_add_box(
			"WestTerrainShelf_%02d" % shelf_index,
			Vector3(-82.0 - offset * 0.15, 0.55 + offset * 0.15, -38.0 + offset * 10.5),
			Vector3(7.0 + offset * 0.45, 1.1 + offset * 0.3, 10.0),
			_materials["ground_light"] if shelf_index % 2 == 0 else _materials["ground_rose"],
			Vector3(0.0, 0.0, -4.0)
		)
		_add_box(
			"EastTerrainShelf_%02d" % shelf_index,
			Vector3(82.0 + offset * 0.15, 0.62 + offset * 0.16, -45.0 + offset * 10.0),
			Vector3(7.0 + offset * 0.42, 1.2 + offset * 0.32, 10.0),
			_materials["ground_rose"] if shelf_index % 2 == 0 else _materials["ground_light"],
			Vector3(0.0, 0.0, 4.0)
		)

	_add_world_bounds()


func _add_world_bounds() -> void:
	# The collision walls and the rocky skyline are built together so the player
	# never sees the flat box that stops them. See kaykit_base_builder.gd.
	KayKitBaseBuilder.build_boundary(self, WORLD_WIDTH, WORLD_DEPTH, WORLD_CENTER_Z)


func _build_central_arena() -> void:
	_add_box(
		"CentralArenaSubstructure",
		Vector3(0.0, -0.25, 0.0),
		Vector3(42.0, 0.5, 42.0),
		_materials["silver"]
	)
	_add_box(
		"CentralArenaOuterBand",
		Vector3(0.0, 0.025, 0.0),
		Vector3(40.0, 0.05, 40.0),
		_materials["blue"]
	)
	_add_box(
		"CentralArenaDeck", Vector3(0.0, 0.03, 0.0), Vector3(38.0, 0.02, 38.0), _materials["pearl"]
	)
	_add_box(
		"CentralArenaInnerDeck",
		Vector3(0.0, 0.047, 0.0),
		Vector3(33.6, 0.014, 33.6),
		_materials["ceramic"]
	)

	for tile_x in range(7):
		for tile_z in range(7):
			var x := -18.0 + float(tile_x) * 6.0
			var z := -18.0 + float(tile_z) * 6.0
			var material: Material = (
				_materials["silver"] if (tile_x + tile_z) % 2 == 0 else _materials["ceramic"]
			)
			_add_box(
				"ArenaPanel_%02d_%02d" % [tile_x, tile_z],
				Vector3(x, 0.061, z),
				Vector3(5.7, 0.02, 5.7),
				material
			)
			_add_box(
				"ArenaPanelSeamX_%02d_%02d" % [tile_x, tile_z],
				Vector3(x, 0.075, z - 2.78),
				Vector3(5.42, 0.008, 0.035),
				_materials["dark_trim"]
			)
			if (tile_x + tile_z) % 3 == 0:
				for bolt_x in [-2.48, 2.48]:
					for bolt_z in [-2.48, 2.48]:
						_add_cylinder(
							"ArenaPanelFastener",
							Vector3(x + bolt_x, 0.086, z + bolt_z),
							0.045,
							0.045,
							0.028,
							_materials["dark_trim"],
							Vector3.ZERO,
							8
						)

	_add_box(
		"ArenaEnergyChannelNorth",
		Vector3(0.0, 0.09, -14.2),
		Vector3(0.46, 0.05, 7.3),
		_materials["cyan"]
	)
	_add_box(
		"ArenaEnergyChannelSouth",
		Vector3(0.0, 0.09, 14.2),
		Vector3(0.46, 0.05, 7.3),
		_materials["cyan"]
	)
	_add_box(
		"ArenaEnergyChannelEast",
		Vector3(14.2, 0.09, 0.0),
		Vector3(7.3, 0.05, 0.46),
		_materials["cyan"]
	)
	_add_box(
		"ArenaEnergyChannelWest",
		Vector3(-14.2, 0.09, 0.0),
		Vector3(7.3, 0.05, 0.46),
		_materials["cyan"]
	)
	_add_box(
		"ArenaCrossChannelX",
		Vector3(0.0, 0.08, 0.0),
		Vector3(31.0, 0.035, 0.18),
		_materials["turquoise"]
	)
	_add_box(
		"ArenaCrossChannelZ",
		Vector3(0.0, 0.08, 0.0),
		Vector3(0.18, 0.035, 31.0),
		_materials["turquoise"]
	)

	for side in [-1.0, 1.0]:
		_add_box(
			"ArenaOrangeConduitX_%s" % str(side),
			Vector3(side * 8.0, 0.08, 0.0),
			Vector3(0.48, 0.16, 18.0),
			_materials["copper"]
		)
		_add_box(
			"ArenaOrangeConduitGlowX_%s" % str(side),
			Vector3(side * 8.0, 0.13, 0.0),
			Vector3(0.12, 0.04, 17.0),
			_materials["orange"]
		)
		_add_box(
			"ArenaOrangeConduitZ_%s" % str(side),
			Vector3(0.0, 0.08, side * 8.0),
			Vector3(18.0, 0.16, 0.48),
			_materials["copper"]
		)
		_add_box(
			"ArenaOrangeConduitGlowZ_%s" % str(side),
			Vector3(0.0, 0.13, side * 8.0),
			Vector3(17.0, 0.04, 0.12),
			_materials["orange"]
		)

	_add_arena_hazard_markings()
	_place_component(REACTOR_SCENE, "CentralReactor", Vector3(0.0, 0.0, 0.0))
	_add_arena_spawn_gates()
	_place_component(COVER_SCENE, "CoverWest", Vector3(-10.0, 0.0, 1.5), Vector3(0.0, 0.0, -8.0))
	_place_component(COVER_SCENE, "CoverEast", Vector3(4.0, 0.0, -3.0), Vector3(0.0, 90.0, 0.0))
	_place_component(
		COVER_SCENE,
		"CoverNorthWest",
		Vector3(-7.0, 0.0, -11.0),
		Vector3(0.0, 22.0, 0.0),
		Vector3(0.8, 0.8, 0.8)
	)
	_place_component(
		COVER_SCENE,
		"CoverSouthEast",
		Vector3(8.0, 0.0, 9.0),
		Vector3(0.0, -16.0, 0.0),
		Vector3(0.75, 0.75, 0.75)
	)

	# Retained service deck and low ramp remain traversable for the existing combat blockout.
	_add_box(
		"ServiceDeck",
		Vector3(11.3, 0.25, 5.5),
		Vector3(3.0, 0.5, 3.0),
		_materials["blue"],
		Vector3.ZERO,
		true
	)
	_add_box(
		"ServiceDeckTop", Vector3(11.3, 0.53, 5.5), Vector3(2.7, 0.08, 2.7), _materials["pearl"]
	)
	_add_box(
		"ServiceRamp",
		Vector3(8.1, 0.25, 5.5),
		Vector3(3.4, 0.16, 2.4),
		_materials["silver"],
		Vector3(0.0, 0.0, 8.5),
		true
	)
	_add_box(
		"ServiceRampStripe",
		Vector3(8.1, 0.36, 5.5),
		Vector3(2.5, 0.035, 0.07),
		_materials["yellow"],
		Vector3(0.0, 0.0, 8.5)
	)
	_add_box(
		"ServiceDeckStripe",
		Vector3(11.3, 0.59, 5.5),
		Vector3(2.0, 0.035, 0.08),
		_materials["orange"]
	)

	_add_box(
		"SouthLaneMarking", Vector3(0.0, 0.09, 17.5), Vector3(0.14, 0.04, 4.0), _materials["cyan"]
	)
	_add_box(
		"NorthLaneMarking", Vector3(0.0, 0.09, -17.5), Vector3(0.14, 0.04, 4.0), _materials["cyan"]
	)
	_add_box(
		"WestLaneMarking", Vector3(-17.5, 0.09, 0.0), Vector3(4.0, 0.04, 0.14), _materials["cyan"]
	)
	_add_box(
		"EastLaneMarking", Vector3(17.5, 0.09, 0.0), Vector3(4.0, 0.04, 0.14), _materials["cyan"]
	)


func _add_arena_hazard_markings() -> void:
	for stripe in range(18):
		var x := -18.0 + float(stripe) * 2.12
		var material: Material = (
			_materials["yellow"] if stripe % 2 == 0 else _materials["dark_trim"]
		)
		_add_box(
			"ArenaEdgeStripeNorth_%02d" % stripe,
			Vector3(x, 0.09, -19.1),
			Vector3(1.0, 0.06, 0.42),
			material
		)
		_add_box(
			"ArenaEdgeStripeSouth_%02d" % stripe,
			Vector3(x, 0.09, 19.1),
			Vector3(1.0, 0.06, 0.42),
			material
		)
		var z := -18.0 + float(stripe) * 2.12
		_add_box(
			"ArenaEdgeStripeEast_%02d" % stripe,
			Vector3(19.1, 0.09, z),
			Vector3(0.42, 0.06, 1.0),
			material
		)
		_add_box(
			"ArenaEdgeStripeWest_%02d" % stripe,
			Vector3(-19.1, 0.09, z),
			Vector3(0.42, 0.06, 1.0),
			material
		)
	for corner_x in [-17.0, 17.0]:
		for corner_z in [-17.0, 17.0]:
			_add_box(
				"ArenaCornerWarningPanel",
				Vector3(corner_x, 0.11, corner_z),
				Vector3(1.1, 0.07, 1.1),
				_materials["orange"]
			)


func _add_arena_spawn_gates() -> void:
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
		_place_component(
			SPAWN_GATE_SCENE,
			"WaveEntry_%s" % gate_data.name,
			gate_data.position,
			gate_data.rotation
		)


func _build_access_routes() -> void:
	# Bright modular road plates physically join every playable district to the arena.
	_add_box(
		"WestRouteLeg", Vector3(-29.0, 0.015, 0.0), Vector3(22.0, 0.03, 8.0), _materials["silver"]
	)
	_add_box(
		"WestRouteNorthLeg",
		Vector3(-38.0, 0.015, -14.0),
		Vector3(8.0, 0.03, 28.0),
		_materials["silver"]
	)
	_add_box(
		"WestRouteSignal", Vector3(-29.0, 0.05, 0.0), Vector3(19.0, 0.045, 0.24), _materials["cyan"]
	)
	_add_box(
		"WestRouteSignalNorth",
		Vector3(-38.0, 0.05, -14.0),
		Vector3(0.24, 0.045, 25.0),
		_materials["turquoise"]
	)
	_add_box(
		"WestRouteEdgeYellow",
		Vector3(-29.0, 0.05, -3.75),
		Vector3(20.0, 0.035, 0.12),
		_materials["yellow"]
	)
	_add_box(
		"WestRouteEdgeYellowSouth",
		Vector3(-29.0, 0.05, 3.75),
		Vector3(20.0, 0.035, 0.12),
		_materials["yellow"]
	)

	_add_box(
		"EastRouteLeg", Vector3(30.0, 0.015, 1.0), Vector3(22.0, 0.03, 8.0), _materials["silver"]
	)
	_add_box(
		"EastRouteSignal", Vector3(30.0, 0.05, 1.0), Vector3(20.0, 0.02, 0.22), _materials["cyan"]
	)
	_add_box(
		"EastRouteEdgeNorth",
		Vector3(30.0, 0.05, -2.75),
		Vector3(21.0, 0.02, 0.12),
		_materials["yellow"]
	)
	_add_box(
		"EastRouteEdgeSouth",
		Vector3(30.0, 0.05, 4.75),
		Vector3(21.0, 0.02, 0.12),
		_materials["yellow"]
	)

	_add_box(
		"NorthRouteLeg", Vector3(0.0, 0.015, -31.0), Vector3(8.0, 0.03, 24.0), _materials["silver"]
	)
	_add_box(
		"NorthRouteCauseway",
		Vector3(0.0, 0.025, -51.0),
		Vector3(10.0, 0.05, 18.0),
		_materials["blue"]
	)
	_add_box(
		"NorthRouteSignal", Vector3(0.0, 0.06, -42.0), Vector3(0.22, 0.04, 36.0), _materials["cyan"]
	)
	for side in [-1.0, 1.0]:
		_add_box(
			"NorthRouteSafetyRail",
			Vector3(side * 4.65, 0.77, -50.5),
			Vector3(0.18, 1.3, 18.0),
			_materials["pearl"]
		)
		_add_box(
			"NorthRouteRailLight",
			Vector3(side * 4.52, 0.89, -50.5),
			Vector3(0.06, 0.08, 17.0),
			_materials["turquoise"]
		)
	_add_box(
		"BossRouteLanding",
		Vector3(0.0, 0.025, -62.0),
		Vector3(19.0, 0.05, 12.0),
		_materials["silver"]
	)

	_add_box(
		"SouthRouteLeg", Vector3(0.0, 0.015, 28.0), Vector3(8.0, 0.03, 16.0), _materials["ceramic"]
	)
	_add_box(
		"SouthRouteSignal", Vector3(0.0, 0.05, 28.0), Vector3(0.22, 0.04, 14.0), _materials["cyan"]
	)
	_add_box(
		"SouthPerimeterGateApproach",
		Vector3(0.0, 0.015, 38.0),
		Vector3(8.0, 0.03, 10.0),
		_materials["silver"]
	)
	_add_box(
		"SouthResourceRouteTurn",
		Vector3(-14.0, 0.015, 43.0),
		Vector3(28.0, 0.03, 8.0),
		_materials["silver"]
	)
	_add_box(
		"SouthResourceRouteLeg",
		Vector3(-28.0, 0.015, 55.0),
		Vector3(8.0, 0.03, 24.0),
		_materials["ceramic"]
	)
	_add_box(
		"SouthWreckApproach",
		Vector3(-39.0, 0.015, 46.0),
		Vector3(22.0, 0.03, 8.0),
		_materials["silver"]
	)
	_add_box(
		"SouthResourceRouteSignal",
		Vector3(-14.0, 0.05, 43.0),
		Vector3(25.0, 0.035, 0.16),
		_materials["turquoise"]
	)
	_add_box(
		"SouthResourceRouteSignalLeg",
		Vector3(-28.0, 0.05, 55.0),
		Vector3(0.16, 0.035, 21.0),
		_materials["cyan"]
	)

	# Conduits visibly carry energy between the reactor and the extraction complex.
	_add_box(
		"MainEnergyConduitWest",
		Vector3(-25.0, 0.72, -2.0),
		Vector3(24.0, 0.38, 0.42),
		_materials["copper"]
	)
	_add_box(
		"MainEnergyConduitWestGlow",
		Vector3(-25.0, 0.94, -2.0),
		Vector3(23.0, 0.08, 0.14),
		_materials["orange"]
	)
	_add_box(
		"MainEnergyConduitNorth",
		Vector3(20.0, 0.72, -26.0),
		Vector3(0.42, 0.38, 50.0),
		_materials["copper"]
	)
	_add_box(
		"MainEnergyConduitNorthGlow",
		Vector3(20.0, 0.94, -26.0),
		Vector3(0.14, 0.08, 49.0),
		_materials["turquoise"]
	)
	_add_box(
		"MainEnergyConduitEast",
		Vector3(31.0, 0.72, -33.0),
		Vector3(22.0, 0.38, 0.42),
		_materials["copper"]
	)
	_add_box(
		"MainEnergyConduitEastGlow",
		Vector3(31.0, 0.94, -33.0),
		Vector3(21.0, 0.08, 0.14),
		_materials["green"]
	)
	for x in [-35.0, -15.0, 20.0, 41.0]:
		var z := -2.0 if x < 0.0 else -33.0
		_add_box(
			"EnergyPipeSupport", Vector3(x, 0.53, z), Vector3(0.34, 1.0, 0.34), _materials["blue"]
		)


func _build_outpost() -> void:
	_place_component(
		COMMAND_SCENE, "OutpostCommandCenter", Vector3(-52.0, 0.0, -4.0), Vector3(0.0, 90.0, 0.0)
	)
	_place_component(
		LAB_SCENE, "WeaponResearchLaboratory", Vector3(-47.0, 0.0, -28.0), Vector3(0.0, 90.0, 0.0)
	)
	_place_component(
		DEPOT_SCENE, "FieldEquipmentDepot", Vector3(-49.0, 0.0, 19.0), Vector3(0.0, -90.0, 0.0)
	)
	_place_component(
		SENSOR_SCENE,
		"WestObservationTower",
		Vector3(-72.0, 0.0, -22.0),
		Vector3(0.0, 18.0, 0.0),
		Vector3(0.9, 1.0, 0.9)
	)
	_place_component(
		SENSOR_SCENE,
		"SouthwestSignalTower",
		Vector3(-69.0, 0.0, 31.0),
		Vector3(0.0, -14.0, 0.0),
		Vector3(0.82, 0.88, 0.82)
	)
	_place_component(
		LANDING_PAD_SCENE,
		"EastVehicleLandingPlatform",
		Vector3(52.0, 0.0, 5.0),
		Vector3(0.0, -12.0, 0.0),
		Vector3(1.0, 0.28, 1.0)
	)
	_add_box(
		"LandingPadAccessRamp",
		Vector3(31.75, 0.0685, 5.0),
		Vector3(9.5, 0.06, 4.0),
		_materials["silver"],
		Vector3(0.0, 0.0, 1.19),
		true
	)
	_add_box(
		"LandingPadRampGuide",
		Vector3(31.75, 0.13, 3.1),
		Vector3(8.5, 0.035, 0.08),
		_materials["yellow"],
		Vector3(0.0, 0.0, 1.19)
	)

	_add_box(
		"CommandToLabAccess",
		Vector3(-48.5, 0.06, -17.0),
		Vector3(7.0, 0.12, 9.0),
		_materials["ceramic"]
	)
	_add_box(
		"CommandToDepotAccess",
		Vector3(-48.5, 0.06, 9.0),
		Vector3(7.0, 0.12, 10.0),
		_materials["ceramic"]
	)
	_add_box(
		"OutpostVehicleApron",
		Vector3(-67.0, 0.07, 2.0),
		Vector3(14.0, 0.14, 42.0),
		_materials["silver"]
	)
	_add_box(
		"OutpostApronStripe",
		Vector3(-67.0, 0.16, 2.0),
		Vector3(0.18, 0.04, 40.0),
		_materials["yellow"]
	)
	_place_world_gltf(
		"spacetruck_large",
		"KayKitOutpostServiceTruck",
		Vector3(-67.0, 0.81, -8.0),
		Vector3.ZERO,
		Vector3.ONE * 6.0,
		true,
		0.78
	)
	for crate_index in range(6):
		var x := -37.0 + float(crate_index % 3) * 2.2
		var z := 14.0 + float(crate_index / 3) * 2.0
		var cargo_name := "cargo_A_stacked" if crate_index % 2 == 0 else "cargo_B_stacked"
		var cargo := _place_world_gltf(
			cargo_name,
			"KayKitOutpostSupply_%02d" % crate_index,
			Vector3(x, 0.02, z),
			Vector3(0.0, float(crate_index % 4) * 90.0, 0.0),
			Vector3.ONE * 1.5
		)
		if cargo == null:
			_add_box(
				"OutpostSupplyCrate_%02d" % crate_index,
				Vector3(x, 0.75, z),
				Vector3(1.7, 1.5, 1.7),
				_materials["copper"]
			)
			_add_box(
				"OutpostCrateLabel_%02d" % crate_index,
				Vector3(x, 1.2, z + 0.88),
				Vector3(0.9, 0.25, 0.05),
				_materials["yellow"]
			)

	for side in [-1.0, 1.0]:
		_add_box(
			"OutpostPerimeterWall_%s" % str(side),
			Vector3(-60.0 + side * 17.0, 1.1, -3.0),
			Vector3(1.0, 2.2, 30.0),
			_materials["blue"]
		)
		_add_box(
			"OutpostWallLight_%s" % str(side),
			Vector3(-60.0 + side * 17.0, 2.3, -3.0),
			Vector3(0.1, 0.08, 28.0),
			_materials["cyan"]
		)
	_add_box(
		"OutpostDamagedWall",
		Vector3(-60.0, 0.95, 23.0),
		Vector3(25.0, 1.9, 0.9),
		_materials["ceramic"],
		Vector3(0.0, 0.0, -4.0),
		true
	)
	_add_box(
		"OutpostWallImpactScar",
		Vector3(-53.0, 1.65, 23.5),
		Vector3(4.8, 0.16, 0.15),
		_materials["orange"],
		Vector3(0.0, 0.0, 22.0)
	)


func _build_extraction_zone() -> void:
	_place_component(
		GENERATOR_SCENE,
		"FrontierEnergyExtractionBank",
		Vector3(43.0, 0.0, -35.0),
		Vector3(0.0, 180.0, 0.0)
	)
	_place_world_gltf(
		"drill_structure",
		"KayKitFrontierDrillStructure",
		Vector3(61.0, 0.0, -31.5),
		Vector3(0.0, 18.0, 0.0),
		Vector3.ONE * 3.2,
		true,
		0.82
	)
	_place_component(
		SENSOR_SCENE,
		"ExtractionSensorMast",
		Vector3(66.0, 0.0, -43.0),
		Vector3(0.0, 42.0, 0.0),
		Vector3(0.72, 0.8, 0.72)
	)
	for pipe_index in range(5):
		var z := -48.0 + float(pipe_index) * 6.0
		_add_box(
			"ExtractionGroundPipe_%02d" % pipe_index,
			Vector3(34.0, 0.62, z),
			Vector3(25.0, 0.45, 0.42),
			_materials["copper"]
		)
		_add_box(
			"ExtractionPipeGlow_%02d" % pipe_index,
			Vector3(34.0, 0.87, z),
			Vector3(24.0, 0.07, 0.11),
			_materials["turquoise"] if pipe_index % 2 == 0 else _materials["green"]
		)
	for support_index in range(4):
		var x := 26.0 + float(support_index) * 5.5
		_add_box(
			"ExtractionPipeSupport_%02d" % support_index,
			Vector3(x, 0.55, -35.0),
			Vector3(0.4, 1.1, 14.0),
			_materials["blue"]
		)
	_add_box(
		"ExtractionMaintenanceWalk",
		Vector3(51.0, 1.25, -27.0),
		Vector3(14.0, 0.32, 1.4),
		_materials["yellow"]
	)
	for side in [-1.0, 1.0]:
		_add_box(
			"ExtractionWalkRail",
			Vector3(51.0, 2.0, -27.0 + side * 0.65),
			Vector3(14.0, 1.2, 0.12),
			_materials["silver"]
		)
	_add_box(
		"ExtractionContainmentApron",
		Vector3(56.0, 0.08, -38.0),
		Vector3(22.0, 0.16, 26.0),
		_materials["ceramic"]
	)
	_add_box(
		"ExtractionHazardLine",
		Vector3(56.0, 0.18, -25.3),
		Vector3(21.0, 0.05, 0.22),
		_materials["orange"]
	)


func _build_boss_encounter_zone() -> void:
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
	add_child(platform_body)
	var platform_artwork := Node3D.new()
	platform_artwork.name = "BossPlatformArtwork"
	platform_artwork.scale.y = 0.3
	add_child(platform_artwork)
	_active_geometry_parent = platform_artwork
	_add_cylinder(
		"BossPlatformSilverRim",
		Vector3(0.0, 0.02, -63.0),
		19.0,
		19.0,
		0.5,
		_materials["silver"],
		Vector3.ZERO,
		32
	)
	_add_cylinder(
		"BossPlatformDeck",
		Vector3(0.0, 0.3, -63.0),
		17.7,
		17.7,
		0.12,
		_materials["blue"],
		Vector3.ZERO,
		32
	)
	_add_cylinder(
		"BossPlatformInnerDeck",
		Vector3(0.0, 0.39, -63.0),
		13.6,
		13.6,
		0.08,
		_materials["pearl"],
		Vector3.ZERO,
		32
	)
	_add_cylinder(
		"BossPlatformCenterPlate",
		Vector3(0.0, 0.45, -63.0),
		8.5,
		8.5,
		0.06,
		_materials["ceramic"],
		Vector3.ZERO,
		32
	)
	_add_cylinder(
		"BossPlatformEnergyRing",
		Vector3(0.0, 0.53, -63.0),
		15.1,
		15.1,
		0.09,
		_materials["cyan"],
		Vector3.ZERO,
		32
	)
	_add_cylinder(
		"BossPlatformWarningRing",
		Vector3(0.0, 0.59, -63.0),
		18.2,
		18.2,
		0.08,
		_materials["yellow"],
		Vector3.ZERO,
		32
	)
	for spoke in range(12):
		var angle := TAU * float(spoke) / 12.0
		var x := cos(angle) * 11.4
		var z := -63.0 + sin(angle) * 11.4
		_add_box(
			"BossPlatformSpoke_%02d" % spoke,
			Vector3(x, 0.52, z),
			Vector3(5.0, 0.07, 0.24),
			_materials["turquoise"],
			Vector3(0.0, -rad_to_deg(angle), 0.0)
		)
		var beacon_x := cos(angle) * 17.0
		var beacon_z := -63.0 + sin(angle) * 17.0
		_add_sphere(
			"BossPlatformRingLight_%02d" % spoke,
			Vector3(beacon_x, 0.75, beacon_z),
			Vector3(0.35, 0.2, 0.35),
			_materials["orange"] if spoke % 3 == 0 else _materials["cyan"]
		)
	_active_geometry_parent = null
	_add_box(
		"BossRouteRamp",
		Vector3(0.0, 0.13, -41.0),
		Vector3(8.0, 0.06, 6.0),
		_materials["silver"],
		Vector3(2.5, 0.0, 0.0),
		true
	)
	_place_component(BOSS_GATE_SCENE, "ColossalDockingGate", Vector3(0.0, 0.0, -83.0))
	for side in [-1.0, 1.0]:
		_add_box(
			"BossArenaSupportPillar",
			Vector3(side * 24.0, 8.0, -81.0),
			Vector3(3.0, 16.0, 5.0),
			_materials["pearl"]
		)
		_add_box(
			"BossArenaSupportConduit",
			Vector3(side * 21.8, 9.0, -64.0),
			Vector3(0.42, 0.42, 30.0),
			_materials["copper"]
		)
		_add_box(
			"BossArenaSupportConduitGlow",
			Vector3(side * 21.8, 9.27, -64.0),
			Vector3(0.12, 0.07, 28.0),
			_materials["orange"]
		)


func _build_defense_perimeter() -> void:
	var turret_positions: Array[Vector3] = [
		Vector3(-78.0, 0.0, -47.0),
		Vector3(78.0, 0.0, -48.0),
		Vector3(-80.0, 0.0, 30.0),
		Vector3(80.0, 0.0, 31.0),
		Vector3(-42.0, 0.0, 62.0),
		Vector3(43.0, 0.0, 62.0),
	]
	for turret_index in range(turret_positions.size()):
		_place_component(
			TURRET_SCENE,
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
		_place_component(
			SPAWN_GATE_SCENE,
			str(gate_data.name),
			gate_data.position,
			gate_data.rotation,
			Vector3(1.45, 1.35, 1.2)
		)

	_place_component(
		SENSOR_SCENE,
		"EastPerimeterSensor",
		Vector3(79.0, 0.0, 6.0),
		Vector3(0.0, -15.0, 0.0),
		Vector3(0.9, 1.1, 0.9)
	)
	_place_component(
		SENSOR_SCENE,
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
			_add_box(
				"PerimeterDefenseWallSide_%s_%d" % [str(side), segment_index],
				Vector3(wall_x, 1.15, segment_center),
				Vector3(0.8, 2.3, segment_length),
				_materials["pearl"],
				Vector3.ZERO,
				true
			)
			_add_box(
				"PerimeterDefenseWallSideLight_%s_%d" % [str(side), segment_index],
				Vector3(wall_x - side * 0.48, 2.35, segment_center),
				Vector3(0.08, 0.08, segment_length - 2.0),
				_materials["cyan"]
			)

	for side in [-1.0, 1.0]:
		var segment_center: float = side * 44.0
		_add_box(
			"NorthPerimeterDefenseWall_%s" % str(side),
			Vector3(segment_center, 1.15, -59.0),
			Vector3(78.0, 2.3, 0.8),
			_materials["pearl"],
			Vector3.ZERO,
			true
		)
		_add_box(
			"NorthPerimeterWallLight_%s" % str(side),
			Vector3(segment_center, 2.35, -59.0),
			Vector3(76.0, 0.08, 0.08),
			_materials["cyan"]
		)
		_add_box(
			"SouthPerimeterDefenseWall_%s" % str(side),
			Vector3(segment_center, 1.15, 39.0),
			Vector3(78.0, 2.3, 0.8),
			_materials["pearl"],
			Vector3.ZERO,
			true
		)
		_add_box(
			"SouthPerimeterWallLight_%s" % str(side),
			Vector3(segment_center, 2.35, 39.0),
			Vector3(76.0, 0.08, 0.08),
			_materials["cyan"]
		)

	_place_component(
		SENSOR_SCENE,
		"NorthwestRadarTower",
		Vector3(-73.0, 0.0, -66.0),
		Vector3.ZERO,
		Vector3(0.72, 0.75, 0.72)
	)
	_place_component(
		SENSOR_SCENE,
		"SoutheastRadarTower",
		Vector3(70.0, 0.0, 57.0),
		Vector3(0.0, 70.0, 0.0),
		Vector3(0.82, 0.85, 0.82)
	)
	_add_box(
		"PerimeterRelayArray",
		Vector3(0.0, 5.4, 40.0),
		Vector3(20.0, 0.6, 1.2),
		_materials["silver"]
	)
	for mast_index in range(7):
		var x := -9.0 + float(mast_index) * 3.0
		_add_box(
			"RelayArrayMast_%02d" % mast_index,
			Vector3(x, 7.8, 40.0),
			Vector3(0.16, 5.2, 0.16),
			_materials["blue"]
		)
		_add_sphere(
			"RelayArrayTip_%02d" % mast_index,
			Vector3(x, 10.5, 40.0),
			Vector3(0.28, 0.38, 0.28),
			_materials["turquoise"]
		)


func _build_destroyed_frontier_sector() -> void:
	_place_component(
		TRANSPORT_SCENE,
		"CrashedFrontierTransport",
		Vector3(-48.0, 0.0, 46.0),
		Vector3(0.0, 33.0, 0.0),
		Vector3(1.2, 1.0, 1.1)
	)
	_place_component(
		DRONE_WRECK_SCENE,
		"AlienDroneWreck",
		Vector3(-28.0, 0.0, 47.0),
		Vector3(0.0, -18.0, 0.0),
		Vector3(1.2, 1.0, 1.1)
	)
	_place_component(
		TURRET_SCENE,
		"DisabledCheckpointTurret",
		Vector3(-64.0, 0.0, 47.0),
		Vector3(0.0, 42.0, 72.0),
		Vector3(0.9, 0.72, 0.9)
	)
	_place_component(
		DEPOT_SCENE,
		"AbandonedLoadingModule",
		Vector3(-34.0, 0.0, 64.0),
		Vector3(0.0, -14.0, 0.0),
		Vector3(0.82, 0.8, 0.82)
	)
	_add_box(
		"CrackedSectorPavement",
		Vector3(-47.0, 0.11, 47.0),
		Vector3(37.0, 0.2, 26.0),
		_materials["ground_rose"],
		Vector3(0.0, 12.0, 0.0)
	)
	for crack_index in range(8):
		var x := -64.0 + float(crack_index) * 4.6
		var z := 36.0 + float(crack_index % 3) * 7.0
		_add_box(
			"FracturedMetalPlate_%02d" % crack_index,
			Vector3(x, 0.27, z),
			Vector3(3.2, 0.12, 2.8),
			_materials["silver"],
			Vector3(0.0, float(crack_index) * 17.0, float(crack_index % 2) * 11.0)
		)
		_add_box(
			"FractureWarningEdge_%02d" % crack_index,
			Vector3(x, 0.35, z + 1.4),
			Vector3(2.2, 0.035, 0.09),
			_materials["orange"],
			Vector3(0.0, float(crack_index) * 17.0, 0.0)
		)
	for debris_index in range(12):
		var x := -67.0 + float((debris_index * 7) % 34)
		var z := 34.0 + float((debris_index * 11) % 35)
		_add_box(
			"SectorMachineDebris_%02d" % debris_index,
			Vector3(x, 0.28, z),
			Vector3(1.8 + float(debris_index % 3) * 0.4, 0.5, 1.2),
			_materials["dark_trim"],
			Vector3(0.0, float(debris_index) * 29.0, float(debris_index % 4) * 8.0)
		)
	_add_box(
		"DisabledSecurityCheckpoint",
		Vector3(-72.0, 1.0, 46.0),
		Vector3(4.0, 2.0, 12.0),
		_materials["blue"],
		Vector3(0.0, 6.0, 0.0),
		true
	)
	_add_box(
		"CheckpointBrokenWindow",
		Vector3(-69.8, 1.55, 44.0),
		Vector3(0.08, 0.75, 5.0),
		_materials["orange"],
		Vector3(16.0, 0.0, 10.0)
	)
	_add_box(
		"DisabledTurretWarning",
		Vector3(-64.0, 2.9, 47.0),
		Vector3(0.12, 0.12, 1.1),
		_materials["red"]
	)
	_add_box(
		"BrokenCableRun",
		Vector3(-42.0, 0.68, 60.0),
		Vector3(12.0, 0.16, 0.15),
		_materials["dark_trim"],
		Vector3(0.0, 18.0, 12.0)
	)
	for spark_index in range(6):
		var x := -47.0 + float(spark_index) * 1.4
		_add_sphere(
			"ControlledCableSpark_%02d" % spark_index,
			Vector3(x, 0.95 + float(spark_index % 2) * 0.6, 59.0),
			Vector3(0.15, 0.18, 0.15),
			_materials["orange"]
		)
	_add_box(
		"SealedDeepFacilityGate",
		Vector3(-22.0, 5.6, 72.0),
		Vector3(18.0, 11.2, 1.5),
		_materials["blue"],
		Vector3.ZERO,
		true
	)
	for slat_index in range(6):
		_add_box(
			"DeepGateLockingSlat_%02d" % slat_index,
			Vector3(-29.0 + float(slat_index) * 2.8, 5.7, 72.9),
			Vector3(0.2, 9.2, 0.24),
			_materials["pearl"]
		)
	_add_box(
		"DeepGateSealedStatus",
		Vector3(-22.0, 10.3, 73.1),
		Vector3(5.0, 0.18, 0.12),
		_materials["red"]
	)


func _build_alien_landscape() -> void:
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
		var rock_name := "FrontierCliffRock_%02d" % rock_index
		var rock_position: Vector3 = rock_positions[rock_index]
		var rock_rotation := Vector3(0.0, rock_index * 29.0, 0.0)
		var rock_scale := Vector3(1.5, 2.7 if rock_index % 3 == 0 else 1.8, 1.45)
		var use_kaykit_rock := (
			rock_index == 0 or rock_index == 6 or rock_index == 12 or rock_index == 18
		)
		var external_rock: Node3D = null
		if use_kaykit_rock:
			external_rock = _place_world_gltf(
				"rocks_B",
				"KayKit" + rock_name,
				rock_position,
				rock_rotation,
				Vector3.ONE * 2.8,
				true,
				0.68
			)
		if external_rock == null:
			_place_component(
				ROCK_SCENE, rock_name, rock_position, rock_rotation, rock_scale, rock_index
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
		_place_component(
			CRYSTAL_SCENE,
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
		_place_component(
			FLORA_SCENE,
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
		_add_cylinder(
			"FrontierResourceCanister_%02d" % pickup_index,
			Vector3(x, 0.72, z),
			0.48,
			0.38,
			1.4,
			_materials["blue"],
			Vector3(0.0, float(pickup_index) * 27.0, 0.0),
			16
		)
		_add_cylinder(
			"ResourceCanisterCore_%02d" % pickup_index,
			Vector3(x, 0.74, z),
			0.23,
			0.23,
			1.1,
			_materials["green"],
			Vector3.ZERO,
			12
		)
		_add_box(
			"ResourceCanisterBand_%02d" % pickup_index,
			Vector3(x, 1.1, z + 0.4),
			Vector3(0.62, 0.12, 0.08),
			_materials["yellow"]
		)


func _build_lighting_and_atmosphere() -> void:
	var sun := DirectionalLight3D.new()
	sun.name = "FrontierDaylightSun"
	sun.rotation_degrees = Vector3(-47.0, -31.0, 0.0)
	sun.light_color = Color(1.0, 0.93, 0.78)
	sun.light_energy = 0.72
	sun.shadow_enabled = true
	sun.directional_shadow_max_distance = 115.0
	sun.shadow_bias = 0.04
	add_child(sun)

	var environment := Environment.new()
	environment.background_mode = Environment.BG_SKY
	var sky := Sky.new()
	var sky_material := ProceduralSkyMaterial.new()
	sky_material.sky_top_color = Color(0.14, 0.48, 0.77)
	sky_material.sky_horizon_color = Color(0.73, 0.88, 0.92)
	sky_material.ground_bottom_color = Color(0.55, 0.46, 0.4)
	sky_material.ground_horizon_color = Color(0.83, 0.73, 0.61)
	sky_material.sun_angle_max = 18.0
	sky_material.sun_curve = 0.18
	sky.sky_material = sky_material
	environment.sky = sky
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	environment.ambient_light_energy = 0.36
	environment.reflected_light_source = Environment.REFLECTION_SOURCE_BG
	environment.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	environment.tonemap_exposure = 0.92
	# The space base is authored in light, toy-like colours; without a little
	# contrast and saturation the whole frame blows out to white and the player
	# (a light-suited astronaut) stops reading against the floor.
	environment.adjustment_enabled = true
	environment.adjustment_brightness = 0.94
	environment.adjustment_contrast = 1.18
	environment.adjustment_saturation = 1.22
	environment.glow_enabled = true
	environment.glow_intensity = 0.1
	environment.fog_enabled = true
	environment.fog_light_color = Color(0.42, 0.62, 0.72)
	environment.fog_density = 0.0042
	environment.fog_aerial_perspective = 0.22
	var world_environment := WorldEnvironment.new()
	world_environment.name = "ArenaEnvironment"
	world_environment.environment = environment
	add_child(world_environment)

	_add_omni_light("ReactorCyanBounce", Vector3(0.0, 7.0, 0.0), Color(0.04, 0.76, 1.0), 2.6, 22.0)
	_add_omni_light(
		"ReactorEmeraldBounce", Vector3(-1.5, 7.0, 0.0), Color(0.08, 1.0, 0.42), 1.4, 13.0
	)
	_add_omni_light(
		"ExtractionGreenBounce", Vector3(43.0, 6.0, -35.0), Color(0.04, 0.95, 0.68), 2.4, 24.0
	)
	_add_omni_light(
		"BossGateBlueBounce", Vector3(0.0, 9.0, -82.0), Color(0.04, 0.45, 1.0), 2.0, 23.0
	)

	_add_atmospheric_specks()


func _add_atmospheric_specks() -> void:
	for speck_index in range(24):
		var x := -22.0 + float((speck_index * 13) % 44)
		var z := -20.0 + float((speck_index * 17) % 40)
		var y := 2.8 + float(speck_index % 5) * 1.1
		_add_sphere(
			"EnergyDustSpeck_%02d" % speck_index,
			Vector3(x, y, z),
			Vector3(0.055, 0.055, 0.055),
			_materials["cyan"] if speck_index % 3 == 0 else _materials["turquoise"]
		)


func _add_omni_light(
	node_name: String, at: Vector3, color: Color, energy: float, range: float
) -> void:
	var light := OmniLight3D.new()
	light.name = node_name
	light.position = at
	light.light_color = color
	light.light_energy = energy
	light.omni_range = range
	light.shadow_enabled = false
	add_child(light)


func _build_spawn_beacons() -> void:
	var spawn_points := get_node_or_null("../SpawnPoints") as Node3D
	if spawn_points == null:
		return
	for marker in spawn_points.get_children():
		if not marker is Marker3D:
			continue
		var beacon := MeshInstance3D.new()
		beacon.name = "%s_Beacon" % marker.name
		var mesh := CylinderMesh.new()
		mesh.top_radius = 0.72
		mesh.bottom_radius = 0.72
		mesh.height = 0.06
		mesh.radial_segments = 20
		beacon.mesh = mesh
		beacon.material_override = _materials["orange"]
		beacon.position = to_local((marker as Marker3D).global_position) + Vector3.UP * 0.46
		add_child(beacon)
		_add_sphere(
			"%s_Core" % marker.name,
			beacon.position + Vector3.UP * 0.12,
			Vector3(0.25, 0.24, 0.25),
			_materials["cyan"]
		)


func _place_world_gltf(
	asset_name: String,
	node_name: String,
	at: Vector3,
	rotation: Vector3 = Vector3.ZERO,
	model_scale: Vector3 = Vector3.ONE,
	collidable: bool = false,
	collider_fill_ratio: float = 0.88
) -> Node3D:
	var model := GltfAssetLibrary.instantiate_model(asset_name)
	if model == null:
		return null
	model.name = node_name
	model.position = at
	model.rotation_degrees = rotation
	model.scale = model_scale
	_get_geometry_parent().add_child(model)
	if collidable:
		GltfAssetLibrary.add_bounds_collider(model, "%s_Collision" % node_name, collider_fill_ratio)
	return model


func _place_component(
	scene: PackedScene,
	node_name: String,
	at: Vector3,
	rotation: Vector3 = Vector3.ZERO,
	component_scale: Vector3 = Vector3.ONE,
	seed: int = 0
) -> Node3D:
	var component := scene.instantiate() as Node3D
	if component == null:
		push_error("Neon Frontier component failed to instantiate: " + node_name)
		return self
	component.name = node_name
	component.position = at
	component.rotation_degrees = rotation
	component.scale = component_scale
	component.set("variant_seed", seed)
	add_child(component)
	return component


func _add_box(
	node_name: String,
	at: Vector3,
	size: Vector3,
	material: Material,
	rotation: Vector3 = Vector3.ZERO,
	collidable: bool = false
) -> MeshInstance3D:
	var mesh := BoxMesh.new()
	mesh.size = size
	var instance := MeshInstance3D.new()
	instance.name = node_name
	instance.mesh = mesh
	instance.material_override = material
	instance.position = at
	instance.rotation_degrees = rotation
	var geometry_parent := _get_geometry_parent()
	geometry_parent.add_child(instance)
	if collidable:
		var body := StaticBody3D.new()
		body.name = "%s_Collision" % node_name
		body.position = at
		body.rotation_degrees = rotation
		body.collision_layer = 1
		body.collision_mask = 0
		var collision_shape := CollisionShape3D.new()
		var box_shape := BoxShape3D.new()
		box_shape.size = size
		collision_shape.shape = box_shape
		body.add_child(collision_shape)
		geometry_parent.add_child(body)
	return instance


func _get_geometry_parent() -> Node3D:
	return _active_geometry_parent if _active_geometry_parent != null else self


func _add_cylinder(
	node_name: String,
	at: Vector3,
	bottom_radius: float,
	top_radius: float,
	height: float,
	material: Material,
	rotation: Vector3 = Vector3.ZERO,
	radial_segments: int = 24
) -> MeshInstance3D:
	var mesh := CylinderMesh.new()
	mesh.bottom_radius = bottom_radius
	mesh.top_radius = top_radius
	mesh.height = height
	mesh.radial_segments = radial_segments
	var instance := MeshInstance3D.new()
	instance.name = node_name
	instance.mesh = mesh
	instance.material_override = material
	instance.position = at
	instance.rotation_degrees = rotation
	_get_geometry_parent().add_child(instance)
	return instance


func _add_sphere(
	node_name: String, at: Vector3, size: Vector3, material: Material
) -> MeshInstance3D:
	var mesh := SphereMesh.new()
	mesh.radius = 1.0
	mesh.height = 2.0
	mesh.radial_segments = 12
	mesh.rings = 8
	var instance := MeshInstance3D.new()
	instance.name = node_name
	instance.mesh = mesh
	instance.material_override = material
	instance.position = at
	instance.scale = size
	_get_geometry_parent().add_child(instance)
	return instance
