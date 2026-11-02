extends SceneTree

## Guards the rigged 3D robot enemy lineup: every enemy must render a fitted
## skeletal GLB model (`Skeleton3D` + `AnimationPlayer` + attached `R_Hand`
## weapon, zero primitive capsule stand-ins), sit cleanly on the ground, and
## satisfy combat scene contracts (`CollisionShape3D`, `Visuals/Muzzle`,
## `AimMarker`, collapse/reset, and `EnforcerEnemy` armored DR + EMP disrupt).

const RunnerScene = preload("res://scenes/enemies/runner.tscn")
const ShooterScene = preload("res://scenes/enemies/shooter.tscn")
const EnforcerScene = preload("res://scenes/enemies/enforcer.tscn")
const GuardianScene = preload("res://scenes/enemies/guardian.tscn")
const DroneScene = preload("res://scenes/enemies/training_drone.tscn")
const ModelFitterScript = preload("res://scripts/visual/model_fitter.gd")
const MainScene = preload("res://scenes/main.tscn")

const CENTRE_TOLERANCE := 0.72


func _initialize() -> void:
	call_deferred("_run_smoke_test")


func _run_smoke_test() -> void:
	var test_root := Node3D.new()
	root.add_child(test_root)
	var ground := _add_ground(test_root)
	ground.name = "Ground"

	var test_passed := true

	# --- Runner (Drive Tier 1 Common Robot) -----------------------------------
	var runner := RunnerScene.instantiate() as Node3D
	runner.position = Vector3(0.0, 0.0, -6.0)
	test_root.add_child(runner)
	await process_frame
	test_passed = _check_visual(test_passed, runner, "runner", 1.88)

	var runner_visuals: Node = runner.get_node("Visuals")
	var runner_body := runner_visuals.get_node_or_null("BodyMesh") as Node3D
	test_passed = (
		_expect(
			(
				runner.get_node_or_null("CollisionShape3D") is CollisionShape3D
				and (runner_body == null or not runner_body.visible)
				and float(runner_visuals.call("visual_height")) > 1.5
			),
			"runner hides primitive BodyMesh capsule and reports fitted robot height",
		)
		and test_passed
	)

	runner.call("apply_damage", 999.0)
	test_passed = (
		_expect(
			bool(runner.call("is_defeated")) and bool(runner_visuals.call("is_dying")),
			"a downed runner plays its collapse instead of vanishing instantly",
		)
		and test_passed
	)
	for _frame in 70:
		runner_visuals.call("_process", 0.05)
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
			"a respawned runner is visible again with its robot rig intact",
		)
		and test_passed
	)
	runner.queue_free()
	await process_frame

	# --- Shooter (Drive Tier 2 Rare Robot) ------------------------------------
	var shooter := ShooterScene.instantiate() as Node3D
	shooter.position = Vector3(4.0, 0.0, -6.0)
	test_root.add_child(shooter)
	await process_frame
	test_passed = _check_visual(test_passed, shooter, "shooter", 1.98)
	var shooter_visuals: Node = shooter.get_node("Visuals")
	var aim_marker := shooter.get_node_or_null("AimMarker") as MeshInstance3D
	test_passed = (
		_expect(
			(
				shooter_visuals.get_node_or_null("Muzzle") is Marker3D
				and aim_marker != null
				and not aim_marker.visible
			),
			"shooter keeps its muzzle marker and hidden aim telegraph",
		)
		and test_passed
	)
	shooter.queue_free()
	await process_frame

	# --- Enforcer (Drive Tier 3 Epic Heavy Robot) -----------------------------
	var enforcer := EnforcerScene.instantiate() as Node3D
	enforcer.position = Vector3(-2.0, 0.0, -6.0)
	test_root.add_child(enforcer)
	await process_frame
	test_passed = _check_visual(test_passed, enforcer, "enforcer", 2.16)
	var hp0 := float(enforcer.get("current_health"))
	enforcer.call("apply_damage", 20.0)
	var armored_loss := hp0 - float(enforcer.get("current_health"))
	enforcer.call("apply_emp_disrupt")
	var hp1 := float(enforcer.get("current_health"))
	enforcer.call("apply_damage", 20.0)
	var disrupted_loss := hp1 - float(enforcer.get("current_health"))
	test_passed = (
		_expect(
			armored_loss < 17.5 and disrupted_loss > 24.0,
			(
				"enforcer armored plating reduces hits (%.1f) until EMP disrupts it (%.1f)"
				% [armored_loss, disrupted_loss]
			),
		)
		and test_passed
	)
	enforcer.queue_free()
	await process_frame

	# --- Guardian (Iron Warden Boss Robot) ------------------------------------
	var guardian := GuardianScene.instantiate() as Node3D
	guardian.position = Vector3(2.0, 0.0, -6.0)
	test_root.add_child(guardian)
	await process_frame
	test_passed = _check_visual(test_passed, guardian, "guardian", 2.42)
	var guardian_visuals: Node = guardian.get_node("Visuals")
	var guardian_shield := guardian.get_node_or_null("ShieldMesh") as MeshInstance3D
	var guardian_aim := guardian.get_node_or_null("AimMarker") as MeshInstance3D
	var guardian_ring := guardian.get_node_or_null("SalvoRing") as MeshInstance3D
	test_passed = (
		_expect(
			(
				guardian_visuals.get_node_or_null("Muzzle") is Marker3D
				and guardian_shield != null
				and guardian_shield.visible
				and guardian_aim != null
				and not guardian_aim.visible
				and guardian_ring != null
				and not guardian_ring.visible
			),
			"guardian renders Iron Warden with active barrier and hidden salvo telegraphs",
		)
		and test_passed
	)
	guardian.queue_free()
	await process_frame

	# --- Training Drone (Iron Sentinel Robot) ---------------------------------
	var drone := DroneScene.instantiate() as Node3D
	drone.position = Vector3(-4.0, 0.0, -6.0)
	test_root.add_child(drone)
	await process_frame
	test_passed = _check_visual(test_passed, drone, "drone", 1.92)
	drone.queue_free()
	await process_frame

	# --- Main scene wiring ----------------------------------------------------
	var main_scene := MainScene.instantiate() as Node3D
	main_scene.set("start_wave_session_on_ready", false)
	test_root.add_child(main_scene)
	await process_frame
	var drone_node := main_scene.get_node_or_null("TrainingDrone")
	test_passed = (
		_expect(
			drone_node != null and bool(drone_node.get_node("Visuals").call("has_model")),
			"the placed training drone renders its rigged robot model in main.tscn",
		)
		and test_passed
	)

	if test_passed:
		print("Enemy visual smoke test passed.")
		quit()
	else:
		quit(1)


func _check_visual(test_passed: bool, enemy: Node3D, label: String, expected_height: float) -> bool:
	var visuals := enemy.get_node_or_null("Visuals")
	var has_model := visuals != null and bool(visuals.call("has_model"))
	var height := float(visuals.call("visual_height")) if has_model else 0.0
	var height_ok := absf(height - expected_height) <= 0.30
	var skeletons := visuals.find_children("*", "Skeleton3D", true, false) if visuals else []
	var anims := visuals.find_children("*", "AnimationPlayer", true, false) if visuals else []
	var weapon := visuals.find_child("EnemyWeapon", true, false) if visuals else null
	var bounds := _model_world_bounds(visuals)
	var offset := Vector2(
		bounds.position.x + bounds.size.x * 0.5, bounds.position.z + bounds.size.z * 0.5
	)
	offset -= Vector2(enemy.global_position.x, enemy.global_position.z)
	var centred := bounds.size.length() > 0.01 and offset.length() <= CENTRE_TOLERANCE
	var grounded := bounds.position.y >= -0.22 and bounds.position.y <= 0.28
	return (
		_expect(
			(
				has_model
				and not skeletons.is_empty()
				and not anims.is_empty()
				and weapon != null
				and height_ok
				and centred
				and grounded
			),
			(
				"%s renders rigged robot + weapon (height %.2f, centre %.2f, floor %.2f)"
				% [label, height, offset.length(), bounds.position.y]
			)
		)
		and test_passed
	)


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
