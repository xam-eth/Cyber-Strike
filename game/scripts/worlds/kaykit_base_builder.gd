class_name KayKitBaseBuilder
extends RefCounted

## Composes level dressing out of the CC0 KayKit "Space Base Bits" pack.
##
## The pack is modular: 2 m terrain tiles, 2.2 m base modules with matching roof
## modules, tunnels, landing pads, cargo and vehicles. Every model is authored
## with the origin at the base and Y up, so the helpers here deal with three
## things a level designer would otherwise repeat by hand:
##
##   * **grounding** — a few models (trucks, tunnels) have their origin slightly
##     above or below the mesh, so `place()` shifts them by the measured
##     `BASE_MIN_Y` instead of letting them float or sink.
##   * **collision** — imported GLTFs carry no physics. Anything the player can
##     walk into gets a box bounds collider, and small props deliberately do not
##     (a 0.3 m rock should not stop a sprint).
##   * **determinism** — every district uses a seeded RNG, so two runs build the
##     same level and screenshots/tests stay comparable.
##
## Placement is always `(parent, model, node_name, position, yaw, scale)` so the
## generated node names stay greppable from the smoke tests.

const GltfAssetLibrary = preload("res://scripts/worlds/gltf_asset_library.gd")

## Measured minimum Y of each model in its own space (metres, scale 1).
## Positive means the mesh starts above the origin; negative means it dips below.
const BASE_MIN_Y := {
	"roofmodule_base": -0.10,
	"roofmodule_cargo_A": -0.10,
	"roofmodule_cargo_B": -0.10,
	"roofmodule_cargo_C": -0.10,
	"roofmodule_solarpanels": -0.10,
	"spacetruck": -0.08,
	"spacetruck_large": -0.13,
	"spacetruck_trailer": -0.14,
	"tunnel_diagonal_long_A": 0.20,
	"tunnel_diagonal_long_B": 0.20,
	"tunnel_diagonal_short_A": 0.20,
	"tunnel_diagonal_short_B": 0.20,
	"tunnel_straight_A": 0.20,
	"tunnel_straight_B": 0.20,
}


## Instantiate one kit model. Returns null when the model is missing or failed to
## import, so callers can fall back instead of leaving a hole in the level.
static func place(
	parent: Node3D,
	model_name: String,
	node_name: String,
	at: Vector3,
	yaw_degrees: float = 0.0,
	uniform_scale: float = 1.0,
	collidable: bool = false,
	collider_fill: float = 0.85,
	pitch_degrees: float = 0.0,
	cast_shadows: bool = false
) -> Node3D:
	if parent == null:
		return null
	var model := GltfAssetLibrary.instantiate_model(model_name)
	if model == null:
		return null
	model.name = node_name
	var ground: float = float(BASE_MIN_Y.get(model_name, 0.0))
	model.scale = Vector3.ONE * uniform_scale
	model.rotation_degrees = Vector3(pitch_degrees, yaw_degrees, 0.0)
	model.position = at - Vector3(0.0, ground * uniform_scale, 0.0)
	parent.add_child(model)
	if not cast_shadows:
		# Buildings catch the sun; the ~70 cliff tiles and every crate do not.
		# Compatibility rendering draws shadows per light, so cutting the small
		# casters is the cheapest frame-time win on a phone.
		for mesh in model.find_children("*", "MeshInstance3D", true, false):
			(mesh as MeshInstance3D).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	if collidable:
		GltfAssetLibrary.add_bounds_collider(model, "%sCollision" % node_name, collider_fill)
	return model


## A run of cliff tiles between two points, used instead of the old single box
## walls. Tiles alternate tall/low with a seeded jitter so the skyline reads as
## rock rather than as a fence; the gameplay wall stays a separate invisible box.
static func cliff_run(
	parent: Node3D,
	prefix: String,
	from: Vector3,
	to: Vector3,
	seed_value: int,
	tile_scale: float = 6.0,
	collidable: bool = true
) -> int:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	var span := to - from
	var length := span.length()
	if length <= 0.001:
		return 0
	var step := 2.0 * tile_scale * 0.92
	var count := maxi(int(round(length / step)), 1)
	var direction := span / length
	var yaw := rad_to_deg(atan2(direction.x, direction.z))
	var placed := 0
	for index in range(count):
		var t := (float(index) + 0.5) / float(count)
		var center := from + span * t
		var tile: String = ["terrain_tall", "terrain_tall_curved", "terrain_low"][index % 3]
		if rng.randf() < 0.18:
			tile = "rocks_B"
		var jitter := Vector3(rng.randf_range(-0.4, 0.4), 0.0, rng.randf_range(-0.4, 0.4))
		var scale := tile_scale * rng.randf_range(0.92, 1.12)
		if tile == "rocks_B":
			scale = tile_scale * 0.9
		place(
			parent,
			tile,
			"%s_%02d" % [prefix, index],
			center + jitter,
			yaw + rng.randf_range(-9.0, 9.0),
			scale,
			collidable and tile != "terrain_low",
			0.82,
		)
		placed += 1
	return placed


## A row of base modules with the matching roof modules on top. This is the
## building block for the outpost: one call is a bunker, four calls are a campus.
static func module_row(
	parent: Node3D,
	prefix: String,
	center: Vector3,
	yaw_degrees: float,
	count: int,
	scale: float = 2.4,
	spacing_scale: float = 1.0,
	roof: String = "roofmodule_base",
	collidable: bool = true
) -> int:
	var module_names := ["basemodule_A", "basemodule_B", "basemodule_C", "basemodule_D"]
	var lateral := Vector3(cos(deg_to_rad(yaw_degrees)), 0.0, -sin(deg_to_rad(yaw_degrees)))
	var step := 2.3 * scale * spacing_scale
	var total := step * float(count - 1)
	var start := center - lateral * (total * 0.5)
	for index in range(count):
		var at := start + lateral * (step * float(index))
		place(
			parent,
			module_names[index % module_names.size()],
			"%sModule_%02d" % [prefix, index],
			at,
			yaw_degrees,
			scale,
			collidable,
			0.86,
		)
		if roof != "":
			place(
				parent,
				roof if index % 2 == 0 else "roofmodule_base",
				"%sRoof_%02d" % [prefix, index],
				at + Vector3(0.0, 1.0 * scale, 0.0),
				yaw_degrees,
				scale * 1.42,
				false,
			)
	return count


## A hangar mouth: the garage module flanked by tunnels and lit by a lamp post.
static func hangar(
	parent: Node3D, prefix: String, at: Vector3, yaw_degrees: float, scale: float = 2.8
) -> void:
	place(parent, "basemodule_garage", "%sGarage" % prefix, at, yaw_degrees, scale, true, 0.88)
	var side := Vector3(cos(deg_to_rad(yaw_degrees)), 0.0, -sin(deg_to_rad(yaw_degrees)))
	for index in range(2):
		var offset := side * (2.6 * scale * (1.0 if index == 0 else -1.0))
		place(
			parent,
			"tunnel_straight_A" if index == 0 else "tunnel_straight_B",
			"%sTunnel_%02d" % [prefix, index],
			at + offset,
			yaw_degrees + (90.0 if index == 0 else -90.0),
			scale * 0.85,
			true,
			0.8,
		)
	place(
		parent,
		"lights",
		"%sLamp" % prefix,
		at + side * (3.4 * scale) + Vector3(0.0, 0.0, 1.2 * scale),
		yaw_degrees,
		scale * 0.9,
		false,
	)


## A landing apron tiled from landing pads. Pads are 2.5 m across at scale 1, so
## a 3x3 grid at scale 3.4 is a 25 m pad that fits the existing ramp.
static func landing_apron(
	parent: Node3D, prefix: String, center: Vector3, grid: int, scale: float = 3.4, y: float = 0.02
) -> int:
	var step := 2.5 * scale * 0.86
	var half := (float(grid) - 1.0) * 0.5
	var placed := 0
	for ix in range(grid):
		for iz in range(grid):
			var at := center + Vector3((float(ix) - half) * step, y, (float(iz) - half) * step)
			place(
				parent,
				"landingpad_large",
				"%sTile_%02d_%02d" % [prefix, ix, iz],
				at,
				30.0 if (ix + iz) % 2 == 0 else 0.0,
				scale,
				false,
			)
			placed += 1
	return placed


## Cargo yard: depots, stacked crates and loose containers, seeded and collidable.
static func cargo_yard(
	parent: Node3D,
	prefix: String,
	center: Vector3,
	yaw_degrees: float,
	seed_value: int,
	crate_count: int = 8,
	scale: float = 1.0
) -> int:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	var placed := 0
	place(
		parent,
		"cargodepot_A",
		"%sDepot" % prefix,
		center,
		yaw_degrees,
		2.2 * scale,
		true,
		0.9,
	)
	for index in range(crate_count):
		var angle := rng.randf_range(0.0, TAU)
		var radius := rng.randf_range(3.0, 11.0) * scale
		var at := center + Vector3(cos(angle) * radius, 0.0, sin(angle) * radius)
		var stack := rng.randf() < 0.45
		place(
			parent,
			(
				"cargo_%s_stacked" % ("A" if index % 2 == 0 else "B")
				if stack
				else "cargo_%s" % ("A" if index % 2 == 0 else "B")
			),
			"%sCrate_%02d" % [prefix, index],
			at,
			rng.randf_range(0.0, 360.0),
			(1.6 if stack else 1.2) * scale,
			index % 3 == 0,
			0.8,
		)
		placed += 1
	for index in range(3):
		var angle := float(index) * TAU / 3.0 + 0.4
		place(
			parent,
			"containers_%s" % ["A", "C", "D"][index],
			"%sContainer_%02d" % [prefix, index],
			center + Vector3(cos(angle) * 4.5, 0.0, sin(angle) * 4.5) * scale,
			rng.randf_range(0.0, 360.0),
			2.4 * scale,
			true,
			0.75,
		)
		placed += 1
	return placed


## A working mine face: mining terrain blocks, a truck trailer and lit poles.
static func mining_site(
	parent: Node3D,
	prefix: String,
	center: Vector3,
	yaw_degrees: int,
	seed_value: int,
	scale: float = 3.0
) -> int:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	var placed := 0
	var tiles := [
		Vector3(0.0, 0.0, 0.0),
		Vector3(2.0, 0.0, 0.0),
		Vector3(-2.0, 0.0, 0.0),
		Vector3(0.0, 0.0, 2.0),
		Vector3(2.0, 0.0, 2.0),
		Vector3(-2.0, 0.0, 2.0),
	]
	for index in range(tiles.size()):
		var offset: Vector3 = tiles[index] * scale
		place(
			parent,
			"terrain_mining" if index % 2 == 0 else "terrain_low_curved",
			"%sFace_%02d" % [prefix, index],
			center + offset,
			yaw_degrees + index * 37,
			scale,
			true,
			0.86,
		)
		placed += 1
	place(
		parent,
		"spacetruck_trailer",
		"%sHauler" % prefix,
		center + Vector3(-6.0, 0.0, 6.5) * (scale / 3.0),
		yaw_degrees + 90,
		2.2,
		true,
		0.8,
	)
	for index in range(4):
		place(
			parent,
			"containers_%s" % ["B", "D", "A", "C"][index],
			"%sOreContainer_%02d" % [prefix, index],
			center + Vector3(rng.randf_range(-7.0, 7.0), 0.0, rng.randf_range(-7.0, 7.0)),
			rng.randf_range(0.0, 360.0),
			2.2,
			true,
			0.75,
		)
		placed += 1
	return placed


## Ruins for the destroyed sector: tunnels knocked off axis, a toppled lander and
## rock debris. Everything is sunk slightly so the pieces read as wreckage.
static func ruin_pile(
	parent: Node3D, prefix: String, center: Vector3, seed_value: int, scale: float = 2.6
) -> int:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	var placed := 0
	var tunnel_names := ["tunnel_straight_A", "tunnel_straight_B", "tunnel_diagonal_short_A"]
	for index in range(tunnel_names.size()):
		place(
			parent,
			tunnel_names[index],
			"%sBrokenTunnel_%02d" % [prefix, index],
			(
				center
				+ (
					Vector3(
						rng.randf_range(-6.0, 6.0),
						rng.randf_range(0.0, 1.4),
						rng.randf_range(-6.0, 6.0)
					)
					* (scale / 2.6)
				)
			),
			rng.randf_range(0.0, 360.0),
			scale * rng.randf_range(0.8, 1.05),
			true,
			0.72,
			rng.randf_range(-14.0, 14.0),
		)
		placed += 1
	place(
		parent,
		"lander_B",
		"%sToppledLander" % prefix,
		center + Vector3(4.0, 0.8, -3.0),
		22.0,
		scale * 0.75,
		true,
		0.8,
		74.0,
	)
	for index in range(5):
		place(
			parent,
			"rocks_A" if index % 2 == 0 else "rocks_B",
			"%sDebris_%02d" % [prefix, index],
			center + Vector3(rng.randf_range(-9.0, 9.0), 0.0, rng.randf_range(-9.0, 9.0)),
			rng.randf_range(0.0, 360.0),
			rng.randf_range(1.4, 2.2),
			false,
		)
		placed += 1
	return placed


## A skyline piece: tall turbine on a small foundation, plus a solar array.
static func power_prop(
	parent: Node3D, prefix: String, at: Vector3, yaw_degrees: float, tall: bool = true
) -> void:
	place(
		parent,
		"windturbine_tall" if tall else "windturbine_low",
		"%sTurbine" % prefix,
		at,
		yaw_degrees,
		4.2 if tall else 3.4,
		false,
	)
	place(
		parent,
		"solarpanel",
		"%sSolar" % prefix,
		at + Vector3(3.2, 0.0, 2.4),
		yaw_degrees + 33.0,
		2.2,
		false,
	)


## A lamp post. Kept separate from `lights` so the name is obvious in the tree.
static func lamp(parent: Node3D, prefix: String, at: Vector3, scale: float = 2.2) -> void:
	place(parent, "lights", prefix, at, 0.0, scale, false)


## The playable rectangle: an invisible collision wall plus a rocky skyline.
##
## The first world pass fenced the frontier with four 10 m boxes. They stopped
## the player but read as painted cardboard from every angle. The collider stays
## (it is the only thing the physics needs); the visible wall is now three rows
## of terrain tiles and boulders, staggered so no straight seam is visible.
static func build_boundary(parent: Node3D, width: float, depth: float, center_z: float) -> void:
	var half_width := width * 0.5
	var half_depth := depth * 0.5
	var walls := [
		{
			"name": "NorthBoundaryCliffCore",
			"at": Vector3(0.0, 5.0, center_z - half_depth),
			"size": Vector3(width, 10.0, 2.0),
		},
		{
			"name": "SouthBoundaryCliffCore",
			"at": Vector3(0.0, 5.0, center_z + half_depth),
			"size": Vector3(width, 10.0, 2.0),
		},
		{
			"name": "WestBoundaryCliffCore",
			"at": Vector3(-half_width, 5.0, center_z),
			"size": Vector3(2.0, 10.0, depth),
		},
		{
			"name": "EastBoundaryCliffCore",
			"at": Vector3(half_width, 5.0, center_z),
			"size": Vector3(2.0, 10.0, depth),
		},
	]
	for wall in walls:
		var body := StaticBody3D.new()
		body.name = wall["name"]
		body.position = wall["at"]
		body.collision_layer = 1
		body.collision_mask = 0
		var collision := CollisionShape3D.new()
		collision.name = "%sCollisionShape" % wall["name"]
		var shape := BoxShape3D.new()
		shape.size = wall["size"]
		collision.shape = shape
		body.add_child(collision)
		parent.add_child(body)
		# Kept visible=false, not freed: the name is asserted by the world smoke
		# test and the collider is what the player actually hits.
		body.visible = false

	var north_z := center_z - half_depth + 1.6
	var south_z := center_z + half_depth + 1.6
	cliff_run(
		parent,
		"NorthCliff",
		Vector3(-half_width, 0.0, north_z),
		Vector3(half_width, 0.0, north_z),
		7101,
		6.0,
		false
	)
	cliff_run(
		parent,
		"SouthCliff",
		Vector3(half_width, 0.0, south_z),
		Vector3(-half_width, 0.0, south_z),
		7102,
		6.0,
		false
	)
	cliff_run(
		parent,
		"WestCliff",
		Vector3(-half_width - 1.6, 0.0, center_z + half_depth),
		Vector3(-half_width - 1.6, 0.0, center_z - half_depth),
		7103,
		6.0,
		false
	)
	cliff_run(
		parent,
		"EastCliff",
		Vector3(half_width + 1.6, 0.0, center_z - half_depth),
		Vector3(half_width + 1.6, 0.0, center_z + half_depth),
		7104,
		6.0,
		false
	)


## All district dressing, in one call from the world script.
##
## Coordinates are the same ones the blockout uses, so a module sits where the
## box it replaces used to stand. Nothing here touches the tested walkways: the
## two paths the smoke test drives (arena -> boss causeway, arena -> landing
## ramp) stay clear by construction.
static func dress_districts(world: Node3D) -> void:
	_dress_arena_rim(world)
	_dress_outpost(world)
	_dress_landing_zone(world)
	_dress_extraction(world)
	_dress_boss_zone(world)
	_dress_ruins(world)
	_dress_power_grid(world)
	_dress_terrain_shoulders(world)
	_dress_routes(world)


static func _dress_arena_rim(world: Node3D) -> void:
	var root := _group(world, "KayKitArenaRim")
	# Diagonal ring only: the four axis lanes carry the spawn gates and the
	# routes the traversal test walks, so nothing may stand there.
	var angles := [24.0, 66.0, 114.0, 156.0, 204.0, 246.0, 294.0, 336.0]
	for index in range(angles.size()):
		var angle := deg_to_rad(float(angles[index]))
		var at := Vector3(cos(angle) * 30.0, 0.0, sin(angle) * 30.0)
		var yaw := -rad_to_deg(angle) + 90.0
		place(
			root,
			"basemodule_%s" % ["A", "B", "C", "D"][index % 4],
			"ArenaCheckpoint_%02d" % index,
			at,
			yaw,
			2.7,
			true,
			0.86,
			0.0,
			true
		)
		place(
			root,
			"roofmodule_base",
			"ArenaCheckpointRoof_%02d" % index,
			at + Vector3(0.0, 2.7, 0.0),
			yaw,
			3.8
		)
		if index % 2 == 0:
			lamp(
				root, "ArenaLamp_%02d" % index, at + Vector3(cos(angle), 0.0, sin(angle)) * 4.5, 2.4
			)
	# The reactor keeps its own platform; a second flush pad here only produced
	# a disc that floated whenever the terrain shifted.
	# Cargo cover just off the lanes, on the diagonals.
	for index in range(4):
		var angle := deg_to_rad(45.0 + 90.0 * float(index))
		place(
			root,
			"cargo_%s_stacked" % ("A" if index % 2 == 0 else "B"),
			"ArenaCoverCargo_%02d" % index,
			Vector3(cos(angle) * 13.0, 0.0, sin(angle) * 13.0),
			float(index) * 63.0,
			1.7,
			true,
			0.8
		)


static func _dress_outpost(world: Node3D) -> void:
	var root := _group(world, "KayKitOutpost")
	# Barracks row inside the perimeter walls (x -77..-43, z -18..12).
	module_row(
		root,
		"OutpostBarracks",
		Vector3(-64.0, 0.0, -11.0),
		90.0,
		3,
		2.6,
		1.0,
		"roofmodule_base",
		true
	)
	for index in range(3):
		place(
			root,
			"roofmodule_solarpanels",
			"OutpostSolarRoof_%02d" % index,
			Vector3(-64.0, 2.6, -11.0 - float(index) * 5.98),
			90.0,
			3.7
		)
	hangar(root, "OutpostHangar", Vector3(-70.0, 0.0, 6.0), 90.0, 2.0)
	cargo_yard(root, "OutpostYard", Vector3(-54.0, 0.0, 7.0), 20.0, 4201, 6, 0.9)
	# Command annex behind the existing command-center component.
	module_row(
		root,
		"OutpostCommandAnnex",
		Vector3(-59.0, 0.0, -19.0),
		0.0,
		2,
		2.2,
		1.0,
		"roofmodule_cargo_A",
		true
	)
	for index in range(4):
		lamp(
			root,
			"OutpostLamp_%02d" % index,
			Vector3(-61.0 + float(index % 2) * 16.0, 0.0, -16.0 + float(index / 2) * 24.0),
			2.4
		)
	# Vehicle park along the west apron, outside the wall.
	place(
		root,
		"spacetruck_large",
		"OutpostParkedTruck",
		Vector3(-72.0, 0.0, 18.0),
		100.0,
		3.2,
		true,
		0.8,
		0.0,
		true
	)
	place(root, "spacetruck", "OutpostShuttle", Vector3(-64.0, 0.0, 22.0), 76.0, 2.8, true, 0.8)


static func _dress_landing_zone(world: Node3D) -> void:
	var root := _group(world, "KayKitLandingZone")
	# Pads are 1 m tall at scale 2, so they are sunk to leave a 0.34 m curb that
	# meets the existing ramp height.
	# The pad tiles are octagons: even at tight spacing their corners leave
	# triangular gaps. A thin continuous slab underneath turns those gaps into
	# joints instead of holes you can see the terrain through.
	var apron := MeshInstance3D.new()
	apron.name = "LandingApronBase"
	var apron_mesh := BoxMesh.new()
	apron_mesh.size = Vector3(26.0, 0.5, 26.0)
	apron.mesh = apron_mesh
	var apron_material := StandardMaterial3D.new()
	apron_material.albedo_color = Color(0.32, 0.36, 0.4)
	apron_material.metallic = 0.35
	apron_material.roughness = 0.6
	apron.material_override = apron_material
	apron.position = Vector3(52.0, 0.05, 5.0)
	root.add_child(apron)
	landing_apron(root, "LandingPad", Vector3(52.0, -0.66, 5.0), 5, 2.0, 0.0)
	place(
		root,
		"lander_A",
		"LandingLanderA",
		Vector3(47.5, 0.34, 2.0),
		24.0,
		2.4,
		true,
		0.8,
		0.0,
		true
	)
	place(
		root,
		"lander_B",
		"LandingLanderB",
		Vector3(58.0, 0.34, 9.5),
		-38.0,
		2.2,
		true,
		0.8,
		0.0,
		true
	)
	place(
		root,
		"spacetruck_large",
		"LandingServiceTruck",
		Vector3(38.0, 0.0, -7.0),
		12.0,
		3.2,
		true,
		0.8,
		0.0,
		true
	)
	cargo_yard(root, "LandingCargo", Vector3(62.0, 0.0, -4.0), -14.0, 4202, 5, 0.85)
	for index in range(4):
		var angle := deg_to_rad(45.0 + 90.0 * float(index))
		lamp(
			root,
			"LandingLamp_%02d" % index,
			Vector3(52.0, 0.0, 5.0) + Vector3(cos(angle), 0.0, sin(angle)) * 17.0,
			2.6
		)


static func _dress_extraction(world: Node3D) -> void:
	var root := _group(world, "KayKitExtraction")
	mining_site(root, "ExtractionMine", Vector3(74.0, 0.0, -40.0), 18, 4301, 2.4)
	mining_site(root, "ExtractionPit", Vector3(48.0, 0.0, -52.0), -64, 4302, 1.8)
	# A tunnel mouth so the mine reads as going somewhere.
	place(
		root,
		"tunnel_straight_B",
		"ExtractionTunnelMouth",
		Vector3(66.0, 0.0, -50.0),
		90.0,
		3.2,
		true,
		0.78,
		0.0,
		true
	)
	place(
		root,
		"tunnel_straight_A",
		"ExtractionTunnelRun",
		Vector3(66.0, 0.0, -56.0),
		90.0,
		3.2,
		true,
		0.78
	)
	for index in range(3):
		place(
			root,
			"structure_tall",
			"ExtractionPylon_%02d" % index,
			Vector3(52.0 + float(index) * 9.0, 0.0, -34.0),
			0.0,
			3.0,
			true,
			0.8,
			0.0,
			true
		)
	for index in range(3):
		lamp(
			root,
			"ExtractionLamp_%02d" % index,
			Vector3(44.0 + float(index) * 12.0, 0.0, -42.0),
			2.8
		)


static func _dress_boss_zone(world: Node3D) -> void:
	var root := _group(world, "KayKitBossZone")
	for side in [-1.0, 1.0]:
		place(
			root,
			"structure_tall",
			"BossGatePylon_%s" % str(side),
			Vector3(side * 15.0, 0.0, -82.0),
			0.0,
			5.6,
			true,
			0.82,
			0.0,
			true
		)
		place(
			root,
			"tunnel_straight_A",
			"BossGateButtress_%s" % str(side),
			Vector3(side * 24.0, 0.0, -78.0),
			0.0,
			3.4,
			true,
			0.8
		)
		lamp(root, "BossGateLamp_%s" % str(side), Vector3(side * 10.0, 0.0, -76.0), 3.0)
	# Ring of low blocks around the platform edge. Slot 0 sits at 90 deg, which
	# is the south ramp lane the traversal test walks, so it stays empty.
	for index in range(8):
		if index == 0:
			continue
		var angle := deg_to_rad(90.0 + 45.0 * float(index))
		var at := Vector3(cos(angle) * 26.0, 0.0, -63.0 + sin(angle) * 26.0)
		place(
			root,
			"containers_%s" % ["A", "B", "C", "D"][index % 4],
			"BossArenaBarrier_%02d" % index,
			at,
			-rad_to_deg(angle),
			3.0,
			true,
			0.75
		)


static func _dress_ruins(world: Node3D) -> void:
	var root := _group(world, "KayKitRuins")
	ruin_pile(root, "SouthWreck", Vector3(-56.0, 0.0, 44.0), 4401, 2.6)
	ruin_pile(root, "SectorDebris", Vector3(-40.0, 0.0, 62.0), 4402, 2.0)
	place(
		root,
		"lander_A",
		"WreckedLanderHull",
		Vector3(-66.0, 0.0, 34.0),
		122.0,
		2.6,
		true,
		0.8,
		0.0,
		true
	)
	place(
		root,
		"tunnel_diagonal_long_A",
		"CollapsedServiceTunnel",
		Vector3(-70.0, 0.0, 52.0),
		42.0,
		3.0,
		true,
		0.76,
		8.0
	)


static func _dress_power_grid(world: Node3D) -> void:
	var root := _group(world, "KayKitPower")
	var turbines := [
		Vector3(-88.0, 0.0, -74.0),
		Vector3(88.0, 0.0, -74.0),
		Vector3(-88.0, 0.0, 22.0),
		Vector3(88.0, 0.0, 26.0),
		Vector3(-34.0, 0.0, 70.0),
		Vector3(34.0, 0.0, 70.0),
	]
	for index in range(turbines.size()):
		power_prop(root, "FrontierTurbine_%02d" % index, turbines[index], float(index) * 41.0, true)
	for index in range(3):
		place(
			root,
			"solarpanel",
			"FrontierSolarFarm_%02d" % index,
			Vector3(-58.0 + float(index) * 6.0, 0.0, -26.0),
			-22.0 + float(index) * 8.0,
			3.2
		)


## Ground relief in the four quadrants the routes do not cross.
##
## The playable floor is one flat plane, which is correct for combat (nothing to
## trip on) but makes the map read as a table top. These fields of terrain tiles
## sit at y = -1 so their tops are flush with the floor, and they are kept off
## the eight route lanes and off both tested walkways.
static func _dress_terrain_shoulders(world: Node3D) -> void:
	var root := _group(world, "KayKitTerrainShoulders")
	var fields := [
		{"center": Vector3(-62.0, 0.0, -62.0), "w": 9, "h": 5, "seed": 4501},
		{"center": Vector3(62.0, 0.0, -70.0), "w": 7, "h": 4, "seed": 4502},
		{"center": Vector3(-66.0, 0.0, 62.0), "w": 8, "h": 4, "seed": 4503},
		{"center": Vector3(64.0, 0.0, 58.0), "w": 8, "h": 4, "seed": 4504},
	]
	for field in fields:
		var rng := RandomNumberGenerator.new()
		rng.seed = int(field["seed"])
		var width: int = field["w"]
		var height: int = field["h"]
		var center: Vector3 = field["center"]
		for ix in range(width):
			for iz in range(height):
				# 7 m grid: the tiles are 2 m at scale 3.5, so the field reads as
				# plateaus rather than as a checkerboard.
				var at := (
					center
					+ Vector3(
						(float(ix) - float(width - 1) * 0.5) * 7.0,
						-1.0,
						(float(iz) - float(height - 1) * 0.5) * 7.0
					)
				)
				var roll := rng.randf()
				var tile := "terrain_low"
				if roll < 0.12:
					tile = "terrain_mining"
				elif roll < 0.34:
					tile = "terrain_low_curved"
				elif roll < 0.44:
					tile = "rocks_B"
				place(
					root,
					tile,
					"Shoulder_%d_%02d_%02d" % [int(field["seed"]), ix, iz],
					at,
					rng.randf_range(0.0, 360.0),
					3.5,
					true,
					0.85,
				)


static func _dress_routes(world: Node3D) -> void:
	var root := _group(world, "KayKitRoutes")
	# Lamp posts line the roads a few metres off the tarmac, never on it.
	var west_lamps := [
		Vector3(-22.0, 0.0, -7.0),
		Vector3(-33.0, 0.0, -7.0),
		Vector3(-44.0, 0.0, -7.0),
		Vector3(-22.0, 0.0, 7.0),
		Vector3(-33.0, 0.0, 7.0)
	]
	for index in range(west_lamps.size()):
		lamp(root, "WestRouteLamp_%02d" % index, west_lamps[index], 2.4)
	var east_lamps := [
		Vector3(23.0, 0.0, -6.0),
		Vector3(34.0, 0.0, -6.0),
		Vector3(23.0, 0.0, 9.0),
		Vector3(34.0, 0.0, 9.0)
	]
	for index in range(east_lamps.size()):
		lamp(root, "EastRouteLamp_%02d" % index, east_lamps[index], 2.4)
	for index in range(4):
		var side := -1.0 if index % 2 == 0 else 1.0
		lamp(
			root,
			"NorthRouteLamp_%02d" % index,
			Vector3(side * 7.5, 0.0, -24.0 - float(index) * 7.0),
			2.6
		)
	# Roadside cargo: cover along the south approach, off the 8 m lane.
	for index in range(4):
		var side := -1.0 if index % 2 == 0 else 1.0
		place(
			root,
			"cargo_%s" % ("A" if index % 2 == 0 else "B"),
			"SouthApproachCargo_%02d" % index,
			Vector3(side * 11.0, 0.0, 22.0 + float(index) * 5.0),
			float(index) * 47.0,
			1.8,
			index % 2 == 0,
			0.8
		)


static func _group(world: Node3D, group_name: String) -> Node3D:
	var existing := world.get_node_or_null(group_name) as Node3D
	if existing != null:
		return existing
	var node := Node3D.new()
	node.name = group_name
	world.add_child(node)
	return node
