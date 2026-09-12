"""Prepare a credited, quiet harp candidate for the isolated combat audition."""
from pathlib import Path
import hashlib
import json
import sys

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT / "artifacts/audio/python"))
import numpy as np
import soundfile as sf

OUT = ROOT / "artifacts/audio/music_mystery_v1"
SOURCE_URL = "https://opengameart.org/sites/default/files/Harp.ogg"
PAGE = "https://opengameart.org/content/soft-mysterious-harp-loop"
LICENSE = "https://creativecommons.org/licenses/by/3.0/"


def main():
    source = OUT / "sources/Harp.ogg"
    x, rate = sf.read(source, always_2d=True)
    # Slightly slower/lower for this audition; the composition remains the author's.
    position = np.arange(round(len(x) * 48000 / (rate * .9))) * rate * .9 / 48000
    y = np.column_stack([np.interp(position, np.arange(len(x)), channel) for channel in x.T])
    size = 1 << (len(y) * 2 - 1).bit_length()
    freq = np.fft.rfftfreq(size, 1 / 48000)
    gain = 10 ** (np.interp(freq, [0, 1800, 3500, 6000, 12000, 24000],
                          [0, 0, -3, -10, -35, -80]) / 20)
    y = np.fft.irfft(np.fft.rfft(y, n=size, axis=0) * gain[:, None], n=size, axis=0)[:len(y)]
    fade = 4800
    y[:fade] *= np.linspace(0, 1, fade)[:, None]
    y[-fade:] *= np.linspace(1, 0, fade)[:, None]
    y *= min(10 ** (-30 / 20) / np.sqrt(np.mean(y * y)),
             10 ** (-18 / 20) / np.max(np.abs(y)))
    destination = OUT / "mysterious_harp.wav"
    sf.write(destination, y, 48000, subtype="PCM_16")
    delivered, sr = sf.read(destination, always_2d=True)
    peak = float(np.max(np.abs(delivered)))
    passed = sr == 48000 and np.isfinite(delivered).all() and peak < .14
    credits = ("Soft Mysterious Harp Loop — VWolfdog (Jordy Hake)\n"
               f"Source: {PAGE}\nLicense: CC BY 3.0 — {LICENSE}\n"
               "Catabase audition adaptation: speed/pitch at 90%, gentle treble reduction, "
               "100 ms edge fades, level adjustment and WAV export. No endorsement implied.\n")
    (OUT / "CREDITS.txt").write_text(credits, encoding="utf-8")
    report = {"cost_eur": 0, "source_url": SOURCE_URL, "page": PAGE, "license": LICENSE,
              "source_sha256": hashlib.sha256(source.read_bytes()).hexdigest(),
              "credit": credits, "duration_s": len(delivered) / sr,
              "peak_dbfs": float(20 * np.log10(peak)),
              "rms_dbfs": float(20 * np.log10(np.sqrt(np.mean(delivered ** 2)))),
              "passed": bool(passed)}
    (OUT / "manifest.json").write_text(json.dumps(report, ensure_ascii=False, indent=2), encoding="utf-8")
    print(json.dumps(report, ensure_ascii=False))
    if not passed:
        raise SystemExit(1)


if __name__ == "__main__":
    main()
