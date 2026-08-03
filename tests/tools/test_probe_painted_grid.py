from __future__ import annotations

import importlib.util
import unittest
from pathlib import Path

import numpy as np


SCRIPT = (
    Path(__file__).resolve().parents[2]
    / "tools"
    / "calibration"
    / "probe_painted_grid.py"
)
SPEC = importlib.util.spec_from_file_location("painted_grid_probe", SCRIPT)
assert SPEC is not None and SPEC.loader is not None
painted_grid_probe = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(painted_grid_probe)


class PaintedGridProbeTest(unittest.TestCase):
    def test_point_parser_rejects_non_integer_coordinates(self) -> None:
        self.assertEqual(painted_grid_probe.parse_point("12,34"), (12, 34))
        with self.assertRaises(Exception):
            painted_grid_probe.parse_point("12.5,34")

    def test_repeated_peak_detection_is_deterministic(self) -> None:
        histogram = np.zeros(240, dtype=np.float64)
        histogram[np.arange(7, 240, 30)] = 100.0

        first = painted_grid_probe.repeated_peaks(
            histogram,
            0,
            spacing_min=28,
            spacing_max=32,
        )
        second = painted_grid_probe.repeated_peaks(
            histogram,
            0,
            spacing_min=28,
            spacing_max=32,
        )

        self.assertEqual(first, second)
        self.assertEqual(first[0], 30)
        self.assertEqual(first[1], [float(value) for value in range(7, 240, 30)])


if __name__ == "__main__":
    unittest.main()
