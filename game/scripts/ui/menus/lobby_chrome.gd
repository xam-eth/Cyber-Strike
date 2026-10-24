## The lobby's shared chrome: one dock across every lobby page.
##
## Before this existed each stage drew its own header, so DASHBOARD had a
## wordmark and a wallet chip, HERO had a BACK button and a heading, and WORLD
## had neither -- three different top bars on one journey, and the empty band
## above the page content is exactly what a player reads as "not finished".
##
## The dock therefore carries what a lobby must always answer, on every page:
##
##   * where am I        -- the wordmark, and which of HOME / OPERATIVE / WORLD
##                          is live (amber edge, bright icon, others at 60 %);
##   * who am I         -- the operative plate: portrait, name, ready state;
##   * what do I have   -- the two figures the save file actually stores:
##                          battle points and completed runs, each with an icon
##                          and a numeral. Nothing here is invented: a third
##                          currency would be decoration lying about the
##                          profile;
##   * where do I go    -- the gear, which opens settings over any lobby page.
##
## Sizes are authored in *physical* pixels through `MenuStage.physical_min_size`
## and re-authored on every resize, so the same dock is 56 px tall on a phone
## held upright and 64 px on a desktop, not "whatever the theme happened to use
## at 1280x720".
class_name LobbyChrome
extends RefCounted

signal navigate(stage_name: StringName)
signal settings_requested

const TAB_HOME := &"HOME"
const TAB_OPERATIVE := &"OPERATIVE"
const TAB_WORLD := &"WORLD"

## tab id -> [label, icon]
const TABS := {
	TAB_HOME: ["HOME", "house"],
	TAB_OPERATIVE: ["OPERATIVE", "shield"],
	TAB_WORLD: ["THEATRE", "target"],
}

## Compressed below this physical width the tabs keep their icons and lose
## their words: a dock whose labels are clipped is worse than one that reads as
## a row of glyphs, and the glyphs are distinct.
const LABEL_MIN_WIDTH := 560.0
## How many leaner configurations `_apply_density` is allowed to try.
const LEVELS := 7
const MARK_WIDE := 168.0
const MARK_COMPACT := 96.0
const CHIP_WIDE := 132.0
const CHIP_COMPACT := 64.0
const RUNS_CHIP_W := 120.0
const PLATE_TEXT_W := 160.0
const PLATE_AVATAR := 36.0
const PLATE_AVATAR_COMPACT := 26.0
const GEAR_W := 42.0
const TAB_SEPARATION := 2.0
const GAPS := 42.0
## Padding a Button and an AegisPanel add around their contents, plus rounding.
## Measured: a glyph dock predicted at 298 px drew 350 px wide, and the 52 px
## difference is what put a 390 px page 6 px past its own right edge.
const SLACK := 56.0

var bar: AegisPanel
var row: HBoxContainer
var _stage: MenuStage
var _active: StringName
var _tabs: Array[AegisButton] = []
var _labels: Array[Label] = []
var _tab_glyphs: Array[TextureRect] = []
var _nav: HBoxContainer
var _plate: HBoxContainer
var _plate_state: Label
var _balance_chip: AegisPanel
var _balance_value: Label
var _runs_chip: AegisPanel
var _runs_value: Label
var _avatar: TextureRect
var _with_settings := true
## True when the dock has room for words as well as glyphs.
var _wide := true
## Which of the `LEVELS` configurations is in force.
var _level := -1
var _gear: AegisButton
var _mark: TextureRect
var _plate_text: VBoxContainer


## `with_settings` is false on pages that do not own the settings overlay: a
## gear that does nothing is worse than no gear, and DASHBOARD is where the
## overlay lives.
static func build(
	stage: MenuStage, active_tab: StringName, with_settings: bool = true
) -> LobbyChrome:
	var chrome := LobbyChrome.new()
	chrome._stage = stage
	chrome._active = active_tab
	chrome._with_settings = with_settings
	chrome._build()
	chrome.set_active(active_tab)
	# Built full, not empty: a stage that forgets to call `refresh` showed two
	# blank chips, and "the dock is empty until something updates it" is a bug
	# waiting for the next screen.
	chrome.refresh(stage.progression_service())
	return chrome


func _build() -> void:
	bar = AegisPanel.new()
	bar.name = &"LobbyDock"
	bar.accent_side = "top"
	bar.accent_color = AegisTokens.ACCENT
	bar.surface_alpha = 0.94
	bar.show_brackets = false
	bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	row = HBoxContainer.new()
	row.name = &"LobbyDockRow"
	row.add_theme_constant_override("separation", 0)
	bar.add_child(row)

	_build_wordmark()
	_build_nav()
	_build_resources()
	_build_plate()
	_build_settings()
	_apply_density()


func _build_wordmark() -> void:
	var mark := TextureRect.new()
	_mark = mark
	mark.name = &"DockWordmark"
	mark.texture = _stage.try_texture("res://assets/ui/logo_wordmark.png")
	mark.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	mark.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	mark.mouse_filter = Control.MOUSE_FILTER_IGNORE
	mark.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_stage.physical_min_size(mark, 168.0, 40.0)
	row.add_child(mark)
	row.add_child(_spacer(12.0))


func _build_nav() -> void:
	_nav = HBoxContainer.new()
	_nav.name = &"DockNav"
	_nav.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_stage.physical_separation(_nav, 2.0)
	for tab_id in [TAB_HOME, TAB_OPERATIVE, TAB_WORLD]:
		var spec: Array = TABS[tab_id]
		# No `Button.icon`. A Button draws its icon texture at the SVG's raster
		# size and ignores `icon_max_width` for these assets -- on the compact
		# dock the glyph came out as a 10 px fragment in a 40 px tab. A
		# TextureRect sized in physical pixels is what the resource chips
		# already use, and those draw correctly at 18 px.
		var button := AegisButton.new()
		button.name = "DockTab%s" % String(tab_id).capitalize()
		button.text = ""
		button.focus_mode = Control.FOCUS_ALL
		button.tooltip_text = spec[0]
		button.set_meta("tab_id", tab_id)
		var glyph := TextureRect.new()
		glyph.name = &"DockTabGlyph"
		glyph.texture = AegisTheme.icon(spec[1], true)
		glyph.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		glyph.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		glyph.mouse_filter = Control.MOUSE_FILTER_IGNORE
		# Centred at a fixed size, not full-rect: a full-rect child of a Button
		# draws over the button's own text, which is exactly what happened on the
		# desktop dock -- three large glyphs sat on top of HOME / OPERATIVE /
		# THEATRE. The size is set in `_apply_density`.
		glyph.set_anchors_preset(Control.PRESET_FULL_RECT)
		button.add_child(glyph)
		_tab_glyphs.append(glyph)
		button.pressed.connect(_on_tab_pressed.bind(tab_id))
		AegisTheme.set_button_variant(button, "ghost")
		_nav.add_child(button)
		_tabs.append(button)
	row.add_child(_nav)
	row.add_child(_spacer(12.0))


func _build_resources() -> void:
	_balance_chip = _make_chip(&"DockBalance", "trophy", AegisTokens.ACCENT, "BATTLE POINTS")
	_balance_value = _balance_chip.get_meta("value_label")
	_runs_chip = _make_chip(&"DockRuns", "chart-bar", AegisTokens.INFO, "RUNS")
	_runs_value = _runs_chip.get_meta("value_label")
	row.add_child(_balance_chip)
	row.add_child(_runs_chip)
	row.add_child(_spacer(12.0))


func _make_chip(
	node_name: StringName, icon_name: String, tint: Color, caption: String
) -> AegisPanel:
	var chip := AegisPanel.new()
	chip.name = node_name
	chip.show_brackets = false
	chip.surface_alpha = 0.92
	chip.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var line := HBoxContainer.new()
	line.add_theme_constant_override("separation", 0)
	chip.add_child(line)
	var glyph := TextureRect.new()
	glyph.texture = AegisTheme.icon(icon_name, true)
	glyph.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	glyph.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	glyph.modulate = tint
	glyph.mouse_filter = Control.MOUSE_FILTER_IGNORE
	glyph.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_stage.physical_min_size(glyph, 18.0, 18.0)
	line.add_child(glyph)
	line.add_child(_spacer(8.0))
	var value := _stage.make_label("", "label", AegisTokens.INK)
	value.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	value.add_theme_constant_override("outline_size", 0)
	line.add_child(value)
	chip.set_meta("value_label", value)
	chip.set_meta("caption", caption)
	return chip


func _build_plate() -> void:
	_plate = HBoxContainer.new()
	_plate.name = &"DockProfile"
	_plate.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_stage.physical_separation(_plate, 8.0)
	_avatar = TextureRect.new()
	# The head, not the sheet. `portrait_hero.png` is a 768x1024 half-body
	# illustration: drawn into a 26-36 px square, the whole figure becomes a
	# patch of noise and the dock's identity chip reads as a broken image
	# (measured in the r4 capture). An `AtlasTexture` crops the helmet and face
	# region, so the chip shows a face at the size a chip is.
	var sheet := _stage.try_texture("res://assets/ui/portrait_hero.png")
	if sheet != null:
		var head := AtlasTexture.new()
		head.atlas = sheet
		head.region = Rect2(
			sheet.get_width() * 0.30,
			sheet.get_height() * 0.07,
			sheet.get_height() * 0.32,
			sheet.get_height() * 0.32
		)
		_avatar.texture = head
	else:
		_avatar.texture = null
	_avatar.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_avatar.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	_avatar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_avatar.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_stage.physical_min_size(_avatar, 36.0, 36.0)
	_plate.add_child(_avatar)
	var text := VBoxContainer.new()
	text.add_theme_constant_override("separation", 0)
	text.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var name_label := _stage.make_label("OPERATIVE", "label", AegisTokens.INK)
	_plate_state = _stage.make_label("FIELD READY", "label_s", AegisTokens.OK)
	text.add_child(name_label)
	text.add_child(_plate_state)
	_plate_text = text
	_plate.add_child(text)
	row.add_child(_plate)
	row.add_child(_spacer(6.0))


func _build_settings() -> void:
	var gear := AegisButton.new()
	gear.name = &"DockSettings"
	_gear = gear
	gear.text = ""
	gear.icon = AegisTheme.icon("gear-six", true)
	gear.expand_icon = true
	gear.focus_mode = Control.FOCUS_ALL
	gear.tooltip_text = "SETTINGS"
	gear.add_theme_constant_override("icon_max_width", 20)
	gear.pressed.connect(func() -> void: settings_requested.emit())
	AegisTheme.set_button_variant(gear, "ghost")
	gear.name = &"DockSettings"
	_gear = gear
	gear.visible = _with_settings
	row.add_child(gear)


func _spacer(physical_width: float) -> Control:
	var spacer := Control.new()
	spacer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_stage.physical_min_size(spacer, physical_width, 0.0)
	spacer.custom_minimum_size.y = 0.0
	return spacer


func _on_tab_pressed(tab_id: StringName) -> void:
	if tab_id == _active:
		return
	navigate.emit(tab_id)


## Re-authored on every resize, and the *content* is decided by measurement.
##
## The dock is the one row that has to hold identity, navigation, two figures, a
## portrait and a control, so it is also the row most able to push the page
## wider than the screen. A table of breakpoints was tried and kept costing
## frames: the thresholds were tuned against the portrait phone and the desktop
## and said nothing about a 844x390 landscape phone, where the runs chip was
## still shown and the gear was drawn 120 px past the right edge (measured in
## the r4 capture, `?qa_menu=1`).
##
## So the dock now walks its own contents from richest to leanest and keeps the
## first configuration whose real combined minimum width fits the screen. What
## it gives up, in order:
##
##   1. tab labels go from 104 px to 88 px
##   2. the RUNS chip goes (HOME's record ribbon already prints the figure)
##   3. tab labels go to 76 px
##   4. the wordmark goes -- the active tab already says where you are, and a
##      player who is mid-menu does not need the logo
##   5. the tabs lose their words entirely and become glyphs
##   6. the operative's portrait goes, and the gear stays
##   7. the settings gear goes
##
## Nothing is ever clipped to make it fit, and the order is the one a player
## would choose: a word you cannot read is worse than a glyph, and a figure the
## page already shows is the first thing that can leave.
func _apply_density() -> void:
	# The page's margin and the bar's own inset are spent before any child is.
	var budget := _stage.physical_size().x - 2.0 * _stage.margin_side() - 12.0
	var chosen := LEVELS
	for level in range(LEVELS + 1):
		if _width_at(level) <= budget:
			chosen = level
			break
	_apply_level(chosen)


## How wide the dock is at `level`, in physical pixels, computed from the parts
## rather than read back from the container.
##
## `get_combined_minimum_size()` is a cache: it is refreshed when a container is
## asked to lay out, not in the middle of a function that has just changed a
## dozen children, so a loop that measured it chose the same level at 360 px as
## at 1280 px and the page stayed 362 px wide on a 360 px screen. The constants
## below are the authored sizes in `_apply_level` plus the width each measured
## label needed in the `?qa_menu=1` report: "EXO OPERATIVE / FIELD READY" is 160,
## "BATTLE POINTS  0" is 132, and a tab's word is inside its 76-104 px.


func _width_at(level: int) -> float:
	var compact := level >= 5 or _wordless()
	var named := level <= 4 and not _wordless()
	var tab_width := 40.0
	if named:
		tab_width = 104.0 if level == 0 else (88.0 if level <= 2 else 76.0)
	var width := 0.0
	if level <= 3:
		width += MARK_COMPACT if compact else MARK_WIDE
	width += (tab_width * 3.0) + (TAB_SEPARATION * 2.0)
	width += CHIP_COMPACT if compact else CHIP_WIDE
	if level <= 1:
		width += RUNS_CHIP_W
	if level <= 5:
		width += PLATE_AVATAR_COMPACT if compact else PLATE_AVATAR
	if level <= 4:
		width += PLATE_TEXT_W
	if level <= 6 and _with_settings:
		width += GEAR_W
	return width + GAPS + SLACK


## True on a landscape phone, where the tabs are glyphs whatever the width says.
func _wordless() -> bool:
	return _stage.is_landscape() and _stage.physical_size().y < 520.0


func _apply_level(level: int) -> void:
	# A landscape phone is wide enough for words and only 390 px tall. A tab
	# that carries a word has to meet the 64 px touch floor, which would cost
	# the dock a fifth of that height; the glyphs are distinct and the tooltip
	# names them, so in that one case the tabs go wordless whatever the width
	# says.
	var wordless := _wordless()
	var named := level <= 4 and not wordless
	var compact := level >= 5 or wordless
	# A wordless tab is 40 px wide whatever the level: the width budget in
	# `_width_at` assumes exactly that, and the two must agree or the loop picks
	# a level that does not fit.
	var tab_width := 40.0
	if named:
		tab_width = 104.0 if level == 0 else (88.0 if level <= 2 else 76.0)

	_runs_chip.visible = level <= 1
	_plate_text.visible = level <= 4
	_mark.visible = level <= 3
	if is_instance_valid(_gear):
		_gear.visible = _with_settings and level <= 6
	# The portrait plate is the last thing the identity chip gives up before the
	# gear does: a face at 0.9 opacity is worth less than a settings key.
	_avatar.visible = level <= 5

	# 64 = AegisTokens.MIN_TOUCH_PX. A tab with a word on it is a touch target,
	# and a 40 px one failed the layout probe at every width that showed words.
	var icon_size := 32.0 if compact else 64.0
	for tab in _tabs:
		tab.text = str(TABS[tab.get_meta("tab_id")][0]) if named else ""
		tab.add_theme_font_override("font", AegisTheme.font(AegisTokens.FAMILY_UI_M))
		tab.add_theme_font_size_override("font_size", 15)
		_stage.physical_min_size(tab, tab_width, icon_size)
		tab.add_theme_constant_override("icon_max_width", 20 if compact else 22)
	_stage.physical_min_size(_mark, 96.0 if compact else 168.0, 24.0 if compact else 28.0)
	_stage.physical_min_size(_avatar, 26.0 if compact else 36.0, 26.0 if compact else 36.0)
	_stage.physical_min_size(_nav, 0.0, icon_size)
	# The glyph is only drawn where the tab has no words: on a wide screen the
	# word IS the icon, and two of them in one tab is a duplicate, not a design.
	for glyph in _tab_glyphs:
		glyph.visible = compact
		# The tab is 40x32 physical; insetting a full-rect child leaves the glyph
		# 26x20, which is the size that rendered correctly when it filled the
		# button. Anchoring to the centre with explicit offsets drew a fragment
		# instead -- a Control's anchors are evaluated against a rect Godot may
		# not have given the child yet.
		glyph.offset_left = _stage.px(7.0)
		glyph.offset_top = _stage.px(6.0)
		glyph.offset_right = -_stage.px(7.0)
		glyph.offset_bottom = -_stage.px(6.0)
	bar.set_surface_pad(_stage.px(3.0 if compact else 7.0))
	_stage.physical_min_size(_balance_chip, 64.0 if compact else 132.0, 0.0)

	var wide := named and level <= 3
	if wide != _wide:
		_wide = wide
		# The chips say "BATTLE POINTS  0" or plain "0" depending on this, and a
		# resize does not otherwise re-render their text.
		refresh(_stage.progression_service())
	_level = level


## Re-fits the dock to the stage it is on. Bound to nothing: the owning stage
## calls it from its own resize handler after it has re-applied its margins,
## because only the stage knows how much of the width it reserves. Without this
## the dock kept whatever it measured on the first mount and a rotation left it
## 316 px wide on a 360 px screen.
func refit() -> void:
	_apply_density()


func set_active(tab_id: StringName) -> void:
	_active = tab_id
	for tab in _tabs:
		var live: bool = tab.get_meta("tab_id") == tab_id
		tab.edge_active = live
		tab.modulate = Color(1, 1, 1, 1.0 if live else 0.55)
		tab.queue_redraw()


func refresh(progression: ProgressionService) -> void:
	if progression == null:
		return
	# The word is part of the value, not a second label: on a wide screen a chip
	# reads "BATTLE POINTS  1234", and on a phone it reads "1234" next to the
	# trophy. One label, so the number can never disagree with its own caption.
	_balance_value.text = _figure(
		str(_balance_chip.get_meta("caption", "")), progression.balance, _wide
	)
	_runs_value.text = _figure(
		str(_runs_chip.get_meta("caption", "")), progression.completed_runs, _wide
	)
	var hero := HeroDefinition.load_definition(progression.selected_hero_id)
	if hero != null and not hero.display_name.is_empty():
		var label := _plate.get_child(1).get_child(0) as Label
		if label != null:
			label.text = hero.display_name.to_upper()
	_plate_state.text = "FIELD READY" if (hero == null or hero.field_ready) else "OFFLINE"
	_plate_state.add_theme_color_override(
		"font_color", AegisTokens.OK if (hero == null or hero.field_ready) else AegisTokens.INK_3
	)


## `wide` decides whether the caption is part of the string. Digits are not
## grouped: the save file stores an integer and "1,234" is a locale decision a
## HUD should not make on a player's behalf.
func _figure(caption: String, value: int, wide: bool) -> String:
	var digits := str(maxi(value, 0))
	return "%s  %s" % [caption, digits] if wide else digits


static func _thousands(value: int) -> String:
	var digits := str(maxi(value, 0))
	var out := ""
	var count := 0
	for index in range(digits.length() - 1, -1, -1):
		out = digits[index] + out
		count += 1
		if count % 3 == 0 and index > 0:
			out = "," + out
	return out
