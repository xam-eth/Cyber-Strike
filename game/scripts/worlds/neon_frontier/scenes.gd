## The component scenes and helper scripts the zones are built from.
##
## These were consts at the top of neon_frontier_world.gd, which meant a zone
## could only use them while it lived in that file. The zones now have their
## own files, so what they share lives here instead of being copied into each.
class_name NeonFrontierScenes
extends RefCounted

const BOSS_GATE_SCENE: PackedScene = preload("res://scenes/worlds/components/boss_gate.tscn")
const COMMAND_SCENE: PackedScene = preload("res://scenes/worlds/components/command_center.tscn")
const CRYSTAL_SCENE: PackedScene = preload("res://scenes/worlds/components/crystal_cluster.tscn")
const DEPOT_SCENE: PackedScene = preload("res://scenes/worlds/components/equipment_depot.tscn")
const DRONE_WRECK_SCENE: PackedScene = preload(
	"res://scenes/worlds/components/alien_drone_wreck.tscn"
)
const FLORA_SCENE: PackedScene = preload("res://scenes/worlds/components/alien_flora.tscn")
const GENERATOR_SCENE: PackedScene = preload("res://scenes/worlds/components/generator_bank.tscn")
const LAB_SCENE: PackedScene = preload("res://scenes/worlds/components/research_lab.tscn")
const LANDING_PAD_SCENE: PackedScene = preload("res://scenes/worlds/components/landing_pad.tscn")
const SENSOR_SCENE: PackedScene = preload("res://scenes/worlds/components/sensor_tower.tscn")
const SPAWN_GATE_SCENE: PackedScene = preload(
	"res://scenes/worlds/components/enemy_spawn_gate.tscn"
)
const ScifiBayBuilder = preload("res://scripts/worlds/scifi_bay_builder.gd")
const TRANSPORT_SCENE: PackedScene = preload(
	"res://scenes/worlds/components/wrecked_transport.tscn"
)
const TURRET_SCENE: PackedScene = preload("res://scenes/worlds/components/defense_turret.tscn")
const REACTOR_SCENE: PackedScene = preload("res://scenes/worlds/components/reactor_core.tscn")
const COVER_SCENE: PackedScene = preload("res://scenes/worlds/components/cover_module.tscn")
