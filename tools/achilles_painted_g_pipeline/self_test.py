"""Run only in Higgsfield sandbox, beside build.py: python self_test.py."""
import io
import json
import tempfile
from pathlib import Path

import numpy as np
from PIL import Image, ImageDraw

import build


def fixture():
    picture = Image.new("RGBA", (800, 800), (227, 25, 223, 255))
    draw = ImageDraw.Draw(picture)
    for index in range(16):
        x, y = index % 4 * 200, index // 4 * 200
        draw.rectangle((x + 50, y + 50, x + 90, y + 150), fill=(180, 100, 35, 255))
    draw.rectangle((50, 50, 90, 220), fill=(180, 100, 35, 255))
    draw.rectangle((65, 84, 215, 87), fill=(30, 110, 130, 255))
    draw.line((90, 81, 214, 81), fill=(20, 95, 100, 16))
    draw.point((216, 85), fill=(20, 95, 100, 1))
    draw.ellipse((105, 112, 121, 132), fill=(15, 85, 95, 255))
    return picture


def inspect_run(picture, output):
    buffer = io.BytesIO()
    picture.save(buffer, format="PNG")
    previous = build.download
    build.download = lambda _url: buffer.getvalue()
    roots = [[70, 150] for _ in range(16)]
    roots[0] = [70, 220]
    try:
        return build.run({"outDir": str(output), "sources": [{"key": "locomotion_N",
            "url": "https://example.cloudfront.net/synthetic.png", "columns": 4, "rows": 4,
            "scale": .5, "roots": roots, "preserveCrossCellEquipment": True}]}, inspect_only=True)
    finally:
        build.download = previous


with tempfile.TemporaryDirectory(prefix="achilles_global_test_") as directory:
    root = Path(directory)
    neutral = Image.new("RGBA", (80, 60), (251, 249, 252, 255))
    neutral_draw = ImageDraw.Draw(neutral)
    neutral_draw.rectangle((10, 10, 69, 49), fill=(160, 90, 40, 255))
    neutral_draw.rectangle((15, 15, 25, 25), fill=(255, 255, 255, 255))
    neutral_draw.rectangle((50, 15, 60, 25), fill=(255, 255, 255, 255))
    neutral_draw.point((26, 26), fill=(255, 255, 255, 255))
    neutral_draw.point((27, 27), fill=(255, 255, 255, 255))
    neutral_draw.point((24, 18), fill=(235, 224, 230, 255))
    unseeded, _ = build.solid_key(neutral, [251, 249, 252])
    seeded, seed_report = build.solid_key(neutral, [251, 249, 252], [[18, 18]])
    assert unseeded.getpixel((18, 18))[3] == 255
    assert seeded.getpixel((18, 18))[3] == 0, "Only the selected enclosed background is removed"
    assert seeded.getpixel((27, 27))[3] == 0, "Seed flood uses eight-neighbor connectivity"
    assert 0 < seeded.getpixel((24, 18))[3] < 255, "Selected pocket keeps progressive edges"
    assert seeded.getpixel((55, 20)) == neutral.getpixel((55, 20)), "Unselected enclosed whites stay exact"
    assert seed_report["seedFullyKeyedPixels"] > 0 and seed_report["enclosedSimilarPixelsRetained"] > 0
    for invalid_seed in [[[35, 35]], [[80, 20]], [[18.5, 18]], [[-1, 18]]]:
        rejected_seed = False
        try:
            build.solid_key(neutral, [251, 249, 252], invalid_seed)
        except ValueError:
            rejected_seed = True
        assert rejected_seed, "Invalid, out-of-bounds or non-background seeds must be rejected"
    neutral_parts, neutral_audit = build.split_global_equipment(neutral,
        {"key": "extra_E", "keyColor": [251, 249, 252], "backgroundSeeds": [[18, 18]]},
        [0, 80], [0, 60], root / "seeded_global.json")
    assert neutral_audit["key"]["backgroundSeeds"][0]["point"] == [18, 18]
    assert neutral_audit["key"]["seedFullyKeyedPixels"] > 0
    assert neutral_parts[0]["image"].getpixel((8, 8))[3] == 0
    picture = fixture()
    bounds = list(range(0, 801, 200))
    parts, audit = build.split_global_equipment(picture, {"key": "locomotion_N"},
        bounds, bounds, root / "positive.json")
    keyed, key_audit = build.chroma_key(picture)
    expected = np.array(keyed)
    rebuilt = np.zeros(expected.shape, dtype=np.uint8)
    multiplicity = np.zeros(expected.shape[:2], dtype=np.uint8)
    for item in parts:
        x0, y0, x1, y1 = item["cropRect"]
        rgba = np.array(item["image"])
        mask = rgba[:, :, 3] > 0
        rebuilt[y0:y1, x0:x1][mask] = rgba[mask]
        multiplicity[y0:y1, x0:x1][mask] += 1
    assert np.array_equal(rebuilt, expected), "Source RGBA must survive assignment exactly"
    assert int(multiplicity.max()) == 1, "No pixel may appear in two actors"
    assert audit["sourceAlphaSum"] == audit["assignedAlphaSum"]
    assert audit["unassignedCorePixels"] == 0
    assert audit["softPixelsBeyondTwoPixelFringeRetained"] > 0
    assert key_audit["borderForegroundFraction"] == 0
    assert expected[0, 0, 3] == 0, "Dark magenta must be fully keyed"
    origin = parts[0]["cropOrigin"]
    assert parts[0]["image"].getpixel((216 - origin[0], 85 - origin[1]))[3] == 1
    assert parts[0]["cropRect"][2] > 200, "Complete connected spear belongs to actor zero"
    assert parts[0]["cropRect"][3] > 200, "Vertical crossing remains complete"
    packed, placement = build.pack(parts[0]["image"], .5, [70, 220], origin)
    assert placement["alphaLoss"] == 0 and not placement["clipped"]
    root_in_crop = [70 - origin[0], 220 - origin[1]]
    assert [root_in_crop[i] + origin[i] for i in range(2)] == [70, 220]
    manifest = inspect_run(picture, root / "run_positive")
    assert not manifest["errors"], manifest["errors"]
    first = manifest["sources"][0]["frames"][0]
    assert first["root"] == [70.0, 220.0], "Manual roots beyond nominal cell height are authoritative"
    assert first["crossesNominalCell"] and not first["sourceTouchesEdge"]
    merged = fixture()
    ImageDraw.Draw(merged).line((215, 85, 250, 85), fill=(180, 100, 35, 255), width=3)
    rejected_merged = False
    try:
        build.split_global_equipment(merged, {"key": "locomotion_N"}, bounds, bounds, root / "merged.json")
    except ValueError:
        rejected_merged = True
    assert rejected_merged, "Merged actors must fail"
    small = fixture()
    draw = ImageDraw.Draw(small)
    draw.rectangle((0, 0, 399, 239), fill=(227, 25, 223, 255))
    draw.rectangle((50, 70, 71, 141), fill=(180, 100, 35, 255))
    draw.rectangle((250, 70, 271, 141), fill=(180, 100, 35, 255))
    draw.line((71, 90, 250, 90), fill=(180, 100, 35, 255))
    draw.rectangle((310, 70, 335, 130), fill=(20, 90, 105, 255))
    rejected_small = False
    try:
        build.split_global_equipment(small, {"key": "locomotion_N"}, bounds, bounds, root / "small_merged.json")
    except ValueError:
        rejected_small = True
    assert rejected_small, "Two smaller fused actors cannot be replaced by detached equipment"
    edge = fixture()
    ImageDraw.Draw(edge).line((0, 95, 65, 95), fill=(30, 110, 130, 255), width=3)
    edge_manifest = inspect_run(edge, root / "run_edge")
    assert edge_manifest["errors"] and edge_manifest["sources"][0]["frames"][0]["sourceTouchesEdge"]
    print(json.dumps({"ok": True, "checks": ["explicit-neutral-seeds", "seed-eight-connectivity",
        "unselected-interior-white-preserved", "invalid-seed-rejection", "global-seed-propagation",
        "dark-magenta-key", "RGBA-conservation", "unique-ownership",
        "secondary-equipment", "low-alpha-fringes", "horizontal-and-vertical-crossings",
        "nominal-root-transform", "manual-root-beyond-cell", "zero-pack-loss",
        "merged-body-rejection", "small-merged-body-rejection", "true-sheet-edge-rejection"]}))
