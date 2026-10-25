#!/usr/bin/env python3
"""Generate Exocomplict's original Frontier Signal audio palette.

The output is deterministic PCM WAV: no samples, external encoder, third-party
music, or non-standard Python packages are used. Both the Godot game and the
HTML shell load these same files, so their musical identity cannot drift.

Run from the repository root:
    python3 tools/generate_audio.py
    python3 tools/generate_audio.py --check
"""

from __future__ import annotations

import argparse
from array import array
import hashlib
import json
import math
from pathlib import Path
import shutil
import sys
import tempfile
import wave

SAMPLE_RATE = 22050
SEED = 0xA3615  # Fixed palette seed; no runtime randomness is used.
TAU = math.tau
ROOT = Path(__file__).resolve().parents[1]
DEFAULT_OUTPUT = ROOT / "game" / "assets" / "audio"

# D minor / modal, 80 BPM. The 24-second theme contains eight 4/4 bars;
# the six-second percussion layer contains two bars and divides it exactly.
BEAT_SECONDS = 0.75
THEME_SECONDS = 24.0
PULSE_SECONDS = 6.0
CHORD_SECONDS = 3.0

# MIDI voicings: Dm, Bb, F, C, Dm, Bb, Gm, Asus. The final suspended chord
# resolves back to Dm without borrowing a unrelated heroic/orchestral style.
CHORDS = (
    (50, 57, 62, 65),
    (46, 53, 58, 62),
    (53, 60, 65, 69),
    (48, 55, 60, 64),
    (50, 57, 62, 65),
    (46, 53, 58, 62),
    (43, 50, 55, 58),
    (45, 52, 57, 62),
)
BASS_ROOTS = (38, 34, 41, 36, 38, 34, 31, 33)
ARP_VOICINGS = (
    (62, 65, 69, 74),
    (58, 62, 65, 70),
    (65, 69, 72, 77),
    (60, 64, 67, 72),
    (62, 65, 69, 74),
    (58, 62, 65, 70),
    (55, 58, 62, 67),
    (57, 62, 64, 69),
)


def midi(note: float) -> float:
    return 440.0 * (2.0 ** ((note - 69.0) / 12.0))


def periodic_frequency(note: float, duration: float) -> float:
    """Snap a pitch to complete cycles so the loop boundary is continuous."""
    return round(midi(note) * duration) / duration


def smoothstep(value: float) -> float:
    value = min(1.0, max(0.0, value))
    return value * value * (3.0 - 2.0 * value)


def chord_weights(seconds: float) -> tuple[tuple[int, float], tuple[int, float]]:
    position = seconds / CHORD_SECONDS
    index = int(math.floor(position)) % len(CHORDS)
    local = position - math.floor(position)
    blend = smoothstep((local - 0.80) / 0.20)
    return (index, 1.0 - blend), ((index + 1) % len(CHORDS), blend)


def theme_sample(seconds: float) -> tuple[float, float]:
    weights = chord_weights(seconds)
    left = 0.0
    right = 0.0
    pad_motion = 0.94 + 0.06 * math.sin(TAU * 2.0 * seconds / THEME_SECONDS)

    # Clean, slowly crossfaded pad. Absolute oscillator time plus periodic
    # frequencies means there is no phase reset at either chord or loop edges.
    pans = (-0.55, 0.30, -0.25, 0.55)
    for chord_index, weight in weights:
        if weight <= 0.0:
            continue
        for voice, note in enumerate(CHORDS[chord_index]):
            frequency = periodic_frequency(note, THEME_SECONDS)
            phase_l = TAU * frequency * seconds + voice * 0.63
            phase_r = phase_l + 0.31 + chord_index * 0.07
            tone_l = math.sin(phase_l) + 0.24 * math.sin(2.0 * phase_l + 0.2)
            tone_r = math.sin(phase_r) + 0.24 * math.sin(2.0 * phase_r + 0.2)
            gain = weight * pad_motion * 0.12
            left += tone_l * gain * math.sqrt((1.0 - pans[voice]) * 0.5)
            right += tone_r * gain * math.sqrt((1.0 + pans[voice]) * 0.5)

        root = periodic_frequency(BASS_ROOTS[chord_index], THEME_SECONDS)
        bass_phase = TAU * root * seconds
        bass = (math.sin(bass_phase) + 0.18 * math.sin(2.0 * bass_phase)) * weight * 0.14
        left += bass
        right += bass

    # A restrained one-note-per-beat telemetry motif. Every event has a zero
    # crossing at both ends, keeping transients clean and leaving space for SFX.
    beat_position = seconds / BEAT_SECONDS
    step = int(math.floor(beat_position)) % 32
    local = (beat_position - math.floor(beat_position)) * BEAT_SECONDS
    chord_index = min(7, step // 4)
    note = ARP_VOICINGS[chord_index][step % 4]
    frequency = periodic_frequency(note, THEME_SECONDS)
    attack = 1.0 - math.exp(-local / 0.009)
    release = 1.0 - smoothstep((local - 0.54) / 0.21)
    envelope = attack * math.exp(-4.2 * local / BEAT_SECONDS) * release
    phase = TAU * frequency * local
    pluck = (math.sin(phase) + 0.28 * math.sin(2.0 * phase)) * envelope * 0.15
    pan = -0.30 if step % 2 == 0 else 0.30
    left += pluck * math.sqrt((1.0 - pan) * 0.5)
    right += pluck * math.sqrt((1.0 + pan) * 0.5)

    # Periodic air, built from quiet harmonics rather than non-looping noise.
    air_l = 0.0
    air_r = 0.0
    for index in range(4):
        cycles = 42000 + index * 9777 + (SEED % 101)
        phase = TAU * cycles * seconds / THEME_SECONDS + index * 1.7
        motion = 0.5 + 0.5 * math.sin(TAU * (index + 1) * seconds / THEME_SECONDS)
        air_l += math.sin(phase) * motion * 0.0035
        air_r += math.sin(phase + 0.8) * motion * 0.0035
    return math.tanh((left + air_l) * 1.15), math.tanh((right + air_r) * 1.15)


def pulse_sample(seconds: float) -> tuple[float, float]:
    beat_position = seconds / BEAT_SECONDS
    step = int(math.floor(beat_position)) % 8
    local = (beat_position - math.floor(beat_position)) * BEAT_SECONDS

    # Short electronic downbeat with an analytic pitch drop, not a sampled kick.
    kick_phase = TAU * (47.0 * local + 1.25 * (1.0 - math.exp(-local / 0.026)))
    kick_envelope = (1.0 - math.exp(-local / 0.0025)) * math.exp(-local / 0.115)
    kick_envelope *= 1.0 - smoothstep((local - 0.50) / 0.25)
    kick = math.sin(kick_phase) * kick_envelope * 0.62

    # Alternating offbeat telemetry ticks. Their frequencies are also periodic
    # over six seconds and their envelopes close before the next event.
    tick_local = (seconds + BEAT_SECONDS * 0.5) % BEAT_SECONDS
    tick_step = (step + 4) % 8
    tick_frequency = round((1640.0 + 90.0 * (tick_step % 3)) * PULSE_SECONDS) / PULSE_SECONDS
    tick_phase = TAU * tick_frequency * tick_local
    tick_envelope = (1.0 - math.exp(-tick_local / 0.0015)) * math.exp(-tick_local / 0.024)
    tick_envelope *= 1.0 - smoothstep((tick_local - 0.11) / 0.08)
    tick = (math.sin(tick_phase) + 0.20 * math.sin(2.7 * tick_phase)) * tick_envelope * 0.13
    pan = -0.48 if tick_step % 2 == 0 else 0.48
    left = kick + tick * math.sqrt((1.0 - pan) * 0.5)
    right = kick + tick * math.sqrt((1.0 + pan) * 0.5)
    return math.tanh(left), math.tanh(right)


def event_envelope(local: float, duration: float, attack: float = 0.008) -> float:
    if local < 0.0 or local >= duration:
        return 0.0
    return (
        (1.0 - math.exp(-local / attack))
        * math.exp(-3.8 * local / duration)
        * (1.0 - smoothstep((local - duration * 0.68) / (duration * 0.32)))
    )


def tone_event(seconds: float, start: float, note: float, duration: float, gain: float) -> float:
    local = seconds - start
    if local < 0.0 or local >= duration:
        return 0.0
    phase = TAU * midi(note) * local
    return (math.sin(phase) + 0.20 * math.sin(2.0 * phase)) * event_envelope(local, duration) * gain


def navigate_sample(seconds: float) -> tuple[float, float]:
    value = tone_event(seconds, 0.0, 86, 0.115, 0.70)  # D6
    value += tone_event(seconds, 0.025, 93, 0.085, 0.24)  # A6, quiet upper signal
    return value * 0.86, value


def confirm_sample(seconds: float) -> tuple[float, float]:
    left = tone_event(seconds, 0.0, 74, 0.19, 0.52)  # D5
    right = left
    left += tone_event(seconds, 0.085, 81, 0.22, 0.45) * 0.82  # A5
    right += tone_event(seconds, 0.085, 81, 0.22, 0.45)
    return left, right


def deploy_sample(seconds: float) -> tuple[float, float]:
    # The same D-A-D identity as the theme, with a restrained sub impact.
    left = tone_event(seconds, 0.00, 62, 0.48, 0.36)
    right = left
    left += tone_event(seconds, 0.24, 69, 0.50, 0.34) * 0.86
    right += tone_event(seconds, 0.24, 69, 0.50, 0.34)
    left += tone_event(seconds, 0.56, 74, 0.78, 0.42) * 0.78
    right += tone_event(seconds, 0.56, 86, 0.70, 0.12)
    sub = tone_event(seconds, 0.0, 38, 0.70, 0.34)
    left += sub
    right += sub
    return math.tanh(left), math.tanh(right)


ASSETS = {
    "frontier_signal.wav": {
        "seconds": THEME_SECONDS,
        "sample": theme_sample,
        "peak": 0.78,
        "loop": True,
        "role": "Opening, dashboard and gameplay theme; eight bars of D-modal synth pad and telemetry motif.",
    },
    "defense_pulse.wav": {
        "seconds": PULSE_SECONDS,
        "sample": pulse_sample,
        "peak": 0.76,
        "loop": True,
        "role": "Gameplay-only rhythmic layer; two bars, synchronized with the 24-second theme.",
    },
    "ui_navigate.wav": {
        "seconds": 0.12,
        "sample": navigate_sample,
        "peak": 0.68,
        "loop": False,
        "role": "Shared shell and Godot UI navigation tick.",
    },
    "ui_confirm.wav": {
        "seconds": 0.32,
        "sample": confirm_sample,
        "peak": 0.72,
        "loop": False,
        "role": "Shell selection confirmation in the same D-modal palette.",
    },
    "deploy_stinger.wav": {
        "seconds": 1.50,
        "sample": deploy_sample,
        "peak": 0.80,
        "loop": False,
        "role": "DEPLOY and Defense-start D-A-D signal with a short sub impact.",
    },
}


def render(spec: dict) -> tuple[bytes, dict]:
    frames = int(round(spec["seconds"] * SAMPLE_RATE))
    channels = [array("f"), array("f")]
    sample = spec["sample"]
    peak = 0.0
    for frame in range(frames):
        left, right = sample(frame / SAMPLE_RATE)
        channels[0].append(left)
        channels[1].append(right)
        peak = max(peak, abs(left), abs(right))
    if peak <= 0.0:
        raise ValueError("refusing to render a silent asset")
    scale = spec["peak"] / peak
    pcm = array("h")
    sum_squares = 0
    dc = [0, 0]
    for left, right in zip(*channels):
        for channel, value in enumerate((left, right)):
            scaled = value * scale
            dc[channel] += scaled
            sum_squares += scaled * scaled
            pcm.append(int(round(max(-1.0, min(1.0, scaled)) * 32767.0)))
    if sys.byteorder != "little":
        pcm.byteswap()
    payload = pcm.tobytes()
    metrics = {
        "sample_rate": SAMPLE_RATE,
        "channels": 2,
        "bits_per_sample": 16,
        "frames": frames,
        "seconds": frames / SAMPLE_RATE,
        "peak": round(max(abs(value) for value in pcm) / 32767.0, 6),
        "rms": round(math.sqrt(sum_squares / (frames * 2)), 6),
        "dc_offset": [round(value / frames, 8) for value in dc],
        "loop": bool(spec["loop"]),
    }
    return payload, metrics


def write_wav(path: Path, pcm: bytes) -> None:
    with wave.open(str(path), "wb") as output:
        output.setnchannels(2)
        output.setsampwidth(2)
        output.setframerate(SAMPLE_RATE)
        output.writeframes(pcm)


def generate(output: Path) -> dict:
    output.mkdir(parents=True, exist_ok=True)
    manifest = {
        "name": "Frontier Signal",
        "version": 1,
        "provenance": "Original deterministic synthesis by tools/generate_audio.py; no external samples or music.",
        "seed": SEED,
        "tempo_bpm": 80,
        "key": "D minor / modal",
        "assets": {},
    }
    for name, spec in ASSETS.items():
        pcm, metrics = render(spec)
        path = output / name
        write_wav(path, pcm)
        entry = {
            **metrics,
            "sha256": hashlib.sha256(path.read_bytes()).hexdigest(),
            "bytes": path.stat().st_size,
            "role": spec["role"],
        }
        manifest["assets"][name] = entry
        print(
            f"{name}: {entry['seconds']:.3f}s, {entry['bytes']} bytes, "
            f"peak={entry['peak']:.3f}, rms={entry['rms']:.3f}, loop={entry['loop']}"
        )
    manifest["total_bytes"] = sum(entry["bytes"] for entry in manifest["assets"].values())
    (output / "manifest.json").write_text(json.dumps(manifest, indent=2) + "\n", encoding="utf-8")
    return manifest


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--output-dir", type=Path, default=DEFAULT_OUTPUT)
    parser.add_argument("--check", action="store_true", help="regenerate temporarily and require byte-identical assets")
    args = parser.parse_args()
    if not args.check:
        generate(args.output_dir)
        return 0

    expected_names = set(ASSETS) | {"manifest.json"}
    missing = [name for name in sorted(expected_names) if not (args.output_dir / name).is_file()]
    if missing:
        print(f"Missing generated audio: {', '.join(missing)}", file=sys.stderr)
        return 1
    temporary = Path(tempfile.mkdtemp(prefix="frontier-signal-"))
    try:
        generate(temporary)
        mismatched = [
            name
            for name in sorted(expected_names)
            if (args.output_dir / name).read_bytes() != (temporary / name).read_bytes()
        ]
        if mismatched:
            print(f"Audio is not reproducible: {', '.join(mismatched)}", file=sys.stderr)
            return 1
        print("Frontier Signal: all generated assets are byte-identical.")
        return 0
    finally:
        shutil.rmtree(temporary)


if __name__ == "__main__":
    raise SystemExit(main())
