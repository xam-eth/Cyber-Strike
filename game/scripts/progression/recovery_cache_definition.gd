class_name RecoveryCacheDefinition
extends Resource

## Authored Recovery content consumed explicitly by Main. This resource does
## not activate guards, decide completion, or write a profile by itself.
@export var cache_id: StringName = &""
@export var display_name: String = ""
@export var landmark_name: String = ""
@export var position: Vector3 = Vector3.ZERO
@export var optional: bool = false
@export_range(2.0, 12.0, 0.5) var interaction_radius: float = 5.0
@export_range(4.0, 60.0, 1.0) var discovery_radius: float = 24.0
@export
var model_scene_path: String = "res://assets/world/kenney_space_kit/station-computer-wide.glb"

## Stable reward transaction fields. A cache has one known reward; there is no
## rarity roll, random currency, or inventory payload in TECH HUNT 0.
@export var reward_id: StringName = &""
@export var blueprint_id: StringName = &""
@export_range(0, 10000, 1) var bp_reward: int = 0

## Each entry is { enemy_id: StringName, position: Vector3 }. WaveDirector
## validates and owns the resulting group; these are not extra wave spawns.
@export var guard_spawns: Array[Dictionary] = []


func is_valid_definition() -> bool:
	if (
		cache_id == &""
		or reward_id == &""
		or display_name.strip_edges().is_empty()
		or landmark_name.strip_edges().is_empty()
		or guard_spawns.is_empty()
		or bp_reward < 0
	):
		return false
	for spawn in guard_spawns:
		if StringName(str(spawn.get("enemy_id", ""))) == &"":
			return false
		if not spawn.get("position") is Vector3:
			return false
	return true
