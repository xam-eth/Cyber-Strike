extends Node3D
## Rig validation controller: playback, scrub, speed, camera presets,
## weapon toggle, skeleton dump and automated checks (UI built in code).
## Status: runtime-validated on Godot 4.7.2 (headless main-scene run, zero
## script errors) - see VALIDATION_REPORT.md section 5.4.

const AutoRigCheck = preload("res://scripts/validation/auto_rig_check.gd")

var hero: Node
var player: AnimationPlayer
var camera: Camera3D
var status_label: Label
var checks_label: Label
var scrub: HSlider
var scrubbing := false
var aim_anim := ""

var CAMERA_PRESETS := {
	"Front": [Vector3(0, 1.05, 3.4), Vector3(0, 0.95, 0)],
	"Side_R": [Vector3(-3.4, 1.05, 0), Vector3(0, 0.95, 0)],
	"Back": [Vector3(0, 1.05, -3.4), Vector3(0, 0.95, 0)],
	"ThreeQuarter": [Vector3(-2.3, 1.3, 2.3), Vector3(0, 0.9, 0)],
	"CloseHands": [Vector3(-0.7, 1.45, 1.15), Vector3(-0.05, 1.3, 0.25)],
	"CloseWeapon": [Vector3(-1.1, 1.4, 1.5), Vector3(-0.1, 1.3, 0.35)],
}

func _ready() -> void:
	hero = $HERO_01
	camera = $Camera3D
	await get_tree().process_frame
	player = hero.get("animation_player") as AnimationPlayer
	if player != null:
		for a in player.get_animation_list():
			if String(a).ends_with("Weapon_Raise_To_Aim"):
				aim_anim = String(a)
	_build_ui()
	_run_checks()
	if aim_anim != "":
		scrub.max_value = player.get_animation(aim_anim).length
		hero.play_aim(true)

func _process(_delta: float) -> void:
	if player != null and aim_anim != "":
		if not scrubbing:
			scrub.value = player.current_animation_position
		status_label.text = "Anim: %s  t=%.2fs / %.2fs  speed=%.2fx  %s" % [
			aim_anim, player.current_animation_position,
			player.get_animation(aim_anim).length, player.speed_scale,
			"PLAYING" if player.is_playing() else "PAUSED"]

func _run_checks() -> void:
	var lines: Array = AutoRigCheck.run_checks(hero)
	var text := "AUTO RIG CHECK\n"
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
	title.text = "HERO_01 - Rig Validation (Weapon_Raise_To_Aim)"
	root.add_child(title)
	status_label = Label.new()
	root.add_child(status_label)
	var row := HBoxContainer.new()
	root.add_child(row)
	_add_button(row, "Play", _on_play)
	_add_button(row, "Pause", _on_pause)
	_add_button(row, "Restart", _on_restart)
	_add_button(row, "Toggle weapon", _on_toggle_weapon)
	_add_button(row, "Dump skeleton", _dump_skeleton)
	_add_button(row, "Re-run checks", _run_checks)
	var speed_row := HBoxContainer.new()
	root.add_child(speed_row)
	var sl := Label.new()
	sl.text = "Speed:"
	speed_row.add_child(sl)
	for s in [0.25, 0.5, 1.0, 2.0]:
		var b := Button.new()
		b.text = "%sx" % s
		b.pressed.connect(_set_speed.bind(s))
		speed_row.add_child(b)
	scrub = HSlider.new()
	scrub.custom_minimum_size = Vector2(520, 0)
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
	checks_label = Label.new()
	root.add_child(checks_label)

func _add_button(parent: Control, text: String, fn: Callable) -> void:
	var b := Button.new()
	b.text = text
	b.pressed.connect(fn)
	parent.add_child(b)

func _on_play() -> void:
	if player != null and aim_anim != "":
		player.play(aim_anim)

func _on_pause() -> void:
	if player != null:
		player.pause()

func _on_restart() -> void:
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
	if scrubbing and player != null:
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
		print("[RigCheck]  bone %02d  %-12s parent=%d" % [i, skeleton.get_bone_name(i), skeleton.get_bone_parent(i)])
