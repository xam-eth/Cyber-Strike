class_name AetherfallInteractionTarget
extends Node3D
## Shared Area3D/range contract for reusable environmental interactions.

signal interaction_completed(target_id: String, result: Dictionary)
signal interaction_state_changed

@export var interaction_id := ""
@export_multiline var interaction_label := "Interaksi"

var _actors_in_range: Dictionary = {}

@onready var interaction_range := get_node_or_null("InteractionRange") as Area3D

func _ready() -> void:
	add_to_group("aetherfall_interactable")
	if interaction_range == null:
		push_error("%s: InteractionRange wajib tersedia." % name)
		return
	interaction_range.body_entered.connect(_on_interaction_range_body_entered)
	interaction_range.body_exited.connect(_on_interaction_range_body_exited)

func _on_interaction_range_body_entered(body: Node3D) -> void:
	if not _is_interaction_actor(body):
		return
	_actors_in_range[body.get_instance_id()] = weakref(body)
	if body.has_method("set_interaction_target"):
		body.set_interaction_target(self)

func _on_interaction_range_body_exited(body: Node3D) -> void:
	_actors_in_range.erase(body.get_instance_id())
	if body.has_method("clear_interaction_target"):
		body.clear_interaction_target(self)

func _is_interaction_actor(body: Node3D) -> bool:
	return body != null and body.has_method("set_interaction_target") and body.has_method("show_interaction_feedback")

func is_actor_in_range(actor: Node3D) -> bool:
	if actor == null:
		return false
	var reference: WeakRef = _actors_in_range.get(actor.get_instance_id())
	return reference != null and reference.get_ref() == actor

func get_prompt() -> String:
	return "Tekan E — " + interaction_label

func validate_interaction(actor: Node3D) -> Dictionary:
	if actor == null:
		return {"ok": false, "code": "no_actor", "message": "Tidak ada aktor interaksi."}
	if not is_actor_in_range(actor):
		return {"ok": false, "code": "out_of_range", "message": "Dekati perangkat untuk berinteraksi."}
	return {"ok": true}

func attempt_interaction(actor: Node3D) -> Dictionary:
	var result := validate_interaction(actor)
	if not result.get("ok", false) and actor != null and actor.has_method("show_interaction_feedback"):
		actor.show_interaction_feedback(str(result.get("message", "Interaksi gagal.")))
	return result

func progression_state() -> AetherfallProgressionState:
	var matches := get_tree().get_nodes_in_group("aetherfall_progression")
	return matches[0] as AetherfallProgressionState if not matches.is_empty() else null
