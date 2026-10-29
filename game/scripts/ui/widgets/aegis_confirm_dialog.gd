## Reusable confirmation modal (`AegisConfirmDialog`) for high-stakes actions
## such as abandoning an active combat session with unbanked Battle Points.
class_name AegisConfirmDialog
extends AegisPanel

signal confirmed
signal alternate_requested
signal cancelled

var _eyebrow_label: Label
var _title_label: Label
var _body_label: Label
var _cancel_button: AegisButton
var _alternate_button: AegisButton
var _confirm_button: AegisButton
var _column: VBoxContainer


func _ready() -> void:
	interactive = true
	bezel = true
	accent_side = "top"
	accent_color = AegisTokens.DANGER
	super._ready()
	mouse_filter = Control.MOUSE_FILTER_STOP
	visible = false

	_column = VBoxContainer.new()
	_column.add_theme_constant_override("separation", 8)
	add_child(_column)

	_eyebrow_label = _make_label("", "label", AegisTokens.ACCENT)
	_column.add_child(_eyebrow_label)

	_title_label = _make_label("", "display_m", AegisTokens.INK)
	_column.add_child(_title_label)

	_body_label = _make_label("", "body_s", AegisTokens.INK_2)
	_body_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_body_label.max_lines_visible = 3
	_column.add_child(_body_label)

	_alternate_button = _make_button("ConfirmBankButton", "primary")
	_alternate_button.pressed.connect(func() -> void: alternate_requested.emit())
	_column.add_child(_alternate_button)

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	_column.add_child(row)

	_cancel_button = _make_button("ConfirmCancelButton", "round")
	_cancel_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_cancel_button.pressed.connect(func() -> void: cancelled.emit())
	row.add_child(_cancel_button)

	_confirm_button = _make_button("ConfirmProceedButton", "ghost")
	_confirm_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_confirm_button.pressed.connect(func() -> void: confirmed.emit())
	row.add_child(_confirm_button)


func present_dialog(
	eyebrow: String,
	title: String,
	body: String,
	cancel_text: String,
	confirm_text: String,
	alternate_text: String = "",
) -> void:
	_eyebrow_label.text = eyebrow
	_title_label.text = title
	_body_label.text = body
	_cancel_button.text = cancel_text
	_confirm_button.text = confirm_text
	_alternate_button.text = alternate_text
	_alternate_button.visible = not alternate_text.is_empty()
	visible = true
	if _alternate_button.visible:
		_alternate_button.grab_focus()
	else:
		_cancel_button.grab_focus()


func layout_for(hud) -> void:
	var width: float = minf(hud._to_layout(440.0), hud.size.x * 0.90)
	var height: float = minf(hud._to_layout(250.0), hud.size.y * 0.90)
	custom_minimum_size = Vector2(width, height)
	UiLayout.place(hud, self, 0.5, 0.5, 0.5, 0.5, Rect2(-width * 0.5, -height * 0.5, width, height))
	for btn in [_alternate_button, _cancel_button, _confirm_button]:
		if is_instance_valid(btn):
			btn.custom_minimum_size = Vector2(0.0, hud._to_layout(44.0))
	add_theme_stylebox_override(
		"panel",
		AegisTheme.panel_style(
			Color(AegisTokens.PANEL, 0.98),
			Color(AegisTokens.DANGER, 0.85),
			1,
			AegisTokens.RADIUS,
			hud._to_layout(14.0)
		)
	)


static func _make_label(text_val: String, role: String, color: Color) -> Label:
	var label := Label.new()
	label.text = text_val
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.set_meta("aegis_role", role)
	label.set_meta("aegis_scale", 1.0)
	AegisTheme.style_label(label, role, color)
	return label


static func _make_button(button_name: String, variant: String) -> AegisButton:
	var button := AegisButton.new()
	button.name = button_name
	button.focus_mode = Control.FOCUS_ALL
	button.mouse_filter = Control.MOUSE_FILTER_STOP
	AegisTheme.set_button_variant(button, variant)
	return button
