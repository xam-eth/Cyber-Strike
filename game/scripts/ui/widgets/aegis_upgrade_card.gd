## Reusable Temporary Run Upgrade choice card (`CHOOSE -> EVOLVE`).
##
## Uses cyan / violet tactical framing (`AegisTokens.INFO` / `ABILITY`) so a
## player can tell at a glance that this card modifies the CURRENT RUN ONLY,
## never permanent Armory or Operative progression.
class_name AegisUpgradeCard
extends AegisButton

var upgrade_id: StringName = &""
var choice_index: int = 0

var _category_badge: AegisTierBadge
var _stack_label: Label
var _title_label: Label
var _desc_label: Label
var _scope_label: Label
var _box: VBoxContainer


func _init() -> void:
	clip_contents = true
	focus_mode = Control.FOCUS_ALL
	mouse_filter = Control.MOUSE_FILTER_STOP
	text = ""
	AegisTheme.set_button_variant(self, "card")
	_build_contents()


func _build_contents() -> void:
	var pad := MarginContainer.new()
	pad.set_anchors_preset(Control.PRESET_FULL_RECT)
	pad.mouse_filter = Control.MOUSE_FILTER_IGNORE
	pad.add_theme_constant_override("margin_left", 10)
	pad.add_theme_constant_override("margin_right", 10)
	pad.add_theme_constant_override("margin_top", 8)
	pad.add_theme_constant_override("margin_bottom", 8)
	add_child(pad)

	_box = VBoxContainer.new()
	_box.add_theme_constant_override("separation", 4)
	_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	pad.add_child(_box)

	var top := HBoxContainer.new()
	top.add_theme_constant_override("separation", 6)
	top.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_box.add_child(top)

	_category_badge = AegisTierBadge.new("MOD", "info")
	top.add_child(_category_badge)

	_stack_label = _make_line("", "label_s", AegisTokens.ACCENT, false)
	_stack_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_stack_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(_stack_label)

	_title_label = _make_line("", "title", AegisTokens.INK, false)
	_box.add_child(_title_label)

	_desc_label = _make_line("", "caption", AegisTokens.INK_2, true)
	_desc_label.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_box.add_child(_desc_label)

	_scope_label = _make_line("", "label_s", AegisTokens.INFO, false)
	_box.add_child(_scope_label)


func bind_upgrade(definition: RunUpgradeDefinition, current_stacks: int, slot_index: int) -> void:
	choice_index = slot_index
	if definition == null:
		upgrade_id = &""
		disabled = true
		visible = false
		return
	visible = true
	disabled = false
	upgrade_id = definition.upgrade_id
	var tone := _tone_for_category(definition.category)
	_category_badge.set_badge(definition.display_category(), tone)
	_stack_label.text = "[%d]  L%d -> L%d" % [slot_index + 1, current_stacks, current_stacks + 1]
	_title_label.text = definition.display_title()
	_desc_label.text = definition.display_summary()
	_scope_label.text = AegisText.t("hud.upg_scope_run")
	tooltip_text = "%s — %s" % [definition.display_title(), definition.display_summary()]


func apply_layout_scale(hud_to_layout: Callable) -> void:
	var pad_control := get_child(0) as MarginContainer
	if pad_control != null:
		var mx := maxi(roundi(float(hud_to_layout.call(10.0))), 6)
		var my := maxi(roundi(float(hud_to_layout.call(8.0))), 5)
		pad_control.add_theme_constant_override("margin_left", mx)
		pad_control.add_theme_constant_override("margin_right", mx)
		pad_control.add_theme_constant_override("margin_top", my)
		pad_control.add_theme_constant_override("margin_bottom", my)
	if _box != null:
		_box.add_theme_constant_override(
			"separation", maxi(roundi(float(hud_to_layout.call(4.0))), 2)
		)


static func _tone_for_category(cat: StringName) -> String:
	match cat:
		RunUpgradeDefinition.CATEGORY_TACTICAL:
			return "ability"
		RunUpgradeDefinition.CATEGORY_SURVIVAL:
			return "ok"
		RunUpgradeDefinition.CATEGORY_MOBILITY:
			return "accent"
		_:
			return "info"


static func _make_line(text_val: String, role: String, color: Color, wrap: bool) -> Label:
	var label := Label.new()
	label.text = text_val
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.set_meta("aegis_role", role)
	label.set_meta("aegis_scale", 1.0)
	if wrap:
		label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		label.max_lines_visible = 3
	else:
		label.autowrap_mode = TextServer.AUTOWRAP_OFF
		label.max_lines_visible = 1
	label.clip_text = true
	label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	AegisTheme.style_label(label, role, color)
	return label
