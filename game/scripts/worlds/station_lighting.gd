class_name StationLighting
extends RefCounted

## Sky, key light and the omnis for Vanguard Station, kept out of the world
## composer because they are a separate concern with their own tuning history:
## the theatre was lit by the engine's default sky until it had an Environment,
## and the first one it got blew the deck out to white.
##
## Every omni here is unshadowed. The pack's own light modules are in every room
## as geometry, so these only lift what the emissive strips cannot reach.


## Sky, key light and fill for a theatre that is mostly indoors.
##
## The hangar has no environment of its own until this runs, which is why the
## first captures were lit by the engine's default sky and read as flat grey: the
## roof ring blocks that sky from everything except the skylight, so the room had
## no key and almost no fill. The sun here is aimed through the open roof, so it
## lands as a pool in the middle of the deck and leaves the walls in shadow --
## the contrast the palette was drawn for.
static func atmosphere(world: Node3D) -> void:
	var sun := DirectionalLight3D.new()
	sun.name = "StationDaylightSun"
	sun.rotation_degrees = Vector3(-58.0, -34.0, 0.0)
	sun.light_color = Color(0.94, 0.96, 1.0)
	sun.light_energy = 0.58
	sun.shadow_enabled = true
	sun.shadow_opacity = 0.6
	sun.directional_shadow_max_distance = 80.0
	sun.shadow_bias = 0.04
	world.add_child(sun)

	var environment := Environment.new()
	environment.background_mode = Environment.BG_SKY
	var sky := Sky.new()
	var sky_material := ProceduralSkyMaterial.new()
	# Deep space above, a cold horizon, nothing warm: the only warmth in this
	# theatre is the amber the pack puts on the crate and sign family.
	sky_material.sky_top_color = Color(0.012, 0.035, 0.075)
	sky_material.sky_horizon_color = Color(0.06, 0.12, 0.19)
	sky_material.ground_bottom_color = Color(0.01, 0.02, 0.035)
	sky_material.ground_horizon_color = Color(0.04, 0.07, 0.11)
	sky.sky_material = sky_material
	environment.sky = sky
	# Ambient is the only light reaching the corridor and the cargo bay, so it is
	# a fill with a job rather than a mood: enough to read plating, cool enough to
	# stay behind the sun and the strips.
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color(0.2, 0.26, 0.35)
	environment.ambient_light_energy = 0.75
	environment.reflected_light_source = Environment.REFLECTION_SOURCE_BG
	environment.tonemap_mode = Environment.TONE_MAPPER_ACES
	environment.tonemap_exposure = 1.02
	environment.adjustment_enabled = true
	environment.adjustment_brightness = 1.02
	environment.adjustment_contrast = 1.03
	environment.adjustment_saturation = 0.92
	environment.glow_enabled = true
	environment.glow_intensity = 0.08
	environment.fog_enabled = true
	# Indoor scale: the facility's longest sight line is 50 m, so the fog is a
	# hint of depth, not weather.
	environment.fog_light_color = Color(0.05, 0.1, 0.16)
	environment.fog_density = 0.006
	environment.fog_aerial_perspective = 0.4
	environment.fog_sky_affect = 0.3
	var world_environment := WorldEnvironment.new()
	world_environment.name = "StationEnvironment"
	world_environment.environment = environment
	world.add_child(world_environment)


static func lights(parent: Node3D) -> void:
	var cold := Color(0.72, 0.86, 1.0)
	var warm := Color(1.0, 0.62, 0.28)
	_light(parent, "HangarLightNW", Vector3(-9.0, 4.2, -9.0), cold, 3.6, 30.0)
	_light(parent, "HangarLightNE", Vector3(9.0, 4.2, -9.0), cold, 3.6, 30.0)
	_light(parent, "HangarLightSW", Vector3(-9.0, 4.2, 9.0), cold, 3.6, 30.0)
	_light(parent, "HangarLightSE", Vector3(9.0, 4.2, 9.0), cold, 3.6, 30.0)
	# One warm source in a cold room: it is what makes the deck read as metal
	# rather than as slate, and it is the only hue in the theatre that is not cyan.
	_light(parent, "HangarGateLight", Vector3(0.0, 3.4, 16.0), warm, 3.2, 20.0)
	_light(parent, "HangarWarmFill", Vector3(-2.0, 2.2, -6.0), Color(1.0, 0.78, 0.5), 2.2, 16.0)
	# A warm threshold at the reactor door: the frame's vanishing point is that
	# opening, and it was the coldest surface in the image.
	_light(parent, "HallDoorWarm", Vector3(0.0, 2.7, -16.4), Color(1.0, 0.66, 0.34), 2.4, 13.0)
	_light(parent, "ReactorLight", Vector3(0.0, 3.7, -28.0), Color(0.5, 0.82, 1.0), 12.0, 34.0)
	# The hall is sealed except for its skylight, so the sun never reaches its
	# back wall: without a second source the turbine face is a black rectangle.
	_light(parent, "ReactorFaceLight", Vector3(0.0, 3.2, -34.2), Color(0.62, 0.86, 1.0), 7.0, 20.0)
	_light(parent, "CargoLight", Vector3(-28.0, 3.5, 0.0), cold, 9.0, 28.0)
	# The bay's cargo stands against its long walls, which the centre lamp does
	# not reach: one more over each stack row.
	_light(parent, "CargoLightNorth", Vector3(-30.0, 3.4, -4.6), cold, 5.0, 16.0)
	_light(parent, "CargoLightSouth", Vector3(-30.0, 3.4, 4.6), cold, 5.0, 16.0)
	# Overhead light leaves a stack's vertical faces black — every lamp in the bay
	# is above the cargo. Two low washes at 1.7 m, one per row, light the sides.
	_light(parent, "CargoWashNorth", Vector3(-24.0, 1.7, -4.6), cold, 2.6, 13.0)
	_light(parent, "CargoWashSouth", Vector3(-24.0, 1.7, 4.6), cold, 2.6, 13.0)
	_light(parent, "CorridorLightWest", Vector3(25.0, 3.4, 0.0), cold, 7.0, 20.0)
	_light(parent, "CorridorLightEast", Vector3(37.0, 3.4, 0.0), cold, 7.0, 20.0)
	# A rim light behind the reactor, so the turbine face is not a silhouette.
	_light(parent, "ReactorRim", Vector3(0.0, 2.0, -36.0), Color(0.3, 0.7, 1.0), 1.8, 12.0)


static func _light(
	parent: Node3D, node_name: String, at: Vector3, color: Color, energy: float, reach: float
) -> void:
	var omni := OmniLight3D.new()
	omni.name = node_name
	omni.position = at
	omni.light_color = color
	omni.light_energy = energy
	omni.omni_range = reach
	omni.shadow_enabled = false
	parent.add_child(omni)
