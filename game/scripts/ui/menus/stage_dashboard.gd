## HOME: the deployment board.
##
## This screen used to be a second HERO page. It carried a full-height 3D
## operative in the middle, an edge-docked portrait card and a bottom dock --
## the same composition as OPERATIVE, only with a DEPLOY tile added, and a
## player who moved between the two tabs saw the same screen twice. That is the
## defect this file answers: HOME is now a *manifest*, not a model.
##
## What it says: the three rows, then the record and the actions beside them.
##
##   * a heading and the profile line -- where you are, and how many runs you
##     have finished;
##   * three numbered rows -- 01 the operative, 02 the theatre, 03 the arsenal
##     -- each with its own plate, its name read from the definition, and the
##     one line of state that belongs to it. Numbers, because the rows are a
##     sequence: pick who, pick where, know what you carry;
##   * the record, as a ribbon of "CAPTION  value" lines;
##   * ARMORY and DEPLOY, in the thumb arc, DEPLOY amber and last.
##
## The operative is *not* shown in 3D here. That is OPERATIVE's job, and the two
## pages only stop looking like duplicates when they stop showing the same
## object the same way. What a player needs on HOME is the receipt of their
## choices before they commit, not another turntable.
##
## Every number comes from ProgressionService, which is the only owner of the
## persistent profile. There is no "profile level", no streak and no daily
## reward: the save file holds Battle Points, best score, completed runs,
## unlocks and the last loadout, so those are the five things this screen shows.
##
## There is no REPLAY INTRO and no ident film: the delivered clip was pulled on
## 2026-10-24 (docs/DECISIONS.md 17).
extends MenuStage

## The lobby's backdrop. Kept as a literal so `data_source_smoke` can prove the
## file exists; it is drawn at low contrast because this page is a board, not a
## painting.
const BACKDROP := "res://assets/ui/dashboard_bg.jpg"
## Where the per-weapon plates live. Built as a prefix rather than a formatted
## literal: the art-path audit reads literals out of this file, and
## "weapon_%s.png" would be reported as a missing file.
const WEAPON_PLATE_DIR := "res://assets/ui/"

# --- chrome ----------------------------------------------------------------- #
var _chrome: LobbyChrome
var _top: HBoxContainer

# --- the column ------------------------------------------------------------- #
var _root: VBoxContainer
## Heading and profile line. A 390 px landscape screen spends that height on
## the rows instead, so both give way on a compact screen.
var _intro: HBoxContainer
var _heading: Label
var _profile_line: Label
## The three rows, beside the record and the actions: 390 px of height cannot
## hold heading, rows, actions and ribbon stacked in one column.
var _body_landscape: HBoxContainer
var _rows: VBoxContainer
var _rail: VBoxContainer
var _actions: VBoxContainer
var _landscape_built := false

# --- the rows --------------------------------------------------------------- #
var _hero_row: AegisPanel
var _hero_plate: TextureRect
var _hero_name_label: Label
var _hero_status: Label
var _mission_row: AegisPanel
var _mission_plate: TextureRect
var _mission_name: Label
var _mission_brief: Label
var _arsenal_row: AegisPanel
var _arsenal_plate: TextureRect
var _arsenal_name: Label
var _arsenal_state: Label
var _hero_caption: Label
var _mission_caption: Label
var _arsenal_caption: Label
var _numerals: Array[Label] = []

# --- the ribbon and the actions -------------------------------------------- #
var _ribbon: AegisPanel
var _best: Label
var _runs: Label
## Catalog keys behind the two figures. The numbers change every run, so the
## label is rebuilt from `key + value` instead of being parked in the tree walk.
var _best_key := "dash.best_score"
var _runs_key := "dash.runs_completed"
var _loadout: Label
var _loadout_items: Array[Label] = []
var _armory: AegisButton
var _deploy: AegisButton
var _deploy_caption: Label

# --- the modals ------------------------------------------------------------- #
var _armory_ui: ArmoryUi
var _settings: AegisSettingsMenu


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(make_backdrop(BACKDROP))

	# Flatter than OPERATIVE's scrim on purpose. That page is lit 3D and needs
	# the backdrop dimmed behind a model; this one is a board, so the plate is
	# nearly opaque and the key art only survives as texture under the rows.
	var plate := ColorRect.new()
	plate.color = Color(AegisTokens.VOID, 0.86)
	plate.set_anchors_preset(Control.PRESET_FULL_RECT)
	plate.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(plate)

	make_margin()
	_root = VBoxContainer.new()
	physical_separation(_root, 16)
	_margin.add_child(_root)

	_build_top_bar()
	_build_intro()
	_build_bands()
	_build_rows()
	_build_ribbon()
	_build_actions()
	_build_modals()

	_connect_resized(_on_resized)
	relayout()
	_apply_orientation()
	_apply_density()
	# A language change on this page is a re-read of the figures and the status
	# lines, both of which are built from the save file.
	AegisText.watch(_on_language)


## Everything on this page that says a word: the keyed tree first, then the two
## figures and the status lines, which are built from the save file.
func _on_language(_code: String) -> void:
	AegisText.refresh(self)
	refresh_profile()


# --- construction ----------------------------------------------------------- #


## The shared lobby dock: wordmark, HOME / OPERATIVE / THEATRE, the two figures
## the save file stores, the operative plate and the gear. Every lobby page
## builds this same dock (see `LobbyChrome`), which is the difference between a
## product with a top bar and three screens that each invented one. It is also
## what carries "BATTLE POINTS  n" on this page -- the ribbon does not repeat
## the wallet.
func _build_top_bar() -> void:
	_chrome = LobbyChrome.build(self, LobbyChrome.TAB_HOME)
	_chrome.navigate.connect(_on_nav_requested)
	_chrome.settings_requested.connect(_on_settings_pressed)
	_top = _chrome.row
	_root.add_child(_chrome.bar)


## The dock is a *navigator*, so a tab means "go to that page" -- not "open the
## thing this page already is".
func _on_nav_requested(tab_id: StringName) -> void:
	match tab_id:
		LobbyChrome.TAB_OPERATIVE:
			completed.emit(&"HERO", {"hero_id": String(progression_service().selected_hero_id)})
		LobbyChrome.TAB_WORLD:
			completed.emit(&"WORLD", {"world_id": String(progression_service().selected_world_id)})
		_:
			pass


func _build_intro() -> void:
	_intro = HBoxContainer.new()
	_intro.name = &"BoardIntro"
	_intro.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	physical_separation(_intro, 16)
	_root.add_child(_intro)

	_heading = make_label_key("dash.title", "display_l", AegisTokens.INK)
	_heading.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_intro.add_child(_heading)

	_profile_line = make_label("", "label", AegisTokens.INK_3)
	_profile_line.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_profile_line.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_intro.add_child(_profile_line)


func _build_bands() -> void:
	_body_landscape = HBoxContainer.new()
	_body_landscape.name = &"BoardBandsLandscape"
	_body_landscape.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_body_landscape.size_flags_vertical = Control.SIZE_EXPAND_FILL
	physical_separation(_body_landscape, 20)

	_rows = VBoxContainer.new()
	_rows.name = &"BoardRows"
	_rows.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	physical_separation(_rows, 12)

	# The right column. It has a width of its own,
	# or it takes the width of its widest child and the rows lose the screen.
	_rail = VBoxContainer.new()
	_rail.name = &"BoardRail"
	_rail.alignment = BoxContainer.ALIGNMENT_END
	physical_separation(_rail, 12)

	_actions = VBoxContainer.new()
	_actions.name = &"BoardActions"
	physical_separation(_actions, 10)


func _build_rows() -> void:
	var hero := _make_row("01", "dash.row_operative", AegisTokens.INFO)
	_hero_row = hero["panel"]
	_hero_plate = hero["plate"]
	_hero_caption = hero["caption"]
	_hero_name_label = hero["name"]
	_hero_status = hero["detail"]
	_rows.add_child(_hero_row)

	var mission := _make_row("02", "dash.row_theatre", AegisTokens.ACCENT)
	_mission_row = mission["panel"]
	_mission_plate = mission["plate"]
	_mission_caption = mission["caption"]
	_mission_name = mission["name"]
	_mission_brief = mission["detail"]
	_rows.add_child(_mission_row)

	var arsenal := _make_row("03", "dash.row_arsenal", AegisTokens.INK_2)
	_arsenal_row = arsenal["panel"]
	_arsenal_plate = arsenal["plate"]
	_arsenal_caption = arsenal["caption"]
	_arsenal_name = arsenal["name"]
	_arsenal_state = arsenal["detail"]
	_rows.add_child(_arsenal_row)


## One numbered row. A row is a *line of a manifest*, not a button: what it
## reports is a choice already made, and the two ways to change that choice are
## the OPERATIVE and THEATRE tabs in the dock above it. A row that looked
## tappable and did nothing would be worse than a row that reads as a receipt.
func _make_row(number: String, caption_key: String, accent: Color) -> Dictionary:
	var panel := AegisPanel.new()
	panel.name = &"Step" + number
	panel.interactive = false
	# Each row is a plate cut on its trailing corner, so the three rows read as
	# one machined stack rather than three rounded cards.
	panel.bezel = true
	panel.cut_top_right = AegisBezel.CUT
	panel.accent_side = "left"
	panel.accent_color = accent
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE

	var row := HBoxContainer.new()
	physical_separation(row, 14)
	row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel.add_child(row)

	var numeral := make_label(number, "display_m", AegisTokens.INK_3)
	numeral.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	row.add_child(numeral)
	_numerals.append(numeral)

	var plate := TextureRect.new()
	plate.name = &"StepPlate" + number
	plate.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	plate.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	plate.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(plate)

	var column := VBoxContainer.new()
	column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	column.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	physical_separation(column, 4)
	row.add_child(column)

	var caption_label := make_label_key(caption_key, "label", AegisTokens.INK_3)
	column.add_child(caption_label)

	var name_label := make_label("", "title", AegisTokens.INK)
	name_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	name_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	column.add_child(name_label)

	var detail := make_label("", "label_s", AegisTokens.INK_2)
	detail.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	detail.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	column.add_child(detail)

	return {
		"panel": panel,
		"plate": plate,
		"caption": caption_label,
		"name": name_label,
		"detail": detail,
	}


## The record: two figures and the loadout they deploy with, on one surface.
## "CAPTION  value" in a single label, because two labels per figure is how the
## first cut printed every caption twice.
func _build_ribbon() -> void:
	_ribbon = AegisPanel.new()
	_ribbon.name = &"RecordRibbon"
	_ribbon.interactive = false
	# The ribbon points the other way from the rows: it is the reading at the
	# foot of the board, not a step in it.
	_ribbon.bezel = true
	_ribbon.cut_top_left = AegisBezel.CUT_SM
	_ribbon.cut_bottom_right = AegisBezel.CUT_LG
	_ribbon.accent_side = "top"
	_ribbon.accent_color = AegisTokens.INFO
	_ribbon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_ribbon.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	var column := VBoxContainer.new()
	physical_separation(column, 6)
	_ribbon.add_child(column)

	_best = make_label("", "label_s", AegisTokens.INK)
	_best_key = "dash.best_score"
	_best.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	column.add_child(_best)
	_runs = make_label("", "label_s", AegisTokens.INK)
	_runs_key = "dash.runs_completed"
	_runs.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	column.add_child(_runs)
	# "LOADOUT  hero / weapon / theatre" was one line that ran out of a 340 px
	# rail mid-word ("PULSE…"). The receipt names the three things on three
	# lines instead, each short enough to print whole.
	_loadout = make_label_key("dash.loadout", "label_s", AegisTokens.ACCENT)
	_loadout.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	column.add_child(_loadout)
	for _slot in [0, 1, 2]:
		var item := make_label("", "label_s", AegisTokens.INK_2)
		item.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		column.add_child(item)
		_loadout_items.append(item)


func _build_actions() -> void:
	_armory = make_button_key("nav.armory", "card", "nav.armory_tip")
	_armory.clip_text = true
	_armory.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_armory.pressed.connect(_on_armory_pressed)
	_actions.add_child(_armory)

	_deploy = make_button_key("nav.deploy", "primary", "nav.deploy_tip")
	_deploy.clip_text = true
	_deploy.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_deploy.pressed.connect(_on_deploy_pressed)
	_actions.add_child(_deploy)

	# The caption states the action's condition, not the theatre: row 02 and the
	# dock both already name the theatre, and printing it a third time under the
	# tile is what pushed the caption past its label's width and cut it to
	# `READY TO…` at 844 px -- in both languages
	# (qa-evidence/ui/round-12/i18n/engine).
	_deploy_caption = make_label("", "label_s", AegisTokens.INK_3)
	_deploy_caption.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_deploy_caption.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_deploy_caption.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	_deploy_caption.max_lines_visible = 1
	_actions.add_child(_deploy_caption)


func _build_modals() -> void:
	_armory_ui = ArmoryUi.new()
	_armory_ui.name = "ArmoryPanel"
	_armory_ui.visible = false
	_armory_ui.weapon_action_requested.connect(_on_weapon_action)
	_armory_ui.weapon_upgrade_requested.connect(_on_weapon_upgrade)
	_armory_ui.close_requested.connect(_on_armory_close)
	add_child(_armory_ui)

	_settings = AegisSettingsMenu.new()
	_settings.name = "SettingsPanel"
	_settings.visible = false
	_settings.close_requested.connect(_on_settings_close)
	add_child(_settings)


# --- stage lifecycle -------------------------------------------------------- #


func enter(_stage_payload: Dictionary) -> void:
	_armory_ui.visible = false
	_settings.visible = false
	apply_safe_margins(_margin)
	_on_resized()
	refresh_profile()


## FrontEnd calls this on `profile_changed`, so an unlock made inside the armory
## updates the board underneath it without reopening the screen.
func refresh_profile() -> void:
	var progression := progression_service()
	if progression == null:
		return
	if _chrome != null:
		_chrome.refresh(progression)
	var hero := _hero_name(progression.selected_hero_id)
	var weapon := _weapon_name(progression.selected_weapon_id)
	var world := _world_name(progression.selected_world_id)

	_set_figure(_best, _best_key, progression.best_score)
	_set_figure(_runs, _runs_key, progression.completed_runs)
	_loadout_items[0].text = hero
	_loadout_items[1].text = weapon
	_loadout_items[2].text = world
	# The profile line is the record, not a rank: the save file stores no level,
	# so "NO RUNS" on a fresh profile is true and "SQUAD LEADER Lv 4" would not
	# be.
	if progression.completed_runs == 0:
		AegisText.apply(_profile_line, "dash.profile_fresh")
	else:
		AegisText.apply(_profile_line, "dash.profile_runs", [progression.completed_runs])

	_hero_name_label.text = hero
	_mission_name.text = world
	_arsenal_name.text = weapon
	AegisText.apply(_deploy_caption, "dash.ready_to_deploy")

	# Both status lines come from the definitions, not from literals: the card
	# on OPERATIVE prints the same string, so the board cannot say an operative
	# is ready when their card says otherwise.
	var hero_definition := HeroDefinition.load_definition(progression.selected_hero_id)
	var hero_tier := progression.fieldable_tier()
	var hero_vitals := roundi(HeroTier.vitals(hero_tier))
	var hero_reduction := roundi(HeroTier.reduction(hero_tier))
	var hero_ready := (
		hero_definition.display_status().to_upper()
		if hero_definition != null
		else AegisText.t("common.field_ready")
	)
	_hero_status.text = AegisText.t(
		"dash.hero_summary", [hero_tier, hero_vitals, hero_reduction, hero_ready]
	)
	_hero_plate.texture = (
		try_texture(hero_definition.portrait_path) if hero_definition != null else null
	)
	var world_definition := WorldDefinition.load_definition(progression.selected_world_id)
	if world_definition != null:
		_mission_brief.text = (
			"%s · %s"
			% [
				world_definition.display_mode_label(),
				world_definition.display_reward_summary(),
			]
		)
		_mission_plate.texture = try_texture(world_definition.plate_path)
	else:
		_mission_brief.text = ""
		_mission_plate.texture = null
	_arsenal_plate.texture = try_texture(
		WEAPON_PLATE_DIR + "weapon_%s.png" % String(progression.selected_weapon_id)
	)
	var wpn_tier := progression.weapon_tier(progression.selected_weapon_id)
	var owned_count := progression.unlocked_ids.size()
	var total_weapons := maxi(WeaponDefinition.load_all_definitions().size(), 1)
	if progression.is_unlocked(progression.selected_weapon_id):
		_arsenal_state.text = AegisText.t(
			"dash.arsenal_summary", [wpn_tier, owned_count, total_weapons]
		)
	else:
		(
			AegisText
			. apply(
				_arsenal_state,
				"dash.selected_cost",
				[progression.unlock_cost(progression.selected_weapon_id)],
			)
		)
	if _armory_ui.visible:
		(
			_armory_ui
			. refresh_profile(
				progression.balance,
				progression.best_score,
				progression.unlocked_ids,
				progression.selected_weapon_id,
				progression.weapon_tiers,
				progression.blueprint_ids,
			)
		)


## A figure is "CAPTION  number" in one label: the caption from the catalog, the
## number from the save file.
func _set_figure(label: Label, key: String, value: int) -> void:
	label.text = AegisText.t(key, [value])


# --- arrangement ------------------------------------------------------------ #


## One arrangement: the rows keep the height they need on the left, the record
## and the actions sit in a rail beside them. 390 px of height cannot hold four
## bands, so the stacked column is gone rather than kept unreachable.
##
## Every block is detached before it is re-parented, so the arrangement never
## depends on the order it was first built in.
func _apply_orientation() -> void:
	if _landscape_built and _body_landscape.get_parent() != null:
		return
	_landscape_built = true
	for block in [_rows, _rail, _actions, _ribbon]:
		if block.get_parent() != null:
			block.get_parent().remove_child(block)
	_root.add_child(_body_landscape)
	_body_landscape.add_child(_rows)
	_body_landscape.add_child(_rail)
	_rail.add_child(_ribbon)
	_rail.add_child(_actions)
	_rows.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_rail.size_flags_vertical = Control.SIZE_EXPAND_FILL


## Two budgets, measured on the landscape viewports the smoke test uses.
## Nothing here invents a target: the rows keep their height, the buttons keep
## their touch floor, and the *copy* gives way first.
func _apply_density() -> void:
	var height := physical_size().y
	var width := physical_size().x
	# A landscape phone is wide but 390 px tall: that is the compact budget.
	var compact := height < 520.0
	# A width budget as well as a height one: the rail shares the width with the
	# rows, so on a narrow window every caption in a row has to give up its
	# minimum too.
	var narrow := width < 560.0
	var tight := narrow or compact

	apply_safe_margins(
		_margin, 20.0 if compact else 36.0, 8.0 if compact else 28.0, 8.0 if compact else 28.0
	)

	var pad := px(6.0 if compact else 12.0)
	for panel in [_hero_row, _mission_row, _arsenal_row, _ribbon]:
		panel.set_surface_pad(pad)

	physical_separation(_root, 12.0 if compact else 20.0)
	physical_separation(_body_landscape, 14.0 if compact else 24.0)
	physical_separation(_rows, 8.0 if compact else 14.0)
	physical_separation(_rail, 10.0 if compact else 16.0)
	physical_separation(_actions, 8.0 if compact else 12.0)
	physical_separation(_intro, 10.0 if compact else 16.0)
	physical_separation(_top, 10.0 if compact else 16.0)

	# --- row and button heights ----------------------------------------- #
	var row_height := 84.0 if compact else 112.0
	var plate := Vector2(84.0, 62.0) if compact else Vector2(120.0, 90.0)
	var touch := 64.0 if compact else 72.0
	if narrow:
		# The plate is the first thing that gives way, not a target.
		plate = Vector2(64.0, 48.0)

	for panel in [_hero_row, _mission_row, _arsenal_row]:
		physical_min_size(panel, 0.0, row_height)
	for texture in [_hero_plate, _mission_plate, _arsenal_plate]:
		physical_min_size(texture, plate.x, plate.y)
	physical_min_size(_armory, 0.0, touch)
	physical_min_size(_deploy, 0.0, 76.0 if compact else 100.0)
	for numeral in _numerals:
		numeral.visible = width >= 520.0

	# A share of the screen, not a constant: 340 px of rail plus the rows' own
	# minimum is 988 px on an 844 px screen, which drew the rail off the right
	# edge at 844x390 (measured in the r4 capture).
	_rail.custom_minimum_size.x = px(minf(340.0, width * 0.34))
	_rows.custom_minimum_size.x = 0.0

	# --- what gives way -------------------------------------------------- #
	_intro.visible = not compact
	# The heading stays (it is what makes the page a board), the profile line
	# goes: "PROFILE · FIELD READY" beside a 265 px wordmark is 472 px of row on
	# a 390 px screen.
	_profile_line.visible = not (compact or narrow)
	# The brief is the theatre's own paragraph, cut to one sentence; the row
	# above already names it, so a compact screen keeps the name and drops this.
	_mission_brief.visible = true
	_arsenal_state.visible = true
	_loadout.visible = not compact
	for item in _loadout_items:
		item.visible = not compact
		_limit_lines(item, 1)
	_limit_lines(_hero_status, 1)
	_limit_lines(_mission_brief, 1)
	_limit_lines(_arsenal_state, 1)
	_limit_lines(_loadout, 2)
	_limit_lines(_deploy_caption, 1)

	# `clip_text` is what takes a label's text out of its *minimum* width. On a
	# narrow window a name set in `title` plus a plate plus a numeral is wider
	# than the screen, and a row that wraps its own name still measures the
	# longest word.
	for label in [_hero_name_label, _mission_name, _arsenal_name]:
		label.clip_text = tight
		_limit_lines(label, 2)
	for label in [
		_hero_status,
		_mission_brief,
		_arsenal_state,
		_hero_caption,
		_mission_caption,
		_arsenal_caption,
	]:
		label.clip_text = tight

	if _chrome != null:
		_chrome.refit()
	_apply_armory_and_settings_sizes()


func _apply_armory_and_settings_sizes() -> void:
	# The armory and settings panels are sized in physical pixels too: they are
	# lists of 56 px rows, and a panel authored in canvas units would be a third
	# of that on a phone.
	var phys := physical_size()
	_armory_ui.custom_minimum_size = Vector2(
		px(minf(phys.x * 0.92, 680.0)),
		px(minf(phys.y * 0.90, 440.0)),
	)
	_settings.custom_minimum_size = Vector2(
		px(minf(phys.x * 0.94, 560.0)),
		px(minf(phys.y * 0.90, 560.0)),
	)
	enforce_font_floor(_armory_ui, _stretch)
	enforce_font_floor(_settings, _stretch)
	_centre(_armory_ui)
	_centre(_settings)


func _on_resized() -> void:
	relayout()
	_orient_nodes([_hero_plate, _mission_plate, _arsenal_plate])
	_apply_orientation()
	_apply_density()


func _centre(panel: Control) -> void:
	var target_size := Vector2(
		maxf(panel.size.x, panel.custom_minimum_size.x),
		maxf(panel.size.y, panel.custom_minimum_size.y),
	)
	panel.set_anchors_preset(Control.PRESET_CENTER)
	panel.position = (size - target_size) * 0.5


# --- actions ---------------------------------------------------------------- #


func _on_deploy_pressed() -> void:
	Sfx.play_ui(&"session_clear")
	completed.emit(&"HERO", {})


func _on_armory_pressed() -> void:
	_armory_ui.visible = true
	_settings.visible = false
	refresh_profile()
	_apply_armory_and_settings_sizes()
	_armory_ui.focus_first()


func _on_armory_close() -> void:
	_armory_ui.visible = false


func _on_settings_pressed() -> void:
	_settings.visible = true
	_armory_ui.visible = false
	_settings.open()


func _on_settings_close() -> void:
	_settings.visible = false


## Same rules as Main._on_armory_weapon_action: buying spends real BP and
## equipping only ever selects within what the profile already owns.
func _on_weapon_action(weapon_id: StringName) -> void:
	var progression := progression_service()
	if progression == null or not ProgressionService.WEAPON_IDS.has(weapon_id):
		return
	if progression.is_unlocked(weapon_id):
		progression.select_weapon(weapon_id)
		_armory_ui.show_hint_key("armory.now_equipped", [String(weapon_id).to_upper()])
		return
	if (
		ProgressionService.BLUEPRINT_REQUIRED.has(weapon_id)
		and not progression.has_blueprint(weapon_id)
	):
		_armory_ui.show_hint_key("recovery.blueprint_required")
		return
	var missing := progression.unlock_cost(weapon_id) - progression.balance
	if missing > 0:
		_armory_ui.show_hint_key("armory.need_bp", [missing])
		return
	if progression.unlock_weapon(weapon_id):
		progression.select_weapon(weapon_id)
		Sfx.play_ui(&"session_clear")
		_armory_ui.show_hint_key("armory.now_unlocked", [String(weapon_id).to_upper()])
	refresh_profile()


func _on_weapon_upgrade(weapon_id: StringName) -> void:
	var progression := progression_service()
	if progression == null or not ProgressionService.WEAPON_IDS.has(weapon_id):
		return
	var current := progression.weapon_tier(weapon_id)
	if current >= WeaponTier.tier_count():
		_armory_ui.show_hint_key("armory.upgrade_max")
		return
	var cost := progression.weapon_upgrade_cost(weapon_id)
	var missing := cost - progression.balance
	if missing > 0:
		_armory_ui.show_hint_key("armory.upgrade_need", [missing])
		return
	if progression.upgrade_weapon(weapon_id):
		var next_tier := progression.weapon_tier(weapon_id)
		Sfx.play_ui(&"session_clear")
		_armory_ui.show_hint_key("armory.upgraded", [next_tier])
	refresh_profile()


# --- naming ----------------------------------------------------------------- #


## The theatre's own blurb, cut to its first sentence. The WORLD screen prints
## the whole paragraph; a board row is a reminder of where you are going.
func _first_sentence(text: String) -> String:
	var trimmed := text.strip_edges()
	var stop := trimmed.find(".")
	if stop <= 0:
		return trimmed
	return trimmed.substr(0, stop)


## Heroes and worlds have no *numeric* model, but they do have a name, and it
## lives in the registry exactly as a weapon's does. Reading it from there
## instead of typing it out here is what stops the board calling the loadout
## something the OPERATIVE and THEATRE pages do not.
func _hero_name(hero_id: StringName) -> String:
	var definition := HeroDefinition.load_definition(hero_id)
	if definition != null:
		return definition.display_name.to_upper()
	return String(hero_id).replace("_", " ").to_upper()


func _world_name(world_id: StringName) -> String:
	var definition := WorldDefinition.load_definition(world_id)
	if definition != null:
		return definition.display_name.to_upper()
	return String(world_id).replace("_", " ").to_upper()


## The weapon names itself: `WeaponDefinition.display_name` is the same string
## the selection card prints, so the board cannot call it something else.
func _weapon_name(weapon_id: StringName) -> String:
	var definition := WeaponDefinition.load_definition(weapon_id)
	if definition != null and not definition.display_name.strip_edges().is_empty():
		return definition.display_name.to_upper()
	return String(weapon_id).to_upper()
