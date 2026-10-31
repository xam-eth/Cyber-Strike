extends Camera3D
## Character-free QA camera for inspecting Aetherfall's composition and assets.
## Numeric presets frame individual landmarks; right-mouse free-fly remains for
## close inspection without introducing a player mesh into visual QA.

var speed := 18.0
var looking := false
var help_label: Label
var view_label: Label

const VIEWS := {
	KEY_1: {
		"position": Vector3(0, 24, 55),
		"target": Vector3(0, 7, -10),
		"label": "01 — overview / skyline",
	},
	KEY_2: {
		"position": Vector3(-47, 10, 24),
		"target": Vector3(-34, 3, 12),
		"label": "02 — primary outpost & arrival edge",
	},
	KEY_3: {
		"position": Vector3(-33, 7, 23),
		"target": Vector3(-24, 1, 10),
		"label": "03 — tech cache / central lane detail",
	},
	KEY_4: {
		"position": Vector3(28, 12, 15),
		"target": Vector3(12, 3, 1),
		"label": "04 — relay device & annex",
	},
	KEY_5: {
		"position": Vector3(45, 9, 3),
		"target": Vector3(30, 2, -10),
		"label": "05 — east service hangar",
	},
	KEY_6: {
		"position": Vector3(0, 61, 43),
		"target": Vector3(0, 5, -6),
		"label": "06 — top-down density / route read",
	},
	KEY_7: {
		"position": Vector3(29, 11, 5),
		"target": Vector3(8, 4, -14),
		"label": "07 — Sentinel Archive exterior",
	},
	KEY_8: {
		"position": Vector3(-2, 14, -1),
		"target": Vector3(0, 15, -26),
		"label": "08 — energy tower / glacial skyline",
	},
	KEY_9: {
		"position": Vector3(-28, 8, 17),
		"target": Vector3(-1, 3, -5),
		"label": "09 — Scrapper Basin cover / archive approach",
	},
	KEY_0: {
		"position": Vector3(11, 9, 31),
		"target": Vector3(3, -3, 25),
		"label": "10 — lower canyon salvage / high-low read",
	},
	KEY_I: {
		"position": Vector3(8, 3.2, -12.9),
		"target": Vector3(8, 1.8, -16.1),
		"label": "11 — Sentinel Archive interior / Data Core",
	},
	KEY_O: {
		"position": Vector3(0, 178, 178),
		"target": Vector3(0, -5, -4),
		"label": "12 — connected glacial expanse / full loop",
	},
}

func _ready() -> void:
	make_current()
	var overlay := CanvasLayer.new()
	overlay.name = "QAReviewOverlay"
	add_child(overlay)
	help_label = Label.new()
	help_label.position = Vector2(16, 14)
	help_label.text = "AETHERFALL QA CAMERA  |  Klik kanan: lihat  •  WASD: terbang  •  Q/E: turun/naik  •  Shift: cepat  •  1–0/I/O: framing detail"
	help_label.add_theme_font_size_override("font_size", 15)
	help_label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.9))
	help_label.add_theme_constant_override("outline_size", 5)
	overlay.add_child(help_label)
	view_label = Label.new()
	view_label.position = Vector2(16, 39)
	view_label.text = "01 — overview / skyline"
	view_label.add_theme_font_size_override("font_size", 14)
	view_label.add_theme_color_override("font_color", Color(0.48, 0.84, 1.0))
	view_label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.9))
	view_label.add_theme_constant_override("outline_size", 4)
	overlay.add_child(view_label)

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_RIGHT:
		looking = event.pressed
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED if looking else Input.MOUSE_MODE_VISIBLE
	elif event is InputEventMouseMotion and looking:
		rotation.y -= event.relative.x * 0.002
		rotation.x = clampf(rotation.x - event.relative.y * 0.002, -1.55, 1.55)
	elif event is InputEventKey and event.pressed and not event.echo and VIEWS.has(event.keycode):
		var view: Dictionary = VIEWS[event.keycode]
		position = view["position"]
		look_at(view["target"], Vector3.UP)
		view_label.text = str(view["label"])
	elif event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE:
		looking = false
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE

func _process(delta: float) -> void:
	var direction := Vector3.ZERO
	if Input.is_key_pressed(KEY_W): direction -= transform.basis.z
	if Input.is_key_pressed(KEY_S): direction += transform.basis.z
	if Input.is_key_pressed(KEY_A): direction -= transform.basis.x
	if Input.is_key_pressed(KEY_D): direction += transform.basis.x
	if Input.is_key_pressed(KEY_E): direction += Vector3.UP
	if Input.is_key_pressed(KEY_Q): direction -= Vector3.UP
	var boost := 3.0 if Input.is_key_pressed(KEY_SHIFT) else 1.0
	position += direction.normalized() * speed * boost * delta
