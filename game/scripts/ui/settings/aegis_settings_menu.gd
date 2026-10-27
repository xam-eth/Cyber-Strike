## One settings screen, used by the pause menu. Every change
## is applied and saved immediately; Done returns to the paused run, not a
## separate scene. The hosting HUD keeps it alive while SceneTree is paused.
class_name AegisSettingsMenu
extends AegisPanel

signal changed(values: Dictionary)
signal close_requested
## HOME leaves the world from the settings page too: a player who opened settings
## to fix the controls should not have to close two plates to reach the lobby.
signal home_requested
signal editor_requested

var preference_path: String = AegisPreferences.PATH
var values: Dictionary = {}
var _active_tab: int = 0
var _tabs: Array[Button] = []
var _shell: VBoxContainer
var _tab_row: HBoxContainer
var _page_scroll: ScrollContainer
var _page: VBoxContainer
var _footer: HBoxContainer
var _stretch: float = 1.0
var _font_scale: float = 1.0


func _ready() -> void:
	interactive = true
	# Both top corners cut, flat foot: the drawer the web shell and the in-engine
	# pause menu both use, so the two settings screens are the same object.
	bezel = true
	cut_top_left = AegisBezel.CUT_LG
	cut_top_right = AegisBezel.CUT_LG
	super._ready()
	mouse_filter = Control.MOUSE_FILTER_STOP
	values = AegisPreferences.read(preference_path)
	_build()
	_show_tab(0)
	AegisText.watch(_on_language)


func open() -> void:
	visible = true
	if not _tabs.is_empty():
		_tabs[_active_tab].grab_focus()


func close() -> void:
	visible = false
	close_requested.emit()


func set_mute_from_game(muted: bool) -> void:
	if bool(values.get("muted", false)) == muted:
		return
	values["muted"] = muted
	AegisPreferences.write(values, preference_path)
	if _active_tab == 0:
		_show_tab(0)


func apply_layout(stretch: float, font_scale: float = 1.0) -> void:
	_stretch = maxf(stretch, 0.001)
	_font_scale = font_scale
	var unit := 1.0 / _stretch
	add_theme_stylebox_override(
		"panel",
		AegisTheme.panel_style(
			Color(AegisTokens.PANEL, 0.98), AegisTokens.LINE_HI, 1, AegisTokens.RADIUS, 20.0 * unit
		)
	)
	for container in [_shell, _tab_row, _page, _footer]:
		if is_instance_valid(container):
			container.add_theme_constant_override("separation", roundi(10.0 * unit))
	var floor_size := maxi(roundi(AegisTokens.MIN_PHYSICAL_FONT_PX * unit), 11)
	for node in find_children("*", "Label", true, false):
		var label := node as Label
		var role := String(label.get_meta("aegis_role", "body"))
		AegisTheme.resize_label(
			label, role, maxi(roundi(AegisTheme.type_size(role) * _font_scale * unit), floor_size)
		)
	for node in find_children("*", "Button", true, false):
		var button := node as Button
		button.custom_minimum_size.y = 48.0 * unit
		AegisTheme.resize_button_font(button, "title", maxi(roundi(13.0 * unit), floor_size))
	for slider in find_children("*", "HSlider", true, false):
		AegisTheme.style_slider(slider as HSlider, _stretch)


func _build() -> void:
	_shell = VBoxContainer.new()
	_shell.name = "SettingsShell"
	_shell.size_flags_vertical = Control.SIZE_EXPAND_FILL
	add_child(_shell)
	_shell.add_child(_label_key("settings.eyebrow", "label", AegisTokens.ACCENT))
	_shell.add_child(_label_key("settings.title", "display_l", AegisTokens.INK))

	_tab_row = HBoxContainer.new()
	_tab_row.name = "SettingsTabs"
	_shell.add_child(_tab_row)
	# Tab ids are stable (`TabAUDIO` ...) so a smoke test can find one; the words
	# on them come from the catalog, because "ACCESS" is not what Indonesian
	# players read.
	for index in 4:
		var tab_key: String = [
			"settings.tab_audio", "settings.tab_controls", "settings.tab_hud", "settings.tab_access"
		][index]
		var tab := _button_key(
			tab_key, "Tab%s" % String(tab_key).to_upper().replace("SETTINGS_TAB_", ""), "ghost"
		)
		tab.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		tab.pressed.connect(_show_tab.bind(index))
		_tab_row.add_child(tab)
		_tabs.append(tab)

	_page_scroll = ScrollContainer.new()
	_page_scroll.name = "SettingsScroll"
	_page_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	_page_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_page_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_shell.add_child(_page_scroll)
	_page = VBoxContainer.new()
	_page.name = "SettingsPage"
	_page.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_page_scroll.add_child(_page)

	_footer = HBoxContainer.new()
	_footer.name = "SettingsFooter"
	_shell.add_child(_footer)
	var reset := _button_key("settings.reset", "ResetSettingsButton", "ghost")
	reset.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	reset.pressed.connect(_reset_defaults)
	_footer.add_child(reset)
	var home := _button_key("settings.home", "HomeSettingsButton", "ghost")
	home.icon = AegisTheme.icon("house")
	home.add_theme_constant_override("icon_max_width", 18)
	home.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	home.pressed.connect(_on_home_pressed)
	_footer.add_child(home)
	var done := _button_key("settings.done", "DoneSettingsButton", "primary")
	done.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	done.pressed.connect(close)
	_footer.add_child(done)


func _on_home_pressed() -> void:
	home_requested.emit()


func _show_tab(index: int) -> void:
	_active_tab = clampi(index, 0, 3)
	_page_scroll.scroll_vertical = 0
	for tab_index in _tabs.size():
		AegisTheme.set_button_variant(
			_tabs[tab_index], "primary" if tab_index == _active_tab else "ghost"
		)
	for child in _page.get_children():
		_page.remove_child(child)
		child.queue_free()
	match _active_tab:
		0:
			_page.add_child(_label_key("settings.audio_title", "heading_s", AegisTokens.INK))
			_add_toggle("muted", "settings.sound", true)
		1:
			_page.add_child(_label_key("settings.controls_title", "heading_s", AegisTokens.INK))
			_add_slider("sensitivity", "settings.look", 0.5, 1.5, 0.05)
			_add_toggle("left_handed", "settings.left_handed")
		2:
			_page.add_child(_label_key("settings.hud_title", "heading_s", AegisTokens.INK))
			_add_slider("hud_scale", "settings.hud_scale", 0.8, 1.2, 0.05)
			_add_slider("hud_opacity", "settings.panel_opacity", 0.65, 1.0, 0.05)
			var edit := _button_key("settings.edit_hud", "EditHudButton", "ghost")
			edit.pressed.connect(editor_requested.emit)
			_page.add_child(edit)
		3:
			_page.add_child(_label_key("settings.access_title", "heading_s", AegisTokens.INK))
			# Language sits first in ACCESS: it is the row a player who cannot
			# read the rest of this page is looking for.
			_add_language()
			_add_slider("text_scale", "settings.text_scale", 1.0, 1.3, 0.05)
			_add_toggle("colorblind", "settings.colorblind")
			_add_toggle("reduce_motion", "settings.reduce_motion")
			_add_toggle("reduce_flash", "settings.reduce_flash")
	apply_layout(_stretch, _font_scale)


func _add_slider(key: String, caption_key: String, low: float, high: float, step: float) -> void:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", roundi(10.0 / _stretch))
	_page.add_child(row)
	var caption_label := _label_key(caption_key, "body_s", AegisTokens.INK_2)
	caption_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(caption_label)
	var slider := HSlider.new()
	slider.name = "%sSlider" % key
	slider.min_value = low
	slider.max_value = high
	slider.step = step
	slider.value = float(values[key])
	slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	slider.custom_minimum_size = Vector2(150.0 / _stretch, 44.0 / _stretch)
	row.add_child(slider)
	var value_label := _label(_percent(slider.value), "mono_m", AegisTokens.ACCENT)
	value_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	value_label.custom_minimum_size.x = 48.0 / _stretch
	row.add_child(value_label)
	slider.value_changed.connect(_on_slider_changed.bind(key, value_label))


func _add_toggle(key: String, caption_key: String, inverse: bool = false) -> void:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", roundi(10.0 / _stretch))
	_page.add_child(row)
	var caption_label := _label_key(caption_key, "body_s", AegisTokens.INK_2)
	caption_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(caption_label)
	var toggle := _button("", "%sToggle" % key, "ghost")
	toggle.toggle_mode = true
	toggle.button_pressed = not bool(values[key]) if inverse else bool(values[key])
	_refresh_toggle(toggle)
	row.add_child(toggle)
	toggle.toggled.connect(_on_toggle_changed.bind(key, inverse, toggle))


func _on_slider_changed(value: float, key: String, label: Label) -> void:
	values[key] = value
	label.text = _percent(value)
	_persist()


func _on_toggle_changed(pressed: bool, key: String, inverse: bool, button: Button) -> void:
	values[key] = not pressed if inverse else pressed
	_refresh_toggle(button)
	_persist()


func _refresh_toggle(button: Button) -> void:
	AegisText.apply(button, "common.on" if button.button_pressed else "common.off")
	AegisTheme.set_button_variant(button, "primary" if button.button_pressed else "ghost")


func _persist() -> void:
	values = AegisPreferences.sanitized(values)
	var error := AegisPreferences.write(values, preference_path)
	if error != OK:
		push_warning("Could not save AEGIS settings: %d" % error)
	changed.emit(values.duplicate(true))


func _reset_defaults() -> void:
	values = AegisPreferences.defaults()
	_persist()
	_show_tab(_active_tab)


func _percent(value: float) -> String:
	return "%d%%" % roundi(value * 100.0)


## The language row: the current language in its own name ("BAHASA INDONESIA"),
## and a switch that cycles the list in `AegisTextCatalog.LOCALES`. It shows the
## *native* name on purpose -- a player looking for their language should not
## have to read the name of it in a language they do not have.
func _add_language() -> void:
	var row := HBoxContainer.new()
	row.name = "LanguageRow"
	row.add_theme_constant_override("separation", roundi(10.0 / _stretch))
	_page.add_child(row)
	var caption := _label_key("settings.language", "body_s", AegisTokens.INK_2)
	caption.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(caption)
	var picker := _button(AegisText.native_name(AegisText.locale()), "LanguageButton", "ghost")
	picker.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	picker.custom_minimum_size.x = 150.0 / _stretch
	picker.pressed.connect(_on_language_pressed.bind(picker))
	row.add_child(picker)


func _on_language_pressed(_picker: Button) -> void:
	# One call, one page rebuild: `set_locale` tells every watcher, including
	# this menu's `_on_language`. Setting the picker's own text here as well
	# would be a second write to a control that is about to be replaced.
	AegisText.set_locale(AegisText.next_locale())


## Rebuilds the tab and the footer in the new language. Called through
## `AegisText.watch()` and directly by the picker.
func _on_language(_code: String) -> void:
	AegisText.refresh(self)
	if is_instance_valid(_shell):
		var title: Label = _shell.get_child(1) as Label
		if title != null:
			AegisText.apply(title, "settings.title")
	# The tab and footer labels keep their keys; only the page is rebuilt,
	# because it is the part that owns sliders mid-drag.
	_show_tab(_active_tab)


func _label(text: String, role: String, color: Color) -> Label:
	var result := Label.new()
	result.text = text
	result.mouse_filter = Control.MOUSE_FILTER_IGNORE
	result.set_meta("aegis_role", role)
	result.set_meta("aegis_scale", 1.0)
	AegisTheme.style_label(result, role, color)
	return result


func _label_key(key: String, role: String, color: Color) -> Label:
	var result := _label("", role, color)
	AegisText.apply(result, key)
	return result


func _button_key(key: String, node_name: String, variant: String) -> AegisButton:
	var result := _button("", node_name, variant)
	AegisText.apply(result, key)
	return result


func _button(text: String, node_name: String, variant: String) -> AegisButton:
	var button := AegisButton.new()
	button.name = node_name
	button.text = text
	button.focus_mode = Control.FOCUS_ALL
	button.mouse_filter = Control.MOUSE_FILTER_STOP
	AegisTheme.set_button_variant(button, variant)
	return button
