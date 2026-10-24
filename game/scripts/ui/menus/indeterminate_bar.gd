## A sweep bar for work that reports no progress.
##
## Used by BOOT, where the real work is reading two ConfigFiles. That has no
## measurable fraction -- `ConfigFile.load` either returns OK or it does not --
## so claiming "40%" would be a number invented by the UI. This draws a segment
## that travels along a fixed track and never states a value.
##
## `reduce_motion` (AegisPreferences) turns it into a static, dimmed track
## rather than removing it, so the screen does not lose the "working" cue.
class_name MenuIndeterminateBar
extends Control

const SWEEP_SECONDS := 1.6
const SEGMENT_RATIO := 0.34

@export var track_color: Color = AegisTokens.LINE
@export var sweep_color: Color = AegisTokens.INFO
@export var corner_color: Color = AegisTokens.LINE_HI
@export var reduce_motion: bool = false

## Paused bars stop animating but stay visible: BOOT pauses the sweep the moment
## its work finishes so the bar never implies progress that has already stopped.
var running := true

var _elapsed := 0.0


func _ready() -> void:
	set_process(running)


## Pausing the bar keeps it on screen and frozen: the screen still reads as
## "working" without the sweep implying progress that has already stopped.
func set_running(value: bool) -> void:
	running = value
	set_process(value)


func _process(delta: float) -> void:
	if reduce_motion:
		return
	_elapsed = fmod(_elapsed + delta, SWEEP_SECONDS)
	queue_redraw()


func _draw() -> void:
	var track := Rect2(0.0, 0.0, size.x, size.y)
	draw_rect(track, track_color, true)
	# Bracket the ends so the bar reads as an instrument, not a web widget.
	var tick := minf(6.0, size.y)
	draw_rect(Rect2(0.0, 0.0, 1.0, size.y), corner_color, true)
	draw_rect(Rect2(size.x - 1.0, 0.0, 1.0, size.y), corner_color, true)
	draw_rect(Rect2(0.0, 0.0, tick, 1.0), corner_color, true)
	draw_rect(Rect2(0.0, size.y - 1.0, tick, 1.0), corner_color, true)
	draw_rect(Rect2(size.x - tick, 0.0, tick, 1.0), corner_color, true)
	draw_rect(Rect2(size.x - tick, size.y - 1.0, tick, 1.0), corner_color, true)
	if reduce_motion:
		draw_rect(Rect2(0.0, 0.0, size.x, size.y), Color(sweep_color, 0.25), true)
		return
	# There-and-back rather than wrapping: a segment that restarts from the left
	# looks like a loop of finished work, which is the exact claim to avoid.
	var phase: float = _elapsed / SWEEP_SECONDS
	var eased: float = 0.5 - 0.5 * cos(phase * TAU)
	var travel: float = size.x * (1.0 - SEGMENT_RATIO)
	draw_rect(Rect2(eased * travel, 0.0, size.x * SEGMENT_RATIO, size.y), sweep_color, true)
