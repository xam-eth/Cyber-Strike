## Short, non-interactive status chip below the sightline. The world and all
## buttons remain touchable; meaningful outcomes (EMP, wave award) are legible
## even when a one-frame VFX is missed on a slower browser renderer.
class_name HudCombatFeedbackUi
extends AegisPanel

var _message_label: Label
var _remaining: float = 0.0
var _message: String = ""
var _compact_explore: bool = false
var _compact_landscape: bool = false


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
	# Only the Explore portrait seam needs a compact two-line status. Keep
	# complete hit/reward messages in Defense, where the START lane is vacant.
	if _compact_explore and _message.contains("NO TARGETS"):
		_message_label.text = "NO\nTARGETS"
	elif _compact_explore and _message.contains("TARGET"):
		_message_label.text = "EMP\nHIT"
	elif _compact_landscape and _message.contains("NO TARGETS"):
		_message_label.text = "NO TARGETS"
	elif _compact_landscape and _message.begins_with("EMP PULSE · "):
		_message_label.text = _message.trim_prefix("EMP PULSE · ")
	elif _compact_landscape and _message.begins_with("TARGET DOWN · "):
		_message_label.text = "KO · " + _message.trim_prefix("TARGET DOWN · ")
	elif _compact_landscape and _message.contains(" CLEAR · "):
		_message_label.text = "CLEAR · " + _message.get_slice(" CLEAR · ", 1)
	else:
		_message_label.text = _message


func clear_message() -> void:
	_remaining = 0.0
	visible = false


## Top of the compact Explore status lane, in layout units: just below the
## magazine plate, the last real control on the left rail.
func _below_ammo_dock(hud) -> float:
	if not is_instance_valid(hud._touch_ammo_chip):
		return hud._top_inset + hud._to_layout(386.0)
	var ammo_bottom: float = hud._touch_ammo_chip.position.y + hud._touch_ammo_chip.size.y
	if ammo_bottom <= hud._top_inset:
		return hud._top_inset + hud._to_layout(386.0)
	return ammo_bottom + hud._to_layout(8.0)


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
	_compact_explore = hud._touch_mode and hud._portrait and hud._state.play_phase == "explore"
	_compact_landscape = hud._touch_mode and not hud._portrait and hud._narrow
	_refresh_message()
	var width: float = minf(hud._to_layout(272.0), hud.size.x - hud._to_layout(24.0))
	if hud._touch_mode:
		var left: float = hud._to_layout(12.0)
		var top: float = hud._top_inset + hud._to_layout(130.0)
		var height: float = hud._to_layout(40.0)
		if _compact_explore:
			# The larger EMP and SWAP plates close the old full-width toast
			# lane: centred in the gap between SWAP and EMP the panel still
			# clipped EMP on both phone widths. It now sits under the
			# weapon/magazine stack on the left rail, above the movement ring.
			# The panel is decorative, so a real touch target always wins.
			left = hud._to_layout(4.0) + hud._safe_left
			top = _below_ammo_dock(hud)
			width = hud._to_layout(84.0)
			height = hud._to_layout(44.0)
		elif not hud._portrait:
			# Lower centre clears the health rail, top-centre Pause and the
			# right-side action cluster. On a narrow landscape, avoid EMP too.
			width = hud._to_layout(140.0 if hud._narrow else 214.0)
			left = hud._to_layout(202.0) if hud._narrow else (hud.size.x - width) * 0.5
			top = hud.size.y - hud._to_layout(58.0)
			# A bar as wide as the old one reaches under EMP now that the
			# gesture reserve lifts EMP off the bottom edge on a 667x375
			# phone. Slide the lane left, then narrow it: the toast must never
			# sit on a control the player is trying to press.
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
