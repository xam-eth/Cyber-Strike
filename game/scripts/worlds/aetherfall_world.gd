extends Node3D
## aetherfall_world.gd — SH-01 "Aetherfall, the Broken Frontier".
##
## One vertical theatre built entirely from the Aetherfall modular kit in
## `res://assets/world/aetherfall/`. Nothing is authored here: the Blender
## forge (`tools/blender/build_aetherfall.py`) bakes the textures, builds the
## 27 modules, centres each one on its own AABB, exports one GLB per module and
## writes `layout.json` + `measurements.json`. This script is the Godot half of
## the same contract:
##
##   * every placement comes from `layout.json` — no coordinates live in two
##     places,
##   * every collider is a box sized from `measurements.json`, which is the same
##     number the module was centred on, so the collider and the mesh agree by
##     construction,
##   * decorative geology (terrain, cliffs, boulders, clouds, background
##     silhouettes) carries no collider: it is set dressing, not walls.
##
## The world is one big platform on the south canyon rim, a 48 m Energy Tower
## rising off its north edge, two elevated routes (an intact bridge east, a
## hazardous catwalk west), a switchback descent into the lower canyon, and a
## deep main canyon behind the tower.

const LAYOUT_PATH := "res://assets/world/aetherfall/layout.json"
const MEASURE_PATH := "res://assets/world/aetherfall/measurements.json"
const MODEL_BASE := "res://assets/world/aetherfall/models/"

## Roles that are set dressing: they are never given a collider. A rock that
## blocks a route is a design bug, and a cloud that stops the player is worse.
const SET_DRESS := {
	"terrain_chunk": true, "cliff_face": true, "rock_boulder": true,
	"background_silhouette": true, "cloud_puff": true, "debris_cluster": true,
}

## Roles whose collider is a slab rather than the full module box: the player
## walks on top of these, they are not walls.
const WALKABLE := {
	"deck_6x6": true, "deck_edge": true, "walkway_deck": true,
	"bridge_deck": true, "railing": true,
}

const COLLIDE_LAYER := 1
const TRIGGER_LAYER := 4

var _built := false
var _layout: Dictionary = {}
var _measures: Dictionary = {}
var _collider_count := 0


func _ready() -> void:
	if _built or not _is_selected():
		return
	_built = true
	_read_manifests()
	_instance_modules()
	_add_colliders()
	_add_spawn_and_routes()
	# When the launcher wraps this scene in `mission_world.tscn`, that wrapper
	# already raises the key/fill/rim rig and the fenced deck floor, and aims them
	# at this world's field. Building a second set here would light the canyon
	# twice. Loaded on its own, this script is the whole theatre.
	if not _has_mission_wrapper():
		_add_lighting_and_atmosphere()
	_report()


func _has_mission_wrapper() -> bool:
	var parent := get_parent()
	return parent != null and str(parent.name) == "MissionWorld"


func _is_selected() -> bool:
	return String(WorldSelection.selected(self)) == "aetherfall"


func _read_manifests() -> void:
	var files := FileAccess.get_file_as_string(LAYOUT_PATH)
	if files.is_empty():
		push_error("Aetherfall: layout.json is missing or unreadable.")
		return
	_layout = JSON.parse_string(files)
	if _layout.is_null():
		push_error("Aetherfall: layout.json did not parse.")
		return
	var measures := FileAccess.get_file_as_string(MEASURE_PATH)
	if measures.is_empty():
		push_error("Aetherfall: measurements.json is missing or unreadable.")
		return
	_measures = JSON.parse_string(measures)


func _build() -> void:
	print("Aetherfall: building SH-01 from %d placements." % _layout.get("placements", []).size())
	_instance_modules()
	_add_colliders()
	_add_lighting_and_atmosphere()
	_add_spawn_and_routes()
	_report()


## Every placement is one instantiated module GLB at the authored transform.
func _instance_modules() -> void:
	var packs := {}
	for key in _measures.get("assets", {}).keys():
		var scene := load(MODEL_BASE + key + ".glb") as PackedScene
		if scene == null:
			push_warning("Aetherfall: module '%s' did not import." % key)
			continue
		packs[key] = scene

	var root := Node3D.new()
	root.name = "AetherfallWorld"
	add_child(root)

	var placed := 0
	for placement in _layout.get("placements", []):
		var key: String = placement.get("asset", "")
		var pack := packs.get(key) as PackedScene
		if pack == null:
			continue
		var instance := pack.instantiate() as Node3D
		instance.name = placement.get("name", key)
		instance.position = Vector3(
			placement.get("pos", Vector3.ZERO)
		)
		var rot := placement.get("rot", Vector3.ZERO)
		instance.rotation = Vector3(
			deg_to_rad(rot.x), deg_to_rad(rot.y), deg_to_rad(rot.z)
		)
		var scale := placement.get("scale", 1.0)
		instance.scale = Vector3(scale, scale, scale)
		root.add_child(instance)
		placed += 1
	print("Aetherfall: placed %d modules." % placed)


## Box colliders derived from the same measurements the mesh was centred on.
## Walkable roles get a slab centred on their top surface.
func _add_colliders() -> void:
	var bodies := Node3D.new()
	bodies.name = "AetherfallColliders"
	add_child(bodies)

	for placement in _layout.get("placements", []):
		var key: String = placement.get("asset", "")
		if SET_DRESS.has(key):
			continue
		var measure := _measures.get("assets", {}).get(key) as Dictionary
		if measure == null:
			continue
		var size: Vector3 = Vector3(measure.get("size", Vector3.ONE))
		if size.x <= 0.0 or size.y <= 0.0 or size.z <= 0.0:
			continue
		var body := StaticBody3D.new()
		body.name = "Collider_" + placement.get("name", key)
		var pos := Vector3(placement.get("pos", Vector3.ZERO))
		var scale := placement.get("scale", 1.0)
		var center := Vector3(measure.get("center", Vector3.ZERO))

		if WALKABLE.has(key):
			# A slab: the box sits so its top face is the walking surface.
			center.y = size.y / 2.0
			size.y = maxf(size.y * 0.5, 0.25)
			pos.y += measure.get("size", Vector3.ONE).y * 0.5 * scale
		else:
			center.y = 0.0

		body.position = pos
		var shape := BoxShape3D.new()
		shape.size = size * scale
		shape.center = center * scale
		var collider := CollisionShape3D.new()
		collider.name = "Shape"
		collider.shape = shape
		body.add_child(collider)
		body.collision_layer = COLLIDE_LAYER
		body.collision_mask = 0
		bodies.add_child(body)
		_collider_count += 1


func _add_lighting_and_atmosphere() -> void:
	var mood := WorldMood.mood("aetherfall")
	if mood.is_empty():
		push_warning("Aetherfall: no 'aetherfall' mood registered in WorldMood.")
		return

	for role in ["key", "fill", "rim"]:
		var spec: Dictionary = mood[role]
		var light := DirectionalLight3D.new()
		light.name = String(spec.get("name", role))
		light.light_color = spec.get("color", Color.WHITE)
		light.light_energy = float(spec.get("energy", 1.0))
		light.shadow_enabled = role == "key"
		if light.shadow_enabled:
			light.shadow_opacity = 0.58
			light.directional_shadow_max_distance = 220.0
		light.look_at_from_position(
			spec.get("position", Vector3(40.0, 60.0, 40.0)),
			_field_center(),
			Vector3.UP
		)
		add_child(light)

	var accent := OmniLight3D.new()
	accent.name = "MissionAccentLight"
	accent.position = Vector3(0.0, 26.0, -26.0)
	accent.light_color = mood.get("accent", Color.WHITE)
	accent.light_energy = float(mood.get("accent_energy", 1.0))
	accent.omni_range = float(mood.get("accent_range", 26.0))
	accent.shadow_enabled = false
	add_child(accent)

	var environment := Environment.new()
	environment.background_mode = Environment.BG_COLOR
	environment.background_color = mood.get("sky", Color(0.1, 0.2, 0.3))
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = mood.get("ambient", Color.WHITE)
	environment.ambient_light_energy = float(mood.get("ambient_energy", 1.0))
	environment.tonemap_mode = Environment.TONE_MAPPER_ACES
	environment.tonemap_white = 6.0
	environment.fog_enabled = true
	environment.fog_light_color = mood.get("fog", Color.WHITE)
	environment.fog_density = float(mood.get("fog_density", 0.0))
	environment.adjustment_enabled = true
	environment.adjustment_saturation = float(mood.get("saturation", 1.0))
	environment.adjustment_contrast = float(mood.get("contrast", 1.0))
	environment.glow_enabled = true
	environment.glow_intensity = float(mood.get("glow", 0.7))
	environment.glow_bloom = 0.12

	var world_environment := WorldEnvironment.new()
	world_environment.name = "AetherfallEnvironment"
	world_environment.environment = environment
	add_child(world_environment)
	print("AETHER FALL: lit as %s" % WorldMood.label("aetherfall"))


func _field_center() -> Vector3:
	var platform: Dictionary = _layout.get("platform", {})
	var center := Vector3(platform.get("center", Vector3.ZERO))
	center.y = float(platform.get("deck_top_y", 0.0))
	return center


func _directional(name: String, color: Color, energy: float,
		pos: Vector3, target: Vector3, shadows: bool) -> DirectionalLight3D:
	var light := DirectionalLight3D.new()
	light.name = name
	light.light_color = color
	light.light_energy = energy
	light.position = pos
	var direction := (target - pos)
	if direction.length() < 0.001:
		direction = Vector3.DOWN
	light.look_at(target, Vector3.UP)
	light.shadow_enabled = shadows
	return light


func _add_spawn_and_routes() -> void:
	var spawns := Node3D.new()
	spawns.name = "SpawnMarkers"
	add_child(spawns)
	var primary: Vector3 = _layout.get("spawn", {}).get("primary", Vector3(-30.0, 1.2, 14.0))
	var secondary: Vector3 = _layout.get("spawn", {}).get("secondary", Vector3(30.0, 1.2, 14.0))
	spawns.add_child(_marker("SpawnPrimary", primary))
	spawns.add_child(_marker("SpawnSecondary", secondary))

	var routes := Node3D.new()
	routes.name = "Routes"
	add_child(routes)
	for route in _layout.get("routes", []):
		var holder := Node3D.new()
		holder.name = "Route_" + route.get("name", "route")
		routes.add_child(holder)
		var start: Vector3 = route.get("from", Vector3.ZERO)
		var end: Vector3 = route.get("to", Vector3.ZERO)
		start.y = maxf(start.y, 0.3)
		end.y = maxf(end.y, 0.3)
		holder.add_child(_marker("Start", start))
		holder.add_child(_marker("End", end))

	var covers := Node3D.new()
	covers.name = "CoverSpots"
	add_child(covers)
	for spot in _layout.get("cover_spots", []):
		covers.add_child(_marker("Cover", Vector3(spot)))


func _marker(name: String, pos: Vector3) -> Marker3D:
	var marker := Marker3D.new()
	marker.name = name
	marker.position = pos
	return marker


func _report() -> void:
	print(
		"Aetherfall: %d colliders, tower at %s, platform %s x %s."
		% [
			_collider_count,
			str(_layout.get("tower", Vector3.ZERO)),
			_layout.get("platform", {}).get("half", Vector2.ONE).x,
			_layout.get("platform", {}).get("half", Vector2.ONE).z,
		]
	)


static func world_for_selection(selected: String) -> String:
	if selected == "aetherfall":
		return "aetherfall"
	return "mission_world"
