@tool
extends Node3D

const ScifiFrontierDresser = preload("res://scripts/worlds/scifi_frontier_dresser.gd")
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
	NeonFrontierArena.build_central_arena(self)
	NeonFrontierRoutes.build_access_routes(self)
	NeonFrontierSettlement.build_outpost(self)
	NeonFrontierSettlement.build_extraction_zone(self)
	NeonFrontierPerimeter.build_boss_encounter_zone(self)
	NeonFrontierPerimeter.build_defense_perimeter(self)
	NeonFrontierWilds.build_destroyed_frontier_sector(self)
	NeonFrontierWilds.build_alien_landscape(self)
	_build_lighting_and_atmosphere()
	_build_spawn_beacons()
	ScifiBayBuilder.build(self)
	ScifiFrontierDresser.dress_districts(self)


func _create_materials() -> void:
	_materials = {
		# Slate metal should read as material under the cool key, not a single
		# saturated cornflower-blue expanse. Warm signals stay sparse on the lane.
		"ground": NeonFrontierMaterialKit.make_material(Color(0.26, 0.3, 0.34), 0.04, 0.9),
		"ground_light": NeonFrontierMaterialKit.make_material(Color(0.32, 0.37, 0.41), 0.06, 0.84),
		"ground_rose": NeonFrontierMaterialKit.make_material(Color(0.29, 0.3, 0.35), 0.05, 0.88),
		"silver": NeonFrontierMaterialKit.make_material(Color(0.36, 0.43, 0.48), 0.56, 0.43),
		"pearl": NeonFrontierMaterialKit.make_material(Color(0.58, 0.65, 0.7), 0.15, 0.5),
		"ceramic": NeonFrontierMaterialKit.make_material(Color(0.43, 0.52, 0.58), 0.23, 0.5),
		"blue": NeonFrontierMaterialKit.make_material(Color(0.06, 0.18, 0.36), 0.46, 0.4),
		"deep_blue": NeonFrontierMaterialKit.make_material(Color(0.025, 0.09, 0.21), 0.5, 0.44),
		"cyan": NeonFrontierMaterialKit.make_emissive(Color(0.02, 0.56, 0.73), 0.82),
		"turquoise": NeonFrontierMaterialKit.make_emissive(Color(0.015, 0.62, 0.55), 0.72),
		"green": NeonFrontierMaterialKit.make_emissive(Color(0.13, 0.64, 0.4), 0.75),
		"yellow": NeonFrontierMaterialKit.make_emissive(Color(0.9, 0.54, 0.065), 0.43),
		"orange": NeonFrontierMaterialKit.make_emissive(Color(1.0, 0.27, 0.04), 0.9),
		"red": NeonFrontierMaterialKit.make_emissive(Color(0.98, 0.05, 0.06), 1.0),
		"dark_trim": NeonFrontierMaterialKit.make_material(Color(0.11, 0.18, 0.2), 0.66, 0.38),
		"copper": NeonFrontierMaterialKit.make_material(Color(0.76, 0.32, 0.13), 0.65, 0.34),
		"rock": NeonFrontierMaterialKit.make_material(Color(0.59, 0.43, 0.34), 0.02, 0.93),
	}


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
	# The invisible collider and visible FBX fencing keep exploration bounded
	# without exposing an untextured blocking box.
	ScifiFrontierDresser.build_boundary(self, WORLD_WIDTH, WORLD_DEPTH, WORLD_CENTER_Z)


func _build_lighting_and_atmosphere() -> void:
	var sun := DirectionalLight3D.new()
	sun.name = "FrontierDaylightSun"
	sun.rotation_degrees = Vector3(-39.0, -31.0, 0.0)
	sun.light_color = Color(0.96, 0.88, 0.76)
	sun.light_energy = 0.68
	sun.shadow_enabled = true
	# Dense FBX ribs used to project solid-black, razor-edged patches across
	# the playable floor in Compatibility. Keep depth cues, but let neutral
	# ambient fill through the key's shadow instead of hiding the tile material.
	sun.shadow_opacity = 0.58
	sun.directional_shadow_max_distance = 115.0
	sun.shadow_bias = 0.04
	add_child(sun)

	var environment := Environment.new()
	environment.background_mode = Environment.BG_SKY
	var sky := Sky.new()
	var sky_material := ProceduralSkyMaterial.new()
	# Warframe-inspired hierarchy, not a copied LUT: a cool low-key sky and
	# broad key light give the armor a silhouette; small amber/cyan fixtures
	# mark traversable paths and interactable structures. Web Compatibility has
	# no dependable real-time GI or volumetric fog, so keep the base legible.
	sky_material.sky_top_color = Color(0.04, 0.1, 0.18)
	sky_material.sky_horizon_color = Color(0.17, 0.29, 0.39)
	sky_material.ground_bottom_color = Color(0.11, 0.18, 0.26)
	sky_material.ground_horizon_color = Color(0.18, 0.27, 0.35)
	sky_material.sun_angle_max = 10.0
	sky_material.sun_curve = 0.14
	sky.sky_material = sky_material
	environment.sky = sky
	# Compatibility can leave SKY-sourced ambient nearly black. A neutral
	# slate fill keeps the FBX plating readable while the reactor owns the cyan
	# accent; a blue global fill washed every floor plate into the same hue.
	# Trial a lower key/fill ratio and cooler shadows: the WebGL capture was
	# flat daylight despite the FBX geometry and warm route lights. Verify
	# actual armor, floor, and interactable contrast before retaining it.
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color(0.4, 0.46, 0.52)
	environment.ambient_light_energy = 0.49
	environment.reflected_light_source = Environment.REFLECTION_SOURCE_BG
	environment.tonemap_mode = Environment.TONE_MAPPER_ACES
	environment.tonemap_exposure = 1.01
	environment.adjustment_enabled = true
	environment.adjustment_brightness = 0.97
	environment.adjustment_contrast = 1.09
	environment.adjustment_saturation = 0.9
	environment.glow_enabled = true
	environment.glow_intensity = 0.06
	environment.fog_enabled = true
	environment.fog_light_color = Color(0.10, 0.19, 0.27)
	environment.fog_density = 0.007
	environment.fog_aerial_perspective = 0.18
	var world_environment := WorldEnvironment.new()
	world_environment.name = "ArenaEnvironment"
	world_environment.environment = environment
	add_child(world_environment)

	# Local light, not a cyan wash across the whole 38 m bay. Warm navigation
	# lamps retain their contrast against the now-neutral shared FBX floor.
	_add_omni_light(
		"ReactorCyanBounce", Vector3(0.0, 7.0, 0.0), Color(0.22, 0.52, 0.72), 0.65, 13.0
	)
	_add_omni_light(
		"ReactorEmeraldBounce", Vector3(-1.5, 7.0, 0.0), Color(0.13, 0.58, 0.43), 0.24, 7.5
	)
	_add_omni_light(
		"ExtractionGreenBounce", Vector3(43.0, 6.0, -35.0), Color(0.1, 0.82, 0.64), 1.3, 19.0
	)
	_add_omni_light(
		"BossGateBlueBounce", Vector3(0.0, 9.0, -82.0), Color(0.12, 0.48, 0.88), 1.4, 21.0
	)
	_add_omni_light(
		"NorthRouteWayfinder", Vector3(0.0, 3.8, -22.0), Color(1.0, 0.48, 0.2), 1.2, 12.0
	)
	_add_omni_light(
		"SouthRouteWayfinder", Vector3(0.0, 3.8, 22.0), Color(1.0, 0.48, 0.2), 1.2, 12.0
	)
	_add_omni_light("OutpostWayfinder", Vector3(-41.0, 3.8, 5.0), Color(1.0, 0.55, 0.23), 1.0, 13.0)

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
		# The player spawns at z=8 and the follow camera sits beside the south
		# marker at z=12. Its decorative orange/cyan puck filled the lower-left
		# 375px playfield and joystick; keep the *spawn marker* for combat but
		# omit only this too-near cosmetic mesh and orb.
		if marker.name == "SpawnSouth":
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
