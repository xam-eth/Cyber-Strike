## Read-only weapon/magazine data next to the icon-only combat action.
## The data is not a touch target: swapping/opening Armory remains a separate
## generous button while the equipped weapon and ammo stay legible at a glance.
class_name AegisAmmoChip
extends AegisPanel

var weapon_label: Label
var tier_label: Label
var value_label: Label
var mag_bar: ProgressBar


func _ready() -> void:
	cut_top_left = 8.0
	cut_top_right = 0.0
	accent_side = "top"
	accent_color = AegisTokens.INFO
	accent_width = 2.0
	tactical_header = true
	super._ready()
	show_brackets = false
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_theme_stylebox_override(
		"panel",
		AegisTheme.panel_style(
			Color(AegisTokens.PANEL, AegisTokens.PANEL_ALPHA),
			AegisTokens.LINE_HI,
			1,
			AegisTokens.RADIUS,
			3.0
		)
	)
	var readout := VBoxContainer.new()
	readout.mouse_filter = Control.MOUSE_FILTER_IGNORE
	readout.add_theme_constant_override("separation", 1)
	add_child(readout)
	weapon_label = Label.new()
	weapon_label.name = "EquippedWeapon"
	weapon_label.text = "PULSE"
	weapon_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	weapon_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	weapon_label.set_meta("aegis_role", "label_s")
	weapon_label.set_meta("aegis_scale", 1.0)
	AegisTheme.style_label(weapon_label, "label_s", AegisTokens.INFO)
	var header := HBoxContainer.new()
	header.mouse_filter = Control.MOUSE_FILTER_IGNORE
	header.add_theme_constant_override("separation", 4)
	readout.add_child(header)
	weapon_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	weapon_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
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
	mag_bar.custom_minimum_size = Vector2(0.0, 3.0)
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
	if is_instance_valid(tier_label):
		tier_label.text = "T%d" % clampi(tier, 1, WeaponTier.tier_count())


func set_ammo(remaining: int, capacity: int, reloading: bool) -> void:
	if not is_instance_valid(value_label):
		return
	if reloading:
		AegisText.apply(value_label, "hud.reloading")
	else:
		value_label.text = "%d/%d" % [remaining, capacity]
	var low_ammo: bool = remaining > 0 and remaining <= maxi(capacity / 3, 1)
	var bar_col: Color = AegisTokens.INFO
	if reloading or low_ammo:
		bar_col = AegisTokens.ACCENT
	elif remaining <= 0:
		bar_col = AegisTokens.DANGER
	accent_color = bar_col
	if is_instance_valid(mag_bar):
		mag_bar.max_value = maxf(float(capacity), 1.0)
		mag_bar.value = 0.0 if reloading else float(clampi(remaining, 0, maxi(capacity, 1)))
		mag_bar.add_theme_stylebox_override("fill", AegisTheme.flat_style(bar_col))
	value_label.add_theme_color_override(
		"font_color",
		(
			AegisTokens.ACCENT
			if reloading
			else (AegisTokens.DANGER if remaining == 0 else AegisTokens.INK)
		)
	)
