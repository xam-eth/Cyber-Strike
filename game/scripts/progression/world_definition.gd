class_name WorldDefinition
extends Resource

## Where every theatre of war lives, in one place.
##
## A world is one id, one name and one scene. The name was spelled out in three
## places -- the WORLD card, the dashboard's loadout line and the cinematic's
## opening subtitle -- keyed off `ProgressionService.WORLD_IDS`, which
## hand-typed the id a fourth time. This file is the one place that spells both,
## and `data_source_smoke.gd` checks the three screens print what it says.
##
## The scene field is the part that matters beyond spelling: the WORLD screen
## names a theatre and the LAUNCH button loads `main.tscn`, and nothing tied
## the two together. `world_scene` declares which world the card is selling, and
## the test instantiates the gameplay scene and looks for a node whose
## `scene_file_path` is that file, so a card advertising a world the launcher
## does not contain fails the suite.
##
## The mission worlds share one scene file. They are the same node graph --
## a world node, collision geometry, a lighting rig -- and what differs is the GLB
## that node loads, chosen from `world_id`. Separate .tscn files for one script
## would be more places for that graph to drift apart.
##
## No wave count, enemy mix or difficulty rating: `mission_world.gd` owns that at
## runtime, and a copy of it here would go stale the moment it is tuned.
const DEFINITION_PATHS := {
	&"frostline_relay": "res://resources/worlds/frostline_relay.tres",
	&"verdant_bloom": "res://resources/worlds/verdant_bloom.tres",
	&"emberfall_foundry": "res://resources/worlds/emberfall_foundry.tres",
	&"vanguard_station": "res://resources/worlds/vanguard_station.tres",
	&"titans": "res://resources/worlds/titans.tres",
}

## Stable iteration order for the registry (GDScript dictionaries keep
## insertion order, but a named list is what a screen should read).
const DEFINITION_IDS: Array[StringName] = [
	&"frostline_relay",
	&"verdant_bloom",
	&"emberfall_foundry",
	&"vanguard_station",
	&"titans",
]

## The theatre the profile falls back to when a save names one that no longer
## exists, and the one selected on a fresh install.
const DEFAULT_WORLD_ID := &"frostline_relay"

@export var world_id: StringName = &""
@export var display_name: String = ""
@export_multiline var role_description: String = ""
@export var world_scene: PackedScene
## Optional environment asset consumed by the shared MissionWorld adapter.
## It is a path, not a PackedScene dependency: a broken external environment
## must not prevent this metadata, the theatre screen, or other worlds loading.
## Vanguard's internal adapter builds its own environment and leaves this empty.
@export var environment_scene_path: String = ""
## Physical fallback bounds belong to the World definition, not a second map in
## the adapter. They are used only for the safety floor and outer boundaries.
@export var field_size: Vector2 = Vector2(192.0, 180.0)
@export var field_center: Vector2 = Vector2(0.0, -10.0)
@export var plate_path: String = ""
@export var status_line: String = ""
## The objective card's explore-mode copy. It lived as two literals inside
## `hud_encounter_ui.gd`, so the second theatre described itself as a frontier
## with a safe zone to move freely in. A world now says what its own quiet state
## is; the HUD reads it instead of remembering one world's wording.
@export var zone_title: String = "EXPLORE THE FRONTIER"
@export var zone_subtitle: String = "SAFE ZONE · MOVE FREELY"
@export var field_ready: bool = true
## Gameplay reads this World-owned spawn after the shell selection is resolved.
## The default is the legacy main.tscn position, so existing theatres and test
## fixtures keep their original start unless their definition opts into another.
@export var player_spawn: Vector3 = Vector3(0.0, 0.0, 8.0)


## The theatre's prose, in the active language. Same rule as the hero card: the
## name is a proper noun, everything a player reads as a sentence is keyed.
func display_role() -> String:
	return AegisText.t_or("world.%s.role" % world_id, role_description)


func display_status() -> String:
	if not field_ready:
		return AegisText.t("common.in_development")
	return AegisText.t_or("world.%s.status" % world_id, status_line)


func display_zone_title() -> String:
	return AegisText.t_or("world.%s.zone_title" % world_id, zone_title)


func display_zone_subtitle() -> String:
	return AegisText.t_or("world.%s.zone_subtitle" % world_id, zone_subtitle)


func is_valid_definition() -> bool:
	return (
		world_id != &""
		and not display_name.strip_edges().is_empty()
		and not role_description.strip_edges().is_empty()
		and not status_line.strip_edges().is_empty()
		and is_instance_valid(world_scene)
		and field_size.x > 0.0
		and field_size.y > 0.0
		# The plate is the card's whole illustration, so like the hero portrait
		# an unusable path would render an empty box rather than a fallback.
		and ResourceLoader.exists(plate_path)
	)


static func load_definition(world_id: StringName) -> WorldDefinition:
	if not DEFINITION_PATHS.has(world_id):
		return null
	return load(DEFINITION_PATHS[world_id]) as WorldDefinition


## Canonical order: the registry's, not a second hand-written one.
static func load_all_definitions() -> Array[WorldDefinition]:
	var out: Array[WorldDefinition] = []
	for world_id in DEFINITION_PATHS:
		var definition := load_definition(world_id)
		if definition != null:
			out.append(definition)
	return out
