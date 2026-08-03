#!/usr/bin/env python3
"""Estimate the two repeated isometric-grid line families in a painted map."""

from __future__ import annotations

import argparse
import json
from pathlib import Path

import numpy as np
from PIL import Image, ImageDraw


Point = tuple[int, int]


def polygon_mask(
    size: tuple[int, int],
    polygon: list[Point] | None = None,
) -> np.ndarray:
    """Build a deterministic float mask; an omitted ROI selects the full image."""
    if polygon is None:
        return np.ones((size[1], size[0]), dtype=np.float32)
    mask = Image.new("L", size, 0)
    ImageDraw.Draw(mask).polygon(polygon, fill=255)
    return np.asarray(mask, dtype=np.float32) / 255.0


def smooth(values: np.ndarray, radius: int = 2) -> np.ndarray:
    if radius < 0:
        raise ValueError("smooth radius must be non-negative")
    if radius == 0:
        return values.astype(np.float64, copy=True)
    kernel = np.ones(radius * 2 + 1, dtype=np.float64)
    kernel /= kernel.sum()
    return np.convolve(values, kernel, mode="same")


def line_score(
    gray: np.ndarray,
    mask: np.ndarray,
    slope: float,
    *,
    smooth_radius: int = 2,
) -> tuple[np.ndarray, int]:
    gy, gx = np.gradient(gray)
    magnitude = np.hypot(gx, gy)
    normal = np.array([-slope, 1.0], dtype=np.float32)
    normal /= np.linalg.norm(normal)
    alignment = np.abs(gx * normal[0] + gy * normal[1]) / (
        magnitude + 1.0e-6
    )
    weights = magnitude * alignment**5 * mask
    yy, xx = np.indices(gray.shape)
    intercept = np.rint(yy - slope * xx).astype(np.int32)
    offset = int(-intercept.min())
    histogram = np.bincount(
        (intercept + offset).ravel(),
        weights=weights.ravel(),
    )
    return smooth(histogram, smooth_radius), offset


def repeated_peaks(
    histogram: np.ndarray,
    offset: int,
    *,
    spacing_min: int = 26,
    spacing_max: int = 38,
    baseline_radius: int = 18,
) -> tuple[int, list[float]]:
    if spacing_min <= 0 or spacing_max < spacing_min:
        raise ValueError("invalid spacing range")
    centered = histogram - smooth(histogram, baseline_radius)
    best_spacing = 0
    best_phase = 0
    best_score = -1.0e30
    for spacing in range(spacing_min, spacing_max + 1):
        for phase in range(spacing):
            indexes = np.arange(phase, len(centered), spacing)
            score = float(centered[indexes].sum())
            if score > best_score:
                best_score = score
                best_spacing = spacing
                best_phase = phase
    values: list[float] = []
    threshold = np.percentile(centered, 55)
    for index in np.arange(best_phase, len(centered), best_spacing):
        if centered[index] <= threshold:
            continue
        window_start = max(0, index - 3)
        window_end = min(len(centered), index + 4)
        refined = window_start + int(
            np.argmax(centered[window_start:window_end])
        )
        values.append(float(refined - offset))
    return best_spacing, values


def best_slope(
    gray: np.ndarray,
    mask: np.ndarray,
    sign: int,
    *,
    slope_min: float = 0.40,
    slope_max: float = 0.62,
    slope_samples: int = 89,
    spacing_min: int = 26,
    spacing_max: int = 38,
) -> tuple[float, np.ndarray, int]:
    if sign not in (-1, 1):
        raise ValueError("sign must be -1 or 1")
    if slope_min <= 0 or slope_max < slope_min or slope_samples < 2:
        raise ValueError("invalid slope search range")
    best: tuple[float, float, np.ndarray, int] | None = None
    for absolute in np.linspace(slope_min, slope_max, slope_samples):
        slope = float(sign * absolute)
        histogram, offset = line_score(gray, mask, slope)
        centered = histogram - smooth(histogram, 18)
        score = max(
            float(np.dot(centered[:-spacing], centered[spacing:]))
            for spacing in range(spacing_min, spacing_max + 1)
            if spacing < len(centered)
        )
        if best is None or score > best[0]:
            best = (score, slope, histogram, offset)
    if best is None:
        raise ValueError("image is too small for the requested spacing range")
    return best[1], best[2], best[3]


def analyze(
    image_path: Path,
    *,
    roi: list[Point] | None = None,
    slope_min: float = 0.40,
    slope_max: float = 0.62,
    slope_samples: int = 89,
    spacing_min: int = 26,
    spacing_max: int = 38,
) -> dict:
    image = Image.open(image_path).convert("RGB")
    gray = np.asarray(image, dtype=np.float32).mean(axis=2)
    mask = polygon_mask(image.size, roi)
    directions: dict[str, dict] = {}
    for sign, label in ((1, "positive"), (-1, "negative")):
        slope, histogram, offset = best_slope(
            gray,
            mask,
            sign,
            slope_min=slope_min,
            slope_max=slope_max,
            slope_samples=slope_samples,
            spacing_min=spacing_min,
            spacing_max=spacing_max,
        )
        spacing, peaks = repeated_peaks(
            histogram,
            offset,
            spacing_min=spacing_min,
            spacing_max=spacing_max,
        )
        directions[label] = {
            "slope": slope,
            "spacing_px": spacing,
            "intercepts": peaks,
        }
    return {
        "image": str(image_path),
        "image_size": list(image.size),
        "roi": [list(point) for point in roi] if roi is not None else None,
        "parameters": {
            "slope_min": slope_min,
            "slope_max": slope_max,
            "slope_samples": slope_samples,
            "spacing_min": spacing_min,
            "spacing_max": spacing_max,
        },
        "directions": directions,
    }


def parse_point(value: str) -> Point:
    try:
        x_text, y_text = value.split(",", maxsplit=1)
        return int(x_text), int(y_text)
    except ValueError as error:
        raise argparse.ArgumentTypeError(
            f"expected X,Y integer pair, got {value!r}"
        ) from error


def parse_args(argv: list[str] | None = None) -> argparse.Namespace:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--image", required=True, type=Path)
    parser.add_argument(
        "--roi",
        nargs="+",
        type=parse_point,
        metavar="X,Y",
        help="polygon vertices in image pixels; omit to analyze the full image",
    )
    parser.add_argument("--slope-min", type=float, default=0.40)
    parser.add_argument("--slope-max", type=float, default=0.62)
    parser.add_argument("--slope-samples", type=int, default=89)
    parser.add_argument("--spacing-min", type=int, default=26)
    parser.add_argument("--spacing-max", type=int, default=38)
    parser.add_argument(
        "--output-json",
        type=Path,
        help="optional JSON destination; stdout is always emitted",
    )
    return parser.parse_args(argv)


def main(argv: list[str] | None = None) -> int:
    args = parse_args(argv)
    if args.roi is not None and len(args.roi) < 3:
        raise SystemExit("--roi requires at least three X,Y vertices")
    result = analyze(
        args.image,
        roi=args.roi,
        slope_min=args.slope_min,
        slope_max=args.slope_max,
        slope_samples=args.slope_samples,
        spacing_min=args.spacing_min,
        spacing_max=args.spacing_max,
    )
    serialized = json.dumps(result, ensure_ascii=False, indent=2)
    if args.output_json is not None:
        args.output_json.parent.mkdir(parents=True, exist_ok=True)
        args.output_json.write_text(serialized + "\n", encoding="utf-8")
    print(serialized)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
