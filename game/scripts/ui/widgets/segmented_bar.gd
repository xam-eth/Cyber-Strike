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
	if segments <= 1:
		return
	var step_width := size.x / float(segments)
	for index in range(1, segments):
		var x := roundf(step_width * float(index))
		draw_rect(Rect2(x - gap_width * 0.5, 0.0, gap_width, size.y), gap_color, true)
		if notch_color.a > 0.0:
			draw_line(Vector2(x, 0.0), Vector2(x, 2.0), notch_color, 1.0)
