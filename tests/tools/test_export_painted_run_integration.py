from __future__ import annotations

import importlib.util
import tempfile
import unittest
from pathlib import Path

from PIL import Image


SCRIPT = (
    Path(__file__).resolve().parents[2]
    / "tools"
    / "export_painted_run_integration.py"
)
SPEC = importlib.util.spec_from_file_location("painted_export", SCRIPT)
assert SPEC is not None and SPEC.loader is not None
painted_export = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(painted_export)


class PaintedExportCacheTest(unittest.TestCase):
    def test_force_bypasses_an_otherwise_valid_png(self) -> None:
        with tempfile.TemporaryDirectory() as directory:
            target = Path(directory) / "calibration.png"
            Image.new("RGB", (16, 9), "black").save(target, "PNG")

            self.assertFalse(
                painted_export.should_regenerate(target, (16, 9))
            )
            self.assertTrue(
                painted_export.should_regenerate(target, (16, 9), force=True)
            )

    def test_invalid_dimensions_are_regenerated_without_force(self) -> None:
        with tempfile.TemporaryDirectory() as directory:
            target = Path(directory) / "calibration.png"
            Image.new("RGB", (8, 8), "black").save(target, "PNG")

            self.assertTrue(
                painted_export.should_regenerate(target, (16, 9))
            )

    def test_godot_uid_is_resolved_from_import_metadata(self) -> None:
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            metadata = root / "map.jpg.import"
            metadata.write_text(
                '[remap]\nuid="uid://painted-map"\n\n'
                '[deps]\nsource_file="res://asset/map/map.jpg"\n',
                encoding="utf-8",
            )

            source = painted_export.source_file_for_uid(
                "uid://painted-map",
                (root,),
            )

            self.assertEqual(source, "res://asset/map/map.jpg")


if __name__ == "__main__":
    unittest.main()
