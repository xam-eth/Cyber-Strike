class_name HeroDefinition
extends Resource

## Single source of truth for a selectable hero's identity and presentation.
##
## Each field-ready definition binds its card to the actual runtime model and
## that model's retargeted rig profile. Portrait artwork is optional: when a
## definition has no standalone portrait, the HERO stage renders its GLB in a
## small SubViewport instead. Heroes share the player controller and combat
## tuning; this resource intentionally contains no decorative health, speed or
## damage stats.
const DEFINITION_PATHS := {
	&"exo_operative": "res://resources/heroes/exo_operative.tres",
	&"hero_tier_2_rare": "res://resources/heroes/hero_tier_2_rare.tres",
	&"hero_tier_3_epic": "res://resources/heroes/hero_tier_3_epic.tres",
}

## Stable iteration order for the registry (dictionaries retain insertion
## order, but a named list is what a screen and save validator should read).
const DEFINITION_IDS: Array[StringName] = [
	&"exo_operative",
	&"hero_tier_2_rare",
	&"hero_tier_3_epic",
]

## The operative the profile falls back to when a save names an unknown hero,
## and the one selected on a fresh install.
const DEFAULT_HERO_ID := &"exo_operative"

@export var hero_id: StringName = &""
@export var display_name: String = ""
@export_multiline var role_description: String = ""
@export var portrait_path: String = ""
@export var status_line: String = ""
@export var field_ready: bool = true
@export var model_scene: PackedScene
@export_file("*.json") var rig_path: String = ""
@export_range(1.0, 2.4, 0.01) var target_height: float = 1.78
@export_range(-180.0, 180.0, 1.0) var model_yaw_offset_degrees: float = 180.0


func is_valid_definition() -> bool:
	var has_identity := (
		hero_id != &""
		and not display_name.strip_edges().is_empty()
		and not role_description.strip_edges().is_empty()
		and not status_line.strip_edges().is_empty()
	)
	var has_model := model_scene != null and model_scene.can_instantiate()
	var has_rig := not rig_path.strip_edges().is_empty() and FileAccess.file_exists(rig_path)
	var has_portrait := (
		not portrait_path.strip_edges().is_empty() and ResourceLoader.exists(portrait_path)
	)
	var has_visual := has_portrait or has_model
	var ready_content_is_complete := not field_ready or (has_model and has_rig)
	return has_identity and has_visual and ready_content_is_complete


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
