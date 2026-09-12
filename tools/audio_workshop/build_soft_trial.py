"""Create mellow, short combat candidates from the accepted internal audition."""
from pathlib import Path
import json
import sys

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT / "artifacts/audio/python"))
import numpy as np
import soundfile as sf

OUT = ROOT / "artifacts/audio/soft_v5"
RATE = 96000


def soften(x):
    # Smooth, broad treble reduction; padded FFT avoids wraparound at contact.
    size = 1 << (len(x) * 2 - 1).bit_length()
    freq = np.fft.rfftfreq(size, 1 / RATE)
    db = np.interp(freq, [0, 1000, 2200, 3500, 5500, 8500, 16000, 48000],
                   [0, 0, -3, -8, -17, -28, -65, -90])
    gain = 10 ** (db / 20)
    y = np.fft.irfft(np.fft.rfft(x, n=size, axis=0) * gain[:, None], n=size, axis=0)[:len(x)]
    return y


def high_fraction(x, rate):
    energy = np.abs(np.fft.rfft(x, axis=0)) ** 2
    mask = np.fft.rfftfreq(len(x), 1 / rate) >= 3500
    return float(energy[mask].sum() / max(energy.sum(), 1e-12))


def main():
    OUT.mkdir(parents=True, exist_ok=True)
    cases = [
        ("strike", "Frappe", "mythic_v3/frappe_fantaisie.wav", .10, .72, -8),
        ("guard", "Garde", "mythic_v3/airain_fantaisie.wav", .10, .85, -11),
        ("shot", "Impact du tir", "mythic_v3/parade_fantaisie.wav", .10, .52, -10),
        ("dash", "Percée : mouvement du cuir", "natural_v2/audition/LeatherArmor_Rustle_03.wav", 0, .45, -14),
    ]
    parts, checks = [], []
    for key, label, source, start, duration, peak in cases:
        x, rate = sf.read(ROOT / "artifacts/audio" / source, always_2d=True)
        if rate != RATE:
            raise ValueError("Expected 96 kHz source")
        x = x[round(start * rate):round((start + duration) * rate)]
        before = high_fraction(x, rate)
        y = soften(x)
        # Resampling to 48 kHz follows the strong anti-alias roll-off above.
        y = y[::2]
        a, b = 48, min(len(y), 4800)
        y[:a] *= np.linspace(0, 1, a)[:, None]
        y[-b:] *= np.linspace(1, 0, b)[:, None] ** 1.7
        y *= 10 ** (peak / 20) / max(np.max(np.abs(y)), 1e-9)
        path = OUT / f"{key}.wav"
        sf.write(path, y, 48000, subtype="PCM_16")
        delivered, sr = sf.read(path, always_2d=True)
        after = high_fraction(delivered, sr)
        passed = sr == 48000 and np.isfinite(delivered).all() and np.max(np.abs(delivered)) < .4 and after < before and np.max(np.abs(delivered[-1])) < .001
        checks.append({"id": key, "label": label, "source": source, "start_s": start,
                       "duration_s": len(delivered) / sr, "peak_dbfs": peak,
                       "high_energy_before": before, "high_energy_after": after, "passed": bool(passed)})
        if delivered.shape[1] == 1:
            delivered = np.repeat(delivered, 2, axis=1)
        parts.extend([delivered, np.zeros((24000, 2))])
    sf.write(OUT / "ecoute_douce.wav", np.concatenate(parts), 48000, subtype="PCM_16")
    report = {"cost_eur": 0, "status": "Isolated first-combat trial; artistic judgement remains subjective.",
              "license": "Sonniss GDC; internal Catabase assets, not a distributable sound pack.",
              "provenance": "../natural_v2/manifest.json and ../mythic_v3/manifest.json",
              "processing": "Broad treble reduction, short tails, 48 kHz WAV, moderate individual peaks.",
              "checks": checks, "failed": sum(not c["passed"] for c in checks)}
    (OUT / "manifest.json").write_text(json.dumps(report, ensure_ascii=False, indent=2), encoding="utf-8")
    print(json.dumps(report, ensure_ascii=False))
    if report["failed"]:
        raise SystemExit(1)


if __name__ == "__main__":
    main()
