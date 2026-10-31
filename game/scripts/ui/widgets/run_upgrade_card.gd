class_name RunUpgradeCard
extends AegisButton

## One reusable, whole-card touch target. The resource supplies identity/effect;
## the service remains the selection authority. Child labels ignore pointers so
## keyboard, mouse, and touch all activate the same Button.pressed path.
signal chosen(upgrade_id: StringName)

var _definition: RunUpgradeDefinition
var _name_label: Label
var _effect_label: Label
var _compatibility_label: Label
var _scope_label: Label
var _state_label: Label
var _selected: bool = false


func _ready() -> void:
	text = ""
	focus_mode = Control.FOCUS_ALL
	mouse_filter = Control.MOUSE_FILTER_STOP
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	size_flags_vertical = Control.SIZE_EXPAND_FILL
	cut = 12.0
	AegisTheme.set_button_variant(self, "card")

	var column := VBoxContainer.new()
	column.name = "Content"
	column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.add_theme_constant_override("separation", 6)
	add_child(column)

	_name_label = _label("heading_s", AegisTokens.INK)
	_name_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	column.add_child(_name_label)
	_effect_label = _label("title", AegisTokens.ACCENT)
	_effect_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	column.add_child(_effect_label)
	_compatibility_label = _label("label_s", AegisTokens.INFO)
	_compatibility_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	column.add_child(_compatibility_label)
	_scope_label = _label("label_s", AegisTokens.INK_2)
	column.add_child(_scope_label)
	_state_label = _label("label", AegisTokens.ACCENT)
	_state_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	column.add_child(_state_label)
	pressed.connect(_on_pressed)


func configure(definition: RunUpgradeDefinition, weapon_id: StringName) -> void:
	_definition = definition
	_selected = false
	edge_active = false
	if definition == null:
		disabled = true
		return
	name = "%sUpgradeCard" % String(definition.upgrade_id).to_pascal_case()
	set_meta("upgrade_id", String(definition.upgrade_id))
	disabled = not definition.supports_weapon(weapon_id)
	AegisText.apply(_name_label, definition.display_name_key)
	AegisText.apply(_effect_label, definition.effect_key)
	AegisText.apply(_compatibility_label, "upgrade.compatibility")
	AegisText.apply(_scope_label, "upgrade.scope")
	AegisText.apply(_state_label, "upgrade.unavailable" if disabled else "upgrade.select")
	tooltip_text = (
		"%s · %s · %s"
		% [
			definition.display_name(),
			definition.effect_description(),
			AegisText.t("upgrade.scope"),
		]
	)


func set_selected(value: bool) -> void:
	_selected = value
	edge_active = value
	if is_instance_valid(_state_label):
		AegisText.apply(_state_label, "upgrade.selected" if value else "upgrade.select")
	queue_redraw()


func is_selected() -> bool:
	return _selected


func refresh_language() -> void:
	if _definition != null:
		var weapon_compatible := not disabled
		configure(_definition, &"pulse_rifle")
		disabled = not weapon_compatible


func _on_pressed() -> void:
	if _definition == null or disabled:
		return
	set_selected(true)
	chosen.emit(_definition.upgrade_id)


func _label(role: String, color: Color) -> Label:
	var label := Label.new()
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.set_meta("aegis_role", role)
	label.set_meta("aegis_scale", 1.0)
	AegisTheme.style_label(label, role, color)
	return label
