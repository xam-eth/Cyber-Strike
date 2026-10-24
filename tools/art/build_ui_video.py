#!/usr/bin/env python3
"""Render the two video assets from the art the pipeline already ships.

    python3 tools/art/build_ui_video.py            # render + encode + manifest
    python3 tools/art/build_ui_video.py --check    # verify only, write nothing

Why this file exists: Asset C (loading robot animation) shipped as a 4-frame
sprite sheet and Asset F (cinematic opening) shipped as an in-engine sequence,
because no video encoder existed in this environment. One does now -- a static
ffmpeg 7.0.2 from a PyPI wheel (``imageio-ffmpeg``), which is built with
``--enable-libtheora --enable-libvorbis`` -- and Godot 4.7.2 ships
``modules/theora``, whose ``ResourceFormatLoaderTheora`` recognises ``.ogv`` on
every platform it builds for, web included. So both videos can be produced *and
played by the game* rather than merely existing next to it.

What it produces:

  * ``loading_robot.ogv``   512x512, 8 fps, 0.5 s, looping -- the same four
    generated walk frames, the same union crop and the same scale as the sprite
    sheet in ``build_ui_art.py``, so the sheet and the video are one animation
    in two containers, not two different animations.
  * ``cinematic_opening.ogv`` 1280x720, 24 fps, 9.6 s -- a slow push-in on the
    shipped loading key art with a vignette and a fade at each end. 9.6 s and
    no captions on purpose: it is the same beat the in-engine cinematic runs,
    and the captions stay UI text the stage overlays, because text baked into
    pixels cannot be localised (docs/ART_DIRECTION.md §2).

Rules it keeps:

  * every frame is derived from a file in ``generated/`` or from a shipping
    texture -- nothing is synthesised from nothing, and a missing source is an
    error, never a placeholder;
  * rendering is deterministic: same sources -> same frames;
  * a sampled frame of each video is audited against the ART_DIRECTION palette
    with the same ``audit()`` the textures use;
  * if no encoder can be found the tool says so and exits non-zero. It never
    writes an empty file and never claims a video exists.

Requires Pillow and an ffmpeg with libtheora. Point ``FFMPEG`` at one, put one
on ``PATH``, or ``pip3 install --break-system-packages imageio-ffmpeg``.
"""
from __future__ import annotations

import argparse
import json
import os
import re
import shutil
import struct
import subprocess
import sys
import tempfile
import wave
from pathlib import Path

try:
    from PIL import Image, ImageChops
except ImportError:  # pragma: no cover
    print("ERROR: Pillow is not installed (pip3 install --break-system-packages Pillow)")
    raise SystemExit(2)

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(Path(__file__).resolve().parent))
import build_ui_art as art  # noqa: E402  (the crop rules live there)

SRC = art.SRC
OUT = art.OUT
MANIFEST = OUT / "video_manifest.json"

# --- asset C ---------------------------------------------------------------- #
ROBOT_OUT = "loading_robot.ogv"
ROBOT_SIZE = (512, 512)
ROBOT_FPS = 8

# --- asset F ---------------------------------------------------------------- #
CINEMATIC_OUT = "cinematic_opening.ogv"
CINEMATIC_SIZE = (1280, 720)
CINEMATIC_FPS = 24
CINEMATIC_SECONDS = 9.6
ZOOM_FROM = 1.00
ZOOM_TO = 1.18
FADE_IN_S = 0.4
FADE_OUT_S = 0.6
VIGNETTE_FLOOR = 0.45  # corners keep 45% of their luma

SAMPLE_RATE = 48000
THEORA_QUALITY = 6
VORBIS_QUALITY = 3


# --------------------------------------------------------------------------- #
# encoder discovery
# --------------------------------------------------------------------------- #
def find_ffmpeg() -> str | None:
    """An ffmpeg that can encode Theora, or None. Never guesses a path."""
    candidates: list[str] = []
    env = os.environ.get("FFMPEG")
    if env:
        candidates.append(env)
    on_path = shutil.which("ffmpeg")
    if on_path:
        candidates.append(on_path)
    try:
        import imageio_ffmpeg  # type: ignore

        candidates.append(imageio_ffmpeg.get_ffmpeg_exe())
    except Exception:
        pass
    for candidate in candidates:
        if not candidate:
            continue
        try:
            out = subprocess.run(
                [candidate, "-hide_banner", "-encoders"],
                capture_output=True,
                text=True,
                timeout=120,
            )
        except (OSError, subprocess.SubprocessError):
            continue
        if "libtheora" in out.stdout:
            return candidate
    return None


def silent_wav(path: Path, seconds: float) -> Path:
    """A real silent Vorbis-friendly WAV.

    Godot's Theora playback seeks by audio granule position when a stream has
    one, so the videos carry a silent track rather than none.
    """
    frames = int(round(seconds * SAMPLE_RATE))
    with wave.open(str(path), "wb") as handle:
        handle.setnchannels(2)
        handle.setsampwidth(2)
        handle.setframerate(SAMPLE_RATE)
        handle.writeframes(struct.pack("<h", 0) * frames * 2)
    return path


# --------------------------------------------------------------------------- #
# frame rendering
# --------------------------------------------------------------------------- #
def robot_frames(directory: Path) -> list[Path]:
    """The four walk frames cropped exactly like the sprite sheet's cells."""
    sources = [SRC / name for name in art.ROBOT_FRAMES]
    missing = [str(source) for source in sources if not source.exists()]
    if missing:
        raise FileNotFoundError("robot frames missing: " + ", ".join(missing))
    opened = [Image.open(source).convert("RGB") for source in sources]
    box = art.union_box([art.content_box(frame) for frame in opened])
    crops = [frame.crop(box) for frame in opened]
    scale = min(art.ROBOT_CELL / crops[0].size[0], art.ROBOT_CELL / crops[0].size[1])
    written: list[Path] = []
    for index, crop in enumerate(crops):
        cell = crop.resize(
            (
                max(1, round(crop.size[0] * scale)),
                max(1, round(crop.size[1] * scale)),
            ),
            Image.LANCZOS,
        )
        frame = Image.new("RGB", ROBOT_SIZE, art.BACKDROP)
        # Same placement as the sheet: centred across, sitting on the bottom.
        frame.paste(
            cell,
            (
                (ROBOT_SIZE[0] - cell.size[0]) // 2,
                ROBOT_SIZE[1] - cell.size[1],
            ),
        )
        target = directory / f"{index + 1:04d}.png"
        frame.save(target, optimize=True)
        written.append(target)
    return written


def vignette(size: tuple[int, int]) -> Image.Image:
    """Radial falloff: 255 in the middle, VIGNETTE_FLOOR*255 at the corners."""
    gradient = Image.radial_gradient("L").resize(size, Image.BICUBIC)
    floor = int(round(VIGNETTE_FLOOR * 255))
    return gradient.point(lambda value: floor + int(value / 255 * (255 - floor)))


def cinematic_frames(directory: Path) -> list[Path]:
    """A push-in on the shipped key art, one frame at a time."""
    source = OUT / "loading_keyart.jpg"
    if not source.exists():
        raise FileNotFoundError(f"key art missing at {source}")
    base = art.cover(Image.open(source).convert("RGB"), CINEMATIC_SIZE)
    falloff = vignette(CINEMATIC_SIZE).convert("RGB")
    total = int(round(CINEMATIC_SECONDS * CINEMATIC_FPS))
    written: list[Path] = []
    for index in range(total):
        t = index / max(total - 1, 1)
        # Ease out, so the move decelerates into the last caption beat instead
        # of stopping dead.
        eased = 1.0 - (1.0 - t) ** 2
        zoom = ZOOM_FROM + (ZOOM_TO - ZOOM_FROM) * eased
        crop_w = CINEMATIC_SIZE[0] / zoom
        crop_h = CINEMATIC_SIZE[1] / zoom
        left = (CINEMATIC_SIZE[0] - crop_w) / 2.0
        top = (CINEMATIC_SIZE[1] - crop_h) / 2.0
        frame = base.crop(
            (round(left), round(top), round(left + crop_w), round(top + crop_h))
        ).resize(CINEMATIC_SIZE, Image.LANCZOS)
        frame = ImageChops.multiply(frame, falloff)
        elapsed = index / float(CINEMATIC_FPS)
        fade = 1.0
        if elapsed < FADE_IN_S:
            fade = elapsed / FADE_IN_S
        remaining = CINEMATIC_SECONDS - elapsed
        if remaining < FADE_OUT_S:
            fade = min(fade, max(remaining, 0.0) / FADE_OUT_S)
        if fade < 1.0:
            frame = ImageChops.multiply(
                frame, Image.new("RGB", CINEMATIC_SIZE, (int(255 * fade),) * 3)
            )
        target = directory / f"{index + 1:04d}.png"
        frame.save(target, optimize=True)
        written.append(target)
    return written


# --------------------------------------------------------------------------- #
# encode + verify
# --------------------------------------------------------------------------- #
def encode(ffmpeg: str, frames: Path, fps: int, silence: Path, target: Path) -> None:
    command = [
        ffmpeg, "-y", "-hide_banner", "-loglevel", "error",
        "-framerate", str(fps), "-i", str(frames / "%04d.png"),
        "-i", str(silence),
        "-c:v", "libtheora", "-q:v", str(THEORA_QUALITY), "-pix_fmt", "yuv420p",
        "-c:a", "libvorbis", "-q:a", str(VORBIS_QUALITY),
        "-shortest", str(target),
    ]
    result = subprocess.run(command, capture_output=True, text=True, timeout=1800)
    if result.returncode != 0 or not target.exists():
        raise RuntimeError(f"ffmpeg failed on {target.name}:\n{result.stderr.strip()}")


def probe(ffmpeg: str, path: Path) -> dict:
    """Stream facts parsed out of ffmpeg's own header dump."""
    result = subprocess.run(
        [ffmpeg, "-hide_banner", "-i", str(path)],
        capture_output=True,
        text=True,
        timeout=300,
    )
    text = result.stderr
    info: dict = {}
    match = re.search(r"Duration: (\d+):(\d+):([\d.]+)", text)
    if match:
        hours, minutes, seconds = match.groups()
        info["duration_s"] = round(
            int(hours) * 3600 + int(minutes) * 60 + float(seconds), 3
        )
    match = re.search(r"Video: theora.*?, (\d+)x(\d+)", text)
    if match:
        info["size"] = [int(match.group(1)), int(match.group(2))]
    match = re.search(r"(\d+(?:\.\d+)?) fps", text)
    if match:
        info["fps"] = float(match.group(1))
    info["has_audio"] = "Audio: vorbis" in text
    info["bytes"] = path.stat().st_size
    return info


def build(args: argparse.Namespace) -> int:
    ffmpeg = find_ffmpeg()
    if ffmpeg is None:
        print("ERROR: no ffmpeg with libtheora found. Set FFMPEG, put one on PATH,\n"
              "       or: pip3 install --break-system-packages imageio-ffmpeg")
        return 2
    print(f"encoder: {ffmpeg}")

    problems: list[str] = []
    manifest: dict = {"encoder": "libtheora", "container": "ogv", "videos": []}

    jobs = [
        ("loading_robot", ROBOT_OUT, ROBOT_FPS, robot_frames, ROBOT_SIZE),
        ("cinematic_opening", CINEMATIC_OUT, CINEMATIC_FPS, cinematic_frames,
         CINEMATIC_SIZE),
    ]
    for key, name, fps, render, size in jobs:
        if args.check:
            target = OUT / name
            if not target.exists():
                problems.append(f"{key}: {name} is missing")
                continue
            info = probe(ffmpeg, target)
            print(f"ok  {name:<24} {info.get('size')}  {info.get('duration_s')}s  "
                  f"{info['bytes'] // 1024} kB")
            manifest["videos"].append({"key": key, "file": f"res://assets/ui/{name}",
                                       **info})
            continue

        with tempfile.TemporaryDirectory(prefix="aegis-video-") as tmp:
            tmp_path = Path(tmp)
            try:
                frames = render(tmp_path)
            except (FileNotFoundError, RuntimeError) as error:
                problems.append(f"{key}: {error}")
                continue
            # Audit a sample of what was rendered: the palette rule applies to
            # pixels that ship, whatever container carries them.
            step = max(1, len(frames) // 8)
            samples = [art.audit(frame) for frame in frames[::step]]
            off_palette = max(sample["off_palette_share"] for sample in samples)
            within = all(sample["within_palette"] for sample in samples)
            silence = silent_wav(tmp_path / "silence.wav", len(frames) / float(fps))
            target = OUT / name
            try:
                encode(ffmpeg, tmp_path, fps, silence, target)
            except RuntimeError as error:
                problems.append(str(error))
                continue
            info = probe(ffmpeg, target)
            entry = {
                "key": key,
                "file": f"res://assets/ui/{name}",
                "format": "OGV (Theora + Vorbis)",
                "size": info.get("size", list(size)),
                "fps": fps,
                "frames": len(frames),
                "duration_s": info.get("duration_s"),
                "bytes": info["bytes"],
                "has_audio": info.get("has_audio", False),
                "off_palette_share": round(off_palette, 4),
                "within_palette": within,
                "sampled_frames": len(samples),
            }
            manifest["videos"].append(entry)
            flag = "ok " if within else "DRIFT"
            print(f"{flag} {name:<24} {entry['size'][0]}x{entry['size'][1]}  "
                  f"{len(frames)} frames @ {fps} fps  {entry['duration_s']}s  "
                  f"{info['bytes'] // 1024} kB  off-palette {off_palette * 100:.1f}%")

    if not args.check:
        MANIFEST.write_text(json.dumps(manifest, indent=2) + "\n", encoding="utf-8")
        print(f"\nmanifest: {MANIFEST.relative_to(ROOT)}")
    for problem in problems:
        print(f"ERROR: {problem}")
    return 1 if problems else 0


def main() -> int:
    parser = argparse.ArgumentParser(
        description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter
    )
    parser.add_argument("--check", action="store_true", help="verify only, write nothing")
    return build(parser.parse_args())


if __name__ == "__main__":
    sys.exit(main())
