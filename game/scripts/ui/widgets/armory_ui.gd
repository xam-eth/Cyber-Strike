## Small in-game economy screen. No submenu maze: the three actual weapon
## definitions are presented as buy/equip actions and the wallet is always in
## view. Main/ProgressionService validate every purchase; the UI owns no BP.
class_name ArmoryUi
extends AegisPanel

signal weapon_action_requested(weapon_id: StringName)
signal close_requested

const ORDER := [&"pulse_rifle", &"nova_launcher", &"arc_shooter"]
const SHORT_NAMES := ["PULSE · PRECISION", "NOVA · BLAST", "ARC · CHAIN"]

var _wallet_label: Label
var _hint_label: Label
var _weapon_buttons: Array[AegisButton] = []
var _close_button: AegisButton
var _column: VBoxContainer


func _ready() -> void:
	interactive = true
	accent_side = "top"
	accent_color = AegisTokens.ACCENT
	super._ready()
	mouse_filter = Control.MOUSE_FILTER_STOP

	_column = VBoxContainer.new()
	add_child(_column)
	_column.add_child(_label("ARMORY / FIELD LOADOUT", "display_l", AegisTokens.INK))
	_wallet_label = _label("0 BP · BEST 0", "mono_m", AegisTokens.ACCENT)
	_column.add_child(_wallet_label)
	_hint_label = _label("EARN BP BY DEFEATING WAVES", "label", AegisTokens.INK_2)
	_column.add_child(_hint_label)
	for index in range(ORDER.size()):
		var button := AegisButton.new()
		button.name = "%sWeaponButton" % SHORT_NAMES[index].get_slice(" ", 0).capitalize()
		button.focus_mode = Control.FOCUS_ALL
		button.mouse_filter = Control.MOUSE_FILTER_STOP
		AegisTheme.set_button_variant(button, "round")
		button.pressed.connect(_on_weapon_pressed.bind(ORDER[index]))
		_column.add_child(button)
		_weapon_buttons.append(button)
	_close_button = AegisButton.new()
	_close_button.name = "CloseArmoryButton"
	_close_button.text = "RETURN TO FIELD"
	_close_button.focus_mode = Control.FOCUS_ALL
	_close_button.mouse_filter = Control.MOUSE_FILTER_STOP
	AegisTheme.set_button_variant(_close_button, "primary")
	_close_button.pressed.connect(_on_close_pressed)
	_column.add_child(_close_button)
	visible = false


func refresh_profile(
	balance: int, best_score: int, unlocked_ids: Dictionary, equipped: StringName
) -> void:
	_wallet_label.text = "BP  %d  ·  BEST  %d" % [balance, best_score]
	for index in range(ORDER.size()):
		var id: StringName = ORDER[index]
		var name: String = SHORT_NAMES[index]
		var button := _weapon_buttons[index]
		var variant := "round"
		if String(id) == String(equipped):
			button.text = "%s · EQUIPPED" % name
		elif unlocked_ids.has(String(id)):
			button.text = "%s · EQUIP" % name
		else:
			var cost: int = int(ProgressionService.COSTS[String(id)])
			button.text = "%s · UNLOCK %d BP" % [name, cost]
			variant = "primary" if balance >= cost else "round"
		# set_button_variant() resets typography to 13 *logical* pixels. On a
		# portrait WASM canvas that becomes ~4 physical pixels, making every
		# purchase/equip action appear broken. Preserve the scaled HUD font.
		if button.get_meta("armory_variant", "") != variant:
			var scaled_font := button.get_theme_font_size("font_size")
			AegisTheme.set_button_variant(button, variant)
			AegisTheme.resize_button_font(button, "title", scaled_font)
			button.set_meta("armory_variant", variant)


func show_hint(text: String) -> void:
	_hint_label.text = text


func layout_for(hud) -> void:
	var sheet: bool = hud._portrait and hud._narrow
	var width := minf(hud._to_layout(360.0 if sheet else 540.0), hud.size.x * 0.92)
	var height := minf(hud._to_layout(406.0 if sheet else 348.0), hud.size.y * 0.92)
	custom_minimum_size = Vector2(width, height)
	UiLayout.place(hud, self, 0.5, 0.5, 0.5, 0.5, Rect2(-width * 0.5, -height * 0.5, width, height))
	_column.add_theme_constant_override("separation", roundi(hud._to_layout(8.0 if sheet else 5.0)))
	for button in _weapon_buttons:
		button.custom_minimum_size = Vector2(0, hud._to_layout(56.0 if sheet else 50.0))
	_close_button.custom_minimum_size = Vector2(0, hud._to_layout(56.0 if sheet else 50.0))
	add_theme_stylebox_override(
		"panel",
		AegisTheme.panel_style(
			Color(AegisTokens.PANEL, 0.98),
			Color(AegisTokens.LINE_HI, 0.9),
			1,
			AegisTokens.RADIUS,
			hud._to_layout(16.0 if sheet else 12.0)
		)
	)


func focus_first() -> void:
	_weapon_buttons[0].grab_focus()


func _on_weapon_pressed(id: StringName) -> void:
	weapon_action_requested.emit(id)


func _on_close_pressed() -> void:
	close_requested.emit()


func _label(text: String, role: String, color: Color) -> Label:
	var label := Label.new()
	label.text = text
	label.set_meta("aegis_role", role)
	label.set_meta("aegis_scale", 1.0)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	AegisTheme.style_label(label, role, color)
	return label
