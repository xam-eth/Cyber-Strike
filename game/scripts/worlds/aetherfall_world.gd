class_name AetherfallWorld
extends Node3D

## SH-01 Aetherfall — Sentinel Citadel world assembler (merged from branch
## `arena/939d9492-cyber-strike` into `game/assets/world/aetherfall/`).
##
## Every visible surface is an authored PBR `.glb` loaded from the shared-texture
## Aetherfall package (`res://assets/world/aetherfall/`). Exact `StaticBody3D`
## collision shapes are constructed per modular deck, ramp, landmark, interior
## wall, and vertical gantry so players and robot squads traverse multi-level
## routes cleanly without coarse convex-hull blockage.
const ASSET_ROOT := "res://assets/world/aetherfall"
const LAYOUT_PATH := ASSET_ROOT + "/layout.json"
const EXPANSION_PATH := ASSET_ROOT + "/world_expansion.json"
const LANDMARKS_PATH := ASSET_ROOT + "/landmarks.json"
const ARCHIVE_PHASE3_PATH := ASSET_ROOT + "/archive_phase3.json"
const PHASE2_COVER_PATH := ASSET_ROOT + "/phase2_cover.json"
const ICE_PLANET_PATH := ASSET_ROOT + "/ice_planet_phase1.json"
const VERTICALITY_PATH := ASSET_ROOT + "/verticality.json"

const MODEL_PATHS := {
	"tower_core": ASSET_ROOT + "/models/tower_core.glb",
	"platform_deck": ASSET_ROOT + "/models/platform_deck.glb",
	"platform_edge": ASSET_ROOT + "/models/platform_edge.glb",
	"railing": ASSET_ROOT + "/models/railing.glb",
	"stair_run": ASSET_ROOT + "/models/stair_run.glb",
	"ramp_deck": ASSET_ROOT + "/models/ramp_deck.glb",
	"bridge_span": ASSET_ROOT + "/models/bridge_span.glb",
	"catwalk_deck": ASSET_ROOT + "/models/catwalk_deck.glb",
	"support_truss": ASSET_ROOT + "/models/support_truss.glb",
	"pillar": ASSET_ROOT + "/models/pillar.glb",
	"wall_panel": ASSET_ROOT + "/models/wall_panel.glb",
	"cover_barrier": ASSET_ROOT + "/models/cover_barrier.glb",
	"crate_cluster": ASSET_ROOT + "/models/crate_cluster.glb",
	"pipe_run": ASSET_ROOT + "/models/pipe_run.glb",
	"cable_tray": ASSET_ROOT + "/models/cable_tray.glb",
	"cover_machine": ASSET_ROOT + "/models/cover_machine.glb",
	"beacon_node": ASSET_ROOT + "/models/beacon_node.glb",
	"cliff_face": ASSET_ROOT + "/models/cliff_face.glb",
	"rock_outcrop": ASSET_ROOT + "/models/rock_outcrop.glb",
	"spawn_pad": ASSET_ROOT + "/models/spawn_pad.glb",
	"snow_patch": ASSET_ROOT + "/ice_planet/snow_patch.glb",
	"snow_drift": ASSET_ROOT + "/ice_planet/snow_drift.glb",
	"glacier_spire": ASSET_ROOT + "/ice_planet/glacier_spire.glb",
	"ice_ridge": ASSET_ROOT + "/ice_planet/ice_ridge.glb",
	"frozen_pipe_cluster": ASSET_ROOT + "/ice_planet/frozen_pipe_cluster.glb",
	"aurora_ribbon": ASSET_ROOT + "/ice_planet/aurora_ribbon.glb",
	"distant_planet": ASSET_ROOT + "/ice_planet/distant_planet.glb",
	"lowland_field": ASSET_ROOT + "/expanse/lowland_field.glb",
	"ice_causeway": ASSET_ROOT + "/expanse/ice_causeway.glb",
	"relay_outpost": ASSET_ROOT + "/expanse/relay_outpost.glb",
	"glacier_arch": ASSET_ROOT + "/expanse/glacier_arch.glb",
	"ice_boulder": ASSET_ROOT + "/expanse/ice_boulder.glb",
	"wall_half": ASSET_ROOT + "/phase2/wall_half.glb",
	"field_outpost": ASSET_ROOT + "/landmarks/field_outpost.glb",
	"relay_annex": ASSET_ROOT + "/landmarks/relay_annex.glb",
	"sentinel_archive": ASSET_ROOT + "/landmarks/sentinel_archive.glb",
	"service_hangar": ASSET_ROOT + "/landmarks/service_hangar.glb",
	"cargo_service_cluster": ASSET_ROOT + "/landmarks/cargo_service_cluster.glb",
	"refinery_stack": ASSET_ROOT + "/vertical/refinery_stack.glb",
	"gantry_overpass": ASSET_ROOT + "/vertical/gantry_overpass.glb",
	"comm_mast": ASSET_ROOT + "/vertical/comm_mast.glb",
	"archive_vestibule": ASSET_ROOT + "/archive/archive_vestibule.glb",
	"archive_console_bank": ASSET_ROOT + "/archive/archive_console_bank.glb",
	"archive_core_pedestal": ASSET_ROOT + "/archive/archive_core_pedestal.glb",
	"archive_containment_rack": ASSET_ROOT + "/archive/archive_containment_rack.glb",
}

const SIMPLE_COLLIDERS := {
	"platform_deck": [Vector3(0.0, 0.0, 0.0), Vector3(4.0, 0.5, 4.0)],
	"bridge_span": [Vector3(0.0, 0.25, 0.0), Vector3(6.0, 0.5, 8.0)],
	"catwalk_deck": [Vector3(0.0, 0.0, 0.0), Vector3(2.0, 0.2, 4.0)],
	"cover_barrier": [Vector3(0.0, 0.55, 0.0), Vector3(2.4, 1.1, 0.7)],
	"crate_cluster": [Vector3(0.0, 0.75, 0.0), Vector3(2.1, 1.5, 1.8)],
	"pillar": [Vector3(0.0, 2.0, 0.0), Vector3(0.8, 4.0, 0.8)],
	"wall_panel": [Vector3(0.0, 2.0, 0.0), Vector3(4.0, 4.0, 0.45)],
	"cover_machine": [Vector3(0.0, 1.2, 0.0), Vector3(2.6, 2.4, 2.0)],
	"beacon_node": [Vector3(0.0, 2.1, 0.0), Vector3(1.5, 4.2, 1.5)],
	"railing": [Vector3(0.0, 0.55, 0.0), Vector3(4.0, 1.1, 0.16)],
	"tower_core": [Vector3(0.0, 16.0, 0.0), Vector3(11.0, 32.0, 11.0)],
}

var layout: Dictionary = {}
var _scene_cache: Dictionary = {}
var _piece_count: int = 0
var _collider_count: int = 0


func _ready() -> void:
	_build_world()


func provides_authored_colliders() -> bool:
	return true


func provides_authored_lighting() -> bool:
	return true


func get_world_summary() -> Dictionary:
	return {
		"world_id": "aetherfall",
		"piece_count": _piece_count,
		"collider_count": _collider_count,
	}


func _build_world() -> void:
	layout = _load_json_dict(LAYOUT_PATH)
	if layout.is_empty():
		push_error("AetherfallWorld: missing or invalid layout at %s" % LAYOUT_PATH)
		return

	var geo := Node3D.new()
	geo.name = "Geometry"
	add_child(geo)

	var col := StaticBody3D.new()
	col.name = "WorldStaticBody"
	col.collision_layer = 1
	col.collision_mask = 0
	add_child(col)

	for piece in layout.get("pieces", []):
		_spawn_layout_piece(piece as Dictionary, geo, col)

	_add_beacon_lights(layout.get("pieces", []))
	_add_connected_expanse(geo, col)
	_add_landmarks(geo, col)
	_add_archive_interior(geo, col)
	_add_phase2_cover(geo, col)
	_add_vertical_infrastructure(geo, col)
	_add_ice_planet_phase1(geo, col)
	print(
		(
			"AETHERFALL WORLD: %d modular GLB pieces, %d precision colliders"
			% [_piece_count, _collider_count]
		)
	)


func _spawn_layout_piece(piece: Dictionary, geo: Node3D, col: StaticBody3D) -> void:
	var kind := String(piece.get("kind", ""))
	if not MODEL_PATHS.has(kind):
		return
	var pos := _vec3(piece.get("pos", [0.0, 0.0, 0.0]))
	var rot_deg := float(piece.get("rot", 0.0))
	var rot_rad := deg_to_rad(rot_deg)
	var scale_vec := _vec3(piece.get("scale", [1.0, 1.0, 1.0]))

	var inst := _instantiate_model(kind)
	if inst == null:
		return
	inst.position = pos
	inst.rotation.y = rot_rad
	inst.scale = scale_vec
	geo.add_child(inst)
	_piece_count += 1

	if SIMPLE_COLLIDERS.has(kind):
		var spec: Array = SIMPLE_COLLIDERS[kind]
		var local_c: Vector3 = spec[0] * scale_vec
		var box_size: Vector3 = spec[1] * scale_vec
		var basis := Basis(Vector3.UP, rot_rad)
		_add_box(col, Transform3D(basis, pos + basis * local_c), box_size)
	elif kind == "stair_run":
		_add_slope_box(col, pos, rot_rad, 4.0, 2.5, 4.0, scale_vec)
	elif kind == "ramp_deck":
		_add_slope_box(col, pos, rot_rad, 4.0, 2.0, 6.0, scale_vec)


func _add_slope_box(
	body: StaticBody3D,
	origin: Vector3,
	yaw: float,
	width: float,
	rise: float,
	run_len: float,
	s: Vector3
) -> void:
	var w := width * s.x
	var h := rise * s.y
	var d := run_len * s.z
	var slope_len := sqrt(h * h + d * d)
	var pitch := atan2(h, d)
	var thickness := 0.35
	var yaw_basis := Basis(Vector3.UP, yaw)
	var local_basis := Basis(Vector3.RIGHT, pitch)
	var center_local := Vector3(0.0, h * 0.5 - thickness * 0.4, 0.0)
	_add_box(
		body,
		Transform3D(yaw_basis * local_basis, origin + yaw_basis * center_local),
		Vector3(w, thickness, slope_len)
	)


func _add_box(body: StaticBody3D, xf: Transform3D, size: Vector3) -> void:
	var shape_node := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = size
	shape_node.shape = box
	shape_node.transform = xf
	body.add_child(shape_node)
	_collider_count += 1


func _add_beacon_lights(pieces: Array) -> void:
	var lights := Node3D.new()
	lights.name = "BeaconLights"
	add_child(lights)
	for piece in pieces:
		var item := piece as Dictionary
		if String(item.get("kind", "")) != "beacon_node":
			continue
		var p := _vec3(item.get("pos", [0.0, 0.0, 0.0]))
		var omni := OmniLight3D.new()
		omni.position = p + Vector3(0.0, 3.6, 0.0)
		omni.light_color = Color(0.15, 0.72, 1.0)
		omni.light_energy = 2.0
		omni.omni_range = 14.0
		omni.omni_attenuation = 1.4
		lights.add_child(omni)


func _add_connected_expanse(geo: Node3D, col: StaticBody3D) -> void:
	var data := _load_json_dict(EXPANSION_PATH)
	if data.is_empty():
		return
	var expanse := Node3D.new()
	expanse.name = "ConnectedExpanse"
	geo.add_child(expanse)

	var field := _instantiate_model("lowland_field")
	if field != null:
		field.name = "LowlandField"
		expanse.add_child(field)
		_piece_count += 1
	_add_box(
		col, Transform3D(Basis.IDENTITY, Vector3(0.0, -19.25, 0.0)), Vector3(760.0, 1.5, 760.0)
	)

	var access := data.get("lowland_access", {}) as Dictionary
	for piece in access.get("pieces", []):
		_spawn_placed_entry(piece as Dictionary, expanse, col)

	for item in data.get("placements", []):
		var entry := item as Dictionary
		var kind := String(entry.get("kind", ""))
		var inst := _instantiate_model(kind)
		if inst == null:
			continue
		var pos := _vec3(entry.get("pos", [0.0, 0.0, 0.0]))
		var scale_vec := _vec3(entry.get("scale", [1.0, 1.0, 1.0]))
		var yaw := deg_to_rad(float(entry.get("rot", 0.0)))
		inst.position = pos
		inst.rotation.y = yaw
		inst.scale = scale_vec
		expanse.add_child(inst)
		_piece_count += 1
		if bool(entry.get("solid", false)):
			var c_size := _vec3(entry.get("collider", [4.0, 2.0, 4.0])) * scale_vec
			var c_off := _vec3(entry.get("collider_offset", [0.0, 1.0, 0.0])) * scale_vec
			var basis := Basis(Vector3.UP, yaw)
			_add_box(col, Transform3D(basis, pos + basis * c_off), c_size)


func _add_landmarks(geo: Node3D, col: StaticBody3D) -> void:
	var data := _load_json_dict(LANDMARKS_PATH)
	if data.is_empty():
		return
	var root := Node3D.new()
	root.name = "Landmarks"
	geo.add_child(root)
	for item in data.get("placements", []):
		_spawn_authored_structure(item as Dictionary, root, col)


func _add_archive_interior(geo: Node3D, col: StaticBody3D) -> void:
	var data := _load_json_dict(ARCHIVE_PHASE3_PATH)
	if data.is_empty():
		return
	var root := Node3D.new()
	root.name = "SentinelArchive"
	geo.add_child(root)

	var building := data.get("building", {}) as Dictionary
	if not building.is_empty():
		_spawn_authored_structure(building, root, col)

	for prop in data.get("interior_props", []):
		_spawn_authored_structure(prop as Dictionary, root, col)

	for light_spec in data.get("lights", []):
		var l := light_spec as Dictionary
		var omni := OmniLight3D.new()
		omni.name = String(l.get("id", "ArchiveLight"))
		omni.position = _vec3(l.get("position", [8.0, 3.0, -14.0]))
		var c: Array = l.get("color", [0.22, 0.78, 1.0])
		omni.light_color = Color(float(c[0]), float(c[1]), float(c[2]))
		omni.light_energy = float(l.get("energy", 1.25))
		omni.omni_range = float(l.get("range", 8.0))
		root.add_child(omni)


func _add_phase2_cover(geo: Node3D, col: StaticBody3D) -> void:
	var data := _load_json_dict(PHASE2_COVER_PATH)
	if data.is_empty():
		return
	var root := Node3D.new()
	root.name = "Phase2Cover"
	geo.add_child(root)
	for item in data.get("placements", []):
		var entry := item as Dictionary
		var kind := String(entry.get("asset", entry.get("kind", "")))
		var inst := _instantiate_model(kind)
		if inst == null:
			continue
		var pos := _vec3(entry.get("position", entry.get("pos", [0.0, 0.0, 0.0])))
		var rot := _vec3(entry.get("rotation_degrees", [0.0, 0.0, 0.0]))
		var scale_vec := _vec3(entry.get("scale", [1.0, 1.0, 1.0]))
		inst.position = pos
		inst.rotation_degrees = rot
		inst.scale = scale_vec
		root.add_child(inst)
		_piece_count += 1
		var yaw_basis := Basis.from_euler(
			Vector3(deg_to_rad(rot.x), deg_to_rad(rot.y), deg_to_rad(rot.z))
		)
		if entry.has("collision_box"):
			var cb := entry["collision_box"] as Dictionary
			var center := _vec3(cb.get("center", [0.0, 0.7, 0.0])) * scale_vec
			var size := _vec3(cb.get("size", [2.4, 1.3, 0.6])) * scale_vec
			_add_box(col, Transform3D(yaw_basis, pos + yaw_basis * center), size)
		elif kind == "wall_half":
			_add_box(
				col,
				Transform3D(yaw_basis, pos + yaw_basis * Vector3(0.0, 0.68, 0.0)),
				Vector3(3.2, 1.36, 0.48) * scale_vec
			)
		elif SIMPLE_COLLIDERS.has(kind):
			var spec: Array = SIMPLE_COLLIDERS[kind]
			_add_box(
				col,
				Transform3D(yaw_basis, pos + yaw_basis * (spec[0] * scale_vec)),
				spec[1] * scale_vec
			)


func _add_vertical_infrastructure(geo: Node3D, col: StaticBody3D) -> void:
	var data := _load_json_dict(VERTICALITY_PATH)
	if data.is_empty():
		return
	var root := Node3D.new()
	root.name = "VerticalInfrastructure"
	geo.add_child(root)
	for item in data.get("placements", []):
		_spawn_authored_structure(item as Dictionary, root, col)


func _add_ice_planet_phase1(geo: Node3D, col: StaticBody3D) -> void:
	var data := _load_json_dict(ICE_PLANET_PATH)
	if data.is_empty():
		return
	var root := Node3D.new()
	root.name = "IcePlanetAtmosphere"
	geo.add_child(root)

	for group_key in ["deck_snow", "frozen_dressing", "glacier_horizon", "sky_vista"]:
		for item in data.get(group_key, []):
			var entry := item as Dictionary
			var kind := String(entry.get("asset", entry.get("kind", "")))
			var inst := _instantiate_model(kind)
			if inst == null:
				continue
			var pos := _vec3(entry.get("position", entry.get("pos", [0.0, 0.0, 0.0])))
			var rot := _vec3(
				entry.get("rotation_degrees", [0.0, float(entry.get("rot", 0.0)), 0.0])
			)
			var s_raw: Variant = entry.get("scale", [1.0, 1.0, 1.0])
			var scale_vec := (
				Vector3.ONE * float(s_raw)
				if (s_raw is float or s_raw is int)
				else _vec3(s_raw as Array)
			)
			inst.position = pos
			inst.rotation_degrees = rot
			inst.scale = scale_vec
			root.add_child(inst)
			_piece_count += 1
			if entry.has("collision_box"):
				var cb := entry["collision_box"] as Dictionary
				var basis := Basis.from_euler(
					Vector3(deg_to_rad(rot.x), deg_to_rad(rot.y), deg_to_rad(rot.z))
				)
				_add_box(
					col,
					Transform3D(basis, pos + basis * (_vec3(cb["center"]) * scale_vec)),
					_vec3(cb["size"]) * scale_vec
				)

	_apply_ice_lighting(data.get("lighting", {}) as Dictionary)
	_spawn_snow_particles(data.get("snow_particles", {}) as Dictionary, root)


func _spawn_authored_structure(entry: Dictionary, parent: Node3D, col: StaticBody3D) -> void:
	var kind := String(entry.get("asset", entry.get("kind", "")))
	var inst := _instantiate_model(kind)
	if inst == null:
		return
	inst.name = String(entry.get("id", kind))
	var pos := _vec3(entry.get("position", entry.get("pos", [0.0, 0.0, 0.0])))
	var rot := _vec3(entry.get("rotation_degrees", [0.0, float(entry.get("rot", 0.0)), 0.0]))
	var scale_vec := _vec3(entry.get("scale", [1.0, 1.0, 1.0]))
	inst.position = pos
	inst.rotation_degrees = rot
	inst.scale = scale_vec
	parent.add_child(inst)
	_piece_count += 1

	var basis := Basis.from_euler(Vector3(deg_to_rad(rot.x), deg_to_rad(rot.y), deg_to_rad(rot.z)))
	for box_entry in entry.get("collision_boxes", []):
		var cb := box_entry as Dictionary
		var center := _vec3(cb.get("center", [0.0, 1.0, 0.0])) * scale_vec
		var size := _vec3(cb.get("size", [2.0, 2.0, 2.0])) * scale_vec
		_add_box(col, Transform3D(basis, pos + basis * center), size)
	if entry.has("collision_box"):
		var single := entry["collision_box"] as Dictionary
		var center := _vec3(single.get("center", [0.0, 1.0, 0.0])) * scale_vec
		var size := _vec3(single.get("size", [2.0, 2.0, 2.0])) * scale_vec
		_add_box(col, Transform3D(basis, pos + basis * center), size)

	if entry.has("light"):
		var l := entry["light"] as Dictionary
		var omni := OmniLight3D.new()
		omni.position = pos + basis * _vec3(l.get("position", [0.0, 3.0, 0.0]))
		var c: Array = l.get("color", [0.18, 0.67, 1.0])
		omni.light_color = Color(float(c[0]), float(c[1]), float(c[2]))
		omni.light_energy = float(l.get("energy", 1.15))
		omni.omni_range = float(l.get("range", 8.0))
		parent.add_child(omni)


func _spawn_placed_entry(entry: Dictionary, parent: Node3D, col: StaticBody3D) -> void:
	_spawn_layout_piece(entry, parent, col)


func _apply_ice_lighting(spec: Dictionary) -> void:
	var sun := get_node_or_null("Sun") as DirectionalLight3D
	if sun != null and spec.has("sun_color"):
		var sc: Array = spec["sun_color"]
		sun.light_color = Color(float(sc[0]), float(sc[1]), float(sc[2]))
		sun.light_energy = float(spec.get("sun_energy", 1.38))
	var fill := get_node_or_null("FillLight") as DirectionalLight3D
	if fill != null and spec.has("fill_color"):
		var fc: Array = spec["fill_color"]
		fill.light_color = Color(float(fc[0]), float(fc[1]), float(fc[2]))
		fill.light_energy = float(spec.get("fill_energy", 0.34))
	var world_env := get_node_or_null("WorldEnvironment") as WorldEnvironment
	if world_env == null or world_env.environment == null:
		return
	var env := world_env.environment
	if spec.has("ambient_color"):
		var ac: Array = spec["ambient_color"]
		env.ambient_light_color = Color(float(ac[0]), float(ac[1]), float(ac[2]))
	if spec.has("fog_color"):
		var fgc: Array = spec["fog_color"]
		env.fog_light_color = Color(float(fgc[0]), float(fgc[1]), float(fgc[2]))
	env.fog_density = float(spec.get("fog_density", 0.00055))
	env.tonemap_exposure = float(spec.get("tonemap_exposure", 1.02))


func _spawn_snow_particles(spec: Dictionary, parent: Node3D) -> void:
	if spec.is_empty():
		return
	var particles := GPUParticles3D.new()
	particles.name = "WindSnowDrift"
	particles.amount = clampi(int(spec.get("amount", 320)), 64, 480)
	particles.lifetime = float(spec.get("lifetime", 7.0))
	particles.preprocess = 2.0
	particles.visibility_aabb = AABB(Vector3(-90.0, -24.0, -90.0), Vector3(180.0, 64.0, 180.0))
	particles.position = Vector3(0.0, 16.0, 0.0)

	var mat := ParticleProcessMaterial.new()
	mat.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	mat.emission_box_extents = Vector3(68.0, 14.0, 56.0)
	mat.direction = Vector3(0.85, -0.42, 0.32).normalized()
	mat.spread = 14.0
	mat.initial_velocity_min = 4.2
	mat.initial_velocity_max = 7.4
	mat.gravity = Vector3(0.6, -1.35, 0.25)
	mat.scale_min = 0.05
	mat.scale_max = 0.13
	particles.process_material = mat

	var quad := QuadMesh.new()
	quad.size = Vector2(0.11, 0.11)
	var flake_mat := StandardMaterial3D.new()
	flake_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	flake_mat.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	flake_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	flake_mat.albedo_color = Color(0.86, 0.94, 1.0, 0.52)
	quad.material = flake_mat
	particles.draw_pass_1 = quad
	parent.add_child(particles)


func _instantiate_model(kind: String) -> Node3D:
	var path := String(MODEL_PATHS.get(kind, ""))
	if path.is_empty():
		return null
	if not _scene_cache.has(path):
		if not ResourceLoader.exists(path):
			push_warning("AetherfallWorld: missing model %s (%s)" % [kind, path])
			_scene_cache[path] = null
			return null
		_scene_cache[path] = load(path)
	var packed := _scene_cache[path] as PackedScene
	if packed == null:
		return null
	return packed.instantiate() as Node3D


func _load_json_dict(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		return {}
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	return parsed as Dictionary if parsed is Dictionary else {}


func _vec3(raw: Variant) -> Vector3:
	if raw is Vector3:
		return raw
	if raw is Array and (raw as Array).size() >= 3:
		var arr := raw as Array
		return Vector3(float(arr[0]), float(arr[1]), float(arr[2]))
	return Vector3.ZERO
