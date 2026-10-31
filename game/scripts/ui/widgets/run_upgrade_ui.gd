class_name RunUpgradeUi
extends AegisPanel

## Modal card group for the one earned adaptation choice. Main decides when the
## offer exists and what a valid selection changes; this panel owns no gameplay
## or progression state. There is deliberately no dismiss-without-choosing path.
signal upgrade_selected(upgrade_id: StringName)

var _column: VBoxContainer
var _cards_row: HBoxContainer
var _subtitle: Label
var _cards: Array[RunUpgradeCard] = []
var _definitions: Array[RunUpgradeDefinition] = []
var _weapon_id: StringName = &"pulse_rifle"
var _selection_locked: bool = false


func _ready() -> void:
	interactive = true
	bezel = true
	cut_top_left = AegisBezel.CUT_LG
	cut_bottom_right = AegisBezel.CUT_LG
	accent_side = "top"
	accent_color = AegisTokens.ACCENT
	surface_alpha = AegisTokens.PANEL_ALPHA
	super._ready()
	mouse_filter = Control.MOUSE_FILTER_STOP

	_column = VBoxContainer.new()
	_column.add_theme_constant_override("separation", 10)
	add_child(_column)
	var eyebrow := _label_key("upgrade.eyebrow", "label", AegisTokens.ACCENT)
	_column.add_child(eyebrow)
	var title := _label_key("upgrade.title", "display_l", AegisTokens.INK)
	_column.add_child(title)
	_subtitle = _label_key("upgrade.subtitle", "body_s", AegisTokens.INK_2)
	_subtitle.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_column.add_child(_subtitle)
	_cards_row = HBoxContainer.new()
	_cards_row.name = "UpgradeCards"
	_cards_row.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_cards_row.add_theme_constant_override("separation", 10)
	_column.add_child(_cards_row)
	visible = false


func show_choices(definitions: Array[RunUpgradeDefinition], weapon_id: StringName) -> void:
	_definitions = definitions.duplicate()
	_weapon_id = weapon_id
	_selection_locked = false
	for card in _cards:
		_cards_row.remove_child(card)
		card.queue_free()
	_cards.clear()
	for definition in _definitions:
		var card := RunUpgradeCard.new()
		card.chosen.connect(_on_card_chosen)
		_cards_row.add_child(card)
		card.configure(definition, weapon_id)
		_cards.append(card)
	visible = true
	focus_first()


func refresh_language() -> void:
	AegisText.refresh(self)
	if not _definitions.is_empty():
		var selected := &""
		for card in _cards:
			if card.is_selected():
				selected = StringName(card.get_meta("upgrade_id", ""))
		show_choices(_definitions, _weapon_id)
		_selection_locked = not selected.is_empty()
		for card in _cards:
			card.disabled = _selection_locked or not card._definition.supports_weapon(_weapon_id)
			card.set_selected(StringName(card.get_meta("upgrade_id", "")) == selected)


func focus_first() -> void:
	for card in _cards:
		if not card.disabled:
			card.grab_focus()
			return


func unlock_choices() -> void:
	_selection_locked = false
	for card in _cards:
		card.configure(card._definition, _weapon_id)
	focus_first()


func layout_for(hud) -> void:
	var width := minf(hud._to_layout(720.0), hud.size.x * 0.94)
	var height := minf(hud._to_layout(340.0), hud.size.y * 0.92)
	custom_minimum_size = Vector2(width, height)
	UiLayout.place(hud, self, 0.5, 0.5, 0.5, 0.5, Rect2(-width * 0.5, -height * 0.5, width, height))
	_column.add_theme_constant_override("separation", roundi(hud._to_layout(8.0)))
	for card in _cards:
		card.custom_minimum_size = Vector2(0.0, hud._to_layout(150.0))
	add_theme_stylebox_override(
		"panel",
		AegisTheme.panel_style(
			Color(AegisTokens.PANEL, 0.98),
			Color(AegisTokens.LINE_HI, 0.9),
			1,
			AegisTokens.RADIUS,
			hud._to_layout(12.0)
		)
	)
	_report_layout(hud)


func _on_card_chosen(upgrade_id: StringName) -> void:
	if _selection_locked:
		return
	_selection_locked = true
	for card in _cards:
		var selected := StringName(card.get_meta("upgrade_id", "")) == upgrade_id
		card.set_selected(selected)
		card.disabled = true
	upgrade_selected.emit(upgrade_id)


func _report_layout(hud) -> void:
	if not visible or not OS.has_feature("web"):
		return
	if not bool(JavaScriptBridge.eval("new URLSearchParams(location.search).has('qa_recovery')")):
		return
	var lines := PackedStringArray()
	var panel_rect := get_global_rect()
	(
		lines
		. append(
			(
				"PANEL=%d,%d,%dx%d"
				% [
					roundi(panel_rect.position.x * hud._stretch),
					roundi(panel_rect.position.y * hud._stretch),
					roundi(panel_rect.size.x * hud._stretch),
					roundi(panel_rect.size.y * hud._stretch),
				]
			)
		)
	)
	for card in _cards:
		var rect := card.get_global_rect()
		(
			lines
			. append(
				(
					"%s=%d,%d,%dx%d"
					% [
						String(card.get_meta("upgrade_id", "unknown")).to_upper(),
						roundi(rect.position.x * hud._stretch),
						roundi(rect.position.y * hud._stretch),
						roundi(rect.size.x * hud._stretch),
						roundi(rect.size.y * hud._stretch),
					]
				)
			)
		)
	print("RunUpgrade QA: " + " | ".join(lines))


func _label_key(key: String, role: String, color: Color) -> Label:
	var label := Label.new()
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.set_meta("aegis_role", role)
	label.set_meta("aegis_scale", 1.0)
	AegisTheme.style_label(label, role, color)
	AegisText.apply(label, key)
	return label
