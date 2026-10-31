class_name RunUpgradeService
extends Node

## The only owner of temporary adaptation state for one Main scene/deployment.
## It never reads or writes ProgressionService's profile. An offer is consumed
## when presented so duplicate guard-clear signals cannot farm another choice.
signal offer_changed
signal selection_changed

var offer_available: bool:
	get:
		return _offer_available

var offer_consumed: bool:
	get:
		return _offer_consumed

var selected_id: StringName:
	get:
		return _selected_id

var _definitions: Array[RunUpgradeDefinition] = []
var _offer_available: bool = false
var _offer_consumed: bool = false
var _selected_id: StringName = &""


func _ready() -> void:
	_load_definitions()


func definitions() -> Array[RunUpgradeDefinition]:
	_load_definitions()
	return _definitions.duplicate()


func offer() -> bool:
	_load_definitions()
	if _offer_consumed or _offer_available or _selected_id != &"" or _definitions.is_empty():
		return false
	for definition in _definitions:
		if not definition.is_valid_definition():
			push_warning("Run upgrades: invalid definition '%s'." % definition.upgrade_id)
			return false
	_offer_available = true
	_offer_consumed = true
	offer_changed.emit()
	return true


func choose(upgrade_id: StringName, weapon_id: StringName) -> bool:
	if not _offer_available or _selected_id != &"":
		return false
	var definition := _find(upgrade_id)
	if definition == null or not definition.supports_weapon(weapon_id):
		return false
	_selected_id = upgrade_id
	_offer_available = false
	offer_changed.emit()
	selection_changed.emit()
	return true


func selected_definition() -> RunUpgradeDefinition:
	return _find(_selected_id)


func modifiers() -> Dictionary:
	var definition := selected_definition()
	if definition == null:
		return {"damage": 1.0, "reload": 1.0}
	return {
		"damage": definition.damage_multiplier,
		"reload": definition.reload_multiplier,
	}


func reset_run() -> void:
	var changed := _offer_available or _offer_consumed or _selected_id != &""
	_offer_available = false
	_offer_consumed = false
	_selected_id = &""
	if changed:
		offer_changed.emit()
		selection_changed.emit()


func _load_definitions() -> void:
	if not _definitions.is_empty():
		return
	_definitions = RunUpgradeDefinition.load_all_definitions()


func _find(upgrade_id: StringName) -> RunUpgradeDefinition:
	_load_definitions()
	for definition in _definitions:
		if definition.upgrade_id == upgrade_id:
			return definition
	return null
