class_name AetherfallObjectiveDevice
extends AetherfallInteractionTarget
## Objective terminal that turns the committed cache data into a persisted
## objective activation. It does not fabricate a generic mission integration.

@export var required_tech_data := 1
var _active := false

func _ready() -> void:
	super._ready()
	var state := progression_state()
	_active = state != null and state.is_objective_active(interaction_id)
	if _active:
		_set_active_visual(true)

func get_prompt() -> String:
	if _active:
		return "Relai horizon — aktif"
	var state := progression_state()
	var held := state.tech_data if state != null else 0
	if held < required_tech_data:
		return "Relai horizon — butuh %d data teknologi" % required_tech_data
	return "Tekan E — Aktifkan relai horizon"

func attempt_interaction(actor: Node3D) -> Dictionary:
	var range_result := validate_interaction(actor)
	if not range_result.get("ok", false):
		actor.show_interaction_feedback(str(range_result.get("message", "Interaksi gagal.")))
		return range_result
	var state := progression_state()
	if state == null:
		var unavailable := {"ok": false, "code": "missing_progression", "message": "State objective lokal tidak tersedia."}
		actor.show_interaction_feedback(str(unavailable.get("message")))
		return unavailable
	var result := state.activate_objective(interaction_id, required_tech_data)
	if result.get("ok", false):
		_active = true
		_set_active_visual(false)
		actor.show_interaction_feedback("Relai horizon aktif. Objective slice selesai dan tersimpan.")
		interaction_completed.emit(interaction_id, result)
		interaction_state_changed.emit()
	else:
		actor.show_interaction_feedback(str(result.get("message", "Relai tidak dapat diaktifkan.")))
	return result

func _set_active_visual(immediate: bool) -> void:
	var players := find_children("*", "AnimationPlayer", true, false)
	if players.is_empty():
		push_error("ObjectiveDevice: animasi GLB tidak ditemukan.")
		return
	var player := players[0] as AnimationPlayer
	var clip := &"ObjectiveDevice_Activate"
	if not player.has_animation(clip):
		var clips := player.get_animation_list()
		if clips.is_empty():
			push_error("ObjectiveDevice: klip animasi GLB tidak ditemukan.")
			return
		clip = clips[0]
	player.play(clip)
	if immediate:
		var animation := player.get_animation(clip)
		player.seek(animation.length, true)
		player.pause()
