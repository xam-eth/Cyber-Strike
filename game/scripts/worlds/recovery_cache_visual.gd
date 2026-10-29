extends Node3D

## View-only Recovery landmark. Main owns interaction and state; this node only
## fits the licensed model and presents the state and guidance focus it is given.
const ModelFitterScript = preload("res://scripts/visual/model_fitter.gd")

var model_scene_path: String = ""
var cache_title: String = "RECOVERY CACHE"
var _label: Label3D
var _light: OmniLight3D
var _beacon: MeshInstance3D
var _beacon_material: StandardMaterial3D
var _state_color: Color = AegisTokens.ACCENT


func _ready() -> void:
	_build_model()
	_light = OmniLight3D.new()
	_light.name = "RecoverySignal"
	_light.position = Vector3(0.0, 1.1, 0.0)
	_light.omni_range = 4.5
	_light.light_energy = 1.15
	_light.shadow_enabled = false
	add_child(_light)

	_beacon = MeshInstance3D.new()
	_beacon.name = "GuidanceBeacon"
	var shaft := CylinderMesh.new()
	shaft.top_radius = 0.025
	shaft.bottom_radius = 0.14
	shaft.height = 6.5
	shaft.radial_segments = 12
	_beacon.mesh = shaft
	_beacon.position = Vector3(0.0, 3.6, 0.0)
	_beacon.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_beacon_material = StandardMaterial3D.new()
	_beacon_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_beacon_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_beacon_material.cull_mode = BaseMaterial3D.CULL_DISABLED
	_beacon_material.albedo_color = Color(AegisTokens.ACCENT, 0.22)
	_beacon.material_override = _beacon_material
	add_child(_beacon)

	_label = Label3D.new()
	_label.name = "RecoveryLabel"
	_label.position = Vector3(0.0, 1.85, 0.0)
	_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_label.font_size = 36
	_label.pixel_size = 0.009
	_label.outline_size = 8
	_label.outline_modulate = Color(0.02, 0.035, 0.05, 0.95)
	_label.no_depth_test = false
	add_child(_label)
	set_visual_state("GUARDED", AegisTokens.ACCENT)
	set_guidance_focus(false, false)


func set_visual_state(state_text: String, color: Color) -> void:
	_state_color = color
	if is_instance_valid(_label):
		_label.text = "%s\n%s" % [cache_title, state_text]
		_label.modulate = color
	if is_instance_valid(_light):
		_light.light_color = color
	if is_instance_valid(_beacon_material):
		var alpha := _beacon_material.albedo_color.a
		_beacon_material.albedo_color = Color(color, alpha)


func set_guidance_focus(is_target: bool, stuck_boost: bool) -> void:
	if is_instance_valid(_beacon):
		_beacon.visible = is_target
		_beacon.scale = Vector3(1.2, 1.35, 1.2) if stuck_boost else Vector3.ONE
	if is_instance_valid(_beacon_material):
		var alpha := 0.42 if stuck_boost else 0.20
		_beacon_material.albedo_color = Color(_state_color, alpha)
	if is_instance_valid(_label):
		# Only lift depth occlusion when a player is genuinely disoriented so
		# normal close-quarters sightlines stay grounded in world geometry.
		_label.no_depth_test = is_target and stuck_boost


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
