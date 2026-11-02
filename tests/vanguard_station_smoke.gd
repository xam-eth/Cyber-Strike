extends SceneTree

## Verifies SH-01 Aetherfall's architectural districts, interior Archive room,
## walkable snow terrain raycasts, and UI card plate integrity.
const MainScene = preload("res://scenes/main.tscn")

var _failures: Array[String] = []


func _initialize() -> void:
	call_deferred("_run")


func _expect(condition: bool, message: String) -> bool:
	if not condition:
		_failures.append(message)
		printerr("  fail: " + message)
	return condition


func _run() -> void:
	var previous := WorldSelection.override_selection(&"aetherfall")
	var main := MainScene.instantiate()
	main.set("start_wave_session_on_ready", false)
	main.get_node("ProgressionService").set("profile_path", "")
	root.add_child(main)
	for _i in 4:
		await process_frame
		await physics_frame
	WorldSelection.override_selection(previous)

	var world := main.get_node_or_null("MissionWorld/RealFrontierWorld") as Node3D
	if not _expect(world != null, "SH-01 Aetherfall mounts under MissionWorld/RealFrontierWorld"):
		main.queue_free()
		quit(1)
		return

	_expect(
		(
			world.get_node_or_null("Modules") != null
			and world.get_node_or_null("Collision") != null
			and world.get_node_or_null("ArchiveInterior") != null
			and world.get_node_or_null("StructuralLandmarks") != null
			and world.get_node_or_null("ConnectedExpanse") != null
		),
		"Aetherfall builds Modules, Collision, ArchiveInterior, Landmarks, and Expanse",
	)

	var space := world.get_world_3d().direct_space_state
	for probe in [
		{"name": "Arrival Outpost", "pos": Vector3(-30.0, 8.0, 14.0)},
		{"name": "Horizon Relay", "pos": Vector3(8.0, 8.0, 7.0)},
		{"name": "Sentinel Archive", "pos": Vector3(8.0, 4.0, -14.3)},
		{"name": "East Hangar", "pos": Vector3(30.0, 8.0, 9.5)},
	]:
		var from: Vector3 = probe["pos"]
		var query := PhysicsRayQueryParameters3D.create(from, from + Vector3(0.0, -25.0, 0.0), 1)
		var hit := space.intersect_ray(query)
		_expect(
			not hit.is_empty(),
			"%s has solid walkable ground beneath it" % String(probe["name"]),
		)

	var wdef := WorldDefinition.load_definition(&"aetherfall")
	_expect(
		wdef != null and FileAccess.file_exists(wdef.plate_path),
		"Aetherfall plate image exists on disk (%s)" % (wdef.plate_path if wdef else ""),
	)

	for retired in [
		"frostline_relay",
		"verdant_bloom",
		"emberfall_foundry",
		"vanguard_station",
		"titans",
	]:
		_expect(
			not ResourceLoader.exists("res://resources/worlds/%s.tres" % retired),
			"retired legacy world %s.tres is completely removed" % retired,
		)

	main.queue_free()
	await process_frame
	if _failures.is_empty():
		print("Aetherfall district & structure smoke test passed.")
		quit()
	else:
		quit(1)
