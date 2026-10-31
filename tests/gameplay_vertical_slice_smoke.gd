extends SceneTree

## Representative content-to-outcome path: the existing hero fires two real
## Pulse Rifle projectiles at one wave-spawned Runner. The Runner must remain
## hittable after the first non-lethal hit, then produce one KO reward, one wave
## reward, and one transition into the next wave. No upgrade is injected: the
## milestone-choice system does not exist in this checkout.

const MainScene = preload("res://scenes/main.tscn")
const PulseRifleDefinition = preload("res://resources/weapons/pulse_rifle.tres")
const EnemyDefinitionScript = preload("res://scripts/enemies/enemy_definition.gd")

var _completed_waves: Array[int] = []
var _runner_eliminated: bool = false


func _initialize() -> void:
	call_deferred("_run_smoke_test")


func _run_smoke_test() -> void:
	var main_scene := MainScene.instantiate()
	main_scene.set("start_wave_session_on_ready", false)
	main_scene.get_node("ProgressionService").set("profile_path", "")
	var wave_director: Node = main_scene.get_node("WaveDirector")
	wave_director.set("base_enemies_per_wave", 1)
	wave_director.set("enemies_added_per_wave", 0)
	wave_director.set("max_enemies_per_wave", 1)
	wave_director.set("max_active_enemies", 1)
	wave_director.set("initial_spawn_delay", 0.0)
	wave_director.set("spawn_interval", 0.0)
	wave_director.set("intermission_duration", 0.05)
	root.add_child(main_scene)
	await process_frame

	var player: Node3D = main_scene.get_node("Player")
	player.set_physics_process(false)
	var weapon_controller: Node = player.get_node("WeaponController")
	var test_passed := true
	test_passed = (
		_expect(
			weapon_controller.call("get_current_definition") == PulseRifleDefinition,
			"the existing hero starts with the real Pulse Rifle definition",
		)
		and test_passed
	)

	var definitions: Array = EnemyDefinitionScript.load_all_definitions()
	test_passed = (
		_expect(
			definitions.size() == 3,
			"the encounter registry exposes Runner, Shooter, and Iron Warden Guardian",
		)
		and test_passed
	)
	for definition in definitions:
		test_passed = (
			_expect(
				definition != null and definition.is_valid_definition(),
				"each encounter definition has a valid id, role, and scene",
			)
			and test_passed
		)

	wave_director.connect("wave_completed", _on_wave_completed)
	wave_director.call("start_session")
	for _frame in 120:
		if int(wave_director.get("active_enemy_count")) == 1:
			break
		await physics_frame
	var active_enemies: Array = wave_director.call("get_active_enemies")
	test_passed = (
		_expect(active_enemies.size() == 1, "one real enemy is spawned through its definition")
		and test_passed
	)
	if active_enemies.is_empty():
		main_scene.queue_free()
		await process_frame
		quit(1)
		return

	var runner := active_enemies[0] as CharacterBody3D
	test_passed = (
		_expect(runner.is_in_group("runner_enemies"), "wave one resolves to the Runner content id")
		and test_passed
	)
	runner.set_physics_process(false)
	runner.connect("eliminated", _on_runner_eliminated)
	# Preserve actual spawning above, then use a deterministic clear lane so this
	# test measures projectile/damage behavior rather than procedural spawn aim.
	runner.global_position = player.global_position + Vector3(0.0, 0.0, -5.0)
	await physics_frame
	var muzzle: Marker3D = player.get_node("VisualRoot/WeaponSocket/Muzzle")
	var aim_point := runner.global_position + Vector3.UP * 0.9
	test_passed = (
		_expect(
			bool(weapon_controller.call("try_fire", player, muzzle, aim_point)),
			"the first Pulse Rifle shot passes firing validation",
		)
		and test_passed
	)
	for _frame in 90:
		if float(runner.get("current_health")) < 36.0:
			break
		await physics_frame
	test_passed = (
		_expect(
			is_equal_approx(float(runner.get("current_health")), 18.0),
			"the first real projectile applies 18 non-lethal damage",
		)
		and test_passed
	)
	await process_frame
	var runner_shape := runner.get_node("CollisionShape3D") as CollisionShape3D
	test_passed = (
		_expect(
			int(runner.get("collision_layer")) == 2 and not runner_shape.disabled,
			"a non-lethal Runner hit leaves its collider enabled for the follow-up shot",
		)
		and test_passed
	)

	for _frame in 24:
		await physics_frame
	test_passed = (
		_expect(
			bool(weapon_controller.call("try_fire", player, muzzle, aim_point)),
			"the second Pulse Rifle shot passes cadence and ammunition validation",
		)
		and test_passed
	)
	for _frame in 90:
		if _runner_eliminated:
			break
		await physics_frame
	test_passed = (
		_expect(_runner_eliminated, "the follow-up real projectile hits and eliminates the Runner")
		and test_passed
	)

	var run_stats: Node = main_scene.get_node("RunStats")
	var reward_service: Node = main_scene.get_node("RewardService")
	# These explicit duplicate calls prove that the outcome remains idempotent
	# even if an integration accidentally repeats either event delivery path.
	if is_instance_valid(runner):
		reward_service.call("award_enemy_defeat", runner)
	reward_service.call("award_wave_completion", 1)
	test_passed = (
		_expect(_completed_waves == [1], "the one-enemy wave emits one completion event")
		and test_passed
	)
	test_passed = (
		_expect(
			(
				int(run_stats.get("eliminations")) == 1
				and int(run_stats.get("run_score")) == 100
				and int(run_stats.get("bp_earned")) == 110
			),
			"KO and wave rewards are applied once: 100 score and 110 run BP",
		)
		and test_passed
	)
	test_passed = (
		_expect(
			wave_director.call("get_state_label").begins_with("WAVE 1 CLEAR"),
			"wave completion enters the readable intermission state",
		)
		and test_passed
	)

	for _frame in 30:
		if int(wave_director.get("current_wave")) == 2:
			break
		await physics_frame
	test_passed = (
		_expect(int(wave_director.get("current_wave")) == 2, "intermission advances into wave two")
		and test_passed
	)

	main_scene.queue_free()
	await process_frame
	if test_passed:
		print("Gameplay content vertical-slice smoke test passed.")
		quit()
	else:
		quit(1)


func _on_wave_completed(wave_index: int) -> void:
	_completed_waves.append(wave_index)


func _on_runner_eliminated() -> void:
	_runner_eliminated = true


func _expect(condition: bool, message: String) -> bool:
	if not condition:
		push_error("Gameplay vertical-slice smoke test failed: " + message)
	return condition
