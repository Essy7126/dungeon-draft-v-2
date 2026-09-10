"""Prepare authored halt manifests; never edits paintings or calls generation APIs."""
from __future__ import annotations

import argparse
import hashlib
import io
import json
import math
import os
import re
import shutil
import uuid
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
HASH_MODE = "lf_utf8_v1"
DEFAULT_PLAYER_HEIGHT_RATIO = 0.22
KINDS = ["sanctuary", "merchant", "hub", "lore", "forge"]


def project_path(value: str, root: Path = ROOT) -> Path:
    path = (root / value.removeprefix("res://")).resolve()
    if not path.is_relative_to(root.resolve()):
        raise ValueError(f"Path outside project: {value}")
    if any(part in {".git", ".godot", ".codex", ".agents"} for part in path.relative_to(root.resolve()).parts):
        raise ValueError(f"Protected project path: {value}")
    return path


def digest(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest()


def text_digest(text: str) -> str:
    """LF-normalized UTF-8 content; binary art continues to use digest()."""
    normalized = text.removeprefix("\ufeff").replace("\r\n", "\n").replace("\r", "\n")
    return hashlib.sha256(normalized.encode("utf-8")).hexdigest()


def manifest_digest(path: Path) -> str:
    return text_digest(path.read_bytes().decode("utf-8-sig"))


def read(path: Path) -> dict:
    return json.loads(path.read_text(encoding="utf-8-sig"))


def json_bytes(value: dict) -> bytes:
    return (json.dumps(value, ensure_ascii=False, indent=2, allow_nan=False) + "\n").encode("utf-8")


def write(path: Path, value: dict) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_bytes(json_bytes(value))


def install_files(files: dict[Path, bytes]) -> None:
    """Stage and verify all files, then replace with durable rollback copies.

    Callers put build.json last so no partial installation passes runtime hashes.
    If rollback fails its .previous copies remain available for recovery.
    """
    stages, previous, installed = {}, {}, []
    suffix = ".halt-" + uuid.uuid4().hex
    cleanup_backups = True
    try:
        for path, data in files.items():
            path.parent.mkdir(parents=True, exist_ok=True)
            temporary = path.with_name(path.name + suffix + ".tmp")
            stages[path] = temporary
            temporary.write_bytes(data)
            if temporary.read_bytes() != data:
                raise OSError(f"Staged data verification failed: {path}")
            previous[path] = None
            if path.exists():
                backup = path.with_name(path.name + suffix + ".previous")
                previous[path] = backup
                shutil.copyfile(path, backup)
                if digest(path) != digest(backup):
                    raise OSError(f"Backup verification failed: {path}")
        for path, temporary in stages.items():
            os.replace(temporary, path)
            installed.append(path)
    except OSError as error:
        rollback_errors = []
        for path in reversed(installed):
            try:
                if previous[path] is None:
                    path.unlink(missing_ok=True)
                else:
                    os.replace(previous[path], path)
            except OSError as rollback_error:
                rollback_errors.append(str(rollback_error))
        if rollback_errors:
            cleanup_backups = False
            raise OSError("Rollback incomplete; .previous backups retained: " + "; ".join(rollback_errors)) from error
        raise
    finally:
        for temporary in stages.values():
            temporary.unlink(missing_ok=True)
        if cleanup_backups:
            for backup in previous.values():
                if backup is not None:
                    backup.unlink(missing_ok=True)


def finite_pair(point):
    return isinstance(point, list) and len(point) == 2 and all(type(v) in (float, int) and math.isfinite(v) for v in point)


def valid_point(point):
    return finite_pair(point) and all(0 <= v <= 1 for v in point)


def require_range(value, minimum, maximum, name):
    if type(value) not in (int, float) or not math.isfinite(value) or not minimum <= value <= maximum:
        raise ValueError(f"{name}: expected {minimum}..{maximum}")


def cross(a, b, c):
    return (b[0] - a[0]) * (c[1] - a[1]) - (b[1] - a[1]) * (c[0] - a[0])


def validate_polygon(points, name):
    if not isinstance(points, list) or len(points) < 3:
        raise ValueError(f"{name}: at least three points required")
    if not all(valid_point(point) for point in points):
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


def point_inside(at, polygon):
    inside = False
    for a, b in zip(polygon, polygon[1:] + polygon[:1]):
        if (a[1] > at[1]) != (b[1] > at[1]) and at[0] < (b[0] - a[0]) * (at[1] - a[1]) / (b[1] - a[1]) + a[0]:
            inside = not inside
    return inside


def polygons(manifest):
    yield "navigation", manifest["navigation"]["outline"]
    for i, polygon in enumerate(manifest["navigation"].get("obstacles", [])):
        yield f"obstacles/{i}", polygon
    for key in ["polygons", "exclusions"]:
        for i, polygon in enumerate(manifest.get("water", {}).get(key, [])):
            yield f"water/{key}/{i}", polygon
    for i, region in enumerate(manifest.get("water", {}).get("regions", [])):
        yield f"water/regions/{i}", region["polygon"]
    for key in ["foliage", "bounce"]:
        for i, polygon in enumerate(manifest.get(key, [])):
            yield f"{key}/{i}", polygon
    for key in ["cascades", "foreground"]:
        for i, entry in enumerate(manifest.get(key, [])):
            yield f"{key}/{i}", entry["polygon"]


def validate(path: Path, root: Path = ROOT) -> dict:
    from PIL import Image
    m = read(path)
    if not isinstance(m, dict) or m.get("schema_version") != 1 or not re.fullmatch(r"[a-z0-9_]+", m.get("id", "")):
        raise ValueError("Unsupported schema or unsafe map identifier")
    if m.get("kind", "sanctuary") not in KINDS:
        raise ValueError("Unsupported halt kind")
    for key in ["source", "world", "navigation", "water", "review", "ambience"]:
        if not isinstance(m.get(key, {}), dict):
            raise ValueError(f"{key}: object required")
    for key in ["landmarks", "cascades", "torches", "foliage", "bounce", "foreground", "mist"]:
        if not isinstance(m.get(key, []), list):
            raise ValueError(f"{key}: list required")
    if m.get("stage") not in {"playable_study", "reviewed"}:
        raise ValueError("Calibration incomplete: author navigation/materials/review anchors, then set stage=playable_study")
    source = project_path(m["source"]["image"], root)
    with Image.open(source) as im:
        if list(im.size) != m["source"]["size"]:
            raise ValueError("Source size changed: recalibrate this map version")
        if im.width * im.height > 33554432:
            raise ValueError("Source exceeds 32 megapixels")
        im.verify()
    if digest(source) != m["source"].get("sha256"):
        raise ValueError("Source hash changed: review and version the painting before recalibration")
    output = project_path(m["build_dir"], root)
    if source in [output / "materials.png", output / "flow.png", output / "build.json"] or path.resolve() == output / "build.json":
        raise ValueError("Build destination would overwrite source or manifest")
    if not project_path(m["style"], root).is_file():
        raise ValueError("Missing shared style reference")
    require_range(m["world"]["width"], 1000, 6000, "World width")
    if "player_height_ratio" in m["world"]:
        require_range(m["world"]["player_height_ratio"], 0.06, 0.35, "Player height ratio")
    else:
        require_range(m["world"].get("player_scale"), 0.2, 1, "Player scale")
    require_range(m["world"].get("speed", 195), 1, 1000, "Player speed")
    require_range(m["world"].get("foot_clearance", 12), 0, 100, "Foot clearance")
    for name, points in polygons(m):
        validate_polygon(points, name)
    if not m["landmarks"] or len(m.get("torches", [])) > 12:
        raise ValueError("Need landmarks and at most twelve independently animated torches")
    for data in [m["world"]["spawn"]] + [p["point"] for p in m["landmarks"]] + [p["point"] for p in m.get("torches", [])]:
        if not valid_point(data):
            raise ValueError("Invalid normalized anchor")
    identities = set()
    for landmark in m["landmarks"]:
        identifier = landmark.get("id", "")
        if not re.fullmatch(r"[a-z0-9_]+", identifier) or identifier in identities:
            raise ValueError("Landmarks need unique safe ids")
        identities.add(identifier)
        if "action" in landmark and landmark["action"] not in {"sanctuary", "merchant", "dialogue", "rest", "exit"}:
            raise ValueError("Invalid landmark action")
        if "description" in landmark and not isinstance(landmark["description"], str):
            raise ValueError("Landmark description must be text")
        if "focus" in landmark and not valid_point(landmark["focus"]):
            raise ValueError("Landmark focus must be a normalized point")
        if "radius" in landmark:
            require_range(landmark["radius"], 0.001, 0.3, "Interaction radius")
    for at in [m["world"]["spawn"]] + [p["point"] for p in m["landmarks"]]:
        if not point_inside(at, m["navigation"]["outline"]) or any(point_inside(at, p) for p in m["navigation"].get("obstacles", [])):
            raise ValueError("Spawn or destination lies outside navigation")
    for region in m.get("water", {}).get("regions", []):
        direction = region.get("direction", [1, 0])
        if not finite_pair(direction) or math.hypot(*direction) < 0.001:
            raise ValueError("Water direction must be finite and nonzero")
        require_range(region.get("speed", 1), 0, 4, "Water speed")
    for cascade in m.get("cascades", []):
        if not valid_point(cascade.get("splash", [])):
            raise ValueError("Cascade splash needs a normalized point")
        require_range(cascade.get("width", 20), 1, 1000, "Cascade width")
    for torch in m.get("torches", []):
        radius = torch.get("radius", [])
        if not valid_point(radius) or min(radius) <= 0:
            raise ValueError("Torch radius must be normalized and positive")
    for foreground in m.get("foreground", []):
        if not valid_point(foreground.get("anchor", [])):
            raise ValueError("Foreground anchor must be a normalized point")
        if "depth_y" in foreground:
            require_range(foreground["depth_y"], 0, 1, "Foreground depth")
    for mist in m.get("mist", []):
        rect = mist.get("rect", [])
        if not isinstance(rect, list) or len(rect) != 4:
            raise ValueError("Invalid mist rectangle")
        for value in rect:
            require_range(value, 0, 1, "Mist rectangle")
        require_range(mist.get("alpha", 0.1), 0, 1, "Mist alpha")
    for key, at in m.get("review", {}).items():
        if key.endswith("_pixel") and at and not valid_point(at):
            raise ValueError("Invalid review anchor")
    for at in m.get("review", {}).get("forbidden_points", []):
        if not valid_point(at):
            raise ValueError("Invalid forbidden anchor")
    ambience = m.get("ambience", {})
    if not isinstance(ambience.get("sources", []), list):
        raise ValueError("Ambient sources must be a list")
    if ambience.get("footsteps", "stone") != "stone":
        raise ValueError("Unsupported footstep material")
    for emitter in ambience.get("sources", []):
        if not isinstance(emitter, dict) or emitter.get("kind", "fire") not in {"water", "fire"}:
            raise ValueError("Unsupported ambient source")
        if not valid_point(emitter.get("point", [])):
            raise ValueError("Ambient source needs a normalized point")
        require_range(emitter.get("radius", 0.3), 0.001, 1, "Ambient radius")
        require_range(emitter.get("gain_db", -17), -40, -6, "Ambient volume")
    return m


def import_settings(uri: str, existing: Path | None = None) -> str:
    if existing is not None and existing.is_file():
        settings = existing.read_text(encoding="utf-8")
        settings = re.sub(r"process/fix_alpha_border=(true|false)", "process/fix_alpha_border=false", settings)
        settings = re.sub(r"process/premult_alpha=(true|false)", "process/premult_alpha=false", settings)
        if "process/fix_alpha_border=" in settings and "process/premult_alpha=" in settings:
            return settings
    cache = "res://.godot/imported/" + uri.rsplit("/", 1)[-1] + "-" + hashlib.md5(uri.encode()).hexdigest() + ".ctex"
    return ('[remap]\nimporter="texture"\ntype="CompressedTexture2D"\npath="' + cache + '"\n\n'
            '[deps]\nsource_file="' + uri + '"\ndest_files=["' + cache + '"]\n\n'
            '[params]\ncompress/mode=0\ncompress/channel_pack=0\nmipmaps/generate=false\n'
            'process/fix_alpha_border=false\nprocess/premult_alpha=false\n')


def prepare(path: Path, root: Path = ROOT) -> dict:
    from PIL import Image, ImageDraw, ImageFilter
    manifest_hash = manifest_digest(path)
    m = validate(path, root)
    size = tuple(m["source"]["size"])
    output = project_path(m["build_dir"], root)
    water = m.get("water", {})
    water_shapes = water.get("polygons", []) + [r["polygon"] for r in water.get("regions", [])]
    specs = [water_shapes, [c["polygon"] for c in m.get("cascades", [])], m.get("foliage", []), m.get("bounce", [])]
    layers = []
    for index, shapes in enumerate(specs):
        layer = Image.new("L", size, 0)
        drawing = ImageDraw.Draw(layer)
        for polygon in shapes:
            drawing.polygon([(round(x * size[0]), round(y * size[1])) for x, y in polygon], fill=255)
        if index == 0:
            for polygon in water.get("exclusions", []):
                drawing.polygon([(round(x * size[0]), round(y * size[1])) for x, y in polygon], fill=0)
        layers.append(layer.filter(ImageFilter.GaussianBlur(1.0 if index < 2 else 5.0)))
    # R=water G=cascades B=foliage A=stone reflections. Alpha is data.
    buffer = io.BytesIO()
    Image.merge("RGBA", layers).save(buffer, format="PNG")
    mask_bytes = buffer.getvalue()
    flow = Image.new("RGBA", size, (242, 185, 64, 0))
    drawing = ImageDraw.Draw(flow)
    for region in water.get("regions", []):
        direction = region.get("direction", [1, 0])
        length = math.hypot(*direction)
        color = tuple(round((v / length * 0.5 + 0.5) * 255) for v in direction) + (round(region.get("speed", 1) / 4 * 255), 255)
        drawing.polygon([(round(x * size[0]), round(y * size[1])) for x, y in region["polygon"]], fill=color)
    flow.putalpha(layers[0])
    buffer = io.BytesIO()
    flow.save(buffer, format="PNG")
    flow_bytes = buffer.getvalue()
    report = {"schema_version": 1, "id": m["id"], "manifest_sha256": manifest_hash,
              "manifest_hash_mode": HASH_MODE, "generator": "python_pillow_v2",
              "source_sha256": m["source"]["sha256"], "mask_sha256": hashlib.sha256(mask_bytes).hexdigest(),
              "flow_sha256": hashlib.sha256(flow_bytes).hexdigest(), "size": list(size),
              "channels": ["water", "cascades", "foliage", "stone_reflections"],
              "flow_channels": ["direction_x", "direction_y", "speed_div_4", "water_coverage"],
              "art_review": "candidate", "navigation_runtime_tested": False}
    if manifest_digest(path) != manifest_hash or digest(project_path(m["source"]["image"], root)) != m["source"]["sha256"]:
        raise ValueError("Manifest or source changed during preparation")
    files = {output / "materials.png": mask_bytes,
             output / "materials.png.import": import_settings(m["build_dir"] + "/materials.png", output / "materials.png.import").encode("utf-8"),
             output / "flow.png": flow_bytes,
             output / "flow.png.import": import_settings(m["build_dir"] + "/flow.png", output / "flow.png.import").encode("utf-8"),
             output / "build.json": json_bytes(report)}
    install_files(files)
    return report


def new_brief(identifier: str, kind: str, brief: str, root: Path = ROOT, plan: Path | None = None) -> Path:
    if not re.fullmatch(r"[a-z0-9_]+", identifier):
        raise ValueError("Use a lowercase map id with underscores")
    if kind not in KINDS:
        raise ValueError("Unsupported halt kind")
    style = read(root / "data/halts/styles/roots_bronze_v1.json")
    folder = root / "art/source/halts" / identifier
    if folder.exists():
        raise ValueError("Map already exists: choose a new version id")
    if plan is not None and not plan.is_file():
        raise ValueError("Spatial plan reference does not exist")
    folder.mkdir(parents=True)
    spatial_plan = {"schema_version": 1, "stage": "planning", "id": identifier,
                    "world": {"player_height_ratio": DEFAULT_PLAYER_HEIGHT_RATIO, "spawn": []},
                    "navigation": {"outline": [], "obstacles": []}, "landmarks": [],
                    "instructions": "Draw normalized entrance, exits, circulation loop, obstacles and interactions before generation. Place equal-height Achilles idle_S references beside the entrance, work surface and exit, with feet on the same adjacent floor. H is feet to silhouette top, including spear and plume; H/image_height is world.player_height_ratio. Furniture ratios use body B excluding spear and plume, as measured in the shared style reference. Export or attach the plan as a second reference; omit reference characters from the final painting."}
    write(folder / "spatial_plan.json", spatial_plan)
    plan_reference = ""
    if plan is not None:
        target = folder / ("spatial_plan_reference" + plan.suffix.lower())
        shutil.copyfile(plan, target)
        plan_reference = "res://" + target.relative_to(root).as_posix()
    height_ratio = spatial_plan["world"]["player_height_ratio"]
    scale_prompt = (
        f"\nHERO SCALE CONTRACT: world.player_height_ratio={height_ratio:g}. "
        f"The standing Achilles idle_S reference measures {height_ratio * 100:g}% of the full image height "
        "from the ground contact at the feet to the top of the visible silhouette, including spear and helmet plume. "
        "Use the same projected height throughout this fixed three-quarter view. "
        "The furniture grid uses BODY height B from the shared style reference, excluding spear and plume; do not treat full silhouette H as the body. "
        "Compare props with a hero standing on the same adjacent floor elevation, using each object's base and top; "
        "exclude handles, weapon extensions, flames and shadows from prop-body measurements. "
        "The plan's reference silhouettes establish scale only: remove them from the final painting."
    )
    request = {"id": identifier, "kind": kind, "stage": "brief", "style": "roots_bronze_v1",
               "references": list(style["reference_images"]) + ([plan_reference] if plan_reference else []), "brief": brief,
               "spatial_plan": f"res://art/source/halts/{identifier}/spatial_plan.json", "plan_reference": plan_reference,
               "prompt": style["prompt_prefix"] + scale_prompt + "\nNEW LOCATION: " + brief +
                         "\nSPATIAL PLAN: preserve the authored entrance, exits, circulation loop, obstacles and interaction positions in the attached plan. Keep walking paths unobstructed.",
               "next": "Author the spatial plan and hero scale references, attach them with the master artwork reference, generate, register the original, compare hero and prop proportions on the same floor, calibrate in Studio, prepare and verify at 720p and 1080p. Proportions require visual review before route assignment."}
    write(folder / "request.json", request)
    (folder / "generation_prompt.txt").write_text(request["prompt"] + "\n", encoding="utf-8", newline="\n")
    return folder


def attach(identifier: str, image: Path, root: Path = ROOT) -> Path:
    """Register a byte-identical original; planned geometry requires calibration."""
    from PIL import Image
    if not re.fullmatch(r"[a-z0-9_]+", identifier):
        raise ValueError("Unsafe map identifier")
    request = read(root / "art/source/halts" / identifier / "request.json")
    spatial_plan_path = project_path(request.get("spatial_plan", f"res://art/source/halts/{identifier}/spatial_plan.json"), root)
    plan = read(spatial_plan_path) if spatial_plan_path.is_file() else {}
    planned_world = plan.get("world", {})
    if not isinstance(planned_world, dict):
        raise ValueError("Spatial plan world must be an object")
    world = {"width": 2200, "player_scale": 0.52, "player_height_ratio": DEFAULT_PLAYER_HEIGHT_RATIO,
             "speed": 195, "foot_clearance": 12, "spawn": []}
    world.update(planned_world)
    require_range(world["player_height_ratio"], 0.06, 0.35, "Player height ratio")
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
    target = folder / ("source" + extension)
    original = image.read_bytes()
    data = {
        "schema_version": 1, "id": identifier, "title": identifier.replace("_", " "),
        "kind": request["kind"], "stage": "calibration",
        "style": "res://data/halts/styles/roots_bronze_v1.json",
        "source": {"image": "res://" + target.relative_to(root).as_posix(), "size": size,
                   "sha256": hashlib.sha256(original).hexdigest(),
                   "prompt": f"res://art/source/halts/{identifier}/generation_prompt.txt",
                   "spatial_plan": request.get("spatial_plan", ""), "references": request["references"], "provider": "record_provider_here"},
        "build_dir": "res://" + folder.relative_to(root).as_posix(),
        "world": world,
        "navigation": plan.get("navigation", {"outline": [], "obstacles": []}), "landmarks": plan.get("landmarks", []),
        "water": {"tint": "#48d896", "polygons": [], "regions": [], "exclusions": []},
        "cascades": [], "torches": [], "foliage": [], "bounce": [], "mist": [], "foreground": [], "review": {}}
    install_files({target: original, manifest: json_bytes(data)})
    return manifest


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    sub = parser.add_subparsers(dest="command", required=True)
    for name in ["check", "prepare"]:
        p = sub.add_parser(name)
        p.add_argument("manifest")
    p = sub.add_parser("new")
    p.add_argument("id")
    p.add_argument("--kind", default="sanctuary", choices=KINDS)
    p.add_argument("--brief", required=True)
    p.add_argument("--plan", type=Path, help="Authored spatial plan image or SVG to attach as a generation reference")
    p = sub.add_parser("attach")
    p.add_argument("id")
    p.add_argument("image")
    args = parser.parse_args()
    try:
        if args.command == "new":
            print(new_brief(args.id, args.kind, args.brief, plan=args.plan))
        elif args.command == "attach":
            print(attach(args.id, Path(args.image)))
        else:
            path = project_path(args.manifest)
            value = prepare(path) if args.command == "prepare" else validate(path)
            print(json.dumps({"passed": True, "id": value["id"], "command": args.command}))
    except (ValueError, KeyError, TypeError, OSError) as error:
        parser.exit(1, str(error) + "\n")


if __name__ == "__main__":
    main()
