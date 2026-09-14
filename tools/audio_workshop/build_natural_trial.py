"""Second audition: recorded materials, no synthesis, pitch or added layers.

Internal project audition of Sonniss GDC samples. Not a redistributable pack.
"""
import hashlib
import json
from pathlib import Path
import sys

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT / "artifacts/audio/python"))
import numpy as np
import soundfile as sf

OUT = ROOT / "artifacts/audio/natural_v2"
ORDER = [
    ("LeatherArmor_Rustle_03.wav", "Frottement d'armure en cuir"),
    ("Chainmail_Impact_Hard_03.wav", "Impact sur cotte de mailles"),
    ("Plate_Impact_Hard_02.wav", "Impact sur plaque d'armure"),
    ("Weapon_Impact_Parry_01.wav", "Parade d'arme"),
]


def main():
    (OUT / "audition").mkdir(exist_ok=True)
    tracklist = (OUT / "official-tracklist.csv").read_text(encoding="utf-8-sig")
    parts, report = [], []
    for filename, label in ORDER:
        if filename not in tracklist:
            raise ValueError(f"Source not listed in the official tracklist: {filename}")
        path = OUT / "sources" / filename
        x, rate = sf.read(path, always_2d=True)
        if not np.isfinite(x).all() or np.max(np.abs(x)) <= .001:
            raise ValueError(f"Invalid audio: {filename}")
        # Retain a little room tone around the recording; no noise gate.
        energy = np.max(np.abs(x), axis=1)
        active = np.flatnonzero(energy > np.max(energy) * .002)
        start = max(0, int(active[0]) - int(.015 * rate))
        end = min(len(x), int(active[-1]) + int(.08 * rate))
        y = x[start:end].copy()
        y -= y.mean(axis=0)
        a, b = min(len(y), int(.002 * rate)), min(len(y), int(.025 * rate))
        y[:a] *= np.linspace(0, 1, a)[:, None]
        y[-b:] *= np.linspace(1, 0, b)[:, None]
        y *= 10 ** (-12 / 20) / np.max(np.abs(y))
        output = OUT / "audition" / filename
        sf.write(output, y, rate, subtype="PCM_16")
        decoded, delivered_rate = sf.read(output, always_2d=True)
        ok = delivered_rate == rate and np.isfinite(decoded).all() and np.max(np.abs(decoded)) < .95
        if not ok:
            raise ValueError(f"Invalid export: {filename}")
        parts.append((decoded, rate))
        report.append({"file": filename, "label": label, "sample_rate": rate,
                       "source_sha256": hashlib.sha256(path.read_bytes()).hexdigest(),
                       "trim_start_s": round(start / rate, 4), "trim_end_s": round(end / rate, 4),
                       "duration_s": round(len(decoded) / rate, 3), "peak_dbfs": -12,
                       "technical_check": "pass"})
    # Upsample only if rates differ; do not lower recorded pitch or speed.
    rate = max(r for _, r in parts)
    montage, timeline, position = [], [], 0
    for (x, r), row in zip(parts, report):
        if x.shape[1] == 1:
            x = np.repeat(x, 2, axis=1)
        elif x.shape[1] != 2:
            raise ValueError("Only mono or stereo recordings supported")
        if r != rate:
            length = round(len(x) * rate / r)
            x = np.stack([np.interp(np.arange(length) * r / rate, np.arange(len(x)), x[:, c]) for c in range(2)], axis=1)
        timeline.append({"at_s": round(position / rate, 2), "label": row["label"]})
        gap = np.zeros((int(.9 * rate), 2))
        montage.extend([x, gap])
        position += len(x) + len(gap)
    sf.write(OUT / "ecoute_matieres.wav", np.concatenate(montage), rate, subtype="PCM_16")
    probe, actual_rate = sf.read(OUT / "ecoute_matieres.wav", always_2d=True)
    if actual_rate != rate or not np.isfinite(probe).all() or np.max(np.abs(probe)) >= .95:
        raise ValueError("Montage failed validation")
    result = {"cost_eur": 0, "source": "Double Trouble Audio — Medieval Armor and Impacts, Sonniss GDC 2017",
              "license": "https://sonniss.com/gdc-bundle-license/", "license_version": "2.0, 27 August 2026",
              "source_delivery": "gamesounds.xyz mirror; filenames verified against official 2017 tracklist",
              "processing": "Trim, short edge fades, gain only. No synthesis, pitch change, layering or reverb.",
              "status": "Internal audition. User evaluation pending. Not integrated into the game.",
              "auditory_review": "Not performed by the assistant; technical checks do not prove naturalness or suitability.",
              "duration_s": round(len(probe) / rate, 3), "timeline": timeline, "files": report}
    (OUT / "manifest.json").write_text(json.dumps(result, ensure_ascii=False, indent=2), encoding="utf-8")
    lines = ["# Essai 2 — matières enregistrées", "", "Le premier essai a été rejeté, sauf les pas jugés corrects.",
             "Motif : trop électronique ou artificiel. Cet essai explore quatre enregistrements sans couches ajoutées.",
             "", "[Écouter](ecoute_matieres.wav)", ""]
    lines += [f"- {t['at_s']:.2f} s : {t['label']}" for t in timeline]
    lines += ["", "La cotte de mailles et l'armure servent de références de matière ; leur pertinence pour Achille reste à juger.",
              "Découpe, fondus aux extrémités et réglage de volume uniquement. Pas de modification de hauteur ni de vitesse.",
              "", "## Provenance et usage", "", "Double Trouble Audio — Medieval Armor and Impacts, bundle Sonniss GDC 2017.",
              "Téléchargement des WAV via le miroir gamesounds.xyz ; quatre noms recoupés avec la liste officielle conservée.",
              "Usage de travail interne à Catabase. Ne pas publier les WAV ni ce dossier en banque de sons ou dépôt public.",
              "Utilisation commerciale dans le jeu permise par la licence Sonniss ; ce contenu n'est pas CC0.",
              "Licence consultée via recherche web, version 2.0 : https://sonniss.com/gdc-bundle-license/",
              "La sauvegarde HTML directe de la licence a échoué (page anti-robot) ; cette note n'est pas une copie du contrat.",
              "", "Contrôles techniques : quatre WAV et montage décodés, valeurs finies, crêtes sous saturation.",
              "Aucune validation d'écoute ou en jeu revendiquée. Aucun achat ni crédit de génération."]
    (OUT / "ECOUTER.md").write_text("\n".join(lines) + "\n", encoding="utf-8")
    print(json.dumps({"files": len(report), "duration_s": result["duration_s"], "timeline": timeline}, ensure_ascii=False))


if __name__ == "__main__":
    main()
