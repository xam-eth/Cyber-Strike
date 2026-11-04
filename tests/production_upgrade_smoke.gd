extends SceneTree

## End-to-end runtime verification for the production-standard upgrade:
##   1) HERO_01 + HERO_01_WEAPON + Kestrel distinct rig & muzzle socket
##   2) Aetherfall ArchiveComputer restoration + PolarSnowfall + PBR world load
##   3) FieldActivityDirector destructible SupplyCrates + 3D FieldPickups +
##      Overshield + Overcharge + Cryo-Alloy Tactical Evolution
##   4) HudResourceBar live telemetry & 21-voice ProceduralSfx library.

const MainScene = preload("res://scenes/main.tscn")
const ProceduralSfxScript = preload("res://scripts/audio/procedural_sfx.gd")
const FieldPickupScript = preload("res://scripts/worlds/field_pickup.gd")

var _failures: Array[String] = []


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	AegisPreferences.write(AegisPreferences.defaults())
	var main := MainScene.instantiate()
	main.set("start_wave_session_on_ready", false)
	main.get_node("ProgressionService").set("profile_path", "")
	root.add_child(main)
	await process_frame
	await process_frame

	var player: Node3D = main.get_node("Player")
	var hud: Control = main.get_node("HUD/TouchControls")
	var run_stats: Node = main.get_node("RunStats")
	var upgrade_mgr: Node = main.get_node("RunUpgradeManager")
	var field_dir: Node3D = main.get_node_or_null("FieldActivityDirector")
	var world_host: Node = main.get_node("Arena")

	# 1. Weapon & Hero verification
	var pulse_def: Resource = load("res://resources/weapons/pulse_rifle.tres")
	_expect(
		(
			pulse_def != null
			and String(pulse_def.get("weapon_model_path")).ends_with("hero_01_weapon.glb")
		),
		"Pulse Rifle uses canonical HERO_01_WEAPON glb",
	)
	var weapon_glb := load("res://assets/weapons/hero_01_weapon/hero_01_weapon.glb") as PackedScene
	_expect(weapon_glb != null, "HERO_01_WEAPON PackedScene loads")
	if weapon_glb != null:
		var inst := weapon_glb.instantiate()
		var muzzle := inst.find_child("MuzzlePoint", true, false) as Node3D
		var grip := inst.find_child("GripPoint", true, false) as Node3D
		_expect(
			muzzle != null and grip != null and muzzle.position.z < -0.45,
			"HERO_01_WEAPON exposes GripPoint and forward -Z MuzzlePoint",
		)
		inst.free()

	# 2. Aetherfall world bug fixes (ArchiveComputer + PolarSnowfall)
	var archive_comp := world_host.find_child("ArchiveComputer", true, false)
	var snowfall := world_host.find_child("PolarSnowfall", true, false) as GPUParticles3D
	_expect(archive_comp != null, "Aetherfall ArchiveVault spawns ArchiveComputer terminal")
	_expect(
		snowfall != null and snowfall.emitting,
		"Aetherfall spawns active PolarSnowfall atmospheric particles",
	)

	# 3. FieldActivityDirector: SupplyCrates + FieldPickups + Overshield + Overcharge
	_expect(field_dir != null, "Main mounts FieldActivityDirector")
	if field_dir != null:
		var init_crates := int(field_dir.call("active_crate_count"))
		var init_pickups := int(field_dir.call("active_pickup_count"))
		_expect(init_crates == 10, "FieldActivityDirector spawns 10 destructible SupplyCrates")
		_expect(init_pickups == 12, "FieldActivityDirector spawns 12 ambient FieldPickups")

		var crates_root := field_dir.get_node("SupplyCrates")
		var first_crate := crates_root.get_child(0)
		first_crate.call("apply_damage", 200.0, player)
		await process_frame
		_expect(
			(
				int(run_stats.get("crates_broken")) == 1
				and int(field_dir.call("active_pickup_count")) == init_pickups + 3
			),
			"Shattering a SupplyCrate records crate break and bursts 3 physical pickups",
		)

		# Simulate active player collecting BP shard, 3 Cryo-Alloys, and Plasma Cell
		player.set("_distance_travelled", 1.5)
		field_dir.emit_signal(
			"pickup_collected", FieldPickupScript.KIND_BP_SHARD, 15, player.global_position
		)
		_expect(
			int(run_stats.get("bp_earned")) == 15,
			"Collecting BP_SHARD increments in-run BP telemetry",
		)

		for _i in range(3):
			field_dir.emit_signal(
				"pickup_collected", FieldPickupScript.KIND_CRYO_ALLOY, 1, player.global_position
			)
		_expect(
			(
				float(player.get("current_overshield")) >= 35.0
				and bool(upgrade_mgr.call("has_pending_choice"))
			),
			"Collecting 3 Cryo-Alloys charges Overshield and unlocks a Field Tactical Evolution",
		)

		# Verify Overshield absorbs incoming hit before Vitals
		var hp_before := float(player.get("current_health"))
		player.call("apply_damage", 20.0)
		_expect(
			(
				is_equal_approx(float(player.get("current_health")), hp_before)
				and float(player.get("current_overshield")) < 36.0
			),
			"Overshield absorbs incoming combat damage before operative Vitals",
		)

		field_dir.emit_signal(
			"pickup_collected", FieldPickupScript.KIND_PLASMA_CELL, 1, player.global_position
		)
		_expect(
			float(player.get("_overcharge_remaining")) >= 5.5,
			"Collecting PLASMA_CELL grants live Weapon Overcharge",
		)

	# 4. HudResourceBar live telemetry
	var res_bar := hud.get("_resource_bar") as Control
	_expect(
		(
			res_bar != null
			and res_bar.visible
			and int(res_bar.get("run_bp")) == 15
			and int(res_bar.get("cryo_alloy")) == 3
		),
		"HudResourceBar is visible during gameplay and reflects live BP and Cryo-Alloy",
	)

	# 5. Studio multi-layer SFX bank
	var streams := ProceduralSfxScript.build_all()
	for req in [
		&"shot_pulse_rifle",
		&"reload_start",
		&"reload_ready",
		&"pickup_bp",
		&"pickup_alloy",
		&"pickup_power",
		&"crate_break",
		&"shield_hit",
	]:
		_expect(streams.has(req) and streams[req] != null, "ProceduralSfx builds %s" % String(req))

	main.queue_free()
	await process_frame
	if _failures.is_empty():
		print("Production upgrade smoke test passed.")
		quit(0)
	else:
		for f in _failures:
			push_error("FAILED: " + f)
		quit(1)


func _expect(cond: bool, msg: String) -> void:
	if cond:
		print("  ok: " + msg)
	else:
		_failures.append(msg)
