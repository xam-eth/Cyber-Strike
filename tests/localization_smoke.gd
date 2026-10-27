extends SceneTree

## The catalogue itself: two complete columns, aligned placeholders, and a
## resolver that answers in the language it was asked for.
##
## This is the half of the claim that needs no viewport -- and no screen. It is a
## separate test from `localization_screen_smoke.gd` because "the strings exist"
## and "a built screen re-reads them" fail for different reasons, and one file
## that checks both cannot say which one broke.

const PLACEHOLDER := "%[sd]"

var _failures: int = 0


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	_test_catalog_symmetry()
	_test_placeholders()
	_test_resolver()
	_test_fallback()
	_finish()


# --- 1. both columns -------------------------------------------------------- #


func _test_catalog_symmetry() -> void:
	var en: Dictionary = AegisTextCatalog.STRINGS[AegisTextCatalog.EN]
	var id: Dictionary = AegisTextCatalog.STRINGS[AegisTextCatalog.ID]
	_expect(not en.is_empty(), "the English column has strings")
	_expect(
		en.size() == id.size(), "both languages carry every key (%d / %d)" % [en.size(), id.size()]
	)
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


## Same placeholders in both columns. Order is deliberately *not* compared: the
## catalogue's contract is that a placeholder may move when the sentence needs
## it, and the numbers arrive positionally from the caller either way. Types are
## compared as a multiset, so `%d ... %s` and `%s ... %d` pass, and a `%d` that
## became a `%s` does not -- that one is a crash in `String % args`.
func _test_placeholders() -> void:
	var en: Dictionary = AegisTextCatalog.STRINGS[AegisTextCatalog.EN]
	var id: Dictionary = AegisTextCatalog.STRINGS[AegisTextCatalog.ID]
	var drift: Array[String] = []
	for key in en:
		if not id.has(key):
			continue
		var left := _placeholder_types(String(en[key]))
		var right := _placeholder_types(String(id[key]))
		left.sort()
		right.sort()
		if left != right:
			drift.append("%s en=%s id=%s" % [key, left, right])
	_expect(drift.is_empty(), "placeholders line up across languages (%s)" % [drift.slice(0, 4)])


# --- 2. the resolver -------------------------------------------------------- #


func _test_resolver() -> void:
	AegisText.set_locale(AegisTextCatalog.EN, false)
	_expect(AegisText.locale() == AegisTextCatalog.EN, "the resolver honours English")
	var english := AegisText.t("pause.resume")
	AegisText.set_locale(AegisTextCatalog.ID, false)
	_expect(AegisText.locale() == AegisTextCatalog.ID, "the resolver honours Indonesian")
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
	_expect(AegisText.next_locale() == AegisTextCatalog.EN, "the switch is a two-state cycle")
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


# --- harness ---------------------------------------------------------------- #


## `%s` / `%d` only. `%%` is a literal percent and is not a placeholder, and
## `%02d` is matched by its last two characters, which is enough to compare the
## two columns against each other.
func _placeholder_types(text: String) -> Array[String]:
	var found := RegEx.create_from_string(PLACEHOLDER)
	var out: Array[String] = []
	for match in found.search_all(text):
		out.append(match.get_string())
	return out


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
