## Base class for one screen of the front-end journey.
##
## The journey is BOOT -> LOADING -> CINEMATIC -> CHAPTER -> DASHBOARD -> HERO
## -> WEAPON -> WORLD -> PRELOAD -> gameplay. A stage owns its own layout and
## its own input, and knows nothing about the others: it finishes by emitting
## `completed` with the name of the stage it wants next, and `FrontEnd` decides
## whether that request is legal. Keeping the decision in one place is what
## stops a stage from being reachable out of order (a dashboard that appears
## before the profile is read, a preload that runs before a world is chosen).
class_name MenuStage
extends Control

## `next_stage` is a StringName key into FrontEnd.STAGE_SCENES. `payload` is
## handed to the next stage's `enter()` untouched.
signal completed(next_stage: StringName, payload: Dictionary)

## How far a thumb has to travel before this is a scroll and not a tap. The
## engine's own default for the same decision (`gui/common/scroll_deadzone`).
const SCROLL_DEADZONE := 10.0

## Widest a landscape card may be. Wide enough for a plate and two lines of
## text, narrow enough that two of them fit on an 844 px wide screen.
const LANDSCAPE_CARD_WIDTH := 340.0

## Set by FrontEnd when the stage is instantiated, before `enter()` runs.
## Typed as Node rather than FrontEnd because the two cannot preload each other;
## `progression_service()` is the typed way back to the profile.
var front_end: Node = null
## Whatever the previous stage passed along. Empty on the first stage.
var payload: Dictionary = {}
## The card list's scroll container, registered by `_make_card_list()`.
var _card_scroll: ScrollContainer = null
## The stage's primary action (DEPLOY, CONTINUE, LAUNCH), remembered by
## `make_button()` so it can take focus when the stage opens.
var _primary_button: AegisButton = null
## Thumb-drag state for `_card_scroll`. See `_input()` for why this exists.
var _card_drag_index := -1
var _card_drag_start := Vector2.ZERO
var _card_drag_active := false

## Full-rect safe-area container every screen lays out in, created by
## `make_margin()`. Stored so `enter()` can re-apply the margins on a resize or
## a rotation without searching the tree for it.
var _margin: MarginContainer = null
## Current canvas scale, refreshed by `_refresh_metrics()`.
##
## The project stretches a 1280x720 canvas to the window with aspect=expand, so
## on a 390x844 phone the canvas is 1280x2770 at 0.305 scale. A button authored
## as 60 units tall reaches the screen 18 px tall, and a 24 px separation lands
## at 7. Every menu size is therefore authored in physical pixels and converted
## through `px()`; the menus inherit the same rule the combat HUD uses.
var _stretch := 1.0


## Called every time the stage becomes visible, with the payload from the
## previous stage. Re-entering a stage (DASHBOARD -> HERO -> back) runs this
## again, so it must be safe to call twice.
## Connects `resized` once per stage, however many times the stage is entered.
##
## Stages are entered over and over in one session -- HERO to DASHBOARD and
## back, WEAPON to HERO and back -- and every one of them connected `resized`
## from `enter()`. The second visit stacked a second handler: Godot printed
## "Signal 'resized' is already connected to given callable" and every later
## resize ran that stage's layout twice, once more per revisit. Guarding it here
## keeps the connect where it is and makes the mistake hard to repeat.
func _connect_resized(callable: Callable) -> void:
	if not resized.is_connected(callable):
		resized.connect(callable)


func enter(_stage_payload: Dictionary) -> void:
	pass


## Called when the stage is hidden. Stages are kept alive and re-shown rather
## than freed, so this must leave the stage in a state `enter()` can restart
## from.
func exit() -> void:
	pass


# --- shared metrics --------------------------------------------------------- #


## Physical window size, falling back to the viewport when there is no real
## window (headless runs report a 64x64 dummy, which would make every layout
## decision wrong in the same way UiLayout guards against it).
func physical_size() -> Vector2:
	var window := get_window()
	if is_instance_valid(window):
		var window_size := Vector2(window.size)
		if window_size.x >= 320.0 and window_size.y >= 320.0:
			return window_size
	return Vector2(get_viewport_rect().size)


## Uniform canvas scale: how many physical pixels one layout unit occupies.
func _stretch_factor(physical: Vector2) -> float:
	return UiLayout.compute_stretch(self, physical)


func _to_layout(physical_pixels: float, stretch: float) -> float:
	return physical_pixels / maxf(stretch, 0.0001)


## (left, right, bottom) in physical pixels. Menus use the same function the
## combat HUD uses, so a notch or a gesture bar is respected in both instead of
## being handled twice and drifting apart.
func _safe_insets(physical: Vector2) -> Vector3:
	return UiLayout.measure_safe_insets(physical, _touch_mode())


func _touch_mode() -> bool:
	return DisplayServer.is_touchscreen_available()


## Mirrors TouchControls._resolve_top_inset: the web shell keeps one browser
## toggle on screen, and a notch pushes content down further.
func _top_inset() -> float:
	var inset := 12.0 if _touch_mode() else 20.0
	if OS.has_feature("web"):
		inset = maxf(inset, 30.0)
	var safe_area := DisplayServer.get_display_safe_area()
	if safe_area.position.y > 0:
		inset = maxf(inset, float(safe_area.position.y))
	return px(inset)


## Smallest font that still renders at AegisTokens.MIN_PHYSICAL_FONT_PX on the
## real screen. Menus inherit the HUD's readability floor on purpose.
func _minimum_font_size(stretch: float) -> int:
	return maxi(roundi(AegisTokens.MIN_PHYSICAL_FONT_PX / maxf(stretch, 0.0001)), 11)


# --- shared widgets --------------------------------------------------------- #


func make_label(text: String, role: String, color: Color, scale: float = 1.0) -> Label:
	var label := Label.new()
	label.text = text
	label.set_meta("aegis_role", role)
	label.set_meta("aegis_scale", scale)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	AegisTheme.style_label(label, role, color, scale)
	return label


func make_button(
	text: String, variant: String, tooltip: String = "", role: String = "title"
) -> AegisButton:
	var button := AegisButton.new()
	button.text = text
	button.focus_mode = Control.FOCUS_ALL
	button.mouse_filter = Control.MOUSE_FILTER_STOP
	button.set_meta("aegis_role", role)
	AegisTheme.set_button_variant(button, variant)
	if variant == "primary":
		_primary_button = button
		# Open the stage with its primary action focused, so ui_accept
		# (Enter/Space) activates it. Two reasons, both measured:
		#   * a keyboard or gamepad player gets a default action instead of
		#     having to Tab to it, which is what every other screen does;
		#   * the browser QA can then walk the front-end journey with one Enter
		#     per stage. A Godot canvas has no DOM to query, the stages set
		#     mouse_filter = MOUSE_FILTER_STOP so a click is absorbed by the
		#     GUI before the stage's _unhandled_input() sees it, and the
		#     button's global rect reads 0,0 while it is inside the front-end
		#     viewport — see docs/AUDIT_2026-10-21.md §12.3 for the three
		#     approaches that were measured and did not work.
		# Deferred: the button has to be in the tree before it can take focus.
		button.grab_focus.call_deferred()
	if not tooltip.is_empty():
		button.tooltip_text = tooltip
	return button


## Enter activates the primary action even when nothing holds GUI focus.
##
## `grab_focus()` above is best effort: `Control.grab_focus()` refuses unless
## the OS window already owns keyboard focus (Godot's own error is "Can't grab
## focus on control outside the focused window"), and a freshly loaded web
## page is exactly that case — the canvas has not been clicked yet. `ui_accept`
## is therefore caught at the scene level as well, or a menu would be
## keyboard-dead until the player clicks it. When a button *does* hold focus
## the GUI consumes the event first, so this never double-fires.
func _unhandled_input(event: InputEvent) -> void:
	if not event.is_action_pressed("ui_accept"):
		return
	if (
		not is_instance_valid(_primary_button)
		or _primary_button.disabled
		or not _primary_button.is_visible_in_tree()
	):
		return
	_primary_button.pressed.emit()
	get_viewport().set_input_as_handled()


func _refresh_metrics() -> float:
	_stretch = _stretch_factor(physical_size())
	return _stretch


## Layout units that render as `physical_pixels` on the real screen.
func px(physical_pixels: float) -> float:
	return physical_pixels / maxf(_stretch, 0.0001)


## Minimum comfortable touch target (AegisTokens.MIN_TOUCH_PX), in layout units.
func touch_height() -> float:
	return px(AegisTokens.MIN_TOUCH_PX)


## Standard gap between stacked actions.
func gap() -> float:
	return px(AegisTokens.TOUCH_GAP_PX)


## Authors a minimum size in physical pixels and stamps it, so a window resize
## or a rotation can re-convert it without rebuilding the tree.
func physical_min_size(control: Control, width: float, height: float) -> void:
	control.set_meta("px_w", width)
	control.set_meta("px_h", height)
	control.custom_minimum_size = Vector2(px(width), px(height))


func physical_separation(container: Container, physical_pixels: float) -> void:
	container.set_meta("px_sep", physical_pixels)
	container.add_theme_constant_override("separation", roundi(px(physical_pixels)))


## Re-converts every size authored through `physical_min_size` /
## `physical_separation`. Bound to the stage's own `resized` signal.
func _reapply_physical_sizes(root: Node) -> void:
	if root is Control and root.has_meta("px_w"):
		var control := root as Control
		control.custom_minimum_size = Vector2(
			px(float(control.get_meta("px_w"))), px(float(control.get_meta("px_h")))
		)
	if root is Container and root.has_meta("px_sep"):
		(root as Container).add_theme_constant_override(
			"separation", roundi(px(float(root.get_meta("px_sep"))))
		)
	for child in root.get_children():
		_reapply_physical_sizes(child)


## The one call a stage makes when its size changes: re-measure, re-scale every
## physical size, and re-apply the readability floor.
func relayout() -> void:
	_refresh_metrics()
	_reapply_physical_sizes(self)
	enforce_font_floor(self, _stretch)


## True when the display is meaningfully wider than it is tall.
##
## A phone held sideways reports something like 844x390. The same vertical
## stack that reads well in portrait is then ~500 px tall on a 390 px screen,
## which is what put DEPLOY and CONTINUE off the bottom edge in the QA
## measurements. Every selection screen and the dashboard branch on this.
func is_landscape() -> bool:
	var size := physical_size()
	return size.x > size.y * 1.2


## Authors two sizes for a control, portrait and landscape, and applies the
## portrait one now. `_orient_nodes()` picks the right one on every relayout, so
## a rotation re-sizes the node instead of the tree being rebuilt.
func _size_both(control: Control, portrait: Vector2, landscape: Vector2) -> void:
	control.set_meta("px_portrait", portrait)
	control.set_meta("px_landscape", landscape)
	physical_min_size(control, portrait.x, portrait.y)


## Re-applies whichever of the two sizes `_size_both()` recorded matches the
## screen right now.
func _orient_nodes(nodes: Array) -> void:
	var landscape := is_landscape()
	for node in nodes:
		var control := node as Control
		if control == null or not control.has_meta("px_landscape"):
			continue
		var wanted: Vector2 = control.get_meta("px_landscape" if landscape else "px_portrait")
		physical_min_size(control, wanted.x, wanted.y)


## Builds the two list containers a selection screen needs -- a column for
## portrait, a row for landscape -- inside `scroll`, and returns them keyed as
## `column`, `row` and `scroll`. Both are built up front so a rotation only
## moves cards between them.
func _make_card_list(scroll: ScrollContainer) -> Dictionary:
	var host := VBoxContainer.new()
	host.mouse_filter = Control.MOUSE_FILTER_IGNORE
	host.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	host.size_flags_vertical = Control.SIZE_EXPAND_FILL
	physical_separation(host, 0)
	scroll.add_child(host)

	var column := VBoxContainer.new()
	column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	physical_separation(column, 12)
	host.add_child(column)

	var row := HBoxContainer.new()
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.visible = false
	physical_separation(row, 12)
	host.add_child(row)
	_card_scroll = scroll
	# Screen events only reach `_input()` on a node that processes input.
	set_process_input(true)
	return {"scroll": scroll, "column": column, "row": row}


## Moves `cards` into the list container that matches the current orientation,
## re-sizes each one through `_size_both()`'s metas, and points the scroll
## container down the axis that now overflows. Returns the list in use.
##
## Portrait is one card per row, full width. Landscape is a row of
## LANDSCAPE_CARD_WIDTH cards that scrolls sideways: a 390 px tall screen only
## leaves ~130 px of height for the list once the heading and the footer are
## placed, and a column of cards in that window is unusable.
func _orient_card_list(lists: Dictionary, cards: Array) -> BoxContainer:
	var landscape := is_landscape()
	var column: BoxContainer = lists["column"]
	var row: BoxContainer = lists["row"]
	var active: BoxContainer = row if landscape else column
	for card in cards:
		var control := card as Control
		if control == null:
			continue
		if control.get_parent() != active:
			if control.get_parent() != null:
				control.get_parent().remove_child(control)
			active.add_child(control)
		_orient_nodes([control])
	column.visible = not landscape
	row.visible = landscape
	var scroll: ScrollContainer = lists["scroll"]
	scroll.horizontal_scroll_mode = (
		ScrollContainer.SCROLL_MODE_AUTO if landscape else ScrollContainer.SCROLL_MODE_DISABLED
	)
	scroll.vertical_scroll_mode = (
		ScrollContainer.SCROLL_MODE_DISABLED if landscape else ScrollContainer.SCROLL_MODE_AUTO
	)
	return active


## Builds the landscape half of a selection screen: a fixed-width info column
## that sits beside the card list, so the heading and the footer stop stealing
## height from the cards on a 390 px tall screen.
func _make_selection_split(info_width: float) -> Dictionary:
	var split := HBoxContainer.new()
	# EXPAND, not the default FILL: a box container only hands a child more
	# than its minimum size when the child asks to expand, and the split has to
	# own the full height or the card list keeps its minimum ~200 px instead of
	# the 284 px a landscape phone actually has.
	split.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	split.size_flags_vertical = Control.SIZE_EXPAND_FILL
	physical_separation(split, 18)
	var info := VBoxContainer.new()
	# SHRINK_BEGIN, not the default FILL: the column keeps its authored width
	# and the card list takes everything that is left.
	info.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	info.size_flags_vertical = Control.SIZE_EXPAND_FILL
	physical_separation(info, 14)
	_size_both(info, Vector2(info_width, 0.0), Vector2(info_width, 0.0))
	# Remembered for `_orient_selection`, which narrows the column on a wide
	# screen every time the stage is resized.
	info.set_meta("aegis_info_width", info_width)
	split.add_child(info)
	return {"split": split, "info": info}


## Arranges a selection screen for the orientation the device is in.
##
## `above` and `below` are the blocks in portrait reading order around the card
## list: heading and summary above it, the explanatory note and the footer
## below it. Portrait stacks them all in `stack`; landscape puts the text in
## `info` -- heading and summary at the top, footer at the bottom -- and moves
## the list beside it, where it has the full 284 px of height a landscape phone
## has to offer instead of the ~130 px left over underneath a stacked header.
func _orient_selection(
	stack: VBoxContainer,
	split: HBoxContainer,
	info: VBoxContainer,
	scroll: ScrollContainer,
	above: Array,
	below: Array
) -> void:
	var landscape := is_landscape()
	# Wide screens get a narrower info column so the card list keeps most of the
	# width: 300 px is a third of a landscape phone but only a quarter of a
	# 1280 px desktop.
	var wide: float = info.get_meta("aegis_info_width", 300.0)
	physical_min_size(info, minf(wide, physical_size().x * 0.4), 0.0)
	if stack.has_meta("aegis_landscape") and bool(stack.get_meta("aegis_landscape")) == landscape:
		return
	stack.set_meta("aegis_landscape", landscape)
	for block in above + below:
		var control := block as Control
		if control.get_parent() != null:
			control.get_parent().remove_child(control)
	if scroll.get_parent() != null:
		scroll.get_parent().remove_child(scroll)
	if landscape:
		if split.get_parent() != stack:
			stack.add_child(split)
		for block in above:
			info.add_child(block)
		var spacer := Control.new()
		spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
		spacer.set_meta("aegis_spacer", true)
		info.add_child(spacer)
		for block in below:
			info.add_child(block)
		split.add_child(scroll)
		return
	if split.get_parent() == stack:
		stack.remove_child(split)
	if scroll.get_parent() == split:
		split.remove_child(scroll)
	for child in info.get_children():
		info.remove_child(child)
		if bool(child.get_meta("aegis_spacer", false)):
			child.queue_free()
	for block in above:
		stack.add_child(block)
	stack.add_child(scroll)
	for block in below:
		stack.add_child(block)


## A line of text inside a card.
##
## Autowrap plus a zero minimum width lets the container shrink the text to the
## card instead of the card growing to the text. Measured on a 390x844 frame:
## an unconstrained stat line inside a 318 px card reported 614 px wide, and a
## row of three 240 px cards forced every label on the screen -- headers
## included -- to 753 px, twice the width of the display.
func card_line(text: String, role: String, color: Color) -> Label:
	var label := make_label(text, role, color)
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	physical_min_size(label, 0.0, 0.0)
	return label


## Creates the full-rect safe-area container a menu screen lays out in.
func make_margin() -> MarginContainer:
	_margin = MarginContainer.new()
	_margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	_margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_margin)
	return _margin


## Push a container's margins out to the safe area plus a comfortable inset.
## Every menu screen calls this so the reserved edge is defined once.
func apply_safe_margins(
	container: MarginContainer, extra_side: float = 28.0, extra_bottom: float = 24.0
) -> void:
	_refresh_metrics()
	var insets := _safe_insets(physical_size())
	container.add_theme_constant_override(
		"margin_left", roundi(px(maxf(insets.x, 0.0) + extra_side))
	)
	container.add_theme_constant_override(
		"margin_right", roundi(px(maxf(insets.y, 0.0) + extra_side))
	)
	container.add_theme_constant_override(
		"margin_bottom", roundi(px(maxf(insets.z, 0.0) + extra_bottom))
	)
	container.add_theme_constant_override("margin_top", roundi(_top_inset() + px(24.0)))


## Grow every font under `root` so it renders at MIN_PHYSICAL_FONT_PX on the
## real screen. Type roles are authored in logical units for a 1280x720 canvas;
## on a phone the canvas is scaled down and a 15 px title lands at ~7 physical
## pixels, which reads as broken rather than small.
func enforce_font_floor(root: Node, stretch: float) -> void:
	var floor_size := _minimum_font_size(stretch)
	if root is Label:
		_grow_label(root, floor_size)
	elif root is Button:
		_grow_button(root as Button, floor_size)
	for child in root.find_children("*", "", true, false):
		if child is Label:
			_grow_label(child, floor_size)
		elif child is Button:
			_grow_button(child, floor_size)


func _grow_label(label: Label, floor_size: int) -> void:
	var role := str(label.get_meta("aegis_role", "body"))
	var scale := float(label.get_meta("aegis_scale", 1.0))
	var wanted := maxi(roundi(float(AegisTheme.type_size(role)) * scale), floor_size)
	if label.get_theme_font_size("font_size") < wanted:
		AegisTheme.resize_label(label, role, wanted)


func _grow_button(button: Button, floor_size: int) -> void:
	var role := str(button.get_meta("aegis_role", "title"))
	var wanted := maxi(AegisTheme.type_size(role), floor_size)
	if button.get_theme_font_size("font_size") < wanted:
		AegisTheme.resize_button_font(button, role, wanted)


## Full-bleed backdrop. `cover` keeps the art's aspect and lets the long edge
## run off-screen, which is what the 16:9 key art expects on a tall phone.
func make_backdrop(texture_path: String) -> TextureRect:
	var rect := TextureRect.new()
	rect.texture = try_texture(texture_path)
	rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return rect


## Loads a texture only if it exists. The front end must never hard-fail on
## missing art: a missing plate is a visual regression, a crash is not.
func try_texture(texture_path: String) -> Texture2D:
	if texture_path.is_empty() or not ResourceLoader.exists(texture_path):
		return null
	return load(texture_path) as Texture2D


## Loads a video only if it exists. Same contract as `try_texture()`: the
## front end must never hard-fail on missing art. A stage that wants a video
## keeps its composed fallback and checks what came back.
func try_video(video_path: String) -> VideoStream:
	if video_path.is_empty() or not ResourceLoader.exists(video_path):
		return null
	return load(video_path) as VideoStream


## The persistent profile the front end owns, or null if this stage is being
## driven by a test that never attached a FrontEnd.
func progression_service() -> ProgressionService:
	if front_end == null:
		return null
	return front_end.get("progression_service") as ProgressionService


## Thumb scrolling for the card list, because the engine will not do it here.
##
## Godot 4.7's `ScrollContainer` pans on `InputEventMouseButton` +
## `InputEventMouseMotion` and on nothing else (scene/gui/scroll_container.cpp,
## from line 237): the screen-drag path is gone. On a phone that still works
## while `input_devices/pointing/emulate_mouse_from_touch` is on, because
## `Input` translates every screen event into a mouse event
## (core/input/input.cpp:908). This project turns that off deliberately -- the
## combat HUD reads raw screen events, and translating them would feed the
## joystick and the fire button twice -- so the row cannot be dragged: measured
## in a browser build with touch emulation, 24 screen drags with real deltas
## (rel = -36.9 px each) arrived at the engine, `is_touchscreen_available()`
## was true, the row had 1074 px of range, and it moved 0 px.
##
## Consequence without this: the third weapon card sits at canvas x 1050..1390
## in a window that ends at 809, and no thumb can reach it.
##
## It disables itself the moment the engine's own path is available again, so
## turning the project setting on later cannot produce double-speed scrolling.
func _input(event: InputEvent) -> void:
	if _card_scroll == null or Input.is_emulating_mouse_from_touch():
		return
	if not is_instance_valid(_card_scroll) or not _card_scroll.is_visible_in_tree():
		return
	if event is InputEventScreenTouch:
		_input_screen_touch(event)
	elif event is InputEventScreenDrag:
		_input_screen_drag(event)


func _input_screen_touch(event: InputEventScreenTouch) -> void:
	if event.is_pressed():
		if _card_drag_index != -1:
			return
		if not _card_scroll.get_global_rect().has_point(event.position):
			return
		# Not claimed: a press with no movement behind it is a tap, and the card
		# under the thumb has to be allowed to select.
		_card_drag_index = event.index
		_card_drag_start = event.position
		_card_drag_active = false
		return
	if event.index != _card_drag_index:
		return
	var dragged := _card_drag_active
	_card_drag_index = -1
	_card_drag_active = false
	if dragged:
		# Claim the release so the drag does not also select the card it started
		# on, and re-run the stage's refresh so no card is left looking pressed.
		get_viewport().set_input_as_handled()
		if has_method("refresh_profile"):
			call("refresh_profile")


func _input_screen_drag(event: InputEventScreenDrag) -> void:
	if event.index != _card_drag_index:
		return
	var travelled := event.position - _card_drag_start
	if not _card_drag_active and travelled.length() < SCROLL_DEADZONE:
		return
	_card_drag_active = true
	var horizontal := _card_scroll.horizontal_scroll_mode != ScrollContainer.SCROLL_MODE_DISABLED
	var vertical := _card_scroll.vertical_scroll_mode != ScrollContainer.SCROLL_MODE_DISABLED
	if horizontal:
		_card_scroll.scroll_horizontal -= event.relative.x
	if vertical:
		_card_scroll.scroll_vertical -= event.relative.y
	get_viewport().set_input_as_handled()
