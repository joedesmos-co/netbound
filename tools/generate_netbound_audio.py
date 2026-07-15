#!/usr/bin/env python3
"""Generate original procedural WAV assets for Netbound Phase 7.

The sounds are simple synthesized tones/noise shaped with envelopes. They use no
external samples and can be regenerated deterministically.
"""

from __future__ import annotations

import math
import os
import random
import struct
import wave

SAMPLE_RATE = 44_100
OUT_DIR = os.path.join("game", "audio", "generated")


def envelope(t: float, duration: float, attack: float = 0.01, release: float = 0.08) -> float:
    if t < attack:
        return t / max(attack, 0.0001)
    if t > duration - release:
        return max(0.0, (duration - t) / max(release, 0.0001))
    return 1.0


def tone(
    t: float,
    freq: float,
    sweep: float = 0.0,
    square: float = 0.0,
) -> float:
    f = freq + sweep * t
    sine = math.sin(2.0 * math.pi * f * t)
    if square <= 0.0:
        return sine
    sq = 1.0 if sine >= 0.0 else -1.0
    return sine * (1.0 - square) + sq * square


def write_wav(name: str, samples: list[float], target_peak: float = 0.82) -> None:
    os.makedirs(OUT_DIR, exist_ok=True)
    peak = max(0.001, max(abs(s) for s in samples))
    gain = target_peak / peak
    path = os.path.join(OUT_DIR, f"{name}.wav")
    with wave.open(path, "w") as f:
        f.setnchannels(1)
        f.setsampwidth(2)
        f.setframerate(SAMPLE_RATE)
        frames = bytearray()
        for sample in samples:
            value = max(-1.0, min(1.0, sample * gain))
            frames += struct.pack("<h", int(value * 32767.0))
        f.writeframes(frames)


def synth(name: str, duration: float, fn, target_peak: float = 0.82) -> None:
    rng = random.Random(name)
    samples = []
    count = int(duration * SAMPLE_RATE)
    for i in range(count):
        t = i / SAMPLE_RATE
        samples.append(fn(t, duration, rng))
    write_wav(name, samples, target_peak)


def click(freq: float, second: float = 0.0, noise: float = 0.0):
    return lambda t, d, r: (
        tone(t, freq, -freq * 0.7)
        + (tone(t, second, -second * 0.3) * 0.45 if second > 0.0 else 0.0)
        + (r.uniform(-1.0, 1.0) * noise)
    ) * envelope(t, d, 0.002, d * 0.55)


def impact(freq: float, noise: float, decay: float):
    return lambda t, d, r: (
        tone(t, freq, -freq * 0.9, 0.18) * 0.45
        + r.uniform(-1.0, 1.0) * noise
    ) * math.exp(-t * decay) * envelope(t, d, 0.001, 0.05)


def rising(freq_a: float, freq_b: float, shimmer: float = 0.0):
    def fn(t: float, d: float, r: random.Random) -> float:
        p = t / d
        freq = freq_a + (freq_b - freq_a) * p
        return (
            tone(t, freq)
            + tone(t, freq * 1.5, 0.0) * 0.25
            + r.uniform(-1.0, 1.0) * shimmer
        ) * envelope(t, d, 0.01, 0.12)

    return fn


def sting(base: float, happy: bool = True):
    intervals = [1.0, 1.25, 1.5, 2.0] if happy else [1.0, 0.84, 0.71, 0.5]

    def fn(t: float, d: float, r: random.Random) -> float:
        p = t / d
        idx = min(int(p * len(intervals)), len(intervals) - 1)
        freq = base * intervals[idx]
        value = tone(t, freq) * 0.58 + tone(t, freq * 2.0) * 0.18
        return value * envelope(t, d, 0.015, 0.22)

    return fn


def goal_chirp(t: float, duration: float, rng: random.Random) -> float:
    """Short sporty confirmation: soft net tap followed by two bright notes."""
    value = rng.uniform(-1.0, 1.0) * 0.045 * math.exp(-t * 30.0)
    notes = ((0.025, 392.0), (0.125, 523.25))
    for start, frequency in notes:
        local = t - start
        if 0.0 <= local <= 0.18:
            note_env = envelope(local, 0.18, 0.006, 0.1)
            value += (
                tone(local, frequency) * 0.62
                + tone(local, frequency * 2.0) * 0.08
            ) * note_env
    return value


def result_flourish(t: float, duration: float, rng: random.Random) -> float:
    """Light three-note result cue, distinct from the immediate goal chirp."""
    value = 0.0
    notes = ((0.0, 523.25), (0.14, 659.25), (0.28, 783.99))
    for start, frequency in notes:
        local = t - start
        if 0.0 <= local <= 0.28:
            note_env = envelope(local, 0.28, 0.012, 0.16)
            value += (
                tone(local, frequency) * 0.5
                + tone(local, frequency * 1.5) * 0.06
            ) * note_env
    return value


def loop(name: str, duration: float, base: float, mood: float) -> None:
    def fn(t: float, d: float, r: random.Random) -> float:
        beat = (math.sin(2.0 * math.pi * 1.0 * t) > 0.86) * 0.22
        pulse = math.sin(2.0 * math.pi * base * t) * 0.28
        fifth = math.sin(2.0 * math.pi * base * 1.5 * t) * 0.12
        air = math.sin(2.0 * math.pi * (base * 0.5 + mood) * t) * 0.1
        fade = math.sin(math.pi * min(1.0, t / 0.08)) * math.sin(math.pi * min(1.0, (d - t) / 0.08))
        return (pulse + fifth + air + beat) * fade

    synth(name, duration, fn)


def main() -> None:
    # UI
    synth("ui_tap", 0.09, click(820.0, 1240.0, 0.015))
    synth("ui_confirm", 0.16, rising(620.0, 1080.0, 0.01))
    synth("ui_back", 0.13, rising(620.0, 360.0, 0.01))
    synth("ui_locked", 0.18, click(220.0, 170.0, 0.02))
    synth("ui_tab", 0.11, click(980.0, 1320.0, 0.006))

    # Gameplay
    synth("aim_start", 0.22, rising(180.0, 380.0, 0.012))
    synth("shot_weak", 0.18, impact(180.0, 0.08, 15.0))
    synth("shot_release", 0.22, impact(260.0, 0.12, 13.0))
    synth("shot_strong", 0.26, impact(340.0, 0.16, 11.0))
    synth("impact_ground", 0.16, impact(130.0, 0.18, 24.0))
    synth("impact_obstacle", 0.19, impact(190.0, 0.16, 18.0))
    synth("impact_bounce", 0.22, rising(280.0, 620.0, 0.07))
    synth("impact_post", 0.26, impact(480.0, 0.08, 13.0))
    synth("hazard_cue", 0.2, click(520.0, 780.0, 0.015))
    synth("near_miss", 0.34, rising(880.0, 520.0, 0.02))
    synth("goal_scored", 0.34, goal_chirp, target_peak=0.44)

    # Results
    synth("result_success", 0.58, result_flourish, target_peak=0.36)
    synth("result_star", 0.18, rising(860.0, 1380.0, 0.005))
    synth("result_failure", 0.7, sting(260.0, False))
    synth("cosmetic_unlock", 0.85, sting(500.0, True))

    # Lightweight loops
    loop("music_menu_loop", 4.0, 110.0, 18.0)
    loop("music_gameplay_loop", 4.0, 82.0, 9.0)
    loop("music_final_loop", 4.0, 124.0, 27.0)


if __name__ == "__main__":
    main()
