class_name RunUpgradeDefinition
extends Resource

## Temporary, run-scoped tactical evolution definition.
##
## Architectural boundary:
##   * Never written to `user://progression.cfg` or `ProgressionService`.
##   * Never mutates authored `.tres` weapon or hero resources on disk.
##   * Resets to zero on retry, exploration reset, or returning to Command Hub.

const CATEGORY_WEAPON := &"weapon"
const CATEGORY_TACTICAL := &"tactical"
const CATEGORY_MOBILITY := &"mobility"
const CATEGORY_SURVIVAL := &"survival"

const DEFINITION_IDS: Array[StringName] = [
	&"overcharge_cells",
	&"rapid_autoloader",
	&"expanded_capacitor",
	&"emp_resonator",
	&"kinetic_servos",
	&"reactive_plating",
]

@export var upgrade_id: StringName = &""
@export var category: StringName = CATEGORY_WEAPON
@export var short_tag: String = "MOD"
@export var title_key: String = ""
@export var summary_key: String = ""
@export var fallback_title: String = ""
@export var fallback_summary: String = ""
@export_range(1, 5, 1) var max_stacks: int = 2

## Per-stack additive or multiplicative modifiers applied to runtime copies.
@export var damage_bonus_per_stack: float = 0.0
@export var fire_rate_bonus_per_stack: float = 0.0
@export var reload_factor_per_stack: float = 1.0
@export var magazine_bonus_per_stack: float = 0.0
@export var range_bonus_per_stack: float = 0.0
@export var emp_cooldown_factor_per_stack: float = 1.0
@export var emp_radius_bonus_per_stack: float = 0.0
@export var emp_damage_bonus_per_stack: float = 0.0
@export var move_speed_bonus_per_stack: float = 0.0
@export var max_health_bonus_per_stack: float = 0.0
@export var damage_reduction_bonus_per_stack: float = 0.0
@export var instant_heal_on_pick: float = 0.0
@export var refill_magazine_on_pick: bool = false


func display_title() -> String:
	return AegisText.t_or(title_key, fallback_title)


func display_summary() -> String:
	return AegisText.t_or(summary_key, fallback_summary)


func display_category() -> String:
	match category:
		CATEGORY_WEAPON:
			return AegisText.t("hud.upg_cat_weapon")
		CATEGORY_TACTICAL:
			return AegisText.t("hud.upg_cat_tactical")
		CATEGORY_MOBILITY:
			return AegisText.t("hud.upg_cat_mobility")
		CATEGORY_SURVIVAL:
			return AegisText.t("hud.upg_cat_survival")
		_:
			return AegisText.t("hud.upg_cat_weapon")


func is_valid_definition() -> bool:
	return (
		upgrade_id != &""
		and not short_tag.strip_edges().is_empty()
		and max_stacks >= 1
		and (not title_key.is_empty() or not fallback_title.is_empty())
	)


static func load_all_definitions() -> Array[RunUpgradeDefinition]:
	return [
		_make(
			&"overcharge_cells",
			CATEGORY_WEAPON,
			"OVR",
			"hud.upg_overcharge_title",
			"hud.upg_overcharge_desc",
			"OVERCHARGE CELLS",
			"+20% weapon & splash damage",
			{"damage": 0.20}
		),
		_make(
			&"rapid_autoloader",
			CATEGORY_WEAPON,
			"RLD",
			"hud.upg_autoloader_title",
			"hud.upg_autoloader_desc",
			"RAPID AUTOLOADER",
			"+18% fire rate, -22% reload & instant mag refill",
			{"fire_rate": 0.18, "reload_factor": 0.78, "refill": true}
		),
		_make(
			&"expanded_capacitor",
			CATEGORY_WEAPON,
			"CAP",
			"hud.upg_capacitor_title",
			"hud.upg_capacitor_desc",
			"HIGH-CAP CAPACITOR",
			"+35% magazine capacity & +15% effective range",
			{"magazine": 0.35, "range": 0.15, "refill": true}
		),
		_make(
			&"emp_resonator",
			CATEGORY_TACTICAL,
			"EMP+",
			"hud.upg_emp_title",
			"hud.upg_emp_desc",
			"EMP RESONATOR",
			"-25% EMP cooldown, +3m blast radius & +12 EMP dmg",
			{"emp_cd": 0.75, "emp_rad": 3.0, "emp_dmg": 12.0}
		),
		_make(
			&"kinetic_servos",
			CATEGORY_MOBILITY,
			"SPD",
			"hud.upg_servos_title",
			"hud.upg_servos_desc",
			"KINETIC SERVOS",
			"+16% move speed & instant +25 HP repair",
			{"speed": 0.16, "heal": 25.0}
		),
		_make(
			&"reactive_plating",
			CATEGORY_SURVIVAL,
			"PLT",
			"hud.upg_plating_title",
			"hud.upg_plating_desc",
			"REACTIVE PLATING",
			"+25 max vitals, +10% armour & +25 HP repair",
			{"vitals": 25.0, "armour": 0.10, "heal": 25.0}
		),
	]


static func load_definition(wanted_id: StringName) -> RunUpgradeDefinition:
	for entry in load_all_definitions():
		if entry.upgrade_id == wanted_id:
			return entry
	return null


static func _make(
	id: StringName,
	cat: StringName,
	tag: String,
	t_key: String,
	s_key: String,
	f_title: String,
	f_summary: String,
	mods: Dictionary,
) -> RunUpgradeDefinition:
	var item := RunUpgradeDefinition.new()
	item.upgrade_id = id
	item.category = cat
	item.short_tag = tag
	item.title_key = t_key
	item.summary_key = s_key
	item.fallback_title = f_title
	item.fallback_summary = f_summary
	item.max_stacks = int(mods.get("max_stacks", 2))
	item.damage_bonus_per_stack = float(mods.get("damage", 0.0))
	item.fire_rate_bonus_per_stack = float(mods.get("fire_rate", 0.0))
	item.reload_factor_per_stack = float(mods.get("reload_factor", 1.0))
	item.magazine_bonus_per_stack = float(mods.get("magazine", 0.0))
	item.range_bonus_per_stack = float(mods.get("range", 0.0))
	item.emp_cooldown_factor_per_stack = float(mods.get("emp_cd", 1.0))
	item.emp_radius_bonus_per_stack = float(mods.get("emp_rad", 0.0))
	item.emp_damage_bonus_per_stack = float(mods.get("emp_dmg", 0.0))
	item.move_speed_bonus_per_stack = float(mods.get("speed", 0.0))
	item.max_health_bonus_per_stack = float(mods.get("vitals", 0.0))
	item.damage_reduction_bonus_per_stack = float(mods.get("armour", 0.0))
	item.instant_heal_on_pick = float(mods.get("heal", 0.0))
	item.refill_magazine_on_pick = bool(mods.get("refill", false))
	return item
