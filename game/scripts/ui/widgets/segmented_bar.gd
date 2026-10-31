## ProgressBar with instrument-style segment ticks.
##
## A thin 4-6 px health bar is hard to read at a glance: four segments let the
## player count "two bars left" without reading the number. The separators are
## painted in the panel colour, so the fill appears to break rather than the bar
## gaining extra lines.
class_name SegmentedBar
extends ProgressBar

@export var segments: int = 4:
	set(value):
		segments = maxi(value, 1)
		queue_redraw()
@export var gap_color: Color = AegisTokens.PANEL:
	set(value):
		gap_color = value
		queue_redraw()
@export var gap_width: float = 2.0:
	set(value):
		gap_width = value
		queue_redraw()
## A brighter notch at the segment boundaries, for bars shown over the world.
@export var notch_color: Color = Color(0, 0, 0, 0):
	set(value):
		notch_color = value
		queue_redraw()


func _ready() -> void:
	resized.connect(queue_redraw)
	show_percentage = false


func _draw() -> void:
	if size.x <= 1.0 or size.y <= 1.0:
		return
	var span := maxf(max_value - min_value, 0.001)
	var ratio := clampf((value - min_value) / span, 0.0, 1.0)
	if ratio > 0.01:
		draw_rect(
			Rect2(0.0, 0.0, size.x * ratio, minf(1.5, size.y * 0.3)),
			Color(1.0, 1.0, 1.0, 0.24),
			true
		)
	draw_rect(Rect2(Vector2.ZERO, size), Color(AegisTokens.LINE_HI, 0.42), false, 1.0)
	if segments <= 1:
		return
	var step_width := size.x / float(segments)
	for index in range(1, segments):
		var x := roundf(step_width * float(index))
		draw_rect(Rect2(x - gap_width * 0.5, 0.0, gap_width, size.y), gap_color, true)
		var tick_col := notch_color if notch_color.a > 0.0 else Color(AegisTokens.LINE_HI, 0.55)
		draw_line(Vector2(x, 0.0), Vector2(x, minf(2.0, size.y * 0.45)), tick_col, 1.0)
