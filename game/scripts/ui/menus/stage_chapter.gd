## CHAPTER 01 title card between the cinematic and the dashboard.
##
## Deliberately small: it names the chapter and the objective the run actually
## measures, then gets out of the way. It advances on CONTINUE or on any tap
## outside the button, and it is the last thing the player sees before the
## dashboard takes input.
extends MenuStage

const CHAPTER := "CHAPTER 01"
const TITLE := "FIRST LIGHT"
const OBJECTIVE := "OBJECTIVE — SURVIVE THE WAVE"
const DETAIL := "Defeat hostiles to bank Battle Points. Unlock weapons in the Armory."

var _card: AegisPanel
var _column: VBoxContainer
var _material := 0.0


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(make_backdrop("res://assets/ui/world_neon_frontier.jpg"))

	var scrim := ColorRect.new()
	scrim.color = Color(AegisTokens.VOID, 0.5)
	scrim.set_anchors_preset(Control.PRESET_FULL_RECT)
	scrim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(scrim)

	var margin := MarginContainer.new()
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(margin)
	apply_safe_margins(margin)

	var centre := CenterContainer.new()
	margin.add_child(centre)

	_card = AegisPanel.new()
	_card.interactive = true
	_card.accent_side = "left"
	_card.accent_color = AegisTokens.ACCENT
	_card.mouse_filter = Control.MOUSE_FILTER_PASS
	centre.add_child(_card)

	_column = VBoxContainer.new()
	physical_separation(_column, 12)
	_card.add_child(_column)

	_column.add_child(_line(CHAPTER, "label", AegisTokens.ACCENT))
	_column.add_child(_line(TITLE, "display_l", AegisTokens.INK))
	_column.add_child(_line(OBJECTIVE, "body", AegisTokens.INFO))
	var detail := _line(DETAIL, "body_s", AegisTokens.INK_2)
	detail.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	physical_min_size(detail, 320.0, 0.0)
	_column.add_child(detail)

	var button := make_button("CONTINUE", "primary", "Continue to the dashboard")
	physical_min_size(button, 220.0, 56.0)
	button.pressed.connect(_on_continue_pressed)
	_column.add_child(button)
	_connect_resized(_on_resized)
	relayout()


func enter(_stage_payload: Dictionary) -> void:
	var reduce := bool(AegisPreferences.read().get("reduce_motion", false))
	_material = 0.0
	if reduce:
		_card.modulate.a = 1.0
		return
	_card.modulate.a = 0.0
	var tween := create_tween()
	tween.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_property(_card, "modulate:a", 1.0, 0.45)


func _unhandled_input(event: InputEvent) -> void:
	# The base class turns ui_accept into this stage's primary action; call it
	# first so Enter works here too, then keep the click-to-continue fallback.
	super._unhandled_input(event)
	if get_viewport().is_input_handled():
		return
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		_on_continue_pressed()


func _on_continue_pressed() -> void:
	completed.emit(&"DASHBOARD", {})


func _line(text: String, role: String, color: Color) -> Label:
	var label := make_label(text, role, color)
	return label


func _on_resized() -> void:
	relayout()
