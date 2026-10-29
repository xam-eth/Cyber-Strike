class_name RunUpgradeManager
extends Node

## Owns run-only temporary combat upgrades (`COLLECT -> CHOOSE -> EVOLVE`).
##
## Separation guarantee:
##   * State lives strictly on this Node for one mission run.
##   * Never writes to `ProgressionService`, `ConfigFile`, or `localStorage`.
##   * `reset_run()` clears all active stacks, pending choices, and charge.

signal state_changed
signal choices_ready(choices: Array[RunUpgradeDefinition], evolution_level: int)
signal upgrade_selected(definition: RunUpgradeDefinition, stack_count: int)

const MAX_EVOLUTIONS_PER_RUN := 5
const CHOICE_COUNT := 3
## Eliminations needed for each evolution step (2 -> 3 -> 4 -> 5 -> 6).
## 2 KOs guarantees the first evolution triggers inside both Verdant Bloom's
## 2-guard Seed Vault encounter and Wave 1 of Frontier Defense.
const BASE_CHARGE_REQUIREMENT := 2

var _catalog: Array[RunUpgradeDefinition] = []
var _stacks: Dictionary = {}
var _pending_choices: Array[RunUpgradeDefinition] = []
var _queued_grants: int = 0
var _evolutions_unlocked: int = 0
var _current_charge: int = 0
var _rewarded_enemy_ids: Dictionary = {}
var _awarded_milestones: Dictionary = {}
var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	_catalog = RunUpgradeDefinition.load_all_definitions()
	_rng.seed = 0xAE615


func set_seed(seed_value: int) -> void:
	_rng.seed = seed_value


func reset_run() -> void:
	_stacks.clear()
	_pending_choices.clear()
	_queued_grants = 0
	_evolutions_unlocked = 0
	_current_charge = 0
	_rewarded_enemy_ids.clear()
	_awarded_milestones.clear()
	state_changed.emit()


func record_elimination(enemy: Node = null) -> bool:
	if enemy != null:
		var id := enemy.get_instance_id()
		if _rewarded_enemy_ids.has(id):
			return false
		_rewarded_enemy_ids[id] = true
	if total_evolutions_claimed_or_queued() >= MAX_EVOLUTIONS_PER_RUN:
		return false
	if not has_available_upgrades():
		return false

	_current_charge += 1
	var needed := charge_required()
	if _current_charge >= needed:
		_current_charge -= needed
		_grant_evolution()
		return true
	state_changed.emit()
	return false


## Major encounter milestones (clearing a Recovery guard group or completing a
## wave before any evolution was earned) top off the first pending evolution so
## objective play always reaches CHOOSE -> EVOLVE cleanly.
func record_milestone(milestone_key: String) -> bool:
	if milestone_key.is_empty() or _awarded_milestones.has(milestone_key):
		return false
	_awarded_milestones[milestone_key] = true
	if total_evolutions_claimed_or_queued() >= MAX_EVOLUTIONS_PER_RUN:
		return false
	if not has_available_upgrades():
		return false
	_current_charge = 0
	_grant_evolution()
	return true


func total_evolutions_claimed_or_queued() -> int:
	var pending := 1 if not _pending_choices.is_empty() else 0
	return total_stacks() + pending + _queued_grants


func total_stacks() -> int:
	var sum := 0
	for value in _stacks.values():
		sum += int(value)
	return sum


func stack_count(upgrade_id: StringName) -> int:
	return int(_stacks.get(String(upgrade_id), 0))


func current_charge() -> int:
	return _current_charge


func charge_required() -> int:
	return BASE_CHARGE_REQUIREMENT + total_evolutions_claimed_or_queued()


func is_maxed() -> bool:
	return (
		total_evolutions_claimed_or_queued() >= MAX_EVOLUTIONS_PER_RUN
		or not has_available_upgrades()
	)


func has_pending_choice() -> bool:
	return not _pending_choices.is_empty()


func pending_count() -> int:
	return (1 if not _pending_choices.is_empty() else 0) + _queued_grants


func get_pending_choices() -> Array[RunUpgradeDefinition]:
	return _pending_choices.duplicate()


func has_available_upgrades() -> bool:
	if _catalog.is_empty():
		_catalog = RunUpgradeDefinition.load_all_definitions()
	for entry in _catalog:
		if stack_count(entry.upgrade_id) < entry.max_stacks:
			return true
	return false


func select_choice(index: int) -> RunUpgradeDefinition:
	if index < 0 or index >= _pending_choices.size():
		return null
	var chosen := _pending_choices[index]
	return apply_upgrade_by_id(chosen.upgrade_id)


func apply_upgrade_by_id(upgrade_id: StringName) -> RunUpgradeDefinition:
	if _catalog.is_empty():
		_catalog = RunUpgradeDefinition.load_all_definitions()
	var chosen: RunUpgradeDefinition = null
	for entry in _catalog:
		if entry.upgrade_id == upgrade_id:
			chosen = entry
			break
	if chosen == null:
		return null
	var current := stack_count(upgrade_id)
	if current >= chosen.max_stacks:
		return null

	var next_stack := current + 1
	_stacks[String(upgrade_id)] = next_stack
	_pending_choices.clear()
	print("RunUpgrade: applied %s stack=%d" % [upgrade_id, next_stack])
	upgrade_selected.emit(chosen, next_stack)

	if _queued_grants > 0 and has_available_upgrades():
		_queued_grants -= 1
		_roll_pending_choices()
	state_changed.emit()
	return chosen


func get_modifiers() -> Dictionary:
	if _catalog.is_empty():
		_catalog = RunUpgradeDefinition.load_all_definitions()
	var damage_mult := 1.0
	var fire_rate_mult := 1.0
	var reload_mult := 1.0
	var magazine_mult := 1.0
	var range_mult := 1.0
	var emp_cd_mult := 1.0
	var emp_radius_add := 0.0
	var emp_damage_add := 0.0
	var speed_mult := 1.0
	var health_add := 0.0
	var armour_add := 0.0

	for entry in _catalog:
		var stacks := stack_count(entry.upgrade_id)
		if stacks <= 0:
			continue
		damage_mult += entry.damage_bonus_per_stack * float(stacks)
		fire_rate_mult += entry.fire_rate_bonus_per_stack * float(stacks)
		reload_mult *= pow(entry.reload_factor_per_stack, float(stacks))
		magazine_mult += entry.magazine_bonus_per_stack * float(stacks)
		range_mult += entry.range_bonus_per_stack * float(stacks)
		emp_cd_mult *= pow(entry.emp_cooldown_factor_per_stack, float(stacks))
		emp_radius_add += entry.emp_radius_bonus_per_stack * float(stacks)
		emp_damage_add += entry.emp_damage_bonus_per_stack * float(stacks)
		speed_mult += entry.move_speed_bonus_per_stack * float(stacks)
		health_add += entry.max_health_bonus_per_stack * float(stacks)
		armour_add += entry.damage_reduction_bonus_per_stack * float(stacks)

	return {
		"damage_multiplier": damage_mult,
		"fire_rate_multiplier": fire_rate_mult,
		"reload_multiplier": reload_mult,
		"magazine_multiplier": magazine_mult,
		"range_multiplier": range_mult,
		"emp_cooldown_multiplier": emp_cd_mult,
		"emp_radius_bonus": emp_radius_add,
		"emp_damage_bonus": emp_damage_add,
		"move_speed_multiplier": speed_mult,
		"max_health_bonus": health_add,
		"damage_reduction_bonus": armour_add,
	}


## Compact badge summary for HUD strip & Results report (e.g. `OVR L1 · EMP+ L2`).
func active_tags_summary() -> String:
	if _catalog.is_empty():
		_catalog = RunUpgradeDefinition.load_all_definitions()
	var parts: Array[String] = []
	for entry in _catalog:
		var stacks := stack_count(entry.upgrade_id)
		if stacks > 0:
			parts.append("%s L%d" % [entry.short_tag, stacks])
	return " · ".join(parts)


func _grant_evolution() -> void:
	_evolutions_unlocked += 1
	if _pending_choices.is_empty():
		_roll_pending_choices()
	else:
		_queued_grants += 1
	state_changed.emit()


func _roll_pending_choices() -> void:
	if _catalog.is_empty():
		_catalog = RunUpgradeDefinition.load_all_definitions()
	var pool: Array[RunUpgradeDefinition] = []
	for entry in _catalog:
		if stack_count(entry.upgrade_id) < entry.max_stacks:
			pool.append(entry)
	_pending_choices.clear()
	while not pool.is_empty() and _pending_choices.size() < CHOICE_COUNT:
		var pick := _rng.randi_range(0, pool.size() - 1)
		_pending_choices.append(pool[pick])
		pool.remove_at(pick)
	if not _pending_choices.is_empty():
		choices_ready.emit(_pending_choices.duplicate(), total_stacks() + 1)
