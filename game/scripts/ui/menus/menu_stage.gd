## Base class for one screen of the front-end journey.
##
## The journey is BOOT -> LOADING -> CHAPTER -> DASHBOARD -> HERO -> WORLD
## -> PRELOAD -> gameplay. A stage owns its own layout and
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
const LANDSCAPE_CARD_WIDTH := 400.0

## Set by FrontEnd when the stage is instantiated, before `enter()` runs.
## Typed as Node rather than FrontEnd because the two cannot preload each other;
## `progression_service()` is the typed way back to the profile.
var front_end: Node = null
## Whatever the previous stage passed along. Empty on the first stage.
var payload: Dictionary = {}
## The card list's scroll container, registered by the stage that builds it.
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
## back, WORLD to HERO and back -- and every one of them connected `resized`
## from `enter()`. The second visit stacked a second handler: Godot printed
## "Signal 'resized' is already connected to given callable" and every later
## resize ran that stage's layout twice, once more per revisit. Guarding it here
## keeps the connect where it is and makes the mistake hard to repeat.
func _connect_resized(callable: Callable) -> void:
	if not resized.is_connected(callable):
		resized.connect(callable)


func enter(_stage_payload: Dictionary) -> void:
	pass


## Puts the keyboard/gamepad focus on this stage's primary action, called by
## FrontEnd right after `enter()`. Opening a screen with nothing focused makes a
## controller or a keyboard dead until the player clicks something, and the
## stages that override `enter()` would each have to remember to do it.
##
## Best effort on purpose: `Control.grab_focus()` refuses when the OS window does
## not own keyboard focus, which is the state of a freshly loaded web page. The
## `ui_accept` fallback in `_unhandled_input` is what keeps those players moving.
func focus_primary() -> void:
	if not is_instance_valid(_primary_button):
		return
	if not _primary_button.is_inside_tree() or not _primary_button.is_visible_in_tree():
		return
	_primary_button.grab_focus()


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
	# A stage drawn inside a SubViewport -- the layout probe in
	# `tests/menu_layout_smoke.gd` mounts the real front end in one and resizes
	# it -- is the size of *that* viewport, not of the window behind it. Reading
	# the window there made every stage lay out for the headless runner's
	# default window while the probe measured against 390x844, so the two
	# disagreed about every size and neither was wrong about the screen it saw.
	var viewport := get_viewport()
	if viewport is SubViewport:
		return Vector2(viewport.size)
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


## A label whose text is a catalog key. The key is kept on the control, so
## `AegisText.refresh()` can rewrite this screen in place when the language
## changes; nothing here reads a finished English string.
func make_label_key(key: String, role: String, color: Color, args: Array = []) -> Label:
	var label := make_label("", role, color)
	AegisText.apply(label, key, args)
	return label


## Same for a button, tooltip included, so the hover text never lags the label.
func make_button_key(
	key: String, variant: String, tip_key: String = "", role: String = "title"
) -> AegisButton:
	var button := make_button("", variant, "", role)
	AegisText.apply(button, key)
	if not tip_key.is_empty():
		AegisText.apply_tip(button, tip_key)
	return button


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
		#     viewport — see docs/DECISIONS.md §12.3 for the three
		#     approaches that were measured and did not work.
		# NOT here. Focus is taken by `focus_primary()` when FrontEnd actually
		# shows this stage. A deferred grab at construction time ran after the
		# scene had already been replaced -- every stage is instantiated up
		# front, including the ones a deep link never shows -- and Godot
		# printed `Condition "!is_inside_tree()" is true. at: grab_focus` on
		# every launch that skipped the front end.
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


## The front end is landscape-only, so every screen composes for it.
##
## A vertical stack is ~500 px tall on a phone on its side and that is what put
## DEPLOY and CONTINUE off the bottom edge in the QA measurements. Rather than
## maintaining a second arrangement nobody runs, a portrait window is refused
## by the shell's rotation notice and every screen here keeps the landscape
## composition at any window size.
func is_landscape() -> bool:
	return true


## Authors the one size a control has.
func _size(control: Control, size_px: Vector2) -> void:
	physical_min_size(control, size_px.x, size_px.y)


## Re-applies the authored size after a resize. The landscape size is the only
## one recorded, so this is now a re-measure rather than an orientation switch.
func _orient_nodes(nodes: Array) -> void:
	for node in nodes:
		var control := node as Control
		if control == null or not control.has_meta("px_landscape"):
			continue
		var wanted: Vector2 = control.get_meta("px_landscape")
		physical_min_size(control, wanted.x, wanted.y)


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


## Holds a line of card copy to `limit` lines with an ellipsis.
##
## Cards are buttons with children laid over them, so a child that grows does
## not grow the card -- it draws past the card's rounded edge and over whatever
## is below. The weapon list did exactly that at 390x844: the ARC SHOOTER's stat
## line ran out of its card and into the Battle Points legend. Fixed card
## heights are safe only if the copy has a bound, and this is the bound.
## A one-line label that is allowed to ellipsise should not claim its text as
## its *minimum* width: that is how a caption 20 px too long made a whole page
## wider than the phone it was drawn on. `clip_text` takes the text out of the
## minimum size calculation, and the overrun behaviour below still draws the
## ellipsis.
func _limit_lines(label: Label, limit: int) -> Label:
	label.max_lines_visible = limit
	label.clip_text = limit > 0
	label.text_overrun_behavior = (
		TextServer.OVERRUN_TRIM_ELLIPSIS if limit > 0 else TextServer.OVERRUN_NO_TRIMMING
	)
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
	container: MarginContainer,
	extra_side: float = 36.0,
	extra_bottom: float = 28.0,
	extra_top: float = 28.0
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
	container.add_theme_constant_override("margin_top", roundi(_top_inset() + px(extra_top)))


## The horizontal margin the stage's own layout container reserves, in physical
## pixels. Shared chrome asks for it instead of guessing a breakpoint: a dock
## that budgets the window and forgets the margin overflows by exactly that
## margin, which is how a 360 px page measured 362 px wide.
func margin_side() -> float:
	if not is_instance_valid(_margin):
		return 0.0
	var left := float(_margin.get_theme_constant(&"margin_left"))
	var right := float(_margin.get_theme_constant(&"margin_right"))
	return maxf(left, right) * _stretch


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
	# A wrapped Label reports the height of the *narrowest* layout it can be
	# squeezed into, so `max_lines_visible = 1` plus autowrap gives a container a
	# minimum height well under the line it draws. That is how HERO's information
	# card ended up 50 px tall around three 20 px lines, with the first and the
	# last drawn outside the card. A single-line label reserves one line, measured
	# from the font it will finally use.
	if label.max_lines_visible > 0:
		var font := label.get_theme_font("font")
		if font != null:
			var line := float(font.get_height(label.get_theme_font_size("font_size")))
			label.custom_minimum_size.y = maxf(label.custom_minimum_size.y, line)


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
