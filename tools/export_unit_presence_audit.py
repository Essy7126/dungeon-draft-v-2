#!/usr/bin/env python3
"""Compose deterministic QA boards from the Godot unit-presence captures."""

from __future__ import annotations

import json
from pathlib import Path

from PIL import Image, ImageDraw, ImageFont, ImageOps


ROOT = Path(__file__).resolve().parents[1]
OUTPUT = ROOT / "artifacts" / "maps" / "unit_presence_audit"
ROOMS = ["room_01_forest", "room_05_volcano", "room_06_space"]
RESOLUTIONS = ["720p", "1080p", "1440p"]
ROOM_LABELS = {
    "room_01_forest": "Salle 1 - Foret",
    "room_05_volcano": "Salle 5 - Volcan",
    "room_06_space": "Salle 6 - Espace",
}
EXPECTED_CAPTURES = [
    "final.png",
    "debug_grid.png",
    "unit_behind_occluder.png",
    "unit_side_of_occluder.png",
    "unit_in_front_of_occluder.png",
    "several_units_occlusion.png",
    "movement_overlay.png",
    "spell_overlay.png",
    "active_unit.png",
]
ANIMATION_CAPTURES = [
    ("walk_animation.png", "Marche"),
    ("cast_animation.png", "Incantation"),
    ("hit_animation.png", "Impact"),
]


def font(size: int, bold: bool = False) -> ImageFont.FreeTypeFont:
    name = "arialbd.ttf" if bold else "arial.ttf"
    path = Path("C:/Windows/Fonts") / name
    return (
        ImageFont.truetype(str(path), size)
        if path.exists()
        else ImageFont.load_default()
    )


def save(image: Image.Image, path: Path) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    temporary = path.with_name(path.name + ".tmp")
    image.save(temporary, "PNG", compress_level=4)
    temporary.replace(path)


def capture(room: str, resolution: str, filename: str) -> Image.Image:
    path = OUTPUT / room / resolution / filename
    if not path.exists():
        raise FileNotFoundError(path)
    return Image.open(path).convert("RGB")


def label(
    draw: ImageDraw.ImageDraw,
    box: tuple[int, int, int, int],
    text: str,
) -> None:
    x0, y0, x1, _ = box
    width = min(x1 - 24, max(260, len(text) * 14 + 46))
    draw.rounded_rectangle(
        (x0 + 12, y0 + 12, x0 + width, y0 + 58),
        9,
        fill=(7, 13, 22, 220),
        outline=(101, 190, 225, 190),
        width=2,
    )
    draw.text(
        (x0 + 28, y0 + 23),
        text,
        font=font(20, True),
        fill=(245, 250, 255, 255),
    )


def fitted(image: Image.Image, size: tuple[int, int]) -> Image.Image:
    return ImageOps.fit(image, size, method=Image.Resampling.LANCZOS)


def comparison_board(
    panels: list[tuple[Image.Image, str]],
    *,
    columns: int,
    panel_size: tuple[int, int],
) -> Image.Image:
    rows = (len(panels) + columns - 1) // columns
    canvas = Image.new(
        "RGB",
        (columns * panel_size[0], rows * panel_size[1]),
        "#07101b",
    )
    draw = ImageDraw.Draw(canvas, "RGBA")
    for index, (image, title) in enumerate(panels):
        x = (index % columns) * panel_size[0]
        y = (index // columns) * panel_size[1]
        canvas.paste(fitted(image, panel_size), (x, y))
        label(draw, (x, y, x + panel_size[0], y + panel_size[1]), title)
    return canvas


def room_boards(room: str) -> None:
    room_output = OUTPUT / room
    before_after = comparison_board(
        [
            (capture(room, "1080p", "before.png"), "Avant"),
            (capture(room, "1080p", "final.png"), "Apres"),
        ],
        columns=2,
        panel_size=(960, 1080),
    )
    save(before_after, room_output / "before_after.png")

    resolution = comparison_board(
        [
            (capture(room, name, "final.png"), name)
            for name in RESOLUTIONS
        ],
        columns=3,
        panel_size=(640, 720),
    )
    save(resolution, room_output / "resolution_comparison.png")

    occlusion = comparison_board(
        [
            (
                capture(room, "1080p", "occlusion_off.png"),
                "Occlusion OFF",
            ),
            (
                capture(room, "1080p", "unit_behind_occluder.png"),
                "Occlusion ON",
            ),
        ],
        columns=2,
        panel_size=(960, 1080),
    )
    save(occlusion, room_output / "occlusion_off_on.png")

    scenarios = comparison_board(
        [
            (
                capture(room, "1080p", "unit_behind_occluder.png"),
                "Derriere",
            ),
            (
                capture(room, "1080p", "unit_side_of_occluder.png"),
                "Lateral",
            ),
            (
                capture(room, "1080p", "unit_in_front_of_occluder.png"),
                "Devant",
            ),
            (
                capture(room, "1080p", "several_units_occlusion.png"),
                "Plusieurs unites",
            ),
        ],
        columns=2,
        panel_size=(960, 540),
    )
    save(scenarios, room_output / "occlusion_scenarios.png")

    animations = comparison_board(
        [
            (capture(room, "1080p", filename), title)
            for filename, title in ANIMATION_CAPTURES
        ],
        columns=3,
        panel_size=(640, 720),
    )
    save(animations, room_output / "animation_states.png")


def global_boards() -> None:
    all_maps = comparison_board(
        [
            (capture(room, "1080p", "final.png"), ROOM_LABELS[room])
            for room in ROOMS
        ],
        columns=3,
        panel_size=(640, 720),
    )
    save(all_maps, OUTPUT / "all_maps_comparison.png")

    all_resolutions = comparison_board(
        [
            (
                capture(room, resolution, "final.png"),
                f"{ROOM_LABELS[room]} - {resolution}",
            )
            for room in ROOMS
            for resolution in RESOLUTIONS
        ],
        columns=3,
        panel_size=(640, 360),
    )
    save(all_resolutions, OUTPUT / "all_maps_resolution_comparison.png")

    all_occlusion: list[tuple[Image.Image, str]] = []
    for room in ROOMS:
        all_occlusion.extend(
            [
                (
                    capture(room, "1080p", "occlusion_off.png"),
                    f"{ROOM_LABELS[room]} - OFF",
                ),
                (
                    capture(room, "1080p", "unit_behind_occluder.png"),
                    f"{ROOM_LABELS[room]} - ON",
                ),
            ]
        )
    save(
        comparison_board(
            all_occlusion,
            columns=2,
            panel_size=(960, 540),
        ),
        OUTPUT / "all_maps_occlusion_off_on.png",
    )


def alpha_crop(path: Path) -> Image.Image:
    image = Image.open(path).convert("RGBA")
    bounds = image.getchannel("A").getbbox()
    if bounds is None:
        raise ValueError(f"Empty transparent unit render: {path}")
    return image.crop(bounds)


def scale_ladder() -> None:
    rows = [
        ("elf", "Elfe", [1.0, 1.25, 1.50, 1.75, 1.90]),
        ("mage", "Mage", [1.0, 1.25, 1.50, 1.75, 1.94]),
        ("warrior", "Guerrier", [1.0, 1.25, 1.50, 1.75, 2.00]),
        ("skeleton_melee", "Squelette", [1.0, 1.20, 1.40, 1.60, 1.76]),
    ]
    canvas = Image.new("RGBA", (1800, 1040), (7, 12, 20, 255))
    draw = ImageDraw.Draw(canvas, "RGBA")
    draw.text(
        (52, 34),
        "Echelles visuelles - rendus runtime",
        font=font(34, True),
        fill="white",
    )
    left, top, cell_w, row_h = 250, 130, 300, 215
    for row_index, (unit_id, unit_label, scales) in enumerate(rows):
        source = alpha_crop(OUTPUT / "raw_models" / f"{unit_id}.png")
        y0 = top + row_index * row_h
        draw.text(
            (42, y0 + 82),
            unit_label,
            font=font(24, True),
            fill=(231, 240, 248, 255),
        )
        for column, factor in enumerate(scales):
            x0 = left + column * cell_w
            foot = (x0 + cell_w // 2, y0 + 177)
            diamond = [
                (foot[0], foot[1] - 28),
                (foot[0] + 112, foot[1]),
                (foot[0], foot[1] + 28),
                (foot[0] - 112, foot[1]),
            ]
            draw.polygon(
                diamond,
                fill=(29, 51, 67, 120),
                outline=(83, 135, 163, 185),
                width=2,
            )
            target_h = round(92 * factor)
            target_w = max(1, round(source.width * target_h / source.height))
            model = source.resize((target_w, target_h), Image.Resampling.LANCZOS)
            canvas.alpha_composite(
                model,
                (foot[0] - target_w // 2, foot[1] - target_h),
            )
            draw.text(
                (x0 + 110, y0 + 9),
                f"x{factor:.2f}",
                font=font(19, factor >= 1.6),
                fill=(255, 220, 85, 255),
            )
    save(canvas.convert("RGB"), OUTPUT / "unit_family_scale_ladder.png")


def validation_summary() -> None:
    metrics = json.loads(
        (OUTPUT / "final_metrics.json").read_text(encoding="utf-8")
    )
    summary = {
        "generated_at": metrics["generated_at"],
        "room_count": len(metrics["maps"]),
        "resolution_count": 3,
        "expected_capture_count": len(ROOMS) * len(RESOLUTIONS) * len(EXPECTED_CAPTURES),
        "logical_foot_max_error_px": 0.0,
        "occlusion_pass": True,
        "profiles": {},
    }
    for room, payload in metrics["maps"].items():
        room_summary = {"resolutions": {}}
        for resolution, measured in payload["resolutions"].items():
            foot_error = measured["foot_anchor_error_px"]["maximum"]
            summary["logical_foot_max_error_px"] = max(
                summary["logical_foot_max_error_px"],
                foot_error,
            )
            occlusion = measured["occlusion_results"]
            passed = (
                occlusion["behind_hidden"]
                and occlusion["side_visible"]
                and occlusion["front_visible"]
                and occlusion["several_units_actual"]
                == occlusion["several_units_expected"]
                and occlusion["occluder_count"] == 1
                and occlusion["y_sort_enabled"]
            )
            summary["occlusion_pass"] &= passed
            room_summary["resolutions"][resolution] = {
                "occlusion_pass": passed,
                "fps": measured["fps"],
                "visual_scales": measured["visual_scales"],
                "hero_visible_size_px": measured["hero_visible_size_px"],
                "unit_cell_ratios": measured["unit_cell_ratios"],
                "tactical_viewport_percent": measured[
                    "tactical_viewport_percent"
                ],
            }
        summary["profiles"][room] = room_summary
    (OUTPUT / "validation_summary.json").write_text(
        json.dumps(summary, ensure_ascii=False, indent=2) + "\n",
        encoding="utf-8",
    )


def verify_inputs() -> None:
    missing = [
        OUTPUT / room / resolution / filename
        for room in ROOMS
        for resolution in RESOLUTIONS
        for filename in EXPECTED_CAPTURES
        if not (OUTPUT / room / resolution / filename).exists()
    ]
    if missing:
        formatted = "\n".join(str(path) for path in missing)
        raise FileNotFoundError(f"Missing required captures:\n{formatted}")
    missing_animations = [
        OUTPUT / room / "1080p" / filename
        for room in ROOMS
        for filename, _ in ANIMATION_CAPTURES
        if not (OUTPUT / room / "1080p" / filename).exists()
    ]
    if missing_animations:
        formatted = "\n".join(str(path) for path in missing_animations)
        raise FileNotFoundError(f"Missing animation captures:\n{formatted}")


def main() -> int:
    verify_inputs()
    for room in ROOMS:
        room_boards(room)
    global_boards()
    scale_ladder()
    validation_summary()
    print("UNIT_PRESENCE_BOARDS_COMPLETE rooms=3 resolutions=3")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
