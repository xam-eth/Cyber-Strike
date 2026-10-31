class_name Hero01Hitboxes
extends Node3D
## Inactive per-bone hitbox scaffold for the future Dynamic Injury system
## (Hybrid Rig specification, attachment layer). Builds one
## BoneAttachment3D + Area3D + CapsuleShape3D per major body segment on
## the hero's Skeleton3D. EVERYTHING IS DISABLED by construction
## (Area3D.monitoring/monitorable = false, CollisionShape3D.disabled =
## true): this is a sizing/naming scaffold only, it must not interact
## with physics or gameplay until the injury system is implemented and
## explicitly enables specific shapes.
##
## Mirrors the Blender-side scaffold markers (script 82, objects HB_*
## with hb_part/hb_radius_m metadata). Capsule radii are approximate
## segment volumes in skeleton units (the hero root applies the usual
## x1.8 scale on top); tune per-part when the injury system lands.

const SEGMENTS: Dictionary = {
	"Head": {"part": "head", "radius": 0.075},
	"Neck": {"part": "neck", "radius": 0.055},
	"UpperChest": {"part": "chest", "radius": 0.115},
	"Chest": {"part": "chest", "radius": 0.115},
	"Spine": {"part": "abdomen", "radius": 0.105},
	"Hips": {"part": "pelvis", "radius": 0.110},
	"UpperArm_L": {"part": "arm", "radius": 0.055},
	"Forearm_L": {"part": "arm", "radius": 0.050},
	"Hand_L": {"part": "hand", "radius": 0.045},
	"UpperArm_R": {"part": "arm", "radius": 0.055},
	"Forearm_R": {"part": "arm", "radius": 0.050},
	"Hand_R": {"part": "hand", "radius": 0.045},
	"UpperLeg_L": {"part": "leg", "radius": 0.075},
	"LowerLeg_L": {"part": "leg", "radius": 0.060},
	"Foot_L": {"part": "foot", "radius": 0.050},
	"UpperLeg_R": {"part": "leg", "radius": 0.075},
	"LowerLeg_R": {"part": "leg", "radius": 0.060},
	"Foot_R": {"part": "foot", "radius": 0.050},
}
## Fallback segment length (skeleton units) for end bones without a
## child joint to measure against (Head, Foot*, Hand* use bone tail).
const FALLBACK_LENGTH := 0.08

var built: bool = false

func build(skeleton: Skeleton3D) -> int:
	if built or skeleton == null:
		return 0
	var count := 0
	for bone_name in SEGMENTS.keys():
		var bone := skeleton.find_bone(bone_name)
		if bone < 0:
			push_warning("Hero01Hitboxes: bone '%s' not found, skipped." % bone_name)
			continue
		var cfg: Dictionary = SEGMENTS[bone_name]
		var rest: Transform3D = skeleton.get_bone_global_rest(bone)
		var a: Vector3 = rest.origin
		var b := _segment_end(skeleton, bone, rest)
		var length: float = maxf(a.distance_to(b), 0.02)
		var radius: float = float(cfg.get("radius", 0.06))

		var attach := BoneAttachment3D.new()
		attach.name = "HB_" + bone_name
		skeleton.add_child(attach)
		attach.bone_name = bone_name

		var area := Area3D.new()
		area.name = "Hitbox"
		area.monitoring = false
		area.monitorable = false
		area.set_meta("hb_part", String(cfg.get("part", "")))
		area.set_meta("hb_bone", bone_name)
		area.set_meta("hb_active", false)
		attach.add_child(area)

		var shape_node := CollisionShape3D.new()
		shape_node.name = "Shape"
		var capsule := CapsuleShape3D.new()
		capsule.radius = radius
		capsule.height = maxf(length + radius * 2.0, radius * 2.0 + 0.001)
		shape_node.shape = capsule
		shape_node.disabled = true
		# Place the capsule centre on the segment midpoint, Y axis along
		# the segment, in bone-local space.
		var mid: Vector3 = (a + b) * 0.5
		var local_mid: Vector3 = rest.affine_inverse() * mid
		var dir_local: Vector3 = (rest.basis.inverse() * (b - a)).normalized()
		var q := Quaternion(Vector3.UP, dir_local) if dir_local.length() > 0.001 else Quaternion.IDENTITY
		shape_node.transform = Transform3D(Basis(q), local_mid)
		area.add_child(shape_node)
		count += 1
	built = true
	return count

func _segment_end(skeleton: Skeleton3D, bone: int, rest: Transform3D) -> Vector3:
	var children := skeleton.get_bone_children(bone)
	if children.size() > 0:
		return skeleton.get_bone_global_rest(children[0]).origin
	# End bone: extend along the bone's rest -Y (glTF bone direction is
	# not guaranteed; use the direction from parent to this bone).
	var parent := skeleton.get_bone_parent(bone)
	if parent >= 0:
		var pa: Vector3 = skeleton.get_bone_global_rest(parent).origin
		var dir: Vector3 = (rest.origin - pa).normalized()
		if dir.length() > 0.001:
			return rest.origin + dir * FALLBACK_LENGTH
	return rest.origin + Vector3.DOWN * FALLBACK_LENGTH
