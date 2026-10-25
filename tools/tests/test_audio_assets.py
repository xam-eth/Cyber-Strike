"""Static contract for the original Frontier Signal WAV assets.

These checks prove file integrity, deterministic generation, PCM format, basic
signal health and loop-boundary continuity. They deliberately do not claim a
human listening review, loudness-normalisation acceptance, or device testing.
"""

from __future__ import annotations

from array import array
import hashlib
import json
import math
from pathlib import Path
import subprocess
import sys
import unittest
import wave

ROOT = Path(__file__).resolve().parents[2]
AUDIO_DIR = ROOT / "game" / "assets" / "audio"
EXPECTED = {
    "frontier_signal.wav": (24.0, True),
    "defense_pulse.wav": (6.0, True),
    "ui_navigate.wav": (0.12, False),
    "ui_confirm.wav": (0.32, False),
    "deploy_stinger.wav": (1.50, False),
}


class AudioAssetsTest(unittest.TestCase):
    @classmethod
    def setUpClass(cls) -> None:
        cls.manifest = json.loads((AUDIO_DIR / "manifest.json").read_text(encoding="utf-8"))

    def read_pcm(self, name: str) -> tuple[wave._wave_params, array]:
        with wave.open(str(AUDIO_DIR / name), "rb") as source:
            params = source.getparams()
            samples = array("h", source.readframes(source.getnframes()))
        if sys.byteorder != "little":
            samples.byteswap()
        return params, samples

    def test_manifest_and_hashes_cover_every_asset(self) -> None:
        self.assertEqual(set(self.manifest["assets"]), set(EXPECTED))
        self.assertEqual(self.manifest["tempo_bpm"], 80)
        self.assertIn("Original deterministic synthesis", self.manifest["provenance"])
        for name in EXPECTED:
            payload = (AUDIO_DIR / name).read_bytes()
            entry = self.manifest["assets"][name]
            self.assertEqual(hashlib.sha256(payload).hexdigest(), entry["sha256"], name)
            self.assertEqual(len(payload), entry["bytes"], name)
        self.assertLess(self.manifest["total_bytes"], 4_000_000)

    def test_pcm_format_duration_and_signal_health(self) -> None:
        for name, (seconds, loop) in EXPECTED.items():
            with self.subTest(name=name):
                params, samples = self.read_pcm(name)
                self.assertEqual(params.nchannels, 2)
                self.assertEqual(params.sampwidth, 2)
                self.assertEqual(params.framerate, 22050)
                self.assertEqual(params.nframes, round(seconds * params.framerate))
                self.assertEqual(self.manifest["assets"][name]["loop"], loop)
                self.assertEqual(len(samples), params.nframes * 2)
                peak = max(abs(value) for value in samples) / 32767.0
                rms = math.sqrt(sum(value * value for value in samples) / len(samples)) / 32767.0
                self.assertGreater(peak, 0.5)
                self.assertLessEqual(peak, 0.85)
                self.assertGreater(rms, 0.02)
                self.assertFalse(any(abs(value) >= 32767 for value in samples), "clipped PCM sample")
                for channel in (0, 1):
                    dc = sum(samples[channel::2]) / params.nframes / 32767.0
                    self.assertLess(abs(dc), 0.002, f"DC offset in channel {channel}")

    def test_loop_boundaries_are_sample_continuous(self) -> None:
        for name, (_, loop) in EXPECTED.items():
            if not loop:
                continue
            with self.subTest(name=name):
                _, samples = self.read_pcm(name)
                for channel in (0, 1):
                    mono = samples[channel::2]
                    steps = sorted(abs(mono[index] - mono[index + 1]) for index in range(len(mono) - 1))
                    p99 = steps[min(len(steps) - 1, int(len(steps) * 0.99))]
                    boundary = abs(mono[-1] - mono[0])
                    # A seamless waveform still has an ordinary per-sample
                    # slope. Compare the wrap with real slopes, not with zero.
                    self.assertLessEqual(boundary, max(32, int(p99 * 1.5)))

    def test_non_looping_sfx_start_and_end_cleanly(self) -> None:
        for name, (_, loop) in EXPECTED.items():
            if loop:
                continue
            with self.subTest(name=name):
                _, samples = self.read_pcm(name)
                self.assertLessEqual(max(abs(samples[0]), abs(samples[1])), 32)
                self.assertLessEqual(max(abs(samples[-2]), abs(samples[-1])), 32)

    def test_generator_reproduces_committed_bytes(self) -> None:
        result = subprocess.run(
            [sys.executable, str(ROOT / "tools" / "generate_audio.py"), "--check"],
            cwd=ROOT,
            capture_output=True,
            text=True,
            timeout=60,
            check=False,
        )
        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)


if __name__ == "__main__":
    unittest.main()
