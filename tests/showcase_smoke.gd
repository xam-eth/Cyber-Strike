extends SceneTree

## Proves the one claim that makes a 3D selection screen honest: the model on the
## showcase screen is the model gameplay spawns, and the animations it plays are
## animations that exist in the file.
##
## The brief is explicit that a showcase must not become a second, prettier
## character ("jangan membuat model showcase baru yang tampak berbeda dari model
## aktual") and that animation clip names must be inspected rather than assumed.
## Screenshots cannot show either: a different model looks fine, and a missing
## clip simply freezes in a plausible pose.
##
## So this measures, headlessly:
##
##   * `HeroDefinition.model_scene` is the same resource `player.tscn` attaches
##     to `VisualRoot` -- one file, two uses;
##   * every weapon definition's `model_scene` is the resource the player scene
##     holds, and the suite prints how many distinct meshes that turns out to be
##     rather than assuming one per weapon;
##   * every clip a definition names is really in the GLB's AnimationPlayer;
##   * the live HERO stage builds a `ShowcaseViewport` that has a model on it, a
##     camera, and a playing clip -- and HOME builds none, because two lobby
##     pages showing the same model the same way are one page printed twice;
##   * the showcase's skeleton is a *different instance* from gameplay's, and
##     driving it does not change the avatar's clip -- the "showcase must not
##     touch combat state" requirement, measured instead of promised.
const FrontEndScene = preload("res://scenes/ui/front_end.tscn")
const PlayerScene = preload("res://scenes/player/player.tscn")
const ShowcaseScript = preload("res://scripts/ui/widgets/showcase_viewport.gd")

const PROFILE_PATH := "user://showcase_smoke_profile.cfg"

var _failures: Array[String] = []
var _front_end: Control = null


func _initialize() -> void:
	call_deferred("_run_smoke_test")


func _run_smoke_test() -> void:
	_clean_profile()
	await _check_hero_model_is_the_gameplay_model()
	await _check_weapon_models_are_the_gameplay_model()
	_check_declared_clips_exist()
	await _check_the_live_stage_shows_a_model()
	await _check_home_does_not_repeat_the_showcase()
	await _check_the_showcase_cannot_move_the_avatar()
	_teardown()
	if _failures.is_empty():
		print("Showcase smoke test passed.")
		quit(0)
		return
	print("Showcase smoke test FAILED:")
	for failure in _failures:
		print("  fail: " + failure)
	quit(1)


## The avatar's model, as the shipping scene declares it.
func _gameplay_hero_scene() -> PackedScene:
	var player := PlayerScene.instantiate()
	var visual := player.get_node_or_null("VisualRoot")
	var scene: PackedScene = visual.get("model_scene") if visual != null else null
	player.free()
	return scene


func _gameplay_weapon_scene() -> PackedScene:
	var player := PlayerScene.instantiate()
	var visual := player.get_node_or_null("VisualRoot")
	var scene: PackedScene = visual.get("weapon_scene") if visual != null else null
	player.free()
	return scene


func _check_hero_model_is_the_gameplay_model() -> void:
	var gameplay := _gameplay_hero_scene()
	_expect(gameplay != null, "player.tscn declares a hero model on VisualRoot")
	for definition in HeroDefinition.load_all_definitions():
		_expect(
			is_instance_valid(definition.model_scene),
			"%s: the definition declares a model scene" % definition.hero_id
		)
		if not is_instance_valid(definition.model_scene) or gameplay == null:
			continue
		_expect(
			definition.model_scene.resource_path == gameplay.resource_path,
			(
				"%s: the showcased model is the avatar's model (%s)"
				% [definition.hero_id, gameplay.resource_path]
			)
		)
		# A rig is what makes the showcase a character rather than a statue.
		var instance := definition.model_scene.instantiate()
		root.add_child(instance)
		await process_frame
		var skeletons := instance.find_children("*", "Skeleton3D", true, false)
		var players := instance.find_children("*", "AnimationPlayer", true, false)
		_expect(not skeletons.is_empty(), "%s: the model has a skeleton" % definition.hero_id)
		_expect(not players.is_empty(), "%s: the model has an AnimationPlayer" % definition.hero_id)
		instance.free()


## Every weapon points at the mesh it is held as. Today that is one file for
## three weapons, which this test states out loud instead of implying three
## distinct models exist.
func _check_weapon_models_are_the_gameplay_model() -> void:
	var gameplay := _gameplay_weapon_scene()
	_expect(gameplay != null, "player.tscn declares a weapon model on VisualRoot")
	var distinct: Array[String] = []
	for definition in WeaponDefinition.load_all_definitions():
		_expect(
			is_instance_valid(definition.model_scene),
			"%s: the definition declares a model scene" % definition.weapon_id
		)
		if not is_instance_valid(definition.model_scene):
			continue
		if gameplay != null:
			_expect(
				definition.model_scene.resource_path == gameplay.resource_path,
				(
					"%s: the showcase model is the held model (%s)"
					% [definition.weapon_id, gameplay.resource_path]
				)
			)
		if not distinct.has(definition.model_scene.resource_path):
			distinct.append(definition.model_scene.resource_path)
	print(
		(
			"Showcase: %d weapon definition(s) share %d mesh file(s) (%s)"
			% [WeaponDefinition.DEFINITION_IDS.size(), distinct.size(), ", ".join(distinct)]
		)
	)


## Clip names come from the definition; this is the measurement that keeps them
## from being a guess. A name that is not in the GLB would simply never play.
func _check_declared_clips_exist() -> void:
	for definition in HeroDefinition.load_all_definitions():
		if not is_instance_valid(definition.model_scene):
			continue
		var instance := definition.model_scene.instantiate()
		root.add_child(instance)
		var players := instance.find_children("*", "AnimationPlayer", true, false)
		if players.is_empty():
			_fail("%s: no AnimationPlayer to check clips against" % definition.hero_id)
			instance.free()
			continue
		var player := players[0] as AnimationPlayer
		var available := player.get_animation_list()
		for clip in definition.showcase_clips:
			_expect(
				player.has_animation(clip),
				(
					"%s: declared showcase clip '%s' exists in the GLB (has: %s)"
					% [definition.hero_id, clip, ", ".join(available)]
				)
			)
		instance.free()


func _check_the_live_stage_shows_a_model() -> void:
	_front_end = FrontEndScene.instantiate()
	_front_end.get_node("ProgressionService").set("profile_path", PROFILE_PATH)
	root.add_child(_front_end)
	await process_frame
	await process_frame
	_front_end.go_to(&"HERO", {})
	await process_frame
	await process_frame
	var stage: Control = _front_end.get_node_or_null("StageHost/HERO")
	if not _expect(stage != null, "the HERO stage is instantiated"):
		return
	var showcase := stage.find_child("HeroShowcase", true, false) as SubViewportContainer
	if not _expect(showcase != null, "the HERO stage mounts a 3D showcase"):
		return
	_expect(showcase is ShowcaseScript, "the showcase is a ShowcaseViewport")
	_expect(showcase.has_model(), "the showcase has a model on it")
	var definition := HeroDefinition.load_definition(ProgressionService.DEFAULT_HERO_ID)
	_expect(
		showcase.model_path() == definition.model_scene.resource_path,
		"the live showcase is showing the definition's model (%s)" % showcase.model_path()
	)
	_expect(
		not showcase.current_clip().is_empty(),
		"a showcase clip is playing (%s)" % showcase.current_clip()
	)
	var camera := showcase.find_children("*", "Camera3D", true, false)
	_expect(not camera.is_empty(), "the showcase owns a camera")
	var lights := showcase.find_children("*", "Light3D", true, false)
	_expect(lights.size() >= 2, "the showcase lights the model (%d lights)" % lights.size())
	# The viewport is the thing that actually renders; a zero-size one is a
	# showcase that exists in the tree and draws nothing.
	var viewports := showcase.find_children("*", "SubViewport", true, false)
	if _expect(not viewports.is_empty(), "the showcase owns a SubViewport"):
		var viewport := viewports[0] as SubViewport
		_expect(
			viewport.size.x > 0 and viewport.size.y > 0,
			"the showcase viewport has been sized (%dx%d)" % [viewport.size.x, viewport.size.y]
		)
		_expect(viewport.get_camera_3d() != null, "the viewport renders through its own camera")


## The defect this file exists to keep out: HOME and OPERATIVE were one screen
## printed twice, both a full-height model between a card column and a dock
## (docs/DECISIONS.md 29). HOME is a manifest now, so it must present **no** 3D
## at all, and it must still be the page that carries the three numbered rows.
## Both halves are asserted: dropping the model without gaining the rows would
## pass a one-sided check and ship an empty page.
func _check_home_does_not_repeat_the_showcase() -> void:
	if _front_end == null:
		return
	_front_end.go_to(&"DASHBOARD", {})
	await process_frame
	await process_frame
	var home: Control = _front_end.get_node_or_null("StageHost/DASHBOARD")
	if not _expect(home != null, "the HOME stage is instantiated"):
		return
	# A `SubViewportContainer` is how every 3D panel in this project is drawn, so
	# finding one here would mean HOME had grown a viewport again.
	var viewports := home.find_children("*", "SubViewportContainer", true, false)
	var names := PackedStringArray()
	for node in viewports:
		names.append(str(node.name))
	_expect(
		viewports.is_empty(),
		(
			"HOME presents no 3D viewport (found %s); the model belongs to OPERATIVE"
			% ", ".join(names)
		),
	)
	for row_name in ["_hero_row", "_mission_row", "_arsenal_row"]:
		_expect(
			home.get(row_name) != null,
			"HOME carries the %s row of its manifest" % row_name,
		)
	# And the other page must still be the showcase: if both lost their 3D the
	# assertion above would be satisfied by two identical empty screens.
	var hero: Control = _front_end.get_node_or_null("StageHost/HERO")
	_expect(
		(
			hero != null
			and not hero.find_children("*", "SubViewportContainer", true, false).is_empty()
		),
		"OPERATIVE is still the page with the 3D showcase",
	)


func _check_the_showcase_cannot_move_the_avatar() -> void:
	if _front_end == null:
		return
	var stage: Control = _front_end.get_node_or_null("StageHost/HERO")
	var showcase := stage.find_child("HeroShowcase", true, false) if stage != null else null
	if showcase == null:
		return
	var player := PlayerScene.instantiate()
	root.add_child(player)
	await process_frame
	await process_frame
	var visual := player.get_node_or_null("VisualRoot")
	if not _expect(visual != null, "the player scene has a VisualRoot"):
		player.free()
		return
	# The player scene is not in a run, so CharacterVisual may sit on its idle
	# clip; whatever it is, it must not change while the showcase animates.
	var before := String(visual.call("current_clip"))
	var showcase_anim := showcase.find_children("*", "AnimationPlayer", true, false)
	var player_anim := player.find_children("*", "AnimationPlayer", true, false)
	_expect(not player_anim.is_empty(), "the avatar has an AnimationPlayer of its own")
	if not showcase_anim.is_empty() and not player_anim.is_empty():
		_expect(
			showcase_anim[0] != player_anim[0],
			"the showcase animates a different AnimationPlayer than the avatar's"
		)
	showcase.play_clip("fire")
	await process_frame
	await process_frame
	_expect(
		String(visual.call("current_clip")) == before,
		(
			"driving the showcase leaves the avatar's clip unchanged (%s -> %s)"
			% [before, String(visual.call("current_clip"))]
		)
	)
	player.free()


func _clean_profile() -> void:
	if FileAccess.file_exists(PROFILE_PATH):
		DirAccess.remove_absolute(PROFILE_PATH)


func _teardown() -> void:
	if is_instance_valid(_front_end):
		_front_end.free()
		_front_end = null
	_clean_profile()


func _expect(condition: bool, message: String) -> bool:
	if condition:
		print("  ok: " + message)
		return true
	_fail(message)
	return false


func _fail(message: String) -> void:
	print("  fail: " + message)
	_failures.append(message)
