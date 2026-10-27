## The only owner of persistent Battle Points and weapon ownership. A run's
## BP is provisional in RunStats; Main banks it *once* at Results, then retries
## can reset the run without wiping the player's wallet. The weapon controller
## never writes saves or subtracts currency itself.
class_name ProgressionService
extends Node

signal profile_changed

const PROFILE_PATH := "user://progression.cfg"
const PROFILE_SECTION := "profile"
const COSTS := {"pulse_rifle": 0, "nova_launcher": 120, "arc_shooter": 250}
const MAX_VALUE := 99999999

## The only content that actually exists. The selection screens show these as
## pickable and everything else as LOCKED, so the front end cannot offer a hero,
## weapon or world the game cannot load.
##
## These lists are read out of the definition registries rather than typed here
## as well. They used to be: an id added to one and not the other left
## `select_weapon()` accepting an id no definition exists for, or a card
## printing a name the service had never heard of. One direction of travel now:
## add the rig / WeaponDefinition / scene, add the `.tres`, and every screen and
## this service pick it up. `data_source_smoke.gd` asserts the registries and
## these constants still describe the same content.
const HERO_IDS: Array[StringName] = HeroDefinition.DEFINITION_IDS
const WEAPON_IDS: Array[StringName] = WeaponDefinition.DEFINITION_IDS
const WORLD_IDS: Array[StringName] = WorldDefinition.DEFINITION_IDS
const DEFAULT_HERO_ID := HeroDefinition.DEFAULT_HERO_ID
const DEFAULT_WEAPON_ID := WeaponDefinition.DEFAULT_WEAPON_ID
const DEFAULT_WORLD_ID := WorldDefinition.DEFAULT_WORLD_ID

## Empty for isolated smoke fixtures; the shipped scene uses PROFILE_PATH.
@export var profile_path: String = PROFILE_PATH

var balance: int = 0
var best_score: int = 0
var completed_runs: int = 0
var unlocked_ids: Dictionary = {"pulse_rifle": true}
## Front-end state that has to outlive the session: whether the opening
## cinematic has been played, and the loadout the player last launched with.
var intro_seen: bool = false
var selected_hero_id: StringName = DEFAULT_HERO_ID
## The rank of the selected operative, 1..HeroTier.tier_count(). Never a value
## the player has not earned: `select_tier()` and the URL intake both clamp it
## to `owned_tier()`, and `load_profile()` re-clamps on every boot because runs
## are not the only way a save can change.
var selected_tier: int = 1
var selected_weapon_id: StringName = DEFAULT_WEAPON_ID
var selected_world_id: StringName = DEFAULT_WORLD_ID


func _ready() -> void:
	# One name for "the profile", so a lookup from inside a scene does not have to
	# guess where in the tree it was parented (see ProgressionLookup).
	add_to_group(ProgressionLookup.GROUP)
	load_profile()


func load_profile() -> void:
	balance = 0
	best_score = 0
	completed_runs = 0
	unlocked_ids = {"pulse_rifle": true}
	intro_seen = false
	selected_hero_id = DEFAULT_HERO_ID
	selected_tier = 1
	selected_weapon_id = DEFAULT_WEAPON_ID
	selected_world_id = DEFAULT_WORLD_ID
	if profile_path.is_empty():
		profile_changed.emit()
		return
	var config := ConfigFile.new()
	if config.load(profile_path) == OK:
		balance = _bounded_int(config.get_value(PROFILE_SECTION, "balance", 0))
		best_score = _bounded_int(config.get_value(PROFILE_SECTION, "best_score", 0))
		completed_runs = _bounded_int(config.get_value(PROFILE_SECTION, "completed_runs", 0))
		var saved_ids = config.get_value(PROFILE_SECTION, "unlocked_ids", [])
		if saved_ids is Array or saved_ids is PackedStringArray:
			for id in saved_ids:
				var key := str(id)
				if COSTS.has(key):
					unlocked_ids[key] = true
		intro_seen = bool(config.get_value(PROFILE_SECTION, "intro_seen", false))
		var saved_hero := StringName(str(config.get_value(PROFILE_SECTION, "selected_hero", "")))
		# SABLE replaces the former EXO presentation, not the player's profile.
		# Migrate the one retired id explicitly; all other unknown ids still use
		# the validated default rather than reaching a content loader.
		if saved_hero == &"exo_operative":
			saved_hero = DEFAULT_HERO_ID
		selected_hero_id = _known_id(saved_hero, HERO_IDS, DEFAULT_HERO_ID)
		selected_tier = _bounded_int(config.get_value(PROFILE_SECTION, "selected_tier", 1))
		selected_world_id = _known_id(
			config.get_value(PROFILE_SECTION, "selected_world", ""), WORLD_IDS, DEFAULT_WORLD_ID
		)
		selected_weapon_id = _known_id(
			config.get_value(PROFILE_SECTION, "selected_weapon", ""), WEAPON_IDS, DEFAULT_WEAPON_ID
		)
	# A weapon can be selected and then lost to a reset save, so re-gate it.
	if not is_unlocked(selected_weapon_id):
		selected_weapon_id = DEFAULT_WEAPON_ID
	# Same for a rank: a save that remembers tier 4 means nothing if the runs
	# that opened it are gone.
	selected_tier = clampi(selected_tier, 1, owned_tier())
	_apply_web_loadout()
	_mirror_runs_to_shell()
	profile_changed.emit()


## The web shell owns HOME, so the loadout the player picked there arrives as a
## URL parameter rather than as a call into this service. It is read here, after
## the saved profile and before anything is emitted, so one code path decides
## what the run deploys with.
##
## It cannot unlock anything: an unknown or still-locked id is refused, leaving
## the already validated saved selection in place. A hand-edited URL therefore
## cannot field a weapon the player has not bought.
func _apply_web_loadout() -> void:
	if not OS.has_feature("web"):
		return
	var requested: Variant = JavaScriptBridge.eval(
		"new URLSearchParams(location.search).get('weapon') || ''"
	)
	var weapon_id := _known_id(requested, WEAPON_IDS, &"")
	if weapon_id != &"" and is_unlocked(weapon_id):
		selected_weapon_id = weapon_id
	# The operative page sends who and which rank. Both are checked against the
	# content that exists and against the runs the player has finished, so a
	# hand-edited `?hero=kestrel&tier=5` fields SABLE at the highest rank this
	# player owns instead of a costume nobody has made.
	var requested_hero := _known_id(
		JavaScriptBridge.eval("new URLSearchParams(location.search).get('hero') || ''"),
		HERO_IDS,
		&""
	)
	if requested_hero != &"" and HeroTier.is_field_ready(requested_hero):
		selected_hero_id = requested_hero
	var has_requested_tier := bool(
		JavaScriptBridge.eval("new URLSearchParams(location.search).has('tier')")
	)
	if has_requested_tier:
		var requested_tier := _bounded_int(
			JavaScriptBridge.eval("new URLSearchParams(location.search).get('tier') || '1'")
		)
		selected_tier = clampi(requested_tier, 1, owned_tier())


## An edited user:// file must not be able to invent a hero, weapon or world.
## Unknown ids fall back to the default rather than reaching the scene loader.
func _known_id(raw: Variant, known: Array[StringName], fallback: StringName) -> StringName:
	var candidate := StringName(str(raw))
	return candidate if known.has(candidate) else fallback


func is_unlocked(weapon_id: StringName) -> bool:
	return unlocked_ids.has(String(weapon_id))


# --- the operative ladder ---------------------------------------------------


## The highest rank this profile has earned. Tier 1 at zero runs; the rest come
## from the roster's own run prices, not from a second table kept here.
func owned_tier() -> int:
	return HeroTier.owned_tier(completed_runs)


## Ranks the player may field right now. `clampi` because every caller -- a URL,
## a saved file, a card -- can be wrong, and the run this launches cannot.
func fieldable_tier() -> int:
	return clampi(selected_tier, 1, owned_tier())


## Moves the selected rank. Returns false for anything the player has not
## earned, so a screen can say why instead of silently ignoring the press.
func select_tier(tier: int) -> bool:
	var wanted := clampi(tier, 1, HeroTier.tier_count())
	if wanted > owned_tier() or wanted == selected_tier:
		return false
	selected_tier = wanted
	_save_profile()
	profile_changed.emit()
	return true


func tier_model_path() -> String:
	return HeroTier.model_path(selected_hero_id, fieldable_tier())


func tier_rig_path() -> String:
	return HeroTier.rig_path(selected_hero_id, fieldable_tier())


## The rank's health pool and plate, as the arena applies them.
func tier_vitals() -> float:
	return HeroTier.vitals(fieldable_tier())


func tier_damage_reduction() -> float:
	return HeroTier.reduction(fieldable_tier())


func unlock_cost(weapon_id: StringName) -> int:
	return int(COSTS.get(String(weapon_id), -1))


## An invalid/repeated purchase has no side effects, including on disk.
func unlock_weapon(weapon_id: StringName) -> bool:
	var cost := unlock_cost(weapon_id)
	if cost <= 0 or is_unlocked(weapon_id) or balance < cost:
		return false
	balance -= cost
	unlocked_ids[String(weapon_id)] = true
	_save_profile()
	profile_changed.emit()
	return true


## Called once when the CHAPTER 01 card is cleared. Persisted immediately so a
## crash on the first run does not show it again forever.
##
## The name predates the correction: the studio ident moved to the front of the
## journey and is not gated on anything, so what this flag actually records is
## the first-launch chapter card. Renaming the persisted key would silently
## replay that card once for every existing profile, so the key stays.
func mark_intro_seen() -> void:
	if intro_seen:
		return
	intro_seen = true
	_save_profile()
	profile_changed.emit()


func select_hero(hero_id: StringName) -> bool:
	if not HERO_IDS.has(hero_id) or hero_id == selected_hero_id:
		return false
	selected_hero_id = hero_id
	_save_profile()
	profile_changed.emit()
	return true


func select_world(world_id: StringName) -> bool:
	if not WORLD_IDS.has(world_id) or world_id == selected_world_id:
		return false
	selected_world_id = world_id
	_save_profile()
	profile_changed.emit()
	return true


## Equipping is separate from owning: the armory buys, this selects within what
## the profile already unlocks. Selecting a locked weapon is refused rather than
## silently fixed up later, so the UI cannot show an equipped weapon it cannot
## fire.
func select_weapon(weapon_id: StringName) -> bool:
	if not WEAPON_IDS.has(weapon_id) or not is_unlocked(weapon_id):
		return false
	var changed := weapon_id != selected_weapon_id
	selected_weapon_id = weapon_id
	if changed:
		_save_profile()
		profile_changed.emit()
	return true


## Only Main calls this on DEFENSE -> RESULTS. Neither returning to Explore nor
## pressing RETRY awards twice; a completed wave's 100 BP is already in bp.
func bank_run(run_score: int, earned_bp: int) -> void:
	balance = mini(balance + _bounded_int(earned_bp), MAX_VALUE)
	best_score = maxi(best_score, _bounded_int(run_score))
	completed_runs = mini(completed_runs + 1, MAX_VALUE)
	_save_profile()
	profile_changed.emit()


## The web shell's operative page lives outside the canvas, so it cannot read
## this service -- and the tier ladder it draws is exactly this number of
## finished runs. Rather than have two saved profiles, the run count is mirrored
## one way into `localStorage['aegis.runs']`; the shell only ever reads it, and
## every decision it feeds (which tier card is open) is re-clamped here when the
## arena launches, so a hand-edited localStorage cannot field an unearned rank.
func _mirror_runs_to_shell() -> void:
	if not OS.has_feature("web"):
		return
	JavaScriptBridge.eval("try{localStorage.setItem('aegis.runs','%d')}catch(e){}" % completed_runs)


func _bounded_int(value: Variant) -> int:
	if value is int or value is float or value is String:
		return clampi(int(value), 0, MAX_VALUE)
	return 0


func _save_profile() -> void:
	if profile_path.is_empty():
		return
	var config := ConfigFile.new()
	config.set_value(PROFILE_SECTION, "balance", balance)
	config.set_value(PROFILE_SECTION, "best_score", best_score)
	config.set_value(PROFILE_SECTION, "completed_runs", completed_runs)
	config.set_value(PROFILE_SECTION, "unlocked_ids", unlocked_ids.keys())
	config.set_value(PROFILE_SECTION, "intro_seen", intro_seen)
	config.set_value(PROFILE_SECTION, "selected_hero", String(selected_hero_id))
	config.set_value(PROFILE_SECTION, "selected_tier", fieldable_tier())
	config.set_value(PROFILE_SECTION, "selected_weapon", String(selected_weapon_id))
	config.set_value(PROFILE_SECTION, "selected_world", String(selected_world_id))
	var result := config.save(profile_path)
	if result != OK:
		push_warning("Could not save Battle Points and unlocks: %s" % error_string(result))
	_mirror_runs_to_shell()
