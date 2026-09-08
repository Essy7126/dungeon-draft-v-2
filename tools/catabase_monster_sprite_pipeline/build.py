"""Pack already-authored local puppet poses without modifying their pixels.

Meshy supplies the fixed reference views; the caller owns articulation and
alignment. This module only validates, packs and serializes those RGBA frames.
"""
from __future__ import annotations

import argparse
import hashlib
import json
from pathlib import Path

import numpy as np
from PIL import Image, ImageDraw

ROOT = Path(__file__).resolve().parents[2]
SLUGS = ("sentinelle_airain", "rejeton_braise", "molosse_styx", "lamie_lethe")
DIRECTIONS = "NESW"
CANVAS = (512, 384)
ANCHOR = (256, 320)
POSES = 20
ACTION_FRAMES = {
    "idle": [0], "walk": list(range(1, 7)), "attack": list(range(7, 11)),
    "cast": list(range(11, 15)), "hit": [15], "death": list(range(16, 20)),
}
FPS = {"idle": 1.0, "walk": 10.0, "attack": 6.67, "cast": 6.67,
       "hit": 1.0, "death": 5.0}


def _hash(value: bytes) -> str:
    return hashlib.sha256(value).hexdigest()


def _write_json(path: Path, value: dict) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(json.dumps(value, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")


def _family(slug: str, project_root: Path | str = ROOT) -> Path:
    if slug not in SLUGS:
        raise ValueError("Unknown monster slug: " + str(slug))
    return Path(project_root) / "assets/characters/catabase_monsters" / slug


def _frame_measure(frame: Image.Image, index: int) -> dict:
    if not isinstance(frame, Image.Image) or frame.mode != "RGBA" or frame.size != CANVAS:
        raise ValueError(f"Pose {index}: expected an RGBA image of exactly {CANVAS}")
    rgba = np.asarray(frame)
    alpha = rgba[:, :, 3]
    ys, xs = np.where(alpha > 32)
    if len(xs) < 32:
        raise ValueError(f"Pose {index}: missing or nearly empty silhouette")
    bbox = [int(xs.min()), int(ys.min()), int(xs.max()) + 1, int(ys.max()) + 1]
    margins = [bbox[0], bbox[1], CANVAS[0] - bbox[2], CANVAS[1] - bbox[3]]
    if min(margins) < 2:
        raise ValueError(f"Pose {index}: silhouette reaches canvas edge, possible clipping: {bbox}")
    return {"index": index, "rgba_sha256": _hash(frame.tobytes()), "core_alpha": 32,
            "bbox": bbox, "margins": margins, "core_pixels": int(len(xs)),
            "alpha_sum": int(alpha.astype(np.uint64).sum()),
            "centroid": [float(xs.mean()), float(ys.mean())]}


def pack_frames(slug: str, direction: str, frames: list[Image.Image], provenance: dict,
                project_root: Path | str = ROOT) -> dict:
    """Write one atlas from exactly twenty prealigned RGBA 512x384 poses.

    No crop, key, re-scale, mirror, inpaint or alignment is performed here.
    provenance should identify fixed-view source hashes and the local pose recipe.
    The exact input bytes must survive PNG packing/reloading unchanged.
    """
    directory = _family(slug, project_root)
    if direction not in DIRECTIONS or len(direction) != 1:
        raise ValueError("Direction must be N, E, S or W")
    if len(frames) != POSES:
        raise ValueError(f"Expected 20 poses, received {len(frames)}")
    if not isinstance(provenance, dict) or not provenance:
        raise ValueError("Explicit, nonempty source/pose provenance is required")
    # Fail before writing any output if provenance cannot be serialized.
    json.dumps(provenance, allow_nan=False)
    measurements = [_frame_measure(frame, index) for index, frame in enumerate(frames)]
    atlas = Image.new("RGBA", (CANVAS[0] * 4, CANVAS[1] * 5))
    for index, frame in enumerate(frames):
        x, y = (index % 4) * CANVAS[0], (index // 4) * CANVAS[1]
        atlas.paste(frame, (x, y))  # No alpha mask: retain exact straight RGBA bytes.
        measurements[index]["region"] = [x, y, CANVAS[0], CANVAS[1]]
    directory.mkdir(parents=True, exist_ok=True)
    atlas_path = directory / f"atlas_{direction}.png"
    atlas.save(atlas_path, compress_level=9)
    reread = Image.open(atlas_path).convert("RGBA")
    raster_error = 0
    for index, frame in enumerate(frames):
        x, y, w, h = measurements[index]["region"]
        restored = reread.crop((x, y, x + w, y + h))
        difference = np.abs(np.asarray(restored).astype(np.int16) -
                            np.asarray(frame).astype(np.int16))
        error = int(difference.max())
        measurements[index]["raster_max_error"] = error
        raster_error = max(raster_error, error)
        if error != 0 or restored.tobytes() != frame.tobytes():
            raise ValueError(f"PNG packing changed pose {index} pixels")
    manifest = {"schema": 1, "slug": slug, "direction": direction,
                "source_kind": "fixed_view_with_local_articulation",
                "canvas": list(CANVAS), "anchor": list(ANCHOR), "grid": [4, 5],
                "atlas": atlas_path.name, "atlas_sha256": _hash(atlas_path.read_bytes()),
                "provenance": provenance, "frames": measurements,
                "raster_max_error": raster_error,
                "actions": ACTION_FRAMES, "fps": FPS,
                "release_frames": {"attack": 2, "cast": 2}}
    _write_json(directory / f"atlas_{direction}.manifest.json", manifest)
    _write_previews(slug, direction, frames, Path(project_root))
    return manifest


def _write_previews(slug: str, direction: str, frames: list[Image.Image], root: Path) -> None:
    directory = root / "output/catabase_monsters" / slug
    directory.mkdir(parents=True, exist_ok=True)
    board = Image.new("RGB", (512 * 4, 410 * 5), "#27363d")
    draw = ImageDraw.Draw(board)
    for index, frame in enumerate(frames):
        x, y = (index % 4) * 512, (index // 4) * 410
        board.paste(frame, (x, y), frame)
        draw.text((x + 10, y + 387), f"{direction} / pose {index:02d}", fill="white")
        draw.line((x + ANCHOR[0] - 4, y + ANCHOR[1], x + ANCHOR[0] + 4,
                   y + ANCHOR[1]), fill="#64c4bd")
    board.save(directory / f"contact_{direction}.png")
    for action, indices in ACTION_FRAMES.items():
        pictures = []
        for index in indices:
            background = Image.new("RGB", CANVAS, "#27363d")
            background.paste(frames[index], (0, 0), frames[index])
            picture = background.resize((768, 576), Image.Resampling.LANCZOS)
            ImageDraw.Draw(picture).text((14, 14), f"{slug}  {direction}  {action}", fill="white")
            pictures.append(picture)
        pictures[0].save(directory / f"{action}_{direction}.gif", save_all=True,
                         append_images=pictures[1:], loop=0, disposal=2,
                         duration=round(1000 / FPS[action]), optimize=False)


def verify_family(slug: str, project_root: Path | str = ROOT,
                  allow_partial: bool = False) -> dict:
    """Read-only validation of persisted atlases against their per-pose hashes."""
    directory = _family(slug, project_root)
    records = {}
    missing = []
    for direction in DIRECTIONS:
        path = directory / f"atlas_{direction}.manifest.json"
        if not path.exists():
            missing.append(direction)
            continue
        record = json.loads(path.read_text(encoding="utf-8"))
        atlas_path = directory / f"atlas_{direction}.png"
        if record.get("slug") != slug or record.get("direction") != direction:
            raise ValueError("Manifest identity mismatch: " + str(path))
        if _hash(atlas_path.read_bytes()) != record["atlas_sha256"]:
            raise ValueError("Atlas file hash mismatch: " + str(atlas_path))
        atlas = Image.open(atlas_path).convert("RGBA")
        if atlas.size != (CANVAS[0] * 4, CANVAS[1] * 5) or len(record["frames"]) != POSES:
            raise ValueError("Atlas size or frame count mismatch")
        for index, frame in enumerate(record["frames"]):
            expected = [(index % 4) * CANVAS[0], (index // 4) * CANVAS[1], *CANVAS]
            if frame["region"] != expected:
                raise ValueError(f"Unexpected atlas region in {direction} pose {index}")
            x, y, w, h = frame["region"]
            restored = atlas.crop((x, y, x + w, y + h))
            _frame_measure(restored, index)
            if _hash(restored.tobytes()) != frame["rgba_sha256"]:
                raise ValueError(f"Region hash mismatch in {direction} pose {index}")
        records[direction] = record
    if missing and not allow_partial:
        raise ValueError("Missing fixed-view directions: " + ", ".join(missing))
    return {"slug": slug, "complete": not missing, "missing": missing, "directions": records}


def write_sprite_frames(slug: str, portrait_rect: list[int], project_root: Path | str = ROOT,
                        allow_partial: bool = False) -> dict:
    """Finalize SpriteFrames, an explicit E-view portrait and family manifest.

    portrait_rect is [x,y,width,height] in the E idle 512x384 runtime frame.
    It should be visually selected around the head/upper torso by the caller.
    Final production output requires all four directions (default).
    """
    audit = verify_family(slug, project_root, allow_partial)
    records = audit["directions"]
    if not records or "E" not in records:
        raise ValueError("At least E is required for the portrait")
    if not isinstance(portrait_rect, (list, tuple)) or len(portrait_rect) != 4 or any(
            isinstance(value, bool) or not isinstance(value, int) for value in portrait_rect):
        raise ValueError("portrait_rect must contain four integer x/y/width/height values")
    x, y, width, height = portrait_rect
    if x < 0 or y < 0 or width <= 0 or height <= 0 or x + width > 512 or y + height > 384:
        raise ValueError("Portrait must be fully inside the E idle frame")
    directory = _family(slug, project_root)
    portrait_image = Image.open(directory / "atlas_E.png").crop((x, y, x + width, y + height))
    if portrait_image.getbbox() is None:
        raise ValueError("Portrait crop is empty")
    resource_root = f"res://assets/characters/catabase_monsters/{slug}/"
    sections = [f'[gd_resource type="SpriteFrames" load_steps={1 + len(records) * 21} format=3]', ""]
    for direction in records:
        sections.append(f'[ext_resource type="Texture2D" path="{resource_root}atlas_{direction}.png" id="atlas_{direction}"]')
    sections.append("")
    for direction in records:
        for index in range(POSES):
            x0, y0 = index % 4 * CANVAS[0], index // 4 * CANVAS[1]
            sections.extend([f'[sub_resource type="AtlasTexture" id="Frame_{direction}_{index}"]',
                             f'atlas = ExtResource("atlas_{direction}")',
                             f'region = Rect2({x0}, {y0}, 512, 384)', ""])
    animations = []
    for direction in records:
        for action, indices in ACTION_FRAMES.items():
            frame_values = ', '.join('{"duration": 1.0, "texture": SubResource("Frame_%s_%d")}' %
                                     (direction, index) for index in indices)
            loop = "true" if action in ["idle", "walk"] else "false"
            animations.append('{"frames": [%s], "loop": %s, "name": &"%s_%s", "speed": %s}' %
                              (frame_values, loop, action, direction, FPS[action]))
    sections.extend(["[resource]", "animations = [" + ",\n".join(animations) + "]", ""])
    (directory / "sprite_frames.tres").write_text("\n".join(sections), encoding="utf-8")
    portrait = f'''[gd_resource type="SpriteFrames" load_steps=3 format=3]

[ext_resource type="Texture2D" path="{resource_root}atlas_E.png" id="atlas"]

[sub_resource type="AtlasTexture" id="portrait"]
atlas = ExtResource("atlas")
region = Rect2({x}, {y}, {width}, {height})

[resource]
animations = [{{"frames": [{{"duration": 1.0, "texture": SubResource("portrait")}}], "loop": true, "name": &"idle_E", "speed": 1.0}}]
'''
    (directory / "portrait.tres").write_text(portrait, encoding="utf-8")
    manifest = {"schema": 1, "slug": slug, "complete": audit["complete"],
                "source_kind": "fixed_view_with_local_articulation", "canvas": list(CANVAS),
                "anchor": list(ANCHOR), "actions": ACTION_FRAMES, "fps": FPS,
                "release_frames": {"attack": 2, "cast": 2}, "portrait_rect": list(portrait_rect),
                "raster_max_error": 0, "directions": records}
    _write_json(directory / "manifest.json", manifest)
    return manifest


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--verify", choices=SLUGS, required=True)
    parser.add_argument("--allow-partial", action="store_true")
    options = parser.parse_args()
    print(json.dumps(verify_family(options.verify, allow_partial=options.allow_partial),
                     ensure_ascii=False, indent=2))
