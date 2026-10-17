class_name WeaponController
extends Node

signal weapon_changed(display_name: String)
signal shot_fired(weapon_id: StringName)

@export var weapon_definitions: Array[WeaponDefinition] = []
@export_range(0, 5, 1) var initial_weapon_index: int = 0

var _current_weapon_index: int = 0
var _cooldowns: Array[float] = []


func _ready() -> void:
	if weapon_definitions.is_empty():
		push_error("WeaponController requires at least one weapon definition.")
		return
	_cooldowns.resize(weapon_definitions.size())
	_cooldowns.fill(0.0)
	for index in range(weapon_definitions.size()):
		var definition: WeaponDefinition = weapon_definitions[index]
		if definition == null or not definition.is_valid_definition():
			push_error("WeaponController has an invalid definition at index %d." % index)
	_current_weapon_index = clampi(initial_weapon_index, 0, weapon_definitions.size() - 1)


func _process(delta: float) -> void:
	for index in range(_cooldowns.size()):
		_cooldowns[index] = maxf(_cooldowns[index] - delta, 0.0)


func get_current_weapon_index() -> int:
	return _current_weapon_index


func get_current_weapon_name() -> String:
	var definition := get_current_definition()
	return definition.display_name if definition != null else ""


func get_current_definition() -> WeaponDefinition:
	if _current_weapon_index < 0 or _current_weapon_index >= weapon_definitions.size():
		return null
	return weapon_definitions[_current_weapon_index]


func select_weapon(index: int) -> bool:
	if index < 0 or index >= weapon_definitions.size():
		return false
	var definition: WeaponDefinition = weapon_definitions[index]
	if definition == null or not definition.is_valid_definition():
		return false
	_current_weapon_index = index
	weapon_changed.emit(definition.display_name)
	return true


func select_next_weapon() -> bool:
	if weapon_definitions.is_empty():
		return false
	return select_weapon((_current_weapon_index + 1) % weapon_definitions.size())


func select_previous_weapon() -> bool:
	if weapon_definitions.is_empty():
		return false
	var previous_index := posmod(_current_weapon_index - 1, weapon_definitions.size())
	return select_weapon(previous_index)


func try_fire(shooter: CollisionObject3D, muzzle: Marker3D, aim_point: Vector3) -> bool:
	var definition := get_current_definition()
	if (
		definition == null
		or not definition.is_valid_definition()
		or _cooldowns[_current_weapon_index] > 0.0
		or not is_instance_valid(shooter)
		or not is_instance_valid(muzzle)
	):
		return false
	var projectile := definition.projectile_scene.instantiate() as Node3D
	if projectile == null or not projectile.has_method("launch"):
		if projectile != null:
			projectile.queue_free()
		push_error(
			(
				"Weapon '%s' projectile scene must create a Node3D with launch()."
				% definition.display_name
			)
		)
		return false
	var projectile_parent: Node = get_tree().current_scene
	if projectile_parent == null and is_instance_valid(shooter.get_parent()):
		projectile_parent = shooter.get_parent()
	if projectile_parent == null:
		projectile_parent = get_tree().root
	projectile_parent.add_child(projectile)
	projectile.call("launch", muzzle.global_position, aim_point, shooter, definition)
	_cooldowns[_current_weapon_index] = 1.0 / definition.fire_rate
	Sfx.play_shot(definition.weapon_id, muzzle.global_position)
	shot_fired.emit(definition.weapon_id)
	return true
