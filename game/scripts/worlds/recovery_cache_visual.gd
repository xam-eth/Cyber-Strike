extends Node3D

## View-only Recovery landmark. Main owns interaction and state; this node only
## fits the licensed model and presents the state it is given.
const ModelFitterScript = preload("res://scripts/visual/model_fitter.gd")

var model_scene_path: String = ""
var cache_title: String = "RECOVERY CACHE"
var _label: Label3D
var _light: OmniLight3D


func _ready() -> void:
	_build_model()
	_light = OmniLight3D.new()
	_light.name = "RecoverySignal"
	_light.position = Vector3(0.0, 1.1, 0.0)
	_light.omni_range = 4.0
	_light.light_energy = 1.1
	_light.shadow_enabled = false
	add_child(_light)

	_label = Label3D.new()
	_label.name = "RecoveryLabel"
	_label.position = Vector3(0.0, 1.65, 0.0)
	_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_label.font_size = 36
	_label.pixel_size = 0.009
	_label.outline_size = 8
	_label.outline_modulate = Color(0.02, 0.035, 0.05, 0.95)
	_label.no_depth_test = false
	add_child(_label)
	set_visual_state("GUARDED", AegisTokens.ACCENT)


func set_visual_state(state_text: String, color: Color) -> void:
	if is_instance_valid(_label):
		_label.text = "%s\n%s" % [cache_title, state_text]
		_label.modulate = color
	if is_instance_valid(_light):
		_light.light_color = color


func _build_model() -> void:
	var result := ContentModuleLoader.load_scene(model_scene_path, ContentModuleLoader.WORLD_ROOTS)
	var fitted: Dictionary = {}
	if bool(result["ok"]):
		# This prop is intentionally wide; fitting its height would make the
		# screen several metres across and obscure the authored landmark.
		fitted = ModelFitterScript.attach(
			self, result["scene"] as PackedScene, 1.8, 0.0, "CacheModelPivot", "CacheModel", 0
		)
	if not fitted.is_empty():
		return

	# Content failure cannot remove the mission interaction or its HUD. Keep a
	# small readable marker in place of the optional external GLB.
	var fallback := MeshInstance3D.new()
	fallback.name = "FallbackCache"
	var mesh := BoxMesh.new()
	mesh.size = Vector3(1.4, 0.8, 0.6)
	fallback.mesh = mesh
	fallback.position.y = 0.4
	var material := StandardMaterial3D.new()
	material.albedo_color = AegisTokens.INFO
	material.emission_enabled = true
	material.emission = AegisTokens.INFO
	material.emission_energy_multiplier = 0.35
	fallback.material_override = material
	add_child(fallback)
