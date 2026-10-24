extends SceneTree

## Guards the one thing that made gameplay and menus look like two products:
## the world's palette had drifted away from the design tokens the entire UI is
## built from (docs/DECISIONS.md 5.1).
##
## This is not a style test -- no test can say whether a colour looks right.
## It asserts that the two palettes are *the same palette*: the world's colours
## are recomputed from `AegisTokens` every run and compared with what the world
## actually publishes. Change a token without carrying the world along and this
## fails, which is the failure mode that produced a near-black menu flow around
## a bright pastel arena.
##
## It also keeps the material policy honest in the one way that is measurable:
## no whole wall may be painted hazard amber. In the shipped build every wall
## surface was orange, so the arena's perimeter out-shouted the reactor that the
## world is composed around.

const KitLibrary = preload("res://scripts/worlds/scifi_kit_library.gd")
const WorldScript = preload("res://scripts/worlds/neon_frontier_world.gd")

var _failures: Array[String] = []


func _initialize() -> void:
	call_deferred("_run_smoke_test")


func _run_smoke_test() -> void:
	_check_palette_is_derived_from_tokens()
	_check_wall_policy_is_not_amber()
	_check_material_variants_differ()
	_finish()


## The core assertion: recompute from the tokens, compare with the literals.
func _check_palette_is_derived_from_tokens() -> void:
	var drift := KitLibrary.palette_drift()
	_expect(drift.is_empty(), "world palette matches AegisTokens (drift: %s)" % [drift])
	_expect(
		KitLibrary.COLORS.size() >= 9,
		"the world palette publishes at least nine surfaces (%d)" % KitLibrary.COLORS.size()
	)
	for key in KitLibrary.COLORS:
		var value: Color = KitLibrary.COLORS[key]
		_expect(
			value.r <= 1.0 and value.g <= 1.0 and value.b <= 1.0,
			"palette '%s' is a colour in range" % key
		)


func _check_wall_policy_is_not_amber() -> void:
	var amber := 0
	for model_key in KitLibrary.POLICY:
		var policy: Dictionary = KitLibrary.POLICY[model_key]
		if not String(model_key).begins_with("wall"):
			continue
		for surface in policy:
			var color_key := String(policy[surface])
			_expect(
				color_key != "hazard",
				(
					"wall '%s' does not paint surface '%s' hazard amber (only trim is)"
					% [model_key, surface]
				)
			)
			if color_key == "hazard":
				amber += 1
	_expect(amber == 0, "no wall family is painted with hazard amber (%d found)" % amber)


## Two surfaces that are used as if they differ must actually differ, otherwise
## a palette change has silently flattened the world into one grey.
func _check_material_variants_differ() -> void:
	var pairs := [["steel", "panel"], ["steel", "trim"], ["floor", "floor_alt"]]
	for pair in pairs:
		var a: Color = KitLibrary.COLORS[pair[0]]
		var b: Color = KitLibrary.COLORS[pair[1]]
		_expect(
			not a.is_equal_approx(b),
			"palette '%s' and '%s' are distinct surfaces" % [pair[0], pair[1]]
		)

	# The material factory must hand back a resource per key, and the floor
	# material must carry its panel texture rather than a flat albedo.
	var floor_material := KitLibrary.material("floor")
	_expect(floor_material != null, "the floor material builds")
	_expect(
		floor_material.albedo_texture != null,
		"the floor material keeps its panel texture (tinted, not replaced)"
	)
	var hazard_material := KitLibrary.material("hazard")
	_expect(hazard_material != null, "the hazard material builds")
	_expect(
		not hazard_material.albedo_color.is_equal_approx(floor_material.albedo_color),
		"hazard trim is not the same value as the deck"
	)

	# The world ships its surfaces inside the staged GLB now. What used to be a
	# GDScript palette is a set of real materials, so the check is that the world
	# really carries them: many distinct materials, and photographic maps rather
	# than flat albedo on the large surfaces.
	var staged := ResourceLoader.exists("res://assets/forge/world/world.glb")
	_expect(staged, "the staged real world GLB is importable")
	if staged:
		var scene: PackedScene = load("res://assets/forge/world/world.glb")
		var instance := scene.instantiate() as Node3D
		var textures := 0
		var unique: Dictionary = {}
		for candidate in instance.find_children("*", "MeshInstance3D", true, false):
			var mesh_instance := candidate as MeshInstance3D
			if mesh_instance.mesh == null:
				continue
			for surface in mesh_instance.mesh.get_surface_count():
				var material := mesh_instance.get_active_material(surface) as StandardMaterial3D
				if material == null:
					continue
				unique[material.get_instance_id()] = true
				if material.albedo_texture != null:
					textures += 1
		_expect(
			unique.size() >= 40,
			"the real world carries its own material library (%d surfaces)" % unique.size()
		)
		_expect(
			textures >= 100,
			"photographic albedo maps survive the import (%d textured surfaces)" % textures
		)
		instance.free()


func _expect(condition: bool, message: String) -> void:
	if condition:
		print("PASS  ", message)
	else:
		_failures.append(message)
		print("FAIL  ", message)


func _finish() -> void:
	if _failures.is_empty():
		print("World palette smoke test passed.")
		quit(0)
	else:
		print("World palette smoke test failed: %d problem(s)." % _failures.size())
		quit(1)
