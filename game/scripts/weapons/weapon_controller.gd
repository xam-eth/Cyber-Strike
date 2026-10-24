class_name WeaponController
extends Node

signal weapon_changed(display_name: String)
signal shot_fired(weapon_id: StringName)
signal ammo_changed(remaining: int, capacity: int, reloading: bool)

@export var weapon_definitions: Array[WeaponDefinition] = []
@export_range(0, 5, 1) var initial_weapon_index: int = 0

var _current_weapon_index: int = 0
var _cooldowns: Array[float] = []
var _magazines: Array[int] = []
var _reload_remaining: Array[float] = []
## Main supplies the validated profile on boot/unlock. Direct slot keys and
## touch SWAP share this same gate, so a locked weapon cannot be fired via E/1-3.
var _available_ids: Dictionary = {"pulse_rifle": true}


func _ready() -> void:
	if weapon_definitions.is_empty():
		push_error("WeaponController requires at least one weapon definition.")
		return
	_cooldowns.resize(weapon_definitions.size())
	_cooldowns.fill(0.0)
	_magazines.resize(weapon_definitions.size())
	_reload_remaining.resize(weapon_definitions.size())
	_reload_remaining.fill(0.0)
	for index in range(weapon_definitions.size()):
		var definition: WeaponDefinition = weapon_definitions[index]
		if definition == null or not definition.is_valid_definition():
			push_error("WeaponController has an invalid definition at index %d." % index)
		else:
			_magazines[index] = definition.magazine_size
	_current_weapon_index = clampi(initial_weapon_index, 0, weapon_definitions.size() - 1)
	_emit_ammo()


func _process(delta: float) -> void:
	for index in range(_cooldowns.size()):
		_cooldowns[index] = maxf(_cooldowns[index] - delta, 0.0)
		if _reload_remaining[index] <= 0.0:
			continue
		_reload_remaining[index] = maxf(_reload_remaining[index] - delta, 0.0)
		if _reload_remaining[index] <= 0.0:
			_magazines[index] = weapon_definitions[index].magazine_size
			if index == _current_weapon_index:
				_emit_ammo()


func get_current_weapon_index() -> int:
	return _current_weapon_index


func get_current_weapon_name() -> String:
	var definition := get_current_definition()
	return definition.display_name if definition != null else ""


func get_current_definition() -> WeaponDefinition:
	if _current_weapon_index < 0 or _current_weapon_index >= weapon_definitions.size():
		return null
	return weapon_definitions[_current_weapon_index]


func get_current_ammo() -> int:
	return _magazines[_current_weapon_index] if _current_weapon_index < _magazines.size() else 0


func get_current_magazine_size() -> int:
	var definition := get_current_definition()
	return definition.magazine_size if definition != null else 0


func is_reloading() -> bool:
	return (
		_current_weapon_index < _reload_remaining.size()
		and _reload_remaining[_current_weapon_index] > 0.0
	)


func current_reload_remaining() -> float:
	if _current_weapon_index < 0 or _current_weapon_index >= _reload_remaining.size():
		return 0.0
	return _reload_remaining[_current_weapon_index]


## A fixed magazine provides the reload rhythm without a finite reserve that
## could strand a survival run. Touch players auto-reload at zero; G reloads early.
func request_reload() -> bool:
	var definition := get_current_definition()
	if definition == null or is_reloading() or get_current_ammo() >= definition.magazine_size:
		return false
	_reload_remaining[_current_weapon_index] = definition.reload_seconds
	_emit_ammo()
	return true


func reset_ammo() -> void:
	for index in range(_magazines.size()):
		var definition: WeaponDefinition = weapon_definitions[index]
		_magazines[index] = definition.magazine_size if definition != null else 0
		_cooldowns[index] = 0.0
		_reload_remaining[index] = 0.0
	_emit_ammo()


func _emit_ammo() -> void:
	ammo_changed.emit(get_current_ammo(), get_current_magazine_size(), is_reloading())


func set_available_weapon_ids(ids: Dictionary) -> void:
	_available_ids = ids.duplicate()
	# Pulse is the starter even when a save was edited or partially written.
	_available_ids["pulse_rifle"] = true
	if not is_weapon_available(_current_weapon_index):
		select_weapon(0)


func is_weapon_available(index: int) -> bool:
	if index < 0 or index >= weapon_definitions.size():
		return false
	var definition: WeaponDefinition = weapon_definitions[index]
	return definition != null and _available_ids.has(String(definition.weapon_id))


func available_weapon_count() -> int:
	var count := 0
	for index in range(weapon_definitions.size()):
		if is_weapon_available(index):
			count += 1
	return count


func select_weapon(index: int) -> bool:
	if not is_weapon_available(index):
		return false
	var definition: WeaponDefinition = weapon_definitions[index]
	if not definition.is_valid_definition():
		return false
	_current_weapon_index = index
	weapon_changed.emit(definition.display_name)
	_emit_ammo()
	return true


func select_next_weapon() -> bool:
	return _cycle_weapon(1)


func select_previous_weapon() -> bool:
	return _cycle_weapon(-1)


func _cycle_weapon(direction: int) -> bool:
	for offset in range(1, weapon_definitions.size() + 1):
		var index := posmod(_current_weapon_index + offset * direction, weapon_definitions.size())
		if is_weapon_available(index):
			return select_weapon(index)
	return false


func try_fire(shooter: CollisionObject3D, muzzle: Marker3D, aim_point: Vector3) -> bool:
	var definition := get_current_definition()
	if (
		definition == null
		or not definition.is_valid_definition()
		or _cooldowns[_current_weapon_index] > 0.0
		or is_reloading()
		or not is_instance_valid(shooter)
		or not is_instance_valid(muzzle)
	):
		return false
	if get_current_ammo() <= 0:
		request_reload()
		return false
	# The camera ray can see around a corner even when the rifle itself is
	# inside cover. Reject that shot before spawning a projectile, consuming a
	# round, or playing muzzle effects: an inside-origin ray on the projectile
	# alone may miss the wall and make the blast pass through solid geometry.
	if _muzzle_is_blocked(shooter, muzzle, definition.collision_mask):
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
	_magazines[_current_weapon_index] -= 1
	if _magazines[_current_weapon_index] == 0:
		request_reload()
	else:
		_emit_ammo()
	Sfx.play_shot(definition.weapon_id, muzzle.global_position)
	shot_fired.emit(definition.weapon_id)
	return true


func _muzzle_is_blocked(shooter: CollisionObject3D, muzzle: Marker3D, mask: int) -> bool:
	# Layer 1 is solid world cover; an enemy reaching the player's barrel on
	# layer 2 is still a valid close-range target, not a reason to dry-fire.
	var world_mask := mask & 1
	if world_mask == 0:
		return false
	var chest := shooter.global_position + Vector3.UP * 1.2
	var mouth := muzzle.global_position
	if chest.distance_squared_to(mouth) < 0.01:
		return false
	var excluded: Array[RID] = [shooter.get_rid()]
	var query := PhysicsRayQueryParameters3D.create(chest, mouth, world_mask, excluded)
	query.hit_from_inside = true
	return not shooter.get_world_3d().direct_space_state.intersect_ray(query).is_empty()
