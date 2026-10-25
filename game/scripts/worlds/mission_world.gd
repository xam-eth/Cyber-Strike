extends Node3D
##
## mission_world.gd — one of the three mission worlds, loaded from one GLB.
##
## This file used to *build* the Frontier Outpost out of GDScript primitives: a
## procedural floor plane, procedurally generated component scenes, dressers and
## a bay builder. Every one of those surfaces was code, not art. It is gone.
##
## What runs now are the three worlds assembled by `tools/asset-forge`, in which
## every visible mesh is a real licensed GLB:
##
##   game/assets/forge/worlds/frostline.glb   113,086 tris · 61 clips ·  5.8 MB
##   game/assets/forge/worlds/verdant.glb     128,182 tris · 156 clips · 3.0 MB
##   game/assets/forge/worlds/emberfall.glb   227,811 tris · 31 clips · 20.5 MB
##
## Exactly one is loaded: the theatre the launcher selected, or Frostline Relay
## when nothing has been selected yet. There is one scene file for all three
## because the *scene* is the same node graph — what differs is the GLB, and
## building three near-identical .tscn files would only give three places for
## that graph to drift.
##
## This script only *places* that scene and lights it. It creates no geometry: the
## only nodes it adds to the tree itself are an invisible collision body, the
## lighting rig and two non-visual waypoint markers.
##
## Provenance: tools/asset-forge/real/real-manifest.json
##   Kenney Space Kit + Nature Kit (CC0-1.0, kenney.nl)
##   Cinder Yard Power Plant + ground plate (CC-BY-4.0, Kammertonus)
##
## Three mission worlds, each one GLB assembled from licensed real assets by
## `tools/asset-forge`. Only the selected one is loaded: together they are 30 MB
## of geometry and maps, and the player is in exactly one of them.
const WORLD_SCENES := {
	"frostline_relay": "res://assets/forge/worlds/frostline.glb",
	"verdant_bloom": "res://assets/forge/worlds/verdant.glb",
	"emberfall_foundry": "res://assets/forge/worlds/emberfall.glb",
}
## Mission order; the first is the default theatre.
const WORLD_ORDER: Array[String] = ["frostline_relay", "verdant_bloom", "emberfall_foundry"]
## The forge's theme ids, accepted as aliases for the world ids. The registry
## selects with the world id itself (they are the same strings), so the map is
## not a second list of ids to keep in sync — it only adds the short names the
## capture tooling uses.
const SELECTION_ALIASES := {
	"frostline": "frostline_relay",
	"verdant": "verdant_bloom",
	"emberfall": "emberfall_foundry",
}

## Collision for the real props. The GLB is a visual scene: it has no physics, so
## the player would walk through a hangar. One box per placed role, taken from the
## bounds of that role's own meshes — no mesh is created, and the collider is
## invisible. Props the player must be able to move through (the reactor housing,
## the wave gates, the boss gate) are skipped on purpose.
const COLLIDER_SKIP := ["Reactor", "WaveEntry", "DockingGate", "Perimeter", "Gate"]
## Anything this close to the origin is the arena's centrepiece — the monument
## every world is composed around, which the forge places at (0, 0) — and keeps
## no collider. This is measured from the origin, not from the field centre: the
## centrepiece is the arena, and the field's centre is wherever the fence happens
## to be balanced. Not a shortcut either: a box around the monument walls off the
## arena, closes the north lane the boss gate sits at the end of, and stops shots
## at the training target standing across it. The meshes are still there; only
## the derived box is skipped, exactly as the old reactor's was.
const ARENA_MONUMENT_RADIUS: float = 7.0

## Walking surface per world, measured from each staged GLB. The fenced field is
## not the same size in three worlds — an extraction site is wider than a relay
## station — so the collision floor and the bound walls follow the world rather
## than the script. Values are `Vector2(width, depth)` in metres, plus the
## `(x, z)` the field is centred on. These are the fences the forge builds, not
## the GLB's total bounds: the foundry's plant is a landmark beyond the east wall,
## so the meshes reach further than the ground the player may walk on.
const WORLD_FIELDS := {
	"frostline_relay": {"size": Vector2(168.0, 156.0), "center": Vector2(0.0, -8.0)},
	"verdant_bloom": {"size": Vector2(176.0, 164.0), "center": Vector2(0.0, -6.0)},
	"emberfall_foundry": {"size": Vector2(200.0, 176.0), "center": Vector2(0.0, -10.0)},
}
## Fallback field, used if a world id ever arrives without an entry above.
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
					world_override if not world_override.is_empty() else WORLD_ORDER[0],
					String(WorldSelection.selected(self)),
				]
			)
		)
		return
	_built = true
	_instance_real_world()
	_add_collision_floor()
	_add_prop_colliders()
	_build_lighting_and_atmosphere()
	_add_wayfinders()


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
	if WORLD_SCENES.has(selected):
		return selected
	return String(SELECTION_ALIASES.get(selected, ""))


## Which mission world this node is. An explicit override wins; otherwise the
## launcher's selection decides, and an empty selection means the default world.
func _world_id() -> String:
	if not world_override.is_empty():
		return world_override
	var selected := String(WorldSelection.selected(self))
	var resolved := world_for_selection(selected)
	if not resolved.is_empty():
		return resolved
	return WORLD_ORDER[0]


## Place the real asset. Everything the player sees inside this node came out of
## that one file.
func _instance_real_world() -> void:
	var world_id := _world_id()
	var scene_path: String = WORLD_SCENES.get(world_id, WORLD_SCENES[WORLD_ORDER[0]])
	var packed := load(scene_path) as PackedScene
	if packed == null:
		push_error("MISSION WORLD: world '%s' did not import (%s)" % [world_id, scene_path])
		return
	_world = packed.instantiate() as Node3D
	_world.name = "RealFrontierWorld"
	_world.set_meta("world_id", world_id)
	add_child(_world)
	print("MISSION WORLD: %s (%s)" % [world_id, scene_path.get_file()])
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
func _field_size() -> Vector2:
	return WORLD_FIELDS.get(_world_id(), {"size": Vector2(WORLD_WIDTH, WORLD_DEPTH)})["size"]


func _field_center() -> Vector2:
	return WORLD_FIELDS.get(_world_id(), {"center": Vector2(0.0, WORLD_CENTER_Z)})["center"]


func _field_center_z() -> float:
	return _field_center().y


func _add_collision_floor() -> void:
	var field := _field_size()
	var center := _field_center()
	var center_z := center.y
	var floor_body := StaticBody3D.new()
	floor_body.name = "ArenaFloor"
	floor_body.position = Vector3(center.x, -0.4, center_z)
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


func _add_prop_colliders() -> void:
	var body := StaticBody3D.new()
	body.name = "FrontierPropCollision"
	body.collision_layer = 1
	body.collision_mask = 0
	add_child(body)
	var made := 0
	for district in _world.find_children("District_*", "Node3D", true, false):
		if str(district.name).ends_with("landmark"):
			continue
		for role in district.get_children():
			var role_name := str(role.name)
			var skip := false
			for needle in COLLIDER_SKIP:
				if role_name.contains(needle):
					skip = true
					break
			if skip or not role is Node3D:
				continue
			var beside_centre := (
				Vector2((role as Node3D).global_position.x, (role as Node3D).global_position.z)
				. length()
			)
			if beside_centre < ARENA_MONUMENT_RADIUS:
				continue
			var box := _role_bounds(role as Node3D)
			if box.size.y < 1.2 or box.size.x < 0.6:
				continue
			var shape := BoxShape3D.new()
			shape.size = Vector3(
				maxf(box.size.x * 0.85, 0.4),
				maxf(box.size.y * 0.92, 0.4),
				maxf(box.size.z * 0.85, 0.4)
			)
			var collider := CollisionShape3D.new()
			collider.name = "Cover_%s" % role_name
			collider.shape = shape
			collider.position = box.get_center()
			body.add_child(collider)
			made += 1
	if made > 0:
		print("MISSION WORLD: %d prop colliders derived from the real world" % made)


## World-space bounds of a placed role, from the meshes it is made of.
func _role_bounds(role: Node3D) -> AABB:
	var merged := AABB()
	var has_box := false
	for candidate in role.find_children("*", "MeshInstance3D", true, false):
		var mesh_instance := candidate as MeshInstance3D
		if mesh_instance.mesh == null:
			continue
		var box := mesh_instance.global_transform * mesh_instance.get_aabb()
		merged = box if not has_box else merged.merge(box)
		has_box = true
	return merged


## Lighting rig, built from the world's own mood. Light is not an asset; it is
## how the licensed surfaces are read, and it is the single strongest signal that
## the player has changed theatre: frostline is a cool key over a cyan ambient,
## verdant a hot green-white sun under a warm canopy, emberfall an orange key
## against a violet rim with molten fill from below.
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
		light.look_at_from_position(
			spec["position"], Vector3(0.0, 0.0, _field_center_z()), Vector3.UP
		)
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
	for entry in [
		{"name": "NorthRouteWayfinder", "pos": Vector3(0.0, 1.6, -84.0)},
		{"name": "SouthRouteWayfinder", "pos": Vector3(0.0, 1.6, 44.0)},
	]:
		var marker := Marker3D.new()
		marker.name = entry["name"]
		marker.position = entry["pos"]
		add_child(marker)
