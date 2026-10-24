extends SceneTree

## One source of truth, enforced rather than asserted in a comment.
##
## Every screen in the front end claims to print real numbers. This test is the
## claim, checked: it reads the value off the screen and compares it with the
## value the game runs on, without a single number hardcoded here. If a
## definition changes, the test follows it -- and if a screen stops reading the
## definition, the test fails.
##
## It exists because the weapon data used to live in two places: the front end's
## WEAPON screen kept its own map of `.tres` paths, and `player.tscn` authors
## the weapon controller's array from the same files. Agreeing today is not the
## same as agreeing tomorrow: a card quoting one file while the controller
## loaded another would print 18 damage for a gun that fires 20, which is
## exactly the decorative-stat rule, reached by accident. The paths now live in
## `WeaponDefinition`, this test proves both sides resolve to the same resource,
## and it checks:
##
##   * the card's printed DMG / RATE / MAG / RELOAD / RNG parse back to the
##     fields of the definition the player fires, for every weapon;
##   * the card's title and price come from that same definition and from
##     `ProgressionService.COSTS`, so the price shown is the price charged;
##   * the dashboard's wallet, best score, run count and loadout are the
##     service's own numbers, read after they are set to known values;
##   * unlocking refuses when the balance is short and costs exactly `COSTS`
##     when it is not -- no currency invented in the UI;
##   * no id appears anywhere that the progression service does not know.

const FrontEndScene = preload("res://scenes/ui/front_end.tscn")
const PlayerScene = preload("res://scenes/player/player.tscn")
const CinematicStage = preload("res://scripts/ui/menus/stage_cinematic.gd")

## Distinct from the real `user://progression.cfg` so the suite never spends or
## unlocks anything in a profile a developer might care about.
const PROFILE_PATH := "user://data_source_smoke_profile.cfg"

## Printed floats are trimmed (`18.0` -> "18", `1.35` -> "1.35"), so a parsed
## value is allowed a rounding step of its last printed digit.
const TOLERANCE := 0.005

## Values the dashboard is asked to display. Chosen to be unmistakable in a log
## and impossible to reach by accident (a run score of 4321, seven runs).
const TEST_BALANCE := 1234
const TEST_BEST_SCORE := 4321
const TEST_RUNS := 7

var _failures: Array[String] = []
var _checks := 0
var _front_end: Control
var _profile: Node


func _initialize() -> void:
	call_deferred("_run_smoke_test")


func _run_smoke_test() -> void:
	if FileAccess.file_exists(PROFILE_PATH):
		DirAccess.remove_absolute(PROFILE_PATH)
	# Every one of these is awaited. They contain `await process_frame`, which
	# makes them coroutines: calling one without awaiting it runs only up to its
	# first await and lets this function fall straight through to _finish(), so
	# the suite would quit half-measured and report a pass.
	await _check_registry_matches_gameplay()
	await _check_cards_match_the_definitions()
	await _check_selection_ids_are_known()
	await _check_dashboard_matches_the_service()
	await _check_dashboard_names_come_from_the_definition()
	await _check_referenced_art_exists()
	await _check_hero_roster_is_one_list()
	await _check_world_roster_is_one_list()
	_check_no_roster_literals_in_screens()
	await _check_unlock_economics()
	_finish()


# --- the two lists ----------------------------------------------------------


## The weapon the player fires is the one the screen describes. `player.tscn`
## authors the controller array; the front end reads `WeaponDefinition`. Both
## must resolve to the same file, and every field in it must be identical.
func _check_registry_matches_gameplay() -> void:
	var player := PlayerScene.instantiate()
	var controller := player.get_node_or_null("WeaponController")
	if not _expect(controller != null, "player.tscn carries a WeaponController"):
		player.free()
		return
	var fired_by_id := {}
	for entry in controller.get("weapon_definitions"):
		var definition := entry as WeaponDefinition
		if definition == null:
			continue
		fired_by_id[String(definition.weapon_id)] = definition

	_expect(
		fired_by_id.size() == WeaponDefinition.DEFINITION_IDS.size(),
		(
			"the controller array and the registry hold the same number of weapons"
			+ " (%d vs %d)" % [fired_by_id.size(), WeaponDefinition.DEFINITION_IDS.size()]
		)
	)
	for weapon_id in WeaponDefinition.DEFINITION_IDS:
		var canonical := WeaponDefinition.load_definition(weapon_id)
		if not _expect(canonical != null, "the registry resolves %s" % weapon_id):
			continue
		var fired: WeaponDefinition = fired_by_id.get(String(weapon_id))
		if not _expect(
			fired != null, "the player can fire %s (it is in the controller array)" % weapon_id
		):
			continue
		_expect(
			fired.resource_path == canonical.resource_path,
			(
				"%s: the card's file and the controller's file are the same (%s vs %s)"
				% [weapon_id, canonical.resource_path, fired.resource_path]
			)
		)
		_expect(
			_definitions_match(canonical, fired),
			(
				"%s: every field matches between the card's definition and the one that fires"
				% weapon_id
			)
		)
	player.free()


## The numbers on the WEAPON cards, parsed back out of the rendered text. This
## is the whole "no decorative stats" rule in one loop, and it is why the
## expected values are read from the resource instead of written here.
func _check_cards_match_the_definitions() -> void:
	_front_end = FrontEndScene.instantiate()
	_front_end.get_node("ProgressionService").set("profile_path", PROFILE_PATH)
	root.add_child(_front_end)
	await process_frame
	await process_frame
	_profile = _front_end.get_node("ProgressionService")
	_front_end.go_to(&"WEAPON", {})
	await process_frame
	await process_frame

	var stage: Control = _front_end.get_node_or_null("StageHost/WEAPON")
	if not _expect(stage != null, "the WEAPON stage is instantiated"):
		return
	var cards := 0
	for child in stage.find_children("*", "Button", true, false):
		var button := child as Button
		if button == null or not button.has_meta("weapon_id"):
			continue
		cards += 1
		var weapon_id := StringName(str(button.get_meta("weapon_id")))
		var definition := WeaponDefinition.load_definition(weapon_id)
		if not _expect(
			definition != null, "%s: the card reads a definition from the registry" % weapon_id
		):
			continue
		_expect(
			text_of(button).contains(definition.display_name.to_upper()),
			(
				"%s: the card names the weapon the definition names (%s)"
				% [weapon_id, definition.display_name]
			)
		)
		var stat_line := _meta_label(button, "stat_line")
		if not _expect(stat_line != null, "%s: the card prints a stat line" % weapon_id):
			continue
		_check_stat("DMG", stat_line.text, definition.damage, weapon_id)
		_check_stat("RATE", stat_line.text, definition.fire_rate, weapon_id)
		_check_stat("MAG", stat_line.text, float(definition.magazine_size), weapon_id)
		_check_stat("RELOAD", stat_line.text, definition.reload_seconds, weapon_id)
		_check_stat("RNG", stat_line.text, definition.max_range, weapon_id)
		if definition.splash_damage > 0.0:
			_check_stat("SPLASH", stat_line.text, definition.splash_damage, weapon_id)
		if definition.chain_count > 0:
			_check_stat("CHAIN", stat_line.text, float(definition.chain_count), weapon_id)
	_expect(
		cards == WeaponDefinition.DEFINITION_IDS.size(),
		(
			"every weapon in the registry gets a card (%d of %d)"
			% [cards, WeaponDefinition.DEFINITION_IDS.size()]
		)
	)
	_expect(
		cards == ProgressionService.WEAPON_IDS.size(),
		"the cards and ProgressionService.WEAPON_IDS cover the same weapons"
	)


## Reads the number back out of the rendered line: "DMG 18" against 18.0.
func _check_stat(key: String, line: String, expected: float, weapon_id: StringName) -> void:
	var regex := RegEx.new()
	# The trailing unit is optional: RATE prints "/s", RELOAD prints "s", DMG
	# prints nothing, and SPLASH prints two numbers.
	regex.compile("%s\\s+([0-9]*\\.?[0-9]+)" % key)
	var match := regex.search(line)
	if not _expect(match != null, "%s: the stat line carries a %s value" % [weapon_id, key]):
		return
	var parsed := float(match.get_string(1))
	_expect(
		absf(parsed - expected) <= TOLERANCE,
		(
			"%s: printed %s %s equals the definition's %.2f"
			% [weapon_id, key, match.get_string(1), expected]
		)
	)


## A card can only offer an id the progression service recognises. This is what
## stops a screen from inventing content: an id that is not in `HERO_IDS` /
## `WORLD_IDS` cannot be selected, saved or launched, so printing it would be a
## promise the game cannot keep.
func _check_selection_ids_are_known() -> void:
	for entry in [
		{"stage": &"HERO", "meta": "hero_id", "known": ProgressionService.HERO_IDS},
		{"stage": &"WORLD", "meta": "world_id", "known": ProgressionService.WORLD_IDS},
	]:
		var name: StringName = entry["stage"]
		_front_end.go_to(name, {})
		await process_frame
		await process_frame
		var stage: Control = _front_end.get_node_or_null("StageHost/" + str(name))
		if not _expect(stage != null, "the %s stage is instantiated" % name):
			continue
		var known: Array[StringName] = entry["known"]
		var offered := 0
		for child in stage.find_children("*", "Button", true, false):
			var button := child as Button
			if button == null or not button.has_meta(entry["meta"]):
				continue
			offered += 1
			var id := StringName(str(button.get_meta(entry["meta"])))
			_expect(known.has(id), "%s: '%s' is an id the progression service knows" % [name, id])
		_expect(offered > 0, "%s offers at least one card" % name)

	# The one operative the project can render is the one the service starts on.
	_front_end.go_to(&"HERO", {})
	await process_frame
	var hero_stage: Control = _front_end.get_node_or_null("StageHost/HERO")
	if hero_stage != null:
		var selectable := 0
		for child in hero_stage.find_children("*", "Button", true, false):
			var button := child as Button
			if button == null or button.disabled or not button.has_meta("hero_id"):
				continue
			selectable += 1
			_expect(
				StringName(str(button.get_meta("hero_id"))) == ProgressionService.DEFAULT_HERO_ID,
				"the only selectable hero is the one with a rig behind it"
			)
		_expect(selectable == 1, "exactly one hero is selectable (%d)" % selectable)


## The dashboard calls the weapon what the weapon calls itself.
func _check_dashboard_names_come_from_the_definition() -> void:
	var stage: Control = _front_end.get_node_or_null("StageHost/DASHBOARD")
	if not _expect(stage != null, "the DASHBOARD stage is instantiated"):
		return
	for weapon_id in ProgressionService.WEAPON_IDS:
		var definition := WeaponDefinition.load_definition(weapon_id)
		if definition == null:
			continue
		var shown := String(stage.call("_weapon_name", weapon_id))
		_expect(
			shown == definition.display_name.to_upper(),
			"the dashboard calls %s '%s', the name in its own definition" % [weapon_id, shown]
		)


# --- the dashboard ----------------------------------------------------------


## Set the numbers, re-enter the screen, and read them back off the labels. A
## dashboard that showed a cached value, or a number of its own, would miss.
func _check_dashboard_matches_the_service() -> void:
	if _profile == null:
		return
	_profile.set("balance", TEST_BALANCE)
	_profile.set("best_score", TEST_BEST_SCORE)
	_profile.set("completed_runs", TEST_RUNS)
	_front_end.go_to(&"DASHBOARD", {})
	await process_frame
	await process_frame
	var stage: Control = _front_end.get_node_or_null("StageHost/DASHBOARD")
	if not _expect(stage != null, "the DASHBOARD stage is instantiated"):
		return
	var text := text_of(stage)
	_expect(
		text.contains("BATTLE POINTS  %d" % TEST_BALANCE),
		"the dashboard wallet shows the service's balance (%d)" % TEST_BALANCE
	)
	_expect(
		text.contains("BEST SCORE  %d" % TEST_BEST_SCORE),
		"the dashboard best score shows the service's (%d)" % TEST_BEST_SCORE
	)
	_expect(
		text.contains("RUNS COMPLETED  %d" % TEST_RUNS),
		"the dashboard run count shows the service's (%d)" % TEST_RUNS
	)
	var selected := _profile.get("selected_weapon_id") as StringName
	var definition := WeaponDefinition.load_definition(selected)
	if definition != null:
		_expect(
			text.contains(definition.display_name.to_upper()),
			"the dashboard loadout names the weapon the service selected (%s)" % selected
		)


## Every art file a screen names is a file that exists.
##
## The stages resolve art through `MenuStage.try_texture()`, which returns null
## for a missing file -- deliberate, because a lost plate should be a visual
## regression rather than a boot failure. The other half of that trade is a
## test, and it has to read the *declared* paths rather than the drawn
## textures: a path with a typo in it resolves to null, draws nothing, and is
## invisible to a check that only looks at what made it onto the screen. So
## this walks each stage's constants (including the dictionaries inside them,
## where the weapon plates live) and asks the engine whether each file is real.
func _check_referenced_art_exists() -> void:
	for name in [
		&"BOOT",
		&"LOADING",
		&"CINEMATIC",
		&"CHAPTER",
		&"DASHBOARD",
		&"HERO",
		&"WEAPON",
		&"WORLD",
	]:
		_front_end.go_to(name, {})
		await process_frame
		await process_frame
		var stage: Control = _front_end.get_node_or_null("StageHost/" + str(name))
		if not _expect(stage != null, "the %s stage is instantiated" % name):
			continue
		var paths := _art_paths_in(stage)
		if name != &"BOOT":
			_expect(paths.size() > 0, "%s names at least one art file (%d)" % [name, paths.size()])
		for path in paths:
			_expect(
				ResourceLoader.exists(path), "%s: the art file it names exists (%s)" % [name, path]
			)
		# The drawn half is separate: a texture built in code -- the robot's
		# AtlasTexture -- has no file to check, but a stage that names art and
		# draws none has a hole in it.
		if name != &"BOOT":
			var drawn := 0
			for child in stage.find_children("*", "TextureRect", true, false):
				var rect := child as TextureRect
				if rect != null and rect.texture != null:
					drawn += 1
			_expect(drawn > 0, "%s draws at least one texture (%d)" % [name, drawn])


## Every `res://` image path the stage's script mentions, at any depth.
##
## Two passes, because the art is declared two ways: in constants (the weapon
## plates sit in a dictionary) and as inline literals in function bodies, where
## most backdrops are built with a path written straight into `make_backdrop`.
## The second pass reads the script's own source, so a path is checked whether
## or not a constant holds it.
func _art_paths_in(stage: Node) -> Array[String]:
	var found: Array[String] = []
	var script := stage.get_script() as Script
	if script == null:
		return found
	for value in script.get_script_constant_map().values():
		_collect_art_paths(value, found)
	var source := FileAccess.get_file_as_string(script.resource_path)
	var regex := RegEx.new()
	regex.compile("res://[^\\s\"'()]+?\\.(?:png|jpg|jpeg|webp|svg)")
	for found_match in regex.search_all(source):
		var path := found_match.get_string(0)
		if not found.has(path):
			found.append(path)
	# The hero portrait and the world plate are no longer literals in the stage
	# script -- they arrive with the definition the card was built from -- so the
	# script scan above cannot see them. Read them off the resources the cards
	# actually hold, which is the same thing the scan was always trying to do.
	for child in stage.find_children("*", "Button", true, false):
		if child.has_meta("hero_id"):
			var hero := HeroDefinition.load_definition(StringName(str(child.get_meta("hero_id"))))
			if hero != null:
				_collect_art_paths(hero.portrait_path, found)
		elif child.has_meta("world_id"):
			var world := WorldDefinition.load_definition(
				StringName(str(child.get_meta("world_id")))
			)
			if world != null:
				_collect_art_paths(world.plate_path, found)
	return found


func _collect_art_paths(value: Variant, found: Array[String]) -> void:
	if value is String:
		var path := str(value)
		var extension := path.get_extension().to_lower()
		if path.begins_with("res://") and extension in ["png", "jpg", "jpeg", "webp", "svg"]:
			if not found.has(path):
				found.append(path)
	elif value is Dictionary:
		for inner in (value as Dictionary).values():
			_collect_art_paths(inner, found)
	elif value is Array:
		for inner in value as Array:
			_collect_art_paths(inner, found)


# --- the economy ------------------------------------------------------------


## Every cost the UI can quote is a cost the service will charge, and nothing
## can be bought with balance it does not have.
func _check_unlock_economics() -> void:
	if _profile == null:
		return
	for weapon_id in ProgressionService.WEAPON_IDS:
		var cost := int(ProgressionService.COSTS.get(String(weapon_id), -1))
		_expect(
			ProgressionService.COSTS.has(String(weapon_id)),
			"%s has a price in ProgressionService.COSTS" % weapon_id
		)
		_expect(cost >= 0, "%s is priced (not -1, which would be an unknown weapon)" % weapon_id)
		if cost <= 0:
			continue
		_reset_unlocks()

		# One Battle Point short: refused, and nothing is spent.
		_profile.set("balance", cost - 1)
		_expect(
			not bool(_profile.unlock_weapon(weapon_id)),
			"%s: unlocking refuses when the balance is short by 1 BP" % weapon_id
		)
		_expect(
			int(_profile.get("balance")) == cost - 1,
			"%s: a refused unlock leaves the balance untouched" % weapon_id
		)
		_expect(
			not bool(_profile.is_unlocked(weapon_id)),
			"%s: a refused unlock does not grant the weapon" % weapon_id
		)

		# Exactly the price: granted, and the price is what was quoted.
		_profile.set("balance", cost)
		_expect(
			bool(_profile.unlock_weapon(weapon_id)),
			"%s: unlocking succeeds at the quoted price (%d BP)" % [weapon_id, cost]
		)
		_expect(
			int(_profile.get("balance")) == 0,
			"%s: unlocking spends exactly the quoted price, leaving 0 BP" % weapon_id
		)
		_expect(
			bool(_profile.is_unlocked(weapon_id)), "%s: unlocking grants the weapon" % weapon_id
		)

	# The price on the card is the price charged. Locked again, the state line
	# has to quote the same number the service will take.
	_reset_unlocks()
	_profile.set("balance", 0)
	_front_end.go_to(&"WEAPON", {})
	await process_frame
	await process_frame
	var stage: Control = _front_end.get_node_or_null("StageHost/WEAPON")
	if stage == null:
		return
	for child in stage.find_children("*", "Button", true, false):
		var button := child as Button
		if button == null or not button.has_meta("weapon_id"):
			continue
		var weapon_id := StringName(str(button.get_meta("weapon_id")))
		if bool(_profile.is_unlocked(weapon_id)):
			continue
		var cost := int(_profile.unlock_cost(weapon_id))
		var state := _meta_label(button, "state_line")
		if state == null:
			continue
		_expect(
			state.text.contains("%d BP" % cost),
			"%s: the locked card quotes the price the service charges (%d BP)" % [weapon_id, cost]
		)


# --- the hero and world rosters ----------------------------------------------


## The hero's name used to live in three places: the HERO card, the dashboard's
## loadout line and `ProgressionService.HERO_IDS`. Every one of them is now read
## out of `HeroDefinition`, so what is checked here is that they still are --
## the card prints the definition's name, the dashboard's `_hero_name()` returns
## the same string, and the service's id list and the registry are the same list.
func _check_hero_roster_is_one_list() -> void:
	for hero_id in HeroDefinition.DEFINITION_PATHS:
		var definition := HeroDefinition.load_definition(hero_id)
		if not _expect(definition != null, "%s: the registry entry loads" % hero_id):
			continue
		_expect(
			definition.hero_id == hero_id,
			"%s: the file's own id matches the key it is registered under" % hero_id
		)
		_expect(
			definition.is_valid_definition(),
			"%s: the definition is complete (name, blurb, status, portrait on disk)" % hero_id
		)
	_expect(
		ProgressionService.HERO_IDS == HeroDefinition.DEFINITION_IDS,
		(
			(
				"ProgressionService.HERO_IDS and HeroDefinition.DEFINITION_IDS are the same list"
				+ " (%d vs %d)"
			)
			% [ProgressionService.HERO_IDS.size(), HeroDefinition.DEFINITION_IDS.size()]
		)
	)
	_expect(
		HeroDefinition.DEFINITION_IDS.has(ProgressionService.DEFAULT_HERO_ID),
		"the default hero is a real registry entry, not an id that was deleted"
	)

	if _front_end == null:
		return
	_front_end.go_to(&"HERO", {})
	await process_frame
	await process_frame
	var stage: Control = _front_end.get_node_or_null("StageHost/HERO")
	if not _expect(stage != null, "the HERO stage is instantiated"):
		return
	var cards := 0
	for child in stage.find_children("*", "Button", true, false):
		var button := child as Button
		if button == null or not button.has_meta("hero_id"):
			continue
		cards += 1
		var hero_id := StringName(str(button.get_meta("hero_id")))
		var definition := HeroDefinition.load_definition(hero_id)
		if not _expect(definition != null, "%s: the card reads a hero from the registry" % hero_id):
			continue
		_expect(
			text_of(button).contains(definition.display_name.to_upper()),
			(
				"%s: the card names the hero the definition names (%s)"
				% [hero_id, definition.display_name]
			)
		)
		_expect(
			text_of(button).to_upper().contains(
				definition.role_description.substr(0, 24).to_upper()
			),
			"%s: the card's blurb is the definition's, not the screen's own" % hero_id
		)
	_expect(
		cards == HeroDefinition.DEFINITION_IDS.size(),
		(
			"every hero in the registry gets a card (%d of %d)"
			% [cards, HeroDefinition.DEFINITION_IDS.size()]
		)
	)

	var dashboard: Control = _front_end.get_node_or_null("StageHost/DASHBOARD")
	if dashboard != null:
		for hero_id in HeroDefinition.DEFINITION_IDS:
			var shown := String(dashboard.call("_hero_name", hero_id))
			var definition := HeroDefinition.load_definition(hero_id)
			_expect(
				shown == definition.display_name.to_upper(),
				"the dashboard calls %s '%s', the name in its own definition" % [hero_id, shown]
			)


## Same argument for worlds, plus the one that actually bites: the WORLD card
## advertises a theatre and LAUNCH loads `main.tscn`, and nothing tied the two
## together. The definition declares which scene the theatre *is*, and this
## check instantiates the gameplay scene and looks for a node whose
## `scene_file_path` is that file. A card naming a world the launcher does not
## contain fails here instead of loading an empty arena on a player's phone.
func _check_world_roster_is_one_list() -> void:
	for world_id in WorldDefinition.DEFINITION_PATHS:
		var definition := WorldDefinition.load_definition(world_id)
		if not _expect(definition != null, "%s: the registry entry loads" % world_id):
			continue
		_expect(
			definition.world_id == world_id,
			"%s: the file's own id matches the key it is registered under" % world_id
		)
		_expect(
			definition.is_valid_definition(),
			"%s: the definition is complete (name, blurb, status, scene, plate on disk)" % world_id
		)
		if definition.world_scene == null:
			continue
		var gameplay := (load(FrontEnd.GAMEPLAY_SCENE) as PackedScene).instantiate()
		if not _expect(gameplay != null, "the gameplay scene FrontEnd launches instantiates"):
			continue
		var paths: Array[String] = []
		_collect_scene_paths(gameplay, paths)
		_expect(
			paths.has(definition.world_scene.resource_path),
			(
				"%s: the scene the card advertises is inside %s (%d scenes found)"
				% [world_id, FrontEnd.GAMEPLAY_SCENE, paths.size()]
			)
		)
		# Never added to the tree, so the run never starts; freed so the suite
		# does not leave a whole arena in ObjectDB behind it.
		gameplay.free()

	_expect(
		ProgressionService.WORLD_IDS == WorldDefinition.DEFINITION_IDS,
		(
			(
				"ProgressionService.WORLD_IDS and WorldDefinition.DEFINITION_IDS are the same list"
				+ " (%d vs %d)"
			)
			% [ProgressionService.WORLD_IDS.size(), WorldDefinition.DEFINITION_IDS.size()]
		)
	)
	_expect(
		WorldDefinition.DEFINITION_IDS.has(ProgressionService.DEFAULT_WORLD_ID),
		"the default world is a real registry entry, not an id that was deleted"
	)

	if _front_end == null:
		return
	_front_end.go_to(&"WORLD", {})
	await process_frame
	await process_frame
	var stage: Control = _front_end.get_node_or_null("StageHost/WORLD")
	if not _expect(stage != null, "the WORLD stage is instantiated"):
		return
	var cards := 0
	for child in stage.find_children("*", "Button", true, false):
		var button := child as Button
		if button == null or not button.has_meta("world_id"):
			continue
		cards += 1
		var world_id := StringName(str(button.get_meta("world_id")))
		var definition := WorldDefinition.load_definition(world_id)
		if not _expect(
			definition != null, "%s: the card reads a world from the registry" % world_id
		):
			continue
		_expect(
			text_of(button).contains(definition.display_name.to_upper()),
			(
				"%s: the card names the world the definition names (%s)"
				% [world_id, definition.display_name]
			)
		)
	_expect(
		cards == WorldDefinition.DEFINITION_IDS.size(),
		(
			"every world in the registry gets a card (%d of %d)"
			% [cards, WorldDefinition.DEFINITION_IDS.size()]
		)
	)

	var dashboard: Control = _front_end.get_node_or_null("StageHost/DASHBOARD")
	if dashboard != null:
		for world_id in WorldDefinition.DEFINITION_IDS:
			var shown := String(dashboard.call("_world_name", world_id))
			var definition := WorldDefinition.load_definition(world_id)
			_expect(
				shown == definition.display_name.to_upper(),
				"the dashboard calls %s '%s', the name in its own definition" % [world_id, shown]
			)

	# The cinematic names the theatre in its second caption. This is a wiring
	# check, not a drift check: renaming the definition moves both sides
	# together, so what it proves is that the line is still *derived*. Drift is
	# what `_check_no_roster_literals_in_screens` catches -- a name typed into
	# the cinematic instead of read from the registry fails there.
	var caption := String(CinematicStage._beat_caption(1))
	for world_id in WorldDefinition.DEFINITION_IDS:
		var definition := WorldDefinition.load_definition(world_id)
		if definition == null:
			continue
		_expect(
			caption.contains(definition.display_name.to_upper()),
			"the opening names the theatre it drops into ('%s')" % caption
		)


## The other half of the same rule, and the half that can actually fail.
## "The card prints the definition's name" is close to a tautology when both
## read the same file -- rename the file and they agree again. What has to be
## impossible is the screen spelling the name *itself*: that is the copy that
## drifts, because a rename touches the card and the registry but not the
## literal. So this reads each screen's own source and fails if it contains any
## roster name or portrait/plate path as a string literal.
func _check_no_roster_literals_in_screens() -> void:
	var screens := {
		"HERO": "res://scripts/ui/menus/stage_hero_select.gd",
		"WORLD": "res://scripts/ui/menus/stage_world_select.gd",
		"DASHBOARD": "res://scripts/ui/menus/stage_dashboard.gd",
		"CINEMATIC": "res://scripts/ui/menus/stage_cinematic.gd",
	}
	var owned: Array[String] = []
	for definition in HeroDefinition.load_all_definitions():
		owned.append(definition.display_name)
		owned.append(definition.portrait_path)
	for definition in WorldDefinition.load_all_definitions():
		owned.append(definition.display_name)
		owned.append(definition.plate_path)
	for screen_name in screens:
		var path: String = screens[screen_name]
		var source := FileAccess.get_file_as_string(path)
		if not _expect(not source.is_empty(), "%s: the screen's source can be read" % screen_name):
			continue
		var upper := source.to_upper()
		for literal in owned:
			if literal.is_empty():
				continue
			_expect(
				not upper.contains(literal.to_upper()),
				(
					"%s: '%s' is not spelled out in the screen -- it belongs to the registry"
					% [screen_name, literal]
				)
			)


## Back to "owns the starter weapon and nothing else".
func _reset_unlocks() -> void:
	_profile.set("unlocked_ids", {String(ProgressionService.DEFAULT_WEAPON_ID): true})


# --- helpers ----------------------------------------------------------------


func _definitions_match(a: WeaponDefinition, b: WeaponDefinition) -> bool:
	return (
		a.weapon_id == b.weapon_id
		and a.display_name == b.display_name
		and a.role_description == b.role_description
		and _same_path(a.projectile_scene, b.projectile_scene)
		and is_equal_approx(a.fire_rate, b.fire_rate)
		and a.magazine_size == b.magazine_size
		and is_equal_approx(a.reload_seconds, b.reload_seconds)
		and is_equal_approx(a.damage, b.damage)
		and is_equal_approx(a.projectile_speed, b.projectile_speed)
		and is_equal_approx(a.max_range, b.max_range)
		and a.collision_mask == b.collision_mask
		and is_equal_approx(a.splash_damage, b.splash_damage)
		and is_equal_approx(a.splash_radius, b.splash_radius)
		and a.chain_count == b.chain_count
		and is_equal_approx(a.chain_radius, b.chain_radius)
		and is_equal_approx(a.chain_damage_multiplier, b.chain_damage_multiplier)
	)


## Every PackedScene-node in a subtree, by the file it was instantiated from.
func _collect_scene_paths(node: Node, found: Array[String]) -> void:
	if node.scene_file_path != "" and not found.has(node.scene_file_path):
		found.append(node.scene_file_path)
	for child in node.get_children():
		_collect_scene_paths(child, found)


## Compared by path, not identity: the two lists load the same file through
## different owners, and only the path is guaranteed to survive that.
func _same_path(a: Resource, b: Resource) -> bool:
	if a == null or b == null:
		return a == b
	return a.resource_path == b.resource_path


## Every visible label under `root`, joined: the test reads what a player reads.
func text_of(root: Node) -> String:
	var parts: Array[String] = []
	for child in root.find_children("*", "Label", true, false):
		var label := child as Label
		if label != null and label.visible:
			parts.append(label.text)
	return " | ".join(parts)


func _meta_label(root: Node, key: String) -> Label:
	for child in root.find_children("*", "Label", true, false):
		if child.has_meta(key):
			return child as Label
	return null


func _expect(condition: bool, description: String) -> bool:
	_checks += 1
	if not condition:
		_failures.append(description)
		print("  fail: %s" % description)
	return condition


func _finish() -> void:
	if _failures.is_empty():
		print("Data source smoke test passed (%d checks)." % _checks)
	else:
		print("Data source smoke test FAILED (%d of %d checks):" % [_failures.size(), _checks])
		for failure in _failures:
			print("  - %s" % failure)
	if is_instance_valid(_front_end):
		_front_end.free()
	quit(0 if _failures.is_empty() else 1)
