## Wires the persistent progression panel to the HUD without putting economy
## rules inside touch_controls.gd. Wallet/buy/equip decisions stay in Main.
class_name HudArmoryBridge
extends RefCounted


static func install_entry(hud) -> void:
	hud._armory_button = (
		hud
		. _text_button_key(
			"armory.chip",
			"ArmoryButton",
			"round",
			"",
			"armory.chip_tip",
		)
	)
	hud._armory_button.pressed.connect(_request_open.bind(hud))


static func install_panel(hud) -> void:
	hud._armory_panel = ArmoryUi.new()
	hud._armory_panel.name = "ArmoryPanel"
	hud.add_child(hud._armory_panel)
	hud._armory_panel.weapon_action_requested.connect(hud.armory_weapon_action_requested.emit)
	hud._armory_panel.weapon_upgrade_requested.connect(hud.armory_weapon_upgrade_requested.emit)
	hud._armory_panel.close_requested.connect(hud.armory_close_requested.emit)
	hud._armory_panel.home_requested.connect(hud._on_home_pressed)


static func refresh(
	hud, balance: int, best: int, unlocked: Dictionary, equipped: StringName, tiers: Dictionary = {}
) -> void:
	hud._state.wallet_bp = balance
	hud._state.available_weapons = unlocked.size()
	refresh_entry_label(hud)
	hud._armory_panel.refresh_profile(balance, best, unlocked, equipped, tiers)


static func refresh_entry_label(hud) -> void:
	if not is_instance_valid(hud._armory_button):
		return
	# The only armory action is the 186 px landscape plate, which fits the
	# balance; the Armory and Results panels still carry the full figure.
	AegisText.apply(hud._armory_button, "armory.chip_bp", [hud._state.wallet_bp])


static func show_panel(hud) -> void:
	hud._clear_touch_state()
	hud._armory_panel.show_home(true)
	hud._armory_panel.visible = true
	hud._overlays.push(hud._armory_panel, hud._close_armory_overlay)
	hud._pause_panel.visible = false
	hud._top_bar.visible = false
	hud._scrim.visible = true
	hud._armory_panel.focus_first()


static func hide_panel(hud) -> void:
	hud._overlays.remove(hud._armory_panel)
	hud._armory_panel.visible = false
	for button in hud._armory_panel.find_children("*", "Button", true, false):
		if button.has_focus():
			button.release_focus()


static func _request_open(hud) -> void:
	if hud._player_down or hud.get_tree().paused:
		return
	Sfx.play_ui(&"ui_click")
	hud.armory_requested.emit()
