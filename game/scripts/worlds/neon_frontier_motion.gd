@tool
extends Node3D
## Runtime motion for one placed world component.
##
## `neon_frontier_asset.gd` builds every component out of named meshes, and an
## AnimationPlayer per component would mean hand-authoring a track for each of
## the forty-odd placements in the world. Instead this node rides along inside a
## component and animates the few meshes that *should* move, from one data table:
## halos spin, radar dishes scan, turret housings sweep, beacons pulse.
##
## Rules are matched by node-name prefix and never by index, because Godot
## renames duplicate siblings (`LandingPadBeaconLens`, `LandingPadBeaconLens2`,
## …) and an index-based rule silently animates the wrong beacon.
##
## Modes
##   spin   — continuous rotation on one axis
##   sweep  — oscillation around the rest rotation
##   bob    — vertical oscillation around the rest position
##   pulse  — oscillation around the rest scale
##
## Nothing runs in the editor (`Engine.is_editor_hint()`), so opening the world
## scene stays cheap; the motion is a game-time effect by design.

const TAU_LOCAL := TAU

## One row per asset kind. `speed` is radians (or cycles) per second, so the
## numbers are directly comparable across components.
const RULES: Dictionary = {
	"reactor_core": [
		{"match": "ContainmentLowerHalo", "mode": "spin", "axis": "y", "speed": 0.55},
		{"match": "ContainmentUpperHalo", "mode": "spin", "axis": "y", "speed": -0.42},
		{"match": "ReactorServiceRing", "mode": "spin", "axis": "y", "speed": 0.22},
		{"match": "ReactorWarningRing", "mode": "spin", "axis": "y", "speed": -0.34},
		{"match": "SuspendedReactorSeed", "mode": "pulse", "amount": 0.05, "speed": 2.1},
		{"match": "EmeraldEnergyColumn", "mode": "pulse", "amount": 0.03, "speed": 1.4},
		{"match": "ReactorBeacon", "mode": "pulse", "amount": 0.18, "speed": 3.4},
	],
	"command_center": [
		{"match": "CommandAntennaDish", "mode": "spin", "axis": "y", "speed": 0.6},
		{"match": "CommandRoofBeaconLens", "mode": "pulse", "amount": 0.22, "speed": 3.0},
		{"match": "CommandMainDoor", "mode": "bob", "amount": 0.06, "speed": 0.9},
	],
	"research_lab": [
		{"match": "ResearchSampleColumn", "mode": "pulse", "amount": 0.06, "speed": 2.6},
		{"match": "ResearchVesselRing", "mode": "spin", "axis": "y", "speed": 0.8},
		{
			"match": "ResearchMaintenanceArm",
			"mode": "sweep",
			"axis": "y",
			"amount": 0.5,
			"speed": 0.7,
		},
		{"match": "ResearchRoofPod", "mode": "sweep", "axis": "x", "amount": 0.08, "speed": 1.1},
	],
	"equipment_depot": [
		{"match": "SciFiEquipmentDepotFacade", "mode": "bob", "amount": 0.02, "speed": 1.2},
	],
	"generator_bank": [
		{"match": "GeneratorEnergyColumn", "mode": "pulse", "amount": 0.07, "speed": 2.4},
		{"match": "GeneratorCrown", "mode": "spin", "axis": "y", "speed": 0.5},
		{"match": "GeneratorManifoldGlow", "mode": "pulse", "amount": 0.16, "speed": 3.8},
	],
	"landing_pad": [
		{"match": "LandingPadBeaconLens", "mode": "pulse", "amount": 0.3, "speed": 3.2},
		{"match": "LandingPadCenterStroke", "mode": "pulse", "amount": 0.08, "speed": 1.6},
	],
	"boss_gate": [
		{"match": "BossGateHeaderEnergy", "mode": "pulse", "amount": 0.05, "speed": 1.8},
		{"match": "BossGateShutterLight", "mode": "pulse", "amount": 0.35, "speed": 4.2},
		{"match": "BossGateEnergyRail", "mode": "pulse", "amount": 0.04, "speed": 2.6},
		{"match": "BossGateConduitNode", "mode": "spin", "axis": "z", "speed": 1.1},
	],
	"defense_turret": [
		{"match": "TurretHousing", "mode": "sweep", "axis": "y", "amount": 0.85, "speed": 0.55},
		{"match": "TurretBarrel", "mode": "bob", "amount": 0.05, "speed": 2.2, "axis": "z"},
		{"match": "TurretSensor", "mode": "pulse", "amount": 0.14, "speed": 2.8},
	],
	"sensor_tower": [
		{"match": "SensorTowerRadar", "mode": "spin", "axis": "y", "speed": 1.3},
		{"match": "SensorTowerDish", "mode": "sweep", "axis": "y", "amount": 0.45, "speed": 0.8},
		{"match": "SensorTowerAntenna", "mode": "sweep", "axis": "z", "amount": 0.04, "speed": 1.4},
		{"match": "SensorTowerBandLight", "mode": "pulse", "amount": 0.1, "speed": 2.0},
	],
	"wrecked_transport": [
		{"match": "TransportFireGlow", "mode": "pulse", "amount": 0.35, "speed": 5.2},
		{"match": "TransportEngineGlow", "mode": "pulse", "amount": 0.22, "speed": 3.6},
	],
	"alien_drone_wreck": [
		{"match": "DroneCoreLens", "mode": "pulse", "amount": 0.22, "speed": 1.6},
		{"match": "DroneSparkingCable", "mode": "pulse", "amount": 0.5, "speed": 7.0},
	],
	# `props.gd` builds these; shards and lanterms are separate meshes, so the
	# prefix matters — "Crystal" would also catch "CrystalRoot".
	"crystal_cluster": [
		{"match": "CrystalShard", "mode": "pulse", "amount": 0.035, "speed": 1.1},
		{"match": "CrystalSmallShard", "mode": "pulse", "amount": 0.05, "speed": 1.6},
		{"match": "FloraLantern", "mode": "pulse", "amount": 0.2, "speed": 2.4},
	],
	"alien_flora": [
		{"match": "FloraArchingFrond", "mode": "sweep", "axis": "z", "amount": 0.07, "speed": 1.5},
		{"match": "FloraStem", "mode": "sweep", "axis": "z", "amount": 0.04, "speed": 1.2},
		{"match": "FloraLantern", "mode": "pulse", "amount": 0.18, "speed": 2.6},
	],
	"rock_cluster": [],
	"enemy_spawn_gate": [
		{"match": "SpawnGateEnergyLintel", "mode": "pulse", "amount": 0.09, "speed": 1.9},
		{"match": "SpawnGateBeacon", "mode": "pulse", "amount": 0.28, "speed": 3.6},
	],
	"cover_module": [
		{"match": "CoverModuleSignal", "mode": "pulse", "amount": 0.3, "speed": 2.6},
	],
}

## Set by `_place_component` before this node enters the tree.
var asset_kind: String = ""

var _targets: Array[Dictionary] = []
var _time: float = 0.0
var _phase: float = 0.0
var _collected: bool = false


func _ready() -> void:
	# Deterministic per-placement phase offset so two identical turrets do not
	# sweep in lockstep, without any random number generator in the loop.
	_phase = fmod(absf(global_position.x * 0.37 + global_position.z * 0.11), TAU_LOCAL)


func _process(delta: float) -> void:
	if Engine.is_editor_hint():
		return
	if not _collected:
		_collect()
	_time += delta
	for target in _targets:
		_apply(target)


## Find every mesh whose name starts with a rule's `match` and cache its rest
## transform, once. Deferred until the first frame because a component builds its
## children in its own `_ready`, which runs *after* its children are ready.
func _collect() -> void:
	_collected = true
	var parent_node := get_parent()
	if parent_node == null:
		return
	var rules: Array = RULES.get(asset_kind, [])
	for rule in rules:
		var pattern: String = str(rule.match) + "*"
		var matches := parent_node.find_children(pattern, "MeshInstance3D", true, false)
		for node in matches:
			var mesh := node as Node3D
			if mesh == null:
				continue
			_targets.append({
				"node": mesh,
				"rest_position": mesh.position,
				"rest_rotation": mesh.rotation,
				"rest_scale": mesh.scale,
				"rule": rule,
			})


func _apply(target: Dictionary) -> void:
	var mesh: Node3D = target["node"]
	if not is_instance_valid(mesh):
		return
	var rule: Dictionary = target["rule"]
	var speed := float(rule.get("speed", 1.0))
	var amount := float(rule.get("amount", 0.1))
	var wave := sin(_time * speed + _phase)
	match str(rule.get("mode", "spin")):
		"spin":
			var rotation: Vector3 = target["rest_rotation"]
			match str(rule.get("axis", "y")):
				"x":
					mesh.rotation.x = rotation.x + _time * speed
				"z":
					mesh.rotation.z = rotation.z + _time * speed
				_:
					mesh.rotation.y = rotation.y + _time * speed
		"sweep":
			var rest: Vector3 = target["rest_rotation"]
			match str(rule.get("axis", "y")):
				"x":
					mesh.rotation.x = rest.x + wave * amount
				"z":
					mesh.rotation.z = rest.z + wave * amount
				_:
					mesh.rotation.y = rest.y + wave * amount
		"bob":
			var base_position: Vector3 = target["rest_position"]
			var offset := Vector3.ZERO
			match str(rule.get("axis", "y")):
				"x":
					offset.x = wave * amount
				"z":
					offset.z = wave * amount
				_:
					offset.y = wave * amount
			mesh.position = base_position + offset
		"pulse":
			var base_scale: Vector3 = target["rest_scale"]
			mesh.scale = base_scale * (1.0 + wave * amount)
		_:
			pass
