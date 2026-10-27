extends SceneTree

## Integration failure containment, measured through the real composition root.
## A missing World environment must leave HUD + Character usable; a missing
## hero/enemy visual must leave the real World, controller, weapon, and HUD
## usable. These are load/validation failures, not a claim that GDScript can
## contain native crashes, infinite loops, or arbitrary executable package code.
const MainScene = preload("res://scenes/main.tscn")
const FrontEndScene = preload("res://scenes/ui/front_end.tscn")
const RunnerScene = preload("res://scenes/enemies/runner.tscn")

var _passed := true


func _initialize() -> void:
	call_deferred("_run_smoke_test")


func _run_smoke_test() -> void:
	_check_loader_results()
	var frostline := WorldDefinition.load_definition(&"frostline_relay")
	var original_world_path := frostline.environment_scene_path
	frostline.environment_scene_path = "res://content/worlds/missing/runtime/world.glb"
	var broken_world: Node = await _make_main("frostline_relay")
	frostline.environment_scene_path = original_world_path
	var world := broken_world.get_node("MissionWorld")
	var hero := broken_world.get_node("Player/VisualRoot")
	_expect(not bool(world.call("has_world_geometry")), "the missing World geometry is rejected")
	_expect(
		not String(world.get("load_error")).is_empty(), "the World failure has a readable reason"
	)
	_expect(
		world.get_node_or_null("ArenaFloor") != null,
		"the World retains its independent safety floor"
	)
	_expect(bool(hero.call("has_model")), "a World failure does not remove the healthy hero")
	_check_shell_and_controller(broken_world, "broken World")
	broken_world.queue_free()
	await process_frame

	var broken_characters: Node = await _make_main(
		"frostline_relay", "res://content/characters/missing/runtime/hero.glb"
	)
	world = broken_characters.get_node("MissionWorld")
	hero = broken_characters.get_node("Player/VisualRoot")
	_expect(
		bool(world.call("has_world_geometry")),
		"a Character failure does not remove the healthy World"
	)
	_expect(not bool(hero.call("has_model")), "the missing hero model is not half-attached")
	_expect(
		bool(hero.get_node("BodyMesh").get("visible")),
		"the hero keeps its visible capsule fallback"
	)
	_expect(
		hero.get_node_or_null("WeaponSocket/WeaponModel") != null,
		"the hero weapon socket still receives the internal weapon"
	)
	_check_shell_and_controller(broken_characters, "broken hero")

	var runner := RunnerScene.instantiate()
	var enemy_visual := runner.get_node("Visuals")
	enemy_visual.set("model_scene", null)
	enemy_visual.set("model_scene_path", "res://content/characters/missing/runtime/enemy.glb")
	runner.set_physics_process(false)
	broken_characters.get_node("WaveEnemies").add_child(runner)
	await process_frame
	_expect(
		not bool(enemy_visual.call("has_model")),
		"the missing enemy model is rejected independently"
	)
	_expect(
		bool(enemy_visual.get_node("BodyMesh").get("visible")),
		"the enemy retains its fallback mesh"
	)
	_expect(
		bool(world.call("has_world_geometry")), "the enemy visual failure leaves World untouched"
	)
	_check_shell_and_controller(broken_characters, "broken enemy")
	broken_characters.queue_free()
	await process_frame

	var broken_weapon: Node = await _make_main(
		"frostline_relay", "", "res://content/characters/missing/runtime/rifle.glb"
	)
	world = broken_weapon.get_node("MissionWorld")
	hero = broken_weapon.get_node("Player/VisualRoot")
	_expect(
		bool(world.call("has_world_geometry")), "a weapon visual failure leaves World untouched"
	)
	_expect(bool(hero.call("has_model")), "a weapon visual failure leaves the hero model attached")
	_expect(
		hero.get_node_or_null("WeaponSocket/WeaponModel") == null,
		"the missing weapon visual is not half-attached"
	)
	_expect(
		hero.get_node_or_null("WeaponSocket/Muzzle") != null,
		"the fallback muzzle remains available"
	)
	_check_shell_and_controller(broken_weapon, "broken weapon visual")
	broken_weapon.queue_free()
	await process_frame

	await _check_shell_character_fallback()

	if _passed:
		print("Module isolation smoke test passed.")
		quit()
	else:
		quit(1)


func _check_shell_character_fallback() -> void:
	var front_end := FrontEndScene.instantiate()
	front_end.get_node("ProgressionService").set("profile_path", "")
	root.add_child(front_end)
	await process_frame
	await process_frame
	var definition := HeroDefinition.load_definition(HeroDefinition.DEFAULT_HERO_ID)
	var original_path := definition.model_scene_path
	var original_scene := definition.model_scene
	definition.model_scene = null
	definition.model_scene_path = "res://content/characters/missing/runtime/hero.glb"
	var progression := front_end.get_node("ProgressionService")
	var saved_hero: StringName = progression.get("selected_hero_id")
	progression.set("selected_hero_id", &"fixture_without_a_tier")
	front_end.go_to(&"HERO", {})
	await process_frame
	await process_frame
	var stage := front_end.get_node_or_null("StageHost/HERO")
	if _expect(stage != null, "HERO remains mounted when its Character package is missing"):
		var name_label := stage.get("_name_label") as Label
		var status_label := stage.get("_status_label") as Label
		_expect(
			name_label != null and name_label.text == "MARA VOSS",
			"hero metadata remains visible"
		)
		_expect(
			status_label != null and status_label.text.contains("VISUAL OFFLINE"),
			"the shell reports the visual fallback explicitly"
		)
		var showcase := stage.find_child("HeroShowcase", true, false)
		_expect(
			showcase != null and not bool(showcase.call("has_model")),
			"the failed showcase has no half-attached model"
		)
	front_end.go_to(&"WORLD", {})
	await process_frame
	_expect(
		front_end.get("current_stage_name") == &"WORLD",
		"WORLD navigation remains available after a Character failure"
	)
	definition.model_scene_path = original_path
	definition.model_scene = original_scene
	progression.set("selected_hero_id", saved_hero)
	front_end.queue_free()
	await process_frame


func _make_main(
	world_override: String,
	hero_path: String = "",
	weapon_path: String = ""
) -> Node:
	var main := MainScene.instantiate()
	main.set("start_wave_session_on_ready", false)
	main.get_node("ProgressionService").set("profile_path", "")
	main.get_node("MissionWorld").set("world_override", world_override)
	var hero := main.get_node("Player/VisualRoot")
	root.add_child(main)
	await process_frame
	await process_frame
	# Progression selects the earned tier during the initial _ready(). Apply a
	# fault after that boot and re-enter the same visual loader; no production
	# test-only switch is needed to exercise failure containment.
	if not hero_path.is_empty():
		hero.set("model_scene", null)
		hero.set("model_scene_path", hero_path)
		hero.call("_spawn_model")
	if not weapon_path.is_empty():
		hero.set("weapon_scene", null)
		hero.set("weapon_scene_path", weapon_path)
		hero.call("_spawn_weapon")
	await process_frame
	return main


func _check_loader_results() -> void:
	var missing := ContentModuleLoader.load_scene(
		"res://content/worlds/missing/runtime/world.glb", ContentModuleLoader.WORLD_ROOTS
	)
	_expect(not bool(missing["ok"]), "a missing package returns failure instead of a scene")
	_expect(missing["code"] == "missing", "the missing-package result has a stable reason")
	var character_path := HeroTier.model_path(HeroDefinition.DEFAULT_HERO_ID, 1)
	var outside := ContentModuleLoader.load_scene(
		character_path, ContentModuleLoader.WORLD_ROOTS
	)
	_expect(not bool(outside["ok"]), "a World loader cannot load a Character path")
	_expect(outside["code"] == "outside_allowed_roots", "the domain boundary is explicit")
	var healthy_character := ContentModuleLoader.load_scene(
		character_path, ContentModuleLoader.CHARACTER_ROOTS
	)
	var healthy_world := ContentModuleLoader.load_scene(
		"res://assets/forge/worlds/frostline.glb", ContentModuleLoader.WORLD_ROOTS
	)
	_expect(
		bool(healthy_character["ok"]), "a prior World failure does not poison Character loading"
	)
	_expect(bool(healthy_world["ok"]), "a prior Character failure does not poison World loading")


func _check_shell_and_controller(main: Node, context: String) -> void:
	_expect(main.get_node_or_null("HUD/TouchControls") != null, context + ": HUD remains mounted")
	_expect(int(main.get("session_mode")) == 0, context + ": session remains in safe Explore")
	var player := main.get_node("Player")
	_expect(
		player.get_node_or_null("WeaponController") != null,
		context + ": controller remains mounted"
	)
	_expect(float(player.get("current_health")) > 0.0, context + ": player remains alive")


func _expect(condition: bool, message: String) -> bool:
	if not condition:
		_passed = false
		push_error("Module isolation smoke test failed: " + message)
	return condition
