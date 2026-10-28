extends Node3D
## Independent Aetherfall assembly. All dimensions and placements are in metres.
const BASE := "res://assets/world/aetherfall/"
const NO_COLLISION := ["terrain_chunk", "cliff_face", "rock_boulder", "background_silhouette", "cloud_puff", "debris_cluster", "cable_bundle", "energy_core"]
const WALKABLE := ["deck_6x6", "deck_edge", "bridge_deck", "walkway_deck", "damaged_slab"]
var placement_count := 0
var collider_count := 0

func v3(value: Variant) -> Vector3:
	if value is Array and value.size() >= 3:
		return Vector3(float(value[0]), float(value[1]), float(value[2]))
	return Vector3.ZERO

func read_json(path: String) -> Dictionary:
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	if not parsed is Dictionary:
		push_error("Aetherfall: invalid JSON: " + path)
		return {}
	return parsed

func _ready() -> void:
	var layout := read_json(BASE + "layout.json")
	var measurements := read_json(BASE + "measurements.json")
	var assets: Dictionary = measurements.get("assets", {})
	var modules := Node3D.new()
	modules.name = "Modules"
	add_child(modules)
	var collision := Node3D.new()
	collision.name = "Collision"
	add_child(collision)
	var packs := {}
	for key in assets:
		var packed := load(BASE + "models/" + str(key) + ".glb") as PackedScene
		if packed == null:
			push_error("Aetherfall: missing model " + str(key))
		else:
			packs[key] = packed
	for item: Dictionary in layout.get("placements", []):
		var key: String = item.get("asset", "")
		if not packs.has(key):
			continue
		var pos := v3(item.get("pos", []))
		var rot := v3(item.get("rot", [])) * PI / 180.0
		var scale_factor := float(item.get("scale", 1.0))
		var instance: Node3D = packs[key].instantiate()
		instance.name = str(item.get("name", key))
		instance.position = pos
		instance.rotation = rot
		instance.scale = Vector3.ONE * scale_factor
		modules.add_child(instance)
		placement_count += 1
		if key in NO_COLLISION:
			continue
		var size := v3(assets[key].get("size", [])) * scale_factor
		if size.x <= 0.0 or size.y <= 0.0 or size.z <= 0.0:
			continue
		var body := StaticBody3D.new()
		body.name = "Collision_" + str(item.get("name", key))
		body.position = pos
		body.rotation = rot
		var shape := BoxShape3D.new()
		var offset := Vector3.ZERO
		if key in WALKABLE:
			# Deck bounding boxes include rails/supports. This is a conservative
			# proxy, not proof that the visual deck surface matches the collision.
			var thickness := minf(size.y, 0.5)
			offset.y = size.y * 0.5 - thickness * 0.5
			size.y = thickness
		shape.size = size
		var node := CollisionShape3D.new()
		node.position = offset
		node.shape = shape
		body.add_child(node)
		collision.add_child(body)
		collider_count += 1
	var routes := Node3D.new()
	routes.name = "Routes"
	add_child(routes)
	for route: Dictionary in layout.get("routes", []):
		var route_node := Node3D.new()
		route_node.name = str(route.get("name", "route"))
		routes.add_child(route_node)
		for point in ["from", "to"]:
			var marker := Marker3D.new()
			marker.name = point
			marker.position = v3(route.get(point, []))
			route_node.add_child(marker)
	var spawn := Node3D.new()
	spawn.name = "Spawns"
	add_child(spawn)
	for key in layout.get("spawn", {}):
		var marker := Marker3D.new()
		marker.name = str(key)
		marker.position = v3(layout["spawn"][key])
		spawn.add_child(marker)
	add_atmosphere()
	add_animation()
	print("Aetherfall: %d placements; %d proxy colliders" % [placement_count, collider_count])

func add_atmosphere() -> void:
	var environment := Environment.new()
	environment.background_mode = Environment.BG_COLOR
	environment.background_color = Color(0.23, 0.34, 0.43)
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color(0.60, 0.72, 0.82)
	environment.ambient_light_energy = 0.8
	environment.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	environment.fog_enabled = true
	environment.fog_light_color = Color(0.46, 0.58, 0.66)
	environment.fog_density = 0.0018
	environment.glow_enabled = true
	var world_env := WorldEnvironment.new()
	world_env.environment = environment
	add_child(world_env)
	var sun := DirectionalLight3D.new()
	sun.name = "Sun"
	sun.rotation_degrees = Vector3(-48, -32, 0)
	sun.light_color = Color(1.0, 0.89, 0.75)
	sun.light_energy = 1.25
	sun.shadow_enabled = true
	add_child(sun)

func add_animation() -> void:
	var packed := load(BASE + "models/energy_orbit.glb") as PackedScene
	if packed == null:
		return
	var orbit := packed.instantiate() as Node3D
	orbit.name = "EnergyOrbit"
	orbit.position = Vector3(0, 20, -26)
	add_child(orbit)
	var players := orbit.find_children("*", "AnimationPlayer", true, false)
	if not players.is_empty():
		var player := players[0] as AnimationPlayer
		var names := player.get_animation_list()
		if not names.is_empty():
			player.get_animation(names[0]).loop_mode = Animation.LOOP_LINEAR
			player.play(names[0])
