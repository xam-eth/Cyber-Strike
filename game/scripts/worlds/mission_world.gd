extends Node3D

signal world_ready(world_id: String)
signal world_load_failed(world_id: String, reason: String)

##
## mission_world.gd — one of the mission worlds, loaded from one GLB.
##
## This file used to *build* the Frontier Outpost out of GDScript primitives: a
## procedural floor plane, procedurally generated component scenes, dressers and
## a bay builder. Every one of those surfaces was code, not art. It is gone.
##
## What runs now are the mission worlds assembled by `tools/asset-forge`, in
## which every visible mesh is a real licensed GLB:
##
##   game/assets/forge/worlds/frostline.glb   — relay layout + authored clips
##   game/assets/forge/worlds/verdant.glb     — grove layout + authored clips
##   game/assets/forge/worlds/emberfall.glb   — foundry layout + authored clips
##   game/assets/forge/worlds/titans.glb      — storm layout + authored clips
##
## Byte-identical photographic maps are staged once in `assets/forge/textures/`
## and referenced by the mission GLBs; measured geometry and clip counts live in
## `assets/forge/forge_manifest.json` rather than drifting in this comment.
##
## Exactly one is loaded: the theatre the launcher selected, or Frostline Relay
## when nothing has been selected yet. There is one scene file for every mission
## because the *scene* is the same node graph — what differs is the GLB, and
## building near-identical .tscn files would only give more places for that graph
## to drift.
##
## This script only *places* that scene and lights it. It creates no geometry: the
## only nodes it adds to the tree itself are invisible collision bodies, the
## lighting rig and two non-visual waypoint markers.
##
## Provenance: tools/asset-forge/real/real-manifest.json
##   Kenney Space Kit + Nature Kit (CC0-1.0, kenney.nl)
##   Cinder Yard Power Plant + ground plate (CC-BY-4.0, Kammertonus)
##
## Mission worlds, each one GLB assembled from licensed real assets by
## `tools/asset-forge`. Only the selected one is instantiated for gameplay; the
## complete pack is already resident from the opening payload.
## Environment paths and field bounds live in WorldDefinition. This adapter
## owns only the default used by a fresh profile or an isolated test fixture.
const DEFAULT_MISSION_WORLD_ID := "frostline_relay"
## The forge's theme ids, accepted as aliases for the world ids. The registry
## selects with the world id itself (they are the same strings), so the map is
## not a second list of ids to keep in sync — it only adds the short names the
## capture tooling uses.
const SELECTION_ALIASES := {
	"frostline": "frostline_relay",
	"verdant": "verdant_bloom",
	"emberfall": "emberfall_foundry",
}

## Fallback field, used only when a test override has no WorldDefinition.
## The safety floor sits below authored geometry; real GLB triangles provide
## normal walking surfaces, cover, bridges, and interiors.
const WORLD_WIDTH: float = 192.0
const WORLD_DEPTH: float = 180.0
const WORLD_CENTER_Z: float = -10.0

## The GLB carries its own clips (spinning dishes, sweeping turrets, pulsing
## crystals). Turn them off for a static capture or a screenshot test.
@export var animate_components: bool = true
## Playback speed multiplier for the authored clips.
@export var animation_speed: float = 1.0
## Force a world (tests and captures). Empty = follow the launcher selection.
@export var world_override: String = ""

var load_error: String = ""
var loaded_world_id: String = ""
var _built: bool = false
var _world: Node3D


func _ready() -> void:
	if _built or get_node_or_null("RealFrontierWorld") != null:
		return
	# Both theatres are instanced by `main.tscn` so the launcher can name either
	# one; only the selected one builds.
	if not _is_selected():
		# Say why, with the id: the launcher and this script disagreeing is the
		# one failure here that leaves no trace in the scene.
		print(
			(
				"MISSION WORLD: not building %s (launcher selected '%s')"
				% [
					world_override if not world_override.is_empty() else DEFAULT_MISSION_WORLD_ID,
					String(WorldSelection.selected(self)),
				]
			)
		)
		return
	_built = true
	var loaded := _instance_real_world()
	# A rejected environment still gets safe bounds, lighting, wayfinders, and a
	# working HUD/player. Only the failed visual/collision module is absent.
	_add_collision_floor()
	if loaded:
		_add_mesh_colliders()
	_build_lighting_and_atmosphere()
	_add_wayfinders()
	if loaded:
		world_ready.emit(_world_id())


func _is_selected() -> bool:
	# An explicit override (captures, tests) always builds: it names the world it
	# wants and does not care what the launcher remembered.
	if not world_override.is_empty():
		return true
	# Otherwise only the selected theatre builds. An empty selection means a
	# fresh profile, which loads the first mission.
	var selected := String(WorldSelection.selected(self))
	return selected == "" or not world_for_selection(selected).is_empty()


## Which world a launcher selection means. A world id is its own selection; the
## forge's theme ids are aliases. Anything else — the station's id, a stale save
## — means this node is not the theatre the player chose, and it stays empty.
static func world_for_selection(selected: String) -> String:
	var candidate := String(SELECTION_ALIASES.get(selected, selected))
	var definition := WorldDefinition.load_definition(StringName(candidate))
	if definition != null and not definition.environment_scene_path.is_empty():
		return candidate
	return ""


## Which mission world this node is. An explicit override wins; otherwise the
## launcher's selection decides, and an empty selection means the default world.
func _world_id() -> String:
	if not world_override.is_empty():
		return world_override
	var selected := String(WorldSelection.selected(self))
	var resolved := world_for_selection(selected)
	if not resolved.is_empty():
		return resolved
	return DEFAULT_MISSION_WORLD_ID


## Place the declared real asset. Loading is dynamic and failure-returning so
## an external World cannot prevent the main scene or UI from loading.
func _instance_real_world() -> bool:
	var world_id := _world_id()
	loaded_world_id = ""
	load_error = ""
	var definition := WorldDefinition.load_definition(StringName(world_id))
	var scene_path := definition.environment_scene_path if definition != null else ""
	var result := ContentModuleLoader.load_scene(scene_path, ContentModuleLoader.WORLD_ROOTS)
	if not bool(result["ok"]):
		return _fail_world_load(world_id, String(result["code"]), String(result["message"]))
	var packed := result["scene"] as PackedScene
	var instance := packed.instantiate()
	if not instance is Node3D:
		if instance != null:
			instance.free()
		return _fail_world_load(world_id, "wrong_root", "World root must be Node3D.")
	_world = instance as Node3D
	_world.name = "RealFrontierWorld"
	_world.set_meta("world_id", world_id)
	add_child(_world)
	loaded_world_id = world_id
	print("MISSION WORLD: %s (%s)" % [world_id, scene_path.get_file()])
	for child in _world.find_children("*", "MeshInstance3D", true, false):
		var mesh_instance := child as MeshInstance3D
		mesh_instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	_start_authored_motion()
	return true


func _fail_world_load(world_id: String, code: String, message: String) -> bool:
	load_error = "%s: %s" % [code, message]
	push_warning("MISSION WORLD: %s disabled (%s)" % [world_id, load_error])
	world_load_failed.emit(world_id, load_error)
	return false


func has_world_geometry() -> bool:
	return is_instance_valid(_world)


## One AnimationPlayer can only run one clip, and the world ships 119 of them --
## one per moving part (a dish here, a turret there). Each clip therefore gets its
## own player, rooted at the GLB so the tracks resolve, so every district moves at
## the same time instead of one prop winning the whole animation.
func _start_authored_motion() -> void:
	if not is_instance_valid(_world):
		return
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


## Last-resort safety floor and outer bounds. Invisible: normal walking surfaces
## come from the authored GLB triangles, not from a flat plane covering routes.
func _field_size() -> Vector2:
	var definition := WorldDefinition.load_definition(StringName(_world_id()))
	if definition != null:
		return definition.field_size
	return Vector2(WORLD_WIDTH, WORLD_DEPTH)


func _field_center() -> Vector2:
	var definition := WorldDefinition.load_definition(StringName(_world_id()))
	if definition != null:
		return definition.field_center
	return Vector2(0.0, WORLD_CENTER_Z)


func _field_center_z() -> float:
	return _field_center().y


func _add_collision_floor() -> void:
	var field := _field_size()
	var center := _field_center()
	var center_z := center.y
	var floor_body := StaticBody3D.new()
	floor_body.name = "ArenaFloor"
	# Its top is y=-3, below every staged world's lowest mesh (about y=-0.6).
	# A safety plane at y=0 would hide missing or misplaced authored surfaces.
	floor_body.position = Vector3(center.x, -3.4, center_z)
	floor_body.collision_layer = 1
	floor_body.collision_mask = 0
	var floor_shape := CollisionShape3D.new()
	floor_shape.name = "ArenaFloorCollisionShape"
	var shape := BoxShape3D.new()
	shape.size = Vector3(field.x, 0.8, field.y)
	floor_shape.shape = shape
	floor_body.add_child(floor_shape)
	add_child(floor_body)

	# A ring of invisible walls keeps the player inside the fenced field.
	var walls := StaticBody3D.new()
	walls.name = "FrontierBounds"
	walls.collision_layer = 1
	walls.collision_mask = 0
	add_child(walls)
	var half_w := field.x * 0.5
	var half_d := field.y * 0.5
	for side in [
		{"name": "North", "pos": Vector3(0.0, 3.0, center_z - half_d)},
		{"name": "South", "pos": Vector3(0.0, 3.0, center_z + half_d)},
		{"name": "West", "pos": Vector3(center.x - half_w, 3.0, center_z)},
		{"name": "East", "pos": Vector3(center.x + half_w, 3.0, center_z)},
	]:
		var wall := CollisionShape3D.new()
		wall.name = "%sWall" % side["name"]
		var wall_shape := BoxShape3D.new()
		wall_shape.size = (
			Vector3(field.x, 6.0, 1.0)
			if side["name"] in ["North", "South"]
			else Vector3(1.0, 6.0, field.y)
		)
		wall.shape = wall_shape
		wall.position = side["pos"]
		walls.add_child(wall)


## Every STELLAR HORIZON variant shares the same physical layout. Use the
## authored triangles for all four: a box derived from a whole bridge, island or
## interior would fill the volume the player must occupy, while a box around a
## small rock or cover module would not match its visible silhouette.
func _add_mesh_colliders() -> void:
	if not is_instance_valid(_world):
		return
	var made := 0
	for candidate in _world.find_children("*", "MeshInstance3D", true, false):
		var mesh_instance := candidate as MeshInstance3D
		if mesh_instance.mesh == null:
			continue
		# DeckEdge is low decorative trim placed continuously across the declared
		# MainNorth/MainSouth routes. Keep it visible, but do not turn that trim
		# into a 0.6 m wall through the route (measured at z=15…20 in the GLB).
		if String(mesh_instance.get_path()).contains("/DeckEdge_"):
			continue
		mesh_instance.create_trimesh_collision()
		made += 1
	print("MISSION WORLD: %d %s mesh colliders derived from the real world" % [made, _world_id()])


## Lighting rig, built from the world's own mood. Light is not an asset; it is
## how the licensed surfaces are read, and it is the single strongest signal that
## the player has changed theatre: bright daytime, warm sunset, cyan night and
## a colder storm all illuminate the same STELLAR HORIZON route.
func _build_lighting_and_atmosphere() -> void:
	var mood := WorldMood.mood(_world_id())

	# Three directional lights: key (casts), fill and rim (do not). Each is aimed
	# at the field centre from the position the theme gives it.
	for role in ["key", "fill", "rim"]:
		var spec: Dictionary = mood[role]
		var light := DirectionalLight3D.new()
		light.name = String(spec["name"])
		light.light_color = spec["color"]
		light.light_energy = spec["energy"]
		light.shadow_enabled = role == "key"
		if light.shadow_enabled:
			light.shadow_opacity = 0.58
			light.directional_shadow_max_distance = 220.0
		add_child(light)
		var target := Vector3(0.0, 0.0, _field_center_z())
		var light_position: Vector3 = spec["position"]
		var up := Vector3.UP
		# The tower rim is directly overhead. Godot rejects a look-at whose up
		# vector is parallel to its direction, so choose a stable roll reference.
		if absf((target - light_position).normalized().dot(up)) > 0.999:
			up = Vector3.FORWARD
		light.look_at_from_position(light_position, target, up)
		light.rotation.z = 0.0

	# The landmark's own light: an emissive accent that blooms in the haze.
	var accent := OmniLight3D.new()
	accent.name = "MissionAccentLight"
	accent.position = Vector3(0.0, 5.4, 0.0)
	accent.light_color = mood["accent"]
	accent.light_energy = mood["accent_energy"]
	accent.omni_range = mood["accent_range"]
	accent.shadow_enabled = false
	add_child(accent)

	var environment := Environment.new()
	environment.background_mode = Environment.BG_COLOR
	environment.background_color = mood["sky"]
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = mood["ambient"]
	environment.ambient_light_energy = mood["ambient_energy"]
	environment.tonemap_mode = Environment.TONE_MAPPER_ACES
	environment.tonemap_exposure = mood["exposure"]
	environment.tonemap_white = 6.0
	environment.ssao_enabled = true
	environment.ssao_radius = 2.4
	environment.glow_enabled = true
	environment.glow_intensity = mood["glow"]
	environment.glow_bloom = 0.12
	environment.fog_enabled = true
	environment.fog_light_color = mood["fog"]
	environment.fog_density = mood["fog_density"]
	environment.adjustment_enabled = true
	environment.adjustment_saturation = mood["saturation"]
	environment.adjustment_contrast = mood["contrast"]

	var world_environment := WorldEnvironment.new()
	world_environment.name = "ArenaEnvironment"
	world_environment.environment = environment
	add_child(world_environment)
	print("MISSION WORLD: lit as %s" % WorldMood.label(_world_id()))


## Non-visual waypoints the HUD and the route hint read. Marker3D draws nothing.
func _add_wayfinders() -> void:
	# Match the forge's MainNorth (+Z) and MainSouth (-Z) route sockets.
	var north_z := 62.0
	var south_z := -62.0
	for entry in [
		{"name": "NorthRouteWayfinder", "pos": Vector3(0.0, 1.6, north_z)},
		{"name": "SouthRouteWayfinder", "pos": Vector3(0.0, 1.6, south_z)},
	]:
		var marker := Marker3D.new()
		marker.name = entry["name"]
		marker.position = entry["pos"]
		add_child(marker)
