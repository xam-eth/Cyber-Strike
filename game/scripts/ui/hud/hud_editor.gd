## In-game HUD editor: live group drag with an 8-unit snap, preset selection,
## persistent group offsets, and a compact inspector that works on a phone.
## Layout math is delegated to hud_editor_layout.gd; this is the UI/input layer.
class_name AegisHudEditor
extends Control

signal changed(values: Dictionary)
signal done

var _hud
var _values: Dictionary = {}
var _selected: String = ""
var _stretch: float = 1.0
var _font_scale: float = 1.0
var _dragging: bool = false
var _drag_total: Vector2 = Vector2.ZERO
var _drag_start: Vector2 = Vector2.ZERO
var _inspector: AegisPanel
var _shell: VBoxContainer
var _content: VBoxContainer
var _groups: OptionButton
var _position_label: Label
var _opacity_label: Label
var _scale_label: Label
var _opacity_slider: HSlider
var _scale_slider: HSlider
var _presets: Dictionary = {}


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_build()


func open(hud, values: Dictionary) -> void:
	_hud = hud
	_values = values.duplicate(true)
	visible = true
	_refresh_groups()
	_refresh_values()
	apply_layout(hud._stretch, hud._ui_scale * hud._hud_scale * hud._text_scale, hud._physical_size)
	_groups.grab_focus()
	queue_redraw()


func close() -> void:
	_dragging = false
	visible = false


func apply_layout(stretch: float, font_scale: float, physical_size: Vector2) -> void:
	_stretch = maxf(stretch, 0.001)
	_font_scale = font_scale
	var width_px := minf(340.0, physical_size.x - 24.0)
	var height_px := minf(430.0, physical_size.y - 24.0)
	var top_px := 270.0 if physical_size.y > physical_size.x else 12.0
	var left_px := (
		physical_size.x - width_px - 16.0
		if physical_size.x >= 1000.0
		else (physical_size.x - width_px) * 0.5
	)
	UiLayout.place(
		_hud,
		_inspector,
		0.0,
		0.0,
		0.0,
		0.0,
		Rect2(left_px / _stretch, top_px / _stretch, width_px / _stretch, height_px / _stretch)
	)
	_inspector.custom_minimum_size = Vector2(width_px, height_px) / _stretch
	_inspector.add_theme_stylebox_override(
		"panel",
		AegisTheme.panel_style(
			Color(AegisTokens.PANEL, 0.98),
			AegisTokens.ACCENT,
			1,
			AegisTokens.RADIUS,
			12.0 / _stretch
		)
	)
	_content.add_theme_constant_override("separation", roundi(6.0 / _stretch))
	_shell.add_theme_constant_override("separation", roundi(6.0 / _stretch))
	var floor_size := maxi(roundi(AegisTokens.MIN_PHYSICAL_FONT_PX / _stretch), 11)
	for node in find_children("*", "Label", true, false):
		var label := node as Label
		var role := String(label.get_meta("aegis_role", "body"))
		AegisTheme.resize_label(
			label,
			role,
			maxi(roundi(AegisTheme.type_size(role) * _font_scale / _stretch), floor_size)
		)
	for node in find_children("*", "Button", true, false):
		var button := node as Button
		button.custom_minimum_size.y = 44.0 / _stretch
		AegisTheme.resize_button_font(button, "label", maxi(roundi(12.0 / _stretch), floor_size))
	for slider in [_opacity_slider, _scale_slider]:
		AegisTheme.style_slider(slider, _stretch)
	queue_redraw()


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			_start_drag(event.position)
		else:
			_dragging = false
		accept_event()
	elif event is InputEventMouseMotion and _dragging:
		_drag_by(event.relative)
		accept_event()
	elif event is InputEventScreenTouch:
		if event.pressed:
			_start_drag(event.position)
		else:
			_dragging = false
		accept_event()
	elif event is InputEventScreenDrag and _dragging:
		_drag_by(event.relative)
		accept_event()


func _draw() -> void:
	if _hud == null or not visible:
		return
	var step := 40.0 / _stretch
	for column in range(1, floori(size.x / step)):
		draw_line(
			Vector2(column * step, 0),
			Vector2(column * step, size.y),
			Color(AegisTokens.LINE_HI, 0.17),
			1.0
		)
	for row in range(1, floori(size.y / step)):
		draw_line(
			Vector2(0, row * step),
			Vector2(size.x, row * step),
			Color(AegisTokens.LINE_HI, 0.17),
			1.0
		)
	var target := _target(_selected)
	if target == null or not target.is_visible_in_tree():
		return
	var bounds := target.get_global_rect()
	var local_position := get_global_transform().affine_inverse() * bounds.position
	var rect := Rect2(local_position, bounds.size).grow(4.0 / _stretch)
	draw_rect(rect, AegisTokens.ACCENT, false, 2.0 / _stretch)
	var handle := 7.0 / _stretch
	for corner in [
		rect.position,
		Vector2(rect.end.x, rect.position.y),
		rect.end,
		Vector2(rect.position.x, rect.end.y)
	]:
		draw_rect(
			Rect2(corner - Vector2.ONE * handle * 0.5, Vector2.ONE * handle), AegisTokens.ACCENT
		)


func _build() -> void:
	_inspector = AegisPanel.new()
	_inspector.name = "HudInspector"
	_inspector.interactive = true
	_inspector.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(_inspector)
	_shell = VBoxContainer.new()
	_shell.name = "InspectorShell"
	_shell.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_inspector.add_child(_shell)
	var scroll := ScrollContainer.new()
	scroll.name = "InspectorScroll"
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_shell.add_child(scroll)
	_content = VBoxContainer.new()
	_content.name = "InspectorContent"
	_content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(_content)
	_content.add_child(_label("AEGIS / LIVE PREVIEW", "label", AegisTokens.ACCENT))
	_content.add_child(_label("HUD LAYOUT", "heading", AegisTokens.INK))
	_groups = OptionButton.new()
	_groups.name = "HudGroupSelect"
	_groups.focus_mode = Control.FOCUS_ALL
	AegisTheme.set_button_variant(_groups, "ghost")
	_groups.item_selected.connect(_on_group_selected)
	_content.add_child(_groups)
	_position_label = _label("OFFSET  0 / 0", "mono_s", AegisTokens.INK_2)
	_content.add_child(_position_label)

	var preset_row := HBoxContainer.new()
	_content.add_child(preset_row)
	for preset in ["MINIMAL", "STANDARD", "ADVANCED"]:
		var button := _button(preset.substr(0, 3), "Preset%s" % preset, "ghost")
		button.tooltip_text = "%s HUD preset" % preset.capitalize()
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		button.pressed.connect(_set_preset.bind(preset))
		preset_row.add_child(button)
		_presets[preset] = button

	_opacity_label = _label("PANEL OPACITY", "body_s", AegisTokens.INK_2)
	_content.add_child(_opacity_label)
	_opacity_slider = _slider("EditorOpacity", 0.65, 1.0, 0.05)
	_opacity_slider.value_changed.connect(_on_slider_changed.bind("hud_opacity"))
	_scale_label = _label("HUD SCALE", "body_s", AegisTokens.INK_2)
	_content.add_child(_scale_label)
	_scale_slider = _slider("EditorScale", 0.8, 1.2, 0.05)
	_scale_slider.value_changed.connect(_on_slider_changed.bind("hud_scale"))

	var reset_row := HBoxContainer.new()
	_content.add_child(reset_row)
	var reset_group := _button("RESET GROUP", "ResetGroupButton", "ghost")
	reset_group.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	reset_group.pressed.connect(_reset_group)
	reset_row.add_child(reset_group)
	var reset_layout := _button("RESET ALL", "ResetLayoutButton", "ghost")
	reset_layout.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	reset_layout.pressed.connect(_reset_layout)
	reset_row.add_child(reset_layout)
	var finish := _button("DONE", "DoneHudEditorButton", "primary")
	finish.pressed.connect(done.emit)
	_shell.add_child(finish)


func _refresh_groups() -> void:
	_groups.clear()
	var keep := _selected
	for key in AegisPreferences.HUD_GROUPS:
		var target := _target(key)
		if target != null and target.is_visible_in_tree():
			_groups.add_item(key)
	if _groups.item_count == 0:
		return
	_selected = keep if _has_group(keep) else _groups.get_item_text(0)
	for index in _groups.item_count:
		if _groups.get_item_text(index) == _selected:
			_groups.select(index)
			break
	_refresh_position()


func _refresh_values() -> void:
	_opacity_slider.set_value_no_signal(float(_values.get("hud_opacity", 1.0)))
	_scale_slider.set_value_no_signal(float(_values.get("hud_scale", 1.0)))
	_opacity_label.text = "PANEL OPACITY  %d%%" % roundi(_opacity_slider.value * 100.0)
	_scale_label.text = "HUD SCALE  %d%%" % roundi(_scale_slider.value * 100.0)
	for preset in _presets:
		AegisTheme.set_button_variant(
			_presets[preset],
			"primary" if preset == _values.get("hud_preset", "STANDARD") else "ghost"
		)


func _has_group(key: String) -> bool:
	for index in _groups.item_count:
		if _groups.get_item_text(index) == key:
			return true
	return false


func _target(key: String) -> Control:
	if _hud == null or not HudEditorLayout.CONTROLS.has(key):
		return null
	return _hud.get(HudEditorLayout.CONTROLS[key]) as Control


func _on_group_selected(index: int) -> void:
	if index < 0 or index >= _groups.item_count:
		return
	_selected = _groups.get_item_text(index)
	_refresh_position()
	queue_redraw()


func _start_drag(point: Vector2) -> void:
	if _inspector.get_global_rect().has_point(point):
		return
	var best := INF
	for key in AegisPreferences.HUD_GROUPS:
		var target := _target(key)
		if target == null or not target.is_visible_in_tree():
			continue
		var bounds := target.get_global_rect().grow(8.0 / _stretch)
		if bounds.has_point(point) and bounds.get_area() < best:
			_selected = key
			best = bounds.get_area()
	if best == INF:
		return
	for index in _groups.item_count:
		if _groups.get_item_text(index) == _selected:
			_groups.select(index)
			break
	_dragging = true
	_drag_total = Vector2.ZERO
	_drag_start = _offset()
	_refresh_position()
	queue_redraw()


func _drag_by(relative: Vector2) -> void:
	_drag_total += relative
	var design := Vector2(
		_drag_total.x * 1280.0 / maxf(size.x, 1.0), _drag_total.y * 720.0 / maxf(size.y, 1.0)
	)
	var snapped := Vector2(roundf(design.x / 8.0) * 8.0, roundf(design.y / 8.0) * 8.0)
	var new_offset := _drag_start + snapped
	if new_offset != _offset():
		_set_offset(new_offset)


func _offset() -> Vector2:
	var offsets: Dictionary = _values.get("hud_offsets", {})
	return offsets.get(_selected, Vector2.ZERO)


func _set_offset(offset: Vector2) -> void:
	var offsets: Dictionary = _values.get("hud_offsets", {}).duplicate(true)
	offsets[_selected] = offset
	_values["hud_offsets"] = offsets
	_persist()
	_refresh_position()
	queue_redraw()


func _refresh_position() -> void:
	var offset := _offset()
	_position_label.text = "OFFSET  X %d  /  Y %d" % [roundi(offset.x), roundi(offset.y)]


func _on_slider_changed(value: float, key: String) -> void:
	_values[key] = value
	_refresh_values()
	_persist()


func _set_preset(preset: String) -> void:
	_values["hud_preset"] = preset
	_refresh_values()
	_persist()


func _reset_group() -> void:
	var offsets: Dictionary = _values.get("hud_offsets", {}).duplicate(true)
	offsets.erase(_selected)
	_values["hud_offsets"] = offsets
	_persist()
	_refresh_position()
	queue_redraw()


func _reset_layout() -> void:
	_values["hud_offsets"] = {}
	_values["hud_preset"] = "STANDARD"
	_refresh_values()
	_persist()
	_refresh_position()
	queue_redraw()


func _persist() -> void:
	_values = AegisPreferences.sanitized(_values)
	var error := AegisPreferences.write(_values)
	if error != OK:
		push_warning("Could not save HUD layout: %d" % error)
	changed.emit(_values.duplicate(true))


func _slider(name_text: String, low: float, high: float, step: float) -> HSlider:
	var slider := HSlider.new()
	slider.name = name_text
	slider.min_value = low
	slider.max_value = high
	slider.step = step
	slider.focus_mode = Control.FOCUS_ALL
	slider.add_theme_stylebox_override("slider", AegisTheme.flat_style(AegisTokens.PANEL_3))
	slider.add_theme_stylebox_override("grabber_area", AegisTheme.flat_style(AegisTokens.ACCENT))
	_content.add_child(slider)
	return slider


func _label(text: String, role: String, color: Color) -> Label:
	var label := Label.new()
	label.text = text
	label.set_meta("aegis_role", role)
	label.set_meta("aegis_scale", 1.0)
	AegisTheme.style_label(label, role, color)
	return label


func _button(text: String, node_name: String, variant: String) -> AegisButton:
	var button := AegisButton.new()
	button.name = node_name
	button.text = text
	button.focus_mode = Control.FOCUS_ALL
	AegisTheme.set_button_variant(button, variant)
	return button
