## Wires the persistent progression panel to the HUD without putting economy
## rules inside touch_controls.gd. Wallet/buy/equip decisions stay in Main.
class_name HudArmoryBridge
extends RefCounted


static func install_entry(hud) -> void:
	hud._armory_button = (
		hud
		. _text_button(
			"ARMORY · 0 BP",
			"ArmoryButton",
			"round",
			"",
			"Open Armory: unlock and equip weapons with Battle Points",
		)
	)
	hud._armory_button.pressed.connect(_request_open.bind(hud))


static func install_panel(hud) -> void:
	hud._armory_panel = ArmoryUi.new()
	hud._armory_panel.name = "ArmoryPanel"
	hud.add_child(hud._armory_panel)
	hud._armory_panel.weapon_action_requested.connect(hud.armory_weapon_action_requested.emit)
	hud._armory_panel.close_requested.connect(hud.armory_close_requested.emit)


static func refresh(
	hud, balance: int, best: int, unlocked: Dictionary, equipped: StringName
) -> void:
	hud._state.wallet_bp = balance
	hud._state.available_weapons = unlocked.size()
	refresh_entry_label(hud)
	hud._armory_panel.refresh_profile(balance, best, unlocked, equipped)


static func refresh_entry_label(hud) -> void:
	if not is_instance_valid(hud._armory_button):
		return
	# Currency lives in the Armory/Results; repeating it on the 106–148 px
	# portrait action clips the text and hides more of the world than it helps.
	hud._armory_button.text = (
		"ARMORY" if hud._touch_mode and hud._portrait else "ARMORY · %d BP" % hud._state.wallet_bp
	)


static func show_panel(hud) -> void:
	hud._clear_touch_state()
	hud._armory_panel.visible = true
	hud._pause_panel.visible = false
	hud._top_bar.visible = false
	hud._scrim.visible = true
	hud._armory_panel.focus_first()


static func hide_panel(hud) -> void:
	hud._armory_panel.visible = false
	for button in hud._armory_panel.find_children("*", "Button", true, false):
		if button.has_focus():
			button.release_focus()


static func _request_open(hud) -> void:
	if hud._player_down or hud.get_tree().paused:
		return
	Sfx.play_ui(&"ui_click")
	hud.armory_requested.emit()
