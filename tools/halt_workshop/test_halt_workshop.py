"""Content contract tests in temporary workspaces; no production files are changed."""
import unittest
import uuid
from pathlib import Path

from PIL import Image
import halt_workshop as workshop


class HaltContentTests(unittest.TestCase):
    def setUp(self):
        base = (workshop.ROOT / "artifacts/dev/halt-test-fixtures").resolve()
        base.mkdir(parents=True, exist_ok=True)
        # Keep small fixtures with dev reports. Default inherited permissions also
        # work in the restricted Windows runner where private temp ACLs do not.
        self.root = base / uuid.uuid4().hex
        self.root.mkdir()
        self.source = self.root / "source.png"
        Image.new("RGB", (100, 60), (40, 130, 95)).save(self.source)
        self.style = self.root / "data/halts/styles/roots_bronze_v1.json"
        workshop.write(self.style, {"reference_images": ["res://reference.png"], "prompt_prefix": "LOCKED ART"})
        self.manifest = self.root / "map.json"
        self.data = {
            "schema_version": 1, "id": "test_v1", "stage": "playable_study",
            "source": {"image": "res://source.png", "size": [100, 60], "sha256": workshop.digest(self.source)},
            "style": "res://data/halts/styles/roots_bronze_v1.json", "build_dir": "res://built",
            "world": {"width": 2000, "player_scale": 0.5, "spawn": [0.1, 0.1]},
            "navigation": {"outline": [[0, 0], [1, 0], [1, 1], [0, 1]], "obstacles": []},
            "water": {"polygons": [[[0.1, 0.2], [0.9, 0.2], [0.9, 0.8], [0.1, 0.8]]], "exclusions": []},
            "landmarks": [{"point": [0.5, 0.5]}], "torches": [],
        }
        self.save()

    def save(self):
        workshop.write(self.manifest, self.data)

    def test_source_replacement_requires_recalibration(self):
        Image.new("RGB", (100, 60), "red").save(self.source)
        with self.assertRaisesRegex(ValueError, "hash changed"):
            workshop.prepare(self.manifest, self.root)
        self.assertFalse((self.root / "built").exists())

    def test_source_dimensions_checked_even_with_new_hash(self):
        Image.new("RGB", (200, 120), "red").save(self.source)
        self.data["source"]["sha256"] = workshop.digest(self.source)
        self.save()
        with self.assertRaisesRegex(ValueError, "size changed"):
            workshop.validate(self.manifest, self.root)

    def test_paths_cannot_escape_workspace(self):
        for path in ["../outside", "res://../../outside", str(self.root.parent / "outside")]:
            with self.subTest(path=path), self.assertRaises(ValueError):
                workshop.project_path(path, self.root)

    def test_bad_polygons_rejected(self):
        for polygon in [[], [[0, 0], [0, 0], [1, 1]], [[0, 0], [1, 1], [0, 1], [1, 0]], [[0, 0], [1, 0], [2, 1]], [[0, 0], [1, 0], [float("nan"), 1]]]:
            with self.subTest(polygon=polygon), self.assertRaises(ValueError):
                workshop.validate_polygon(polygon, "test")

    def test_packed_mask_keeps_water_when_alpha_is_zero(self):
        source_hash = workshop.digest(self.source)
        workshop.prepare(self.manifest, self.root)
        with Image.open(self.root / "built/materials.png") as image:
            self.assertEqual(image.getpixel((50, 30)), (255, 0, 0, 0))
        settings = (self.root / "built/materials.png.import").read_text(encoding="utf-8")
        self.assertIn("process/fix_alpha_border=false", settings)
        self.assertEqual(source_hash, workshop.digest(self.source))

    def test_exclusion_does_not_erase_other_channels(self):
        polygon = [[0.3, 0.3], [0.7, 0.3], [0.7, 0.7], [0.3, 0.7]]
        self.data["water"]["exclusions"] = [polygon]
        self.data["cascades"] = [{"polygon": polygon}]
        self.save()
        workshop.prepare(self.manifest, self.root)
        with Image.open(self.root / "built/materials.png") as image:
            self.assertEqual(image.getpixel((50, 30))[:2], (0, 255))

    def test_build_is_repeatable_and_manifest_changes_invalidate_it(self):
        first = workshop.prepare(self.manifest, self.root)
        self.assertEqual(first, workshop.prepare(self.manifest, self.root))
        self.data["world"]["width"] = 2100
        self.save()
        self.assertNotEqual(first["manifest_sha256"], workshop.digest(self.manifest))
        self.assertFalse(first["navigation_runtime_tested"])

    def test_brief_carries_reference_and_cannot_overwrite_version(self):
        folder = workshop.new_brief("new_v1", "sanctuary", "Emerald water", self.root)
        brief = workshop.read(folder / "request.json")
        self.assertIn("LOCKED ART", brief["prompt"])
        self.assertEqual(brief["references"], ["res://reference.png"])
        with self.assertRaises(ValueError):
            workshop.new_brief("new_v1", "merchant", "Different", self.root)

    def test_attach_measures_original_and_requires_authored_calibration(self):
        workshop.new_brief("new_v1", "sanctuary", "Emerald water", self.root)
        path = workshop.attach("new_v1", self.source, self.root)
        attached = workshop.read(path)
        self.assertEqual(attached["source"]["size"], [100, 60])
        self.assertEqual(attached["source"]["sha256"], workshop.digest(self.source))
        self.assertEqual(attached["navigation"]["outline"], [])
        with self.assertRaisesRegex(ValueError, "Calibration incomplete"):
            workshop.prepare(path, self.root)
        with self.assertRaises(ValueError):
            workshop.attach("new_v1", self.source, self.root)


if __name__ == "__main__":
    unittest.main()
