#!/usr/bin/env python3
"""Render the prayer/tasbeeh alert sounds that ship inside the app.

The app plays three short, self-contained sounds and never downloads audio:

* ``chime_prayer.wav``   — a calm two-strike bell when a prayer time arrives.
* ``chime_complete.wav`` — three ascending soft notes when a tasbeeh target is
  reached (Tasbeeh-e-Zahra included).
* ``tap_click.wav``      — a very quiet click under every tasbeeh tap.

They are synthesised, so the repository carries no third-party audio and the
APK stays small (~180 kB for all three). Every strike is built from a handful
of inharmonic partials with an exponential decay, which is what makes a sine
sound like a struck bell rather than a beep.

Usage::

    python3 scripts/make_alert_sounds.py        # writes app/assets/audio/*.wav

Requires ``numpy`` (``pip install numpy``). The script is deterministic: run it
twice and the files are byte-identical, so a rerun never shows up as a diff
unless a sound is actually changed.
"""
from __future__ import annotations

import wave
from pathlib import Path

import numpy as np

ROOT = Path(__file__).resolve().parents[1]
OUTPUT = ROOT / "app" / "assets" / "audio"

SAMPLE_RATE = 22050
MAX_AMPLITUDE = 32767


def _bell(duration: float, frequency: float, decay: float, gain: float = 1.0) -> np.ndarray:
    """One struck-bell tone: inharmonic partials, each with its own decay."""
    samples = int(duration * SAMPLE_RATE)
    t = np.arange(samples, dtype=np.float64) / SAMPLE_RATE
    #
    # (ratio to the fundamental, relative level, decay multiplier)
    partials = (
        (1.00, 1.00, 1.00),
        (2.00, 0.42, 1.55),
        (2.99, 0.26, 1.90),
        (4.21, 0.14, 2.40),
        (5.43, 0.08, 3.00),
        (6.79, 0.05, 3.60),
    )
    tone = np.zeros(samples, dtype=np.float64)
    for ratio, level, faster in partials:
        tone += level * np.sin(2.0 * np.pi * frequency * ratio * t) * np.exp(-t / (decay / faster))
    # A short, quiet noise transient gives the strike its "clack" without a click.
    transient_length = min(samples, int(0.012 * SAMPLE_RATE))
    rng = np.random.default_rng(int(frequency))  # fixed seed → reproducible files
    tone[:transient_length] += 0.06 * rng.uniform(-1.0, 1.0, transient_length) * np.exp(
        -np.arange(transient_length) / (0.004 * SAMPLE_RATE)
    )
    return gain * tone


def _click(duration: float = 0.055) -> np.ndarray:
    """A soft, high-frequency tick — felt more than heard under a fingertip."""
    samples = int(duration * SAMPLE_RATE)
    t = np.arange(samples, dtype=np.float64) / SAMPLE_RATE
    body = np.sin(2.0 * np.pi * 1180.0 * t) * np.exp(-t / 0.010)
    body += 0.35 * np.sin(2.0 * np.pi * 2360.0 * t) * np.exp(-t / 0.006)
    rng = np.random.default_rng(7)
    body += 0.12 * rng.uniform(-1.0, 1.0, samples) * np.exp(-t / 0.003)
    return body


def _place(track: np.ndarray, tone: np.ndarray, at_seconds: float) -> None:
    start = int(at_seconds * SAMPLE_RATE)
    end = min(len(track), start + len(tone))
    track[start:end] += tone[: end - start]


def _fade_edges(track: np.ndarray, seconds: float = 0.012) -> np.ndarray:
    """Remove the DC step at both ends so playback never pops."""
    length = min(int(seconds * SAMPLE_RATE), len(track) // 2)
    if length <= 0:
        return track
    ramp = np.linspace(0.0, 1.0, length)
    track[:length] *= ramp
    track[-length:] *= ramp[::-1]
    return track


def _write(name: str, track: np.ndarray) -> None:
    track = _fade_edges(track)
    peak = float(np.max(np.abs(track))) or 1.0
    normalised = np.clip(track / peak * 0.82, -1.0, 1.0)
    pcm = (normalised * MAX_AMPLITUDE).astype("<i2")
    OUTPUT.mkdir(parents=True, exist_ok=True)
    path = OUTPUT / name
    with wave.open(str(path), "wb") as handle:
        handle.setnchannels(1)
        handle.setsampwidth(2)
        handle.setframerate(SAMPLE_RATE)
        handle.writeframes(pcm.tobytes())
    print(f"wrote {path.relative_to(ROOT)} ({path.stat().st_size} bytes, {len(track) / SAMPLE_RATE:.2f}s)")


def prayer_chime() -> np.ndarray:
    """Two calm strikes, a fourth apart — a soft call, not an alarm."""
    track = np.zeros(int(2.4 * SAMPLE_RATE), dtype=np.float64)
    _place(track, _bell(2.2, 587.33, 1.05), 0.00)  # D5
    _place(track, _bell(2.0, 783.99, 0.95, gain=0.82), 0.62)  # G5
    return track


def complete_chime() -> np.ndarray:
    """Three ascending notes: a gentle 'done' for a finished tasbeeh."""
    track = np.zeros(int(2.0 * SAMPLE_RATE), dtype=np.float64)
    _place(track, _bell(1.5, 523.25, 0.72), 0.00)  # C5
    _place(track, _bell(1.5, 659.25, 0.72, gain=0.9), 0.26)  # E5
    _place(track, _bell(1.7, 783.99, 0.80, gain=0.95), 0.52)  # G5
    return track


def main() -> int:
    _write("chime_prayer.wav", prayer_chime() * 0.9)
    _write("chime_complete.wav", complete_chime() * 0.9)
    _write("tap_click.wav", _click() * 0.35)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
