#!/usr/bin/env python3
"""Prepare the clean, data-driven character HUD V2 presentation assets.

The sources remain read-only.  The four discipline frames are flattened PNGs
whose checkerboards are part of the RGB image, so only background pixels
connected to the exterior are removed.  The watermarked blue/red reference
sheet is deliberately never loaded or sampled.

Run with Blender's bundled Python:

    blender --background --python tools/ui/prepare_character_hud_v2_assets.py --
"""

from __future__ import annotations

import argparse
import hashlib
import json
import sys
from collections import deque
from pathlib import Path


SCRIPT_DIR = Path(__file__).resolve().parent
if str(SCRIPT_DIR) not in sys.path:
    sys.path.insert(0, str(SCRIPT_DIR))

from prepare_character_hud_assets import (  # noqa: E402
    _background_palette,
    _closest_color,
    autocrop,
    crop,
    load_image,
    remove_exterior_background,
    validate_transparency,
    write_png,
)


FRAME_SOURCES = {
    "spell_frame_archer.png": "cadre_sort_archer.png",
    "spell_frame_assassin.png": "cadre_sort_assassin.png",
    "spell_frame_mage.png": "cadre_sort_mage.png",
    "spell_frame_healer.png": "cadre_sort_healer.png",
}

# Coordinates are measured on the clean 640x480 gold sheet.  These crops keep
# a small exterior border so the shared flood-fill can identify the black
# connected background without erasing enclosed ornament details.
GOLD_CROPS = {
    "gold_health_bar_frame.png": (370, 286, 489, 318),
    "gold_end_turn_button.png": (386, 314, 495, 361),
}

REJECTED_CANDIDATES = {
    "gold_resource_badge.png": (
        "Rejected after visual inspection: the medallion touches a neighboring "
        "separator on the flattened sheet; the existing clean badge is retained."
    ),
    "gold_portrait_frame.png": (
        "Rejected after visual inspection: the tiny square source has incomplete "
        "corners and visible color compression; the clean archer frame is reused."
    ),
}

WATERMARKED_REFERENCE = "pack/pack_bouton.jpg"
WATERMARK_REASON = (
    "Excluded: repeated PCAT007 SAMPLE watermark; never loaded or extracted."
)


def _sha256(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest()


def _remove_flattened_checkerboard(image):
    """Remove large neutral checker components, including the enclosed center.

    The background is identified from border colors, but a component is erased
    only if it touches the exterior or is large enough to be a checker field.
    Small neutral highlights belonging to the ornament are therefore kept.
    """

    palette = _background_palette(image)
    pixel_count = image.width * image.height
    candidates = bytearray(pixel_count)
    for index in range(pixel_count):
        offset = index * 4
        rgb = tuple(image.pixels[offset : offset + 3])
        chroma = max(rgb) - min(rgb)
        _, distance = _closest_color(rgb, palette)
        if chroma <= 12 and distance <= 52.0:
            candidates[index] = 1

    removed = bytearray(pixel_count)
    visited = bytearray(pixel_count)
    minimum_field_size = max(256, round(pixel_count * 0.00035))
    for seed in range(pixel_count):
        if not candidates[seed] or visited[seed]:
            continue
        component: list[int] = []
        queue: deque[int] = deque([seed])
        visited[seed] = 1
        touches_border = False
        while queue:
            index = queue.popleft()
            component.append(index)
            x = index % image.width
            y = index // image.width
            touches_border = touches_border or (
                x == 0
                or y == 0
                or x + 1 == image.width
                or y + 1 == image.height
            )
            for neighbor in (
                index - 1 if x > 0 else -1,
                index + 1 if x + 1 < image.width else -1,
                index - image.width if y > 0 else -1,
                index + image.width if y + 1 < image.height else -1,
            ):
                if (
                    neighbor >= 0
                    and candidates[neighbor]
                    and not visited[neighbor]
                ):
                    visited[neighbor] = 1
                    queue.append(neighbor)
        if touches_border or len(component) >= minimum_field_size:
            for index in component:
                removed[index] = 1
                image.pixels[index * 4 + 3] = 0

    # Reconstruct anti-aliased and glow pixels on the first foreground rings.
    frontier: list[int] = []
    seen = bytearray(pixel_count)
    for index, is_removed in enumerate(removed):
        if not is_removed:
            continue
        x = index % image.width
        y = index // image.width
        for neighbor in (
            index - 1 if x > 0 else -1,
            index + 1 if x + 1 < image.width else -1,
            index - image.width if y > 0 else -1,
            index + image.width if y + 1 < image.height else -1,
        ):
            if neighbor >= 0 and not removed[neighbor] and not seen[neighbor]:
                seen[neighbor] = 1
                frontier.append(neighbor)
    for _depth in range(4):
        next_frontier: list[int] = []
        for index in frontier:
            x = index % image.width
            y = index // image.width
            rgb = image.rgb(x, y)
            background, distance = _closest_color(rgb, palette)
            if distance < 88.0:
                alpha = round(
                    255.0 * max(0.04, min(1.0, (distance - 8.0) / 72.0))
                )
                if alpha < 250:
                    fraction = max(alpha / 255.0, 0.04)
                    unmixed = tuple(
                        round(
                            max(
                                0.0,
                                min(
                                    255.0,
                                    (
                                        rgb[channel]
                                        - background[channel] * (1.0 - fraction)
                                    )
                                    / fraction,
                                ),
                            )
                        )
                        for channel in range(3)
                    )
                    image.set_rgba(x, y, (*unmixed, alpha))
            for neighbor in (
                index - 1 if x > 0 else -1,
                index + 1 if x + 1 < image.width else -1,
                index - image.width if y > 0 else -1,
                index + image.width if y + 1 < image.height else -1,
            ):
                if (
                    neighbor >= 0
                    and not removed[neighbor]
                    and not seen[neighbor]
                ):
                    seen[neighbor] = 1
                    next_frontier.append(neighbor)
        frontier = next_frontier
    return image


def _prepare_frame(source: Path, output: Path) -> dict[str, int | str]:
    image = load_image(source)
    clean = autocrop(
        _remove_flattened_checkerboard(image),
        margin=4,
    )
    write_png(output, clean)
    return validate_transparency(output)


def _prepare_gold_crop(
    sheet,
    rectangle: tuple[int, int, int, int],
    output: Path,
) -> dict[str, int | str]:
    clean = autocrop(
        remove_exterior_background(
            crop(sheet, rectangle),
            strict_distance=25.0,
            feather_distance=68.0,
        ),
        margin=3,
    )
    write_png(output, clean)
    return validate_transparency(output)


def prepare(source_root: Path, output_dir: Path) -> None:
    frame_root = source_root / "spell_icons"
    gold_sheet_path = source_root / "pack/84f1c661db9220f4e9d51fdfdbf6c787.jpg"
    required = [frame_root / name for name in FRAME_SOURCES.values()]
    required.append(gold_sheet_path)
    missing = [path for path in required if not path.is_file()]
    if missing:
        raise FileNotFoundError(
            "Missing source asset(s): " + ", ".join(str(path) for path in missing)
        )

    output_dir.mkdir(parents=True, exist_ok=True)
    manifest: dict[str, object] = {
        "generator": "tools/ui/prepare_character_hud_v2_assets.py",
        "background_policy": (
            "Only exterior-connected flattened backgrounds are removed; "
            "source files are never modified."
        ),
        "excluded_sources": {
            WATERMARKED_REFERENCE: WATERMARK_REASON,
        },
        "rejected_candidates": REJECTED_CANDIDATES,
        "sources": {},
        "outputs": {},
    }
    for rejected_name in REJECTED_CANDIDATES:
        rejected_path = output_dir / rejected_name
        if rejected_path.is_file():
            rejected_path.unlink()

    sources = manifest["sources"]
    outputs = manifest["outputs"]
    assert isinstance(sources, dict)
    assert isinstance(outputs, dict)

    for output_name, source_name in FRAME_SOURCES.items():
        source_path = frame_root / source_name
        output_path = output_dir / output_name
        sources[source_name] = _sha256(source_path)
        outputs[output_name] = _prepare_frame(source_path, output_path)

    sources[gold_sheet_path.name] = _sha256(gold_sheet_path)
    gold_sheet = load_image(gold_sheet_path)
    for output_name, rectangle in GOLD_CROPS.items():
        output_path = output_dir / output_name
        result = _prepare_gold_crop(gold_sheet, rectangle, output_path)
        result["source_rectangle"] = list(rectangle)
        outputs[output_name] = result

    manifest_path = output_dir / "hud_v2_manifest.json"
    manifest_path.write_text(
        json.dumps(manifest, indent=2, sort_keys=True) + "\n",
        encoding="utf-8",
    )
    print(
        "Prepared %d HUD V2 assets in %s"
        % (len(outputs), output_dir)
    )


def main() -> int:
    repository_root = Path(__file__).resolve().parents[2]
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument(
        "--source-root",
        type=Path,
        default=repository_root / "asset/ui/dark_menu/source",
    )
    parser.add_argument(
        "--output-dir",
        type=Path,
        default=repository_root / "asset/ui/character_hud/generated/v2",
    )
    arguments = parser.parse_args(sys.argv[sys.argv.index("--") + 1 :] if "--" in sys.argv else [])
    prepare(arguments.source_root.resolve(), arguments.output_dir.resolve())
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
