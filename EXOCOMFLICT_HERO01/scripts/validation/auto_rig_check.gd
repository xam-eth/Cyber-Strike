extends RefCounted
## Automated sanity checks for the HERO_01 rig (shared by the RigValidation
## scene and the headless CI scene). Returns PASS/FAIL/INFO lines; see
## VALIDATION_REPORT.md sections 5.3-5.4 and 5.10.

const EXPECTED_BONES := 24
const CLIP_DURATIONS := {
	"Idle": 3.0,
	"Weapon_Raise": 1.2,
	"Aim_Idle": 3.0,
	"Fire": 0.4,
	"Weapon_Lower": 0.8,
	"Weapon_Raise_To_Aim": 1.5,
}
const LOOP_CLIPS := ["Idle", "Aim_Idle"]

static func _ok(lines: Array, cond: bool, label: String) -> void:
	lines.append(("PASS  " if cond else "FAIL  ") + label)

static func _base_name(full_name: String) -> String:
	var parts := full_name.split("/")
	return String(parts[parts.size() - 1]) if parts.size() > 0 else full_name

static func _resolve_clip(player: AnimationPlayer, clip_name: String) -> String:
	if player == null:
		return ""
	# Exact basename first: searching by suffix alone would confuse
	# "Idle" with "Aim_Idle".
	for candidate in player.get_animation_list():
		var s := String(candidate)
		if s == clip_name or _base_name(s) == clip_name:
			return s
	for candidate in player.get_animation_list():
		var s := String(candidate)
		if s.ends_with("/" + clip_name):
			return s
	return ""

static func _check_clip(lines: Array, player: AnimationPlayer, clip_name: String, expected_length: float) -> void:
	var resolved := _resolve_clip(player, clip_name)
	_ok(lines, resolved != "", "%s exists in AnimationPlayer" % clip_name)
	if resolved == "":
		return
	var anim := player.get_animation(resolved)
	_ok(lines, anim != null, "%s resource loads" % clip_name)
	if anim == null:
		return
	_ok(lines, absf(anim.length - expected_length) <= 0.05,
		"%s duration %.2f s (expected ~%.2f s)" % [clip_name, anim.length, expected_length])
	var expected_loop := Animation.LOOP_NONE
	var loop_label := "no loop"
	if clip_name in LOOP_CLIPS:
		expected_loop = Animation.LOOP_LINEAR
		loop_label = "linear loop"
	_ok(lines, anim.loop_mode == expected_loop, "%s loop mode = %s" % [clip_name, loop_label])

static func run_checks(hero: Node) -> Array:
	var lines: Array = []
	var skeleton = hero.get("skeleton") as Skeleton3D
	var player = hero.get("animation_player") as AnimationPlayer
	var weapon = hero.get("weapon_instance") as Node3D
	_ok(lines, skeleton != null, "Skeleton3D located")
	_ok(lines, player != null, "AnimationPlayer located")
	_ok(lines, weapon != null, "Weapon attached")
	if skeleton != null:
		_ok(lines, skeleton.get_bone_count() == EXPECTED_BONES, "Bone count == 24 (got %d)" % skeleton.get_bone_count())
		for b in ["Root", "Hips", "Head", "Hand_R", "Hand_L", "Weapon_R"]:
			_ok(lines, skeleton.find_bone(b) >= 0, "Bone %s exists" % b)
	if player != null:
		var names: Array = []
		for clip_name in CLIP_DURATIONS.keys():
			names.append(String(clip_name))
		names.sort()
		for clip_name in names:
			_check_clip(lines, player, String(clip_name), float(CLIP_DURATIONS[clip_name]))
		lines.append("INFO  AnimationPlayer clips: " + str(player.get_animation_list()))
	var resolved_variant: Variant = hero.get("resolved_animations")
	if resolved_variant is Dictionary:
		var resolved: Dictionary = resolved_variant
		_ok(lines, resolved.size() >= CLIP_DURATIONS.size(), "Hero resolved %d/%d named clips" % [resolved.size(), CLIP_DURATIONS.size()])
	var tree = hero.get("animation_tree") as AnimationTree
	_ok(lines, tree != null, "Phase-1 AnimationTree built")
	if hero.has_method("is_animation_tree_enabled") and hero.has_method("get_current_animation_state"):
		lines.append("INFO  AnimationTree enabled=%s state=%s" % [
			str(bool(hero.call("is_animation_tree_enabled"))),
			String(hero.call("get_current_animation_state")),
		])
	if weapon != null:
		_ok(lines, weapon.get_parent() is BoneAttachment3D, "Weapon parent is BoneAttachment3D")
		var attachment = weapon.get_parent() as BoneAttachment3D
		if attachment != null:
			_ok(lines, attachment.bone_name == "Weapon_R", "Attachment bone == Weapon_R")
		for marker_name in ["GripPoint", "ForegripPoint", "MuzzlePoint", "ReceiverPoint"]:
			_ok(lines, weapon.find_child(marker_name, true, false) != null, "Marker %s present" % marker_name)
	return lines
