class_name HeroTier
extends RefCounted

## The five ranks of a hero, read from `resources/heroes/roster.json`.
##
## The roster is one file for both halves of the product: the web shell builds
## the operative page's tier cards and ladder from it, and this class gives the
## engine the same numbers -- which model a tier wears, per-hero vitals/mobility,
## tactical capability specs, and how many completed runs unlock each tier.

const ROSTER_PATH := "res://resources/heroes/roster.json"

static var _roster: Dictionary = {}
static var _loaded: bool = false


static func roster() -> Dictionary:
	if _loaded:
		return _roster
	_loaded = true
	_roster = {}
	var text := _read(ROSTER_PATH)
	if text.is_empty():
		push_warning("HeroTier: %s could not be read; the ladder is empty." % ROSTER_PATH)
		return _roster
	var parsed: Variant = JSON.parse_string(text)
	if not parsed is Dictionary:
		push_warning("HeroTier: %s is not a JSON object." % ROSTER_PATH)
		return _roster
	_roster = parsed
	return _roster


static func _read(path: String) -> String:
	if FileAccess.file_exists(path):
		return FileAccess.get_file_as_string(path)
	var resource: Variant = load(path)
	if resource is JSON and (resource as JSON).data != null:
		return JSON.stringify((resource as JSON).data)
	return ""


static func has_roster() -> bool:
	return not roster().is_empty()


static func tier_count() -> int:
	return int(roster().get("tier_count", 0))


static func rows() -> Array:
	var out: Array = roster().get("tiers", [])
	return out


static func row(tier: int) -> Dictionary:
	var table := rows()
	if table.is_empty():
		return {}
	var want := clampi(tier, 1, table.size())
	for entry in table:
		if int(entry.get("tier", 0)) == want:
			return entry
	return table[clampi(want - 1, 0, table.size() - 1)]


static func owned_tier(completed_runs: int) -> int:
	var owned := 1
	for entry in rows():
		if completed_runs >= int(entry.get("runs_required", 0)):
			owned = maxi(owned, int(entry.get("tier", 1)))
	return owned


static func vitals(tier: int, hero_id: StringName = &"") -> float:
	var base := float(row(tier).get("vitals", 100))
	if hero_id == &"":
		return base
	var offset := float(hero(hero_id).get("vitals_offset", 0))
	return maxf(base + offset, 1.0)


static func reduction(tier: int, hero_id: StringName = &"") -> float:
	var base := float(row(tier).get("reduction", 0))
	if hero_id == &"":
		return base
	var offset := float(hero(hero_id).get("reduction_offset", 0))
	return clampf(base + offset, 0.0, 90.0)


static func hero(hero_id: StringName) -> Dictionary:
	for entry in roster().get("heroes", []):
		if StringName(str(entry.get("id", ""))) == hero_id:
			return entry
	return {}


static func callsign(hero_id: StringName) -> String:
	var entry := hero(hero_id)
	var sign := str(entry.get("callsign", ""))
	if not sign.is_empty():
		return sign
	return String(hero_id).to_upper()


static func skill_id(hero_id: StringName) -> StringName:
	var raw := str(hero(hero_id).get("skill_id", "emp_pulse"))
	return StringName(raw if not raw.is_empty() else "emp_pulse")


static func move_speed_multiplier(hero_id: StringName) -> float:
	var pct := float(hero(hero_id).get("speed_pct", 0.0))
	return clampf(1.0 + pct * 0.01, 0.5, 2.0)


static func reload_multiplier(hero_id: StringName) -> float:
	var pct := float(hero(hero_id).get("reload_pct", 0.0))
	return clampf(1.0 + pct * 0.01, 0.4, 2.0)


static func skill_spec(hero_id: StringName) -> Dictionary:
	var entry := hero(hero_id)
	return {
		"skill_id": skill_id(hero_id),
		"cooldown": maxf(float(entry.get("skill_cooldown", 12.0)), 1.0),
		"range": maxf(float(entry.get("skill_range", 9.0)), 1.0),
		"damage": maxf(float(entry.get("skill_damage", 18.0)), 0.0),
		"overdrive_seconds": maxf(float(entry.get("overdrive_seconds", 0.0)), 0.0),
		"overdrive_speed_multiplier":
		1.0 + maxf(float(entry.get("overdrive_speed_pct", 0.0)), 0.0) * 0.01,
		"overdrive_fire_rate_multiplier":
		1.0 + maxf(float(entry.get("overdrive_rate_pct", 0.0)), 0.0) * 0.01,
	}


static func tier_livery(hero_id: StringName, tier: int) -> Dictionary:
	var item := _tier_row(hero_id, tier)
	var tint := str(item.get("tint", ""))
	if tint.is_empty():
		return {}
	return {
		"tint": tint,
		"emission": str(item.get("emission", "#000000")),
		"energy": float(item.get("energy", 0.0)),
		"metal": float(item.get("metal", -1.0)),
		"rough": float(item.get("rough", -1.0)),
	}


static func model_path(hero_id: StringName, tier: int) -> String:
	return _engine_path(_tier_field(hero_id, tier, "model"))


static func rig_path(hero_id: StringName, tier: int) -> String:
	return _engine_path(_tier_field(hero_id, tier, "rig"))


static func art_path(hero_id: StringName, tier: int) -> String:
	return _tier_field(hero_id, tier, "art")


static func _engine_path(path: String) -> String:
	if path.begins_with("game/"):
		return "res://" + path.trim_prefix("game/")
	return path


static func _tier_row(hero_id: StringName, tier: int) -> Dictionary:
	var entry := hero(hero_id)
	var table: Array = entry.get("tiers", [])
	if table.is_empty():
		return {}
	var want := clampi(tier, 1, table.size())
	for item in table:
		if item is Dictionary and int(item.get("tier", 0)) == want:
			return item
	return {}


static func _tier_field(hero_id: StringName, tier: int, field: String) -> String:
	var item := _tier_row(hero_id, tier)
	var value: Variant = item.get(field, null)
	return str(value) if value is String else ""


static func is_field_ready(hero_id: StringName) -> bool:
	var entry := hero(hero_id)
	if entry.is_empty():
		return false
	return str(entry.get("status", "")) == "field_ready" and not model_path(hero_id, 1).is_empty()
