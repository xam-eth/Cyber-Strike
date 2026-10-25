## HERO SELECTION.
##
## The selectable roster is loaded from HeroDefinition. Each field-ready card
## has a runtime GLB and a per-model retargeted rig profile behind it; the two
## additional slots remain disabled placeholders rather than promises of
## content that does not exist.
##
## The card carries no numeric stats on purpose. Heroes share the same player
## controller, weapons, and combat tuning, so health/speed/damage numbers here
## would be decoration. Existing standalone portrait art is used when present;
## otherwise the actual runtime GLB is shown in a small 3D preview.
##
## Name, blurb, status, model and rig paths all come from HeroDefinition, so the
## card and the dashboard cannot quietly describe different operative data.
extends MenuStage

const ModelFitterScript = preload("res://scripts/visual/model_fitter.gd")

## The roster is read from HeroDefinition, not from a second hand-written list.
const OPERATIVE_ID := ProgressionService.DEFAULT_HERO_ID
## The remaining slots are disabled placeholders, never selectable.
const LOCKED_SLOTS := 2

var _cards: Array[AegisButton] = []
## Placeholder slots: not selectable, but they still have to move to the
## landscape row with the real cards.
var _locked: Array[AegisButton] = []
var _hero_button_group := ButtonGroup.new()
## Portrait/landscape list pair built by MenuStage._make_card_list().
var _lists: Dictionary = {}
## Every control authored with MenuStage._size_both() (cards and previews).
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
	_hero_button_group.allow_unpress = false
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
	var progression := progression_service()
	_selected = progression.selected_hero_id if progression != null else OPERATIVE_ID
	_on_resized()
	_refresh()


func refresh_profile() -> void:
	_refresh()


func _refresh() -> void:
	var progression := progression_service()
	if progression != null and ProgressionService.HERO_IDS.has(progression.selected_hero_id):
		_selected = progression.selected_hero_id

	var ready := 0
	for definition in HeroDefinition.load_all_definitions():
		if (
			definition.field_ready
			and definition.is_valid_definition()
			and ProgressionService.HERO_IDS.has(definition.hero_id)
		):
			ready += 1
	_summary.text = (
		"%d OPERATIVE%s FIELD READY · %d IN DEVELOPMENT"
		% [ready, "" if ready == 1 else "S", LOCKED_SLOTS]
	)
	for card in _cards:
		var id := StringName(str(card.get_meta("hero_id", "")))
		var definition := HeroDefinition.load_definition(id)
		var selectable := (
			definition != null
			and definition.field_ready
			and definition.is_valid_definition()
			and ProgressionService.HERO_IDS.has(id)
		)
		card.disabled = not selectable
		card.edge_active = selectable
		card.set_pressed_no_signal(selectable and id == _selected)


func _build_hero_card(definition: HeroDefinition) -> Control:
	var hero_id := definition.hero_id
	var card := AegisButton.new()
	card.name = "%sCard" % String(hero_id).to_pascal_case()
	card.button_group = _hero_button_group
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
	row.add_child(_build_hero_visual(definition))

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


func _build_hero_visual(definition: HeroDefinition) -> Control:
	if (
		not definition.portrait_path.strip_edges().is_empty()
		and ResourceLoader.exists(definition.portrait_path)
	):
		var portrait := TextureRect.new()
		portrait.texture = try_texture(definition.portrait_path)
		portrait.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
		_size_both(portrait, Vector2(130.0, 170.0), Vector2(100.0, 100.0))
		_oriented.append(portrait)
		return portrait
	return _build_model_preview(definition)


## No Drive thumbnail exists for the Rare/Epic GLBs, so show the real model
## instead of leaving a blank image or inventing a portrait.
func _build_model_preview(definition: HeroDefinition) -> Control:
	var container := SubViewportContainer.new()
	container.name = "%sPreview" % String(definition.hero_id).to_pascal_case()
	container.stretch = true
	container.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_size_both(container, Vector2(130.0, 170.0), Vector2(100.0, 100.0))
	_oriented.append(container)

	var viewport := SubViewport.new()
	viewport.name = "HeroPreviewViewport"
	viewport.size = Vector2i(256, 340)
	viewport.own_world_3d = true
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	container.add_child(viewport)

	var preview_world := Node3D.new()
	preview_world.name = "PreviewWorld"
	viewport.add_child(preview_world)

	var environment_node := WorldEnvironment.new()
	var environment := Environment.new()
	environment.background_mode = Environment.BG_COLOR
	environment.background_color = Color(0.025, 0.055, 0.075, 1.0)
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color(0.54, 0.72, 0.82)
	environment.ambient_light_energy = 0.7
	environment_node.environment = environment
	preview_world.add_child(environment_node)

	var key_light := DirectionalLight3D.new()
	key_light.rotation = Vector3(deg_to_rad(-28.0), deg_to_rad(24.0), 0.0)
	key_light.light_energy = 1.55
	key_light.shadow_enabled = false
	preview_world.add_child(key_light)

	var fill_light := OmniLight3D.new()
	fill_light.position = Vector3(0.8, 1.25, 1.9)
	fill_light.light_energy = 1.4
	fill_light.omni_range = 5.0
	preview_world.add_child(fill_light)

	var model_root := Node3D.new()
	model_root.name = "PreviewModelRoot"
	preview_world.add_child(model_root)
	var fitted := ModelFitterScript.attach(
		model_root,
		definition.model_scene,
		definition.target_height * 0.9,
		0.0,
		"PreviewPivot",
		"PreviewModel"
	)
	if not fitted.is_empty():
		var model := fitted["model"] as Node3D
		var players := model.find_children("*", "AnimationPlayer", true, false)
		if not players.is_empty():
			var animation_player := players[0] as AnimationPlayer
			if animation_player.has_animation("idle"):
				animation_player.play("idle")

	var camera := Camera3D.new()
	camera.name = "PreviewCamera"
	camera.position = Vector3(0.0, definition.target_height * 0.52, definition.target_height * 2.65)
	camera.fov = 28.0
	camera.near = 0.05
	camera.far = 20.0
	camera.look_at(Vector3(0.0, definition.target_height * 0.45, 0.0), Vector3.UP)
	camera.current = true
	viewport.add_child(camera)
	return container


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
	# Slot numbers follow the roster: the three real heroes make these SLOT 04+.
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
	var definition := HeroDefinition.load_definition(hero_id)
	if progression == null or definition == null or not definition.field_ready:
		return
	_selected = hero_id
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
