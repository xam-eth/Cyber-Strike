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

## Per staged world: the material library it must still carry after import.
## Each world ships its surfaces inside its own GLB, so what used to be one
## GDScript palette is three sets of real materials — and a lost import shows up
## as a flat grey world rather than as an error.
const STAGED := {
	"frostline": {"materials": 12, "textures": 8},
	"verdant": {"materials": 8, "textures": 4},
	"emberfall": {"materials": 40, "textures": 40},
}

var _failures: Array[String] = []


func _initialize() -> void:
	call_deferred("_run_smoke_test")


func _run_smoke_test() -> void:
	_check_palette_is_derived_from_tokens()
	_check_wall_policy_is_not_amber()
	_check_material_variants_differ()
	_check_every_world_carries_its_surfaces()
	_check_worlds_are_not_one_palette()
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


func _check_every_world_carries_its_surfaces() -> void:
	for world_id in STAGED:
		var path := "res://assets/forge/worlds/%s.glb" % world_id
		if not ResourceLoader.exists(path):
			_expect(false, "the staged %s GLB is importable (%s)" % [world_id, path])
			continue
		var scene: PackedScene = load(path)
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
		var floor: Dictionary = STAGED[world_id]
		_expect(
			unique.size() >= int(floor["materials"]),
			(
				"%s carries its own material library (%d material(s), floor %d)"
				% [world_id, unique.size(), int(floor["materials"])]
			)
		)
		_expect(
			textures >= int(floor["textures"]),
			(
				"%s keeps its photographic albedo maps (%d textured surface(s), floor %d)"
				% [world_id, textures, int(floor["textures"])]
			)
		)
		instance.free()


## Three missions, three looks. If two worlds resolve to the same sky, fog and
## key light, the game has three copies of one theatre and the launcher is lying
## about what the player is choosing.
func _check_worlds_are_not_one_palette() -> void:
	var moods: Array[Dictionary] = []
	for world_id in WorldMood.MOOD_ORDER:
		_expect(WorldMood.has_mood(world_id), "a mood is declared for %s" % world_id)
		var mood := WorldMood.mood(world_id)
		_expect(mood["sky"] != mood["fog"], "%s's sky and fog are distinct values" % world_id)
		moods.append(mood)
	for i in moods.size():
		for j in range(i + 1, moods.size()):
			var a: Dictionary = moods[i]
			var b: Dictionary = moods[j]
			_expect(
				not a["key"]["color"].is_equal_approx(b["key"]["color"]),
				(
					"%s and %s do not share a key light"
					% [WorldMood.MOOD_ORDER[i], WorldMood.MOOD_ORDER[j]]
				)
			)
			_expect(
				not a["sky"].is_equal_approx(b["sky"]),
				"%s and %s do not share a sky" % [WorldMood.MOOD_ORDER[i], WorldMood.MOOD_ORDER[j]]
			)
			_expect(
				absf(float(a["fog_density"]) - float(b["fog_density"])) > 0.0005,
				(
					"%s and %s do not share an atmosphere"
					% [WorldMood.MOOD_ORDER[i], WorldMood.MOOD_ORDER[j]]
				)
			)


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
