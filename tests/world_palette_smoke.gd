extends SceneTree

## Verifies SH-01 Aetherfall's atmosphere, shared texture library, and UI token
## palette alignment so the Citadel world and dark sci-fi HUD read as one game.
const WorldScene = preload("res://scenes/worlds/aetherfall_world.tscn")

var _failures: Array[String] = []


func _initialize() -> void:
	call_deferred("_run_smoke_test")


func _run_smoke_test() -> void:
	var mood := WorldMood.for_world("aetherfall")
	_expect(not mood.is_empty(), "WorldMood defines SH-01 Aetherfall atmosphere")
	var sun: Color = WorldMood.sun_color("aetherfall")
	var fog: Color = WorldMood.fog_color("aetherfall")
	_expect(
		sun.r > 0.8 and sun.b > 0.7 and not sun.is_equal_approx(fog),
		"Aetherfall alpine sun and mist fog colours are distinct and in-range",
	)
	_expect(
		AegisTokens.ACCENT.r > AegisTokens.ACCENT.b and AegisTokens.INFO.b > AegisTokens.INFO.r,
		"AegisTokens preserves yellow primary action and cyan info accents",
	)

	var world := WorldScene.instantiate() as Node3D
	root.add_child(world)
	await process_frame
	await process_frame

	var meshes := world.find_children("*", "MeshInstance3D", true, false)
	var unique_albedo_textures := {}
	var unique_pbr_textures := {}
	var unique_materials := {}
	for node in meshes:
		var mi := node as MeshInstance3D
		if mi.mesh == null:
			continue
		for s in range(mi.mesh.get_surface_count()):
			var mat := mi.get_active_material(s) as BaseMaterial3D
			if mat != null:
				unique_materials[mat.get_instance_id()] = true
				for tex in [
					mat.albedo_texture,
					mat.normal_texture,
					mat.orm_texture,
					mat.roughness_texture,
					mat.metallic_texture,
				]:
					if tex == null:
						continue
					var key := (
						tex.resource_path
						if not tex.resource_path.is_empty()
						else str(tex.get_instance_id())
					)
					unique_pbr_textures[key] = true
					if tex == mat.albedo_texture:
						unique_albedo_textures[key] = true

	_expect(
		(
			unique_materials.size() >= 18
			and unique_albedo_textures.size() >= 8
			and unique_pbr_textures.size() >= 18
		),
		(
			"Aetherfall carries rich PBR materials (%d materials, %d albedo / %d PBR maps)"
			% [unique_materials.size(), unique_albedo_textures.size(), unique_pbr_textures.size()]
		),
	)

	world.queue_free()
	await process_frame
	if _failures.is_empty():
		print("World palette smoke test passed.")
		quit()
	else:
		printerr("World palette smoke failed: %s" % [_failures])
		quit(1)


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
		push_error("World palette smoke failed: " + message)
