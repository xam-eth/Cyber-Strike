extends SceneTree

## The chosen language is part of the save file, and an older or hand-edited save
## cannot put the game in a language it does not ship.
##
## Separate from `localization_smoke.gd` because it touches `user://`: a store
## that writes nothing and a store that writes the wrong key look identical from
## inside a screen.

const PROFILE_PATH := "user://localization_preferences_smoke.cfg"

var _failures: int = 0


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	AegisPreferences.write(AegisPreferences.defaults(), PROFILE_PATH)
	AegisText.set_locale(AegisTextCatalog.ID)
	_expect(
		String(AegisPreferences.read(PROFILE_PATH).get("locale", "")) == "id",
		"choosing Indonesian writes it to the save file",
	)
	AegisText.set_locale(AegisTextCatalog.EN)
	_expect(
		String(AegisPreferences.read(PROFILE_PATH).get("locale", "")) == "en",
		"and choosing English writes that instead",
	)

	var dirty := AegisPreferences.defaults()
	dirty["locale"] = "de"
	_expect(
		String(AegisPreferences.sanitized(dirty).get("locale", "x")) == "",
		"an unknown language is dropped rather than trusted",
	)
	var fresh := AegisPreferences.sanitized(dirty)
	_expect(
		AegisText.t_or("pause.resume", "missing").length() > 0,
		"a dropped language still resolves through the fallback",
	)
	_expect(String(fresh["locale"]) == "", "the sanitized value is an empty locale, not 'de'")

	DirAccess.remove_absolute(ProjectSettings.globalize_path(PROFILE_PATH))
	_finish()


func _expect(condition: bool, label: String) -> void:
	if condition:
		print("PASS %s" % label)
		return
	_failures += 1
	printerr("FAIL %s" % label)


func _finish() -> void:
	if _failures == 0:
		print("LOCALIZATION PREFERENCES SMOKE OK")
	else:
		printerr("LOCALIZATION PREFERENCES SMOKE FAILED: %d" % _failures)
	quit(1 if _failures > 0 else 0)
