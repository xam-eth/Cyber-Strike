extends SceneTree

## Guards the procedural audio pipeline: the Audio autoload must expose a full
## set of playable 16-bit streams, playback must respect mute and the per-sound
## throttle, and the gameplay wiring must actually reach the singleton (a sound
## API that nothing calls is the failure this test exists to catch).

const MainScene = preload("res://scenes/main.tscn")
const ProceduralSfxScript = preload("res://scripts/audio/procedural_sfx.gd")

const REQUIRED_SOUNDS: Array[StringName] = [
	&"shot_pulse_rifle",
	&"shot_nova_launcher",
	&"shot_arc_shooter",
	&"impact",
	&"explosion",
	&"chain_zap",
	&"enemy_down",
	&"player_hurt",
	&"skill_pulse",
	&"ui_click",
	&"hit_confirm",
	&"wave_start",
	&"session_clear",
	&"defeat",
]


func _initialize() -> void:
	call_deferred("_run_smoke_test")


func _run_smoke_test() -> void:
	var test_passed := true
	var audio := root.get_node_or_null("Audio")
	test_passed = (
		_expect(audio != null, "the Audio autoload is registered in project.godot") and test_passed
	)
	if audio == null:
		quit(1)
		return

	# --- streams --------------------------------------------------------------
	var sounds := ProceduralSfxScript.build_all()
	var missing: Array[String] = []
	for sound_id in REQUIRED_SOUNDS:
		if not sounds.has(sound_id):
			missing.append(String(sound_id))
	test_passed = (
		_expect(
			missing.is_empty(), "every required sound exists (missing: %s)" % ", ".join(missing)
		)
		and test_passed
	)

	var bad_streams: Array[String] = []
	for sound_id in sounds.keys():
		var stream := sounds[sound_id] as AudioStreamWAV
		if stream == null:
			bad_streams.append(String(sound_id))
			continue
		if (
			stream.format != AudioStreamWAV.FORMAT_16_BITS
			or stream.data.size() < 1000
			or stream.mix_rate < 22050
			or stream.get_length() <= 0.01
		):
			bad_streams.append(String(sound_id))
	test_passed = (
		_expect(
			bad_streams.is_empty(),
			"every sound is a playable 16-bit stream (bad: %s)" % ", ".join(bad_streams),
		)
		and test_passed
	)

	var silent: Array[String] = []
	for sound_id in sounds.keys():
		var stream := sounds[sound_id] as AudioStreamWAV
		if stream != null and _peak_level(stream) < 0.05:
			silent.append(String(sound_id))
	test_passed = (
		_expect(silent.is_empty(), "no sound is silent (quiet: %s)" % ", ".join(silent))
		and test_passed
	)

	# --- weapon mapping ------------------------------------------------------
	var pulse_id := ProceduralSfxScript.weapon_sound_id(&"pulse_rifle")
	var nova_id := ProceduralSfxScript.weapon_sound_id(&"nova_launcher")
	var arc_id := ProceduralSfxScript.weapon_sound_id(&"arc_shooter")
	test_passed = (
		_expect(
			(
				pulse_id == &"shot_pulse_rifle"
				and nova_id == &"shot_nova_launcher"
				and arc_id == &"shot_arc_shooter"
			),
			"each weapon id maps to its own gunshot",
		)
		and test_passed
	)

	# --- playback, mute, throttle -------------------------------------------
	var before := Sfx.played_count()
	Sfx.play_ui(&"wave_start")
	var after_ui := int(audio.call("played_count"))
	test_passed = (
		_expect(after_ui == before + 1, "playing a UI sound counts as one voice") and test_passed
	)

	Sfx.play_ui(&"hit_confirm")
	var after_first_confirm := int(audio.call("played_count"))
	Sfx.play_ui(&"hit_confirm")
	var after_second_confirm := int(audio.call("played_count"))
	test_passed = (
		_expect(
			after_first_confirm == after_ui + 1 and after_second_confirm == after_first_confirm,
			"an identical hit confirmation in the same instant is throttled",
		)
		and test_passed
	)

	audio.call("set_muted", true)
	audio.call("play_ui", &"ui_click")
	var muted_count := int(audio.call("played_count"))
	audio.call("set_muted", false)
	audio.call("play_ui", &"ui_click")
	var unmuted_count := int(audio.call("played_count"))
	test_passed = (
		_expect(
			(
				audio.call("is_muted") == false
				and muted_count == after_second_confirm
				and unmuted_count == muted_count + 1
			),
			"muting silences playback and unmuting restores it",
		)
		and test_passed
	)

	# --- gameplay wiring -----------------------------------------------------
	var main_scene := MainScene.instantiate()
	main_scene.set("start_wave_session_on_ready", false)
	root.add_child(main_scene)
	await process_frame
	var player: Node3D = main_scene.get_node("Player")
	var muzzle: Marker3D = player.get_node("VisualRoot/WeaponSocket/Muzzle")
	var weapon_controller: Node = player.get_node("WeaponController")
	var before_shot := int(audio.call("played_count"))
	var fired := bool(weapon_controller.call("try_fire", player, muzzle, Vector3(0.0, 0.9, -8.0)))
	var after_shot := int(audio.call("played_count"))
	test_passed = (
		_expect(
			fired and after_shot > before_shot,
			"firing the weapon reaches the audio singleton",
		)
		and test_passed
	)

	# The drone respawns itself and the wave session stayed off: nothing else in
	# this scene should keep making noise after the shot.
	main_scene.queue_free()
	await process_frame

	if test_passed:
		print("Audio smoke test passed.")
		quit()
	else:
		quit(1)


## Loudest absolute sample in a stream, used to prove a sound is not silence.
func _peak_level(stream: AudioStreamWAV) -> float:
	var data := stream.data
	var peak := 0.0
	var index := 0
	while index + 1 < data.size():
		peak = maxf(peak, absf(float(data.decode_s16(index)) / 32767.0))
		index += 2
	return peak


func _expect(condition: bool, message: String) -> bool:
	if not condition:
		push_error("Audio smoke test failed: " + message)
	return condition
