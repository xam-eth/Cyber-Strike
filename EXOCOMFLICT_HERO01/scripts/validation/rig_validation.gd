extends Node3D
## Rig validation controller for NEW_HERO_01: camera presets, weapon
## toggle, skeleton dump and automated checks (UI built in code). The
## Phase-1 chain controls remain wired to hero_01.gd's API and activate
## once clips for the new skeleton are authored; until then the scene
## validates the rig at rest (deformation proof lives in the Blender
## battery, screenshots/rig/audit67_*).

const AutoRigCheck = preload("res://scripts/validation/auto_rig_check.gd")

var hero: Node
var player: AnimationPlayer
var camera: Camera3D
var status_label: Label
var checks_label: Label
var scrub: HSlider
var scrubbing := false
var legacy_anim := ""

var CAMERA_PRESETS := {
	"Front": [Vector3(0, 1.05, 3.4), Vector3(0, 0.95, 0)],
	"Side_R": [Vector3(-3.4, 1.05, 0), Vector3(0, 0.95, 0)],
	"Back": [Vector3(0, 1.05, -3.4), Vector3(0, 0.95, 0)],
	"ThreeQuarter": [Vector3(-2.3, 1.3, 2.3), Vector3(0, 0.9, 0)],
	# NEW_HERO_01 A-pose: hands rest at world (+-0.64, 1.03, 0.11).
	"CloseHands": [Vector3(-1.15, 1.15, 0.75), Vector3(-0.60, 1.02, 0.10)],
	"CloseWeapon": [Vector3(-1.35, 1.25, 1.05), Vector3(-0.58, 1.00, 0.10)],
	"CloseShoulderR": [Vector3(-0.85, 1.55, 0.85), Vector3(-0.22, 1.38, 0.0)],
}

func _ready() -> void:
	hero = $HERO_01
	camera = $Camera3D
	await get_tree().process_frame
	player = hero.get("animation_player") as AnimationPlayer
	legacy_anim = _resolve_anim("Weapon_Raise_To_Aim")
	_build_ui()
	_run_checks()
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
	else:
		status_label.text = "NEW_HERO_01 rig at rest - animation clips not authored yet. Inspect with camera presets; deformation battery lives in Blender (audit67)."

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
	var text := "AUTO RIG CHECK - NEW_HERO_01 re-rig (2026-10-31)\n"
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
	title.text = "HERO_01 - Rig Validation (NEW_HERO_01 re-rig)"
	root.add_child(title)
	status_label = Label.new()
	root.add_child(status_label)

	var chain_row := HBoxContainer.new()
	root.add_child(chain_row)
	var chain_label := Label.new()
	chain_label.text = "Phase-1 chain (clips pending):"
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
	if hero.has_method("has_animation") and not bool(hero.call("has_animation", state_name)):
		print("[RigCheck] Clip '%s' not authored for NEW_HERO_01 yet (animation phase pending)." % state_name)
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
	elif legacy_anim != "":
		hero.play_aim(true)
	else:
		print("[RigCheck] No clips to restart yet (animation phase pending).")

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
