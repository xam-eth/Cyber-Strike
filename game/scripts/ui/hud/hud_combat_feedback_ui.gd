## Short, non-interactive status chip below the sightline. The world and all
## buttons remain touchable; meaningful outcomes (EMP, wave award) are legible
## even when a one-frame VFX is missed on a slower browser renderer.
class_name HudCombatFeedbackUi
extends AegisPanel

var _message_label: Label
var _remaining: float = 0.0
var _message: String = ""


func _ready() -> void:
	accent_color = AegisTokens.INFO
	accent_side = "left"
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
	# One lane: the gap between the movement pocket and the right-thumb cluster.
	_refresh_message()
	var width: float = minf(hud._to_layout(272.0), hud.size.x - hud._to_layout(24.0))
	if hud._touch_mode:
		var left: float = hud._to_layout(12.0)
		var top: float = hud._top_inset + hud._to_layout(130.0)
		var height: float = hud._to_layout(40.0)
		# Lower centre clears the health rail, top-centre Pause, the movement
		# pocket on the left and the action cluster on the right. On a narrow
		# phone the lane is narrower and starts further in.
		width = hud._to_layout(140.0 if hud._narrow else 214.0)
		left = hud._to_layout(202.0) if hud._narrow else (hud.size.x - width) * 0.5
		top = hud.size.y - hud._to_layout(58.0)
		# A bar as wide as the old one reaches under EMP now that the gesture
		# reserve lifts EMP off the bottom edge on a 667x375 phone. Slide the
		# lane left, then narrow it: the toast must never sit on a control the
		# player is trying to press.
		var emp_limit: float = hud._skill_button.position.x - hud._to_layout(10.0)
		if is_instance_valid(hud._skill_button) and left + width > emp_limit:
			left = maxf(hud._to_layout(202.0), emp_limit - width)
			if left + width > emp_limit:
				width = maxf(hud._to_layout(96.0), emp_limit - left)
		UiLayout.place(hud, self, 0.0, 0.0, 0.0, 0.0, Rect2(left, top, width, height))
	else:
		UiLayout.place(
			hud,
			self,
			0.5,
			0.5,
			0.5,
			0.5,
			Rect2(-width * 0.5, hud._to_layout(64.0), width, hud._to_layout(40.0))
		)
