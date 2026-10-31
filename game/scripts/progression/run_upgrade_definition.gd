class_name RunUpgradeDefinition
extends Resource

## Public content contract for one temporary field adaptation. The service owns
## whether it was earned/selected; WeaponController owns the resulting combat
## values; the UI only renders this resource. No profile/save fields live here.
const DEFINITION_PATHS := {
	&"overcharge": "res://resources/upgrades/overcharge.tres",
	&"quick_cycle": "res://resources/upgrades/quick_cycle.tres",
}
const DEFINITION_IDS: Array[StringName] = [&"overcharge", &"quick_cycle"]

@export var upgrade_id: StringName = &""
@export var display_name_key: String = ""
@export var effect_key: String = ""
@export_range(0.25, 4.0, 0.01) var damage_multiplier: float = 1.0
@export_range(0.25, 2.0, 0.01) var reload_multiplier: float = 1.0
@export var compatible_weapons: Array[StringName] = [
	&"pulse_rifle",
	&"nova_launcher",
	&"arc_shooter",
]


func display_name() -> String:
	return AegisText.t(display_name_key)


func effect_description() -> String:
	return AegisText.t(effect_key)


func supports_weapon(weapon_id: StringName) -> bool:
	return compatible_weapons.has(weapon_id)


func is_valid_definition() -> bool:
	if (
		upgrade_id == &""
		or display_name_key.is_empty()
		or effect_key.is_empty()
		or compatible_weapons.is_empty()
	):
		return false
	if is_equal_approx(damage_multiplier, 1.0) and is_equal_approx(reload_multiplier, 1.0):
		return false
	for weapon_id in compatible_weapons:
		if not WeaponDefinition.DEFINITION_IDS.has(weapon_id):
			return false
	return true


static func load_definition(upgrade_id: StringName) -> RunUpgradeDefinition:
	if not DEFINITION_PATHS.has(upgrade_id):
		return null
	return load(DEFINITION_PATHS[upgrade_id]) as RunUpgradeDefinition


static func load_all_definitions() -> Array[RunUpgradeDefinition]:
	var result: Array[RunUpgradeDefinition] = []
	for upgrade_id in DEFINITION_IDS:
		var definition := load_definition(upgrade_id)
		if definition != null:
			result.append(definition)
	return result
