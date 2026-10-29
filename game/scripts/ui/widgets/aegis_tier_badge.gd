## Reusable sci-fi tier, scope, or mode badge (`T1..T5`, `THIS RUN`, `PERMANENT`).
##
## Non-interactive (`MOUSE_FILTER_IGNORE`) so embedding inside cards or rows
## never intercepts touch/mouse presses on the parent button.
class_name AegisTierBadge
extends PanelContainer

var _label: Label
var _tone: String = "accent"


func _init(initial_text: String = "", initial_tone: String = "accent") -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	clip_contents = true
	_tone = initial_tone
	_label = Label.new()
	_label.name = "BadgeLabel"
	_label.text = initial_text
	_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_label.autowrap_mode = TextServer.AUTOWRAP_OFF
	_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_label.set_meta("aegis_role", "label_s")
	_label.set_meta("aegis_scale", 1.0)
	add_child(_label)
	apply_tone(initial_tone)


func set_badge(text: String, tone: String = "") -> void:
	_label.text = text
	if not tone.is_empty():
		apply_tone(tone)


func apply_tone(tone: String) -> void:
	_tone = tone
	var fg := _tone_color(tone)
	var bg := Color(fg.r * 0.16, fg.g * 0.16, fg.b * 0.18, 0.92)
	var style := AegisTheme.panel_style(bg, Color(fg, 0.85), 1, 2, 6.0)
	style.content_margin_top = 2.0
	style.content_margin_bottom = 2.0
	add_theme_stylebox_override("panel", style)
	AegisTheme.style_label(_label, "label_s", fg)


static func _tone_color(tone: String) -> Color:
	match tone:
		"info":
			return AegisTokens.INFO
		"ok":
			return AegisTokens.OK
		"danger":
			return AegisTokens.DANGER
		"ability":
			return AegisTokens.ABILITY
		"neutral":
			return AegisTokens.INK_2
		_:
			return AegisTokens.ACCENT
