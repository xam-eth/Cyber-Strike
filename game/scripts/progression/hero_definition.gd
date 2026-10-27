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
## Tiers live beside this file, not inside it: `resources/heroes/roster.json`
## is the one table of what each of a hero's five ranks looks like, what it is
## worth and what it costs in runs, and `HeroTier` reads it for both the shell
## and the engine. A hero definition therefore describes *the operative* (name,
## role, portrait, the tier-1 rig the showcase opens on); the ladder is data.
##
## There is no speed or ability block on purpose: heroes have no per-hero
## movement or skill model in this project, so such a field would be decoration.
## Health and damage reduction *are* here, because a tier changes them and the
## arena applies them (`PlayerController` reads `HeroTier.vitals/reduction`).
const DEFINITION_PATHS := {
	&"sable": "res://resources/heroes/sable.tres",
}

## Stable iteration order for the registry (GDScript dictionaries keep
## insertion order, but a named list is what a screen should read).
const DEFINITION_IDS: Array[StringName] = [
	&"sable",
]

## The operative the profile falls back to when a save names one that no longer
## exists, and the one selected on a fresh install.
const DEFAULT_HERO_ID := &"sable"

@export var hero_id: StringName = &""
@export var display_name: String = ""
@export_multiline var role_description: String = ""
@export var portrait_path: String = ""
@export var status_line: String = ""
@export var field_ready: bool = true

## The rigged model, declared once and used by both the HERO showcase and the
## player avatar. Before this field the model path existed only inside
## `player.tscn`, so a selection screen had to either guess it or fall back to a
## painted portrait -- and a showcase showing a different model from the one
## that spawns is the same class of lie as a card quoting the wrong damage
## number. `showcase_smoke.gd` asserts the resolved definition path and the
## scene's `VisualRoot.model_scene_path` name the same file.
@export var model_scene: PackedScene
## Dynamic equivalent used by imported/character-owned content. Prefer this for
## new definitions: the roster and UI metadata remain readable even when the
## visual asset is unavailable. `model_scene` remains for trusted fixtures and
## backwards-compatible internal resources.
@export var model_scene_path: String = ""
## Showcase clips, in the order the screen should cycle them. They are checked
## against the GLB before anything plays (`ShowcaseViewport` only ever calls
## `has_animation`), and `showcase_smoke.gd` fails if one is not in the file --
## an animation name is not a thing to assume, it is a thing to measure.
@export var showcase_clips: Array[String] = ["idle", "aim", "fire"]


## The words on the card, not the words in the file.
##
## `display_name` ("Mara Voss") is a proper noun and never translated. The
## role and the status are prose a player reads, so they come from the catalog
## by id and fall back to the authored English when a language has not written
## its own line yet. `IN DEVELOPMENT` is the one status that is not a resource
## string at all -- it is the absence of a definition -- so it is keyed here.
func display_role() -> String:
	return AegisText.t_or("hero.%s.role" % hero_id, role_description)


func display_status() -> String:
	return AegisText.t_or("hero.%s.status" % hero_id, status_line)


static func development_status() -> String:
	return AegisText.t("common.in_development")


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
		# Structural validity is separate from visual availability. Gameplay has
		# a capsule fallback; the showcase reports a failed load without taking
		# down the roster or another Character package.
		and (is_instance_valid(model_scene) or not model_scene_path.is_empty())
	)


func resolved_model_path() -> String:
	if is_instance_valid(model_scene):
		return model_scene.resource_path
	return model_scene_path


func load_model_scene() -> PackedScene:
	if is_instance_valid(model_scene):
		return model_scene
	var result := ContentModuleLoader.load_scene(
		model_scene_path, ContentModuleLoader.CHARACTER_ROOTS
	)
	return result["scene"] as PackedScene if bool(result["ok"]) else null


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
