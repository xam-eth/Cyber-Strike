extends Node3D
# World viewer — STELLAR HORIZON one-world / many battles
# Disciplines applied:
#  - level-design: metrics → geometry sizing, critical path (canyon → tower → platform → interior), pacing curve (rest/tension), blockout→dress via real GLB kit
#  - camera-systems: frame-rate independent smoothing (1-exp(-rate*dt)), orbit with clamped pitch + screen_relative, cinematic tour with look-ahead, late update
#  - create-game-assets: real GLB components (asli) not procedural, provenance via realModels
#
# HOW TO OPEN:
#  1) Install Godot 4.6.2 (https://godotengine.org/download) — or use bundled headless: tools/.cache/godot --path world-qa
#  2) Open Godot → Import → select world-qa/project.godot → Open
#  3) Press Play (F5) — cinematic tour starts automatically (tanpa controll). No input needed.
#  4) Optional: SPACE = toggle Cinematic / Orbit, N/P = next/prev world, 1-4 = jump world, R = recenter, Scroll = zoom (orbit), Right-drag = orbit
# World metrics (from level-design): 180x180, cover every 5-6m (8 covers), tower hub 28m beam, 6 islands y+6-11, 4 bridges y+6, 2 interior bases, 4 canyon walls

@export_enum("frostline", "verdant", "emberfall", "titans") var world: String = "frostline"
@export var start_cinematic: bool = true

var _holder: Node3D
var _camera: Camera3D
var _cinematic: CinematicCamera
var _orbit: OrbitCamera
var _mode_cinematic: bool = true
var _current_world: Node3D

# Level pacing: each viewpoint is a beat — intensity 0..1, duration controls rest/tension curve (level-design #2)
func _build_tour() -> Array:
	# STELLAR HORIZON viewpoints — same geometry, different moods via theme lighting
	# Positions tuned for 180x180 world, center (0,2,0), tower at (0,22,0), islands up to y 11
	return [
		{ "label": "01 — OVERVIEW (Main View foto)", "pos": Vector3(0, 52, 96), "look": Vector3(0, 10, 0), "fov": 54.0, "duration": 7.0 },
		{ "label": "02 — CENTRAL TOWER",            "pos": Vector3(18, 34, 32), "look": Vector3(0, 22, 0), "fov": 58.0, "duration": 6.0 },
		{ "label": "03 — UPPER PLATFORM",           "pos": Vector3(46, 20, 58), "look": Vector3(38, 12, 44), "fov": 62.0, "duration": 6.0 },
		{ "label": "04 — CANYON PATH",              "pos": Vector3(-58, 16, -8), "look": Vector3(-38, 7, -22), "fov": 66.0, "duration": 6.5 },
		{ "label": "05 — INTERIOR BASE",            "pos": Vector3(30, 5.5, -38), "look": Vector3(32, 2.5, -46), "fov": 70.0, "duration": 6.0 },
		{ "label": "06 — BRIDGE MID",               "pos": Vector3(2, 17, 56), "look": Vector3(0, 11, 0), "fov": 60.0, "duration": 5.5 },
		{ "label": "07 — ISLAND WATERFALL",         "pos": Vector3(66, 22, 32), "look": Vector3(50, 13, 36), "fov": 60.0, "duration": 5.0 },
		{ "label": "08 — TOWER RIM (dusk)",         "pos": Vector3(-22, 28, 48), "look": Vector3(0, 18, 0), "fov": 56.0, "duration": 5.0 },
	]

func _ready() -> void:
	_holder = $WorldHolder
	_camera = $Camera
	# setup cinematic rig
	_cinematic = CinematicCamera.new()
	add_child(_cinematic)
	_cinematic.setup(_camera, _build_tour())
	# setup orbit rig (starts disabled, shares same camera)
	_orbit = OrbitCamera.new()
	add_child(_orbit)
	_orbit.setup(_camera, Vector3.ZERO)
	_mode_cinematic = start_cinematic
	_cinematic.set_enabled(_mode_cinematic)
	_orbit.set_enabled(not _mode_cinematic)
	if _mode_cinematic:
		_camera.current = true
	# load world
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
		push_error("World QA: failed to load %s" % path)
		return
	_current_world = packed.instantiate() as Node3D
	_current_world.name = "StellarWorld"
	_holder.add_child(_current_world)
	world = id
	print("World QA: loaded %s" % id)
	_update_ui()

func _process(_dt: float) -> void:
	# late update already via _cinematic/_orbit _process (camera-systems #7)
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
				_orbit.distance = 78.0
				_orbit.yaw = 0.78
				_orbit.pitch = 0.42
			KEY_1: load_world("frostline")
			KEY_2: load_world("verdant")
			KEY_3: load_world("emberfall")
			KEY_4: load_world("titans")
	if event is InputEventMouseButton and event.pressed:
		if _mode_cinematic == false:
			if event.button_index == MOUSE_BUTTON_WHEEL_UP:
				_orbit.distance = clampf(_orbit.distance - 4.0, _orbit.min_distance, _orbit.max_distance)
			elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
				_orbit.distance = clampf(_orbit.distance + 4.0, _orbit.min_distance, _orbit.max_distance)

# UI — minimal, no gameplay
func _update_ui() -> void:
	if has_node("UI/Info"):
		var lab := $UI/Info as Label
		var mode := "CINEMATIC — tanpa controll (auto tour)" if _mode_cinematic else "ORBIT — Right-drag orbit | Scroll zoom | WASD/QE pan | SPACE toggle"
		var vp := ""
		if _mode_cinematic and _cinematic:
			vp = _cinematic.current_viewpoint_label()
		lab.text = "STELLAR HORIZON  •  %s  •  %s\n%s\n[SPACE] toggle  [N/P] world  [1-4] jump  [R] recenter" % [world.to_upper(), mode, vp]

func _update_ui_label() -> void:
	# refresh viewpoint label every frame during cinematic
	if _mode_cinematic and has_node("UI/Info"):
		_update_ui()
