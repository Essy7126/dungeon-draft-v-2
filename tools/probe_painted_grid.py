from __future__ import annotations

from pathlib import Path

import numpy as np
from PIL import Image, ImageDraw


ROOT = Path(__file__).resolve().parents[1]


ROOMS = {
    "volcano": {
        "path": ROOT / "artifacts/maps/pool_map/map_lave_v2.jpg",
        "roi": [(315, 155), (688, 135), (1062, 326), (1056, 420), (688, 592), (315, 420)],
    },
    "space": {
        "path": ROOT / "artifacts/maps/pool_map/map_espace.jpg",
        "roi": [(252, 238), (688, 116), (1120, 302), (1120, 455), (688, 624), (250, 455)],
    },
}


def polygon_mask(size: tuple[int, int], polygon: list[tuple[int, int]]) -> np.ndarray:
    mask = Image.new("L", size, 0)
    ImageDraw.Draw(mask).polygon(polygon, fill=255)
    return np.asarray(mask, dtype=np.float32) / 255.0


def smooth(values: np.ndarray, radius: int = 2) -> np.ndarray:
    kernel = np.ones(radius * 2 + 1, dtype=np.float64)
    kernel /= kernel.sum()
    return np.convolve(values, kernel, mode="same")


def line_score(gray: np.ndarray, mask: np.ndarray, slope: float) -> tuple[np.ndarray, int]:
    gy, gx = np.gradient(gray)
    magnitude = np.hypot(gx, gy)
    normal = np.array([-slope, 1.0], dtype=np.float32)
    normal /= np.linalg.norm(normal)
    alignment = np.abs(gx * normal[0] + gy * normal[1]) / (magnitude + 1.0e-6)
    weights = magnitude * alignment**5 * mask
    yy, xx = np.indices(gray.shape)
    intercept = np.rint(yy - slope * xx).astype(np.int32)
    offset = int(-intercept.min())
    hist = np.bincount((intercept + offset).ravel(), weights=weights.ravel())
    return smooth(hist, 2), offset


def best_slope(gray: np.ndarray, mask: np.ndarray, sign: int) -> tuple[float, np.ndarray, int]:
    best: tuple[float, float, np.ndarray, int] | None = None
    for absolute in np.linspace(0.40, 0.62, 89):
        slope = float(sign * absolute)
        hist, offset = line_score(gray, mask, slope)
        # A real grid produces a repeated response at roughly 28-38 px spacing.
        centered = hist - smooth(hist, 18)
        score = 0.0
        for spacing in range(26, 39):
            score = max(score, float(np.dot(centered[:-spacing], centered[spacing:])))
        if best is None or score > best[0]:
            best = (score, slope, hist, offset)
    assert best is not None
    return best[1], best[2], best[3]


def repeated_peaks(hist: np.ndarray, offset: int) -> tuple[int, list[float]]:
    centered = hist - smooth(hist, 18)
    best_spacing = 0
    best_phase = 0
    best_score = -1.0e30
    for spacing in range(26, 39):
        for phase in range(spacing):
            indexes = np.arange(phase, len(centered), spacing)
            score = float(centered[indexes].sum())
            if score > best_score:
                best_score = score
                best_spacing = spacing
                best_phase = phase
    values = []
    for index in np.arange(best_phase, len(centered), best_spacing):
        if centered[index] > np.percentile(centered, 55):
            window_start = max(0, index - 3)
            window_end = min(len(centered), index + 4)
            refined = window_start + int(np.argmax(centered[window_start:window_end]))
            values.append(float(refined - offset))
    return best_spacing, values


def main() -> None:
    for room, config in ROOMS.items():
        image = Image.open(config["path"]).convert("RGB")
        gray = np.asarray(image, dtype=np.float32).mean(axis=2)
        mask = polygon_mask(image.size, config["roi"])
        print(room)
        for sign, label in ((1, "positive"), (-1, "negative")):
            slope, hist, offset = best_slope(gray, mask, sign)
            spacing, peaks = repeated_peaks(hist, offset)
            print(f"  {label}: slope={slope:.4f} spacing={spacing} peaks={peaks}")


if __name__ == "__main__":
    main()
