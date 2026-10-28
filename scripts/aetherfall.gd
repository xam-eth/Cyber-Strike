extends Node3D
## Independent Aetherfall assembly. All dimensions and placements are in metres.
const BASE := "res://assets/world/aetherfall/"
const NO_COLLISION := ["terrain_chunk", "cliff_face", "rock_boulder", "background_silhouette", "cloud_puff", "debris_cluster", "cable_bundle", "energy_core", "railing"]
# Surface meshes, not the enclosing AABB of railings or dangling cables.
const WALKABLE_MESH := {
	"deck_6x6": "DeckPlate", "deck_edge": "DeckEdgePlate",
	"bridge_deck": "BridgeDeck", "walkway_deck": "WalkwayDeck",
}
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
		if WALKABLE_MESH.has(key):
			var surface := instance.find_child(WALKABLE_MESH[key], true, false) as MeshInstance3D
			if surface == null or surface.mesh == null:
				push_error("Aetherfall: missing walking mesh for " + key)
				body.free()
				continue
			# Transform the authored surface bounds to module-local coordinates.
			# The AABB of the entire asset includes railings and is not a floor.
			var relative := instance.global_transform.affine_inverse() * surface.global_transform
			var bounds: AABB = relative * surface.get_aabb()
			size = bounds.size * scale_factor
			offset = bounds.get_center() * scale_factor
		shape.size = size
		var node := CollisionShape3D.new()
		node.name = "Shape"
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
	add_connectors()
	add_atmosphere()
	add_animation()
	print("Aetherfall: %d placements; %d proxy colliders" % [placement_count, collider_count])


func add_connectors() -> void:
	var data := read_json(BASE + "connectors.json")
	var packed := load(BASE + "models/connector_ramp.glb") as PackedScene
	if packed == null:
		push_error("Aetherfall: missing connector ramp")
		return
	var group := Node3D.new()
	group.name = "Connectors"
	add_child(group)
	for connector: Dictionary in data.get("connectors", []):
		var start := v3(connector.get("from", []))
		var end := v3(connector.get("to", []))
		var delta := end - start
		# Current connectors run in X; enforce ordered endpoints so the top
		# surface remains upward-facing. Future arbitrary routes need a basis.
		if delta.x <= 0.0 or absf(delta.z) > 0.001:
			push_error("Aetherfall: invalid connector endpoints")
			continue
		var length := delta.length()
		var width := float(connector.get("width", 1.6))
		var root := Node3D.new()
		root.name = str(connector.get("name", "connector"))
		root.position = (start + end) * 0.5
		root.rotation.z = atan2(delta.y, delta.x)
		group.add_child(root)
		var visual := packed.instantiate() as Node3D
		visual.name = "Visual"
		visual.scale = Vector3(length, 1.0, width)
		root.add_child(visual)
		var body := StaticBody3D.new()
		body.name = "DeckCollision"
		root.add_child(body)
		var shape := BoxShape3D.new()
		shape.size = Vector3(length, 0.2, width)
		var node := CollisionShape3D.new()
		node.name = "Shape"
		node.position.y = -0.1
		node.shape = shape
		body.add_child(node)


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
