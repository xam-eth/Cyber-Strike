extends SceneTree

## Vanguard Station — the second world, checked the way a player meets it.
##
## The brief for this world is "full assets, no random procedural stand-ins", so
## this test asks questions about the *imported modules* and not about counts:
## which pack model each node came from, whether every module is inside its room,
## whether the ceiling is above head height, and whether a body can walk from the
## spawn point through the gate, into the reactor hall, across to the cargo bay
## and down the corridor.
##
## It selects the world first: both theatres are instanced by `main.tscn` and each
## builds only when selected, so a test that did not select would silently check
## two empty nodes and pass.

const MainScene = preload("res://scenes/main.tscn")
const ScifiKitLibrary = preload("res://scripts/worlds/scifi_kit_library.gd")

var _passes := 0
var _failures: Array[String] = []


func _initialize() -> void:
	call_deferred("_run")


func _expect(condition: bool, message: String) -> bool:
	if condition:
		_passes += 1
	else:
		_failures.append(message)
		print("  fail: " + message)
	return condition


func _run() -> void:
	# A `--script` test has no autoloads, so selection goes through the explicit
	# hook rather than through `ProgressionService`.
	var previous := WorldSelection.override_selection(&"vanguard_station")

	var main := MainScene.instantiate()
	main.set("start_wave_session_on_ready", false)
	root.add_child(main)
	await process_frame
	await physics_frame

	var station: Node3D = main.get_node_or_null("VanguardStation")
	var frontier: Node3D = main.get_node_or_null("NeonFrontier")
	if not _expect(station != null, "the station world is instanced by the gameplay scene"):
		_finish()
		return
	if not _expect(frontier != null, "the first world is still instanced beside it"):
		_finish()
		return

	# 1. The first world must not have built under this one.
	_expect(
		frontier.get_node_or_null("ArenaFloor") == null,
		"Neon Frontier does not build while Vanguard Station is selected"
	)
	var station_root: Node3D = station.get_node_or_null("Station")
	if not _expect(station_root != null, "the station built itself"):
		_finish()
		return

	# 2. Every room exists, and is built from imported modules.
	for room in VanguardStationWorld.ROOMS:
		var count := _count_room(station_root, room)
		_expect(count >= 20, "%s has %d kit modules (>= 20)" % [room, count])

	# 2b. The furniture the first frame is composed around is actually there. This
	#     is a separate assertion because the crates were built and invisible for
	#     two captures running: existence and framing are different failures.
	var containers := _count_named(station_root, "HangarContainer")
	var crates := _count_named(station_root, "HangarCoverCrate")
	_expect(
		containers >= 4 and crates >= 2,
		"the spawn apron has %d containers and %d crates" % [containers, crates]
	)
	_expect(
		(
			_count_named(station_root, "DockGate") >= 1
			and _count_named(station_root, "HallNumeral") >= 2
		),
		"the dock gate and its numerals exist"
	)

	# 2c. The objective card belongs to the theatre. It printed one world's copy in
	#     every world until the strings moved into the definitions.
	var station_definition := WorldDefinition.load_definition(&"vanguard_station")
	var frontier_definition := WorldDefinition.load_definition(&"neon_frontier")
	_expect(
		(
			station_definition != null
			and frontier_definition != null
			and station_definition.zone_title != frontier_definition.zone_title
			and station_definition.zone_subtitle != frontier_definition.zone_subtitle
		),
		"each world states its own explore-mode copy"
	)

	# 2d. The card's plate is the station. It shipped for a while as a byte copy
	#     of the frontier's, which is a card advertising one theatre with a
	#     photograph of another.
	var plate := FileAccess.get_md5("res://assets/ui/world_vanguard_station.jpg")
	var frontier_plate := FileAccess.get_md5("res://assets/ui/world_neon_frontier.jpg")
	_expect(
		not plate.is_empty() and plate != frontier_plate,
		"the station's card plate is its own image"
	)

	# 2e. A sign is only a sign if the artwork survives. The palette overrides
	#     every surface with a flat colour, which had turned the pack's caution and
	#     danger signs into blank rectangles.
	var signs_with_art := 0
	for node in station_root.get_children():
		if not String(node.name).begins_with("HallCautionWest"):
			continue
		for mesh in node.find_children("*", "MeshInstance3D", true, false):
			var mesh_instance := mesh as MeshInstance3D
			for index in range(mesh_instance.mesh.get_surface_count()):
				var surface := mesh_instance.get_active_material(index) as StandardMaterial3D
				if surface != null and surface.albedo_texture != null:
					signs_with_art += 1
	_expect(signs_with_art > 0, "the hall's caution sign keeps its printed artwork")

	# 3. No module is a bare MeshInstance3D placed by hand: each one hangs off a
	#    pivot whose child is an imported scene with a MeshInstance3D under it.
	var non_kit := 0
	for node in station_root.get_children():
		var mesh := node.get_node_or_null("Mesh")
		if mesh == null:
			continue
		if not mesh.is_in_group(&"uploaded_fbx_visual"):
			non_kit += 1
	_expect(non_kit == 0, "every module is an imported kit asset (%d strays)" % non_kit)

	# 4. The modules this world claims to use resolve, and to measured sizes.
	for key in [
		"wall", "floor", "doorway_large", "roof", "roof_glass", "console_half", "crate", "gear"
	]:
		var size := ScifiKitLibrary.size(key)
		_expect(size.length() > 0.0, "%s has a measured footprint" % key)

	# 5. Head height. The ceiling must clear a 1.8 m player with room to spare,
	#    or the arena is a crawlspace with a reactor in it.
	_expect(
		VanguardStationWorld.ROOF_Y - VanguardStationWorld.WALL_HEIGHT > 0.2,
		"the roof clears the 4 m wall modules"
	)

	# 6. A body can walk the route. The player is parked out of the way first: a
	#    capsule sweep down the room's centre line hits whatever stands at the
	#    spawn point, and the first run of this test reported every route blocked
	#    "by Main" — which was the player, standing exactly where the player does.
	#    The training drone stands in the reactor doorway, so it moves too: both of
	#    them are fixed obstacles as far as a walkability sweep is concerned.
	var parked: Array[Node3D] = []
	for node_name in ["Player", "TrainingDrone"]:
		var body: Node3D = main.get_node_or_null(node_name)
		if body == null:
			continue
		parked.append(body)
		body.set_meta("smoke_was_at", body.global_position)
		body.global_position = Vector3(0.0, 60.0, 0.0)
		body.set_physics_process(false)
	await physics_frame
	# Capsule at player proportions, sampled every 0.5 m along four legs, and
	# nothing may intersect it.
	var space := root.world_3d.direct_space_state
	_check_route(space, "spawn to gate", Vector3(0.0, 1.0, 0.0), Vector3(0.0, 1.0, 17.5))
	_check_route(space, "hangar to reactor", Vector3(0.0, 1.0, 0.0), Vector3(0.0, 1.0, -31.0))
	_check_route(space, "hangar to cargo", Vector3(-6.0, 1.0, 0.0), Vector3(-28.0, 1.0, 0.0))
	_check_route(space, "hangar to corridor", Vector3(6.0, 1.0, 0.0), Vector3(35.0, 1.0, 0.0))

	# 7. The deck exists where the player stands: a ray straight down must hit a
	#    body at the spawn point, or the spawn is over a hole.
	var from := Vector3(0.0, 2.0, 8.0)
	var query := PhysicsRayQueryParameters3D.create(from, from + Vector3(0.0, -3.0, 0.0))
	var hit := root.world_3d.direct_space_state.intersect_ray(query)
	_expect(not hit.is_empty(), "there is deck under the player spawn")

	# 8. Budget, printed rather than asserted, so a later change has a baseline.
	var meshes := 0
	var lights := 0
	for node in _all(station_root):
		if node is MeshInstance3D:
			meshes += 1
		elif node is OmniLight3D:
			lights += 1
	print(
		(
			"VanguardStation: %d modules, %d mesh instances, %d omnis"
			% [station_root.get_child_count(), meshes, lights]
		)
	)
	_finish()


func _check_route(space: PhysicsDirectSpaceState3D, label: String, a: Vector3, b: Vector3) -> void:
	var steps := int(a.distance_to(b) / 0.5)
	var blocked := ""
	for step in range(steps + 1):
		var at := a.lerp(b, float(step) / float(maxi(steps, 1)))
		var shape := CapsuleShape3D.new()
		shape.radius = 0.42
		shape.height = 1.8
		var query := PhysicsShapeQueryParameters3D.new()
		query.shape = shape
		query.transform = Transform3D(Basis(), at)
		var hits := space.intersect_shape(query, 1)
		if not hits.is_empty():
			var collider: Node = hits[0].get("collider")
			var owner_name := "?"
			if collider != null and collider.get_parent() != null:
				owner_name = String(collider.get_parent().name)
			blocked = "at %.1f, %.1f by %s" % [at.x, at.z, owner_name]
			break
	_expect(blocked == "", "%s is walkable (%s)" % [label, blocked])


func _count_named(root: Node3D, prefix: String) -> int:
	var count := 0
	for node in root.get_children():
		if String(node.name).begins_with(prefix):
			count += 1
	return count


func _count_room(root: Node3D, room: String) -> int:
	var count := 0
	for node in root.get_children():
		if String(node.get_meta("station_room", "")) == room:
			count += 1
	return count


func _all(node: Node) -> Array[Node]:
	var out: Array[Node] = [node]
	for child in node.get_children():
		out.append_array(_all(child))
	return out


func _finish() -> void:
	print("Vanguard station smoke: %d passed, %d failed" % [_passes, _failures.size()])
	if _failures.is_empty():
		print("Vanguard station smoke test PASSED")
	else:
		print("Vanguard station smoke test FAILED:")
		for failure in _failures:
			print("  - " + failure)
	quit(0 if _failures.is_empty() else 1)
