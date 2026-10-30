## The context-sensitive objective rail and opt-in encounter action. The HUD
## facade owns signals and input; this helper keeps the visual mode policy in
## one place without creating a second controller or a second gameplay state.
class_name HudEncounterUi
extends RefCounted

## Explore-mode copy per theatre, resolved once. The card used to print one
## world's words in every world.
static var _zone_copy: Array = []
static var _zone_copy_id: StringName = &""


static func zone_copy(hud) -> Array:
	var world_id := WorldSelection.selected(hud)
	# `_zone_copy_id` starts empty and so can a real selection: the HUD also runs
	# outside the gameplay tree, where no service answers. The emptiness check is
	# what keeps that first call from returning an array that was never filled.
	if _zone_copy.is_empty() or _zone_copy_id != world_id:
		_zone_copy_id = world_id
		var definition := WorldDefinition.load_definition(world_id)
		if definition != null:
			_zone_copy = [definition.display_zone_title(), definition.display_zone_subtitle()]
		else:
			_zone_copy = [
				AegisText.t("hud.zone_title_fallback"),
				AegisText.t("hud.zone_subtitle_fallback"),
			]
	return _zone_copy


static func update_objective(
	hud, wave_number: int, _active_enemies: int, remaining_enemies: int, state_text: String
) -> void:
	if not is_instance_valid(hud._wave_title_label):
		return
	if hud._state.play_phase == "explore":
		if hud._state.recovery_active:
			refresh_recovery_objective(hud)
			return
		var copy: Array = zone_copy(hud)
		hud._wave_title_label.text = copy[0]
		hud._wave_enemy_label.text = copy[1]
		AegisText.apply(hud._wave_state_label, "hud.no_hostiles")
		AegisText.apply(hud._wave_chip_label, "hud.chip_explore")
	elif hud._state.play_phase == "preparing":
		AegisText.apply(hud._wave_title_label, "hud.defense_in", [hud._state.preparation_seconds])
		# Keep the promise readable in a 294 px objective card.
		AegisText.apply(hud._wave_enemy_label, "hud.get_ready")
		AegisText.apply(hud._wave_state_label, "hud.prepare")
		AegisText.apply(
			hud._wave_chip_label, "hud.chip_defense_in", [hud._state.preparation_seconds]
		)
	else:
		if wave_number > 0:
			AegisText.apply(hud._wave_title_label, "hud.wave", [wave_number])
		else:
			AegisText.apply(hud._wave_title_label, "hud.frontier_defense")
		hud._wave_state_label.text = state_text.to_upper()
		# The action earns visible currency now; the full accounting stays in
		# Results. Active count remains in the wave state (ACTIVE n/max).
		(
			AegisText
			. apply(
				hud._wave_enemy_label,
				"hud.left_ko_bp",
				[remaining_enemies, hud._state.kos, hud._state.bp],
			)
		)
		if wave_number > 0:
			AegisText.apply(hud._wave_chip_label, "hud.chip_wave", [wave_number, remaining_enemies])
		else:
			AegisText.apply(hud._wave_chip_label, "hud.chip_ready", [remaining_enemies])
	hud._compact_wave_text = hud._wave_enemy_label.text
	hud._refresh_compact_label()


static func refresh_recovery_objective(hud) -> void:
	if (
		not is_instance_valid(hud._wave_title_label)
		or hud._state.play_phase != "explore"
		or not hud._state.recovery_active
	):
		return
	hud._wave_title_label.text = hud._state.recovery_title
	hud._wave_enemy_label.text = hud._state.recovery_detail
	hud._wave_state_label.text = hud._state.recovery_state
	if is_instance_valid(hud._wave_state_label):
		hud._wave_state_label.visible = (
			hud._state.recovery_guard_count > 0 and not hud._state.recovery_state.is_empty()
		)
	AegisText.apply(hud._wave_chip_label, "hud.chip_recovery")
	hud._compact_wave_text = hud._wave_enemy_label.text
	hud._refresh_compact_label()


## Read-only browser diagnostics for the real Recovery state machine. The log
## is emitted only on actual HUD state changes and only with ?qa_recovery; it
## gives browser automation a deterministic alternative to guessed key timing.
static func report_recovery_qa(hud) -> void:
	if not OS.has_feature("web"):
		return
	if not bool(JavaScriptBridge.eval("new URLSearchParams(location.search).has('qa_recovery')")):
		return
	var action: String = hud._state.recovery_action
	var guidance: String = hud._state.recovery_guidance
	print(
		(
			"Recovery QA: phase=%s action=%s guards=%d guidance=%s title=%s detail=%s state=%s"
			% [
				hud._state.play_phase,
				action if not action.is_empty() else "none",
				hud._state.recovery_guard_count,
				guidance if not guidance.is_empty() else "none",
				hud._state.recovery_title,
				hud._state.recovery_detail,
				hud._state.recovery_state,
			]
		)
	)


static func apply_context(hud) -> void:
	if not is_instance_valid(hud._defense_button):
		return
	var active: bool = (
		not hud._results_visible() and not hud._player_down and not hud.get_tree().paused
	)
	var exploring: bool = hud._state.play_phase == "explore"
	var preparing: bool = hud._state.play_phase == "preparing"
	var defending: bool = hud._state.play_phase == "defense"
	var recovery_available: bool = (
		not hud._state.recovery_action.is_empty() and (exploring or defending)
	)
	# A live Recovery encounter needs combat, not a generic START DEFENSE action.
	# Explicit Engage/Secure remains available when Main supplies one; the visible
	# objective detail carries the guard count because the tertiary state badge is
	# intentionally hidden on short landscape displays.
	var generic_defense_available: bool = (
		(exploring or preparing) and hud._state.recovery_guard_count == 0
	)
	hud._defense_button.visible = active and (generic_defense_available or recovery_available)
	if is_instance_valid(hud._armory_button):
		# The expanded WEAPON plate owns Armory on a short phone and whenever
		# one-weapon Explore has no SWAP to offer. Multiple owned weapons make
		# these distinct actions again; Defense retains the normal SWAP action.
		hud._armory_button.visible = active and exploring and not weapon_acts_as_armory(hud)
	hud._defense_button.disabled = preparing
	if recovery_available:
		var action_key := ""
		if hud._state.recovery_action == "engage":
			action_key = "hud.engage_guards" if hud._touch_mode else "hud.engage_guards_key"
		else:
			action_key = "hud.secure_cache" if hud._touch_mode else "hud.secure_cache_key"
		AegisText.apply(hud._defense_button, action_key)
	elif preparing:
		AegisText.apply(hud._defense_button, "hud.defense_in", [hud._state.preparation_seconds])
	else:
		(
			AegisText
			. apply(
				hud._defense_button,
				"hud.start_defense" if hud._touch_mode else "hud.start_defense_key",
			)
		)
	hud._wave_card.visible = not hud._results_visible() and hud._state.play_phase != "results"
	# The old three-line run panel competed with the horizon. Detailed score,
	# BP and shots remain available in pause and results.
	hud._run_card.visible = false
	hud._score_chip.visible = false
	hud._compact_card.visible = false
	if is_instance_valid(hud._pause_restart_button):
		if exploring:
			AegisText.apply(hud._pause_restart_button, "pause.reset")
		else:
			(
				AegisText
				. apply(
					hud._pause_restart_button,
					(
						"pause.finish_run"
						if hud._state.play_phase == "defense"
						else "pause.cancel_defense"
					),
				)
			)
	if is_instance_valid(hud._pause_stats_label) and exploring:
		AegisText.apply(hud._pause_stats_label, "hud.pause_safe")
	# The short status chip shares START's slot only after Defense begins.
	# Re-anchor when the encounter changes phase, not only on window resize.
	if is_instance_valid(hud._feedback_panel):
		hud._feedback_panel.layout_for(hud)


static func weapon_acts_as_armory(hud) -> bool:
	if hud._state.play_phase != "explore":
		return false
	# One owned weapon cannot be swapped: Main already routes that case to the
	# Armory. Make the same fact drive the caption, signal, and top-button
	# visibility so Explore never presents two identical Armory actions.
	return (hud._touch_mode and hud._narrow) or hud._state.available_weapons <= 1


static func refresh_weapon_action(hud) -> void:
	if not is_instance_valid(hud._weapon_button):
		return
	var compact_armory: bool = weapon_acts_as_armory(hud)
	var can_swap: bool = hud._state.available_weapons > 1 and not compact_armory
	hud._weapon_button.text = ""
	hud._weapon_button.icon = AegisTheme.hud_icon("hud-swap" if can_swap else "hud-weapon")
	hud._weapon_button.set_meta("aegis_state", "swap" if can_swap else "armory")
	if is_instance_valid(hud._weapon_caption):
		AegisText.apply(hud._weapon_caption, "hud.swap" if can_swap else "hud.armory_short")
	(
		AegisText
		. apply_tip(
			hud._weapon_button,
			"hud.swap_tip" if can_swap else "hud.armory_tip",
			[hud._state.weapon_display_name],
		)
	)


## An opt-in browser report of the rendered Control rectangles, never glyph
## bounding boxes or design constants. Only present with ?qa_touch.
##
## The report covers every control that can sit near a display edge, and it
## carries the resolved safe-area reserve, so an edge-margin regression can be
## checked from the browser log alone: `SAFE=` is what the OS (and the touch
## gesture reserve) took away, and each rect is what is left for the thumb.
static func finish_layout(hud) -> void:
	refresh_weapon_action(hud)
	if not OS.has_feature("web") or not hud._touch_mode:
		return
	if not bool(JavaScriptBridge.eval("new URLSearchParams(location.search).has('qa_touch')")):
		return
	var names := [
		"FIRE",
		"ADS",
		"EMP",
		"SWAP",
		"PAUSE",
		"AMMO",
		"WAVE",
		"HEALTH",
		"START",
		"ARMORY",
		"RUN",
	]
	var controls: Array[Control] = [
		hud._fire_button,
		hud._aim_button,
		hud._skill_button,
		hud._weapon_button,
		hud._pause_button,
		hud._touch_ammo_chip,
		hud._wave_card,
		hud._health_card,
		hud._defense_button,
		hud._armory_button,
		hud._run_card,
	]
	var rects := PackedStringArray()
	for index in range(controls.size()):
		var control: Control = controls[index]
		if not is_instance_valid(control) or not control.visible:
			continue
		var rect: Rect2 = control.get_global_rect()
		(
			rects
			. append(
				(
					"%s=%d,%d,%dx%d"
					% [
						names[index],
						roundi(rect.position.x * hud._stretch),
						roundi(rect.position.y * hud._stretch),
						roundi(rect.size.x * hud._stretch),
						roundi(rect.size.y * hud._stretch),
					]
				)
			)
		)
	# JOY is a drawn circle, not a Control: report the real touch pocket.
	var joy_radius: float = hud._joystick_radius * hud._stretch
	var joy_center: Vector2 = hud._joystick_center * hud._stretch
	(
		rects
		. append(
			(
				"JOY=%d,%d,%dx%d"
				% [
					roundi(joy_center.x - joy_radius),
					roundi(joy_center.y - joy_radius),
					roundi(joy_radius * 2.0),
					roundi(joy_radius * 2.0),
				]
			)
		)
	)
	print(
		(
			"Touch QA: viewport=%dx%d phase=%s SAFE=%d,%d,%d,%d %s"
			% [
				roundi(hud._physical_size.x),
				roundi(hud._physical_size.y),
				hud._state.play_phase,
				roundi(hud._safe_left * hud._stretch),
				roundi(hud._top_inset * hud._stretch),
				roundi(hud._safe_right * hud._stretch),
				roundi(hud._safe_bottom * hud._stretch),
				" ".join(rects),
			]
		)
	)


static func build_objective(hud) -> void:
	hud._wave_card = AegisPanel.new()
	hud._wave_card.name = "WaveCard"
	hud._wave_card.clip_contents = true
	hud._top_bar.add_child(hud._wave_card)

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	hud._wave_card.add_child(row)

	hud._wave_icon = TextureRect.new()
	hud._wave_icon.texture = AegisTheme.icon("target")
	hud._wave_icon.custom_minimum_size = Vector2(16.0, 16.0)
	hud._wave_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	hud._wave_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	hud._wave_icon.modulate = AegisTokens.INK_2
	row.add_child(hud._wave_icon)

	var text_col := VBoxContainer.new()
	text_col.add_theme_constant_override("separation", 0)
	text_col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(text_col)
	hud._wave_title_label = hud._label_key("hud.zone_title_fallback", "heading_s", AegisTokens.INK)
	text_col.add_child(hud._wave_title_label)
	hud._wave_enemy_label = hud._label_key(
		"hud.zone_subtitle_fallback", "label_s", AegisTokens.INK_2
	)
	text_col.add_child(hud._wave_enemy_label)
	hud._wave_chip_label = hud._label_key("hud.chip_explore", "label_s", AegisTokens.INK_2)
	hud._wave_chip_label.visible = false
	text_col.add_child(hud._wave_chip_label)

	hud._wave_state_label = hud._label_key("hud.no_hostiles", "label_s", AegisTokens.ACCENT)
	hud._wave_state_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	hud._wave_state_label.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(hud._wave_state_label)


static func build_start_action(hud) -> void:
	hud._defense_button = (
		hud
		. _text_button_key(
			"hud.start_defense_key",
			"DefenseStartButton",
			"tactical_start",
			"play",
			"hud.start_defense_tip",
		)
	)
	hud._defense_button.pressed.connect(hud._on_defense_pressed)


## Retain data nodes for results, accessibility preferences, and older smoke
## fixtures without painting run statistics over the exploration sightline.
static func build_legacy_score_widgets(hud) -> void:
	hud._score_chip = AegisPanel.new()
	hud._score_chip.name = "ScoreChip"
	hud._score_chip.show_brackets = false
	hud.add_child(hud._score_chip)
	hud._score_value_label = hud._label("", "mono_m", AegisTokens.INK)
	hud._score_value_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hud._score_value_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	hud._score_value_label.autowrap_mode = TextServer.AUTOWRAP_OFF
	hud._score_chip.add_child(hud._score_value_label)

	hud._compact_card = AegisPanel.new()
	hud._compact_card.name = "CompactDataCard"
	hud._compact_card.visible = false
	hud._compact_card.clip_contents = true
	hud.add_child(hud._compact_card)
	hud._compact_label = hud._label(
		hud._compact_wave_text + "\n" + hud._collapsed_run_text(), "mono_s", AegisTokens.INK_2
	)
	hud._compact_label.name = "CompactDataLabel"
	hud._compact_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	hud._compact_card.add_child(hud._compact_label)


static func build_run_data(hud) -> void:
	hud._run_card = AegisPanel.new()
	hud._run_card.name = "RunDataCard"
	hud._run_card.clip_contents = true
	hud.add_child(hud._run_card)

	var content := VBoxContainer.new()
	content.add_theme_constant_override("separation", 3)
	hud._run_card.add_child(content)
	content.add_child(hud._label_key("hud.run_data", "label_s", AegisTokens.INK_3))
	hud._status_label = hud._label(
		"Score: 0 · BP earned: 0\nKOs: 0 · Time: 00:00\nTarget 54 / 54 · Shots 0",
		"mono_s",
		AegisTokens.INK_2
	)
	hud._status_label.name = "StatusLabel"
	hud._status_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	content.add_child(hud._status_label)


static func build_help_panel(hud, help_text: String) -> void:
	hud._help_panel = AegisPanel.new()
	hud._help_panel.name = "ControlsHelpPanel"
	hud._help_panel.accent_side = "left"
	hud._help_panel.accent_color = Color(AegisTokens.INFO, 0.9)
	hud._help_panel.visible = false
	hud._help_remaining = 0.0
	hud._help_panel.clip_contents = true
	hud._help_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hud.add_child(hud._help_panel)
	hud._help_label = hud._label(help_text, "caption", AegisTokens.INK_2, 1.0, true)
	# All help variants supply explicit, width-checked line breaks. Autowrap in
	# a PanelContainer can compute an enormous minimum height while its hidden
	# label temporarily has zero width, making the optional plate cover FIRE.
	hud._help_label.autowrap_mode = TextServer.AUTOWRAP_OFF
	hud._help_label.clip_text = true
	hud._help_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	hud._help_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	hud._help_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hud._help_panel.add_child(hud._help_label)
