extends Camera3D
## Free-fly review camera: WASD, Q/E, shift and right-mouse look.
var speed := 18.0
var looking := false
var review_mode := false
var help_label: Label

const VIEWS := {
	KEY_1: [Vector3(0, 19, 55), Vector3(0, 20, -26)],
	KEY_2: [Vector3(-30, 12, 28), Vector3(0, 5, -8)],
	KEY_3: [Vector3(55, 15, 22), Vector3(38, 4, 0)],
	KEY_4: [Vector3(0, 12, 50), Vector3(0, -3, 25)],
	KEY_5: [Vector3(0, 95, 100), Vector3(0, 0, -8)],
}

func _ready() -> void:
	var overlay := CanvasLayer.new()
	overlay.name = "ReviewHelp"
	add_child(overlay)
	help_label = Label.new()
	help_label.position = Vector2(16, 14)
	help_label.text = "REVIEW AETHERFALL  |  Klik kanan: lihat  •  WASD: terbang  •  Q/E: turun/naik  •  Shift: cepat  •  1–5: sudut review  •  F1: operator"
	help_label.add_theme_font_size_override("font_size", 15)
	help_label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.9))
	help_label.add_theme_constant_override("outline_size", 5)
	help_label.visible = false
	overlay.add_child(help_label)

func set_review_mode(enabled: bool) -> void:
	review_mode = enabled
	looking = false
	if help_label != null:
		help_label.visible = enabled
	if enabled:
		make_current()
	else:
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE

func _unhandled_input(event: InputEvent) -> void:
	if not review_mode:
		return
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_RIGHT:
		looking = event.pressed
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED if looking else Input.MOUSE_MODE_VISIBLE
	elif event is InputEventMouseMotion and looking:
		rotation.y -= event.relative.x * 0.002
		rotation.x = clampf(rotation.x - event.relative.y * 0.002, -1.55, 1.55)
	elif event is InputEventKey and event.pressed and not event.echo and VIEWS.has(event.keycode):
		position = VIEWS[event.keycode][0]
		look_at(VIEWS[event.keycode][1], Vector3.UP)
	elif event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE:
		looking = false
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE

func _process(delta: float) -> void:
	if not review_mode:
		return
	var direction := Vector3.ZERO
	if Input.is_key_pressed(KEY_W): direction -= transform.basis.z
	if Input.is_key_pressed(KEY_S): direction += transform.basis.z
	if Input.is_key_pressed(KEY_A): direction -= transform.basis.x
	if Input.is_key_pressed(KEY_D): direction += transform.basis.x
	if Input.is_key_pressed(KEY_E): direction += Vector3.UP
	if Input.is_key_pressed(KEY_Q): direction -= Vector3.UP
	var boost := 3.0 if Input.is_key_pressed(KEY_SHIFT) else 1.0
	position += direction.normalized() * speed * boost * delta
