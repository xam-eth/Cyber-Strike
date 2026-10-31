class_name EnemyDefinition
extends Resource

## Public encounter content: stable id, gameplay role, and the scene that
## implements it. WaveDirector consumes this interface instead of preloading
## individual enemy scenes. Behaviour statistics stay on the existing enemy
## behaviours for now; duplicating them here would create a second source of
## truth before the separate stat-migration work is approved.
const DEFINITION_PATHS := {
	&"runner": "res://resources/enemies/runner.tres",
	&"shooter": "res://resources/enemies/shooter.tres",
	&"guardian": "res://resources/enemies/guardian.tres",
}

const DEFINITION_IDS: Array[StringName] = [&"runner", &"shooter", &"guardian"]

@export var enemy_id: StringName = &""
@export var display_name: String = ""
@export var gameplay_role: StringName = &""
@export_multiline var role_description: String = ""
@export var enemy_scene: PackedScene


func is_valid_definition() -> bool:
	return (
		enemy_id != &""
		and not display_name.strip_edges().is_empty()
		and gameplay_role != &""
		and not role_description.strip_edges().is_empty()
		and enemy_scene != null
		and enemy_scene.can_instantiate()
	)


static func load_definition(enemy_id: StringName) -> EnemyDefinition:
	if not DEFINITION_PATHS.has(enemy_id):
		return null
	return load(DEFINITION_PATHS[enemy_id]) as EnemyDefinition


static func load_all_definitions() -> Array[EnemyDefinition]:
	var definitions: Array[EnemyDefinition] = []
	for enemy_id in DEFINITION_IDS:
		var definition := load_definition(enemy_id)
		if definition != null:
			definitions.append(definition)
	return definitions
