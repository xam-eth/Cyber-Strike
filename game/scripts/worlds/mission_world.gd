extends Node3D

signal world_ready(world_id: String)
signal world_load_failed(world_id: String, reason: String)

## mission_world.gd — canonical world adapter for SH-01 Aetherfall.
##
## Instantiates the declared theatre scene (`res://scenes/worlds/aetherfall_world.tscn`)
## through `ContentModuleLoader`, supplies last-resort safety bounds below the
## glacial lowland floor, and keeps fallback lighting/wayfinders active even if
## a test fixture injects a failing environment path.
const DEFAULT_MISSION_WORLD_ID := "aetherfall"
const SELECTION_ALIASES := {
	"sh01": "aetherfall",
	"sentinel_citadel": "aetherfall",
}

const WORLD_WIDTH: float = 360.0
const WORLD_DEPTH: float = 320.0
const WORLD_CENTER_Z: float = -4.0

@export var animate_components: bool = true
@export var animation_speed: float = 1.0
@export var world_override: String = ""

var load_error: String = ""
var loaded_world_id: String = ""
var _built: bool = false
var _world: Node3D


func _ready() -> void:
	if _built or get_node_or_null("RealFrontierWorld") != null:
		return
	if not _is_selected():
		print(
			(
				"MISSION WORLD: not building %s (launcher selected '%s')"
				% [
					world_override if not world_override.is_empty() else DEFAULT_MISSION_WORLD_ID,
					String(WorldSelection.selected(self)),
				]
			)
		)
		return
	_built = true
	var loaded := _instance_real_world()
	_add_collision_floor()
	if loaded:
		if (
			_world.has_method("provides_authored_colliders")
			and bool(_world.call("provides_authored_colliders"))
		):
			print("MISSION WORLD: precision colliders provided by %s" % _world_id())
		else:
			_add_mesh_colliders()
	_build_lighting_and_atmosphere()
	_add_wayfinders()
	if loaded:
		world_ready.emit(_world_id())


func _is_selected() -> bool:
	if not world_override.is_empty():
		return true
	var selected := String(WorldSelection.selected(self))
	return selected == "" or not world_for_selection(selected).is_empty()


static func world_for_selection(selected: String) -> String:
	var candidate := String(SELECTION_ALIASES.get(selected, selected))
	var definition := WorldDefinition.load_definition(StringName(candidate))
	if definition != null and not definition.environment_scene_path.is_empty():
		return candidate
	return ""


func _world_id() -> String:
	if not world_override.is_empty():
		return world_override
	var selected := String(WorldSelection.selected(self))
	var resolved := world_for_selection(selected)
	if not resolved.is_empty():
		return resolved
	return DEFAULT_MISSION_WORLD_ID


func _instance_real_world() -> bool:
	var world_id := _world_id()
	loaded_world_id = ""
	load_error = ""
	var definition := WorldDefinition.load_definition(StringName(world_id))
	var scene_path := definition.environment_scene_path if definition != null else ""
	var result := ContentModuleLoader.load_scene(scene_path, ContentModuleLoader.WORLD_ROOTS)
	if not bool(result["ok"]):
		return _fail_world_load(world_id, String(result["code"]), String(result["message"]))
	var packed := result["scene"] as PackedScene
	var instance := packed.instantiate()
	if not instance is Node3D:
		if instance != null:
			instance.free()
		return _fail_world_load(world_id, "wrong_root", "World root must be Node3D.")
	_world = instance as Node3D
	_world.name = "RealFrontierWorld"
	_world.set_meta("world_id", world_id)
	add_child(_world)
	loaded_world_id = world_id
	print("MISSION WORLD: %s (%s)" % [world_id, scene_path.get_file()])
	for child in _world.find_children("*", "MeshInstance3D", true, false):
		var mesh_instance := child as MeshInstance3D
		var skip_shadow := false
		var cur: Node = mesh_instance
		while cur != null and cur != _world:
			if cur.has_meta("no_shadow_cast"):
				skip_shadow = true
				break
			cur = cur.get_parent()
		mesh_instance.cast_shadow = (
			GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			if skip_shadow
			else GeometryInstance3D.SHADOW_CASTING_SETTING_ON
		)
	_start_authored_motion()
	return true


func _fail_world_load(world_id: String, code: String, message: String) -> bool:
	load_error = "%s: %s" % [code, message]
	push_warning("MISSION WORLD: %s disabled (%s)" % [world_id, load_error])
	world_load_failed.emit(world_id, load_error)
	return false


func has_world_geometry() -> bool:
	return is_instance_valid(_world)


func _start_authored_motion() -> void:
	if not is_instance_valid(_world):
		return
	if (
		_world.has_method("provides_authored_motion")
		and bool(_world.call("provides_authored_motion"))
	):
		for child in _world.find_children("*", "AnimationPlayer", true, false):
			var ap := child as AnimationPlayer
			ap.speed_scale = animation_speed if animate_components else 0.0
		return
	var found := _world.find_children("*", "AnimationPlayer", true, false)
	if found.is_empty():
		return
	var imported := found[0] as AnimationPlayer
	imported.name = "MotionLibrary"
	imported.active = false
	for clip_name in imported.get_animation_list():
		var animation := imported.get_animation(clip_name)
		if animation == null:
			continue
		animation.loop_mode = Animation.LOOP_LINEAR
		var player := AnimationPlayer.new()
		player.name = "Clip_%s" % clip_name.validate_node_name()
		var library := AnimationLibrary.new()
		library.add_animation(clip_name, animation)
		player.add_animation_library("", library)
		_world.add_child(player)
		player.speed_scale = animation_speed if animate_components else 0.0
		player.play(clip_name)
	if not animate_components:
		imported.speed_scale = 0.0


func _field_size() -> Vector2:
	var definition := WorldDefinition.load_definition(StringName(_world_id()))
	if definition != null:
		return definition.field_size
	return Vector2(WORLD_WIDTH, WORLD_DEPTH)


func _field_center() -> Vector2:
	var definition := WorldDefinition.load_definition(StringName(_world_id()))
	if definition != null:
		return definition.field_center
	return Vector2(0.0, WORLD_CENTER_Z)


func _field_center_z() -> float:
	return _field_center().y


func _add_collision_floor() -> void:
	var field := _field_size()
	var center := _field_center()
	var center_z := center.y
	var floor_body := StaticBody3D.new()
	floor_body.name = "ArenaFloor"
	# Sits below Aetherfall's glacial lowland (-18.5 m) so ramps and lower valleys
	# remain fully traversable while guaranteeing a last-resort void catch.
	floor_body.position = Vector3(center.x, -22.4, center_z)
	floor_body.collision_layer = 1
	floor_body.collision_mask = 0
	var floor_shape := CollisionShape3D.new()
	floor_shape.name = "ArenaFloorCollisionShape"
	var shape := BoxShape3D.new()
	shape.size = Vector3(field.x, 0.8, field.y)
	floor_shape.shape = shape
	floor_body.add_child(floor_shape)
	add_child(floor_body)

	var walls := StaticBody3D.new()
	walls.name = "FrontierBounds"
	walls.collision_layer = 1
	walls.collision_mask = 0
	add_child(walls)
	var half_w := field.x * 0.5
	var half_d := field.y * 0.5
	for side in [
		{"name": "North", "pos": Vector3(center.x, 2.0, center_z - half_d)},
		{"name": "South", "pos": Vector3(center.x, 2.0, center_z + half_d)},
		{"name": "West", "pos": Vector3(center.x - half_w, 2.0, center_z)},
		{"name": "East", "pos": Vector3(center.x + half_w, 2.0, center_z)},
	]:
		var wall := CollisionShape3D.new()
		wall.name = "%sWall" % side["name"]
		var wall_shape := BoxShape3D.new()
		wall_shape.size = (
			Vector3(field.x, 48.0, 1.0)
			if side["name"] in ["North", "South"]
			else Vector3(1.0, 48.0, field.y)
		)
		wall.shape = wall_shape
		wall.position = side["pos"]
		walls.add_child(wall)


func _add_mesh_colliders() -> void:
	if not is_instance_valid(_world):
		return
	var made := 0
	for candidate in _world.find_children("*", "MeshInstance3D", true, false):
		var mesh_instance := candidate as MeshInstance3D
		if mesh_instance.mesh == null:
			continue
		mesh_instance.create_trimesh_collision()
		made += 1
	print("MISSION WORLD: %d %s mesh colliders derived from the real world" % [made, _world_id()])


func _build_lighting_and_atmosphere() -> void:
	if (
		is_instance_valid(_world)
		and _world.has_method("provides_authored_lighting")
		and bool(_world.call("provides_authored_lighting"))
	):
		print("MISSION WORLD: lit as %s" % WorldMood.label(_world_id()))
		return

	var mood := WorldMood.mood(_world_id())
	for role in ["key", "fill", "rim"]:
		var spec: Dictionary = mood[role]
		var light := DirectionalLight3D.new()
		light.name = String(spec["name"])
		light.light_color = spec["color"]
		light.light_energy = spec["energy"]
		light.shadow_enabled = role == "key"
		if light.shadow_enabled:
			light.shadow_opacity = 0.58
			light.directional_shadow_max_distance = 220.0
		add_child(light)
		var target := Vector3(0.0, 0.0, _field_center_z())
		var light_position: Vector3 = spec["position"]
		var up := Vector3.UP
		if absf((target - light_position).normalized().dot(up)) > 0.999:
			up = Vector3.FORWARD
		light.look_at_from_position(light_position, target, up)
		light.rotation.z = 0.0

	var accent := OmniLight3D.new()
	accent.name = "MissionAccentLight"
	accent.position = Vector3(0.0, 5.4, 0.0)
	accent.light_color = mood["accent"]
	accent.light_energy = mood["accent_energy"]
	accent.omni_range = mood["accent_range"]
	accent.shadow_enabled = false
	add_child(accent)

	var environment := Environment.new()
	environment.background_mode = Environment.BG_COLOR
	environment.background_color = mood["sky"]
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = mood["ambient"]
	environment.ambient_light_energy = mood["ambient_energy"]
	environment.tonemap_mode = Environment.TONE_MAPPER_ACES
	environment.tonemap_exposure = mood["exposure"]
	environment.tonemap_white = 6.0
	environment.ssao_enabled = true
	environment.ssao_radius = 2.4
	environment.glow_enabled = true
	environment.glow_intensity = mood["glow"]
	environment.glow_bloom = 0.12
	environment.fog_enabled = true
	environment.fog_light_color = mood["fog"]
	environment.fog_density = mood["fog_density"]
	environment.adjustment_enabled = true
	environment.adjustment_saturation = mood["saturation"]
	environment.adjustment_contrast = mood["contrast"]

	var world_environment := WorldEnvironment.new()
	world_environment.name = "ArenaEnvironment"
	world_environment.environment = environment
	add_child(world_environment)
	print("MISSION WORLD: lit as %s" % WorldMood.label(_world_id()))


func _add_wayfinders() -> void:
	for entry in [
		{"name": "NorthRouteWayfinder", "pos": Vector3(8.0, 1.6, -14.3)},
		{"name": "SouthRouteWayfinder", "pos": Vector3(0.0, 1.6, 18.0)},
	]:
		var marker := Marker3D.new()
		marker.name = entry["name"]
		marker.position = entry["pos"]
		add_child(marker)
