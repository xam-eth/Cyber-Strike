## The active language, and the one way to change it.
##
## Deliberately not an autoload: this is static state plus a list of interested
## callables, so a headless smoke test can switch language and read the result
## without a scene tree having booted a singleton first. Every player-facing
## string comes from `AegisTextCatalog`, is fetched through `t()`, and is written
## onto a control through `apply()` so that a language change can rewrite the
## screen in place instead of rebuilding it.
##
## The default is chosen from the device, then remembered:
##   1. an explicit choice in `AegisPreferences` ("locale"),
##   2. `?lang=` in the URL (the web shell hands its own choice over),
##   3. the OS/browser language — Indonesian for anything `id*`,
##   4. English.
class_name AegisText
extends RefCounted

const PREF_KEY := "locale"
const EN := AegisTextCatalog.EN
const ID := AegisTextCatalog.ID

static var _locale := ""
static var _watchers: Array[Callable] = []
static var _registered := false
## Keeps the JS callback object alive: an unreferenced one is freed and the page
## keeps calling into a dead callback.
static var _bridge_handle: JavaScriptObject = null


## Resolves the language the first time it is asked for. Cheap after that.
static func locale() -> String:
	if _locale.is_empty():
		_locale = _resolve_initial_locale()
		_register_translations()
	return _locale


## The string for `key` in the active language. `args` is passed to `%` when the
## line has placeholders. A missing key falls back to English, then to the key
## itself, so a hole is visible in a capture instead of blank.
static func t(key: String, args: Array = []) -> String:
	var text := _lookup(key, locale())
	if text.is_empty():
		text = _lookup(key, EN)
	if text.is_empty():
		push_warning("AegisText: no string for '%s'" % key)
		return key
	return text % args if not args.is_empty() else text


## `t()` when the catalog has the key, `fallback` when it does not.
##
## This is what lets a data resource keep its authored English while a
## translation exists: the *resource* stays the source of truth for the id and
## the name, and the catalog can override the prose by id without a `.tres`
## re-author for every language.
static func t_or(key: String, fallback: String) -> String:
	var text := _lookup(key, locale())
	if text.is_empty():
		text = _lookup(key, EN)
	return fallback if text.is_empty() else text


## Writes the string onto a Label / Button and remembers the key, so
## `refresh()` can rewrite it when the language changes.
static func apply(control: Control, key: String, args: Array = []) -> void:
	if not is_instance_valid(control):
		return
	control.set_meta("i18n_key", key)
	control.set_meta("i18n_args", args)
	_write_text(control, t(key, args))


## Same, for the hover label.
static func apply_tip(control: Control, key: String, args: Array = []) -> void:
	if not is_instance_valid(control):
		return
	control.set_meta("i18n_tip", key)
	control.set_meta("i18n_tip_args", args)
	control.tooltip_text = t(key, args)


## Rewrites every keyed control under `root`. One tree walk per language change
## is cheaper than making every screen remember which labels it owns.
static func refresh(root: Node) -> void:
	if not is_instance_valid(root):
		return
	if root is Control and root.has_meta("i18n_key"):
		_write_text(root, t(String(root.get_meta("i18n_key")), root.get_meta("i18n_args")))
	if root is Control and root.has_meta("i18n_tip"):
		root.tooltip_text = t(String(root.get_meta("i18n_tip")), root.get_meta("i18n_tip_args"))
	for child in root.get_children():
		refresh(child)


## Switches language, persists it, and tells every watcher. No-op when the code
## is the one already active, so a settings row that re-applies defaults does not
## fire a redraw of the whole HUD for nothing.
static func set_locale(code: String, persist: bool = true) -> void:
	var wanted := _sanitize(code)
	if wanted == locale():
		return
	_locale = wanted
	if persist:
		var values := AegisPreferences.read()
		values[PREF_KEY] = wanted
		AegisPreferences.write(values)
		_mirror_to_shell(wanted)
	TranslationServer.set_locale(wanted)
	var live: Array[Callable] = []
	for watcher in _watchers:
		if watcher.is_valid():
			live.append(watcher)
			watcher.call(wanted)
	_watchers = live


## A screen registers here instead of connecting to a signal that static state
## cannot offer. Dead callables are dropped on the next change.
static func watch(callable: Callable) -> void:
	if callable.is_valid() and not _watchers.has(callable):
		_watchers.append(callable)


static func unwatch(callable: Callable) -> void:
	_watchers.erase(callable)


static func native_name(code: String) -> String:
	return String(AegisTextCatalog.NATIVE_NAMES.get(code, code))


## The next language in `LOCALES`, for a two-state switch with one button.
static func next_locale() -> String:
	var order := AegisTextCatalog.LOCALES
	var index := order.find(locale())
	return order[(index + 1) % order.size()]


static func available() -> Array[String]:
	return AegisTextCatalog.LOCALES.duplicate()


# --- internals -------------------------------------------------------------- #


## `Control` itself has no `text`, so the write has to go through the concrete
## class. Kept in one place: three call sites in this file and one rule about
## which controls carry a caption.
static func _write_text(control: Control, text: String) -> void:
	if control is Label:
		(control as Label).text = text
	elif control is Button:
		(control as Button).text = text
	elif control is RichTextLabel:
		(control as RichTextLabel).text = text


## A choice made inside the game has to survive the trip back to the lobby.
##
## HOME reloads the page (`ui/shell.js` -> `home()`), and the page resolves its
## language from `localStorage`. Without this write, switching to Indonesian in
## the pause menu and then pressing HOME puts the lobby back in English while the
## arena stays Indonesian -- the exact inconsistency this round is fixing.
static func _mirror_to_shell(code: String) -> void:
	if not OS.has_feature("web"):
		return
	JavaScriptBridge.eval("try{localStorage.setItem('aegis.locale','%s')}catch(e){}" % code)


static func _lookup(key: String, code: String) -> String:
	var table: Dictionary = AegisTextCatalog.STRINGS.get(code, {})
	return String(table.get(key, ""))


static func _sanitize(code: String) -> String:
	var cleaned := code.strip_edges().to_lower()
	if cleaned.begins_with("id"):
		return ID
	if cleaned.begins_with("en"):
		return EN
	return EN


static func _resolve_initial_locale() -> String:
	var stored := String(AegisPreferences.read().get(PREF_KEY, ""))
	if not stored.is_empty():
		return _sanitize(stored)
	var from_url := _url_language()
	if not from_url.is_empty():
		return _sanitize(from_url)
	return _sanitize(OS.get_locale())


## The web shell keeps its own language choice; it passes it in the URL so the
## canvas and the page never disagree about what language the player is reading.
static func _url_language() -> String:
	if not OS.has_feature("web"):
		return ""
	var value: Variant = JavaScriptBridge.eval(
		"new URLSearchParams(location.search).get('lang') || ''"
	)
	return String(value)


## The running game, reachable from the page.
##
## `ui/i18n.js` switches the shell's own text and then calls this, so a player who
## changes language with the world already loaded does not have to reload and
## lose the run.
static func _expose_to_shell() -> void:
	if not OS.has_feature("web") or _bridge_handle != null:
		return
	var callback := JavaScriptBridge.create_callback(_on_shell_locale)
	_bridge_handle = callback
	JavaScriptBridge.get_interface("window").set("aegisSetLocale", callback)


static func _on_shell_locale(args: Array) -> void:
	if args.is_empty():
		return
	var code := String(args[0])
	if code.is_empty():
		return
	# `persist = false`: the shell already stored the choice in localStorage, and
	# the engine writes `AegisPreferences` — two stores, one decision.
	set_locale(code, false)


## Godot's own `tr()` and any engine-drawn text follow the same tables.
static func _register_translations() -> void:
	if _registered:
		return
	_registered = true
	_expose_to_shell()
	for code in AegisTextCatalog.STRINGS:
		var table: Dictionary = AegisTextCatalog.STRINGS[code]
		var translation := Translation.new()
		translation.locale = code
		for key in table:
			translation.add_message(key, table[key])
		TranslationServer.add_translation(translation)
	TranslationServer.set_locale(locale())
