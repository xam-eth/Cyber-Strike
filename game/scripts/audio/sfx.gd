class_name Sfx
extends RefCounted

## Static facade in front of the `Audio` autoload.
##
## Why this exists: an autoload's name only resolves as a global identifier when
## the engine boots a real game session. Headless `--script` runs — which is how
## every smoke test in this repository runs — do not register it, so a bare
## `Audio.play_*` call fails to compile and takes the whole script (and with it
## the scene that uses it) down. These wrappers look the node up at runtime
## instead, and do nothing when the singleton is absent, so a test that never
## installs audio stays quiet rather than crashing.

const AUTOLOAD_NAME := "Audio"


static func play_3d(sound_id: StringName, position: Vector3) -> void:
	var director := _director()
	if director != null:
		director.play_3d(sound_id, position)


static func play_ui(sound_id: StringName) -> void:
	var director := _director()
	if director != null:
		director.play_ui(sound_id)


static func play_shot(weapon_id: StringName, position: Vector3) -> void:
	var director := _director()
	if director != null:
		director.play_shot(weapon_id, position)


static func stop_all() -> void:
	var director := _director()
	if director != null:
		director.stop_all()


static func set_muted(value: bool) -> void:
	var director := _director()
	if director != null:
		director.set_muted(value)


static func toggle_muted() -> bool:
	var director := _director()
	return director.toggle_muted() if director != null else false


static func is_muted() -> bool:
	var director := _director()
	return director.is_muted() if director != null else false


static func sound_count() -> int:
	var director := _director()
	return director.sound_count() if director != null else 0


static func played_count() -> int:
	var director := _director()
	return director.played_count() if director != null else 0


## Human-readable state for logs; still answers when audio never came up.
static func describe() -> String:
	var director := _director()
	if director == null:
		return "Audio: unavailable (no %s autoload)" % AUTOLOAD_NAME
	return director.describe()


static func is_available() -> bool:
	return _director() != null


static func _director() -> AudioDirector:
	var loop := Engine.get_main_loop() as SceneTree
	if loop == null:
		return null
	return loop.root.get_node_or_null(AUTOLOAD_NAME) as AudioDirector
