extends Node
class_name CinematicCamera
# Cinematic tour — discipline: camera-systems (smooth follow, frame-rate independent, look-ahead, bounds)
# No input required (tanpa controll): camera autonomously tours STELLAR HORIZON's critical path
# Level-design: derived from world metrics — cover every 5-6m, 180x180, tower hub + 6 islands + 4 bridges
# Viewpoints cover Key Areas foto: Central Tower / Upper Platform / Canyon Path / Interior Base

# Frame-rate independent smoothing: t = 1 - exp(-rate * dt)  — same feel at 30/60/144 FPS (camera-systems #2)
# Don't use lerp(a,b,0.1) per frame — that is FPS-dependent.

@export var tour_speed: float = 0.22          # progress per second (viewpoint interpolation)
@export var position_smooth_rate: float = 2.2 # for position (higher = snappier)
@export var look_smooth_rate: float = 2.6     # for look target
@export var fov_smooth_rate: float = 2.0

var _camera: Camera3D
var _viewpoints: Array = []
var _idx: int = 0
var _t: float = 0.0  # 0..1 within current segment
var _active_pos: Vector3
var _active_look: Vector3
var _enabled: bool = true

func setup(camera: Camera3D, viewpoints: Array) -> void:
	_camera = camera
	_viewpoints = viewpoints
	if _viewpoints.size() > 0:
		_active_pos = _viewpoints[0].pos
		_active_look = _viewpoints[0].look
		_camera.global_position = _active_pos
		_camera.look_at(_active_look, Vector3.UP)
		_camera.fov = _viewpoints[0].fov

func set_enabled(v: bool) -> void:
	_enabled = v

func _process(dt: float) -> void:
	if not _enabled or not _camera or _viewpoints.size() < 2:
		return
	var cur = _viewpoints[_idx]
	var nxt = _viewpoints[(_idx + 1) % _viewpoints.size()]
	# advance segment progress — duration per viewpoint controls pacing (level-design: tension/rest curve)
	var seg_duration: float = cur.get("duration", 6.0)
	_t += dt / seg_duration
	if _t >= 1.0:
		_t -= 1.0
		_idx = (_idx + 1) % _viewpoints.size()
		cur = _viewpoints[_idx]
		nxt = _viewpoints[(_idx + 1) % _viewpoints.size()]
	# ease: smoothstep for cinematic (not linear — linear feels robotic, game-feel)
	var eased := _smoothstep(clampf(_t, 0.0, 1.0))
	var target_pos: Vector3 = cur.pos.lerp(nxt.pos, eased)
	var target_look: Vector3 = cur.look.lerp(nxt.look, eased)
	var target_fov: float = lerpf(cur.fov, nxt.fov, eased)
	# exponential smoothing — dt correct, late update (camera follows after world settled)
	var tp := 1.0 - exp(-position_smooth_rate * dt)
	var tl := 1.0 - exp(-look_smooth_rate * dt)
	var tf := 1.0 - exp(-fov_smooth_rate * dt)
	_active_pos = _active_pos.lerp(target_pos, tp)
	_active_look = _active_look.lerp(target_look, tl)
	_camera.fov = lerpf(_camera.fov, target_fov, tf)
	_camera.global_position = _active_pos
	# look_at rebuilds basis each frame — clamp up to avoid roll flip (camera-systems pitch clamp)
	_camera.look_at(_active_look, Vector3.UP)

func _smoothstep(x: float) -> float:
	# 3x² - 2x³  — ease in/out, cheap cinematic
	return x * x * (3.0 - 2.0 * x)

func current_viewpoint_label() -> String:
	if _viewpoints.is_empty(): return ""
	return _viewpoints[_idx].get("label", "")
