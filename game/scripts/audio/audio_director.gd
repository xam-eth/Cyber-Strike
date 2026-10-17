class_name AudioDirector
extends Node

## Autoload (`Audio`) that owns every sound in the game. Gameplay code never
## touches this class directly: it calls the Sfx facade, which also works in
## headless `--script` runs where the autoload name is not a global identifier.
##
## Sounds are synthesised once at startup by ProceduralSfx and replayed through a
## small pool of players: positional for anything that happens in the world,
## non-positional for interface and player feedback. Gameplay code never creates
## an AudioStreamPlayer itself — it calls one of the play_* helpers, which makes
## "why is this silent?" a single place to look.
##
## The pool exists because a wave can fire dozens of shots a second: allocating a
## node per shot would leak node churn into the frame time, and letting finished
## players pile up would keep their voices alive forever.

const ProceduralSfxScript = preload("res://scripts/audio/procedural_sfx.gd")

const PREFERENCE_PATH := "user://audio.cfg"
const PREFERENCE_SECTION := "audio"
const PREFERENCE_KEY := "muted"

const POOL_3D_SIZE := 12
const POOL_UI_SIZE := 4

## Minimum gap between two plays of the same id. Without it, a volley that lands
## several projectiles in one frame stacks identical transients and clips.
const THROTTLE_MS := {
	&"impact": 45,
	&"chain_zap": 60,
	&"hit_confirm": 70,
	&"player_hurt": 120,
	&"enemy_down": 60,
}

var _streams: Dictionary = {}
var _pool_3d: Array[AudioStreamPlayer3D] = []
var _pool_ui: Array[AudioStreamPlayer] = []
var _next_3d: int = 0
var _next_ui: int = 0
var _muted: bool = false
var _played: int = 0
var _boot_ms: int = 0
var _last_played_ms: Dictionary = {}
var _ready_ms: int = 0


func _ready() -> void:
	var started := Time.get_ticks_msec()
	_ensure_streams()
	_build_pool(_pool_3d, POOL_3D_SIZE, false)
	_build_pool(_pool_ui, POOL_UI_SIZE, true)
	_ready_ms = Time.get_ticks_msec() - started
	_muted = _load_muted_preference()
	# One line at boot: the browser console and the editor log both show whether
	# audio came up, how long synthesis took and how many sounds exist.
	print("Audio: %d sounds synthesised in %d ms" % [_streams.size(), _ready_ms])


## Positional world sound (gunfire, impacts, enemy deaths).
func play_3d(sound_id: StringName, position: Vector3) -> void:
	if _muted:
		return
	_ensure_pools()
	if not _may_play(sound_id):
		return
	var stream := _stream(sound_id)
	if stream == null:
		return
	var player := _take_3d(_pool_3d, _next_3d)
	_next_3d = (_next_3d + 1) % maxi(_pool_3d.size(), 1)
	if player == null:
		return
	player.global_position = position
	player.volume_db = ProceduralSfxScript.volume_db_for(sound_id)
	player.stream = stream
	player.play()
	_note_played(sound_id)


## Interface and player feedback: not positioned, so it stays audible regardless
## of where the camera is looking.
func play_ui(sound_id: StringName) -> void:
	if _muted:
		return
	_ensure_pools()
	if not _may_play(sound_id):
		return
	var stream := _stream(sound_id)
	if stream == null:
		return
	var player := _take_ui(_pool_ui, _next_ui)
	_next_ui = (_next_ui + 1) % maxi(_pool_ui.size(), 1)
	if player == null:
		return
	player.volume_db = ProceduralSfxScript.volume_db_for(sound_id)
	player.stream = stream
	player.play()
	_note_played(sound_id)


## Fires the right weapon sound for a weapon definition id.
func play_shot(weapon_id: StringName, position: Vector3) -> void:
	play_3d(ProceduralSfxScript.weapon_sound_id(weapon_id), position)


func set_muted(value: bool) -> void:
	_muted = value
	if _muted:
		stop_all()
	_save_muted_preference(value)
	# Logged on purpose: a screenshot cannot show mute, and the browser QA gate
	# asserts on this line to prove the HUD button and the M key reach the audio.
	print("Audio: %s" % ("muted" if _muted else "unmuted"))


func is_muted() -> bool:
	return _muted


func toggle_muted() -> bool:
	set_muted(not _muted)
	return _muted


func stop_all() -> void:
	for player in _pool_3d:
		player.stop()
	for player in _pool_ui:
		player.stop()


func sound_count() -> int:
	return _streams.size()


func played_count() -> int:
	return _played


## Short human-readable state, printed once per session so the browser console
## proves the pipeline is alive in the exported build.
func describe() -> String:
	return (
		"Audio: %d sounds, %d played, ready in %d ms, muted=%s"
		% [_streams.size(), _played, _ready_ms, "yes" if _muted else "no"]
	)


## Pools are built with the streams, not only in _ready: an autoload can be
## asked for a sound before the tree has processed its first frame.
func _ensure_pools() -> void:
	if _pool_3d.is_empty():
		_build_pool(_pool_3d, POOL_3D_SIZE, false)
	if _pool_ui.is_empty():
		_build_pool(_pool_ui, POOL_UI_SIZE, true)


## The preference lives in user:// so a muted player stays muted across a reload
## (on the web build user:// is IndexedDB-backed, so it survives the tab too).
## Storage failures are not worth a crash: an unwritable path just means the
## preference is forgotten.
func _load_muted_preference() -> bool:
	var config := ConfigFile.new()
	if config.load(PREFERENCE_PATH) != OK:
		return false
	return bool(config.get_value(PREFERENCE_SECTION, PREFERENCE_KEY, false))


func _save_muted_preference(value: bool) -> void:
	var config := ConfigFile.new()
	config.load(PREFERENCE_PATH)
	config.set_value(PREFERENCE_SECTION, PREFERENCE_KEY, value)
	config.save(PREFERENCE_PATH)


func _stream(sound_id: StringName) -> AudioStreamWAV:
	_ensure_streams()
	return _streams.get(sound_id) as AudioStreamWAV


## Synthesis is deferred to the first request: an autoload can be asked for a
## sound before its _ready ran (headless --script tests do exactly that).
func _ensure_streams() -> void:
	if _streams.is_empty():
		_streams = ProceduralSfxScript.build_all()
		_boot_ms = Time.get_ticks_msec()


## Counts a voice and logs the first one: "audio works" must be visible in a
## log, not only audible, because the browser QA run has no ears.
func _note_played(sound_id: StringName) -> void:
	_played += 1
	if _played == 1:
		print(
			(
				"Audio: first voice played (%s) %d ms after synthesis"
				% [sound_id, Time.get_ticks_msec() - _boot_ms]
			)
		)


## True when the sound may play now; records the play otherwise.
func _may_play(sound_id: StringName) -> bool:
	var gap := float(THROTTLE_MS.get(sound_id, 0))
	if gap <= 0.0:
		return true
	var now := Time.get_ticks_msec()
	if now - int(_last_played_ms.get(sound_id, -100000)) < int(gap):
		return false
	_last_played_ms[sound_id] = now
	return true


func _build_pool(pool: Array, size: int, ui: bool) -> void:
	for _index in range(size):
		if ui:
			var ui_player := AudioStreamPlayer.new()
			ui_player.bus = &"Master"
			add_child(ui_player)
			pool.append(ui_player)
		else:
			var world_player := AudioStreamPlayer3D.new()
			world_player.bus = &"Master"
			world_player.max_distance = 36.0
			world_player.unit_size = 6.0
			add_child(world_player)
			pool.append(world_player)


## Round-robin, but a free voice wins over stealing one that is still playing.
## The two pools need their own accessors: AudioStreamPlayer3D does not inherit
## from AudioStreamPlayer in Godot 4, so one shared helper could never serve both.
func _take_3d(pool: Array[AudioStreamPlayer3D], start: int) -> AudioStreamPlayer3D:
	if pool.is_empty():
		return null
	var size := pool.size()
	for offset in range(size):
		var candidate := pool[(start + offset) % size]
		if not candidate.playing:
			return candidate
	return pool[start % size]


func _take_ui(pool: Array[AudioStreamPlayer], start: int) -> AudioStreamPlayer:
	if pool.is_empty():
		return null
	var size := pool.size()
	for offset in range(size):
		var candidate := pool[(start + offset) % size]
		if not candidate.playing:
			return candidate
	return pool[start % size]
