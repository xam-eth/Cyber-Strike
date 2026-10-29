## Reusable data-bound stat / resource / objective chip (`CAPTION` + `VALUE`).
##
## Built on `AegisPanel` so menus, HUD briefings, and results screens share one
## consistent card primitive without duplicating label hierarchies.
class_name AegisStatChip
extends AegisPanel

var caption_label: Label
var value_label: Label
var detail_label: Label


func _ready() -> void:
	interactive = false
	clip_contents = true
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	if accent_side.is_empty():
		accent_side = "left"
	super._ready()
	if caption_label != null:
		return

	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 2)
	column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(column)

	caption_label = _make_label("", "label_s", AegisTokens.INK_3)
	column.add_child(caption_label)

	value_label = _make_label("", "mono_m", AegisTokens.INK)
	column.add_child(value_label)

	detail_label = _make_label("", "caption", AegisTokens.INK_2)
	detail_label.visible = false
	column.add_child(detail_label)


func set_stat(
	caption: String, value: String, detail: String = "", tone: Color = AegisTokens.INK
) -> void:
	if caption_label != null:
		caption_label.text = caption
	if value_label != null:
		value_label.text = value
		value_label.add_theme_color_override("font_color", tone)
	if detail_label != null:
		detail_label.text = detail
		detail_label.visible = not detail.is_empty()


static func _make_label(text: String, role: String, color: Color) -> Label:
	var label := Label.new()
	label.text = text
	label.autowrap_mode = TextServer.AUTOWRAP_OFF
	label.clip_text = true
	label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.set_meta("aegis_role", role)
	label.set_meta("aegis_scale", 1.0)
	AegisTheme.style_label(label, role, color)
	return label
