extends SceneTree
##
## mission_world_smoke.gd — every mission world is real and works in the engine.
##
## This test used to assert the *procedural* build: component scenes generated in
## GDScript, an FBX kit, a hand-built arena bay, per-route causeway nodes. None of
## that exists any more. Each mission world is one staged GLB assembled by the
## asset forge, so what is worth asserting is different, and
## stricter:
##
##   for every world:
##     1. the declared GLB imports and is instanced under the world node,
##     2. it carries the geometry and it is not empty or a placeholder,
##     3. every single MeshInstance3D in the world lives inside that GLB —
##        nothing is added by code,
##     4. the authored clips are running (one player per clip),
##     5. the lighting rig matches the world's own mood, and all moods are
##        actually different from one another,
##     6. the collision floor covers that world's field and not another's size.
##
##   for the default world, through `main.tscn`:
##     7. the player can walk the field and cross to the outpost district.
##
## (3) is the in-engine version of the forge's asset-policy gate: it fails the day
## somebody adds a MeshInstance3D with a primitive mesh to the world script.
##
const MainScene = preload("res://scenes/main.tscn")
const WorldScene = preload("res://scenes/worlds/mission_world.tscn")
const WorldScript = preload("res://scripts/worlds/mission_world.gd")

## Per world: the number of meshes and clips the staged GLB is known to carry. The
## floors sit just under those counts, so losing a district fails the test while a
## re-tune of a scatter field does not need this file edited.
const EXPECTED := {
	"frostline_relay": {"meshes": 175, "clips": 60, "textures": 8, "field": Vector2(168.0, 156.0)},
	"verdant_bloom": {"meshes": 210, "clips": 150, "textures": 4, "field": Vector2(176.0, 164.0)},
	"emberfall_foundry":
	{"meshes": 400, "clips": 40, "textures": 40, "field": Vector2(200.0, 176.0)},
	"titans": {"meshes": 180, "clips": 48, "textures": 19, "field": Vector2(64.0, 64.0)},
}

var _passed := true


func _initialize() -> void:
	call_deferred("_run_smoke_test")


func _run_smoke_test() -> void:
	# The launcher selects by world id, so every registry id has to resolve back to
	# itself. This is the bug that shipped once: the map of launcher ids to worlds
	# held the forge's short names and not the ids the launcher actually uses, so
	# the default world silently refused to build.
	for definition in WorldDefinition.DEFINITION_IDS:
		if not WorldMood.MOODS.has(String(definition)):
			continue
		_passed = (
			_expect(
				WorldScript.world_for_selection(String(definition)) == String(definition),
				"the launcher id '%s' resolves to that world" % definition,
			)
			and _passed
		)

	var seen_key_colors: Array[Color] = []
	for world_id in WorldMood.MOOD_ORDER:
		var key_color: Variant = await _check_world(world_id)
		if key_color != null:
			seen_key_colors.append(key_color)

	# If two theatres share a key light they are the same theatre with different
	# props. The count follows the mission registry rather than a hard-coded roster.
	_passed = (
		_expect(
			(
				seen_key_colors.size() == WorldMood.MOOD_ORDER.size()
				and _all_distinct(seen_key_colors)
			),
			(
				"each mission world is lit by its own key colour (got %d distinct)"
				% _distinct_count(seen_key_colors)
			),
		)
		and _passed
	)

	await _check_gameplay_scene()
	await _check_titans_gameplay_scene()

	if _passed:
		print("MISSION WORLD smoke test passed.")
		quit()
	else:
		quit(1)


## Everything that can be asserted about one world on its own.
## Returns the key light colour, or null if the world did not build.
func _check_world(world_id: String) -> Variant:
	print("--- %s" % WorldMood.label(world_id))
	var world := WorldScene.instantiate() as Node3D
	world.set("world_override", world_id)
	root.add_child(world)
	# The GLB import is lazy on first load; give the animation players a frame to
	# register their clips before we count them.
	for _warm in 4:
		await process_frame

	var expected: Dictionary = EXPECTED[world_id]
	var real_world := world.get_node_or_null("RealFrontierWorld") as Node3D
	if not _expect(real_world != null, "%s instances its staged GLB" % world_id):
		world.queue_free()
		await process_frame
		return null

	_passed = (
		_expect(
			String(real_world.get_meta("world_id", "")) == world_id,
			"%s is the world that was actually loaded" % world_id,
		)
		and _passed
	)

	var all_meshes := world.find_children("*", "MeshInstance3D", true, false)
	var glb_meshes := real_world.find_children("*", "MeshInstance3D", true, false)
	print("%s: %d meshes, all from the GLB." % [world_id, glb_meshes.size()])
	_passed = (
		_expect(
			glb_meshes.size() >= int(expected["meshes"]),
			(
				"%s carries its geometry (%d meshes, floor %d)"
				% [world_id, glb_meshes.size(), int(expected["meshes"])]
			),
		)
		and _passed
	)
	_passed = (
		_expect(
			all_meshes.size() == glb_meshes.size(),
			(
				"%s adds no mesh outside the real GLB (%d foreign)"
				% [world_id, all_meshes.size() - glb_meshes.size()]
			),
		)
		and _passed
	)

	# Every mesh must arrive with a surface and a material: an import that lost
	# its materials would still pass a mesh count.
	var textured := 0
	var bare := 0
	for candidate in glb_meshes:
		var mesh_instance := candidate as MeshInstance3D
		if mesh_instance.mesh == null or mesh_instance.mesh.get_surface_count() == 0:
			bare += 1
			continue
		var material := mesh_instance.get_active_material(0) as StandardMaterial3D
		if material != null and material.albedo_texture != null:
			textured += 1
	_passed = (
		_expect(bare == 0, "%s has no surface-less mesh (%d bare)" % [world_id, bare]) and _passed
	)
	_passed = (
		_expect(
			textured >= int(expected["textures"]),
			(
				"%s keeps its photographic maps (%d textured surfaces, floor %d)"
				% [world_id, textured, int(expected["textures"])]
			),
		)
		and _passed
	)

	var clip_players := 0
	for candidate in real_world.find_children("Clip_*", "AnimationPlayer", true, false):
		var clip_player := candidate as AnimationPlayer
		if clip_player.is_playing():
			clip_players += 1
	print("%s: %d authored clips running." % [world_id, clip_players])
	_passed = (
		_expect(
			clip_players >= int(expected["clips"]),
			(
				"%s animates its components (%d clips, floor %d)"
				% [world_id, clip_players, int(expected["clips"])]
			),
		)
		and _passed
	)

	var key_color: Variant = _check_mood(world, world_id)
	if key_color == null:
		_passed = _expect(false, "%s has its lighting rig" % world_id) and _passed

	var floor_shape := _floor_shape(world)
	_passed = (
		_expect(
			floor_shape != null,
			"%s has a collision floor" % world_id,
		)
		and _passed
	)
	if floor_shape != null:
		var expected_field: Vector2 = expected["field"]
		_passed = (
			_expect(
				(
					is_equal_approx(floor_shape.size.x, expected_field.x)
					and is_equal_approx(floor_shape.size.z, expected_field.y)
				),
				(
					"%s's collision floor matches its own field (%.1f × %.1f)"
					% [world_id, floor_shape.size.x, floor_shape.size.z]
				),
			)
			and _passed
		)

	if world_id == "titans":
		var triangle_colliders := 0
		for candidate in real_world.find_children("*", "CollisionShape3D", true, false):
			var collision := candidate as CollisionShape3D
			if collision.shape is ConcavePolygonShape3D:
				triangle_colliders += 1
		_passed = (
			_expect(
				triangle_colliders >= int(expected["meshes"]),
				(
					"Titans uses its authored deck/stair/walkway triangles, not role-filling boxes "
					+ "(%d mesh colliders)" % triangle_colliders
				),
			)
			and _passed
		)
		_passed = (
			_expect(
				world.get_node_or_null("FrontierPropCollision") == null,
				"Titans does not also build the flat-arena prop-box collider",
			)
			and _passed
		)

	world.queue_free()
	await process_frame
	return key_color


## The lighting rig must agree with `WorldMood`, which is what the launcher card
## promises and what the forge theme says. Returns the key colour on success.
func _check_mood(world: Node3D, world_id: String) -> Variant:
	var mood := WorldMood.mood(world_id)
	var key := world.get_node_or_null(String(mood["key"]["name"])) as DirectionalLight3D
	var fill := world.get_node_or_null(String(mood["fill"]["name"])) as DirectionalLight3D
	var rim := world.get_node_or_null(String(mood["rim"]["name"])) as DirectionalLight3D
	var accent := world.get_node_or_null("MissionAccentLight") as OmniLight3D
	var environment := world.get_node_or_null("ArenaEnvironment") as WorldEnvironment
	if key == null or fill == null or rim == null or accent == null or environment == null:
		return null
	var env := environment.environment
	if env == null:
		return null

	# Colours are stored as sRGB `Color` values on both sides, so this compares
	# the same numbers the theme file holds.
	var ok := (
		_near(key.light_color, mood["key"]["color"])
		and _near(fill.light_color, mood["fill"]["color"])
		and _near(rim.light_color, mood["rim"]["color"])
		and _near(accent.light_color, mood["accent"])
		and _near(env.background_color, mood["sky"])
		and _near(env.ambient_light_color, mood["ambient"])
		and _near(env.fog_light_color, mood["fog"])
		and is_equal_approx(env.fog_density, float(mood["fog_density"]))
		and key.shadow_enabled
		and not fill.shadow_enabled
		and not rim.shadow_enabled
		and env.tonemap_mode == Environment.TONE_MAPPER_ACES
		and is_equal_approx(env.adjustment_saturation, float(mood["saturation"]))
	)
	# And the range the mood is meant to occupy: a key light that drifts into a
	# muddy grey would still "match" a typo in both files, so check the intent.
	match world_id:
		"frostline_relay":
			ok = ok and key.light_color.b > key.light_color.r and env.ambient_light_color.b > 0.4
		"verdant_bloom":
			ok = (
				ok
				and key.light_color.r > 0.9
				and key.light_color.b < 0.8
				and env.ambient_light_color.g > 0.5
			)
		"emberfall_foundry":
			ok = ok and key.light_color.r > 0.9 and key.light_color.r > key.light_color.b * 2.0
		"titans":
			ok = (
				ok
				and key.light_color.r > 0.9
				and key.light_color.g > key.light_color.b
				and fill.light_color.b > fill.light_color.r
			)
	_passed = _expect(ok, "%s's lights, sky and fog are its theme" % world_id) and _passed
	return key.light_color


func _floor_shape(world: Node3D) -> BoxShape3D:
	var collision := (
		world.get_node_or_null("ArenaFloor/ArenaFloorCollisionShape") as CollisionShape3D
	)
	if collision == null:
		return null
	return collision.shape as BoxShape3D


## The default world through the real gameplay scene, including a walk.
func _check_gameplay_scene() -> void:
	print("--- gameplay scene (%s)" % WorldMood.label(WorldMood.MOOD_ORDER[0]))
	var main_scene := MainScene.instantiate()
	main_scene.set("start_wave_session_on_ready", false)
	root.add_child(main_scene)
	await process_frame
	await physics_frame
	for _warm in 4:
		await process_frame

	var world: Node3D = main_scene.get_node("MissionWorld")
	var player: Node3D = main_scene.get_node("Player")

	var real_world := world.get_node_or_null("RealFrontierWorld") as Node3D
	_passed = (
		_expect(
			real_world != null,
			(
				"the gameplay scene builds a world (launcher selected '%s', node has %d child(ren), script %s)"
				% [
					String(WorldSelection.selected(world)),
					world.get_child_count(),
					"present" if world.get_script() != null else "MISSING",
				]
			),
		)
		and _passed
	)
	if real_world == null:
		main_scene.queue_free()
		await process_frame
		return
	_passed = (
		_expect(
			String(real_world.get_meta("world_id", "")) == "frostline_relay",
			"an empty selection resolves to the default mission world",
		)
		and _passed
	)

	for wayfinder in ["NorthRouteWayfinder", "SouthRouteWayfinder"]:
		_passed = (
			_expect(
				world.get_node_or_null(wayfinder) != null,
				"non-visual waypoint exists: " + wayfinder,
			)
			and _passed
		)

	# Walk the field: the GLB is visual, the collision floor is the ground.
	player.global_position = Vector3(0.0, 0.0, 8.0)
	player.set("velocity", Vector3.ZERO)
	player.call("set_touch_movement", Vector2.UP)
	for _frame in 800:
		await physics_frame
		if player.global_position.z <= -49.0:
			break
	player.call("set_touch_movement", Vector2.ZERO)
	_passed = (
		_expect(
			player.global_position.z <= -49.0,
			"player can walk from the arena to the boss gate on the real world floor",
		)
		and _passed
	)
	print("Central-to-boss traversal ended at %s." % player.global_position)

	# Along z = 8 the outpost lane is clear: the command centre sits at z = -4 and
	# the depot at z = 19, and both are solid now that the props have colliders.
	player.global_position = Vector3(-40.0, 0.0, 8.0)
	player.set("velocity", Vector3.ZERO)
	player.call("set_touch_movement", Vector2.LEFT)
	for _frame in 400:
		await physics_frame
		if player.global_position.x <= -60.0:
			break
	player.call("set_touch_movement", Vector2.ZERO)
	_passed = (
		_expect(
			player.global_position.x <= -60.0,
			"player can cross to the outpost district",
		)
		and _passed
	)

	main_scene.queue_free()
	await process_frame


## Titans uses the same main.tscn and selection resolver as shell DEPLOY. Check
## both the authored Hangar spawn and its physical result; a correct coordinate
## that drops the player through the station is not a working deployment.
func _check_titans_gameplay_scene() -> void:
	print("--- gameplay scene (THE TITANS)")
	var previous := WorldSelection.override_selection(&"titans")
	var main_scene := MainScene.instantiate()
	main_scene.set("start_wave_session_on_ready", false)
	root.add_child(main_scene)
	# _ready() has run synchronously, so this is the WorldDefinition mapping
	# before gravity or collision recovery can move the body.
	var player := main_scene.get_node("Player") as CharacterBody3D
	var initial_spawn := player.position
	_passed = (
		_expect(
			initial_spawn.is_equal_approx(Vector3(0.0, 0.1, -20.0)),
			"Titans DEPLOY resolves the authored Hangar spawn, got %s" % initial_spawn,
		)
		and _passed
	)

	var world := main_scene.get_node("MissionWorld") as Node3D
	var real_world := world.get_node_or_null("RealFrontierWorld") as Node3D
	_passed = (
		_expect(
			real_world != null and String(real_world.get_meta("world_id", "")) == "titans",
			"the selected Titans card builds titans.glb through main.tscn",
		)
		and _passed
	)

	for _frame in 24:
		await physics_frame
	_passed = (
		_expect(
			player.is_on_floor() and player.position.y > -0.75 and player.position.y < 0.75,
			"Titans Hangar spawn settles on real collision, got %s" % player.position,
		)
		and _passed
	)

	# Walk north along the Hangar spine. This is a short deployment smoke, not a
	# claim that every stair, pit and launch route has been traversed.
	player.set("velocity", Vector3.ZERO)
	player.call("set_touch_movement", Vector2.UP)
	for _frame in 60:
		await physics_frame
	player.call("set_touch_movement", Vector2.ZERO)
	_passed = (
		_expect(
			player.position.z < -22.0 and player.position.z > -31.0 and player.position.y > -1.0,
			"player can leave the Titans spawn along the Hangar spine, got %s" % player.position,
		)
		and _passed
	)
	print("Titans Hangar traversal ended at %s." % player.position)
	await _probe_titans_multi_level(player)

	main_scene.queue_free()
	await process_frame
	WorldSelection.override_selection(previous)


## Report multi-level physics without disguising a blocked route as a passing
## assertion. The World source owns whether the sealed pit and elevated Reactor
## stair should be opened/connected; that is not a merge-adapter decision.
## Direct spawns on the walkway/launch probe their surfaces only, never a route
## from the Hangar. Read the emitted positions before claiming traversability.
func _probe_titans_multi_level(player: CharacterBody3D) -> void:
	var space := player.get_world_3d().direct_space_state
	var excluded: Array[RID] = [player.get_rid()]
	var pit_query := PhysicsRayQueryParameters3D.create(
		Vector3(0.0, 1.0, 0.0), Vector3(0.0, -3.0, 0.0), 1, excluded
	)
	var lower_query := PhysicsRayQueryParameters3D.create(
		Vector3(0.0, -0.55, 0.0), Vector3(0.0, -3.0, 0.0), 1, excluded
	)
	var pit_hit := space.intersect_ray(pit_query)
	var lower_hit := space.intersect_ray(lower_query)
	var pit_position: Vector3 = pit_hit.get("position", Vector3.INF)
	var lower_position: Vector3 = lower_hit.get("position", Vector3.INF)
	_probe_notice(
		"pit rays",
		(
			"first floor below Y=1 is %s; lower-pit ray from Y=-0.55 is %s"
			% [pit_position, lower_position]
		)
	)

	await _probe_move(
		player, "Lab north stairs from deck", Vector3(0.0, 0.7, -6.0), Vector2.DOWN, 120
	)
	# This is a surface probe, not proof that the walkway is reachable.
	await _probe_move(
		player, "walkway surface (direct spawn)", Vector3(0.0, 3.2, -8.0), Vector2.RIGHT, 90
	)
	await _probe_move(
		player, "Reactor stairs from ground", Vector3(0.0, 0.1, 15.0), Vector2.DOWN, 180
	)
	# The authored pedestal is 4.5 + 2.2m high. Probe its top directly; do not
	# imply that the disconnected Reactor stair provided a route to this point.
	await _probe_move(
		player, "launch surface (direct spawn)", Vector3(-0.5, 6.9, 24.0), Vector2.ZERO, 1, 30
	)


func _probe_move(
	player: CharacterBody3D,
	label: String,
	start: Vector3,
	direction: Vector2,
	frames: int,
	settle_frames := 8
) -> void:
	player.global_position = start
	player.velocity = Vector3.ZERO
	player.call("set_touch_movement", Vector2.ZERO)
	for _frame in settle_frames:
		await physics_frame
	var settled := player.global_position
	player.call("set_touch_movement", direction)
	for _frame in frames:
		await physics_frame
	player.call("set_touch_movement", Vector2.ZERO)
	_probe_notice(
		label,
		(
			"start=%s settled=%s end=%s on_floor=%s"
			% [start, settled, player.global_position, player.is_on_floor()]
		)
	)


func _probe_notice(label: String, detail: String) -> void:
	# run_smoke_tests captures each engine log. The CI evidence step lifts these
	# lines into one annotation so restricted contributors can inspect the result.
	print("THE TITANS PROBE %s | %s" % [label, detail])


func _near(a: Color, b: Color, tolerance := 0.002) -> bool:
	return (
		absf(a.r - b.r) <= tolerance
		and absf(a.g - b.g) <= tolerance
		and absf(a.b - b.b) <= tolerance
	)


func _all_distinct(colors: Array[Color]) -> bool:
	return _distinct_count(colors) == colors.size()


func _distinct_count(colors: Array[Color]) -> int:
	var unique: Array[Color] = []
	for color in colors:
		var duplicate := false
		for seen in unique:
			if _near(seen, color):
				duplicate = true
				break
		if not duplicate:
			unique.append(color)
	return unique.size()


func _expect(condition: bool, message: String) -> bool:
	if not condition:
		push_error("MISSION WORLD world smoke test failed: " + message)
	return condition
