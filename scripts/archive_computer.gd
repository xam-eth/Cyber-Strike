class_name AetherfallArchiveComputer
extends AetherfallInteractionTarget
## Compact final-tech interaction. The only durable reward here is the named
## Archive Data Core record; authorization and downloading are real intermediate
## states, not a visual-only completion message.

signal archive_state_changed(previous_state: StringName, next_state: StringName)

const LOCKED: StringName = &"locked"
const AUTHORIZED: StringName = &"authorized"
const DOWNLOADING: StringName = &"downloading"
const COLLECTED: StringName = &"collected"

@export var data_core_id := "aetherfall_sentinel_data_core"
@export var required_access_data := 1
@export var download_seconds := 1.20

var _state: StringName = LOCKED
var _download_generation := 0

func _ready() -> void:
	super._ready()
	sync_from_progression()

func sync_from_progression() -> void:
	## Public for deterministic isolated tests after their profile reset.
	var state := progression_state()
	if state != null and state.has_data_core(data_core_id):
		_set_state(COLLECTED, true)
	elif state != null and state.is_archive_computer_authorized(interaction_id):
		_set_state(AUTHORIZED, true)
	else:
		_set_state(LOCKED, true)

func current_state() -> StringName:
	return _state

func get_prompt() -> String:
	match _state:
		LOCKED:
			var state := progression_state()
			var held := state.tech_data if state != null else 0
			return "Archive Computer — butuh %d data akses" % required_access_data if held < required_access_data else "Tekan E — Otentikasi Archive Computer"
		AUTHORIZED:
			return "Tekan E — Unduh Archive Data Core"
		DOWNLOADING:
			return "Archive Computer — mengunduh Data Core"
		COLLECTED:
			return "Archive Data Core — tersimpan"
	return "Archive Computer"

func attempt_interaction(actor: Node3D) -> Dictionary:
	var range_result := validate_interaction(actor)
	if not range_result.get("ok", false):
		if actor != null and actor.has_method("show_interaction_feedback"):
			actor.show_interaction_feedback(str(range_result.get("message", "Interaksi gagal.")))
		return range_result
	var state := progression_state()
	if state == null:
		var unavailable := {"ok": false, "code": "missing_progression", "message": "State progression lokal tidak tersedia."}
		actor.show_interaction_feedback(str(unavailable.message))
		return unavailable
	if _state == COLLECTED:
		var already := {"ok": false, "code": "already_collected", "message": "Archive Data Core ini sudah tersimpan."}
		actor.show_interaction_feedback(str(already.message))
		return already
	if _state == DOWNLOADING:
		var busy := {"ok": false, "code": "download_in_progress", "message": "Pengunduhan Archive Data Core sedang berjalan."}
		actor.show_interaction_feedback(str(busy.message))
		return busy
	if _state == LOCKED:
		var authorization := state.authorize_archive_computer(interaction_id, required_access_data)
		if authorization.get("ok", false):
			_set_state(AUTHORIZED)
			actor.show_interaction_feedback("Archive Computer diautentikasi. Data Core siap diunduh.")
			interaction_state_changed.emit()
		else:
			actor.show_interaction_feedback(str(authorization.get("message", "Otentikasi Archive Computer gagal.")))
		return authorization
	# The authorized state starts an actual delayed transaction. The core record
	# is persisted only when the timer completes, and the state returns to
	# authorized on any persistence failure.
	_set_state(DOWNLOADING)
	_download_generation += 1
	var generation := _download_generation
	actor.show_interaction_feedback("Mengunduh Archive Data Core…")
	interaction_state_changed.emit()
	_finish_download_after_delay(weakref(actor), generation)
	return {"ok": true, "code": "downloading", "data_core_id": data_core_id}

func _finish_download_after_delay(actor_ref: WeakRef, generation: int) -> void:
	await get_tree().create_timer(maxf(0.05, download_seconds)).timeout
	if generation != _download_generation or _state != DOWNLOADING:
		return
	var state := progression_state()
	if state == null:
		_set_state(AUTHORIZED)
		_feedback(actor_ref, "Pengunduhan dibatalkan: state progression lokal tidak tersedia.")
		interaction_state_changed.emit()
		return
	var result := state.commit_archive_data_core(data_core_id, interaction_id)
	if result.get("ok", false):
		_set_state(COLLECTED)
		_feedback(actor_ref, "Archive Data Core tersimpan secara permanen.")
		interaction_completed.emit(interaction_id, result)
	else:
		_set_state(COLLECTED if result.get("code", "") == "already_collected" else AUTHORIZED)
		_feedback(actor_ref, str(result.get("message", "Pengunduhan Archive Data Core gagal.")))
	interaction_state_changed.emit()

func _feedback(actor_ref: WeakRef, message: String) -> void:
	var actor := actor_ref.get_ref() as Node3D
	if actor != null and actor.has_method("show_interaction_feedback"):
		actor.show_interaction_feedback(message)

func _set_state(next_state: StringName, immediate := false) -> void:
	var previous := _state
	_state = next_state
	if next_state == DOWNLOADING:
		_play_download(false)
	elif next_state == COLLECTED:
		_play_download(immediate)
	if previous != next_state:
		archive_state_changed.emit(previous, next_state)

func _play_download(immediate: bool) -> void:
	var players := find_children("*", "AnimationPlayer", true, false)
	if players.is_empty():
		push_error("ArchiveComputer: animasi GLB tidak ditemukan.")
		return
	var player := players[0] as AnimationPlayer
	var clip := &"ArchiveComputer_Download"
	if not player.has_animation(clip):
		push_error("ArchiveComputer: klip download authored tidak ditemukan.")
		return
	player.play(clip)
	if immediate:
		var animation := player.get_animation(clip)
		player.seek(animation.length, true)
		player.pause()
