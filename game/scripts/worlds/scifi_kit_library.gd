class_name ScifiKitLibrary
extends RefCounted

## The uploaded `3DScifiStarterKitFree.zip` pack, imported as GLB.
##
## `tools/convert_fbx_pack.py` runs on a GitHub runner (the archive is a Git LFS
## object that this machine cannot download) and commits the converted models.
## This class is the only place that knows their paths, their measured footprint
## and how far each one has to be lifted so it sits on the floor instead of
## floating or sinking.
##
## The pack ships **named materials with no texture links** (Orange, HD_Wall_02,
## Stuff_01, Glass, ...), so the look comes from a palette applied here rather
## than from the 4K texture set. That is also what keeps the committed models at
## 2.4 MB instead of a few hundred.

const ROOT := "res://assets/world/scifi_starter_kit/models/"

## Models this level uses. Everything else stays on disk for future rounds.
const MODELS := {
	"floor": "Floor_Squared_01_6x6",
	"floor_alt": "Floor_Angle_01_6x6",
	"floor_grate": "Floor_Pipes_01",
	"wall": "Wall_Simple_01_Long",
	"wall_b": "Wall_Simple_02_Long",
	"wall_c": "Wall_Simple_03_Long",
	"wall_cube": "Wall_Cube_01_Long",
	"wall_low": "Wall_Cube_01_Flat",
	"doorway": "DoorWay_01_Large",
	"column": "Column_01_Big",
	"pillar": "Wall_Cube_01_Round",
	"crate": "Crate_01",
	"console": "Wall_Console_01_Half",
	"console_large": "Wall_Console_01_Large",
	"light_strip": "Light_SideLight_01",
	"light_corridor": "Light_Corridor_01",
	"pipes": "Pipes_03",
	"wall_pipes": "Wall_Pipes_01_Large",
	"fence": "Fence_Long_01",
	"sign_danger": "Sign_Danger_01",
	"word_zone": "Word_Zone",
	"beam": "Beam_01",
}

## Measured with `game/tests/_kit_probe.gd`: a model whose mesh starts below zero
## would otherwise sink into the floor, and one that starts above it would float.
const BASE_OFFSET := {
	"floor": 0.0,
	"floor_alt": 0.0,
	"floor_grate": 0.28,
	"wall": 0.0,
	"wall_b": 0.0,
	"wall_c": 0.0,
	"wall_cube": 0.0,
	"wall_low": 0.0,
	"doorway": 0.0,
	"column": 0.0,
	"pillar": 0.0,
	"crate": 0.0,
	"console": -0.74,
	"console_large": -0.74,
	"light_strip": 0.19,
	"light_corridor": 0.28,
	"pipes": 0.34,
	"wall_pipes": -1.34,
	"fence": 0.0,
	"sign_danger": 0.0,
	"word_zone": 0.0,
	"beam": 0.0,
}

## Footprint used for box colliders, in metres, before the placement scale.
const SIZE := {
	"floor": Vector3(6.0, 0.05, 6.0),
	"floor_alt": Vector3(6.0, 0.05, 6.0),
	"floor_grate": Vector3(1.5, 0.5, 5.0),
	"wall": Vector3(2.0, 4.0, 6.0),
	"wall_b": Vector3(2.0, 4.0, 6.0),
	"wall_c": Vector3(2.0, 4.0, 6.0),
	"wall_cube": Vector3(2.0, 4.0, 6.0),
	"wall_low": Vector3(2.0, 1.0, 6.0),
	"doorway": Vector3(5.0, 4.0, 1.0),
	"column": Vector3(4.0, 4.0, 0.5),
	"pillar": Vector3(2.0, 4.0, 2.0),
	"crate": Vector3(1.0, 0.75, 2.0),
	"console": Vector3(3.3, 2.8, 2.8),
	"console_large": Vector3(1.5, 2.8, 5.5),
	"light_strip": Vector3(0.9, 0.2, 0.1),
	"light_corridor": Vector3(1.0, 0.3, 3.5),
	"pipes": Vector3(1.7, 0.7, 4.0),
	"wall_pipes": Vector3(1.1, 1.6, 5.5),
	"fence": Vector3(0.25, 1.3, 5.0),
	"sign_danger": Vector3(0.02, 1.2, 2.4),
	"word_zone": Vector3(0.02, 1.2, 6.0),
	"beam": Vector3(0.25, 4.0, 4.4),
}

## Palette: the pack's own material names, given a dark industrial look. The
## result is deliberately a step away from the pastel KayKit exterior, so the
## arena reads as an interior bay and the horizon reads as outside.
const COLORS := {
	"orange": Color(0.95, 0.45, 0.1),
	"steel": Color(0.44, 0.47, 0.52),
	"steel_light": Color(0.56, 0.59, 0.64),
	"panel": Color(0.29, 0.32, 0.37),
	"trim": Color(0.16, 0.18, 0.22),
	"floor": Color(0.3, 0.33, 0.38),
	"glass": Color(0.35, 0.78, 0.92),
	"light": Color(0.62, 0.93, 1.0),
}

## Per-model policy, because the pack's material names are not reliable on their
## own: every floor tile, wall and crate shares a material literally named
## "Orange". Mapping that name straight to orange painted the whole arena orange,
## so the *model* decides what its "Orange" surface means.
const POLICY := {
	"floor": {"all": "floor"},
	"floor_alt": {"all": "floor"},
	"floor_grate": {"all": "steel_light"},
	"wall": {"Orange": "orange"},
	"wall_b": {"Orange": "orange"},
	"wall_c": {"Orange": "orange"},
	"wall_cube": {"Orange": "orange"},
	"wall_low": {"Orange": "orange"},
	"doorway": {"Orange": "steel_light"},
	"column": {"all": "steel"},
	"pillar": {"all": "steel"},
	"crate": {"Orange": "orange", "all": "panel"},
	"console": {"Orange": "light", "all": "panel"},
	"console_large": {"Orange": "light", "all": "panel"},
	"light_strip": {"all": "light"},
	"light_corridor": {"all": "light"},
	"pipes": {"all": "steel_light"},
	"wall_pipes": {"all": "steel"},
	"fence": {"all": "steel"},
	"sign_danger": {"all": "orange"},
	"word_zone": {"all": "light"},
	"beam": {"all": "steel"},
}

const DEFAULT_MATERIAL_KEYS := {
	"orange": "orange",
	"glass": "glass",
	"light": "light",
	"hd_wall": "steel",
	"stuff": "panel",
	"alpha": "trim",
	"wall": "trim",
	"floor": "floor",
	"toto": "floor",
}

static var _scenes: Dictionary = {}
static var _materials: Dictionary = {}


static func color_key_for(material_name: String) -> String:
	var lower := material_name.to_lower()
	for prefix in DEFAULT_MATERIAL_KEYS:
		if lower.begins_with(prefix):
			return DEFAULT_MATERIAL_KEYS[prefix]
	return "steel"


static func model(key: String) -> PackedScene:
	if _scenes.has(key):
		return _scenes[key]
	var file: String = MODELS.get(key, "")
	if file == "":
		push_error("ScifiKitLibrary has no model registered for '%s'" % key)
		return null
	var scene: PackedScene = load(ROOT + file + ".glb")
	_scenes[key] = scene
	return scene


static func base_offset(key: String) -> float:
	return float(BASE_OFFSET.get(key, 0.0))


static func size(key: String) -> Vector3:
	return SIZE.get(key, Vector3.ONE)


## One shared material per palette colour: the imported GLB materials are all
## plain white, so without this every surface in the bay renders the same.
static func material(color_key: String) -> StandardMaterial3D:
	if _materials.has(color_key):
		return _materials[color_key]
	var material := StandardMaterial3D.new()
	material.resource_name = "SciFi_" + color_key
	match color_key:
		"glass":
			material.albedo_color = Color(COLORS.glass, 0.24)
			material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
			material.metallic = 0.1
			material.roughness = 0.08
			material.emission_enabled = true
			material.emission = COLORS.glass
			material.emission_energy_multiplier = 0.35
		"light":
			material.albedo_color = COLORS.light
			material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
			material.emission_enabled = true
			material.emission = COLORS.light
			material.emission_energy_multiplier = 2.4
		"orange":
			material.albedo_color = COLORS.orange
			material.metallic = 0.05
			material.roughness = 0.55
		"floor":
			material.albedo_color = COLORS.floor
			material.metallic = 0.02
			material.roughness = 0.72
		_:
			material.albedo_color = COLORS.get(color_key, COLORS.steel)
			material.metallic = 0.06
			material.roughness = 0.62
	_materials[color_key] = material
	return material


## Resolves one surface's palette colour for one model, honouring the
## per-model policy first and the material-name fallback second.
static func surface_color_key(model_key: String, material_name: String) -> String:
	var policy: Dictionary = POLICY.get(model_key, {})
	if policy.has(material_name):
		return policy[material_name]
	if policy.has("all"):
		return policy["all"]
	return color_key_for(material_name)


## Replaces the blank imported materials surface by surface. Keeping the
## per-surface structure matters: a wall is plating plus an orange stripe, and a
## single material override would flatten it.
static func apply_palette(node: Node, model_key: String, emissive: bool = true) -> void:
	for child in node.find_children("*", "MeshInstance3D", true, false):
		var mesh_instance := child as MeshInstance3D
		var mesh := mesh_instance.mesh
		if mesh == null:
			continue
		for index in range(mesh.get_surface_count()):
			var source := mesh_instance.get_active_material(index)
			var material_name := ""
			if source != null:
				material_name = source.resource_name
			var key := surface_color_key(model_key, material_name)
			if key == "light" and not emissive:
				key = "steel_light"
			mesh_instance.set_surface_override_material(index, material(key))
