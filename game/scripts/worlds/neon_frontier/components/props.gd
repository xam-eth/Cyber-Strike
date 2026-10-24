## Crystal clusters, alien flora, rock outcrops, spawn gates and cover modules.
##
## Split out of neon_frontier_asset.gd, which had grown to 1,631 physical lines
## — over the 1,600 gdlint allows — once every shape call carried its parent.
## These are the components that get *placed* rather than built: five of the
## fourteen builders, and the ones least tangled with the station structures,
## so they are the first group to get a file of their own.
##
## Each builder takes the asset node and only reaches for its palette
## (`asset._materials`) and its variant seed; the shapes come from
## NeonFrontierGeometry.
class_name NeonFrontierProps
extends RefCounted

# Same short alias as the asset builder: these builders place a lot of shapes.
const GEOMETRY = preload("res://scripts/worlds/neon_frontier/geometry.gd")


static func build_crystal_cluster(asset) -> void:
	var color_keys: Array[String] = ["cyan", "emerald", "turquoise", "flora_lime", "blue"]
	var heights: Array[float] = [3.8, 5.4, 2.9, 4.6, 3.2, 2.3]
	var positions: Array[Vector2] = [
		Vector2(-1.6, -0.4),
		Vector2(-0.6, 0.9),
		Vector2(0.8, -0.8),
		Vector2(1.7, 0.5),
		Vector2(0.2, 1.8),
		Vector2(-2.0, 1.6)
	]
	for crystal_index in range(positions.size()):
		var position := positions[crystal_index]
		var height := heights[(crystal_index + asset.variant_seed) % heights.size()]
		var bottom_radius := 0.58 + 0.08 * float((crystal_index + asset.variant_seed) % 3)
		GEOMETRY.cylinder(
			asset,
			"CrystalShard_%02d" % crystal_index,
			Vector3(position.x, height * 0.5, position.y),
			bottom_radius,
			0.025,
			height,
			asset._materials[color_keys[(crystal_index + asset.variant_seed) % color_keys.size()]],
			Vector3(
				float(crystal_index % 2) * 6.0,
				float(crystal_index * 31),
				float(crystal_index % 3 - 1) * 8.0
			),
			6
		)
		GEOMETRY.cylinder(
			asset,
			"CrystalRoot_%02d" % crystal_index,
			Vector3(position.x, 0.18, position.y),
			bottom_radius * 1.35,
			bottom_radius,
			0.36,
			asset._materials["rock_rose"],
			Vector3.ZERO,
			7
		)
	for shard in range(3):
		var x := -2.0 + float(shard) * 1.8
		GEOMETRY.cylinder(
			asset,
			"CrystalSmallShard_%02d" % shard,
			Vector3(x, 0.52, -2.6),
			0.35,
			0.02,
			1.0 + float(shard % 2) * 0.55,
			asset._materials[color_keys[(shard + asset.variant_seed) % color_keys.size()]],
			Vector3(0.0, shard * 35.0, 12.0),
			5
		)


static func build_alien_flora(asset) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = asset.variant_seed + 1907
	for plant_index in range(7):
		var angle := TAU * float(plant_index) / 7.0 + rng.randf_range(-0.18, 0.18)
		var radius := rng.randf_range(0.8, 3.0)
		var x := cos(angle) * radius
		var z := sin(angle) * radius
		var height := rng.randf_range(1.0, 2.6)
		GEOMETRY.cylinder(
			asset,
			"FloraStem_%02d" % plant_index,
			Vector3(x, height * 0.5, z),
			0.12,
			0.08,
			height,
			asset._materials["flora"],
			Vector3(0.0, 0.0, rng.randf_range(-12.0, 12.0)),
			10
		)
		GEOMETRY.sphere(
			asset,
			"FloraLantern_%02d" % plant_index,
			Vector3(x, height, z),
			Vector3(0.25, 0.36, 0.25),
			asset._materials["flora_lime"]
		)
		for leaf_index in range(3):
			var leaf_angle := angle + float(leaf_index) * TAU / 3.0
			var leaf_center := Vector3(
				x + cos(leaf_angle) * 0.42, height * 0.64, z + sin(leaf_angle) * 0.42
			)
			GEOMETRY.sphere(
				asset,
				"FloraLeaf_%02d_%02d" % [plant_index, leaf_index],
				leaf_center,
				Vector3(0.62, 0.16, 0.28),
				asset._materials["flora_teal"],
				Vector3(0.0, -rad_to_deg(leaf_angle), 20.0)
			)
	for frond_index in range(3):
		var x := -1.4 + float(frond_index) * 1.4
		GEOMETRY.link_cylinder(
			asset,
			"FloraArchingFrond_%02d" % frond_index,
			Vector3(x, 0.2, 0.0),
			Vector3(x * 1.5, 1.8 + float(frond_index % 2) * 0.4, 0.6),
			0.07,
			asset._materials["flora"]
		)
		GEOMETRY.sphere(
			asset,
			"FloraFrondTip_%02d" % frond_index,
			Vector3(x * 1.5, 1.8 + float(frond_index % 2) * 0.4, 0.6),
			Vector3(0.18, 0.34, 0.18),
			asset._materials["flora_lime"]
		)


static func build_rock_cluster(asset) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = asset.variant_seed + 811
	var rock_mats: Array[String] = ["rock", "rock_light", "rock_rose"]
	for rock_index in range(9):
		var angle := TAU * float(rock_index) / 9.0 + rng.randf_range(-0.24, 0.24)
		var distance := rng.randf_range(0.6, 3.8)
		var width := rng.randf_range(1.0, 3.0)
		var height := rng.randf_range(1.1, 4.4)
		var depth := rng.randf_range(1.0, 2.7)
		GEOMETRY.sphere(
			asset,
			"RockMass_%02d" % rock_index,
			Vector3(cos(angle) * distance, height * 0.45, sin(angle) * distance),
			Vector3(width, height, depth),
			asset._materials[rock_mats[(rock_index + asset.variant_seed) % rock_mats.size()]],
			Vector3(
				rng.randf_range(-24.0, 24.0),
				rng.randf_range(0.0, 360.0),
				rng.randf_range(-16.0, 16.0)
			)
		)
		if rock_index % 3 == 0:
			GEOMETRY.box_collider(
				asset,
				"RockCollision_%02d" % rock_index,
				Vector3(cos(angle) * distance, height * 0.42, sin(angle) * distance),
				Vector3(width * 0.72, height * 0.78, depth * 0.72),
				Vector3(0.0, rng.randf_range(0.0, 360.0), 0.0)
			)


static func build_enemy_spawn_gate(asset) -> void:
	GEOMETRY.box(
		asset,
		"SpawnGateLeftFoot",
		Vector3(-2.8, 0.25, 0.0),
		Vector3(1.7, 0.5, 2.2),
		asset._materials["yellow"]
	)
	GEOMETRY.box(
		asset,
		"SpawnGateRightFoot",
		Vector3(2.8, 0.25, 0.0),
		Vector3(1.7, 0.5, 2.2),
		asset._materials["yellow"]
	)
	GEOMETRY.box(
		asset,
		"SpawnGateLeftPillar",
		Vector3(-2.55, 2.5, 0.0),
		Vector3(0.8, 4.4, 1.2),
		asset._materials["pearl"],
		Vector3.ZERO,
		true
	)
	GEOMETRY.box(
		asset,
		"SpawnGateRightPillar",
		Vector3(2.55, 2.5, 0.0),
		Vector3(0.8, 4.4, 1.2),
		asset._materials["pearl"],
		Vector3.ZERO,
		true
	)
	GEOMETRY.box(
		asset,
		"SpawnGateHeader",
		Vector3(0.0, 4.75, 0.0),
		Vector3(6.1, 0.75, 1.6),
		asset._materials["blue"]
	)
	GEOMETRY.box(
		asset,
		"SpawnGateEnergyLintel",
		Vector3(0.0, 4.25, 0.88),
		Vector3(4.3, 0.12, 0.08),
		asset._materials["cyan"]
	)
	GEOMETRY.box(
		asset,
		"SpawnGateWarningPanel",
		Vector3(0.0, 4.8, 0.86),
		Vector3(2.1, 0.4, 0.12),
		asset._materials["orange"]
	)
	for side in [-1.0, 1.0]:
		GEOMETRY.box(
			asset,
			"SpawnGatePillarStripe",
			Vector3(side * 2.55, 2.5, 0.63),
			Vector3(0.14, 3.3, 0.08),
			asset._materials["turquoise"]
		)
		GEOMETRY.sphere(
			asset,
			"SpawnGateBeacon",
			Vector3(side * 2.55, 5.35, 0.0),
			Vector3(0.34, 0.3, 0.34),
			asset._materials["red"]
		)
	for rail_index in range(3):
		GEOMETRY.box(
			asset,
			"SpawnGateFloorGuide_%d" % rail_index,
			Vector3(0.0, 0.06, -0.8 + rail_index * 0.7),
			Vector3(3.4, 0.08, 0.12),
			asset._materials["cyan"]
		)
	GEOMETRY.bolts(
		asset, "SpawnGate", Vector3.ZERO, Vector2(2.9, 0.8), 0.54, asset._materials["dark_trim"]
	)


static func build_cover_module(asset) -> void:
	GEOMETRY.box(
		asset,
		"CoverModuleBase",
		Vector3(0.0, 0.4, 0.0),
		Vector3(4.4, 0.8, 1.5),
		asset._materials["blue"],
		Vector3.ZERO,
		true
	)
	GEOMETRY.box(
		asset,
		"CoverModuleArmor",
		Vector3(0.0, 1.18, 0.0),
		Vector3(3.9, 0.84, 1.25),
		asset._materials["pearl"],
		Vector3.ZERO,
		true
	)
	GEOMETRY.box(
		asset,
		"CoverModuleTopStripe",
		Vector3(0.0, 1.62, 0.0),
		Vector3(3.7, 0.09, 1.12),
		asset._materials["yellow"]
	)
	for side in [-1.0, 1.0]:
		GEOMETRY.box(
			asset,
			"CoverModuleEdgeGuard",
			Vector3(side * 1.82, 1.12, 0.0),
			Vector3(0.22, 1.25, 1.35),
			asset._materials["copper"]
		)
		GEOMETRY.box(
			asset,
			"CoverModuleSignal",
			Vector3(side * 1.1, 1.18, 0.64),
			Vector3(0.54, 0.32, 0.06),
			asset._materials["cyan"]
		)
	for bolt_index in range(4):
		GEOMETRY.cylinder(
			asset,
			"CoverModuleBolt_%d" % bolt_index,
			Vector3(-1.4 + bolt_index * 0.94, 1.28, 0.69),
			0.07,
			0.07,
			0.04,
			asset._materials["dark_trim"],
			Vector3(90.0, 0.0, 0.0),
			8
		)
