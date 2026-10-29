class_name AetherfallProgressionState
extends Node
## Small authoritative progression ledger for this standalone vertical slice.
## It is intentionally local to Aetherfall: no global autoload or claimed
## compatibility with a removed game-wide inventory is introduced here.

signal reward_committed(resource: String, new_total: int, source_id: String)
signal cache_claimed(cache_id: String)
signal objective_activated(objective_id: String)
signal state_changed

const PROFILE_PATH := "user://aetherfall_stellar_horizon.cfg"
const SECTION := "stellar_horizon_vertical_slice"

var tech_data := 0
var _claimed_cache_ids: Dictionary = {}
var _activated_objective_ids: Dictionary = {}

func _ready() -> void:
	add_to_group("aetherfall_progression")
	_load_profile()

func _load_profile() -> void:
	var profile := ConfigFile.new()
	if profile.load(PROFILE_PATH) != OK:
		return
	tech_data = max(0, int(profile.get_value(SECTION, "tech_data", 0)))
	_claimed_cache_ids = _array_to_lookup(profile.get_value(SECTION, "claimed_cache_ids", []))
	_activated_objective_ids = _array_to_lookup(profile.get_value(SECTION, "activated_objective_ids", []))

func _save_profile() -> bool:
	var profile := ConfigFile.new()
	profile.set_value(SECTION, "tech_data", tech_data)
	profile.set_value(SECTION, "claimed_cache_ids", _claimed_cache_ids.keys())
	profile.set_value(SECTION, "activated_objective_ids", _activated_objective_ids.keys())
	return profile.save(PROFILE_PATH) == OK

func _array_to_lookup(value: Variant) -> Dictionary:
	var result: Dictionary = {}
	if value is Array:
		for item in value:
			result[str(item)] = true
	return result

func claim_tech_cache(cache_id: String, amount: int) -> Dictionary:
	if cache_id.is_empty() or amount <= 0:
		return {"ok": false, "code": "invalid_reward", "message": "Konfigurasi reward cache tidak valid."}
	if _claimed_cache_ids.has(cache_id):
		return {"ok": false, "code": "already_claimed", "message": "Cache ini sudah diklaim."}
	_claimed_cache_ids[cache_id] = true
	tech_data += amount
	if not _save_profile():
		tech_data -= amount
		_claimed_cache_ids.erase(cache_id)
		return {"ok": false, "code": "save_failed", "message": "Reward dibatalkan: profil lokal tidak dapat disimpan."}
	cache_claimed.emit(cache_id)
	reward_committed.emit("tech_data", tech_data, cache_id)
	state_changed.emit()
	return {"ok": true, "code": "committed", "resource": "tech_data", "amount": amount, "total": tech_data}

func activate_objective(objective_id: String, required_tech_data: int) -> Dictionary:
	if objective_id.is_empty() or required_tech_data < 0:
		return {"ok": false, "code": "invalid_objective", "message": "Konfigurasi relai tidak valid."}
	if _activated_objective_ids.has(objective_id):
		return {"ok": false, "code": "already_active", "message": "Relai sudah aktif."}
	if tech_data < required_tech_data:
		return {"ok": false, "code": "requirement_missing", "message": "Butuh %d data teknologi sebelum relai dapat diaktifkan." % required_tech_data}
	_activated_objective_ids[objective_id] = true
	if not _save_profile():
		_activated_objective_ids.erase(objective_id)
		return {"ok": false, "code": "save_failed", "message": "Aktivasi dibatalkan: profil lokal tidak dapat disimpan."}
	objective_activated.emit(objective_id)
	state_changed.emit()
	return {"ok": true, "code": "activated", "objective_id": objective_id}

func has_claimed_cache(cache_id: String) -> bool:
	return _claimed_cache_ids.has(cache_id)

func is_objective_active(objective_id: String) -> bool:
	return _activated_objective_ids.has(objective_id)

func reset_for_test() -> void:
	## Test-only reset is in-memory, so ordinary smoke checks do not alter data.
	tech_data = 0
	_claimed_cache_ids.clear()
	_activated_objective_ids.clear()
	state_changed.emit()

func clear_persisted_profile_for_test() -> void:
	## Called only by tests/interactive_slice.gd before and after a persistence test.
	DirAccess.remove_absolute(ProjectSettings.globalize_path(PROFILE_PATH))
	reset_for_test()
