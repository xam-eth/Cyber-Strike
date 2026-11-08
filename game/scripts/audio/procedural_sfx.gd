class_name ProceduralSfx
extends RefCounted

## Studio-grade deterministic procedural weapon, combat, and pickup audio
## combined with shared Frontier Signal UI WAV stingers.
##
## Uses true phase-integrated frequency sweeps (eliminating chirp phase-reversal
## artifacts), multi-layer weapon transients (sub-bass receiver punch +
## supersonic crack + mechanical bolt cycle + glacier canyon slapback tail),
## and deterministic seeded noise so automated stream tests remain reproducible.

const SHOT_VOLUME_DB := -4.4
const HEAVY_SHOT_VOLUME_DB := -3.6
const IMPACT_VOLUME_DB := -7.8
const UI_VOLUME_DB := -10.5
const FOLEY_VOLUME_DB := -8.5

const VOLUME_DB := {
	&"shot_pulse_rifle": SHOT_VOLUME_DB,
	&"shot_pulse_rifle_r2": SHOT_VOLUME_DB,
	&"shot_pulse_rifle_r3": SHOT_VOLUME_DB,
	&"shot_pulse_rifle_r4": SHOT_VOLUME_DB,
	&"shot_nova_launcher": HEAVY_SHOT_VOLUME_DB,
	&"shot_nova_launcher_r2": HEAVY_SHOT_VOLUME_DB,
	&"shot_nova_launcher_r3": HEAVY_SHOT_VOLUME_DB,
	&"shot_nova_launcher_r4": HEAVY_SHOT_VOLUME_DB,
	&"shot_arc_shooter": SHOT_VOLUME_DB,
	&"shot_arc_shooter_r2": SHOT_VOLUME_DB,
	&"shot_arc_shooter_r3": SHOT_VOLUME_DB,
	&"shot_arc_shooter_r4": SHOT_VOLUME_DB,
	&"enemy_shot": -6.4,
	&"enemy_shot_r2": -6.4,
	&"enemy_shot_r3": -6.4,
	&"impact": IMPACT_VOLUME_DB,
	&"explosion": HEAVY_SHOT_VOLUME_DB,
	&"chain_zap": IMPACT_VOLUME_DB,
	&"enemy_down": IMPACT_VOLUME_DB,
	&"player_hurt": IMPACT_VOLUME_DB,
	&"skill_pulse": IMPACT_VOLUME_DB,
	&"ui_click": UI_VOLUME_DB,
	&"hit_confirm": -9.0,
	&"wave_start": UI_VOLUME_DB,
	&"session_clear": UI_VOLUME_DB,
	&"defeat": UI_VOLUME_DB,
	&"reload_start": FOLEY_VOLUME_DB,
	&"reload_ready": FOLEY_VOLUME_DB,
	&"pickup_bp": -8.2,
	&"pickup_alloy": -8.0,
	&"pickup_power": -7.8,
	&"crate_break": -6.8,
	&"shield_hit": -8.0,
}


static func volume_db_for(sound_id: StringName) -> float:
	return float(VOLUME_DB.get(sound_id, -8.0))


static func build_all() -> Dictionary:
	var sounds := {
		&"shot_pulse_rifle": _shot_pulse_rifle(0),
		&"shot_pulse_rifle_r2": _shot_pulse_rifle(1),
		&"shot_pulse_rifle_r3": _shot_pulse_rifle(2),
		&"shot_pulse_rifle_r4": _shot_pulse_rifle(3),
		&"shot_nova_launcher": _shot_nova_launcher(0),
		&"shot_nova_launcher_r2": _shot_nova_launcher(1),
		&"shot_nova_launcher_r3": _shot_nova_launcher(2),
		&"shot_nova_launcher_r4": _shot_nova_launcher(3),
		&"shot_arc_shooter": _shot_arc_shooter(0),
		&"shot_arc_shooter_r2": _shot_arc_shooter(1),
		&"shot_arc_shooter_r3": _shot_arc_shooter(2),
		&"shot_arc_shooter_r4": _shot_arc_shooter(3),
		&"enemy_shot": _enemy_shot(0),
		&"enemy_shot_r2": _enemy_shot(1),
		&"enemy_shot_r3": _enemy_shot(2),
		&"impact": _impact(),
		&"explosion": _explosion(),
		&"chain_zap": _chain_zap(),
		&"enemy_down": _enemy_down(),
		&"player_hurt": _player_hurt(),
		&"skill_pulse": _skill_pulse(),
		&"ui_click": _ui_click(),
		&"hit_confirm": _hit_confirm(),
		&"wave_start": _wave_start(),
		&"session_clear": _session_clear(),
		&"defeat": _defeat(),
		&"reload_start": _reload_start(),
		&"reload_ready": _reload_ready(),
		&"pickup_bp": _pickup_bp(),
		&"pickup_alloy": _pickup_alloy(),
		&"pickup_power": _pickup_power(),
		&"crate_break": _crate_break(),
		&"shield_hit": _shield_hit(),
	}
	return sounds


## Fast constant-time lookup — never rebuilds WAV buffers at runtime.
static func weapon_sound_id(weapon_id: StringName) -> StringName:
	var candidate := StringName("shot_%s" % String(weapon_id))
	return candidate if VOLUME_DB.has(candidate) else &"shot_pulse_rifle"


## Round-robin bank for a base id: the base sound plus its `_r2.._rN` variants,
## in playback order. Only ids that actually exist are returned, so banks stay
## correct as sounds are added.
static func variant_bank(base_id: StringName) -> Array[StringName]:
	var bank: Array[StringName] = [base_id]
	var suffix := 2
	while VOLUME_DB.has(StringName("%s_r%d" % [String(base_id), suffix])):
		bank.append(StringName("%s_r%d" % [String(base_id), suffix]))
		suffix += 1
	return bank


# --- weapons -----------------------------------------------------------------


static func _shot_pulse_rifle(variant: int) -> AudioStreamWAV:
	# Multi-layer kinetic-plasma assault rifle:
	# 1) Sub-bass chest punch (175 -> 46 Hz) with variant detune
	# 2) Supersonic muzzle crack + high-voltage plasma snap (2900 -> 540 Hz)
	# 3) Delayed machined steel bolt clack (timing jitters per variant)
	# 4) Air-whip crack on the transient
	# 5) Filtered glacier canyon slapback acoustic tail
	var v := float(variant)
	var detune := 1.0 + (v - 1.5) * 0.035
	var bolt_time := 0.0115 + v * 0.0012
	return _build_filtered(
		44100,
		0.28,
		0.62,
		func(t: float, span: float, rng: RandomNumberGenerator) -> float:
			var n := rng.randf() * 2.0 - 1.0
			var sub := (
				_sine(_chirp_power(175.0 * detune, 46.0, t, 0.085, 0.45))
				* _envelope(t, span, 0.0008, 34.0)
			)
			var mid_punch := (
				_saw(_chirp_power(680.0 * detune, 145.0, t, 0.065, 0.55))
				* _envelope(t, span, 0.0006, 46.0)
				* 0.58
			)
			var plasma_snap := (
				_sine(_chirp_power(2850.0 * detune, 520.0, t, 0.028, 0.4))
				* _envelope(t, span, 0.0004, 95.0)
				* 0.44
			)
			var muzzle_blast := n * _envelope(t, span, 0.0004, 78.0) * 0.78
			var air_whip := n * _envelope(t, span, 0.0015, 128.0) * 0.34
			var bolt := 0.0
			if t >= bolt_time:
				var bt := t - bolt_time
				bolt = (
					(_sine(_phase(1820.0, bt)) * 0.5 + _sine(_phase(3140.0, bt)) * 0.32 + n * 0.35)
					* _envelope(bt, span - bolt_time, 0.0005, 85.0)
					* 0.36
				)
			var canyon_tail := 0.0
			if t >= 0.032:
				var tt := t - 0.032
				canyon_tail = (
					(n * 0.65 + _sine(_phase(165.0, tt)) * 0.35)
					* _envelope(tt, span - 0.032, 0.008, 13.5)
					* 0.22
				)
			return tanh(
				(
					(
						sub * 1.15
						+ mid_punch
						+ plasma_snap
						+ muzzle_blast
						+ air_whip
						+ bolt
						+ canyon_tail
					)
					* 1.45
				)
			),
		0x5F3A17 + variant * 7919
	)


static func _shot_nova_launcher(variant: int) -> AudioStreamWAV:
	# Heavy ordnance launcher: deep breech concussion + hollow tube resonance +
	# propellant roar + falling tube sweep + debris shimmer. Variant jitters the
	# breech timing and tube detune so consecutive launches never sound cloned.
	var v := float(variant)
	var detune := 1.0 + (v - 1.5) * 0.05
	var breech_bias := rng_bias(v)
	return _build_filtered(
		44100,
		0.54,
		0.48,
		func(t: float, span: float, rng: RandomNumberGenerator) -> float:
			var n := rng.randf() * 2.0 - 1.0
			var sub := (
				_sine(_chirp_power(210.0 * detune, 34.0, t, 0.24, 0.42))
				* _envelope(t, span, 0.0015, 8.5)
			)
			var tube := (
				(_sine(_phase(340.0 * detune, t)) * 0.6 + _sine(_phase(585.0 * detune, t)) * 0.4)
				* _envelope(t, span, 0.001, 26.0)
				* 0.48
			)
			var tube_sweep := (
				_sine(_chirp_power(320.0, 88.0, t, 0.09, 0.6))
				* _envelope(t, span, 0.002, 14.0)
				* 0.4
			)
			var breech_crack := n * _envelope(t, span, 0.0006 + breech_bias * 0.0004, 52.0) * 0.72
			var propellant := n * _envelope(t, span, 0.022, 6.2) * 0.46
			var debris := 0.0
			if t >= 0.05:
				debris = n * _envelope(t - 0.05, span - 0.05, 0.002, 27.0) * 0.2
			return tanh((sub * 1.3 + tube + tube_sweep + breech_crack + propellant + debris) * 1.38),
		0x5F3A17 + variant * 7919
	)


static func _shot_arc_shooter(variant: int) -> AudioStreamWAV:
	# High-voltage rail/arc carbine: electrostatic whip crack + capacitor thump +
	# ionized FM sizzle + rising capacitor whine + spark rain. Variant detunes the
	# arc body and whine start so bursts keep crackling instead of repeating.
	var v := float(variant)
	var detune := 1.0 + (v - 1.5) * 0.045
	var whine_start := 2150.0 + v * 90.0
	return _build_filtered(
		44100,
		0.31,
		0.74,
		func(t: float, span: float, rng: RandomNumberGenerator) -> float:
			var n := rng.randf() * 2.0 - 1.0
			var cap_thump := (
				_sine(_chirp_power(155.0 * detune, 48.0, t, 0.075, 0.5))
				* _envelope(t, span, 0.0007, 32.0)
			)
			var whip := (
				_saw(_chirp_power(3900.0 * detune, 380.0, t, 0.055, 0.38))
				* _envelope(t, span, 0.0004, 42.0)
				* 0.56
			)
			var fm_mod := _sine(_phase(118.0, t)) * 3.2
			var arc_body := (
				sin(_phase(940.0 * detune, t) + fm_mod) * _envelope(t, span, 0.0015, 18.0) * 0.42
			)
			var spark := n * _envelope(t, span, 0.0004, 48.0) * 0.58
			var whine := (
				_sine(_chirp_power(whine_start, whine_start * 1.22, t, 0.13, 1.0))
				* _envelope(t, span, 0.004, 13.0)
				* 0.16
			)
			var spark_rain := 0.0
			if t >= 0.04:
				spark_rain = n * _envelope(t - 0.04, span - 0.04, 0.001, 32.0) * 0.22
			return tanh((cap_thump * 0.95 + whip + arc_body + spark + whine + spark_rain) * 1.35),
		0x5F3A17 + variant * 7919
	)


static func _enemy_shot(variant: int) -> AudioStreamWAV:
	# Hostile robot servoplasma: cold square body + hard electric snap + servo
	# chamber clack. No warm sub and a harder clip than the player weapons, so
	# incoming fire reads as machinery, not as your own arsenal echoing back.
	var v := float(variant)
	var detune := 1.0 + (v - 1.0) * 0.04
	return _build_filtered(
		44100,
		0.22,
		0.55,
		func(t: float, span: float, rng: RandomNumberGenerator) -> float:
			var n := rng.randf() * 2.0 - 1.0
			var body := (
				_square(_chirp_power(210.0 * detune, 115.0, t, 0.05, 0.5))
				* _envelope(t, span, 0.0005, 40.0)
				* 0.42
			)
			var snap := n * _envelope(t, span, 0.0003, 110.0) * 0.72
			var servo := 0.0
			if t >= 0.008:
				var st := t - 0.008
				servo = (
					_saw(_chirp_power(780.0 * detune, 620.0, st, 0.04, 1.0))
					* _envelope(st, span - 0.008, 0.0006, 62.0)
					* 0.3
				)
			var crackle := (
				_sine(_chirp_power(3200.0, 900.0, t, 0.03, 0.35))
				* _envelope(t, span, 0.0003, 120.0)
				* 0.34
			)
			return tanh((body + snap + servo + crackle) * 1.6),
		0x5F3A17 + variant * 7919
	)


## Deterministic per-variant timing bias in [0, 1].
static func rng_bias(variant: float) -> float:
	return (
		absf(sin(variant * 12.9898 + 78.233) * 43758.5453)
		- floorf(absf(sin(variant * 12.9898 + 78.233) * 43758.5453))
	)


# --- impacts & foley ---------------------------------------------------------


static func _impact() -> AudioStreamWAV:
	return _build_filtered(
		44100,
		0.11,
		0.68,
		func(t: float, span: float, rng: RandomNumberGenerator) -> float:
			var n := rng.randf() * 2.0 - 1.0
			var thud := (
				_sine(_chirp_power(240.0, 72.0, t, span, 0.5)) * _envelope(t, span, 0.0005, 44.0)
			)
			var ping := _sine(_phase(2380.0, t)) * _envelope(t, span, 0.0004, 68.0) * 0.35
			return tanh((thud * 0.8 + ping + n * _envelope(t, span, 0.0004, 52.0) * 0.75) * 1.25)
	)


static func _explosion() -> AudioStreamWAV:
	return _build_filtered(
		44100,
		0.62,
		0.42,
		func(t: float, span: float, rng: RandomNumberGenerator) -> float:
			var n := rng.randf() * 2.0 - 1.0
			var boom := (
				_sine(_chirp_power(128.0, 29.0, t, 0.38, 0.45)) * _envelope(t, span, 0.002, 5.6)
			)
			var blast := n * _envelope(t, span, 0.001, 7.2) * 0.95
			return tanh((boom * 1.28 + blast) * 1.38)
	)


static func _chain_zap() -> AudioStreamWAV:
	return _build(
		44100,
		0.18,
		func(t: float, span: float, rng: RandomNumberGenerator) -> float:
			var n := rng.randf() * 2.0 - 1.0
			var zap := (
				sin(_chirp_power(2600.0, 460.0, t, span, 0.48) + sin(_phase(140.0, t)) * 2.4)
				* _envelope(t, span, 0.0008, 22.0)
			)
			return tanh((zap * 0.65 + n * _envelope(t, span, 0.0006, 28.0) * 0.48) * 1.2)
	)


static func _enemy_down() -> AudioStreamWAV:
	# Robotic power-down drop + armor plate collapse thud + crisp KO confirmation ping.
	return _build_filtered(
		44100,
		0.44,
		0.66,
		func(t: float, span: float, rng: RandomNumberGenerator) -> float:
			var n := rng.randf() * 2.0 - 1.0
			var servo_drop := (
				_saw(_chirp_power(520.0, 78.0, t, span, 0.62))
				* _envelope(t, span, 0.003, 7.5)
				* 0.48
			)
			var confirm_ping := (
				(_sine(_phase(880.0, t)) + _sine(_phase(1318.5, t)) * 0.6)
				* _envelope(t, span, 0.001, 22.0)
				* 0.34
			)
			var thud := (
				_sine(_chirp_power(135.0, 44.0, t, 0.22, 0.5))
				* _envelope(t, span, 0.002, 10.0)
				* 0.65
			)
			var sparks := n * _envelope(t, span, 0.001, 24.0) * 0.28
			return tanh((servo_drop + confirm_ping + thud + sparks) * 1.22)
	)


static func _player_hurt() -> AudioStreamWAV:
	return _build_filtered(
		44100,
		0.30,
		0.55,
		func(t: float, span: float, rng: RandomNumberGenerator) -> float:
			var n := rng.randf() * 2.0 - 1.0
			var body := (
				_sine(_chirp_power(230.0, 62.0, t, span, 0.55)) * _envelope(t, span, 0.0015, 10.5)
			)
			var crack := n * _envelope(t, span, 0.0008, 24.0) * 0.42
			return tanh((body * 1.15 + crack) * 1.25)
	)


static func _skill_pulse() -> AudioStreamWAV:
	return _build_filtered(
		44100,
		0.48,
		0.68,
		func(t: float, span: float, rng: RandomNumberGenerator) -> float:
			var n := rng.randf() * 2.0 - 1.0
			var drop := (
				_sine(_chirp_power(1680.0, 92.0, t, span, 0.44)) * _envelope(t, span, 0.002, 6.8)
			)
			var chord := (
				(_sine(_phase(220.0, t)) + _sine(_phase(329.63, t)) * 0.7)
				* _envelope(t, span, 0.012, 5.5)
				* 0.36
			)
			var air := n * _envelope(t, span, 0.015, 5.8) * 0.34
			return tanh((drop * 0.72 + chord + air) * 1.25)
	)


static func _reload_start() -> AudioStreamWAV:
	return _build(
		44100,
		0.22,
		func(t: float, span: float, rng: RandomNumberGenerator) -> float:
			var n := rng.randf() * 2.0 - 1.0
			var latch := (
				(_sine(_phase(1960.0, t)) * 0.55 + n * 0.45) * _envelope(t, span, 0.0005, 65.0)
			)
			var slide := 0.0
			if t >= 0.075:
				var st := t - 0.075
				slide = (
					(_sine(_chirp_power(620.0, 290.0, st, 0.12, 0.7)) * 0.5 + n * 0.35)
					* _envelope(st, span - 0.075, 0.002, 26.0)
				)
			return tanh((latch * 0.75 + slide * 0.7) * 1.2)
	)


static func _reload_ready() -> AudioStreamWAV:
	return _build(
		44100,
		0.24,
		func(t: float, span: float, rng: RandomNumberGenerator) -> float:
			var n := rng.randf() * 2.0 - 1.0
			var mag_seat := (
				(_sine(_chirp_power(210.0, 88.0, t, 0.08, 0.5)) * 0.7 + n * 0.4)
				* _envelope(t, span, 0.0006, 48.0)
			)
			var bolt_lock := 0.0
			if t >= 0.085:
				var bt := t - 0.085
				bolt_lock = (
					(_sine(_phase(2480.0, bt)) * 0.5 + _sine(_phase(3720.0, bt)) * 0.35 + n * 0.4)
					* _envelope(bt, span - 0.085, 0.0005, 55.0)
				)
			return tanh((mag_seat * 0.85 + bolt_lock * 0.85) * 1.28)
	)


static func _pickup_bp() -> AudioStreamWAV:
	return _arpeggio([587.33, 739.99, 880.0, 1174.66], 0.28, 12.0)


static func _pickup_alloy() -> AudioStreamWAV:
	return _arpeggio([523.25, 659.25, 987.77, 1318.51], 0.32, 10.5)


static func _pickup_power() -> AudioStreamWAV:
	return _build(
		44100,
		0.34,
		func(t: float, span: float, _rng: RandomNumberGenerator) -> float:
			var rise := (
				_sine(_chirp_power(330.0, 1320.0, t, span, 0.75)) * _envelope(t, span, 0.006, 5.5)
			)
			var lock := (
				(_sine(_phase(880.0, t)) + _sine(_phase(1318.5, t)) * 0.65)
				* _envelope(t, span, 0.04, 6.2)
				* 0.45
			)
			return tanh((rise * 0.55 + lock) * 1.1)
	)


static func _crate_break() -> AudioStreamWAV:
	return _build_filtered(
		44100,
		0.36,
		0.62,
		func(t: float, span: float, rng: RandomNumberGenerator) -> float:
			var n := rng.randf() * 2.0 - 1.0
			var punch := (
				_sine(_chirp_power(190.0, 52.0, t, 0.16, 0.5)) * _envelope(t, span, 0.0008, 16.0)
			)
			var clang := (
				(_sine(_phase(1140.0, t)) * 0.5 + _sine(_phase(1790.0, t)) * 0.4)
				* _envelope(t, span, 0.0005, 22.0)
				* 0.55
			)
			var debris := n * _envelope(t, span, 0.001, 14.0) * 0.65
			return tanh((punch + clang + debris) * 1.28)
	)


static func _shield_hit() -> AudioStreamWAV:
	return _build(
		44100,
		0.18,
		func(t: float, span: float, rng: RandomNumberGenerator) -> float:
			var n := rng.randf() * 2.0 - 1.0
			var shimmer := (
				sin(_chirp_power(1240.0, 420.0, t, span, 0.6) + sin(_phase(95.0, t)) * 1.8)
				* _envelope(t, span, 0.0008, 18.0)
			)
			return tanh((shimmer * 0.7 + n * _envelope(t, span, 0.0006, 36.0) * 0.32) * 1.15)
	)


# --- interface -----------------------------------------------------------------


static func _ui_click() -> AudioStreamWAV:
	return load("res://assets/audio/ui_navigate.wav") as AudioStreamWAV


static func _hit_confirm() -> AudioStreamWAV:
	# Crisp dual-transient tactical hitmarker tick (high snap + mid body).
	return _build(
		44100,
		0.065,
		func(t: float, span: float, rng: RandomNumberGenerator) -> float:
			var n := rng.randf() * 2.0 - 1.0
			var snap := _sine(_phase(2340.0, t)) * _envelope(t, span, 0.0004, 52.0) * 0.52
			var body := _sine(_phase(1280.0, t)) * _envelope(t, span, 0.0006, 38.0) * 0.42
			var click := n * _envelope(t, span, 0.0003, 95.0) * 0.36
			return clampf(snap + body + click, -0.95, 0.95)
	)


static func _arpeggio(notes: Array, span: float, decay: float) -> AudioStreamWAV:
	return _build(
		44100,
		span,
		func(t: float, _total: float, _rng: RandomNumberGenerator) -> float:
			var slot := clampi(int(t / (span / float(notes.size()))), 0, notes.size() - 1)
			var local := t - float(slot) * (span / float(notes.size()))
			var f := float(notes[slot])
			var tone := _sine(_phase(f, local)) + _sine(_phase(f * 2.0, local)) * 0.25
			return tone * _envelope(local, span / float(notes.size()), 0.003, decay) * 0.48
	)


static func _wave_start() -> AudioStreamWAV:
	return load("res://assets/audio/deploy_stinger.wav") as AudioStreamWAV


static func _session_clear() -> AudioStreamWAV:
	return _arpeggio([293.66, 349.23, 440.0, 587.33], 0.9, 6.0)


static func _defeat() -> AudioStreamWAV:
	return _build(
		22050,
		0.95,
		func(t: float, span: float, _rng: RandomNumberGenerator) -> float:
			var notes: Array = [293.66, 261.63, 220.0]
			var slot := clampi(int(t / (span / 3.0)), 0, notes.size() - 1)
			var local := t - float(slot) * (span / 3.0)
			var tone := _sine(_phase(notes[slot], local)) * _envelope(local, span / 3.0, 0.01, 4.5)
			var sub := _sine(_phase(58.0, t)) * _envelope(t, span, 0.02, 3.0) * 0.5
			return (tone * 0.55 + sub) * 0.9
	)


# --- synthesis helpers --------------------------------------------------------


static func _build(mix_rate: int, seconds: float, shaper: Callable) -> AudioStreamWAV:
	var rng := RandomNumberGenerator.new()
	rng.seed = 0x5F3A17
	var sample_count := maxi(int(seconds * float(mix_rate)), 1)
	var samples := PackedFloat32Array()
	samples.resize(sample_count)
	for index in range(sample_count):
		var time := float(index) / float(mix_rate)
		samples[index] = clampf(float(shaper.call(time, seconds, rng)), -1.0, 1.0)
	return to_stream(samples, mix_rate)


## One-pole warm low-pass + canyon slapback reflection tap so procedural weapons
## sound grounded and acoustic rather than harsh raw digital noise. The noise
## seed is per-call so round-robin variants get distinct noise textures.
static func _build_filtered(
	mix_rate: int, seconds: float, cutoff_alpha: float, shaper: Callable, seed_value: int = 0x5F3A17
) -> AudioStreamWAV:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	var sample_count := maxi(int(seconds * float(mix_rate)), 1)
	var raw := PackedFloat32Array()
	raw.resize(sample_count)
	var lp := 0.0
	var a := clampf(cutoff_alpha, 0.08, 1.0)
	for index in range(sample_count):
		var time := float(index) / float(mix_rate)
		var x := float(shaper.call(time, seconds, rng))
		lp += a * (x - lp)
		raw[index] = lp
	var delay_samples := int(0.048 * float(mix_rate))
	var samples := PackedFloat32Array()
	samples.resize(sample_count)
	for index in range(sample_count):
		var echo := raw[index - delay_samples] * 0.16 if index >= delay_samples else 0.0
		samples[index] = clampf(raw[index] + echo, -1.0, 1.0)
	return to_stream(samples, mix_rate)


static func to_stream(samples: PackedFloat32Array, mix_rate: int) -> AudioStreamWAV:
	var data := PackedByteArray()
	data.resize(samples.size() * 2)
	for index in range(samples.size()):
		var value := clampi(int(round(samples[index] * 32767.0)), -32768, 32767)
		data.encode_s16(index * 2, value)
	var stream := AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = mix_rate
	stream.stereo = false
	stream.data = data
	return stream


static func _envelope(time: float, span: float, attack_seconds: float, decay_rate: float) -> float:
	var attack := clampf(time / maxf(attack_seconds, 0.0001), 0.0, 1.0)
	var remaining := clampf(1.0 - time / maxf(span, 0.0001), 0.0, 1.0)
	return attack * exp(-decay_rate * time) * remaining


static func _phase(frequency: float, time: float) -> float:
	return TAU * frequency * time


## Exact analytical integral of f(t) = f0 + (f1 - f0) * clamp(t / sweep_span, 0, 1)^power.
static func _chirp_power(
	f0: float, f1: float, time: float, sweep_span: float, power: float
) -> float:
	var dur := maxf(sweep_span, 0.0001)
	var clamped_t := minf(maxf(time, 0.0), dur)
	var ratio := clamped_t / dur
	var swept := f0 * clamped_t + (f1 - f0) * dur * pow(ratio, power + 1.0) / (power + 1.0)
	var tail := maxf(time - dur, 0.0) * f1
	return TAU * (swept + tail)


static func _sine(phase: float) -> float:
	return sin(phase)


static func _square(phase: float) -> float:
	return 1.0 if sin(phase) >= 0.0 else -1.0


static func _saw(phase: float) -> float:
	var wrapped := fposmod(phase, TAU) / TAU
	return wrapped * 2.0 - 1.0
