## Video asset smoke test.
##
## Assets C and F were the two things the art pipeline could not deliver: no
## video encoder existed in this environment. One does now (a static ffmpeg with
## libtheora, from a PyPI wheel), and Godot 4.7.2 ships `modules/theora`, whose
## `ResourceFormatLoaderTheora` claims `.ogv` on every platform it builds for.
##
## A file on disk proves nothing about an export -- a texture can sit in the
## repo and never be imported, and a video can sit there and never decode. So
## this test loads both videos through `ResourceLoader` the way the stages do
## and compares what the *engine* reports against
## `game/assets/ui/video_manifest.json`, then checks the two stages that consume
## them really did pick the video path over their composed fallbacks.
##
## What it cannot tell you is whether a frame is ever presented: the headless
## runner has neither a display nor an audio device. Playback is measured in a
## real browser build and recorded in docs/asset-inspections/, not asserted here.
extends SceneTree

const VIDEOS := {
	"loading_robot": "res://assets/ui/loading_robot.ogv",
	"cinematic_opening": "res://assets/ui/cinematic_opening.ogv",
}
const MANIFEST := "res://assets/ui/video_manifest.json"
const CinematicScene = preload("res://scenes/ui/menus/stage_cinematic.tscn")
const LoadingScene = preload("res://scenes/ui/menus/stage_loading.tscn")

var _failures: Array[String] = []
## How many videos were actually measured. A skipped assertion is a silent
## pass, and this file is worthless if one of them can slip through.
var _measured := 0


func _initialize() -> void:
	call_deferred("_run_smoke_test")


func _run_smoke_test() -> void:
	var manifest := _read_manifest()
	for key in VIDEOS:
		await _check_video(key, VIDEOS[key], manifest)
	await _check_stage("cinematic", CinematicScene, "_video")
	await _check_stage("loading", LoadingScene, "_robot_video")
	_expect(
		_measured == VIDEOS.size(),
		"both videos were measured (%d of %d)" % [_measured, VIDEOS.size()]
	)
	if _failures.is_empty():
		print("Video asset smoke test passed.")
		quit(0)
		return
	print("Video asset smoke test FAILED:")
	for failure in _failures:
		print("  fail: " + failure)
	quit(1)


func _read_manifest() -> Dictionary:
	var handle := FileAccess.open(MANIFEST, FileAccess.READ)
	if handle == null:
		_fail("the video manifest is missing at %s" % MANIFEST)
		return {}
	var parsed: Variant = JSON.parse_string(handle.get_as_text())
	handle.close()
	if typeof(parsed) != TYPE_DICTIONARY:
		_fail("the video manifest is not a JSON object")
		return {}
	var entries := {}
	for entry in (parsed as Dictionary).get("videos", []):
		entries[str((entry as Dictionary)["key"])] = entry
	return entries


func _check_video(key: String, path: String, manifest: Dictionary) -> void:
	var stream := ResourceLoader.load(path, "VideoStream") as VideoStream
	if not _expect(stream != null, "%s: %s loads as a VideoStream" % [key, path]):
		return
	if ClassDB.class_exists("VideoStreamTheora"):
		_expect(stream is VideoStreamTheora, "%s: the engine reports it as VideoStreamTheora" % key)
	var entry: Dictionary = manifest.get(key, {})
	if entry.is_empty():
		_fail("%s: no manifest entry to compare against" % key)
		return
	# Size and length live on the playback, not the stream: `VideoStream` is
	# only a factory until something instantiates a decoder for it.
	var player := VideoStreamPlayer.new()
	player.stream = stream
	root.add_child(player)
	player.play()
	var texture: Texture2D = null
	for _frame in range(240):
		await process_frame
		texture = player.get_video_texture()
		if texture != null:
			break
	if not _expect(texture != null, "%s: a frame decodes into a texture" % key):
		player.free()
		return
	var wanted_size := Vector2(
		float((entry["size"] as Array)[0]), float((entry["size"] as Array)[1])
	)
	var measured_size := texture.get_size()
	_expect(
		measured_size == wanted_size,
		(
			"%s: the engine measures %dx%d, the manifest says %dx%d"
			% [
				key,
				int(measured_size.x),
				int(measured_size.y),
				int(wanted_size.x),
				int(wanted_size.y)
			]
		)
	)
	var measured_length := player.get_stream_length()
	var wanted_length := float(entry["duration_s"])
	_expect(
		absf(measured_length - wanted_length) < 0.15,
		(
			"%s: the engine measures %.2f s, the manifest says %.2f s"
			% [key, measured_length, wanted_length]
		)
	)
	# Headless frames carry a tiny delta, so advancing is measured in frames
	# rather than seconds: give the decoder room and then require it to have
	# moved.
	var advanced := 0.0
	for _frame in range(240):
		await process_frame
		advanced = player.get_stream_position()
		if advanced > 0.05:
			break
	_expect(
		advanced > 0.05,
		"%s: playback advances (%.2f s of %.2f s decoded)" % [key, advanced, measured_length]
	)
	_measured += 1
	player.stop()
	player.free()


## A stage that wants a video keeps its composed fallback, so the test has to
## prove it picked the video -- not merely that the file loads.
func _check_stage(name: String, scene: PackedScene, player_var: String) -> void:
	var stage: Control = scene.instantiate()
	root.add_child(stage)
	await process_frame
	await process_frame
	var player: VideoStreamPlayer = stage.get(player_var) as VideoStreamPlayer
	if not _expect(
		player != null and player.stream != null,
		"%s: the stage loaded the video into its %s player" % [name, player_var]
	):
		stage.free()
		return
	_expect(
		stage.call("try_video", "res://assets/ui/definitely_not_here.ogv") == null,
		"%s: a missing video loads as null instead of crashing the stage" % name
	)
	stage.free()


func _expect(condition: bool, message: String) -> bool:
	if condition:
		print("  ok: " + message)
		return true
	_fail(message)
	return false


func _fail(message: String) -> void:
	print("  fail: " + message)
	_failures.append(message)
