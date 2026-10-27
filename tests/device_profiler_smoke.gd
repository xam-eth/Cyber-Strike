extends SceneTree

const DeviceProfilerScript = preload("res://scripts/integration/device_profiler.gd")

var _failures := 0
var _events: Array[Dictionary] = []


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var profiler := DeviceProfilerScript.new() as Node
	profiler.connect("metrics_emitted", _record)
	root.add_child(profiler)
	_expect(_events.size() == 1 and _events[0].get("event") == "profile_start", "startup metadata")
	_expect(
		String(_events[0].get("renderer", "")) == "mobile",
		"startup records the Android renderer contract",
	)
	profiler.call("set_context", "defense", 3, 8)
	for _frame in 300:
		profiler.call("_process", 1.0 / 60.0)
	var windows := _frame_windows()
	_expect(windows.size() == 1, "one five-second window is emitted and reset")
	if windows.size() == 1:
		var window := windows[0]
		_expect(int(window.get("frames", 0)) == 300, "all rendered frames are counted")
		_expect(is_equal_approx(float(window.get("fps", 0.0)), 60.0), "FPS follows frames/elapsed")
		_expect(
			is_equal_approx(float(window.get("frame_p50_ms", 0.0)), 16.667),
			"p50 is calculated from real frame deltas",
		)
		_expect(
			is_equal_approx(float(window.get("frame_p95_ms", 0.0)), 16.667),
			"p95 is calculated from real frame deltas",
		)
		_expect(
			(
				window.get("phase") == "defense"
				and int(window.get("wave", 0)) == 3
				and int(window.get("enemies", 0)) == 8
			),
			"phase, wave, and enemy context remain attached to the window",
		)
		_expect(int(window.get("over_33ms", -1)) == 0, "33 ms counter is evidence-based")
	_expect(
		int(profiler.get("_window_frames")) == 0, "emitted samples do not leak into the next window"
	)

	# Focus changes reset the timing window instead of charging suspension time
	# to the first visible frame after resume.
	profiler.notification(Node.NOTIFICATION_APPLICATION_FOCUS_OUT)
	profiler.notification(Node.NOTIFICATION_APPLICATION_FOCUS_IN)
	profiler.call("_process", 1.0 / 60.0)
	_expect(int(profiler.get("_window_frames")) == 1, "lifecycle starts a fresh timing window")
	# Android can send both focus and application notifications. Duplicate pairs
	# must not overwrite the restored gameplay phase with "background".
	profiler.notification(Node.NOTIFICATION_APPLICATION_FOCUS_OUT)
	profiler.notification(Node.NOTIFICATION_APPLICATION_PAUSED)
	profiler.notification(Node.NOTIFICATION_APPLICATION_RESUMED)
	profiler.notification(Node.NOTIFICATION_APPLICATION_FOCUS_IN)
	_expect(profiler.get("_phase") == "defense", "paired lifecycle notifications restore context")
	_expect(not profiler.get("_background"), "paired lifecycle notifications resume sampling")
	profiler.queue_free()
	await process_frame
	if _failures == 0:
		print("DEVICE PROFILER smoke test passed.")
		quit()
	else:
		quit(1)


func _record(payload: Dictionary) -> void:
	_events.append(payload)


func _frame_windows() -> Array[Dictionary]:
	var windows: Array[Dictionary] = []
	for event in _events:
		if event.get("event") == "frame_window":
			windows.append(event)
	return windows


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures += 1
		push_error("DEVICE PROFILER smoke test failed: " + message)
