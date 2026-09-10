"""Prepare authored halt manifests; never edits the generated painting or calls APIs."""
from __future__ import annotations

import argparse
import hashlib
import json
import math
import re
import shutil
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]


def project_path(value: str, root: Path = ROOT) -> Path:
    relative = value.removeprefix("res://")
    path = (root / relative).resolve()
    if not path.is_relative_to(root.resolve()):
        raise ValueError(f"Path outside project: {value}")
    return path


def digest(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest()


def read(path: Path) -> dict:
    return json.loads(path.read_text(encoding="utf-8-sig"))


def write(path: Path, value: dict) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(json.dumps(value, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")


def cross(a, b, c):
    return (b[0] - a[0]) * (c[1] - a[1]) - (b[1] - a[1]) * (c[0] - a[0])


def validate_polygon(points, name):
    if len(points) < 3:
        raise ValueError(f"{name}: at least three points required")
    for point in points:
        if len(point) != 2 or not all(math.isfinite(v) and 0 <= v <= 1 for v in point):
            raise ValueError(f"{name}: coordinates must be finite normalized pairs")
    area = sum(a[0] * b[1] - b[0] * a[1] for a, b in zip(points, points[1:] + points[:1]))
    if abs(area) < 1e-8:
        raise ValueError(f"{name}: degenerate polygon")
    for i in range(len(points)):
        a, b = points[i], points[(i + 1) % len(points)]
        if a == b:
            raise ValueError(f"{name}: duplicate adjacent point")
        for j in range(i + 2, len(points)):
            if i == 0 and j == len(points) - 1:
                continue
            c, d = points[j], points[(j + 1) % len(points)]
            if cross(a, b, c) * cross(a, b, d) < 0 and cross(c, d, a) * cross(c, d, b) < 0:
                raise ValueError(f"{name}: self intersection")


def polygons(manifest):
    yield "navigation", manifest["navigation"]["outline"]
    for key in ["obstacles"]:
        for i, p in enumerate(manifest["navigation"].get(key, [])):
            yield f"{key}/{i}", p
    for key in ["polygons", "exclusions"]:
        for i, p in enumerate(manifest["water"].get(key, [])):
            yield f"water/{key}/{i}", p
    for key in ["foliage", "bounce"]:
        for i, p in enumerate(manifest.get(key, [])):
            yield f"{key}/{i}", p
    for i, cascade in enumerate(manifest.get("cascades", [])):
        yield f"cascade/{i}", cascade["polygon"]
    for i, foreground in enumerate(manifest.get("foreground", [])):
        yield f"foreground/{i}", foreground["polygon"]


def validate(path: Path, root: Path = ROOT) -> dict:
    from PIL import Image
    m = read(path)
    if m["schema_version"] != 1 or not re.fullmatch(r"[a-z0-9_]+", m["id"]):
        raise ValueError("Unsupported schema or unsafe map identifier")
    if m.get("stage") not in {"playable_study", "reviewed"}:
        raise ValueError("Calibration incomplete: author navigation/materials/review anchors, then set stage=playable_study")
    source = project_path(m["source"]["image"], root)
    with Image.open(source) as im:
        if list(im.size) != m["source"]["size"]:
            raise ValueError("Source size changed: recalibrate this map version")
    if digest(source) != m["source"].get("sha256"):
        raise ValueError("Source hash changed: review and version the painting before recalibration")
    project_path(m["build_dir"], root)
    if not project_path(m["style"], root).is_file():
        raise ValueError("Missing shared style reference")
    if not 1000 <= m["world"]["width"] <= 6000 or not 0.2 <= m["world"]["player_scale"] <= 1:
        raise ValueError("Invalid world/actor scale")
    for name, points in polygons(m):
        validate_polygon(points, name)
    if not m["landmarks"] or len(m.get("torches", [])) > 12:
        raise ValueError("Need landmarks and at most twelve independently animated torches")
    for data in [m["world"]["spawn"]] + [p["point"] for p in m["landmarks"]] + [p["point"] for p in m.get("torches", [])]:
        if len(data) != 2 or not all(math.isfinite(v) and 0 <= v <= 1 for v in data):
            raise ValueError("Invalid normalized anchor")
    return m


def prepare(path: Path, root: Path = ROOT) -> dict:
    from PIL import Image, ImageDraw, ImageFilter
    m = validate(path, root)
    size = tuple(m["source"]["size"])
    output = project_path(m["build_dir"], root)
    output.mkdir(parents=True, exist_ok=True)
    layers = []
    specs = [m["water"]["polygons"], [c["polygon"] for c in m.get("cascades", [])], m.get("foliage", []), m.get("bounce", [])]
    for index, shapes in enumerate(specs):
        layer = Image.new("L", size, 0)
        drawing = ImageDraw.Draw(layer)
        for polygon in shapes:
            drawing.polygon([(round(x * size[0]), round(y * size[1])) for x, y in polygon], fill=255)
        if index == 0:
            for polygon in m["water"].get("exclusions", []):
                drawing.polygon([(round(x * size[0]), round(y * size[1])) for x, y in polygon], fill=0)
        layers.append(layer.filter(ImageFilter.GaussianBlur(1.0 if index < 2 else 5.0)))
    # Data texture only: R=surface water, G=falling water, B=foliage, A=stone reflections.
    mask = output / "materials.png"
    Image.merge("RGBA", layers).save(mask)
    # This is a packed data texture: alpha is a fourth material channel. Godot's
    # ordinary transparent-border repair would corrupt RGB where alpha is zero.
    import_path = mask.with_suffix(".png.import")
    if import_path.exists():
        settings = import_path.read_text(encoding="utf-8")
        settings = settings.replace("process/fix_alpha_border=true", "process/fix_alpha_border=false")
    else:
        uri = m["build_dir"] + "/materials.png"
        cache = "res://.godot/imported/materials.png-" + hashlib.md5(uri.encode()).hexdigest() + ".ctex"
        settings = ('[remap]\nimporter="texture"\ntype="CompressedTexture2D"\npath="' + cache + '"\n\n'
                    '[deps]\nsource_file="' + uri + '"\ndest_files=["' + cache + '"]\n\n'
                    '[params]\ncompress/mode=0\ncompress/channel_pack=0\nmipmaps/generate=false\n'
                    'process/fix_alpha_border=false\nprocess/premult_alpha=false\n')
    import_path.write_text(settings, encoding="utf-8")
    report = {"schema_version": 1, "id": m["id"], "manifest_sha256": digest(path),
              "source_sha256": m["source"]["sha256"], "mask_sha256": digest(mask),
              "size": list(size), "channels": ["water", "cascades", "foliage", "stone_reflections"],
              "art_review": "candidate", "navigation_runtime_tested": False}
    write(output / "build.json", report)
    return report


def new_brief(identifier: str, kind: str, brief: str, root: Path = ROOT) -> Path:
    if not re.fullmatch(r"[a-z0-9_]+", identifier):
        raise ValueError("Use a lowercase map id with underscores")
    style_path = root / "data/halts/styles/roots_bronze_v1.json"
    style = read(style_path)
    folder = root / "art/source/halts" / identifier
    if folder.exists():
        raise ValueError("Map already exists: choose a new version id")
    folder.mkdir(parents=True)
    request = {"id": identifier, "kind": kind, "stage": "brief", "style": "roots_bronze_v1",
               "references": style["reference_images"], "brief": brief,
               "prompt": style["prompt_prefix"] + "\nNEW LOCATION: " + brief,
               "next": "Generate with the reference attached, save original, measure dimensions/hash, author normalized manifest, prepare, verify and review."}
    write(folder / "request.json", request)
    (folder / "generation_prompt.txt").write_text(request["prompt"] + "\n", encoding="utf-8")
    return folder


def attach(identifier: str, image: Path, root: Path = ROOT) -> Path:
    """Register a new original without borrowing another painting's geometry."""
    from PIL import Image
    if not re.fullmatch(r"[a-z0-9_]+", identifier):
        raise ValueError("Unsafe map identifier")
    request = read(root / "art/source/halts" / identifier / "request.json")
    manifest = root / "data/halts" / (identifier + ".json")
    folder = root / "asset/map/painted/halts" / identifier
    if manifest.exists() or folder.exists():
        raise ValueError("Version already has an image: choose a new id")
    with Image.open(image) as source:
        size = list(source.size)
        extension = {"PNG": ".png", "JPEG": ".jpg", "WEBP": ".webp"}.get(source.format)
        if extension is None:
            raise ValueError("Use a PNG, JPEG or WebP original")
        source.verify()
    folder.mkdir(parents=True)
    target = folder / ("source" + extension)
    shutil.copyfile(image, target)
    uri = "res://" + target.relative_to(root).as_posix()
    write(manifest, {
        "schema_version": 1, "id": identifier, "title": identifier.replace("_", " "),
        "kind": request["kind"], "stage": "calibration",
        "style": "res://data/halts/styles/roots_bronze_v1.json",
        "source": {"image": uri, "size": size, "sha256": digest(target),
                   "prompt": f"res://art/source/halts/{identifier}/generation_prompt.txt",
                   "references": request["references"], "provider": "record_provider_here"},
        "build_dir": "res://" + folder.relative_to(root).as_posix(),
        "world": {"width": 2200, "player_scale": 0.52, "speed": 195,
                  "foot_clearance": 12, "spawn": []},
        "navigation": {"outline": [], "obstacles": []}, "landmarks": [],
        "water": {"tint": "#48d896", "polygons": [], "exclusions": []},
        "cascades": [], "torches": [], "foliage": [], "bounce": [], "mist": [], "foreground": [],
        "review": {"forbidden_points": [], "stable_pixel": [], "water_pixel": [],
                   "fire_pixel": [], "waterfall_pixel": []}
    })
    return manifest


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    sub = parser.add_subparsers(dest="command", required=True)
    for name in ["check", "prepare"]:
        p = sub.add_parser(name)
        p.add_argument("manifest")
    p = sub.add_parser("new")
    p.add_argument("id")
    p.add_argument("--kind", default="sanctuary", choices=["sanctuary", "merchant", "hub", "lore"])
    p.add_argument("--brief", required=True)
    p = sub.add_parser("attach")
    p.add_argument("id")
    p.add_argument("image")
    args = parser.parse_args()
    try:
        if args.command == "new":
            print(new_brief(args.id, args.kind, args.brief))
        elif args.command == "attach":
            print(attach(args.id, Path(args.image)))
        else:
            path = project_path(args.manifest)
            value = prepare(path) if args.command == "prepare" else validate(path)
            print(json.dumps({"passed": True, "id": value["id"], "command": args.command}))
    except (ValueError, KeyError, OSError) as error:
        parser.exit(1, str(error) + "\n")


if __name__ == "__main__":
    main()
