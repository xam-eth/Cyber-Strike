extends SceneTree

## world_guidance_smoke.gd -- the "there are no directions" fix.
##
## The gameplay bug report: the player spawns with no idea where to go. The old
## `_add_wayfinders()` created invisible Marker3D nodes only. This test proves
## the visible guidance layer exists and is built from real mission data:
##
##   * an arrival pad + briefing pillar at the authored spawn,
##   * a billboard label carrying the real first objective's display name,
##   * ground chevron arrows routing spawn -> primary cache -> later caches,
##   * everything presentation-only (zero colliders under WorldGuidance).

const WorldScene = preload("res://scenes/worlds/mission_world.tscn")

var _passed := true


func _initialize() -> void:
	call_deferred("_run_smoke_test")


func _run_smoke_test() -> void:
	var world := WorldScene.instantiate() as Node3D
	world.set("world_override", "aetherfall")
	root.add_child(world)
	for _warm in 6:
		await process_frame
	await physics_frame

	var guidance := world.get_node_or_null("WorldGuidance") as Node3D
	if not _expect(guidance != null, "MissionWorld installs the visible WorldGuidance layer"):
		world.queue_free()
		await process_frame
		quit(1)
		return

	var definition := WorldDefinition.load_definition(&"aetherfall")
	_passed = _expect(definition != null, "Aetherfall WorldDefinition loads") and _passed
	var spawn: Vector3 = definition.player_spawn if definition != null else Vector3.ZERO

	var pad := guidance.get_node_or_null("ArrivalPad") as MeshInstance3D
	_passed = _expect(pad != null, "arrival pad exists at the spawn") and _passed
	if pad != null:
		_passed = (
			_expect(
				(
					pad.global_position.distance_to(
						Vector3(spawn.x, pad.global_position.y, spawn.z)
					)
					< 0.2
				),
				"arrival pad sits at the authored spawn (%s)" % pad.global_position,
			)
			and _passed
		)
	var ring := guidance.get_node_or_null("ArrivalPadRing") as MeshInstance3D
	_passed = _expect(ring != null, "arrival pad carries its yellow guide ring") and _passed

	var label := guidance.get_node_or_null("BriefingLabel") as Label3D
	_passed = _expect(label != null, "briefing sign exists at the arrival pad") and _passed
	if label != null:
		_passed = (
			_expect(
				label.text.contains("ARRIVAL OUTPOST"),
				"briefing sign names the arrival area (%s)" % label.text.split("\n")[0],
			)
			and _passed
		)
		var primary_name := ""
		if definition != null:
			for cache in definition.recovery_caches:
				if cache != null and String(cache.cache_id).contains("primary"):
					primary_name = String(cache.display_name)
					break
		_passed = (
			_expect(
				not primary_name.is_empty() and label.text.contains(primary_name),
				"briefing sign shows the real first objective '%s'" % primary_name,
			)
			and _passed
		)
		_passed = (
			_expect(
				label.billboard == BaseMaterial3D.BILLBOARD_FIXED_Y,
				"briefing sign is billboarded toward the player",
			)
			and _passed
		)

	var chevrons := guidance.find_children("Chevron*", "Label3D", true, false)
	_passed = (
		_expect(chevrons.size() >= 4, "route chevrons mark the way (%d)" % chevrons.size())
		and _passed
	)
	var chevron_meta := int(guidance.get_meta("chevrons", 0))
	_passed = (
		_expect(
			chevron_meta == chevrons.size(),
			"chevron telemetry matches the visible arrows (%d)" % chevron_meta,
		)
		and _passed
	)
	for candidate in chevrons:
		var chevron := candidate as Label3D
		if chevron == null:
			continue
		if not _expect(chevron.text == "▲", "chevron glyph is a direction arrow"):
			_passed = false
		if not _expect(chevron.visible, "chevron %s is visible" % chevron.name):
			_passed = false
		if not _expect(
			chevron.global_position.y < 1.0 and chevron.global_position.y > -1.0,
			"chevron %s lies on the deck" % chevron.name
		):
			_passed = false

	# Guidance is presentation-only: it must never add physics blockers.
	var bodies := guidance.find_children("*", "StaticBody3D", true, false)
	_passed = (
		_expect(bodies.is_empty(), "guidance adds no colliders (%d found)" % bodies.size())
		and _passed
	)

	world.queue_free()
	await process_frame

	if _passed:
		print("WORLD GUIDANCE smoke test passed.")
		quit()
	else:
		quit(1)


func _expect(condition: bool, message: String) -> bool:
	if not condition:
		push_error("WORLD GUIDANCE smoke test failed: " + message)
	return condition
