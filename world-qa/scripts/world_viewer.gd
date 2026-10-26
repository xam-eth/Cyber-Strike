extends Node3D
# World viewer — STELLAR HORIZON one-world / many battles
# Godot 4.7.2 — world QA 100% same as game import (world-qa/assets/worlds/*.glb == game/assets/worlds/*.glb)
# Disciplines: level-design (metrics, blockout, critical path, pacing) + camera-systems (smooth follow, orbit, cinematic)
#
# HOW TO OPEN (Godot 4.7.2):
#  1) Install Godot 4.7.2 → Import → select world-qa/project.godot → Play (F5)
#  2) Click WORLD 1..4 buttons (top) — 100% same GLB as game akan di-import (no copy drift)
#  3) Cinematic tour starts automatically (tanpa controll) at ground level 2-12m — captures small details, not top-down arena
#  4) SPACE = cinematic/orbit, Right-drag = orbit, Scroll = zoom, N/P or 1-4 = switch world
# World metrics: 180x180 exploration adventure (bukan arena lapangan), canyon+islands+interior, cover 5-6m, tower 28m, bridges y+6, vertical 22m

@export_enum("frostline", "verdant", "emberfall", "titans") var world: String = "frostline"
@export var start_cinematic: bool = true

var _holder: Node3D
var _camera: Camera3D
var _sun: DirectionalLight3D
var _env: WorldEnvironment
var _cinematic: CinematicCamera
var _orbit: OrbitCamera
var _mode_cinematic: bool = true
var _current_world: Node3D

# Per-world lighting — fixes "semua putih cahaya putih sama" (each world has distinct Sun/fog, not white)
# Values from tools/asset-forge/src/worlds/themes.js (same data that builds GLB)
const MOOD := {
	"frostline": { "label": "WORLD 1 — Frostline Relay [POLAR DEFENCE] — DAYTIME", "sun": Color(1, 0.97, 0.88), "sun_energy": 1.65, "ambient": Color(0.55, 0.75, 1.0), "ambient_energy": 0.9, "fog": Color(0.61, 0.78, 0.91), "bg": Color(0.52, 0.77, 0.92) },
	"verdant":   { "label": "WORLD 2 — Verdant Bloom [BIO STATION] — SUNSET",  "sun": Color(1, 0.72, 0.42), "sun_energy": 1.45, "ambient": Color(1, 0.6, 0.35), "ambient_energy": 0.85, "fog": Color(0.62, 0.32, 0.25), "bg": Color(1, 0.55, 0.32) },
	"emberfall": { "label": "WORLD 3 — Emberfall Foundry [EXTRACTION] — NIGHT", "sun": Color(0.56, 0.72, 1.0), "sun_energy": 1.05, "ambient": Color(0.16, 0.22, 0.35), "ambient_energy": 0.65, "fog": Color(0.04, 0.08, 0.16), "bg": Color(0.02, 0.05, 0.11) },
	"titans":    { "label": "WORLD 4 — Titans Horizon [FLOATING ISLANDS] — STORM",    "sun": Color(0.75, 0.82, 0.91), "sun_energy": 1.20, "ambient": Color(0.35, 0.42, 0.48), "ambient_energy": 0.75, "fog": Color(0.10, 0.13, 0.18), "bg": Color(0.06, 0.09, 0.13) },
}

# Low ground-level tour — captures small details (bukan dari atas full 52,96). Adventure, not arena field.
func _build_tour() -> Array:
	return [
		{ "label": "01 — OVERVIEW mid (ground 12m, not 52m)", "pos": Vector3(0, 14, 36), "look": Vector3(0, 7, 0), "fov": 62.0, "duration": 6.5 },
		{ "label": "02 — CENTRAL TOWER base",                "pos": Vector3(10, 6, 14), "look": Vector3(0, 8, 0), "fov": 64.0, "duration": 6.0 },
		{ "label": "03 — PLATFORM edge (detail crates)",     "pos": Vector3(38, 11, 44), "look": Vector3(42, 6, 46), "fov": 66.0, "duration": 6.0 },
		{ "label": "04 — CANYON wall (cliff close)",         "pos": Vector3(-34, 6, -10), "look": Vector3(-42, 4, -22), "fov": 68.0, "duration": 6.0 },
		{ "label": "05 — INTERIOR base (inside, low)",       "pos": Vector3(4, 2.8, -30), "look": Vector3(2, 2.5, -40), "fov": 70.0, "duration": 6.5 },
		{ "label": "06 — BRIDGE low (under arch)",           "pos": Vector3(0, 8, 16), "look": Vector3(0, 6, 0), "fov": 62.0, "duration": 5.5 },
		{ "label": "07 — ISLAND moss (small rocks)",         "pos": Vector3(48, 10, 30), "look": Vector3(52, 5, 34), "fov": 66.0, "duration": 5.0 },
		{ "label": "08 — COVER cluster (5-6m detail)",       "pos": Vector3(-18, 4.5, 10), "look": Vector3(-22, 2, 12), "fov": 64.0, "duration": 5.0 },
	]

func _ready() -> void:
	_holder = $WorldHolder
	_camera = $Camera
	_sun = $Sun
	_env = $WorldEnvironment
	# clickable WORLD 1-4 buttons
	var b1 := $UI/WorldTabs/World1 as Button
	var b2 := $UI/WorldTabs/World2 as Button
	var b3 := $UI/WorldTabs/World3 as Button
	var b4 := $UI/WorldTabs/World4 as Button
	b1.pressed.connect(func(): load_world("frostline"))
	b2.pressed.connect(func(): load_world("verdant"))
	b3.pressed.connect(func(): load_world("emberfall"))
	b4.pressed.connect(func(): load_world("titans"))
	# setup cinematic rig (low, adventure)
	_cinematic = CinematicCamera.new()
	add_child(_cinematic)
	_cinematic.setup(_camera, _build_tour())
	# orbit rig
	_orbit = OrbitCamera.new()
	add_child(_orbit)
	_orbit.setup(_camera, Vector3.ZERO)
	_orbit.distance = 28.0
	_orbit.min_distance = 8.0
	_orbit.max_distance = 90.0
	_mode_cinematic = start_cinematic
	_cinematic.set_enabled(_mode_cinematic)
	_orbit.set_enabled(not _mode_cinematic)
	load_world(world)
	set_process(true)
	_update_ui()

func load_world(id: String) -> void:
	if _current_world:
		_current_world.queue_free()
		await get_tree().process_frame
	var path := "res://assets/worlds/%s.glb" % id
	var packed: PackedScene = load(path) as PackedScene
	if packed == null:
		push_error("World QA: failed to load %s — file must be same as game import (100%%)" % path)
		return
	_current_world = packed.instantiate() as Node3D
	_current_world.name = "StellarWorld"
	_holder.add_child(_current_world)
	world = id
	_apply_mood(id)
	print("World QA: loaded %s — 100%% same as game import" % id)
	_update_ui()

func _apply_mood(id: String) -> void:
	var m: Dictionary = MOOD.get(id, MOOD["frostline"])
	if _sun:
		_sun.light_color = m.sun
		_sun.light_energy = m.sun_energy
	if _env and _env.environment:
		var env: Environment = _env.environment
		env.background_color = m.bg
		env.ambient_light_color = m.ambient
		env.ambient_light_energy = m.ambient_energy
		env.fog_light_color = m.fog
		env.fog_enabled = true
	# highlight active button
	for i in range(4):
		var btn: Button = $UI/WorldTabs.get_child(i) as Button
		var key: String = ["frostline","verdant","emberfall","titans"][i]
		var is_active: bool = (key == id)
		btn.modulate = Color(1, 1, 1, 1) if is_active else Color(0.85, 0.85, 0.85, 1)
		btn.add_theme_color_override("font_color", Color(0.1, 0.4, 0.9, 1) if is_active else Color(0.9, 0.9, 0.9, 1))

func _process(_dt: float) -> void:
	_update_ui_label()

func _unhandled_input(event: InputEvent) -> void:
	if _orbit and _mode_cinematic == false:
		_orbit.handle_input(event)
	if event is InputEventKey and event.pressed and not event.echo:
		match event.keycode:
			KEY_SPACE:
				_mode_cinematic = not _mode_cinematic
				_cinematic.set_enabled(_mode_cinematic)
				_orbit.set_enabled(not _mode_cinematic)
				_update_ui()
			KEY_N:
				var o := ["frostline","verdant","emberfall","titans"]
				var i := o.find(world)
				load_world(o[(i+1)%o.size()])
			KEY_P:
				var o2 := ["frostline","verdant","emberfall","titans"]
				var i2 := o2.find(world)
				load_world(o2[(i2-1+o2.size())%o2.size()])
			KEY_R:
				_orbit.target = Vector3.ZERO
				_orbit.distance = 28.0
				_orbit.yaw = 0.78
				_orbit.pitch = 0.35
			KEY_1: load_world("frostline")
			KEY_2: load_world("verdant")
			KEY_3: load_world("emberfall")
			KEY_4: load_world("titans")
	if event is InputEventMouseButton and event.pressed:
		if _mode_cinematic == false:
			if event.button_index == MOUSE_BUTTON_WHEEL_UP:
				_orbit.distance = clampf(_orbit.distance - 3.0, _orbit.min_distance, _orbit.max_distance)
			elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
				_orbit.distance = clampf(_orbit.distance + 3.0, _orbit.min_distance, _orbit.max_distance)

func _update_ui() -> void:
	if has_node("UI/Info"):
		var lab := $UI/Info as Label
		var mode := "CINEMATIC — ground 2-12m (tanpa controll, adventure)" if _mode_cinematic else "ORBIT — Right-drag orbit | Scroll zoom | WASD/QE pan | SPACE toggle"
		var vp := ""
		if _mode_cinematic and _cinematic:
			vp = _cinematic.current_viewpoint_label()
		var mood: String = MOOD[world].label if MOOD.has(world) else world
		lab.text = "%s  •  %s\n%s\n[Click WORLD 1-4] or [1-4] — 100%% same as game import  |  [SPACE] toggle  [N/P] cycle  [R] recenter" % [mood, mode, vp]

func _update_ui_label() -> void:
	if _mode_cinematic and has_node("UI/Info"):
		_update_ui()
