extends Node3D
## HERO_01 wrapper: locates the imported Skeleton3D / AnimationPlayer and
## attaches the separate weapon scene to the Weapon_R bone.
## The weapon GLB origin equals the character origin with identity transform
## at rest (VERIFIED in Blender), so the attachment offset is solved from the
## Weapon_R bone rest transform: offset = inverse(bone_global_rest).
## Status: authored for Godot 4.7.2, runtime UNVERIFIED in the authoring
## environment (no Godot binary available) - see VALIDATION_REPORT.md.

const WEAPON_SCENE = preload("res://scenes/weapons/HERO_01_WEAPON.tscn")
const AIM_ANIMATION := "Weapon_Raise_To_Aim"

## Set true and fill manual_weapon_offset to override automatic calibration
## (printed solved offset can be pasted here after the first successful run).
@export var use_manual_weapon_offset: bool = false
@export var manual_weapon_offset: Transform3D = Transform3D.IDENTITY

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

func _find_first(node: Node, type_name: String) -> Node:
	for child in node.get_children():
		if child.is_class(type_name):
			return child
		var found := _find_first(child, type_name)
		if found != null:
			return found
	return null

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
		var bone_rest: Transform3D = skeleton.get_bone_global_rest(bone_idx)
		var attach_global: Transform3D = skeleton.global_transform * bone_rest
		weapon_instance.transform = attach_global.affine_inverse() * global_transform
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
