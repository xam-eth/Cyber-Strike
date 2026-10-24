## Read-only weapon/magazine data next to the icon-only combat action.
## The data is not a touch target: swapping/opening Armory remains a separate
## generous button while the equipped weapon and ammo stay legible at a glance.
class_name AegisAmmoChip
extends AegisPanel

var weapon_label: Label
var value_label: Label


func _ready() -> void:
	super._ready()
	show_brackets = false
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_theme_stylebox_override(
		"panel",
		AegisTheme.panel_style(
			Color(AegisTokens.PANEL, AegisTokens.PANEL_ALPHA),
			AegisTokens.LINE,
			1,
			AegisTokens.RADIUS,
			2.0
		)
	)
	var readout := VBoxContainer.new()
	readout.mouse_filter = Control.MOUSE_FILTER_IGNORE
	readout.add_theme_constant_override("separation", 0)
	add_child(readout)
	weapon_label = Label.new()
	weapon_label.name = "EquippedWeapon"
	weapon_label.text = "PULSE"
	weapon_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	weapon_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	weapon_label.set_meta("aegis_role", "label_s")
	weapon_label.set_meta("aegis_scale", 1.0)
	AegisTheme.style_label(weapon_label, "label_s", AegisTokens.INFO)
	readout.add_child(weapon_label)
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


func set_weapon(short_name: String) -> void:
	if is_instance_valid(weapon_label):
		weapon_label.text = short_name


func set_ammo(remaining: int, capacity: int, reloading: bool) -> void:
	if not is_instance_valid(value_label):
		return
	value_label.text = "RELOAD" if reloading else "%d/%d" % [remaining, capacity]
	value_label.add_theme_color_override(
		"font_color",
		(
			AegisTokens.ACCENT
			if reloading
			else (AegisTokens.DANGER if remaining == 0 else AegisTokens.INK)
		)
	)
