#!/usr/bin/env python3
"""Compose deterministic QA boards from the real Godot runtime captures."""

from __future__ import annotations

import json
from pathlib import Path

from PIL import Image, ImageDraw, ImageFont, ImageOps


ROOT = Path(__file__).resolve().parents[1]
OUTPUT = ROOT / "artifacts" / "maps" / "unit_presence_audit"
ROOMS = ["room_01_forest", "room_05_volcano", "room_06_space"]
ROOM_LABELS = {
    "room_01_forest": "Salle 1 — Forêt",
    "room_05_volcano": "Salle 5 — Volcan",
    "room_06_space": "Salle 6 — Espace",
}


def font(size: int, bold: bool = False) -> ImageFont.FreeTypeFont:
    name = "arialbd.ttf" if bold else "arial.ttf"
    path = Path("C:/Windows/Fonts") / name
    return ImageFont.truetype(str(path), size) if path.exists() else ImageFont.load_default()


def save(image: Image.Image, path: Path) -> None:
    temporary = path.with_name(path.name + ".tmp")
    image.save(temporary, "PNG", compress_level=4)
    temporary.replace(path)


def label(draw: ImageDraw.ImageDraw, box: tuple[int, int, int, int], text: str) -> None:
    x0, y0, x1, _ = box
    draw.rounded_rectangle((x0 + 12, y0 + 12, min(x1 - 12, x0 + 520), y0 + 58), 9,
                           fill=(7, 13, 22, 220), outline=(101, 190, 225, 190), width=2)
    draw.text((x0 + 28, y0 + 23), text, font=font(22, True), fill=(245, 250, 255, 255))


def four_way(room: str) -> None:
    variants = [
        ("post_change_baseline_recheck.png", "1 · Référence inchangée"),
        ("camera_only.png", "2 · Caméra seule"),
        ("camera_and_scale.png", "3 · Caméra + échelle"),
        ("final_readability.png", "4 · Lisibilité finale"),
    ]
    canvas = Image.new("RGB", (1920, 1080), "#070b12")
    draw = ImageDraw.Draw(canvas, "RGBA")
    for index, (filename, title) in enumerate(variants):
        image = Image.open(OUTPUT / room / filename).convert("RGB")
        panel = ImageOps.fit(image, (960, 540), method=Image.Resampling.LANCZOS)
        x, y = (index % 2) * 960, (index // 2) * 540
        canvas.paste(panel, (x, y))
        label(draw, (x, y, x + 960, y + 540), title)
    save(canvas, OUTPUT / room / "four_way_comparison.png")


def resolution_board(room: str) -> None:
    variants = [
        ("final_720p.png", "720p"),
        ("final.png", "1080p"),
        ("final_1440p.png", "1440p"),
    ]
    canvas = Image.new("RGB", (1920, 720), "#07101b")
    draw = ImageDraw.Draw(canvas, "RGBA")
    for index, (filename, title) in enumerate(variants):
        image = Image.open(OUTPUT / room / filename).convert("RGB")
        panel = ImageOps.fit(image, (640, 720), method=Image.Resampling.LANCZOS)
        x = index * 640
        canvas.paste(panel, (x, 0))
        label(draw, (x, 0, x + 640, 720), f"{ROOM_LABELS[room]} · {title}")
    save(canvas, OUTPUT / room / "resolution_comparison.png")


def action_board(room: str) -> None:
    variants = [
        ("front_center_back_units.png", "Repos / profondeur"),
        ("active_unit.png", "Unité active"),
        ("movement.png", "Mouvement"),
        ("cast.png", "Cast"),
        ("hit.png", "Hit"),
        ("death.png", "Mort"),
    ]
    canvas = Image.new("RGB", (1920, 1080), "#070b12")
    draw = ImageDraw.Draw(canvas, "RGBA")
    for index, (filename, title) in enumerate(variants):
        image = Image.open(OUTPUT / room / filename).convert("RGB")
        panel = ImageOps.fit(image, (640, 540), method=Image.Resampling.LANCZOS)
        x, y = (index % 3) * 640, (index // 3) * 540
        canvas.paste(panel, (x, y))
        label(draw, (x, y, x + 640, y + 540), title)
    save(canvas, OUTPUT / room / "action_states_comparison.png")


def alpha_crop(path: Path) -> Image.Image:
    image = Image.open(path).convert("RGBA")
    bounds = image.getchannel("A").getbbox()
    if bounds is None:
        raise ValueError(f"Modèle transparent vide: {path}")
    return image.crop(bounds)


def scale_ladder() -> None:
    hero_scales = [1.0, 1.25, 1.35, 1.45, 1.50]
    enemy_scales = [1.0, 1.20, 1.30, 1.40]
    rows = [
        ("elf", "Elfe", hero_scales),
        ("mage", "Mage", hero_scales),
        ("warrior", "Guerrier", hero_scales),
        ("skeleton_melee", "Squelette standard", enemy_scales),
    ]
    width, height = 1800, 1040
    canvas = Image.new("RGBA", (width, height), (7, 12, 20, 255))
    draw = ImageDraw.Draw(canvas, "RGBA")
    draw.text((52, 34), "Planche d’échelles — modèles runtime réels", font=font(34, True), fill="white")
    draw.text((52, 80), "Pied commun au centre de cellule · aucune modification des textures 3D",
              font=font(20), fill=(178, 207, 226, 255))
    left, top, cell_w, row_h = 250, 130, 300, 215
    for row_index, (unit_id, unit_label, scales) in enumerate(rows):
        y0 = top + row_index * row_h
        draw.text((42, y0 + 82), unit_label, font=font(24, True), fill=(231, 240, 248, 255))
        source = alpha_crop(OUTPUT / "raw_models" / f"{unit_id}.png")
        for column, factor in enumerate(scales):
            x0 = left + column * cell_w
            foot = (x0 + cell_w // 2, y0 + 177)
            diamond = [(foot[0], foot[1] - 28), (foot[0] + 112, foot[1]),
                       (foot[0], foot[1] + 28), (foot[0] - 112, foot[1])]
            draw.polygon(diamond, fill=(29, 51, 67, 120), outline=(83, 135, 163, 185), width=2)
            draw.ellipse((foot[0] - 34 * factor, foot[1] - 7 * factor,
                          foot[0] + 34 * factor, foot[1] + 7 * factor), fill=(0, 0, 0, 105))
            target_h = round(92 * factor)
            target_w = max(1, round(source.width * target_h / source.height))
            model = source.resize((target_w, target_h), Image.Resampling.LANCZOS)
            canvas.alpha_composite(model, (foot[0] - target_w // 2, foot[1] - target_h))
            title = "actuel" if factor == 1.0 else f"×{factor:.2f}"
            color = (255, 220, 85, 255) if factor in (1.45, 1.50, 1.40) else (197, 218, 231, 255)
            bbox = draw.textbbox((0, 0), title, font=font(19, factor >= 1.4))
            draw.text((x0 + (cell_w - (bbox[2] - bbox[0])) // 2, y0 + 9), title,
                      font=font(19, factor >= 1.4), fill=color)
    save(canvas.convert("RGB"), OUTPUT / "unit_family_scale_ladder.png")


def all_rooms_board() -> None:
    canvas = Image.new("RGB", (1920, 720), "#07101b")
    draw = ImageDraw.Draw(canvas, "RGBA")
    for index, room in enumerate(ROOMS):
        image = Image.open(OUTPUT / room / "final.png").convert("RGB")
        panel = ImageOps.fit(image, (640, 720), method=Image.Resampling.LANCZOS)
        x = index * 640
        canvas.paste(panel, (x, 0))
        label(draw, (x, 0, x + 640, 720), ROOM_LABELS[room])
    save(canvas, OUTPUT / "all_rooms_final_comparison.png")


def validation_summary() -> None:
    metrics = json.loads((OUTPUT / "final_metrics.json").read_text(encoding="utf-8"))
    summary = {
        "generated_at": metrics["generated_at"],
        "room_count": len(metrics["maps"]),
        "unit_view_root_scale_unchanged": True,
        "logical_foot_max_error_px": 0.0,
        "profiles": {},
    }
    for room, payload in metrics["maps"].items():
        resolution = payload["resolutions"]["1080p"]
        summary["profiles"][room] = {
            "camera_zoom_multiplier": payload["camera_zoom_multiplier"],
            "global_unit_scale_multiplier": payload["global_unit_scale_multiplier"],
            "platform_width_percent": resolution["platform_width_percent"],
            "visual_scales": {
                unit["unit_id"]: unit["painted_visual_scale"]
                for unit in resolution["units"]
            },
            "height_per_cell_range": [
                min(unit["height_per_projected_cell_height"] for unit in resolution["units"]),
                max(unit["height_per_projected_cell_height"] for unit in resolution["units"]),
            ],
        }
        for unit in resolution["units"]:
            root_scale = unit["unit_view_scale"]
            summary["unit_view_root_scale_unchanged"] &= all(abs(v - 0.58) < 1e-5 for v in root_scale)
            summary["logical_foot_max_error_px"] = max(
                summary["logical_foot_max_error_px"],
                abs(unit["logical_foot_local"][0]), abs(unit["logical_foot_local"][1]),
            )
    (OUTPUT / "validation_summary.json").write_text(
        json.dumps(summary, ensure_ascii=False, indent=2), encoding="utf-8"
    )


def main() -> int:
    for room in ROOMS:
        four_way(room)
        resolution_board(room)
        action_board(room)
    scale_ladder()
    all_rooms_board()
    validation_summary()
    print("UNIT_PRESENCE_BOARDS_COMPLETE rooms=3")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
