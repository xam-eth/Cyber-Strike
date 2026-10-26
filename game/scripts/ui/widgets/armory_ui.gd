## The armory: a modal of weapon cards with the weapon's own art, not a list of
## text rows.
##
## A row that says "ARC · CHAIN" asks the player to imagine a gun. The three
## weapons in this game are three very different silhouettes, and the decision
## being made here -- what am I carrying into the next wave -- is a visual one, so
## every option is a card with a photograph of the weapon, its numbers, its price
## and one action. The card is the same machined plate as the rest of the
## interface (AegisPanel, cut corner, hairline), so the modal reads as part of the
## HUD and not as a spreadsheet that wandered in.
##
## What the card says is only what exists: `damage`, `fire_rate`, `magazine_size`
## come from the weapon definitions, and the price comes from
## ProgressionService.COSTS. Main/ProgressionService still validate every
## purchase; this screen owns no BP and grants nothing.
class_name ArmoryUi
extends AegisPanel

signal weapon_action_requested(weapon_id: StringName)
signal close_requested
signal home_requested

const ORDER := [&"pulse_rifle", &"nova_launcher", &"arc_shooter"]
const SHORT_NAMES := ["PULSE · PRECISION", "NOVA · BLAST", "ARC · CHAIN"]
const CARD_NAMES := ["PULSE RIFLE", "NOVA LAUNCHER", "ARC SHOOTER"]
## One line per weapon: what it does in play, in the player's words. The full
## `role_description` is a sentence in a resource; a card needs a verdict.
const CARD_ROLES := ["Tembakan cepat, akurat", "Ledakan area, lambat", "Rantai listrik"]
const ART := [
	"res://assets/ui/weapon_pulse_rifle.png",
	"res://assets/ui/weapon_nova_launcher.png",
	"res://assets/ui/weapon_arc_shooter.png",
]

var _wallet_label: Label
var _hint_label: Label
var _weapon_buttons: Array[AegisButton] = []
var _cards: Array[AegisPanel] = []
var _states: Array[Label] = []
var _close_button: AegisButton
var _home_button: AegisButton
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

	var row := HBoxContainer.new()
	row.name = "WeaponCards"
	row.size_flags_vertical = Control.SIZE_EXPAND_FILL
	row.add_theme_constant_override("separation", 8)
	_column.add_child(row)
	for index in range(ORDER.size()):
		row.add_child(_build_card(index))

	# Two ways out, both explicit: back to the run, or back to the dashboard the
	# run was launched from. RETURN TO FIELD stays the primary action because
	# leaving the world from a loadout screen is the rarer choice.
	var footer := HBoxContainer.new()
	footer.name = "ArmoryFooter"
	footer.add_theme_constant_override("separation", 8)
	_column.add_child(footer)

	_close_button = AegisButton.new()
	_close_button.name = "CloseArmoryButton"
	_close_button.text = "RETURN TO FIELD"
	_close_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_close_button.focus_mode = Control.FOCUS_ALL
	_close_button.mouse_filter = Control.MOUSE_FILTER_STOP
	AegisTheme.set_button_variant(_close_button, "primary")
	_close_button.pressed.connect(_on_close_pressed)
	footer.add_child(_close_button)

	_home_button = AegisButton.new()
	_home_button.name = "ArmoryHomeButton"
	_home_button.text = "HOME"
	_home_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_home_button.focus_mode = Control.FOCUS_ALL
	_home_button.mouse_filter = Control.MOUSE_FILTER_STOP
	_home_button.icon = AegisTheme.icon("house")
	_home_button.add_theme_constant_override("icon_max_width", 18)
	AegisTheme.set_button_variant(_home_button, "ghost")
	_home_button.pressed.connect(_on_home_pressed)
	footer.add_child(_home_button)
	# Hidden by default: the dashboard shows this same panel as its own armory,
	# and there HOME would be a button that reloads the screen you are on.
	_home_button.visible = false
	visible = false


## One weapon, one plate: art on top, identity under it, numbers in a ruled
## block, and the action at the foot of the card. The action is a real Button so
## keyboard/touch focus and the existing ArmoryUi contract keep working.
func _build_card(index: int) -> AegisPanel:
	var card := AegisPanel.new()
	card.name = "%sCard" % CARD_NAMES[index].get_slice(" ", 0).capitalize()
	card.bezel = true
	card.interactive = false
	card.cut_top_right = 12.0
	card.accent_side = "top"
	card.accent_color = AegisTokens.LINE_HI
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	card.size_flags_vertical = Control.SIZE_EXPAND_FILL
	card.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_cards.append(card)

	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 4)
	column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card.add_child(column)

	var shot := TextureRect.new()
	shot.name = "Art"
	shot.texture = load(ART[index])
	shot.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	shot.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	shot.custom_minimum_size = Vector2(0, 64)
	shot.size_flags_vertical = Control.SIZE_EXPAND_FILL
	shot.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.add_child(shot)

	var name_label := _label(CARD_NAMES[index], "mono_m", AegisTokens.INK)
	column.add_child(name_label)
	var role_label := _label(CARD_ROLES[index], "label", AegisTokens.INK_3)
	column.add_child(role_label)

	var state := _label("", "label", AegisTokens.INFO)
	state.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_states.append(state)
	column.add_child(state)

	var button := AegisButton.new()
	button.name = "%sWeaponButton" % SHORT_NAMES[index].get_slice(" ", 0).capitalize()
	button.focus_mode = Control.FOCUS_ALL
	button.mouse_filter = Control.MOUSE_FILTER_STOP
	AegisTheme.set_button_variant(button, "round")
	button.pressed.connect(_on_weapon_pressed.bind(ORDER[index]))
	column.add_child(button)
	_weapon_buttons.append(button)
	return card


func refresh_profile(
	balance: int, best_score: int, unlocked_ids: Dictionary, equipped: StringName
) -> void:
	_wallet_label.text = "BP  %d  ·  BEST  %d" % [balance, best_score]
	for index in range(ORDER.size()):
		var id: StringName = ORDER[index]
		var definition := load("res://resources/weapons/%s.tres" % String(id)) as WeaponDefinition
		var specs := ""
		if definition != null:
			specs = (
				"%d DMG · %.1f/S · %d"
				% [roundi(definition.damage), definition.fire_rate, definition.magazine_size]
			)
		var state := _states[index]
		state.text = specs
		var button := _weapon_buttons[index]
		var variant := "round"
		if String(id) == String(equipped):
			button.text = "EQUIPPED"
			state.add_theme_color_override("font_color", AegisTokens.ACCENT)
			_cards[index].accent_color = AegisTokens.ACCENT
			variant = "round"
		elif unlocked_ids.has(String(id)):
			button.text = "EQUIP"
			state.add_theme_color_override("font_color", AegisTokens.OK)
			_cards[index].accent_color = AegisTokens.OK
		else:
			var cost: int = int(ProgressionService.COSTS[String(id)])
			button.text = "UNLOCK %d BP" % cost
			state.add_theme_color_override("font_color", AegisTokens.INK_2)
			_cards[index].accent_color = AegisTokens.LINE_HI
			variant = "primary" if balance >= cost else "round"
		# set_button_variant() resets typography to 13 *logical* pixels. On a
		# scaled WASM canvas that is a fraction of a physical pixel, making every
		# purchase/equip action look broken. Preserve the scaled HUD font.
		if button.get_meta("armory_variant", "") != variant:
			var scaled_font := button.get_theme_font_size("font_size")
			AegisTheme.set_button_variant(button, variant)
			AegisTheme.resize_button_font(button, "title", scaled_font)
			button.set_meta("armory_variant", variant)


## The in-world HUD is the only context where leaving for the dashboard is a
## different place than the one the panel is standing on.
func show_home(enabled: bool) -> void:
	_home_button.visible = enabled


func show_hint(text: String) -> void:
	_hint_label.text = text


func layout_for(hud) -> void:
	var width := minf(hud._to_layout(720.0), hud.size.x * 0.94)
	var height := minf(hud._to_layout(300.0), hud.size.y * 0.94)
	custom_minimum_size = Vector2(width, height)
	UiLayout.place(hud, self, 0.5, 0.5, 0.5, 0.5, Rect2(-width * 0.5, -height * 0.5, width, height))
	_column.add_theme_constant_override("separation", roundi(hud._to_layout(4.0)))
	for card in _cards:
		card.custom_minimum_size = Vector2(hud._to_layout(180.0), 0)
	for button in _weapon_buttons:
		button.custom_minimum_size = Vector2(0, hud._to_layout(38.0))
	_close_button.custom_minimum_size = Vector2(0, hud._to_layout(40.0))
	_home_button.custom_minimum_size = Vector2(hud._to_layout(120.0), hud._to_layout(40.0))
	add_theme_stylebox_override(
		"panel",
		AegisTheme.panel_style(
			Color(AegisTokens.PANEL, 0.98),
			Color(AegisTokens.LINE_HI, 0.9),
			1,
			AegisTokens.RADIUS,
			hud._to_layout(14.0)
		)
	)


func focus_first() -> void:
	_weapon_buttons[0].grab_focus()


func _on_home_pressed() -> void:
	home_requested.emit()


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
