class_name WeaponTier
extends RefCounted

## Shared, bounded weapon progression for the engine, Armory and Web shell.
## ProgressionService owns the saved rank and BP transaction; this class only
## reads the table. WeaponController applies these multipliers to runtime
## duplicates, never to the authored WeaponDefinition resources.
const TABLE_PATH := "res://resources/weapons/tiers.json"

static var _table: Dictionary = {}
static var _loaded: bool = false


static func table() -> Dictionary:
	if _loaded:
		return _table
	_loaded = true
	_table = {}
	var text := _read(TABLE_PATH)
	if text.is_empty():
		push_warning("WeaponTier: %s could not read; tier 1 is the fallback." % TABLE_PATH)
		return _table
	var parsed: Variant = JSON.parse_string(text)
	if not parsed is Dictionary:
		push_warning("WeaponTier: %s is not a JSON object." % TABLE_PATH)
		return _table
	_table = parsed
	return _table


static func _read(path: String) -> String:
	if FileAccess.file_exists(path):
		return FileAccess.get_file_as_string(path)
	var resource: Variant = load(path)
	if resource is JSON and (resource as JSON).data != null:
		return JSON.stringify((resource as JSON).data)
	return ""


static func has_table() -> bool:
	return not table().is_empty() and not rows().is_empty()


static func tier_count() -> int:
	return maxi(1, int(table().get("tier_count", rows().size())))


static func rows() -> Array:
	var result: Array = table().get("tiers", [])
	return result


static func row(tier: int) -> Dictionary:
	var entries := rows()
	if entries.is_empty():
		return {"tier": 1, "damage_multiplier": 1.0, "reload_multiplier": 1.0, "costs": {}}
	var wanted := clampi(tier, 1, mini(tier_count(), entries.size()))
	for entry in entries:
		if entry is Dictionary and int(entry.get("tier", 0)) == wanted:
			return entry
	return entries[wanted - 1]


static func damage_multiplier(tier: int) -> float:
	return clampf(float(row(tier).get("damage_multiplier", 1.0)), 1.0, 1.16)


static func reload_multiplier(tier: int) -> float:
	return clampf(float(row(tier).get("reload_multiplier", 1.0)), 0.92, 1.0)


## Cost of purchasing [param target_tier], not a cumulative price. Tier 1 is
## free; an unknown weapon or a tier outside the table returns -1.
static func cost(weapon_id: StringName, target_tier: int) -> int:
	if not WeaponDefinition.DEFINITION_IDS.has(weapon_id):
		return -1
	if target_tier < 1 or target_tier > tier_count():
		return -1
	if target_tier == 1:
		return 0
	var costs: Variant = row(target_tier).get("costs", {})
	if not costs is Dictionary:
		return -1
	return int(costs.get(String(weapon_id), -1))
