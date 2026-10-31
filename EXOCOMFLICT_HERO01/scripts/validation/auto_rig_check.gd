extends RefCounted
## Automated sanity checks for the NEW_HERO_01 rig (shared by the
## RigValidation scene and the headless CI scene). Returns PASS/FAIL/INFO
## lines. Skeleton expectations are skeleton-local global-rest values
## measured from the shipped NEW_HERO_01 GLB (Blender scripts 66/68).
## Animation clips for the new skeleton are not authored yet: while
## EXPECT_CLIPS is false, missing clips/tree are INFO, never FAIL.

const EXPECTED_BONES := 24
const EXPECT_CLIPS := false
const CLIP_DURATIONS := {
	"Idle": 3.0,
	"Weapon_Raise": 1.2,
	"Aim_Idle": 3.0,
	"Fire": 0.4,
	"Weapon_Lower": 0.8,
	"Weapon_Raise_To_Aim": 1.5,
}
const LOOP_CLIPS := ["Idle", "Aim_Idle"]
const RIG_BUILD := "NEW_HERO_01 re-rig (2026-10-31)"
# Skeleton-local global-rest measurements from the NEW_HERO_01 GLB.
const EXPECTED_HANDL_REST := Vector3(0.3550, 0.5720, 0.0620)
const EXPECTED_HANDR_REST := Vector3(-0.3550, 0.5720, 0.0620)
const EXPECTED_WEAPONR_REST := Vector3(-0.3770, 0.5420, 0.0670)
const EXPECTED_UPPERARM_LENGTH := 0.1894
const EXPECTED_FOREARM_LENGTH := 0.1375
const EXPECTED_UPPERLEG_LENGTH := 0.2201
const EXPECTED_LOWERLEG_LENGTH := 0.1865
const EXPECTED_HIPS_Y := 0.5050
const EXPECTED_HEAD_Y := 0.8550

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

static func _seg(lines: Array, skeleton: Skeleton3D, a: String, b: String, expected: float) -> float:
	var ia := skeleton.find_bone(a)
	var ib := skeleton.find_bone(b)
	if ia < 0 or ib < 0:
		_ok(lines, false, "Segment %s->%s bones resolved" % [a, b])
		return -1.0
	var d: float = skeleton.get_bone_global_rest(ia).origin.distance_to(skeleton.get_bone_global_rest(ib).origin)
	_ok(lines, absf(d - expected) <= 0.010, "Segment %s->%s length %.4f (~%.4f)" % [a, b, d, expected])
	return d

static func _check_new_skeleton(lines: Array, skeleton: Skeleton3D) -> void:
	var hand_l := skeleton.find_bone("Hand_L")
	var hand_r := skeleton.find_bone("Hand_R")
	var weapon_r := skeleton.find_bone("Weapon_R")
	var hips := skeleton.find_bone("Hips")
	var head := skeleton.find_bone("Head")
	var foot_l := skeleton.find_bone("Foot_L")
	var foot_r := skeleton.find_bone("Foot_R")
	if hand_l >= 0:
		var o: Vector3 = skeleton.get_bone_global_rest(hand_l).origin
		lines.append("INFO  Hand_L global-rest origin=%s" % str(o))
		_ok(lines, o.distance_to(EXPECTED_HANDL_REST) <= 0.020, "%s: Hand_L rest matches shipped GLB" % RIG_BUILD)
	if hand_r >= 0:
		var o: Vector3 = skeleton.get_bone_global_rest(hand_r).origin
		_ok(lines, o.distance_to(EXPECTED_HANDR_REST) <= 0.020, "%s: Hand_R rest matches shipped GLB" % RIG_BUILD)
	if weapon_r >= 0:
		var o: Vector3 = skeleton.get_bone_global_rest(weapon_r).origin
		_ok(lines, o.distance_to(EXPECTED_WEAPONR_REST) <= 0.020, "Weapon_R rest at right palm (dist %.4f)" % o.distance_to(EXPECTED_WEAPONR_REST))
	if hips >= 0:
		_ok(lines, absf(skeleton.get_bone_global_rest(hips).origin.y - EXPECTED_HIPS_Y) <= 0.010, "Hips rest height %.4f" % skeleton.get_bone_global_rest(hips).origin.y)
	if head >= 0:
		_ok(lines, absf(skeleton.get_bone_global_rest(head).origin.y - EXPECTED_HEAD_Y) <= 0.010, "Head rest height %.4f" % skeleton.get_bone_global_rest(head).origin.y)
	var ua_l := _seg(lines, skeleton, "UpperArm_L", "Forearm_L", EXPECTED_UPPERARM_LENGTH)
	var ua_r := _seg(lines, skeleton, "UpperArm_R", "Forearm_R", EXPECTED_UPPERARM_LENGTH)
	var fa_l := _seg(lines, skeleton, "Forearm_L", "Hand_L", EXPECTED_FOREARM_LENGTH)
	var fa_r := _seg(lines, skeleton, "Forearm_R", "Hand_R", EXPECTED_FOREARM_LENGTH)
	var ul_l := _seg(lines, skeleton, "UpperLeg_L", "LowerLeg_L", EXPECTED_UPPERLEG_LENGTH)
	var ul_r := _seg(lines, skeleton, "UpperLeg_R", "LowerLeg_R", EXPECTED_UPPERLEG_LENGTH)
	var ll_l := _seg(lines, skeleton, "LowerLeg_L", "Foot_L", EXPECTED_LOWERLEG_LENGTH)
	var ll_r := _seg(lines, skeleton, "LowerLeg_R", "Foot_R", EXPECTED_LOWERLEG_LENGTH)
	for pair in [[ua_l, ua_r, "upper arm"], [fa_l, fa_r, "forearm"], [ul_l, ul_r, "upper leg"], [ll_l, ll_r, "lower leg"]]:
		var l: float = pair[0]
		var r: float = pair[1]
		if l > 0.0 and r > 0.0:
			_ok(lines, absf(l / r - 1.0) <= 0.03, "L/R %s symmetry ratio %.3f" % [String(pair[2]), l / r])
	if foot_l >= 0 and foot_r >= 0:
		var dy: float = absf(skeleton.get_bone_global_rest(foot_l).origin.y - skeleton.get_bone_global_rest(foot_r).origin.y)
		_ok(lines, dy <= 0.005, "Feet rest heights equal (dy=%.4f)" % dy)

static func run_checks(hero: Node) -> Array:
	var lines: Array = []
	var skeleton = hero.get("skeleton") as Skeleton3D
	var player = hero.get("animation_player") as AnimationPlayer
	var weapon = hero.get("weapon_instance") as Node3D
	lines.append("INFO  Rig build: " + RIG_BUILD)
	_ok(lines, skeleton != null, "Skeleton3D located")
	if player == null:
		lines.append("INFO  AnimationPlayer absent (GLB has no animations yet - expected at this stage)" if not EXPECT_CLIPS else "FAIL  AnimationPlayer located")
	else:
		_ok(lines, true, "AnimationPlayer located")
	_ok(lines, weapon != null, "Weapon attached")
	if skeleton != null:
		_ok(lines, skeleton.get_bone_count() == EXPECTED_BONES, "Bone count == 24 (got %d)" % skeleton.get_bone_count())
		for b in ["Root", "Hips", "Spine", "Chest", "UpperChest", "Neck", "Head",
				"Clavicle_L", "UpperArm_L", "Forearm_L", "Hand_L",
				"Clavicle_R", "UpperArm_R", "Forearm_R", "Hand_R", "Weapon_R",
				"UpperLeg_L", "LowerLeg_L", "Foot_L", "Toe_L",
				"UpperLeg_R", "LowerLeg_R", "Foot_R", "Toe_R"]:
			_ok(lines, skeleton.find_bone(b) >= 0, "Bone %s exists" % b)
		_check_new_skeleton(lines, skeleton)
	if player != null:
		if EXPECT_CLIPS:
			var names: Array = []
			for clip_name in CLIP_DURATIONS.keys():
				names.append(String(clip_name))
			names.sort()
			for clip_name in names:
				_check_clip(lines, player, String(clip_name), float(CLIP_DURATIONS[clip_name]))
		else:
			for clip_name in CLIP_DURATIONS.keys():
				var rn := String(clip_name)
				if _resolve_clip(player, rn) != "":
					_check_clip(lines, player, rn, float(CLIP_DURATIONS[clip_name]))
				else:
					lines.append("INFO  Clip %s not authored yet (deferred)" % rn)
		lines.append("INFO  AnimationPlayer clips: " + str(player.get_animation_list()))
	var resolved_variant: Variant = hero.get("resolved_animations")
	if resolved_variant is Dictionary:
		var resolved: Dictionary = resolved_variant
		if EXPECT_CLIPS:
			_ok(lines, resolved.size() >= CLIP_DURATIONS.size(), "Hero resolved %d/%d named clips" % [resolved.size(), CLIP_DURATIONS.size()])
		else:
			lines.append("INFO  Hero resolved %d named clips (animation phase pending)" % resolved.size())
	var tree = hero.get("animation_tree") as AnimationTree
	if EXPECT_CLIPS:
		_ok(lines, tree != null, "Phase-1 AnimationTree built")
	else:
		lines.append("INFO  AnimationTree %s (built once clips exist)" % ("built" if tree != null else "not built yet"))
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
		if skeleton != null:
			var grip = weapon.find_child("GripPoint", true, false) as Node3D
			var wr := skeleton.find_bone("Weapon_R")
			if grip != null and wr >= 0:
				var bone_g: Vector3 = (skeleton.global_transform * skeleton.get_bone_global_pose(wr)).origin
				var d: float = bone_g.distance_to(grip.global_position)
				_ok(lines, d <= 0.020, "GripPoint seated on Weapon_R at rest (d=%.4f m)" % d)
	return lines
