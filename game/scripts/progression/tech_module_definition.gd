class_name TechModuleDefinition
extends Resource

## Permanent Field Kit technology modules (docs/GAMEPLAY_DESIGN.md §8 & §9).
##
## Unlike temporary violet Run Evolutions (which reset every session), Tech
## Modules are permanent hardware schematics hunted across frontier theatres,
## fabricated once with Battle Points in the Armory, and equipped into up to
## two active Field Kit slots (`MAX_SLOTS = 2`).
const MAX_SLOTS: int = 2

const MODULE_IDS: Array[StringName] = [
	&"breach_capacitor",
	&"phase_thrusters",
	&"storm_conductor",
]

const COSTS := {
	"breach_capacitor": 140,
	"phase_thrusters": 120,
	"storm_conductor": 160,
}

static var _cache: Dictionary = {}

@export var module_id: StringName = &""
@export var title_key: String = ""
@export var role_key: String = ""
@export var summary_key: String = ""
@export var short_tag: String = ""
@export var source_world_id: StringName = &""
@export var source_cache_id: StringName = &""
@export var unlock_cost: int = 120
@export var modifiers: Dictionary = {}


static func all_definitions() -> Array[TechModuleDefinition]:
	_ensure_cache()
	var list: Array[TechModuleDefinition] = []
	for id in MODULE_IDS:
		var def := _cache.get(id) as TechModuleDefinition
		if def != null:
			list.append(def)
	return list


static func find(module_id: StringName) -> TechModuleDefinition:
	_ensure_cache()
	return _cache.get(module_id) as TechModuleDefinition


static func get_definition(module_id: StringName) -> TechModuleDefinition:
	return find(module_id)


static func cost_for(module_id: StringName) -> int:
	return int(COSTS.get(String(module_id), -1))


static func aggregate_modifiers(equipped_ids: Array[StringName]) -> Dictionary:
	var combined := {
		"ads_shield_pierce": false,
		"projectile_speed_multiplier": 1.0,
		"splash_radius_multiplier": 1.0,
		"move_speed_multiplier": 1.0,
		"reload_multiplier": 1.0,
		"emp_ammo_refill_ratio": 0.0,
		"chain_count_bonus": 0,
		"chain_radius_bonus": 0.0,
		"emp_radius_bonus": 0.0,
		"emp_cooldown_multiplier": 1.0,
		"arc_chain_emp_refund": 0.0,
	}
	var seen: Dictionary = {}
	var slots_used := 0
	for raw_id in equipped_ids:
		if slots_used >= MAX_SLOTS:
			break
		var id := StringName(raw_id)
		if seen.has(id):
			continue
		var def := find(id)
		if def == null:
			continue
		seen[id] = true
		slots_used += 1
		var mods := def.modifiers
		if mods.get("ads_shield_pierce") == true:
			combined["ads_shield_pierce"] = true
		combined["projectile_speed_multiplier"] = (
			float(combined["projectile_speed_multiplier"])
			* float(mods.get("projectile_speed_multiplier", 1.0))
		)
		combined["splash_radius_multiplier"] = (
			float(combined["splash_radius_multiplier"])
			* float(mods.get("splash_radius_multiplier", 1.0))
		)
		combined["move_speed_multiplier"] = (
			float(combined["move_speed_multiplier"]) * float(mods.get("move_speed_multiplier", 1.0))
		)
		combined["reload_multiplier"] = (
			float(combined["reload_multiplier"]) * float(mods.get("reload_multiplier", 1.0))
		)
		combined["emp_ammo_refill_ratio"] = clampf(
			(
				float(combined["emp_ammo_refill_ratio"])
				+ float(mods.get("emp_ammo_refill_ratio", 0.0))
			),
			0.0,
			1.0
		)
		combined["chain_count_bonus"] = (
			int(combined["chain_count_bonus"]) + int(mods.get("chain_count_bonus", 0))
		)
		combined["chain_radius_bonus"] = (
			float(combined["chain_radius_bonus"]) + float(mods.get("chain_radius_bonus", 0.0))
		)
		combined["emp_radius_bonus"] = (
			float(combined["emp_radius_bonus"]) + float(mods.get("emp_radius_bonus", 0.0))
		)
		combined["emp_cooldown_multiplier"] = (
			float(combined["emp_cooldown_multiplier"])
			* float(mods.get("emp_cooldown_multiplier", 1.0))
		)
		combined["arc_chain_emp_refund"] = (
			float(combined["arc_chain_emp_refund"]) + float(mods.get("arc_chain_emp_refund", 0.0))
		)
	return combined


static func active_tags_summary(equipped_ids: Array[StringName]) -> String:
	var tags := PackedStringArray()
	var seen: Dictionary = {}
	for raw_id in equipped_ids:
		if tags.size() >= MAX_SLOTS:
			break
		var id := StringName(raw_id)
		if seen.has(id):
			continue
		var def := find(id)
		if def == null:
			continue
		seen[id] = true
		tags.append(def.short_tag)
	return " + ".join(tags)


func display_title() -> String:
	return AegisText.t(title_key)


func display_role() -> String:
	return AegisText.t(role_key)


func display_summary() -> String:
	return AegisText.t(summary_key)


func display_source_world() -> String:
	var world := WorldDefinition.load_definition(source_world_id)
	if world != null:
		return world.display_name.to_upper()
	return String(source_world_id).to_upper()


static func _ensure_cache() -> void:
	if not _cache.is_empty():
		return
	var entries: Array[TechModuleDefinition] = [
		_make(
			&"breach_capacitor",
			"mod.breach.name",
			"mod.breach.role",
			"mod.breach.summary",
			"BREACH",
			&"emberfall_foundry",
			&"emberfall_seam_core",
			140,
			{
				"ads_shield_pierce": true,
				"projectile_speed_multiplier": 1.18,
				"splash_radius_multiplier": 1.20,
			}
		),
		_make(
			&"phase_thrusters",
			"mod.phase.name",
			"mod.phase.role",
			"mod.phase.summary",
			"PHASE",
			&"vanguard_station",
			&"vanguard_reactor_core",
			120,
			{
				"move_speed_multiplier": 1.14,
				"reload_multiplier": 0.88,
				"emp_ammo_refill_ratio": 0.35,
			}
		),
		_make(
			&"storm_conductor",
			"mod.storm.name",
			"mod.storm.role",
			"mod.storm.summary",
			"STORM",
			&"titans",
			&"titans_storm_spire",
			160,
			{
				"chain_count_bonus": 1,
				"chain_radius_bonus": 2.5,
				"emp_radius_bonus": 2.5,
				"emp_cooldown_multiplier": 0.82,
				"arc_chain_emp_refund": 0.75,
			}
		),
	]
	for entry in entries:
		_cache[entry.module_id] = entry


static func _make(
	id: StringName,
	t_key: String,
	r_key: String,
	s_key: String,
	tag: String,
	world_id: StringName,
	cache_id: StringName,
	cost: int,
	mods: Dictionary
) -> TechModuleDefinition:
	var def := TechModuleDefinition.new()
	def.module_id = id
	def.title_key = t_key
	def.role_key = r_key
	def.summary_key = s_key
	def.short_tag = tag
	def.source_world_id = world_id
	def.source_cache_id = cache_id
	def.unlock_cost = cost
	def.modifiers = mods
	return def
