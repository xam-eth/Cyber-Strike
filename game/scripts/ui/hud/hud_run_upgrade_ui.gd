## HUD surface for Temporary In-Run Tactical Upgrades (`CHOOSE -> EVOLVE`).
##
## Consists of:
##   1. Top-right `UpgradeStatusCard` (passive charge progress + active run-mod
##      tags during combat) and `UpgradeReadyButton` (`EVOLVE [V]` action when a
##      draft is available, positioned clear of every thumb combat control).
##   2. Centered `RunUpgradePanel` modal displaying three `AegisUpgradeCard`
##      choices while combat is safely suspended via `HudOverlayStack`.
class_name HudRunUpgradeUi
extends AegisPanel

signal choice_selected(index: int)
signal close_requested

var _eyebrow_label: Label
var _title_label: Label
var _hint_label: Label
var _active_label: Label
var _cards: Array[AegisUpgradeCard] = []
var _defer_button: AegisButton
var _column: VBoxContainer


func _ready() -> void:
	interactive = true
	bezel = true
	accent_side = "top"
	accent_color = AegisTokens.INFO
	super._ready()
	mouse_filter = Control.MOUSE_FILTER_STOP
	visible = false

	_column = VBoxContainer.new()
	_column.add_theme_constant_override("separation", 6)
	add_child(_column)

	var header := HBoxContainer.new()
	header.add_theme_constant_override("separation", 8)
	_column.add_child(header)

	var titles := VBoxContainer.new()
	titles.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	titles.add_theme_constant_override("separation", 2)
	header.add_child(titles)

	_eyebrow_label = _make_key("hud.upg_eyebrow", "label", AegisTokens.INFO)
	titles.add_child(_eyebrow_label)

	_title_label = _make_key("hud.upg_title", "display_m", AegisTokens.INK)
	titles.add_child(_title_label)

	_defer_button = AegisButton.new()
	_defer_button.name = "DeferUpgradeButton"
	AegisText.apply(_defer_button, "hud.upg_later")
	_defer_button.focus_mode = Control.FOCUS_ALL
	_defer_button.mouse_filter = Control.MOUSE_FILTER_STOP
	AegisTheme.set_button_variant(_defer_button, "ghost")
	_defer_button.pressed.connect(func() -> void: close_requested.emit())
	header.add_child(_defer_button)

	_hint_label = _make_key("hud.upg_hint", "caption", AegisTokens.INK_2)
	_column.add_child(_hint_label)

	var row := HBoxContainer.new()
	row.name = "UpgradeChoicesRow"
	row.size_flags_vertical = Control.SIZE_EXPAND_FILL
	row.add_theme_constant_override("separation", 8)
	_column.add_child(row)

	for idx in range(RunUpgradeManager.CHOICE_COUNT):
		var card := AegisUpgradeCard.new()
		card.name = "UpgradeChoiceCard%d" % idx
		card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		card.size_flags_vertical = Control.SIZE_EXPAND_FILL
		card.pressed.connect(_on_card_pressed.bind(idx))
		row.add_child(card)
		_cards.append(card)

	_active_label = _make_text("", "label_s", AegisTokens.ACCENT)
	_column.add_child(_active_label)


func present_choices(choices: Array[RunUpgradeDefinition], manager: RunUpgradeManager) -> void:
	for idx in range(_cards.size()):
		var def: RunUpgradeDefinition = choices[idx] if idx < choices.size() else null
		var stacks := manager.stack_count(def.upgrade_id) if def != null else 0
		_cards[idx].bind_upgrade(def, stacks, idx)
	var summary := manager.active_tags_summary()
	if summary.is_empty():
		_active_label.text = AegisText.t("hud.upg_active_none")
	else:
		_active_label.text = AegisText.t("hud.upg_active_list", [summary])
	visible = true
	if not _cards.is_empty() and _cards[0].visible:
		_cards[0].grab_focus()


func _unhandled_input(event: InputEvent) -> void:
	if not visible:
		return
	var key_event := event as InputEventKey
	if key_event == null or not key_event.pressed or key_event.echo:
		return
	var slot := -1
	if key_event.keycode == KEY_1 or key_event.physical_keycode == KEY_1:
		slot = 0
	elif key_event.keycode == KEY_2 or key_event.physical_keycode == KEY_2:
		slot = 1
	elif key_event.keycode == KEY_3 or key_event.physical_keycode == KEY_3:
		slot = 2
	if slot >= 0 and slot < _cards.size() and _cards[slot].visible and not _cards[slot].disabled:
		get_viewport().set_input_as_handled()
		choice_selected.emit(slot)


func layout_for(hud) -> void:
	var width: float = minf(hud._to_layout(720.0), hud.size.x * 0.94)
	var height: float = minf(hud._to_layout(310.0), hud.size.y * 0.90)
	custom_minimum_size = Vector2(width, height)
	UiLayout.place(hud, self, 0.5, 0.5, 0.5, 0.5, Rect2(-width * 0.5, -height * 0.5, width, height))
	_column.add_theme_constant_override("separation", maxi(roundi(hud._to_layout(6.0)), 3))
	_defer_button.custom_minimum_size = Vector2(hud._to_layout(96.0), hud._to_layout(40.0))
	for card in _cards:
		card.custom_minimum_size = Vector2(hud._to_layout(160.0), hud._to_layout(136.0))
		card.apply_layout_scale(hud._to_layout)
	add_theme_stylebox_override(
		"panel",
		AegisTheme.panel_style(
			Color(AegisTokens.PANEL, 0.98),
			Color(AegisTokens.INFO, 0.92),
			1,
			AegisTokens.RADIUS,
			hud._to_layout(14.0)
		)
	)


func _on_card_pressed(index: int) -> void:
	choice_selected.emit(index)


static func _make_key(key: String, role: String, color: Color) -> Label:
	var label := _make_text("", role, color)
	AegisText.apply(label, key)
	return label


static func _make_text(text_val: String, role: String, color: Color) -> Label:
	var label := Label.new()
	label.text = text_val
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.set_meta("aegis_role", role)
	label.set_meta("aegis_scale", 1.0)
	label.clip_text = true
	label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	AegisTheme.style_label(label, role, color)
	return label
