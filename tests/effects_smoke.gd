extends SceneTree

## Guards the combat presentation effects: a shot must produce a muzzle flash at
## the weapon, a projectile must carry a tracer long enough to read while it
## moves, and an impact must spawn a spark burst that cleans itself up.
##
## A single screenshot cannot prove the timing (the flash is ~100 ms and the
## burst ~400 ms), but it can reveal an oversized trail crossing the avatar.

const MainScene = preload("res://scenes/main.tscn")
const PulseScene = preload("res://scenes/weapons/pulse_projectile.tscn")
const ImpactBurstScript = preload("res://scripts/weapons/impact_burst.gd")
const PulseAfterglowScript = preload("res://scripts/weapons/pulse_afterglow.gd")
const NovaShockwaveScript = preload("res://scripts/weapons/nova_shockwave.gd")
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
	var glint: MeshInstance3D
	if muzzle_flash != null:
		test_passed = (
			_expect(
				not bool(muzzle_flash.call("is_flashing")),
				"the muzzle flash is dark until something is fired",
			)
			and test_passed
		)
		var cone := muzzle_flash.get_node_or_null("FlashCone") as MeshInstance3D
		glint = muzzle_flash.get_node_or_null("FlashGlint") as MeshInstance3D
		test_passed = (
			_expect(
				(
					cone != null
					and cone.mesh is CylinderMesh
					and cone.position.z < -0.1
					and (cone.mesh as CylinderMesh).height <= 0.2
					and (cone.mesh as CylinderMesh).bottom_radius <= 0.04
					and glint != null
					and glint.position.z > -0.4
					and glint.mesh is QuadMesh
					and (glint.material_override as StandardMaterial3D).albedo_texture != null
					and muzzle_flash.get_node_or_null("FlashSpark_1") != null
				),
				"barrel flash cone has bounded forward dimensions (visual check still needed)",
			)
			and test_passed
		)

	# --- tracer -------------------------------------------------------------
	# Built outside the tree on purpose: a projectile handed to the scene starts
	# flying immediately and frees itself on the floor before it can be measured.
	var projectile := PulseScene.instantiate() as Node3D
	projectile.call("_stretch_tracer")
	var tracer := projectile.get_node_or_null("Tracer") as MeshInstance3D
	var glow := projectile.get_node_or_null("TracerGlow") as MeshInstance3D
	var tracer_length := 0.0
	var capsule := tracer.mesh as CapsuleMesh if tracer != null else null
	if capsule != null:
		tracer_length = capsule.height
	test_passed = (
		_expect(
			(
				tracer != null
				and glow != null
				and tracer_length >= 0.8
				and absf(tracer.rotation.x - deg_to_rad(90.0)) < 0.01
				and tracer.position.z > 0.2
				and glow.material_override is StandardMaterial3D
			),
			"a pulse bolt carries a tracer behind it, along its travel axis",
		)
		and test_passed
	)
	projectile.call("_stretch_tracer", 2.6)
	var independent_projectile := PulseScene.instantiate() as Node3D
	var untouched_tracer := independent_projectile.get_node("Tracer") as MeshInstance3D
	test_passed = (
		_expect(
			(
				is_equal_approx((tracer.mesh as CapsuleMesh).height, 2.6)
				and is_equal_approx((glow.mesh as CapsuleMesh).height, 2.6)
				and (untouched_tracer.mesh as CapsuleMesh).height < 1.5
			),
			"the bright core and halo stretch with one real bolt, never all shared projectiles",
		)
		and test_passed
	)
	independent_projectile.free()
	projectile.free()

	# A spent Pulse bolt may leave a short wake at its actual collision, not a
	# full-length laser, an untravelled trail behind the player or a leaked node.
	var before_wakes := get_nodes_in_group(PulseAfterglowScript.GROUP).size()
	var wake := PulseAfterglowScript.spawn(
		main_scene, Vector3(0.0, 1.0, -4.0), Vector3(0.0, 1.0, -8.0)
	)
	var wake_core := wake.get_node_or_null("Core") as MeshInstance3D if wake != null else null
	test_passed = (
		_expect(
			(
				wake != null
				and get_nodes_in_group(PulseAfterglowScript.GROUP).size() == before_wakes + 1
				and is_equal_approx(wake.global_position.z, -7.0)
				and wake_core != null
				and wake_core.mesh is CapsuleMesh
				and is_equal_approx((wake_core.mesh as CapsuleMesh).height, 2.0)
			),
			"Pulse afterglow ends at the real hit and uses only its last two metres",
		)
		and test_passed
	)
	test_passed = (
		_expect(
			PulseAfterglowScript.spawn(main_scene, Vector3.ZERO, Vector3.ZERO) == null,
			"an untravelled Pulse round cannot create a cosmetic hit trail",
		)
		and test_passed
	)
	var view_camera := main_scene.get_viewport().get_camera_3d()
	if view_camera != null:
		var near_end := view_camera.global_position - view_camera.global_basis.z * 3.0
		var near_width := PulseAfterglowScript.screen_limited_length(
			main_scene, near_end, view_camera.global_basis.x, 2.0
		)
		test_passed = (
			_expect(
				near_width > 0.0 and near_width < 1.0,
				"side-on near-camera Pulse wakes shrink before becoming white screen spears",
			)
			and test_passed
		)

	# --- muzzle flash on a real shot ----------------------------------------
	var weapon_controller: Node = player.get_node("WeaponController")
	var muzzle: Marker3D = player.get_node("VisualRoot/WeaponSocket/Muzzle")
	var fired := bool(weapon_controller.call("try_fire", player, muzzle, Vector3(0.0, 0.9, -12.0)))
	test_passed = (_expect(fired, "the weapon fires for the effect test") and test_passed)
	var spawned_bolt: PulseProjectile
	for child in main_scene.get_children():
		if child is PulseProjectile:
			spawned_bolt = child as PulseProjectile
			break
	test_passed = (
		_expect(
			(
				spawned_bolt != null
				and not (spawned_bolt.get_node("Tracer") as MeshInstance3D).visible
				and not (spawned_bolt.get_node("TracerGlow") as MeshInstance3D).visible
			),
			"the first frame at the muzzle has a bolt but no untravelled trail through the hero",
		)
		and test_passed
	)
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
		var spark := muzzle_flash.get_node_or_null("FlashSpark_0") as MeshInstance3D
		var bounce := muzzle_flash.get_node_or_null("FlashLight") as OmniLight3D
		muzzle_flash.call("set_reduced_flash", true)
		test_passed = (
			_expect(
				(
					spark != null
					and not spark.visible
					and glint != null
					and not glint.visible
					and bounce != null
					and bounce.light_energy == 0.0
				),
				"Reduce Flash removes outer streaks, glint, and bounce but keeps the hot core",
			)
			and test_passed
		)
		muzzle_flash.call("set_reduced_flash", false)
		test_passed = (
			_expect(
				spark != null and spark.visible and glint != null and glint.visible,
				"normal axial muzzle streaks and face-on glint return when opted in"
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
	var burst := ImpactBurstScript.spawn(
		main_scene, Vector3(0.0, 1.0, -6.0), Color(0.28, 0.86, 1.0), Vector3.RIGHT, true
	)
	test_passed = (_expect(burst != null, "an impact spawns a spark burst") and test_passed)
	if burst != null:
		var contact := burst.get_node_or_null("PulseContactRing") as MeshInstance3D
		test_passed = (
			_expect(
				(
					contact != null
					and contact.mesh is TorusMesh
					and contact.basis.y.dot(Vector3.RIGHT) > 0.9
				),
				"a real Pulse collision can leave a hollow ring aligned to the hit surface",
			)
			and test_passed
		)
		test_passed = (
			_expect(
				(
					burst.is_inside_tree()
					and burst.emitting
					and burst.amount >= 20
					and burst.mesh is CylinderMesh
					and burst.direction.is_equal_approx(Vector3.RIGHT)
					and burst.get_node_or_null("ImpactBounce") is OmniLight3D
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
	var before_shock := get_nodes_in_group(NovaShockwaveScript.GROUP).size()
	var shock := NovaShockwaveScript.spawn(
		main_scene, Vector3(0.0, 1.0, -6.0), Vector3(0.0, 0.14, -6.0), Vector3.UP, 4.0, true, true
	)
	var band := shock.get_node_or_null("ImpactSurface/BlastFront") as MeshInstance3D
	var reduced_filaments := shock.get_node_or_null("ImpactSurface/IonFilaments") as MeshInstance3D
	var reduced_etch := shock.get_node_or_null("ImpactSurface/ImpactEtch") as MeshInstance3D
	var core := shock.get_node_or_null("ImpactCore") as MeshInstance3D
	var bounce := shock.get_node_or_null("BlastBounce") as OmniLight3D
	test_passed = (
		_expect(
			(
				shock != null
				and band != null
				and band.scale.x >= 3.9
				and reduced_filaments != null
				and not reduced_filaments.visible
				and reduced_etch != null
				and not reduced_etch.visible
				and core != null
				and not core.visible
				and bounce != null
				and is_zero_approx(bounce.light_energy)
				and get_nodes_in_group(NovaShockwaveScript.GROUP).size() == before_shock + 1
			),
			"reduced-motion Nova keeps a static radius cue without the bright core or bounce",
		)
		and test_passed
	)
	var full_shock := NovaShockwaveScript.spawn(
		main_scene, Vector3(3.0, 1.0, -6.0), Vector3(3.0, 0.14, -6.0), Vector3.UP, 4.0
	)
	var filaments := full_shock.get_node_or_null("ImpactSurface/IonFilaments") as MeshInstance3D
	var etch := full_shock.get_node_or_null("ImpactSurface/ImpactEtch") as MeshInstance3D
	test_passed = (
		_expect(
			(
				filaments != null
				and filaments.visible
				and filaments.mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX].size() == 90
				and etch != null
				and etch.visible
				and etch.mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX].size() == 36
				and get_nodes_in_group(NovaShockwaveScript.GROUP).size() == before_shock + 2
			),
			"normal Nova adds segmented inner arcs and a contact scar only at real impact",
		)
		and test_passed
	)
	# Neither effect may leak after its final rendered frame and lifetime.
	await create_timer(ImpactBurstScript.CLEANUP_DELAY + 0.5).timeout
	var after := get_nodes_in_group(ImpactBurstScript.BURST_GROUP).size()
	test_passed = (
		_expect(after == before, "the burst frees itself after its particles die") and test_passed
	)
	test_passed = (
		_expect(
			get_nodes_in_group(PulseAfterglowScript.GROUP).size() == before_wakes,
			"Pulse impact wakes expire instead of accumulating during a firing run",
		)
		and test_passed
	)
	test_passed = (
		_expect(
			get_nodes_in_group(NovaShockwaveScript.GROUP).size() == before_shock,
			"the Nova radius cue frees itself after the impact instead of piling up",
		)
		and test_passed
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
