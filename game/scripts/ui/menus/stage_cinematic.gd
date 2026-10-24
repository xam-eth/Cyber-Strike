## The opening cinematic.
##
## Asset F asked for a video. One exists now -- `cinematic_opening.ogv`, encoded
## by `tools/art/build_ui_video.py` from the loading key art -- and this stage
## plays it when it loads. When it does not, the stage falls back to the same
## beat composed in-engine: a slow push-in on `loading_keyart.jpg` under four
## captions, skippable from the first frame. The two paths are the same length
## and carry the same captions, so the journey cannot tell them apart.
##
## The captions are UI text in both paths, never pixels in the video: text baked
## into a frame cannot be localised (docs/ART_DIRECTION.md §2).
##
## The captions state the premise the game actually implements (an arena, waves
## of hostiles, Battle Points that unlock weapons). They invent no characters,
## no faction history and no plot: GAME_CONCEPT.md is explicit that this game is
## not story-driven, so a lore-dump intro would be a lie about the product.
extends MenuStage

## Seconds each caption is held, fade in/out included.
const BEAT_SECONDS := 2.4
const FADE_SECONDS := 0.55
const PUSH_SECONDS := 9.6
const PUSH_SCALE := 1.14

## The encoded intro, 1280x720 @ 24 fps. Absent -> the composed fallback runs.
const OPENING_VIDEO := "res://assets/ui/cinematic_opening.ogv"
## How long a started-but-frozen video is given before the composed opening
## takes over, so a device that cannot decode Theora is never stranded.
const STALL_SECONDS := 2.5

## Assumed until the decoder reports the real frame size.
const DEFAULT_FRAME_SIZE := Vector2(1280.0, 720.0)

## Three of the four caption beats. The missing one is the theatre line, and it
## is built at runtime (see `_beat_caption`) because the theatre's name is the
## world definition's, not a literal kept here as well.
const CAPTIONS := [
	"AEGIS TRAINING FACILITY",
	"HOSTILE WAVES INBOUND",
	"SURVIVE · EARN BATTLE POINTS · UNLOCK",
]

## The sector the opening drops into. There is no sector data model, so this
## half of the theatre line stays a literal; the theatre's name does not.
const CAPTION_SECTOR := "SECTOR 01"

var _video: VideoStreamPlayer
var _plate: TextureRect
var _caption: Label
var _mark: TextureRect
var _skip: AegisButton
var _position: ProgressBar
var _elapsed := 0.0
var _total := 0.0
## Watchdog for a video that loads but never advances. Without it a device
## that cannot decode Theora would sit on the opening forever with no way out
## but a cold restart.
var _stall := 0.0
var _last_position := 0.0
var _reported := false
var _video_sized := false
var _beat := -1
var _reduce_motion := false
var _finished := false


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP

	var viewport := Control.new()
	viewport.set_anchors_preset(Control.PRESET_FULL_RECT)
	viewport.mouse_filter = Control.MOUSE_FILTER_IGNORE
	# Clip the push-in so the plate never spills past the frame edge.
	viewport.clip_contents = true
	add_child(viewport)

	# The key art is the poster frame: it sits behind the video, so a device
	# that cannot decode Theora shows the composed opening instead of a hole.
	_plate = make_backdrop("res://assets/ui/loading_keyart.jpg")
	_plate.pivot_offset = Vector2(960.0, 540.0)
	viewport.add_child(_plate)

	_video = VideoStreamPlayer.new()
	_video.name = &"OpeningVideo"
	_video.stream = try_video(OPENING_VIDEO)
	# `expand` stretches the frame to the control's rect, so the rect has to
	# keep the video's own aspect: on a 390x844 screen a full-rect 16:9 player
	# would stretch the opening into a vertical smear. Sized to *cover* the
	# stage instead, with the parent's clip_contents trimming the overflow.
	_video.expand = true
	_video.loop = false
	_video.autoplay = false
	_video.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_video.finished.connect(_on_video_finished)
	viewport.add_child(_video)

	var scrim := ColorRect.new()
	scrim.color = Color(AegisTokens.VOID, 0.42)
	scrim.set_anchors_preset(Control.PRESET_FULL_RECT)
	scrim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(scrim)

	var margin := MarginContainer.new()
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(margin)
	apply_safe_margins(margin)

	var column := VBoxContainer.new()
	column.alignment = BoxContainer.ALIGNMENT_END
	physical_separation(column, 20)
	margin.add_child(column)

	var spacer := Control.new()
	spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	column.add_child(spacer)

	_mark = TextureRect.new()
	_mark.texture = try_texture("res://assets/ui/logo_wordmark.png")
	_mark.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_mark.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	physical_min_size(_mark, 300.0, 75.0)
	_mark.modulate.a = 0.0
	column.add_child(_mark)

	_caption = make_label("", "heading", AegisTokens.INK)
	_caption.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_caption.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_caption.modulate.a = 0.0
	column.add_child(_caption)

	_position = ProgressBar.new()
	_position.show_percentage = false
	_position.min_value = 0.0
	_position.max_value = 1.0
	_position.value = 0.0
	physical_min_size(_position, 0.0, 4.0)
	column.add_child(_position)

	_skip = make_button("SKIP", "ghost", "Skip the opening cinematic")
	physical_min_size(_skip, 160.0, 56.0)
	_skip.pressed.connect(_on_skip_pressed)
	_connect_resized(_on_resized)
	relayout()
	column.add_child(_skip)


func enter(_stage_payload: Dictionary) -> void:
	_reduce_motion = bool(AegisPreferences.read().get("reduce_motion", false))
	_elapsed = 0.0
	_total = _captions_count() * BEAT_SECONDS
	_beat = -1
	_finished = false
	_position.value = 0.0
	_caption.modulate.a = 0.0
	_mark.modulate.a = 0.0
	_plate.scale = Vector2.ONE
	_stall = 0.0
	_last_position = 0.0
	_reported = false
	_video_sized = false
	# The length is *not* known yet: `stream_length` reads 0.00 until the
	# decoder has opened the file, and taking it here made the progress bar
	# saturate and the intro finish on its first frame (measured in a real
	# browser build). Start from the authored length and adopt the measured one
	# as soon as the decoder reports it.
	_video.visible = _video.stream != null and not _reduce_motion
	_layout_video()
	if _video.visible:
		_video.play()
		print("MenuCinematic: playing the encoded opening")
	else:
		_video.stop()
		_video.stream_position = 0.0
		print("MenuCinematic: playing the composed opening (%.2f s)" % _total)
	_advance_beat()
	set_process(true)


func exit() -> void:
	set_process(false)
	if is_instance_valid(_plate):
		_plate.scale = Vector2.ONE
	if is_instance_valid(_video) and _video.is_playing():
		_video.stop()


func _process(delta: float) -> void:
	if _finished:
		return
	if _video.visible:
		if _watch_video(delta):
			return
		var measured := _video.get_stream_length()
		if measured > 0.1:
			_total = measured
		if not _video_sized:
			_video_sized = _layout_video()
	if _video.visible and not _reported and _elapsed >= 2.0:
		# One line, once: which path this device is on is exactly the question
		# a QA run has to be able to answer from the log alone.
		_reported = true
		print("MenuCinematic: stream at %.2f s of %.2f s" % [_elapsed, _total])
	_elapsed = _video.stream_position if _video.visible else _elapsed + delta
	_position.value = clampf(_elapsed / maxf(_total, 0.001), 0.0, 1.0)
	# The push-in belongs to the composed opening. It is skipped while the video
	# covers the plate, which also means any motion measured during playback
	# comes from the video and nothing else.
	if not _video.visible and not _reduce_motion:
		var phase := clampf(_elapsed / PUSH_SECONDS, 0.0, 1.0)
		var eased: float = 1.0 - pow(1.0 - phase, 3.0)
		_plate.scale = Vector2.ONE * lerpf(1.0, PUSH_SCALE, eased)
		_plate.pivot_offset = _plate.size * 0.5
	var beat := int(_elapsed / BEAT_SECONDS)
	if beat != _beat and beat < _captions_count():
		_beat = beat
		_advance_beat()
	if _elapsed >= _total:
		_finish()


func _advance_beat() -> void:
	if _beat < 0 or _beat >= _captions_count():
		return
	_caption.text = _beat_caption(_beat)
	# The wordmark only lands with the last caption, so the title is revealed
	# by the intro rather than competing with it for the first eight seconds.
	if _beat == _captions_count() - 1:
		_fade(_mark, 1.0)
	if _reduce_motion:
		_caption.modulate.a = 1.0
		return
	_caption.modulate.a = 0.0
	_fade(_caption, 1.0)


func _fade(target: CanvasItem, to_alpha: float) -> void:
	var tween := create_tween()
	tween.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_property(target, "modulate:a", to_alpha, FADE_SECONDS)


## True when the video stalled and the composed opening took over, in which
## case this frame is already spent and `_process` should stop.
func _watch_video(delta: float) -> bool:
	if not _video.is_playing():
		return false
	if _video.stream_position > _last_position + 0.001:
		_last_position = _video.stream_position
		_stall = 0.0
		return false
	_stall += delta
	if _stall < STALL_SECONDS:
		return false
	push_warning(
		"MenuCinematic: the opening video stalled at %.2f s; falling back." % _last_position
	)
	_fallback_to_composed()
	return true


## Hand the rest of the intro to the composed path from wherever the video got
## to, so the captions keep their place instead of restarting the opening.
func _fallback_to_composed() -> void:
	_video.visible = false
	_video.stop()
	_total = _captions_count() * BEAT_SECONDS
	_elapsed = _last_position
	_stall = 0.0


## Cover the stage with the video's own aspect, centred, so nothing is
## stretched and the overflow is clipped by the parent.
## True once the real frame size is known and the rect can stop moving.
##
## `VideoStream` carries no size -- `stream.get_size()` does not exist in this
## build (`has_method("get_size")` is false on VideoStreamTheora), so the first
## draft of this function threw on every call and left the player at the full
## stage rect: exactly the vertical smear it was written to prevent. The frame
## size only becomes knowable from the decoded texture, so the layout starts
## from the authored 16:9 and is refined on the first decoded frame.
func _layout_video() -> bool:
	if _video.stream == null or size.x <= 0.0 or size.y <= 0.0:
		return false
	var natural := DEFAULT_FRAME_SIZE
	var texture := _video.get_video_texture()
	if texture != null:
		var decoded := texture.get_size()
		if decoded.x > 0.0 and decoded.y > 0.0:
			natural = decoded
	var scale := maxf(size.x / natural.x, size.y / natural.y)
	var wanted := natural * scale
	_video.size = wanted
	_video.position = (size - wanted) * 0.5
	return texture != null


func _on_skip_pressed() -> void:
	_finish()


func _on_video_finished() -> void:
	_finish()


func _finish() -> void:
	if _finished:
		return
	_finished = true
	set_process(false)
	completed.emit(&"CHAPTER", {})


func _on_resized() -> void:
	relayout()
	_layout_video()


## Four beats: the facility line, then the theatre, then the two closing lines.
static func _captions_count() -> int:
	return CAPTIONS.size() + 1


## The theatre line is built from `WorldDefinition` rather than typed out, so
## the opening cannot name one world while the WORLD card and the dashboard
## name another. If the definition is ever missing the id is spelled out
## instead -- never a remembered copy of the name.
static func _beat_caption(beat: int) -> String:
	if beat <= 0:
		return CAPTIONS[0]
	if beat == 1:
		var world := WorldDefinition.load_definition(WorldDefinition.DEFAULT_WORLD_ID)
		var theatre := (
			String(WorldDefinition.DEFAULT_WORLD_ID).replace("_", " ").to_upper()
			if world == null
			else world.display_name.to_upper()
		)
		return "%s — %s" % [theatre, CAPTION_SECTOR]
	if beat - 1 < CAPTIONS.size():
		return CAPTIONS[beat - 1]
	return ""
