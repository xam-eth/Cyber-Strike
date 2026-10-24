## WEAPON SELECTION.
##
## Every number printed here is read off the WeaponDefinition resource at
## runtime -- damage, fire rate, magazine size, reload, range, splash and chain
## -- so the screen cannot drift from the weapon the player fires. Locked
## weapons are disabled and priced from ProgressionService.COSTS; unlocking
## happens in the Armory, which is the single place that spends Battle Points.
extends MenuStage

## The paths are not written out here a second time: `WeaponDefinition` owns
## them, and the player scene's weapon controller is authored from the same
## files. `data_source_smoke.gd` checks both sides agree.
const DEFINITIONS := WeaponDefinition.DEFINITION_PATHS
const PLATES := {
	&"pulse_rifle": "res://assets/ui/weapon_pulse_rifle.png",
	&"nova_launcher": "res://assets/ui/weapon_nova_launcher.png",
	&"arc_shooter": "res://assets/ui/weapon_arc_shooter.png",
}
## Presentation order, taken from the same registry rather than retyped.
const ORDER: Array[StringName] = WeaponDefinition.DEFINITION_IDS

var _cards: Dictionary = {}
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
var _continue: AegisButton
var _detail: Label
var _qa_scroll_hooked := false
var _qa_scroll := false


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(make_backdrop("res://assets/ui/dashboard_bg.jpg"))
	var scrim := ColorRect.new()
	scrim.color = Color(AegisTokens.VOID, 0.6)
	scrim.set_anchors_preset(Control.PRESET_FULL_RECT)
	scrim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(scrim)

	_stack = VBoxContainer.new()
	physical_separation(_stack, 14)
	make_margin().add_child(_stack)
	var split := _make_selection_split(300.0)
	_split = split["split"]
	_info = split["info"]

	var heading := card_line("SELECT WEAPON", "display_l", AegisTokens.INK)
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

	var group := ButtonGroup.new()
	for weapon_id in ORDER:
		var card := _build_card(weapon_id, group)
		_cards[weapon_id] = card
		_lists["column"].add_child(card)

	_detail = card_line("", "body_s", AegisTokens.INK_2)
	_stack.add_child(_detail)

	var footer := HBoxContainer.new()
	physical_separation(footer, 12)
	_stack.add_child(footer)
	_below = [_detail, footer]

	var back := make_button("BACK", "ghost", "Return to operative selection")
	back.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	physical_min_size(back, 0.0, 56.0)
	back.pressed.connect(func() -> void: completed.emit(&"HERO", {}))
	footer.add_child(back)

	_continue = make_button("CONTINUE", "primary", "Choose a world")
	_continue.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	physical_min_size(_continue, 0.0, 56.0)
	_continue.pressed.connect(func() -> void: completed.emit(&"WORLD", {}))
	footer.add_child(_continue)

	_connect_resized(_on_resized)
	relayout()


func enter(_stage_payload: Dictionary) -> void:
	apply_safe_margins(_margin)
	_on_resized()
	_refresh()


func refresh_profile() -> void:
	_refresh()


func _definition(weapon_id: StringName) -> WeaponDefinition:
	return WeaponDefinition.load_definition(weapon_id)


func _build_card(weapon_id: StringName, group: ButtonGroup) -> Control:
	var card := AegisButton.new()
	card.name = "%sCard" % String(weapon_id).to_pascal_case()
	card.button_group = group
	card.toggle_mode = true
	card.focus_mode = Control.FOCUS_ALL
	card.mouse_filter = Control.MOUSE_FILTER_STOP
	# 216 px holds a plate and four text lines in portrait; a landscape row
	# only has ~130 px of height, so the card is shorter and fixed-width there.
	_size_both(card, Vector2(0.0, 216.0), Vector2(LANDSCAPE_CARD_WIDTH, 216.0))
	_oriented.append(card)
	card.set_meta("weapon_id", String(weapon_id))
	card.pressed.connect(_on_card_pressed.bind(weapon_id))
	AegisTheme.set_button_variant(card, "round")

	var row := HBoxContainer.new()
	row.set_anchors_preset(Control.PRESET_FULL_RECT)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	physical_separation(row, 14)
	card.add_child(row)

	var plate := TextureRect.new()
	plate.texture = try_texture(PLATES[weapon_id])
	plate.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	plate.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	_size_both(plate, Vector2(110.0, 100.0), Vector2(100.0, 100.0))
	_oriented.append(plate)
	row.add_child(plate)

	var column := VBoxContainer.new()
	column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	physical_separation(column, 4)
	row.add_child(column)

	var definition := _definition(weapon_id)
	column.add_child(card_line(definition.display_name.to_upper(), "title", AegisTokens.INK))
	column.add_child(card_line(definition.role_description, "caption", AegisTokens.INK_2))

	var stats := card_line(_stat_line(definition), "mono_s", AegisTokens.INFO)
	stats.set_meta("stat_line", true)
	column.add_child(stats)

	var state := card_line("", "label_s", AegisTokens.OK)
	state.set_meta("state_line", true)
	column.add_child(state)
	return card


## Real values straight off the resource. `fire_rate` is shots per second in the
## definition, so it is printed as such rather than being converted into a
## number the file does not contain.
func _stat_line(definition: WeaponDefinition) -> String:
	var parts := [
		"DMG %s" % _trim(definition.damage),
		"RATE %s/s" % _trim(definition.fire_rate),
		"MAG %d" % definition.magazine_size,
		"RELOAD %ss" % _trim(definition.reload_seconds),
		"RNG %sm" % _trim(definition.max_range),
	]
	if definition.splash_damage > 0.0:
		parts.append(
			"SPLASH %s / %sm" % [_trim(definition.splash_damage), _trim(definition.splash_radius)]
		)
	if definition.chain_count > 0:
		parts.append("CHAIN %d" % definition.chain_count)
	return "  ·  ".join(parts)


func _trim(value: float) -> String:
	var text := "%.2f" % value
	while text.ends_with("0") and text.contains("."):
		text = text.substr(0, text.length() - 1)
	return text.substr(0, text.length() - 1) if text.ends_with(".") else text


func _refresh() -> void:
	var progression := progression_service()
	if progression == null:
		return
	var owned := 0
	for weapon_id in ORDER:
		var unlocked := progression.is_unlocked(weapon_id)
		if unlocked:
			owned += 1
		var card: AegisButton = _cards[weapon_id]
		var selected := progression.selected_weapon_id == weapon_id
		card.disabled = not unlocked
		card.edge_active = selected
		card.set_pressed_no_signal(selected)
		var state: Label = _find_meta(card, "state_line")
		if state == null:
			continue
		if unlocked:
			state.text = "EQUIPPED" if selected else "OWNED · TAP TO EQUIP"
			state.add_theme_color_override("font_color", AegisTokens.OK)
		else:
			var cost := progression.unlock_cost(weapon_id)
			state.text = "LOCKED · %d BP · UNLOCK IN ARMORY" % cost
			state.add_theme_color_override("font_color", AegisTokens.ACCENT)
	_summary.text = (
		"BATTLE POINTS  %d  ·  %d / %d WEAPONS" % [progression.balance, owned, ORDER.size()]
	)
	_detail.text = (
		"Battle Points are earned by defeating waves. Unlocks are permanent and "
		+ "stored in your profile."
	)


func _find_meta(root: Node, key: String) -> Label:
	if root.has_meta(key):
		return root as Label
	for child in root.find_children("*", "Label", true, false):
		if child.has_meta(key):
			return child
	return null


func _on_card_pressed(weapon_id: StringName) -> void:
	if _qa_scroll:
		print("MenuScroll: card pressed %s" % weapon_id)
	var progression := progression_service()
	if progression == null or not progression.select_weapon(weapon_id):
		return
	Sfx.play_ui(&"ui_click")
	_refresh()


func _on_resized() -> void:
	relayout()
	_hook_qa_scroll()
	if _qa_scroll:
		_report_qa_scroll("resized")
	_orient_nodes(_oriented)
	_orient_card_list(_lists, _cards.values())
	_orient_selection(_stack, _split, _info, _scroll, _above, _below)


## QA hook, web only: `?qa_scroll=1` prints the card row's horizontal offset
## whenever it moves.
##
## This exists because the gesture could not be tested any other way.
## `ScrollContainer` gates touch panning on `DisplayServer::is_touchscreen_
## available()` (`scene/gui/scroll_container.cpp`), which every headless display
## server reports as false, so a synthetic drag in a smoke test moves the row
## 0 px and proves nothing about a thumb. A browser with touch emulation does
## report it, and the offset printed here is what a drag in
## `tools/qa_touch_scroll.mjs` is measured against.
func _hook_qa_scroll() -> void:
	if _qa_scroll_hooked or not OS.has_feature("web"):
		return
	var wanted: Variant = JavaScriptBridge.eval(
		"new URLSearchParams(location.search).has('qa_scroll')"
	)
	if not bool(wanted):
		return
	var bar := _scroll.get_h_scroll_bar()
	if bar == null:
		return
	_qa_scroll = true
	# `ScrollContainer` pans on a screen drag only when the display server says
	# a touchscreen exists (scene/gui/scroll_container.cpp:237). Every headless
	# display server answers false; whether an emulated one answers true is the
	# difference between "the gesture is untested" and "the gesture is broken",
	# so the probe has to be able to read it.
	print("MenuScroll: is_touchscreen_available = %s" % DisplayServer.is_touchscreen_available())
	bar.value_changed.connect(_on_qa_scroll_changed)
	# Log the raw input too. "The row did not move" has two causes that look
	# identical from outside -- the drag never arrived, and the drag arrived and
	# was ignored -- and only the event log tells them apart.
	set_process_input(true)
	_qa_scroll_hooked = true
	_report_qa_scroll("hooked")


## Counts what actually reached the engine during a QA run.
func _input(event: InputEvent) -> void:
	# The base class drags the card list from these same events; overriding
	# `_input` without calling super silently switched that off.
	super._input(event)
	if not _qa_scroll:
		return
	if (
		event is InputEventScreenTouch
		or event is InputEventScreenDrag
		or event is InputEventMouseButton
		or event is InputEventPanGesture
		or (event is InputEventMouseMotion and (event as InputEventMouseMotion).button_mask != 0)
	):
		if event is InputEventScreenDrag:
			# Position and relative are the whole question: a drag that arrives
			# with no delta is an input-emulation artefact, a drag with a delta
			# that the row ignores is the game's problem.
			print(
				(
					"MenuScroll: input ScreenDrag index=%d pos=%s rel=%s"
					% [event.index, event.position, event.relative]
				)
			)
		else:
			print("MenuScroll: input %s" % event.as_text())


func _on_qa_scroll_changed(value: float) -> void:
	_report_qa_scroll("offset %.1f" % value)


## The container's own numbers, printed whenever the layout changes and whenever
## the bar moves, because "the row did not scroll" and "the row cannot scroll"
## look identical from outside and only the range tells them apart.
func _report_qa_scroll(what: String) -> void:
	# A frame late on purpose. `resized` fires before the containers have been
	# sorted for this frame, so a rect read inside it is still the previous
	# one -- 0x0 on the first pass, which is what made an unscrollable row and
	# an unmeasured row look the same.
	await get_tree().process_frame
	var bar := _scroll.get_h_scroll_bar()
	print(
		(
			"MenuScroll: %s, row %s, range %.1f, page %.1f"
			% [
				what,
				_scroll.get_global_rect(),
				bar.max_value if bar != null else -1.0,
				bar.page if bar != null else -1.0
			]
		)
	)
