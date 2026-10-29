extends RefCounted
## Automated HERO_01 rig checks. Returns human-readable PASS/FAIL lines.
## Run inside Godot (validation scene calls this on _ready).

const REQUIRED_BONES := [
	"Root", "Hips", "Spine", "Chest", "UpperChest", "Neck", "Head",
	"Clavicle_R", "UpperArm_R", "Forearm_R", "Hand_R", "Weapon_R",
	"Clavicle_L", "UpperArm_L", "Forearm_L", "Hand_L",
	"UpperLeg_R", "LowerLeg_R", "Foot_R", "Toe_R",
	"UpperLeg_L", "LowerLeg_L", "Foot_L", "Toe_L",
]
const AIM_ANIMATION := "Weapon_Raise_To_Aim"

static func run_checks(hero: Node) -> Array:
	var results: Array = []
	var skeleton: Skeleton3D = hero.get("skeleton") as Skeleton3D
	var player: AnimationPlayer = hero.get("animation_player") as AnimationPlayer
	results.append(_line(skeleton != null, "Skeleton3D found"))
	if skeleton != null:
		results.append(_line(skeleton.get_bone_count() == 24, "Bone count == 24 (got %d)" % skeleton.get_bone_count()))
		var missing: Array = []
		for b in REQUIRED_BONES:
			if skeleton.find_bone(b) < 0:
				missing.append(b)
		results.append(_line(missing.is_empty(), "All required bones present" + ("" if missing.is_empty() else " - MISSING: %s" % str(missing))))
	results.append(_line(player != null, "AnimationPlayer found"))
	if player != null:
		var found := ""
		for a in player.get_animation_list():
			if String(a).ends_with(AIM_ANIMATION):
				found = a
		results.append(_line(found != "", "Animation '%s' present" % AIM_ANIMATION))
		if found != "":
			var anim := player.get_animation(found)
			results.append(_line(anim != null and absf(anim.length - 1.5) < 0.05, "Animation length ~1.5s (got %.3f)" % (anim.length if anim else -1.0)))
	var attachment = hero.get("weapon_attachment")
	results.append(_line(attachment != null, "BoneAttachment3D created for Weapon_R"))
	var weapon = hero.get("weapon_instance")
	results.append(_line(weapon != null, "Weapon scene instanced under attachment"))
	return results

static func _line(ok: bool, text: String) -> String:
	return ("PASS  " if ok else "FAIL  ") + text
