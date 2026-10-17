class_name TouchControls
extends Control

## Runtime HUD for Project Overdrive, built on the AEGIS design language
## (docs/UI_UX_REDESIGN_SPEC.md).
##
## The script keeps its historical name and signal surface because main.gd and
## the smoke tests drive it directly. Inside, it has three layout branches:
## desktop, touch portrait and touch landscape. All three share the same widgets
## and tokens so the interface never drifts between platforms.

signal movement_changed(value: Vector2)
signal look_delta(value: Vector2)
signal fire_changed(pressed: bool)
signal aim_changed(pressed: bool)
signal weapon_switch_requested
signal skill_requested
signal pause_requested
signal retry_requested
signal sound_mute_requested

const HIT_CONFIRM_DURATION: float = AegisTokens.HIT_MARKER
const HELP_VISIBLE_SECONDS: float = 10.0
## Below this width the top bar stops fitting three cards: the run data moves
## into a single compact strip under it instead of disappearing.
const NARROW_WIDTH: float = 760.0
## Smaller than this is a headless dummy window, not a real viewport.
const MIN_WINDOW_PX: float = 200.0
## Smallest font the HUD may use, in *physical* pixels. A font that is 11
## logical px inside a canvas the engine then scales down to a third is only
## ~3 px on the glass, which is unreadable no matter how well it fits the card.
const MIN_PHYSICAL_FONT_PX: float = AegisTokens.MIN_PHYSICAL_FONT_PX
## Lines the narrow-screen data strip must fit: the enemy line plus the wrapped
## run summary. Four gives the wrapped summary one line of slack.
const COMPACT_LINES: int = 4
const DESKTOP_HINT := (
	"WASD MOVE · SHIFT SPRINT · SPACE JUMP · RMB ADS · LMB FIRE · 1-3 WEAPON"
	+ " · F EMP · ESC PAUSE"
)
const DESKTOP_HINT_SHORT := "WASD · SHIFT · SPACE · RMB ADS · LMB FIRE · 1-3 · F EMP · ESC"
const HELP_FADE_SECONDS: float = 1.5
## The browser shell (game/web_shell/index.html) draws chips along the top of
## the page; the HUD keeps clear of them instead of overlapping.
const WEB_TOP_INSET: float = 46.0
const DAMAGE_FLASH_DURATION: float = AegisTokens.DAMAGE_VIGNETTE

const DEFAULT_HEALTH_COLOR: Color = AegisTokens.OK
const WARNING_HEALTH_COLOR: Color = AegisTokens.ACCENT
const CRITICAL_HEALTH_COLOR: Color = AegisTokens.DANGER

# --- Interaction state ----------------------------------------------------- #
var _move_touch_id: int = -1
var _look_touch_id: int = -1
var _fire_touch_id: int = -1
## Debug breadcrumb for the smoke test: what the last touch resolved to.
var _last_touch_debug: String = ""
var _pressed_touch_buttons: Dictionary = {}
var _move_origin: Vector2 = Vector2.ZERO
var _move_position: Vector2 = Vector2.ZERO
var _touch_mode: bool = false
var _narrow: bool = false
var _portrait: bool = false
var _physical_size: Vector2 = Vector2.ZERO
var _stretch: float = 1.0
var _ui_scale: float = 1.0
var _top_inset: float = 0.0

# --- Widgets --------------------------------------------------------------- #
var _top_bar: Control
var _health_card: AegisPanel
var _wave_card: AegisPanel
var _system_row: HBoxContainer
var _run_card: AegisPanel
var _score_chip: AegisPanel
var _compact_card: AegisPanel
var _help_panel: AegisPanel
var _desktop_weapon_card: AegisPanel
var _ads_chip: AegisPanel
var _emp_chip: AegisButton
var _scrim: ColorRect

var _health_heading: Label
var _health_value_label: Label
var _health_bar: SegmentedBar
var _wave_title_label: Label
var _wave_state_label: Label
var _wave_enemy_label: Label
var _wave_chip_label: Label
var _wave_icon: TextureRect
var _status_label: Label
var _score_value_label: Label
var _compact_label: Label
var _help_label: Label
var _desktop_hint: Label
var _pause_panel: AegisPanel
var _pause_label: Label
var _pause_stats_label: Label
var _pause_resume_button: AegisButton
var _pause_restart_button: AegisButton
var _results_summary: Label
var _results_title: Label
var _desktop_weapon_name: Label
var _desktop_weapon_meta: Label
var _ads_label: Label

var _fire_button: AegisButton
var _weapon_button: AegisButton
var _skill_button: AegisButton
var _pause_button: AegisButton
var _sound_button: AegisButton
var _aim_button: AegisButton
var _results_retry_button: AegisButton
var _skill_ring: CooldownRing
var _results_panel: AegisPanel

var _touch_buttons: Array[Button] = []
var _compact_wave_text: String = "ENEMIES  0 ACTIVE  ·  0 LEFT"
var _joystick_center: Vector2 = Vector2.ZERO
var _joystick_radius: float = 64.0

# --- Run state ------------------------------------------------------------- #
var _player_down: bool = false
var _hit_confirm_remaining: float = 0.0
var _damage_flash_remaining: float = 0.0
var _skill_cooldown_remaining: float = 0.0
var _skill_cooldown_total: float = 12.0
var _skill_feedback_remaining: float = 0.0
var _aiming: bool = false
var _fire_flash_remaining: float = 0.0
var _help_remaining: float = HELP_VISIBLE_SECONDS
var _run_score: int = 0
var _run_bp: int = 0
var _run_kos: int = 0
var _run_time: String = "00:00"
var _run_shots: int = 0


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	process_mode = Node.PROCESS_MODE_ALWAYS
	_touch_mode = DisplayServer.is_touchscreen_available()
	_build_ui()
	resized.connect(_layout_controls)
	var window := get_window()
	if is_instance_valid(window):
		window.focus_exited.connect(_on_window_focus_exited)
	_layout_controls()
	_apply_input_mode()
	queue_redraw()


func _process(delta: float) -> void:
	var needs_redraw := false
	if _hit_confirm_remaining > 0.0:
		_hit_confirm_remaining = maxf(_hit_confirm_remaining - delta, 0.0)
		needs_redraw = true
	if _damage_flash_remaining > 0.0:
		_damage_flash_remaining = maxf(_damage_flash_remaining - delta, 0.0)
		needs_redraw = true
	if _skill_feedback_remaining > 0.0:
		_skill_feedback_remaining = maxf(_skill_feedback_remaining - delta, 0.0)
		if _skill_feedback_remaining <= 0.0:
			_refresh_skill_button()
	if _fire_flash_remaining > 0.0:
		_fire_flash_remaining = maxf(_fire_flash_remaining - delta, 0.0)
		needs_redraw = true
	if is_instance_valid(_help_panel) and _help_panel.visible and _help_remaining > 0.0:
		_help_remaining = maxf(_help_remaining - delta, 0.0)
		if _help_remaining <= HELP_FADE_SECONDS:
			_help_panel.modulate.a = clampf(_help_remaining / HELP_FADE_SECONDS, 0.0, 1.0)
		if _help_remaining <= 0.0:
			_help_panel.visible = false
	if _aiming and not get_tree().paused:
		needs_redraw = true
	if needs_redraw:
		queue_redraw()


func _input(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		if event.pressed and not _touch_mode:
			# A hybrid laptop or a browser that starts reporting touch after the
			# first tap should still get the thumb controls.
			set_touch_mode(true)
		if event.pressed:
			_begin_touch(event.index, event.position)
		else:
			_end_touch(event.index, event.position)
	elif event is InputEventScreenDrag:
		_update_touch(event.index, event.position, event.relative)
	elif (
		event is InputEventKey
		and event.pressed
		and not event.echo
		and event.keycode == KEY_R
		and get_tree().paused
	):
		retry_requested.emit()
		get_viewport().set_input_as_handled()


# --------------------------------------------------------------------------- #
# Public API (kept compatible with main.gd and the smoke tests)
# --------------------------------------------------------------------------- #


func set_hud_health(current: float, maximum: float) -> void:
	if not is_instance_valid(_health_bar) or not is_instance_valid(_health_value_label):
		return
	var safe_maximum := maxf(maximum, 1.0)
	var safe_current := clampf(current, 0.0, safe_maximum)
	_health_bar.max_value = safe_maximum
	_health_bar.value = safe_current
	_health_value_label.text = "%d / %d" % [roundi(safe_current), roundi(safe_maximum)]
	var health_ratio := safe_current / safe_maximum
	var health_color: Color = DEFAULT_HEALTH_COLOR
	if health_ratio <= 0.3:
		health_color = CRITICAL_HEALTH_COLOR
	elif health_ratio <= 0.6:
		health_color = WARNING_HEALTH_COLOR
	_health_bar.add_theme_stylebox_override("fill", AegisTheme.flat_style(health_color))
	_health_bar.add_theme_stylebox_override(
		"background", AegisTheme.flat_style(Color(AegisTokens.PANEL_3, 0.95))
	)
	if is_instance_valid(_health_card):
		_health_card.accent_color = health_color
	_health_value_label.add_theme_color_override(
		"font_color", health_color if health_ratio <= 0.6 else AegisTokens.INK
	)


func set_wave_status(
	wave_number: int,
	active_enemies: int,
	remaining_enemies: int,
	state_text: String,
) -> void:
	if not is_instance_valid(_wave_title_label):
		return
	_wave_title_label.text = "WAVE %02d" % wave_number if wave_number > 0 else "FRONTIER DEFENSE"
	_wave_state_label.text = state_text.to_upper()
	_wave_enemy_label.text = "ENEMIES  %d ACTIVE  ·  %d LEFT" % [active_enemies, remaining_enemies]
	_wave_chip_label.text = (
		"WAVE %02d\n%d LEFT" % [wave_number, remaining_enemies]
		if wave_number > 0
		else "READY\n%d LEFT" % remaining_enemies
	)
	_compact_wave_text = _wave_enemy_label.text
	_refresh_compact_label()


## Explicit run numbers: the score chip needs the key figure, and parsing the
## three-line status string would be fragile. main.gd calls this every update.
func set_run_summary(score: int, bp: int, kos: int, time_text: String, shots: int) -> void:
	_run_score = score
	_run_bp = bp
	_run_kos = kos
	_run_time = time_text
	_run_shots = shots
	_refresh_score_chip()


func _refresh_score_chip() -> void:
	if not is_instance_valid(_score_value_label):
		return
	_score_value_label.text = "SCORE %s  ·  %s" % [_format_number(_run_score), _run_time]


## Reflects the audio state on the HUD button, wherever the change came from
## (the button itself, the M key, or a restored preference).
func set_sound_muted(muted: bool) -> void:
	if not is_instance_valid(_sound_button):
		return
	_sound_button.icon = AegisTheme.icon("speaker-slash" if muted else "speaker-high", not muted)
	_sound_button.set_meta("aegis_state", "muted" if muted else "on")
	_sound_button.tooltip_text = "Unmute audio (M)" if muted else "Mute audio (M)"
	AegisTheme.set_button_variant(_sound_button, "icon")
	_sound_button.add_theme_color_override(
		"font_color", AegisTokens.DANGER if muted else AegisTokens.INK
	)
	AegisTheme.tint_icon(_sound_button, AegisTokens.DANGER if muted else AegisTokens.INK)


## The control hint is noise once the player has started playing; the first shot
## or the first joystick drag retires it early.
func hide_help() -> void:
	if is_instance_valid(_help_panel):
		_help_panel.visible = false
	_help_remaining = 0.0


## Bring the control hint back (called on retry and when the run starts).
func show_help() -> void:
	if not is_instance_valid(_help_panel):
		return
	_help_remaining = HELP_VISIBLE_SECONDS
	_help_panel.modulate.a = 1.0
	_help_panel.visible = true


## Switches the HUD between thumb controls and a keyboard/mouse legend. Public
## because browser QA and the smoke test drive a touchscreen that the headless
## display server does not report.
func set_touch_mode(enabled: bool) -> void:
	if _touch_mode == enabled:
		return
	_touch_mode = enabled
	_apply_input_mode()
	_layout_controls()
	queue_redraw()


func is_touch_mode() -> bool:
	return _touch_mode


func _apply_input_mode() -> void:
	var desktop := not _touch_mode and not _narrow
	for button in [_fire_button, _aim_button, _skill_button, _weapon_button]:
		if is_instance_valid(button):
			button.visible = _touch_mode
	for control in [_desktop_weapon_card, _ads_chip, _emp_chip]:
		if is_instance_valid(control):
			control.visible = desktop
	if is_instance_valid(_desktop_hint):
		_desktop_hint.visible = not _touch_mode
	if is_instance_valid(_skill_ring):
		_skill_ring.visible = _touch_mode and not _narrow
	if is_instance_valid(_sound_button):
		_sound_button.visible = not _narrow
	if is_instance_valid(_pause_button):
		_pause_button.visible = true


## Lays the HUD out for an explicit viewport size. The public entry point uses
## the control's own rect; tests call this directly so a narrow phone layout can
## be exercised without a real window.
func apply_layout_for_size(viewport_size: Vector2, stretch_scale: float = 0.0) -> void:
	_layout_controls(viewport_size, stretch_scale)


func show_hit_confirmed() -> void:
	_hit_confirm_remaining = HIT_CONFIRM_DURATION
	queue_redraw()


func show_damage_received() -> void:
	_damage_flash_remaining = DAMAGE_FLASH_DURATION
	queue_redraw()


func set_status(text: String) -> void:
	if is_instance_valid(_status_label):
		_status_label.text = text
	_parse_status_fallback(text)
	_refresh_compact_label(text)


## The run-data string is multi-line for the wide card; the compact strip joins
## it into one flowing line so a phone still shows every number.
func _collapsed_run_text(source: String = "") -> String:
	var text := source
	if text.is_empty() and is_instance_valid(_status_label):
		text = _status_label.text
	return text.replace("\n", "  ·  ")


func _refresh_compact_label(source: String = "") -> void:
	if not is_instance_valid(_compact_label):
		return
	_compact_label.text = _compact_wave_text + "\n" + _collapsed_run_text(source)


func set_weapon_label(display_name: String) -> void:
	if is_instance_valid(_weapon_button):
		_weapon_button.text = display_name.to_upper()
	if is_instance_valid(_desktop_weapon_name):
		_desktop_weapon_name.text = display_name.to_upper()


func set_skill_cooldown(remaining_seconds: float, total_seconds: float) -> void:
	_skill_cooldown_total = maxf(total_seconds, 0.0)
	_skill_cooldown_remaining = clampf(remaining_seconds, 0.0, _skill_cooldown_total)
	if _skill_cooldown_remaining <= 0.0:
		_skill_feedback_remaining = 0.0
	_refresh_skill_button()


func show_skill_feedback(targets_hit: int) -> void:
	if not is_instance_valid(_skill_button):
		return
	_skill_feedback_remaining = 1.1
	_skill_button.text = "EMP\n%d HIT" % targets_hit if targets_hit > 0 else "EMP\nNO HIT"
	_skill_button.disabled = (_player_down or get_tree().paused or _skill_cooldown_remaining > 0.0)
	_emp_chip.text = ("EMP · %d HIT" % targets_hit if targets_hit > 0 else "EMP · NO HIT")


func _refresh_skill_button() -> void:
	if not is_instance_valid(_skill_button):
		return
	var fraction := 0.0
	if _skill_cooldown_total > 0.0:
		fraction = clampf(_skill_cooldown_remaining / _skill_cooldown_total, 0.0, 1.0)
	if _skill_feedback_remaining <= 0.0:
		if _skill_cooldown_remaining > 0.0:
			_skill_button.text = "EMP\n%d s" % ceili(_skill_cooldown_remaining)
			_emp_chip.text = "EMP · %d s" % ceili(_skill_cooldown_remaining)
		else:
			_skill_button.text = "EMP\nREADY"
			_emp_chip.text = "EMP · READY"
	_skill_button.disabled = (_player_down or get_tree().paused or _skill_cooldown_remaining > 0.0)
	if is_instance_valid(_emp_chip):
		_emp_chip.disabled = _skill_cooldown_remaining > 0.0 or _player_down
	if is_instance_valid(_skill_ring):
		_skill_ring.remaining = fraction
		_skill_ring.available = _skill_cooldown_remaining <= 0.0
	_skill_button.set_meta(
		"aegis_state", "ready" if _skill_cooldown_remaining <= 0.0 else "cooling"
	)


## External aim state (desktop right mouse), so the reticle tightens even when
## the AIM button is not the thing being held.
func set_aim_state(aiming: bool) -> void:
	if _aiming == aiming:
		return
	_aiming = aiming
	_apply_aim_visual(aiming)
	queue_redraw()


func _apply_aim_visual(aiming: bool) -> void:
	if not is_instance_valid(_aim_button):
		return
	AegisTheme.set_button_variant(_aim_button, "round")
	_aim_button.add_theme_color_override(
		"font_color", AegisTokens.ACCENT_INK if aiming else AegisTokens.INK
	)
	AegisTheme.tint_icon(_aim_button, AegisTokens.ACCENT_INK if aiming else AegisTokens.INK)
	_aim_button.icon = AegisTheme.icon("crosshair", aiming)
	_aim_button.set_meta("aegis_state", "active" if aiming else "idle")


func set_paused(paused: bool) -> void:
	if paused:
		_clear_touch_state()
	if is_instance_valid(_pause_button):
		_pause_button.icon = AegisTheme.icon("play" if paused else "pause", paused)
		_pause_button.set_meta("aegis_state", "resume" if paused else "pause")
		_pause_button.tooltip_text = "Resume (Esc)" if paused else "Pause (Esc)"
		_pause_button.disabled = false
	if is_instance_valid(_pause_panel):
		_pause_panel.visible = paused and not _player_down
	if is_instance_valid(_pause_stats_label):
		_pause_stats_label.text = "SCORE %s  ·  %s" % [_format_number(_run_score), _run_time]
	if is_instance_valid(_scrim):
		_scrim.visible = (paused or _player_down) and not _results_visible()
	if is_instance_valid(_fire_button):
		_fire_button.disabled = paused or _player_down
	if is_instance_valid(_weapon_button):
		_weapon_button.disabled = paused or _player_down
	if is_instance_valid(_aim_button):
		_aim_button.disabled = paused or _player_down
	if paused and _aiming:
		_on_aim_up()
	_refresh_skill_button()


func set_player_down(down: bool) -> void:
	_player_down = down
	if down:
		_clear_touch_state()
	if is_instance_valid(_pause_button):
		_pause_button.icon = AegisTheme.icon(
			"arrow-counter-clockwise" if down else ("play" if get_tree().paused else "pause")
		)
		_pause_button.set_meta("aegis_state", "retry" if down else "pause")
		_pause_button.tooltip_text = "Retry the run" if down else "Pause (Esc)"
	if is_instance_valid(_fire_button):
		_fire_button.disabled = down or get_tree().paused
	if is_instance_valid(_weapon_button):
		_weapon_button.disabled = down or get_tree().paused
	if is_instance_valid(_aim_button):
		_aim_button.disabled = down or get_tree().paused
	if down and _aiming:
		_on_aim_up()
	_refresh_skill_button()


func show_results(
	wave_reached: int,
	survival_time: String,
	eliminations: int,
	run_score: int,
	bp_earned: int,
) -> void:
	if not is_instance_valid(_results_panel):
		return
	_clear_touch_state()
	_results_summary.text = (
		"\n"
		. join(
			[
				"WAVE REACHED      %d" % wave_reached,
				"SURVIVAL TIME     %s" % survival_time,
				"ELIMINATIONS      %d" % eliminations,
				"RUN SCORE         %s" % _format_number(run_score),
				"BATTLE POINTS     +%d" % bp_earned,
			]
		)
	)
	_results_panel.visible = true
	if is_instance_valid(_scrim):
		_scrim.visible = true
	_top_bar.visible = false
	_help_label.visible = false
	if is_instance_valid(_help_panel):
		_help_panel.visible = false
	for control in [
		_fire_button,
		_weapon_button,
		_skill_button,
		_aim_button,
		_pause_button,
		_sound_button,
		_compact_card,
		_score_chip,
		_run_card,
		_desktop_hint,
		_desktop_weapon_card,
		_emp_chip,
		_ads_chip,
		_skill_ring,
	]:
		if is_instance_valid(control):
			control.visible = false
	if is_instance_valid(_pause_panel):
		_pause_panel.visible = false
	_aiming = false
	queue_redraw()


func hide_results() -> void:
	if not is_instance_valid(_results_panel):
		return
	_results_panel.visible = false
	if is_instance_valid(_scrim):
		_scrim.visible = get_tree().paused
	_top_bar.visible = true
	_help_label.visible = true
	_apply_input_mode()
	_layout_controls()
	_refresh_skill_button()
	show_help()


func _results_visible() -> bool:
	return is_instance_valid(_results_panel) and _results_panel.visible


# --------------------------------------------------------------------------- #
# Construction
# --------------------------------------------------------------------------- #


func _build_ui() -> void:
	_top_bar = Control.new()
	_top_bar.name = "PlaytestHUD"
	_top_bar.anchor_left = 0.0
	_top_bar.anchor_right = 1.0
	_top_bar.anchor_top = 0.0
	_top_bar.anchor_bottom = 0.0
	_top_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_top_bar)

	_build_health_card()
	_build_wave_card()
	_build_system_row()
	_build_run_card()
	_build_score_chip()
	_build_compact_card()
	_build_help_panel()
	_build_touch_buttons()
	_build_desktop_chips()
	_build_overlays()


func _build_health_card() -> void:
	_health_card = AegisPanel.new()
	_health_card.name = "HealthCard"
	_health_card.accent_side = "left"
	_health_card.accent_color = AegisTokens.OK
	_health_card.clip_contents = true
	_top_bar.add_child(_health_card)

	var content := VBoxContainer.new()
	content.add_theme_constant_override("separation", 6)
	_health_card.add_child(content)

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	content.add_child(row)
	_health_heading = _label("VITALS", "label", AegisTokens.INK_3)
	row.add_child(_health_heading)
	_health_value_label = _label("100 / 100", "mono_m", AegisTokens.INK)
	_health_value_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_health_value_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(_health_value_label)

	_health_bar = SegmentedBar.new()
	_health_bar.name = "HealthBar"
	_health_bar.min_value = 0.0
	_health_bar.max_value = 100.0
	_health_bar.value = 100.0
	_health_bar.segments = 4
	_health_bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_health_bar.add_theme_stylebox_override(
		"background", AegisTheme.flat_style(AegisTokens.PANEL_3)
	)
	_health_bar.add_theme_stylebox_override("fill", AegisTheme.flat_style(AegisTokens.OK))
	content.add_child(_health_bar)


func _build_wave_card() -> void:
	_wave_card = AegisPanel.new()
	_wave_card.name = "WaveCard"
	_wave_card.clip_contents = true
	_top_bar.add_child(_wave_card)

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	_wave_card.add_child(row)

	_wave_icon = TextureRect.new()
	_wave_icon.texture = AegisTheme.icon("target")
	_wave_icon.custom_minimum_size = Vector2(16.0, 16.0)
	_wave_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_wave_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_wave_icon.modulate = AegisTokens.INK_2
	row.add_child(_wave_icon)

	var text_col := VBoxContainer.new()
	text_col.add_theme_constant_override("separation", 0)
	text_col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(text_col)
	_wave_title_label = _label("FRONTIER DEFENSE", "heading_s", AegisTokens.INK)
	text_col.add_child(_wave_title_label)
	_wave_enemy_label = _label("ENEMIES  0 ACTIVE  ·  0 LEFT", "label_s", AegisTokens.INK_2)
	text_col.add_child(_wave_enemy_label)
	_wave_chip_label = _label("READY\n0 LEFT", "label_s", AegisTokens.INK_2)
	_wave_chip_label.visible = false
	text_col.add_child(_wave_chip_label)

	_wave_state_label = _label("READY", "label_s", AegisTokens.ACCENT)
	_wave_state_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_wave_state_label.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(_wave_state_label)


func _build_system_row() -> void:
	_system_row = HBoxContainer.new()
	_system_row.name = "SystemRow"
	_system_row.add_theme_constant_override("separation", 8)
	_system_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_top_bar.add_child(_system_row)

	_sound_button = _icon_button("SoundButton", "speaker-high", "Mute audio (M)")
	_sound_button.set_meta("aegis_state", "on")
	_system_row.add_child(_sound_button)

	_pause_button = _icon_button("PauseButton", "pause", "Pause (Esc)")
	_pause_button.set_meta("aegis_state", "pause")
	_system_row.add_child(_pause_button)


func _build_run_card() -> void:
	_run_card = AegisPanel.new()
	_run_card.name = "RunDataCard"
	_run_card.clip_contents = true
	add_child(_run_card)

	var content := VBoxContainer.new()
	content.add_theme_constant_override("separation", 3)
	_run_card.add_child(content)
	content.add_child(_label("RUN DATA", "label_s", AegisTokens.INK_3))
	_status_label = _label(
		"Score: 0 · BP earned: 0\nKOs: 0 · Time: 00:00\nTarget 54 / 54 · Shots 0",
		"mono_s",
		AegisTokens.INK_2
	)
	_status_label.name = "StatusLabel"
	_status_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	content.add_child(_status_label)


func _build_score_chip() -> void:
	_score_chip = AegisPanel.new()
	_score_chip.name = "ScoreChip"
	_score_chip.show_brackets = false
	add_child(_score_chip)
	_score_value_label = _label("SCORE 0  ·  00:00", "mono_m", AegisTokens.INK)
	_score_value_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_score_value_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_score_value_label.autowrap_mode = TextServer.AUTOWRAP_OFF
	_score_chip.add_child(_score_value_label)


## One-line-per-topic strip shown below the top bar on narrow screens, where the
## three-column bar cannot fit: the player keeps the enemy counts and run stats.
func _build_compact_card() -> void:
	_compact_card = AegisPanel.new()
	_compact_card.name = "CompactDataCard"
	_compact_card.visible = false
	_compact_card.clip_contents = true
	add_child(_compact_card)
	_compact_label = _label(
		_compact_wave_text + "\n" + _collapsed_run_text(), "mono_s", AegisTokens.INK_2
	)
	_compact_label.name = "CompactDataLabel"
	_compact_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_compact_card.add_child(_compact_label)


func _build_help_panel() -> void:
	_help_panel = AegisPanel.new()
	_help_panel.name = "ControlsHelpPanel"
	_help_panel.accent_side = "left"
	_help_panel.accent_color = Color(AegisTokens.INFO, 0.9)
	_help_panel.clip_contents = true
	_help_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_help_panel)
	_help_label = _label(
		(
			"TOUCH: 360° joystick moves · drag right to aim · hold FIRE / AIM · EMP is the skill\n"
			+ "DESKTOP: WASD moves · Shift sprint · Space jump · RMB aims · hold LMB to fire\n"
			+ "E / Q or 1-3 switch weapons · F EMP · R retries · Esc pauses"
		),
		"caption",
		AegisTokens.INK_2,
		1.0,
		true
	)
	_help_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_help_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	_help_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_help_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_help_panel.add_child(_help_label)


func _build_touch_buttons() -> void:
	_fire_button = _text_button("FIRE", "FireButton", "fire", "crosshair", "Hold to fire")
	_fire_button.add_theme_constant_override("icon_max_width", 22)
	_fire_button.button_down.connect(_on_fire_down)
	_fire_button.button_up.connect(_on_fire_up)

	_weapon_button = _text_button(
		"PULSE RIFLE", "WeaponSwitchButton", "round", "", "Tap to cycle weapons"
	)
	_weapon_button.set_meta("aegis_state", "idle")
	_weapon_button.pressed.connect(_on_weapon_switch_pressed)

	_aim_button = _text_button("AIM", "AimButton", "round", "crosshair", "Hold to aim down sights")
	_aim_button.add_theme_constant_override("icon_max_width", 16)
	_aim_button.button_down.connect(_on_aim_down)
	_aim_button.button_up.connect(_on_aim_up)

	_skill_button = _text_button(
		"EMP\nREADY", "SkillButton", "ability", "", "EMP Pulse: damage nearby enemies"
	)
	_skill_button.pressed.connect(_on_skill_pressed)
	_skill_button.set_meta("aegis_state", "ready")

	_skill_ring = CooldownRing.new()
	_skill_ring.name = "SkillCooldownRing"
	add_child(_skill_ring)


func _build_desktop_chips() -> void:
	_desktop_weapon_card = AegisPanel.new()
	_desktop_weapon_card.name = "DesktopWeaponCard"
	_desktop_weapon_card.clip_contents = true
	add_child(_desktop_weapon_card)
	var weapon_col := VBoxContainer.new()
	weapon_col.add_theme_constant_override("separation", 3)
	_desktop_weapon_card.add_child(weapon_col)
	weapon_col.add_child(_label("ACTIVE WEAPON", "label_s", AegisTokens.INK_3))
	_desktop_weapon_name = _label("PULSE RIFLE", "title", AegisTokens.INK)
	weapon_col.add_child(_desktop_weapon_name)
	_desktop_weapon_meta = _label("E / Q SWAP · 1-3 SLOTS", "label_s", AegisTokens.INK_3)
	weapon_col.add_child(_desktop_weapon_meta)

	_emp_chip = AegisButton.new()
	_emp_chip.name = "DesktopEmpChip"
	_emp_chip.text = "EMP · READY"
	_emp_chip.focus_mode = Control.FOCUS_NONE
	_emp_chip.mouse_filter = Control.MOUSE_FILTER_STOP
	_emp_chip.icon = AegisTheme.icon("lightning", true)
	_emp_chip.add_theme_constant_override("icon_max_width", 16)
	AegisTheme.set_button_variant(_emp_chip, "ability")
	_emp_chip.pressed.connect(_on_skill_pressed)
	add_child(_emp_chip)
	_touch_buttons.append(_emp_chip)

	_ads_chip = AegisPanel.new()
	_ads_chip.name = "AdsChip"
	_ads_chip.show_brackets = false
	add_child(_ads_chip)
	var ads_row := HBoxContainer.new()
	ads_row.add_theme_constant_override("separation", 6)
	_ads_chip.add_child(ads_row)
	var ads_icon := TextureRect.new()
	ads_icon.texture = AegisTheme.icon("crosshair-simple")
	ads_icon.custom_minimum_size = Vector2(14.0, 14.0)
	ads_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	ads_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	ads_icon.modulate = AegisTokens.INK_2
	ads_row.add_child(ads_icon)
	_ads_label = _label("ADS", "label_s", AegisTokens.INK_2)
	_ads_label.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	ads_row.add_child(_ads_label)

	_desktop_hint = _label(DESKTOP_HINT, "label_s", AegisTokens.INK_2, 1.0, true)
	_desktop_hint.name = "DesktopHint"
	add_child(_desktop_hint)


func _build_overlays() -> void:
	_scrim = ColorRect.new()
	_scrim.name = "HudScrim"
	_scrim.color = Color(AegisTokens.VOID, AegisTokens.SCRIM_ALPHA)
	_scrim.anchor_right = 1.0
	_scrim.anchor_bottom = 1.0
	# The scrim is visual only: it must not swallow the click/tap that lands on
	# the pause or results buttons sitting above it. Touch input is gated by
	# `get_tree().paused` / `_player_down` instead.
	_scrim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_scrim.visible = false
	add_child(_scrim)

	_build_pause_menu()
	_build_results_panel()


## Pause is a sibling of the results card: same panel language, same button
## hierarchy. RESUME is the first (and default) action, RESTART the second.
func _build_pause_menu() -> void:
	_pause_panel = AegisPanel.new()
	_pause_panel.name = "PausePanel"
	_pause_panel.interactive = true
	_pause_panel.visible = false
	add_child(_pause_panel)

	var content := VBoxContainer.new()
	content.add_theme_constant_override("separation", 12)
	_pause_panel.add_child(content)

	var eyebrow := _label("RUN SUSPENDED", "label", AegisTokens.ACCENT)
	content.add_child(eyebrow)
	_pause_label = _label("PAUSED", "display_l", AegisTokens.INK)
	content.add_child(_pause_label)
	_pause_stats_label = _label("SCORE 0  ·  00:00", "mono_m", AegisTokens.INK_2)
	content.add_child(_pause_stats_label)

	var rule := ColorRect.new()
	rule.color = AegisTokens.LINE
	rule.custom_minimum_size = Vector2(0.0, 1.0)
	content.add_child(rule)

	_pause_resume_button = AegisButton.new()
	_pause_resume_button.name = "ResumeButton"
	_pause_resume_button.text = "RESUME"
	_pause_resume_button.focus_mode = Control.FOCUS_NONE
	_pause_resume_button.mouse_filter = Control.MOUSE_FILTER_STOP
	_pause_resume_button.icon = AegisTheme.icon("play", true)
	_pause_resume_button.add_theme_constant_override("icon_max_width", 18)
	AegisTheme.set_button_variant(_pause_resume_button, "primary")
	_pause_resume_button.pressed.connect(_on_pause_pressed)
	content.add_child(_pause_resume_button)
	_touch_buttons.append(_pause_resume_button)

	_pause_restart_button = AegisButton.new()
	_pause_restart_button.name = "RestartButton"
	_pause_restart_button.text = "RESTART RUN"
	_pause_restart_button.focus_mode = Control.FOCUS_NONE
	_pause_restart_button.mouse_filter = Control.MOUSE_FILTER_STOP
	_pause_restart_button.icon = AegisTheme.icon("arrow-counter-clockwise")
	_pause_restart_button.add_theme_constant_override("icon_max_width", 18)
	AegisTheme.set_button_variant(_pause_restart_button, "ghost")
	_pause_restart_button.pressed.connect(_on_restart_pressed)
	content.add_child(_pause_restart_button)
	_touch_buttons.append(_pause_restart_button)

	var hint := _label("ESC  ·  RESUME  ·  R  ·  RESTART", "label_s", AegisTokens.INK_3)
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	content.add_child(hint)


func _build_results_panel() -> void:
	_results_panel = AegisPanel.new()
	_results_panel.name = "ResultsPanel"
	_results_panel.interactive = true
	_results_panel.visible = false
	add_child(_results_panel)

	var content := VBoxContainer.new()
	content.add_theme_constant_override("separation", 12)
	_results_panel.add_child(content)

	content.add_child(_label("RUN COMPLETE", "label", AegisTokens.ACCENT))
	_results_title = _label("RUN RESULTS", "display_l", AegisTokens.INK)
	content.add_child(_results_title)

	var rule := ColorRect.new()
	rule.color = AegisTokens.LINE
	rule.custom_minimum_size = Vector2(0.0, 1.0)
	content.add_child(rule)

	_results_summary = _label("", "mono_m", AegisTokens.INK_2)
	_results_summary.autowrap_mode = TextServer.AUTOWRAP_OFF
	_results_summary.size_flags_vertical = Control.SIZE_EXPAND_FILL
	content.add_child(_results_summary)

	_results_retry_button = AegisButton.new()
	_results_retry_button.name = "ResultsRetryButton"
	_results_retry_button.text = "RETRY"
	_results_retry_button.focus_mode = Control.FOCUS_NONE
	_results_retry_button.mouse_filter = Control.MOUSE_FILTER_STOP
	_results_retry_button.icon = AegisTheme.icon("arrow-counter-clockwise")
	_results_retry_button.add_theme_constant_override("icon_max_width", 18)
	AegisTheme.set_button_variant(_results_retry_button, "primary")
	_results_retry_button.pressed.connect(_on_results_retry_pressed)
	content.add_child(_results_retry_button)
	_touch_buttons.append(_results_retry_button)


# --------------------------------------------------------------------------- #
# Small factories
# --------------------------------------------------------------------------- #


func _label(
	text: String, role: String, color: Color, multiplier: float = 1.0, shadow: bool = false
) -> Label:
	var label := Label.new()
	label.text = text
	AegisTheme.style_label(label, role, color, 1.0, shadow)
	label.set_meta("aegis_role", role)
	label.set_meta("aegis_scale", multiplier)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return label


func _register_type(control: Control, role: String, _color: Color, multiplier: float = 1.0) -> void:
	control.set_meta("aegis_role", role)
	control.set_meta("aegis_scale", multiplier)


func _icon_button(button_name: String, icon_name: String, tooltip: String) -> AegisButton:
	var button := AegisButton.new()
	button.name = button_name
	button.text = ""
	button.tooltip_text = tooltip
	button.focus_mode = Control.FOCUS_NONE
	button.mouse_filter = Control.MOUSE_FILTER_STOP
	button.icon = AegisTheme.icon(icon_name, true)
	button.expand_icon = false
	button.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
	button.add_theme_constant_override("icon_max_width", 20)
	button.add_theme_font_size_override("font_size", 11)
	AegisTheme.set_button_variant(button, "icon")
	if button_name == "SoundButton":
		button.pressed.connect(_on_sound_pressed)
	else:
		button.pressed.connect(_on_pause_pressed)
	# The caller reparents the button into `_system_row`; adding it to the HUD
	# first and then calling add_child() again fails in Godot, which left the
	# pause and sound buttons floating at the top-left corner of the screen.
	_touch_buttons.append(button)
	return button


func _text_button(
	label_text: String, button_name: String, variant: String, icon_name: String, tooltip: String
) -> AegisButton:
	var button := AegisButton.new()
	button.name = button_name
	button.text = label_text
	button.tooltip_text = tooltip
	button.focus_mode = Control.FOCUS_NONE
	button.mouse_filter = Control.MOUSE_FILTER_STOP
	if not icon_name.is_empty():
		button.icon = AegisTheme.icon(icon_name, variant == "fire")
	button.add_theme_constant_override("icon_max_width", 18)
	button.add_theme_constant_override("h_separation", 6)
	AegisTheme.set_button_variant(button, variant)
	button.set_meta("aegis_state", "idle")
	add_child(button)
	_touch_buttons.append(button)
	return button


# --------------------------------------------------------------------------- #
# Layout
# --------------------------------------------------------------------------- #


func _layout_controls(
	viewport_override: Vector2 = Vector2.ZERO, stretch_override: float = 0.0
) -> void:
	if not is_instance_valid(_top_bar):
		return
	# Size against the *physical* window, not the logical canvas: with stretch
	# mode canvas_items the logical canvas keeps its width on a phone and is
	# only scaled down, so a portrait HUD laid out in logical units would render
	# at ~30 % of its designed size.
	var physical := (
		viewport_override if viewport_override != Vector2.ZERO else _resolve_physical_size()
	)
	_physical_size = physical
	var physical_width := maxf(physical.x, 320.0)
	var physical_height := maxf(physical.y, 320.0)
	_stretch = stretch_override if stretch_override > 0.0 else _compute_stretch(physical)
	_ui_scale = clampf(minf(physical_width, physical_height) / 720.0, 0.64, 1.0)
	_top_inset = _resolve_top_inset()
	_narrow = physical_width < NARROW_WIDTH
	if is_instance_valid(_desktop_hint):
		_desktop_hint.text = DESKTOP_HINT_SHORT if _narrow else DESKTOP_HINT
	_portrait = physical_height > physical_width

	_refresh_card_styles()
	_apply_font_scale()
	if not _touch_mode and not _narrow:
		HudLayout.desktop(self)
	elif _portrait:
		HudLayout.touch_portrait(self)
	else:
		HudLayout.touch_landscape(self)

	_layout_overlays()
	_apply_input_mode()
	queue_redraw()


func _show_top_wave_details(wide: bool) -> void:
	_wave_title_label.visible = wide
	_wave_enemy_label.visible = wide
	_wave_chip_label.visible = not wide
	_wave_state_label.visible = wide
	_health_heading.visible = wide
	_wave_state_label.add_theme_color_override("font_color", AegisTokens.ACCENT)


func _help_block_height(lines: int) -> float:
	var font := float(_help_label.get_theme_font_size("font_size"))
	return font * 1.45 * float(lines) + _to_layout(16.0)


func _layout_overlays() -> void:
	if is_instance_valid(_scrim):
		_scrim.anchor_right = 1.0
		_scrim.anchor_bottom = 1.0
		_scrim.offset_right = 0.0
		_scrim.offset_bottom = 0.0
	var panel_width := minf(_to_layout(600.0), size.x * 0.92)
	var panel_height := minf(_to_layout(528.0), size.y * 0.9)
	_results_panel.custom_minimum_size = Vector2(panel_width, panel_height)
	HudLayout.place(
		self,
		_results_panel,
		0.5,
		0.5,
		0.5,
		0.5,
		Rect2(-panel_width * 0.5, -panel_height * 0.5, panel_width, panel_height)
	)
	_results_retry_button.custom_minimum_size = Vector2(
		minf(_to_layout(240.0), panel_width - _to_layout(48.0)), _to_layout(52.0)
	)
	_results_retry_button.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	if is_instance_valid(_pause_panel):
		var pause_width := minf(_to_layout(400.0), size.x * 0.88)
		var pause_height := minf(_to_layout(330.0), size.y * 0.84)
		HudLayout.place(
			self,
			_pause_panel,
			0.5,
			0.5,
			0.5,
			0.5,
			Rect2(-pause_width * 0.5, -pause_height * 0.5, pause_width, pause_height)
		)
		for button in [_pause_resume_button, _pause_restart_button]:
			if is_instance_valid(button):
				button.custom_minimum_size = Vector2(0.0, _to_layout(52.0))


## Card padding is expressed in physical pixels so a 168 px phone rail gets the
## same 8 px breathing room as a 268 px desktop card.
func _refresh_card_styles() -> void:
	var pad := _to_layout(10.0)
	var tight := _to_layout(8.0)
	var fill := Color(AegisTokens.PANEL, AegisTokens.PANEL_ALPHA)
	_health_card.add_theme_stylebox_override(
		"panel", AegisTheme.panel_style(fill, AegisTokens.LINE, 1, AegisTokens.RADIUS, pad)
	)
	_wave_card.add_theme_stylebox_override(
		"panel", AegisTheme.panel_style(fill, AegisTokens.LINE, 1, AegisTokens.RADIUS, tight)
	)
	_run_card.add_theme_stylebox_override(
		"panel", AegisTheme.panel_style(fill, AegisTokens.LINE, 1, AegisTokens.RADIUS, pad)
	)
	_score_chip.add_theme_stylebox_override(
		"panel", AegisTheme.panel_style(fill, AegisTokens.LINE, 1, AegisTokens.RADIUS, tight)
	)
	_compact_card.add_theme_stylebox_override(
		"panel", AegisTheme.panel_style(fill, AegisTokens.LINE, 1, AegisTokens.RADIUS, pad)
	)
	_help_panel.add_theme_stylebox_override(
		"panel",
		AegisTheme.panel_style(
			Color(AegisTokens.VOID, 0.86), Color(AegisTokens.LINE, 0.9), 1, AegisTokens.RADIUS, pad
		)
	)
	_desktop_weapon_card.add_theme_stylebox_override(
		"panel", AegisTheme.panel_style(fill, AegisTokens.LINE, 1, AegisTokens.RADIUS, pad)
	)
	_ads_chip.add_theme_stylebox_override(
		"panel", AegisTheme.panel_style(fill, AegisTokens.LINE, 1, AegisTokens.RADIUS, tight)
	)
	_pause_panel.add_theme_stylebox_override(
		"panel",
		AegisTheme.panel_style(
			Color(AegisTokens.PANEL, 0.97),
			Color(AegisTokens.LINE_HI, 0.9),
			1,
			AegisTokens.RADIUS,
			_to_layout(24.0)
		)
	)
	_results_panel.add_theme_stylebox_override(
		"panel",
		AegisTheme.panel_style(
			Color(AegisTokens.PANEL, 0.97),
			Color(AegisTokens.LINE_HI, 0.9),
			1,
			AegisTokens.RADIUS,
			_to_layout(24.0)
		)
	)
	if is_instance_valid(_health_bar):
		_health_bar.custom_minimum_size = Vector2(0.0, _to_layout(6.0))
		_health_bar.gap_width = maxf(_to_layout(2.0), 1.0)
	if is_instance_valid(_wave_icon):
		var icon_size := _to_layout(16.0)
		_wave_icon.custom_minimum_size = Vector2(icon_size, icon_size)
	if is_instance_valid(_results_retry_button):
		_results_retry_button.add_theme_constant_override(
			"icon_max_width", roundi(_to_layout(18.0))
		)


func _apply_font_scale() -> void:
	var floor_size := _minimum_font_size()
	var unit := _control_unit()
	for node in find_children("*", "Label", true, false):
		var label := node as Label
		if label == null or not label.has_meta("aegis_role"):
			continue
		var role := String(label.get_meta("aegis_role"))
		var multiplier := float(label.get_meta("aegis_scale", 1.0))
		var text_size := maxi(
			roundi(float(AegisTheme.type_size(role)) * unit * multiplier), floor_size
		)
		AegisTheme.resize_label(label, role, text_size)
	for node in find_children("*", "Button", true, false):
		var button := node as Button
		if button == null:
			continue
		button.add_theme_font_size_override("font_size", floor_size)
		if button == _fire_button:
			AegisTheme.resize_button_font(button, "title", maxi(roundi(15.0 * unit), floor_size))
		elif button == _weapon_button or button == _skill_button or button == _aim_button:
			AegisTheme.resize_button_font(button, "label", maxi(roundi(11.0 * unit), floor_size))
		elif (
			button == _results_retry_button
			or button == _pause_resume_button
			or button == _pause_restart_button
		):
			AegisTheme.resize_button_font(button, "title", maxi(roundi(15.0 * unit), floor_size))
	if is_instance_valid(_health_bar):
		_health_bar.custom_minimum_size.y = maxf(_to_layout(6.0), 3.0)
	# Icons are raster assets; size them in physical pixels so a 20 px glyph on
	# desktop is still 20 px on a phone instead of shrinking with the canvas.
	var icon_px := maxi(roundi(_to_layout(18.0)), 12)
	var icon_button_px := maxf(_to_layout(44.0), 32.0)
	for icon_button in [_pause_button, _sound_button]:
		if is_instance_valid(icon_button):
			icon_button.custom_minimum_size = Vector2(icon_button_px, icon_button_px)
	for button in [
		_fire_button,
		_weapon_button,
		_skill_button,
		_aim_button,
		_pause_button,
		_sound_button,
		_emp_chip
	]:
		if is_instance_valid(button):
			button.add_theme_constant_override("icon_max_width", icon_px)


# --------------------------------------------------------------------------- #
# Geometry helpers
# --------------------------------------------------------------------------- #


## Physical window size, with a sane fallback for headless runs where there is no
## window at all.
func _resolve_physical_size() -> Vector2:
	var window := get_window()
	if is_instance_valid(window):
		var window_size := Vector2(window.size)
		# A headless run reports a 64x64 dummy window; trusting it would make the
		# HUD believe every viewport is a phone and hide the desktop legend.
		if window_size.x >= MIN_WINDOW_PX and window_size.y >= MIN_WINDOW_PX:
			return window_size
	return size


## How many physical pixels one logical canvas unit occupies. With stretch mode
## canvas_items this is the uniform scale the engine applies to the canvas.
func _compute_stretch(physical: Vector2) -> float:
	if size.x <= 0.0 or size.y <= 0.0 or physical.x <= 0.0 or physical.y <= 0.0:
		return 1.0
	return maxf(minf(physical.x / size.x, physical.y / size.y), 0.0001)


## Converts physical pixels into the logical units the HUD lays out in.
func _to_layout(physical_pixels: float) -> float:
	return physical_pixels / _stretch


func _control_unit() -> float:
	return _ui_scale / _stretch


## Font size (in logical canvas units) that renders as [constant
## MIN_PHYSICAL_FONT_PX] on the actual screen.
func _minimum_font_size() -> int:
	return maxi(roundi(MIN_PHYSICAL_FONT_PX / maxf(_stretch, 0.0001)), 11)


## Keep the HUD clear of notches and of the browser shell chrome.
func _resolve_top_inset() -> float:
	var physical := _physical_size if _physical_size != Vector2.ZERO else size
	var inset := 20.0 if not _touch_mode else 12.0
	if OS.has_feature("web"):
		# Browser chips wrap onto two rows on a narrow screen; reserve for that.
		inset = maxf(
			inset, WEB_TOP_INSET + (WEB_TOP_INSET * 0.8 if physical.x < physical.y else 0.0)
		)
	var safe_area := DisplayServer.get_display_safe_area()
	if safe_area.position.y > 0:
		inset = maxf(inset, float(safe_area.position.y))
	return _to_layout(inset)


func _format_number(value: int) -> String:
	var digits := str(absi(value))
	var grouped := ""
	while digits.length() > 3:
		grouped = "," + digits.substr(digits.length() - 3) + grouped
		digits = digits.substr(0, digits.length() - 3)
	return ("-" if value < 0 else "") + digits + grouped


## Fallback for callers that only hand the HUD its three-line status string
## (the smoke test does). main.gd calls set_run_summary with exact numbers.
func _parse_status_fallback(text: String) -> void:
	var score := _run_score
	var time_text := _run_time
	var parts := text.replace("\n", " · ").split("·")
	for part in parts:
		var piece := part.strip_edges()
		if piece.begins_with("Score:"):
			score = int(piece.trim_prefix("Score:").strip_edges())
		elif piece.begins_with("Time:"):
			time_text = piece.trim_prefix("Time:").strip_edges()
	_run_score = score
	_run_time = time_text
	_refresh_score_chip()


# --------------------------------------------------------------------------- #
# Touch input
# --------------------------------------------------------------------------- #


func _begin_touch(touch_id: int, position: Vector2) -> void:
	var touched_button := _find_touch_button(position)
	_last_touch_debug = (
		"id=%d pos=%s hit=%s"
		% [touch_id, position, touched_button.name if is_instance_valid(touched_button) else "none"]
	)
	if is_instance_valid(touched_button):
		get_viewport().set_input_as_handled()
		if (
			touched_button == _fire_button
			and not touched_button.disabled
			and not _player_down
			and not get_tree().paused
			and _fire_touch_id == -1
		):
			_fire_touch_id = touch_id
			hide_help()
			_fire_flash_remaining = 1.0
			fire_changed.emit(true)
			queue_redraw()
		else:
			_pressed_touch_buttons[touch_id] = touched_button
			if not touched_button.disabled:
				# Godot buttons only fire `pressed` on release, so a hold button
				# (AIM) also needs its press forwarded here.
				touched_button.emit_signal("button_down")
		return
	if (
		_player_down
		or get_tree().paused
		or _is_over_hud(position)
		or (is_instance_valid(_scrim) and _scrim.visible)
	):
		return
	if position.y < size.y * 0.2:
		return
	if position.x < size.x * 0.47 and _move_touch_id == -1:
		_move_touch_id = touch_id
		_move_origin = position
		_move_position = position
		movement_changed.emit(Vector2.ZERO)
		queue_redraw()
	elif position.x >= size.x * 0.47 and _look_touch_id == -1:
		_look_touch_id = touch_id


func _update_touch(touch_id: int, position: Vector2, relative: Vector2) -> void:
	if touch_id == _fire_touch_id or _pressed_touch_buttons.has(touch_id):
		get_viewport().set_input_as_handled()
		return
	if _player_down or get_tree().paused:
		_clear_touch_state()
		return
	if touch_id == _move_touch_id:
		_move_position = position
		var radius := maxf(_joystick_radius, 1.0)
		var offset := (position - _move_origin) / radius
		if offset.length() > 0.25:
			hide_help()
		movement_changed.emit(offset.limit_length(1.0))
		queue_redraw()
	elif touch_id == _look_touch_id:
		look_delta.emit(relative)


func _end_touch(touch_id: int, position: Vector2) -> void:
	if touch_id == _fire_touch_id:
		_fire_touch_id = -1
		fire_changed.emit(false)
		get_viewport().set_input_as_handled()
		return
	if _pressed_touch_buttons.has(touch_id):
		var button := _pressed_touch_buttons[touch_id] as Button
		_pressed_touch_buttons.erase(touch_id)
		get_viewport().set_input_as_handled()
		if is_instance_valid(button):
			button.emit_signal("button_up")
		if (
			is_instance_valid(button)
			and not button.disabled
			and button.get_global_rect().has_point(position)
		):
			_activate_touch_button(button)
		return
	if touch_id == _move_touch_id:
		_move_touch_id = -1
		movement_changed.emit(Vector2.ZERO)
		queue_redraw()
	elif touch_id == _look_touch_id:
		_look_touch_id = -1


func _clear_touch_state() -> void:
	_move_touch_id = -1
	_look_touch_id = -1
	_fire_touch_id = -1
	_pressed_touch_buttons.clear()
	_move_origin = Vector2.ZERO
	_move_position = Vector2.ZERO
	movement_changed.emit(Vector2.ZERO)
	fire_changed.emit(false)
	queue_redraw()


func _find_touch_button(position: Vector2) -> Button:
	# Pick the smallest target containing the touch: the AIM button sits close to
	# FIRE and an overlapping (larger) control must not steal the press.
	var best: Button = null
	var best_area := INF
	for button in _touch_buttons:
		if not is_instance_valid(button) or not button.is_visible_in_tree():
			continue
		var rect := button.get_global_rect()
		if not rect.has_point(position):
			continue
		var area := rect.size.x * rect.size.y
		if area < best_area:
			best_area = area
			best = button
	return best


func _activate_touch_button(button: Button) -> void:
	if button == _weapon_button:
		_on_weapon_switch_pressed()
	elif button == _skill_button or button == _emp_chip:
		_on_skill_pressed()
	elif button == _pause_button:
		_on_pause_pressed()
	elif button == _sound_button:
		_on_sound_pressed()
	elif button == _results_retry_button:
		_on_results_retry_pressed()
	elif button == _pause_resume_button:
		_on_pause_pressed()
	elif button == _pause_restart_button:
		_on_restart_pressed()


func _is_over_hud(position: Vector2) -> bool:
	var hud_controls: Array[Control] = [
		_top_bar,
		_help_panel,
		_fire_button,
		_weapon_button,
		_skill_button,
		_aim_button,
		_pause_panel,
		_results_panel,
		_run_card,
		_score_chip,
		_desktop_weapon_card,
		_emp_chip,
		_ads_chip,
		_compact_card,
	]
	for control in hud_controls:
		if (
			is_instance_valid(control)
			and control.visible
			and control.get_global_rect().has_point(position)
		):
			return true
	return false


# --------------------------------------------------------------------------- #
# Drawing
# --------------------------------------------------------------------------- #


func _draw() -> void:
	if _damage_flash_remaining > 0.0:
		HudRenderer.damage_vignette(
			self,
			size,
			_damage_flash_remaining / DAMAGE_FLASH_DURATION,
			maxf(_to_layout(14.0), 2.0),
			AegisTokens.DANGER
		)
	if _results_visible() or (is_instance_valid(_scrim) and _scrim.visible and _player_down):
		return
	if not _player_down and not get_tree().paused:
		var spread := 5.0 + _fire_flash_remaining * 46.0
		if _move_touch_id != -1:
			spread += 4.0
		if _aiming:
			spread *= 0.45
		HudRenderer.crosshair(
			self,
			size * 0.5,
			_to_layout(12.0 + spread),
			maxf(_to_layout(6.0), 2.0),
			maxf(_to_layout(1.5), 1.0),
			AegisTokens.INK,
			Color(AegisTokens.VOID, 0.7),
			_hit_confirm_remaining > 0.0,
			maxf(_to_layout(1.0), 0.75)
		)
	if _touch_mode or _move_touch_id != -1:
		HudRenderer.joystick(
			self,
			_move_origin if _move_touch_id != -1 else _joystick_center,
			_joystick_radius,
			_move_position if _move_touch_id != -1 else _joystick_center,
			maxf(_to_layout(1.0), 1.0)
		)


# --------------------------------------------------------------------------- #
# Callbacks
# --------------------------------------------------------------------------- #


func _on_sound_pressed() -> void:
	sound_mute_requested.emit()


func _on_fire_down() -> void:
	if not _player_down and not get_tree().paused:
		hide_help()
		_fire_flash_remaining = 1.0
		queue_redraw()
		fire_changed.emit(true)


func _on_fire_up() -> void:
	fire_changed.emit(false)


func _on_aim_down() -> void:
	if _player_down or get_tree().paused:
		return
	_aiming = true
	_apply_aim_visual(true)
	queue_redraw()
	aim_changed.emit(true)


func _on_aim_up() -> void:
	_aiming = false
	_apply_aim_visual(false)
	queue_redraw()
	aim_changed.emit(false)


func _on_weapon_switch_pressed() -> void:
	if not _player_down and not get_tree().paused:
		Sfx.play_ui(&"ui_click")
		weapon_switch_requested.emit()


func _on_skill_pressed() -> void:
	if not _player_down and not get_tree().paused and _skill_cooldown_remaining <= 0.0:
		Sfx.play_ui(&"ui_click")
		skill_requested.emit()


func _on_pause_pressed() -> void:
	Sfx.play_ui(&"ui_click")
	if _player_down:
		retry_requested.emit()
	else:
		pause_requested.emit()


func _on_results_retry_pressed() -> void:
	Sfx.play_ui(&"ui_click")
	retry_requested.emit()


func _on_window_focus_exited() -> void:
	_clear_touch_state()
