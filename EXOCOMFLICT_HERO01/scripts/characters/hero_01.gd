extends Node3D
## HERO_01 wrapper: locates the imported Skeleton3D / AnimationPlayer and
## attaches the separate weapon scene to the Weapon_R bone.
## The weapon GLB origin equals the character origin with identity transform
## at rest (VERIFIED in Blender), so the attachment offset is solved from the
## Weapon_R bone rest transform: offset = inverse(bone_global_rest).
## Status: runtime-validated on Godot 4.7.2 (headless) 2026-10-29 - see
## VALIDATION_REPORT.md section 5 and tools/godot/ci_check.gd.

const WEAPON_SCENE = preload("res://scenes/weapons/HERO_01_WEAPON.tscn")
const AIM_ANIMATION := "Weapon_Raise_To_Aim"

## Set true and fill manual_weapon_offset to override automatic calibration
## (printed solved offset can be pasted here after the first successful run).
@export var use_manual_weapon_offset: bool = false
@export var manual_weapon_offset: Transform3D = Transform3D.IDENTITY
## Hero meshes are dense open-shell geometry: force LOD0 and a generous
## cull margin so fine detail never pops out while animating or in
## close-up cameras. (Materials are double-sided in the GLBs themselves;
## see tools/patch_glb_double_sided.py and VALIDATION_REPORT 5.6.)
@export var force_full_detail: bool = true

var skeleton: Skeleton3D
var animation_player: AnimationPlayer
var weapon_attachment: BoneAttachment3D
var weapon_instance: Node3D
var calibrated_weapon_offset: Transform3D = Transform3D.IDENTITY

func _ready() -> void:
	skeleton = _find_first(self, "Skeleton3D") as Skeleton3D
	animation_player = _find_first(self, "AnimationPlayer") as AnimationPlayer
	if skeleton == null:
		push_error("HERO_01: Skeleton3D not found in imported GLB scene.")
		return
	if animation_player == null:
		push_warning("HERO_01: AnimationPlayer not found in imported GLB scene.")
	_attach_weapon()
	if force_full_detail:
		_apply_full_detail(self)

func _find_first(node: Node, type_name: String) -> Node:
	for child in node.get_children():
		if child.is_class(type_name):
			return child
		var found := _find_first(child, type_name)
		if found != null:
			return found
	return null

func _apply_full_detail(node: Node) -> void:
	if node is GeometryInstance3D:
		var gi := node as GeometryInstance3D
		gi.lod_bias = 64.0
		gi.extra_cull_margin = 1.0
	for child in node.get_children():
		_apply_full_detail(child)

func _attach_weapon() -> void:
	var bone_idx := skeleton.find_bone("Weapon_R")
	if bone_idx < 0:
		push_error("HERO_01: bone 'Weapon_R' not found in Skeleton3D.")
		return
	weapon_attachment = BoneAttachment3D.new()
	weapon_attachment.name = "WeaponAttachment_R"
	skeleton.add_child(weapon_attachment)
	weapon_attachment.bone_name = "Weapon_R"
	weapon_instance = WEAPON_SCENE.instantiate() as Node3D
	weapon_attachment.add_child(weapon_instance)
	if use_manual_weapon_offset:
		weapon_instance.transform = manual_weapon_offset
	else:
		# The weapon GLB is authored at the skeleton's origin (identity at
		# rest), so the attachment-local offset is simply the inverse of the
		# bone's global rest transform in skeleton space. This is invariant
		# to character scale/placement. (Validated in Godot 4.7.2 headless:
		# tools/godot/ci_check.gd — do NOT anchor to the hero root global,
		# whose space differs by the ScaleRoot factor.)
		var bone_rest: Transform3D = skeleton.get_bone_global_rest(bone_idx)
		weapon_instance.transform = bone_rest.affine_inverse()
	calibrated_weapon_offset = weapon_instance.transform
	print("HERO_01: weapon local offset under Weapon_R = ", calibrated_weapon_offset)

func play_aim(from_start: bool = true) -> void:
	if animation_player == null:
		return
	var anim := _resolve_animation(AIM_ANIMATION)
	if anim == "":
		push_error("HERO_01: animation '%s' not found. Available: %s" % [AIM_ANIMATION, str(animation_player.get_animation_list())])
		return
	animation_player.play(anim)
	if from_start:
		animation_player.seek(0.0, true)

func _resolve_animation(anim_name: String) -> String:
	if animation_player == null:
		return ""
	for candidate in animation_player.get_animation_list():
		if String(candidate).ends_with(anim_name):
			return String(candidate)
	return ""

func set_weapon_visible(v: bool) -> void:
	if weapon_instance != null:
		weapon_instance.visible = v
