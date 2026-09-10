"""Deterministic original audio for halts; standard library only, no download.

Bounded filtered noise layers, crackles and damped resonances; mono 22.05 kHz
samples are positioned by Godot. Loops use a circular crossfade at their seam.
"""
import math
import random
import struct
import wave
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
RATE = 22050


def synth(kind, seconds, seed):
    rng = random.Random(seed)
    values = []
    low = slower = 0.0
    burst = 0.0
    for index in range(int(RATE * seconds)):
        t = index / RATE
        noise = rng.uniform(-1.0, 1.0)
        low += 0.18 * (noise - low)
        slower += 0.025 * (noise - slower)
        if kind == "water":
            bubbles = sum(math.sin(t * frequency * math.tau + i) *
                          max(0, math.sin(t * (0.4 + i * 0.13) * math.tau)) ** 12
                          for i, frequency in enumerate((139, 203, 281, 367)))
            value = low * 0.62 + slower * 0.35 + bubbles * 0.025
        elif kind == "fire":
            if rng.random() < 0.0006:
                burst = rng.uniform(0.2, 0.7)
            burst *= 0.978
            value = slower * 1.1 + low * 0.27 + noise * burst * 0.24
        else:
            envelope = math.exp(-t * 35) * min(1, t * 1300)
            value = (low * 0.9 + math.sin(t * 112 * math.tau) * 0.2) * envelope
        values.append(value)
    if kind != "step":
        seam = int(RATE * 0.15)
        for index in range(seam):
            a = index / seam
            values[index] = values[-seam + index] * (1 - a) + values[index] * a
        values = values[:-seam]
    peak = max(abs(v) for v in values)
    return [max(-32767, min(32767, round(v / peak * 0.65 * 32767))) for v in values]


if __name__ == "__main__":
    folder = ROOT / "asset/audio/halts"
    folder.mkdir(parents=True, exist_ok=True)
    for name, kind, duration, seed in [("water", "water", 5.15, 271), ("fire", "fire", 5.15, 811), ("stone_step", "step", 0.2, 31)]:
        samples = synth(kind, duration, seed)
        with wave.open(str(folder / (name + ".wav")), "wb") as out:
            out.setparams((1, 2, RATE, len(samples), "NONE", "not compressed"))
            out.writeframes(struct.pack("<" + "h" * len(samples), *samples))
    print("Three original mono sounds written to asset/audio/halts; 22050 Hz, bounded peaks.")
