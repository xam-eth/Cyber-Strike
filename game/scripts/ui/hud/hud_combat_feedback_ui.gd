## Short, non-interactive status chip below the sightline. The world and all
## buttons remain touchable; meaningful outcomes (EMP, wave award) are legible
## even when a one-frame VFX is missed on a slower browser renderer.
class_name HudCombatFeedbackUi
extends AegisPanel

var _message_label: Label
var _remaining: float = 0.0
var _message: String = ""


func _ready() -> void:
	cut_top_left = 10.0
	cut_bottom_right = 10.0
	accent_color = AegisTokens.INFO
	accent_side = "left"
	accent_width = 3.0
	tactical_header = true
	super._ready()
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_message_label = Label.new()
	_message_label.name = "CombatMessage"
	_message_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_message_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_message_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_message_label.set_meta("aegis_role", "title")
	_message_label.set_meta("aegis_scale", 1.0)
	AegisTheme.style_label(_message_label, "title", AegisTokens.INK)
	# The lane is a strip, not a card: the message wraps inside it instead of
	# widening the panel over the thumb keys it must never cover.
	_message_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_message_label.max_lines_visible = 2
	_message_label.clip_text = true
	_message_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_message_label.size_flags_vertical = Control.SIZE_EXPAND_FILL
	add_child(_message_label)
	visible = false


func _process(delta: float) -> void:
	if _remaining > 0.0:
		_remaining = maxf(_remaining - delta, 0.0)
		if _remaining <= 0.0:
			visible = false


func show_message(text: String) -> void:
	if text.is_empty():
		return
	_message = text
	_refresh_message()
	_remaining = 1.9
	visible = true
	notification(Container.NOTIFICATION_SORT_CHILDREN)
	queue_redraw()


func _refresh_message() -> void:
	# One line: the lane under the sightline is wide enough for the whole
	# message, and a shortened one told the player less than the panel could.
	_message_label.text = _message


func clear_message() -> void:
	_remaining = 0.0
	visible = false


func layout_for(hud) -> void:
	add_theme_stylebox_override(
		"panel",
		AegisTheme.panel_style(
			Color(AegisTokens.PANEL, 0.94 * hud._hud_opacity),
			AegisTokens.INFO,
			1,
			AegisTokens.RADIUS,
			hud._to_layout(8.0)
		)
	)
	# One lane: the strip between the movement pocket and the EMP plate, lifted
	# clear of the gesture reserve. Both edges come from the controls that own
	# them, so the strip cannot drift onto a finger target when the layout
	# changes.
	var inset: float = hud._to_layout(10.0)
	var left: float = hud._joystick_center.x + hud._joystick_radius + inset
	var right: float = hud.size.x - inset
	if is_instance_valid(hud._skill_button):
		right = minf(right, hud._skill_button.position.x - inset)
	var height: float = hud._to_layout(48.0)
	var top: float = hud.size.y - hud._safe_bottom - hud._to_layout(10.0) - height
	var lane_w: float = maxf(right - left, hud._to_layout(96.0))
	var max_w: float = hud._to_layout(420.0)
	var width: float = minf(lane_w, maxf(max_w, hud._to_layout(96.0)))
	var x: float = left + maxf((lane_w - width) * 0.5, 0.0)
	UiLayout.place(hud, self, 0.0, 0.0, 0.0, 0.0, Rect2(x, top, width, height))
	if visible:
		notification(Container.NOTIFICATION_SORT_CHILDREN)
