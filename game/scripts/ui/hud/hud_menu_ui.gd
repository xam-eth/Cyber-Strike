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
	# A modal is the largest plate in the HUD, so it carries the deepest cut --
	# the same 22 px the menu cards use, which is what makes the overlay read as
	# part of the same machine as the screen behind it.
	hud._pause_panel.bezel = true
	hud._pause_panel.cut_top_left = AegisBezel.CUT_LG
	hud._pause_panel.cut_bottom_right = AegisBezel.CUT_LG
	# A modal is read, not seen through: at the soft fill the thumb stick and the
	# fire tile drew a faint ring and a faint corner across the card's actions.
	hud._pause_panel.surface_alpha = AegisTokens.PANEL_ALPHA
	hud._pause_panel.visible = false
	hud.add_child(hud._pause_panel)

	var content := VBoxContainer.new()
	content.add_theme_constant_override("separation", 12)
	hud._pause_panel.add_child(content)

	var eyebrow: Label = hud._label_key("pause.eyebrow", "label", AegisTokens.ACCENT)
	content.add_child(eyebrow)
	hud._pause_label = hud._label_key("pause.title", "display_l", AegisTokens.INK)
	content.add_child(hud._pause_label)
	hud._pause_stats_label = hud._label("", "mono_m", AegisTokens.INK_2)
	content.add_child(hud._pause_stats_label)

	var rule := ColorRect.new()
	rule.color = AegisTokens.LINE
	rule.custom_minimum_size = Vector2(0.0, 1.0)
	content.add_child(rule)

	hud._pause_resume_button = AegisButton.new()
	hud._pause_resume_button.name = "ResumeButton"
	AegisText.apply(hud._pause_resume_button, "pause.resume")
	hud._pause_resume_button.focus_mode = Control.FOCUS_ALL
	hud._pause_resume_button.mouse_filter = Control.MOUSE_FILTER_STOP
	hud._pause_resume_button.icon = AegisTheme.icon("play", true)
	hud._pause_resume_button.add_theme_constant_override("icon_max_width", 18)
	AegisTheme.set_button_variant(hud._pause_resume_button, "primary")
	hud._pause_resume_button.pressed.connect(hud._on_pause_pressed)
	content.add_child(hud._pause_resume_button)
	hud._touch_buttons.append(hud._pause_resume_button)

	# RESUME, then the run decision, then the pair of ways out. That is three
	# 52 px rows plus the header, which is what a 375 px-tall phone can hold; the
	# old four stacked plates overflowed it and the last action fell off the card.
	# The two exits share a row because they are the same rank: one goes back to
	# the field's settings, the other leaves the world entirely.
	hud._pause_restart_button = AegisButton.new()
	hud._pause_restart_button.name = "RestartButton"
	AegisText.apply(hud._pause_restart_button, "pause.restart")
	hud._pause_restart_button.focus_mode = Control.FOCUS_ALL
	hud._pause_restart_button.mouse_filter = Control.MOUSE_FILTER_STOP
	hud._pause_restart_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hud._pause_restart_button.icon = AegisTheme.icon("arrow-counter-clockwise")
	hud._pause_restart_button.add_theme_constant_override("icon_max_width", 18)
	AegisTheme.set_button_variant(hud._pause_restart_button, "round")
	hud._pause_restart_button.pressed.connect(hud._on_restart_pressed)
	content.add_child(hud._pause_restart_button)
	hud._touch_buttons.append(hud._pause_restart_button)

	var actions := HBoxContainer.new()
	actions.name = "PauseActions"
	actions.add_theme_constant_override("separation", 8)
	content.add_child(actions)

	hud._pause_settings_button = AegisButton.new()
	hud._pause_settings_button.name = "SettingsButton"
	AegisText.apply(hud._pause_settings_button, "pause.settings")
	hud._pause_settings_button.icon = AegisTheme.icon("gear-six")
	hud._pause_settings_button.focus_mode = Control.FOCUS_ALL
	hud._pause_settings_button.mouse_filter = Control.MOUSE_FILTER_STOP
	hud._pause_settings_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	AegisTheme.set_button_variant(hud._pause_settings_button, "ghost")
	hud._pause_settings_button.pressed.connect(hud._open_settings)
	actions.add_child(hud._pause_settings_button)
	hud._touch_buttons.append(hud._pause_settings_button)

	hud._pause_home_button = AegisButton.new()
	hud._pause_home_button.name = "PauseHomeButton"
	AegisText.apply(hud._pause_home_button, "pause.home")
	hud._pause_home_button.icon = AegisTheme.icon("house")
	hud._pause_home_button.add_theme_constant_override("icon_max_width", 18)
	hud._pause_home_button.focus_mode = Control.FOCUS_ALL
	hud._pause_home_button.mouse_filter = Control.MOUSE_FILTER_STOP
	hud._pause_home_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	AegisTheme.set_button_variant(hud._pause_home_button, "ghost")
	hud._pause_home_button.pressed.connect(hud._on_pause_home_pressed)
	actions.add_child(hud._pause_home_button)
	hud._touch_buttons.append(hud._pause_home_button)

	var hint: Label = hud._label_key("pause.hint", "label_s", AegisTokens.INK_3)
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	content.add_child(hint)


static func build_results(hud) -> void:
	hud._results_panel = AegisPanel.new()
	hud._results_panel.name = "ResultsPanel"
	hud._results_panel.interactive = true
	hud._results_panel.bezel = true
	hud._results_panel.cut_top_left = AegisBezel.CUT_LG
	hud._results_panel.cut_bottom_right = AegisBezel.CUT_LG
	hud._results_panel.visible = false
	hud.add_child(hud._results_panel)

	var content := VBoxContainer.new()
	content.add_theme_constant_override("separation", 12)
	hud._results_panel.add_child(content)

	hud._results_eyebrow = hud._label_key("results.eyebrow", "label", AegisTokens.ACCENT)
	content.add_child(hud._results_eyebrow)
	hud._results_title = hud._label_key("results.title", "display_xl", AegisTokens.INK)
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

	hud._results_reward_label = hud._label("", "mono_l", AegisTokens.ACCENT)
	hud._results_reward_label.set_meta("aegis_scale", 1.4)
	report.add_child(hud._results_reward_label)
	hud._results_goal_label = hud._label("", "label", AegisTokens.INK)
	hud._results_goal_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	report.add_child(hud._results_goal_label)
	hud._results_goal_progress_label = hud._label("", "mono_m", AegisTokens.INK_2)
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
	hud._results_hint_label = hud._label_key("results.hint", "caption", AegisTokens.INK_3)
	hud._results_hint_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	report.add_child(hud._results_hint_label)

	hud._results_retry_button = AegisButton.new()
	hud._results_retry_button.name = "ResultsRetryButton"
	AegisText.apply(hud._results_retry_button, "results.retry")
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
	AegisText.apply(hud._results_explore_button, "results.explore")
	hud._results_explore_button.focus_mode = Control.FOCUS_ALL
	hud._results_explore_button.mouse_filter = Control.MOUSE_FILTER_STOP
	hud._results_explore_button.icon = AegisTheme.icon("caret-right")
	AegisTheme.set_button_variant(hud._results_explore_button, "round")
	hud._results_explore_button.pressed.connect(hud._on_return_to_explore_pressed)
	content.add_child(hud._results_explore_button)
	hud._touch_buttons.append(hud._results_explore_button)

	# A run ends where the player came from: the results card is the one screen
	# that can name the dashboard without leaving the report behind.
	hud._results_home_button = AegisButton.new()
	hud._results_home_button.name = "ResultsHomeButton"
	AegisText.apply(hud._results_home_button, "results.home")
	hud._results_home_button.focus_mode = Control.FOCUS_ALL
	hud._results_home_button.mouse_filter = Control.MOUSE_FILTER_STOP
	hud._results_home_button.icon = AegisTheme.icon("house")
	hud._results_home_button.add_theme_constant_override("icon_max_width", 18)
	AegisTheme.set_button_variant(hud._results_home_button, "ghost")
	hud._results_home_button.pressed.connect(hud._on_home_pressed)
	content.add_child(hud._results_home_button)
	hud._touch_buttons.append(hud._results_home_button)

	hud._results_retry_button.focus_neighbor_bottom = hud._results_retry_button.get_path_to(
		hud._results_explore_button
	)
	hud._results_explore_button.focus_neighbor_top = hud._results_explore_button.get_path_to(
		hud._results_retry_button
	)
	hud._results_explore_button.focus_neighbor_bottom = hud._results_explore_button.get_path_to(
		hud._results_home_button
	)
	hud._results_home_button.focus_neighbor_top = hud._results_home_button.get_path_to(
		hud._results_explore_button
	)
	hud._results_home_button.focus_neighbor_bottom = hud._results_home_button.get_path_to(
		hud._results_retry_button
	)


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
	recovery_summary: String = "",
) -> void:
	var was_extracted: bool = hud._state.results_extracted
	AegisText.apply(hud._results_hint_label, "results.hint")
	if was_extracted and not was_defeated:
		AegisText.apply(hud._results_eyebrow, "results.extracted_eyebrow")
	else:
		AegisText.apply(
			hud._results_eyebrow,
			"results.eyebrow_ended" if was_defeated else "results.eyebrow_complete"
		)
	if was_extracted and wave_reached <= 0 and not was_defeated:
		AegisText.apply(hud._results_title, "results.extracted_title")
	else:
		(
			AegisText
			. apply(
				hud._results_title,
				"results.recover" if wave_reached <= 0 else "hud.wave",
				[] if wave_reached <= 0 else [wave_reached],
			)
		)
	(
		AegisText
		. apply(
			hud._results_retry_button,
			"results.retry_explore" if wave_reached <= 0 else "results.retry_defense",
		)
	)
	if wave_reached > 0 or (was_extracted and bp_earned > 0):
		AegisText.apply(hud._results_reward_label, "results.banked", [bp_earned])
	elif was_extracted and not was_defeated:
		AegisText.apply(hud._results_reward_label, "results.extracted_reward")
	else:
		AegisText.apply(hud._results_reward_label, "results.no_bp")
	hud._results_summary.set_meta("i18n_skip", true)
	hud._results_summary.text = (
		AegisText.t("results.summary_wave", [maxi(wave_reached, 0), survival_time])
		+ "\n"
		+ AegisText.t("results.summary_run", [eliminations, hud._format_number(run_score)])
		+ "\n"
		+ (
			AegisText
			. t(
				"results.summary_best",
				[hud._format_number(best_score), wallet_bp],
			)
		)
	)
	if not recovery_summary.is_empty():
		hud._results_summary.text += "\n" + recovery_summary

	var next_cost := 0
	var next_name := ""
	if not unlocked_ids.has("nova_launcher"):
		next_cost = int(ProgressionService.COSTS["nova_launcher"])
		next_name = AegisText.t("wpn.nova.name")
	elif not unlocked_ids.has("arc_shooter"):
		next_cost = int(ProgressionService.COSTS["arc_shooter"])
		next_name = AegisText.t("wpn.arc.name")
	if next_cost > 0:
		AegisText.apply(hud._results_goal_label, "results.next", [next_name])
		if wallet_bp >= next_cost:
			AegisText.apply(hud._results_goal_progress_label, "results.ready_unlock")
		else:
			(
				AegisText
				. apply(
					hud._results_goal_progress_label,
					"results.progress_to_go",
					[wallet_bp, next_cost, next_cost - wallet_bp],
				)
			)
		hud._results_goal_bar.max_value = next_cost
		hud._results_goal_bar.value = mini(wallet_bp, next_cost)
	else:
		AegisText.apply(hud._results_goal_label, "results.arsenal_complete")
		AegisText.apply(hud._results_goal_progress_label, "results.all_ready")
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
	# Shown when asked for, including on a narrow phone: the plate fades after
	# HELP_FADE_SECONDS and the first input retires it, so it is a hint rather
	# than an overlay that stays over the play area.
	hud._help_panel.visible = true


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
	recovery_summary: String = "",
) -> void:
	if not is_instance_valid(hud._results_panel):
		return
	hud._state.results_mode = "results"
	hud._results_home_button.visible = true
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
		recovery_summary,
	)
	hud._results_panel.visible = true
	# The report is a layer like any other: ESC on it RETRYs (the path the pause
	# card takes after a defeat), and it traps focus while it is up.
	hud._overlays.push(hud._results_panel, hud._on_pause_pressed)
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
		hud._upgrade_entry_button,
		hud._upgrade_status_card,
		hud._upgrade_panel,
		hud._confirm_dialog,
		hud._fire_button,
		hud._weapon_button,
		hud._skill_button,
		hud._aim_button,
		hud._pause_button,
		hud._sound_button,
		hud._compact_card,
		hud._score_chip,
		hud._run_card,
		hud._skill_ring,
		hud._touch_ammo_chip,
	]:
		if is_instance_valid(control):
			control.visible = false
	if is_instance_valid(hud._pause_panel):
		hud._pause_panel.visible = false
	hud._aiming = false
	hud.queue_redraw()
	hud.call_deferred("_report_results_qa")


## The primary secure opens a choice inside the existing Results surface. No
## banking happens until Extract; Continue keeps the current field and run.
static func show_extraction_choice(
	hud,
	wallet_bp: int,
	arc_unlocked: bool,
	completed_runs: int = 0,
	optional_secured: bool = false,
) -> void:
	hud._state.results_extracted = false
	var unlocked: Dictionary = {"arc_shooter": true} if arc_unlocked else {}
	show_results(hud, 0, "00:00", 0, 0, 0, wallet_bp, 0, unlocked, false)
	hud._state.results_mode = "extraction"
	AegisText.apply(hud._results_eyebrow, "recovery.complete_eyebrow")
	AegisText.apply(hud._results_title, "recovery.complete_title")
	AegisText.apply(hud._results_reward_label, "recovery.primary_reward")
	var summary_lines := PackedStringArray([AegisText.t("recovery.choice_summary")])
	var cur_tier := HeroTier.owned_tier(completed_runs)
	var next_tier := HeroTier.owned_tier(completed_runs + 1)
	if next_tier > cur_tier:
		(
			summary_lines
			. append(
				(
					AegisText
					. t(
						"recovery.choice_tier_unlock",
						[
							next_tier,
							roundi(HeroTier.vitals(next_tier)),
							roundi(HeroTier.reduction(next_tier)),
						],
					)
				)
			)
		)
	else:
		(
			summary_lines
			. append(
				(
					AegisText
					. t(
						"recovery.choice_tier_progress",
						[completed_runs + 1, cur_tier, roundi(HeroTier.vitals(cur_tier))],
					)
				)
			)
		)
	if optional_secured:
		summary_lines.append(AegisText.t("results.recovery_bp", [80]))
	hud._results_summary.set_meta("i18n_skip", true)
	hud._results_summary.text = "\n".join(summary_lines)
	AegisText.apply(hud._results_hint_label, "recovery.choice_hint")
	AegisText.apply(hud._results_retry_button, "recovery.extract")
	AegisText.apply(hud._results_explore_button, "recovery.continue_endless")
	hud._results_home_button.visible = false
	if arc_unlocked:
		AegisText.apply(hud._results_goal_label, "recovery.arc_owned")
		AegisText.apply(hud._results_goal_progress_label, "recovery.arc_ready")
	else:
		AegisText.apply(hud._results_goal_label, "recovery.arc_blueprint")
		(
			AegisText
			. apply(
				hud._results_goal_progress_label,
				"recovery.armory_cost",
				[ProgressionService.COSTS["arc_shooter"]],
			)
		)
	hud._results_goal_bar.max_value = ProgressionService.COSTS["arc_shooter"]
	hud._results_goal_bar.value = mini(wallet_bp, int(hud._results_goal_bar.max_value))
	hud.call_deferred("_report_results_qa")


static func report_results_qa(hud) -> void:
	if not OS.has_feature("web") or not results_visible(hud):
		return
	if not bool(JavaScriptBridge.eval("new URLSearchParams(location.search).has('qa_recovery')")):
		return
	var physical := Vector2(hud.get_window().size)
	var stretch := UiLayout.compute_stretch(hud, physical)
	var btn_center := func(btn: Control) -> String:
		if not is_instance_valid(btn) or not btn.visible:
			return "none"
		var rect := btn.get_global_rect()
		var center := (rect.position + rect.size * 0.5) * stretch
		return "%.1f,%.1f" % [center.x, center.y]
	print(
		(
			"Recovery Results QA: mode=%s primary=%s secondary=%s home=%s reward=%s"
			% [
				hud._state.results_mode,
				btn_center.call(hud._results_retry_button),
				btn_center.call(hud._results_explore_button),
				btn_center.call(hud._results_home_button),
				hud._results_reward_label.text,
			]
		)
	)


static func hide_results(hud) -> void:
	if not is_instance_valid(hud._results_panel):
		return
	hud._state.results_mode = "results"
	hud._results_home_button.visible = true
	hud._overlays.remove(hud._results_panel)
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
## control hint, the help plate, which buttons are dead, and whether the
## pause card gets the focus. Keeping all of it in one function is the point —
## a half-applied pause is worse than none — but the function belongs with the
## panels it drives, not on the facade.


## The pause card's status line: a sentence about state, so it is rebuilt by the
## code that owns that state rather than by the language walk.
static func apply_pause_stats(hud) -> void:
	if not is_instance_valid(hud._pause_stats_label):
		return
	if hud._state.play_phase == "explore":
		AegisText.apply(hud._pause_stats_label, "hud.pause_safe")
	else:
		(
			AegisText
			. apply(
				hud._pause_stats_label,
				"hud.score_time",
				[hud._format_number(hud._state.score), hud._state.run_time],
			)
		)


static func apply_paused(hud, paused: bool) -> void:
	if paused:
		hud._clear_touch_state()
	else:
		# Resuming ends every overlay, not just the pause card: a layer left in
		# the stack would keep its focus trap switched on over live play.
		hud._overlays.clear()
	if not paused and is_instance_valid(hud._settings_menu):
		hud._settings_menu.visible = false
		if is_instance_valid(hud._hud_editor):
			hud._hud_editor.close()
		hud._top_bar.visible = true
	if not paused:
		if is_instance_valid(hud._upgrade_panel):
			hud._upgrade_panel.visible = false
		if is_instance_valid(hud._confirm_dialog):
			hud._confirm_dialog.visible = false
	if is_instance_valid(hud._pause_button):
		hud._pause_button.icon = AegisTheme.icon("play" if paused else "pause", true)
		hud._pause_button.text = ""
		hud._pause_button.set_meta("aegis_state", "resume" if paused else "pause")
		AegisText.apply_tip(hud._pause_button, "hud.resume_tip" if paused else "hud.pause_tip")
		hud._pause_button.disabled = false
	if is_instance_valid(hud._pause_panel):
		hud._pause_panel.visible = paused and not hud._player_down
		if hud._pause_panel.visible:
			# The card owns the screen while it is up: focus is trapped inside
			# it, and ESC on it brings the run back.
			hud._overlays.push(hud._pause_panel, hud._on_pause_pressed)
		if hud._pause_panel.visible and is_instance_valid(hud._pause_resume_button):
			hud._pause_resume_button.grab_focus()
		elif is_instance_valid(hud._pause_resume_button) and hud._pause_resume_button.has_focus():
			hud._pause_resume_button.release_focus()
	apply_pause_stats(hud)
	if is_instance_valid(hud._scrim):
		hud._scrim.visible = (paused or hud._player_down) and not hud._results_visible()
	if is_instance_valid(hud._help_panel):
		hud._help_panel.visible = (
			not paused and hud._help_remaining > 0.0 and not hud._results_visible()
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
	hud._overlays.push(hud._settings_menu, hud._settings_menu.close)
	hud._settings_menu.open()
	print("HUD: settings opened")


static func close_settings(hud) -> void:
	if not hud.get_tree().paused:
		return
	hud._overlays.remove(hud._settings_menu)
	hud._pause_panel.visible = true
	hud._top_bar.visible = true
	hud._pause_resume_button.grab_focus()
	print("HUD: settings closed")
