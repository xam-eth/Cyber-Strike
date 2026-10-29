extends Node3D
## Independent Aetherfall assembly. All dimensions and placements are in metres.
const BASE := "res://assets/world/aetherfall/"
const PLAYER_SCENE := preload("res://scenes/aetherfall_player.tscn")
const PROGRESSION_STATE := preload("res://scripts/progression_state.gd")
const MISSION_HUD := preload("res://scripts/mission_hud.gd")
const NO_COLLISION := ["terrain_chunk", "cliff_face", "rock_boulder", "background_silhouette", "cloud_puff", "debris_cluster", "cable_bundle", "energy_core", "railing"]
# Surface meshes, not the enclosing AABB of railings or dangling cables.
const WALKABLE_MESH := {
	"deck_6x6": "DeckPlate", "deck_edge": "DeckEdgePlate",
	"bridge_deck": "BridgeDeck", "walkway_deck": "WalkwayDeck",
}
var placement_count := 0
var collider_count := 0
var landmark_count := 0
var landmark_collider_count := 0

func v3(value: Variant) -> Vector3:
	if value is Array and value.size() >= 3:
		return Vector3(float(value[0]), float(value[1]), float(value[2]))
	return Vector3.ZERO

func color3(value: Variant, fallback := Color.WHITE) -> Color:
	if value is Array and value.size() >= 3:
		return Color(float(value[0]), float(value[1]), float(value[2]))
	return fallback

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
		if key == "access_gate":
			# The gate is an opening, not the solid AABB of the whole arch.
			for child in instance.find_children("Gate*", "MeshInstance3D", true, false):
				add_mesh_shape(body, instance, child as MeshInstance3D, scale_factor)
			collision.add_child(body)
			collider_count += 1
			continue
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
		# Thin rail meshes are represented individually, never as a solid box
		# surrounding the entire bridge or catwalk.
		if key == "bridge_deck" or key == "walkway_deck":
			var prefix := "Bridge" if key == "bridge_deck" else "Walkway"
			for child in instance.find_children(prefix + "*", "MeshInstance3D", true, false):
				if String(child.name).contains("Rail") or String(child.name).contains("Post"):
					add_mesh_shape(body, instance, child as MeshInstance3D, scale_factor)
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
	add_structural_landmarks()
	add_stellar_horizon_slice(layout)
	print("Aetherfall: %d kit placements; %d proxy colliders; %d landmark placements; %d landmark colliders" % [placement_count, collider_count, landmark_count, landmark_collider_count])


func add_structural_landmarks() -> void:
	## Purpose-authored buildings live outside layout.json so the original 251-kit
	## composition remains reviewable and its module contract stays stable.
	var data := read_json(BASE + "landmarks.json")
	if data.is_empty():
		return
	var group := Node3D.new()
	group.name = "StructuralLandmarks"
	add_child(group)
	for spec: Dictionary in data.get("placements", []):
		var asset := str(spec.get("asset", ""))
		var packed := load(BASE + "landmarks/" + asset + ".glb") as PackedScene
		if packed == null:
			push_error("Aetherfall: landmark model tidak ditemukan: " + asset)
			continue
		var landmark := Node3D.new()
		landmark.name = str(spec.get("id", asset))
		landmark.position = v3(spec.get("position", []))
		landmark.rotation = v3(spec.get("rotation_degrees", [])) * PI / 180.0
		group.add_child(landmark)
		var visual := packed.instantiate() as Node3D
		visual.name = "Visual"
		landmark.add_child(visual)
		var collision := StaticBody3D.new()
		collision.name = "Collision"
		landmark.add_child(collision)
		for box_data: Dictionary in spec.get("collision_boxes", []):
			var size := v3(box_data.get("size", []))
			if size.x <= 0.0 or size.y <= 0.0 or size.z <= 0.0:
				push_error("Aetherfall: invalid landmark collision " + landmark.name)
				continue
			var shape := CollisionShape3D.new()
			shape.name = "Shape"
			shape.position = v3(box_data.get("center", []))
			var box := BoxShape3D.new()
			box.size = size
			shape.shape = box
			collision.add_child(shape)
			landmark_collider_count += 1
		var light_data: Variant = spec.get("light", null)
		if light_data is Dictionary:
			var light_config := light_data as Dictionary
			var light := OmniLight3D.new()
			light.name = "StructuralLight"
			light.position = v3(light_config.get("position", []))
			light.light_color = color3(light_config.get("color", []), Color(0.18, 0.67, 1.0))
			light.light_energy = float(light_config.get("energy", 1.0))
			light.omni_range = float(light_config.get("range", 7.0))
			light.shadow_enabled = false
			landmark.add_child(light)
		landmark_count += 1


func add_stellar_horizon_slice(layout: Dictionary) -> void:
	## This local slice is kept separate from the kit assembly: it does not
	## replace routes, cover or legacy review controls, and has no autoload.
	var data := read_json(BASE + "stellar_horizon_slice.json")
	if data.is_empty():
		return
	var progression := PROGRESSION_STATE.new() as AetherfallProgressionState
	progression.name = "ProgressionState"
	add_child(progression)
	var group := Node3D.new()
	group.name = "StellarHorizon"
	add_child(group)
	var cache_id := ""
	var objective_id := ""
	var required_data := 1
	for spec: Dictionary in data.get("interactives", []):
		var packed := load(str(spec.get("scene", ""))) as PackedScene
		if packed == null:
			push_error("Aetherfall: interactive scene tidak ditemukan: " + str(spec.get("scene", "")))
			continue
		var instance := packed.instantiate() as AetherfallInteractionTarget
		if instance == null:
			push_error("Aetherfall: scene interaktif bukan AetherfallInteractionTarget.")
			continue
		instance.name = str(spec.get("id", "Interactive"))
		instance.interaction_id = str(spec.get("id", instance.interaction_id))
		instance.position = v3(spec.get("position", []))
		instance.rotation = v3(spec.get("rotation_degrees", [])) * PI / 180.0
		if instance is AetherfallTechCache:
			var cache := instance as AetherfallTechCache
			cache.reward_amount = int(spec.get("reward", {}).get("amount", cache.reward_amount))
			cache_id = cache.interaction_id
		elif instance is AetherfallObjectiveDevice:
			var device := instance as AetherfallObjectiveDevice
			device.required_tech_data = int(spec.get("requires", {}).get("amount", device.required_tech_data))
			objective_id = device.interaction_id
			required_data = device.required_tech_data
		group.add_child(instance)
	var spawn_key := str(data.get("player_spawn", "primary"))
	var spawn_position := v3(layout.get("spawn", {}).get(spawn_key, []))
	var player := PLAYER_SCENE.instantiate() as AetherfallPlayer
	player.name = "AetherfallPlayer"
	player.position = spawn_position
	add_child(player)
	var hud := MISSION_HUD.new() as AetherfallMissionHud
	hud.name = "MissionHUD"
	add_child(hud)
	hud.bind_slice(progression, player, cache_id, objective_id, required_data)


func add_mesh_shape(body: StaticBody3D, instance: Node3D, mesh: MeshInstance3D, scale_factor: float) -> void:
	if mesh == null or mesh.mesh == null:
		return
	var relative := instance.global_transform.affine_inverse() * mesh.global_transform
	var bounds: AABB = relative * mesh.get_aabb()
	var box := BoxShape3D.new()
	box.size = bounds.size * scale_factor
	var shape := CollisionShape3D.new()
	shape.name = "Part_" + mesh.name
	shape.position = bounds.get_center() * scale_factor
	shape.shape = box
	body.add_child(shape)


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
		# Build an orthonormal slope basis for either east-west or north-south
		# routes. X follows the slope and Y is its upward-facing normal.
		if Vector2(delta.x, delta.z).length() < 0.01:
			push_error("Aetherfall: invalid connector endpoints")
			continue
		var length := delta.length()
		var forward := delta.normalized()
		var side := forward.cross(Vector3.UP).normalized()
		var normal := side.cross(forward).normalized()
		var width := float(connector.get("width", 1.6))
		var root := Node3D.new()
		root.name = str(connector.get("name", "connector"))
		root.position = (start + end) * 0.5
		root.basis = Basis(forward, normal, side)
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
	var sky_material := ProceduralSkyMaterial.new()
	sky_material.sky_top_color = Color(0.055, 0.14, 0.27)
	sky_material.sky_horizon_color = Color(0.44, 0.59, 0.72)
	sky_material.ground_bottom_color = Color(0.075, 0.10, 0.14)
	sky_material.ground_horizon_color = Color(0.34, 0.43, 0.50)
	var sky := Sky.new()
	sky.sky_material = sky_material
	environment.background_mode = Environment.BG_SKY
	environment.sky = sky
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	environment.ambient_light_energy = 0.95
	environment.reflected_light_source = Environment.REFLECTION_SOURCE_SKY
	environment.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	# Deliberately lean haze and restrained glow preserve canyon depth, PBR
	# contrast and building silhouettes instead of flattening the scene.
	environment.tonemap_exposure = 1.04
	environment.tonemap_white = 1.15
	environment.fog_enabled = true
	environment.fog_light_color = Color(0.44, 0.58, 0.68)
	environment.fog_density = 0.00095
	environment.fog_aerial_perspective = 0.34
	environment.fog_sky_affect = 0.22
	environment.glow_enabled = true
	environment.glow_intensity = 0.55
	environment.glow_strength = 0.72
	environment.glow_bloom = 0.08
	environment.adjustment_enabled = true
	environment.adjustment_contrast = 1.07
	environment.adjustment_saturation = 1.04
	var world_env := WorldEnvironment.new()
	world_env.environment = environment
	add_child(world_env)
	var sun := DirectionalLight3D.new()
	sun.name = "Sun"
	sun.rotation_degrees = Vector3(-48, -32, 0)
	sun.light_color = Color(1.0, 0.90, 0.76)
	sun.light_energy = 1.72
	sun.shadow_enabled = true
	sun.directional_shadow_max_distance = 115.0
	sun.directional_shadow_fade_start = 0.84
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
