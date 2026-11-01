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
signal weapon_upgrade_requested(weapon_id: StringName)
signal module_action_requested(module_id: StringName)
signal close_requested
signal home_requested

const ORDER := [&"pulse_rifle", &"nova_launcher", &"arc_shooter"]
const MODULE_ICONS := ["optic", "pulse", "lightning"]
## Node names are built from these, so they keep the id: a test finds
## `ArcWeaponButton` by name, and a name is not copy.
## Node-name stems only. These are never drawn: `wpn.*.name` and `wpn.*.role`
## are the words on the card, and a node name is not copy.
const SHORT_NAMES := ["PULSE · PRECISION", "NOVA · BLAST", "ARC · CHAIN"]
const CARD_NAMES := ["PULSE RIFLE", "NOVA LAUNCHER", "ARC SHOOTER"]
## One line per weapon: what it does in play, in the player's words. The full
## `role_description` is a sentence in a resource; a card needs a verdict. These
## were three Indonesian lines in an otherwise English card -- the exact mix this
## catalog exists to end -- so they are keys now, in both languages.
const CARD_ROLE_KEYS := ["wpn.pulse.role", "wpn.nova.role", "wpn.arc.role"]
const CARD_NAME_KEYS := ["wpn.pulse.name", "wpn.nova.name", "wpn.arc.name"]
const ART := [
	"res://assets/ui/weapon_pulse_rifle.png",
	"res://assets/ui/weapon_nova_launcher.png",
	"res://assets/ui/weapon_arc_shooter.png",
]

var _wallet_label: Label
var _hint_label: Label
var _weapons_tab_btn: AegisButton
var _modules_tab_btn: AegisButton
var _weapon_row: HBoxContainer
var _module_row: HBoxContainer
var _active_tab: String = "weapons"
var _weapon_buttons: Array[AegisButton] = []
var _upgrade_buttons: Array[AegisButton] = []
var _cards: Array[AegisPanel] = []
var _states: Array[Label] = []
var _tier_labels: Array[Label] = []
var _arts: Array[TextureRect] = []
var _module_cards: Array[AegisPanel] = []
var _module_buttons: Array[AegisButton] = []
var _module_states: Array[Label] = []
var _module_notes: Array[Label] = []
var _module_icons: Array[TextureRect] = []
var _close_button: AegisButton
var _home_button: AegisButton
var _column: VBoxContainer
## What the last `refresh_profile` was told, so a language change can re-print
## the wallet and the three cards without the HUD handing the numbers over again.
var _last_balance := 0
var _last_best := 0
var _last_unlocked: Dictionary = {}
var _last_equipped := &""
var _last_tiers: Dictionary = {}
var _last_blueprints: Variant = null
var _last_mod_blueprints: Dictionary = {}
var _last_unlocked_mods: Dictionary = {}
var _last_equipped_mods: Array[StringName] = []
var _hint_key := ""
var _hint_args: Array = []


func _ready() -> void:
	interactive = true
	accent_side = "top"
	accent_color = AegisTokens.ACCENT
	super._ready()
	mouse_filter = Control.MOUSE_FILTER_STOP

	_column = VBoxContainer.new()
	add_child(_column)
	var header_row := HBoxContainer.new()
	header_row.name = "ArmoryHeader"
	header_row.add_theme_constant_override("separation", 8)
	_column.add_child(header_row)
	var title_lbl := _label_key("armory.title", "display_l", AegisTokens.INK)
	title_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header_row.add_child(title_lbl)

	_weapons_tab_btn = AegisButton.new()
	_weapons_tab_btn.name = "WeaponsTabButton"
	_weapons_tab_btn.focus_mode = Control.FOCUS_ALL
	_weapons_tab_btn.mouse_filter = Control.MOUSE_FILTER_STOP
	AegisTheme.set_button_variant(_weapons_tab_btn, "primary")
	_weapons_tab_btn.pressed.connect(show_tab.bind("weapons"))
	header_row.add_child(_weapons_tab_btn)

	_modules_tab_btn = AegisButton.new()
	_modules_tab_btn.name = "ModulesTabButton"
	_modules_tab_btn.focus_mode = Control.FOCUS_ALL
	_modules_tab_btn.mouse_filter = Control.MOUSE_FILTER_STOP
	AegisTheme.set_button_variant(_modules_tab_btn, "ghost")
	_modules_tab_btn.pressed.connect(show_tab.bind("modules"))
	header_row.add_child(_modules_tab_btn)

	_wallet_label = _label("", "mono_m", AegisTokens.ACCENT)
	_column.add_child(_wallet_label)
	_hint_label = _label_key("armory.hint", "label", AegisTokens.INK_2)
	_column.add_child(_hint_label)

	_weapon_row = HBoxContainer.new()
	_weapon_row.name = "WeaponCards"
	_weapon_row.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_weapon_row.add_theme_constant_override("separation", 8)
	_column.add_child(_weapon_row)
	for index in range(ORDER.size()):
		_weapon_row.add_child(_build_card(index))

	_module_row = HBoxContainer.new()
	_module_row.name = "ModuleCards"
	_module_row.visible = false
	_module_row.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_module_row.add_theme_constant_override("separation", 8)
	_column.add_child(_module_row)
	var mod_defs := TechModuleDefinition.all_definitions()
	for index in range(mod_defs.size()):
		_module_row.add_child(_build_module_card(index, mod_defs[index]))
	_refresh_tab_buttons()

	# Two ways out, both explicit: back to the run, or back to the dashboard the
	# run was launched from. RETURN TO FIELD stays the primary action because
	# leaving the world from a loadout screen is the rarer choice.
	var footer := HBoxContainer.new()
	footer.name = "ArmoryFooter"
	footer.add_theme_constant_override("separation", 8)
	_column.add_child(footer)

	_close_button = AegisButton.new()
	_close_button.name = "CloseArmoryButton"
	AegisText.apply(_close_button, "armory.return_field")
	_close_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_close_button.focus_mode = Control.FOCUS_ALL
	_close_button.mouse_filter = Control.MOUSE_FILTER_STOP
	AegisTheme.set_button_variant(_close_button, "primary")
	_close_button.pressed.connect(_on_close_pressed)
	footer.add_child(_close_button)

	_home_button = AegisButton.new()
	_home_button.name = "ArmoryHomeButton"
	AegisText.apply(_home_button, "armory.home")
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
	_arts.append(shot)

	var name_label := _label_key(CARD_NAME_KEYS[index], "mono_m", AegisTokens.INK)
	column.add_child(name_label)
	var role_label := _label_key(CARD_ROLE_KEYS[index], "label", AegisTokens.INK_3)
	column.add_child(role_label)

	var state := _label("", "label", AegisTokens.INFO)
	state.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_states.append(state)
	column.add_child(state)
	var tier_label := _label("", "label_s", AegisTokens.INK_2)
	_tier_labels.append(tier_label)
	column.add_child(tier_label)

	var actions := HBoxContainer.new()
	actions.add_theme_constant_override("separation", 4)
	actions.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.add_child(actions)
	var button := AegisButton.new()
	button.name = "%sWeaponButton" % SHORT_NAMES[index].get_slice(" ", 0).capitalize()
	button.focus_mode = Control.FOCUS_ALL
	button.mouse_filter = Control.MOUSE_FILTER_STOP
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	AegisTheme.set_button_variant(button, "card")
	button.pressed.connect(_on_weapon_pressed.bind(ORDER[index]))
	actions.add_child(button)
	_weapon_buttons.append(button)

	var upgrade := AegisButton.new()
	upgrade.name = "%sUpgradeButton" % SHORT_NAMES[index].get_slice(" ", 0).capitalize()
	upgrade.tooltip_text = "Upgrade weapon tier with Battle Points"
	upgrade.focus_mode = Control.FOCUS_ALL
	upgrade.mouse_filter = Control.MOUSE_FILTER_STOP
	upgrade.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	AegisTheme.set_button_variant(upgrade, "ghost")
	upgrade.pressed.connect(_on_upgrade_pressed.bind(ORDER[index]))
	actions.add_child(upgrade)
	_upgrade_buttons.append(upgrade)
	return card


func _build_module_card(index: int, def: TechModuleDefinition) -> AegisPanel:
	var stem := def.short_tag.capitalize()
	var card := AegisPanel.new()
	card.name = "%sModuleCard" % stem
	card.bezel = true
	card.interactive = false
	card.cut_top_right = 12.0
	card.accent_side = "top"
	card.accent_color = AegisTokens.INFO
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	card.size_flags_vertical = Control.SIZE_EXPAND_FILL
	card.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_module_cards.append(card)

	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 4)
	column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card.add_child(column)

	var icon_wrap := CenterContainer.new()
	icon_wrap.size_flags_vertical = Control.SIZE_EXPAND_FILL
	icon_wrap.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.add_child(icon_wrap)
	var icon_rect := TextureRect.new()
	icon_rect.name = "Icon"
	var icon_key: String = MODULE_ICONS[index % MODULE_ICONS.size()]
	icon_rect.texture = AegisTheme.icon(icon_key, true)
	icon_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon_rect.custom_minimum_size = Vector2(36, 36)
	icon_rect.modulate = AegisTokens.INFO
	icon_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	icon_wrap.add_child(icon_rect)
	_module_icons.append(icon_rect)

	var name_label := _label_key(def.title_key, "mono_m", AegisTokens.INK)
	column.add_child(name_label)
	var summary_label := _label_key(def.summary_key, "label_s", AegisTokens.INK_2)
	summary_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	summary_label.max_lines_visible = 2
	column.add_child(summary_label)

	var state := _label("", "label_s", AegisTokens.INFO)
	state.autowrap_mode = TextServer.AUTOWRAP_OFF
	state.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	_module_states.append(state)
	column.add_child(state)
	var note := _label("", "label_s", AegisTokens.INK_3)
	note.autowrap_mode = TextServer.AUTOWRAP_OFF
	note.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	_module_notes.append(note)
	column.add_child(note)

	var button := AegisButton.new()
	button.name = "%sModuleButton" % stem
	button.focus_mode = Control.FOCUS_ALL
	button.mouse_filter = Control.MOUSE_FILTER_STOP
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	AegisTheme.set_button_variant(button, "card")
	button.pressed.connect(_on_module_pressed.bind(def.module_id))
	column.add_child(button)
	_module_buttons.append(button)
	return card


func show_tab(tab_name: String) -> void:
	_active_tab = "modules" if tab_name == "modules" else "weapons"
	if is_instance_valid(_weapon_row):
		_weapon_row.visible = _active_tab == "weapons"
	if is_instance_valid(_module_row):
		_module_row.visible = _active_tab == "modules"
	_refresh_tab_buttons()


func _refresh_tab_buttons() -> void:
	var owned_weapons := maxi(_last_unlocked.size(), 1)
	if is_instance_valid(_weapons_tab_btn):
		AegisText.apply(_weapons_tab_btn, "armory.tab_weapons", [owned_weapons])
		var w_var := "primary" if _active_tab == "weapons" else "ghost"
		if _weapons_tab_btn.get_meta("armory_variant", "") != w_var:
			var f_sz := _weapons_tab_btn.get_theme_font_size("font_size")
			AegisTheme.set_button_variant(_weapons_tab_btn, w_var)
			if f_sz > 0:
				AegisTheme.resize_button_font(_weapons_tab_btn, "title", f_sz)
			_weapons_tab_btn.set_meta("armory_variant", w_var)
	if is_instance_valid(_modules_tab_btn):
		AegisText.apply(
			_modules_tab_btn,
			"armory.tab_modules",
			[_last_equipped_mods.size(), TechModuleDefinition.MAX_SLOTS]
		)
		var m_var := "primary" if _active_tab == "modules" else "ghost"
		if _modules_tab_btn.get_meta("armory_variant", "") != m_var:
			var f_sz := _modules_tab_btn.get_theme_font_size("font_size")
			AegisTheme.set_button_variant(_modules_tab_btn, m_var)
			if f_sz > 0:
				AegisTheme.resize_button_font(_modules_tab_btn, "title", f_sz)
			_modules_tab_btn.set_meta("armory_variant", m_var)


func refresh_profile(
	balance: int,
	best_score: int,
	unlocked_ids: Dictionary,
	equipped: StringName,
	tiers: Dictionary = {},
	blueprints: Variant = null,
) -> void:
	_last_balance = balance
	_last_best = best_score
	_last_unlocked = unlocked_ids
	_last_equipped = equipped
	_last_tiers = tiers.duplicate()
	_last_blueprints = blueprints.duplicate() if blueprints is Dictionary else null
	_wallet_label.text = AegisText.t("armory.wallet", [balance, best_score])
	for index in range(ORDER.size()):
		var id: StringName = ORDER[index]
		var definition := WeaponDefinition.load_definition(id)
		var owned := unlocked_ids.has(String(id))
		var tier := clampi(int(tiers.get(String(id), 1)), 1, WeaponTier.tier_count())
		var missing_blueprint := false
		if not owned and blueprints is Dictionary and ProgressionService.BLUEPRINT_REQUIRED.has(id):
			missing_blueprint = not (blueprints as Dictionary).has(String(id))
		var specs := ""
		if definition != null:
			specs = AegisText.t(
				"armory.specs",
				[
					roundi(definition.damage * WeaponTier.damage_multiplier(tier)),
					_numeral(definition.fire_rate),
					definition.magazine_size
				]
			)
			if missing_blueprint:
				_tier_labels[index].text = AegisText.t("armory.blueprint_tier_note")
			else:
				_tier_labels[index].text = AegisText.t(
					"armory.tier_reload",
					[tier, _numeral(definition.reload_seconds * WeaponTier.reload_multiplier(tier))]
				)
		var state := _states[index]
		state.text = specs
		var button := _weapon_buttons[index]
		var variant := "card"
		if String(id) == String(equipped):
			AegisText.apply(button, "common.equipped")
			state.add_theme_color_override("font_color", AegisTokens.ACCENT)
			_cards[index].accent_color = AegisTokens.ACCENT
		elif owned:
			AegisText.apply(button, "armory.equip")
			state.add_theme_color_override("font_color", AegisTokens.OK)
			_cards[index].accent_color = AegisTokens.OK
		elif missing_blueprint:
			AegisText.apply(button, "armory.blueprint_locked")
			state.add_theme_color_override("font_color", AegisTokens.INFO)
			_cards[index].accent_color = AegisTokens.INFO
			variant = "ghost"
		else:
			var cost: int = int(ProgressionService.COSTS[String(id)])
			AegisText.apply(button, "armory.unlock", [cost])
			state.add_theme_color_override("font_color", AegisTokens.INK_2)
			_cards[index].accent_color = AegisTokens.LINE_HI
			variant = "primary" if balance >= cost else "card"
		# set_button_variant() resets typography to logical pixels. Preserve the
		# scaled HUD font after changing the visual state.
		if button.get_meta("armory_variant", "") != variant:
			var scaled_font := button.get_theme_font_size("font_size")
			AegisTheme.set_button_variant(button, variant)
			AegisTheme.resize_button_font(button, "title", scaled_font)
			button.set_meta("armory_variant", variant)

		var upgrade := _upgrade_buttons[index]
		upgrade.disabled = not owned or tier >= WeaponTier.tier_count()
		if tier >= WeaponTier.tier_count():
			AegisText.apply(upgrade, "armory.upgrade_max_short", [tier])
		else:
			AegisText.apply(
				upgrade, "armory.upgrade_short", [tier + 1, WeaponTier.cost(id, tier + 1)]
			)
		var can_afford := balance >= WeaponTier.cost(id, tier + 1)
		var upgrade_variant := (
			"primary" if owned and can_afford and tier < WeaponTier.tier_count() else "ghost"
		)
		if upgrade.get_meta("armory_variant", "") != upgrade_variant:
			var scaled_font := upgrade.get_theme_font_size("font_size")
			AegisTheme.set_button_variant(upgrade, upgrade_variant)
			AegisTheme.resize_button_font(upgrade, "title", scaled_font)
			upgrade.set_meta("armory_variant", upgrade_variant)
	_refresh_tab_buttons()
	refresh_modules(_last_mod_blueprints, _last_unlocked_mods, _last_equipped_mods)


func refresh_modules(
	module_blueprints: Dictionary,
	unlocked_modules: Dictionary,
	equipped_modules: Array[StringName],
) -> void:
	_last_mod_blueprints = module_blueprints.duplicate()
	_last_unlocked_mods = unlocked_modules.duplicate()
	_last_equipped_mods = equipped_modules.duplicate()
	_refresh_tab_buttons()
	var defs := TechModuleDefinition.all_definitions()
	for index in range(mini(defs.size(), _module_cards.size())):
		var def := defs[index]
		var key := String(def.module_id)
		var owned := unlocked_modules.has(key)
		var has_bp := owned or module_blueprints.has(key)
		var eq_slot := equipped_modules.find(def.module_id)
		var is_eq := eq_slot >= 0
		var state := _module_states[index]
		var note := _module_notes[index]
		var button := _module_buttons[index]
		var icon_rect := _module_icons[index]
		note.text = def.display_role()
		var variant := "card"
		if is_eq:
			state.text = AegisText.t(
				"armory.mod_equipped_slot", [eq_slot + 1, TechModuleDefinition.MAX_SLOTS]
			)
			state.add_theme_color_override("font_color", AegisTokens.ACCENT)
			_module_cards[index].accent_color = AegisTokens.ACCENT
			icon_rect.modulate = AegisTokens.ACCENT
			AegisText.apply(button, "armory.mod_unequip")
			variant = "card"
		elif owned:
			state.text = AegisText.t("armory.mod_owned")
			state.add_theme_color_override("font_color", AegisTokens.OK)
			_module_cards[index].accent_color = AegisTokens.OK
			icon_rect.modulate = AegisTokens.OK
			AegisText.apply(button, "armory.equip")
			variant = (
				"primary" if equipped_modules.size() < TechModuleDefinition.MAX_SLOTS else "ghost"
			)
		elif not has_bp:
			state.text = AegisText.t("armory.mod_source", [def.display_source_world()])
			state.add_theme_color_override("font_color", AegisTokens.INFO)
			_module_cards[index].accent_color = AegisTokens.INFO
			icon_rect.modulate = Color(AegisTokens.INFO, 0.55)
			AegisText.apply(button, "armory.blueprint_locked")
			variant = "ghost"
		else:
			state.text = AegisText.t("armory.mod_source", [def.display_source_world()])
			state.add_theme_color_override("font_color", AegisTokens.INK_2)
			_module_cards[index].accent_color = AegisTokens.LINE_HI
			icon_rect.modulate = AegisTokens.INFO
			AegisText.apply(button, "armory.unlock", [def.unlock_cost])
			variant = "primary" if _last_balance >= def.unlock_cost else "card"
		if button.get_meta("armory_variant", "") != variant:
			var scaled_font := button.get_theme_font_size("font_size")
			AegisTheme.set_button_variant(button, variant)
			if scaled_font > 0:
				AegisTheme.resize_button_font(button, "title", scaled_font)
			button.set_meta("armory_variant", variant)


## The in-world HUD is the only context where leaving for the dashboard is a
## different place than the one the panel is standing on.
func show_home(enabled: bool) -> void:
	_home_button.visible = enabled


## A hint that is a catalog key plus its numbers, so it survives a language
## change. The literal setter stays for a caller that already has a finished
## sentence, and clears the key so the language walk cannot overwrite it.
func show_hint_key(key: String, args: Array = []) -> void:
	_hint_key = key
	_hint_args = args
	AegisText.apply(_hint_label, key, args)


func show_hint(text: String) -> void:
	_hint_key = ""
	_hint_args = []
	if _hint_label.has_meta("i18n_key"):
		_hint_label.remove_meta("i18n_key")
	_hint_label.text = text


## Re-reads every card in the new language. Called by the HUD when the player
## switches language while the armory is open.
func refresh_language() -> void:
	AegisText.refresh(self)
	if not _last_equipped.is_empty():
		refresh_profile(
			int(_last_balance),
			int(_last_best),
			_last_unlocked,
			_last_equipped,
			_last_tiers,
			_last_blueprints,
		)
	if not _hint_key.is_empty():
		AegisText.apply(_hint_label, _hint_key, _hint_args)


func layout_for(hud) -> void:
	var screen_height: float = hud.size.y * hud._stretch
	var compact_v: bool = screen_height < 480.0
	var width: float = minf(float(hud._to_layout(720.0)), hud.size.x * 0.94)
	var target_h: float = 336.0 if compact_v else 380.0
	var height: float = minf(float(hud._to_layout(target_h)), hud.size.y * 0.92)
	var col_sep: int = roundi(float(hud._to_layout(2.0 if compact_v else 4.0)))
	_column.add_theme_constant_override("separation", col_sep)
	var card_pad: float = float(hud._to_layout(6.0 if compact_v else 12.0))
	var card_min_w: float = float(hud._to_layout(148.0 if compact_v else 180.0))
	for card in _cards:
		card.set_surface_pad(card_pad)
		card.custom_minimum_size = Vector2(card_min_w, 0.0)
		if card.get_child_count() > 0 and card.get_child(0) is VBoxContainer:
			(card.get_child(0) as VBoxContainer).add_theme_constant_override("separation", col_sep)
	var art_floor: float = 54.0 if screen_height < 400.0 else (68.0 if compact_v else 104.0)
	var art_min_h: float = float(hud._to_layout(art_floor))
	for art in _arts:
		art.custom_minimum_size = Vector2(0.0, art_min_h)
	var icon_sz: float = float(hud._to_layout(28.0 if compact_v else 38.0))
	for m_card in _module_cards:
		m_card.set_surface_pad(card_pad)
		m_card.custom_minimum_size = Vector2(card_min_w, 0.0)
		if m_card.get_child_count() > 0 and m_card.get_child(0) is VBoxContainer:
			(m_card.get_child(0) as VBoxContainer).add_theme_constant_override(
				"separation", col_sep
			)
	for m_icon in _module_icons:
		m_icon.custom_minimum_size = Vector2(icon_sz, icon_sz)
	var btn_h: float = float(hud._to_layout(32.0 if compact_v else 36.0))
	var tab_h: float = float(hud._to_layout(26.0 if compact_v else 30.0))
	if is_instance_valid(_weapons_tab_btn):
		_weapons_tab_btn.custom_minimum_size = Vector2(0.0, tab_h)
	if is_instance_valid(_modules_tab_btn):
		_modules_tab_btn.custom_minimum_size = Vector2(0.0, tab_h)
	for button in _weapon_buttons:
		button.custom_minimum_size = Vector2(0.0, btn_h)
	for button in _upgrade_buttons:
		button.custom_minimum_size = Vector2(0.0, btn_h)
	for button in _module_buttons:
		button.custom_minimum_size = Vector2(0.0, btn_h)
	var foot_h: float = float(hud._to_layout(34.0 if compact_v else 40.0))
	var home_w: float = float(hud._to_layout(120.0))
	_close_button.custom_minimum_size = Vector2(0.0, foot_h)
	_home_button.custom_minimum_size = Vector2(home_w, foot_h)
	var panel_pad: float = float(hud._to_layout(8.0 if compact_v else 14.0))
	add_theme_stylebox_override(
		"panel",
		AegisTheme.panel_style(
			Color(AegisTokens.PANEL, 0.98),
			Color(AegisTokens.LINE_HI, 0.9),
			1,
			AegisTokens.RADIUS,
			panel_pad
		)
	)
	custom_minimum_size = Vector2(width, height)
	var min_size: Vector2 = get_combined_minimum_size()
	var final_w: float = maxf(width, min_size.x)
	var final_h: float = maxf(height, min_size.y)
	UiLayout.place(
		hud, self, 0.5, 0.5, 0.5, 0.5, Rect2(-final_w * 0.5, -final_h * 0.5, final_w, final_h)
	)


func focus_first() -> void:
	if _active_tab == "modules" and not _module_buttons.is_empty():
		_module_buttons[0].grab_focus()
	else:
		_weapon_buttons[0].grab_focus()


func _on_home_pressed() -> void:
	home_requested.emit()


func _on_weapon_pressed(id: StringName) -> void:
	weapon_action_requested.emit(id)


func _on_upgrade_pressed(id: StringName) -> void:
	weapon_upgrade_requested.emit(id)


func _on_module_pressed(id: StringName) -> void:
	module_action_requested.emit(id)


func _on_close_pressed() -> void:
	close_requested.emit()


func _label_key(key: String, role: String, color: Color) -> Label:
	var result := _label("", role, color)
	AegisText.apply(result, key)
	return result


## "5" not "5.00": the same trimming the weapon rail uses, so one card and one
## rail print a rate the same way.
static func _numeral(value: float) -> String:
	var text := "%.2f" % value
	while text.ends_with("0") and text.contains("."):
		text = text.substr(0, text.length() - 1)
	return text.substr(0, text.length() - 1) if text.ends_with(".") else text


func _label(text: String, role: String, color: Color) -> Label:
	var label := Label.new()
	label.text = text
	label.set_meta("aegis_role", role)
	label.set_meta("aegis_scale", 1.0)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	AegisTheme.style_label(label, role, color)
	return label
