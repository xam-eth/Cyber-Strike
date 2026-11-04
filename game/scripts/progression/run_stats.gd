extends Node

signal stats_changed

var run_score: int = 0
var bp_earned: int = 0
var cryo_alloy: int = 0
var pickups_collected: int = 0
var crates_broken: int = 0
var eliminations: int = 0
var guardians_defeated: int = 0
var survival_seconds: float = 0.0
var is_run_active: bool = false


func _process(delta: float) -> void:
	if not is_run_active:
		return

	var previous_second := floori(survival_seconds)
	survival_seconds += delta
	if floori(survival_seconds) != previous_second:
		stats_changed.emit()


func start_run() -> void:
	if is_run_active:
		return
	is_run_active = true
	stats_changed.emit()


func end_run() -> void:
	if not is_run_active:
		return
	is_run_active = false
	stats_changed.emit()


func reset_run() -> void:
	is_run_active = false
	run_score = 0
	bp_earned = 0
	cryo_alloy = 0
	pickups_collected = 0
	crates_broken = 0
	eliminations = 0
	guardians_defeated = 0
	survival_seconds = 0.0
	stats_changed.emit()


func record_guardian_defeated() -> void:
	if not is_run_active:
		return
	guardians_defeated += 1
	stats_changed.emit()


func record_elimination(score_reward: int, bp_reward: int) -> void:
	if not is_run_active or score_reward < 0 or bp_reward < 0:
		return
	eliminations += 1
	run_score += score_reward
	bp_earned += bp_reward
	stats_changed.emit()


func award_battle_points(amount: int) -> void:
	if not is_run_active or amount <= 0:
		return
	bp_earned += amount
	stats_changed.emit()


func collect_field_bp(amount: int, score_bonus: int = 75) -> void:
	if amount <= 0:
		return
	bp_earned += amount
	run_score += maxi(score_bonus, 0)
	pickups_collected += 1
	stats_changed.emit()


func collect_cryo_alloy(amount: int = 1, score_bonus: int = 50) -> int:
	if amount <= 0:
		return cryo_alloy
	cryo_alloy += amount
	run_score += maxi(score_bonus, 0)
	pickups_collected += 1
	stats_changed.emit()
	return cryo_alloy


func record_pickup_collected(score_bonus: int = 35) -> void:
	run_score += maxi(score_bonus, 0)
	pickups_collected += 1
	stats_changed.emit()


func record_crate_broken(score_bonus: int = 40) -> void:
	crates_broken += 1
	run_score += maxi(score_bonus, 0)
	stats_changed.emit()


func get_survival_time_text() -> String:
	var total_seconds := floori(survival_seconds)
	var minutes := floori(float(total_seconds) / 60.0)
	return "%02d:%02d" % [minutes, total_seconds % 60]
