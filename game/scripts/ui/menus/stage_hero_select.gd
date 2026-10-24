## HERO SELECTION — a full-screen 3D showcase of the operative gameplay spawns.
##
## This screen used to be a painted card list. The card was honest about what
## existed (one playable operative, two slots marked IN DEVELOPMENT) but it sold
## the hero with concept art while the game spawned a rigged GLB. `showcase_smoke`
## asserts the model on this screen is the exact resource `player.tscn` attaches,
## so the first thing a player sees is the thing that will be holding the rifle.
##
## The composition follows the showcase brief: carousel and identity at the top,
## the model filling the middle, information and actions at the bottom, and
## deliberate space around the silhouette rather than panels over it.
##
## What it does *not* show is a stat block. This project has no per-hero gameplay
## model -- every operative runs the same controller and the same `CharacterVisual`
## -- so health, shield, mobility and skills would be decoration a player can read
## that nothing in the game uses. `HeroDefinition` documents that decision; the
## panel shows what is real: the operative's status and the loadout they will
## deploy with.
extends MenuStage

const ShowcaseViewportScript = preload("res://scripts/ui/widgets/showcase_viewport.gd")

## The id the screen starts on. The roster is read from `HeroDefinition`, not
## from a second list kept here.
const OPERATIVE_ID := ProgressionService.DEFAULT_HERO_ID
## Placeholder slots, so the layout is not one lonely chip on a tablet. They are
## disabled and never selectable: the project ships one operative.
const LOCKED_SLOTS := 2
## Showcase model height in metres. The same value `CharacterVisual` fits the
## avatar to, so the showcase and the arena agree about how tall this hero is.
const SHOWCASE_HEIGHT := 1.78

## How much of the showcase box the operative fills.
##
## One number for every box: the fill is solved against the box's own aspect, so
## a tall portrait slot and a wide landscape one both get an operative that fills
## the same fraction of what is available. 0.84 leaves the helmet and the boots
## clear of the edges -- raising it per orientation is what cropped the head at
## 1280x720.
const SHOWCASE_FILL := 0.84

var _cards: Array[AegisButton] = []
var _locked: Array[AegisButton] = []
var _showcase: ShowcaseViewport
var _carousel: ScrollContainer
var _heading: Label
var _development_label: Label
var _name_label: Label
var _status_label: Label
var _role_label: Label
var _loadout_label: Label
var _select_button: AegisButton
var _continue: AegisButton
var _selected := OPERATIVE_ID
var _select_requested := false

# Containers that move between the portrait and landscape arrangements.
var _stack: VBoxContainer
var _header: HBoxContainer
var _body_portrait: VBoxContainer
var _body_landscape: HBoxContainer
var _col_left: VBoxContainer
var _col_right: VBoxContainer
var _showcase_holder: Control
var _panel: AegisPanel
var _actions: HBoxContainer
var _carousel_wrap: VBoxContainer
var _landscape_built := false
var _chrome: LobbyChrome
## The weapon rail. The WEAPON stage is gone -- its screen was a carousel of
## three chips around a 3D rifle, which is a section of a loadout, not a page in
## a journey. It lives here now as one row under the operative's card: choose the
## weapon you deploy with, see the numbers it will actually fire.
## HBox where three chips fit side by side, VBox on a narrow screen: the
## direction is the container class, and a `vertical` flag did nothing.
var _weapon_row: Container
var _weapon_stat: Label
var _weapon_pins: Array[AegisButton] = []


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(make_backdrop("res://assets/ui/dashboard_bg.jpg"))
	var scrim := ColorRect.new()
	# Darker than the dashboard's scrim on purpose: the model is the subject, and
	# a busy backdrop directly behind a silhouette is what the brief forbids.
	scrim.color = Color(AegisTokens.VOID, 0.74)
	scrim.set_anchors_preset(Control.PRESET_FULL_RECT)
	scrim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(scrim)

	_stack = VBoxContainer.new()
	physical_separation(_stack, 14)
	make_margin().add_child(_stack)

	_build_header()
	_build_body_containers()
	_build_carousel()
	_build_showcase()
	_build_panel()
	_build_actions()

	_connect_resized(_on_resized)
	relayout()


## The dock navigates between the three lobby pages, so HERO can go straight
## home or to the theatre without walking back through the dashboard.
## A rail chip is a button with its text inside it as a label, the way the cards
## are built. A Button's own `text` sets a minimum width equal to one unwrapped
## line, and three of those in a row were wider than a 390 px screen.
func _build_weapon_pin(definition: WeaponDefinition) -> AegisButton:
	var pin := AegisButton.new()
	pin.name = "%sWeapon" % String(definition.weapon_id).to_pascal_case()
	pin.text = ""
	pin.set_meta("weapon_id", String(definition.weapon_id))
	pin.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	pin.focus_mode = Control.FOCUS_ALL
	AegisTheme.set_button_variant(pin, "card")
	var label := make_label("", "label_s", AegisTokens.INK)
	label.name = &"WeaponName"
	label.set_anchors_preset(Control.PRESET_FULL_RECT)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_limit_lines(label, 2)
	label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	pin.add_child(label)
	pin.pressed.connect(_on_weapon_pressed.bind(definition.weapon_id))
	_weapon_pins.append(pin)
	return pin


## Equipping writes to the service, which is what DEPLOY reads. A locked weapon
## is shown, priced, and not saved until it is bought in the armory.
func _on_weapon_pressed(weapon_id: StringName) -> void:
	var progression := progression_service()
	if progression == null or not progression.is_unlocked(weapon_id):
		return
	if progression.selected_weapon_id == weapon_id:
		return
	progression.select_weapon(weapon_id)
	Sfx.play_ui(&"ui_click")
	_refresh()


## Three chips in a portrait column cost 192 px of height and put the action row
## 76 px past the bottom edge on a 1280x720 desktop; side by side they cost 64.
func _orient_rail(horizontal: bool) -> void:
	if not is_instance_valid(_weapon_row):
		return
	if (
		(horizontal and _weapon_row is HBoxContainer)
		or (not horizontal and _weapon_row is VBoxContainer)
	):
		return
	var target: Container = HBoxContainer.new() if horizontal else VBoxContainer.new()
	target.name = &"WeaponRail"
	for pin in _weapon_pins:
		if pin.get_parent() != null:
			pin.get_parent().remove_child(pin)
		target.add_child(pin)
	var parent := _weapon_row.get_parent()
	if parent != null:
		var index := _weapon_row.get_index()
		parent.remove_child(_weapon_row)
		parent.add_child(target)
		parent.move_child(target, index)
	_weapon_row = target
	physical_separation(_weapon_row, 8)


func _refresh_weapons(progression: ProgressionService) -> void:
	for pin in _weapon_pins:
		var weapon_id := StringName(str(pin.get_meta("weapon_id", "")))
		var definition := WeaponDefinition.load_definition(weapon_id)
		if definition == null:
			continue
		var owned: bool = progression == null or progression.is_unlocked(weapon_id)
		var live: bool = progression != null and progression.selected_weapon_id == weapon_id
		pin.disabled = not owned
		# The chip's own label says what it is and what it costs. The data test
		# reads this label and compares it with the WeaponDefinition, so a price
		# here that the service does not charge fails the suite.
		var label := pin.get_node_or_null("WeaponName") as Label
		if label != null:
			label.text = (
				definition.display_name.to_upper()
				if owned
				else (
					"%s\n%d BP"
					% [definition.display_name.to_upper(), definition_id_cost(weapon_id)]
				)
			)
		pin.edge_active = live
		pin.queue_redraw()
	if progression == null:
		return
	var selected := WeaponDefinition.load_definition(progression.selected_weapon_id)
	if selected == null or not is_instance_valid(_weapon_stat):
		return
	var parts: Array[String] = [
		"DMG %d" % roundi(selected.damage),
		"RATE %s/s" % _numeral(selected.fire_rate),
		"MAG %d" % selected.magazine_size,
		"RELOAD %ss" % _numeral(selected.reload_seconds),
		"RNG %d" % roundi(selected.max_range),
	]
	if selected.splash_damage > 0.0:
		parts.append("SPLASH %d" % roundi(selected.splash_damage))
	if selected.chain_count > 0:
		parts.append("CHAIN %d" % selected.chain_count)
	_weapon_stat.text = "  ·  ".join(parts)


## 5.0 prints "5", 1.35 prints "1.35": the same trimming the old weapon screen
## did, because "RATE 5.00/s" reads like a spreadsheet.
static func _numeral(value: float) -> String:
	var text := "%.2f" % value
	while text.ends_with("0") and text.contains("."):
		text = text.substr(0, text.length() - 1)
	return text.substr(0, text.length() - 1) if text.ends_with(".") else text


func definition_id_cost(weapon_id: StringName) -> int:
	var progression := progression_service()
	return 0 if progression == null else progression.unlock_cost(weapon_id)


func _on_nav_requested(tab_id: StringName) -> void:
	match tab_id:
		LobbyChrome.TAB_HOME:
			completed.emit(&"DASHBOARD", {})
		LobbyChrome.TAB_WORLD:
			completed.emit(&"WORLD", {"world_id": String(progression_service().selected_world_id)})
		_:
			pass


func enter(_stage_payload: Dictionary) -> void:
	apply_safe_margins(_margin)
	_selected = OPERATIVE_ID
	_select_requested = false
	_on_resized()
	_refresh()
	# The reveal runs on entry, not only on a change: the brief's first beat is
	# the hero arriving, and a screen that is already fully composed when the
	# transition ends has no reveal at all.
	_present_selected(true)


func exit() -> void:
	if is_instance_valid(_showcase):
		_showcase.clear_model()


func refresh_profile() -> void:
	_refresh()
	if _chrome != null:
		_chrome.refresh(progression_service())


# --- construction ----------------------------------------------------------- #


func _build_header() -> void:
	_chrome = LobbyChrome.build(self, LobbyChrome.TAB_OPERATIVE, false)
	_chrome.navigate.connect(_on_nav_requested)
	_stack.add_child(_chrome.bar)

	_header = HBoxContainer.new()
	physical_separation(_header, 16)
	_stack.add_child(_header)

	var back := make_button("BACK", "ghost", "Return to the dashboard")
	physical_min_size(back, 110.0, AegisTokens.MIN_TOUCH_PX)
	back.pressed.connect(func() -> void: completed.emit(&"DASHBOARD", {}))
	_header.add_child(back)

	_heading = make_label("SELECT OPERATIVE", "display_m", AegisTokens.INK)
	_heading.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_heading.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_heading.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_header.add_child(_heading)

	_status_label = make_label("", "label", AegisTokens.OK)
	_status_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_status_label.autowrap_mode = TextServer.AUTOWRAP_OFF
	_header.add_child(_status_label)


func _build_body_containers() -> void:
	_body_portrait = VBoxContainer.new()
	_body_portrait.size_flags_vertical = Control.SIZE_EXPAND_FILL
	physical_separation(_body_portrait, 14)

	_body_landscape = HBoxContainer.new()
	_body_landscape.size_flags_vertical = Control.SIZE_EXPAND_FILL
	physical_separation(_body_landscape, 18)

	_col_left = VBoxContainer.new()
	_col_left.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_col_left.size_flags_vertical = Control.SIZE_EXPAND_FILL
	physical_separation(_col_left, 14)

	_col_right = VBoxContainer.new()
	_col_right.size_flags_vertical = Control.SIZE_EXPAND_FILL
	physical_separation(_col_right, 14)

	_stack.add_child(_body_portrait)


func _build_carousel() -> void:
	_carousel_wrap = VBoxContainer.new()
	physical_separation(_carousel_wrap, 10)
	_body_portrait.add_child(_carousel_wrap)

	_carousel = ScrollContainer.new()
	_carousel.name = &"HeroCarousel"
	_carousel.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	_carousel.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_carousel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	physical_min_size(_carousel, 0.0, 120.0)
	# A ScrollContainer defaults to EXPAND_FILL vertically. In the right-hand rail
	# that meant the carousel ate every spare pixel and pushed the name and the
	# information card 90 px down the screen, leaving a hole above them.
	_carousel.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	_carousel_wrap.add_child(_carousel)

	# MenuStage drives horizontal thumb-drags against `_card_scroll`; the
	# carousel is a scroll container the stage did not build, so it has to be
	# registered or a touch drag does nothing on a swipe.
	_card_scroll = _carousel

	var row := HBoxContainer.new()
	row.name = &"HeroChips"
	physical_separation(row, 10)
	row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_carousel.add_child(row)

	for definition in HeroDefinition.load_all_definitions():
		row.add_child(_build_chip(definition))
	for index in range(LOCKED_SLOTS):
		row.add_child(_build_locked_chip(index))
	# The name and the roster caption are not part of the carousel: they belong to
	# the information card, which `_build_panel()` puts under this row.


## One small portrait per operative. Small on purpose: the model is the subject,
## and the portrait is how a player recognises which one is selected without
## reading a name. It keeps `hero_id` metadata because the data-source test reads
## the roster back out of these buttons.
func _build_chip(definition: HeroDefinition) -> Control:
	var chip := AegisButton.new()
	chip.name = "%sChip" % String(definition.hero_id).to_pascal_case()
	chip.button_group = ButtonGroup.new()
	chip.toggle_mode = true
	chip.focus_mode = Control.FOCUS_ALL
	chip.mouse_filter = Control.MOUSE_FILTER_STOP
	chip.set_meta("hero_id", String(definition.hero_id))
	chip.tooltip_text = "%s — %s" % [definition.display_name, definition.status_line.to_lower()]
	_size_both(chip, Vector2(104.0, 104.0), Vector2(84.0, 84.0))
	AegisTheme.set_button_variant(chip, "round")
	chip.pressed.connect(_on_chip_pressed.bind(definition.hero_id))
	_cards.append(chip)

	var portrait := TextureRect.new()
	portrait.texture = try_texture(definition.portrait_path)
	portrait.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	portrait.set_anchors_preset(Control.PRESET_FULL_RECT)
	portrait.mouse_filter = Control.MOUSE_FILTER_IGNORE
	portrait.name = "Portrait"
	chip.add_child(portrait)
	return chip


func _build_locked_chip(index: int) -> Control:
	var chip := AegisButton.new()
	chip.name = "LockedHeroChip%d" % index
	chip.disabled = true
	chip.focus_mode = Control.FOCUS_NONE
	chip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	chip.tooltip_text = "No rig and no definition in this build"
	_size_both(chip, Vector2(84.0, 84.0), Vector2(68.0, 68.0))
	AegisTheme.set_button_variant(chip, "round")
	_locked.append(chip)

	# The chip is 68-84 px: a slot number fits, two words do not. "IN DEVELOPMENT"
	# lives in the caption under the carousel instead of being squeezed into a
	# square and drawn past its edge, which is what the containment assertion in
	# menu_layout_smoke caught.
	var column := VBoxContainer.new()
	column.set_anchors_preset(Control.PRESET_FULL_RECT)
	column.alignment = BoxContainer.ALIGNMENT_CENTER
	column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	chip.add_child(column)
	var slot := make_label(
		"SLOT %02d" % (HeroDefinition.DEFINITION_IDS.size() + index + 1),
		"label_s",
		AegisTokens.LINE_HI
	)
	slot.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	slot.autowrap_mode = TextServer.AUTOWRAP_OFF
	column.add_child(slot)
	return chip


## The model stage. It is a plain Control so the 3D viewport can fill it while
## the panels stay in the 2D layer above it.
func _build_showcase() -> void:
	_showcase_holder = Control.new()
	_showcase_holder.name = &"ShowcaseHolder"
	_showcase_holder.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_showcase_holder.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_showcase_holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_showcase_holder.clip_contents = false
	_body_portrait.add_child(_showcase_holder)

	_showcase = ShowcaseViewportScript.new()
	_showcase.name = &"HeroShowcase"
	_showcase.set_anchors_preset(Control.PRESET_FULL_RECT)
	_showcase_holder.add_child(_showcase)


func _build_panel() -> void:
	_panel = AegisPanel.new()
	_panel.interactive = false
	_panel.accent_side = "top"
	_panel.accent_color = AegisTokens.INFO
	_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_body_portrait.add_child(_panel)

	var column := VBoxContainer.new()
	physical_separation(column, 10)
	_panel.add_child(column)

	# The operative's name is the card's heading, so it is inside the card. The
	# first capture had it floating 70 px above the card, and the card's top edge
	# cut through the roster line under it.
	_name_label = make_label("", "display_m", AegisTokens.INK)
	_name_label.autowrap_mode = TextServer.AUTOWRAP_OFF
	_limit_lines(_name_label, 1)
	column.add_child(_name_label)

	# Says out loud what the empty squares are. The roster is one operative in
	# this build; the slots are the plan, not content. Wrapped, not clipped: this
	# was the widest single-line text on the screen (334 px at 13 px with 10 px
	# tracking) and, with autowrap off, its width was the *minimum width* of the
	# whole column -- 370 px of panel on a 360 px phone.
	_development_label = make_label(
		"%d OPERATIVE SLOT%s IN DEVELOPMENT" % [LOCKED_SLOTS, "" if LOCKED_SLOTS == 1 else "S"],
		"label_s",
		AegisTokens.INK_3
	)
	_development_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_limit_lines(_development_label, 1)
	column.add_child(_development_label)

	# Single-line with an ellipsis, not wrapping: a wrapped Label reports a
	# minimum height that ignores its extra lines, so a PanelContainer sized from
	# it draws smaller than its own text -- which is exactly what the first
	# capture showed, with the blurb floating above the card's top edge.
	_role_label = make_label("", "body_s", AegisTokens.INK_2)
	_role_label.autowrap_mode = TextServer.AUTOWRAP_OFF
	_role_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_limit_lines(_role_label, 1)
	_role_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	column.add_child(_role_label)

	_loadout_label = make_label("", "label_s", AegisTokens.INK_3)
	_loadout_label.autowrap_mode = TextServer.AUTOWRAP_OFF
	_loadout_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_limit_lines(_loadout_label, 1)
	_loadout_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	column.add_child(_loadout_label)

	_weapon_row = VBoxContainer.new()
	_weapon_row.name = &"WeaponRail"
	physical_separation(_weapon_row, 8)
	column.add_child(_weapon_row)
	for definition in WeaponDefinition.load_all_definitions():
		_weapon_row.add_child(_build_weapon_pin(definition))
	# The numbers are printed straight from the WeaponDefinition: if this line
	# and the resource ever disagree, the screen is lying about damage.
	_weapon_stat = make_label("", "label_s", AegisTokens.INK_3)
	# Marked `stat_line` because it *is* the loadout's stat line, the same role
	# the WEAPON page's panel had before the rail moved here; the data test reads
	# every marked line and compares it with the WeaponDefinition.
	_weapon_stat.set_meta("stat_line", true)
	_weapon_stat.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_limit_lines(_weapon_stat, 1)
	column.add_child(_weapon_stat)


## The two buttons are a row of their own under the information card, the way the
## dashboard puts DEPLOY above its secondary controls. Keeping them out of the
## card also keeps the card's height a function of two text lines.
func _build_actions() -> void:
	_actions = HBoxContainer.new()
	physical_separation(_actions, 14)
	# Parented here, in the portrait arrangement, exactly like the other blocks:
	# `_apply_orientation()` returns early when the orientation has not changed,
	# so a first layout must not depend on it to put anything in the tree.
	_body_portrait.add_child(_actions)

	_select_button = make_button("EQUIPPED", "round", "Keep this operative selected")
	_select_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	physical_min_size(_select_button, 0.0, AegisTokens.MIN_TOUCH_PX)
	_select_button.pressed.connect(_on_select_pressed)
	_actions.add_child(_select_button)

	_continue = make_button("CONTINUE", "primary", "Choose a weapon")
	_continue.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	physical_min_size(_continue, 0.0, AegisTokens.MIN_TOUCH_PX)
	_continue.pressed.connect(_on_continue_pressed)
	_actions.add_child(_continue)


# --- state ------------------------------------------------------------------ #


func _refresh() -> void:
	for card in _cards:
		var id := StringName(str(card.get_meta("hero_id", "")))
		var selectable := ProgressionService.HERO_IDS.has(id)
		card.disabled = not selectable
		card.edge_active = id == _selected and selectable
		card.set_pressed_no_signal(id == _selected and selectable)
	# SELECT means "this is not the saved choice yet"; EQUIPPED means it is, and
	# is disabled because there is nothing left to confirm.
	var progression := progression_service()
	var saved := progression.selected_hero_id if progression != null else _selected
	_select_requested = StringName(saved) != _selected
	_continue.disabled = not ProgressionService.HERO_IDS.has(_selected)
	_select_button.text = "SELECT" if _select_requested else "EQUIPPED"
	_select_button.disabled = not _select_requested
	_select_button.tooltip_text = (
		"Confirm %s" % _hero_name(_selected)
		if _select_requested
		else "%s is equipped" % _hero_name(_selected)
	)
	_refresh_weapons(progression)


## Puts the selected hero's model on the stage and updates every panel line from
## the same definition. `reveal` is false when restoring a screen that was
## already showing this hero (a rotation or a profile refresh), so the animation
## does not replay for a resize.
func _present_selected(reveal: bool) -> void:
	var definition := HeroDefinition.load_definition(_selected)
	if definition == null:
		_showcase.clear_model()
		return
	if not is_instance_valid(definition.model_scene):
		_showcase.clear_model()
		return
	var already := _showcase.model_path() == definition.model_scene.resource_path
	if not already:
		var clips: Array = definition.showcase_clips
		(
			_showcase
			. present(
				definition.model_scene,
				{
					"fit_axis": 1,
					"height": SHOWCASE_HEIGHT,
					# The rig faces +Z; the camera sits on +Z looking at the origin,
					# so no yaw is what turns the hero towards the viewer. 180 was
					# inherited from ModelFitter's kit-model default and showed the
					# back of the operative in the first capture.
					"yaw": 0.0,
					"clips": clips,
				}
			)
		)
		_showcase.frame_to_fill(SHOWCASE_FILL, 0.06)
		if not reveal:
			_showcase.skip_reveal()
	_name_label.text = definition.display_name.to_upper()
	_status_label.text = definition.status_line.to_upper()
	_status_label.add_theme_color_override("font_color", AegisTokens.OK)
	_role_label.text = _first_sentence(definition.role_description)
	var progression := progression_service()
	if progression != null:
		_loadout_label.text = (
			"%s  ·  %s"
			% [
				_weapon_name(progression.selected_weapon_id),
				_world_name(progression.selected_world_id),
			]
		)


func _hero_name(hero_id: StringName) -> String:
	var definition := HeroDefinition.load_definition(hero_id)
	if definition != null:
		return definition.display_name
	return String(hero_id).replace("_", " ").capitalize()


func _weapon_name(weapon_id: StringName) -> String:
	var definition := WeaponDefinition.load_definition(weapon_id)
	if definition != null:
		return definition.display_name.to_upper()
	return String(weapon_id).to_upper()


func _world_name(world_id: StringName) -> String:
	var definition := WorldDefinition.load_definition(world_id)
	if definition != null:
		return definition.display_name.to_upper()
	return String(world_id).replace("_", " ").to_upper()


func _first_sentence(text: String) -> String:
	var trimmed := text.strip_edges().replace("\n", " ")
	var stop := trimmed.find(".")
	if stop > 0:
		return trimmed.substr(0, stop + 1)
	return trimmed


# --- interaction ------------------------------------------------------------ #


func _on_chip_pressed(hero_id: StringName) -> void:
	if hero_id == _selected:
		return
	_selected = hero_id
	_select_requested = false
	Sfx.play_ui(&"ui_click")
	# A chip pick changes what is on the stage, not what is saved: SELECT or
	# CONTINUE commits it. That is what makes the SELECT/EQUIPPED state mean
	# something instead of being a label that is always true.
	_refresh()
	_present_selected(true)


func _on_select_pressed() -> void:
	var progression := progression_service()
	if progression != null:
		progression.select_hero(_selected)
	_select_requested = false
	Sfx.play_ui(&"ui_click")
	_refresh()


func _on_continue_pressed() -> void:
	var progression := progression_service()
	if progression != null:
		progression.select_hero(_selected)
	completed.emit(&"WORLD", {})


# --- layout ----------------------------------------------------------------- #


func _on_resized() -> void:
	relayout()
	_orient_nodes(_cards + _locked)
	_apply_orientation()
	# Every resize, not only a rotation: the first layout is not a transition, so
	# anything reached only through `_apply_orientation()` would never run here.
	_apply_density()
	# The camera framing depends on how tall the stage is: a 96 px showcase
	# strip on a landscape phone needs the model pulled back, not cropped.
	if is_instance_valid(_showcase) and _showcase.has_model():
		_showcase.frame_to_fill(SHOWCASE_FILL, 0.06)


## Portrait stacks the carousel, the model and the panel. Landscape puts the
## model on the left and everything that is read or tapped on the right, because
## a 390 px tall screen cannot stack three bands and still show a hero.
func _apply_orientation() -> void:
	var landscape := is_landscape()
	if landscape == _landscape_built:
		return
	_landscape_built = landscape
	for block in [_carousel_wrap, _showcase_holder, _panel, _actions]:
		if block.get_parent() != null:
			block.get_parent().remove_child(block)
	if landscape:
		_stack.remove_child(_body_portrait)
		_stack.add_child(_body_landscape)
		_body_landscape.add_child(_col_left)
		_body_landscape.add_child(_col_right)
		_col_left.add_child(_showcase_holder)
		_col_right.add_child(_carousel_wrap)
		_col_right.add_child(_panel)
		_col_right.add_child(_actions)
		_panel.size_flags_vertical = Control.SIZE_SHRINK_END
		_showcase_holder.size_flags_vertical = Control.SIZE_EXPAND_FILL
	else:
		if _body_landscape.get_parent() == _stack:
			_stack.remove_child(_body_landscape)
		if _col_left.get_parent() == _body_landscape:
			_body_landscape.remove_child(_col_left)
		if _col_right.get_parent() == _body_landscape:
			_body_landscape.remove_child(_col_right)
		_stack.add_child(_body_portrait)
		_body_portrait.add_child(_carousel_wrap)
		_body_portrait.add_child(_showcase_holder)
		_body_portrait.add_child(_panel)
		_body_portrait.add_child(_actions)
		_panel.size_flags_vertical = Control.SIZE_SHRINK_END
	# Landscape has room for the full label; portrait shares the header with the
	# status line and clipped it to "SELECT OPER…" in the first capture.
	physical_min_size(_carousel, 0.0, 84.0 if landscape else 120.0)
	# The right-hand column had no width of its own, so it took the width of its
	# widest child and every line in the information card was ellipsised at ~250
	# px on a 1280 px screen ("2 OPERATIVE SLOTS IN...", "The operative fielded
	# by the...") while EQUIPPED and CONTINUE, whose minimums add to 376, spilled
	# over each other. A rail with a width of its own is the fix the capture
	# asked for; the model keeps the rest of the canvas.
	_col_right.size_flags_horizontal = Control.SIZE_SHRINK_END
	if landscape:
		var rail := 340.0 if physical_size().y < 520.0 else minf(440.0, physical_size().x * 0.36)
		_col_right.custom_minimum_size.x = px(rail)


## The model is the subject, so when height is short the *chrome* gives way, not
## the showcase: chips shrink to 64 px, the caption goes, and the information
## card keeps two lines. DEPLOY-scale buttons never shrink -- they are the
## controls a thumb has to hit on a phone.
func _apply_density() -> void:
	if _chrome != null:
		_chrome.refit()
	var width := physical_size().x
	# A 390 px tall landscape screen has no room under the operative for three
	# 52 px chips: they drew 104 px tall at y=333 and the last line of the panel
	# fell off the bottom. The armory swaps weapons, and the stat line below
	# still names what is equipped, so the rail gives way -- copy before
	# controls, and a control that cannot be reached is not a control.
	var short_landscape := is_landscape() and physical_size().y < 520.0
	if is_instance_valid(_weapon_row):
		_weapon_row.visible = not short_landscape
	# On a 390 px tall landscape screen the two action buttons were 19 px past the
	# bottom edge; this line is the 21 px that pays for them.
	if is_instance_valid(_development_label):
		_development_label.visible = not short_landscape
	# Two more lines that restate what is already on screen: the role is the
	# card's own subtitle and the loadout is the rail. On 390 px of height they
	# are the difference between the buttons fitting and not.
	if is_instance_valid(_role_label):
		_role_label.visible = not short_landscape
	if is_instance_valid(_loadout_label):
		_loadout_label.visible = not short_landscape
	if is_instance_valid(_weapon_stat):
		# The stat line is one more row than the old header had, and on 390 px of
		# height it was the row that pushed EQUIPPED/CONTINUE past the bottom edge.
		_weapon_stat.visible = not short_landscape
	for pin in _weapon_pins:
		# 64 px is the project's touch floor (`AegisTokens.MIN_TOUCH_PX`); 52 was
		# under it on every portrait size the suite measures.
		# "NOVA LAUNCHER · 120 BP" is three lines in a 143 px chip; 64 px clipped
		# the third. 76 is still above the touch floor and fits the text.
		physical_min_size(
			pin,
			0.0,
			AegisTokens.MIN_TOUCH_PX if is_landscape() else maxf(AegisTokens.MIN_TOUCH_PX, 76.0),
		)
	# A phone in portrait has 640-844 px of height and three 64 px chips is 192 of
	# it: the action row landed 14 px below the bottom edge. What a phone shows
	# is the gun it will deploy with; the other two are priced, disabled and
	# named in the armory, which is where buying happens anyway.
	var room_for_rail := physical_size().y >= (520.0 if is_landscape() else 900.0)
	_orient_rail(physical_size().x >= 720.0)
	for pin in _weapon_pins:
		var owned := true
		var progression := progression_service()
		if progression != null:
			owned = progression.is_unlocked(StringName(str(pin.get_meta("weapon_id", ""))))
		pin.visible = owned or room_for_rail
	# A row of three chips is only honest when there is room for three; below
	# that they stack, full width, and the loadout reads as a list of choices
	# rather than three clipped words.
	# A column, always: a `vertical` flag is not a container class, and the flag
	# silently did nothing on this build. The rail is a list of choices.
	if is_instance_valid(_carousel_wrap):
		_carousel_wrap.visible = not short_landscape
	var short_screen := physical_size().y < (520.0 if is_landscape() else 760.0)
	# Same trade as the old WEAPON page: on a portrait phone the header keeps BACK and the
	# heading, and the field-ready state lives on the card itself.
	_status_label.visible = is_landscape() or physical_size().x >= 560.0
	# 64 px chips clipped their own slot label: "SLOT 02" is 71 px at the current
	# `label_s` size, and menu_layout_smoke asserted exactly that on the pushed
	# build (text 548,142 71x20 in card 548,120 64x64). A 390 px tall landscape
	# screen does not get its height back from a control that has to stay wide
	# enough to be read and tapped; it gets it from copy, which is what the three
	# lines below give up instead.
	var compact_chip := Vector2(84.0, 84.0)
	for chip in _cards + _locked:
		var control := chip as Control
		if control == null:
			continue
		if control.has_meta("px_landscape"):
			control.set_meta("px_portrait", compact_chip)
			control.set_meta("px_landscape", compact_chip)
		physical_min_size(control, compact_chip.x, compact_chip.y)
	# Landscape has room for the full label; portrait shares the header with the
	# status line and clipped it to "SELECT OPER…" when it did not fit.
	# A 390 px tall landscape screen cannot hold the heading, the showcase, the
	# carousel, three panel lines and two 64 px actions. The two descriptive
	# lines are the part that goes: the name above them already says what the
	# operative is, and the panel keeps the actions it exists to reach.
	_development_label.visible = not short_screen
	_role_label.visible = not short_screen
	_loadout_label.visible = not short_screen
	physical_separation(_actions, 8.0 if short_screen else 14.0)
	physical_min_size(_continue, 0.0, AegisTokens.MIN_TOUCH_PX)
	_heading.text = "SELECT OPERATIVE" if is_landscape() else "OPERATIVE"
	# BACK + heading + status have to share 288 px on a 360 px phone. "OPERATIVE"
	# set in `display_m` is 208 of them, which is what pushed the heading to
	# x=162 and its right edge to 370 (menu_layout_smoke, 360x640). The heading
	# steps down one role there; the wording is the same.
	var narrow := physical_size().x < 420.0
	var heading_role := "heading" if narrow else "display_m"
	_heading.set_meta("aegis_role", heading_role)
	AegisTheme.resize_label(
		_heading,
		heading_role,
		maxi(AegisTheme.type_size(heading_role), _minimum_font_size(_stretch))
	)
	# 88 px of carousel plus 84 px chips plus the header, the panel and a 64 px
	# action row was 400 px of content on a 390 px screen -- the actions drew at
	# y=345. The carousel gives up 24 px and the chips 12 on a short landscape.
	var carousel_height := (
		64.0 if (short_screen and is_landscape()) else (88.0 if short_screen else 120.0)
	)
	physical_min_size(_carousel, 0.0, carousel_height)
	physical_min_size(_carousel_wrap, 0.0, 0.0)
	physical_separation(_stack, 8.0 if short_screen else 14.0)
	physical_separation(_body_portrait, 8.0 if short_screen else 14.0)
	physical_separation(_carousel_wrap, 4.0 if short_screen else 10.0)
