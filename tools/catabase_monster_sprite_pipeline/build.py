"""Pack already-authored local puppet poses without modifying their pixels.

Meshy supplies the fixed reference views; the caller owns articulation and
alignment. This module only validates, packs and serializes those RGBA frames.
"""
from __future__ import annotations

import argparse
import hashlib
import json
import re
from pathlib import Path

import numpy as np
from PIL import Image, ImageDraw

ROOT = Path(__file__).resolve().parents[2]
SLUGS = ("sentinelle_airain", "rejeton_braise", "molosse_styx", "lamie_lethe")
DIRECTIONS = "NESW"
CANVAS = (512, 384)
ANCHOR = (256, 320)
POSES = 48
GUTTER = 2
ACTION_FRAMES = {
    "idle": list(range(0, 8)), "walk": list(range(8, 20)),
    "attack": list(range(20, 28)), "cast": list(range(28, 36)),
    "hit": list(range(36, 40)), "death": list(range(40, 48)),
}
FPS = {"idle": 5.0, "walk": 16.0, "attack": 12.5, "cast": 10.0,
       "hit": 20.0, "death": 10.0}
RELEASE_FRAMES = {"attack": 4, "cast": 4}


def profile_durations(slug: str, project_root: Path | str = ROOT) -> dict:
    """Read the runtime profile so exported/GIF clocks match each creature."""
    path = Path(project_root) / "data/visuals/catabase_monsters" / (slug + "_sprite_profile.tres")
    source = path.read_text(encoding="utf-8") if path.exists() else ""
    def field(name, fallback):
        match = re.search(r"^" + name + r"\s*=\s*([\d.]+)", source, re.M)
        return float(match[1]) if match else fallback
    action_match = re.search(r"^action_durations\s*=\s*(\{.*\})", source, re.M)
    durations = json.loads(action_match[1]) if action_match else {"attack": .64, "cast": .8}
    durations.update(idle=field("idle_cycle_seconds", 1.6),
                     hit=field("hit_duration_seconds", .2), death=field("death_duration_seconds", .64))
    durations["walk"] = field("movement_segment_duration_seconds", .30) / field("stride_cycles_per_cell", .5)
    return durations


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


def _packed_layout(sizes: list[tuple[int, int]]) -> tuple[tuple[int, int], dict]:
    """Deterministic, unrotated shelf packing; try widths and both useful orders."""
    candidates = []
    for width in (512, 768, 1024, 1280, 1536, 1792, 2048):
        if width < max(w + GUTTER * 2 for w, _ in sizes):
            continue
        for by_height in (True, False):
            order = sorted(range(len(sizes)), key=lambda i: (
                -(sizes[i][1] if by_height else sizes[i][0] * sizes[i][1]),
                -sizes[i][0], i))
            shelves, placements = [], {}
            for index in order:
                w, h = sizes[index]
                padded_w, padded_h = w + GUTTER * 2, h + GUTTER * 2
                fits = [(row[1] - padded_h, width - row[2] - padded_w, number)
                        for number, row in enumerate(shelves)
                        if padded_h <= row[1] and row[2] + padded_w <= width]
                if fits:
                    row = shelves[min(fits)[2]]
                else:
                    y = sum(row[1] for row in shelves)
                    row = [y, padded_h, 0]
                    shelves.append(row)
                placements[index] = [row[2] + GUTTER, row[0] + GUTTER, w, h]
                row[2] += padded_w
            height = sum(row[1] for row in shelves)
            used_width = max(row[2] for row in shelves)
            if height <= 4096:
                candidates.append((used_width * height, max(used_width, height),
                                   used_width, height, placements))
    if not candidates:
        raise ValueError("Cropped poses do not fit within the 4096px atlas limit")
    best = min(candidates, key=lambda value: value[:4])
    return (best[2], best[3]), best[4]


def restore_frame(atlas: Image.Image, frame: dict) -> Image.Image:
    """Rebuild the logical canvas; AtlasTexture.get_image omits its margin."""
    x, y, w, h = frame["region"]
    ox, oy, cw, ch = frame["crop"]
    if (w, h) != (cw, ch) or ox < 0 or oy < 0 or ox + w > 512 or oy + h > 384:
        raise ValueError("Invalid packed crop geometry")
    restored = Image.new("RGBA", CANVAS)
    restored.paste(atlas.crop((x, y, x + w, y + h)), (ox, oy))
    return restored


def pack_frames(slug: str, direction: str, frames: list[Image.Image], provenance: dict,
                project_root: Path | str = ROOT) -> dict:
    """Write one compact atlas from 48 prealigned RGBA 512x384 poses.

    Only empty padding is removed. AtlasTexture margins restore that padding;
    no key, re-scale, mirror, inpaint or alignment is performed here.
    provenance should identify fixed-view source hashes and the local pose recipe.
    The exact input bytes must survive PNG packing/reloading unchanged.
    """
    directory = _family(slug, project_root)
    if direction not in DIRECTIONS or len(direction) != 1:
        raise ValueError("Direction must be N, E, S or W")
    if len(frames) != POSES:
        raise ValueError(f"Expected {POSES} poses, received {len(frames)}")
    if not isinstance(provenance, dict) or not provenance:
        raise ValueError("Explicit, nonempty source/pose provenance is required")
    # Fail before writing any output if provenance cannot be serialized.
    json.dumps(provenance, allow_nan=False)
    durations = profile_durations(slug, project_root)
    fps = {action: len(indices) / durations[action] for action, indices in ACTION_FRAMES.items()}
    measurements = [_frame_measure(frame, index) for index, frame in enumerate(frames)]
    source_path = Path(project_root) / "art/source/characters/catabase_monsters" / slug / f"base_frame_{direction}.png"
    if source_path.exists() and frames[0].tobytes() != Image.open(source_path).convert("RGBA").tobytes():
        raise ValueError("Idle frame zero must preserve the fixed source view exactly")
    crops = []
    for index, frame in enumerate(frames):
        # Include invisible RGB too: complete original RGBA bytes remain auditable.
        ys, xs = np.where(np.any(np.asarray(frame) != 0, axis=2))
        left, top, right, bottom = int(xs.min()), int(ys.min()), int(xs.max()) + 1, int(ys.max()) + 1
        crops.append(frame.crop((left, top, right, bottom)))
        measurements[index]["crop"] = [left, top, right - left, bottom - top]
    atlas_size, placements = _packed_layout([crop.size for crop in crops])
    atlas = Image.new("RGBA", atlas_size)
    for index, crop in enumerate(crops):
        x, y, w, h = placements[index]
        atlas.paste(crop, (x, y))  # No alpha mask: retain exact straight RGBA bytes.
        measurements[index]["region"] = [x, y, w, h]
        ox, oy, _, _ = measurements[index]["crop"]
        measurements[index]["margin"] = [ox, oy, CANVAS[0] - w, CANVAS[1] - h]
    directory.mkdir(parents=True, exist_ok=True)
    atlas_path = directory / f"atlas_{direction}.png"
    atlas.save(atlas_path, compress_level=9)
    reread = Image.open(atlas_path).convert("RGBA")
    raster_error = 0
    for index, frame in enumerate(frames):
        restored = restore_frame(reread, measurements[index])
        difference = np.abs(np.asarray(restored).astype(np.int16) -
                            np.asarray(frame).astype(np.int16))
        error = int(difference.max())
        measurements[index]["raster_max_error"] = error
        raster_error = max(raster_error, error)
        if error != 0 or restored.tobytes() != frame.tobytes():
            raise ValueError(f"PNG packing changed pose {index} pixels")
    manifest = {"schema": 2, "slug": slug, "direction": direction,
                "source_kind": "fixed_view_with_local_articulation",
                "canvas": list(CANVAS), "anchor": list(ANCHOR),
                "packing": "trimmed_shelves_no_rotation", "gutter": GUTTER,
                "atlas_size": list(atlas_size),
                "rgba_bytes": atlas_size[0] * atlas_size[1] * 4,
                "untrimmed_rgba_bytes": POSES * CANVAS[0] * CANVAS[1] * 4,
                "atlas": atlas_path.name, "atlas_sha256": _hash(atlas_path.read_bytes()),
                "provenance": provenance, "frames": measurements,
                "raster_max_error": raster_error,
                "actions": ACTION_FRAMES, "fps": fps,
                "release_frames": RELEASE_FRAMES}
    _write_json(directory / f"atlas_{direction}.manifest.json", manifest)
    _write_previews(slug, direction, frames, Path(project_root), fps)
    return manifest


def _write_previews(slug: str, direction: str, frames: list[Image.Image], root: Path, fps: dict) -> None:
    directory = root / "output/catabase_monsters" / slug
    directory.mkdir(parents=True, exist_ok=True)
    board = Image.new("RGB", (512 * 8, 410 * 6), "#27363d")
    draw = ImageDraw.Draw(board)
    for index, frame in enumerate(frames):
        x, y = (index % 8) * 512, (index // 8) * 410
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
                         duration=round(1000 / fps[action]), optimize=False)


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
        if record.get("schema") != 2 or atlas.size != tuple(record["atlas_size"]) or len(record["frames"]) != POSES:
            raise ValueError("Atlas size or frame count mismatch")
        regions = []
        for index, frame in enumerate(record["frames"]):
            x, y, w, h = frame["region"]
            if x < GUTTER or y < GUTTER or x + w + GUTTER > atlas.width or y + h + GUTTER > atlas.height:
                raise ValueError(f"Packed region/gutter outside atlas in {direction} pose {index}")
            if any(x < rx + rw and x + w > rx and y < ry + rh and y + h > ry
                   for rx, ry, rw, rh in regions):
                raise ValueError(f"Overlapping atlas regions in {direction} pose {index}")
            regions.append(frame["region"])
            ox, oy, _, _ = frame["crop"]
            if frame["margin"] != [ox, oy, 512 - w, 384 - h]:
                raise ValueError("Logical AtlasTexture margin mismatch")
            restored = restore_frame(atlas, frame)
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
    portrait_image = restore_frame(Image.open(directory / "atlas_E.png").convert("RGBA"),
                                   records["E"]["frames"][0]).crop((x, y, x + width, y + height))
    if portrait_image.getbbox() is None:
        raise ValueError("Portrait crop is empty")
    portrait_image.save(directory / "portrait.png", compress_level=9)
    resource_root = f"res://assets/characters/catabase_monsters/{slug}/"
    sections = [f'[gd_resource type="SpriteFrames" load_steps={1 + len(records) * (POSES + 1)} format=3]', ""]
    for direction in records:
        sections.append(f'[ext_resource type="Texture2D" path="{resource_root}atlas_{direction}.png" id="atlas_{direction}"]')
    sections.append("")
    for direction in records:
        for index in range(POSES):
            frame = records[direction]["frames"][index]
            x0, y0, w, h = frame["region"]
            mx, my, mw, mh = frame["margin"]
            sections.extend([f'[sub_resource type="AtlasTexture" id="Frame_{direction}_{index}"]',
                             f'atlas = ExtResource("atlas_{direction}")',
                             f'region = Rect2({x0}, {y0}, {w}, {h})',
                             f'margin = Rect2({mx}, {my}, {mw}, {mh})',
                             'filter_clip = true', ""])
    animations = []
    for direction in records:
        for action, indices in ACTION_FRAMES.items():
            frame_values = ', '.join('{"duration": 1.0, "texture": SubResource("Frame_%s_%d")}' %
                                     (direction, index) for index in indices)
            loop = "true" if action in ["idle", "walk"] else "false"
            animations.append('{"frames": [%s], "loop": %s, "name": &"%s_%s", "speed": %s}' %
                              (frame_values, loop, action, direction, records[direction]["fps"][action]))
    sections.extend(["[resource]", "animations = [" + ",\n".join(animations) + "]", ""])
    (directory / "sprite_frames.tres").write_text("\n".join(sections), encoding="utf-8")
    portrait = f'''[gd_resource type="SpriteFrames" load_steps=2 format=3]

[ext_resource type="Texture2D" path="{resource_root}portrait.png" id="portrait"]

[resource]
animations = [{{"frames": [{{"duration": 1.0, "texture": ExtResource("portrait")}}], "loop": true, "name": &"idle_E", "speed": 1.0}}]
'''
    (directory / "portrait.tres").write_text(portrait, encoding="utf-8")
    manifest = {"schema": 2, "slug": slug, "complete": audit["complete"],
                "source_kind": "fixed_view_with_local_articulation", "canvas": list(CANVAS),
                "anchor": list(ANCHOR), "actions": ACTION_FRAMES, "fps": records["E"]["fps"],
                "release_frames": RELEASE_FRAMES, "portrait_rect": list(portrait_rect),
                "portrait_rgba_sha256": _hash(portrait_image.tobytes()),
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
