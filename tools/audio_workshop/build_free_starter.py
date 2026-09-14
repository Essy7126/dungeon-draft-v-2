"""Build an isolated CC0 listening prototype; never edits production audio.

Requires numpy and soundfile 0.13.1. Archives downloaded from Kenney are read
directly (no archive extraction or execution). Outputs live in artifacts/audio.
"""
from pathlib import Path
import hashlib
import io
import json
import sys
import zipfile

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT / "artifacts/audio/python"))
import numpy as np
import soundfile as sf

OUT = ROOT / "artifacts/audio/free_starter_v1"
RATE = 44100
PACKS = {
    "interface": ("interface-sounds", "fa43c1dd4d-1677589452/kenney_interface-sounds.zip"),
    "impact": ("impact-sounds", "87b4ddecda-1677589768/kenney_impact-sounds.zip"),
    "rpg": ("rpg-audio", "8e99002d76-1677590336/kenney_rpg-audio.zip"),
}


def fade(x, attack=.002, release=.025):
    x = x.copy()
    a, b = min(len(x), int(RATE * attack)), min(len(x), int(RATE * release))
    if a:
        x[:a] *= np.linspace(0, 1, a)
    if b:
        x[-b:] *= np.linspace(1, 0, b)
    return x


def load(pack, filename, speed=1.0):
    with zipfile.ZipFile(OUT / "sources" / f"{pack}.zip") as archive:
        x, rate = sf.read(io.BytesIO(archive.read("Audio/" + filename + ".ogg")), always_2d=True)
    x = x.mean(axis=1)
    active = np.flatnonzero(np.abs(x) > .001)
    if not len(active):
        raise ValueError(f"Silent source: {pack}/{filename}")
    x = x[max(0, active[0] - int(rate * .002)):min(len(x), active[-1] + int(rate * .035))]
    count = max(2, round(len(x) * RATE / rate / speed))
    x = np.interp(np.linspace(0, len(x) - 1, count), np.arange(len(x)), x)
    # Gentle filtering when pitching down; prototypes use modest speed changes.
    if speed < 1:
        x = np.convolve(x, np.array([.2, .6, .2]), mode="same")
    x -= x.mean()
    return fade(x / max(np.max(np.abs(x)), .001))


def layer(pack, filename, gain=1, delay=0, speed=1):
    return {"pack": pack, "file": filename, "gain": gain, "delay_s": delay, "speed": speed}


def render(layers, peak_db):
    parts = [(load(p["pack"], p["file"], p["speed"]) * p["gain"], round(p["delay_s"] * RATE)) for p in layers]
    x = np.zeros(max(len(a) + offset for a, offset in parts) + int(.03 * RATE))
    for a, offset in parts:
        x[offset:offset + len(a)] += a
    x = fade(x)
    return x / max(np.max(np.abs(x)), .001) * 10 ** (peak_db / 20)


def main():
    (OUT / "wav").mkdir(parents=True, exist_ok=True)
    licenses = OUT / "licenses"
    licenses.mkdir(exist_ok=True)
    packs = []
    for key, (slug, download) in PACKS.items():
        path = OUT / "sources" / f"{key}.zip"
        with zipfile.ZipFile(path) as archive:
            license_text = archive.read("License.txt")
            if b"CC0" not in license_text:
                raise ValueError(f"Unexpected licence for {key}")
            (licenses / f"kenney_{key}.txt").write_bytes(license_text)
            count = len([n for n in archive.namelist() if n.startswith("Audio/") and n.endswith(".ogg")])
        packs.append({"id": key, "url": f"https://kenney.nl/assets/{slug}",
                      "download": f"https://kenney.nl/media/pages/assets/{slug}/{download}",
                      "sha256": hashlib.sha256(path.read_bytes()).hexdigest(), "audio_count": count, "license": "CC0"})

    cues = []
    def add(key, label, category, variants, peak_db):
        files = []
        for i, layers in enumerate(variants, 1):
            x = render(layers, peak_db)
            rel = f"wav/{key}_{i:02}.wav"
            sf.write(OUT / rel, x, RATE, subtype="PCM_16")
            files.append({"file": rel, "layers": layers})
        cues.append({"id": key, "label": label, "category": category, "variants": files})

    singles = [
        ("ui_select", "Sélection", "Interface", "interface", ["click_001", "click_002", "click_003"], -18),
        ("ui_confirm", "Validation", "Interface", "interface", ["confirmation_001", "confirmation_002"], -15),
        ("ui_back", "Retour", "Interface", "interface", ["back_001", "back_002"], -18),
        ("ui_error", "Action impossible", "Interface", "interface", ["error_001", "error_002"], -20),
        ("book_open", "Ouvrir le grimoire", "Interface", "rpg", ["bookOpen"], -17),
        ("book_page", "Tourner une page", "Interface", "rpg", ["bookFlip1", "bookFlip2", "bookFlip3"], -20),
        ("book_close", "Fermer le grimoire", "Interface", "rpg", ["bookClose"], -18),
        ("step_stone", "Pas sur pierre", "Exploration", "impact", [f"footstep_concrete_{i:03}" for i in range(5)], -17),
        ("step_wood", "Pas sur bois", "Exploration", "impact", [f"footstep_wood_{i:03}" for i in range(5)], -18),
        ("step_grass", "Pas dans l'herbe", "Exploration", "impact", [f"footstep_grass_{i:03}" for i in range(5)], -19),
        ("cloth", "Mouvement du vêtement", "Exploration", "rpg", ["cloth1", "cloth2", "cloth3"], -24),
        ("door_open", "Ouvrir une porte", "Exploration", "rpg", ["doorOpen_1", "doorOpen_2"], -14),
        ("door_close", "Fermer une porte", "Exploration", "rpg", ["doorClose_1", "doorClose_2"], -14),
        ("coins", "Recevoir des oboles", "Récompenses", "rpg", ["handleCoins", "handleCoins2"], -15),
        ("hit_body", "Impact sur une cible", "Combat", "impact", [f"impactPunch_heavy_{i:03}" for i in range(3)], -9),
        ("hit_armor", "Impact sur une armure", "Combat", "impact", [f"impactMetal_medium_{i:03}" for i in range(3)], -10),
    ]
    for key, label, category, pack, filenames, db in singles:
        add(key, label, category, [[layer(pack, name)] for name in filenames], db)

    # Abilities are assembled auditions, not animation-synchronised production cues.
    for key, label in [("peleide", "Frappe du Péléide"), ("percee", "Percée fulgurante"),
                       ("pelion", "Tir du Pélion"), ("garde", "Garde d'airain"),
                       ("block", "Blocage du bouclier"), ("equip", "Équiper une pièce d'armure")]:
        variants = []
        for i in range(3):
            metal = f"impactMetal_medium_{i:03}"
            body = f"impactPunch_heavy_{i:03}"
            if key == "peleide":
                parts = [layer("rpg", "knifeSlice", .3, speed=.86 + i * .03), layer("impact", body, 1, .15, .9), layer("impact", metal, .3, .15, .8)]
            elif key == "percee":
                parts = [layer("rpg", "cloth" + str(i + 1), .2), layer("rpg", "knifeSlice2", .65, .07, 1.18), layer("impact", body, .85, .23, 1.05)]
            elif key == "pelion":
                parts = [layer("interface", "pluck_001", .4, speed=.68 + i * .04), layer("rpg", "knifeSlice", .12, .06, 1.3), layer("impact", f"impactWood_light_{i:03}", .7, .28)]
            elif key == "garde":
                parts = [layer("rpg", "metalLatch", .65, speed=.85 + i * .025), layer("impact", f"impactBell_heavy_{i:03}", .28, .06, .8)]
            elif key == "block":
                parts = [layer("impact", f"impactPlate_heavy_{i:03}", 1, speed=.86), layer("impact", metal, .28, .012, 1.08)]
            else:
                parts = [layer("rpg", "clothBelt", .3), layer("rpg", "metalClick", .5, .12, .92 + i * .025)]
            variants.append(parts)
        add(key, label, "Récompenses" if key == "equip" else "Combat", variants, -15 if key == "equip" else -7)

    add("reward", "Révélation de récompense", "Récompenses", [[
        layer("rpg", "handleCoins", .3), layer("interface", "pluck_001", .5, .1, 1),
        layer("interface", "pluck_001", .4, .23, 1.5), layer("interface", "pluck_001", .25, .38, 2),
    ]], -12)
    add("mastery", "Maîtrise acquise", "Récompenses", [[
        layer("rpg", "bookFlip1", .15), layer("interface", "pluck_002", .4, .1, .75),
        layer("interface", "pluck_002", .35, .3, 1), layer("interface", "pluck_002", .3, .5, 1.5),
    ]], -12)

    manifest = {"status": "Prototype d'écoute, non intégré et non validé artistiquement", "cost_eur": 0,
                "format": "WAV PCM 16-bit mono 44100 Hz", "sources": packs, "cues": cues}
    (OUT / "manifest.json").write_text(json.dumps(manifest, ensure_ascii=False, indent=2), encoding="utf-8")

    # A short, labelled sequence at the authored relative levels.
    sequence = ["ui_select", "ui_confirm", "book_open", "book_page", "step_stone", "step_wood",
                "peleide", "percee", "pelion", "garde", "block", "coins", "equip", "reward", "mastery"]
    montage, timeline, position = [], [], 0
    for key in sequence:
        cue = next(c for c in cues if c["id"] == key)
        x, _ = sf.read(OUT / cue["variants"][0]["file"])
        if key.startswith("step_"):
            steps = []
            for variant in cue["variants"][:4]:
                step, _ = sf.read(OUT / variant["file"])
                steps.extend([step, np.zeros(int(.15 * RATE))])
            x = np.concatenate(steps)
        timeline.append({"at_s": round(position / RATE, 2), "label": cue["label"]})
        silence = np.zeros(int(.65 * RATE))
        montage.extend([x, silence])
        position += len(x) + len(silence)
    sf.write(OUT / "ecoute_catabase.wav", np.concatenate(montage), RATE, subtype="PCM_16")
    (OUT / "timeline.json").write_text(json.dumps(timeline, ensure_ascii=False, indent=2), encoding="utf-8")

    # Decode the delivered files, check actual levels and report each asset.
    checks = []
    for path in sorted((OUT / "wav").glob("*.wav")) + [OUT / "ecoute_catabase.wav"]:
        x, sr = sf.read(path)
        peak = float(np.max(np.abs(x)))
        ok = sr == RATE and len(x) > 0 and np.isfinite(x).all() and .0001 < peak < .95 and abs(x[0]) < .001 and abs(x[-1]) < .001
        checks.append({"file": path.relative_to(OUT).as_posix(), "duration_s": round(len(x) / sr, 3),
                       "peak_dbfs": round(20 * np.log10(max(peak, 1e-10)), 2), "ok": bool(ok),
                       "sha256": hashlib.sha256(path.read_bytes()).hexdigest()})
    report = {"files": len(checks), "events": len(cues), "failures": sum(not c["ok"] for c in checks),
              "auditory_review": "Not performed; numeric checks do not establish perceived quality.", "checks": checks}
    (OUT / "validation.json").write_text(json.dumps(report, indent=2), encoding="utf-8")
    lines = ["# Catabase — essai sonore gratuit", "", "24 événements, banques Kenney CC0, coût : 0 €.",
             "Prototype non intégré au jeu. Contrôles numériques réalisés ; écoute artistique et synchronisation en jeu à faire.",
             "", "[Écouter le montage](ecoute_catabase.wav)", "", "## Repères du montage", ""]
    lines += [f"- {t['at_s']:05.2f} s — {t['label']}" for t in timeline]
    lines += ["", "## Catalogue", ""]
    for cue in cues:
        links = " · ".join(f"[variante {i}]({v['file']})" for i, v in enumerate(cue["variants"], 1))
        lines.append(f"- **{cue['label']}** — {links}")
    lines += ["", "## Sources et provenance", "", "Les licences originales sont dans `licenses/`. Les archives sont dans `sources/`.",
              "Chaque variante du manifeste décrit ses couches, gains, décalages et vitesses. Aucun service de génération payant."]
    lines += [f"- [{p['id']}]({p['url']}) — {p['audio_count']} sons, CC0" for p in packs]
    lines += ["", "## Suite", "", "Choisir les timbres à l'écoute, puis synchroniser lancement et impact séparément aux animations.",
              "À compléter : ambiances naturelles, ennemis, états, boss, voix et musique. Cet essai ne constitue pas une bande-son complète."]
    (OUT / "ECOUTER.md").write_text("\n".join(lines) + "\n", encoding="utf-8")
    print(json.dumps({k: report[k] for k in ("files", "events", "failures")}) )
    if report["failures"]:
        raise SystemExit(1)


if __name__ == "__main__":
    main()
