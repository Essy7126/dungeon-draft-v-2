"""Content contract tests in temporary workspaces; no production files are changed."""
import json
import unittest
import uuid
from pathlib import Path
from unittest import mock

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
            "landmarks": [{"id": "altar", "point": [0.5, 0.5]}], "torches": [],
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
        self.data["cascades"] = [{"polygon": polygon, "splash": [0.5, 0.7], "width": 10}]
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
        plan = workshop.read(folder / "spatial_plan.json")
        self.assertEqual(plan["world"]["player_height_ratio"], 0.22)
        self.assertIn("world.player_height_ratio=0.22", brief["prompt"])
        self.assertIn("22% of the full image height", brief["prompt"])
        self.assertIn("including spear and helmet plume", brief["prompt"])
        self.assertIn("same adjacent floor", brief["prompt"])
        self.assertEqual((folder / "generation_prompt.txt").read_text(encoding="utf-8").strip(), brief["prompt"])
        with self.assertRaises(ValueError):
            workshop.new_brief("new_v1", "merchant", "Different", self.root)

    def test_attach_measures_original_and_requires_authored_calibration(self):
        workshop.new_brief("new_v1", "sanctuary", "Emerald water", self.root)
        path = workshop.attach("new_v1", self.source, self.root)
        attached = workshop.read(path)
        self.assertEqual(attached["source"]["size"], [100, 60])
        self.assertEqual(attached["source"]["sha256"], workshop.digest(self.source))
        self.assertEqual(attached["navigation"]["outline"], [])
        self.assertEqual(attached["world"]["player_height_ratio"], 0.22)
        with self.assertRaisesRegex(ValueError, "Calibration incomplete"):
            workshop.prepare(path, self.root)
        with self.assertRaises(ValueError):
            workshop.attach("new_v1", self.source, self.root)



    def test_canonical_hash_survives_git_line_endings_and_utf8_bom(self):
        original = self.manifest.read_bytes()
        first = workshop.prepare(self.manifest, self.root)
        self.manifest.write_bytes(b"\xef\xbb\xbf" + original.replace(b"\n", b"\r\n"))
        self.assertEqual(first["manifest_sha256"], workshop.manifest_digest(self.manifest))
        self.assertNotEqual(workshop.digest(self.manifest), first["manifest_sha256"])
        self.assertEqual(first, workshop.prepare(self.manifest, self.root))
        self.data["world"]["width"] = 2400
        self.save()
        self.assertNotEqual(first["manifest_sha256"], workshop.manifest_digest(self.manifest))

    def test_dry_forge_without_optional_materials_produces_empty_channels(self):
        for key in ["water", "cascades", "torches", "foliage", "bounce", "review"]:
            self.data.pop(key, None)
        self.data["kind"] = "forge"
        self.save()
        first = workshop.prepare(self.manifest, self.root)
        self.assertEqual(first["manifest_hash_mode"], "lf_utf8_v1")
        with Image.open(self.root / "built/materials.png") as image:
            self.assertIsNone(image.getbbox())
            self.assertEqual(image.getpixel((50, 30)), (0, 0, 0, 0))
        with Image.open(self.root / "built/flow.png") as image:
            self.assertEqual(image.getpixel((50, 30))[3], 0)

    def test_per_region_flow_keeps_direction_speed_and_water_exclusions(self):
        polygon = self.data["water"]["polygons"].pop()
        self.data["water"]["regions"] = [{"polygon": polygon, "direction": [-1, 0], "speed": 2}]
        self.data["water"]["exclusions"] = [[[0.3, 0.3], [0.7, 0.3], [0.7, 0.7], [0.3, 0.7]]]
        self.save()
        workshop.prepare(self.manifest, self.root)
        with Image.open(self.root / "built/flow.png") as image:
            self.assertEqual(image.getpixel((20, 30)), (0, 128, 128, 255))
            self.assertEqual(image.getpixel((50, 30))[3], 0)
        self.data["water"]["regions"][0]["speed"] = 5
        self.save()
        with self.assertRaisesRegex(ValueError, "Water speed"):
            workshop.prepare(self.manifest, self.root)

    def test_failed_install_restores_previous_build_and_removes_temporary_files(self):
        first = workshop.prepare(self.manifest, self.root)
        files = {p: p.read_bytes() for p in (self.root / "built").iterdir()}
        self.data["water"]["polygons"] = []
        self.save()
        replace = workshop.os.replace
        calls = []

        def fail_second(source, target):
            calls.append(target)
            if len(calls) == 2:
                raise OSError("injected replacement failure")
            replace(source, target)

        with mock.patch.object(workshop.os, "replace", side_effect=fail_second):
            with self.assertRaisesRegex(OSError, "injected"):
                workshop.prepare(self.manifest, self.root)
        self.assertEqual(files, {p: p.read_bytes() for p in (self.root / "built").iterdir()})
        self.assertEqual(first, workshop.read(self.root / "built/build.json"))

    def test_invalid_landmarks_and_geometry_do_not_mutate_build(self):
        workshop.prepare(self.manifest, self.root)
        before = (self.root / "built/build.json").read_bytes()
        self.data["landmarks"].append(dict(self.data["landmarks"][0]))
        self.save()
        with self.assertRaisesRegex(ValueError, "unique"):
            workshop.prepare(self.manifest, self.root)
        self.assertEqual(before, (self.root / "built/build.json").read_bytes())
        self.data["landmarks"].pop()
        self.data["navigation"]["outline"] = [[0, 0], [0.3, 0], [0.3, 0.3], [0, 0.3]]
        self.save()
        with self.assertRaisesRegex(ValueError, "outside navigation"):
            workshop.validate(self.manifest, self.root)

    def test_preparation_refuses_source_as_output(self):
        self.data["source"]["image"] = "res://built/materials.png"
        (self.root / "built").mkdir()
        (self.root / "built/materials.png").write_bytes(self.source.read_bytes())
        self.save()
        with self.assertRaisesRegex(ValueError, "overwrite"):
            workshop.prepare(self.manifest, self.root)
        self.assertEqual(workshop.digest(self.source), workshop.digest(self.root / "built/materials.png"))

    def test_spatial_plan_reference_and_geometry_survive_attach(self):
        folder = workshop.new_brief("planned_forge_v1", "forge", "Dry forge", self.root, plan=self.source)
        request = workshop.read(folder / "request.json")
        self.assertEqual(len(request["references"]), 2)
        plan = workshop.read(folder / "spatial_plan.json")
        plan["world"].update(spawn=[0.1, 0.2], player_height_ratio=0.27, width=2800,
                             speed=210, foot_clearance=18, player_scale=0.65)
        plan["navigation"]["outline"] = self.data["navigation"]["outline"]
        plan["landmarks"] = self.data["landmarks"]
        workshop.write(folder / "spatial_plan.json", plan)
        attached = workshop.read(workshop.attach("planned_forge_v1", self.source, self.root))
        self.assertEqual(attached["world"], plan["world"])
        self.assertEqual(attached["navigation"], plan["navigation"])
        self.assertEqual(attached["source"]["references"], request["references"])
        self.assertEqual(attached["stage"], "calibration")



    def test_landmark_behavior_fields_reject_unhandled_actions_and_bad_ranges(self):
        self.data["landmarks"][0].update(action="merchant", description="Forge", focus=[0.5, 0.4], radius=0.04)
        self.save()
        self.assertEqual(workshop.validate(self.manifest, self.root)["landmarks"][0]["action"], "merchant")
        for field, value in [("action", "unhandled"), ("description", 42), ("focus", [4, 5]), ("radius", -1)]:
            original = self.data["landmarks"][0][field]
            self.data["landmarks"][0][field] = value
            self.save()
            with self.subTest(field=field), self.assertRaises(ValueError):
                workshop.validate(self.manifest, self.root)
            self.data["landmarks"][0][field] = original


    def test_ratio_contract_accepts_boundaries_without_legacy_scale(self):
        self.data["world"].pop("player_scale")
        for ratio in [0.06, 0.22, 0.35]:
            self.data["world"]["player_height_ratio"] = ratio
            self.save()
            with self.subTest(ratio=ratio):
                self.assertEqual(workshop.validate(self.manifest, self.root)["world"]["player_height_ratio"], ratio)
        self.data["world"]["player_scale"] = "unused legacy fallback"
        self.save()
        self.assertEqual(workshop.validate(self.manifest, self.root)["world"]["player_height_ratio"], 0.35)

    def test_invalid_ratio_is_rejected_before_build_even_with_valid_legacy_scale(self):
        for ratio in [0.059, 0.351, -1, 0, True, "0.22", None, [], float("nan"), float("inf"), -float("inf")]:
            self.data["world"]["player_height_ratio"] = ratio
            self.manifest.write_text(json.dumps(self.data), encoding="utf-8")
            with self.subTest(ratio=ratio), self.assertRaisesRegex(ValueError, "Player height ratio"):
                workshop.prepare(self.manifest, self.root)
            self.assertFalse((self.root / "built").exists())

    def test_absent_ratio_retains_legacy_scale_validation(self):
        self.assertEqual(workshop.validate(self.manifest, self.root)["world"]["player_scale"], 0.5)
        for scale in [None, 0.1, 1.01, True]:
            self.data["world"]["player_scale"] = scale
            self.save()
            with self.subTest(scale=scale), self.assertRaisesRegex(ValueError, "Player scale"):
                workshop.validate(self.manifest, self.root)
        self.data["world"].pop("player_scale")
        self.save()
        with self.assertRaisesRegex(ValueError, "Player scale"):
            workshop.validate(self.manifest, self.root)

    def test_attach_rejects_invalid_plan_ratio_without_installing_original(self):
        for index, ratio in enumerate([0.01, 0.36, True, "0.22", None, float("nan"), float("inf")]):
            identifier = f"bad_scale_{index}"
            folder = workshop.new_brief(identifier, "forge", "Dry forge", self.root)
            plan = workshop.read(folder / "spatial_plan.json")
            plan["world"]["player_height_ratio"] = ratio
            (folder / "spatial_plan.json").write_text(json.dumps(plan), encoding="utf-8")
            with self.subTest(ratio=ratio), self.assertRaisesRegex(ValueError, "Player height ratio"):
                workshop.attach(identifier, self.source, self.root)
            self.assertFalse((self.root / "data/halts" / f"{identifier}.json").exists())
            self.assertFalse((self.root / "asset/map/painted/halts" / identifier).exists())

    def test_attach_older_plan_adds_ratio_default_and_keeps_world_fields(self):
        folder = workshop.new_brief("old_plan_v1", "forge", "Dry forge", self.root)
        plan = workshop.read(folder / "spatial_plan.json")
        plan["world"] = {"spawn": [0.2, 0.3], "width": 2600, "player_scale": 0.7}
        workshop.write(folder / "spatial_plan.json", plan)
        attached = workshop.read(workshop.attach("old_plan_v1", self.source, self.root))
        self.assertEqual(attached["world"]["player_height_ratio"], 0.22)
        for field, value in plan["world"].items():
            self.assertEqual(attached["world"][field], value)

    def test_shared_style_generation_includes_human_scale_grid_and_review_gate(self):
        style = workshop.read(workshop.ROOT / "data/halts/styles/roots_bronze_v1.json")
        workshop.write(self.style, style)
        folder = workshop.new_brief("scale_grid_v1", "forge", "Dry forge", self.root)
        request = workshop.read(folder / "request.json")
        for fragment in ["0.15-0.25B", "0.45-0.55B", "1.3-1.6B", "B=202/257 H", "three hero body widths", "world.player_height_ratio=0.22"]:
            self.assertIn(fragment, request["prompt"])
        self.assertIn("Proportions require visual review", request["next"])
        self.assertEqual(style["proportions"]["default_player_height_ratio"], workshop.DEFAULT_PLAYER_HEIGHT_RATIO)


    def test_optional_water_effects_preserve_defaults_and_accept_boundaries(self):
        self.assertEqual(workshop.validate(self.manifest, self.root), self.data)
        for strength in [0, 1.0, 4]:
            self.data["water"].update(caustic_strength=strength, distortion_strength=strength)
            self.save()
            with self.subTest(strength=strength):
                self.assertEqual(workshop.validate(self.manifest, self.root), self.data)
        for bounds in [[0, 0], [0.5, 0.5], [1, 1], [0, 1], [0.2, 0.7]]:
            self.data["water"]["far_fade"] = bounds
            self.save()
            with self.subTest(bounds=bounds):
                self.assertEqual(workshop.validate(self.manifest, self.root), self.data)

    def test_water_strengths_reject_nonfinite_nonnumeric_and_out_of_range_before_build(self):
        for field in ["caustic_strength", "distortion_strength"]:
            for value in [-0.01, 4.01, float("nan"), float("inf"), -float("inf"), "1", True, None, [], {}]:
                self.data["water"][field] = value
                self.manifest.write_text(json.dumps(self.data), encoding="utf-8")
                with self.subTest(field=field, value=value), self.assertRaisesRegex(ValueError, f"water.{field}"):
                    workshop.prepare(self.manifest, self.root)
                self.assertFalse((self.root / "built").exists())
            self.data["water"].pop(field)

    def test_water_far_fade_requires_two_finite_normalized_ordered_bounds_before_build(self):
        for value in [[], [0], [0, 0.5, 1], [0.8, 0.2], [-0.1, 0.5], [0.5, 1.1],
                      [float("nan"), 1], [0, float("inf")], [-float("inf"), 1],
                      [True, 1], [0, "1"], "0,1", None, {}]:
            self.data["water"]["far_fade"] = value
            self.manifest.write_text(json.dumps(self.data), encoding="utf-8")
            with self.subTest(value=value), self.assertRaisesRegex(ValueError, "water.far_fade"):
                workshop.prepare(self.manifest, self.root)
            self.assertFalse((self.root / "built").exists())


    def test_optional_foliage_motion_accepts_defaults_and_closed_boundaries(self):
        self.assertEqual(workshop.validate(self.manifest, self.root), self.data)
        for settings in [{}, {"strength": 0}, {"speed": 4}, {"strength": 4.0, "speed": 0.0},
                         {"strength": 1.5, "speed": 0.75}]:
            self.data["foliage_motion"] = settings
            self.save()
            with self.subTest(settings=settings):
                self.assertEqual(workshop.validate(self.manifest, self.root), self.data)

    def test_foliage_motion_rejects_invalid_objects_and_fields_before_build(self):
        for value in [None, [], "wind", 1, True]:
            self.data["foliage_motion"] = value
            self.save()
            with self.subTest(value=value), self.assertRaisesRegex(ValueError, "foliage_motion"):
                workshop.prepare(self.manifest, self.root)
            self.assertFalse((self.root / "built").exists())
        for field in ["strength", "speed"]:
            for value in [-0.01, 4.01, float("nan"), float("inf"), -float("inf"), "1", True, None, [], {}]:
                self.data["foliage_motion"] = {field: value}
                self.manifest.write_text(json.dumps(self.data), encoding="utf-8")
                with self.subTest(field=field, value=value), self.assertRaisesRegex(ValueError, f"foliage_motion.{field}"):
                    workshop.prepare(self.manifest, self.root)
                self.assertFalse((self.root / "built").exists())

    def test_enclosed_lantern_flag_accepts_only_booleans_and_remains_optional(self):
        self.data["torches"] = [{"point": [0.5, 0.5], "radius": [0.01, 0.02]}]
        self.save()
        self.assertEqual(workshop.validate(self.manifest, self.root), self.data)
        self.assertNotIn("enclosed", self.data["torches"][0])
        for value in [True, False]:
            self.data["torches"][0]["enclosed"] = value
            self.save()
            self.assertEqual(workshop.validate(self.manifest, self.root), self.data)
        for value in [0, 1, 0.0, "true", "false", None, [], {}, float("nan")]:
            self.data["torches"][0]["enclosed"] = value
            self.manifest.write_text(json.dumps(self.data), encoding="utf-8")
            with self.subTest(value=value), self.assertRaisesRegex(ValueError, "torches.enclosed"):
                workshop.prepare(self.manifest, self.root)
            self.assertFalse((self.root / "built").exists())


if __name__ == "__main__":
    unittest.main()
