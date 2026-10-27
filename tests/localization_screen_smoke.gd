extends SceneTree

## A screen that is already built changes its words.
##
## This is the mechanism every menu uses: `AegisText.apply()` stores the key on
## the control, the screen registers a watcher, and the watcher walks its own
## tree. A keyed `Label` and a real `AegisButton` are enough to exercise the same
## code the dashboard runs, without a 3D viewport; then the settings drawer is
## built for real, because the language row is the only control in the game whose
## own label is a language name and whose press has to rebuild the page it sits
## on.

var _failures: int = 0


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	await _test_screen_refresh()
	await _test_settings_row()
	_finish()


# --- 1. a built control ---------------------------------------------------- #


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
	var watcher := func(code: String) -> void: AegisText.refresh(host)
	AegisText.watch(watcher)

	AegisText.set_locale(AegisTextCatalog.EN, false)
	_expect(label.text == "PAUSED", "a keyed label reads English in English (%s)" % label.text)
	_expect(button.text == "RETRY", "a keyed button reads English in English (%s)" % button.text)
	_expect(
		button.tooltip_text == "SETTINGS", "and so does its hover text (%s)" % button.tooltip_text
	)

	AegisText.set_locale(AegisTextCatalog.ID, false)
	_expect(label.text == "JEDA", "the live label becomes JEDA after the switch (%s)" % label.text)
	_expect(
		button.text == "ULANGI",
		"the live button becomes ULANGI after the switch (%s)" % button.text
	)
	_expect(
		button.tooltip_text == "PENGATURAN",
		"the hover text follows too (%s)" % button.tooltip_text,
	)

	# Unwatch before the host goes away: the watcher is a lambda, so its own
	# Callable stays valid after the node it closes over is freed, and the next
	# language change would call into a dead instance.
	AegisText.unwatch(watcher)
	host.queue_free()
	AegisText.set_locale(AegisTextCatalog.EN, false)


# --- 2. the settings drawer's language row --------------------------------- #


func _test_settings_row() -> void:
	AegisText.set_locale(AegisTextCatalog.ID, false)
	var menu := AegisSettingsMenu.new()
	root.add_child(menu)
	await process_frame
	menu.call("_show_tab", 3)
	await process_frame
	var picker := menu.find_child("LanguageButton", true, false) as Button
	_expect(is_instance_valid(picker), "the ACCESS tab offers a language row")
	if not is_instance_valid(picker):
		menu.queue_free()
		await process_frame
		AegisText.set_locale(AegisTextCatalog.EN, false)
		return
	_expect(
		picker.text == "BAHASA INDONESIA",
		"the row names the active language in itself (%s)" % picker.text,
	)
	picker.pressed.emit()
	await process_frame
	_expect(AegisText.locale() == AegisTextCatalog.EN, "pressing it switches language")
	var again := menu.find_child("LanguageButton", true, false) as Button
	_expect(is_instance_valid(again), "the row survives the rebuild it caused")
	if is_instance_valid(again):
		_expect(
			again.text == "ENGLISH",
			"and it re-reads in the new language (%s)" % again.text,
		)
	menu.queue_free()
	await process_frame
	AegisText.set_locale(AegisTextCatalog.EN, false)


# --- harness ---------------------------------------------------------------- #


func _expect(condition: bool, label: String) -> void:
	if condition:
		print("PASS %s" % label)
		return
	_failures += 1
	printerr("FAIL %s" % label)


func _finish() -> void:
	if _failures == 0:
		print("LOCALIZATION SCREEN SMOKE OK")
	else:
		printerr("LOCALIZATION SCREEN SMOKE FAILED: %d" % _failures)
	quit(1 if _failures > 0 else 0)
