## Owns the transient touch state: which finger is the movement stick, which
## one is the look drag, which buttons are held down.
##
## The HUD facade (touch_controls.gd) owns the widgets, the run state and the
## meaning of every button. This module owns only the four things a touch has
## that a mouse click does not: an identity, a start point, a drag path and a
## release. It turns those into three intents — move, look, fire — and calls
## back into the HUD for anything that needs to know what a button *is*.
##
## Keeping the finger bookkeeping out of the facade matters because it is the
## part that leaks: a blur, a pause or an app switch can skip the release, and
## a stranded finger id leaves the player walking into a wall with no thumb on
## the glass. One owner for that state means one place to clear it.
class_name HudTouchInput
extends RefCounted

signal movement_changed(value: Vector2)
signal look_delta(value: Vector2)
signal fire_changed(pressed: bool)

## The HUD this module dispatches for. Assigned by the owner in _ready().
var hud: TouchControls

var move_touch_id: int = -1
var look_touch_id: int = -1
var fire_touch_id: int = -1
## touch id -> Button, for buttons that are held rather than tapped (AIM).
var pressed_buttons: Dictionary = {}
var move_origin: Vector2 = Vector2.ZERO
var move_position: Vector2 = Vector2.ZERO
## Debug breadcrumb for the smoke test: what the last touch resolved to.
var last_touch_debug: String = ""


func begin(touch_id: int, position: Vector2) -> void:
	var touched_button := find_button(position)
	last_touch_debug = (
		"id=%d pos=%s hit=%s"
		% [touch_id, position, touched_button.name if is_instance_valid(touched_button) else "none"]
	)
	if is_instance_valid(touched_button):
		hud.get_viewport().set_input_as_handled()
		if (
			touched_button == hud._fire_button
			and not touched_button.disabled
			and not hud._player_down
			and not hud.get_tree().paused
			and fire_touch_id == -1
		):
			fire_touch_id = touch_id
			# Synthetic touches skip Godot Button GUI. Forward both edges so
			# the glyph rim and actual shot agree with native button_down/up.
			touched_button.emit_signal("button_down")
		else:
			pressed_buttons[touch_id] = touched_button
			if not touched_button.disabled:
				# Godot buttons only fire `pressed` on release, so a hold button
				# (AIM) also needs its press forwarded here.
				touched_button.emit_signal("button_down")
		return
	if (
		hud._player_down
		or hud.get_tree().paused
		or hud._is_over_hud(position)
		or (is_instance_valid(hud._scrim) and hud._scrim.visible)
	):
		return
	if position.y < hud.size.y * 0.2:
		return
	var split := hud.size.x * (0.53 if hud._left_handed else 0.47)
	var move_zone := position.x > split if hud._left_handed else position.x < split
	var look_zone := position.x < split if hud._left_handed else position.x >= split
	if move_zone and move_touch_id == -1:
		# Movement is a fixed thumb zone, not any tap on the left half. Offset
		# starts at the painted ring; touching its edge gives immediate motion.
		if position.distance_to(hud._joystick_center) > hud._joystick_radius + hud._to_layout(20.0):
			return
		move_touch_id = touch_id
		move_origin = hud._joystick_center
		move_position = position
		var offset := (position - move_origin) / maxf(hud._joystick_radius, 1.0)
		movement_changed.emit(offset.limit_length(1.0))
		hud.queue_redraw()
	elif look_zone and look_touch_id == -1:
		look_touch_id = touch_id


func update(touch_id: int, position: Vector2, relative: Vector2) -> void:
	if touch_id == fire_touch_id or pressed_buttons.has(touch_id):
		hud.get_viewport().set_input_as_handled()
		return
	if hud._player_down or hud.get_tree().paused:
		clear()
		return
	if touch_id == move_touch_id:
		move_position = position
		var radius := maxf(hud._joystick_radius, 1.0)
		var offset := (position - move_origin) / radius
		if offset.length() > 0.25:
			hud.hide_help()
		movement_changed.emit(offset.limit_length(1.0))
		hud.queue_redraw()
	elif touch_id == look_touch_id:
		look_delta.emit(relative)


func end(touch_id: int, position: Vector2) -> void:
	if touch_id == fire_touch_id:
		fire_touch_id = -1
		hud._fire_button.emit_signal("button_up")
		hud.get_viewport().set_input_as_handled()
		return
	if pressed_buttons.has(touch_id):
		var button := pressed_buttons[touch_id] as Button
		pressed_buttons.erase(touch_id)
		hud.get_viewport().set_input_as_handled()
		if is_instance_valid(button):
			button.emit_signal("button_up")
		if (
			is_instance_valid(button)
			and not button.disabled
			and button.get_global_rect().has_point(position)
		):
			activate(button)
		return
	if touch_id == move_touch_id:
		move_touch_id = -1
		movement_changed.emit(Vector2.ZERO)
		hud.queue_redraw()
	elif touch_id == look_touch_id:
		look_touch_id = -1


## Blur/pause can skip finger release; restore gameplay input and visual
## button-down state rather than stranding AIM or the FIRE rim.
func clear() -> void:
	if fire_touch_id != -1 and is_instance_valid(hud._fire_button):
		hud._fire_button.emit_signal("button_up")
	for held_button in pressed_buttons.values():
		if is_instance_valid(held_button):
			held_button.emit_signal("button_up")
	move_touch_id = -1
	look_touch_id = -1
	fire_touch_id = -1
	pressed_buttons.clear()
	move_origin = Vector2.ZERO
	move_position = Vector2.ZERO
	hud._soft_lock = false
	movement_changed.emit(Vector2.ZERO)
	fire_changed.emit(false)
	hud.queue_redraw()


func find_button(position: Vector2) -> Button:
	# Only the foreground menu accepts touches while a submenu is open.
	var candidates: Array[Button] = hud._touch_buttons
	if is_instance_valid(hud._confirm_dialog) and hud._confirm_dialog.visible:
		candidates = []
		for node in hud._confirm_dialog.find_children("*", "Button", true, false):
			candidates.append(node as Button)
	elif is_instance_valid(hud._settings_menu) and hud._settings_menu.visible:
		candidates = []
		for node in hud._settings_menu.find_children("*", "Button", true, false):
			candidates.append(node as Button)
	elif is_instance_valid(hud._upgrade_panel) and hud._upgrade_panel.visible:
		candidates = []
		for node in hud._upgrade_panel.find_children("*", "Button", true, false):
			candidates.append(node as Button)
	elif is_instance_valid(hud._armory_panel) and hud._armory_panel.visible:
		candidates = []
		for node in hud._armory_panel.find_children("*", "Button", true, false):
			candidates.append(node as Button)
	# Pick the smallest target containing the touch: the AIM button sits close to
	# FIRE and an overlapping (larger) control must not steal the press.
	var best: Button = null
	var best_area := INF
	for button in candidates:
		if not is_instance_valid(button) or not button.is_visible_in_tree():
			continue
		var rect := button.get_global_rect()
		if not rect.has_point(position):
			continue
		var area := rect.size.x * rect.size.y
		if area < best_area:
			best_area = area
			best = button
	return best


## A finger on a HUD button runs whatever that button was connected to when it
## was built.
##
## This used to be a hand-written if/elif ladder naming every button in the HUD,
## and the ladder is why the round-11 HOME plates shipped drawn, connected and
## dead: a synthetic touch never reaches Godot's Button GUI, so `pressed` only
## fires if this function emits it, and a button the ladder forgot did nothing
## at all. Emitting `pressed` is the same call the button makes when the GUI does
## handle it, so there is now one behaviour instead of two.
##
## The `push_error` is the guard the ladder could not give: a new plate with no
## handler is reported the first time a finger lands on it, instead of looking
## pressable forever.
func activate(button: Button) -> void:
	# Toggles carry their action on `toggled`, which flipping the state emits.
	if button.toggle_mode:
		button.button_pressed = not button.button_pressed
		return
	if not button.pressed.get_connections().is_empty():
		button.pressed.emit()
		return
	# FIRE and AIM act while held (button_down / button_up) and have no release
	# action, which is legitimate. A plate with neither a press nor a hold
	# handler is the dead button, and it names itself here the first time a
	# finger lands on it instead of looking pressable forever.
	if (
		button.button_down.get_connections().is_empty()
		and button.button_up.get_connections().is_empty()
	):
		push_error("HUD: %s has no handler; a finger on it does nothing." % button.name)
