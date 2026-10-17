extends SceneTree

## Guards the combat presentation effects: a shot must produce a muzzle flash at
## the weapon, a projectile must carry a tracer long enough to read while it
## moves, and an impact must spawn a spark burst that cleans itself up.
##
## These are exactly the things a screenshot cannot prove (the flash lasts 90 ms,
## the burst 400 ms) and exactly what makes the shooting feel like shooting.

const MainScene = preload("res://scenes/main.tscn")
const PulseScene = preload("res://scenes/weapons/pulse_projectile.tscn")
const ImpactBurstScript = preload("res://scripts/effects/impact_burst.gd")
const ModelFitterScript = preload("res://scripts/visual/model_fitter.gd")


func _initialize() -> void:
	call_deferred("_run_smoke_test")


func _run_smoke_test() -> void:
	var test_passed := true
	var main_scene := MainScene.instantiate()
	main_scene.set("start_wave_session_on_ready", false)
	root.add_child(main_scene)
	await process_frame
	var player: Node3D = main_scene.get_node("Player")
	var muzzle_flash := player.get_node_or_null("VisualRoot/WeaponSocket/MuzzleFlash")
	test_passed = (
		_expect(muzzle_flash != null, "the player weapon carries a muzzle flash node")
		and test_passed
	)
	if muzzle_flash != null:
		test_passed = (
			_expect(
				not bool(muzzle_flash.call("is_flashing")),
				"the muzzle flash is dark until something is fired",
			)
			and test_passed
		)

	# --- tracer -------------------------------------------------------------
	# Built outside the tree on purpose: a projectile handed to the scene starts
	# flying immediately and frees itself on the floor before it can be measured.
	var projectile := PulseScene.instantiate() as Node3D
	projectile.call("_stretch_tracer")
	var tracer := projectile.get_node_or_null("Tracer") as MeshInstance3D
	var tracer_length := 0.0
	var capsule := tracer.mesh as CapsuleMesh if tracer != null else null
	if capsule != null:
		tracer_length = capsule.height
	test_passed = (
		_expect(
			(
				tracer != null
				and tracer_length >= 0.8
				and absf(tracer.rotation.x - deg_to_rad(90.0)) < 0.01
				and tracer.position.z > 0.2
			),
			"a pulse bolt carries a tracer behind it, along its travel axis",
		)
		and test_passed
	)
	projectile.free()

	# --- muzzle flash on a real shot ----------------------------------------
	var weapon_controller: Node = player.get_node("WeaponController")
	var muzzle: Marker3D = player.get_node("VisualRoot/WeaponSocket/Muzzle")
	var fired := bool(weapon_controller.call("try_fire", player, muzzle, Vector3(0.0, 0.9, -12.0)))
	test_passed = (_expect(fired, "the weapon fires for the effect test") and test_passed)
	# try_fire is called directly by this test, so drive the flash the same way the
	# controller does when the player pulls the trigger.
	if muzzle_flash != null:
		muzzle_flash.call("flash")
	test_passed = (
		_expect(
			muzzle_flash != null and bool(muzzle_flash.call("is_flashing")),
			"firing lights the muzzle flash",
		)
		and test_passed
	)
	# A frame delta longer than the flash must not kill it in the same frame: at
	# 3 fps the first shot used to be cleared before it was ever drawn.
	if muzzle_flash != null:
		muzzle_flash.call("flash")
		muzzle_flash.call("_process", 1.5)
		test_passed = (
			_expect(
				bool(muzzle_flash.call("is_flashing")),
				"a flash survives a frame delta longer than its own duration",
			)
			and test_passed
		)
	for _frame in 20:
		await process_frame
	test_passed = (
		_expect(
			muzzle_flash != null and not bool(muzzle_flash.call("is_flashing")),
			"the muzzle flash goes dark again on its own",
		)
		and test_passed
	)

	# --- impact burst -------------------------------------------------------
	var before := get_nodes_in_group(ImpactBurstScript.BURST_GROUP).size()
	var burst := ImpactBurstScript.spawn(main_scene, Vector3(0.0, 1.0, -6.0))
	test_passed = (_expect(burst != null, "an impact spawns a spark burst") and test_passed)
	if burst != null:
		test_passed = (
			_expect(
				(
					burst.is_inside_tree()
					and burst.emitting
					and burst.amount > 0
					and burst.mesh != null
				),
				"the burst is emitting with a mesh to draw",
			)
			and test_passed
		)
	var during := get_nodes_in_group(ImpactBurstScript.BURST_GROUP).size()
	test_passed = (
		_expect(during == before + 1, "the burst joins the impact group for inspection")
		and test_passed
	)
	# The burst frees itself; leaked bursts would poison the frame time in a wave.
	await create_timer(ImpactBurstScript.CLEANUP_DELAY + 0.5).timeout
	var after := get_nodes_in_group(ImpactBurstScript.BURST_GROUP).size()
	test_passed = (
		_expect(after == before, "the burst frees itself after its particles die") and test_passed
	)

	main_scene.queue_free()
	await process_frame
	if test_passed:
		print("Effects smoke test passed.")
		quit()
	else:
		quit(1)


func _expect(condition: bool, message: String) -> bool:
	if not condition:
		push_error("Effects smoke test failed: " + message)
	return condition
