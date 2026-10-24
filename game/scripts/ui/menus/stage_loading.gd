## LOADING and PRELOAD: one implementation, two stages.
##
## The screen is a **poster, not a dialog**. The reference is the opening of a
## mobile survival title (Doomsday): full-bleed key art edge to edge, no
## letterbox, a heavy gradient to near-black across the lower half, and the
## product mark sitting in that dark band at a size it could be read across a
## room. Measured off the reference frames: the mark spans roughly 60 % of the
## frame width, sits with its cap-height centre about 88 % down, and the only
## other element on the screen is a small low-contrast credit line under it.
##
## What that rules out, and why each one was already a defect here:
##
##   * a flat void plate with a wordmark floating in the optical centre -- that
##     is BOOT's composition, and two stages that look the same are one stage
##     printed twice;
##   * a "LOADING" heading, a status count and a percentage stacked as a form --
##     the reference has one line of small type and the player reads the bar,
##     not a table;
##   * the wordmark at 440 px in the middle of the screen -- on a poster the
##     mark is large and anchored, and the art is what the screen is for.
##
## The bar is still driven by `ResourceLoader.load_threaded_get_status`, so the
## percentage is the engine's own count of resources fetched, not a timer. When
## there is nothing real to load the stage refuses to invent a number: the
## hairline becomes an indeterminate sweep instead.
##
## Payload:
##   targets: Array[String]  resource paths to fetch, in order
##   title:   String         the caption over the bar
##   next:    StringName     stage to enter when the queue drains
##   scene:   String         if set, change to this scene instead of going to a
##                           stage (used by PRELOAD for the gameplay scene)
extends MenuStage

## The poster. Kept as a literal so `data_source_smoke` can prove the file
## exists -- and it is the front end's key art, which `BOOT.FRONT_END_ART`
## loads with real progress before this screen is reached.
const KEY_ART := "res://assets/ui/loading_keyart.jpg"
const WORDMARK := "res://assets/ui/logo_wordmark.png"

## How much of the frame the bottom gradient covers. 0.52 is measured off the
## reference: the artwork is legible down to the horizon and the title band is
## the bottom half, so the mark never sits on a busy part of the picture.
const SCRIM_HEIGHT := 0.52

var _targets: Array[String] = []
var _index := 0
var _failed: Array[String] = []
var _title: Label
var _bar: ProgressBar
var _percent: Label
var _status: Label
var _mark: TextureRect
var _indeterminate: MenuIndeterminateBar
var _reduce_motion := false
var _done := false
## QA only (`?qa_hold=1`): stop at 100 % instead of leaving the stage. A web
## build finishes this preload within one frame, so the screen cannot otherwise
## be photographed or reviewed at all -- and "it is always too fast to see" is
## not a reason to ship a screen nobody has looked at. Inert in the real flow:
## FrontEnd only sets it from the QA deep link, and nothing else reads it.
var _hold := false
var _scrim_top: TextureRect
var _scrim_bottom: TextureRect
var _bottom_gap: Control


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	_build_poster()
	_build_caption()

	_connect_resized(_on_resized)
	relayout()
	_apply_poster()


## The picture, and the darkness it needs. Key art is drawn with
## `STRETCH_KEEP_ASPECT_COVERED`: the reference is full-bleed at every aspect,
## and letterboxing a phone would put two black bars over the one thing the
## screen exists to show. The two gradients are what let white type sit on a
## photograph without a plate behind it -- a flat scrim dulls the whole image,
## a gradient only dims the band the type is in.
func _build_poster() -> void:
	# Anything at all behind the art, so a decode that has not landed yet is a
	# dark frame rather than the uninitialised grey of the viewport. Added
	# first: a sibling drawn earlier is a sibling drawn under.
	var plate := ColorRect.new()
	plate.name = &"LoadingPlate"
	plate.color = AegisTokens.VOID
	plate.set_anchors_preset(Control.PRESET_FULL_RECT)
	plate.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(plate)

	var art := TextureRect.new()
	art.name = &"LoadingKeyArt"
	art.texture = try_texture(KEY_ART)
	art.set_anchors_preset(Control.PRESET_FULL_RECT)
	art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	art.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	art.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(art)

	# `true` ramps near-black at the top down to transparent: the top band.
	_scrim_top = _make_scrim(true)
	_scrim_top.name = &"LoadingScrimTop"
	add_child(_scrim_top)
	# `false` ramps transparent at the top down to near-black: the bottom band.
	_scrim_bottom = _make_scrim(false)
	_scrim_bottom.name = &"LoadingScrimBottom"
	add_child(_scrim_bottom)


## A vertical gradient from transparent to near-black. Built as a
## `GradientTexture2D` because a `ColorRect` has one colour and stacking four
## of them to fake a ramp leaves visible steps on a 720 px-tall frame.
func _make_scrim(upwards: bool) -> TextureRect:
	var gradient := Gradient.new()
	gradient.offsets = PackedFloat32Array([0.0, 0.62, 1.0])
	gradient.colors = PackedColorArray(
		[
			Color(AegisTokens.VOID, 0.0),
			Color(AegisTokens.VOID, 0.45),
			Color(AegisTokens.VOID, 0.97),
		]
	)
	var texture := GradientTexture2D.new()
	texture.gradient = gradient
	texture.fill = GradientTexture2D.FILL_LINEAR
	texture.fill_from = Vector2(0.0, 1.0) if upwards else Vector2(0.0, 0.0)
	texture.fill_to = Vector2(0.0, 0.0) if upwards else Vector2(0.0, 1.0)
	texture.width = 8
	texture.height = 256

	var scrim := TextureRect.new()
	scrim.texture = texture
	scrim.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	scrim.stretch_mode = TextureRect.STRETCH_SCALE
	scrim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return scrim


## The title band, anchored to the bottom of the frame: the mark, one caption
## row, and the hairline. A `VBoxContainer` with an expanding spacer above it
## is what pins the block down instead of leaving it in the optical centre.
func _build_caption() -> void:
	var margin := MarginContainer.new()
	margin.name = &"LoadingBand"
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(margin)
	apply_safe_margins(margin)

	var column := VBoxContainer.new()
	column.alignment = BoxContainer.ALIGNMENT_END
	physical_separation(column, 18)
	margin.add_child(column)

	var top_spacer := Control.new()
	top_spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	top_spacer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.add_child(top_spacer)

	# The mark comes first: a player who alt-tabs back mid-load should recognise
	# the product before reading the status line. Two authored sizes, because a
	# 390 px phone cannot hold a 620 px wordmark.
	_mark = TextureRect.new()
	_mark.name = &"Wordmark"
	_mark.texture = try_texture(WORDMARK)
	_mark.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_mark.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_mark.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_size_both(_mark, Vector2(340.0, 85.0), Vector2(720.0, 180.0))
	column.add_child(_mark)

	# One row, the same shape the reference uses: what is happening on the
	# left, the figure on the right, both small. Two lines of copy under a
	# poster title is a dialog; this is a credit line.
	var headline := HBoxContainer.new()
	physical_separation(headline, 16)
	column.add_child(headline)

	# `label`, not `label_s`: at 1280x720 the canvas scale is 1, so `label_s`
	# drew a 14 px credit line under a 720 px wordmark and the frame read as a
	# mock-up. The floor for supporting text in this project is 16 px
	# (docs/DECISIONS.md 20).
	_title = make_label("LOADING", "label", AegisTokens.INK_2)
	_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	headline.add_child(_title)

	_percent = make_label("", "mono_m", AegisTokens.INK)
	_percent.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	headline.add_child(_percent)

	_status = make_label("", "label", AegisTokens.INK_3)
	column.add_child(_status)

	# The hairline: 3 physical px of amber across the full text width. It is
	# the only element on the screen that moves, which is what makes it
	# readable as progress rather than as a decorative rule.
	_bar = ProgressBar.new()
	_bar.name = &"LoadingBar"
	_bar.show_percentage = false
	_bar.min_value = 0.0
	_bar.max_value = 1.0
	_bar.value = 0.0
	physical_min_size(_bar, 0.0, 3.0)
	# Not the default theme: an unstyled `ProgressBar` draws Godot's grey
	# trough, which on a photograph reads as a browser widget. The track is
	# line-coloured at a third of its alpha and the fill is the one amber the
	# palette allows, so the hairline belongs to the palette rather than to the
	# engine.
	var track := StyleBoxFlat.new()
	track.bg_color = Color(AegisTokens.LINE, 0.55)
	var fill := StyleBoxFlat.new()
	fill.bg_color = AegisTokens.ACCENT
	_bar.add_theme_stylebox_override("background", track)
	_bar.add_theme_stylebox_override("fill", fill)
	column.add_child(_bar)

	_indeterminate = MenuIndeterminateBar.new()
	_indeterminate.name = &"LoadingSweep"
	physical_min_size(_indeterminate, 0.0, 3.0)
	_indeterminate.visible = false
	column.add_child(_indeterminate)

	# Breathing room under the bar. The web shell draws its own control chip in
	# the bottom-left corner, and the poster's credit line sat on top of it
	# (measured on the first 1280x720 frame of this design). Five per cent of
	# the frame keeps the whole band clear of it without moving the band up
	# into the picture.
	_bottom_gap = Control.new()
	_bottom_gap.name = &"LoadingGap"
	_bottom_gap.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.add_child(_bottom_gap)


func enter(stage_payload: Dictionary) -> void:
	_reduce_motion = bool(AegisPreferences.read().get("reduce_motion", false))
	_targets = []
	for path in stage_payload.get("targets", []):
		_targets.append(str(path))
	_index = 0
	_failed = []
	_done = false
	_hold = bool(stage_payload.get("hold", false))
	_title.text = str(stage_payload.get("title", "LOADING"))
	_apply_poster()
	var total := _targets.size()
	if total == 0:
		# Nothing measurable to fetch: say so rather than animating a number.
		_bar.visible = false
		_indeterminate.visible = true
		_indeterminate.reduce_motion = _reduce_motion
		_indeterminate.set_running(true)
		_percent.text = ""
		_status.text = "PREPARING"
	else:
		_bar.visible = true
		_indeterminate.visible = false
		_bar.value = 0.0
		_percent.text = "0%"
		_status.text = "0 / %d" % total
		ResourceLoader.load_threaded_request(_targets[0])
	set_process(true)
	# An empty queue still has to leave the stage; give it one beat.
	if total == 0:
		call_deferred("_finish")


func exit() -> void:
	set_process(false)
	_indeterminate.set_running(false)


func _process(_delta: float) -> void:
	if _done or _index >= _targets.size():
		return
	var progress: Array = []
	var status := ResourceLoader.load_threaded_get_status(_targets[_index], progress)
	match status:
		ResourceLoader.THREAD_LOAD_LOADED:
			_index += 1
			_status.text = "%d / %d" % [_index, _targets.size()]
			if _index < _targets.size():
				ResourceLoader.load_threaded_request(_targets[_index])
			else:
				_finish()
		ResourceLoader.THREAD_LOAD_IN_PROGRESS:
			var fraction := float(progress[0]) if progress.size() > 0 else 0.0
			var overall := (float(_index) + clampf(fraction, 0.0, 1.0)) / float(_targets.size())
			_bar.value = overall
			_percent.text = "%d%%" % roundi(overall * 100.0)
		ResourceLoader.THREAD_LOAD_FAILED, ResourceLoader.THREAD_LOAD_INVALID_RESOURCE:
			# A missing resource must be loud. Continuing keeps the game
			# bootable; the push_error is what the test suite sees.
			push_error("MenuLoading: could not load '%s'." % _targets[_index])
			_failed.append(_targets[_index])
			_index += 1
			_status.text = "%d / %d" % [_index, _targets.size()]
			if _index < _targets.size():
				ResourceLoader.load_threaded_request(_targets[_index])
			else:
				_finish()


func _finish() -> void:
	if _done:
		return
	_done = true
	set_process(false)
	_indeterminate.set_running(false)
	_bar.value = 1.0
	_percent.text = "100%"
	_status.text = "READY"
	if _hold:
		return
	var scene_path := str(payload.get("scene", ""))
	if not scene_path.is_empty():
		if not _failed.is_empty():
			push_error("MenuLoading: %d resource(s) failed; see earlier errors." % _failed.size())
		call_deferred("_change_scene", scene_path)
		return
	# An empty `next` means "wherever the journey goes after the art is in",
	# which is FrontEnd's decision, not this stage's.
	var next := StringName(str(payload.get("next", "")))
	if next == &"" and is_instance_valid(front_end) and front_end.has_method("stage_after_loading"):
		next = front_end.stage_after_loading()
	if next == &"":
		next = &"DASHBOARD"
	completed.emit(next, {})


func _change_scene(scene_path: String) -> void:
	var scene := load(scene_path) as PackedScene
	if scene == null:
		push_error("MenuLoading: '%s' is not a PackedScene." % scene_path)
		return
	var error := get_tree().change_scene_to_packed(scene)
	if error != OK:
		push_error("MenuLoading: change_scene failed (%d)." % error)


func _on_resized() -> void:
	relayout()
	_orient_nodes([_mark])
	_apply_poster()


## The two bands that darken the picture, in physical pixels off the frame's
## own size: the bottom scrim is `SCRIM_HEIGHT` of it and the top one is a
## notch's worth, so the wordmark band sits on near-black at any aspect.
func _apply_poster() -> void:
	var frame := physical_size()
	if is_instance_valid(_bottom_gap):
		physical_min_size(_bottom_gap, 0.0, maxf(frame.y * 0.05, 20.0))
	if is_instance_valid(_scrim_bottom):
		_scrim_bottom.anchor_left = 0.0
		_scrim_bottom.anchor_right = 1.0
		_scrim_bottom.anchor_top = 1.0
		_scrim_bottom.anchor_bottom = 1.0
		_scrim_bottom.offset_top = -frame.y * SCRIM_HEIGHT
		_scrim_bottom.offset_bottom = 0.0
	if is_instance_valid(_scrim_top):
		_scrim_top.anchor_left = 0.0
		_scrim_top.anchor_right = 1.0
		_scrim_top.anchor_top = 0.0
		_scrim_top.anchor_bottom = 0.0
		_scrim_top.offset_top = 0.0
		_scrim_top.offset_bottom = maxf(frame.y * 0.16, 64.0)
