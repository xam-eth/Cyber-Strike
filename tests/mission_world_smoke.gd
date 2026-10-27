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
##   for every mission world, through `main.tscn`:
##     7. DEPLOY resolves the shared tower spawn and the player can leave it
##        along MainNorth; surface probes report the other STELLAR districts.
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
	"frostline_relay": {"meshes": 185, "clips": 35, "textures": 55},
	"verdant_bloom": {"meshes": 180, "clips": 37, "textures": 44},
	"emberfall_foundry": {"meshes": 175, "clips": 33, "textures": 60},
	"titans": {"meshes": 180, "clips": 35, "textures": 55},
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
	await _check_mission_deployments()

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
		# MissionWorld copies these measured bounds from WorldDefinition. Keeping
		# the contract in one resource avoids a stale 180 m literal per theatre.
		var expected_field: Vector2 = world.get("field_size")
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

	var triangle_colliders := 0
	for candidate in real_world.find_children("*", "CollisionShape3D", true, false):
		var collision := candidate as CollisionShape3D
		if collision.shape is ConcavePolygonShape3D:
			triangle_colliders += 1
	_passed = (
		_expect(
			triangle_colliders >= int(expected["meshes"]),
			(
				"%s uses its authored route/cover/interior triangles, not role-filling boxes "
				+ "(%d mesh colliders)" % [world_id, triangle_colliders]
			),
		)
		and _passed
	)
	_passed = (
		_expect(
			world.get_node_or_null("FrontierPropCollision") == null,
			"%s does not also build the obsolete flat-arena prop-box collider" % world_id,
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
			# Daytime: warm sun, blue sky and bright sky fill.
			ok = (
				ok
				and key.light_color.r > 0.9
				and env.background_color.b > env.background_color.r
				and env.ambient_light_color.b > 0.7
			)
		"verdant_bloom":
			# Sunset: amber key/horizon with the cyan tower rim preserved.
			ok = (
				ok
				and key.light_color.r > 0.9
				and key.light_color.b < 0.8
				and rim.light_color.b > rim.light_color.r
			)
		"emberfall_foundry":
			# Night: blue moon key rather than the old orange furnace key.
			ok = (
				ok
				and key.light_color.b > key.light_color.r
				and env.background_color.b > env.background_color.r
				and accent.light_color.b > 0.9
			)
		"titans":
			# Storm: cold key plus a brighter cyan lightning fill and dense haze.
			ok = (
				ok
				and key.light_color.b > key.light_color.r
				and fill.light_color.b > fill.light_color.r
				and env.fog_density >= 0.004
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


## The default world through the real gameplay scene and selection resolver.
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

	main_scene.queue_free()
	await process_frame


## Every mission card uses the same main.tscn and selection resolver as shell
## DEPLOY. Check the authored spawn and a real MainNorth walk for all four
## variants; a correct coordinate that drops or traps the player is not a
## working deployment.
func _check_mission_deployments() -> void:
	for world_id in WorldMood.MOOD_ORDER:
		await _check_mission_deployment(world_id)


func _check_mission_deployment(world_id: String) -> void:
	print("--- gameplay scene (%s)" % WorldMood.label(world_id))
	var previous := WorldSelection.override_selection(StringName(world_id))
	var main_scene := MainScene.instantiate()
	main_scene.set("start_wave_session_on_ready", false)
	root.add_child(main_scene)
	# _ready() has run synchronously, so this is the WorldDefinition mapping
	# before gravity or collision recovery can move the body.
	var player := main_scene.get_node("Player") as CharacterBody3D
	var initial_spawn := player.position
	var expected_spawn: Vector3 = WorldDefinition.new().with_id(world_id).player_spawn
	_passed = (
		_expect(
			initial_spawn.is_equal_approx(expected_spawn),
			(
				"%s DEPLOY resolves its authored spawn %s, got %s"
				% [world_id, expected_spawn, initial_spawn]
			),
		)
		and _passed
	)

	var world := main_scene.get_node("MissionWorld") as Node3D
	var real_world := world.get_node_or_null("RealFrontierWorld") as Node3D
	var selected_ok := (
		real_world != null and String(real_world.get_meta("world_id", "")) == world_id
	)
	_passed = (
		_expect(
			selected_ok,
			"the selected %s card builds its GLB through main.tscn" % world_id,
		)
		and _passed
	)
	if not selected_ok:
		main_scene.queue_free()
		await process_frame
		WorldSelection.override_selection(previous)
		return

	for _frame in 24:
		await physics_frame
	var settled := player.position
	_passed = (
		_expect(
			player.is_on_floor() and settled.y > -1.0 and settled.y < 3.0,
			"%s tower spawn settles on real collision, got %s" % [world_id, settled],
		)
		and _passed
	)

	# MainNorth runs from the tower spawn towards +Z. Stop before Cover_E at
	# z=34; this tests deployment and the shared route, not a fictitious boss
	# gate left over from the replaced layouts.
	player.set("velocity", Vector3.ZERO)
	player.call("set_touch_movement", Vector2.DOWN)
	for _frame in 180:
		await physics_frame
		if player.position.z >= 28.0:
			break
	player.call("set_touch_movement", Vector2.ZERO)
	_passed = (
		_expect(
			player.position.z >= 20.0 and player.position.z < 34.0 and player.position.y > -1.0,
			(
				"%s player can leave the tower spawn along MainNorth, got %s"
				% [world_id, player.position]
			),
		)
		and _passed
	)
	_probe_notice(
		world_id,
		(
			"spawn=%s settled=%s MainNorth end=%s on_floor=%s"
			% [initial_spawn, settled, player.position, player.is_on_floor()]
		)
	)
	if world_id == "frostline_relay":
		_probe_stellar_surfaces(player)

	main_scene.queue_free()
	await process_frame
	WorldSelection.override_selection(previous)


## Surface rays make the new bridge/island/interior/canyon collision heights
## visible in CI without pretending that a ray proves those districts are
## connected. The deployment walk above is the actual traversal assertion.
func _probe_stellar_surfaces(player: CharacterBody3D) -> void:
	var space := player.get_world_3d().direct_space_state
	var excluded: Array[RID] = [player.get_rid()]
	for entry in [
		{"label": "tower", "point": Vector2(0.0, 8.0)},
		{"label": "Bridge_E", "point": Vector2(22.0, 0.0)},
		{"label": "Island_NE", "point": Vector2(42.0, 32.0)},
		{"label": "InteriorBase_South", "point": Vector2(0.0, -38.0)},
		{"label": "Canyon_N", "point": Vector2(0.0, 58.0)},
		{"label": "NorthSpawn", "point": Vector2(0.0, 62.0)},
	]:
		var point: Vector2 = entry["point"]
		var query := PhysicsRayQueryParameters3D.create(
			Vector3(point.x, 30.0, point.y), Vector3(point.x, -5.0, point.y), 1, excluded
		)
		var hit := space.intersect_ray(query)
		var hit_position: Vector3 = hit.get("position", Vector3.INF)
		_probe_notice(
			"surface " + String(entry["label"]), "first collision below Y=30 is %s" % hit_position
		)


func _probe_notice(label: String, detail: String) -> void:
	# run_smoke_tests captures each engine log. The CI evidence step lifts these
	# lines into one annotation so restricted contributors can inspect the result.
	print("STELLAR HORIZON PROBE %s | %s" % [label, detail])


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
