extends SceneTree

## character_animation_smoke.gd -- the "character animation is incomplete" fix.
##
## The gameplay bug report: character animation was incomplete. The hero GLB
## shipped raise_weapon/lower_weapon but nothing played them, the jump had no
## airborne clip at all (walk/run legs kept playing mid-air), and backpedaling
## while aiming moon-walked. This test drives the real CharacterVisual state
## machine and proves:
##
##   * every clip ships in both hero GLBs (player hero + Kestrel),
##   * raising/lowering the weapon plays the authored transitions and settles,
##   * jump/fall/land map to rising/airborne/landing states,
##   * backpedal reverses the walk clip instead of moon-walking.

const MainScene = preload("res://scenes/main.tscn")

const EXPECTED_CLIPS := [
	"idle",
	"walk",
	"run",
	"raise_weapon",
	"aim",
	"aim_walk",
	"aim_run",
	"fire",
	"reload",
	"hit",
	"death",
	"lower_weapon",
	"jump",
	"fall",
	"land",
]

var _passed := true


func _initialize() -> void:
	call_deferred("_run_smoke_test")


func _run_smoke_test() -> void:
	AegisPreferences.write(AegisPreferences.defaults())
	_check_kestrel_clips()

	var main := MainScene.instantiate() as Node3D
	main.set("start_wave_session_on_ready", false)
	main.get_node("ProgressionService").set("profile_path", "")
	root.add_child(main)
	for _warm in 3:
		await process_frame
		await physics_frame

	var player: CharacterBody3D = main.get_node("Player")
	var visual: Node3D = player.get_node("VisualRoot")
	player.set_physics_process(false)
	_expect(visual.is_rigged(), "the hero model is rigged at runtime")
	if not visual.is_rigged():
		main.queue_free()
		await process_frame
		quit(1)
		return

	var anim := _anim_player(visual)
	_expect(anim != null, "the hero carries an AnimationPlayer")
	if anim != null:
		for clip in EXPECTED_CLIPS:
			_passed = _expect(anim.has_animation(clip), "hero GLB provides '%s'" % clip) and _passed

	# --- raise / lower transitions ---------------------------------------
	visual.call("update_pose", Vector3.ZERO, true, 0.016)
	visual.call("set_aiming", true)
	visual.call("_process", 0.016)
	_passed = (
		_expect(
			str(visual.call("current_clip")) == "raise_weapon",
			"entering aim plays the authored raise_weapon (clip=%s)" % visual.call("current_clip"),
		)
		and _passed
	)
	if anim != null:
		anim.advance(1.1)
	visual.call("_process", 1.1)
	_passed = (
		_expect(str(visual.call("current_clip")) == "aim", "raise settles into aim") and _passed
	)

	visual.call("set_aiming", false)
	visual.call("_process", 0.016)
	_passed = (
		_expect(
			str(visual.call("current_clip")) == "lower_weapon",
			"leaving aim plays the authored lower_weapon (clip=%s)" % visual.call("current_clip"),
		)
		and _passed
	)
	if anim != null:
		anim.advance(1.0)
	visual.call("_process", 1.0)
	_passed = (
		_expect(str(visual.call("current_clip")) == "idle", "lower settles into idle") and _passed
	)

	# --- airborne: jump -> fall -> land -----------------------------------
	visual.call("reset_action_state")
	visual.call("update_pose", Vector3(0.0, 3.0, 0.0), false, 0.016)
	visual.call("_process", 0.016)
	_passed = (
		_expect(
			str(visual.call("current_clip")) == "jump",
			"rising off the floor plays jump (clip=%s)" % visual.call("current_clip"),
		)
		and _passed
	)
	visual.call("update_pose", Vector3(0.0, -3.0, 0.0), false, 0.016)
	visual.call("_process", 0.016)
	_passed = (
		_expect(
			str(visual.call("current_clip")) == "fall",
			"descending plays fall (clip=%s)" % visual.call("current_clip"),
		)
		and _passed
	)
	visual.call("update_pose", Vector3.ZERO, true, 0.016)
	visual.call("_process", 0.016)
	_passed = (
		_expect(
			str(visual.call("current_clip")) == "land",
			"touching down plays land (clip=%s)" % visual.call("current_clip"),
		)
		and _passed
	)
	visual.call("_process", 1.0)
	_passed = (
		_expect(str(visual.call("current_clip")) == "idle", "landing recovery settles to idle")
		and _passed
	)

	# --- backpedal reverses the walk clip ---------------------------------
	visual.call("reset_action_state")
	visual.call("set_aiming", true)
	if anim != null:
		anim.advance(1.1)
	visual.call("_process", 1.1)
	# Facing yaw 0 looks along -Z, so +Z velocity is a backpedal.
	visual.call("update_pose", Vector3(0.0, 0.0, 3.0), true, 0.016)
	visual.call("_process", 0.016)
	_passed = (
		_expect(
			str(visual.call("current_clip")) == "aim_walk",
			"aim backpedal keeps the aim-walk clip (clip=%s)" % visual.call("current_clip"),
		)
		and _passed
	)
	_passed = (
		_expect(
			anim != null and anim.speed_scale < 0.0,
			(
				"backpedal reverses playback instead of moon-walking (speed=%.2f)"
				% (anim.speed_scale if anim != null else 0.0)
			),
		)
		and _passed
	)
	visual.call("update_pose", Vector3(0.0, 0.0, -3.0), true, 0.016)
	visual.call("_process", 0.016)
	_passed = (
		_expect(
			anim != null and anim.speed_scale > 0.0,
			(
				"forward aim-walk plays forward again (speed=%.2f)"
				% (anim.speed_scale if anim != null else 0.0)
			),
		)
		and _passed
	)

	main.queue_free()
	await process_frame

	if _passed:
		print("CHARACTER ANIMATION smoke test passed.")
		quit()
	else:
		quit(1)


func _check_kestrel_clips() -> void:
	var packed := load("res://assets/characters/kestrel_hero.glb") as PackedScene
	_passed = _expect(packed != null, "kestrel_hero.glb loads") and _passed
	if packed == null:
		return
	var instance := packed.instantiate() as Node3D
	var anim := _anim_player(instance)
	_passed = _expect(anim != null, "kestrel hero carries an AnimationPlayer") and _passed
	if anim != null:
		for clip in EXPECTED_CLIPS:
			_passed = (
				_expect(anim.has_animation(clip), "kestrel GLB provides '%s'" % clip) and _passed
			)
	instance.free()


func _anim_player(visual: Node) -> AnimationPlayer:
	if visual == null:
		return null
	var players := visual.find_children("*", "AnimationPlayer", true, false)
	if players.is_empty():
		return null
	return players[0] as AnimationPlayer


func _expect(condition: bool, message: String) -> bool:
	if not condition:
		push_error("CHARACTER ANIMATION smoke test failed: " + message)
	return condition
