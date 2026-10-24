extends SceneTree

## A melee Runner must not sink into the player when it arrives from a flank.
## Both capsules need actual physics separation; a no-collision chase can leave
## the last wave target hidden inside the hero and impossible to shoot.

const PlayerScene = preload("res://scenes/player/player.tscn")
const RunnerScene = preload("res://scenes/enemies/runner.tscn")


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var arena := Node3D.new()
	root.add_child(arena)
	var ground := StaticBody3D.new()
	ground.collision_layer = 1
	var floor_shape := CollisionShape3D.new()
	var floor_box := BoxShape3D.new()
	floor_box.size = Vector3(24.0, 0.2, 24.0)
	floor_shape.position.y = -0.1
	floor_shape.shape = floor_box
	ground.add_child(floor_shape)
	arena.add_child(ground)

	var player := PlayerScene.instantiate() as CharacterBody3D
	player.name = "Player"
	arena.add_child(player)
	player.set_physics_process(false)
	var runner := RunnerScene.instantiate() as CharacterBody3D
	runner.name = "Runner"
	runner.set("target_path", NodePath("../Player"))
	runner.position = Vector3(0.10, 0.0, 0.10)
	arena.add_child(runner)
	for _frame in 16:
		await physics_frame
	var initial_separation := _horizontal_distance(player, runner)
	var passed := _expect(
		initial_separation >= 0.6,
		"overlapping Runner/player capsules resolve apart (%.2f m)" % initial_separation,
	)

	# After the stationary target moves away, the Runner can pursue and attack,
	# but its collider must still prevent it from occupying the player's feet.
	player.global_position = Vector3(0.0, 0.0, -4.0)
	for _frame in 130:
		await physics_frame
	var chase_separation := _horizontal_distance(player, runner)
	passed = (
		_expect(
			chase_separation >= 0.6 and chase_separation < 3.0,
			"Runner approaches the target but stands clear (%.2f m)" % chase_separation,
		)
		and passed
	)
	arena.queue_free()
	await process_frame
	if passed:
		print("Runner standoff smoke test passed.")
		quit()
	else:
		quit(1)


func _horizontal_distance(first: Node3D, second: Node3D) -> float:
	var delta := first.global_position - second.global_position
	delta.y = 0.0
	return delta.length()


func _expect(condition: bool, reason: String) -> bool:
	if not condition:
		push_error("Runner standoff smoke test failed: " + reason)
	return condition
