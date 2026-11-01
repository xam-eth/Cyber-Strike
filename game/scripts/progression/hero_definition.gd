class_name HeroDefinition
extends Resource

## Where every hero lives, in one place.
##
## Field-ready operatives (`sable`, `kestrel`) are registered here and mirrored
## in `resources/heroes/roster.json`, which `HeroTier` and the Web shell both
## read for per-hero vitals, tactical mobility, active capability specs, and
## the five-tier armour/livery ladder. `data_source_smoke.gd` and
## `tools/check_hero_roster.py` verify that both registries name the exact same
## field-ready operatives.
const DEFINITION_PATHS := {
	&"sable": "res://resources/heroes/sable.tres",
	&"kestrel": "res://resources/heroes/kestrel.tres",
}

## Stable iteration order for the registry.
const DEFINITION_IDS: Array[StringName] = [
	&"sable",
	&"kestrel",
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
@export var model_scene: PackedScene
@export var model_scene_path: String = ""
@export var showcase_clips: Array[String] = ["idle", "aim", "fire"]


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
		and ResourceLoader.exists(portrait_path)
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


static func load_all_definitions() -> Array[HeroDefinition]:
	var out: Array[HeroDefinition] = []
	for hero_id in DEFINITION_PATHS:
		var definition := load_definition(hero_id)
		if definition != null:
			out.append(definition)
	return out
