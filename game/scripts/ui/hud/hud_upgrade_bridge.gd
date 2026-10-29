## Connects run-scoped Tactical Upgrades (`RunUpgradeManager`) and high-stakes
## leave confirmation (`AegisConfirmDialog`) to `TouchControls` without bloating
## the HUD facade.
class_name HudUpgradeBridge
extends RefCounted


static func install_top_widgets(hud) -> void:
	hud._upgrade_status_card = AegisPanel.new()
	hud._upgrade_status_card.name = "UpgradeStatusCard"
	hud._upgrade_status_card.accent_side = "left"
	hud._upgrade_status_card.accent_color = AegisTokens.INFO
	hud._upgrade_status_card.clip_contents = true
	hud._upgrade_status_card.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hud._upgrade_status_card.visible = false
	hud._top_bar.add_child(hud._upgrade_status_card)

	var content := VBoxContainer.new()
	content.add_theme_constant_override("separation", 4)
	content.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hud._upgrade_status_card.add_child(content)

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 6)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	content.add_child(row)

	var heading: Label = hud._label_key("hud.upg_chip_title", "label_s", AegisTokens.INFO)
	row.add_child(heading)

	hud._upgrade_status_value = hud._label("0 / 2", "mono_s", AegisTokens.INK)
	hud._upgrade_status_value.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	hud._upgrade_status_value.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hud._upgrade_status_value.clip_text = true
	hud._upgrade_status_value.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	row.add_child(hud._upgrade_status_value)

	hud._upgrade_charge_bar = SegmentedBar.new()
	hud._upgrade_charge_bar.name = "UpgradeChargeBar"
	hud._upgrade_charge_bar.min_value = 0.0
	hud._upgrade_charge_bar.max_value = 2.0
	hud._upgrade_charge_bar.value = 0.0
	hud._upgrade_charge_bar.segments = 2
	hud._upgrade_charge_bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hud._upgrade_charge_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hud._upgrade_charge_bar.add_theme_stylebox_override(
		"background", AegisTheme.flat_style(AegisTokens.PANEL_3)
	)
	hud._upgrade_charge_bar.add_theme_stylebox_override(
		"fill", AegisTheme.flat_style(AegisTokens.INFO)
	)
	content.add_child(hud._upgrade_charge_bar)

	hud._upgrade_entry_button = (
		hud
		. _text_button_key(
			"hud.upg_ready_key",
			"UpgradeReadyButton",
			"primary",
			"lightning",
			"hud.upg_ready_tip",
		)
	)
	hud._upgrade_entry_button.visible = false
	hud._upgrade_entry_button.pressed.connect(_request_open.bind(hud))


static func install_overlays(hud) -> void:
	hud._upgrade_panel = HudRunUpgradeUi.new()
	hud._upgrade_panel.name = "RunUpgradePanel"
	hud.add_child(hud._upgrade_panel)
	hud._upgrade_panel.choice_selected.connect(hud.upgrade_choice_requested.emit)
	hud._upgrade_panel.close_requested.connect(hud.upgrade_close_requested.emit)

	hud._confirm_dialog = AegisConfirmDialog.new()
	hud._confirm_dialog.name = "ConfirmLeaveDialog"
	hud.add_child(hud._confirm_dialog)
	hud._confirm_dialog.cancelled.connect(hide_leave_confirm.bind(hud))
	hud._confirm_dialog.alternate_requested.connect(_bank_and_finish.bind(hud))
	hud._confirm_dialog.confirmed.connect(_confirm_leave.bind(hud))


static func refresh(hud, manager: RunUpgradeManager) -> void:
	if manager == null:
		return
	var pending := manager.has_pending_choice()
	var charge := manager.current_charge()
	var needed := maxi(manager.charge_required(), 1)
	var tags := manager.active_tags_summary()
	var maxed := manager.is_maxed()

	hud._state.upgrade_pending = pending
	hud._state.upgrade_active_tags = tags
	hud._state.upgrade_charge = charge
	hud._state.upgrade_required = needed
	hud._state.upgrade_maxed = maxed

	if is_instance_valid(hud._upgrade_charge_bar):
		hud._upgrade_charge_bar.max_value = float(1 if maxed else needed)
		hud._upgrade_charge_bar.segments = clampi(1 if maxed else needed, 1, 6)
		hud._upgrade_charge_bar.value = float(1 if maxed else charge)
	if is_instance_valid(hud._upgrade_status_value):
		if maxed and not tags.is_empty():
			hud._upgrade_status_value.text = tags
		elif not tags.is_empty():
			hud._upgrade_status_value.text = "%s %d/%d" % [tags, charge, needed]
		else:
			hud._upgrade_status_value.text = "%d/%d KO" % [charge, needed]
	update_visibility(hud)


static func update_visibility(hud) -> void:
	var gameplay_live: bool = (
		not hud._results_visible() and not hud.get_tree().paused and not hud._player_down
	)
	var show_ready: bool = gameplay_live and hud._state.upgrade_pending
	var has_activity: bool = (
		hud._state.play_phase == "defense"
		or hud._state.upgrade_charge > 0
		or not hud._state.upgrade_active_tags.is_empty()
		or hud._state.recovery_guard_count > 0
	)
	if is_instance_valid(hud._upgrade_entry_button):
		hud._upgrade_entry_button.visible = show_ready
	if is_instance_valid(hud._upgrade_status_card):
		hud._upgrade_status_card.visible = gameplay_live and not show_ready and has_activity


static func show_panel(
	hud, choices: Array[RunUpgradeDefinition], manager: RunUpgradeManager
) -> void:
	if not is_instance_valid(hud._upgrade_panel) or choices.is_empty():
		return
	hud._clear_touch_state()
	hud._upgrade_panel.present_choices(choices, manager)
	hud._overlays.push(hud._upgrade_panel, hud._close_upgrade_overlay)
	if is_instance_valid(hud._pause_panel):
		hud._pause_panel.visible = false
	hud._top_bar.visible = false
	if is_instance_valid(hud._scrim):
		hud._scrim.visible = true
	update_visibility(hud)


static func hide_panel(hud) -> void:
	if not is_instance_valid(hud._upgrade_panel):
		return
	hud._overlays.remove(hud._upgrade_panel)
	hud._upgrade_panel.visible = false
	for button in hud._upgrade_panel.find_children("*", "Button", true, false):
		if button.has_focus():
			button.release_focus()
	hud._top_bar.visible = not hud._results_visible()
	update_visibility(hud)


static func show_leave_confirm(hud) -> void:
	if not is_instance_valid(hud._confirm_dialog):
		hud._on_home_pressed()
		return
	var alt := AegisText.t("pause.confirm_bank") if hud._state.play_phase == "defense" else ""
	hud._pause_panel.visible = false
	(
		hud
		. _confirm_dialog
		. present_dialog(
			AegisText.t("pause.confirm_eyebrow"),
			AegisText.t("pause.confirm_title"),
			AegisText.t("pause.confirm_body", [hud._state.bp]),
			AegisText.t("pause.confirm_stay"),
			AegisText.t("pause.confirm_leave"),
			alt,
		)
	)
	hud._overlays.push(hud._confirm_dialog, hide_leave_confirm.bind(hud))


static func hide_leave_confirm(hud) -> void:
	if not is_instance_valid(hud._confirm_dialog) or not hud._confirm_dialog.visible:
		return
	hud._overlays.remove(hud._confirm_dialog)
	hud._confirm_dialog.visible = false
	if hud.get_tree().paused and is_instance_valid(hud._pause_panel):
		hud._pause_panel.visible = true
		if is_instance_valid(hud._pause_resume_button):
			hud._pause_resume_button.grab_focus()


static func _bank_and_finish(hud) -> void:
	hide_leave_confirm(hud)
	Sfx.play_ui(&"ui_click")
	hud.finish_run_requested.emit()


static func _confirm_leave(hud) -> void:
	hide_leave_confirm(hud)
	hud._on_home_pressed()


static func _request_open(hud) -> void:
	if hud._player_down or hud.get_tree().paused:
		return
	Sfx.play_ui(&"ui_click")
	hud.upgrade_open_requested.emit()
