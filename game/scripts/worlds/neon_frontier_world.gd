extends Node3D
##
## neon_frontier_world.gd — the real world, loaded from one GLB.
##
## This file used to *build* the Frontier Outpost out of GDScript primitives: a
## procedural floor plane, procedurally generated component scenes, dressers and
## a bay builder. Every one of those surfaces was code, not art. It is gone.
##
## What runs now is the world assembled by `tools/asset-forge`, in which every
## visible mesh is a real licensed GLB:
##
##   game/assets/forge/world/world.glb   one scene, 530 meshes, 119 clips,
##                                       84 embedded maps, 21.6 MB
##
## This script only *places* that scene and lights it. It creates no geometry: the
## only nodes it adds to the tree itself are an invisible collision body, the
## lighting rig and two non-visual waypoint markers.
##
## Provenance: tools/asset-forge/real/real-manifest.json
##   Kenney Space Kit (CC0-1.0, kenney.nl)
##   Cinder Yard Power Plant + ground plate (CC-BY-4.0, Kammertonus)
##

const WORLD_SCENE: PackedScene = preload("res://assets/forge/world/world.glb")

const WORLD_WIDTH: float = 192.0
const WORLD_DEPTH: float = 180.0
const WORLD_CENTER_Z: float = -10.0

## The GLB carries its own clips (spinning dishes, sweeping turrets, pulsing
## crystals). Turn them off for a static capture or a screenshot test.
@export var animate_components: bool = true
## Playback speed multiplier for the authored clips.
@export var animation_speed: float = 1.0

var _built: bool = false
var _world: Node3D


func _ready() -> void:
	if _built or get_node_or_null("RealFrontierWorld") != null:
		return
	# Both theatres are instanced by `main.tscn` so the launcher can name either
	# one; only the selected one builds.
	if not _is_selected():
		return
	_built = true
	_instance_real_world()
	_add_collision_floor()
	_build_lighting_and_atmosphere()
	_add_wayfinders()


func _is_selected() -> bool:
	var selected := WorldSelection.selected(self)
	return selected == &"" or selected == &"neon_frontier"


## Place the one real asset. Everything the player sees inside this node came
## out of that file.
func _instance_real_world() -> void:
	_world = WORLD_SCENE.instantiate() as Node3D
	_world.name = "RealFrontierWorld"
	add_child(_world)
	for child in _world.find_children("*", "MeshInstance3D", true, false):
		var mesh_instance := child as MeshInstance3D
		mesh_instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	_start_authored_motion()


## One AnimationPlayer can only run one clip, and the world ships 119 of them --
## one per moving part (a dish here, a turret there). Each clip therefore gets its
## own player, rooted at the GLB so the tracks resolve, so every district moves at
## the same time instead of one prop winning the whole animation.
func _start_authored_motion() -> void:
	var found := _world.find_children("*", "AnimationPlayer", true, false)
	if found.is_empty():
		return
	var imported := found[0] as AnimationPlayer
	imported.name = "MotionLibrary"
	imported.active = false
	for clip_name in imported.get_animation_list():
		var animation := imported.get_animation(clip_name)
		if animation == null:
			continue
		animation.loop_mode = Animation.LOOP_LINEAR
		var player := AnimationPlayer.new()
		player.name = "Clip_%s" % clip_name.validate_node_name()
		var library := AnimationLibrary.new()
		library.add_animation(clip_name, animation)
		player.add_animation_library("", library)
		_world.add_child(player)
		player.speed_scale = animation_speed if animate_components else 0.0
		player.play(clip_name)
	if not animate_components:
		imported.speed_scale = 0.0


## Walking surface and outer bound. Invisible: it exists so the player has ground,
## not so the world has geometry.
func _add_collision_floor() -> void:
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

	# A ring of invisible walls keeps the player inside the fenced field.
	var walls := StaticBody3D.new()
	walls.name = "FrontierBounds"
	walls.collision_layer = 1
	walls.collision_mask = 0
	add_child(walls)
	var half_w := WORLD_WIDTH * 0.5
	var half_d := WORLD_DEPTH * 0.5
	for side in [
		{"name": "North", "pos": Vector3(0.0, 3.0, WORLD_CENTER_Z - half_d)},
		{"name": "South", "pos": Vector3(0.0, 3.0, WORLD_CENTER_Z + half_d)},
		{"name": "West", "pos": Vector3(-half_w, 3.0, WORLD_CENTER_Z)},
		{"name": "East", "pos": Vector3(half_w, 3.0, WORLD_CENTER_Z)},
	]:
		var wall := CollisionShape3D.new()
		wall.name = "%sWall" % side["name"]
		var wall_shape := BoxShape3D.new()
		wall_shape.size = (
			Vector3(WORLD_WIDTH, 6.0, 1.0)
			if side["name"] in ["North", "South"]
			else Vector3(1.0, 6.0, WORLD_DEPTH)
		)
		wall.shape = wall_shape
		wall.position = side["pos"]
		walls.add_child(wall)


## Lighting rig. Light is not an asset; it is how the scanned surfaces are read.
func _build_lighting_and_atmosphere() -> void:
	var sun := DirectionalLight3D.new()
	sun.name = "FrontierDaylightSun"
	sun.rotation_degrees = Vector3(-39.0, -31.0, 0.0)
	# Warm key, cool ambient: the split the key art uses. Energy stays under the
	# 1.1 ceiling the smoke test guards, with real shadowing because the world is
	# lit by the scanned maps rather than by bright flat albedo.
	sun.light_color = Color(0.98, 0.9, 0.8)
	sun.light_energy = 1.05
	sun.shadow_enabled = true
	sun.shadow_opacity = 0.58
	sun.directional_shadow_max_distance = 220.0
	add_child(sun)

	var fill := DirectionalLight3D.new()
	fill.name = "FrontierCoolFill"
	fill.rotation_degrees = Vector3(-24.0, 148.0, 0.0)
	fill.light_color = Color(0.55, 0.72, 0.95)
	fill.light_energy = 0.35
	fill.shadow_enabled = false
	add_child(fill)

	var reactor_fill := OmniLight3D.new()
	reactor_fill.name = "ReactorCyanBounce"
	reactor_fill.position = Vector3(0.0, 5.4, 0.0)
	reactor_fill.light_color = Color(0.33, 0.78, 1.0)
	reactor_fill.light_energy = 0.7
	reactor_fill.omni_range = 12.5
	reactor_fill.shadow_enabled = false
	add_child(reactor_fill)

	var environment := Environment.new()
	environment.background_mode = Environment.BG_COLOR
	environment.background_color = Color(0.035, 0.06, 0.09)
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color(0.30, 0.42, 0.52)
	environment.ambient_light_energy = 0.9
	environment.tonemap_mode = Environment.TONE_MAPPER_ACES
	environment.tonemap_white = 6.0
	environment.ssao_enabled = true
	environment.ssao_radius = 2.4
	environment.glow_enabled = true
	environment.glow_intensity = 0.55
	environment.glow_bloom = 0.12
	environment.fog_enabled = true
	environment.fog_light_color = Color(0.09, 0.14, 0.19)
	environment.fog_density = 0.006
	environment.adjustment_enabled = true
	environment.adjustment_saturation = 0.92
	environment.adjustment_contrast = 1.06

	var world_environment := WorldEnvironment.new()
	world_environment.name = "ArenaEnvironment"
	world_environment.environment = environment
	add_child(world_environment)


## Non-visual waypoints the HUD and the route hint read. Marker3D draws nothing.
func _add_wayfinders() -> void:
	for entry in [
		{"name": "NorthRouteWayfinder", "pos": Vector3(0.0, 1.6, -84.0)},
		{"name": "SouthRouteWayfinder", "pos": Vector3(0.0, 1.6, 44.0)},
	]:
		var marker := Marker3D.new()
		marker.name = entry["name"]
		marker.position = entry["pos"]
		add_child(marker)
