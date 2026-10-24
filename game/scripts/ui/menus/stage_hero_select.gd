## HERO SELECTION.
##
## One operative exists. The rig in `assets/characters/hero/` is the only
## skinned hero in the project, so one card is selectable and the rest are
## marked IN DEVELOPMENT rather than populated with invented names, invented
## portraits and invented stat blocks.
##
## The card carries no numeric stats on purpose. There is no hero data model --
## no per-hero health, speed or damage -- so any number printed here would be
## decoration that disagrees with gameplay. What the portrait shows is the
## concept art for the operative; docs/ART_DIRECTION.md §4 is explicit that the
## portrait is not the in-game model.
##
## The name, the blurb, the status line and the portrait path all come from the
## `HeroDefinition` registry, so this screen cannot call the operative one thing
## while the dashboard's loadout line calls it another.
extends MenuStage

## The id the screen starts on. The roster is read from `HeroDefinition`, not
## from a second list kept here: a second spelling of "exo_operative" is a
## second thing to keep in step.
const OPERATIVE_ID := ProgressionService.DEFAULT_HERO_ID
## How many slots the screen shows. Two are placeholders so the layout is not a
## single lonely card on a tablet; they are disabled, never selectable.
const LOCKED_SLOTS := 2

var _cards: Array[AegisButton] = []
## Placeholder slots: not selectable, but they still have to move to the
## landscape row with the real card.
var _locked: Array[AegisButton] = []
## Portrait/landscape list pair built by MenuStage._make_card_list().
var _lists: Dictionary = {}
## Every control authored with MenuStage._size_both() (cards and portraits).
var _oriented: Array = []
## The landscape arrangement: heading and summary stay in the info column, the
## card list moves beside it. See MenuStage._orient_selection().
var _stack: VBoxContainer
var _split: HBoxContainer
var _info: VBoxContainer
var _scroll: ScrollContainer
var _above: Array = []
var _below: Array = []
var _summary: Label
var _continue: AegisButton
var _selected := OPERATIVE_ID


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(make_backdrop("res://assets/ui/dashboard_bg.jpg"))
	var scrim := ColorRect.new()
	scrim.color = Color(AegisTokens.VOID, 0.58)
	scrim.set_anchors_preset(Control.PRESET_FULL_RECT)
	scrim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(scrim)

	_stack = VBoxContainer.new()
	physical_separation(_stack, 14)
	make_margin().add_child(_stack)
	var split := _make_selection_split(300.0)
	_split = split["split"]
	_info = split["info"]

	var heading := card_line("SELECT OPERATIVE", "display_l", AegisTokens.INK)
	_stack.add_child(heading)
	_summary = card_line("", "label", AegisTokens.INK_2)
	_stack.add_child(_summary)
	_above = [heading, _summary]

	_scroll = ScrollContainer.new()
	_scroll.name = &"CardScroll"
	_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_stack.add_child(_scroll)
	_lists = _make_card_list(_scroll)

	# One card per row: three 240 px cards side by side need 752 px, and on a
	# 390 px screen that pushed every label on the screen to twice the display
	# width. A vertical list scrolls instead of overflowing.
	var list: BoxContainer = _lists["column"]

	for definition in HeroDefinition.load_all_definitions():
		list.add_child(_build_hero_card(definition))
	for index in range(LOCKED_SLOTS):
		list.add_child(_build_locked_card(index))

	var footer := HBoxContainer.new()
	physical_separation(footer, 12)
	_stack.add_child(footer)
	_below = [footer]

	var back := make_button("BACK", "ghost", "Return to the dashboard")
	back.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	physical_min_size(back, 0.0, 56.0)
	back.pressed.connect(func() -> void: completed.emit(&"DASHBOARD", {}))
	footer.add_child(back)

	_continue = make_button("CONTINUE", "primary", "Choose a weapon")
	_continue.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	physical_min_size(_continue, 0.0, 56.0)
	_continue.pressed.connect(_on_continue_pressed)
	footer.add_child(_continue)

	_connect_resized(_on_resized)
	relayout()


func enter(_stage_payload: Dictionary) -> void:
	apply_safe_margins(_margin)
	_selected = OPERATIVE_ID
	_on_resized()
	_refresh()


func refresh_profile() -> void:
	_refresh()


func _refresh() -> void:
	var ready := HeroDefinition.DEFINITION_IDS.size()
	_summary.text = (
		"%d OPERATIVE%s FIELD READY · %d IN DEVELOPMENT"
		% [ready, "" if ready == 1 else "S", LOCKED_SLOTS]
	)
	for card in _cards:
		var id := StringName(str(card.get_meta("hero_id", "")))
		# The service owns which heroes exist; a card for an id it does not
		# know about is disabled even if a definition was written for it.
		var selectable := ProgressionService.HERO_IDS.has(id)
		card.disabled = not selectable
		card.edge_active = selectable
		card.set_pressed_no_signal(selectable)


func _build_hero_card(definition: HeroDefinition) -> Control:
	var hero_id := definition.hero_id
	var card := AegisButton.new()
	card.name = "%sCard" % String(hero_id).to_pascal_case()
	card.button_group = ButtonGroup.new()
	card.set_meta("hero_id", String(hero_id))
	card.toggle_mode = true
	card.focus_mode = Control.FOCUS_ALL
	card.mouse_filter = Control.MOUSE_FILTER_STOP
	card.tooltip_text = "%s — %s" % [definition.display_name, definition.status_line.to_lower()]
	_size_both(card, Vector2(0.0, 190.0), Vector2(LANDSCAPE_CARD_WIDTH, 190.0))
	_oriented.append(card)
	card.pressed.connect(_on_card_pressed.bind(hero_id))
	AegisTheme.set_button_variant(card, "round")

	var row := HBoxContainer.new()
	row.set_anchors_preset(Control.PRESET_FULL_RECT)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	physical_separation(row, 14)
	card.add_child(row)

	var portrait := TextureRect.new()
	portrait.texture = try_texture(definition.portrait_path)
	portrait.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	_size_both(portrait, Vector2(130.0, 170.0), Vector2(100.0, 100.0))
	_oriented.append(portrait)
	row.add_child(portrait)

	var column := VBoxContainer.new()
	column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	physical_separation(column, 6)
	row.add_child(column)

	column.add_child(card_line(definition.display_name.to_upper(), "title", AegisTokens.INK))
	column.add_child(card_line(definition.role_description, "body_s", AegisTokens.INK_2))
	column.add_child(
		card_line("STATUS  %s" % definition.status_line.to_upper(), "label_s", AegisTokens.OK)
	)
	_cards.append(card)
	return card


## A placeholder slot, laid out like the real card so the screen does not look
## broken. Disabled and unlabelled beyond "IN DEVELOPMENT" so it cannot be
## mistaken for a hero the player nearly has.
func _build_locked_card(index: int) -> Control:
	var card := AegisButton.new()
	card.name = "LockedHeroCard%d" % index
	_locked.append(card)
	card.disabled = true
	card.focus_mode = Control.FOCUS_NONE
	card.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_size_both(card, Vector2(0.0, 110.0), Vector2(200.0, 96.0))
	_oriented.append(card)
	AegisTheme.set_button_variant(card, "round")

	var row := HBoxContainer.new()
	row.set_anchors_preset(Control.PRESET_FULL_RECT)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	physical_separation(row, 14)
	card.add_child(row)

	var slot := Control.new()
	# Landscape keeps only a sliver of the portrait slot: the card is 200 px
	# wide there, and a 100 px slot would leave 56 px for the words.
	_size_both(slot, Vector2(130.0, 86.0), Vector2(40.0, 86.0))
	_oriented.append(slot)
	row.add_child(slot)

	var column := VBoxContainer.new()
	column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	column.alignment = BoxContainer.ALIGNMENT_CENTER
	column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(column)
	# Slot numbers follow the roster: two heroes would make this SLOT 03.
	column.add_child(
		card_line(
			"SLOT %02d" % (HeroDefinition.DEFINITION_IDS.size() + index + 1),
			"label",
			AegisTokens.LINE_HI
		)
	)
	column.add_child(card_line("IN DEVELOPMENT", "title", AegisTokens.INK_3))
	return card


func _on_card_pressed(hero_id: StringName) -> void:
	var progression := progression_service()
	if progression == null:
		return
	progression.select_hero(hero_id)
	Sfx.play_ui(&"ui_click")
	_refresh()


func _on_continue_pressed() -> void:
	var progression := progression_service()
	if progression != null:
		progression.select_hero(_selected)
	completed.emit(&"WEAPON", {})


func _on_resized() -> void:
	relayout()
	_orient_nodes(_oriented)
	_orient_card_list(_lists, _cards + _locked)
	_orient_selection(_stack, _split, _info, _scroll, _above, _below)
