extends Node

signal enemy_rewarded(enemy: Node3D, score_reward: int, bp_reward: int)
signal wave_rewarded(wave_index: int, bp_reward: int)

const RunStatsScript = preload("res://scripts/progression/run_stats.gd")

@export_range(0, 10000, 1) var runner_score_reward: int = 100
@export_range(0, 1000, 1) var runner_bp_reward: int = 10
@export_range(0, 10000, 1) var shooter_score_reward: int = 100
@export_range(0, 1000, 1) var shooter_bp_reward: int = 10
@export_range(0, 10000, 1) var guardian_score_reward: int = 300
@export_range(0, 1000, 1) var guardian_bp_reward: int = 45
@export_range(0, 10000, 1) var wave_bp_reward: int = 100
@export_range(0, 1000, 1) var guardian_wave_bonus_bp: int = 50

var _rewarded_enemy_ids: Dictionary = {}
var _rewarded_wave_indexes: Dictionary = {}

@onready var run_stats = get_node("../RunStats") as RunStatsScript


func award_enemy_defeat(enemy: Node3D) -> void:
	if not is_instance_valid(enemy) or not enemy.is_in_group("enemies"):
		return
	if not enemy.has_method("is_defeated") or not bool(enemy.call("is_defeated")):
		return
	if not is_instance_valid(run_stats) or not run_stats.is_run_active:
		return

	var score_reward: int
	var bp_reward: int
	var is_guardian := false
	if enemy.is_in_group("runner_enemies"):
		score_reward = runner_score_reward
		bp_reward = runner_bp_reward
	elif enemy.is_in_group("shooter_enemies"):
		score_reward = shooter_score_reward
		bp_reward = shooter_bp_reward
	elif enemy.is_in_group("guardian_enemies"):
		score_reward = guardian_score_reward
		bp_reward = guardian_bp_reward
		is_guardian = true
	else:
		push_warning("RewardService has no reward configured for enemy '%s'." % enemy.name)
		return

	var enemy_id := enemy.get_instance_id()
	if _rewarded_enemy_ids.has(enemy_id):
		return

	_rewarded_enemy_ids[enemy_id] = true
	if is_guardian:
		run_stats.record_guardian_defeated()
	run_stats.record_elimination(score_reward, bp_reward)
	enemy_rewarded.emit(enemy, score_reward, bp_reward)


func award_wave_completion(wave_index: int, is_guardian_milestone: bool = false) -> void:
	if wave_index < 1 or not is_instance_valid(run_stats) or not run_stats.is_run_active:
		return
	if _rewarded_wave_indexes.has(wave_index):
		return

	_rewarded_wave_indexes[wave_index] = true
	var bp_total := wave_bp_reward + (guardian_wave_bonus_bp if is_guardian_milestone else 0)
	run_stats.award_battle_points(bp_total)
	wave_rewarded.emit(wave_index, bp_total)


func reset_run() -> void:
	_rewarded_enemy_ids.clear()
	_rewarded_wave_indexes.clear()
