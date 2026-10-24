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
## does not contain fails the suite. There is only one world today, so this is
## cheap -- it is here so the second one cannot silently lie.
##
## No wave count, enemy mix or difficulty rating: `neon_frontier_world.gd` owns
## that at runtime, and a copy of it here would go stale the moment it is tuned.
const DEFINITION_PATHS := {
	&"neon_frontier": "res://resources/worlds/neon_frontier.tres",
}

## Stable iteration order for the registry (GDScript dictionaries keep
## insertion order, but a named list is what a screen should read).
const DEFINITION_IDS: Array[StringName] = [
	&"neon_frontier",
]

## The theatre the profile falls back to when a save names one that no longer
## exists, and the one selected on a fresh install.
const DEFAULT_WORLD_ID := &"neon_frontier"

@export var world_id: StringName = &""
@export var display_name: String = ""
@export_multiline var role_description: String = ""
@export var world_scene: PackedScene
@export var plate_path: String = ""
@export var status_line: String = ""
@export var field_ready: bool = true


func is_valid_definition() -> bool:
	return (
		world_id != &""
		and not display_name.strip_edges().is_empty()
		and not role_description.strip_edges().is_empty()
		and not status_line.strip_edges().is_empty()
		and is_instance_valid(world_scene)
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
