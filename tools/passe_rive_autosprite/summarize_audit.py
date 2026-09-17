"""Compare two Godot audit reports; render their idle assets at fixed ground anchors.

The PNG/GIF is an atlas reconstruction, not a screenshot or a performance measure.
Run audit_animations.ps1 before and after the change before running this script.
"""
import json
from collections import Counter
from pathlib import Path

from PIL import Image, ImageDraw, ImageFont

ROOT = Path(__file__).resolve().parents[2]
OUT = ROOT / "artifacts/dev/passe_rive_animation_audit"
NATIVE = ROOT / "assets/characters/PasseRive/autosprite_v1"
COMBAT = ROOT / "assets/characters/PasseRive/combat_v2"


def read(path):
    return json.loads(path.read_text(encoding="utf-8"))


def main():
    before = read(OUT / "before/runtime.json")
    after = read(OUT / "after/runtime.json")
    if len(before["directions"]) != 8 or any(
        item["initial"]["clip"] != "combat_idle_" + item["direction"]
        or item["idle_distinct_frames"] != 1 for item in before["directions"]
    ):
        raise ValueError("The before report must be the observed armed-idle regression, before its fix.")
    native, combat = read(NATIVE / "manifest.json"), read(COMBAT / "manifest.json")
    changes = []
    for entry in after["directions"]:
        direction = entry["direction"]
        old = next(item for item in before["directions"] if item["direction"] == direction)
        expected = "idle_" + direction
        valid = [item for item in entry["returns"] if item["state"]["clip"] == expected
                 and not item["state"]["action_pending"]]
        changes.append({"direction": direction, "before_clip": old["initial"]["clip"],
                        "after_clip": entry["initial"]["clip"],
                        "before_frames": old["idle_distinct_frames"],
                        "after_frames": entry["idle_distinct_frames"],
                        "correct_returns": len(valid), "total_returns": len(entry["returns"])})
    summary = {"directions": changes, "correct_returns": sum(c["correct_returns"] for c in changes),
               "total_returns": sum(c["total_returns"] for c in changes),
               "catalog_entries": len(after["spells"]), "clips": len(after["clips"]),
               "routing": dict(Counter(f'{s["family"]}: {s["requested_stem"]} -> {s["played_stem"]}'
                                       for s in after["spells"]))}
    summary["ok"] = len(changes) == 8 and all(
        c["after_clip"] == "idle_" + c["direction"] and c["after_frames"] == 25
        and c["correct_returns"] == c["total_returns"] == 11 for c in changes)
    (OUT / "comparison.json").write_text(json.dumps(summary, ensure_ascii=False, indent=2), encoding="utf-8")

    # Fixed scale and contact anchors reproduce the relative sizes of the assets.
    # This is enlarged atlas artwork, not a capture of the battle camera.
    directions = ["N", "NE", "E", "SE", "S", "SW", "W", "NW"]
    assets = {}
    for direction in directions:
        n = next(s for s in native["sheets"] if s["stem"] == "idle" and s["direction"] == direction)
        c = next(s for s in combat["sheets"] if s["direction"] == direction)
        assets[direction] = (Image.open(COMBAT / c["file"]).convert("RGBA"),
                             Image.open(NATIVE / n["file"]).convert("RGBA"))
    font_path = Path("C:/Windows/Fonts/segoeui.ttf")
    font = ImageFont.truetype(str(font_path), 18) if font_path.exists() else ImageFont.load_default()
    pictures = []
    for frame in range(25):
        canvas = Image.new("RGBA", (1360, 640), "#172c2e")
        draw = ImageDraw.Draw(canvas)
        draw.text((20, 10), "AVANT — pose armée fixe", font=font, fill="#ffcf96")
        draw.text((20, 315), "APRÈS — idle d’origine, sans arc, boucle de 25 images", font=font, fill="#bce3c9")
        draw.text((20, 606), "Reconstitution depuis les atlas et leurs pivots — agrandissement, hors moteur", font=font, fill="#9fb6b8")
        for column, direction in enumerate(directions):
            for row in range(2):
                sheet = assets[direction][row]
                geometry = combat["geometry"]["combat_idle_" + direction] if row == 0 else native["geometry"]["idle_" + direction]
                cell = 384 if row == 0 else 256
                index = 0 if row == 0 else frame
                cols = 4 if row == 0 else 5
                x, y = index % cols * cell, index // cols * cell
                sprite = sheet.crop((x, y, x + cell, y + cell))
                factor = 0.9 * geometry["scale"]
                sprite = sprite.resize((round(cell * factor), round(cell * factor)), Image.Resampling.LANCZOS)
                anchor_x, anchor_y = geometry["anchor"]
                ground_x, ground_y = column * 170 + 85, 280 + row * 305
                draw.line((ground_x - 35, ground_y, ground_x + 35, ground_y), fill="#45615c")
                canvas.alpha_composite(sprite, (round(ground_x - anchor_x * factor), round(ground_y - anchor_y * factor)))
                draw.text((column * 170 + 12, 48 + row * 305), direction, font=font, fill="#d9e3da")
        pictures.append(canvas.convert("RGB"))
    pictures[0].save(OUT / "idle_comparison.png")
    pictures[0].save(OUT / "idle_comparison.gif", save_all=True, append_images=pictures[1:], duration=80, loop=0)
    print(json.dumps({"ok": summary["ok"], "returns": summary["correct_returns"],
                      "report": str(OUT / "comparison.json"), "image": str(OUT / "idle_comparison.png")}))
    if not summary["ok"]:
        raise SystemExit(1)


if __name__ == "__main__":
    main()
