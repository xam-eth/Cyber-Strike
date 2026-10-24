## Construction and behaviour of the modal pause, results, settings and help
## cards. The TouchControls facade owns their signals and run state; this helper
## creates the nodes and drives their visibility, which is what kept ~150 lines
## of panel bookkeeping inside the facade (docs/ARCHITECTURE.md, phase 1).
class_name HudMenuUi
extends RefCounted


static func build_pause(hud) -> void:
	hud._pause_panel = AegisPanel.new()
	hud._pause_panel.name = "PausePanel"
	hud._pause_panel.interactive = true
	hud._pause_panel.visible = false
	hud.add_child(hud._pause_panel)

	var content := VBoxContainer.new()
	content.add_theme_constant_override("separation", 12)
	hud._pause_panel.add_child(content)

	hud._pause_swipe_handle = ColorRect.new()
	hud._pause_swipe_handle.name = "PauseSwipeHandle"
	hud._pause_swipe_handle.color = AegisTokens.LINE_HI
	hud._pause_swipe_handle.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hud._pause_swipe_handle.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	content.add_child(hud._pause_swipe_handle)

	var eyebrow: Label = hud._label("RUN SUSPENDED", "label", AegisTokens.ACCENT)
	content.add_child(eyebrow)
	hud._pause_label = hud._label("PAUSED", "display_l", AegisTokens.INK)
	content.add_child(hud._pause_label)
	hud._pause_stats_label = hud._label("SCORE 0  ·  00:00", "mono_m", AegisTokens.INK_2)
	content.add_child(hud._pause_stats_label)

	var rule := ColorRect.new()
	rule.color = AegisTokens.LINE
	rule.custom_minimum_size = Vector2(0.0, 1.0)
	content.add_child(rule)

	hud._pause_resume_button = AegisButton.new()
	hud._pause_resume_button.name = "ResumeButton"
	hud._pause_resume_button.text = "RESUME"
	hud._pause_resume_button.focus_mode = Control.FOCUS_ALL
	hud._pause_resume_button.mouse_filter = Control.MOUSE_FILTER_STOP
	hud._pause_resume_button.icon = AegisTheme.icon("play", true)
	hud._pause_resume_button.add_theme_constant_override("icon_max_width", 18)
	AegisTheme.set_button_variant(hud._pause_resume_button, "primary")
	hud._pause_resume_button.pressed.connect(hud._on_pause_pressed)
	content.add_child(hud._pause_resume_button)
	hud._touch_buttons.append(hud._pause_resume_button)

	hud._pause_restart_button = AegisButton.new()
	hud._pause_restart_button.name = "RestartButton"
	hud._pause_restart_button.text = "RESTART RUN"
	hud._pause_restart_button.focus_mode = Control.FOCUS_ALL
	hud._pause_restart_button.mouse_filter = Control.MOUSE_FILTER_STOP
	hud._pause_restart_button.icon = AegisTheme.icon("arrow-counter-clockwise")
	hud._pause_restart_button.add_theme_constant_override("icon_max_width", 18)
	AegisTheme.set_button_variant(hud._pause_restart_button, "round")
	hud._pause_restart_button.pressed.connect(hud._on_restart_pressed)
	content.add_child(hud._pause_restart_button)
	hud._touch_buttons.append(hud._pause_restart_button)

	hud._pause_settings_button = AegisButton.new()
	hud._pause_settings_button.name = "SettingsButton"
	hud._pause_settings_button.text = "SETTINGS"
	hud._pause_settings_button.icon = AegisTheme.icon("gear-six")
	hud._pause_settings_button.focus_mode = Control.FOCUS_ALL
	AegisTheme.set_button_variant(hud._pause_settings_button, "ghost")
	hud._pause_settings_button.pressed.connect(hud._open_settings)
	content.add_child(hud._pause_settings_button)
	hud._touch_buttons.append(hud._pause_settings_button)

	var hint: Label = hud._label("SETTINGS → CONTROLS · ESC RESUME", "label_s", AegisTokens.INK_3)
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	content.add_child(hint)


static func build_results(hud) -> void:
	hud._results_panel = AegisPanel.new()
	hud._results_panel.name = "ResultsPanel"
	hud._results_panel.interactive = true
	hud._results_panel.visible = false
	hud.add_child(hud._results_panel)

	var content := VBoxContainer.new()
	content.add_theme_constant_override("separation", 12)
	hud._results_panel.add_child(content)

	hud._results_eyebrow = hud._label("RUN COMPLETE", "label", AegisTokens.ACCENT)
	content.add_child(hud._results_eyebrow)
	hud._results_title = hud._label("RUN RESULTS", "display_xl", AegisTokens.INK)
	content.add_child(hud._results_title)

	var rule := ColorRect.new()
	rule.color = AegisTokens.LINE
	rule.custom_minimum_size = Vector2(0.0, 1.0)
	content.add_child(rule)

	# The report scrolls on short landscape viewports; the two run decisions
	# remain pinned and reachable. Portrait has room to display all of it.
	var report_scroll := ScrollContainer.new()
	report_scroll.name = "RunReportScroll"
	report_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	report_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	report_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	content.add_child(report_scroll)
	var report := VBoxContainer.new()
	report.add_theme_constant_override("separation", 12)
	report.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	report_scroll.add_child(report)

	hud._results_reward_label = hud._label("+0 BP BANKED", "mono_l", AegisTokens.ACCENT)
	hud._results_reward_label.set_meta("aegis_scale", 1.4)
	report.add_child(hud._results_reward_label)
	hud._results_goal_label = hud._label("NEXT LOADOUT · NOVA LAUNCHER", "label", AegisTokens.INK)
	hud._results_goal_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	report.add_child(hud._results_goal_label)
	hud._results_goal_progress_label = hud._label("0 / 120 BP", "mono_m", AegisTokens.INK_2)
	report.add_child(hud._results_goal_progress_label)
	hud._results_goal_bar = ProgressBar.new()
	hud._results_goal_bar.name = "NextUnlockProgress"
	hud._results_goal_bar.show_percentage = false
	hud._results_goal_bar.min_value = 0
	hud._results_goal_bar.max_value = 120
	hud._results_goal_bar.add_theme_stylebox_override(
		"background", AegisTheme.flat_style(AegisTokens.LINE)
	)
	hud._results_goal_bar.add_theme_stylebox_override(
		"fill", AegisTheme.flat_style(AegisTokens.ACCENT)
	)
	report.add_child(hud._results_goal_bar)
	var goal_rule := ColorRect.new()
	goal_rule.color = AegisTokens.LINE_HI
	goal_rule.custom_minimum_size = Vector2(0.0, 1.0)
	report.add_child(goal_rule)
	hud._results_summary = hud._label("", "mono_m", AegisTokens.INK_2)
	hud._results_summary.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	report.add_child(hud._results_summary)
	var hint: Label = hud._label(
		"10 BP PER KO · 100 BP PER CLEARED WAVE", "caption", AegisTokens.INK_3
	)
	hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	report.add_child(hint)

	hud._results_retry_button = AegisButton.new()
	hud._results_retry_button.name = "ResultsRetryButton"
	hud._results_retry_button.text = "RETRY"
	hud._results_retry_button.focus_mode = Control.FOCUS_ALL
	hud._results_retry_button.mouse_filter = Control.MOUSE_FILTER_STOP
	hud._results_retry_button.icon = AegisTheme.icon("arrow-counter-clockwise")
	hud._results_retry_button.add_theme_constant_override("icon_max_width", 18)
	AegisTheme.set_button_variant(hud._results_retry_button, "primary")
	hud._results_retry_button.pressed.connect(hud._on_results_retry_pressed)
	content.add_child(hud._results_retry_button)
	hud._touch_buttons.append(hud._results_retry_button)

	hud._results_explore_button = AegisButton.new()
	hud._results_explore_button.name = "ResultsExploreButton"
	hud._results_explore_button.text = "RETURN TO EXPLORE"
	hud._results_explore_button.focus_mode = Control.FOCUS_ALL
	hud._results_explore_button.mouse_filter = Control.MOUSE_FILTER_STOP
	hud._results_explore_button.icon = AegisTheme.icon("caret-right")
	AegisTheme.set_button_variant(hud._results_explore_button, "round")
	hud._results_explore_button.pressed.connect(hud._on_return_to_explore_pressed)
	content.add_child(hud._results_explore_button)
	hud._touch_buttons.append(hud._results_explore_button)


## Results makes the objective -> earned reward -> next loadout relationship
## visible. Purchases still live exclusively in ProgressionService/Main.
static func update_results(
	hud,
	wave_reached: int,
	survival_time: String,
	eliminations: int,
	run_score: int,
	bp_earned: int,
	wallet_bp: int,
	best_score: int,
	unlocked_ids: Dictionary,
	was_defeated: bool,
) -> void:
	hud._results_eyebrow.text = "RUN ENDED" if was_defeated else "RUN COMPLETE"
	hud._results_title.text = "RECOVER" if wave_reached <= 0 else "WAVE %02d" % wave_reached
	hud._results_retry_button.text = "RETRY EXPLORE" if wave_reached <= 0 else "RETRY DEFENSE"
	hud._results_reward_label.text = (
		"NO BP · NO RUN STARTED" if wave_reached <= 0 else "+%d BP BANKED" % bp_earned
	)
	hud._results_summary.text = (
		"WAVE %02d  ·  SURVIVED %s\n" % [maxi(wave_reached, 0), survival_time]
		+ "ELIMINATIONS %d  ·  SCORE %s\n" % [eliminations, hud._format_number(run_score)]
		+ "BEST SCORE %s  ·  WALLET %d BP" % [hud._format_number(best_score), wallet_bp]
	)

	var next_cost := 0
	var next_name := ""
	if not unlocked_ids.has("nova_launcher"):
		next_cost = int(ProgressionService.COSTS["nova_launcher"])
		next_name = "NOVA LAUNCHER"
	elif not unlocked_ids.has("arc_shooter"):
		next_cost = int(ProgressionService.COSTS["arc_shooter"])
		next_name = "ARC SHOOTER"
	if next_cost > 0:
		hud._results_goal_label.text = "NEXT LOADOUT · " + next_name
		hud._results_goal_progress_label.text = (
			"READY TO UNLOCK · OPEN ARMORY IN EXPLORE"
			if wallet_bp >= next_cost
			else "%d / %d BP  ·  %d TO GO" % [wallet_bp, next_cost, next_cost - wallet_bp]
		)
		hud._results_goal_bar.max_value = next_cost
		hud._results_goal_bar.value = mini(wallet_bp, next_cost)
	else:
		hud._results_goal_label.text = "ARSENAL COMPLETE"
		hud._results_goal_progress_label.text = "ALL LOADOUTS READY · EQUIP IN ARMORY"
		hud._results_goal_bar.max_value = 1
		hud._results_goal_bar.value = 1


# --------------------------------------------------------------------------- #
# Behaviour
# --------------------------------------------------------------------------- #


## The control hint is noise once the player has started playing; the first
## shot or the first joystick drag retires it early.
static func hide_help(hud) -> void:
	if is_instance_valid(hud._help_panel):
		hud._help_panel.visible = false
	hud._help_remaining = 0.0


## Bring the control hint back (called on retry and when the run starts). The
## countdown itself belongs to the facade, which ticks it every frame.
static func show_help(hud) -> void:
	if not is_instance_valid(hud._help_panel):
		return
	hud._help_panel.modulate.a = 1.0
	hud._help_panel.visible = not (hud._touch_mode and hud._narrow and not hud._portrait)


static func results_visible(hud) -> bool:
	return is_instance_valid(hud._results_panel) and hud._results_panel.visible


## Results takes the screen: every play control is hidden so the player cannot
## fire into a dead run, and the retry button takes focus so Enter restarts it.
static func show_results(
	hud,
	wave_reached: int,
	survival_time: String,
	eliminations: int,
	run_score: int,
	bp_earned: int,
	wallet_bp: int,
	best_score: int,
	unlocked_ids: Dictionary,
	was_defeated: bool,
) -> void:
	if not is_instance_valid(hud._results_panel):
		return
	hud._clear_touch_state()
	update_results(
		hud,
		wave_reached,
		survival_time,
		eliminations,
		run_score,
		bp_earned,
		wallet_bp,
		best_score,
		unlocked_ids,
		was_defeated,
	)
	hud._results_panel.visible = true
	if is_instance_valid(hud._feedback_panel):
		hud._feedback_panel.clear_message()
	hud._results_retry_button.grab_focus()
	if is_instance_valid(hud._scrim):
		hud._scrim.visible = true
	hud._top_bar.visible = false
	hud._help_label.visible = false
	if is_instance_valid(hud._help_panel):
		hud._help_panel.visible = false
	for control in [
		hud._defense_button,
		hud._armory_button,
		hud._fire_button,
		hud._weapon_button,
		hud._skill_button,
		hud._aim_button,
		hud._pause_button,
		hud._sound_button,
		hud._compact_card,
		hud._score_chip,
		hud._run_card,
		hud._desktop_hint,
		hud._desktop_weapon_card,
		hud._emp_chip,
		hud._ads_chip,
		hud._skill_ring,
		hud._touch_ammo_chip,
	]:
		if is_instance_valid(control):
			control.visible = false
	if is_instance_valid(hud._pause_panel):
		hud._pause_panel.visible = false
	hud._aiming = false
	hud.queue_redraw()


static func hide_results(hud) -> void:
	if not is_instance_valid(hud._results_panel):
		return
	hud._results_panel.visible = false
	if hud._results_retry_button.has_focus():
		hud._results_retry_button.release_focus()
	if hud._results_explore_button.has_focus():
		hud._results_explore_button.release_focus()
	if is_instance_valid(hud._scrim):
		hud._scrim.visible = hud.get_tree().paused
	hud._top_bar.visible = true
	hud._help_label.visible = true
	hud._apply_input_mode()
	hud._layout_controls()
	hud._refresh_skill_button()


## Pause is a whole-screen state, not one panel: it decides the scrim, the
## control hint, the desktop legend, which buttons are dead, and whether the
## pause card gets the focus. Keeping all of it in one function is the point —
## a half-applied pause is worse than none — but the function belongs with the
## panels it drives, not on the facade.


static func apply_paused(hud, paused: bool) -> void:
	if paused:
		hud._clear_touch_state()
	elif is_instance_valid(hud._settings_menu):
		hud._settings_menu.visible = false
		if is_instance_valid(hud._hud_editor):
			hud._hud_editor.close()
		hud._top_bar.visible = true
	if is_instance_valid(hud._pause_button):
		hud._pause_button.icon = AegisTheme.icon("play" if paused else "pause", true)
		hud._pause_button.text = ""
		hud._pause_button.set_meta("aegis_state", "resume" if paused else "pause")
		hud._pause_button.tooltip_text = "Resume (Esc)" if paused else "Pause (Esc)"
		hud._pause_button.disabled = false
	if is_instance_valid(hud._pause_panel):
		hud._pause_panel.visible = paused and not hud._player_down
		if hud._pause_panel.visible and is_instance_valid(hud._pause_resume_button):
			hud._pause_resume_button.grab_focus()
		elif is_instance_valid(hud._pause_resume_button) and hud._pause_resume_button.has_focus():
			hud._pause_resume_button.release_focus()
	if is_instance_valid(hud._pause_stats_label):
		hud._pause_stats_label.text = (
			"SAFE ZONE · NO WAVES UNTIL YOU START"
			if hud._state.play_phase == "explore"
			else "SCORE %s  ·  %s" % [hud._format_number(hud._state.score), hud._state.run_time]
		)
	if is_instance_valid(hud._scrim):
		hud._scrim.visible = (paused or hud._player_down) and not hud._results_visible()
	if is_instance_valid(hud._help_panel):
		hud._help_panel.visible = (
			not paused and hud._help_remaining > 0.0 and not hud._results_visible()
		)
	if is_instance_valid(hud._desktop_hint):
		hud._desktop_hint.visible = (
			not paused and not hud._touch_mode and not hud._results_visible()
		)
	if is_instance_valid(hud._fire_button):
		hud._fire_button.disabled = paused or hud._player_down
	if is_instance_valid(hud._weapon_button):
		hud._weapon_button.disabled = paused or hud._player_down
	if is_instance_valid(hud._aim_button):
		hud._aim_button.disabled = paused or hud._player_down
	if paused and hud._aiming:
		hud._on_aim_up()
	hud._refresh_skill_button()
	hud._apply_context_visibility()


## Both settings transitions only exist while the game is paused: outside a
## pause the pause card is not the thing on screen, so there is nothing to
## give the screen back to.
static func open_settings(hud) -> void:
	if not hud.get_tree().paused:
		return
	hud._pause_panel.visible = false
	hud._top_bar.visible = false
	hud._settings_menu.open()
	print("HUD: settings opened")


static func close_settings(hud) -> void:
	if not hud.get_tree().paused:
		return
	hud._pause_panel.visible = true
	hud._top_bar.visible = true
	hud._pause_resume_button.grab_focus()
	print("HUD: settings closed")
