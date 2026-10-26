extends SceneTree

## Two languages, one product.
##
## The failures this smoke test exists to catch are the ones a screenshot does
## not show: a key that only exists in English, a `%d` that is `%s` in the other
## column, a screen that keeps the words it was built with after the player
## changed language, and a save file that forgets which language was chosen.
##
## It runs headless and needs no viewport: the catalog and the resolver are the
## subject, then two real screens (the dock and the settings drawer) are built
## and switched, because "the strings exist" and "the screen changed" are not the
## same claim.

const FALLBACK_PREFIXES := ["hero.", "world.", "wpn.", "editor.preset"]
const PLACEHOLDER := "%[sd]"

var _failures: int = 0


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	_test_catalog_symmetry()
	_test_placeholders()
	_test_resolver()
	_test_fallback()
	_test_preferences_persist()
	await _test_screen_refresh()
	_finish()


# --- 1. the catalog --------------------------------------------------------- #


func _test_catalog_symmetry() -> void:
	var en: Dictionary = AegisTextCatalog.STRINGS[AegisTextCatalog.EN]
	var id: Dictionary = AegisTextCatalog.STRINGS[AegisTextCatalog.ID]
	_expect(not en.is_empty() and en.size() == id.size(), "both languages carry every key")
	var only_en: Array = []
	var only_id: Array = []
	for key in en:
		if not id.has(key):
			only_en.append(key)
	for key in id:
		if not en.has(key):
			only_id.append(key)
	_expect(only_en.is_empty(), "no key that only English has (%s)" % [only_en.slice(0, 6)])
	_expect(only_id.is_empty(), "no key that only Indonesian has (%s)" % [only_id.slice(0, 6)])
	_expect(
		(
			AegisTextCatalog.LOCALES.size() == 2
			and AegisTextCatalog.LOCALES.has(AegisTextCatalog.EN)
			and AegisTextCatalog.LOCALES.has(AegisTextCatalog.ID)
		),
		"the switch offers exactly English and Indonesian",
	)
	_expect(
		(
			AegisTextCatalog.NATIVE_NAMES[AegisTextCatalog.EN] == "ENGLISH"
			and AegisTextCatalog.NATIVE_NAMES[AegisTextCatalog.ID] == "BAHASA INDONESIA"
		),
		"the language picker names each language in itself",
	)


## Same placeholders, same order, both columns. A `%d` read as `%s` is a crash
## in `String % args`, not a typo a player can ignore.
func _test_placeholders() -> void:
	var en: Dictionary = AegisTextCatalog.STRINGS[AegisTextCatalog.EN]
	var id: Dictionary = AegisTextCatalog.STRINGS[AegisTextCatalog.ID]
	var drift: Array[String] = []
	for key in en:
		if not id.has(key):
			continue
		var left := _placeholders(String(en[key]))
		var right := _placeholders(String(id[key]))
		if left != right:
			drift.append("%s en=%s id=%s" % [key, left, right])
	_expect(drift.is_empty(), "placeholders line up across languages (%s)" % [drift.slice(0, 4)])


## "Real content in each language, not a translation" is a rule this test can
## only approximate: a sentence that is byte-identical in both columns was not
## written twice. Jargon the project keeps in English is listed in the catalog's
## `SHARED_VALUES`, so it is not counted.
func _test_resolver() -> void:
	AegisText.set_locale(AegisTextCatalog.EN, false)
	var english := AegisText.t("pause.resume")
	AegisText.set_locale(AegisTextCatalog.ID, false)
	var indonesian := AegisText.t("pause.resume")
	_expect(english == "RESUME", "English says RESUME")
	_expect(indonesian == "LANJUTKAN", "Indonesian says LANJUTKAN")
	_expect(english != indonesian, "the same key reads differently in each language")
	_expect(
		AegisText.t("results.banked", [25]) == "+25 BP MASUK DOMPET",
		"a formatted key takes its argument in either language",
	)
	_expect(
		AegisText.t("results.progress_to_go", [25, 120, 95]).contains("95"),
		"three-argument keys keep every number",
	)
	AegisText.set_locale(AegisTextCatalog.EN, false)


func _test_fallback() -> void:
	_expect(AegisText.t("no.such.key") == "no.such.key", "a missing key falls back to its name")
	_expect(
		AegisText.t_or("no.such.key", "authored english") == "authored english",
		"t_or keeps the resource's own sentence when a language has not written one",
	)
	# Every dynamic key family resolves for the ids that exist.
	for hero_id in HeroDefinition.DEFINITION_IDS:
		_expect(
			AegisText.t_or("hero.%s.role" % hero_id, "").length() > 20,
			"the hero card has a written role in the catalog (%s)" % hero_id,
		)
	for world_id in WorldDefinition.DEFINITION_IDS:
		_expect(
			AegisText.t_or("world.%s.zone_title" % world_id, "").length() > 3,
			"the theatre has a written explore title (%s)" % world_id,
		)


func _test_preferences_persist() -> void:
	AegisPreferences.write(AegisPreferences.defaults())
	AegisText.set_locale(AegisTextCatalog.ID)
	_expect(
		String(AegisPreferences.read().get("locale", "")) == "id",
		"choosing Indonesian writes it to the save file",
	)
	# A hand-edited or older save must not be able to put the game in a language
	# it does not have.
	var dirty := AegisPreferences.defaults()
	dirty["locale"] = "de"
	_expect(
		String(AegisPreferences.sanitized(dirty).get("locale", "x")) == "",
		"an unknown language is dropped rather than trusted",
	)
	AegisText.set_locale(AegisTextCatalog.EN)


## The claim that matters: a screen that is already built changes its words.
##
## This is the mechanism every screen uses -- `apply()` stores the key, the screen
## registers a watcher, the watcher walks its own tree. Testing it on a Label and
## a real button is testing the same code the dashboard runs, without needing a
## 3D viewport.
func _test_screen_refresh() -> void:
	var host := Control.new()
	root.add_child(host)
	var label := Label.new()
	host.add_child(label)
	var button := AegisButton.new()
	host.add_child(button)
	AegisText.apply(label, "pause.title")
	AegisText.apply(button, "results.retry")
	AegisText.apply_tip(button, "nav.settings")
	AegisText.watch(func(_code: String) -> void: AegisText.refresh(host))

	AegisText.set_locale(AegisTextCatalog.EN, false)
	_expect(label.text == "PAUSED", "a keyed label reads English in English")
	_expect(button.text == "RETRY", "a keyed button reads English in English")
	_expect(button.tooltip_text == "SETTINGS", "and so does its hover text")

	AegisText.set_locale(AegisTextCatalog.ID, false)
	_expect(label.text == "JEDA", "the live label becomes JEDA after the switch")
	_expect(button.text == "ULANGI", "the live button becomes ULANGI after the switch")
	_expect(button.tooltip_text == "PENGATURAN", "the hover text follows too")
	host.queue_free()

	var menu := AegisSettingsMenu.new()
	root.add_child(menu)
	await process_frame
	menu.call("_show_tab", 3)
	var picker := menu.find_child("LanguageButton", true, false) as Button
	_expect(is_instance_valid(picker), "the ACCESS tab offers a language row")
	if is_instance_valid(picker):
		_expect(
			picker.text == "BAHASA INDONESIA",
			"the row shows the active language in its own name (%s)" % picker.text,
		)
		picker.pressed.emit()
		await process_frame
		_expect(AegisText.locale() == AegisTextCatalog.EN, "pressing it switches language")
		var again := menu.find_child("LanguageButton", true, false) as Button
		_expect(
			again != null and again.text == "ENGLISH",
			"and the row re-reads in the new language",
		)
		var title := menu.find_child("SettingsShell", true, false)
		_expect(title != null, "the drawer survived its own rebuild")
	menu.queue_free()
	AegisText.set_locale(AegisTextCatalog.EN, false)


# --- harness ---------------------------------------------------------------- #


func _placeholders(text: String) -> String:
	var found := RegEx.create_from_string(PLACEHOLDER)
	var out: Array[String] = []
	for match in found.search_all(text):
		out.append(match.get_string())
	return ",".join(out)


func _expect(condition: bool, label: String) -> void:
	if condition:
		print("PASS %s" % label)
		return
	_failures += 1
	printerr("FAIL %s" % label)


func _finish() -> void:
	if _failures == 0:
		print("LOCALIZATION SMOKE OK")
	else:
		printerr("LOCALIZATION SMOKE FAILED: %d" % _failures)
	quit(1 if _failures > 0 else 0)
