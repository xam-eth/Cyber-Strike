## WORLD SELECTION.
##
## One world exists: `scenes/worlds/neon_frontier.tscn`, the arena the game
## actually loads. The remaining slots are marked IN DEVELOPMENT. A launch
## button that looked playable but loaded nothing would be the exact failure
## this project is trying to avoid, so the placeholders are disabled and never
## hand an id to the preloader.
##
## The name, blurb, plate, status and *scene* come from the `WorldDefinition`
## registry, and the launch payload names the scene `FrontEnd.GAMEPLAY_SCENE`
## rather than a third copy of the path. `data_source_smoke.gd` instantiates
## the gameplay scene and looks for the world the card advertises, so a card
## naming a theatre the launcher does not contain fails the suite.
extends MenuStage

const LOCKED_SLOTS := 2

var _cards: Array[AegisButton] = []
## Placeholder slots: not selectable, but they still have to move to the
## landscape row with the real card.
var _locked: Array[AegisButton] = []
## Portrait/landscape list pair built by MenuStage._make_card_list().
var _lists: Dictionary = {}
## Every control authored with MenuStage._size_both() (cards and plates).
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


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	# The backdrop is the first theatre's own plate, read from the registry the
	# cards are built from, so the screen cannot fade in behind one image while
	# the card below it shows another.
	var definitions := WorldDefinition.load_all_definitions()
	add_child(make_backdrop("" if definitions.is_empty() else definitions[0].plate_path))
	var scrim := ColorRect.new()
	scrim.color = Color(AegisTokens.VOID, 0.55)
	scrim.set_anchors_preset(Control.PRESET_FULL_RECT)
	scrim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(scrim)

	_stack = VBoxContainer.new()
	physical_separation(_stack, 14)
	make_margin().add_child(_stack)
	var split := _make_selection_split(300.0)
	_split = split["split"]
	_info = split["info"]

	var heading := card_line("SELECT THEATRE", "display_l", AegisTokens.INK)
	_stack.add_child(heading)
	_summary = card_line("", "label", AegisTokens.ACCENT)
	_stack.add_child(_summary)
	_above = [heading, _summary]

	_scroll = ScrollContainer.new()
	_scroll.name = &"CardScroll"
	_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_stack.add_child(_scroll)
	_lists = _make_card_list(_scroll)

	var list: BoxContainer = _lists["column"]
	var group := ButtonGroup.new()
	for definition in definitions:
		list.add_child(_build_world_card(group, definition))
	for index in range(LOCKED_SLOTS):
		list.add_child(_build_locked_card(index))

	var footer := HBoxContainer.new()
	physical_separation(footer, 12)
	_stack.add_child(footer)
	_below = [footer]

	var back := make_button("BACK", "ghost", "Return to weapon selection")
	back.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	physical_min_size(back, 0.0, 56.0)
	back.pressed.connect(func() -> void: completed.emit(&"WEAPON", {}))
	footer.add_child(back)

	var launch := make_button("LAUNCH", "primary", "Load the arena and start the run")
	launch.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	physical_min_size(launch, 0.0, 56.0)
	launch.pressed.connect(_on_launch_pressed)
	footer.add_child(launch)

	_connect_resized(_on_resized)
	relayout()


func enter(_stage_payload: Dictionary) -> void:
	apply_safe_margins(_margin)
	_on_resized()
	_refresh()


func refresh_profile() -> void:
	_refresh()


func _build_world_card(group: ButtonGroup, definition: WorldDefinition) -> Control:
	var world_id := definition.world_id
	var card := AegisButton.new()
	card.name = "%sCard" % String(world_id).to_pascal_case()
	card.button_group = group
	card.toggle_mode = true
	card.focus_mode = Control.FOCUS_ALL
	card.mouse_filter = Control.MOUSE_FILTER_STOP
	_size_both(card, Vector2(0.0, 168.0), Vector2(LANDSCAPE_CARD_WIDTH, 168.0))
	_oriented.append(card)
	card.set_meta("world_id", String(world_id))
	card.pressed.connect(_on_card_pressed.bind(world_id))
	AegisTheme.set_button_variant(card, "round")

	var row := HBoxContainer.new()
	row.set_anchors_preset(Control.PRESET_FULL_RECT)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	physical_separation(row, 14)
	card.add_child(row)

	var plate := TextureRect.new()
	plate.texture = try_texture(definition.plate_path)
	plate.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	plate.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	_size_both(plate, Vector2(120.0, 100.0), Vector2(100.0, 100.0))
	_oriented.append(plate)
	row.add_child(plate)

	var column := VBoxContainer.new()
	column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	physical_separation(column, 4)
	row.add_child(column)
	column.add_child(card_line(definition.display_name.to_upper(), "title", AegisTokens.INK))
	column.add_child(card_line(definition.role_description, "body_s", AegisTokens.INK_2))
	column.add_child(
		card_line("STATUS  %s" % definition.status_line.to_upper(), "label_s", AegisTokens.OK)
	)

	_cards.append(card)
	return card


func _build_locked_card(index: int) -> Control:
	var card := AegisButton.new()
	card.name = "LockedWorldCard%d" % index
	_locked.append(card)
	card.disabled = true
	card.focus_mode = Control.FOCUS_NONE
	card.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_size_both(card, Vector2(0.0, 96.0), Vector2(LANDSCAPE_CARD_WIDTH * 0.5, 96.0))
	_oriented.append(card)
	AegisTheme.set_button_variant(card, "round")

	var column := VBoxContainer.new()
	column.set_anchors_preset(Control.PRESET_FULL_RECT)
	column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.alignment = BoxContainer.ALIGNMENT_CENTER
	card.add_child(column)
	# Theatre numbers follow the roster: two worlds would make this THEATRE 03.
	column.add_child(
		card_line(
			"THEATRE %02d" % (WorldDefinition.DEFINITION_IDS.size() + index + 1),
			"label",
			AegisTokens.LINE_HI
		)
	)
	column.add_child(card_line("IN DEVELOPMENT", "title", AegisTokens.INK_3))
	return card


func _refresh() -> void:
	var progression := progression_service()
	if progression == null:
		return
	var selected := progression.selected_world_id
	for card in _cards:
		var id := StringName(str(card.get_meta("world_id", "")))
		var is_selected := id == selected
		card.edge_active = is_selected
		card.set_pressed_no_signal(is_selected)
	var open_count := WorldDefinition.DEFINITION_IDS.size()
	_summary.text = (
		"%d THEATRE%s OPEN · %d IN DEVELOPMENT"
		% [open_count, "" if open_count == 1 else "S", LOCKED_SLOTS]
	)


func _on_card_pressed(world_id: StringName) -> void:
	var progression := progression_service()
	if progression == null:
		return
	progression.select_world(world_id)
	Sfx.play_ui(&"ui_click")
	_refresh()


func _on_launch_pressed() -> void:
	var progression := progression_service()
	if progression == null:
		return
	progression.select_world(progression.selected_world_id)
	# PRELOAD gets the gameplay scene path and the loadout it must honour. It
	# does the threaded load and the scene change itself.
	(
		completed
		. emit(
			&"PRELOAD",
			{
				"scene": FrontEnd.GAMEPLAY_SCENE,
				"title": "PREPARING DROP",
				"targets": [FrontEnd.GAMEPLAY_SCENE],
				"weapon_id": String(progression.selected_weapon_id),
				"world_id": String(progression.selected_world_id),
			}
		)
	)


func _on_resized() -> void:
	relayout()
	_orient_nodes(_oriented)
	_orient_card_list(_lists, _cards + _locked)
	_orient_selection(_stack, _split, _info, _scroll, _above, _below)
