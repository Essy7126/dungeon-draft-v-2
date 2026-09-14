"""Extend the accepted natural materials; never reuse the rejected electronic cues."""
from pathlib import Path
import json
import sys
import shutil

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT / "artifacts/audio/python"))
import numpy as np
import soundfile as sf

OUT = ROOT / "assets/audio/catabase/feedback"
SOURCES = ROOT / "artifacts/audio"


def material(file, duration, speed=1.0, reverse=False):
    x, rate = sf.read(SOURCES / file, always_2d=True)
    x = x.mean(axis=1)
    if reverse:
        x = x[::-1]
    count = min(round(duration * 48000), round(len(x) * 48000 / rate / speed))
    y = np.interp(np.arange(count) * rate * speed / 48000, np.arange(len(x)), x)
    return y / max(abs(y).max(), 1e-8)


def main():
    OUT.mkdir(parents=True, exist_ok=True)
    leather = "natural_v2/audition/LeatherArmor_Rustle_03.wav"
    chain = "natural_v2/audition/Chainmail_Impact_Hard_03.wav"
    guard = "soft_v5/guard.wav"
    shot = "soft_v5/shot.wav"
    cases = {
        "select": ([(leather, .11, 1.1, False, 1, 0)], -23),
        "open": ([(leather, .3, .9, False, 1, 0)], -20),
        "close": ([(leather, .22, .95, True, 1, 0)], -22),
        "confirm": ([(leather, .17, 1, False, .4, 0), (guard, .28, .8, False, .45, .06)], -18),
        "error": ([(leather, .15, .65, False, 1, 0)], -24),
        "equip": ([(leather, .32, .9, False, .5, 0), (chain, .26, .75, False, .4, .09)], -17),
        "reward": ([(leather, .3, .8, False, .18, 0), (guard, .85, .85, False, .6, .1)], -16),
        "turn": ([(leather, .16, .85, False, 1, 0)], -23),
        "heal": ([(guard, .55, .78, True, .35, 0), (leather, .25, .8, False, .15, .2)], -19),
        "block": ([(guard, .32, .92, False, 1, 0)], -13),
        "dodge": ([(leather, .28, 1.1, False, 1, 0)], -19),
        "hit": ([(chain, .36, .82, False, 1, 0)], -13),
        "magic_hit": ([(shot, .48, .82, False, .6, 0), (leather, .2, .8, True, .15, .08)], -15),
        "fall": ([(leather, .5, .7, False, .6, 0), (chain, .35, .6, False, .3, .13)], -17),
    }
    records = []
    for key, (layers, peak) in cases.items():
        parts = [(material(f, d, s, r) * g, round(at * 48000)) for f, d, s, r, g, at in layers]
        y = np.zeros(max(len(x) + at for x, at in parts))
        for x, at in parts:
            y[at:at + len(x)] += x
        size = 1 << (len(y) * 2 - 1).bit_length()
        frequency = np.fft.rfftfreq(size, 1 / 48000)
        gain = 10 ** (np.interp(frequency, [0, 1200, 3000, 5500, 10000, 24000], [0, 0, -8, -22, -48, -90]) / 20)
        y = np.fft.irfft(np.fft.rfft(y, n=size) * gain, n=size)[:len(y)]
        y[:96] *= np.linspace(0, 1, 96)
        tail = min(2400, len(y))
        y[-tail:] *= np.linspace(1, 0, tail) ** 1.5
        y *= 10 ** (peak / 20) / max(abs(y).max(), 1e-8)
        sf.write(OUT / f"{key}.wav", y, 48000, subtype="PCM_16")
        result, rate = sf.read(OUT / f"{key}.wav")
        assert rate == 48000 and np.isfinite(result).all() and abs(result).max() < .3
        assert abs(result[0]) < .001 and abs(result[-1]) < .001
        records.append({"cue": key, "peak_dbfs": peak, "duration": len(result) / rate, "layers": layers})
    for index in range(1, 4):
        shutil.copyfile(SOURCES / f"free_starter_v1/wav/step_stone_{index:02}.wav", OUT / f"step_{index}.wav")
    report = {"cost_eur": 0, "material_license": "Sonniss GDC 2.0; see ../CREDITS.md",
              "steps": "Kenney Impact Sounds CC0; accepted first audition, unchanged.",
              "cues": records, "passed": True}
    (OUT / "manifest.json").write_text(json.dumps(report, ensure_ascii=False, indent=2), encoding="utf-8")
    print(json.dumps({"passed": True, "new_cues": len(records), "step_variants": 3}))


if __name__ == "__main__":
    main()
