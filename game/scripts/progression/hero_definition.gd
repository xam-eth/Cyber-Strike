class_name HeroDefinition
extends Resource

## Where every hero lives, in one place.
##
## The hero roster is deliberately small: one operative is field-ready and the
## remaining cards on the HERO screen are placeholders marked IN DEVELOPMENT,
## because there is no second playable hero and inventing one would put a
## selectable card in front of a player with nothing behind it. What that does
## leave is a name and a description, and before this file existed the name was
## spelled out in three places -- the HERO card, the dashboard's loadout line
## and `ProgressionService.HERO_IDS` -- with nothing binding them together.
## A rename that catches two of the three prints a hero called one thing on the
## card and another on the dashboard, which is the same class of lie as a card
## quoting the wrong damage number. `data_source_smoke.gd` now reads all three
## and asserts they come from here.
##
## There is no health, speed or ability block on purpose: heroes have no
## per-hero gameplay model in this project. Every operative runs the same
## `CharacterVisual` and the same controller, so a stat here would be
## decoration -- a number a player can read that nothing in the game uses.
const DEFINITION_PATHS := {
	&"exo_operative": "res://resources/heroes/exo_operative.tres",
}

## Stable iteration order for the registry (GDScript dictionaries keep
## insertion order, but a named list is what a screen should read).
const DEFINITION_IDS: Array[StringName] = [
	&"exo_operative",
]

## The operative the profile falls back to when a save names one that no longer
## exists, and the one selected on a fresh install.
const DEFAULT_HERO_ID := &"exo_operative"

@export var hero_id: StringName = &""
@export var display_name: String = ""
@export_multiline var role_description: String = ""
@export var portrait_path: String = ""
@export var status_line: String = ""
@export var field_ready: bool = true


func is_valid_definition() -> bool:
	return (
		hero_id != &""
		and not display_name.strip_edges().is_empty()
		and not role_description.strip_edges().is_empty()
		and not status_line.strip_edges().is_empty()
		# The portrait is not decoration: it is the only picture of the hero a
		# player sees before the briefing, so an empty path would render a blank
		# card rather than fall back to anything.
		and ResourceLoader.exists(portrait_path)
	)


static func load_definition(hero_id: StringName) -> HeroDefinition:
	if not DEFINITION_PATHS.has(hero_id):
		return null
	return load(DEFINITION_PATHS[hero_id]) as HeroDefinition


## Canonical order: the registry's, not a second hand-written one.
static func load_all_definitions() -> Array[HeroDefinition]:
	var out: Array[HeroDefinition] = []
	for hero_id in DEFINITION_PATHS:
		var definition := load_definition(hero_id)
		if definition != null:
			out.append(definition)
	return out
