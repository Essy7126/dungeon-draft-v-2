"""Internal audition: modest fantasy treatment derived only from recorded foley.

Uses existing licensed Sonniss materials; no downloads or paid generation.
Keep these working files out of public source/asset packs (Sonniss licence).
"""
from pathlib import Path
import hashlib
import json
import sys

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT / "artifacts/audio/python"))
import numpy as np
import soundfile as sf

SOURCE = ROOT / "artifacts/audio/natural_v2/audition"
OUT = ROOT / "artifacts/audio/mythic_v3"
RATE = 96000
CASES = [
    ("frappe", "Frappe — élan bref", "Chainmail_Impact_Hard_03.wav", .94, .08, .10),
    ("airain", "Airain — résonance grave", "Plate_Impact_Hard_02.wav", .78, .12, .05),
    ("parade", "Parade — éclat prolongé", "Weapon_Impact_Parry_01.wav", .90, .10, .065),
]


def read(name):
    x, rate = sf.read(SOURCE / name, always_2d=True)
    if rate != RATE or x.shape[1] not in (1, 2) or not np.isfinite(x).all():
        raise ValueError(f"Unsupported source: {name}")
    if x.shape[1] == 1:
        x = np.repeat(x, 2, axis=1)
    return x


def edge_fade(x, seconds=.025):
    x = x.copy()
    n = min(len(x), round(seconds * RATE))
    x[-n:] *= np.linspace(1, 0, n)[:, None]
    return x


def respeed(x, speed):
    grid = np.arange(round(len(x) / speed)) * speed
    return np.stack([np.interp(grid, np.arange(len(x)), x[:, c]) for c in range(2)], axis=1)


def main():
    OUT.mkdir(parents=True, exist_ok=True)
    leather = read("LeatherArmor_Rustle_03.wav")
    parts, fantasy_parts, timeline, records = [], [], [], []
    cursor = 0
    for key, label, name, speed, tail_gain, air_gain in CASES:
        x = read(name)
        # Padding gives the original and treatment identical comparison windows.
        lead = round(.10 * RATE)
        length = max(round(1.8 * RATE), lead + len(x) + round(.65 * RATE))
        dry = np.zeros((length, 2))
        dry[lead:lead + len(x)] = x
        wet = np.zeros_like(dry)
        lowered = respeed(x, speed)
        # Only the resonating part is reinforced; the main contact stays dry.
        onset = min(len(lowered), round(.035 * RATE))
        lowered[:onset] *= np.linspace(0, 1, onset)[:, None] ** 2
        # Smooth the added copy to keep high metallic fizz from dominating.
        kernel = np.ones(17) / 17
        lowered = np.stack([np.convolve(lowered[:, c], kernel, mode="same") for c in range(2)], axis=1)
        for delay, gain, pan in [(.028, 1, .1), (.071, .34, -.22), (.113, .24, .25), (.181, .12, -.12), (.269, .07, .18)]:
            at = lead + round(delay * RATE)
            count = min(len(lowered), length - at)
            wet[at:at + count] += lowered[:count] * gain * np.array([1 - pan, 1 + pan])
        # A very quiet reversed leather movement provides a physical intake of air.
        air = respeed(leather[:round(.17 * RATE)][::-1], 1.7)
        air = np.stack([np.convolve(air[:, c], np.ones(31) / 31, mode="same") for c in range(2)], axis=1)
        n = min(lead, len(air))
        envelope = np.sin(np.linspace(0, np.pi, n))[:, None] ** 1.5
        air = air[:n] * envelope
        air *= np.max(np.abs(x)) / max(np.max(np.abs(air)), 1e-9)
        treated = dry + tail_gain * wet
        treated[:n] += air * air_gain
        treated = edge_fade(treated)
        # Match total signal energy over equal windows, then use a common peak cap.
        # This reduces loudness bias; it is not a perceptual LUFS measurement.
        treated *= np.sqrt(np.sum(dry ** 2) / max(np.sum(treated ** 2), 1e-12))
        scale = 10 ** (-12 / 20) / max(np.max(np.abs(dry)), np.max(np.abs(treated)))
        dry *= scale
        treated *= scale
        for version, signal in [("naturel", dry), ("fantaisie", treated)]:
            path = OUT / f"{key}_{version}.wav"
            sf.write(path, signal, RATE, subtype="PCM_16")
            timeline.append({"at_s": round(cursor / RATE, 2), "label": f"{label} : {version}"})
            parts.extend([signal, np.zeros((round(.40 * RATE), 2))])
            cursor += len(signal) + round(.40 * RATE)
        fantasy_parts.extend([treated, np.zeros((round(.45 * RATE), 2))])
        records.append({"id": key, "label": label, "source": name,
                        "source_sha256": hashlib.sha256((SOURCE / name).read_bytes()).hexdigest(),
                        "resonance_speed": speed, "tail_gain": tail_gain, "leather_gain": air_gain,
                        "difference_rms": float(np.sqrt(np.mean((treated - dry) ** 2))),
                        "energy_ratio": float(np.sum(treated ** 2) / np.sum(dry ** 2))})
    sf.write(OUT / "comparaison_naturel_fantaisie.wav", np.concatenate(parts), RATE, subtype="PCM_16")
    sf.write(OUT / "fantaisie_seule.wav", np.concatenate(fantasy_parts), RATE, subtype="PCM_16")
    checks = []
    for path in sorted(OUT.glob("*.wav")):
        y, sr = sf.read(path, always_2d=True)
        peak = float(np.max(np.abs(y)))
        passed = sr == RATE and y.shape[1] == 2 and np.isfinite(y).all() and .001 < peak < .95 and np.max(np.abs(y[-1])) < .001
        checks.append({"file": path.name, "duration_s": round(len(y) / sr, 3), "peak_dbfs": round(20 * np.log10(peak), 2), "pass": bool(passed)})
    if any(not c["pass"] for c in checks) or any(r["difference_rms"] <= 1e-5 or abs(r["energy_ratio"] - 1) > .001 for r in records):
        raise ValueError("Audio export or comparison validation failed")
    manifest = {"cost_eur": 0, "user_feedback": "V2 preferred; add a little fantasy while retaining natural material.",
                "source_manifest": "../natural_v2/manifest.json", "license": "https://sonniss.com/gdc-bundle-license/",
                "usage": "Internal Catabase audition; not a distributable sound pack. Not integrated.",
                "recipe": "Recorded contact preserved. Quiet lowered recorded resonance, irregular short reflections, reversed recorded leather. No oscillators, notes or musical jingles.",
                "level_matching": "Equal signal energy within identical windows; not a perceptual loudness measurement.",
                "auditory_review": "Pending user audition; numerical verification does not establish artistic quality.",
                "records": records, "timeline": timeline, "checks": checks}
    (OUT / "manifest.json").write_text(json.dumps(manifest, ensure_ascii=False, indent=2), encoding="utf-8")
    lines = ["# Essai 3 — naturel avec une touche de fantaisie", "",
             "Retour retenu : les pas sont corrects ; V1 trop artificielle ; V2 meilleure mais manque un peu de fantaisie.",
             "", "[Comparaison : naturel puis fantaisie pour chaque paire](comparaison_naturel_fantaisie.wav)",
             "", "[Les trois propositions seules](fantaisie_seule.wav)", ""]
    lines += [f"- {t['at_s']:.2f} s — {t['label']}" for t in timeline]
    lines += ["", "Traitement : résonance abaissée provenant du métal enregistré, réflexions courtes et discrètes, aspiration faite avec le cuir enregistré.",
              "Les contacts restent au centre. Aucun son musical ajouté. Niveaux comparés à énergie égale, sans mesure de sonie perceptuelle.",
              "", "Sources : Double Trouble Audio, Medieval Armor and Impacts, Sonniss GDC 2017 ; voir le manifeste V2 et sa provenance.",
              "Usage de travail interne à Catabase. Licence Sonniss, pas CC0 : ne pas redistribuer les sons en banque ou dépôt public.",
              "", "Huit WAV vérifiés : décodage, valeurs finies, crêtes, fins des fichiers ; comparaison non identique et énergie contrôlée.",
              "L'écoute artistique reste à juger par l'utilisateur. Aucune modification des scènes du jeu. Coût : 0 €."]
    (OUT / "ECOUTER.md").write_text("\n".join(lines) + "\n", encoding="utf-8")
    print(json.dumps({"files": len(checks), "failed": 0, "timeline": timeline}, ensure_ascii=False))


if __name__ == "__main__":
    main()
