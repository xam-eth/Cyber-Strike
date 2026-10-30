class_name AetherfallTechCache
extends AetherfallInteractionTarget
## Reusable cache: validates proximity, commits a durable reward once, then
## plays its authored Blender state animation. A failed persistence write rolls
## back the reward in AetherfallProgressionState.

@export var reward_amount := 1
var _opened := false

func _ready() -> void:
	super._ready()
	var state := progression_state()
	_opened = state != null and state.has_claimed_cache(interaction_id)
	if _opened:
		_set_open_visual(true)

func get_prompt() -> String:
	if _opened:
		return "Cache teknologi — sudah diklaim"
	return "Tekan E — Ambil credential akses Archive"

func attempt_interaction(actor: Node3D) -> Dictionary:
	var range_result := validate_interaction(actor)
	if not range_result.get("ok", false):
		actor.show_interaction_feedback(str(range_result.get("message", "Interaksi gagal.")))
		return range_result
	var state := progression_state()
	if state == null:
		var unavailable := {"ok": false, "code": "missing_progression", "message": "State progression lokal tidak tersedia."}
		actor.show_interaction_feedback(str(unavailable.get("message")))
		return unavailable
	var result := state.claim_tech_cache(interaction_id, reward_amount)
	if result.get("ok", false):
		_opened = true
		_set_open_visual(false)
		actor.show_interaction_feedback("+%d credential akses Archive tersimpan. Archive Computer dapat diautentikasi; ini bukan Data Core final." % reward_amount)
		interaction_completed.emit(interaction_id, result)
		interaction_state_changed.emit()
	else:
		actor.show_interaction_feedback(str(result.get("message", "Cache tidak dapat diklaim.")))
	return result

func _set_open_visual(immediate: bool) -> void:
	var players := find_children("*", "AnimationPlayer", true, false)
	if players.is_empty():
		push_error("TechCache: animasi GLB tidak ditemukan.")
		return
	var player := players[0] as AnimationPlayer
	var clip := &"TechCache_Open"
	if not player.has_animation(clip):
		var clips := player.get_animation_list()
		if clips.is_empty():
			push_error("TechCache: klip animasi GLB tidak ditemukan.")
			return
		clip = clips[0]
	player.play(clip)
	if immediate:
		var animation := player.get_animation(clip)
		player.seek(animation.length, true)
		player.pause()
