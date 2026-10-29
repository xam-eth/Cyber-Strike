class_name AetherfallMissionHud
extends CanvasLayer
## HUD values are connected to the local authoritative progression state only.

var _state: AetherfallProgressionState
var _player: AetherfallPlayer
var _cache_id := ""
var _objective_id := ""
var _required_data := 1
var _mission_label: Label
var _resource_label: Label
var _prompt_label: Label
var _feedback_label: Label
var _feedback_timer: Timer

func _ready() -> void:
	layer = 5
	_build_ui()

func bind_slice(state: AetherfallProgressionState, player: AetherfallPlayer, cache_id: String, objective_id: String, required_data: int) -> void:
	_state = state
	_player = player
	_cache_id = cache_id
	_objective_id = objective_id
	_required_data = required_data
	state.state_changed.connect(_refresh)
	player.interaction_target_changed.connect(_on_target_changed)
	player.interaction_feedback.connect(_on_feedback)
	_refresh()

func _build_ui() -> void:
	var panel := PanelContainer.new()
	panel.position = Vector2(18, 58)
	panel.custom_minimum_size = Vector2(385, 0)
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.025, 0.045, 0.065, 0.86)
	style.border_color = Color(0.16, 0.68, 0.91, 0.8)
	style.set_border_width_all(1)
	style.set_corner_radius_all(5)
	style.content_margin_left = 14
	style.content_margin_right = 14
	style.content_margin_top = 11
	style.content_margin_bottom = 11
	panel.add_theme_stylebox_override("panel", style)
	add_child(panel)
	var content := VBoxContainer.new()
	content.add_theme_constant_override("separation", 5)
	panel.add_child(content)
	var title := Label.new()
	title.text = "STELLAR HORIZON  •  VERTICAL SLICE"
	title.add_theme_font_size_override("font_size", 14)
	title.add_theme_color_override("font_color", Color(0.37, 0.82, 1.0))
	content.add_child(title)
	_mission_label = Label.new()
	_mission_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_mission_label.add_theme_font_size_override("font_size", 17)
	content.add_child(_mission_label)
	_resource_label = Label.new()
	_resource_label.add_theme_font_size_override("font_size", 14)
	_resource_label.add_theme_color_override("font_color", Color(0.75, 0.88, 0.97))
	content.add_child(_resource_label)
	var help := Label.new()
	help.text = "WASD bergerak  •  klik kanan lihat  •  E interaksi  •  F1 review"
	help.add_theme_font_size_override("font_size", 12)
	help.add_theme_color_override("font_color", Color(0.62, 0.7, 0.76))
	content.add_child(help)
	_prompt_label = Label.new()
	_prompt_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_prompt_label.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	_prompt_label.position = Vector2(-320, -116)
	_prompt_label.size = Vector2(640, 36)
	_prompt_label.add_theme_font_size_override("font_size", 20)
	_prompt_label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.95))
	_prompt_label.add_theme_constant_override("outline_size", 6)
	add_child(_prompt_label)
	_feedback_label = Label.new()
	_feedback_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_feedback_label.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	_feedback_label.position = Vector2(-370, -77)
	_feedback_label.size = Vector2(740, 30)
	_feedback_label.add_theme_font_size_override("font_size", 16)
	_feedback_label.add_theme_color_override("font_color", Color(0.65, 0.93, 1.0))
	_feedback_label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.95))
	_feedback_label.add_theme_constant_override("outline_size", 5)
	add_child(_feedback_label)
	_feedback_timer = Timer.new()
	_feedback_timer.one_shot = true
	_feedback_timer.timeout.connect(func(): _feedback_label.text = "")
	add_child(_feedback_timer)

func _refresh() -> void:
	if _state == null:
		return
	_resource_label.text = "Data teknologi tersimpan: %d" % _state.tech_data
	if _state.is_objective_active(_objective_id):
		_mission_label.text = "Status: relai horizon aktif — slice selesai"
	elif _state.tech_data >= _required_data:
		_mission_label.text = "Tujuan: autentikasi relai horizon di zona tengah"
	else:
		_mission_label.text = "Tujuan: temukan dan buka Tech Cache primer"

func _on_target_changed(target: AetherfallInteractionTarget) -> void:
	_prompt_label.text = target.get_prompt() if target != null else ""

func _on_feedback(message: String) -> void:
	_feedback_label.text = message
	_feedback_timer.start(3.8)
