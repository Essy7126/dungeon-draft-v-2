"""Assemble documentary Godot captures; never edit animation source pixels."""
import argparse
import ast
import json
from pathlib import Path
from PIL import Image, ImageDraw, ImageFont

parser = argparse.ArgumentParser()
parser.add_argument("capture", type=Path)
parser.add_argument("out", type=Path)
parser.add_argument("--crop", type=int, nargs=4, default=[450, 260, 1040, 670])
args = parser.parse_args()
samples = json.loads((args.capture / "samples.json").read_text())
report = json.loads((args.capture / "report.json").read_text())
assert report["passed"], "A failed capture cannot be published as verified."
assert len(report["casts"]) == 2, "Base and upgraded card must both be exercised."
body_samples = [sample for sample in samples if sample["state"]["animation"] == "PR_PULL_S25"]
assert body_samples and len({sample["state"]["drawing_scale"] for sample in body_samples}) == 1
origin = ast.literal_eval(samples[0]["target_world"])
destination = ast.literal_eval(samples[-1]["target_world"])
axis = [destination[i] - origin[i] for i in range(2)]
length_squared = sum(value * value for value in axis)
assert length_squared > 1, "The real target must have moved."
progress = [sum((ast.literal_eval(sample["target_world"])[i] - origin[i]) * axis[i]
                for i in range(2)) / length_squared for sample in samples]
assert all(-.001 <= value <= 1.001 for value in progress), "Target overshot the committed cell."
assert all(right >= left - .001 for left, right in zip(progress, progress[1:])), "Target snapped backwards."
intermediate = len({round(value, 4) for value in progress if .001 < value < .999})
assert intermediate >= 3, "Capture must show smooth translation, not just the final cell."
assert all(sample["target_cell"] == samples[0]["target_cell"]
           and ast.literal_eval(sample["target_world"]) == origin
           for sample in body_samples if sample["state"]["action_elapsed"] < .4)
args.out.mkdir(parents=True, exist_ok=True)
images = [Image.open(args.capture / f"frames/{i:04d}.png").convert("RGB").crop(args.crop)
          for i in range(len(samples))]
# GIF stores hundredths of a second. Quantize the cumulative clock rather than
# each 16 ms frame separately, which would silently accelerate a 60 fps capture.
durations = []
gif_elapsed = 0
for sample in samples[1:]:
    end = round((sample["time_ms"] - samples[0]["time_ms"]) / 10) * 10
    duration = max(10, end - gif_elapsed)
    durations.append(duration)
    gif_elapsed += duration
durations.append(600)
images[0].save(args.out / "ramener_au_front.gif", save_all=True,
               append_images=images[1:], duration=durations, loop=0)
indices = [0]
for pose in [3, 5, 7]:
    indices.append(next(i for i, sample in enumerate(samples)
                        if sample["state"]["animation"] == "PR_PULL_S25"
                        and sample["state"]["frame"] == pose))
indices.append(len(images) - 1)
width, height = images[0].size
board = Image.new("RGB", (width * 3, (height + 42) * 2), "#182626")
draw = ImageDraw.Draw(board)
font = ImageFont.truetype("C:/Windows/Fonts/segoeui.ttf", 21)
labels = ["Repos natif", "Projection du crochet", "Fil tendu", "Traction confirmée", "Retour au repos"]
for n, (index, title) in enumerate(zip(indices, labels)):
    x, y = n % 3 * width, n // 3 * (height + 42)
    board.paste(images[index], (x, y + 42))
    draw.text((x + 16, y + 9), title, font=font, fill="#f1e8d1")
upgrade = Image.open(args.capture / "upgraded_g04_recovery.png").convert("RGB").crop(args.crop)
board.paste(upgrade, (width * 2, height + 84))
draw.text((width * 2 + 16, height + 51), "Carte améliorée : deux cases", font=font, fill="#f1e8d1")
board.save(args.out / "audit_poses.png")
metadata = json.loads((Path(__file__).resolve().parents[3] /
                      "assets/characters/PasseRive/sprites_s25/pull.json").read_text())
provenance = dict(capture=str(args.capture.resolve()), passed=report["passed"],
                  checks=len(report["checks"]), frames=len(samples),
                  poses=metadata["sequence"], duration_ms=sum(metadata["duration_ms"]),
                  release_ms=metadata["release_ms"],
                  source_atlas_sha256=metadata["source_sha256"], casts=report["casts"],
                  capture_audit=dict(scale_constant=True, no_early_pull=True,
                                     target_motion_monotonic=True,
                                     intermediate_target_positions=intermediate,
                                     gif_capture_timing_error_ms=gif_elapsed - (
                                         samples[-1]["time_ms"] - samples[0]["time_ms"])))
(args.out / "capture_provenance.json").write_text(json.dumps(provenance, indent=2), encoding="utf-8")
(args.out / "review.html").write_text('''<!doctype html><html lang="fr"><meta charset="utf-8">
<title>Passe-Rive · Ramener au front</title>
<style>body{margin:40px;background:#152522;color:#eae1ce;font:17px system-ui}main{max-width:1100px;margin:auto}h1{font-size:28px}img{max-width:100%;border-radius:10px}p{line-height:1.6}.film{width:800px}</style>
<main><h1>Ramener au front · Crochet spectral</h1>
<p>Animatique SE · 11 poses · 890 ms. La carte réelle consomme 1 PA ; le crochet part de la main, le corps tend le fil et la cible est attirée au début de la traction (400 ms).</p>
<img class="film" src="ramener_au_front.gif" alt="Capture du sort dans Godot">
<p>Une case pour la carte normale, deux pour la version améliorée. Une seule échelle, une palette commune et un appui arrière fixe. Les autres directions restent à dessiner.</p>
<img src="audit_poses.png" alt="Repos, projection, tension, traction et récupération">
<p>Capture du banc de combat utilisant les règles et cartes du jeu, avec une main et une cible préparées pour la comparaison.</p></main></html>''', encoding="utf-8")
print(json.dumps({key: value for key, value in provenance.items() if key != "casts"}))
