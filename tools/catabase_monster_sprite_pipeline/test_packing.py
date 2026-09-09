"""Pixel-preservation and public-resource contracts for compact 48-pose atlases."""
from pathlib import Path
import json
import shutil
import unittest
import uuid
from unittest.mock import patch

from PIL import Image, ImageDraw
import build


class PackedPoseTests(unittest.TestCase):
    def setUp(self):
        self.temp_root = (build.ROOT / "artifacts/catabase_monsters/packing_test_temp").resolve()
        self.temp_root.mkdir(parents=True, exist_ok=True)
        # Normal inherited Windows ACLs also work in restricted sandbox tokens;
        # tempfile's owner-only ACL does not.
        self.root = self.temp_root / ("fixture_" + uuid.uuid4().hex)
        self.root.mkdir()
        self.addCleanup(self.cleanup_fixture)
        self.frames = []
        for index in range(48):
            frame = Image.new("RGBA", build.CANVAS)
            draw = ImageDraw.Draw(frame)
            x, y = 180 + index % 8, 150 + index % 5
            draw.rectangle((x, y, x + 75 + index % 7, y + 119), fill=(80 + index, 140, 70, 255))
            draw.point((x - 2, y - 2), fill=(27, 50, 99, 0))  # Invisible RGB is preserved too.
            self.frames.append(frame)
        self.preview_patch = patch.object(build, "_write_previews")
        self.preview_patch.start()
        self.addCleanup(self.preview_patch.stop)

    def cleanup_fixture(self):
        # Verify the exact generated directory before recursive temporary cleanup.
        self.assertTrue(self.root.resolve().is_relative_to(self.temp_root))
        shutil.rmtree(self.root)

    def pack(self, direction="E"):
        return build.pack_frames("rejeton_braise", direction, self.frames,
                                 {"fixture": "synthetic moving silhouette"}, self.root)

    def test_all_48_frames_survive_trimming_png_and_logical_restoration_exactly(self):
        manifest = self.pack()
        atlas = Image.open(build._family("rejeton_braise", self.root) / "atlas_E.png").convert("RGBA")
        self.assertLess(manifest["rgba_bytes"], manifest["untrimmed_rgba_bytes"] * 0.15)
        for original, frame in zip(self.frames, manifest["frames"]):
            self.assertEqual(original.tobytes(), build.restore_frame(atlas, frame).tobytes())
            self.assertEqual(frame["region"][2] + frame["margin"][2], 512)
            self.assertEqual(frame["region"][3] + frame["margin"][3], 384)
        self.assertTrue(build.verify_family("rejeton_braise", self.root, True)["directions"])
        with self.assertRaisesRegex(ValueError, "Missing fixed-view directions"):
            build.verify_family("rejeton_braise", self.root)

    def test_exports_24_clips_with_release_four_and_exact_separate_portrait(self):
        for direction in build.DIRECTIONS:
            self.pack(direction)
        portrait_rect = [170, 140, 110, 90]
        manifest = build.write_sprite_frames("rejeton_braise", portrait_rect, self.root)
        directory = build._family("rejeton_braise", self.root)
        resource = (directory / "sprite_frames.tres").read_text(encoding="utf-8")
        self.assertEqual(resource.count('[sub_resource type="AtlasTexture"'), 192)
        self.assertEqual(resource.count('"name": &'), 24)
        self.assertEqual(resource.count("filter_clip = true"), 192)
        self.assertEqual(manifest["release_frames"], {"attack": 4, "cast": 4})
        self.assertEqual([len(v) for v in manifest["actions"].values()], [8, 12, 8, 8, 4, 8])
        portrait = Image.open(directory / "portrait.png").convert("RGBA")
        self.assertEqual(portrait.tobytes(), self.frames[0].crop((170, 140, 280, 230)).tobytes())
        self.assertIn('portrait.png', (directory / "portrait.tres").read_text(encoding="utf-8"))

    def test_source_frame_zero_must_remain_pixel_exact(self):
        source = self.root / "art/source/characters/catabase_monsters/rejeton_braise"
        source.mkdir(parents=True)
        self.frames[0].save(source / "base_frame_E.png")
        self.pack()
        self.frames[0].putpixel((200, 200), (1, 2, 3, 255))
        with self.assertRaisesRegex(ValueError, "frame zero"):
            self.pack()

    def test_manifest_corruption_or_wrong_count_is_rejected(self):
        self.pack()
        path = build._family("rejeton_braise", self.root) / "atlas_E.manifest.json"
        manifest = json.loads(path.read_text(encoding="utf-8"))
        manifest["frames"][0]["margin"][0] += 1
        path.write_text(json.dumps(manifest), encoding="utf-8")
        with self.assertRaisesRegex(ValueError, "margin mismatch"):
            build.verify_family("rejeton_braise", self.root, True)
        with self.assertRaisesRegex(ValueError, "Expected 48"):
            build.pack_frames("rejeton_braise", "E", self.frames[:20], {"fixture": True}, self.root)

    def test_packing_is_deterministic_and_has_nonoverlapping_gutters(self):
        sizes = [(70 + i % 20, 100 + i % 12) for i in range(48)]
        size, layout = build._packed_layout(sizes)
        self.assertEqual((size, layout), build._packed_layout(sizes))
        for index, (x, y, w, h) in layout.items():
            for other, (rx, ry, rw, rh) in layout.items():
                if index == other:
                    continue
                self.assertFalse(x - 2 < rx + rw + 2 and x + w + 2 > rx - 2
                                 and y - 2 < ry + rh + 2 and y + h + 2 > ry - 2)


if __name__ == "__main__":
    unittest.main()
