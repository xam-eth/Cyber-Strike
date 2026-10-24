class_name ProceduralSfx
extends RefCounted

## Every sound in the game is synthesised at runtime.
##
## Why: the repository ships no audio files at all, and the asset pipeline is
## reviewed for provenance, so pulling in WAV files means ownership paperwork for
## something a few dozen lines of maths can produce. Sound effects are the one
## place where generated wave data is a legitimate shipped artifact: they are
## short, they are not art assets, and they keep the web payload small.
##
## All generators are deterministic (the noise source is seeded), so the same
## build always sounds the same and tests can assert on stream properties.
##
## A generator (the "shaper") receives the current time, the sound span and a
## seeded noise source, and returns one normalised sample.

const SHOT_VOLUME_DB := -7.0
const IMPACT_VOLUME_DB := -9.0
const UI_VOLUME_DB := -11.0

## Playback level per sound. AudioStreamWAV carries no volume of its own, so the
## director applies this to the pooled player that ends up playing the sound.
const VOLUME_DB := {
	&"shot_pulse_rifle": SHOT_VOLUME_DB,
	&"shot_nova_launcher": SHOT_VOLUME_DB,
	&"shot_arc_shooter": SHOT_VOLUME_DB,
	&"impact": IMPACT_VOLUME_DB,
	&"explosion": IMPACT_VOLUME_DB,
	&"chain_zap": IMPACT_VOLUME_DB,
	&"enemy_down": IMPACT_VOLUME_DB,
	&"player_hurt": IMPACT_VOLUME_DB,
	&"skill_pulse": IMPACT_VOLUME_DB,
	&"ui_click": UI_VOLUME_DB,
	&"hit_confirm": UI_VOLUME_DB,
	&"wave_start": UI_VOLUME_DB,
	&"session_clear": UI_VOLUME_DB,
	&"defeat": UI_VOLUME_DB,
}


static func volume_db_for(sound_id: StringName) -> float:
	return float(VOLUME_DB.get(sound_id, 0.0))


## All sounds, keyed by the id gameplay code uses.
static func build_all() -> Dictionary:
	return {
		&"shot_pulse_rifle": _shot_pulse_rifle(),
		&"shot_nova_launcher": _shot_nova_launcher(),
		&"shot_arc_shooter": _shot_arc_shooter(),
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
	}


## Maps a weapon id from a WeaponDefinition onto a sound, falling back to the
## rifle when a new weapon is added without a voice of its own.
static func weapon_sound_id(weapon_id: StringName) -> StringName:
	var candidate := StringName("shot_%s" % String(weapon_id))
	return candidate if build_all().has(candidate) else &"shot_pulse_rifle"


# --- weapons -----------------------------------------------------------------


static func _shot_pulse_rifle() -> AudioStreamWAV:
	# Bright and tight: a falling saw with a noise transient, gone in about a
	# tenth of a second so a fast fire rate never smears into noise.
	return _build(
		44100,
		0.11,
		func(t: float, span: float, rng: RandomNumberGenerator) -> float:
			var frequency := lerpf(620.0, 190.0, pow(t / span, 0.65))
			var body := _saw(_phase(frequency, t)) * _envelope(t, span, 0.004, 26.0)
			var crack := (rng.randf() * 2.0 - 1.0) * _envelope(t, span, 0.001, 70.0) * 0.5
			return tanh((body * 0.8 + crack) * 1.6)
	)


static func _shot_nova_launcher() -> AudioStreamWAV:
	# Heavy launcher: a saturated sub sweep with a dust tail.
	return _build(
		22050,
		0.38,
		func(t: float, span: float, rng: RandomNumberGenerator) -> float:
			var frequency := lerpf(190.0, 52.0, pow(t / span, 0.5))
			var body := _sine(_phase(frequency, t)) * _envelope(t, span, 0.006, 9.0)
			var dust := (rng.randf() * 2.0 - 1.0) * _envelope(t, span, 0.02, 7.0) * 0.35
			return tanh((body * 1.2 + dust) * 1.4)
	)


static func _shot_arc_shooter() -> AudioStreamWAV:
	# Electric: a square carrier whose pitch jitters, plus a short noise spit.
	return _build(
		44100,
		0.18,
		func(t: float, span: float, rng: RandomNumberGenerator) -> float:
			var jitter := 1.0 + 0.35 * _sine(_phase(37.0, t))
			var carrier := _square(_phase(880.0 * jitter, t)) * _envelope(t, span, 0.002, 16.0)
			var spit := (rng.randf() * 2.0 - 1.0) * _envelope(t, span, 0.001, 40.0) * 0.35
			return (carrier * 0.55 + spit) * 0.9
	)


# --- impacts -----------------------------------------------------------------


static func _impact() -> AudioStreamWAV:
	return _build(
		44100,
		0.07,
		func(t: float, span: float, rng: RandomNumberGenerator) -> float:
			return (rng.randf() * 2.0 - 1.0) * _envelope(t, span, 0.0006, 55.0)
	)


static func _explosion() -> AudioStreamWAV:
	return _build(
		22050,
		0.5,
		func(t: float, span: float, rng: RandomNumberGenerator) -> float:
			var rumble := (
				_sine(_phase(lerpf(96.0, 38.0, t / span), t)) * _envelope(t, span, 0.004, 6.5)
			)
			var roar := (rng.randf() * 2.0 - 1.0) * _envelope(t, span, 0.002, 8.0)
			return tanh((rumble * 1.1 + roar * 0.8) * 1.3)
	)


static func _chain_zap() -> AudioStreamWAV:
	return _build(
		44100,
		0.16,
		func(t: float, span: float, rng: RandomNumberGenerator) -> float:
			var frequency := lerpf(1900.0, 420.0, t / span)
			var zap := _square(_phase(frequency, t)) * _envelope(t, span, 0.001, 22.0)
			var fizz := (rng.randf() * 2.0 - 1.0) * _envelope(t, span, 0.001, 26.0) * 0.5
			return (zap * 0.5 + fizz) * 0.85
	)


static func _enemy_down() -> AudioStreamWAV:
	# Two descending tones, so a kill still reads under the gunfire.
	return _build(
		22050,
		0.42,
		func(t: float, span: float, _rng: RandomNumberGenerator) -> float:
			var second := t >= span * 0.5
			var frequency := 320.0 if second else 520.0
			var local := (t - span * 0.5) if second else t
			var tone := _sine(_phase(frequency, local)) * _envelope(local, span * 0.5, 0.004, 11.0)
			var thud := _sine(_phase(120.0, t)) * _envelope(t, span, 0.003, 9.0) * 0.5
			return (tone * 0.7 + thud) * 0.9
	)


static func _player_hurt() -> AudioStreamWAV:
	return _build(
		22050,
		0.3,
		func(t: float, span: float, rng: RandomNumberGenerator) -> float:
			var fall := _sine(_phase(lerpf(240.0, 88.0, pow(t / span, 0.7)), t))
			var body := fall * _envelope(t, span, 0.002, 10.0)
			var grit := (rng.randf() * 2.0 - 1.0) * _envelope(t, span, 0.001, 18.0) * 0.25
			return tanh((body * 1.1 + grit) * 1.2)
	)


static func _skill_pulse() -> AudioStreamWAV:
	# The EMP skill: a downward whoosh with a dusty tail.
	return _build(
		22050,
		0.45,
		func(t: float, span: float, rng: RandomNumberGenerator) -> float:
			var sweep := _sine(_phase(lerpf(1500.0, 130.0, pow(t / span, 0.55)), t))
			var whoosh := (rng.randf() * 2.0 - 1.0) * _envelope(t, span, 0.03, 5.0) * 0.4
			return (sweep * _envelope(t, span, 0.004, 7.0) * 0.7 + whoosh) * 0.95
	)


# --- interface -----------------------------------------------------------------


static func _ui_click() -> AudioStreamWAV:
	return _build(
		44100,
		0.05,
		func(t: float, span: float, _rng: RandomNumberGenerator) -> float:
			return _square(_phase(1450.0, t)) * _envelope(t, span, 0.001, 45.0) * 0.4
	)


static func _hit_confirm() -> AudioStreamWAV:
	# Confirmation feedback, deliberately brighter than the impact itself.
	return _build(
		44100,
		0.06,
		func(t: float, span: float, _rng: RandomNumberGenerator) -> float:
			return _sine(_phase(1750.0, t)) * _envelope(t, span, 0.001, 30.0) * 0.35
	)


static func _arpeggio(notes: Array, span: float, decay: float) -> AudioStreamWAV:
	return _build(
		22050,
		span,
		func(t: float, _total: float, _rng: RandomNumberGenerator) -> float:
			var slot := clampi(int(t / (span / float(notes.size()))), 0, notes.size() - 1)
			var local := t - float(slot) * (span / float(notes.size()))
			return (
				_sine(_phase(notes[slot], local))
				* _envelope(local, span / float(notes.size()), 0.006, decay)
				* 0.45
			)
	)


static func _wave_start() -> AudioStreamWAV:
	return _arpeggio([440.0, 660.0, 880.0], 0.72, 9.0)


static func _session_clear() -> AudioStreamWAV:
	return _arpeggio([523.25, 659.25, 783.99, 1046.5], 0.9, 6.0)


static func _defeat() -> AudioStreamWAV:
	return _build(
		22050,
		0.95,
		func(t: float, span: float, _rng: RandomNumberGenerator) -> float:
			var notes: Array = [392.0, 311.13, 233.08]
			var slot := clampi(int(t / (span / 3.0)), 0, notes.size() - 1)
			var local := t - float(slot) * (span / 3.0)
			var tone := _sine(_phase(notes[slot], local)) * _envelope(local, span / 3.0, 0.01, 4.5)
			var sub := _sine(_phase(58.0, t)) * _envelope(t, span, 0.02, 3.0) * 0.5
			return (tone * 0.55 + sub) * 0.9
	)


# --- synthesis helpers --------------------------------------------------------


## Renders [param seconds] of audio with [param shaper].
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


## Converts normalised samples into the 16-bit stream the engine plays.
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


## Attack and decay envelope normalised to the sound's length.
static func _envelope(time: float, span: float, attack_seconds: float, decay_rate: float) -> float:
	var attack := clampf(time / maxf(attack_seconds, 0.0001), 0.0, 1.0)
	var remaining := clampf(1.0 - time / maxf(span, 0.0001), 0.0, 1.0)
	return attack * exp(-decay_rate * time) * remaining


static func _phase(frequency: float, time: float) -> float:
	return TAU * frequency * time


static func _sine(phase: float) -> float:
	return sin(phase)


static func _square(phase: float) -> float:
	return 1.0 if sin(phase) >= 0.0 else -1.0


static func _saw(phase: float) -> float:
	var wrapped := fposmod(phase, TAU) / TAU
	return wrapped * 2.0 - 1.0
