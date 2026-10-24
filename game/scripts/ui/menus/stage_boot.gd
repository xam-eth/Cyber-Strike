## BOOT: the wordmark on void while the persistent profile is read.
##
## The work here is real but unmeasurable -- `ProgressionService.load_profile()`
## and `AegisPreferences.read()` are two ConfigFile reads -- so the bar is
## indeterminate and states no percentage. A short minimum hold keeps the
## wordmark from flashing for a single frame on a fast device; that is a brand
## beat, not a loading claim, and the label says what is happening rather than
## how far along it is.
extends MenuStage

const MINIMUM_SECONDS := 1.2
const STATUS := "READING PROFILE"

## The art the front end needs resident before the first menu is worth showing.
## BOOT does not load it; it names it, and LOADING loads it with real progress.
const FRONT_END_ART := [
	"res://assets/ui/loading_keyart.jpg",
	"res://assets/ui/dashboard_bg.jpg",
	"res://assets/ui/logo_wordmark.png",
	"res://assets/ui/portrait_hero.png",
	"res://assets/ui/world_neon_frontier.jpg",
	"res://assets/ui/weapon_pulse_rifle.png",
	"res://assets/ui/weapon_nova_launcher.png",
	"res://assets/ui/weapon_arc_shooter.png",
]

var _mark: TextureRect
var _bar: MenuIndeterminateBar
var _status: Label
var _hold_remaining := 0.0
var _reported := false


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	var fill := ColorRect.new()
	fill.color = AegisTokens.VOID
	fill.set_anchors_preset(Control.PRESET_FULL_RECT)
	fill.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(fill)

	var centre := CenterContainer.new()
	centre.set_anchors_preset(Control.PRESET_FULL_RECT)
	centre.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(centre)

	var column := VBoxContainer.new()
	column.alignment = BoxContainer.ALIGNMENT_CENTER
	physical_separation(column, 32)
	centre.add_child(column)

	# Two authored sizes: a portrait phone is 390 px wide and cannot hold a
	# 540 px wordmark without it hanging off both edges, while a desktop has
	# the width to make the mark the thing the screen opens on.
	_mark = TextureRect.new()
	_mark.texture = try_texture("res://assets/ui/logo_wordmark.png")
	_mark.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_mark.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_size_both(_mark, Vector2(300.0, 75.0), Vector2(540.0, 135.0))
	column.add_child(_mark)

	var holder := VBoxContainer.new()
	holder.alignment = BoxContainer.ALIGNMENT_CENTER
	physical_separation(holder, 14)
	column.add_child(holder)

	_bar = MenuIndeterminateBar.new()
	_bar.reduce_motion = bool(AegisPreferences.read().get("reduce_motion", false))
	physical_min_size(_bar, 420.0, 10.0)
	holder.add_child(_bar)

	_status = make_label(STATUS, "label", AegisTokens.INK_2)
	_status.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	holder.add_child(_status)


func enter(_stage_payload: Dictionary) -> void:
	var values := AegisPreferences.read()
	_bar.reduce_motion = bool(values.get("reduce_motion", false))
	_reported = false
	_hold_remaining = MINIMUM_SECONDS
	_bar.set_running(true)
	_status.text = STATUS
	_connect_resized(_on_resized)
	relayout()
	set_process(true)


func exit() -> void:
	set_process(false)
	_bar.set_running(false)


func _process(delta: float) -> void:
	_hold_remaining = maxf(_hold_remaining - delta, 0.0)
	if _hold_remaining > 0.0 or _reported:
		return
	_reported = true
	_bar.set_running(false)
	set_process(false)
	completed.emit(&"LOADING", {"targets": FRONT_END_ART})


func _on_resized() -> void:
	relayout()
	_orient_nodes([_mark])
