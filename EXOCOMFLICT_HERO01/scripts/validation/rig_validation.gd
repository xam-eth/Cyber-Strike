extends Node3D
## Rig validation controller: Phase-1 AnimationTree chain controls, legacy
## clip playback/scrub, speed, camera presets, weapon toggle, skeleton dump
## and automated checks (UI built in code).
## Status: legacy controller runtime-validated on Godot 4.7.2 headless in
## VALIDATION_REPORT 5.4; Phase-1 controls await the owner's desktop
## Godot re-import pass in 5.10.

const AutoRigCheck = preload("res://scripts/validation/auto_rig_check.gd")

var hero: Node
var player: AnimationPlayer
var camera: Camera3D
var status_label: Label
var checks_label: Label
var scrub: HSlider
var scrubbing := false
var legacy_anim := ""
var pivot_markers: Array[Node3D] = []

var CAMERA_PRESETS := {
	"Front": [Vector3(0, 1.05, 3.4), Vector3(0, 0.95, 0)],
	"Side_R": [Vector3(-3.4, 1.05, 0), Vector3(0, 0.95, 0)],
	"Back": [Vector3(0, 1.05, -3.4), Vector3(0, 0.95, 0)],
	"ThreeQuarter": [Vector3(-2.3, 1.3, 2.3), Vector3(0, 0.9, 0)],
	"CloseHands": [Vector3(-0.7, 1.45, 1.15), Vector3(-0.05, 1.3, 0.25)],
	"CloseWeapon": [Vector3(-1.1, 1.4, 1.5), Vector3(-0.1, 1.3, 0.35)],
	"CloseWristL": [Vector3(0.62, 1.02, 0.92), Vector3(0.43, 0.89, 0.03)],
}

func _ready() -> void:
	hero = $HERO_01
	camera = $Camera3D
	await get_tree().process_frame
	player = hero.get("animation_player") as AnimationPlayer
	legacy_anim = _resolve_anim("Weapon_Raise_To_Aim")
	_build_ui()
	_run_checks()
	_build_pivot_markers()
	if _tree_enabled():
		scrub.max_value = float(hero.call("get_current_animation_length"))
	elif legacy_anim != "" and player != null:
		scrub.max_value = player.get_animation(legacy_anim).length
		hero.play_aim(true)

func _process(_delta: float) -> void:
	if status_label == null:
		return
	if _tree_enabled():
		var state := String(hero.call("get_current_animation_state"))
		var pos := float(hero.call("get_current_animation_position"))
		var length := float(hero.call("get_current_animation_length"))
		if scrub != null:
			scrub.max_value = maxf(length, 0.001)
			if not scrubbing:
				scrub.value = pos
		status_label.text = "AnimationTree state: %s  t=%.2fs / %.2fs  (Idle -> Raise -> Aim -> Fire -> Lower)" % [state, pos, length]
	elif player != null and legacy_anim != "":
		if scrub != null and not scrubbing:
			scrub.value = player.current_animation_position
		status_label.text = "Legacy anim: %s  t=%.2fs / %.2fs  speed=%.2fx  %s" % [
			legacy_anim, player.current_animation_position,
			player.get_animation(legacy_anim).length, player.speed_scale,
			"PLAYING" if player.is_playing() else "PAUSED"]

func _resolve_anim(anim_name: String) -> String:
	if player == null:
		return ""
	for candidate in player.get_animation_list():
		var s := String(candidate)
		var parts := s.split("/")
		var base := String(parts[parts.size() - 1]) if parts.size() > 0 else s
		if s == anim_name or base == anim_name:
			return s
	return ""

func _tree_enabled() -> bool:
	return hero != null and hero.has_method("is_animation_tree_enabled") and bool(hero.call("is_animation_tree_enabled"))

func _run_checks() -> void:
	var lines: Array = AutoRigCheck.run_checks(hero)
	var text := "AUTO RIG CHECK — Hand_L rerig v2\nINFO  Pivot markers: white=elbow, green=NEW Hand_L wrist, red=OLD Hand_L point carried by Forearm_L\n"
	for l in lines:
		text += String(l) + "\n"
		print("[RigCheck] ", l)
	checks_label.text = text

func _build_ui() -> void:
	var layer := $UI as CanvasLayer
	var root := VBoxContainer.new()
	root.position = Vector2(12, 10)
	layer.add_child(root)
	var title := Label.new()
	title.text = "HERO_01 - Rig Validation (Phase-1 + Hand_L rerig v2)"
	root.add_child(title)
	status_label = Label.new()
	root.add_child(status_label)

	var chain_row := HBoxContainer.new()
	root.add_child(chain_row)
	var chain_label := Label.new()
	chain_label.text = "Phase-1 chain:"
	chain_row.add_child(chain_label)
	for state_name in ["Idle", "Weapon_Raise", "Aim_Idle", "Fire", "Weapon_Lower"]:
		var b := Button.new()
		b.text = state_name
		b.pressed.connect(_on_state_pressed.bind(state_name))
		chain_row.add_child(b)
	_add_button(chain_row, "Tree on/off", _on_toggle_tree)

	var row := HBoxContainer.new()
	root.add_child(row)
	_add_button(row, "Play legacy aim", _on_play)
	_add_button(row, "Pause", _on_pause)
	_add_button(row, "Restart", _on_restart)
	_add_button(row, "Toggle weapon", _on_toggle_weapon)
	_add_button(row, "Dump skeleton", _dump_skeleton)
	_add_button(row, "Toggle wrist markers", _toggle_pivot_markers)
	_add_button(row, "Re-run checks", _run_checks)

	var speed_row := HBoxContainer.new()
	root.add_child(speed_row)
	var sl := Label.new()
	sl.text = "Legacy speed:"
	speed_row.add_child(sl)
	for s in [0.25, 0.5, 1.0, 2.0]:
		var b := Button.new()
		b.text = "%sx" % s
		b.pressed.connect(_set_speed.bind(s))
		speed_row.add_child(b)

	scrub = HSlider.new()
	scrub.custom_minimum_size = Vector2(640, 0)
	scrub.min_value = 0.0
	scrub.step = 0.001
	scrub.drag_started.connect(_on_scrub_started)
	scrub.drag_ended.connect(_on_scrub_ended)
	scrub.value_changed.connect(_on_scrub_changed)
	root.add_child(scrub)

	var cam_row := HBoxContainer.new()
	root.add_child(cam_row)
	var cl := Label.new()
	cl.text = "Camera:"
	cam_row.add_child(cl)
	for preset_name in CAMERA_PRESETS.keys():
		var b := Button.new()
		b.text = preset_name
		b.pressed.connect(_apply_camera.bind(preset_name))
		cam_row.add_child(b)

	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(980, 330)
	root.add_child(scroll)
	checks_label = Label.new()
	scroll.add_child(checks_label)

func _add_button(parent: Control, text: String, fn: Callable) -> void:
	var b := Button.new()
	b.text = text
	b.pressed.connect(fn)
	parent.add_child(b)

func _on_state_pressed(state_name: String) -> void:
	if hero == null:
		return
	if not _tree_enabled():
		hero.call("set_animation_tree_enabled", true)
	if state_name == "Fire":
		hero.call("fire_weapon")
	else:
		hero.call("travel_animation_state", state_name)

func _on_toggle_tree() -> void:
	if hero != null and hero.has_method("set_animation_tree_enabled"):
		hero.call("set_animation_tree_enabled", not _tree_enabled())

func _on_play() -> void:
	if _tree_enabled():
		hero.call("set_animation_tree_enabled", false)
	if player != null and legacy_anim != "":
		player.play(legacy_anim)

func _on_pause() -> void:
	if _tree_enabled():
		hero.call("set_animation_tree_enabled", false)
	elif player != null:
		player.pause()

func _on_restart() -> void:
	if _tree_enabled():
		hero.call("raise_weapon")
	else:
		hero.play_aim(true)

func _on_toggle_weapon() -> void:
	var w: Node3D = hero.get("weapon_instance") as Node3D
	if w != null:
		hero.set_weapon_visible(not w.visible)

func _set_speed(s: float) -> void:
	if player != null:
		player.speed_scale = s

func _on_scrub_started() -> void:
	scrubbing = true

func _on_scrub_ended(_changed: bool) -> void:
	scrubbing = false

func _on_scrub_changed(v: float) -> void:
	# Scrubbing is a direct-AnimationPlayer inspection tool; in tree mode the
	# slider is a read-only position indicator.
	if scrubbing and player != null and not _tree_enabled():
		player.seek(v, true)

func _apply_camera(preset_name: String) -> void:
	var p: Array = CAMERA_PRESETS[preset_name]
	camera.position = p[0]
	camera.look_at(p[1], Vector3.UP)

func _make_pivot_marker(parent: Node, marker_name: String, local_pos: Vector3, color: Color, radius: float) -> MeshInstance3D:
	var sphere := SphereMesh.new()
	sphere.radius = radius
	sphere.height = radius * 2.0
	sphere.radial_segments = 20
	sphere.rings = 10
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.no_depth_test = true
	sphere.material = mat
	var instance := MeshInstance3D.new()
	instance.name = marker_name
	instance.mesh = sphere
	instance.position = local_pos
	parent.add_child(instance)
	return instance

func _build_pivot_markers() -> void:
	if not pivot_markers.is_empty() or hero == null:
		return
	var skeleton: Skeleton3D = hero.get("skeleton") as Skeleton3D
	if skeleton == null:
		return
	var fore_idx := skeleton.find_bone("Forearm_L")
	var hand_idx := skeleton.find_bone("Hand_L")
	if fore_idx < 0 or hand_idx < 0:
		return
	var fore_attachment := BoneAttachment3D.new()
	fore_attachment.name = "PivotMarker_Forearm_L"
	skeleton.add_child(fore_attachment)
	fore_attachment.bone_name = "Forearm_L"
	var hand_attachment := BoneAttachment3D.new()
	hand_attachment.name = "PivotMarker_Hand_L"
	skeleton.add_child(hand_attachment)
	hand_attachment.bone_name = "Hand_L"
	_make_pivot_marker(fore_attachment, "ElbowMarker", Vector3.ZERO, Color.WHITE, 0.012)
	_make_pivot_marker(hand_attachment, "NewWristMarker", Vector3.ZERO, Color(0.1, 1.0, 0.35), 0.014)
	# Old thigh-space wrist point, expressed in Forearm_L's rest frame so
	# it follows the forearm deformation for a direct old/new comparison.
	var fore_rest: Transform3D = skeleton.get_bone_global_rest(fore_idx)
	var old_local: Vector3 = fore_rest.affine_inverse() * Vector3(0.190, 0.410, 0.015)
	_make_pivot_marker(fore_attachment, "OldWristMarker", old_local, Color(1.0, 0.12, 0.08), 0.014)
	pivot_markers.append(fore_attachment)
	pivot_markers.append(hand_attachment)
	print("[RigCheck] Hand_L pivot markers built: white=elbow green=NEW wrist red=OLD wrist")

func _toggle_pivot_markers() -> void:
	_build_pivot_markers()
	for marker in pivot_markers:
		marker.visible = not marker.visible

func _dump_skeleton() -> void:
	var skeleton: Skeleton3D = hero.get("skeleton") as Skeleton3D
	if skeleton == null:
		print("[RigCheck] No skeleton to dump.")
		return
	print("[RigCheck] Skeleton3D bone count: ", skeleton.get_bone_count())
	for i in skeleton.get_bone_count():
		var rest_origin: Vector3 = skeleton.get_bone_global_rest(i).origin
		print("[RigCheck]  bone %02d  %-12s parent=%d  global_rest=(%.4f, %.4f, %.4f)" % [
			i, skeleton.get_bone_name(i), skeleton.get_bone_parent(i),
			rest_origin.x, rest_origin.y, rest_origin.z])
