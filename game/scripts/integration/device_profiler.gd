extends Node

signal metrics_emitted(payload: Dictionary)

## Low-overhead Android profiling transport. Main supplies only presentation
## context; this node never changes gameplay, quality, timing, or persistence.
## JSON lines are read from logcat by tools/android_perf_report.py.
const MARKER := "EXOCOMPLICT_METRICS "
const WINDOW_SECONDS := 5.0

var _phase := "boot"
var _wave := 0
var _enemies := 0
var _frame_times: Array[float] = []
var _window_frames := 0
var _window_elapsed := 0.0
var _started := false
var _background := false
var _phase_before_background := "explore"


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_PAUSABLE
	var refresh := 0.0
	var screen := Vector2i.ZERO
	var gpu := ""
	var gpu_api := ""
	if DisplayServer.get_name() != "headless":
		refresh = DisplayServer.screen_get_refresh_rate()
		screen = DisplayServer.screen_get_size()
		gpu = RenderingServer.get_video_adapter_name()
		gpu_api = RenderingServer.get_video_adapter_api_version()
	_emit(
		{
			"schema": 1,
			"event": "profile_start",
			"unix_time": Time.get_unix_time_from_system(),
			"godot": String(Engine.get_version_info().get("string", "unknown")),
			"debug_build": OS.is_debug_build(),
			"profiling_feature": OS.has_feature("device_profile"),
			"model": OS.get_model_name(),
			"processor": OS.get_processor_name(),
			"gpu": gpu,
			"gpu_api": gpu_api,
			"os": OS.get_name(),
			"os_version": OS.get_version(),
			"screen": [screen.x, screen.y],
			"refresh_hz": maxf(refresh, 0.0),
			"scale_3d": float(ProjectSettings.get_setting("rendering/scaling_3d/scale", 1.0)),
			"max_fps": Engine.max_fps,
			"vsync_mode": int(ProjectSettings.get_setting("display/window/vsync/vsync_mode", 1)),
			"render_stats_sampling": "end_of_window",
			"renderer":
			String(
				ProjectSettings.get_setting("rendering/renderer/rendering_method.mobile", "mobile")
			),
		}
	)
	_started = true


func set_context(phase: String, wave: int, enemies: int) -> void:
	if _background:
		return
	_phase = phase
	_wave = maxi(wave, 0)
	_enemies = maxi(enemies, 0)


func _process(delta: float) -> void:
	if not _started or _background:
		return
	_frame_times.append(delta * 1000.0)
	_window_frames += 1
	_window_elapsed += delta
	if _window_elapsed >= WINDOW_SECONDS:
		_emit_window()


func _notification(what: int) -> void:
	if not _started:
		return
	if what in [NOTIFICATION_APPLICATION_FOCUS_OUT, NOTIFICATION_APPLICATION_PAUSED]:
		if _background:
			return
		_emit_window()
		_phase_before_background = _phase
		_background = true
		_phase = "background"
		_reset_window()
	elif what in [NOTIFICATION_APPLICATION_FOCUS_IN, NOTIFICATION_APPLICATION_RESUMED]:
		if not _background:
			return
		_background = false
		_phase = _phase_before_background
		# Do not attribute time spent suspended to the first visible frame.
		_reset_window()


func _exit_tree() -> void:
	_emit_window()


func _reset_window() -> void:
	_frame_times.clear()
	_window_frames = 0
	_window_elapsed = 0.0


func _emit_window() -> void:
	if _window_frames <= 0 or _window_elapsed <= 0.0:
		_reset_window()
		return
	var sorted: Array[float] = _frame_times.duplicate()
	sorted.sort()
	var over_33 := 0
	var over_50 := 0
	for frame_ms in _frame_times:
		if frame_ms > 33.334:
			over_33 += 1
		if frame_ms > 50.0:
			over_50 += 1
	_emit(
		{
			"schema": 1,
			"event": "frame_window",
			"uptime_ms": Time.get_ticks_msec(),
			"phase": _phase,
			"wave": _wave,
			"enemies": _enemies,
			"elapsed_s": snappedf(_window_elapsed, 0.001),
			"frames": _window_frames,
			"fps": snappedf(_window_frames / _window_elapsed, 0.01),
			"frame_p50_ms": _percentile(sorted, 0.50),
			"frame_p95_ms": _percentile(sorted, 0.95),
			"frame_p99_ms": _percentile(sorted, 0.99),
			"frame_max_ms": snappedf(sorted[-1], 0.001),
			"over_33ms": over_33,
			"over_50ms": over_50,
			"process_ms":
			snappedf(Performance.get_monitor(Performance.TIME_PROCESS) * 1000.0, 0.001),
			"physics_ms":
			snappedf(Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS) * 1000.0, 0.001),
			"draw_calls":
			int(Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)),
			"primitives":
			int(Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME)),
			"objects": int(Performance.get_monitor(Performance.RENDER_TOTAL_OBJECTS_IN_FRAME)),
			"static_mb":
			snappedf(Performance.get_monitor(Performance.MEMORY_STATIC) / 1048576.0, 0.01),
			"video_mb":
			snappedf(Performance.get_monitor(Performance.RENDER_VIDEO_MEM_USED) / 1048576.0, 0.01),
			"texture_mb":
			snappedf(
				Performance.get_monitor(Performance.RENDER_TEXTURE_MEM_USED) / 1048576.0, 0.01
			),
		}
	)
	_reset_window()


func _percentile(sorted_frames: Array[float], percentile: float) -> float:
	var index := clampi(ceili(sorted_frames.size() * percentile) - 1, 0, sorted_frames.size() - 1)
	return snappedf(sorted_frames[index], 0.001)


func _emit(payload: Dictionary) -> void:
	metrics_emitted.emit(payload)
	print(MARKER + JSON.stringify(payload))
