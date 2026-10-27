class_name HeroTier
extends RefCounted

## The five ranks of a hero, read from `resources/heroes/roster.json`.
##
## The roster is one file for both halves of the product: the web shell builds
## the operative page's tier cards and ladder from it, and this class gives the
## engine the same numbers -- which model a tier wears, what it is worth in
## health and damage reduction, and how many completed runs unlock it. Before
## this file the tier ladder existed only in the shell's copy of the data, which
## is exactly how a card ends up claiming a costume the arena cannot field.
##
## It never *awards* anything: `owned_tier()` is a function of the run count the
## player already has, so a tier is either earned or it is not. Every caller that
## can be reached from a URL passes the result through here.

const ROSTER_PATH := "res://resources/heroes/roster.json"

static var _roster: Dictionary = {}
static var _loaded: bool = false


## Read once. An unreadable or malformed roster yields an empty table rather than
## a partially-invented one: every accessor below then answers with the tier-1
## default, which is the only rank that needs no unlock.
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


## Godot imports `.json` as a resource in 4.x, which means the file can also be
## reached with `load()`; the plain read is tried first because it works in the
## editor and in an exported build alike.
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


## The row for [param tier], clamped into the ladder. A tier outside 1..count
## answers with the nearest end rather than with nothing: the caller prints a
## number, and a blank stat panel is worse than a clamped one.
static func row(tier: int) -> Dictionary:
	var table := rows()
	if table.is_empty():
		return {}
	var want := clampi(tier, 1, table.size())
	for entry in table:
		if int(entry.get("tier", 0)) == want:
			return entry
	return table[clampi(want - 1, 0, table.size() - 1)]


## The highest rank [param completed_runs] has earned. Tier 1 needs no runs.
static func owned_tier(completed_runs: int) -> int:
	var owned := 1
	for entry in rows():
		if completed_runs >= int(entry.get("runs_required", 0)):
			owned = maxi(owned, int(entry.get("tier", 1)))
	return owned


static func vitals(tier: int) -> float:
	return float(row(tier).get("vitals", 100))


## Percent of incoming damage the tier's plate absorbs, 0..100.
static func reduction(tier: int) -> float:
	return float(row(tier).get("reduction", 0))


static func hero(hero_id: StringName) -> Dictionary:
	for entry in roster().get("heroes", []):
		if StringName(str(entry.get("id", ""))) == hero_id:
			return entry
	return {}


## The rig GLB a tier wears, as a `res://` path, or "" when the hero has no
## model at that rank (an in-development slot).
static func model_path(hero_id: StringName, tier: int) -> String:
	return _engine_path(_tier_field(hero_id, tier, "model"))


static func rig_path(hero_id: StringName, tier: int) -> String:
	return _engine_path(_tier_field(hero_id, tier, "rig"))


static func art_path(hero_id: StringName, tier: int) -> String:
	return _tier_field(hero_id, tier, "art")


## The roster is also fetched by the HTML shell, so its authoring paths are
## repository-relative (`game/assets/...`). Engine consumers alone translate
## them to `res://`; the shell's art paths remain untouched.
static func _engine_path(path: String) -> String:
	if path.begins_with("game/"):
		return "res://" + path.trim_prefix("game/")
	return path


static func _tier_field(hero_id: StringName, tier: int, field: String) -> String:
	var entry := hero(hero_id)
	var table: Array = entry.get("tiers", [])
	if table.is_empty():
		return ""
	var want := clampi(tier, 1, table.size())
	for item in table:
		if int(item.get("tier", 0)) == want:
			var value: Variant = item.get(field, null)
			return str(value) if value is String else ""
	return ""


## A hero can be fielded when the roster says so *and* a tier-1 model exists.
## The status string alone is not enough: a slot marked field_ready with no rig
## is a card that would spawn nothing.
static func is_field_ready(hero_id: StringName) -> bool:
	var entry := hero(hero_id)
	if entry.is_empty():
		return false
	return str(entry.get("status", "")) == "field_ready" and not model_path(hero_id, 1).is_empty()
