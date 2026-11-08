## Read-only weapon/magazine data next to the icon-only combat action.
## Upgraded with segmented plasma magazine telemetry and live Overcharge status
## while keeping swapping/Armory on its dedicated combat button.
class_name AegisAmmoChip
extends AegisPanel

var weapon_label: Label
var tier_label: Label
var value_label: Label
var mag_bar: ProgressBar
var _overcharge_seconds: float = 0.0
var _remaining: int = 24
var _capacity: int = 24
var _reloading: bool = false
var _tier: int = 1
var _compact_row: bool = false


func _ready() -> void:
	cut_top_left = 10.0
	cut_top_right = 0.0
	cut_bottom_right = 6.0
	accent_side = "top"
	accent_color = AegisTokens.INFO
	accent_width = 2.5
	tactical_header = true
	super._ready()
	show_brackets = true
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_theme_stylebox_override(
		"panel",
		AegisTheme.panel_style(
			Color(AegisTokens.VOID, 0.84), AegisTokens.LINE_HI, 1, AegisTokens.RADIUS, 4.0
		)
	)
	var readout := VBoxContainer.new()
	readout.mouse_filter = Control.MOUSE_FILTER_IGNORE
	readout.add_theme_constant_override("separation", 1)
	add_child(readout)
	weapon_label = Label.new()
	weapon_label.name = "EquippedWeapon"
	weapon_label.text = "PULSE"
	weapon_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	weapon_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	weapon_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	weapon_label.set_meta("aegis_role", "label_s")
	weapon_label.set_meta("aegis_scale", 1.0)
	AegisTheme.style_label(weapon_label, "label_s", AegisTokens.INFO)
	var header := HBoxContainer.new()
	header.mouse_filter = Control.MOUSE_FILTER_IGNORE
	header.add_theme_constant_override("separation", 4)
	readout.add_child(header)
	header.add_child(weapon_label)
	tier_label = Label.new()
	tier_label.name = "WeaponTier"
	tier_label.text = "T1"
	tier_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	tier_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	tier_label.set_meta("aegis_role", "mono_s")
	tier_label.set_meta("aegis_scale", 1.0)
	AegisTheme.style_label(tier_label, "mono_s", AegisTokens.ACCENT)
	header.add_child(tier_label)
	value_label = Label.new()
	value_label.name = "AmmoValue"
	value_label.text = "24/24"
	value_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	value_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	value_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	value_label.set_meta("aegis_role", "mono_s")
	value_label.set_meta("aegis_scale", 1.0)
	AegisTheme.style_label(value_label, "mono_s", AegisTokens.INK)
	readout.add_child(value_label)
	mag_bar = ProgressBar.new()
	mag_bar.name = "MagazineBar"
	mag_bar.show_percentage = false
	mag_bar.min_value = 0.0
	mag_bar.max_value = 24.0
	mag_bar.value = 24.0
	mag_bar.custom_minimum_size = Vector2(0.0, 4.0)
	mag_bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	mag_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	mag_bar.add_theme_stylebox_override(
		"background", AegisTheme.flat_style(Color(AegisTokens.PANEL_3, 0.95))
	)
	mag_bar.add_theme_stylebox_override("fill", AegisTheme.flat_style(AegisTokens.INFO))
	readout.add_child(mag_bar)


func set_weapon(short_name: String) -> void:
	if is_instance_valid(weapon_label):
		weapon_label.text = short_name


func set_tier(tier: int) -> void:
	_tier = clampi(tier, 1, WeaponTier.tier_count())
	_refresh_tier_text()


## One-line mode for screens too short for the full readout: the tier badge
## carries the ammo count too and the value/bar rows step aside. The chip is a
## PanelContainer, so hiding rows is what actually shrinks its minimum height.
func set_compact_row(enabled: bool) -> void:
	_compact_row = enabled
	if is_instance_valid(value_label):
		value_label.visible = not enabled
	if is_instance_valid(mag_bar):
		mag_bar.visible = not enabled
	_refresh_tier_text()
	queue_redraw()


func _refresh_tier_text() -> void:
	if not is_instance_valid(tier_label):
		return
	var badge := ("⚡T%d" if _overcharge_seconds > 0.0 else "T%d") % _tier
	if _compact_row:
		var count_text: String = (
			AegisText.t("hud.reloading") if _reloading else "%d/%d" % [_remaining, _capacity]
		)
		tier_label.text = "%s · %s" % [badge, count_text]
	else:
		tier_label.text = badge


func set_overcharge(seconds: float) -> void:
	_overcharge_seconds = maxf(seconds, 0.0)
	if is_instance_valid(tier_label):
		tier_label.add_theme_color_override(
			"font_color",
			Color(0.76, 0.48, 1.0) if _overcharge_seconds > 0.0 else AegisTokens.ACCENT
		)
	_refresh_tier_text()
	_refresh_bar_style()


func set_ammo(remaining: int, capacity: int, reloading: bool) -> void:
	if not is_instance_valid(value_label):
		return
	_remaining = remaining
	_capacity = maxi(capacity, 1)
	_reloading = reloading
	if reloading:
		AegisText.apply(value_label, "hud.reloading")
	else:
		value_label.text = "%d/%d" % [remaining, capacity]
	_refresh_tier_text()
	_refresh_bar_style()


func _refresh_bar_style() -> void:
	var low_ammo: bool = _remaining > 0 and _remaining <= maxi(_capacity / 3, 1)
	var bar_col: Color = Color(0.74, 0.46, 1.0) if _overcharge_seconds > 0.0 else AegisTokens.INFO
	if _reloading or low_ammo:
		bar_col = AegisTokens.ACCENT
	elif _remaining <= 0:
		bar_col = AegisTokens.DANGER
	accent_color = bar_col
	if is_instance_valid(mag_bar):
		mag_bar.max_value = maxf(float(_capacity), 1.0)
		mag_bar.value = 0.0 if _reloading else float(clampi(_remaining, 0, _capacity))
		mag_bar.add_theme_stylebox_override("fill", AegisTheme.flat_style(bar_col))
	if is_instance_valid(value_label):
		value_label.add_theme_color_override(
			"font_color",
			(
				AegisTokens.ACCENT
				if _reloading
				else (AegisTokens.DANGER if _remaining == 0 else AegisTokens.INK)
			)
		)
	queue_redraw()
