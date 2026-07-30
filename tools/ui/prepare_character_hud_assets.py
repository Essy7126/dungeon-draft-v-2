#!/usr/bin/env python3
"""Prepare character HUD assets from the four flattened JPG reference sheets.

The script is intentionally deterministic and keeps every source file read-only.
It can be run with Pillow when available or from Blender's bundled Python:

    blender --background --python tools/ui/prepare_character_hud_assets.py --

Generated spell icons use stable row/column names.  The accompanying manifest
records both their source rectangle and their position in the generated atlas.
"""

from __future__ import annotations

import argparse
import hashlib
import json
import math
import struct
import sys
import zlib
from collections import Counter, deque
from dataclasses import dataclass
from pathlib import Path
from typing import Iterable, Sequence


PNG_SIGNATURE = b"\x89PNG\r\n\x1a\n"
ICON_COLUMNS = 6
ICON_ROWS = 10
ICON_SIZE = 112
TRANSPARENT_MARGIN = 3


@dataclass
class ImageData:
    width: int
    height: int
    pixels: bytearray

    def offset(self, x: int, y: int) -> int:
        return (y * self.width + x) * 4

    def rgb(self, x: int, y: int) -> tuple[int, int, int]:
        offset = self.offset(x, y)
        return tuple(self.pixels[offset : offset + 3])  # type: ignore[return-value]

    def alpha(self, x: int, y: int) -> int:
        return self.pixels[self.offset(x, y) + 3]

    def set_rgba(self, x: int, y: int, rgba: tuple[int, int, int, int]) -> None:
        offset = self.offset(x, y)
        self.pixels[offset : offset + 4] = bytes(rgba)


def _load_with_pillow(path: Path) -> ImageData | None:
    try:
        from PIL import Image  # type: ignore[import-not-found]
    except ImportError:
        return None
    source = Image.open(path).convert("RGBA")
    return ImageData(source.width, source.height, bytearray(source.tobytes()))


def _load_with_blender(path: Path) -> ImageData:
    try:
        import bpy  # type: ignore[import-not-found]
    except ImportError as error:
        raise RuntimeError(
            "JPG loading requires Pillow or execution through Blender"
        ) from error

    source = bpy.data.images.load(str(path), check_existing=False)
    try:
        source.colorspace_settings.name = "Non-Color"
    except TypeError:
        pass
    width, height = source.size
    floats = list(source.pixels)
    pixels = bytearray(width * height * 4)
    # Blender exposes image rows bottom-to-top.
    for target_y in range(height):
        source_y = height - 1 - target_y
        for x in range(width):
            source_offset = (source_y * width + x) * 4
            target_offset = (target_y * width + x) * 4
            for channel in range(4):
                value = floats[source_offset + channel]
                pixels[target_offset + channel] = round(
                    max(0.0, min(1.0, value)) * 255.0
                )
    bpy.data.images.remove(source)
    return ImageData(width, height, pixels)


def load_image(path: Path) -> ImageData:
    image = _load_with_pillow(path)
    return image if image is not None else _load_with_blender(path)


def _png_chunk(chunk_type: bytes, data: bytes) -> bytes:
    return (
        struct.pack(">I", len(data))
        + chunk_type
        + data
        + struct.pack(">I", zlib.crc32(chunk_type + data) & 0xFFFFFFFF)
    )


def write_png(path: Path, image: ImageData) -> None:
    scanlines = bytearray()
    stride = image.width * 4
    for y in range(image.height):
        scanlines.append(0)
        row_start = y * stride
        scanlines.extend(image.pixels[row_start : row_start + stride])
    header = struct.pack(">IIBBBBB", image.width, image.height, 8, 6, 0, 0, 0)
    payload = (
        PNG_SIGNATURE
        + _png_chunk(b"IHDR", header)
        + _png_chunk(b"IDAT", zlib.compress(bytes(scanlines), 9))
        + _png_chunk(b"IEND", b"")
    )
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_bytes(payload)


def _paeth(left: int, above: int, upper_left: int) -> int:
    prediction = left + above - upper_left
    distances = (
        (abs(prediction - left), left),
        (abs(prediction - above), above),
        (abs(prediction - upper_left), upper_left),
    )
    return min(distances, key=lambda item: item[0])[1]


def read_png(path: Path) -> ImageData:
    payload = path.read_bytes()
    if not payload.startswith(PNG_SIGNATURE):
        raise ValueError(f"{path}: invalid PNG signature")
    cursor = len(PNG_SIGNATURE)
    compressed = bytearray()
    width = height = color_type = bit_depth = interlace = -1
    while cursor < len(payload):
        length = struct.unpack(">I", payload[cursor : cursor + 4])[0]
        chunk_type = payload[cursor + 4 : cursor + 8]
        chunk_data = payload[cursor + 8 : cursor + 8 + length]
        cursor += length + 12
        if chunk_type == b"IHDR":
            width, height, bit_depth, color_type, _, _, interlace = struct.unpack(
                ">IIBBBBB", chunk_data
            )
        elif chunk_type == b"IDAT":
            compressed.extend(chunk_data)
        elif chunk_type == b"IEND":
            break
    if bit_depth != 8 or color_type != 6 or interlace != 0:
        raise ValueError(f"{path}: unsupported PNG format")
    stride = width * 4
    raw = zlib.decompress(bytes(compressed))
    reconstructed = bytearray(height * stride)
    cursor = 0
    for y in range(height):
        filter_type = raw[cursor]
        cursor += 1
        row_start = y * stride
        previous_start = (y - 1) * stride
        for column in range(stride):
            value = raw[cursor]
            cursor += 1
            left = reconstructed[row_start + column - 4] if column >= 4 else 0
            above = reconstructed[previous_start + column] if y > 0 else 0
            upper_left = (
                reconstructed[previous_start + column - 4]
                if y > 0 and column >= 4
                else 0
            )
            if filter_type == 1:
                value = (value + left) & 0xFF
            elif filter_type == 2:
                value = (value + above) & 0xFF
            elif filter_type == 3:
                value = (value + ((left + above) // 2)) & 0xFF
            elif filter_type == 4:
                value = (value + _paeth(left, above, upper_left)) & 0xFF
            elif filter_type != 0:
                raise ValueError(f"{path}: unsupported PNG filter {filter_type}")
            reconstructed[row_start + column] = value
    return ImageData(width, height, reconstructed)


def crop(image: ImageData, rectangle: tuple[int, int, int, int]) -> ImageData:
    left, top, right, bottom = rectangle
    left = max(0, min(image.width, left))
    top = max(0, min(image.height, top))
    right = max(left, min(image.width, right))
    bottom = max(top, min(image.height, bottom))
    result = ImageData(right - left, bottom - top, bytearray())
    for y in range(top, bottom):
        start = image.offset(left, y)
        end = image.offset(right - 1, y) + 4
        result.pixels.extend(image.pixels[start:end])
    return result


def _border_coordinates(width: int, height: int, depth: int = 3) -> Iterable[tuple[int, int]]:
    for y in range(height):
        for x in range(min(depth, width)):
            yield x, y
            yield width - 1 - x, y
    for x in range(depth, max(depth, width - depth)):
        for y in range(min(depth, height)):
            yield x, y
            yield x, height - 1 - y


def _color_distance(first: tuple[int, int, int], second: tuple[int, int, int]) -> float:
    return math.sqrt(sum((first[index] - second[index]) ** 2 for index in range(3)))


def _background_palette(image: ImageData) -> list[tuple[int, int, int]]:
    bins: Counter[tuple[int, int, int]] = Counter()
    sums: dict[tuple[int, int, int], list[int]] = {}
    for x, y in _border_coordinates(image.width, image.height, 4):
        rgb = image.rgb(x, y)
        key = tuple(channel // 12 for channel in rgb)
        bins[key] += 1
        values = sums.setdefault(key, [0, 0, 0, 0])
        values[0] += rgb[0]
        values[1] += rgb[1]
        values[2] += rgb[2]
        values[3] += 1
    palette: list[tuple[int, int, int]] = []
    covered = 0
    total = sum(bins.values())
    for key, count in bins.most_common(16):
        values = sums[key]
        palette.append(
            (
                round(values[0] / values[3]),
                round(values[1] / values[3]),
                round(values[2] / values[3]),
            )
        )
        covered += count
        if len(palette) >= 3 and covered >= total * 0.92:
            break
    if not palette:
        raise ValueError("Unable to estimate the flattened background")
    return palette


def _closest_color(
    rgb: tuple[int, int, int],
    palette: Sequence[tuple[int, int, int]],
) -> tuple[tuple[int, int, int], float]:
    result = min(palette, key=lambda candidate: _color_distance(rgb, candidate))
    return result, _color_distance(rgb, result)


def remove_exterior_background(
    image: ImageData,
    strict_distance: float = 34.0,
    feather_distance: float = 72.0,
) -> ImageData:
    palette = _background_palette(image)
    exterior = bytearray(image.width * image.height)
    queue: deque[int] = deque()
    for x, y in _border_coordinates(image.width, image.height, 1):
        index = y * image.width + x
        if exterior[index]:
            continue
        _, distance = _closest_color(image.rgb(x, y), palette)
        if distance <= strict_distance:
            exterior[index] = 1
            queue.append(index)
    while queue:
        index = queue.popleft()
        x = index % image.width
        y = index // image.width
        for neighbor in (
            index - 1 if x > 0 else -1,
            index + 1 if x + 1 < image.width else -1,
            index - image.width if y > 0 else -1,
            index + image.width if y + 1 < image.height else -1,
        ):
            if neighbor < 0 or exterior[neighbor]:
                continue
            nx = neighbor % image.width
            ny = neighbor // image.width
            _, distance = _closest_color(image.rgb(nx, ny), palette)
            if distance <= strict_distance:
                exterior[neighbor] = 1
                queue.append(neighbor)
    for index, value in enumerate(exterior):
        if value:
            image.pixels[index * 4 + 3] = 0

    # Recover anti-aliased silhouettes by assigning alpha from color contrast
    # on only the first two foreground rings around the removed exterior.
    frontier: list[int] = []
    seen = bytearray(image.width * image.height)
    for index, value in enumerate(exterior):
        if not value:
            continue
        x = index % image.width
        y = index // image.width
        for neighbor in (
            index - 1 if x > 0 else -1,
            index + 1 if x + 1 < image.width else -1,
            index - image.width if y > 0 else -1,
            index + image.width if y + 1 < image.height else -1,
        ):
            if neighbor >= 0 and not exterior[neighbor] and not seen[neighbor]:
                seen[neighbor] = 1
                frontier.append(neighbor)
    for depth in range(2):
        next_frontier: list[int] = []
        for index in frontier:
            x = index % image.width
            y = index // image.width
            rgb = image.rgb(x, y)
            background, distance = _closest_color(rgb, palette)
            if distance < feather_distance:
                alpha = round(
                    255.0
                    * max(0.08, min(1.0, (distance - strict_distance * 0.45) / 50.0))
                )
                if alpha < 250:
                    fraction = max(alpha / 255.0, 0.05)
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
                if neighbor >= 0 and not exterior[neighbor] and not seen[neighbor]:
                    seen[neighbor] = 1
                    next_frontier.append(neighbor)
        frontier = next_frontier
    return image


def autocrop(image: ImageData, margin: int = TRANSPARENT_MARGIN) -> ImageData:
    visible: list[tuple[int, int]] = []
    for y in range(image.height):
        for x in range(image.width):
            if image.alpha(x, y) > 2:
                visible.append((x, y))
    if not visible:
        raise ValueError("Asset became fully transparent")
    left = min(point[0] for point in visible)
    right = max(point[0] for point in visible)
    top = min(point[1] for point in visible)
    bottom = max(point[1] for point in visible)
    source = crop(image, (left, top, right + 1, bottom + 1))
    result = ImageData(
        source.width + margin * 2,
        source.height + margin * 2,
        bytearray((source.width + margin * 2) * (source.height + margin * 2) * 4),
    )
    for y in range(source.height):
        source_start = source.offset(0, y)
        target_start = result.offset(margin, y + margin)
        result.pixels[target_start : target_start + source.width * 4] = (
            source.pixels[source_start : source_start + source.width * 4]
        )
    return result


def _estimate_sheet_background(image: ImageData) -> tuple[int, int, int]:
    samples = [
        image.rgb(0, 0),
        image.rgb(image.width - 1, 0),
        image.rgb(0, image.height - 1),
        image.rgb(image.width - 1, image.height - 1),
    ]
    return tuple(round(sum(sample[channel] for sample in samples) / 4) for channel in range(3))  # type: ignore[return-value]


def _activity_runs(
    image: ImageData,
    horizontal: bool,
    expected: int,
) -> list[tuple[int, int]]:
    background = _estimate_sheet_background(image)
    primary = image.width if horizontal else image.height
    secondary = image.height if horizontal else image.width
    scores: list[float] = []
    for position in range(primary):
        active = 0
        for other in range(secondary):
            x, y = (position, other) if horizontal else (other, position)
            if _color_distance(image.rgb(x, y), background) > 28.0:
                active += 1
        scores.append(active / secondary)
    smoothed: list[float] = []
    for index in range(primary):
        left = max(0, index - 2)
        right = min(primary, index + 3)
        smoothed.append(sum(scores[left:right]) / (right - left))
    threshold = 0.11 if horizontal else 0.10
    runs: list[tuple[int, int]] = []
    start = -1
    for index, score in enumerate(smoothed + [0.0]):
        if score >= threshold and start < 0:
            start = index
        elif score < threshold and start >= 0:
            if index - start >= 20:
                runs.append((start, index))
            start = -1
    if len(runs) != expected:
        raise ValueError(
            f"Detected {len(runs)} {'columns' if horizontal else 'rows'}, "
            f"expected {expected}: {runs}"
        )
    return runs


def _place_centered(source: ImageData, size: int) -> ImageData:
    if source.width > size or source.height > size:
        raise ValueError(
            f"Detected icon {source.width}x{source.height} does not fit {size}px cell"
        )
    result = ImageData(size, size, bytearray(size * size * 4))
    left = (size - source.width) // 2
    top = (size - source.height) // 2
    for y in range(source.height):
        source_start = source.offset(0, y)
        target_start = result.offset(left, top + y)
        result.pixels[target_start : target_start + source.width * 4] = (
            source.pixels[source_start : source_start + source.width * 4]
        )
    return result


def _blit(target: ImageData, source: ImageData, left: int, top: int) -> None:
    for y in range(source.height):
        source_start = source.offset(0, y)
        target_start = target.offset(left, top + y)
        target.pixels[target_start : target_start + source.width * 4] = (
            source.pixels[source_start : source_start + source.width * 4]
        )


def _alpha_counts(image: ImageData) -> tuple[int, int, int]:
    transparent = partial = opaque = 0
    for index in range(image.width * image.height):
        alpha = image.pixels[index * 4 + 3]
        if alpha == 0:
            transparent += 1
        elif alpha == 255:
            opaque += 1
        else:
            partial += 1
    return transparent, partial, opaque


def validate_transparency(path: Path) -> dict[str, int | str]:
    image = read_png(path)
    transparent, partial, opaque = _alpha_counts(image)
    if transparent == 0 or partial == 0 or opaque == 0:
        raise ValueError(
            f"{path.name}: expected transparent, partial and opaque pixels, "
            f"got {transparent}/{partial}/{opaque}"
        )
    return {
        "width": image.width,
        "height": image.height,
        "transparent": transparent,
        "partial": partial,
        "opaque": opaque,
        "sha256": hashlib.sha256(path.read_bytes()).hexdigest()[:16],
    }


def _resolve_sources(source_root: Path) -> dict[str, Path]:
    candidates = {
        "bar": source_root / "character_bars/barre_personnage.jpg",
        "emblem": source_root / "class_emblems/branche_main_abre_competence.jpg",
        "icons": source_root / "spell_icons/icone_sorts.jpg",
        "banner": source_root / "turn_banner/présentation_tour.jpg",
    }
    missing = [path for path in candidates.values() if not path.is_file()]
    if missing:
        raise FileNotFoundError(
            "Missing source asset(s): " + ", ".join(str(path) for path in missing)
        )
    return candidates


def prepare(source_root: Path, output_dir: Path) -> None:
    repository_root = Path(__file__).resolve().parents[2]
    sources = _resolve_sources(source_root)
    source_hashes = {
        role: hashlib.sha256(path.read_bytes()).hexdigest()
        for role, path in sources.items()
    }
    output_dir.mkdir(parents=True, exist_ok=True)

    bar_sheet = load_image(sources["bar"])
    bar_crop = (
        round(bar_sheet.width * 0.215),
        round(bar_sheet.height * 0.282),
        round(bar_sheet.width * 0.992),
        round(bar_sheet.height * 0.470),
    )
    bar = autocrop(remove_exterior_background(crop(bar_sheet, bar_crop)))
    bar_path = output_dir / "elf_character_bar.png"
    write_png(bar_path, bar)

    emblem_sheet = load_image(sources["emblem"])
    emblem_crop = (
        round(emblem_sheet.width * 0.335),
        round(emblem_sheet.height * 0.495),
        round(emblem_sheet.width * 0.665),
        round(emblem_sheet.height * 0.720),
    )
    emblem = autocrop(remove_exterior_background(crop(emblem_sheet, emblem_crop)))
    emblem_path = output_dir / "elf_hunter_emblem.png"
    write_png(emblem_path, emblem)

    banner_sheet = load_image(sources["banner"])
    banner = autocrop(
        remove_exterior_background(
            banner_sheet,
            strict_distance=30.0,
            feather_distance=76.0,
        )
    )
    banner_path = output_dir / "turn_intro_banner.png"
    write_png(banner_path, banner)

    icon_sheet = load_image(sources["icons"])
    column_runs = _activity_runs(icon_sheet, horizontal=True, expected=ICON_COLUMNS)
    row_runs = _activity_runs(icon_sheet, horizontal=False, expected=ICON_ROWS)
    atlas = ImageData(
        ICON_COLUMNS * ICON_SIZE,
        ICON_ROWS * ICON_SIZE,
        bytearray(ICON_COLUMNS * ICON_SIZE * ICON_ROWS * ICON_SIZE * 4),
    )
    manifest_icons: list[dict[str, object]] = []
    for row, (top, bottom) in enumerate(row_runs):
        for column, (left, right) in enumerate(column_runs):
            pad = 3
            source_rect = (
                max(0, left - pad),
                max(0, top - pad),
                min(icon_sheet.width, right + pad),
                min(icon_sheet.height, bottom + pad),
            )
            icon = autocrop(
                remove_exterior_background(crop(icon_sheet, source_rect)),
                margin=4,
            )
            icon = _place_centered(icon, ICON_SIZE)
            filename = f"spell_icon_r{row:02d}_c{column:02d}.png"
            write_png(output_dir / filename, icon)
            atlas_x = column * ICON_SIZE
            atlas_y = row * ICON_SIZE
            _blit(atlas, icon, atlas_x, atlas_y)
            manifest_icons.append(
                {
                    "row": row,
                    "column": column,
                    "filename": filename,
                    "source_rect": {
                        "x": source_rect[0],
                        "y": source_rect[1],
                        "width": source_rect[2] - source_rect[0],
                        "height": source_rect[3] - source_rect[1],
                    },
                    "atlas_rect": {
                        "x": atlas_x,
                        "y": atlas_y,
                        "width": ICON_SIZE,
                        "height": ICON_SIZE,
                    },
                }
            )
    atlas_path = output_dir / "spell_icons_atlas.png"
    write_png(atlas_path, atlas)
    manifest = {
        "source": sources["icons"].relative_to(repository_root).as_posix(),
        "source_sha256": source_hashes["icons"],
        "rows": ICON_ROWS,
        "columns": ICON_COLUMNS,
        "cell_size": ICON_SIZE,
        "atlas": atlas_path.name,
        "detected_columns": [
            {"left": left, "right": right} for left, right in column_runs
        ],
        "detected_rows": [{"top": top, "bottom": bottom} for top, bottom in row_runs],
        "icons": manifest_icons,
    }
    (output_dir / "spell_icons_manifest.json").write_text(
        json.dumps(manifest, ensure_ascii=False, indent=2) + "\n",
        encoding="utf-8",
    )

    for path in (bar_path, emblem_path, banner_path):
        report = validate_transparency(path)
        print(
            f"{path.name}: {report['width']}x{report['height']}, "
            f"alpha={report['transparent']}/{report['partial']}/{report['opaque']}, "
            f"sha256={report['sha256']}"
        )
    print(
        f"{atlas_path.name}: {atlas.width}x{atlas.height}; "
        f"grid={len(column_runs)}x{len(row_runs)}; icons={len(manifest_icons)}"
    )
    for role, source_path in sources.items():
        current_hash = hashlib.sha256(source_path.read_bytes()).hexdigest()
        if current_hash != source_hashes[role]:
            raise RuntimeError(f"Source asset was modified: {source_path}")


def check(output_dir: Path) -> None:
    for filename in (
        "elf_character_bar.png",
        "elf_hunter_emblem.png",
        "turn_intro_banner.png",
    ):
        report = validate_transparency(output_dir / filename)
        print(
            f"{filename}: {report['width']}x{report['height']}, "
            f"sha256={report['sha256']}"
        )
    manifest_path = output_dir / "spell_icons_manifest.json"
    manifest = json.loads(manifest_path.read_text(encoding="utf-8"))
    if manifest.get("rows") != ICON_ROWS or manifest.get("columns") != ICON_COLUMNS:
        raise ValueError("Unexpected manifest dimensions")
    icons = manifest.get("icons", [])
    if len(icons) != ICON_ROWS * ICON_COLUMNS:
        raise ValueError(f"Expected 60 manifest icons, got {len(icons)}")
    for entry in icons:
        icon_path = output_dir / entry["filename"]
        report = validate_transparency(icon_path)
        if report["width"] != ICON_SIZE or report["height"] != ICON_SIZE:
            raise ValueError(f"{icon_path.name}: unexpected dimensions")
    atlas = read_png(output_dir / manifest["atlas"])
    if atlas.width != ICON_COLUMNS * ICON_SIZE or atlas.height != ICON_ROWS * ICON_SIZE:
        raise ValueError("Unexpected spell atlas dimensions")
    print("spell_icons_manifest.json: 6x10 grid, 60 validated icons")


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
        default=repository_root / "asset/ui/character_hud/generated",
    )
    parser.add_argument("--check", action="store_true")
    command_line = (
        sys.argv[sys.argv.index("--") + 1 :]
        if "--" in sys.argv
        else sys.argv[1:]
    )
    arguments = parser.parse_args(command_line)
    try:
        if arguments.check:
            check(arguments.output_dir.resolve())
        else:
            prepare(arguments.source_root.resolve(), arguments.output_dir.resolve())
    except (OSError, ValueError, RuntimeError, zlib.error) as error:
        print(f"error: {error}", file=sys.stderr)
        return 1
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
