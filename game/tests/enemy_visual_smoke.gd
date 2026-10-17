extends SceneTree

## Guards the enemy presentation layer: every enemy must render a fitted GLB
## model (not the primitive fallback capsule), the model must sit on the enemy
## origin, and the scene contracts that gameplay depends on — CollisionShape3D,
## Visuals/Muzzle and AimMarker — must survive the swap.
##
## The centring assertion exists because an earlier attempt compensated the
## model offset on the rotated node, which displaced the model by twice the
## bounds offset and left it floating metres away from its collider.

const RunnerScene = preload("res://scenes/enemies/runner.tscn")
const ShooterScene = preload("res://scenes/enemies/shooter.tscn")
const DroneScene = preload("res://scenes/enemies/training_drone.tscn")
const ModelFitterScript = preload("res://scripts/visual/model_fitter.gd")
const MainScene = preload("res://scenes/main.tscn")

const CENTRE_TOLERANCE := 0.65


func _initialize() -> void:
	call_deferred("_run_smoke_test")


func _run_smoke_test() -> void:
	var test_root := Node3D.new()
	root.add_child(test_root)
	var ground := _add_ground(test_root)
	ground.name = "Ground"

	var test_passed := true

	# --- Runner ---------------------------------------------------------------
	var runner := RunnerScene.instantiate() as Node3D
	runner.position = Vector3(0.0, 0.0, -6.0)
	test_root.add_child(runner)
	await process_frame
	test_passed = _check_visual(test_passed, runner, "runner", 1.72, false)

	var runner_visuals: Node = runner.get_node("Visuals")
	test_passed = (
		_expect(
			(
				runner.get_node_or_null("CollisionShape3D") is CollisionShape3D
				and runner_visuals.get_node_or_null("BodyMesh") is MeshInstance3D
				and float(runner_visuals.call("visual_height")) > 1.4
			),
			"runner keeps its collider and reports the fitted model height",
		)
		and test_passed
	)

	# Killing the enemy must collapse the model, and a wave reset must bring it back.
	runner.call("apply_damage", 999.0)
	test_passed = (
		_expect(
			bool(runner.call("is_defeated")) and bool(runner_visuals.call("is_dying")),
			"a downed runner plays its collapse instead of vanishing instantly",
		)
		and test_passed
	)
	for _frame in 70:
		await process_frame
	test_passed = (
		_expect(not runner_visuals.visible, "the collapsed runner is hidden when the fall ends")
		and test_passed
	)
	runner.call("reset_runner")
	await process_frame
	test_passed = (
		_expect(
			(
				runner_visuals.visible
				and bool(runner_visuals.call("has_model"))
				and not bool(runner_visuals.call("is_dying"))
			),
			"a respawned runner is visible again with its model intact",
		)
		and test_passed
	)
	runner.queue_free()
	await process_frame

	# --- Shooter --------------------------------------------------------------
	var shooter := ShooterScene.instantiate() as Node3D
	shooter.position = Vector3(4.0, 0.0, -6.0)
	test_root.add_child(shooter)
	await process_frame
	test_passed = _check_visual(test_passed, shooter, "shooter", 1.62, false)
	var shooter_visuals: Node = shooter.get_node("Visuals")
	var aim_marker := shooter.get_node_or_null("AimMarker") as MeshInstance3D
	test_passed = (
		_expect(
			(
				shooter_visuals.get_node_or_null("Muzzle") is Marker3D
				and aim_marker != null
				and not aim_marker.visible
			),
			"shooter keeps its muzzle marker and its hidden aim telegraph",
		)
		and test_passed
	)
	shooter.queue_free()
	await process_frame

	# --- Training drone -------------------------------------------------------
	var drone := DroneScene.instantiate() as Node3D
	drone.position = Vector3(-4.0, 0.0, -6.0)
	test_root.add_child(drone)
	await process_frame
	test_passed = _check_visual(test_passed, drone, "drone", 0.0, true)
	var drone_visuals: Node = drone.get_node("Visuals")
	var hover_start := _model_local_height(drone_visuals)
	for _frame in 26:
		await process_frame
	var hover_now := _model_local_height(drone_visuals)
	test_passed = (
		_expect(
			hover_start > 0.3 and absf(hover_now - hover_start) > 0.01,
			"the training drone hovers above the floor and keeps bobbing",
		)
		and test_passed
	)
	drone.queue_free()
	await process_frame

	# --- Main scene wiring ----------------------------------------------------
	var main_scene := MainScene.instantiate() as Node3D
	main_scene.set("start_wave_session_on_ready", false)
	test_root.add_child(main_scene)
	await process_frame
	var wired := 0
	for enemy_name in ["TrainingDrone"]:
		var enemy := main_scene.get_node_or_null(enemy_name)
		if enemy != null and bool(enemy.get_node("Visuals").call("has_model")):
			wired += 1
	test_passed = (
		_expect(wired == 1, "the placed training drone renders a model in the main scene")
		and test_passed
	)

	if test_passed:
		print("Enemy visual smoke test passed.")
		quit()
	else:
		quit(1)


## Shared assertions: a fitted model, the fallback mesh retired, and a model that
## is centred on the enemy instead of offset by its own bounds.
func _check_visual(
	test_passed: bool, enemy: Node3D, label: String, expected_height: float, hover: bool
) -> bool:
	var visuals := enemy.get_node_or_null("Visuals")
	var fallback := visuals.get_node_or_null("BodyMesh") as MeshInstance3D
	var has_model := visuals != null and bool(visuals.call("has_model"))
	var height := 0.0
	if has_model:
		height = float(visuals.call("visual_height"))
	var height_ok := true
	if expected_height > 0.0:
		height_ok = absf(height - expected_height) <= 0.25
	var bounds := _model_world_bounds(visuals)
	var offset := Vector2(
		bounds.position.x + bounds.size.x * 0.5, bounds.position.z + bounds.size.z * 0.5
	)
	offset -= Vector2(enemy.global_position.x, enemy.global_position.z)
	var centred := bounds.size.length() > 0.01 and offset.length() <= CENTRE_TOLERANCE
	var grounded := true
	if not hover:
		grounded = bounds.position.y >= -0.15 and bounds.position.y <= 0.25
	return (
		_expect(
			(
				has_model
				and fallback != null
				and not fallback.visible
				and height_ok
				and centred
				and grounded
			),
			(
				"%s renders a fitted %s model (height %.2f, centre offset %.2f, floor %.2f)"
				% [
					label,
					"hovering" if hover else "grounded",
					height,
					offset.length(),
					bounds.position.y
				]
			)
		)
		and test_passed
	)


## World-space bounds of every mesh under the enemy visuals.
func _model_world_bounds(visuals: Node) -> AABB:
	if visuals == null:
		return AABB()
	var has_bounds := false
	var combined := AABB()
	for child in visuals.find_children("*", "MeshInstance3D", true, false):
		var mesh_instance := child as MeshInstance3D
		if mesh_instance == null or mesh_instance.name == "BodyMesh" or mesh_instance.mesh == null:
			continue
		var converted := ModelFitterScript.transform_aabb(
			mesh_instance.get_aabb(), mesh_instance.global_transform
		)
		combined = converted if not has_bounds else combined.merge(converted)
		has_bounds = true
	return combined


func _model_local_height(visuals: Node) -> float:
	var model := visuals.get_node_or_null("ModelPivot/EnemyModel") as Node3D
	return model.position.y if model != null else 0.0


func _add_ground(parent: Node3D) -> StaticBody3D:
	var body := StaticBody3D.new()
	body.collision_layer = 1
	body.position = Vector3(0.0, -0.1, 0.0)
	var collision_shape := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = Vector3(60.0, 0.2, 60.0)
	collision_shape.shape = shape
	body.add_child(collision_shape)
	parent.add_child(body)
	return body


func _expect(condition: bool, message: String) -> bool:
	if not condition:
		push_error("Enemy visual smoke test failed: " + message)
	return condition
