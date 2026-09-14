"""Shape the CC0 JaggedStone cave ambience into a soft, slowly breathing loop."""
from pathlib import Path
import hashlib
import json
import sys

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT / 'artifacts/audio/python'))
import numpy as np
import soundfile as sf

SOURCE = ROOT / 'artifacts/audio/cavern_v1/sources/dungeon_ambient_1_0.ogg'
OUT = ROOT / 'assets/audio/catabase/ambience'


def main():
    OUT.mkdir(parents=True, exist_ok=True)
    original, rate = sf.read(SOURCE, dtype='float32', always_2d=True)
    rate_out = 32000
    speed = .82
    count = round(len(original) * rate_out / rate / speed)
    positions = np.arange(count) * rate * speed / rate_out
    x = np.column_stack([np.interp(positions, np.arange(len(original)), c) for c in original.T])
    if x.shape[1] == 1:
        x = np.repeat(x, 2, axis=1)
    x -= x.mean(axis=0)
    # Broad filtering, no oscillator or melodic layer. Sub-bass and sharp drips recede.
    f = np.fft.rfftfreq(len(x), 1 / rate_out)
    gain = 10 ** (np.interp(f, [0, 25, 55, 450, 1000, 2000, 4500, 16000],
                          [-90, -24, 0, 0, -4, -14, -38, -90]) / 20)
    for ch in range(2):
        x[:, ch] = np.fft.irfft(np.fft.rfft(x[:, ch]) * gain, n=len(x))
    # Wrap the original tail into the head, preserving ambience across the seam.
    overlap = min(6 * rate_out, len(x) // 4)
    blend = np.linspace(0, 1, overlap)[:, None]
    head = x[-overlap:] * (1 - blend) + x[:overlap] * blend
    x = np.concatenate([head, x[overlap:-overlap]])
    phase = np.arange(len(x)) / len(x)
    breath = np.interp(phase, [0, .13, .23, .38, .51, .68, .79, .91, 1],
                       [.45, .9, .18, .42, .95, .14, .3, .65, .45])
    x *= breath[:, None]
    # Round isolated water transients so the air remains audible without loud drops.
    knee = 3.5 * np.sqrt(np.mean(x*x))
    x = knee * np.tanh(x / knee)
    rms = np.sqrt(np.mean(x*x))
    x *= min(10**(-30/20) / rms, 10**(-17/20) / np.max(abs(x)))
    target = OUT / 'suspended_cavern.ogg'
    with sf.SoundFile(target, 'w', samplerate=rate_out, channels=2,
                      format='OGG', subtype='VORBIS') as writer:
        for start in range(0, len(x), 65536):
            writer.write(x[start:start+65536])
    y, sr = sf.read(target, always_2d=True)
    peak = float(np.max(abs(y)))
    rms_db = float(20*np.log10(np.sqrt(np.mean(y*y))))
    seam = float(np.max(abs(y[0]-y[-1])))
    assert sr == rate_out and np.isfinite(y).all() and len(y)/sr > 30
    assert peak < .2 and -38 < rms_db < -28 and seam < .008, (peak, rms_db, seam)
    report = dict(passed=True, source='https://opengameart.org/content/loopable-dungeon-ambience',
                  download='https://opengameart.org/sites/default/files/dungeon_ambient_1_0.ogg',
                  author='JaggedStone', license='CC0 1.0', speed=speed, sample_rate=sr,
                  duration_seconds=len(y)/sr, rms_dbfs=rms_db, peak_dbfs=float(20*np.log10(peak)),
                  loop_seam_delta=seam, source_sha256=hashlib.sha256(SOURCE.read_bytes()).hexdigest(),
                  output_sha256=hashlib.sha256(target.read_bytes()).hexdigest())
    (OUT/'manifest.json').write_text(json.dumps(report, indent=2), encoding='utf-8')
    preview = y[:min(len(y), 40*sr)] * 10**(-3/20)
    preview[:sr] *= np.linspace(0, 1, sr)[:, None]
    preview[-sr:] *= np.linspace(1, 0, sr)[:, None]
    sf.write(ROOT/'artifacts/audio/cavern_v1/ecoute_caverne.wav', preview, sr, subtype='PCM_16')
    print(json.dumps(report))


if __name__ == '__main__':
    main()
