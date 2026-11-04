class_name FieldActivityDirector
extends Node3D

## Orchestrates Aetherfall's active field ecology:
##   1) Destructible armored Supply Crates scattered across outpost & basin lanes
##   2) Ambient 3D Collectible Shards (BP Shards, Cryo-Alloy, Plasma Cells)
##   3) Physical 3D Loot Bursts from defeated WaveDirector & Patrol robot units
##   4) Roaming 3D Robot Sector Patrols that engage as the player advances out of
##      Arrival Outpost (keeping the western landing zone & WaveDirector counts clean).

signal pickup_collected(kind: StringName, amount: int, world_position: Vector3)
signal supply_crate_broken(world_position: Vector3, crate_tier: int)
signal field_target_hit
signal patrol_robot_defeated(
	score_reward: int, bp_reward: int, world_position: Vector3, kind_id: StringName
)

const RUNNER_SCENE_PATH := "res://scenes/enemies/runner_enemy.tscn"
const SHOOTER_SCENE_PATH := "res://scenes/enemies/shooter_enemy.tscn"
const ENFORCER_SCENE_PATH := "res://scenes/enemies/enforcer_enemy.tscn"

const MAX_ACTIVE_PICKUPS := 38
const CRATE_SPECS := [
	{"pos": Vector3(-24.8, 0.25, 14.3), "yaw": 18.0, "tier": 1},
	{"pos": Vector3(-19.4, 0.25, 5.8), "yaw": -24.0, "tier": 2},
	{"pos": Vector3(-12.2, 0.25, 12.6), "yaw": 12.0, "tier": 1},
	{"pos": Vector3(-4.5, 0.25, 6.4), "yaw": -32.0, "tier": 2},
	{"pos": Vector3(2.8, 0.25, 15.6), "yaw": 28.0, "tier": 1},
	{"pos": Vector3(13.8, 0.25, 3.2), "yaw": -15.0, "tier": 2},
	{"pos": Vector3(3.6, 0.25, -7.2), "yaw": 40.0, "tier": 1},
	{"pos": Vector3(14.6, 0.25, -14.2), "yaw": -22.0, "tier": 2},
	{"pos": Vector3(22.4, 0.25, 6.2), "yaw": 16.0, "tier": 1},
	{"pos": Vector3(33.8, 0.25, 15.8), "yaw": -35.0, "tier": 2},
]

const AMBIENT_PICKUP_SPECS := [
	{"kind": &"bp_shard", "amount": 10, "pos": Vector3(-17.8, 0.25, 10.6)},
	{"kind": &"cryo_alloy", "amount": 1, "pos": Vector3(-14.6, 0.25, 8.2)},
	{"kind": &"bp_shard", "amount": 10, "pos": Vector3(-8.4, 0.25, 9.8)},
	{"kind": &"plasma_cell", "amount": 1, "pos": Vector3(-1.8, 0.25, 11.4)},
	{"kind": &"cryo_alloy", "amount": 1, "pos": Vector3(4.2, 0.25, 3.4)},
	{"kind": &"bp_shard", "amount": 15, "pos": Vector3(14.4, 0.25, 12.4)},
	{"kind": &"med_injector", "amount": 32, "pos": Vector3(-2.6, 0.25, -3.6)},
	{"kind": &"cryo_alloy", "amount": 1, "pos": Vector3(13.2, 0.25, -8.4)},
	{"kind": &"bp_shard", "amount": 15, "pos": Vector3(18.6, 0.25, 9.4)},
	{"kind": &"plasma_cell", "amount": 1, "pos": Vector3(24.2, 0.25, 13.8)},
	{"kind": &"cryo_alloy", "amount": 1, "pos": Vector3(34.6, 0.25, 6.4)},
	{"kind": &"med_injector", "amount": 32, "pos": Vector3(25.6, 0.25, 7.6)},
]

const PATROL_ZONES := [
	{
		"trigger_x": -15.5,
		"units":
		[
			{"kind": &"runner", "pos": Vector3(-3.2, 0.35, 13.4)},
			{"kind": &"shooter", "pos": Vector3(1.6, 0.35, 6.8)},
		],
	},
	{
		"trigger_x": 0.5,
		"units":
		[
			{"kind": &"runner", "pos": Vector3(4.8, 0.35, -5.8)},
			{"kind": &"enforcer", "pos": Vector3(16.4, 0.35, 3.8)},
		],
	},
]

var target_player: Node3D = null
var _pickups_root: Node3D
var _crates_root: Node3D
var _patrols_root: Node3D
var _patrol_units: Array[Node3D] = []
var _rng := RandomNumberGenerator.new()
var _spawned_patrol_zones: Dictionary = {}
var _runner_scene: PackedScene
var _shooter_scene: PackedScene
var _enforcer_scene: PackedScene


func _ready() -> void:
	name = "FieldActivityDirector"
	_rng.seed = 0xAE74E11
	_pickups_root = Node3D.new()
	_pickups_root.name = "Pickups"
	add_child(_pickups_root)
	_crates_root = Node3D.new()
	_crates_root.name = "SupplyCrates"
	add_child(_crates_root)
	_patrols_root = Node3D.new()
	_patrols_root.name = "SectorPatrols"
	add_child(_patrols_root)


func configure(player_node: Node3D) -> void:
	target_player = player_node
	reset_field_activity()


func reset_field_activity() -> void:
	_clear_children(_pickups_root)
	_clear_children(_crates_root)
	_clear_children(_patrols_root)
	_patrol_units.clear()
	_spawned_patrol_zones.clear()
	_rng.seed = 0xAE74E11
	_populate_supply_crates()
	_populate_ambient_pickups()


func set_patrols_paused(paused: bool) -> void:
	if not is_instance_valid(_patrols_root):
		return
	for child in _patrols_root.get_children():
		child.set_physics_process(not paused)
		child.set_process(not paused)


func clear_patrols() -> void:
	_clear_children(_patrols_root)


func active_pickup_count() -> int:
	return _pickups_root.get_child_count() if is_instance_valid(_pickups_root) else 0


func active_crate_count() -> int:
	return _crates_root.get_child_count() if is_instance_valid(_crates_root) else 0


func _process(_delta: float) -> void:
	if not is_instance_valid(target_player):
		return
	if not target_player.is_physics_processing():
		return
	_activate_nearby_patrols()
	var dist_moved: Variant = target_player.get("_distance_travelled")
	if dist_moved != null and float(dist_moved) < 0.35:
		return
	var px := target_player.global_position.x
	for idx in range(PATROL_ZONES.size()):
		if _spawned_patrol_zones.has(idx):
			continue
		var zone: Dictionary = PATROL_ZONES[idx]
		if px >= float(zone["trigger_x"]):
			_spawned_patrol_zones[idx] = true
			_spawn_patrol_zone(zone["units"] as Array)


## Sector patrols stand frozen until the player closes to engagement range (or shoots one).
func _activate_nearby_patrols() -> void:
	if _patrol_units.is_empty():
		return
	var player_pos: Vector3 = target_player.global_position
	for unit in _patrol_units:
		if not is_instance_valid(unit) or unit.has_meta("patrol_active"):
			continue
		if player_pos.distance_squared_to(unit.global_position) <= 14.0 * 14.0:
			_activate_patrol_unit(unit)


func _activate_patrol_unit(unit: Node3D) -> void:
	if not is_instance_valid(unit) or unit.has_meta("patrol_active"):
		return
	unit.set_meta("patrol_active", true)
	unit.set_physics_process(true)
	unit.set_process(true)
	if unit.has_method("set_target"):
		unit.call("set_target", target_player)


func spawn_enemy_drops(enemy: Node3D, is_guardian: bool = false) -> void:
	if not is_instance_valid(enemy):
		return
	var origin := enemy.global_position
	var ground_y := maxf(origin.y, 0.25)
	if is_guardian:
		_spawn_scattered_pickup(FieldPickup.KIND_BP_SHARD, 25, origin, ground_y, 0, 4)
		_spawn_scattered_pickup(FieldPickup.KIND_CRYO_ALLOY, 1, origin, ground_y, 1, 4)
		_spawn_scattered_pickup(FieldPickup.KIND_MED_INJECTOR, 40, origin, ground_y, 2, 4)
		_spawn_scattered_pickup(FieldPickup.KIND_PLASMA_CELL, 1, origin, ground_y, 3, 4)
		return

	_spawn_scattered_pickup(FieldPickup.KIND_BP_SHARD, 10, origin, ground_y, 0, 2)
	var roll := _rng.randf()
	if roll < 0.42:
		_spawn_scattered_pickup(FieldPickup.KIND_CRYO_ALLOY, 1, origin, ground_y, 1, 2)
	elif roll < 0.72:
		_spawn_scattered_pickup(FieldPickup.KIND_PLASMA_CELL, 1, origin, ground_y, 1, 2)
	elif roll < 0.92:
		_spawn_scattered_pickup(FieldPickup.KIND_MED_INJECTOR, 28, origin, ground_y, 1, 2)


func _populate_supply_crates() -> void:
	for entry in CRATE_SPECS:
		var spec: Dictionary = entry
		var crate := SupplyCrate.new()
		crate.configure(
			spec["pos"] as Vector3, float(spec.get("yaw", 0.0)), int(spec.get("tier", 1))
		)
		crate.crate_damaged.connect(func() -> void: field_target_hit.emit())
		crate.crate_broken.connect(_on_supply_crate_broken)
		_crates_root.add_child(crate)


func _populate_ambient_pickups() -> void:
	for entry in AMBIENT_PICKUP_SPECS:
		var spec: Dictionary = entry
		var pos: Vector3 = spec["pos"]
		_spawn_pickup(StringName(spec["kind"]), int(spec["amount"]), pos, pos.y, Vector3.ZERO)


func _on_supply_crate_broken(world_pos: Vector3, tier: int) -> void:
	supply_crate_broken.emit(world_pos, tier)
	var ground_y := maxf(world_pos.y, 0.25)
	_spawn_scattered_pickup(
		FieldPickup.KIND_BP_SHARD, 15 if tier == 2 else 10, world_pos, ground_y, 0, 3
	)
	_spawn_scattered_pickup(FieldPickup.KIND_CRYO_ALLOY, 1, world_pos, ground_y, 1, 3)
	var bonus_kind := FieldPickup.KIND_PLASMA_CELL if tier == 2 else FieldPickup.KIND_MED_INJECTOR
	var bonus_amt := 1 if bonus_kind == FieldPickup.KIND_PLASMA_CELL else 30
	_spawn_scattered_pickup(bonus_kind, bonus_amt, world_pos, ground_y, 2, 3)


func _spawn_scattered_pickup(
	kind: StringName, amount: int, origin: Vector3, ground_y: float, slot: int, total: int
) -> void:
	var base_angle := TAU * float(slot) / float(maxi(total, 1)) + _rng.randf_range(-0.32, 0.32)
	var speed := _rng.randf_range(2.6, 4.1)
	var vel := Vector3(cos(base_angle) * speed, _rng.randf_range(4.6, 6.2), sin(base_angle) * speed)
	_spawn_pickup(kind, amount, origin + Vector3(0.0, 0.55, 0.0), ground_y, vel)


func _spawn_pickup(
	kind: StringName, amount: int, spawn_pos: Vector3, ground_y: float, vel: Vector3
) -> FieldPickup:
	if _pickups_root.get_child_count() >= MAX_ACTIVE_PICKUPS:
		var oldest := _pickups_root.get_child(0)
		if is_instance_valid(oldest):
			oldest.queue_free()
	var pickup := FieldPickup.new()
	pickup.target_player = target_player
	pickup.configure(kind, amount, spawn_pos, ground_y, vel)
	pickup.collected.connect(_on_pickup_collected)
	_pickups_root.add_child(pickup)
	return pickup


func _on_pickup_collected(kind: StringName, amount: int, world_pos: Vector3) -> void:
	match kind:
		FieldPickup.KIND_BP_SHARD:
			Sfx.play_ui(&"pickup_bp")
		FieldPickup.KIND_CRYO_ALLOY:
			Sfx.play_ui(&"pickup_alloy")
		_:
			Sfx.play_ui(&"pickup_power")
	pickup_collected.emit(kind, amount, world_pos)


func _spawn_patrol_zone(units: Array) -> void:
	_ensure_enemy_scenes()
	for item in units:
		var spec: Dictionary = item
		var kind := StringName(spec.get("kind", &"runner"))
		var scene := _scene_for_kind(kind)
		if scene == null:
			continue
		var enemy := scene.instantiate() as Node3D
		if enemy == null:
			continue
		enemy.position = spec["pos"] as Vector3
		# Frozen sentry: AI stays off until the player closes in or lands a shot.
		enemy.set_physics_process(false)
		enemy.set_process(false)
		if enemy.has_signal("damage_received"):
			enemy.connect(
				"damage_received",
				func(_a: float, _c: float, _m: float) -> void:
					_activate_patrol_unit(enemy)
					field_target_hit.emit()
			)
		if enemy.has_signal("defeated"):
			enemy.connect("defeated", _on_patrol_unit_defeated.bind(enemy, kind))
		_patrols_root.add_child(enemy)
		_patrol_units.append(enemy)


func _on_patrol_unit_defeated(enemy: Node3D, kind: StringName) -> void:
	var pos := enemy.global_position if is_instance_valid(enemy) else Vector3.ZERO
	spawn_enemy_drops(enemy, false)
	var bp := 16 if kind == &"enforcer" else (12 if kind == &"shooter" else 10)
	var score := 140 if kind == &"enforcer" else (110 if kind == &"shooter" else 90)
	patrol_robot_defeated.emit(score, bp, pos, kind)


func _ensure_enemy_scenes() -> void:
	if _runner_scene == null:
		_runner_scene = load(RUNNER_SCENE_PATH) as PackedScene
	if _shooter_scene == null:
		_shooter_scene = load(SHOOTER_SCENE_PATH) as PackedScene
	if _enforcer_scene == null:
		_enforcer_scene = load(ENFORCER_SCENE_PATH) as PackedScene


func _scene_for_kind(kind: StringName) -> PackedScene:
	match kind:
		&"shooter":
			return _shooter_scene
		&"enforcer":
			return _enforcer_scene
		_:
			return _runner_scene


func _clear_children(container: Node) -> void:
	if not is_instance_valid(container):
		return
	for child in container.get_children():
		container.remove_child(child)
		child.queue_free()


static func apply_pickup_effect(
	kind: StringName, amount: int, player_node: Node, stats_node: Node, upgrade_mgr: Node
) -> Dictionary:
	match kind:
		FieldPickup.KIND_BP_SHARD:
			stats_node.call("collect_field_bp", amount, 75)
			return {"text": "◆ +%d BLUEPRINT DATA" % amount, "color": AegisTokens.ACCENT}
		FieldPickup.KIND_CRYO_ALLOY:
			var total_alloy := int(stats_node.call("collect_cryo_alloy", amount, 60))
			player_node.call("_grant_overshield", 12.0)
			if total_alloy > 0 and (total_alloy % 3) == 0:
				upgrade_mgr.call("record_milestone", "cryo_alloy_%d" % total_alloy)
				return {
					"text": "⬢ CRYO-ALLOY 3/3 · EVOLUTION READY",
					"color": AegisTokens.INFO,
				}
			return {
				"text": "⬢ +1 CRYO-ALLOY (%d/3) · +12 SHD" % (total_alloy % 3),
				"color": AegisTokens.INFO,
			}
		FieldPickup.KIND_MED_INJECTOR:
			stats_node.call("record_pickup_collected", 40)
			var heal_res: Dictionary = player_node.call("_heal_or_shield", float(amount))
			var healed := roundi(float(heal_res.get("healed", 0.0)))
			var shd := roundi(float(heal_res.get("shielded", 0.0)))
			if healed > 0:
				return {"text": "✚ +%d HP NANO-REPAIR" % healed, "color": AegisTokens.OK}
			return {
				"text": "✚ +%d OVERSHIELD BOOST" % maxi(shd, 1),
				"color": AegisTokens.INFO,
			}
		_:
			stats_node.call("record_pickup_collected", 45)
			player_node.call("_grant_weapon_overcharge", 6.0)
			return {"text": "⚡ MAG FULL · OVERCHARGE 6s", "color": Color(0.76, 0.48, 1.0)}
