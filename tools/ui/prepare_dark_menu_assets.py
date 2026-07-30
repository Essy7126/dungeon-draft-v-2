#!/usr/bin/env python3
"""Prepare the opaque dark-menu source renders for Godot.

The source PNGs contain a flattened checkerboard.  This script deliberately
removes only checker-like pixels connected to the exterior, then softens the
remaining boundary to retain useful drop shadows and anti-aliased edges.

No third-party package is required.  The tiny PNG reader/writer below supports
the 8-bit, non-interlaced RGB/RGBA files used by this asset set.
"""

from __future__ import annotations

import argparse
import hashlib
import struct
import sys
import zlib
from collections import Counter, deque
from dataclasses import dataclass
from pathlib import Path
from typing import Iterable, Sequence


PNG_SIGNATURE = b"\x89PNG\r\n\x1a\n"
TRANSPARENT_MARGIN = 3
SOFT_EDGE_DEPTH = 6


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

    def set_rgba(
        self,
        x: int,
        y: int,
        rgba: tuple[int, int, int, int],
    ) -> None:
        offset = self.offset(x, y)
        self.pixels[offset : offset + 4] = bytes(rgba)


def _paeth(left: int, above: int, upper_left: int) -> int:
    prediction = left + above - upper_left
    left_distance = abs(prediction - left)
    above_distance = abs(prediction - above)
    upper_left_distance = abs(prediction - upper_left)
    if left_distance <= above_distance and left_distance <= upper_left_distance:
        return left
    if above_distance <= upper_left_distance:
        return above
    return upper_left


def read_png(path: Path) -> ImageData:
    payload = path.read_bytes()
    if not payload.startswith(PNG_SIGNATURE):
        raise ValueError(f"{path}: invalid PNG signature")

    cursor = len(PNG_SIGNATURE)
    width = height = bit_depth = color_type = interlace = -1
    compressed = bytearray()
    while cursor < len(payload):
        length = struct.unpack(">I", payload[cursor : cursor + 4])[0]
        chunk_type = payload[cursor + 4 : cursor + 8]
        chunk_data = payload[cursor + 8 : cursor + 8 + length]
        cursor += 12 + length
        if chunk_type == b"IHDR":
            width, height, bit_depth, color_type, _, _, interlace = struct.unpack(
                ">IIBBBBB", chunk_data
            )
        elif chunk_type == b"IDAT":
            compressed.extend(chunk_data)
        elif chunk_type == b"IEND":
            break

    if bit_depth != 8 or color_type not in (2, 6) or interlace != 0:
        raise ValueError(
            f"{path}: expected non-interlaced 8-bit RGB/RGBA PNG, "
            f"got depth={bit_depth}, type={color_type}, interlace={interlace}"
        )

    channels = 3 if color_type == 2 else 4
    stride = width * channels
    raw = zlib.decompress(bytes(compressed))
    expected = height * (stride + 1)
    if len(raw) != expected:
        raise ValueError(f"{path}: unexpected decompressed PNG size")

    reconstructed = bytearray(height * stride)
    source_cursor = 0
    for y in range(height):
        filter_type = raw[source_cursor]
        source_cursor += 1
        row_start = y * stride
        previous_start = (y - 1) * stride
        for column in range(stride):
            value = raw[source_cursor]
            source_cursor += 1
            left = reconstructed[row_start + column - channels] if column >= channels else 0
            above = reconstructed[previous_start + column] if y > 0 else 0
            upper_left = (
                reconstructed[previous_start + column - channels]
                if y > 0 and column >= channels
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

    rgba = bytearray(width * height * 4)
    for index in range(width * height):
        source = index * channels
        target = index * 4
        rgba[target : target + 3] = reconstructed[source : source + 3]
        rgba[target + 3] = reconstructed[source + 3] if channels == 4 else 255
    return ImageData(width, height, rgba)


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
    header = struct.pack(
        ">IIBBBBB",
        image.width,
        image.height,
        8,
        6,
        0,
        0,
        0,
    )
    payload = (
        PNG_SIGNATURE
        + _png_chunk(b"IHDR", header)
        + _png_chunk(b"IDAT", zlib.compress(bytes(scanlines), 9))
        + _png_chunk(b"IEND", b"")
    )
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_bytes(payload)


def _luminance(rgb: tuple[int, int, int]) -> float:
    red, green, blue = rgb
    return 0.2126 * red + 0.7152 * green + 0.0722 * blue


def _color_distance(
    first: tuple[int, int, int],
    second: tuple[int, int, int],
) -> float:
    return sum((first[index] - second[index]) ** 2 for index in range(3)) ** 0.5


def _border_coordinates(width: int, height: int, depth: int = 3) -> Iterable[tuple[int, int]]:
    for y in range(height):
        for x in range(min(depth, width)):
            yield x, y
            yield width - 1 - x, y
    for x in range(depth, max(depth, width - depth)):
        for y in range(min(depth, height)):
            yield x, y
            yield x, height - 1 - y


def _background_palette(image: ImageData) -> list[tuple[int, int, int]]:
    quantized: Counter[tuple[int, int, int]] = Counter()
    exact_sums: dict[tuple[int, int, int], list[int]] = {}
    for x, y in _border_coordinates(image.width, image.height):
        rgb = image.rgb(x, y)
        spread = max(rgb) - min(rgb)
        if spread > 24:
            continue
        key = tuple(channel // 8 for channel in rgb)
        quantized[key] += 1
        sums = exact_sums.setdefault(key, [0, 0, 0, 0])
        sums[0] += rgb[0]
        sums[1] += rgb[1]
        sums[2] += rgb[2]
        sums[3] += 1

    if not quantized:
        raise ValueError("No neutral checkerboard colors found on the image border")

    minimum_count = max(2, sum(quantized.values()) // 1200)
    palette: list[tuple[int, int, int]] = []
    for key, count in quantized.most_common(24):
        if count < minimum_count and len(palette) >= 8:
            continue
        sums = exact_sums[key]
        palette.append(
            (
                round(sums[0] / sums[3]),
                round(sums[1] / sums[3]),
                round(sums[2] / sums[3]),
            )
        )
    return palette


def _closest_palette_color(
    rgb: tuple[int, int, int],
    palette: Sequence[tuple[int, int, int]],
) -> tuple[tuple[int, int, int], float]:
    closest = palette[0]
    closest_distance = _color_distance(rgb, closest)
    for candidate in palette[1:]:
        distance = _color_distance(rgb, candidate)
        if distance < closest_distance:
            closest = candidate
            closest_distance = distance
    return closest, closest_distance


def _is_strict_background(
    rgb: tuple[int, int, int],
    palette: Sequence[tuple[int, int, int]],
    minimum_luminance: float,
    maximum_luminance: float,
) -> bool:
    spread = max(rgb) - min(rgb)
    if spread > 24:
        return False
    luminance = _luminance(rgb)
    if luminance < minimum_luminance - 18 or luminance > maximum_luminance + 18:
        return False
    _, distance = _closest_palette_color(rgb, palette)
    return distance <= 34


def remove_exterior_checkerboard(image: ImageData) -> tuple[ImageData, list[tuple[int, int, int]]]:
    palette = _background_palette(image)
    palette_luminances = [_luminance(color) for color in palette]
    minimum_luminance = min(palette_luminances)
    maximum_luminance = max(palette_luminances)
    pixel_count = image.width * image.height
    exterior = bytearray(pixel_count)
    queue: deque[int] = deque()

    for x, y in _border_coordinates(image.width, image.height, 1):
        index = y * image.width + x
        if exterior[index]:
            continue
        rgb = image.rgb(x, y)
        if _is_strict_background(
            rgb,
            palette,
            minimum_luminance,
            maximum_luminance,
        ):
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
            neighbor_x = neighbor % image.width
            neighbor_y = neighbor // image.width
            if not _is_strict_background(
                image.rgb(neighbor_x, neighbor_y),
                palette,
                minimum_luminance,
                maximum_luminance,
            ):
                continue
            exterior[neighbor] = 1
            queue.append(neighbor)

    for index, is_exterior in enumerate(exterior):
        if is_exterior:
            image.pixels[index * 4 + 3] = 0

    _soften_boundary(image, exterior, palette)
    return image, palette


def _soften_boundary(
    image: ImageData,
    exterior: bytearray,
    palette: Sequence[tuple[int, int, int]],
) -> None:
    width = image.width
    height = image.height
    seen = bytearray(width * height)
    frontier: list[int] = []

    for index in range(width * height):
        if exterior[index]:
            continue
        x = index % width
        y = index // width
        if (
            (x > 0 and exterior[index - 1])
            or (x + 1 < width and exterior[index + 1])
            or (y > 0 and exterior[index - width])
            or (y + 1 < height and exterior[index + width])
        ):
            frontier.append(index)
            seen[index] = 1

    for depth in range(1, SOFT_EDGE_DEPTH + 1):
        next_frontier: list[int] = []
        for index in frontier:
            x = index % width
            y = index // width
            rgb = image.rgb(x, y)
            background, distance = _closest_palette_color(rgb, palette)
            spread = max(rgb) - min(rgb)
            if spread <= 34 and distance < 92:
                contrast_alpha = round(
                    255.0 * max(0.0, min(1.0, (distance - 8.0) / 72.0))
                )
                depth_alpha = round(255.0 * depth / (SOFT_EDGE_DEPTH + 1))
                alpha = max(12, min(255, max(contrast_alpha, depth_alpha)))
                if alpha < 248:
                    image.set_rgba(
                        x,
                        y,
                        (*_unmix_background(rgb, background, alpha), alpha),
                    )
            for neighbor in (
                index - 1 if x > 0 else -1,
                index + 1 if x + 1 < width else -1,
                index - width if y > 0 else -1,
                index + width if y + 1 < height else -1,
            ):
                if (
                    neighbor < 0
                    or exterior[neighbor]
                    or seen[neighbor]
                ):
                    continue
                seen[neighbor] = 1
                next_frontier.append(neighbor)
        frontier = next_frontier


def _unmix_background(
    source: tuple[int, int, int],
    background: tuple[int, int, int],
    alpha: int,
) -> tuple[int, int, int]:
    fraction = max(alpha / 255.0, 0.05)
    result = []
    for channel in range(3):
        foreground = (
            source[channel] - background[channel] * (1.0 - fraction)
        ) / fraction
        result.append(round(max(0.0, min(255.0, foreground))))
    return tuple(result)  # type: ignore[return-value]


def autocrop(image: ImageData, margin: int = TRANSPARENT_MARGIN) -> ImageData:
    visible_x: list[int] = []
    visible_y: list[int] = []
    for y in range(image.height):
        for x in range(image.width):
            if image.alpha(x, y) > 2:
                visible_x.append(x)
                visible_y.append(y)
    if not visible_x:
        raise ValueError("Asset became fully transparent")

    left = min(visible_x)
    right = max(visible_x)
    top = min(visible_y)
    bottom = max(visible_y)
    width = right - left + 1 + margin * 2
    height = bottom - top + 1 + margin * 2
    cropped = ImageData(width, height, bytearray(width * height * 4))
    for source_y in range(top, bottom + 1):
        target_y = source_y - top + margin
        source_start = image.offset(left, source_y)
        source_end = image.offset(right, source_y) + 4
        target_start = cropped.offset(margin, target_y)
        cropped.pixels[target_start : target_start + source_end - source_start] = (
            image.pixels[source_start:source_end]
        )
    return cropped


def _button_visual_score(image: ImageData) -> float:
    left = image.width // 5
    right = image.width - left
    top = image.height // 4
    bottom = image.height - top
    scores: list[float] = []
    for y in range(top, bottom):
        for x in range(left, right):
            if image.alpha(x, y) < 240:
                continue
            red, green, blue = image.rgb(x, y)
            if red <= green * 1.08:
                continue
            scores.append(_luminance((red, green, blue)) + (red - green) * 0.35)
    if not scores:
        raise ValueError("Unable to score red button appearance")
    return sum(scores) / len(scores)


def _source_role(path: Path) -> str | None:
    name = path.name.lower()
    if "close-button" in name:
        return "close_button"
    if "plain-recessed" in name:
        return "bottom_section"
    if "title-header" in name:
        return "title_header"
    if "game-menu-frame" in name:
        return "main_frame"
    return None


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


def validate_output(path: Path) -> dict[str, int | str]:
    image = read_png(path)
    transparent, partial, opaque = _alpha_counts(image)
    if transparent == 0 or partial == 0 or opaque == 0:
        raise ValueError(
            f"{path}: alpha validation failed "
            f"(transparent={transparent}, partial={partial}, opaque={opaque})"
        )
    for x, y in _border_coordinates(image.width, image.height, 1):
        if image.alpha(x, y) != 0:
            raise ValueError(f"{path}: autocrop margin is not transparent")
    return {
        "width": image.width,
        "height": image.height,
        "transparent": transparent,
        "partial": partial,
        "opaque": opaque,
        "sha256": hashlib.sha256(path.read_bytes()).hexdigest()[:16],
    }


def prepare(source_dir: Path, output_dir: Path) -> None:
    source_paths = sorted(source_dir.glob("*.png"))
    if len(source_paths) != 7:
        raise ValueError(
            f"Expected exactly seven source PNGs in {source_dir}, "
            f"found {len(source_paths)}"
        )
    source_hashes = {
        path: hashlib.sha256(path.read_bytes()).digest()
        for path in source_paths
    }

    prepared: dict[Path, ImageData] = {}
    fixed_roles: dict[str, ImageData] = {}
    button_candidates: list[tuple[Path, ImageData, float]] = []
    for source_path in source_paths:
        image, _ = remove_exterior_checkerboard(read_png(source_path))
        image = autocrop(image)
        prepared[source_path] = image
        role = _source_role(source_path)
        if role is not None:
            fixed_roles[role] = image
        else:
            button_candidates.append(
                (source_path, image, _button_visual_score(image))
            )

    if len(fixed_roles) != 4 or len(button_candidates) != 3:
        raise ValueError(
            "Unable to identify four structural assets and three button states"
        )

    # Visual classification only: the darkest red is the resting state, the
    # brightest is hover/focus, and the remaining attenuated render is pressed.
    button_candidates.sort(key=lambda item: item[2])
    classified = {
        "button_normal": button_candidates[0][1],
        "button_pressed": button_candidates[1][1],
        "button_hover": button_candidates[2][1],
    }
    roles = {**fixed_roles, **classified}

    output_dir.mkdir(parents=True, exist_ok=True)
    print("Button classification (dark -> bright):")
    for source_path, _, score in button_candidates:
        print(f"  {score:7.2f}  {source_path.name}")

    for role in (
        "button_normal",
        "button_hover",
        "button_pressed",
        "close_button",
        "bottom_section",
        "title_header",
        "main_frame",
    ):
        output_path = output_dir / f"{role}.png"
        write_png(output_path, roles[role])
        report = validate_output(output_path)
        print(
            f"{output_path.name}: {report['width']}x{report['height']}, "
            f"alpha 0/partial/255 = {report['transparent']}/"
            f"{report['partial']}/{report['opaque']}, "
            f"sha256={report['sha256']}"
        )

    for source_path, digest in source_hashes.items():
        if hashlib.sha256(source_path.read_bytes()).digest() != digest:
            raise RuntimeError(f"Source asset was modified: {source_path}")


def check(output_dir: Path) -> None:
    expected = (
        "button_normal.png",
        "button_hover.png",
        "button_pressed.png",
        "close_button.png",
        "bottom_section.png",
        "title_header.png",
        "main_frame.png",
    )
    for name in expected:
        path = output_dir / name
        if not path.is_file():
            raise FileNotFoundError(path)
        report = validate_output(path)
        print(
            f"{name}: {report['width']}x{report['height']}, "
            f"alpha OK, sha256={report['sha256']}"
        )


def main() -> int:
    repository_root = Path(__file__).resolve().parents[2]
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument(
        "--source-dir",
        type=Path,
        default=repository_root / "asset/ui/dark_menu/source",
    )
    parser.add_argument(
        "--output-dir",
        type=Path,
        default=repository_root / "asset/ui/dark_menu/generated",
    )
    parser.add_argument(
        "--check",
        action="store_true",
        help="validate already generated files without rewriting them",
    )
    arguments = parser.parse_args()

    try:
        if arguments.check:
            check(arguments.output_dir.resolve())
        else:
            prepare(
                arguments.source_dir.resolve(),
                arguments.output_dir.resolve(),
            )
    except (OSError, ValueError, RuntimeError, zlib.error) as error:
        print(f"error: {error}", file=sys.stderr)
        return 1
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
