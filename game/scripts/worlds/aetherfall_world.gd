extends Node3D

## Complete SH-01 Aetherfall world assembly ported from `arena/939d9492-cyber-strike`.
## Builds all 251 exterior kit modules with precision walkable deck colliders,
## sloped connectors, animated energy orbit, vertical infrastructure, structural
## landmarks, polar glacier basin, Archive interior room, tactical cover, and
## connected lowland expanse.
const BASE := "res://assets/world/aetherfall/"
const NO_COLLISION := [
	"terrain_chunk",
	"cliff_face",
	"rock_boulder",
	"background_silhouette",
	"cloud_puff",
	"debris_cluster",
	"cable_bundle",
	"energy_core",
	"railing",
]
const WALKABLE_MESH := {
	"deck_6x6": "ChamferedDeckArmour",
	"deck_edge": "EdgeArmour",
	"bridge_deck": "BridgeArmourDeck",
	"walkway_deck": "CatwalkArmour",
}

var placement_count: int = 0
var collider_count: int = 0
var landmark_count: int = 0
var verticality_count: int = 0
var ice_planet_count: int = 0
var phase2_cover_count: int = 0
var archive_interior_count: int = 0
var archive_computer_count: int = 0
var expanse_route_count: int = 0
var _skip_web_omni_lights: bool = false
var _software_webgl: bool = false


func _ready() -> void:
	set_meta("world_id", "aetherfall")
	_apply_web_render_budget()
	_build_kit_and_routes()
	_add_connectors()
	_add_animation()
	_add_vertical_infrastructure()
	_add_structural_landmarks()
	_add_ice_planet_phase1()
	_add_archive_interior()
	_add_phase2_cover()
	_add_connected_expanse()
	_add_polar_snowfall()
	print(
		(
			(
				"AETHERFALL WORLD: %d kit / %d colliders / %d vertical / %d landmarks / "
				+ "%d ice-planet / %d archive / %d cover / %d expanse routes"
			)
			% [
				placement_count,
				collider_count,
				verticality_count,
				landmark_count,
				ice_planet_count,
				archive_interior_count,
				phase2_cover_count,
				expanse_route_count,
			]
		)
	)


func provides_authored_colliders() -> bool:
	return true


func provides_authored_lighting() -> bool:
	return true


func provides_authored_motion() -> bool:
	return true


func _apply_web_render_budget() -> void:
	if not OS.has_feature("web"):
		return
	var adapter := RenderingServer.get_video_adapter_name().to_lower()
	var sw_webgl := bool(
		JavaScriptBridge.eval(
			(
				"(() => { try { const c = document.createElement('canvas'); "
				+ "const g = c.getContext('webgl2') || c.getContext('webgl'); "
				+ "const d = g && g.getExtension('WEBGL_debug_renderer_info'); "
				+ "const r = g ? String(d ? g.getParameter(d.UNMASKED_RENDERER_WEBGL) "
				+ ": g.getParameter(g.RENDERER)) : ''; "
				+ "return /swiftshader|llvmpipe|software/i.test(r); } catch { return false; } })()"
			)
		)
	)
	_software_webgl = (
		sw_webgl
		or adapter.contains("swiftshader")
		or adapter.contains("llvmpipe")
		or adapter.contains("software")
	)
	var world_env := get_node_or_null("WorldEnvironment") as WorldEnvironment
	if world_env != null and world_env.environment != null:
		# SSAO is costly in mobile/WebGL2; real GPUs keep directional shadows,
		# sky reflections, fog, and cyan emissive glow.
		world_env.environment.ssao_enabled = false
		if _software_webgl:
			world_env.environment.glow_enabled = false
	if _software_webgl:
		_skip_web_omni_lights = true
		var sun := get_node_or_null("Sun") as DirectionalLight3D
		if sun != null:
			sun.shadow_enabled = false
		var vp := get_viewport()
		if vp != null:
			vp.scaling_3d_scale = 0.45


func get_world_summary() -> Dictionary:
	return {
		"world_id": "aetherfall",
		"piece_count": placement_count,
		"collider_count": collider_count,
		"landmark_count": landmark_count,
	}


func _build_kit_and_routes() -> void:
	var layout: Dictionary = _read_json(BASE + "layout.json")
	var measurements: Dictionary = _read_json(BASE + "measurements.json")
	var measured_models: Dictionary = measurements.get("models", {}) as Dictionary

	var modules := Node3D.new()
	modules.name = "Modules"
	add_child(modules)

	var collision := Node3D.new()
	collision.name = "Collision"
	add_child(collision)

	var packs: Dictionary = {}
	var sizes: Dictionary = {}
	var mins: Dictionary = {}
	for rel_key in measured_models.keys():
		var rel_path := str(rel_key)
		if not rel_path.begins_with("models/") or not rel_path.ends_with(".glb"):
			continue
		var key := rel_path.trim_prefix("models/").trim_suffix(".glb")
		var packed := load(BASE + rel_path) as PackedScene
		if packed != null:
			packs[key] = packed
			var entry: Dictionary = measured_models[rel_key] as Dictionary
			sizes[key] = _v3(entry.get("size", []))
			mins[key] = _v3(entry.get("min", []))

	var placements: Array = layout.get("placements", []) as Array
	for raw_item in placements:
		if not (raw_item is Dictionary):
			continue
		var item: Dictionary = raw_item as Dictionary
		var key := str(item.get("asset", ""))
		if not packs.has(key):
			continue
		var pos: Vector3 = _v3(item.get("pos", []))
		var rot: Vector3 = _v3(item.get("rot", [])) * PI / 180.0
		var scale_factor := float(item.get("scale", 1.0))
		var packed_scene := packs[key] as PackedScene
		var instance := packed_scene.instantiate() as Node3D
		if instance == null:
			continue
		instance.name = str(item.get("name", key))
		instance.position = pos
		instance.rotation = rot
		instance.scale = Vector3.ONE * scale_factor
		if key in ["cloud_puff", "background_silhouette", "energy_core"]:
			instance.set_meta("no_shadow_cast", true)
		modules.add_child(instance)
		placement_count += 1
		if key in NO_COLLISION:
			continue
		var base_size: Vector3 = sizes.get(key, Vector3.ZERO) as Vector3
		var base_min: Vector3 = mins.get(key, -base_size * 0.5) as Vector3
		var size: Vector3 = base_size * scale_factor
		if size.x <= 0.0 or size.y <= 0.0 or size.z <= 0.0:
			continue
		var body := StaticBody3D.new()
		body.name = "Collision_" + str(item.get("name", key))
		body.collision_layer = 1
		body.collision_mask = 0
		body.position = pos
		body.rotation = rot
		if key == "access_gate":
			for child in instance.find_children("Gate*", "MeshInstance3D", true, false):
				_add_mesh_shape(body, instance, child as MeshInstance3D, scale_factor)
			collision.add_child(body)
			collider_count += 1
			continue
		var shape := BoxShape3D.new()
		var offset: Vector3 = (base_min + base_size * 0.5) * scale_factor
		if WALKABLE_MESH.has(key):
			var mesh_name := String(WALKABLE_MESH[key])
			var surface := instance.find_child(mesh_name, true, false) as MeshInstance3D
			if surface == null or surface.mesh == null:
				body.free()
				continue
			var relative: Transform3D = (
				instance.transform.affine_inverse() * _local_transform_under(instance, surface)
			)
			var bounds: AABB = relative * surface.get_aabb()
			size = bounds.size * scale_factor
			offset = bounds.get_center() * scale_factor
		shape.size = size
		var node := CollisionShape3D.new()
		node.name = "Shape"
		node.position = offset
		node.shape = shape
		body.add_child(node)
		if key == "bridge_deck" or key == "walkway_deck":
			var prefix := "Bridge" if key == "bridge_deck" else "Walkway"
			for child in instance.find_children(prefix + "*", "MeshInstance3D", true, false):
				var child_name := String(child.name)
				if child_name.contains("Rail") or child_name.contains("Post"):
					_add_mesh_shape(body, instance, child as MeshInstance3D, scale_factor)
		collision.add_child(body)
		collider_count += 1

	var routes := Node3D.new()
	routes.name = "Routes"
	add_child(routes)
	var route_list: Array = layout.get("routes", []) as Array
	for raw_route in route_list:
		if not (raw_route is Dictionary):
			continue
		var route: Dictionary = raw_route as Dictionary
		var route_node := Node3D.new()
		route_node.name = str(route.get("name", "route"))
		routes.add_child(route_node)
		for point in ["from", "to"]:
			var marker := Marker3D.new()
			marker.name = point
			marker.position = _v3(route.get(point, []))
			route_node.add_child(marker)

	var spawn := Node3D.new()
	spawn.name = "Spawns"
	add_child(spawn)
	var spawn_dict: Dictionary = layout.get("spawn", {}) as Dictionary
	for sp_key in spawn_dict.keys():
		var marker := Marker3D.new()
		marker.name = str(sp_key)
		marker.position = _v3(spawn_dict[sp_key])
		spawn.add_child(marker)


func _local_transform_under(root_node: Node3D, leaf: Node3D) -> Transform3D:
	var acc := Transform3D.IDENTITY
	var cur: Node = leaf
	while cur != null and cur != root_node:
		if cur is Node3D:
			acc = (cur as Node3D).transform * acc
		cur = cur.get_parent()
	return root_node.transform * acc


func _add_mesh_shape(
	body: StaticBody3D, instance: Node3D, mesh: MeshInstance3D, scale_factor: float
) -> void:
	if mesh == null or mesh.mesh == null:
		return
	var relative: Transform3D = (
		instance.transform.affine_inverse() * _local_transform_under(instance, mesh)
	)
	var bounds: AABB = relative * mesh.get_aabb()
	var box := BoxShape3D.new()
	box.size = bounds.size * scale_factor
	var shape := CollisionShape3D.new()
	shape.name = "Part_" + String(mesh.name)
	shape.position = bounds.get_center() * scale_factor
	shape.shape = box
	body.add_child(shape)


func _add_connectors() -> void:
	var data: Dictionary = _read_json(BASE + "connectors.json")
	var packed := load(BASE + "models/connector_ramp.glb") as PackedScene
	if packed == null:
		return
	var group := Node3D.new()
	group.name = "Connectors"
	add_child(group)
	var connectors: Array = data.get("connectors", []) as Array
	for raw_conn in connectors:
		if not (raw_conn is Dictionary):
			continue
		var connector: Dictionary = raw_conn as Dictionary
		var start: Vector3 = _v3(connector.get("from", []))
		var finish: Vector3 = _v3(connector.get("to", []))
		var delta: Vector3 = finish - start
		if Vector2(delta.x, delta.z).length() < 0.01:
			continue
		var length := delta.length()
		var forward := delta.normalized()
		var side := forward.cross(Vector3.UP).normalized()
		var normal := side.cross(forward).normalized()
		var width := float(connector.get("width", 1.6))
		var conn_root := Node3D.new()
		conn_root.name = str(connector.get("name", "connector"))
		conn_root.position = (start + finish) * 0.5
		conn_root.basis = Basis(forward, normal, side)
		group.add_child(conn_root)
		var visual := packed.instantiate() as Node3D
		if visual != null:
			visual.name = "Visual"
			visual.scale = Vector3(length, 1.0, width)
			conn_root.add_child(visual)
		var body := StaticBody3D.new()
		body.name = "DeckCollision"
		body.collision_layer = 1
		body.collision_mask = 0
		conn_root.add_child(body)
		var shape := BoxShape3D.new()
		shape.size = Vector3(length, 0.2, width)
		var node := CollisionShape3D.new()
		node.name = "Shape"
		node.position.y = -0.1
		node.shape = shape
		body.add_child(node)
		collider_count += 1


func _add_animation() -> void:
	var packed := load(BASE + "models/energy_orbit.glb") as PackedScene
	if packed == null:
		return
	var orbit := packed.instantiate() as Node3D
	if orbit == null:
		return
	orbit.name = "EnergyOrbit"
	orbit.position = Vector3(0.0, 20.0, -26.0)
	add_child(orbit)
	var players := orbit.find_children("*", "AnimationPlayer", true, false)
	if not players.is_empty():
		var anim_player := players[0] as AnimationPlayer
		var names := anim_player.get_animation_list()
		if not names.is_empty():
			anim_player.get_animation(names[0]).loop_mode = Animation.LOOP_LINEAR
			anim_player.play(names[0])


func _add_vertical_infrastructure() -> void:
	verticality_count = _spawn_setpiece_group(
		"VerticalInfrastructure", "verticality.json", "vertical/", Color(0.12, 0.60, 1.0), 12.0
	)


func _add_structural_landmarks() -> void:
	landmark_count = _spawn_setpiece_group(
		"StructuralLandmarks", "landmarks.json", "landmarks/", Color(0.18, 0.67, 1.0), 7.0
	)


func _add_ice_planet_phase1() -> void:
	ice_planet_count = _spawn_setpiece_group(
		"IcePlanetPhase1", "ice_planet_phase1.json", "ice_planet/", Color(0.18, 0.72, 1.0), 10.0
	)


func _add_phase2_cover() -> void:
	phase2_cover_count = _spawn_setpiece_group(
		"Phase2Cover", "phase2_cover.json", "phase2/", Color(0.08, 0.66, 1.0), 6.0
	)


func _spawn_setpiece_group(
	group_name: String, json_file: String, subdir: String, fallback_light: Color, def_range: float
) -> int:
	var data: Dictionary = _read_json(BASE + json_file)
	if data.is_empty():
		return 0
	var group := Node3D.new()
	group.name = group_name
	add_child(group)
	var count := 0
	var placements: Array = data.get("placements", []) as Array
	for raw_spec in placements:
		if not (raw_spec is Dictionary):
			continue
		var spec: Dictionary = raw_spec as Dictionary
		var asset := str(spec.get("asset", ""))
		var packed := load(BASE + subdir + asset + ".glb") as PackedScene
		if packed == null:
			continue
		var setpiece := Node3D.new()
		setpiece.name = str(spec.get("id", asset))
		setpiece.position = _v3(spec.get("position", []))
		setpiece.rotation = _v3(spec.get("rotation_degrees", [])) * PI / 180.0
		group.add_child(setpiece)
		var visual := packed.instantiate() as Node3D
		if visual != null:
			visual.name = "Visual"
			setpiece.add_child(visual)
		var boxes: Array = spec.get("collision_boxes", []) as Array
		if not boxes.is_empty():
			var collision := StaticBody3D.new()
			collision.name = "Collision"
			collision.collision_layer = 1
			collision.collision_mask = 0
			setpiece.add_child(collision)
			for raw_box in boxes:
				if not (raw_box is Dictionary):
					continue
				var box_data: Dictionary = raw_box as Dictionary
				var size: Vector3 = _v3(box_data.get("size", []))
				if size.x <= 0.0 or size.y <= 0.0 or size.z <= 0.0:
					continue
				var shape := CollisionShape3D.new()
				shape.name = "Shape"
				shape.position = _v3(box_data.get("center", []))
				var box := BoxShape3D.new()
				box.size = size
				shape.shape = box
				collision.add_child(shape)
				collider_count += 1
		var light_data: Variant = spec.get("light", null)
		if light_data is Dictionary and not _skip_web_omni_lights:
			var light_cfg: Dictionary = light_data as Dictionary
			var light := OmniLight3D.new()
			light.name = "AccentLight"
			light.position = _v3(light_cfg.get("position", []))
			light.light_color = _color3(light_cfg.get("color", []), fallback_light)
			light.light_energy = float(light_cfg.get("energy", 1.0))
			light.omni_range = float(light_cfg.get("range", def_range))
			light.shadow_enabled = false
			setpiece.add_child(light)
		count += 1
	return count


func _add_archive_interior() -> void:
	var data: Dictionary = _read_json(BASE + "archive_phase3.json")
	var interior: Dictionary = data.get("interior", {}) as Dictionary
	if interior.is_empty():
		return
	var asset := str(interior.get("asset", ""))
	var packed := load(BASE + "archive/" + asset + ".glb") as PackedScene
	if packed == null:
		return
	var archive := Node3D.new()
	archive.name = "ArchiveInterior"
	archive.position = _v3(interior.get("position", []))
	archive.rotation = _v3(interior.get("rotation_degrees", [])) * PI / 180.0
	add_child(archive)
	var visual := packed.instantiate() as Node3D
	if visual != null:
		visual.name = "VestibuleVisual"
		archive.add_child(visual)
	var collision := StaticBody3D.new()
	collision.name = "Collision"
	collision.collision_layer = 1
	collision.collision_mask = 0
	archive.add_child(collision)
	var boxes: Array = interior.get("collision_boxes", []) as Array
	for raw_box in boxes:
		if not (raw_box is Dictionary):
			continue
		var box_data: Dictionary = raw_box as Dictionary
		var size: Vector3 = _v3(box_data.get("size", []))
		if size.x <= 0.0 or size.y <= 0.0 or size.z <= 0.0:
			continue
		var shape := CollisionShape3D.new()
		shape.name = "Shape"
		shape.position = _v3(box_data.get("center", []))
		var box := BoxShape3D.new()
		box.size = size
		shape.shape = box
		collision.add_child(shape)
		collider_count += 1
	var lights: Array = interior.get("lights", []) as Array
	for raw_light in lights:
		if _skip_web_omni_lights or not (raw_light is Dictionary):
			continue
		var light_data: Dictionary = raw_light as Dictionary
		var light := OmniLight3D.new()
		light.name = "ArchiveInteriorLight"
		light.position = _v3(light_data.get("position", []))
		light.light_color = _color3(light_data.get("color", []), Color(0.12, 0.62, 1.0))
		light.light_energy = float(light_data.get("energy", 1.0))
		light.omni_range = float(light_data.get("range", 6.0))
		light.shadow_enabled = false
		archive.add_child(light)
	var computer_spec: Dictionary = data.get("computer", {}) as Dictionary
	var comp_pack := load(BASE + "archive/archive_computer.glb") as PackedScene
	if not computer_spec.is_empty() and comp_pack != null:
		var comp_visual := comp_pack.instantiate() as Node3D
		if comp_visual != null:
			comp_visual.name = "ArchiveComputer"
			comp_visual.position = _v3(computer_spec.get("local_position", [0.0, 0.6, 1.85]))
			comp_visual.rotation = (
				_v3(computer_spec.get("local_rotation_degrees", [0.0, 180.0, 0.0])) * PI / 180.0
			)
			archive.add_child(comp_visual)
			var comp_shape := CollisionShape3D.new()
			comp_shape.name = "ArchiveComputerShape"
			comp_shape.position = comp_visual.position + Vector3(0.0, 0.9, 0.0)
			var comp_box := BoxShape3D.new()
			comp_box.size = Vector3(1.6, 1.8, 0.95)
			comp_shape.shape = comp_box
			collision.add_child(comp_shape)
			collider_count += 1
			archive_computer_count += 1
	archive_interior_count += 1


func _add_connected_expanse() -> void:
	var data: Dictionary = _read_json(BASE + "world_expansion.json")
	if data.is_empty():
		return
	var field_pack := load(BASE + "expanse/lowland_field.glb") as PackedScene
	var shelf_pack := load(BASE + "expanse/expanse_shelf.glb") as PackedScene
	var route_pack := load(BASE + "expanse/transit_spine.glb") as PackedScene
	if field_pack == null or shelf_pack == null or route_pack == null:
		return
	var group := Node3D.new()
	group.name = "ConnectedExpanse"
	add_child(group)
	var lowlands := Node3D.new()
	lowlands.name = "LowlandFields"
	group.add_child(lowlands)
	for raw_spec in data.get("lowland_fields", []) as Array:
		if raw_spec is Dictionary:
			_add_expanse_static(
				lowlands,
				field_pack,
				raw_spec as Dictionary,
				Vector3(80.0, 0.4, 72.0),
				Vector3(0.0, -0.2, 0.0),
			)
	var shelves := Node3D.new()
	shelves.name = "RimShelves"
	group.add_child(shelves)
	for raw_spec in data.get("shelves", []) as Array:
		if raw_spec is Dictionary:
			_add_expanse_static(
				shelves,
				shelf_pack,
				raw_spec as Dictionary,
				Vector3(28.0, 0.6, 24.0),
				Vector3(0.0, -0.3, 0.0),
			)
	var routes := Node3D.new()
	routes.name = "PerimeterLoop"
	group.add_child(routes)
	for raw_spec in data.get("loop_routes", []) as Array:
		if raw_spec is Dictionary:
			_add_expanse_route(routes, route_pack, raw_spec as Dictionary)
	for raw_spec in data.get("recovery_routes", []) as Array:
		if raw_spec is Dictionary:
			_add_expanse_route(routes, route_pack, raw_spec as Dictionary)


func _add_expanse_static(
	parent: Node3D,
	packed: PackedScene,
	spec: Dictionary,
	shape_size: Vector3,
	shape_center: Vector3,
) -> void:
	var setpiece := Node3D.new()
	setpiece.name = str(spec.get("id", "ExpanseSetpiece"))
	setpiece.position = _v3(spec.get("position", []))
	setpiece.rotation = _v3(spec.get("rotation_degrees", [])) * PI / 180.0
	parent.add_child(setpiece)
	var visual := packed.instantiate() as Node3D
	if visual != null:
		visual.name = "Visual"
		setpiece.add_child(visual)
	var body := StaticBody3D.new()
	body.name = "Collision"
	body.collision_layer = 1
	body.collision_mask = 0
	setpiece.add_child(body)
	var shape := CollisionShape3D.new()
	shape.name = "Surface"
	shape.position = shape_center
	var box := BoxShape3D.new()
	box.size = shape_size
	shape.shape = box
	body.add_child(shape)
	collider_count += 1


func _add_expanse_route(parent: Node3D, packed: PackedScene, spec: Dictionary) -> void:
	var start: Vector3 = _v3(spec.get("from", []))
	var finish: Vector3 = _v3(spec.get("to", []))
	var delta: Vector3 = finish - start
	if delta.length() < 0.01 or Vector2(delta.x, delta.z).length() < 0.01:
		return
	var length := delta.length()
	var forward := delta.normalized()
	var side := forward.cross(Vector3.UP).normalized()
	var normal := side.cross(forward).normalized()
	var width := float(spec.get("width", 5.2))
	var route := Node3D.new()
	route.name = str(spec.get("id", "ExpanseRoute"))
	route.position = (start + finish) * 0.5
	route.basis = Basis(forward, normal, side)
	parent.add_child(route)
	var visual := packed.instantiate() as Node3D
	if visual != null:
		visual.name = "Visual"
		visual.scale = Vector3(length / 12.0, 1.0, width / 5.2)
		route.add_child(visual)
	var body := StaticBody3D.new()
	body.name = "Collision"
	body.collision_layer = 1
	body.collision_mask = 0
	route.add_child(body)
	var shape := CollisionShape3D.new()
	shape.name = "Surface"
	shape.position.y = 0.0
	var box := BoxShape3D.new()
	box.size = Vector3(length, 0.95, width)
	shape.shape = box
	body.add_child(shape)
	collider_count += 1
	expanse_route_count += 1


func _add_polar_snowfall() -> void:
	# Software WebGL must not pay for 140 alpha-blended flakes; headless keeps
	# the node so smoke fixtures can assert the atmosphere really is authored.
	if _software_webgl:
		return
	var snowfall := CPUParticles3D.new()
	snowfall.name = "PolarSnowfall"
	snowfall.position = Vector3(0.0, 14.0, 0.0)
	snowfall.amount = 140
	snowfall.lifetime = 5.5
	snowfall.preprocess = 2.5
	snowfall.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	snowfall.emission_box_extents = Vector3(46.0, 8.0, 38.0)
	snowfall.direction = Vector3(-0.42, -1.0, 0.24).normalized()
	snowfall.spread = 22.0
	snowfall.gravity = Vector3(-0.85, -1.65, 0.35)
	snowfall.initial_velocity_min = 1.6
	snowfall.initial_velocity_max = 3.2
	snowfall.scale_amount_min = 0.65
	snowfall.scale_amount_max = 1.45
	var flake_mat := StandardMaterial3D.new()
	flake_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	flake_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	flake_mat.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	flake_mat.billboard_keep_scale = true
	flake_mat.albedo_color = Color(0.84, 0.94, 1.0, 0.52)
	var quad := QuadMesh.new()
	quad.size = Vector2(0.065, 0.065)
	quad.material = flake_mat
	snowfall.mesh = quad
	snowfall.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(snowfall)


static func _v3(value: Variant) -> Vector3:
	if value is Array and (value as Array).size() >= 3:
		var arr := value as Array
		return Vector3(float(arr[0]), float(arr[1]), float(arr[2]))
	return Vector3.ZERO


static func _color3(value: Variant, fallback: Color = Color.WHITE) -> Color:
	if value is Array and (value as Array).size() >= 3:
		var arr := value as Array
		return Color(float(arr[0]), float(arr[1]), float(arr[2]))
	return fallback


static func _read_json(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		return {}
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	return parsed as Dictionary if parsed is Dictionary else {}
